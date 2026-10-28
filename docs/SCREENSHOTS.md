# Screenshots (Hyprland)

macOS-style screenshots for the Quickshell Island, after
`crates/shoji-island/src/island/capture.rs` and `mod.rs:6780-6862`.
Selection is `slurp`, capture is `grim`, copying is `wl-copy`; the focused
screen and the windows come from `hyprctl -j`.

## Needs

`grim`, `slurp`, `wl-clipboard` (`wl-copy`), `hyprctl` (Hyprland). Optional:
`canberra-gtk-play` (shutter sound), `xdg-open`, `dbus-send` (Show in Folder
through the file manager's `org.freedesktop.FileManager1.ShowItems`), `gio`
(Delete moves to the Trash).

## Use

Bind these in `hyprland.conf` (macOS's Super+Shift+3/4, Ctrl to copy):

```ini
bind = SUPER SHIFT, 3, exec, qs ipc -p ~/path/to/quickshell/island call capture screen
bind = SUPER SHIFT, 4, exec, qs ipc -p ~/path/to/quickshell/island call capture portion
bind = SUPER SHIFT, 5, exec, qs ipc -p ~/path/to/quickshell/island call capture window
bind = SUPER CTRL SHIFT, 3, exec, qs ipc -p ~/path/to/quickshell/island call capture screenCopy
bind = SUPER CTRL SHIFT, 4, exec, qs ipc -p ~/path/to/quickshell/island call capture portionCopy
bind = SUPER CTRL SHIFT, 5, exec, qs ipc -p ~/path/to/quickshell/island call capture windowCopy
```

IPC target `capture`:

| call | does |
| --- | --- |
| `screen` / `window` / `portion` | save the focused screen / a chosen window / a dragged portion |
| `screenCopy` / `windowCopy` / `portionCopy` | the same onto the clipboard (image/png) |
| `timer <seconds>` | the focused screen after a countdown in the Island |
| `take <screen\|window\|portion> <true\|false copy> <seconds>` | the general form |
| `cancel` | stop a countdown |
| `openLast` / `showLast` / `copyLast` / `trashLast` | act on the newest saved shot |
| `status` | `""` when idle, else `query` / `select` / `countdown` / `grab` |

Saved to `~/Pictures/Screenshots/Screenshot YYYY-MM-DD at HH.MM.SS.png`
(`$SHOJI_ISLAND_SCREENSHOTS_DIR` overrides the folder); a taken name gets
" (2)", " (3)", …. Esc in slurp cancels and shows nothing. A missing `grim`
(or any failure) shows "Screenshot Failed".

A portion or window is chosen first, then the countdown runs (a generic
notice with the seconds left), then the countdown leaves the Island and the
picture is taken 350 ms later (`mod.rs:1068` CAPTURE_DELAY_MS), so the
countdown is not in it. One capture at a time.

Testing without the real tools: `SHOJI_ISLAND_GRIM`, `SHOJI_ISLAND_SLURP`,
`SHOJI_ISLAND_OPEN`, `SHOJI_ISLAND_TRASH` name stand-ins (as the Rust
Island's tests); `SHOJI_ISLAND_SILENT` mutes the shutter.

## Files

- `services/Capture.qml` — Singleton, IPC target `capture`.
- `scripts/capture.sh` — every shell step; all values are positional
  arguments (paths, regions, window titles are never interpolated into
  a command string). The PNG goes straight from grim to its file or to
  wl-copy, never through QML.
- `views/notices/ScreenshotNotice.qml` — the floating thumbnail notice.
- `views/notices/ScreenshotExpanded.qml` — held open: larger thumbnail and
  Copy / Open / Show in Folder / Delete.
- `assets/island/{screenshot,copy,file,folder,trash}.svg` — from
  `crates/shoji-island/assets/assets/island`.

## Capture API

```
Capture.take(mode: string, copy: bool, timerSeconds: int)   // "screen" | "window" | "portion"
Capture.cancel()
Capture.busy: bool          Capture.phase: string     Capture.countdown: int
Capture.last: null | {path, copied, failed, error, at}
Capture.open: bool          Capture.setOpen(bool)     Capture.holdOpen(hovered: bool)
Capture.openFile(path)      Capture.showInFolder(path)
Capture.copyFile(path)      Capture.trash(path)       // trash also clears last, open and the notice
Capture.fileUri(path)       Capture.fileName(path)    Capture.parentDir(path)
signal Capture.flash()      // a shot was saved or copied
```

On every outcome (not a cancel) Capture calls

```js
Notices.show({kind: "screenshot", path, copied, failed, durationMs: 5000})
```

(`notices.rs:290`: the floating thumbnail stays about five seconds). The
views read `Capture.last`, not `Notices.current`, so they work whether or not
Notices passes `path` / `copied` / `failed` through.

## Integration (WP-D)

1. **Notices.qml** must accept kind `"screenshot"`. As it stands, `show()`
   already keeps `kind` and `durationMs`, which is all the views need. For
   completeness add `"screenshot": 5000` to `durations` and copy
   `path`, `copied`, `failed` into the notice object (default `""`, `false`,
   `false`).
2. **shell.qml**:
   ```qml
   readonly property Component screenshotNotice: Component { ScreenshotNotice {} }
   readonly property Component screenshotExpanded: Component { ScreenshotExpanded {} }
   ```
   In `noticeView`, after the banner check and **before** `Notices.current`
   (the expanded one outlives the notice's 5 s):
   ```js
   if (Capture.open)
       return shell.screenshotExpanded;
   ```
   and in the `switch`: `case "screenshot": return shell.screenshotNotice;`
   (until then a screenshot notice falls to CompactNotice and shows empty).
   Touch `Capture.busy` in `Component.onCompleted` so the IPC target exists
   from the start. Optionally connect `Capture.flash` to a brief white flash.
3. The expanded view handles its own hover (`Capture.holdOpen`): it stays
   while the pointer is on it and closes 8 s after it leaves
   (`Capture.openMs`). A click outside the Island should call
   `Capture.setOpen(false)` if IslandWindow has such a hook.
4. The Island must not take keyboard focus or input over the screen while
   slurp runs (slurp is its own layer surface; nothing to do unless the
   Island grabs input).

## Sizes

ScreenshotNotice is 408 × 84 as the Rust Island (`notices.rs:268`:
`(EXPANDED.0, 84.0)`), not 360 × 64: a 60 px thumbnail needs the 84 px
card. Padding 18, gap 14, thumbnail fitted in 96 × 60, r 6, 1 px `#40ffffff`
edge; title 16/600, detail 13/400; Copied / Failed show the symbol in a 48 px
circle (`#24ffffff`, failed `#33ff453a`). ScreenshotExpanded is 408 wide,
thumbnail fitted in 372 × 200 (r 10), four 44 px round buttons with captions.

## Not done

- **Recording** (optional in the plan; `recording.rs`, wf-recorder, SIGINT
  to stop, 3 s countdown, a "recording" activity) is not ported.
- The macOS toolbar (Super+Shift+5's capture bar and its Options menu,
  `capture.rs:303-407`) is not ported; use the IPC calls.
- The thumbnail's drop shadow (`0 2 8 #00000080`) is left out.
