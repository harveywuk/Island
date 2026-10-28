pragma Singleton
pragma ComponentBehavior: Bound

// Screenshots on Hyprland, after macOS's (crates/shoji-island/src/island/
// capture.rs, mod.rs:6780-6862 take_capture / on_capture): the focused
// screen, a window or a portion, saved to ~/Pictures/Screenshots or copied.
// Selecting is slurp, capturing grim, copying wl-copy, all in
// scripts/capture.sh, so no PNG passes through QML and every path, region
// and window title reaches the shell as a positional argument.
//
// A saved, copied or failed shot is kept in `last` and announced with
// Notices.show({kind: "screenshot", path, copied, failed, durationMs: 5000})
// (notices.rs:290). The views (views/notices/Screenshot*.qml) read `last`,
// so they do not depend on Notices passing those fields through. A cancelled
// selection shows nothing (mod.rs:6856).
//
// IPC (target "capture"):
//   qs ipc -c island call capture screen | window | portion
//   qs ipc -c island call capture screenCopy | windowCopy | portionCopy
//   qs ipc -c island call capture timer 5        (the screen, after 5 s)
//   qs ipc -c island call capture take portion false 3
//   qs ipc -c island call capture openLast | showLast | copyLast | trashLast

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    // mod.rs:1068 CAPTURE_DELAY_MS — the countdown leaves the Island before
    // the picture is taken (mod.rs:3437-3447).
    readonly property int captureDelayMs: 350
    // notices.rs:290 — macOS's floating thumbnail stays about five seconds.
    readonly property int noticeMs: 5000
    // A held-open screenshot (ScreenshotExpanded) stays this long after the
    // pointer leaves it (as Notifs.openBannerMs, the banner's 8 s).
    readonly property int openMs: 8000
    readonly property string script: Quickshell.shellDir + "/scripts/capture.sh"

    // A capture in progress (querying, selecting, counting down or grabbing).
    // One at a time, as mod.rs:6796-6800.
    readonly property bool busy: phase !== ""
    // "" | "query" | "select" | "countdown" | "grab"
    property string phase: ""
    // Seconds left while counting down, else 0.
    property int countdown: 0
    // The newest outcome: null or {path, copied, failed, error, at}.
    property var last: null
    // The notice held open (ScreenshotExpanded); WP-D shows it while true.
    property bool open: false

    // The request in flight.
    property var _req: ({
            mode: "screen",
            copy: false,
            timer: 0,
            region: "",
            output: ""
        })

    // The picture is taken: a white flash for the window (optional).
    signal flash()

    // ------------------------------------------------------------ public API

    // mode "screen" | "window" | "portion"; copy puts it on the clipboard;
    // timerSeconds counts down in the Island first (a portion or window is
    // chosen before the countdown, as on macOS, mod.rs:6784).
    function take(mode: string, copy: bool, timerSeconds: int): void {
        if (root.busy)
            return;
        if (mode !== "screen" && mode !== "window" && mode !== "portion")
            return;
        root._req = {
            mode: mode,
            copy: copy,
            timer: Math.max(0, timerSeconds | 0),
            region: "",
            output: ""
        };
        root.phase = "query";
        hypr.running = true;
    }

    function cancel(): void {
        if (root.phase === "countdown" || root.phase === "query") {
            tick.stop();
            delay.stop();
            root.countdown = 0;
            root.phase = "";
        }
    }

    // file_actions.rs / capture.rs:652-665.
    function openFile(path: string): void {
        if (path === "")
            return;
        const opener = Quickshell.env("SHOJI_ISLAND_OPEN");
        root._spawn([opener ? String(opener) : "xdg-open", path]);
    }

    function showInFolder(path: string): void {
        if (path === "")
            return;
        root._spawn(["sh", root.script, "show", root.fileUri(path), root.parentDir(path)]);
    }

    function copyFile(path: string): void {
        if (path === "")
            return;
        root._spawn(["sh", root.script, "copyfile", path]);
    }

    // Moves it to the Trash and lets the notice go.
    function trash(path: string): void {
        if (path === "")
            return;
        root._spawn(["sh", root.script, "trash", path]);
        if (root.last && root.last.path === path) {
            root.last = null;
            root.setOpen(false);
            if (Notices.current && Notices.current.kind === "screenshot")
                Notices.clear();
        }
    }

    // ScreenshotNotice held: open out; ScreenshotExpanded's pointer holds it.
    function setOpen(value: bool): void {
        // Only a saved one has a file to act on.
        root.open = value && root.last !== null && root.last.path !== "";
        if (root.open)
            openTimer.restart();
        else
            openTimer.stop();
    }

    function holdOpen(hovered: bool): void {
        if (!root.open)
            return;
        if (hovered)
            openTimer.stop();
        else
            openTimer.restart();
    }

    // file_actions.rs:55-63 — every byte but A-Z a-z 0-9 - _ . ~ encoded, a
    // segment at a time. Also safe inside dbus-send's comma-split array.
    function fileUri(path: string): string {
        return "file://" + path.split("/").map(part => encodeURIComponent(part).replace(/[!'()*]/g, c => "%" + c.charCodeAt(0).toString(16).toUpperCase())).join("/");
    }

    function parentDir(path: string): string {
        const i = path.lastIndexOf("/");
        return i > 0 ? path.slice(0, i) : "/";
    }

    function fileName(path: string): string {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    // ------------------------------------------------------------- the flow

    function _spawn(command: var): void {
        const p = runner.createObject(root, {
            command: command
        });
        p.running = true;
    }

    // hyprctl -j monitors / clients, split by a record separator.
    function _onHypr(text: string): void {
        const parts = text.split("\x1e");
        let monitors = [];
        let clients = [];
        try {
            monitors = JSON.parse(parts[0]);
        } catch (e) {
            monitors = [];
        }
        try {
            clients = JSON.parse(parts[1] ?? "[]");
        } catch (e) {
            clients = [];
        }
        if (!Array.isArray(monitors))
            monitors = [];
        if (!Array.isArray(clients))
            clients = [];
        const focused = monitors.find(m => m.focused) ?? monitors[0];
        // No hyprctl: grim without -o takes every output (VERIFY).
        root._req.output = focused ? String(focused.name ?? "") : "";
        const mode = root._req.mode;
        if (mode === "screen") {
            root._afterRegion();
            return;
        }
        root.phase = "select";
        select.command = ["sh", root.script, "select", mode, mode === "window" ? root._boxes(monitors, clients) : ""];
        select.running = true;
    }

    // capture.rs:444-453 — mapped windows on the shown workspaces as slurp -r
    // boxes, "x,y wxh title", one a line, the title without control chars.
    // Most recently focused first (VERIFY: which box slurp prefers where
    // windows overlap).
    function _boxes(monitors: var, clients: var): string {
        const shown = new Set();
        for (const m of monitors) {
            if (m.activeWorkspace && m.activeWorkspace.id !== undefined)
                shown.add(m.activeWorkspace.id);
            if (m.specialWorkspace && m.specialWorkspace.id)
                shown.add(m.specialWorkspace.id);
        }
        return clients.filter(c => c.mapped !== false && !c.hidden && c.workspace && shown.has(c.workspace.id) && Array.isArray(c.at) && Array.isArray(c.size) && c.size[0] > 0 && c.size[1] > 0).sort((a, b) => (a.focusHistoryID ?? 0) - (b.focusHistoryID ?? 0)).map(c => Math.round(c.at[0]) + "," + Math.round(c.at[1]) + " " + Math.round(c.size[0]) + "x" + Math.round(c.size[1]) + " " + String(c.title ?? "").replace(/[\x00-\x1f\x7f]/g, "") + "\n").join("");
    }

    function _onSelect(text: string): void {
        const line = text.split("\n")[0];
        const tab = line.indexOf("\t");
        const word = tab < 0 ? line : line.slice(0, tab);
        const rest = tab < 0 ? "" : line.slice(tab + 1);
        if (word === "region" && rest !== "") {
            root._req.region = rest;
            root._afterRegion();
        } else if (word === "failed") {
            root._finish({
                path: "",
                copied: false,
                failed: true,
                error: rest
            });
        } else {
            // Cancelled (Esc in slurp): nothing (mod.rs:6856).
            root.phase = "";
        }
    }

    function _afterRegion(): void {
        if (root._req.timer > 0) {
            root.phase = "countdown";
            root.countdown = root._req.timer;
            root._showCountdown();
            tick.restart();
        } else {
            root._grab();
        }
    }

    // A generic notice each second (timer.svg and the seconds left).
    function _showCountdown(): void {
        Notices.show({
            kind: "generic",
            icon: "timer",
            label: String(root.countdown),
            durationMs: 1300
        });
    }

    function _grab(): void {
        root.phase = "grab";
        grab.command = ["sh", root.script, "grab", root._req.copy ? "1" : "0", root._req.region, root._req.output];
        grab.running = true;
    }

    function _onGrab(text: string): void {
        const line = text.split("\n")[0];
        const tab = line.indexOf("\t");
        const word = tab < 0 ? line : line.slice(0, tab);
        const rest = tab < 0 ? "" : line.slice(tab + 1);
        if (word === "saved" && rest !== "")
            root._finish({
                path: rest,
                copied: false,
                failed: false,
                error: ""
            });
        else if (word === "copied")
            root._finish({
                path: "",
                copied: true,
                failed: false,
                error: ""
            });
        else
            root._finish({
                path: "",
                copied: false,
                failed: true,
                error: rest !== "" ? rest : "the capture did not finish"
            });
    }

    function _finish(shot: var): void {
        root.phase = "";
        root.countdown = 0;
        shot.at = Date.now();
        if (shot.failed)
            console.warn("Capture: could not take a screenshot:", shot.error);
        else {
            // capture.rs:576-595 — the shutter (not with SHOJI_ISLAND_SILENT).
            if (!Quickshell.env("SHOJI_ISLAND_SILENT"))
                root._spawn(["canberra-gtk-play", "-i", "screen-capture", "-d", "Screenshot"]);
            root.flash();
        }
        root.open = false;
        root.last = shot;
        Notices.show({
            kind: "screenshot",
            path: shot.path,
            copied: shot.copied,
            failed: shot.failed,
            durationMs: root.noticeMs
        });
    }

    // ------------------------------------------------------------ processes

    Process {
        id: hypr

        command: ["sh", "-c", "hyprctl -j monitors 2>/dev/null; printf '\\n\\036\\n'; hyprctl -j clients 2>/dev/null"]
        stdout: StdioCollector {
            id: hyprOut

            onStreamFinished: root._onHypr(hyprOut.text)
        }
    }

    Process {
        id: select

        stdout: StdioCollector {
            id: selectOut

            onStreamFinished: root._onSelect(selectOut.text)
        }
        onExited: (code, status) => exitCheck.check("select")
    }

    Process {
        id: grab

        stdout: StdioCollector {
            id: grabOut

            onStreamFinished: root._onGrab(grabOut.text)
        }
        onExited: (code, status) => exitCheck.check("grab")
    }

    // A step whose output never came (sh could not start, a crash): a
    // moment after its process exits, a select is let go and a grab fails,
    // so `busy` cannot stick.
    Timer {
        id: exitCheck

        property string phase: ""

        function check(phase: string): void {
            exitCheck.phase = phase;
            exitCheck.restart();
        }

        interval: 500
        onTriggered: {
            if (root.phase !== exitCheck.phase)
                return;
            if (exitCheck.phase === "grab")
                root._finish({
                    path: "",
                    copied: false,
                    failed: true,
                    error: "the capture did not finish"
                });
            else
                root.phase = "";
        }
    }

    // Fire-and-forget actions (open, show, copy, trash, the shutter); each
    // object goes once its process exits or fails to start.
    Component {
        id: runner

        Process {
            id: proc

            onRunningChanged: {
                if (!proc.running)
                    proc.destroy();
            }
        }
    }

    // The countdown, a second at a time.
    Timer {
        id: tick

        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown > 0) {
                root._showCountdown();
                return;
            }
            tick.stop();
            // The countdown leaves the Island first, so it is not in the picture.
            if (Notices.current && Notices.current.kind === "generic" && Notices.current.icon === "timer")
                Notices.clear();
            delay.restart();
        }
    }

    Timer {
        id: delay

        interval: root.captureDelayMs
        onTriggered: root._grab()
    }

    Timer {
        id: openTimer

        interval: root.openMs
        onTriggered: root.open = false
    }

    IpcHandler {
        target: "capture"

        function screen(): void {
            root.take("screen", false, 0);
        }
        function window(): void {
            root.take("window", false, 0);
        }
        function portion(): void {
            root.take("portion", false, 0);
        }
        function screenCopy(): void {
            root.take("screen", true, 0);
        }
        function windowCopy(): void {
            root.take("window", true, 0);
        }
        function portionCopy(): void {
            root.take("portion", true, 0);
        }
        // The focused screen after `seconds`.
        function timer(seconds: int): void {
            root.take("screen", false, seconds);
        }
        function take(mode: string, copy: bool, seconds: int): void {
            root.take(mode, copy, seconds);
        }
        function cancel(): void {
            root.cancel();
        }
        function openLast(): void {
            if (root.last)
                root.openFile(root.last.path);
        }
        function showLast(): void {
            if (root.last)
                root.showInFolder(root.last.path);
        }
        function copyLast(): void {
            if (root.last)
                root.copyFile(root.last.path);
        }
        function trashLast(): void {
            if (root.last)
                root.trash(root.last.path);
        }
        // "" when idle, else the phase (query, select, countdown, grab).
        function status(): string {
            return root.phase;
        }
    }
}
