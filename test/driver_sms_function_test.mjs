import { generateKeyPairSync } from 'node:crypto';
import assert from 'node:assert/strict';
import test from 'node:test';
import { handler } from '../netlify/functions/driver-sms.mjs';

test('only manager-officers can record a preview, and a repeated request is not sent again', async (t) => {
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
  let saved;
  let savedPhone = '0240000000';
  let writes = 0;
  const doc = (data) => ({ fields: Object.fromEntries(Object.entries(data)
    .map(([key, value]) => [key, typeof value === 'boolean'
      ? { booleanValue: value } : { stringValue: value }])) });
  t.mock.method(globalThis, 'fetch', async (url, options = {}) => {
    const address = new URL(url);
    if (address.hostname === 'identitytoolkit.googleapis.com') {
      return Response.json({ users: [{ localId: 'manager-1' }] });
    }
    if (address.hostname === 'oauth2.googleapis.com') {
      return Response.json({ access_token: 'admin' });
    }
    assert.equal(address.hostname, 'firestore.googleapis.com', 'preview cannot contact Arkesel');
    if (address.pathname.endsWith('/users/manager-1')) {
      return Response.json(doc({ role, isActive: true, fullName: 'Test Manager' }));
    }
    if (address.pathname.endsWith('/users/driver-1')) {
      return Response.json(doc({ role: 'driver', isActive: true, phoneNumber: savedPhone }));
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
  assert.equal(writes, 0);
  role = 'manager_officer';
  const first = await handler(event);
  assert.equal(first.statusCode, 200);
  assert.equal(JSON.parse(first.body).record.status, 'preview');
  assert.equal(JSON.parse(first.body).record.phone, '233240000000');
  assert.equal(writes, 2);
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
});
