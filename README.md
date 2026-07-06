# Notch Apple 🍎✨

Hover the notch on your MacBook and an enchanted golden apple appears in a
dirt-textured tray. Press and hold to eat it (with the real chewing sound).
What happens next depends on the mode — click the Minecraft-style button in
the tray to cycle through them:

- **Particles** — potion swirls rise up your screen
- **Pomodoro** — starts a focus timer (`[-] 25 min [+]` to adjust). A
  potion-effect badge with the countdown shows in the tray; when it ends you
  get the achievement sound and an "Advancement Made!" toast under the notch
- **Blocker** — cold-turkey for social media. While active, landing on
  facebook/instagram/x/tiktok/reddit/youtube in Safari/Chrome/Arc/Brave/Edge
  redirects the tab to a Minecraft "Connection Lost — Disconnected" screen
  served from `127.0.0.1:25565` (yes, the Minecraft server port). Eat the
  apple again to reconnect. The first time it touches a browser, macOS asks
  for automation permission — click OK. No browser extension needed; the app
  polls the frontmost tab via AppleScript once a second.

## Run it

From this folder:

```sh
swift run
```

The app has no Dock icon or menu bar item — it lives in the notch. Move your
mouse into the notch at the top of the screen and the tray opens. Press and
hold the apple for 1.5 s to eat it. **Right-click the tray → Quit Notch
Apple** to quit (or Ctrl-C in the terminal).

## Run it in Xcode

No `.xcodeproj` needed — Xcode opens Swift packages directly:

```sh
open Package.swift
```

Wait for the package to resolve, pick the **NotchApple** scheme (top toolbar,
next to the ▶ button), choose **My Mac** as the destination, and hit **⌘R**.
Set breakpoints, edit, re-run — everything works like a normal app project.

If `xcodebuild` complains that the developer directory points at command line
tools, run once:

```sh
sudo xcode-select -s /Applications/Xcode.app
```

## How the apple video was made

The apple is a real green-screen video (https://www.youtube.com/watch?v=MlGiSrcO52o),
downloaded with `yt-dlp` and chroma-keyed into a transparent ProRes 4444 loop
that AVFoundation plays natively:

```sh
yt-dlp -f "bv*[ext=mp4]/b[ext=mp4]/b" -o raw.mp4 "https://www.youtube.com/watch?v=MlGiSrcO52o"
ffmpeg -t 10 -i raw.mp4 \
  -vf "crop=560:560:680:260,colorkey=0x009600:0.30:0.08,despill=type=green,fps=30,scale=240:240:flags=lanczos" \
  -c:v prores_ks -profile:v 4444 -pix_fmt yuva444p10le -an \
  Sources/NotchApple/Resources/golden_apple.mov
```

(Note: `colorkey`, not `chromakey` — gold is close enough to green in YUV
space that `chromakey` eats the apple itself.)

If the video resource is missing, the app falls back to a built-in 16×16
pixel-art golden apple.

## Layout

- `NotchController.swift` — mouse polling, expand/collapse state machine
- `NotchPanel.swift` — borderless non-activating panel above the menu bar
- `NotchGeometry.swift` — finds the notch via `safeAreaInsets` +
  `auxiliaryTopLeft/RightArea` (fakes one on external displays)
- `TrayView.swift` — the black tray, hint label, right-click menu
- `AppleViews.swift` — video player, pixel-art fallback, press-and-hold logic
- `EffectController.swift` — fullscreen click-through overlay: golden flash,
  purple vignette pulse, CAEmitterLayer potion particles

## Packaging & distribution

```sh
scripts/make-app.sh
```

builds a release binary and wraps it into `dist/NotchApple.app` (ad-hoc
signed) plus `dist/NotchApple.zip`. Drag the app into /Applications; add it to
Login Items to start on boot. Recipients of the zip need to right-click →
Open the first time (ad-hoc signature). For public distribution you need an
Apple Developer ID ($99/yr): `codesign` with the Developer ID cert, then
`xcrun notarytool submit --wait` and `xcrun stapler staple`.

## Landing page

`landing/` is a static Minecraft-themed page (dirt tiles, Monocraft webfont,
transparent VP9 apple video, click sounds). `make-app.sh` output gets copied
in as `NotchApple.zip`. Deploy anywhere static (GitHub Pages, Netlify):
it's self-contained.

## Interaction details

- The apple is the centerpiece of the tray with "hold to eat" right above it.
  Holding sprays Minecraft food crumbs and plays the chewing loop; finishing
  plays the "gulp" and fires the current mode's effect (every mode also shows
  the on-screen potion particles).
- Tray contents only fade in *after* the tray finishes expanding, and fade out
  *before* it collapses (sequenced in `TrayView.setExpanded`).
- **Info** button in the tray opens a how-it-works panel; **Settings** opens
  the blocklist editor.

## The apple video (perfect loop)

`scripts/` and the ffmpeg pipeline pick exactly one rotation of the source so
the loop is seamless (frame-matched: the last frame ≈ the first). It starts on
a bright full-face frame and is colour-graded brighter/golden so there are no
dark or near-invisible moments. See git history / `find_loop.py` approach if
you want to re-derive it from a new source clip.

## Roadmap

- **Ask the Agent** — input box wired to an agent
- Real FOV warp (needs ScreenCaptureKit: capture the screen, re-render with a
  lens distortion shader)
- XP/levels, advancements, more foods (see ideas in project discussions)
