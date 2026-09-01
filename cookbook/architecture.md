# Architecture: App Deployer Mobile

## System Boundary

```text
Flutter UI
  -> Repository
  -> Dio API Client
  -> App Deployer Web

Flutter UI
  -> Download Service
  -> Local APK File
  -> Installer Service
  -> Android Package Installer

Installer Service
  -> MethodChannel
  -> Kotlin MainActivity
  -> PackageManager and FileProvider
```

## Runtime Components

- Flutter renders Material 3 UI.
- Riverpod provides app config and services.
- Dio performs API and APK download requests.
- Kotlin bridge checks installed package versions.
- Kotlin bridge opens Android Package Installer.

## API Contract

The client starts with:

```text
GET /api/trpc/apps.list
```

Later endpoints should include:

```text
GET /api/apps
GET /api/apps/{packageName}/latest
GET /api/releases/{id}/download-url
```

The exact route can change, but the model fields in `schema.md` should remain stable.

## APK Update Safety

Android preserves app data only when:

- package name is unchanged
- signing key is unchanged
- versionCode is higher than installed version
- user updates without uninstalling

The client should warn only when the APK would be a downgrade or a different package.

## Android Permissions

Required:

- `REQUEST_INSTALL_PACKAGES`

Package visibility:

- `QUERY_ALL_PACKAGES` is currently included for private MVP package checks.
- Later, replace it with narrower `<queries>` entries if the app list is known.
