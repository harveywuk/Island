pragma Singleton
pragma ComponentBehavior: Bound

// App notifications (org.freedesktop.Notifications) as Island banners.
// Port of crates/shoji-island/src/notifications.rs (timeouts, :358-365) and
// island/mod.rs on_notification / end_notice (:2663-2840).
//
// Rules, as the Rust Island:
// - The newest banner replaces the one showing (a burst never queues up),
//   unless the one showing is critical: then a critical one waits its turn in
//   the queue, any other is let go (mod.rs:2817-2833).
// - expire_timeout -1 -> 5 s, 0 -> never, critical -> never, else its own
//   (notifications.rs:360-365).
// - The pointer on the banner holds it: an expiry while held comes back
//   1.5 s later (mod.rs:2673-2678). A banner held open stays at least 8 s
//   (notices.rs:28, mod.rs:2783).
// - A click runs its default action, else dismisses it (notices.rs:913-917).
// There is no Notification Centre in this port, so a banner that times out
// or is displaced is expired (the app hears "expired") instead of kept.
//
// For WP5: `current` non-null means a banner owns the Island; Notices defers
// to it on its own (see Notices.qml). Use Banner when !open, BannerExpanded
// when open.

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

Singleton {
    id: root

    // notifications.rs:363 — expire_timeout -1 (the server's choice).
    readonly property int defaultTimeoutMs: Motion.bannerExpiryMs
    // notices.rs:28 — OPEN_BANNER_MS.
    readonly property int openBannerMs: Motion.openBannerMs
    // mod.rs:2675 — a held banner is looked at again this much later.
    readonly property int holdRecheckMs: 1500

    // The banner showing, or null. Typed, so it resets to null when the
    // server destroys the object.
    property Notification current: null
    // Critical banners waiting behind a critical one (mod.rs:546).
    // A plain array: entries the server has since closed are skipped by
    // _advance (checked against trackedNotifications).
    property var queue: []
    readonly property int queueLength: queue.length
    // The banner held open (press and hold, notices.rs:913-916).
    property bool open: false
    // The pointer is on the banner.
    property bool paused: false

    readonly property bool critical: current !== null && current.urgency === NotificationUrgency.Critical
    // Every notification the server still tracks (for a later centre).
    readonly property var all: server.trackedNotifications

    // ---- API -------------------------------------------------------------

    // Close the banner (the user dismissed it).
    function dismiss(): void {
        const n = root.current;
        root._advance();
        if (n)
            n.dismiss();
    }

    // Its default action, else away (notices.rs:913-917).
    function invokeDefault(): void {
        const n = root.current;
        if (!n)
            return;
        const action = root._action(n, "default");
        if (!action) {
            root.dismiss();
            return;
        }
        root._advance();
        action.invoke();
        // VERIFY: Quickshell dismisses a non-resident notification itself
        // after an action is invoked; if it does not, this closes it.
        if (n && !n.resident && n.tracked)
            n.dismiss();
    }

    // One of its buttons (any action but "default" / "inline-reply").
    function invokeAction(identifier: string): void {
        const n = root.current;
        if (!n)
            return;
        const action = root._action(n, identifier);
        if (!action)
            return;
        root._advance();
        action.invoke();
        // VERIFY: as invokeDefault.
        if (n && !n.resident && n.tracked)
            n.dismiss();
    }

    // The pointer on the banner holds it (mod.rs:2673-2678).
    function pauseExpiry(pause: bool): void {
        root.paused = pause;
    }

    // Press and hold opens the banner out to its whole text; it then stays
    // at least OPEN_BANNER_MS (mod.rs:2783).
    function setOpen(value: bool): void {
        if (root.open === value || (value && !root.current))
            return;
        root.open = value;
        if (value && expiry.running) {
            const left = expiry.dueAt - Date.now();
            if (left < root.openBannerMs)
                root._schedule(root.openBannerMs);
        }
    }

    // The buttons to draw: every action but "default" and inline reply
    // (notifications.rs:93-98). Returns [{identifier, text}].
    function buttons(n: Notification): var {
        if (!n)
            return [];
        const out = [];
        const actions = n.actions;
        for (let i = 0; i < actions.length; i++) {
            const a = actions[i];
            if (a.identifier !== "default" && a.identifier !== "inline-reply")
                out.push({ identifier: a.identifier, text: a.text });
        }
        return out;
    }

    function hasDefault(n: Notification): bool {
        return !!n && root._action(n, "default") !== null;
    }

    // Its timeout in ms, or -1 for never (notifications.rs:360-365).
    function timeoutMs(n: Notification): int {
        if (!n || n.urgency === NotificationUrgency.Critical)
            return -1;
        const t = n.expireTimeout;
        if (t === undefined || t === null || t < 0)
            return root.defaultTimeoutMs;
        if (t === 0)
            return -1;
        // VERIFY: Quickshell documents expireTimeout as a real; if it is in
        // seconds (not the D-Bus milliseconds), small values are scaled.
        return t < 100 ? Math.round(t * 1000) : Math.round(t);
    }

    // A picture for its banner: the image it sent, else its icon (a path or
    // a theme name), else its desktop entry's icon; "" for none (the view
    // then draws the app's initial). notices.rs:808-814, mod.rs:2839-2841.
    function iconSource(n: Notification): string {
        if (!n)
            return "";
        const image = n.image ?? "";
        if (image !== "")
            return root._url(image);
        const icon = n.appIcon ?? "";
        if (icon !== "") {
            if (icon.startsWith("/") || icon.indexOf("://") > 0)
                return root._url(icon);
            // VERIFY: Quickshell.iconPath(name, check) returns "" when the
            // theme has no such icon and check is true.
            const themed = Quickshell.iconPath(icon, true);
            if (themed !== "")
                return themed;
        }
        const entryId = n.desktopEntry ?? "";
        if (entryId !== "") {
            // VERIFY: DesktopEntries.byId exists and returns null if unknown.
            const entry = DesktopEntries.byId(entryId);
            if (entry && entry.icon)
                return Quickshell.iconPath(entry.icon, true);
        }
        return "";
    }

    function _url(path: string): string {
        return path.startsWith("/") ? "file://" + path : path;
    }

    // ---- internals -------------------------------------------------------

    function _action(n: Notification, identifier: string): var {
        const actions = n.actions;
        for (let i = 0; i < actions.length; i++) {
            if (actions[i].identifier === identifier)
                return actions[i];
        }
        return null;
    }

    // VERIFY: ObjectModel exposes its items as `values`.
    function _stillTracked(n: var): bool {
        return !!n && server.trackedNotifications.values.indexOf(n) >= 0;
    }

    function _isCritical(n: Notification): bool {
        return n.urgency === NotificationUrgency.Critical;
    }

    function _present(n: Notification): void {
        root.open = false;
        root.paused = false;
        root.current = n;
        const ms = root.timeoutMs(n);
        if (ms < 0)
            expiry.stop();
        else
            root._schedule(ms);
    }

    function _schedule(ms: int): void {
        expiry.stop();
        expiry.interval = Math.max(1, ms);
        expiry.dueAt = Date.now() + expiry.interval;
        expiry.start();
    }

    // The banner goes; the next critical one waiting comes (mod.rs:2711-2718).
    function _advance(): void {
        expiry.stop();
        root.open = false;
        root.paused = false;
        let next = null;
        const rest = [];
        for (let i = 0; i < root.queue.length; i++) {
            const q = root.queue[i];
            if (!root._stillTracked(q))
                continue; // closed while it waited
            if (next === null)
                next = q;
            else
                rest.push(q);
        }
        root.queue = rest;
        root.current = null;
        if (next)
            root._present(next);
    }

    function _expired(): void {
        const n = root.current;
        if (!n)
            return;
        // A held banner comes back to it (mod.rs:2673-2678).
        if (root.paused) {
            root._schedule(root.holdRecheckMs);
            return;
        }
        root._advance();
        n.expire();
    }

    function _incoming(n: Notification): void {
        // Kept by the server until it closes (else it is dropped at once).
        n.tracked = true;
        const shown = root.current;
        if (shown && root._isCritical(shown)) {
            // A critical banner is never displaced: a critical one waits its
            // turn, the others are let go (mod.rs:2817-2824).
            if (root._isCritical(n))
                root.queue = root.queue.concat([n]);
            else
                n.expire(); // no Notification Centre to keep it in
            return;
        }
        // The newest replaces the one showing (mod.rs:2826-2833).
        root.current = null;
        if (shown)
            shown.expire();
        root._present(n);
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        // Bodies are shown as plain text (notices.rs draws them raw).
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: false

        onNotification: notification => root._incoming(notification)
    }

    // A replacement (same id) updates the object in place; its timeout
    // starts again (mod.rs:2779-2790). The app closing it takes it away.
    // VERIFY: Quickshell updates the existing Notification for replaces_id
    // rather than emitting `notification` again.
    Connections {
        target: root.current
        ignoreUnknownSignals: true

        function onClosed(): void {
            root._advance();
        }
        function onSummaryChanged(): void {
            root._restartForUpdate();
        }
        function onBodyChanged(): void {
            root._restartForUpdate();
        }
    }

    function _restartForUpdate(): void {
        const n = root.current;
        if (!n)
            return;
        let ms = root.timeoutMs(n);
        if (ms < 0) {
            expiry.stop();
            return;
        }
        if (root.open)
            ms = Math.max(ms, root.openBannerMs);
        root._schedule(ms);
    }

    Timer {
        id: expiry

        property real dueAt: 0

        repeat: false
        onTriggered: root._expired()
    }
}
