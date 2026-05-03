# Firebase User Setup

The app now uses Firebase Authentication for login and the Firestore `users` collection for role-based dashboard access.

## 1. Enable Email/Password Login

In Firebase Console:

```text
Build > Authentication > Sign-in method > Email/Password > Enable
```

## 2. Create Auth Users

In Firebase Console:

```text
Build > Authentication > Users > Add user
```

Create each user with:

```text
email
password
```

## 3. Create Matching Firestore User Profile

After creating the Auth user, copy the user's UID.

Create a Firestore document at:

```text
users/{uid}
```

Example Officer user:

```json
{
  "userId": "paste-auth-uid-here",
  "fullName": "Officer Name",
  "email": "officer@example.com",
  "role": "Officer",
  "isActive": true,
  "createdAt": "2026-05-02T10:00:00",
  "updatedAt": "2026-05-02T10:00:00"
}
```

Example Driver user:

```json
{
  "userId": "paste-auth-uid-here",
  "fullName": "Driver Name",
  "email": "driver@example.com",
  "role": "Driver",
  "isActive": true,
  "createdAt": "2026-05-02T10:00:00",
  "updatedAt": "2026-05-02T10:00:00"
}
```

Example Accounts user:

```json
{
  "userId": "paste-auth-uid-here",
  "fullName": "Accounts Name",
  "email": "accounts@example.com",
  "role": "Accounts",
  "isActive": true,
  "createdAt": "2026-05-02T10:00:00",
  "updatedAt": "2026-05-02T10:00:00"
}
```

## Supported Roles

```text
Officer
Officer In Charge
Driver
Accounts
```

The login screen routes users based on their `role` value.

## Login Requirements

A user can log in only when:

```text
1. The email/password exists in Firebase Authentication.
2. A matching users/{uid} Firestore document exists.
3. isActive is true.
```
