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

- [ ] Align response parsing with final tRPC response format.
- [ ] Add latest release endpoint usage.
- [ ] Add signed download URL endpoint.
- [ ] Add refresh action.
- [ ] Add empty and error states with short text.

## Phase 3: Local Package Checks

- [ ] Check installed versionCode by package name.
- [ ] Show `Installed`, `Update`, or `Not installed`.
- [ ] Block downgrade installs unless user explicitly chooses dev behavior.

## Phase 4: Download UX

- [ ] Show download progress.
- [ ] Verify APK SHA-256.
- [ ] Keep one APK file per release.
- [ ] Add retry for failed downloads.

## Phase 5: Android Install Flow

- [ ] Request unknown app install permission when needed.
- [ ] Open settings page if install permission is missing.
- [ ] Re-check installed version after returning from installer.

## Phase 6: Release Build

- [ ] Configure stable Android signing.
- [ ] Build release APK.
- [ ] Upload mobile client APK through web dashboard.
