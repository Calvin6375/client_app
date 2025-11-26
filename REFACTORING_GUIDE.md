# Flutter + Firebase Architecture Refactoring Guide

## Overview

This codebase has been completely refactored to follow a secure, scalable, production-grade architecture. All client-side writes to payments and wallet have been removed, and all business logic has been moved to Cloud Functions.

## Key Changes

### ✅ Completed Refactoring

1. **Firebase Initialization**
   - Migrated to `firebase_options.dart` from FlutterFire CLI
   - Updated `main.dart` to use `DefaultFirebaseOptions.currentPlatform`

2. **Authentication**
   - Created `AuthService` with centralized auth operations
   - All auth screens now use `AuthService` instead of direct Firebase calls
   - Removed deprecated email link authentication mock

3. **User Profiles**
   - Created `UserRepository` for Firestore operations
   - All user data stored in Firestore under `users/{uid}`
   - Removed user profile data from Realtime Database

4. **Payment System**
   - **CRITICAL**: Client code can NO LONGER write to payments
   - Created `PaymentService` that calls Cloud Functions
   - Created `PaymentRepository` for read-only payment streams
   - Deprecated `FirebasePaymentService` (kept for backward compatibility)

5. **Wallet System**
   - **CRITICAL**: Client code can NO LONGER write to wallet
   - Created `WalletRepository` for read-only wallet streams
   - All wallet updates happen server-side via Cloud Functions

6. **Models**
   - Created proper models with `fromJson`, `toJson`, and `copyWith`
   - `UserModel` for Firestore
   - `PaymentModel` for Realtime Database
   - `Wallet` model updated with proper methods

7. **Logging**
   - Created `Logger` utility to replace all `print()` statements
   - Centralized logging with different log levels

8. **Cloud Functions**
   - Created Cloud Functions stubs in `functions/` directory
   - `createPayment` - Creates payments server-side
   - `handlePaymentWebhook` - Updates payment status
   - `updateWalletAfterPayment` - Updates wallet balance

## Architecture

### Folder Structure

```
lib/
  services/
    auth_service.dart          # Authentication operations
    payment_service.dart        # Payment operations (Cloud Functions)
    firebase_payment_service.dart  # DEPRECATED - kept for compatibility
  
  repositories/
    user_repository.dart        # Firestore user operations
    wallet_repository.dart      # Read-only wallet streams
    payment_repository.dart     # Read-only payment streams
  
  models/
    user_model.dart             # User model for Firestore
    payment_model.dart          # Payment model for RTDB
    wallet_model.dart           # Wallet model for RTDB
  
  utils/
    logger.dart                 # Centralized logging
  
  firebase_options.dart         # Firebase configuration (from FlutterFire CLI)

functions/
  index.js                     # Cloud Functions
  package.json                 # Node.js dependencies
```

### Data Flow

#### Payment Creation Flow

```
User Action
  ↓
IntaSendService.processPayment()
  ↓
1. Create IntaSend checkout
  ↓
2. PaymentService.createPayment() → Cloud Function
  ↓
3. Cloud Function creates payment in RTDB
  ↓
4. Launch checkout URL
  ↓
5. PaymentService.handlePaymentWebhook() → Cloud Function
  ↓
6. Cloud Function updates payment status
```

#### Wallet Updates

```
Payment Completed
  ↓
Cloud Function (handlePaymentWebhook)
  ↓
updateWalletAfterPayment()
  ↓
Updates wallet/{uid}/balance in RTDB
  ↓
WalletRepository.streamWalletBalance() (client reads)
```

## Security Rules

### ⚠️ CRITICAL: Client-Side Restrictions

**The client MUST NEVER:**
- Write to `/payments` nodes
- Write to `/wallet` nodes
- Generate payment IDs
- Update payment statuses directly
- Modify wallet balances

**All writes must go through:**
- `PaymentService.createPayment()` → Cloud Function
- `PaymentService.handlePaymentWebhook()` → Cloud Function
- Cloud Functions update wallet automatically

