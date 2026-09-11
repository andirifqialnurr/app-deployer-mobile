# Android Permissions: App Deployer Mobile

App Deployer Mobile is a private APK distribution client. It is not a Play
Store app updater, so Android requires explicit user-facing permissions and
system intents for download, install, open, and uninstall actions.

## Permission summary

| Permission | Why it exists | Current scope |
| --- | --- | --- |
| `INTERNET` | Calls the App Deployer API and downloads release APK files. | Required for all app list, release history, and download flows. |
| `REQUEST_INSTALL_PACKAGES` | Allows App Deployer to ask Android to install or update an APK downloaded outside Google Play. | Used only after the user taps Install or Update, and Android still shows its own install/update confirmation dialog. |
| `REQUEST_DELETE_PACKAGES` | Allows App Deployer to ask Android to uninstall a target app. | Used only after the user taps Uninstall, and Android still shows its own uninstall confirmation dialog. |
| `QUERY_ALL_PACKAGES` | Allows App Deployer to check whether managed apps are installed and compare installed version codes. | Accepted for the private MVP because the managed package list is dynamic and comes from the server. Replace with narrower `<queries>` entries if the managed package set becomes fixed. |
| `POST_NOTIFICATIONS` | Allows Android 13+ devices to show download-complete and failure notifications created by App Deployer. | Requested only when download/install flows need notifications. Android DownloadManager may also show its own system notification. |

## User control and Android confirmation

App Deployer does not silently install, update, or uninstall apps.

- Download starts only after the user taps Install, Update, or Retry.
- Install/update is delegated to Android Package Installer.
- Uninstall is delegated to Android package delete UI.
- Android shows its own confirmation dialog before changing installed apps.

## Package visibility rationale

The app needs to know whether each managed package is:

- not installed;
- installed at the same version;
- installed with an older version and eligible for update;
- installed with a newer version where downgrade should be blocked.

For the private MVP, the server can add package names dynamically, so
`QUERY_ALL_PACKAGES` avoids shipping a new App Deployer build every time a new
managed package is added.

If the project later targets a public app store or a fixed package set, replace
`QUERY_ALL_PACKAGES` with narrower manifest `<queries>` entries for only the
managed package names or the required package intents.

## Download notification rationale

APK downloads can continue while the app is backgrounded. Notifications are
needed so users can see active download state and return to the install action
after completion.

The current implementation prefers Android DownloadManager for the active
download notification because it provides a system-owned progress notification.
App Deployer can still post a custom completion/failure notification when the
system notification is not enough.
