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

// netlify/functions/driver-sms-background.mjs
var driver_sms_background_exports = {};
__export(driver_sms_background_exports, {
  handler: () => handler
});
module.exports = __toCommonJS(driver_sms_background_exports);

// netlify/functions/driver-sms.mjs
var import_node_crypto = require("crypto");
var project = "bajfreight-system";
var root = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
var roles = /* @__PURE__ */ new Set(["manager_officer", "manager/officer"]);
var officeRoles = /* @__PURE__ */ new Set([...roles, "officer", "officer in charge", "manager", "management"]);
var fetchBounded = (url, options = {}, timeoutMs = 5e3) => fetch(url, { ...options, signal: AbortSignal.timeout(timeoutMs) });
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

// netlify/functions/driver-sms-background.mjs
async function handler(event) {
  await runQueuedBatch(event);
  return { statusCode: 200 };
}
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  handler
});
//# sourceMappingURL=driver-sms-background.js.map
