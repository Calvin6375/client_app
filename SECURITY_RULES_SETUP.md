# Firebase Security Rules Setup Guide

## Problem

You're seeing this error:
```
[firebase_database/permission-denied] Client doesn't have permission to access the desired data.
```

This is because Firebase Realtime Database security rules are blocking reads. The default rules deny all access.

## Solution

I've created `database.rules.json` with proper security rules. You need to deploy these rules to Firebase.

## Quick Fix

### Option 1: Deploy via Firebase Console (Recommended for Quick Testing)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **TruePay (truepay-72060)**
3. Navigate to **Realtime Database** → **Rules** tab
4. Copy and paste the rules from `database.rules.json`
5. Click **Publish**

### Option 2: Deploy via Firebase CLI

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Deploy database rules
firebase deploy --only database
```

## Security Rules Explained

The rules I've created:

### ✅ **Allowed (Read-Only for Clients)**
- Authenticated users can **read** their own wallet balance: `wallet/{uid}/balance`
- Authenticated users can **read** their own payments: `payments/{paymentId}` (if `user_id` matches)
- Authenticated users can **read** their payment references: `users/{uid}/payments/{paymentId}`

### ❌ **Blocked (Client Writes)**
- **NO** client writes to `/payments` nodes
- **NO** client writes to `/wallet` nodes
- **NO** client writes to `/users/{uid}/payments` nodes

### ✅ **Allowed (Server-Side Only)**
- Cloud Functions can write to all nodes (they use Admin SDK which bypasses rules)

## Rules Structure

```json
{
  "rules": {
    "payments": {
      "$paymentId": {
        ".read": "auth != null && data.child('user_id').val() == auth.uid",
        ".write": false  // Only Cloud Functions can write
      }
    },
    "wallet": {
      "$userId": {
        ".read": "auth != null && auth.uid == $userId",
        "balance": {
          ".read": "auth != null && auth.uid == $userId",
          ".write": false  // Only Cloud Functions can write
        },
        ".write": false
      }
    },
    "users": {
      "$userId": {
        ".read": "auth != null && auth.uid == $userId",
        "payments": {
          "$paymentId": {
            ".read": "auth != null && auth.uid == $userId",
            ".write": false  // Only Cloud Functions can write
          }
        },
        ".write": false
      }
    }
  }
}
```

## Testing

After deploying the rules:

1. **Test Read Access:**
   - Login to the app
   - Navigate to wallet screen
   - You should see wallet balance (if data exists)

2. **Test Write Protection:**
   - Try to write to wallet from client code
   - Should be blocked (this is correct behavior)

3. **Verify Cloud Functions:**
   - Cloud Functions use Admin SDK
   - They bypass security rules
   - They can write to all nodes

## Important Notes

1. **Authentication Required**: All reads require authentication (`auth != null`)
2. **User Isolation**: Users can only read their own data (`auth.uid == $userId`)
3. **No Client Writes**: All `.write` rules are set to `false` for client code
4. **Cloud Functions**: Use Admin SDK, so they bypass these rules

## Troubleshooting

### Still Getting Permission Denied?

1. **Check Authentication:**
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   print('User ID: ${user?.uid}');
   ```
   Make sure user is authenticated.

2. **Check Rules Deployment:**
   - Go to Firebase Console → Realtime Database → Rules
   - Verify rules are published
   - Check for syntax errors

3. **Check Database Path:**
   - Wallet: `wallet/{uid}/balance`
   - Payments: `payments/{paymentId}` where `user_id == auth.uid`

4. **Test Rules in Console:**
   - Firebase Console → Realtime Database → Rules
   - Use "Rules Playground" to test rules

## Next Steps

After deploying rules:
1. ✅ Restart your app
2. ✅ Login as a user
3. ✅ Check wallet balance loads
4. ✅ Verify payments can be read

---

**File Created**: `database.rules.json`
**Deploy Command**: `firebase deploy --only database`
**Console URL**: https://console.firebase.google.com/project/truepay-72060/database/truepay-72060-default-rtdb/rules

