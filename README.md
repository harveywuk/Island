# shoji-island for Quickshell

The Dynamic Island from shoji-island (`crates/shoji-island/src/island/`,
`crates/island-motion`) as a standalone [Quickshell](https://quickshell.org)
config (QML, Qt 6). It runs on its own, next to whatever bar or shell you
already use.

## Run

```sh
qs -p quickshell/island            # from the repository root
# or install it as a named config:
ln -s "$PWD/quickshell/island" ~/.config/quickshell/island
qs -c island
```

The Island goes on the first screen Quickshell lists. To pick another, name
it: `SHOJI_ISLAND_SCREEN=DP-1 qs -p quickshell/island`.

Needs Quickshell 0.2 or later (for `import qs` modules) on Qt 6.5+
(`QtQuick.Effects`, `FrameAnimation`).

### Hyprland

The window is a wlr-layer-shell surface on the **overlay** layer with the
namespace `shoji-island`, anchored to the top edge, reserving
8 + 64 + 12 = 84 px (the Rust's `reserved_top`). Its envelope is 680 px wide
but only the capsule and its bubbles take input. The Island animates itself, so turn
Hyprland's layer animation off for it (this is the pre-0.52 rule syntax; newer
releases spell layer rules differently, see the Hyprland wiki):

```ini
# hyprland.conf
layerrule = noanim, shoji-island
```

If another shell (revo-shell's `DynamicIsland`, a bar) also draws at the top
centre, turn that off or it will sit under the Island.

## Use

- Rest the pointer on it for 110 ms to open it; it closes 180 ms after the
  pointer leaves.
- Click toggles it; press and hold (350 ms) opens it.

### IPC

```sh
qs ipc -p quickshell/island call islandWindow toggle
qs ipc -p quickshell/island call islandWindow open
qs ipc -p quickshell/island call islandWindow close
qs ipc -p quickshell/island call islandWindow holdOpen 4000
qs ipc -p quickshell/island show          # every target and function
```

The services add their own targets:

```sh
qs ipc -p quickshell/island call island timer 300      # a 5-minute timer
qs ipc -p quickshell/island call island cancelTimer
qs ipc -p quickshell/island call brightness up         # or down, set <percent>, get
```

(Bind your brightness keys to `brightness up` / `down` to get the notice at
once; a change made elsewhere shows within the 1.5 s poll.)

## What's ported / what's not yet

Ported:

- The idle Island (time, iOS-style 24 h / 12 h) and the opened clock with the date.
- The capsule's springs (the Rust's closed-form spring, expand / collapse),
  hover lift, hover-to-open, click to toggle, press and hold to open, and the
  content handover (cross-fade with the 60 ms arrival lag, blur and drift).
- Live Activities, ordered as the Rust's `activity.rs` (urgent, just arrived,
  music playing, the rest): one in the capsule, up to two as bubbles beside it.
  - **Now Playing** (MPRIS): artwork, waveform, title / artist marquee,
    progress with scrubbing, previous / play-pause / next; a paused player
    lingers 5 minutes.
  - **Timer**: one countdown from IPC, pause / resume / cancel; at zero it
    plays the "complete" sound and opens on "Timer done" for 4 s.
  - **Battery** (UPower display device): low at 20 %, red at 10 %, "Charging"
    for 4 s when the charger goes in.
- Notification banners (the Island is the notification server): newest
  replaces the one showing, critical ones queue, hover holds, click runs the
  default action, actions as buttons, press and hold opens the full text.
- Notices: volume and brightness (the Island is the OSD, with a draggable
  bar), Silent / Sound On, microphone muted / on.

Not yet:

- Shaders: the goo neck between capsule and bubbles, Liquid Glass, the
  artwork flow (bubbles are plain circles 8 px from the capsule).
- A Notification Centre, unread badge and Do Not Disturb (the idle bell /
  moon is wired but always off), notification history.
- Several timers, focus / break timers, Bluetooth batteries, the "other
  batteries" line, the new-song announcement, the Now Playing big card,
  real FFT for the waveform (it is a random walk).
- Bringing a bubble forward by clicking it, indicators (privacy dots,
  Caps Lock), and anything that needs the compositor (fullscreen tuck,
  screenshots and recording, keyboard grabs, clipboard).

## Layout

```
shell.qml        ShellRoot: one IslandWindow on the primary screen
Theme.qml        colours, sizes, type (each with its Rust file:line)
Motion.qml       springs, curves, timings (each with its Rust file:line)
components/      IslandWindow Capsule Bubble ProgressRing Spring Arrival Icon …
views/           IdleCompact IdleExpanded and the activity views;
                 notices/ (banners, OSD notices), bubbles/ (48 px bubble faces)
services/        Media Notifs Notices Audio Brightness Power Timers Activities
assets/island/   the Island's symbols
docs/PORT-PLAN.md  the port's plan and the views' contract
```

A view is an `Item` with `targetWidth` / `targetHeight` (and optionally
`targetRadius`); `IslandWindow` springs the capsule to the shown view's size
with the Rust's own closed-form spring (`components/Spring.qml`, expand
450 ms / ζ 0.68 growing, collapse 360 ms / ζ 0.86 shrinking) and cross-fades
the content.

Not in this pass: the goo neck between capsule and bubbles, Liquid Glass and
the music artwork flow (they are shaders), and anything that needs the
compositor (fullscreen tuck, screenshots, keyboard grabs).

## Licence and credits

Everything here is written fresh from shoji-island's own Rust and design
notes. The SVG symbols in `assets/island/` are copied from
`crates/shoji-island/assets/assets/island` and `…/widgets` (the project's own
artwork); `sun.svg` is `sun-dark.svg` recoloured white.

[revo-shell](https://github.com/vzbc/revo-shell) is the base environment this
targets (Hyprland + Quickshell) and its QML was read as API reference only.
It has no licence, so **no file or code from revo-shell is copied here**.
