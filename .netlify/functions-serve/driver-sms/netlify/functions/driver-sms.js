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
  normalizePhone: () => normalizePhone
});
module.exports = __toCommonJS(driver_sms_exports);
var import_node_crypto = require("crypto");
var project = "bajfreight-system";
var root = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
var roles = /* @__PURE__ */ new Set(["manager_officer", "manager/officer"]);
var fetchBounded = (url, options = {}) => fetch(url, { ...options, signal: AbortSignal.timeout(5e3) });
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
    if (!profile || profile.isActive !== true || !roles.has(String(profile.role).trim().toLowerCase())) {
      return json(403, { error: "Only active Transport Managers can use driver SMS." });
    }
    stage = "SMS service-account authentication";
    const admin = await adminToken();
    stage = "Firestore SMS history and driver access";
    const collection = `${owner}/driverSmsHistory`;
    if (event.httpMethod === "GET") {
      const params = new URLSearchParams({ pageSize: "25", orderBy: "createdAt desc" });
      const cursor = event.queryStringParameters?.cursor;
      if (cursor) params.set("pageToken", cursor);
      const result = await fetchBounded(`${root}/${collection}?${params}`, { headers: auth(admin) });
      if (!result.ok) throw new Error("History read failed");
      const page = await result.json();
      return json(200, { records: (page.documents || []).map(fields), cursor: page.nextPageToken });
    }
    let payload;
    try {
      payload = JSON.parse(event.body || "{}") || {};
    } catch {
      return json(400, { error: "Invalid message request." });
    }
    const { driverId, requestId, phone } = payload;
    const message = typeof payload.message === "string" ? payload.message.trim() : "";
    if (!/^[\w-]{1,128}$/.test(driverId || "") || !/^[a-f0-9]{32}$/.test(requestId || "") || !message || message.length > 480) {
      return json(400, { error: "Select a driver and enter a message of 1\u2013480 characters." });
    }
    const path = `${collection}/${requestId}`;
    const previous = await read(path, admin);
    if (previous) return json(200, { record: previous });
    const driver = await read(`users/${encodeURIComponent(driverId)}`, admin);
    const savedPhone = String(driver?.phoneNumber ?? "").trim();
    const to = normalizePhone(phone);
    if (!driver || driver.isActive === false || driver.role !== "driver") {
      return json(400, { error: "Select an active driver." });
    }
    if (!to) return json(400, { error: "Enter a valid Ghana phone number." });
    if (savedPhone && to !== normalizePhone(savedPhone)) {
      return json(409, { error: "The driver\u2019s number changed. Refresh the driver list before sending." });
    }
    const record = {
      requestId,
      senderId: uid,
      senderName: String(profile.fullName || uid),
      driverId,
      driverName: String(driver.fullName || "Driver"),
      phone: to,
      message,
      createdAt: (/* @__PURE__ */ new Date()).toISOString(),
      status: "pending",
      detail: "",
      providerId: ""
    };
    const created = await fetchBounded(`${root}/${collection}?documentId=${requestId}`, {
      method: "POST",
      headers: { ...auth(admin), "content-type": "application/json" },
      body: document(record)
    });
    if (created.status === 409) return json(200, { record: await read(path, admin) });
    if (!created.ok) throw new Error("Could not create history record");
    const dryRun = process.env.BAJ_SMS_MODE !== "live";
    const apiKey = process.env.BAJ_ARKESEL_API_KEY?.trim();
    const sender = process.env.BAJ_ARKESEL_SENDER_ID?.trim();
    if (dryRun) {
      record.status = "preview";
      record.detail = "Recorded in preview mode. No SMS was sent.";
    } else if (!apiKey || !/^[A-Za-z0-9]{1,11}$/.test(sender || "")) {
      record.status = "failed";
      record.detail = "BAJ SMS credentials or Sender ID are not configured.";
    } else {
      try {
        const response = await fetchBounded("https://sms.arkesel.com/api/v2/sms/send", {
          method: "POST",
          headers: { "api-key": apiKey, "content-type": "application/json", accept: "application/json" },
          body: JSON.stringify({ sender, message, recipients: [to], sandbox: false })
        });
        const result = await response.json().catch(() => null);
        const accepted = Array.isArray(result?.data) && result.data.find(
          (item) => normalizePhone(item?.recipient) === to && item?.id
        );
        if (response.ok && result?.status === "success" && accepted) {
          record.status = "accepted";
          record.providerId = String(accepted.id);
          record.detail = "Arkesel accepted the SMS for delivery.";
        } else if (response.status >= 500 || response.ok && result?.status !== "error") {
          record.status = "unknown";
          record.detail = "Arkesel did not confirm the result. Check the provider before resending.";
        } else {
          record.status = "failed";
          record.detail = `Arkesel rejected the SMS (HTTP ${response.status}).`;
        }
      } catch {
        record.status = "unknown";
        record.detail = "No confirmation from Arkesel. Check the provider before resending.";
      }
    }
    stage = "saving the provider result";
    const updated = await fetchBounded(`${root}/${path}`, {
      method: "PATCH",
      headers: { ...auth(admin), "content-type": "application/json" },
      body: document(record)
    });
    if (!updated.ok) throw new Error("Could not save the provider result");
    return json(200, { record });
  } catch {
    console.error("BAJ SMS request failed during %s", stage);
    return json(503, { error: `SMS service failed during ${stage}. Check history before sending again.` });
  }
}
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  handler,
  normalizePhone
});
//# sourceMappingURL=driver-sms.js.map
