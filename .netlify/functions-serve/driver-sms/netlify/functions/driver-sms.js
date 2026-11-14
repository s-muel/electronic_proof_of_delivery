var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// netlify/functions/driver-sms.mjs
var driver_sms_exports = {};
__export(driver_sms_exports, {
  handler: () => handler,
  normalizePhone: () => normalizePhone,
  runQueuedBatch: () => runQueuedBatch
});
module.exports = __toCommonJS(driver_sms_exports);
var import_node_crypto = require("crypto");
var project = "bajfreight-system";
var root = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
var roles = /* @__PURE__ */ new Set(["manager_officer", "manager/officer"]);
var officeRoles = /* @__PURE__ */ new Set([...roles, "officer", "officer in charge", "manager", "management"]);
var department = (profile) => String(profile?.department ?? "").trim();
var isOfficePeer = (member, sender) => Boolean(department(sender)) && department(member) === department(sender) && member?.isActive === true && officeRoles.has(String(member.role).trim().toLowerCase());
var superUserRoles = /* @__PURE__ */ new Set(["super_user", "super user", "admin"]);
var fetchBounded = (url, options = {}, timeoutMs = 5e3) => fetch(url, { ...options, signal: AbortSignal.timeout(timeoutMs) });
var json = (statusCode, data) => ({
  statusCode,
  headers: {
    "content-type": "application/json",
    "cache-control": "no-store",
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "authorization, content-type",
    "access-control-allow-methods": "GET, POST, OPTIONS"
  },
  body: JSON.stringify(data)
});
var auth = (token) => ({ authorization: `Bearer ${token}` });
var fields = (data) => Object.fromEntries(
  Object.entries(data.fields || {}).map(([k, v]) => [k, Object.values(v)[0]])
);
var document = (data) => JSON.stringify({
  fields: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, { stringValue: v }]))
});
var encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
var idPattern = /^[a-f0-9]{32}$/;
var database = `projects/${project}/databases/(default)/documents`;
async function inChunks(items, size, action) {
  const results = [];
  for (let i = 0; i < items.length; i += size) {
    results.push(...await Promise.all(items.slice(i, i + size).map(action)));
  }
  return results;
}
function workerSignature(body) {
  const account = JSON.parse(process.env.BAJ_SMS_SERVICE_ACCOUNT_JSON || "{}");
  return (0, import_node_crypto.createHmac)("sha256", account.private_key).update("baj-sms-worker-v1\n").update(body).digest();
}
async function dispatchBatch(uid, batchId, ids) {
  const origin = process.env.BAJ_SMS_WORKER_LOCAL_URL || process.env.DEPLOY_URL || process.env.URL;
  if (!origin) throw Error("SMS worker URL is unavailable");
  const body = JSON.stringify({ uid, batchId, ids, issuedAt: Date.now() });
  const response = await fetchBounded(new URL("/.netlify/functions/driver-sms-background", origin), {
    method: "POST",
    headers: { "content-type": "application/json", "x-baj-sms-signature": workerSignature(body).toString("hex") },
    body
  }, 8e3);
  if (response.status !== 202) throw Error("SMS worker did not accept the batch");
}
async function queueBatch(payload, uid, profile, collection, admin) {
  const { batchId, recipients } = payload;
  const message = typeof payload.message === "string" ? payload.message.trim() : "";
  if (!idPattern.test(batchId || "") || !Array.isArray(recipients) || !recipients.length || recipients.length > 200 || !message || message.length > 480 || recipients.some((r) => !r || !idPattern.test(r.requestId || "") || !/^[\w-]{1,128}$/.test(r.driverId || "") || !normalizePhone(r.phone)) || new Set(recipients.map((r) => r.requestId)).size !== recipients.length || new Set(recipients.map((r) => r.driverId)).size !== recipients.length) {
    return json(400, { error: "Choose up to 200 recipients with valid Ghana numbers and enter a message." });
  }
  const batchPath = `users/${encodeURIComponent(uid)}/driverSmsBatches/${batchId}`;
  const fingerprint = (0, import_node_crypto.createHmac)("sha256", batchId).update(JSON.stringify({ message, recipients })).digest("hex");
  const existing = await read(batchPath, admin);
  if (existing && existing.fingerprint !== fingerprint) {
    return json(409, { error: "This batch ID was already used for a different message." });
  }
  const loadRecords = () => inChunks(recipients, 20, (r) => read(`${collection}/${r.requestId}`, admin));
  let records;
  if (existing) {
    records = await loadRecords();
  } else {
    const createdAt = (/* @__PURE__ */ new Date()).toISOString();
    const preview = process.env.BAJ_SMS_MODE !== "live";
    records = await inChunks(recipients, 20, async (r) => {
      const member = await read(`users/${encodeURIComponent(r.driverId)}`, admin);
      const office = r.recipientType === "office";
      const phone = normalizePhone(r.phone);
      const saved = String(member?.phoneNumber ?? "").trim();
      const eligible = office ? r.driverId !== uid && isOfficePeer(member, profile) : member?.role === "driver" && member.isActive !== false;
      return {
        requestId: r.requestId,
        batchId,
        senderId: uid,
        senderName: String(profile.fullName || uid),
        driverId: office ? "" : r.driverId,
        recipientId: r.driverId,
        recipientType: office ? "office" : "driver",
        driverName: String(member?.fullName || "Recipient"),
        phone,
        message,
        createdAt,
        status: !eligible || saved && normalizePhone(saved) !== phone ? "failed" : preview ? "preview" : "queued"
      };
    });
    const create = (path, data) => ({
      update: { name: `${database}/${path}`, ...JSON.parse(document(data)) },
      currentDocument: { exists: false }
    });
    const response = await fetchBounded(`${root}:commit`, {
      method: "POST",
      headers: { ...auth(admin), "content-type": "application/json" },
      body: JSON.stringify({ writes: [
        create(batchPath, { fingerprint, createdAt }),
        ...records.map((record) => create(`${collection}/${record.requestId}`, record))
      ] })
    });
    if (!response.ok) {
      const raced = await read(batchPath, admin);
      if (raced?.fingerprint !== fingerprint) throw Error("Could not save SMS batch");
      records = await loadRecords();
    }
  }
  if (records.some((record) => !record || record.batchId !== batchId)) {
    throw Error("SMS batch history is incomplete");
  }
  const queued = records.filter((record) => record.status === "queued");
  if (queued.length) await dispatchBatch(uid, batchId, queued.map((record) => record.requestId));
  return json(200, { records });
}
function normalizePhone(value) {
  if (!/^[+\d\s().-]+$/.test(String(value || ""))) return "";
  let digits = String(value).replace(/\D/g, "").replace(/^00/, "");
  if (/^0\d{9}$/.test(digits)) digits = "233" + digits.slice(1);
  else if (/^\d{9}$/.test(digits)) digits = "233" + digits;
  return /^233\d{9}$/.test(digits) ? digits : "";
}
async function adminToken() {
  const account = JSON.parse(process.env.BAJ_SMS_SERVICE_ACCOUNT_JSON || "{}");
  if (account.project_id !== project) throw new Error("Invalid SMS service account");
  const now = Math.floor(Date.now() / 1e3);
  const aud = "https://oauth2.googleapis.com/token";
  const jwt = encode({ alg: "RS256", typ: "JWT" }) + "." + encode({
    iss: account.client_email,
    aud,
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/datastore"
  });
  const assertion = jwt + "." + (0, import_node_crypto.createSign)("RSA-SHA256").update(jwt).sign(account.private_key, "base64url");
  const response = await fetchBounded(aud, {
    method: "POST",
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion
    })
  });
  if (!response.ok) throw new Error("Service account authentication failed");
  return (await response.json()).access_token;
}
async function read(path, token) {
  const response = await fetchBounded(`${root}/${path}`, { headers: auth(token) });
  if (response.status === 404) return null;
  if (!response.ok) throw new Error("Firestore read failed");
  return fields(await response.json());
}
async function handler(event) {
  if (event.httpMethod === "OPTIONS") return { ...json(204, {}), body: "" };
  if (!["GET", "POST"].includes(event.httpMethod)) return json(405, { error: "Method not allowed." });
  const token = /^Bearer (\S+)$/i.exec(event.headers?.authorization || "")?.[1];
  if (!token) return json(401, { error: "Sign in again to use driver SMS." });
  let stage = "Firebase sign-in verification";
  try {
    const key = process.env.BAJ_SMS_FIREBASE_WEB_API_KEY;
    if (!key) return json(503, { error: "Driver SMS is not configured." });
    const lookup = await fetchBounded(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(key)}`,
      { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ idToken: token }) }
    );
    if (!lookup.ok) return json(401, { error: "Sign in again to use driver SMS." });
    const uid = (await lookup.json()).users?.[0]?.localId;
    if (!uid) return json(401, { error: "Sign in again to use driver SMS." });
    const owner = `users/${encodeURIComponent(uid)}`;
    stage = "manager profile lookup";
    const profile = await read(owner, token);
    const role = String(profile?.role).trim().toLowerCase();
    let payload;
    if (event.httpMethod === "POST") {
      try {
        payload = JSON.parse(event.body || "{}") || {};
      } catch {
        return json(400, { error: "Invalid message request." });
      }
    }
    const testSms = payload?.testSms === "true";
    if (profile?.isActive !== true || !(testSms ? superUserRoles : roles).has(role)) {
      return json(403, { error: testSms ? "Only active Super Users can send test SMS." : "Only active Transport Managers can use driver SMS." });
    }
    if (testSms && process.env.BAJ_SMS_ALLOW_TEST !== "true") {
      return json(403, { error: "Direct test SMS is not enabled on this server." });
    }
    stage = "SMS service-account authentication";
    const admin = await adminToken();
    stage = "Firestore SMS history and driver access";
    const collection = `${owner}/driverSmsHistory`;
    if (event.httpMethod === "GET") {
      if (event.queryStringParameters?.directory === "office") {
        if (!department(profile)) return json(200, { members: [] });
        const result2 = await fetchBounded(`${root}:runQuery`, {
          method: "POST",
          headers: { ...auth(admin), "content-type": "application/json" },
          body: JSON.stringify({ structuredQuery: {
            from: [{ collectionId: "users" }],
            select: { fields: ["fullName", "phoneNumber", "role", "department", "isActive"].map((fieldPath) => ({ fieldPath })) },
            where: { fieldFilter: {
              field: { fieldPath: "department" },
              op: "EQUAL",
              value: { stringValue: profile.department }
            } }
          } })
        });
        if (!result2.ok) throw new Error("Office directory lookup failed");
        const members = (await result2.json()).flatMap(({ document: doc }) => {
          if (!doc) return [];
          const member = fields(doc);
          const userId = doc.name.split("/").at(-1);
          return isOfficePeer(member, profile) && userId !== uid ? [{ ...member, userId }] : [];
        });
        return json(200, { members });
      }
      const params = new URLSearchParams({ pageSize: "25", orderBy: "createdAt desc" });
      const cursor = event.queryStringParameters?.cursor;
      if (cursor) params.set("pageToken", cursor);
      const result = await fetchBounded(`${root}/${collection}?${params}`, { headers: auth(admin) });
      if (!result.ok) throw new Error("History read failed");
      const page = await result.json();
      const records = (page.documents || []).map(fields);
      return json(200, { records, cursor: page.nextPageToken });
    }
    if (payload.action === "queue" && !testSms) {
      stage = "queueing and starting the SMS batch";
      return await queueBatch(payload, uid, profile, collection, admin);
    }
    const { driverId, requestId, phone } = payload;
    const officeSms = !testSms && payload.recipientType === "office";
    const { batchId } = payload;
    if (batchId != null && (typeof batchId !== "string" || !/^[a-f0-9]{32}$/.test(batchId))) {
      return json(400, { error: "Invalid SMS batch ID." });
    }
    const message = typeof payload.message === "string" ? payload.message.trim() : "";
    if (!testSms && !/^[\w-]{1,128}$/.test(driverId || "") || !/^[a-f0-9]{32}$/.test(requestId || "") || !message || message.length > 480) {
      return json(400, { error: "Select a driver and enter a message of 1\u2013480 characters." });
    }
    const path = `${collection}/${requestId}`;
    const previous = await read(path, admin);
    if (previous) return json(200, { record: previous });
    const driver = testSms ? null : await read(`users/${encodeURIComponent(driverId)}`, admin);
    const savedPhone = String(driver?.phoneNumber ?? "").trim();
    const to = normalizePhone(phone);
    if (officeSms && (driverId === uid || !isOfficePeer(driver, profile))) {
      return json(403, { error: "Select an active officer or manager in your department." });
    }
    if (!testSms && !officeSms && (!driver || driver.isActive === false || driver.role !== "driver")) {
      return json(400, { error: "Select an active driver." });
    }
    if (!to) return json(400, { error: "Enter a valid Ghana phone number." });
    if (savedPhone && to !== normalizePhone(savedPhone)) {
      return json(409, { error: "The recipient\u2019s number changed. Refresh the directory before sending." });
    }
    const record = {
      requestId,
      senderId: uid,
      senderName: String(profile.fullName || uid),
      driverId: testSms || officeSms ? "" : driverId,
      recipientId: testSms ? "" : driverId,
      recipientType: testSms ? "test" : officeSms ? "office" : "driver",
      driverName: testSms ? "Direct test SMS" : String(driver.fullName || (officeSms ? "Office staff" : "Driver")),
      phone: to,
      message,
      createdAt: (/* @__PURE__ */ new Date()).toISOString(),
      ...!testSms && batchId ? { batchId } : {},
      status: "pending"
    };
    const created = await fetchBounded(`${root}/${collection}?documentId=${requestId}`, {
      method: "POST",
      headers: { ...auth(admin), "content-type": "application/json" },
      body: document(record)
    });
    if (created.status === 409) return json(200, { record: await read(path, admin) });
    if (!created.ok) throw new Error("Could not create history record");
    stage = "sending and saving the result";
    await sendRecord(path, record, admin);
    return json(200, { record });
  } catch {
    console.error("BAJ SMS request failed during %s", stage);
    return json(503, { error: `SMS service failed during ${stage}. Check history before sending again.` });
  }
}
async function sendRecord(path, record, admin) {
  const to = record.phone;
  const { message } = record;
  const dryRun = process.env.BAJ_SMS_MODE !== "live";
  const apiKey = process.env.BAJ_ARKESEL_API_KEY?.trim();
  const sender = process.env.BAJ_ARKESEL_SENDER_ID?.trim();
  if (dryRun) {
    record.status = "preview";
  } else if (!apiKey || !/^[A-Za-z0-9]{1,11}$/.test(sender || "")) {
    record.status = "failed";
  } else {
    try {
      const response = await fetchBounded("https://sms.arkesel.com/api/v2/sms/send", {
        method: "POST",
        headers: { "api-key": apiKey, "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({ sender, message, recipients: [to], sandbox: false })
      }, 12e3);
      record.httpStatus = String(response.status);
      if (response.ok) {
        delete record.status;
      } else {
        record.status = response.status >= 500 ? "unknown" : "failed";
      }
      void response.body?.cancel().catch(() => {
      });
    } catch {
      record.status = "unknown";
    }
  }
  const updated = await fetchBounded(`${root}/${path}`, {
    method: "PATCH",
    headers: { ...auth(admin), "content-type": "application/json" },
    body: document(record)
  });
  if (!updated.ok) throw new Error("Could not save the provider result");
}
async function runQueuedBatch(event) {
  if (event.httpMethod !== "POST" || event.isBase64Encoded) return;
  const body = event.body || "";
  const signature = event.headers?.["x-baj-sms-signature"] || "";
  if (!/^[a-f0-9]{64}$/.test(signature) || !(0, import_node_crypto.timingSafeEqual)(Buffer.from(signature, "hex"), workerSignature(body))) return;
  const { uid, ids, batchId, issuedAt } = JSON.parse(body);
  if (!/^[\w-]{1,128}$/.test(uid) || !idPattern.test(batchId) || !Number.isFinite(issuedAt) || Date.now() - issuedAt > 15 * 60 * 1e3 || !Array.isArray(ids) || ids.length > 200 || ids.some((id) => !idPattern.test(id))) return;
  const admin = await adminToken();
  await inChunks(ids, 5, async (id) => {
    try {
      const path = `users/${uid}/driverSmsHistory/${id}`;
      const response = await fetchBounded(`${root}/${path}`, { headers: auth(admin) });
      if (!response.ok) throw Error("Queued SMS read failed");
      const doc = await response.json();
      const record = fields(doc);
      if (record.status !== "queued" || record.batchId !== batchId || !doc.updateTime) return;
      const params = new URLSearchParams({
        "updateMask.fieldPaths": "status",
        "currentDocument.updateTime": doc.updateTime
      });
      const claim = await fetchBounded(`${root}/${path}?${params}`, {
        method: "PATCH",
        headers: { ...auth(admin), "content-type": "application/json" },
        body: document({ status: "processing" })
      });
      if (claim.status === 409 || claim.status === 412 || claim.status === 400) return;
      if (!claim.ok) throw Error("Queued SMS claim failed");
      await sendRecord(path, record, admin);
    } catch {
      console.error("Could not finish a queued BAJ SMS record");
    }
  });
}
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  handler,
  normalizePhone,
  runQueuedBatch
});
//# sourceMappingURL=driver-sms.js.map
