# SafariCard

Flutter digital wallet for fiat and crypto: balances, top-ups, transfers, swaps, and Circle USDC. Package name: `pretium`. Backend: Firebase (Auth, Realtime Database, Firestore, Cloud Functions, FCM).

---

## Table of Contents

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
14. [Platform Support](#platform-support)

---

## Overview

SafariCard is a dual-wallet app for African and international currencies plus stablecoins:

- **Fiat wallet**: USD, KES, NGN, GHS, UGX (and related deposit countries)
- **Crypto wallet**: USDT (legacy balances) and **USDC** via Circle
- **Top-up**: Paystack / Transak hosted checkout, direct fiat deposit, crypto deposit
- **Send money**: Multi-step transfer flow with order tracking
- **Swap**: Fiat ↔ crypto with live rates
- **Realtime balances**: Firebase Realtime Database streams
- **Push notifications**, biometric login, light/dark theme

---

## Features

### Authentication & access

- Email/password via Firebase Auth
- Registration through backend HTTP API (`/api/register`)
- Password reset, biometric session unlock (`local_auth` + secure storage)
- App access guard (customer claims / KYC-style gates)
- Wallet verification screen before crypto transfers

### Dual wallet

- Side-by-side fiat and crypto cards on the home dashboard
- Per-currency fiat balances; swipe between currencies
- USDT + Circle USDC (send, receive, balance, transaction history)
- Client is read-only for balances; writes go through Cloud Functions / APIs

### Top-up

- **Card / mobile money**: `PaymentService.createPayment` → Paystack (African currencies) or Transak (USD, GBP, EUR, etc.)
- **Direct fiat deposit**: Country-aware deposit flow
- **Crypto deposit**: Deposit addresses / on-chain funding
- Deep-link / callback handling after hosted checkout (`app_links`, `PaymentCallbackService`)
- Receipt save / share helpers

### Send money & swap

- Amount → payment method → recipient → review
- Swap with rates service and order creation
- Transaction list, detail view, and simple charts

### Settings & notifications

- Wallet settings: profile, theme, biometric toggle, sign out
- Contact support
- In-app notifications page + FCM / local notifications

---

## Architecture

Feature-based modules with clear layers:

```
Presentation (screens / widgets)
        ↓
Services (auth, payments, crypto API, notifications)
        ↓
Repositories (wallet, user — mostly read)
        ↓
Firebase / HTTP Cloud Functions
```

**Principles**

1. Separation of UI, business logic, and data access
2. Repository pattern for client data reads
3. Sensitive writes (payments, wallet balances) only on the server
4. Stream-based realtime balance updates
5. Theme via `Provider` (`ThemeProvider`)

---

## Tech Stack

### Frontend

| Area | Choice |
|------|--------|
| Framework | Flutter (Dart SDK `^3.1.4`) |
| State | `StatefulWidget` + `Provider` (theme) |
| Navigation | Named routes (`RouteNames`) |
| UI | Material 3, light/dark palettes |

### Backend & integrations

- Firebase Auth, Realtime Database, Firestore, Cloud Functions, FCM
- **Paystack** / **Transak** for fiat top-up checkout
- **Circle** for USDC wallet, balance, send, and history (`cryptoApi`)
- Binance-backed rates via callable / HTTP APIs (see `api.md`)

### Key dependencies

```yaml
# Firebase
firebase_core, cloud_firestore, firebase_auth, firebase_database
cloud_functions, firebase_messaging, flutter_local_notifications

# Payments / deep links / crypto helpers
http, url_launcher, app_links, crypto, uuid

# UX & security
provider, confetti, font_awesome_flutter, shared_preferences
flutter_secure_storage, local_auth, gal, image, share_plus
```

Version: **1.0.0+13** (`pubspec.yaml`).

---

## Project Structure

```
lib/
├── app/
│   └── route_names.dart
├── core/
│   ├── constants/          # colors, auth config, Cloud Functions URLs
│   ├── theme/              # ThemeProvider
│   └── widgets/
├── features/
│   ├── auth/               # login, register, forgot password
│   ├── splash/
│   ├── home/               # landing / dashboard
│   ├── topup/              # Paystack/Transak, direct fiat, crypto deposit
│   ├── send_money/
│   ├── swap/
│   ├── crypto/             # Circle USDC send / receive / history
│   ├── transactions/
│   ├── notifications/
│   ├── wallet/
│   ├── wallet_settings/
│   └── wallet_verification/
├── models/
├── repositories/           # wallet_repository, user_repository
├── services/               # auth, payments, notifications, biometrics, …
├── widgets/                # wallet_card, financial_service, headers, …
└── main.dart
```

Cloud Functions live under `functions/` (see also `api.md` for the full HTTP/callable surface).

---

## Key Components

### Authentication

`lib/services/auth_service.dart`, `lib/features/auth/`

- Sign up / sign in / sign out / password reset
- Post-auth routing and registration API
- Biometric credential storage: `BiometricSessionService`

### Wallets

`lib/repositories/wallet_repository.dart`, `lib/widgets/wallet_card.dart`

- Fiat: `wallet/{userId}/fiat/{currency}`
- Crypto: `wallet/{userId}/crypto/{currencyCode}`
- USDC also refreshed from Circle HTTP API for send validation

### Payments & top-up

`lib/services/payment_service.dart`, `lib/features/topup/`

1. User enters amount and method on top-up
2. Callable `createPayment` creates the payment server-side
3. App opens hosted checkout (Paystack or Transak)
4. Webhook / callback updates status; wallet credited server-side

### Circle USDC

`lib/features/crypto/`, `CloudFunctionsApiConfig.baseCryptoApiUrl`

- `GET /crypto/wallet`, `/crypto/balance`, `/crypto/transactions`
- `POST /crypto/send` (idempotency key supported)

### Send money & swap

- Multi-step UI under `features/send_money/`
- `features/swap/` + `RatesService` / `SwapOrderService`

---

## Firebase Integration

| Service | Use |
|---------|-----|
| Auth | Sessions, ID tokens for callables / HTTP APIs |
| Realtime Database | Wallet balances, payment records |
| Firestore | Profiles, orders, notifications metadata |
| Cloud Functions | Payments, wallet init, rates, registration, Circle proxy |
| FCM | Push + background handler in `main.dart` |

**Typical RTDB shape**

```
wallet/{userId}/fiat/{currency}
wallet/{userId}/crypto/{USDT|USDC}
payments/{paymentId}
users/{userId}/payments/...
```

**Notable functions** (local `functions/index.js` and deployed API set):

- `initializeWalletOnUserCreate`
- `createPayment`, `handlePaymentWebhook`, `updateWalletAfterPayment`
- `initializeCryptoWallet`
- HTTP: `/api/*` (register, countries, rates, …) and `cryptoApi` for Circle

Rules: see `database.rules.json`, `firestore.rules`, and `SECURITY_RULES_SETUP.md`.

---

## Payment System

### Fiat checkout

- African currencies → **Paystack**
- USD / GBP / EUR and other non-African → **Transak**
- Created only via Cloud Functions; client never writes payment docs for settlement

### Direct fiat & crypto

- Direct deposit flow: `direct_fiat_deposit_flow.dart`
- Country catalog: `TopupDepositCountry`
- Crypto deposit option on the same top-up screen

### Orders

Historical order tracking remains Firestore-backed for top-ups, swaps, and transfers (see transaction models / services).

---

## Wallet System

**Fiat example**

```json
{
  "balance": 0.0,
  "currency": "USD",
  "updatedAt": "...",
  "createdAt": "..."
}
```

**Crypto**: same shape under `crypto/{USDT|USDC}`; USDC spendable balance also comes from Circle.

Client APIs (repository): get / stream fiat and crypto balances. All balance mutations are server-side.

---

## Getting Started

### Prerequisites

- Flutter / Dart (SDK `^3.1.4`)
- Firebase project configured
- Node.js (Cloud Functions)
- Android Studio and/or Xcode for device builds

### Install

```bash
git clone <repository-url>
cd pretium
flutter pub get
```

### Firebase

1. Place `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
2. Ensure `lib/firebase_options.dart` exists (`flutterfire configure` if needed)
3. Deploy functions and rules as needed:

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
firebase deploy --only database,firestore:rules
```

### Run

```bash
flutter run
```

### Flutter Web / PWA (Firebase Hosting)

Production URL: https://app.truepay.live

```bash
./scripts/build_web.sh
firebase deploy --only hosting:app
```

This builds a release PWA with Flutter’s offline-first service worker, branded splash (`web/index.html`), and SafariCard manifest/icons. Hosting cache headers live in `firebase.json`.

Payment provider credentials and Circle keys belong in Cloud Functions config / secrets — not in the Flutter client.

---

## Development Guidelines

- **Features** own their screens, models, and feature services
- **Files** `snake_case.dart` · **Classes** `PascalCase` · **members** `camelCase`
- Prefer streams for wallet UI; cache short-lived dashboard data via `DashboardSessionCache`
- Log with `Logger` (`debug` / `info` / `warning` / `error` / `success`)
- Do not write wallet balances or payment settlement from the client

---

## Security

1. Wallet and payment writes blocked for clients (RTDB / Firestore rules + Functions)
2. Callable and HTTP APIs require Firebase Auth (Bearer ID token)
3. Biometric login stores credentials in platform secure storage
4. Hosted checkout and Circle operations run server-side

---

## API Integration

Full reference: **[api.md](./api.md)**.

**Cloud Functions HTTP base** (from `CloudFunctionsApiConfig`):

```
https://us-central1-<project-id>.cloudfunctions.net/api
https://us-central1-<project-id>.cloudfunctions.net/cryptoApi
```

**Callable example**

```dart
final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
final callable = functions.httpsCallable('createPayment');
final result = await callable.call({
  'amount': 100,
  'currency': 'KES',
  'provider': 'paystack',
});
```

---

## Platform Support

- Android (min SDK 23)
- iOS
- Web
- Windows / macOS / Linux

---

## Testing

```bash
flutter test
```

---

## Additional documentation

| Doc | Topic |
|-----|--------|
| [api.md](./api.md) | Backend callable + HTTP APIs |
| [firebase.md](./firebase.md) | Firebase setup and data paths |
| [SECURITY_RULES_SETUP.md](./SECURITY_RULES_SETUP.md) | Rules deployment |
| [REFACTORING_GUIDE.md](./REFACTORING_GUIDE.md) | Architecture notes |

---

## Version

- **1.0.0+13** — SafariCard wallet: dual fiat/crypto, Paystack/Transak top-up, Circle USDC, send/swap, notifications, biometrics, light/dark theme

---

Built with Flutter and Firebase
