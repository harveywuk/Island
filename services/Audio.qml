pragma Singleton
pragma ComponentBehavior: Bound

// The default output (and input) through PipeWire; the Island is the
// volume OSD (notices.rs:174-178, :282-290, :417-448).
// - volume change   -> Notices "volume"  (1500 ms) with the level
// - output muted    -> Notices "silent"  (2000 ms), "Silent" in red
// - output unmuted  -> Notices "soundOn" (2000 ms)
// - mic mute toggle -> Notices "generic" (2000 ms, notices.rs:376-383)
// Nothing at startup, and nothing when the default device switches or a
// node becomes ready: those changes only set the baseline.
// Volume, mute and the mic are watched on the same sink (separate settle
// windows per node would be finer; one is enough here).

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

Singleton {
    id: root

    // How long after the default device switches (or turns ready) changes
    // only set the baseline: its parameters land just after.
    readonly property int settleMs: 400

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property bool ready: !!sink && sink.ready && !!sink.audio
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    readonly property bool micMuted: (!!source && source.ready && !!source.audio) ? source.audio.muted : false

    // Baseline: what was last announced (or seen while settling).
    property int _percent: -1
    property bool _muted: false
    property bool _micMuted: false
    property bool _settling: true

    function setVolume(v: real): void {
        if (!root.ready)
            return;
        root.sink.audio.muted = false;
        root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute(): void {
        if (root.ready)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    function toggleMicMute(): void {
        if (root.source && root.source.ready && root.source.audio)
            root.source.audio.muted = !root.source.audio.muted;
    }

    // Binds the nodes so their audio properties are live.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => !!n)
    }

    function _rebase(): void {
        root._percent = Math.round(root.volume * 100);
        root._muted = root.muted;
        root._micMuted = root.micMuted;
        root._settling = true;
        settle.restart();
    }

    onSinkChanged: root._rebase()
    onSourceChanged: root._rebase()
    onReadyChanged: root._rebase()

    onVolumeChanged: {
        const percent = Math.round(root.volume * 100);
        if (root._settling || !root.ready) {
            root._percent = percent;
            return;
        }
        if (percent === root._percent)
            return;
        root._percent = percent;
        Notices.show({
            kind: "volume",
            icon: percent === 0 ? "speaker-slash" : "speaker",
            label: String(percent),
            level: Math.min(1, root.volume)
        });
    }

    onMutedChanged: {
        if (root._settling || !root.ready) {
            root._muted = root.muted;
            return;
        }
        if (root.muted === root._muted)
            return;
        root._muted = root.muted;
        Notices.show(root.muted ? {
            kind: "silent",
            icon: "speaker-slash",
            label: "Silent"
        } : {
            kind: "soundOn",
            icon: "speaker",
            label: "Sound On"
        });
    }

    onMicMutedChanged: {
        if (root._settling) {
            root._micMuted = root.micMuted;
            return;
        }
        if (root.micMuted === root._micMuted)
            return;
        root._micMuted = root.micMuted;
        // notices.rs:376-383 — red when muted.
        Notices.show({
            kind: "generic",
            icon: root.micMuted ? "mic-slash-red" : "mic-fill",
            label: root.micMuted ? "Microphone Muted" : "Microphone On",
            color: root.micMuted ? "#ff453a" : "#ffffff",
            durationMs: 2000
        });
    }

    Timer {
        id: settle

        interval: root.settleMs
        repeat: false
        onTriggered: {
            root._percent = Math.round(root.volume * 100);
            root._muted = root.muted;
            root._micMuted = root.micMuted;
            root._settling = false;
        }
    }

    Component.onCompleted: root._rebase()
}
