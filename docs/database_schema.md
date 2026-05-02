# E-POD MVP Database Schema

This schema defines the first Firebase/Firestore database structure for the BAJ E-POD app.

## Storage Rule

Firestore stores shared waybill data and signature URLs only.

Hive stores local/offline data and temporary signature bytes only.

Do not store these fields in Firestore:

```text
receiverSignatureBytes
driverSignatureBytes
```

These byte fields are only for offline sync in Hive.

## Main Relationship

Every waybill must be linked to a BAJ Number.

One BAJ Number can have many waybills.

Example:

```text
BAJ-2026-001
  - WB-1001
  - WB-1002
  - WB-1003
```

## Firestore Collections

For the MVP, use one main collection:

```text
waybills
```

Recommended document ID:

```text
waybillNumber
```

Example path:

```text
waybills/WB-1001
```

## Waybill Document Fields

```json
{
  "bajNumber": "BAJ-2026-001",
  "waybillNumber": "WB-1001",
  "date": "2026-05-02",
  "poNumber": "PO-2345",

  "shippingVendor": "Vendor A",
  "consigneeReceiver": "Receiver A",
  "deliveryAddress": "Tema, Ghana",

  "cargoDescription": "Spare parts",
  "grossWeight": "1500kg",
  "comments": "Handle with care",

  "hazardousCargoType": "",
  "unNumber": "",
  "tremcard": "",

  "vehicleNumber": "GT-1234-20",
  "driverName": "John Driver",

  "receiverName": "Client Rep",

  "status": "Pending Delivery",
  "syncStatus": "Synced",

  "isOk": false,
  "isShort": false,
  "isOver": false,
  "isDamaged": false,
  "isParkingUnsuitable": false,
  "isPartOrder": false,
  "isCompleteOrder": false,

  "receiverSignatureUrl": "",
  "driverSignatureUrl": "",

  "createdAt": "2026-05-02T10:00:00",
  "updatedAt": "2026-05-02T10:00:00",
  "deliveredAt": "",
  "invoicedAt": ""
}
```

## Required Fields

```text
bajNumber
waybillNumber
date
poNumber
shippingVendor
consigneeReceiver
deliveryAddress
cargoDescription
grossWeight
vehicleNumber
driverName
status
syncStatus
createdAt
updatedAt
```

## Status Values

```text
Pending Delivery
Pending Sync
Delivered
Invoiced
Cancelled
```

Meaning:

```text
Pending Delivery = created but not yet delivered
Pending Sync = delivered offline, waiting for signature URL upload
Delivered = delivery complete and signature URLs are available
Invoiced = accounts has processed the delivered waybill
Cancelled = waybill is no longer active
```

## Sync Status Values

```text
Synced
Pending
Failed
```

Meaning:

```text
Synced = local and online records are up to date
Pending = local delivery/signatures are waiting to sync
Failed = last sync attempt failed and should be retried
```

## Offline Delivery Flow

When internet is unavailable:

```text
1. Driver captures receiver signature.
2. Driver captures driver signature.
3. App saves delivery details to Hive.
4. App saves receiverSignatureBytes and driverSignatureBytes to Hive.
5. App sets status to Pending Sync.
6. App sets syncStatus to Pending.
7. Firebase is not updated until sync succeeds.
```

When internet returns:

```text
1. App uploads receiver signature image.
2. App uploads driver signature image.
3. App receives receiverSignatureUrl and driverSignatureUrl.
4. App updates Firestore waybill document.
5. App sets status to Delivered.
6. App sets syncStatus to Synced.
```

## Accounts Rule

Accounts should invoice only when:

```text
status = Delivered
syncStatus = Synced
```

Accounts should not invoice when:

```text
status = Pending Sync
syncStatus = Pending
```

## Fields Kept Out For Now

These fields are intentionally excluded from the MVP schema:

```text
driverPhone
receiverPhone
assignedDriverId
createdByUserId
syncError
lastSyncAttemptAt
receiverSignatureBytes
driverSignatureBytes
```