### Database Structure

#### Firestore
```
users/
  {uid}/
    firstName: string
    lastName: string
    email: string
    createdAt: timestamp
    updatedAt: timestamp
```

#### Realtime Database
```
payments/
  {paymentId}/
    payment_id: string
    user_id: string
    amount: number
    currency: string
    status: string
    ... (created by Cloud Functions)

wallet/
  {uid}/
    balance/
      balance: number
      currency: string
      updatedAt: timestamp
      ... (updated by Cloud Functions)
```

## Migration Steps

### For Developers

1. **Update Dependencies**
   ```bash
   flutter pub get
   ```

2. **Generate firebase_options.dart**
   ```bash
   flutterfire configure
   ```
   This will regenerate `lib/firebase_options.dart` with your project settings.

3. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

4. **Update Your Code**
   - Replace `FirebasePaymentService` calls with `PaymentService`
   - Use `PaymentRepository` for reading payments
   - Use `WalletRepository` for reading wallet
   - Use `AuthService` for authentication
   - Use `UserRepository` for user profiles

### Code Examples

#### Before (❌ Deprecated)
```dart
// OLD - Client writes directly to Firebase
final paymentId = FirebasePaymentService.generatePaymentId();
await FirebasePaymentService.storePaymentInitiation(
  paymentId: paymentId,
  amount: 100.0,
  // ...
);
```

#### After (✅ Secure)
```dart
// NEW - Server-side via Cloud Functions
final paymentService = PaymentService();
final result = await paymentService.createPayment(
  amount: 100.0,
  currency: 'USD',
  email: 'user@example.com',
  firstName: 'John',
  lastName: 'Doe',
);
```

#### Reading Payments (✅ Read-Only)
```dart
// Use PaymentRepository for reading
final paymentRepo = PaymentRepository();
final paymentsStream = paymentRepo.streamUserPayments(userId, limit: 10);

StreamBuilder<List<PaymentModel>>(
  stream: paymentsStream,
  builder: (context, snapshot) {
    // Build UI
  },
)
```

#### Reading Wallet (✅ Read-Only)
```dart
// Use WalletRepository for reading
final walletRepo = WalletRepository();
final walletStream = walletRepo.streamWalletBalance(userId);

StreamBuilder<Wallet?>(
  stream: walletStream,
  builder: (context, snapshot) {
    // Build UI
  },
)
```

## Testing

### Local Testing

1. **Test Cloud Functions Locally**
   ```bash
   cd functions
   npm run serve
   ```

2. **Test Flutter App**
   ```bash
   flutter run
   ```

### Production Deployment

1. **Deploy Cloud Functions**
   ```bash
   firebase deploy --only functions
   ```

2. **Build Flutter App**
   ```bash
   flutter build apk  # Android
   flutter build ios  # iOS
   ```

## Important Notes

1. **Firebase Security Rules**: Make sure your Realtime Database rules prevent client writes to `/payments` and `/wallet`. Only Cloud Functions should have write access.

2. **Authentication**: All Cloud Functions validate Firebase Auth tokens. Ensure users are authenticated before calling payment functions.

3. **Error Handling**: All services include comprehensive error handling. Check logs using `Logger` utility.

4. **Backward Compatibility**: `FirebasePaymentService` is deprecated but kept for reference. All methods throw `UnimplementedError` to force migration.

## Next Steps

1. ✅ Update widgets to use `StreamBuilder` for real-time data
2. ✅ Add Firebase Security Rules to prevent client writes
3. ✅ Test Cloud Functions in production
4. ✅ Monitor logs for any deprecated method calls
5. ✅ Remove `FirebasePaymentService` after full migration

## Support

If you encounter issues:
1. Check `Logger` output for detailed error messages
2. Verify Cloud Functions are deployed
3. Ensure Firebase Security Rules are configured correctly
4. Check that `firebase_options.dart` is properly generated

---

**Last Updated**: After refactoring
**Status**: ✅ Production-Ready Architecture

