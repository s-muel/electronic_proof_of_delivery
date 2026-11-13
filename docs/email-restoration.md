# Restore email sending after version 1.0.2

Email sending is disabled at the service boundary in version 1.0.2, build 3. Delivery submission skips the email service. PDF generation and WhatsApp sharing remain available.

Before restoring email:

1. Choose an approved sender and mail service. Prefer a backend that holds credentials rather than copying SMTP passwords onto app devices.
2. Require direct TLS or STARTTLS with no plaintext fallback, and validate hostname and certificate chain. The installed mailer already defaults to allowInsecure=false; ignoreBadCertificate=true was the bypass found in the app.
3. Verify the SMTP connection using the app's Dart runtime and Android device trust store. The Windows check of mail.bajfreight.com:465 returned PartialChain; this needs diagnosis before using that server with strict validation.
4. Send only a sample document to an explicitly approved test recipient, then verify PDF content, success handling, and offline/error handling.
5. Restore email UI and descriptions only with a verified release; update the privacy policy and Google Play declarations to match the versions being distributed.

This file records the follow-up work for a future release.
