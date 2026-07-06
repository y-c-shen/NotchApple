# Notch Apple 🍎✨

> A Minecraft enchanted golden apple that lives in your MacBook's notch. Hover to open it, press and hold to eat it — for focus, for blocking distractions, or just for the particles.

[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/arch-Apple%20Silicon-black)](https://support.apple.com/en-us/HT211814)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](#license)

Notch Apple turns the black notch at the top of your MacBook into a tiny dirt‑textured tray with an enchanted golden apple inside. Move your mouse into the notch and the tray slides open. Press and hold the apple for ~1.5 seconds to eat it — complete with the real chewing sound — and whatever happens next depends on the mode you've picked.

There's no Dock icon and no menu bar item. The whole app lives in the notch.

---

## Demo

<p align="center">
  <video src="https://github.com/y-c-shen/NotchApple/raw/main/landing/apple.webm" poster="https://github.com/y-c-shen/NotchApple/raw/main/landing/poster.png" autoplay loop muted playsinline width="360">
    <img src="https://github.com/y-c-shen/NotchApple/raw/main/landing/poster.png" alt="Enchanted golden apple demo" width="360">
  </video>
</p>

> If the video doesn't play inline, [click here to watch it](https://github.com/y-c-shen/NotchApple/raw/main/landing/apple.webm).

**Live landing page:** [notch-apple.vercel.app](https://notch-apple.vercel.app)

A self‑contained, Minecraft‑themed landing page lives in [`landing/`](landing/) (dirt tiles, the Monocraft webfont, a transparent apple video, and an interactive hold‑to‑eat hero apple). Open `landing/index.html` in a browser to see the whole loop, or deploy it to any static host (GitHub Pages, Netlify, etc.).

## Features

Click the Minecraft‑style button in the tray to cycle through three modes. The apple remembers your pick.

| Mode | What it does |
| --- | --- |
| **✦ Particles** *(default)* | Eat the apple and Minecraft potion swirls rise across your whole screen with a golden flash. Zero productivity value, maximum joy. |
| **⏳ Pomodoro** | Eat to start a focus timer (`[-] 25 min [+]` to adjust). A potion‑effect badge counts down in the notch; when it ends you get the achievement chime and an "Advancement Made!" toast under the notch. |
| **⛔ Blocker** | Cold‑turkey for social media. While active, landing on facebook / instagram / x / tiktok / reddit / youtube in Safari / Chrome / Arc / Brave / Edge redirects the tab to a Minecraft "Connection Lost — Disconnected" screen served from `127.0.0.1:25565` (yes, the Minecraft server port). Eat the apple again to reconnect. |

> The Blocker needs no browser extension — it polls the frontmost tab via AppleScript once a second. The first time it touches a browser, macOS asks for **Automation** permission; click OK.

## Requirements

- A MacBook **with a notch** (MacBook Pro/Air, 2021 or later)
- **macOS 13 (Ventura)** or newer
- **Apple Silicon**
- To build from source: **Xcode 15+** / Swift 5.9 toolchain

## Installation

### Option 1 — Download the app

1. Grab the latest `NotchApple.zip` from the [**Releases**](https://github.com/y-c-shen/NotchApple/releases) page.
2. Unzip it and drag **Notch Apple.app** into `/Applications`.
3. The build is ad‑hoc signed, so the first launch needs **right‑click → Open** to get past Gatekeeper.
4. (Optional) Add it to **System Settings → General → Login Items** to start on boot.

### Option 2 — Build & run from source

```sh
git clone https://github.com/y-c-shen/NotchApple.git
cd NotchApple
swift run
```

Move your mouse into the notch and the tray opens. **Right‑click the tray → Quit Notch Apple** to quit (or `Ctrl‑C` in the terminal).

### Option 3 — Open in Xcode

No `.xcodeproj` needed — Xcode opens Swift packages directly:

```sh
open Package.swift
```

Wait for the package to resolve, pick the **NotchApple** scheme, choose **My Mac** as the destination, and hit **⌘R**.

If `xcodebuild` complains that the developer directory points at command line tools, run once:

```sh
sudo xcode-select -s /Applications/Xcode.app
```

## Usage

1. **Hover the notch.** The tray slides down and the apple appears.
2. **Choose the effect.** Click the mode button in the tray to cycle Particles → Pomodoro → Blocker.
3. **Press and hold** the apple (~1.5 s). A ring fills as you eat, crumbs fly, and the chewing loop plays. On release, your chosen effect fires.

- The **Info** button in the tray opens a how‑it‑works panel.
- The **Settings** button opens the blocklist editor.

## How it works

The app is a plain SwiftPM executable (`LSUIElement`, so no Dock presence):

| File | Responsibility |
| --- | --- |
| `main.swift` / `AppDelegate.swift` | Entry point and app lifecycle |
| `AppState.swift` | Shared state, current mode, persistence |
| `NotchController.swift` | Mouse polling, expand/collapse state machine |
| `NotchPanel.swift` | Borderless, non‑activating panel above the menu bar |
| `NotchGeometry.swift` | Finds the notch via `safeAreaInsets` + `auxiliaryTopLeft/RightArea` (fakes one on external displays) |
| `TrayView.swift` | The black tray, hint label, right‑click menu, sequenced fade in/out |
| `AppleViews.swift` | Video player, pixel‑art fallback, press‑and‑hold logic |
| `EffectController.swift` | Fullscreen click‑through overlay: golden flash, purple vignette pulse, `CAEmitterLayer` potion particles |
| `Pomodoro.swift` | Focus timer + countdown badge + advancement toast |
| `Blocker.swift` | AppleScript tab polling and the local "Connection Lost" server |
| `SoundPlayer.swift` | Chewing / gulp / achievement / click SFX |
| `MinecraftTheme.swift` | Fonts, colors, pixel styling |
| `InfoWindow.swift` / `SettingsWindow.swift` | Info panel and blocklist editor |

### The apple video

The apple is a real green‑screen clip, chroma‑keyed into a transparent ProRes 4444 loop that AVFoundation plays natively:

```sh
yt-dlp -f "bv*[ext=mp4]/b[ext=mp4]/b" -o raw.mp4 "https://www.youtube.com/watch?v=MlGiSrcO52o"
ffmpeg -t 10 -i raw.mp4 \
  -vf "crop=560:560:680:260,colorkey=0x009600:0.30:0.08,despill=type=green,fps=30,scale=240:240:flags=lanczos" \
  -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le -an \
  Sources/NotchApple/Resources/golden_apple.mov
```

> `colorkey`, not `chromakey` — gold is close enough to green in YUV space that `chromakey` eats the apple itself. The loop is frame‑matched (last frame ≈ first) and color‑graded brighter so there are no dark moments. If the video resource is missing, the app falls back to a built‑in 16×16 pixel‑art golden apple.

## Packaging & distribution

```sh
scripts/make-app.sh
```

builds a release binary and wraps it into `dist/NotchApple.app` (ad‑hoc signed) plus `dist/NotchApple.zip`. Recipients of the zip need to right‑click → Open the first time because of the ad‑hoc signature.

For public, Gatekeeper‑clean distribution you need an Apple Developer ID ($99/yr): `codesign` with the Developer ID cert, then `xcrun notarytool submit --wait` and `xcrun stapler staple`.

## Roadmap

- **Ask the Agent** — input box wired to an agent
- Real FOV warp (needs ScreenCaptureKit: capture the screen, re‑render with a lens‑distortion shader)
- XP / levels, advancements, more foods

## Contributing

Issues and pull requests are welcome. For source layout and build steps, see [How it works](#how-it-works) and [Installation](#installation) above.

## License

Released under the MIT License — do whatever you like, no warranty. (Add a `LICENSE` file if you want the badge above to link to real terms.)

Notch Apple is a fan‑made toy and is **not affiliated with or approved by Mojang, Microsoft, or Apple**. Golden‑apple footage and sound effects belong to their respective owners. The [Monocraft](https://github.com/IdreesInc/Monocraft) font is by IdreesInc (OFL).
