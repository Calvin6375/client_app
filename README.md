# SafariTap

Flutter digital wallet for fiat and crypto: balances, top-ups, transfers, swaps, Kenya pay, and USDC. Package name: `pretium` (`com.truepay.safaritap`). Backend: Firebase (Auth, Firestore, Cloud Functions, FCM, Remote Config) plus HTTP APIs under `api`, `cryptoApi`, `transactionsApi`, and `safariCardApi`.

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
15. [Testing](#testing)

---

## Overview

SafariTap is a dual-wallet app for African and international currencies plus stablecoins:

- **Fiat wallet**: balances from `GET /api/accounts` (KES, USD, ETB, and other catalog currencies from `/api/countries`)
- **Crypto wallet**: USDT (Tron), USDC (Avalanche C-Chain deposit watch), BNB (BSC)
- **Top-up**: Paystack / Transak hosted checkout in an in-app WebView; USD Grid bank instructions (ACH/WIRE/RTP/SWIFT); optional Crossmint checkout; crypto deposit
- **Send money**: SafariTap-to-SafariTap, mobile money, and bank payouts via `safariCardApi`
- **Pay (Kenya)**: TruePay merchant QR, PayBill, Till (Buy Goods), Pochi la Biashara
- **Swap**: Fiat ↔ crypto with live rates
- **Safari AI**: in-app safari destination guide on the home financial-services row
- Push notifications, biometric session unlock, force-update gate, light/dark/system theme (Inter)

Production web: https://app.truepay.live

---

## Features

### Authentication & access

- Email/password via Firebase Auth
- Registration through backend HTTP (`POST /api/register`)
- Password reset, biometric session unlock (`local_auth` + `flutter_secure_storage`)
- App access guard (customer claims / KYC-style gates)
- Legal documents in-app (WebView)
- Wallet verification screen before crypto transfers
- Store version check on launch (`ForceUpdateService`); users cannot skip a required update on iOS/Android

### Dual wallet

- Home dashboard: fiat and crypto cards, recent transactions, bottom nav (Home, Top up, Pay, Wallet)
- Per-currency fiat balances; swipe between owned currencies
- Client is read-only for balances; settlement happens on the server
- Dashboard stale-while-revalidate cache: `DashboardSessionCache` + `walletAccountsProvider`

### Top-up

- Quote first: `POST /api/funding/topup/quote`
- **Card / mobile money**: `PaymentService.createPayment` (callable `createPayment`)
  - African currencies → **Paystack**
  - USD, GBP, EUR, and other non-African → **Transak**
  - Checkout opens in `PaymentCheckoutWebviewPage` (stays in-app)
- **USD bank rails**: provider `grid` returns `CreatePaymentFlow.gridUsdInstructions` (no hosted URL); `UsdFundingInstructionsScreen` shows ACH / WIRE / RTP / FEDNOW / SWIFT details
- **USD Crossmint**: hosted or embedded checkout when the backend returns checkout secrets / URL
- **Crypto deposit**: USDT (Tron), USDC (Avalanche via `POST /crypto/deposit/watch`), BNB (BSC)
- Deep-link / callback handling after hosted checkout (`app_links`, `PaymentCallbackService`)
- Receipt save / share helpers

### Send money, pay & swap

- Send: amount → method → recipient → review → payout (`safari-card/payouts`)
- Pay hub: merchant QR scan (`mobile_scanner`), PayBill, Buy Goods, Pochi (KES)
- Swap with `RatesService` / quote + order creation
- Transaction list and detail via `transactionsApi`

### Settings & notifications

- Wallet settings: profile, theme, biometric toggle, sign out
- Contact support
- In-app notifications + FCM / local notifications

---

## Architecture

Feature-based modules with Riverpod at the app root (`ProviderScope` in `main.dart`):

```
Presentation (screens / widgets)
        ↓
Riverpod notifiers (flow + session providers)
        ↓
Services (auth, payments, HTTP APIs, notifications)
        ↓
Repositories (wallet, user — client reads only)
        ↓
Firebase Auth / Functions  ·  HTTP Cloud Functions
```

**Principles**

1. UI, flow state, and data access stay separate
2. Feature notifiers (`topUpFlowProvider`, `sendMoneyFlowProvider`, `swapFlowProvider`, `kenyaPayFlowProvider`) own multi-step screens
3. Sensitive writes (payments, payouts, wallet credits) only on the server
4. Wallet list from `GET /api/accounts` (not client RTDB `wallet/{uid}/…` reads)
5. Theme via Riverpod `themeProvider` (`ThemeController`), persisted in `SharedPreferences`
6. C2B HTTP bodies may be encrypted (`C2bHttpCodec` / Remote Config key)

---

## Tech Stack

### Frontend

| Area | Choice |
|------|--------|
| Framework | Flutter (Dart SDK `^3.1.4`) |
| State | Riverpod (`flutter_riverpod`) |
| Navigation | Named routes (`RouteNames`) plus `MaterialPageRoute` for nested flows |
| UI | Material 3, Inter, light/dark palettes (`AppColors`, `AppTypography`) |
| Checkout / pay | `webview_flutter`, `mobile_scanner`, `pretty_qr_code` |

### Backend & integrations

- Firebase Auth, Firestore, Cloud Functions, FCM, Remote Config
- **Paystack** / **Transak** for card / mobile-money checkout
- **Grid** for USD bank-transfer instructions
- **Crossmint** for USD checkout when the API returns that provider
- **Circle / Turnkey** via `cryptoApi` (wallet status, production address, USDC deposit watch, send, history)
- **safariCardApi** for Kenya payouts, merchant resolve, profile QR, banks
- Rates via callable / HTTP APIs (see `api.md`)

### Key dependencies

```yaml
# Firebase
firebase_core, cloud_firestore, firebase_auth, firebase_database
cloud_functions, firebase_messaging, firebase_remote_config
flutter_local_notifications

# HTTP / crypto / deep links
http, url_launcher, app_links, crypto, encrypt, uuid

# App state & UX
flutter_riverpod, webview_flutter, mobile_scanner, pretty_qr_code
flutter_contacts, image_picker, shimmer, share_plus, gal, image
flutter_secure_storage, local_auth, package_info_plus, confetti
```

Version: **1.0.3000+35** (`pubspec.yaml`).

---

## Project Structure

```
lib/
├── app/
│   └── route_names.dart
├── core/
│   ├── constants/          # colors, auth config, Cloud Functions URLs
│   ├── crypto/             # C2B payload encryption
│   ├── http/               # C2B HTTP codec
│   ├── providers/          # auth, wallets, theme-adjacent session
│   ├── theme/              # ThemeController, typography, system UI
│   └── widgets/
├── features/
│   ├── auth/               # login, register, forgot password
│   ├── splash/             # launch + force-update routing
│   ├── force_update/
│   ├── home/               # landing / dashboard
│   ├── topup/              # quotes, checkout WebView, Grid USD instructions
│   ├── pay/                # Kenya pay hub + QR scan
│   ├── safari_tap/         # payout API, merchant QR, profile QR
│   ├── safari_ai/          # destination guide
│   ├── send_money/
│   ├── swap/
│   ├── crypto/             # USDC watch, send / receive / history
│   ├── transactions/
│   ├── notifications/
│   ├── wallet/
│   ├── wallet_settings/
│   └── wallet_verification/
├── models/
├── repositories/           # wallet_repository, user_repository
├── services/               # auth, payments, accounts, transactions, …
├── widgets/
└── main.dart
```

Cloud Functions live under `functions/`. Full HTTP/callable surface: **[api.md](./api.md)**.

---

## Key Components

### Authentication

`lib/services/auth_service.dart`, `lib/features/auth/`

- Sign up / sign in / sign out / password reset
- `AppStartupRouter` after splash; `AppAccessGuard` on home
- Biometric credential storage: `BiometricSessionService`

### Wallets

`lib/repositories/wallet_repository.dart`, `lib/core/providers/wallet_accounts_provider.dart`, `lib/widgets/wallet_card.dart`

- Source of truth: `GET /api/accounts` (alias `GET /api/wallets`)
- `WalletBalanceRefresh` bumps a revision so the dashboard refetches after money movement
- USDC spendable balance / deposit address from `cryptoApi` (deposit watch, not Circle `GET /crypto/wallet` for top-up)

### Payments & top-up

`lib/services/payment_service.dart`, `lib/features/topup/`

1. User picks method, currency, and amount; optional quote on review
2. Callable `createPayment` creates the order server-side
3. Result is parsed as `CreatePaymentResult` (`hostedCheckout` | `gridUsdInstructions` | `crossmintCheckout` | `error`)
4. Webhook / callback updates status; wallet credited server-side

### Circle / USDC

`lib/features/crypto/`, `CloudFunctionsApiConfig.baseCryptoApiUrl`

- `GET /crypto/wallet/status`, `POST /crypto/wallet/production`
- `GET /crypto/balance`, `/crypto/transactions`
- `POST /crypto/send` (idempotency key supported)
- `POST /crypto/deposit/watch` for USDC top-up addresses

### Send money, pay & SafariTap API

`lib/features/safari_tap/`, `lib/features/pay/`, `CloudFunctionsApiConfig.baseSafariTapApiUrl`

- Validate beneficiary, quote, create payouts
- Resolve TruePay merchant QR / ID
- Profile QR for wallet-to-wallet send
- Kenya bank list for bank transfers

---

## Firebase Integration

| Service | Use |
|---------|-----|
| Auth | Sessions, ID tokens for callables / HTTP APIs |
| Firestore | Profiles, orders, notifications metadata (server-owned money movement) |
| Realtime Database | Legacy / ancillary paths; **not** the wallet list in this client |
| Cloud Functions | Payments, registration, rates, Circle/crypto proxy, SafariTap payouts, transactions |
| FCM | Push + background handler in `main.dart` |
| Remote Config | C2B encryption key material |

**HTTP function bases** (`us-central1`):

```
…/api                  # register, countries, accounts/wallets, top-up quote
…/cryptoApi            # Circle / Turnkey USDC
…/transactionsApi      # transaction feed
…/safariCardApi        # pay / send / merchant / banks
```

**Notable callables** (see `functions/` and `api.md`):

- `createPayment`, payment webhooks / wallet credit
- Rates (`getBinanceRates` and related)

Rules: `database.rules.json`, `firestore.rules`, [SECURITY_RULES_SETUP.md](./SECURITY_RULES_SETUP.md).

---

## Payment System

### Fiat checkout

- African currencies → **Paystack**
- USD / GBP / EUR and other non-African → **Transak**
- Created only via Cloud Functions; the client never writes payment docs for settlement
- Hosted URLs load in-app (`webview_flutter`)

### USD Grid & Crossmint

- Grid: pending order + `fundingPaymentInstructions` (not “payment successful” until funds clear)
- Crossmint: checkout URL and/or `orderId` + `clientSecret`

### Direct fiat & crypto

- Direct deposit flow still exists in the top-up feature
- Country / currency catalog: `TopupDepositCountry` plus live `GET /api/countries`
- Deposit picker currently allows KES, ETB, and non-African codes (AED excluded)

### Kenya pay & payouts

Historical order tracking is API-backed (`transactionsApi` / payout endpoints), not client-written wallet nodes.

---

## Wallet System

**Account payload (simplified)** from `GET /api/accounts`:

```json
{
  "success": true,
  "data": {
    "fiat": { "KES": { "balance": 0.0, "currency": "KES" } },
    "crypto": { "USDC": { "balance": 0.0, "currency": "USDC" } }
  }
}
```

Client APIs: `WalletRepository.fetchAccounts`, streams via Riverpod refresh — not RTDB `wallet/{userId}/fiat/{currency}` in this app version. All balance mutations are server-side.

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
./scripts/build_web.sh --deploy   # build + firebase hosting deploy
```

This builds a release PWA with Flutter’s offline-first service worker, branded splash (`web/index.html`), and SafariTap manifest/icons. Hosting cache headers live in `firebase.json`.

### Mobile release builds

```bash
./scripts/build_android_apk.sh              # release APK → dist/android/
./scripts/build_android_apk.sh --split-per-abi
./scripts/build_android_appbundle.sh        # Play Store AAB
./scripts/build_ios.sh                      # signed IPA (macOS + Xcode signing)
./scripts/build_ios.sh --no-codesign        # unsigned iOS build
./scripts/build_all.sh                      # android + web + ios (when available)
```

Artifacts are copied under `dist/{android,ios,web}`.

Payment provider credentials, Circle, and C2B keys belong in Cloud Functions config / secrets / Remote Config — not in the Flutter client.

---

## Development Guidelines

- **Features** own their screens, models, providers, and feature services
- **Files** `snake_case.dart` · **Classes** `PascalCase` · **members** `camelCase`
- Prefer `walletAccountsProvider` + `WalletBalanceRefresh` for wallet UI; cache short-lived dashboard data via `DashboardSessionCache`
- Log with `Logger` (`debug` / `info` / `warning` / `error` / `success`)
- Do not write wallet balances or payment settlement from the client
- Do not treat Grid/USD instruction screens as a completed payment (`isPaymentSettled` stays false while `pending`)

---

## Security

1. Wallet and payment writes blocked for clients (rules + Functions)
2. Callable and HTTP APIs require Firebase Auth (Bearer ID token)
3. Biometric login stores credentials in platform secure storage
4. Hosted checkout, Grid orders, Crossmint, Circle, and payouts run server-side
5. Optional C2B envelope encryption (`X-TruePay-Encrypted`) for HTTP JSON

---

## API Integration

Full reference: **[api.md](./api.md)**.

**Cloud Functions HTTP base** (from `CloudFunctionsApiConfig`):

```
https://us-central1-<project-id>.cloudfunctions.net/api
https://us-central1-<project-id>.cloudfunctions.net/cryptoApi
https://us-central1-<project-id>.cloudfunctions.net/transactionsApi
https://us-central1-<project-id>.cloudfunctions.net/safariCardApi
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

- Android (`minSdk` 23 via launcher-icons config; `compileSdk` 36)
- iOS
- Web
- Windows / macOS / Linux

Bundle ID: `com.truepay.safaritap`.

---

## Testing

```bash
flutter test
flutter analyze
```

Notable unit coverage: `test/create_payment_result_test.dart` (Paystack hosted URL, Grid USD instructions, Crossmint secrets).

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

- **1.0.3000+35** — SafariTap: Riverpod session/flows, HTTP accounts, Paystack/Transak WebView, Grid USD instructions, Crossmint, Kenya pay/QR, safariCard payouts, USDC deposit watch, transactions API, C2B encryption, force update, Safari AI, Inter theme

---

Built with Flutter and Firebase
