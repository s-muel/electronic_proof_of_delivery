# Review before publishing the BAJ E-POD privacy policy

This draft is based on the repository’s current Android app, not an audit of production infrastructure or organizational practices.

Confirmed by the user: delivery records are retained for 3 years, and deletion requests are handled through essumantechnologies@gmail.com. This policy update does not implement automatic deletion in the app or cloud services.

Operational review:

1. The exact legal name of the organization operating the service and whether Essuman Technologies acts as publisher, processor, or controller.
2. Implement and verify the 3-year delivery-record retention policy, including associated images and backups. Confirm account-specific retention separately.
3. Ensure the confirmed support mailbox has a request-handling process covering Firebase Authentication, Firestore, Cloudinary, and retained backups. Account disabling and soft-deleting a waybill are not permanent deletion.
4. Who receives copies of signed PDFs through configured email settings and whether existing business notices cover recipient data and signature capture.
5. Whether the business sells data, uses it for advertising, or performs additional processing outside this repository. The draft makes no unsupported promise that data is never sold.
6. The actual audience, processing locations, access rules, and security configuration.

Implementation findings relevant to accurate publication:

- Account creation stores a temporary password in a user profile (`tempPass`). Do not claim credentials are never stored or visible to administrators; review this implementation before broader distribution.
- Cloudinary image links are stored in records and can be shared. Do not claim every image is accessible only after signing in without checking the Cloudinary delivery settings.
- SMTP settings can allow unencrypted or certificate-unverified connections. Do not claim all app traffic is encrypted without checking and correcting those settings.
- Google Play requires a public, accessible HTML privacy-policy URL and a privacy-policy link or text within the app. Neither hosting nor an in-app link is added by this draft.
- Review Google Play’s account-deletion requirements against the administrator account-creation workflow. An email request in a policy is not automatically sufficient for every app.

References:
- https://support.google.com/googleplay/android-developer/answer/10144311
- https://support.google.com/googleplay/android-developer/answer/13327111
