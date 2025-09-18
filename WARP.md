# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Pretium is a modern Flutter wallet application with a modular, feature-based architecture. The app includes authentication, financial services, currency swapping, and top-up functionality, with Firebase integration for backend services and payment processing through IntaSend.

## Architecture

### Feature-Based Structure
The codebase follows a feature-based architecture with clear separation of concerns:

- `lib/features/` - Feature modules (auth, home, splash, swap, topup)
- `lib/core/` - Shared constants, widgets, and utilities
- `lib/app/` - App-level configuration and routing
- `lib/models/` - Data models
- `lib/utils/` - Utility functions and services
- `lib/widgets/` - Shared widgets

### Key Architecture Patterns
- **Feature Modules**: Each feature is self-contained with its own screens, widgets, and services
- **Centralized Theming**: Uses Material 3 with a centralized color scheme based on brand primary color (`#0097A7`)
- **Named Routes**: Route management through `RouteNames` class in `app/route_names.dart`
- **Firebase Integration**: Backend services through Firebase Auth and Firestore
- **Stream-based Services**: Reactive programming pattern (e.g., `RatesService` for currency exchange)

### Technology Stack
- **Framework**: Flutter 3.7.0+ with Material 3
- **State Management**: Stateful widgets (ready for Provider/Riverpod/Bloc integration)
- **Backend**: Firebase (Auth, Firestore)
- **Payment**: IntaSend Flutter SDK
- **Navigation**: GetX routing (`get: ^4.7.2`)
- **UI**: Font Awesome Flutter icons, custom themed components

## Development Commands

### Basic Flutter Commands
```bash
# Install dependencies
flutter pub get

# Run the app (development)
flutter run

# Run on specific platform
flutter run -d ios
flutter run -d android
flutter run -d chrome

# Hot restart
flutter run --hot

# Build for release
flutter build apk
flutter build ios
flutter build web
```

### Testing & Quality
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Analyze code for issues
flutter analyze

# Format code
flutter format lib/ test/

# Check for outdated dependencies
flutter pub outdated

# Upgrade dependencies
flutter pub upgrade
```

### Firebase Setup
```bash
# Install Firebase CLI tools (if needed)
npm install -g firebase-tools

# Initialize Firebase (already configured)
firebase login
firebase init
```

### Platform-Specific Commands
```bash
# Generate app icons
flutter pub run flutter_launcher_icons:main

# iOS specific
cd ios && pod install && cd ..

# Android specific - clean build
flutter clean && flutter pub get
```

### Development Tools
```bash
# Run a single widget test
flutter test test/widget_test.dart --plain-name "App loads splash screen"

# Run with specific flavor/environment
flutter run --flavor development
flutter run --dart-define=ENV=dev

# Profile performance
flutter run --profile

# Debug network calls
flutter run --verbose
```

## Key Implementation Details

### Navigation Flow
The app follows this navigation structure:
1. `SplashPage` → Initial app entry point
2. `SplashPage1` → Onboarding/intro screen  
3. `LoginPage`/`RegisterPage` → Authentication flow
4. `LandingPage` → Main dashboard
5. Feature pages (`TopUpPage`, `SwapPage`) → Specific functionalities

### Firebase Integration
- **Authentication**: Email/password and email link sign-in (demo implementation)
- **Firestore**: Document-based data storage
- **Configuration**: Uses platform-specific config files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS)

### State Management Architecture
Currently uses StatefulWidget pattern but structured for easy migration to:
- Provider (recommended for medium complexity)
- Riverpod (recommended for complex state)
- Bloc/Cubit (recommended for enterprise apps)

### Currency Exchange System
- Service-based architecture with `RatesService`
- Stream-based reactive updates for live rates
- Simulated rate updates with NGN/USD pair support
- Ready for integration with real exchange rate APIs

### Theme System
- Material 3 design system
- Brand primary color: `#0097A7` (teal-blue)
- Consistent theming across light/dark modes
- Centralized theme configuration in `main.dart`

### Payment Integration
- **Custom IntaSend HTTP API integration** replaces the problematic `intasend_flutter` plugin
- Direct HTTP API calls to IntaSend checkout endpoints
- Browser-based payment flow using `url_launcher` package
- Modular payment service architecture in `lib/features/topup/services/intasend_service.dart`
- Support for multiple African payment methods

## File Organization Conventions

- **Screens**: Place in `features/{feature}/screens/`
- **Widgets**: Feature-specific in `features/{feature}/widgets/`, shared in `lib/widgets/`
- **Services**: Feature-specific in `features/{feature}/services/`, shared in `lib/utils/`
- **Models**: Global models in `lib/models/`, feature-specific can be in feature directory
- **Constants**: Centralized in `lib/core/constants/`

## Development Guidelines

### Adding New Features
1. Create feature directory in `lib/features/{feature_name}/`
2. Add route in `RouteNames` and `main.dart`
3. Follow existing widget and screen naming conventions
4. Use consistent theming from `Theme.of(context).colorScheme`

### Working with Firebase
- Ensure platform configurations are present before running
- Use `FirebaseAuth.instance` for authentication operations  
- Follow Firebase security rules for Firestore operations
- Test authentication flows thoroughly on both platforms

### Currency/Financial Operations
- Use `RatesService` pattern for exchange rate operations
- Implement proper error handling for payment operations
- Follow financial app security best practices
- Test payment flows in sandbox environments

### UI/UX Consistency  
- Use established color scheme from theme
- Follow Material 3 design principles
- Maintain consistent spacing and typography
- Test on multiple screen sizes and orientations

## Testing Strategy

- **Widget Tests**: Focus on UI component behavior
- **Integration Tests**: Test complete user flows  
- **Unit Tests**: Test business logic and services
- **Platform Tests**: Test Firebase integration and payments

The current test setup includes basic widget testing for app initialization and can be extended for comprehensive test coverage.

## Known Issues & Workarounds

### IntaSend Payment Integration (RESOLVED ✅)
- **Issue**: `intasend_flutter: ^0.0.2` package causes build failures due to dependency on outdated `flutter_webview_plugin: ^0.4.0`
- **Error**: `flutter_webview_plugin` is incompatible with modern Flutter and AndroidX
- **Solution**: Implemented custom HTTP-based IntaSend integration using direct API calls
- **Implementation**: 
  - Custom `IntaSendService` class in `lib/features/topup/services/intasend_service.dart`
  - Uses `http` package for API calls and `url_launcher` for browser-based checkout
  - Supports both sandbox and live environments
  - Maintains the same user experience as the original plugin

### Future Payment Integration Options
- **Stripe Flutter**: `stripe_flutter: ^latest` (recommended)
- **Flutterwave**: `flutterwave_standard: ^latest` (good for African markets)
- **PayPal**: `paypal_flutter: ^latest`
- **Custom API**: Direct HTTP integration with IntaSend REST API
