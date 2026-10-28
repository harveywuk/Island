# Plan: goo shader, polkit, screenshots (Hyprland)

Base: `quickshell/island/`. New files use `pragma ComponentBehavior: Bound`, the
`targetWidth/targetHeight/targetRadius` view contract and Theme/Motion tokens (new
tokens carry Rust file:line comments). Three parallel packages with disjoint files,
then one integration pass (WP-D). **README.md is owned by WP-D**: each package writes
its user-facing notes to its own `docs/<FEATURE>.md` and WP-D links them.

Tools here: `/usr/lib/qt6/bin/qsb` 6.4.2 and `/usr/lib/qt6/bin/qmllint` 6.4.2
(syntax only; Quickshell types are unknown to it). grim, slurp, wl-copy, hyprctl and
qs are not installed here.

## WP-A  Goo shader

Files: `components/Capsule.qml` (rewrite), `components/Bubble.qml` (edit), new
`components/Liquid.qml`, new `shaders/island-goo.frag` + `shaders/island-goo.frag.qsb`,
`Theme.qml` (add shadow/goo tokens only), `docs/SHADERS.md`.

One `ShaderEffect` (`Liquid.qml`) sized to the envelope, placed first in IslandWindow
(below capsule and bubbles), at window origin; rects are passed in window logical px
(`edge = 0`, since the window starts at the screen edge). It draws fill + key line +
shadow for capsule and bubbles as metaballs, as `island-goo.frag`'s `paint_main`
(crates/shoji-island/assets/src/effect/island-goo.frag; QML wiring reference
mod.rs:9833-10010). `Capsule.qml` drops its fill Rectangle, shadow and key line,
keeping only the mask-clipped content box. `Bubble.qml` keeps its geometry and no
longer draws its own shape. Input mask unchanged.

Uniforms → QML properties (ShaderEffect maps by name):
- `capsule: vec4` (x,y,w,h window px), `capsuleRadius`
- `leftBubble`, `rightBubble: vec4` (w=0 = absent)
- `leftSmoothness/rightSmoothness` (mod.rs:9877-9881): `2 + 20*travelling`,
  `travelling = amount>0.02 ? (1-amount)*smoothstep(0,.35,amount) : 0`. Add
  `readonly property real reach` to Bubble.qml computed from its presence.
- `edge` = 0, `edgeSmoothness` (mod.rs:9894-9898): expose, default 0; drip animation later.
- `fill, keyLine, rimTop, shadowColor` from Theme. Drop Control Centre menu shadow
  uniforms; hardcode the Island branch.
- `scale` = `Screen.devicePixelRatio`; `p = qt_TexCoord0 * size` in logical px.

GLSL 440: `#version 440`, `layout(location=0) in vec2 qt_TexCoord0; layout(location=0)
out vec4 fragColor; layout(std140, binding=0) uniform buf { mat4 qt_Matrix; float
qt_Opacity; ... }`, premultiplied output × qt_Opacity. Compile:
`/usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o
shaders/island-goo.frag.qsb shaders/island-goo.frag` (fall back to `"300 es,150"` if
100 es fails). `fragmentShader: Qt.resolvedUrl("../shaders/island-goo.frag.qsb")`.
Liquid Glass (needs backdrop capture) is out of scope.

Acceptance: qsb compiles with no warnings; qmllint clean; idle silhouette
160×64 r32, 1 px key line, shadow below; a leaving bubble shows a neck that thins
and breaks; two resting bubbles are separate; ShaderEffect visible only when width>0;
docs/SHADERS.md says how to rebuild the .qsb.

## WP-B  Polkit

Files: new `services/Auth.qml` (Singleton), new `views/AuthExpanded.qml`,
`assets/island/lock.svg` (+ check.svg if missing) copied from
crates/shoji-island/assets/assets/island, `Motion.qml` (add `shakeSeconds`,
`authSuccessHoldMs: 700`), `docs/POLKIT.md`.

API (quickshell master `src/services/polkit/`; confirm against the source on GitHub):
`import Quickshell.Services.Polkit`; `PolkitAgent { path; isRegistered; isActive;
flow: AuthFlow; signal authenticationRequestStarted() }`. `AuthFlow { message,
iconName, actionId, cookie, identities, selectedIdentity, isResponseRequired,
inputPrompt, responseVisible, supplementaryMessage, supplementaryIsError, isCompleted,
isSuccessful, isCancelled, failed; submit(string); cancelAuthenticationRequest();
signals authenticationSucceeded/Failed/RequestCancelled }`. `Identity { id, string,
displayName, isGroup }`.

Auth.qml: wraps PolkitAgent; `registered`, `active`, `message`, `user` (identity
matching `$USER`, else first; polkit.rs:93-102), `typed` (count only; password in a
private property cleared on submit/cancel), `state: "asking"|"checking"|"failed"|
"succeeded"`, `failureText` (supplementaryMessage when error and not "Authentication
failure", else "Incorrect password"), `shakeOffset` (island-motion lib.rs:72-77:
`12*sin(t*8π)*exp(-6t)`, t≤0.5 s, FrameAnimation), functions `type(text)`,
`backspace()`, `submit()`, `cancel()`. Failed: clear, shake. Succeeded: 700 ms then
inactive (mod.rs:4686-4700). Daemon cancel: inactive.

