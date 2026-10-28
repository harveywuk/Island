# Polkit: the password prompt in the Island

The Island is the session's polkit agent. When an app asks polkit for
permission (`pkexec`, a GNOME Settings panel, a package manager, …), the
Island opens to a 408 × 160 prompt in the style of macOS's authentication
sheet: a lock, "Authentication Required" over polkit's message, the password
as dots, and Cancel / Authenticate. A wrong password clears the field, shows
PAM's message (or "Incorrect password") in red and shakes; the right one shows
a check for 0.7 s and closes. Escape cancels.

Port of `crates/shoji-island/src/polkit.rs` and `src/island/auth.rs`.

## Requirements

- **Quickshell 0.3.0 or newer.** `Quickshell.Services.Polkit` first ships in
  v0.3.0 (changelog/v0.3.0.md: "Added support for creating Polkit agents";
  added in commit `db1777c`). Quickshell must be built with polkit support
  (it then links `glib` and `polkit-agent-1`). On older Quickshell, or a build
  without polkit, `import Quickshell.Services.Polkit` fails and so does the
  shell; remove `Auth` from shell.qml in that case.
- polkitd (`polkit` package) running on the system bus, as on any desktop.

## One agent per session

polkit lets exactly one authentication agent serve a session. If another
agent registered first, the Island cannot register and `Auth.registered` is
false (Quickshell logs "failed to register listener"); prompts then come from
the other agent.

On Hyprland the usual other agent is hyprpolkitagent. Turn it off:

```sh
systemctl --user disable --now hyprpolkitagent.service
```

and remove any `exec-once` line that starts an agent from
`~/.config/hypr/hyprland.conf` (hyprpolkitagent, polkit-gnome's
`polkit-gnome-authentication-agent-1`, `polkit-kde-authentication-agent-1`,
lxpolkit, mate-polkit, …). Restart the session (or the Island, `qs -c island`)
afterwards.

Check: `pkexec true` opens the prompt in the Island.

## Behaviour

- One request at a time. Quickshell queues the rest and starts the next when
  the current one ends.
- The identity asked for is `$USER` if polkit offers it, else the first user
  it offers (the Rust picks by uid, polkit.rs:93-102). Groups are skipped.
- The prompt is modal: clicks outside the buttons only refocus the field.
- The password is kept in `Auth` (never in the TextInput), counted for the
  dots, and cleared on submit, failure and close. JS strings cannot be wiped
  in place, so a copy may live in the JS heap until it is collected; the Rust
  zeroes it with `shrink_to_fit`.

## API (`services/Auth.qml`, singleton)

| Member | |
| --- | --- |
| `registered: bool` | this process is the session's agent |
| `active: bool` | the prompt is showing (outlasts the AuthFlow by the 700 ms success hold) |
| `message, user, actionId: string` | polkit's message, the user asked for, the action |
| `typed: int` | characters typed (dots) |
| `state: string` | `"asking"`, `"checking"`, `"failed"`, `"succeeded"` |
| `failureText: string` | what a failure shows |
| `shakeOffset: real` | wrong-password shake, px (bind content `x` to it) |
| `reduceMotion: bool` | set to skip the shake |
| `type(text)`, `backspace()`, `submit()`, `cancel()` | input |

Tokens added to `Motion.qml`: `shakeSeconds` (0.5), `shakeAmplitude` (12),
`authSuccessHoldMs` (700).

## Integration (WP-D)

1. **Instantiate early.** Touch `Auth` in shell.qml's `Component.onCompleted`
   (e.g. `Auth.registered;`) so the agent registers at start-up, not when the
   prompt is first needed.
2. **Precedence.** `Auth.active` outranks everything: show
   `views/AuthExpanded.qml` expanded (its `targetWidth/Height/Radius` are
   408 / 160 / `Theme.expandedRadius`), ignore hover-close, collapse when
   `Auth.active` goes false.
3. **Keyboard.** On the Island's layer surface:

   ```qml
   WlrLayershell.keyboardFocus: Auth.active ? WlrKeyboardFocus.Exclusive
                                            : WlrKeyboardFocus.None
   ```

   (or via IslandWindow's `keyboardWanted`). AuthExpanded calls
   `forceActiveFocus()` on its hidden input on creation and whenever
   `Auth.active` turns true; if the view is created before the window has
   keyboard focus, call `view.focusInput()` once focus arrives.
4. **Input region.** The prompt's buttons must receive clicks: the window's
   input mask must cover the 408 × 160 rect while `Auth.active`.
5. **Assets.** `assets/island/lock.svg` was added (copied from
   crates/shoji-island/assets/assets/island); `check.svg` was already there.

## Not ported

- The Rust's other prompts hosted by the Island (`auth::Prompt`, e.g. a
  service's own credential dialog).
- Cancelling on screen lock (the Rust drops its input grab and cancels); here
  the prompt stays until Escape / Cancel or polkitd cancels it.
- Picking a different identity when polkit offers several (Quickshell
  supports it via `AuthFlow.selectedIdentity`).
