# AGENTS.md

## Aurora Studio Release Workflow

Use this one-command release flow for signed, notarized `.app` output:

```bash
cd /Users/jakerains/Projects/imagegenerator
./scripts/release_app.sh
```

What it does:
1. Builds the app bundle.
2. Signs with `Developer ID Application` identity (auto-detected unless `AURORA_CODESIGN_IDENTITY` is set).
3. Notarizes and staples the app using `notarytool`.
4. Opens the finished app.

Output app path:

```bash
/Users/jakerains/Projects/imagegenerator/dist/AuroraStudio.app
```

## Required one-time setup

Store notary credentials in Keychain (profile name can be reused forever):

```bash
xcrun notarytool store-credentials "AuroraNotary" \
  --apple-id "<your-apple-id-email>" \
  --team-id "47347VQHQV" \
  --password "<app-specific-password>"
```

## Useful options

Build debug and skip notarization:

```bash
./scripts/release_app.sh --debug --skip-notarize
```

Do not auto-open app after completion:

```bash
./scripts/release_app.sh --no-open
```

Use a different notary profile:

```bash
NOTARY_KEYCHAIN_PROFILE="YourProfile" ./scripts/release_app.sh
```

Use an explicit signing identity:

```bash
AURORA_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/release_app.sh
```
