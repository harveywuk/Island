pragma Singleton
pragma ComponentBehavior: Bound

// The computer's battery as a Live Activity (crates/shoji-island/src/island/battery.rs).
// Low at 20% and not charging (orange), red from 10%; plugging the charger in
// shows "Charging" for a moment (4 s, mod.rs:1115 ALERT_MS) and only then.
// Scope of this port: UPower's display device only (no BlueZ devices, no
// "other batteries" footer line).

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs

Singleton {
    id: root

    // battery.rs:37-38
    readonly property real lowLevel: Theme.batteryLow
    readonly property real nearlyEmptyLevel: Theme.batteryNearlyEmpty
    // mod.rs:1115 ALERT_MS
    readonly property int chargingMs: Motion.alertMs
    // battery.rs:40-42
    readonly property color green: Theme.batteryGreen
    readonly property color orange: Theme.batteryOrange
    readonly property color red: Theme.batteryRed

    readonly property var device: UPower.displayDevice

    // A laptop battery we can read. VERIFY: `ready` and `isLaptopBattery` on
    // UPowerDevice (documented in Quickshell 0.1+).
    readonly property bool present: device !== null && device.ready && device.isLaptopBattery

    // VERIFY: Quickshell's UPowerDevice.percentage is documented as 0-1; older
    // builds passed UPower's 0-100 through. Normalise either way.
    readonly property real percentage: {
        if (!present)
            return 0;
        const p = device.percentage;
        return Math.max(0, Math.min(1, p > 1 ? p / 100 : p));
    }
    // Whole percent, as the card and ring show it.
    readonly property int percent: Math.round(percentage * 100)

    // battery.rs computer_charging: charging, not merely plugged in and full.
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging
    readonly property bool pluggedIn: present && (device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.FullyCharged
        || device.state === UPowerDeviceState.PendingCharge)

    // battery.rs subject(): <= LOW and not charging.
    readonly property bool low: present && !pluggedIn && percentage <= lowLevel
    readonly property bool nearlyEmpty: low && percentage <= nearlyEmptyLevel

    // True for 4 s after the charger goes in (never at startup).
    property bool showCharging: false

    // The battery activity is up: the charging moment, or running low.
    readonly property bool active: showCharging || low

    // battery.rs Battery::colour / title / glyph
    readonly property color colour: showCharging ? green : (nearlyEmpty ? red : orange)
    readonly property string title: showCharging ? "Charging" : "Low Battery"
    readonly property string name: "Computer"
    // bolt.svg is from crates/shoji-island/assets/assets/widgets/, laptop.svg from …/island/.
    readonly property string icon: Quickshell.shellDir + "/assets/island/" + (showCharging ? "bolt.svg" : "laptop.svg")

    // Ignore the state UPower reports while the shell starts up.
    property bool primed: false

    onChargingChanged: {
        if (charging && primed) {
            showCharging = true;
            chargingTimer.restart();
        } else if (!charging) {
            showCharging = false;
            chargingTimer.stop();
        }
    }

    Timer {
        id: primeTimer
        interval: 1500
        running: true
        onTriggered: root.primed = true
    }

    Timer {
        id: chargingTimer
        interval: root.chargingMs
        onTriggered: root.showCharging = false
    }
}
