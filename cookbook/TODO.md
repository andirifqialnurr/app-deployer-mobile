# TODO: App Deployer Mobile

> Current product target: a DeployGate-style app detail and APK delivery flow.

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

## Phase 7: Reliable APK Download

- [x] Use received-byte progress from Dio for the current foreground download.
- [x] Add `INTERNET` permission to the release manifest.
- [ ] Expose received bytes and total bytes instead of passing percentage only.
- [ ] Show a real progress bar, downloaded size, total size, and transfer status.
- [ ] Use `apkSizeBytes` only as a fallback when the response has no `Content-Length`.
- [ ] Move APK downloads to Android `DownloadManager` or a native foreground download service.
- [ ] Show persistent Android notification with real download progress.
- [ ] Support queued, downloading, verifying, completed, failed, cancelled, and expired states.
- [ ] Support retry for failed downloads.
- [ ] Prevent duplicate downloads for the same release.
- [ ] Resume or safely restart an interrupted download.
- [ ] Delete incomplete or hash-mismatched APK files.
- [ ] Persist download jobs so status survives app restart.
- [ ] Verify SHA-256 before opening the installer.

## Phase 8: DeployGate-Style App Detail

- [ ] Redesign the app detail header with app icon, app name, project/package name, version, version code, and upload source.
- [ ] Add primary `Open` action for an installed app.
- [ ] Add `Install` action when the app is not installed.
- [ ] Add `Update` action when a newer release is available.
- [ ] Add `Uninstall` action that opens the Android uninstall confirmation dialog.
- [ ] Add `Open App Info` action that navigates to Android application settings.
- [ ] Handle apps that are not launchable or have no launcher activity.
- [ ] Re-check installed version after returning from install/update flow.
- [ ] Show release changelog and APK size in the detail page.
- [ ] Show download/verification/install status without losing the current release context.

## Phase 9: Revisions

- [ ] Add a revisions section or page to the app detail screen.
- [ ] Load all active releases for the selected app from the web API.
- [ ] Show version name, version code, channel, upload date, APK size, and changelog.
- [ ] Mark the installed release and latest release clearly.
- [ ] Allow downloading/installing a selected revision when it is not a downgrade.
- [ ] Show an explicit downgrade warning when developer behavior allows it.
- [ ] Handle an empty revision list and unavailable revision gracefully.

## Phase 10: Deferred Actions and Android Integration

- [ ] Show a `Coming Soon` dialog when `Distributions` is tapped.
- [ ] Show a `Coming Soon` dialog when `Start Replay Capture` is tapped.
- [ ] Keep these placeholders visible in the app detail layout without starting unfinished flows.
- [ ] Implement Android launch intent for `Open`.
- [ ] Implement `Intent.ACTION_DELETE` for `Uninstall`.
- [ ] Implement `Settings.ACTION_APPLICATION_DETAILS_SETTINGS` for `Open App Info`.
- [ ] Review Android 13+ notification permission for download notifications.
- [ ] Review foreground-service declarations if the chosen downloader requires them.
- [ ] Keep FileProvider authorities and APK paths package-scoped and secure.

## Phase 11: Release Validation and Safety

- [ ] Verify the release APK is non-debuggable and signed by the stable keystore.
- [ ] Verify certificate continuity between bootstrap APK updates.
- [ ] Test install, update, uninstall, and open actions on a physical Android device.
- [ ] Test interrupted download, retry, app restart, and device rotation.
- [ ] Test checksum failure and expired download URL.
- [ ] Review `REQUEST_INSTALL_PACKAGES` and `QUERY_ALL_PACKAGES` against the intended distribution channel.
- [ ] Document why package installation and package visibility permissions are required.
