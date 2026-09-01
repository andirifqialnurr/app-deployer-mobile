# Design System: App Deployer Mobile

## Foundation

The mobile app uses Flutter Material 3.

## Navigation

Use three bottom navigation destinations:

- Apps
- Downloads
- Settings

No additional tab should repeat the app list or release list.

## Layout

- Use standard `Scaffold`, `AppBar`, `NavigationBar`, `Card`, and `ListTile`.
- Keep cards flat with 8px radius.
- Use 16px screen padding.
- Use lists for repeated app or release items.

## Typography

- Page title is one or two words.
- Body copy must be short.
- Long changelog text should be collapsed in a later phase.
- Do not put instructions directly on every screen.

## Color

- Seed color: blue.
- Use Material generated colors.
- Avoid one-tone layouts dominated by a single color.

## Interaction

- Use icons for app, download, settings, update, and install actions.
- Use filled buttons for primary actions.
- Use snackbars only for short status feedback.

## Content Rules

- Apps page shows apps only.
- App detail shows release action only for that app.
- Downloads page shows local download state only.
- Settings page shows configuration only.
