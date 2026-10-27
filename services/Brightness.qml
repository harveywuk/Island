pragma Singleton
pragma ComponentBehavior: Bound

// The screen's backlight through brightnessctl, as the Rust Island reads and
// sets it (crates/shoji-island/src/controls.rs:171-205):
//   read  `brightnessctl -m -c backlight info` -> "device,class,current,percent%,max"
//   write `brightnessctl -q -c backlight set N%` (never below 1 %)
// Polled, since sysfs backlight files do not notify reliably. A change after
// the first reading shows a "brightness" notice (1500 ms, as the volume's).
// IPC: `qs ipc -p quickshell/island call brightness up|down|set <percent>|get`.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property int pollMs: 1500
    // One key press (as a typical OSD step).
    readonly property int stepPercent: 5

    property real level: 0
    property bool available: false
    property bool _primed: false
    property int _percent: -1
    property var _pendingSet: null

    function set(v: real): void {
        // controls.rs:203 — never fully dark.
        const percent = Math.max(1, Math.round(Math.max(0, Math.min(1, v)) * 100));
        root.level = percent / 100;
        root._announce(percent);
        root._run(["brightnessctl", "-q", "-c", "backlight", "set", percent + "%"]);
    }

    function step(deltaPercent: int): void {
        root.set(root.level + deltaPercent / 100);
    }

    function refresh(): void {
        if (!reader.running)
            reader.running = true;
    }

    function _run(command: var): void {
        if (writer.running) {
            root._pendingSet = command; // the latest wins
            return;
        }
        writer.command = command;
        writer.running = true;
    }

    function _announce(percent: int): void {
        if (percent === root._percent)
            return;
        root._percent = percent;
        if (!root._primed)
            return;
        Notices.show({
            kind: "brightness",
            icon: "",
            label: String(percent),
            level: percent / 100
        });
    }

    function _parse(text: string): void {
        // controls.rs:172-176
        const fields = text.split("\n")[0].split(",");
        const current = parseFloat(fields[2]);
        const max = parseFloat(fields[4]);
        if (!(max > 0) || isNaN(current)) {
            root.available = false;
            return;
        }
        root.available = true;
        const value = Math.max(0, Math.min(1, current / max));
        // A set still on its way: its reading is not news.
        if (writer.running)
            return;
        root.level = value;
        root._announce(Math.round(value * 100));
        root._primed = true;
    }

    Process {
        id: reader

        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            id: readout

            onStreamFinished: root._parse(readout.text)
        }
        onExited: (code, status) => {
            if (code !== 0)
                root.available = false;
        }
    }

    Process {
        id: writer

        onExited: (code, status) => {
            if (root._pendingSet) {
                const next = root._pendingSet;
                root._pendingSet = null;
                root._run(next);
            } else {
                root.refresh();
            }
        }
    }

    Timer {
        interval: root.pollMs
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "brightness"

        function up(): void {
            root.step(root.stepPercent);
        }
        function down(): void {
            root.step(-root.stepPercent);
        }
        function set(percent: int): void {
            root.set(percent / 100);
        }
        function get(): int {
            return Math.round(root.level * 100);
        }
    }
}
