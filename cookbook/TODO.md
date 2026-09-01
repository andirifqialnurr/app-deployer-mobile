# TODO: App Deployer Mobile

## Phase 1: Base Project

- [x] Create Flutter project structure.
- [x] Add Material 3 app shell.
- [x] Add Apps, Downloads, and Settings tabs.
- [x] Add API config through `.env`.
- [x] Add Dio client.
- [x] Add download service.
- [x] Add Android installer MethodChannel.

## Phase 2: API Integration

- [x] Align response parsing with REST API response format.
- [ ] Add latest release endpoint usage.
- [x] Add signed download URL endpoint.
- [x] Add refresh action.
- [x] Refresh app list automatically while Apps page is open.
- [x] Show new/update status on app list.
- [x] Add empty and error states with short text.

## Phase 3: Local Package Checks

- [x] Check installed versionCode by package name.
- [x] Show `Installed`, `Update`, or `Not installed`.
- [x] Block downgrade installs unless user explicitly chooses dev behavior.

## Phase 4: Download UX

- [x] Show download progress.
- [x] Verify APK SHA-256.
- [x] Keep one APK file per release.
- [ ] Add retry for failed downloads.

## Phase 5: Android Install Flow

- [x] Request unknown app install permission when needed.
- [x] Open settings page if install permission is missing.
- [ ] Re-check installed version after returning from installer.

## Phase 6: Release Build

- [ ] Configure stable Android signing.
- [ ] Build release APK.
- [ ] Upload mobile client APK through web dashboard.
