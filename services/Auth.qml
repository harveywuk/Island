pragma Singleton
pragma ComponentBehavior: Bound

// The session's polkit agent: polkit's password prompt as the expanded
// Island. Port of crates/shoji-island/src/polkit.rs (the agent) and
// island/mod.rs on_polkit .. close_auth (:4522-4748), on Quickshell's
// PolkitAgent (Quickshell.Services.Polkit, Quickshell >= 0.3.0).
//
// Rules, as the Rust Island:
// - One request at a time; Quickshell queues the rest and starts the next
//   when this one ends.
// - The identity asked for is the user logged in here ($USER) if polkit
//   offers it, else the first user it offers (polkit.rs:93-102).
// - The password is never exposed: the view shows `typed` dots. It lives in
//   a private property and is cleared on submit, failure and close.
// - Wrong password: the field clears, shows PAM's message (or "Incorrect
//   password") and shakes; typing again goes back to asking (mod.rs:4648-4720).
// - Right password: a check for 700 ms, then the prompt closes (mod.rs:4686-4700).
// - Escape / Cancel, or polkitd cancelling: the prompt closes at once.
//
// For WP-D: `active` true means the prompt owns the Island (show
// AuthExpanded, take the keyboard). It outlasts the AuthFlow by the success
// hold, so bind to Auth.active, not to the agent.

import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import qs