AuthExpanded.qml (auth.rs:23-34, 179-299): 408×160, radius Theme.expandedRadius;
margin 18, top 16, header 48 (40 px circle with lock/check, "Authentication Required"
15/600, message in two 12/400 lines using auth.rs's message_lines(…, 50) logic),
field 34 px r10 `#1affffff` (Qt #AARRGGBB!) with red #ff453a border on failure, dots
20/700, placeholder "Password for {user}", hint right-aligned 140 px; buttons 30 px
pills: Cancel, Authenticate (accent gradient) 13/600. Content `x: Auth.shakeOffset`.
Hidden TextInput, echoMode Password, focus, Return → submit, Escape → cancel; calls
forceActiveFocus() on completion.

Keyboard focus (WP-D wires): `WlrLayershell.keyboardFocus: Auth.active ?
WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None`.

docs/POLKIT.md: one agent per session; disable hyprpolkitagent
(`systemctl --user disable --now hyprpolkitagent.service`, remove `exec-once` lines);
if another agent is registered, `Auth.registered` is false.

Acceptance: qmllint clean; `pkexec true` opens 408×160 prompt; wrong password shakes
and shows the failure; correct shows check then closes after 0.7 s; Escape cancels.

## WP-C  Screenshots

Files: new `services/Capture.qml` (Singleton; IpcHandler target "capture"), new
`views/notices/ScreenshotNotice.qml`, `views/notices/ScreenshotExpanded.qml`, icons
copied from crates/shoji-island/assets/assets/island as needed, `docs/SCREENSHOTS.md`.
Do not edit Theme.qml (use literals with capture.rs refs).

grim + slurp (not ScreencopyView). IPC: `screen()`, `window()`, `portion()`,
`screenCopy()`, `windowCopy()`, `portionCopy()`, `timer(seconds)`; function
`take(mode, copy, timerSeconds)`.
- screen: `grim -o <focused output>` (hyprctl -j monitors, focused)
- portion: `slurp -d -b #00000038 -c #ffffff -s #ffffff12 -w 1` → `grim -g "$region"`
- window: `hyprctl -j clients` filtered to mapped windows on the active workspace(s),
  fed as `"x,y wxh title"` lines to `slurp -r -b #00000000 -B #00000000 -c #7a8eff
  -s #4a5fd738 -w 2` (capture.rs:445-453, 523-542)
- Save to `~/Pictures/Screenshots/Screenshot YYYY-MM-DD at HH.MM.SS.png`
  (`$SHOJI_ISLAND_SCREENSHOTS_DIR` override), unique " (2)" suffix, via a `sh -c`
  wrapper so the PNG never passes through QML. Copy: `grim … - | wl-copy --type image/png`.
- Countdown: per-second generic notice. Shutter: `canberra-gtk-play -i screen-capture`
  (ignore failure). Expose `signal flash()`.
- Outcome → `Notices.show({kind:"screenshot", path, copied, failed, durationMs:5000})`
  (notices.rs:290). Slurp cancelled → nothing.
- Actions: `open(path)` xdg-open; `showInFolder(path)` dbus FileManager1.ShowItems
  else xdg-open parent (file_actions.rs:31-53); `copy(path)` wl-copy; `trash(path)` gio trash.

ScreenshotNotice.qml (notices.rs:684-749): 360×64, padding 18, gap 14, thumbnail
fitted in 96×60 r6 with 1 px #40ffffff border; title 16/600 "Screenshot
Saved/Copied/Failed", detail 13/400; click opens. ScreenshotExpanded.qml: 408 wide,
larger thumbnail + 44 px round buttons Copy / Open / Show in Folder / Delete; Delete
trashes and clears the notice.

Recording (optional, only if time remains): wf-recorder, SIGINT to stop, 3 s
countdown, "recording" activity. Mark as optional in docs.

Acceptance: qmllint clean; `capture screen` saves with that name and shows the
notice 5 s; `portionCopy` puts image/png on the clipboard; Esc in slurp shows
nothing; grim missing → "Screenshot Failed".

## WP-D  Integration (after A–C)

Files: `shell.qml`, `components/IslandWindow.qml`, `services/Notices.qml`, README.md,
docs/PORT-PLAN.md status.
1. IslandWindow: Liquid as first child bound to capsule and bubble rects/reach;
   `property bool keyboardWanted` → WlrLayershell.keyboardFocus.
2. shell.qml: Auth.active outranks everything → AuthExpanded (open, no hover
   close, close when inactive); kind "screenshot" → ScreenshotNotice /
   ScreenshotExpanded when expanded; touch Auth and Capture in onCompleted; flash.
3. Notices.qml accepts kind "screenshot" with 5000 ms.
4. README: link docs/SHADERS.md, POLKIT.md, SCREENSHOTS.md; update ported list.
