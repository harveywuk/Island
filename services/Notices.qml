pragma Singleton
pragma ComponentBehavior: Bound

// Brief notices: the Island widens to say something, then returns to what
// it was showing (crates/shoji-island/src/island/notices.rs).
//
// One notice at a time; a new one replaces it and its timer starts again.
// An app's banner outranks every notice (notices.rs:300-303): while
// Notifs.current is set, `current` stays null and the newest notice waits;
// when the banner goes it shows if it is still news (notices.rs:122-133,
// mod.rs:2711-2718). A notice showing when a banner arrives waits the same
// way for what was left of its time. So WP5 can map `current` straight to
// IslandWindow.noticeView, with the banner checked first.
//
// current: null or {kind, icon, label, level, durationMs, color?, width?,
//                   path, copied, failed}
//   kind  "volume" | "brightness" | "silent" | "soundOn" | "generic" | "screenshot"
//   icon  asset name without ".svg" (assets/island), "" for the view's own
//   label text shown (volume/brightness: the percentage)
//   level 0..1 for volume/brightness, else -1
//   color optional label colour ("generic"), width optional capsule width
//   path / copied / failed  a screenshot's outcome (services/Capture.qml;
//         the views read Capture.last, these are for anything else)

import QtQuick
import Quickshell
import qs
import qs.services

Singleton {
    id: root

    // notices.rs:282-290 — how long each kind shows.
    readonly property var durations: ({
            "volume": Motion.volumeNoticeMs,
            "brightness": Motion.volumeNoticeMs,
            "silent": Motion.soundNoticeMs,
            "soundOn": Motion.soundNoticeMs,
            "generic": Motion.soundNoticeMs,
            // notices.rs:290 — the floating thumbnail.
            "screenshot": 5000
        })

    property var current: null
    // {notice, until} — a notice held back by a banner (notices.rs:36-37).
    property var waiting: null

    readonly property bool bannerShowing: Notifs.current !== null

    function show(obj: var): void {
        if (!obj || !obj.kind)
            return;
        const kind = obj.kind;
        const notice = {
            kind: kind,
            icon: obj.icon ?? "",
            label: obj.label ?? "",
            level: obj.level ?? -1,
            durationMs: obj.durationMs ?? (root.durations[kind] ?? 2000),
            color: obj.color ?? "",
            width: obj.width ?? 0,
            path: obj.path ?? "",
            copied: obj.copied ?? false,
            failed: obj.failed ?? false
        };
        if (root.bannerShowing) {
            // A newer one takes the waiting one's place (notices.rs:122-126).
            root.waiting = {
                notice: notice,
                until: Date.now() + notice.durationMs
            };
            return;
        }
        root._present(notice, notice.durationMs);
    }

    function clear(): void {
        timer.stop();
        root.current = null;
        root.waiting = null;
    }

    function _present(notice: var, ms: int): void {
        root.current = notice;
        timer.stop();
        timer.interval = Math.max(1, ms);
        timer.dueAt = Date.now() + timer.interval;
        timer.start();
    }

    onBannerShowingChanged: {
        if (root.bannerShowing) {
            // The banner takes the Island; this notice waits out its time.
            if (root.current) {
                root.waiting = {
                    notice: root.current,
                    until: timer.dueAt
                };
                timer.stop();
                root.current = null;
            }
        } else if (root.waiting) {
            // Still news? A stale one (a level from before) is dropped.
            const w = root.waiting;
            root.waiting = null;
            const left = w.until - Date.now();
            if (left > 0)
                root._present(w.notice, left);
        }
    }

    Timer {
        id: timer

        property real dueAt: 0

        repeat: false
        onTriggered: root.current = null
    }
}
