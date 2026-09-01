# PRD: App Deployer Mobile

## Purpose

App Deployer Mobile is an Android client for installing APK updates from the personal App Deployer server.

## Target User

The user is a developer or tester installing private Android apps outside Play Store and DeployGate.

## MVP Goals

- Show available Android apps from the server.
- Show the latest release for each app.
- Compare local installed version with server version.
- Download APK files.
- Open Android Package Installer for install or update.

## Non-Goals

- Silent installation.
- Play Store replacement.
- iOS support.
- Public marketplace discovery.
- Complex tester management.

## Core Flow

1. User opens the mobile client.
2. Client requests app list from the web API.
3. User opens an app detail.
4. Client checks installed package version.
5. If update is available, user downloads APK.
6. Client opens Android Package Installer.
7. User confirms install or update.

## Product Rules

- Never tell the user to uninstall an old app for normal updates.
- Updates require the same package name and signing key.
- The app should keep text short.
- Avoid duplicate screens that show the same app list.

## MVP Acceptance

- App launches with Material 3 UI.
- Apps screen consumes the web API contract.
- Detail screen can start APK download.
- Native Android bridge exposes install and version-check methods.
