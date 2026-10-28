# shoji-island for Quickshell

The Dynamic Island from [shoji-island](https://github.com/harveywuk/shoji-island)
(`crates/shoji-island/src/island/`, `crates/island-motion`), ported to a standalone [Quickshell](https://quickshell.org)
config (QML, Qt 6). It runs on its own, next to whatever bar or shell you
already use.

## Run

```sh
git clone https://github.com/harveywuk/island ~/.config/quickshell/island
qs -c island
# or run it from anywhere:
qs -p /path/to/island
```

The Island goes on the first screen Quickshell lists. To pick another, name
it: `SHOJI_ISLAND_SCREEN=DP-1 qs -c island`.

Needs **Quickshell 0.3.0 or later** (`Quickshell.Services.Polkit`, built
with polkit support; 0.2 is enough without `services/Auth.qml`, see
[docs/POLKIT.md](docs/POLKIT.md)) on Qt 6.5+ (`QtQuick.Effects`,
`FrameAnimation`).

Screenshots also need `grim`, `slurp`, `wl-clipboard` (`wl-copy`) and
`hyprctl` (Hyprland); the shutter sound uses `canberra-gtk-play`
(libcanberra), optional. Open / Show in Folder / Delete use `xdg-open`,
`dbus-send` and `gio` when present.

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
qs ipc -c island call islandWindow toggle
qs ipc -c island call islandWindow open
qs ipc -c island call islandWindow close
qs ipc -c island call islandWindow holdOpen 4000
qs ipc -c island show          # every target and function
```

The services add their own targets:

```sh
qs ipc -c island call island timer 300      # a 5-minute timer
qs ipc -c island call island cancelTimer
qs ipc -c island call brightness up         # or down, set <percent>, get
qs ipc -c island call capture portion       # screenshots, see below
```

(Bind your brightness keys to `brightness up` / `down` to get the notice at
once; a change made elsewhere shows within the 1.5 s poll.)

### Screenshots

The Island takes screenshots (grim + slurp) and shows macOS's floating
thumbnail; press and hold it for Copy / Open / Show in Folder / Delete.
Bind the keys in `hyprland.conf` (use your own path to this folder):

```ini
bind = , Print, exec, qs ipc -c island call capture portion
bind = SHIFT, Print, exec, qs ipc -c island call capture screen
bind = CTRL, Print, exec, qs ipc -c island call capture portionCopy
# macOS's: Super+Shift+3 screen, 4 portion, 5 window; add Ctrl to copy
bind = SUPER SHIFT, 3, exec, qs ipc -c island call capture screen
bind = SUPER SHIFT, 4, exec, qs ipc -c island call capture portion
bind = SUPER SHIFT, 5, exec, qs ipc -c island call capture window
bind = SUPER CTRL SHIFT, 3, exec, qs ipc -c island call capture screenCopy
bind = SUPER CTRL SHIFT, 4, exec, qs ipc -c island call capture portionCopy
bind = SUPER CTRL SHIFT, 5, exec, qs ipc -c island call capture windowCopy
```

(With `qs -c island`, write `qs ipc -c island call …`.) Saved to
`~/Pictures/Screenshots` (`$SHOJI_ISLAND_SCREENSHOTS_DIR` overrides). The
full call list, the countdown (`capture timer 5`) and the details are in
[docs/SCREENSHOTS.md](docs/SCREENSHOTS.md).

### Password prompts (polkit)

The Island is the session's polkit agent: `pkexec`, Settings panels and
package managers ask for your password in a 408 × 160 prompt in the
Island, which takes the keyboard while it shows. Only one agent can serve a
session, so turn the others off first:

```sh
systemctl --user disable --now hyprpolkitagent.service
```

and remove any `exec-once` line that starts an agent (hyprpolkitagent,
polkit-gnome, polkit-kde, lxpolkit, …). See [docs/POLKIT.md](docs/POLKIT.md).

### The liquid

The capsule and its bubbles are drawn as one liquid shape by a shader
(`shaders/island-goo.frag`, precompiled to `.qsb` and checked in): a bubble
leaving the capsule draws a neck that thins and breaks. To rebuild the
`.qsb` after editing the shader, see [docs/SHADERS.md](docs/SHADERS.md).

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
- The goo: capsule and bubbles as one liquid shape with the key line and
  shadow (`shaders/island-goo.frag`, the Rust's `paint_main`).
- Polkit password prompts (Quickshell 0.3+): wrong-password shake, PAM's
  message, the check on success, Escape cancels.
- Screenshots on Hyprland (grim / slurp / wl-copy): screen, window, portion,
  saved or copied, a countdown, the floating thumbnail and its held-open
  actions, the shutter sound and a white flash.

Not yet:

- Shaders: Liquid Glass (needs a backdrop capture), the artwork flow, the
  liquid's drip from the screen edge.
- A Notification Centre, unread badge and Do Not Disturb (the idle bell /
  moon is wired but always off), notification history.
- Several timers, focus / break timers, Bluetooth batteries, the "other
  batteries" line, the new-song announcement, the Now Playing big card,
  real FFT for the waveform (it is a random walk).
- Bringing a bubble forward by clicking it, indicators (privacy dots,
  Caps Lock), screen recording, the macOS capture toolbar, and the rest that
  needs the compositor (fullscreen tuck, clipboard history).

## Layout

```
shell.qml        ShellRoot: one IslandWindow on the primary screen
Theme.qml        colours, sizes, type (each with its Rust file:line)
Motion.qml       springs, curves, timings (each with its Rust file:line)
components/      IslandWindow Liquid Capsule Bubble ProgressRing Spring Arrival Icon …
views/           IdleCompact IdleExpanded AuthExpanded and the activity views;
                 notices/ (banners, OSD and screenshot notices),
                 bubbles/ (48 px bubble faces)
services/        Media Notifs Notices Audio Brightness Power Timers Activities
                 Auth (polkit) Capture (screenshots)
shaders/         island-goo.frag and its compiled .qsb
scripts/         capture.sh (grim / slurp / wl-copy steps)
assets/island/   the Island's symbols
docs/            PORT-PLAN.md (plan, views' contract), SHADERS.md, POLKIT.md,
                 SCREENSHOTS.md
```

A view is an `Item` with `targetWidth` / `targetHeight` (and optionally
`targetRadius`); `IslandWindow` springs the capsule to the shown view's size
with the Rust's own closed-form spring (`components/Spring.qml`, expand
450 ms / ζ 0.68 growing, collapse 360 ms / ζ 0.86 shrinking) and cross-fades
the content.

Not in this pass: Liquid Glass and the music artwork flow (shaders), and
the fullscreen tuck.

## Licence and credits

Everything here is written fresh from shoji-island's own Rust and design
notes. The SVG symbols in `assets/island/` are copied from
`crates/shoji-island/assets/assets/island` and `…/widgets` (the project's own
artwork); `sun.svg` is `sun-dark.svg` recoloured white.

[revo-shell](https://github.com/vzbc/revo-shell) is the base environment this
targets (Hyprland + Quickshell) and its QML was read as API reference only.
It has no licence, so **no file or code from revo-shell is copied here**.
