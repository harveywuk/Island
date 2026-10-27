# Island → Quickshell port plan

Scope: the Island only. Target: Hyprland + Quickshell (revo-shell's setup), run as
its own Quickshell config next to whatever revo-shell shell is active:
`qs -p quickshell/island` (or symlink to `~/.config/quickshell/island` and `qs -c island`).

## Licence constraint

revo-shell (`vzbc/revo-shell`) has no licence at its root, and neither do
`quickshell/macos` or its bundled `eqsh`. Its `macos` shell also cannot run on its
own: `config/`, `core/foundation`, `modules/settings` and parts of `core/system` are
absolute symlinks into `/home/revo/.config/quickshell/eqsh`. So **no revo-shell file
is copied**. Its QML is API reference only; everything here is written fresh from
the Rust Island in `crates/shoji-island/src/island/`. revo-shell's own
`modules/topbar/DynamicIsland.qml` is not referenced by its `shell.qml`, so it can
be left alone; this Island replaces it in practice.

## Layout

```
quickshell/island/
  shell.qml                 ShellRoot → IslandWindow (+ services instantiated)
  Theme.qml                 pragma Singleton: colours, sizes, fonts (Rust file:line in comments)
  Motion.qml                pragma Singleton: spring params + Bezier curves
  README.md
  services/  Media Notifs Notices Audio Brightness Power Timers Activities   (pragma Singleton each)
  components/ IslandWindow Capsule Bubble ProgressRing Spring Arrival Icon Marquee Waveform
  views/     IdleCompact IdleExpanded NowPlayingCompact NowPlayingExpanded
             TimerCompact TimerExpanded BatteryCompact BatteryExpanded
             notices/{VolumeNotice,SoundNotice,CompactNotice,Banner,BannerExpanded}
  assets/island/*.svg       copied from crates/shoji-island/assets (project's own)
```

Modules: root dir is `qs` (`import qs` gives Theme, Motion), subdirs are
`qs.services`, `qs.components`, `qs.views`, `qs.views.notices`. Every QML file uses
`pragma ComponentBehavior: Bound`.

No custom shaders in this pass (no `qsb` to compile them): goo neck, Liquid Glass and
artwork flow are later. Bubbles are plain circles 8 px from the capsule.

## Shared contract (everyone codes to this)

**Views.** Every view is an `Item` that declares the capsule size it wants:
`property real targetWidth`, `property real targetHeight`, optional
`property real targetRadius` (default `targetHeight / 2`). It fills its parent and
lays out inside that box. Views read services directly.

**IslandWindow** (WP1): `property Component compactView`, `property Component
expandedView`, `property Component noticeView` (null = none), `property var bubbles`
(array of Components, max 2), `readonly property bool expanded`, functions
`open()`, `close()`, `holdOpen(ms)`. It shows `noticeView` if set, else
`expandedView` when expanded, else `compactView`; it springs the capsule to the
shown view's target size and cross-fades content (420 ms handover, arrival lag
60 ms + 8 px drift). Idle views are the fallback when a slot is null.

**Services** (singletons):
- `Media`: `player` (MprisPlayer or null), `active`, `playing`, `position`,
  `length`, `togglePlaying()`, `next()`, `previous()`, `seek(fraction)`.
- `Notifs`: `current` (Notification or null), `queueLength`, `dismiss()`,
  `invokeDefault()`, `pauseExpiry(bool)`.
- `Notices`: `current` (null or `{kind, icon, label, level, durationMs}`),
  `show(obj)`, `clear()`. Kinds: "volume", "brightness", "silent", "soundOn", "generic".
- `Audio`: `volume`, `muted`, `micMuted`; emits Notices on change (not at startup).
- `Brightness`: `level` (0–1), `set(v)`; emits a "brightness" notice on change.
- `Power`: `percentage`, `charging`, `low`, `nearlyEmpty`, `showCharging`
  (true 4 s after charger-in).
- `Timers`: `running`, `paused`, `finished`, `remaining` (s), `total` (s),
  `start(seconds)`, `pause()`, `resume()`, `cancel()`. IPC target "island":
  `timer <seconds>`, `cancelTimer`.
- `Activities`: `list` — ordered array of ids from {"timer","music","battery"};
  first = main, the rest become bubbles.

## Work packages

- WP1 shell/window/capsule/motion/theme/idle views/README/assets.
- WP2 Now Playing: `services/Media.qml`, `components/{Marquee,Waveform}.qml`, `views/NowPlaying*.qml`.
- WP3 notifications & notices: `services/{Notifs,Notices,Audio,Brightness}.qml`, `views/notices/*`.
- WP4 activities: `services/{Power,Timers,Activities}.qml`, `views/{Battery,Timer}*.qml`.
- WP5 integration in `shell.qml`: maps Activities/Notifs/Notices to IslandWindow slots, review pass.

Constants and Rust references: see `Theme.qml` / `Motion.qml` comments.

## Status

- WP1–WP4: done (see each file's header for its Rust references).
- WP5 integration: done. `shell.qml` maps state to the window's slots:
  `Notifs.current` → Banner / BannerExpanded (when `Notifs.open`), else
  `Notices.current` → VolumeNotice (volume, brightness) / SoundNotice
  (silent, soundOn) / CompactNotice (generic); `Activities.main` →
  Timer / NowPlaying / Battery compact and expanded views (null → idle);
  `Activities.bubbles` → `views/bubbles/{Timer,Music,Battery}Bubble.qml`.
  A finished timer forces TimerExpanded and `Timers.alerted` holds the
  Island open for `Motion.alertMs`. Every service singleton is touched at
  startup so the notification server, watchers and IPC targets exist.
  The idle fallbacks are set from `shell.qml` (no qs.components → qs.views
  import). IdleCompact's unread / Do Not Disturb stay false (no centre / DND).
- Review fixes: ProgressRing's `thickness` (views used a non-existent
  `lineWidth` and drew a second track); 8-digit colours written as
  #RRGGBBAA (Qt reads #AARRGGBB) in the banners and volume notice; missing
  `laptop.svg` / `mic-slash-red.svg` copied; explicit `import qs.services`
  in services that use siblings; handover guarded until the window is
  complete; hover no longer opens the Island under a banner; local constants
  that equal Theme / Motion tokens now use them.
- Not run on a real session yet: every `// VERIFY:` is open. qmllint
  (Qt 6.4, no Quickshell types) reports no syntax errors.
