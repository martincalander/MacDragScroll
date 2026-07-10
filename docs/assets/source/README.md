# README Demo Sources

The three animated README demos are rendered from `readme-demos.html`. Their
frames are deterministic, fully opaque browser screenshots, which prevents GIF
frame-disposal artifacts from accumulating on GitHub.

Regenerate the assets on macOS with Google Chrome, Node.js, npm, and FFmpeg:

```sh
./scripts/render-readme-demos.sh
```

The renderer pins Playwright, uses the checked-in app icon, writes the three GIF
files to `docs/assets`, and removes its temporary PNG frames when complete.
