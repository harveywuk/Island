pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.views
import qs.views.notices
import qs.views.bubbles

// The Island, as its own Quickshell config: `qs -p quickshell/island`.
// One Island on the primary screen (the first Quickshell lists, or the one
// named by $SHOJI_ISLAND_SCREEN, e.g. "DP-1").
ShellRoot {
    id: shell

    // VERIFY: Quickshell.env() returns the variable's value, or null when unset.
    readonly property string wantedScreen: Quickshell.env("SHOJI_ISLAND_SCREEN") ?? ""
    readonly property var islandScreens: {
        const screens = Quickshell.screens;
        const named = screens.filter(s => s.name === shell.wantedScreen);
        if (named.length > 0)
            return named;
        return screens.length > 0 ? [screens[0]] : [];
    }

    // ------------------------------------------------------------- the views
    // Made once here and handed to the window's slots; the window's handover
    // compares them by identity, so the same view never cross-fades into
    // itself. The idle ones live here (not in IslandWindow) so qs.components
    // does not import qs.views.
    readonly property Component idleCompact: Component {
        IdleCompact {
            // No Notification Centre in this port: a banner that ends is
            // expired, not kept, so nothing is ever "unread"; and Notifs has
            // no Do Not Disturb yet. Bind these when either lands.
            unread: false
            doNotDisturb: false
        }
    }
    readonly property Component idleExpanded: Component { IdleExpanded {} }

    readonly property Component timerCompact: Component { TimerCompact {} }
    readonly property Component timerExpanded: Component { TimerExpanded {} }
    readonly property Component musicCompact: Component { NowPlayingCompact {} }
    readonly property Component musicExpanded: Component { NowPlayingExpanded {} }
    readonly property Component batteryCompact: Component { BatteryCompact {} }
    readonly property Component batteryExpanded: Component { BatteryExpanded {} }

    readonly property Component timerBubble: Component { TimerBubble {} }
    readonly property Component musicBubble: Component { MusicBubble {} }
    readonly property Component batteryBubble: Component { BatteryBubble {} }

    readonly property Component banner: Component { Banner {} }
    readonly property Component bannerExpanded: Component { BannerExpanded {} }
    readonly property Component volumeNotice: Component { VolumeNotice {} }
    readonly property Component soundNotice: Component { SoundNotice {} }
    readonly property Component compactNotice: Component { CompactNotice {} }
    readonly property Component screenshotNotice: Component { ScreenshotNotice {} }
    readonly property Component screenshotExpanded: Component { ScreenshotExpanded {} }
    // The polkit prompt (docs/POLKIT.md).
    readonly property Component authExpanded: Component { AuthExpanded {} }

    // ------------------------------------------------------- state -> slots
    // The polkit prompt outranks everything (mod.rs:4522-4748: it owns the
    // Island until it closes). Then an app's banner outranks every notice
    // (notices.rs:300-303); Notices already holds its own back while one
    // shows. A held-open screenshot outlives its 5 s notice, so it comes
    // before Notices.current (docs/SCREENSHOTS.md).
    readonly property Component noticeView: {
        if (Auth.active)
            return shell.authExpanded;
        if (Notifs.current !== null)
            return Notifs.open ? shell.bannerExpanded : shell.banner;
        if (Capture.open)
            return shell.screenshotExpanded;
        const notice = Notices.current;
        if (!notice)
            return null;
        switch (notice.kind) {
        case "volume":
        case "brightness":
            return shell.volumeNotice;
        case "silent":
        case "soundOn":
            return shell.soundNotice;
        case "screenshot":
            return shell.screenshotNotice;
        default:
            return shell.compactNotice;
        }
    }

    function compactFor(id: string): Component {
        switch (id) {
        case "timer":
            return shell.timerCompact;
        case "music":
            return shell.musicCompact;
        case "battery":
            return shell.batteryCompact;
        }
        return null;
    }

    function expandedFor(id: string): Component {
        switch (id) {
        case "timer":
            return shell.timerExpanded;
        case "music":
            return shell.musicExpanded;
        case "battery":
            return shell.batteryExpanded;
        }
        return null;
    }

    function bubbleFor(id: string): Component {
        switch (id) {
        case "timer":
            return shell.timerBubble;
        case "music":
            return shell.musicBubble;
        case "battery":
            return shell.batteryBubble;
        }
        return null;
    }

    // Null falls back to the idle views.
    readonly property Component compactView: shell.compactFor(Activities.main)
    // A finished timer opens to "Timer done" whatever else is up (mod.rs:2342-2360).
    readonly property Component expandedView: Timers.finished ? shell.timerExpanded : shell.expandedFor(Activities.main)
    readonly property var bubbleViews: Activities.bubbles.map(id => shell.bubbleFor(id)).filter(c => c !== null)

    Variants {
        id: islands
        model: shell.islandScreens

        IslandWindow {
            required property var modelData
            screen: modelData

            idleCompactView: shell.idleCompact
            idleExpandedView: shell.idleExpanded
            compactView: shell.compactView
            expandedView: shell.expandedView
            noticeView: shell.noticeView
            bubbles: shell.bubbleViews
            // Resting on a banner holds it (Notifs.pauseExpiry), it does not
            // open the Island under it.
            openOnHover: shell.noticeView === null
            // The polkit prompt: the capsule ignores hover-close and taps,
            // and the Island takes the keyboard (AuthExpanded's focusInput()
            // is called once focus arrives).
            modal: Auth.active
            keyboardWanted: Auth.active
        }
    }

    // The prompt gone, the Island goes back to compact (not to whatever
    // the capsule's tap / hover left it at).
    Connections {
        target: Auth
        function onActiveChanged(): void {
            if (Auth.active)
                return;
            for (const w of islands.instances)
                w.close();
        }
    }

    // A shot was taken: a brief white flash over the Island's screen, as
    // macOS's (click-through, no exclusive zone; made only while it shows).
    property real flashOpacity: 0
    NumberAnimation {
        id: flashAnim
        target: shell
        property: "flashOpacity"
        from: 0.6
        to: 0
        duration: 280
        easing.type: Easing.OutCubic
    }
    Connections {
        target: Capture
        function onFlash(): void {
            flashAnim.restart();
        }
    }
    Variants {
        model: shell.flashOpacity > 0 ? shell.islandScreens : []

        PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "shoji-island-flash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            color: "transparent"
            // An empty region: the pointer goes through.
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                color: "white"
                opacity: shell.flashOpacity
            }
        }
    }

    // A timer reaching zero opens the Island on "Timer done" for ALERT_MS
    // (island/mod.rs:1115, :2342-2360).
    Connections {
        target: Timers
        function onAlerted(): void {
            for (const w of islands.instances)
                w.holdOpen(Motion.alertMs);
        }
    }

    // Quickshell creates a singleton on first use. Touch every service at
    // startup so the notification server, the PipeWire / brightness watchers
    // (which raise notices nothing else reads them for) and the IPC targets
    // ("island" in Timers, "brightness" in Brightness, "capture" in Capture)
    // exist from the start, and the polkit agent (Auth) registers at once.
    Component.onCompleted: {
        const services = [Notifs.queueLength, Notices.current, Audio.ready, Brightness.available,
            Media.active, Power.active, Timers.running, Activities.main, Auth.registered, Capture.busy];
        void services;
    }

    // `qs ipc -p quickshell/island call islandWindow toggle` (see README).
    IpcHandler {
        target: "islandWindow"

        function open(): void {
            for (const w of islands.instances)
                w.open();
        }
        function close(): void {
            for (const w of islands.instances)
                w.close();
        }
        function toggle(): void {
            for (const w of islands.instances)
                w.toggle();
        }
        function holdOpen(ms: int): void {
            for (const w of islands.instances)
                w.holdOpen(ms);
        }
    }
}
