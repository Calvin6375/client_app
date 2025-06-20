# Pretium Mock

A modern, modular Flutter wallet app mockup with scalable architecture and clean code practices.

---

## 🚀 Features

- Modular and scalable widget structure
- Custom authentication screens (Login, Register)
- Reusable custom text fields and UI components
- Themed with a consistent primary color
- Example home/dashboard with financial services and transactions
- Ready for advanced state management and navigation

---

## 🏗️ Project Structure

```
lib/
├── features/
│   ├── auth/
│   │   ├── screens/
│   │   │   ├── login_page.dart
│   │   │   └── register_page.dart
│   │   └── widgets/
│   │       ├── custom_text_field.dart
│   │       ├── register_header.dart
│   │       ├── terms_checkbox.dart
│   │       ├── wallet_icon_header.dart
│   │       └── welcome_text_section.dart
│   └── home/
│       ├── screens/
│       │   └── landing_page.dart
│       └── widgets/
│           ├── financial_services.dart
│           ├── header_widget.dart
│           ├── placeholder_transactions.dart
│           ├── recent_transactions_header.dart
│           └── wallet_card.dart
└── main.dart
```

---

## 🛠️ Getting Started

1. **Clone the repository:**

   ```bash
   git clone <your-repo-url>
   cd pretium_mock
   ```

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

---

## 📝 Customization

- **Primary Color:** Change the `primaryColor` constant in your widgets or centralize it in a `theme.dart` file.
- **Add Features:** Extend the modular widget structure for new features or screens.
- **State Management:** Integrate Provider, Riverpod, or Bloc as your app grows.

---

## 📚 Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter Codelabs](https://docs.flutter.dev/get-started/codelab)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)

---
