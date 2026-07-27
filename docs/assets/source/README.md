# README Demo Sources

The three animated README demos are rendered from `readme-demos.html`. Their
frames are deterministic, fully opaque browser screenshots, which prevents GIF
frame-disposal artifacts from accumulating on GitHub.

Regenerate the assets on macOS with Node.js, npm, and FFmpeg:

```sh
./scripts/render-readme-demos.sh
```

The renderer installs Playwright with `npm ci` from the committed lockfile,
installs its matching Chromium build, uses the checked-in app icon, and stages
all three GIF files before atomically replacing the assets in `docs/assets`. It
removes its temporary PNG frames and staged outputs when complete.
