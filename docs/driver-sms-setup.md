# BAJ driver assignment SMS

Open **Manager Desk → SMS**. Type a driver name or phone to see matches.
Add drivers one at a time or choose **Select all drivers**, then review the
shared message and all recipients. Enter any missing numbers or remove those
recipients before sending.
Saved phone numbers fill in automatically. If a driver has no linked number,
enter a Ghana phone number for this message. This does not change the profile.
Each recipient gets a separate history entry.
Super users can enter a phone when creating a driver or use **Edit driver
phone** on an existing driver. The app updates the same driver index used for
waybill assignment. The server checks the current profile and rejects a send
if the number has changed since the manager reviewed it.

Configure the BAJ Netlify site's Functions environment:

- `BAJ_SMS_FIREBASE_WEB_API_KEY`: the web API key for `bajfreight-system`.
- `BAJ_SMS_SERVICE_ACCOUNT_JSON`: server-only service account for that project
  with the Firestore permissions required to read drivers and write history.
- `BAJ_ARKESEL_API_KEY` and `BAJ_ARKESEL_SENDER_ID`: BAJ's own Arkesel
  credentials and approved sender ID. Do not use Greenline's values.
- `BAJ_SMS_MODE`: leave unset for preview mode, which records attempts without
  calling Arkesel. Set to `live` only when ready to send.

The web app uses the same Netlify site by default. For native builds, pass
`--dart-define=SMS_FUNCTION_BASE_URL=https://YOUR-BAJ-SITE`.
The URL is public configuration; the API and service-account keys stay on Netlify.

History is scoped to the signed-in manager and stored in
`users/{managerUid}/driverSmsHistory/{requestId}`. Check the deployed Firestore
rules before enabling live mode: clients should have no direct access to this
subcollection. The function writes history through its service account and
authorizes reads using the manager's Firebase session. An accepted SMS was
accepted by Arkesel; it is not proof that the handset received it. If an
attempt is pending or unconfirmed, check history and Arkesel before resending.
