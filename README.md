# TruePay (Pretium) - Digital Wallet Application

A comprehensive Flutter-based digital wallet application that enables users to manage fiat and cryptocurrency balances, process payments, send money, swap currencies, and top up their wallets. Built with Firebase backend services and IntaSend payment integration.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Architecture](#architecture)
4. [Tech Stack](#tech-stack)
5. [Project Structure](#project-structure)
6. [Key Components](#key-components)
7. [Firebase Integration](#firebase-integration)
8. [Payment System](#payment-system)
9. [Wallet System](#wallet-system)
10. [Getting Started](#getting-started)
11. [Development Guidelines](#development-guidelines)
12. [Security](#security)
13. [API Integration](#api-integration)

---

## 🎯 Overview

TruePay is a modern digital wallet application that provides users with a seamless experience for managing both fiat currencies (USD, KES, UGX, TZS, EUR, GBP) and cryptocurrencies (USDT, USDC, BNB). The application features:

- **Dual Wallet System**: Separate wallets for fiat and crypto currencies
- **Payment Processing**: Integration with IntaSend for secure payment processing
- **Money Transfer**: Send money to other users with multiple payment methods
- **Currency Swap**: Exchange between fiat and crypto currencies
- **Top-up Functionality**: Add funds via fiat payments or cryptocurrency deposits
- **Real-time Updates**: Live balance updates using Firebase Realtime Database
- **Order Management**: Track all transactions and orders in Firestore

---

## ✨ Features

### Core Features

1. **Authentication & User Management**
   - Email/password authentication via Firebase Auth
   - User profile management in Firestore
   - Automatic wallet initialization on user registration

2. **Dual Wallet System**
   - **Fiat Wallet**: Supports USD, KES, UGX, TZS, EUR, GBP
   - **Crypto Wallet**: Supports USDT, USDC, BNB
   - Real-time balance synchronization
   - Side-by-side balance display

3. **Top-up (Add Funds)**
   - **Fiat Top-up**: Via IntaSend payment gateway
     - Supports multiple currencies
     - Card and mobile money payments
     - Secure checkout flow
   - **Crypto Top-up**: Direct cryptocurrency deposits
     - Multiple crypto addresses (USDT, USDC, BNB)
     - Network-specific addresses (Tron, Solana, BNB Smart Chain)
     - Copy-to-clipboard functionality

4. **Send Money**
   - Multi-step transaction flow
   - Amount selection with currency conversion
   - Payment method selection
   - Recipient details collection
   - Transaction review and confirmation
   - Order creation in Firestore

5. **Currency Swap**
   - Real-time exchange rates
   - Swap between fiat and crypto currencies
   - Balance validation
   - Confirmation flow with success animation
   - Order tracking

6. **Financial Services**
   - Send Money
   - Buy Goods
   - Pay Bills
   - Airtime Purchase

7. **Transaction History**
   - Recent transactions display
   - Order tracking in Firestore
   - Payment status monitoring

---

## 🏗️ Architecture

### Architecture Pattern

The application follows a **Feature-Based Modular Architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
│  (Screens, Widgets, UI Components)                      │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                    Service Layer                         │
│  (Business Logic, API Calls, Cloud Functions)           │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  Repository Layer                        │
│  (Data Access, Firebase Operations)                      │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                    Data Layer                            │
│  (Firebase Realtime DB, Firestore, Models)              │
└─────────────────────────────────────────────────────────┘
```

### Key Architectural Principles

1. **Separation of Concerns**: Clear boundaries between UI, business logic, and data access
2. **Repository Pattern**: All data access goes through repositories
3. **Service Layer**: Business logic encapsulated in service classes
4. **Read-Only Client**: Client code cannot directly write to sensitive data (payments, wallets)
5. **Cloud Functions**: All write operations for payments and wallets handled server-side
6. **Real-time Updates**: Stream-based data synchronization

---

## 🛠️ Tech Stack

### Frontend
- **Framework**: Flutter 3.7.0+
- **Language**: Dart
- **State Management**: StatefulWidget (can be extended with Provider/Riverpod/Bloc)
- **Navigation**: Named routes with MaterialApp
- **UI Components**: Material Design 3

### Backend & Services
- **Firebase Authentication**: User authentication
- **Firebase Realtime Database**: Real-time wallet balances and payment tracking
- **Cloud Firestore**: User profiles and order management
- **Firebase Cloud Functions**: Server-side payment and wallet operations
- **Firebase Cloud Messaging**: Push notifications (configured)
- **IntaSend API**: Payment processing gateway

### Key Dependencies

```yaml
# Firebase
firebase_core: ^3.6.0
cloud_firestore: ^5.4.3
firebase_auth: ^5.3.1
firebase_database: ^11.1.3
cloud_functions: ^5.1.5
firebase_messaging: ^15.1.3

# UI & Utilities
get: ^4.7.2
font_awesome_flutter: ^10.8.0
shared_preferences: ^2.2.2
confetti: ^0.7.0

# Network
http: ^0.13.4
url_launcher: ^6.2.1
```

---

## 📁 Project Structure

```
lib/
├── app/                          # App-level configuration
│   ├── app.dart                  # Main app widget
│   └── route_names.dart          # Route name constants
│
├── core/                         # Core utilities and constants
│   ├── constants/
│   │   ├── app_colors.dart       # Color definitions
│   │   ├── app_strings.dart     # String constants
│   │   └── app_text_styles.dart # Text style definitions
│   └── widgets/                  # Reusable core widgets
│       ├── custom_button.dart
│       └── input_field.dart
│
├── features/                     # Feature modules
│   ├── auth/                     # Authentication feature
│   │   ├── screens/
│   │   │   ├── login_page.dart
│   │   │   └── register_page.dart
│   │   └── widgets/              # Auth-specific widgets
│   │
│   ├── home/                     # Home/Dashboard feature
│   │   └── screens/
│   │       └── landing_page.dart
│   │
│   ├── splash/                   # Splash screens
│   │   └── screens/
│   │       ├── splash_page.dart
│   │       ├── splash_page_1.dart
│   │       └── splash_page_2.dart
│   │
│   ├── topup/                     # Top-up feature
│   │   ├── screens/
│   │   │   └── topup_page.dart   # Main top-up screen
│   │   └── services/
│   │       └── intasend_service.dart  # IntaSend integration
│   │
│   ├── send_money/               # Send money feature
│   │   └── screens/
│   │       ├── send_money_page.dart
│   │       ├── send_amount_screen.dart
│   │       ├── payment_method_screen.dart
│   │       ├── recipient_details_screen.dart
│   │       └── review_details_screen.dart
│   │
│   └── swap/                      # Currency swap feature
│       ├── screens/
│       │   └── swap_page.dart
│       ├── services/
│       │   └── rates_service.dart
│       └── widgets/
│           └── currency_picker_bottom_sheet.dart
│
├── models/                        # Data models
│   ├── wallet_model.dart          # Wallet data model
│   ├── user_model.dart            # User profile model
│   ├── payment_model.dart         # Payment data model
│   ├── order_model.dart           # Order data model
│   └── transaction_details_model.dart
│
├── repositories/                  # Data access layer
│   ├── wallet_repository.dart     # Wallet operations (READ-ONLY)
│   ├── user_repository.dart       # User profile operations
│   └── payment_repository.dart     # Payment read operations
│
├── services/                      # Business logic layer
│   ├── auth_service.dart          # Authentication service
│   ├── payment_service.dart       # Payment operations via Cloud Functions
│   ├── order_service.dart         # Order management
│   └── firebase_payment_service.dart  # Legacy payment service
│
├── utils/                         # Utility classes
│   ├── logger.dart                # Logging utility
│   ├── navigation_service.dart    # Navigation helpers
│   └── validators.dart            # Input validation
│
├── widgets/                       # Shared UI widgets
│   ├── wallet_card.dart           # Wallet balance card
│   ├── header_widget.dart         # App header
│   ├── financial_service.dart     # Financial service buttons
│   └── placeholder_transactions.dart
│
└── main.dart                      # Application entry point
```

---

## 🔑 Key Components

### 1. Authentication System

**Location**: `lib/services/auth_service.dart`

- **Email/Password Authentication**: Sign up, sign in, sign out
- **Password Reset**: Email-based password recovery
- **Session Management**: Automatic session handling via Firebase Auth
- **Error Handling**: User-friendly error messages

**Flow**:
1. User enters credentials on login/register page
2. `AuthService` handles Firebase Auth operations
3. On successful registration, Cloud Function creates user profile and wallets
4. User is redirected to landing page

### 2. Wallet System

**Location**: `lib/repositories/wallet_repository.dart`, `lib/models/wallet_model.dart`

**Dual Wallet Architecture**:
- **Fiat Wallet**: `wallet/{userId}/balance` in Realtime Database
- **Crypto Wallet**: `wallet/{userId}/crypto/{currencyCode}` in Realtime Database

**Features**:
- Real-time balance streaming
- Separate balances for each currency
- Automatic wallet initialization on user creation
- Read-only client access (updates via Cloud Functions only)

**Wallet Initialization**:
- Triggered automatically when a new user is created
- Creates both fiat (USD) and crypto (USDT) wallets with 0 balance
- Handled by Cloud Function: `initializeWalletOnUserCreate`

### 3. Payment Processing

**Location**: `lib/services/payment_service.dart`, `lib/features/topup/services/intasend_service.dart`

**Payment Flow**:
1. User enters amount and payment details on top-up page
2. `IntaSendService` creates checkout session via IntaSend API
3. `PaymentService` creates payment record via Cloud Function
4. User completes payment on IntaSend checkout page
5. Webhook updates payment status
6. Cloud Function updates wallet balance on successful payment
7. Order is created in Firestore for tracking

**Payment Methods**:
- **Fiat**: Card payments, Mobile Money (via IntaSend)
- **Crypto**: Direct cryptocurrency deposits to provided addresses

### 4. Top-up Feature

**Location**: `lib/features/topup/screens/topup_page.dart`

**Features**:
- Dual balance display (Fiat + Crypto side by side)
- Amount input with quick-add buttons
- Currency selection for fiat payments
- Fiat payment form (email, name, currency)
- Crypto deposit addresses with copy functionality
- Automatic crypto wallet creation if missing
- Order creation on payment initiation

**UI Components**:
- `_BalanceHeader`: Displays both USD and USDT balances
- `_SetAmountCard`: Amount input with quick-add chips
- `_FiatOptionCard`: Fiat payment form
- `_CryptoOptionCard`: Cryptocurrency deposit addresses

### 5. Send Money Feature

**Location**: `lib/features/send_money/screens/`

**Multi-Step Flow**:
1. **Amount Screen**: Enter amount, select currencies
2. **Payment Method Screen**: Choose payment method
3. **Recipient Details Screen**: Enter recipient information
4. **Review Screen**: Confirm transaction details
5. **Order Creation**: Transaction saved to Firestore

**Transaction Model**: `TransactionDetails` tracks all transaction data through the flow

### 6. Currency Swap Feature

**Location**: `lib/features/swap/screens/swap_page.dart`

**Features**:
- Real-time exchange rate calculation
- Balance validation before swap
- Currency selection with bottom sheet picker
- Confirmation dialog with rate details
- Success animation with confetti
- Order creation for swap transactions

**Rates Service**: `RatesService` provides exchange rates between currencies

---

## 🔥 Firebase Integration

### Firebase Services Used

1. **Firebase Authentication**
   - Email/password authentication
   - User session management
   - Password reset functionality

2. **Firebase Realtime Database**
   - Wallet balances (real-time sync)
   - Payment tracking
   - Path structure:
     ```
     wallet/
       {userId}/
         balance/          # Fiat wallet
         crypto/
           USDT/          # Crypto wallets
           USDC/
           BNB/
     payments/
       {paymentId}/       # Payment records
     users/
       {userId}/
         payments/        # User payment references
     ```

3. **Cloud Firestore**
   - User profiles: `users/{userId}`
   - Orders: `orders/{orderId}`
   - Document-based storage for structured data

4. **Firebase Cloud Functions**
   - `initializeWalletOnUserCreate`: Auto-creates wallets on user registration
   - `createPayment`: Creates payment records (server-side)
   - `handlePaymentWebhook`: Processes payment status updates
   - `updateWalletAfterPayment`: Updates wallet balance after payment
   - `initializeCryptoWallet`: Creates crypto wallet for existing users

5. **Firebase Cloud Messaging**
   - Push notification support (configured)
   - Background message handling

### Database Security Rules

**Realtime Database** (`database.rules.json`):
- Users can only read their own wallet data
- Client writes to wallet balances are blocked (Cloud Functions only)
- Exception: Crypto wallet initialization (balance must be 0)
- Payment writes are blocked (Cloud Functions only)

**Firestore** (`firestore.rules`):
- Users can read/write their own profile
- Orders are user-scoped
- Admin access can be configured separately

---

## 💳 Payment System

### IntaSend Integration

**Service**: `lib/features/topup/services/intasend_service.dart`

**Features**:
- Checkout session creation
- Payment URL generation
- Browser launch for payment completion
- Support for multiple currencies
- Test and production modes

**Payment Flow**:
1. User fills payment form on top-up page
2. `IntaSendService.createCheckout()` called with payment details
3. IntaSend API returns checkout URL
4. User redirected to IntaSend payment page
5. Payment completed on IntaSend
6. Webhook notifies application (via Cloud Function)
7. Wallet balance updated automatically

### Order Management

**Service**: `lib/services/order_service.dart`

**Features**:
- Order creation in Firestore
- Order status tracking
- User order history
- Order metadata storage

**Order Model**: Tracks order type (topup, swap, send_money), amount, currency, status, and metadata

---

## 💰 Wallet System

### Wallet Structure

**Fiat Wallet**:
- Path: `wallet/{userId}/balance`
- Default currency: USD
- Supports: USD, KES, UGX, TZS, EUR, GBP
- Structure:
  ```json
  {
    "balance": 0.0,
    "currency": "USD",
    "updatedAt": "2024-01-01T00:00:00Z",
    "createdAt": "2024-01-01T00:00:00Z"
  }
  ```

**Crypto Wallet**:
- Path: `wallet/{userId}/crypto/{currencyCode}`
- Supports: USDT, USDC, BNB
- Structure:
  ```json
  {
    "balance": 0.0,
    "currency": "USDT",
    "updatedAt": "2024-01-01T00:00:00Z",
    "createdAt": "2024-01-01T00:00:00Z"
  }
  ```

### Wallet Operations

**Read Operations** (Client):
- `getWalletBalance(uid)`: Get fiat wallet balance
- `getCryptoWalletBalance(uid, currencyCode)`: Get crypto wallet balance
- `streamWalletBalance(uid)`: Stream fiat wallet updates
- `streamCryptoWalletBalance(uid, currencyCode)`: Stream crypto wallet updates

**Write Operations** (Cloud Functions Only):
- Wallet initialization on user creation
- Balance updates after payment completion
- Crypto wallet creation (if missing)

**Security**:
- Client code is **READ-ONLY** for wallet data
- All balance updates happen server-side via Cloud Functions
- Database rules enforce this restriction

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.7.0 or higher
- Dart SDK 3.7.0 or higher
- Firebase project configured
- Node.js (for Cloud Functions)
- Android Studio / Xcode (for mobile development)

### Installation

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd pretium
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**:
   - Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in place
   - Verify `lib/firebase_options.dart` is generated
   - If not, run: `flutterfire configure`

4. **Cloud Functions Setup**:
   ```bash
   cd functions
   npm install
   ```

5. **Deploy Cloud Functions**:
   ```bash
   firebase deploy --only functions
   ```

6. **Deploy Database Rules**:
   ```bash
   firebase deploy --only database
   ```

7. **Run the application**:
   ```bash
   flutter run
   ```

### Configuration

**IntaSend API Keys**:
- Update `intaSendPublicKey` in `lib/features/topup/screens/topup_page.dart`
- Set `isTestMode` to `false` for production

**Firebase Configuration**:
- Verify Firebase project ID in `firebase.json`
- Check database URL in `firebase.md`

---

## 📝 Development Guidelines

### Code Organization

1. **Feature-Based Structure**: Each feature is self-contained in its own directory
2. **Separation of Concerns**: UI, business logic, and data access are separated
3. **Repository Pattern**: All data access goes through repositories
4. **Service Layer**: Business logic in service classes

### Naming Conventions

- **Files**: `snake_case.dart`
- **Classes**: `PascalCase`
- **Variables/Methods**: `camelCase`
- **Constants**: `UPPER_SNAKE_CASE`

### State Management

- Currently using `StatefulWidget` for local state
- Can be extended with Provider, Riverpod, or Bloc for global state
- Streams used for real-time data (wallet balances)

### Error Handling

- All services include try-catch blocks
- User-friendly error messages via `Logger`
- Firebase errors are caught and displayed appropriately

### Logging

- Use `Logger` utility for all logging
- Levels: `debug`, `info`, `warning`, `error`, `success`
- Logs include context and error details

---

## 🔒 Security

### Security Measures

1. **Client-Side Restrictions**:
   - Wallet balances are READ-ONLY from client
   - Payment creation/updates via Cloud Functions only
   - Database rules enforce write restrictions

2. **Server-Side Validation**:
   - All payment operations validated in Cloud Functions
   - User authentication required for all operations
   - Input validation on all API calls

3. **Data Protection**:
   - User data is scoped to authenticated users
   - Database rules prevent unauthorized access
   - Sensitive operations require authentication

4. **Payment Security**:
   - Payment processing via secure IntaSend gateway
   - Payment IDs generated server-side
   - Webhook validation for payment status

### Security Rules

**Realtime Database**:
- Users can only read their own wallet data
- Wallet writes blocked (Cloud Functions only)
- Payment writes blocked (Cloud Functions only)
- Crypto wallet initialization allowed (balance must be 0)

**Firestore**:
- Users can read/write their own profile
- Orders are user-scoped
- Admin access configurable

---

## 🔌 API Integration

### IntaSend API

**Base URLs**:
- Test: `https://sandbox.intasend.com/api/v1`
- Production: `https://payment.intasend.com/api/v1`

**Endpoints Used**:
- `POST /checkout/`: Create checkout session
- Returns checkout URL for payment completion

**Authentication**:
- Public key authentication
- Key stored in app (consider environment variables for production)

### Firebase Cloud Functions

**Available Functions**:
- `createPayment`: Create payment record
- `handlePaymentWebhook`: Process payment webhooks
- `updateWalletAfterPayment`: Update wallet balance
- `initializeCryptoWallet`: Initialize crypto wallet

**Calling Functions**:
```dart
final functions = FirebaseFunctions.instance;
final callable = functions.httpsCallable('functionName');
final result = await callable.call({'param': 'value'});
```

---

## 📱 Platform Support

- ✅ Android (min SDK 23)
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

---

## 🧪 Testing

### Running Tests

```bash
flutter test
```

### Test Coverage

- Unit tests for services and repositories
- Widget tests for UI components
- Integration tests for critical flows

---

## 📄 License

[Specify your license here]

---

## 🤝 Contributing

[Contributing guidelines]

---

## 📞 Support

For issues and questions:
- Create an issue in the repository
- Check `firebase.md` for Firebase-specific documentation
- Review `REFACTORING_GUIDE.md` for architecture details

---

## 🔄 Version History

- **v1.0.0+3**: Current version
  - Dual wallet system (Fiat + Crypto)
  - IntaSend payment integration
  - Send money feature
  - Currency swap feature
  - Order management system
  - Real-time balance updates

---

## 📚 Additional Documentation

- `firebase.md`: Comprehensive Firebase setup and usage
- `REFACTORING_GUIDE.md`: Architecture and refactoring guidelines
- `SECURITY_RULES_SETUP.md`: Security rules configuration
- `WARP.md`: Additional project documentation

---

**Built with ❤️ using Flutter and Firebase**
