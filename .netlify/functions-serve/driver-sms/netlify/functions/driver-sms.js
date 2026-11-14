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
  acceptedProviderId: () => acceptedProviderId,
  handler: () => handler,
  normalizePhone: () => normalizePhone
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
function normalizePhone(value) {
  if (!/^[+\d\s().-]+$/.test(String(value || ""))) return "";
  let digits = String(value).replace(/\D/g, "").replace(/^00/, "");
  if (/^0\d{9}$/.test(digits)) digits = "233" + digits.slice(1);
  else if (/^\d{9}$/.test(digits)) digits = "233" + digits;
  return /^233\d{9}$/.test(digits) ? digits : "";
}
function acceptedProviderId(data, phone) {
  const item = Array.isArray(data) ? data.find((entry) => normalizePhone(entry?.recipient) === phone) : data;
  if (item?.recipient != null && normalizePhone(item.recipient) !== phone) return "";
  return typeof item?.id === "string" ? item.id.trim() : "";
}
async function deliveryReports(records, apiKey) {
  const eligible = (record) => record.status === "accepted" && Boolean(record.providerId);
  const ids = [...new Set(records.filter(eligible).map((record) => record.providerId))];
  if (!ids.length) return records;
  const unavailable = (record, reason) => ({
    ...record,
    detail: `Accepted by Arkesel. Delivery status unavailable: ${reason}.`
  });
  const unavailableForAll = (reason) => records.map((record) => eligible(record) ? unavailable(record, reason) : record);
  if (!apiKey) return unavailableForAll("BAJ Arkesel API key is not configured");
  let reports;
  try {
    const response = await fetchBounded(
      "https://sms.arkesel.com/api/v2/sms/message-reports",
      {
        method: "POST",
        headers: { "api-key": apiKey, "content-type": "application/json", accept: "application/json" },
        body: JSON.stringify({ msg_ids: ids })
      }
    );
    if (!response.ok) return unavailableForAll(`Arkesel report request returned HTTP ${response.status}`);
    const report = await response.json();
    if (report?.status !== "success" || !report.data || typeof report.data !== "object") {
      return unavailableForAll("Arkesel did not return a usable report");
    }
    reports = report.data;
  } catch {
    return unavailableForAll("could not read the Arkesel delivery report");
  }
  return records.map((record) => {
    if (!eligible(record)) return record;
    const data = Object.hasOwn(reports, record.providerId) ? reports[record.providerId] : null;
    if (!data || data.status === "error") {
      return unavailable(record, "Arkesel returned no report for this message ID");
    }
    if (normalizePhone(data.recipient) !== record.phone) {
      return unavailable(record, "the report did not match this recipient");
    }
    switch (data.status) {
      case "DELIVERED":
        return { ...record, status: "delivered", detail: "Arkesel confirmed delivery to the phone." };
      case "NOT_DELIVERED":
      case "PROHIBITED":
      case "EXPIRED":
        return { ...record, status: "not_delivered", detail: `Arkesel delivery report: ${data.status}.` };
      case "SUBMITTED":
      case "QUEUED":
        return { ...record, detail: `Arkesel: ${data.status}. Delivery is not confirmed yet.` };
      default:
        return unavailable(record, "Arkesel returned an unrecognized delivery status");
    }
  });
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
      const key2 = process.env.BAJ_ARKESEL_API_KEY?.trim();
      const records = await deliveryReports((page.documents || []).map(fields), key2);
      return json(200, { records, cursor: page.nextPageToken });
    }
    const { driverId, requestId, phone } = payload;
    const officeSms = !testSms && payload.recipientType === "office";
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
        }, 12e3);
        const result = await response.json().catch((error) => {
          if (error instanceof SyntaxError) return null;
          throw error;
        });
        const accepted = acceptedProviderId(result?.data, to);
        if (response.ok && result?.status === "success" && accepted) {
          record.status = "accepted";
          record.providerId = accepted;
          record.detail = "Arkesel accepted the SMS for delivery.";
        } else if (response.status >= 500 || response.ok && result?.status !== "error") {
          record.status = "unknown";
          record.detail = "Arkesel did not confirm the result. Check the provider before resending.";
        } else {
          record.status = "failed";
          record.detail = `Arkesel rejected the SMS (HTTP ${response.status}).`;
        }
      } catch (error) {
        record.status = "unknown";
        const timedOut = ["TimeoutError", "AbortError"].includes(error?.name);
        record.detail = timedOut ? "Arkesel did not respond in time. The SMS may have arrived; check before resending." : "Could not read the Arkesel response. The SMS may have arrived; check before resending.";
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
  acceptedProviderId,
  handler,
  normalizePhone
});
//# sourceMappingURL=driver-sms.js.map