Singleton {
    id: root

    // ---- state -----------------------------------------------------------

    // This process is the session's polkit agent (false when another agent,
    // e.g. hyprpolkitagent, already holds the session).
    readonly property bool registered: agent.isRegistered
    // The prompt is showing.
    property bool active: false
    // polkit's message, and the user whose password is asked for. Kept after
    // the prompt closes so the view can fade out with them.
    property string message: ""
    property string user: ""
    property string actionId: ""
    // How many characters are typed (shown as dots).
    readonly property int typed: root._password.length
    // "asking" | "checking" | "failed" | "succeeded" (auth.rs:44-52).
    property string state: "asking"
    // What a failure shows (auth.rs:194-197): PAM's error, unless it is the
    // generic "Authentication failure".
    property string failureText: ""
    // Horizontal offset of the wrong-password shake (island-motion lib.rs:72-77).
    property real shakeOffset: 0
    // Skip the shake (Settings.reduce_motion in the Rust; mod.rs:4704).
    property bool reduceMotion: false

    // ---- API -------------------------------------------------------------

    // Add typed text (control characters are dropped, auth.rs:162).
    function type(text: string): void {
        if (!root.active || root.state === "checking" || root.state === "succeeded")
            return;
        let clean = "";
        for (const ch of text) {
            const code = ch.codePointAt(0);
            if (code >= 0x20 && code !== 0x7f && !(code >= 0x80 && code < 0xa0))
                clean += ch;
        }
        if (clean === "")
            return;
        root._password += clean;
        if (root.state === "failed")
            root.state = "asking";
    }

    function backspace(): void {
        if (!root.active || root.state === "checking" || root.state === "succeeded")
            return;
        const chars = Array.from(root._password);
        chars.pop();
        root._password = chars.join("");
        if (root.state === "failed")
            root.state = "asking";
    }

    // Check the password (mod.rs:4661-4673). Nothing typed: nothing happens.
    function submit(): void {
        if (!root.active || root._flow === null || root._password === "")
            return;
        if (root.state === "checking" || root.state === "succeeded")
            return;
        root.state = "checking";
        root._pending = true;
        root._respond();
    }

    // Escape / Cancel: polkit hears the request was dismissed.
    function cancel(): void {
        if (!root.active)
            return;
        const flow = root._flow;
        root._close();
        if (flow !== null && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
    }

    // ---- internals -------------------------------------------------------

    // The current AuthFlow. Untyped on purpose: the agent drops its flow the
    // moment the request completes (before authenticationSucceeded), and the
    // old object (deleteLater) is still read once to learn how it ended.
    property var _flow: null
    property string _password: ""
    // A submit waiting for PAM to ask (isResponseRequired).
    property bool _pending: false
    // Changing the identity: the old session's end is not a wrong password.
    property bool _switching: false
    property real _shakeT: 0

    function _respond(): void {
        const flow = root._flow;
        if (!root._pending || flow === null || !flow.isResponseRequired)
            return;
        const password = root._password;
        root._pending = false;
        root._password = "";
        flow.submit(password);
    }

    function _chooseIdentity(flow: var): var {
        const ids = flow.identities ?? [];
        const me = Quickshell.env("USER") ?? "";
        let first = null;
        for (const id of ids) {
            if (id.isGroup)
                continue;
            if (id.string === me)
                return id;
            if (first === null)
                first = id;
        }
        return first ?? (ids.length > 0 ? ids[0] : null);
    }

    function _begin(flow: var): void {
        hold.stop();
        root._stopShake();
        root._password = "";
        root._pending = false;
        root.failureText = "";
        root.state = "asking";
        root.message = flow.message;
        root.actionId = flow.actionId;
        const id = root._chooseIdentity(flow);
        if (id !== null && flow.selectedIdentity !== id) {
            // Restarts the PAM conversation for that identity. Cancelling the
            // old session can report it as a failed attempt; ignore that.
            root._switching = true;
            flow.selectedIdentity = id;
            root._switching = false;
        }
        root.user = id !== null ? (id.string || id.displayName) : "";
        root.active = true;
    }

    function _succeed(): void {
        if (root.state === "succeeded")
            return;
        root._password = "";
        root._pending = false;
        root.state = "succeeded";
        hold.restart();
    }

    function _fail(): void {
        const flow = root._flow;
        const pam = flow !== null && flow.supplementaryIsError ? flow.supplementaryMessage : "";
        root._password = "";
        root._pending = false;
        root.failureText = pam !== "" && pam !== "Authentication failure" ? pam : "Incorrect password";
        root.state = "failed";
        root._startShake();
    }

    function _close(): void {
        hold.stop();
        root._password = "";
        root._pending = false;
        root._stopShake();
        root.active = false;
    }

    function _flowChanged(next: var): void {
        const prev = root._flow;
        root._flow = next;
        if (prev !== null && prev !== next) {
            if (prev.isSuccessful)
                root._succeed();
            else if (root.state !== "succeeded")
                root._close(); // cancelled, by the user or by polkitd
        }
        if (next !== null && next !== prev)
            root._begin(next);
    }

    function _startShake(): void {
        if (root.reduceMotion)
            return;
        root._shakeT = 0;
        shake.restart();
    }

    function _stopShake(): void {
        shake.stop();
        root._shakeT = 0;
        root.shakeOffset = 0;
    }

    // island-motion/src/lib.rs:72-77.
    function shakeAt(t: real): real {
        if (t < 0 || t >= Motion.shakeSeconds)
            return 0;
        return Motion.shakeAmplitude * Math.sin(t * Math.PI * 8) * Math.exp(-t * 6);
    }

    PolkitAgent {
        id: agent
    }

    Connections {
        target: agent
        function onFlowChanged() {
            root._flowChanged(agent.flow);
        }
    }

    Connections {
        target: root._flow
        ignoreUnknownSignals: true

        function onAuthenticationFailed() {
            if (!root._switching)
                root._fail();
        }
        function onAuthenticationSucceeded() {
            root._succeed();
        }
        function onAuthenticationRequestCancelled() {
            if (root.state !== "succeeded")
                root._close();
        }
        function onIsResponseRequiredChanged() {
            const flow = root._flow;
            if (flow === null || !flow.isResponseRequired)
                return;
            if (root._pending)
                root._respond();
            else if (root.state === "checking")
                root.state = "asking"; // a further prompt (a second factor)
        }
    }

    // The check, then close (mod.rs:4686-4700).
    Timer {
        id: hold

        interval: Motion.authSuccessHoldMs
        repeat: false
        onTriggered: root._close()
    }

    FrameAnimation {
        id: shake

        onTriggered: {
            root._shakeT += shake.frameTime;
            if (root._shakeT >= Motion.shakeSeconds || root.reduceMotion) {
                root._stopShake();
                return;
            }
            root.shakeOffset = root.shakeAt(root._shakeT);
        }
    }

    // A flow may already be running when the singleton is first touched.
    Component.onCompleted: {
        if (agent.flow)
            root._flowChanged(agent.flow);
    }
}
