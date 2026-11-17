import { generateKeyPairSync } from 'node:crypto';
import assert from 'node:assert/strict';
import test from 'node:test';
import { handler, runQueuedBatch } from '../netlify/functions/driver-sms.mjs';

test('authorized staff can record a preview, and a repeated request is not sent again', async (t) => {
  const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
  t.mock.method(process, 'emitWarning', () => {});
  process.env.BAJ_SMS_MODE = 'preview';
  process.env.BAJ_SMS_FIREBASE_WEB_API_KEY = 'test';
  process.env.BAJ_SMS_SERVICE_ACCOUNT_JSON = JSON.stringify({
    project_id: 'bajfreight-system',
    client_email: 'test@example.com',
    private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
  });
  let role = 'driver';
  let senderDepartment = 'Transport';
  let saved;
  let savedPhone = '0240000000';
  let writes = 0;
  let providerCalls = 0;
  let acceptSend = false;
  const queuedDocs = new Map();
  let workerEvent;
  const doc = (data) => ({ fields: Object.fromEntries(Object.entries(data)
    .map(([key, value]) => [key, typeof value === 'boolean'
      ? { booleanValue: value } : { stringValue: value }])) });
  t.mock.method(globalThis, 'fetch', async (url, options = {}) => {
    const address = new URL(url);
    if (address.hostname === 'sms-worker.example') {
      workerEvent = { httpMethod: 'POST', headers: options.headers, body: options.body };
      return new Response(null, { status: 202 });
    }
    if (address.hostname === 'identitytoolkit.googleapis.com') {
      return Response.json({ users: [{ localId: 'manager-1' }] });
    }
    if (address.hostname === 'oauth2.googleapis.com') {
      return Response.json({ access_token: 'admin' });
    }
    if (address.hostname === 'sms.arkesel.com' && process.env.BAJ_SMS_MODE === 'live') {
      providerCalls++;
      assert.equal(address.pathname, '/api/v2/sms/send');
      assert.equal(options.method, 'POST');
      assert.equal(options.headers['api-key'], 'test');
      assert.deepEqual(JSON.parse(options.body), {
        sender: 'BAJ',
        message: 'Collect the cargo at 9 AM.',
        recipients: ['233200000000'],
        sandbox: false,
      });
      if (acceptSend) return new Response('unused response body', { status: 202 });
      throw new DOMException('Mock response timeout', 'TimeoutError');
    }
    assert.equal(address.hostname, 'firestore.googleapis.com', 'preview cannot contact Arkesel');
    if (address.pathname.endsWith(':commit')) {
      for (const { update } of JSON.parse(options.body).writes) {
        queuedDocs.set(update.name.split('/documents/')[1], update);
      }
      return Response.json({});
    }
    const path = address.pathname.split('/documents/')[1];
    if (queuedDocs.has(path)) {
      const current = queuedDocs.get(path);
      if (options.method === 'PATCH') {
        const next = JSON.parse(options.body);
        if (address.searchParams.has('currentDocument.updateTime')) {
          assert.equal(address.searchParams.get('currentDocument.updateTime'), '2026-01-01T00:00:00Z');
          current.fields.status = next.fields.status;
        } else {
          queuedDocs.set(path, next);
        }
        return Response.json({});
      }
      return Response.json({ ...current, updateTime: '2026-01-01T00:00:00Z' });
    }
    if (path?.includes('/driverSmsBatches/')) return new Response(null, { status: 404 });
    if (address.pathname.endsWith('/users/manager-1')) {
      return Response.json(doc({ role, isActive: true, fullName: 'Test Manager', department: senderDepartment }));
    }
    const office = (department) => doc({
      role: 'officer', isActive: true, department, phoneNumber: '0240000000',
    });
    if (address.pathname.endsWith(':runQuery')) {
      const query = JSON.parse(options.body).structuredQuery;
      assert.equal(query.where.fieldFilter.value.stringValue, 'Transport');
      return Response.json(['office-1', 'office-2'].map((id, i) => ({
        document: { name: `users/${id}`, ...office(i ? 'Accounts' : 'Transport') },
      })));
    }
    if (address.pathname.endsWith('/users/office-1')) return Response.json(office('Transport'));
    if (address.pathname.endsWith('/users/office-2')) return Response.json(office('Accounts'));
    if (address.pathname.endsWith('/users/driver-1')) {
      return Response.json(doc({ role: 'driver', isActive: true, phoneNumber: savedPhone }));
    }
    if (address.pathname.endsWith('/driverSmsHistory') && !options.method) {
      return Response.json({ documents: [
        doc({ status: 'accepted', providerId: 'message-1', phone: '233200000000' }),
        doc({ status: 'unknown', providerId: '', phone: '233200000000' }),
        doc({ status: 'accepted', providerId: 'missing', phone: '233200000000' }),
      ] });
    }
    if (['POST', 'PATCH'].includes(options.method)) {
      writes++;
      saved = JSON.parse(options.body);
      return Response.json(saved);
    }
    return saved ? Response.json(saved) : new Response(null, { status: 404 });
  });
  const event = {
    httpMethod: 'POST',
    headers: { authorization: 'Bearer test-token' },
    body: JSON.stringify({
      driverId: 'driver-1', requestId: 'a'.repeat(32), phone: '024 000 0000',
      message: 'Collect the cargo at 9 AM.',
    }),
  };
  assert.equal((await handler(event)).statusCode, 403);
  role = 'officer';
  senderDepartment = 'Shipping';
  assert.equal((await handler(event)).statusCode, 403);
  assert.equal(writes, 0);
  senderDepartment = 'Transport';
  const first = await handler(event);
  assert.equal(first.statusCode, 200);
  assert.equal(JSON.parse(first.body).record.status, 'preview');
  assert.equal(JSON.parse(first.body).record.phone, '233240000000');
  assert.equal(writes, 2);
  role = 'manager_officer';
  assert.equal(JSON.parse((await handler(event)).body).record.status, 'preview');
  assert.equal(writes, 2);
  saved = undefined;
  const manual = { ...event, body: JSON.stringify({
    ...JSON.parse(event.body), requestId: 'b'.repeat(32), phone: '020 000 0000',
  }) };
  assert.equal((await handler(manual)).statusCode, 409);
  savedPhone = '';
  const manualResult = await handler(manual);
  assert.equal(manualResult.statusCode, 200);
  assert.equal(JSON.parse(manualResult.body).record.phone, '233200000000');
  process.env.BAJ_SMS_MODE = 'live';
  process.env.BAJ_ARKESEL_API_KEY = 'test';
  process.env.BAJ_ARKESEL_SENDER_ID = 'BAJ';
  saved = undefined;
  const live = { ...manual, body: JSON.stringify({
    ...JSON.parse(manual.body), requestId: 'c'.repeat(32),
  }) };
  const timedOut = JSON.parse((await handler(live)).body).record;
  assert.equal(timedOut.status, 'unknown');
  assert.equal(timedOut.httpStatus, undefined);
  assert.equal(JSON.parse((await handler(live)).body).record.status, 'unknown');
  assert.equal(providerCalls, 1);
  const history = await handler({ ...event, httpMethod: 'GET' });
  assert.equal(history.statusCode, 200);
  const records = JSON.parse(history.body).records;
  assert.deepEqual(records.map((r) => r.status), ['accepted', 'unknown', 'accepted']);
  assert.equal(providerCalls, 1);
  saved = undefined;
  acceptSend = true;
  const accepted = JSON.parse((await handler({ ...live, body: JSON.stringify({
    ...JSON.parse(live.body), requestId: 'd'.repeat(32),
  }) })).body).record;
  assert.equal(accepted.status, undefined);
  assert.equal(accepted.httpStatus, '202');
  assert.equal(accepted.providerId, undefined);
  assert.equal(accepted.detail, undefined);
  assert.equal(providerCalls, 2);
  const direct = { ...event, body: JSON.stringify({
    testSms: 'true', requestId: 'e'.repeat(32), phone: '0240000000', message: 'Direct test',
  }) };
  delete process.env.BAJ_SMS_ALLOW_TEST;
  assert.equal((await handler(direct)).statusCode, 403);
  process.env.BAJ_SMS_ALLOW_TEST = 'true';
  assert.equal((await handler(direct)).statusCode, 403);
  role = 'super_user';
  assert.equal((await handler(event)).statusCode, 403);
  process.env.BAJ_SMS_MODE = 'preview';
  saved = undefined;
  const directResult = JSON.parse((await handler(direct)).body).record;
  assert.equal(directResult.driverName, 'Direct test SMS');
  assert.equal(directResult.status, 'preview');
  assert.equal(directResult.phone, '233240000000');
  assert.equal(providerCalls, 2);
  role = 'manager_officer';
  const directory = await handler({ ...event, httpMethod: 'GET', queryStringParameters: { directory: 'office' } });
  assert.deepEqual(JSON.parse(directory.body).members.map((member) => member.userId), ['office-1']);
  saved = undefined;
  const officeSend = (id) => ({ ...event, body: JSON.stringify({
    ...JSON.parse(event.body), driverId: id, recipientType: 'office', requestId: 'f'.repeat(32),
  }) });
  assert.equal((await handler(officeSend('office-2'))).statusCode, 403);
  const officeRecord = JSON.parse((await handler(officeSend('office-1'))).body).record;
  assert.equal(officeRecord.recipientType, 'office');
  assert.equal(officeRecord.recipientId, 'office-1');
  assert.equal(officeRecord.status, 'preview');
  saved = undefined;
  process.env.BAJ_SMS_MODE = 'live';
  process.env.BAJ_SMS_WORKER_LOCAL_URL = 'https://sms-worker.example';
  const batch = { ...event, body: JSON.stringify({
    action: 'queue', batchId: '8'.repeat(32), message: 'Collect the cargo at 9 AM.',
    recipients: [{ driverId: 'driver-1', requestId: '9'.repeat(32), phone: '0200000000' }],
  }) };
  const countBeforeQueue = providerCalls;
  const queued = await handler(batch);
  assert.equal(queued.statusCode, 200);
  assert.equal(JSON.parse(queued.body).records[0].status, 'queued');
  assert.equal(providerCalls, countBeforeQueue);
  await runQueuedBatch({ ...workerEvent, headers: { 'x-baj-sms-signature': '0'.repeat(64) } });
  assert.equal(providerCalls, countBeforeQueue);
  await runQueuedBatch(workerEvent);
  await runQueuedBatch(workerEvent);
  const retried = await handler(batch);
  assert.equal(JSON.parse(retried.body).records[0].httpStatus, '202');
  assert.equal(providerCalls, countBeforeQueue + 1);
});
