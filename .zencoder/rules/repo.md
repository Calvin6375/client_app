---
description: Repository Information Overview
alwaysApply: true
---

# Pretium Mock Information

## Summary
A modern, modular Flutter wallet app mockup with scalable architecture and clean code practices. Features include custom authentication screens, reusable UI components, themed design, and example dashboard with financial services and transactions.

## Structure
- **lib/**: Core application code organized in a feature-first architecture
  - **app/**: App configuration and routing
  - **features/**: Feature modules (auth, home, splash)
  - **core/**: Core utilities and constants
  - **models/**: Data models
  - **utils/**: Utility functions
  - **widgets/**: Shared widgets
- **assets/**: Application assets (images)
- **android/**, **ios/**, **web/**, **linux/**, **macos/**, **windows/**: Platform-specific code
- **test/**: Test files

## Language & Runtime
**Language**: Dart
**Version**: SDK ^3.7.0
**Framework**: Flutter
**Package Manager**: pub (Flutter/Dart package manager)

## Dependencies
**Main Dependencies**:
- flutter (SDK)
- cupertino_icons: ^1.0.8
- get: ^4.7.2 (GetX for state management)
- font_awesome_flutter: ^10.8.0
- (Firebase dependencies removed for demo version)
- shared_preferences: ^2.2.2

**Development Dependencies**:
- flutter_test (SDK)
- flutter_lints: ^5.0.0
- flutter_launcher_icons: ^0.13.1

## Build & Installation
```bash
# Install dependencies
flutter pub get

# Run the application
flutter run

# Build for specific platforms
flutter build apk  # Android (requires minSdkVersion 23 for Firebase Auth)
flutter build ios  # iOS
flutter build web  # Web
```

## Android Configuration
- **minSdkVersion**: 23 (required for Firebase Auth)
- **NDK Version**: 26.3.11579264 (compatible with Firebase plugins)
- **Target SDK**: As specified in Flutter configuration

## Testing
**Framework**: flutter_test
**Test Location**: test/
**Naming Convention**: *_test.dart
**Run Command**:
```bash
flutter test
```

## Project Features
- Modular and scalable widget structure
- Custom authentication screens (Login, Register)
- Reusable custom text fields and UI components
- Themed with a consistent primary color
- Example home/dashboard with financial services and transactions
- Email link authentication simulation (demo version)
- GetX for state management and navigation