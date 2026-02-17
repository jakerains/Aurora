# Aurora Studio

Aurora Studio is a native macOS image generation app built with SwiftUI and OpenRouter.

## Highlights

- Native SwiftUI on macOS 26+
- System-first Liquid Glass UX (`glassEffect`, `GlassEffectContainer`, `.glass`, `.glassProminent`)
- Direct OpenRouter integration via REST (`/models`, `/chat/completions`, OAuth PKCE endpoints)
- Single active generation queue with streaming UI snapshots
- Local encrypted image blob storage and Keychain credential handling
- SwiftData metadata for projects/history/assets
- Internal TypeScript tooling to sync popular model seeds using `@openrouter/sdk`

## Run

```bash
swift run
```

## Test

```bash
swift test
```

## OpenRouter setup

1. Launch app and paste your OpenRouter API key in onboarding, or use OAuth PKCE mode.
2. Optional: set OAuth bootstrap key when using OAuth code creation/exchange in-app.

## Refresh popular model seed (internal tooling)

```bash
cd tools/openrouter-sync
npm install
OPENROUTER_API_KEY=sk-or-v1-... npm run sync
```

## Notarization notes

A starter script is included at `scripts/notarize-dmg.sh`.
Update your Apple developer credentials and app identifiers before use.
