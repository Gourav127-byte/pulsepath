# PulsePath

> **Personal activity tracking, daily scoring, and biometric habit analytics built with Flutter & Riverpod.**

PulsePath is a cross-platform mobile application designed for personal biometric health tracking, activity analytics, and daily consistency scoring. Built with a modular Clean Architecture, it synchronizes device health sensor feeds with deterministic offline-first storage and scheduled notifications.

---

## 🏗️ Architecture & Technical Design

PulsePath follows a strict layered separation of concerns:

```
lib/
├── core/
│   ├── constants/       # App constants, design tokens, endpoints
│   ├── network/         # HTTP client wrappers, error interceptors
│   ├── storage/         # Secure storage & persistent preference adapters
│   └── utils/           # Timezone calculations, metric formatters
├── data/
│   ├── datasources/     # HealthKit/Health Connect integration, local SQLite/Prefs
│   ├── models/          # JSON serialization & schema definitions
│   └── repositories/    # Repository pattern implementations
├── domain/
│   ├── entities/        # Immutable domain objects & business models
│   ├── repositories/    # Abstract repository interfaces
│   └── usecases/        # Encapsulated application business logic
└── presentation/
    ├── providers/       # StateNotifier / Riverpod reactive state providers
    ├── screens/         # Dashboard, activity analytics, profile, auth
    └── widgets/         # Reusable charts, cards, progress rings
```

---

## ⚡ Key Capabilities

- **Biometric Health Sync**: Integrates with Apple HealthKit and Android Health Connect to ingest daily step counts, active calories, and heart rate telemetry.
- **Reactive State Management**: Driven by `flutter_riverpod` for deterministic unidirectional data flow and testable view-models.
- **Secure Credential Storage**: Encrypted token and session storage using `flutter_secure_storage` (Keychain on iOS / Keystore on Android).
- **Scheduled Background Alerts**: Timezone-aware local notifications reminding users to complete daily movement targets.
- **Offline-First Persistence**: Local caching ensures full interface responsiveness without network latency.

---

## 🛠️ Tech Stack

- **Framework**: Flutter (Dart 3.x)
- **State Management**: `flutter_riverpod` (v2.6+)
- **Storage**: `flutter_secure_storage`, `shared_preferences`
- **Sensors & Biometrics**: `health` (HealthKit / Health Connect)
- **Notifications**: `flutter_local_notifications`, `timezone`
- **Code Quality**: `flutter_lints`

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.12+ recommended)
- Android Studio / Xcode configured for mobile development

### Installation & Run

```bash
# 1. Clone the repository
git clone https://github.com/Gourav127-byte/pulsepath.git
cd pulsepath

# 2. Install dependencies
flutter pub get

# 3. Run on connected device or simulator
flutter run
```

### Running Tests
```bash
flutter test
```

---

## 📁 Repository Structure & Documentation

Detailed architecture blueprints and internal audits are maintained in `/docs`:
- [`docs/architecture/`](docs/architecture/) — Authentication flow and data architecture specifications.
- [`docs/reports/`](docs/reports/) — Production gate and permission audit records.

---

## 📄 License
This project is open-source under the MIT License.
