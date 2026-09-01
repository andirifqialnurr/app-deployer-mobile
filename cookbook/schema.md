# Schema: App Deployer Mobile

## Remote Models

The mobile app reads models from the web API.

## MobileApp

Fields:

- `id`
- `name`
- `packageName`
- `description`
- `iconUrl`
- `latestRelease`

## AppRelease

Fields:

- `id`
- `versionName`
- `versionCode`
- `channel`
- `apkObjectKey`
- `apkSizeBytes`
- `apkSha256`
- `changelog`

## Local State

Initial MVP can keep state in memory.

Later local records:

- downloaded release id
- local APK path
- download status
- verified SHA-256
- last checked time

## Install Status

Derived from Android package manager:

- `notInstalled`
- `installed`
- `updateAvailable`
- `sameVersion`
- `downgradeBlocked`

Comparison rule:

```text
server.versionCode > installed.versionCode
```
