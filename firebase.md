# Firebase Implementation Documentation

## Overview

This document provides a comprehensive guide to all Firebase features implemented in the TruePay (Pretium) application. The app uses Firebase for authentication, user data storage, payment tracking, and wallet balance management.

## Table of Contents

1. [Firebase Project Configuration](#firebase-project-configuration)
2. [Firebase Initialization](#firebase-initialization)
3. [Firebase Services Used](#firebase-services-used)
4. [Firebase Authentication](#firebase-authentication)
5. [Firebase Realtime Database](#firebase-realtime-database)
6. [Cloud Firestore](#cloud-firestore)
7. [Database Structure](#database-structure)
8. [Implementation Details](#implementation-details)
9. [Configuration Files](#configuration-files)
10. [Error Handling](#error-handling)

---

## Firebase Project Configuration

### Project Information

- **Project Name**: TruePay
- **Project ID**: `truepay-72060`
- **Project Number**: `241917597382`
- **Database URL**: `https://truepay-72060-default-rtdb.firebaseio.com/`
- **Storage Bucket**: `truepay-72060.firebasestorage.app`

### Firebase Services Enabled

- ✅ Firebase Authentication
- ✅ Firebase Realtime Database
- ✅ Cloud Firestore
- ✅ Firebase Storage (configured but not actively used)
- ✅ Firebase Cloud Messaging (GCM) - Enabled
- ✅ App Invite Service - Enabled
- ❌ Firebase Analytics - Disabled
- ❌ Firebase Ads - Disabled

---

## Firebase Initialization

### Location
`lib/main.dart`

### Implementation

Firebase is initialized in the `main()` function before the app starts:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Provides helpful setup instructions if initialization fails
  }
  
  runApp(const MyApp());
}
```

### Error Handling

The initialization includes comprehensive error handling that:
- Catches Firebase initialization errors
- Provides debug instructions for setup
- Allows the app to continue running (with limited functionality) if Firebase fails to initialize
- Displays helpful messages about downloading configuration files

---

## Firebase Services Used

### Dependencies (from `pubspec.yaml`)

```yaml
firebase_core: ^3.0.0        # Core Firebase SDK
cloud_firestore: ^5.0.0      # Cloud Firestore (NoSQL document database)
firebase_auth: ^5.0.0        # Firebase Authentication
firebase_database: ^11.0.4   # Firebase Realtime Database
```

### Service Usage Summary

| Service | Purpose | Primary Use Cases |
|---------|---------|-------------------|
| **Firebase Auth** | User authentication | Login, Registration, User session management |
| **Realtime Database** | Real-time data sync | Payment tracking, Wallet balances, Payment history |
| **Cloud Firestore** | Document storage | User profiles, User metadata |

---

## Firebase Authentication

### Implementation Location
- Login: `lib/features/auth/screens/login_page.dart`
- Registration: `lib/features/auth/screens/register_page.dart`

### Authentication Methods

#### 1. Email/Password Authentication

**Login Flow:**
```dart
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);
```

**Registration Flow:**
```dart
// Step 1: Create user in Firebase Auth
final credential = await FirebaseAuth.instance
    .createUserWithEmailAndPassword(email: email, password: password);

// Step 2: Create user profile in Firestore
final uid = credential.user!.uid;
await FirebaseFirestore.instance.collection('users').doc(uid).set({
  'firstName': firstName,
  'lastName': lastName,
  'email': email,
  'createdAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

#### 2. Email Link Authentication (Placeholder)

The app includes a UI for email link authentication, but it's currently implemented as a demo/mock:
- Email link sending is simulated
- No actual email links are sent
- Placeholder for future implementation

### Authentication Features

1. **User Registration**
   - Email validation
   - Password strength checking
   - Terms and conditions acceptance
   - Automatic user profile creation in Firestore
   - Error handling for duplicate emails, weak passwords, etc.

2. **User Login**
   - Email/password validation
   - Remember me functionality (UI only, not persisted)
   - Firebase initialization check before login
   - Comprehensive error handling with user-friendly messages

3. **Error Handling**

   The app handles various Firebase Auth exceptions:
   - `user-not-found`: No user found for that email
   - `wrong-password`: Incorrect password
   - `invalid-email`: Invalid email format
   - `email-already-in-use`: Email already registered
   - `weak-password`: Password doesn't meet requirements

4. **Session Management**
   - Current user access via `FirebaseAuth.instance.currentUser`
   - User ID retrieval: `FirebaseAuth.instance.currentUser!.uid`
   - User email access: `FirebaseAuth.instance.currentUser!.email`

### Authentication State

The app checks for authenticated users throughout the codebase:
```dart
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  // User is authenticated
  final userId = user.uid;
  final userEmail = user.email;
}
```

---

## Firebase Realtime Database

### Implementation Location
- Service: `lib/services/firebase_payment_service.dart`
- Wallet Balance: `lib/features/topup/services/intasend_service.dart`
- Constants: `lib/core/constants/app_strings.dart`

### Database Configuration

**Database URL**: `https://truepay-72060-default-rtdb.firebaseio.com/`

The database is initialized with a custom URL:
```dart
static const String _databaseUrl = 'https://truepay-72060-default-rtdb.firebaseio.com/';

static FirebaseDatabase get database {
  _database ??= FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _databaseUrl,
  );
  return _database!;
}
```

### Database Structure

```
truepay-72060-default-rtdb/
├── payments/
│   └── {paymentId}/
│       ├── payment_id
│       ├── intasend_checkout_id
│       ├── user_id
│       ├── user_email
│       ├── amount
│       ├── currency
│       ├── customer_info/
│       │   ├── email
│       │   ├── first_name
│       │   └── last_name
│       ├── checkout_url
│       ├── status (initiated | link_opened | completed | failed)
│       ├── created_at
│       ├── updated_at
│       ├── payment_method
│       ├── platform
│       └── [additional_data]
│
├── users/
│   └── {userId}/
│       └── payments/
│           └── {paymentId}/
│               ├── payment_id
│               ├── amount
│               ├── currency
│               ├── status
│               └── created_at
│
└── wallet/
    └── balance/
        └── {userId}/
            ├── amount
│           ├── currency
│           └── [wallet_data]
```

### Payment Service Implementation

The `FirebasePaymentService` class provides comprehensive payment management:

#### 1. Payment ID Generation
```dart
static String generatePaymentId() {
  return 'payment_${DateTime.now().millisecondsSinceEpoch}_${(DateTime.now().microsecond % 1000).toString().padLeft(3, '0')}';
}
```

#### 2. Store Payment Initiation
Stores payment data when a checkout link is created:
- Creates entry in `/payments/{paymentId}`
- Creates entry in `/users/{userId}/payments/{paymentId}` (if authenticated)
- Tracks payment status, amount, currency, customer info, checkout URL

#### 3. Update Payment Status
Methods for tracking payment lifecycle:
- `markPaymentLinkOpened()`: When user opens checkout link
- `markPaymentCompleted()`: When payment is verified/completed
- `markPaymentFailed()`: When payment fails

#### 4. Retrieve Payment Data
- `getPaymentById()`: Get specific payment details
- `getUserPayments()`: Get user's payment history (with optional limit)

### Wallet Balance Management

**Location**: `lib/features/topup/services/intasend_service.dart`

```dart
Future<Wallet> fetchWalletBalance(String userId) async {
  final authUserId = FirebaseAuth.instance.currentUser!.uid;
  final balanceRef = FirebaseDatabase.instance.ref().child('wallet/balance/$authUserId');
  final snapshot = await balanceRef.get();
  
  if (snapshot.exists && snapshot.value != null) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return Wallet.fromJson(data);
  }
  throw Exception('No wallet balance found');
}
```

### Payment Flow Integration

The payment service integrates with IntaSend payment processing:

1. **Payment Initiation**
   - Generate unique payment ID
   - Create IntaSend checkout session
   - Store payment data in Firebase Realtime Database
   - Launch checkout URL

2. **Status Tracking**
   - `initiated` → Payment created
   - `link_opened` → User opened checkout link
   - `completed` → Payment verified
   - `failed` → Payment failed

3. **Data Synchronization**
   - Payment data stored in both global `/payments` and user-specific `/users/{userId}/payments`
   - Ensures data consistency and easy querying

---

## Cloud Firestore

### Implementation Location
`lib/features/auth/screens/register_page.dart`

### Usage

Cloud Firestore is used to store user profile information:

```dart
await FirebaseFirestore.instance.collection('users').doc(uid).set({
  'firstName': firstName,
  'lastName': lastName,
  'email': email,
  'createdAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

### Firestore Structure

```
users/
└── {userId}/
    ├── firstName: string
    ├── lastName: string
    ├── email: string
    └── createdAt: timestamp
```

### Features

- **User Profile Storage**: Stores user registration information
- **Server Timestamps**: Uses `FieldValue.serverTimestamp()` for accurate creation dates
- **Merge Strategy**: Uses `SetOptions(merge: true)` to prevent overwriting existing data

---

## Database Structure

### Complete Schema

#### Realtime Database

```
{
  "payments": {
    "{paymentId}": {
      "payment_id": "string",
      "intasend_checkout_id": "string",
      "user_id": "string",
      "user_email": "string",
      "amount": "number",
      "currency": "string",
      "customer_info": {
        "email": "string",
        "first_name": "string",
        "last_name": "string"
      },
      "checkout_url": "string",
      "status": "initiated | link_opened | completed | failed",
      "created_at": "ISO8601 timestamp",
      "updated_at": "ISO8601 timestamp",
      "payment_method": "intasend",
      "platform": "mobile_app",
      "link_opened_at": "ISO8601 timestamp (optional)",
      "completed_at": "ISO8601 timestamp (optional)",
      "failed_at": "ISO8601 timestamp (optional)",
      "transaction_id": "string (optional)",
      "error_reason": "string (optional)",
      "payment_details": "object (optional)"
    }
  },
  "users": {
    "{userId}": {
      "payments": {
        "{paymentId}": {
          "payment_id": "string",
          "amount": "number",
          "currency": "string",
          "status": "string",
          "created_at": "ISO8601 timestamp",
          "link_opened_at": "ISO8601 timestamp (optional)",
          "completed_at": "ISO8601 timestamp (optional)",
          "failed_at": "ISO8601 timestamp (optional)",
          "transaction_id": "string (optional)",
          "error_reason": "string (optional)"
        }
      }
    }
  },
  "wallet": {
    "balance": {
      "{userId}": {
        "amount": "number",
        "currency": "string",
        // Additional wallet fields
      }
    }
  }
}
```

#### Firestore Collections

```
users/
└── {userId}/
    ├── firstName: string
    ├── lastName: string
    ├── email: string
    └── createdAt: timestamp
```

---

## Implementation Details

### Payment Service Architecture

The `FirebasePaymentService` class follows a singleton-like pattern with static methods:

**Key Features:**
- Lazy initialization of database instance
- Centralized database URL configuration
- Comprehensive error handling
- Dual storage (global + user-specific)
- Status tracking throughout payment lifecycle

**Payment Status Lifecycle:**
```
initiated → link_opened → completed/failed
```

### Integration with IntaSend

The payment flow integrates Firebase with IntaSend payment processing:

1. **Checkout Creation** (`IntaSendService.processPayment()`)
   - Creates IntaSend checkout session
   - Generates payment ID
   - Stores payment initiation in Firebase

2. **Link Launch** (`IntaSendService.launchCheckout()`)
   - Opens checkout URL
   - Updates Firebase status to `link_opened`

3. **Payment Completion** (User confirmation)
   - Updates Firebase status to `completed`
   - Stores transaction details

### Error Handling Patterns

1. **Try-Catch Blocks**: All Firebase operations wrapped in try-catch
2. **User-Friendly Messages**: Errors converted to readable messages
3. **Graceful Degradation**: App continues functioning if Firebase fails
4. **Logging**: Comprehensive print statements for debugging

### Security Considerations

1. **Authentication Required**: Most operations check for authenticated user
2. **User ID Validation**: Uses authenticated user ID, not passed parameters
3. **Data Validation**: Input validation before Firebase operations
4. **Error Sanitization**: Error messages don't expose sensitive information

---

## Configuration Files

### Android Configuration

**File**: `android/app/google-services.json`

```json
{
  "project_info": {
    "project_number": "241917597382",
    "firebase_url": "https://truepay-72060-default-rtdb.firebaseio.com",
    "project_id": "truepay-72060",
    "storage_bucket": "truepay-72060.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:241917597382:android:11278578d75ad12f4969c7",
        "android_client_info": {
          "package_name": "com.example.pretium_mock"
        }
      },
      "api_key": [
        {
          "current_key": "AIzaSyAbkhQZp_sbiGsaWYsqUqdJErvFVnI-KBI"
        }
      ]
    }
  ]
}
```

### iOS Configuration

**File**: `ios/Runner/GoogleService-Info.plist`

```xml
<key>PROJECT_ID</key>
<string>truepay-72060</string>
<key>DATABASE_URL</key>
<string>https://truepay-72060-default-rtdb.firebaseio.com</string>
<key>GCM_SENDER_ID</key>
<string>241917597382</string>
<key>BUNDLE_ID</key>
<string>com.example.TP</string>
```

### Code Configuration

**File**: `lib/core/constants/app_strings.dart`

```dart
const String kBackendBaseUrl = 'https://truepay-72060-default-rtdb.firebaseio.com/';
```

**File**: `lib/services/firebase_payment_service.dart`

```dart
static const String _databaseUrl = 'https://truepay-72060-default-rtdb.firebaseio.com/';
```

---

## Error Handling

### Firebase Initialization Errors

**Location**: `lib/main.dart`

- Catches initialization exceptions
- Provides setup instructions
- Allows app to continue with limited functionality

### Authentication Errors

**Location**: `lib/features/auth/screens/login_page.dart`, `register_page.dart`

**Handled Errors:**
- `user-not-found`
- `wrong-password`
- `invalid-email`
- `email-already-in-use`
- `weak-password`
- Network errors
- Firebase not initialized

### Database Errors

**Location**: `lib/services/firebase_payment_service.dart`

**Error Handling:**
- Try-catch blocks around all database operations
- Returns success/error maps for operation results
- Logs errors for debugging
- Graceful failure (doesn't crash app)

### Wallet Balance Errors

**Location**: `lib/features/topup/services/intasend_service.dart`

- Handles missing wallet data
- Throws exceptions for debugging
- Provides user feedback

---

## Best Practices Implemented

1. ✅ **Centralized Configuration**: Database URLs stored in constants
2. ✅ **Error Handling**: Comprehensive error handling throughout
3. ✅ **User Feedback**: User-friendly error messages
4. ✅ **Data Validation**: Input validation before Firebase operations
5. ✅ **Status Tracking**: Complete payment lifecycle tracking
6. ✅ **Dual Storage**: Global and user-specific data storage
7. ✅ **Authentication Checks**: Verifies user authentication before operations
8. ✅ **Logging**: Debug logging for troubleshooting
9. ✅ **Graceful Degradation**: App continues if Firebase fails
10. ✅ **Type Safety**: Proper type handling for Firebase data

---

## Future Enhancements

### Potential Improvements

1. **Real Email Link Authentication**: Implement actual email link sign-in
2. **Real-time Listeners**: Add real-time listeners for payment status updates
3. **Offline Support**: Implement offline persistence for Realtime Database
4. **Security Rules**: Document and implement Firebase Security Rules
5. **Analytics**: Enable Firebase Analytics for user behavior tracking
6. **Cloud Functions**: Add Firebase Cloud Functions for server-side processing
7. **Push Notifications**: Implement Firebase Cloud Messaging for payment notifications
8. **Storage**: Use Firebase Storage for user profile images
9. **Remote Config**: Use Firebase Remote Config for feature flags
10. **Performance Monitoring**: Enable Firebase Performance Monitoring

---

## Troubleshooting

### Common Issues

1. **Firebase Not Initialized**
   - Check configuration files are in correct locations
   - Verify project ID matches in all files
   - Ensure Firebase project is active

2. **Authentication Failures**
   - Verify email/password format
   - Check Firebase Authentication is enabled in console
   - Verify user exists in Firebase Auth

3. **Database Connection Issues**
   - Verify database URL is correct
   - Check Realtime Database is enabled
   - Verify database rules allow read/write

4. **Payment Data Not Storing**
   - Check user is authenticated
   - Verify database permissions
   - Check error logs for specific errors

---

## References

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Firebase Realtime Database Guide](https://firebase.google.com/docs/database)
- [Firebase Authentication Guide](https://firebase.google.com/docs/auth)
- [Cloud Firestore Guide](https://firebase.google.com/docs/firestore)

---

**Last Updated**: Based on codebase analysis
**Project**: TruePay (Pretium)
**Firebase Project ID**: truepay-72060

