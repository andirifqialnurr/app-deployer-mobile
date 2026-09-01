# App Deployer Mobile

Flutter Android client for checking, downloading, and installing APK updates from App Deployer Web.

## Local Setup

1. Copy `.env.example` to `.env`.
2. Set `API_BASE_URL`.
3. Install dependencies.

```bash
flutter pub get
flutter run
```

## Android Update Flow

The app downloads an APK, then opens the Android Package Installer. Android still requires the user to approve install or update.
