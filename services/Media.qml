pragma Singleton
pragma ComponentBehavior: Bound

// Now Playing's player: which MPRIS player the Island follows, and its state.
// Port of crates/shoji-island/src/media.rs (pick, :496-509) and the paused
// linger in crates/shoji-island/src/island/mod.rs (:175, :1915-1926, :1998-2010).
//
// Active player: the most recent one to start playing that is playing now,
// else the most recent paused one (media.rs:497-500). A paused player keeps
// its place in the Island for 5 minutes from when it was first seen paused,
// then `active` goes false (it is still `player`, so a resume brings it back).

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs

Singleton {
    id: root

    // island/mod.rs:175 PAUSED_LINGER_MS
    readonly property real pausedLingerMs: Motion.pausedLingerMs
    // How often the position is re-read while playing (the times show whole
    // seconds; the 280-wide track moves under 6 px a step at 48 steps).
    readonly property int positionPollMs: 250

    // Bus names, most recently started playing first (media.rs:296). Players
    // never seen playing are appended in the order they appear.
    property var recent: []
    // Bumped on any player's playback-state change so `player` re-picks.
    property int revision: 0

    readonly property MprisPlayer player: {
        root.revision; // dependency
        return root.pick(Mpris.players.values, root.recent);
    }

    readonly property bool playing: root.player !== null && root.player.isPlaying
    readonly property bool paused: root.player !== null && root.player.playbackState === MprisPlaybackState.Paused

    // When the followed player was first seen paused (ms, wall clock), or -1.
    property real pausedSince: -1
    property bool lingerExpired: false

    // Whether Now Playing has a place in the Island now (mod.rs:1998-2010).
    readonly property bool active: root.playing || (root.paused && !root.lingerExpired)

    // Seconds, as Quickshell's MprisPlayer reports them.
    readonly property real position: root.player !== null && root.player.positionSupported ? root.player.position : 0
    readonly property real length: root.player !== null && root.player.lengthSupported ? root.player.length : 0

    readonly property string title: root.player !== null ? (root.player.trackTitle ?? "") : ""
    readonly property string artist: root.player !== null ? (root.player.trackArtist ?? "") : ""
    readonly property string artUrl: root.player !== null ? (root.player.trackArtUrl ?? "") : ""

    readonly property bool canTogglePlaying: root.player !== null && root.player.canTogglePlaying
    readonly property bool canNext: root.player !== null && root.player.canGoNext
    readonly property bool canPrevious: root.player !== null && root.player.canGoPrevious
    // now_playing.rs:452 — seekable only with a known length.
    readonly property bool canSeek: root.player !== null && root.player.canSeek && root.player.positionSupported && root.length > 0
    readonly property bool canRaise: root.player !== null && root.player.canRaise

    function togglePlaying(): void {
        if (root.canTogglePlaying)
            root.player.togglePlaying();
    }

    function next(): void {
        if (root.canNext)
            root.player.next();
    }

    function previous(): void {
        if (root.canPrevious)
            root.player.previous();
    }

    // Play from `fraction` (0..1) of the track (now_playing.rs:90-99).
    function seek(fraction: real): bool {
        if (!root.canSeek)
            return false;
        const f = Math.max(0, Math.min(1, fraction));
        root.player.position = root.length * f; // VERIFY: writable when canSeek && positionSupported (Quickshell docs say so)
        return true;
    }

    // Bring the player's window forward (now_playing.rs:103-109).
    function raise(): bool {
        if (!root.canRaise)
            return false;
        root.player.raise();
        return true;
    }

    // media.rs:500-509: most recent playing, else most recent paused.
    function pick(players: var, order: var): MprisPlayer {
        if (!players || players.length === 0)
            return null;
        const byName = {};
        for (let i = 0; i < players.length; i++)
            byName[players[i].dbusName] = players[i];
        const ordered = [];
        for (let i = 0; i < order.length; i++)
            if (byName[order[i]])
                ordered.push(byName[order[i]]);
        // Anything not yet recorded (a player that appeared this tick) goes last.
        for (let i = 0; i < players.length; i++)
            if (order.indexOf(players[i].dbusName) < 0)
                ordered.push(players[i]);
        for (let i = 0; i < ordered.length; i++)
            if (ordered[i].isPlaying)
                return ordered[i];
        for (let i = 0; i < ordered.length; i++)
            if (ordered[i].playbackState === MprisPlaybackState.Paused)
                return ordered[i];
        return null;
    }

    function noteAdded(name: string, isPlaying: bool): void {
        const list = root.recent.filter(n => n !== name);
        if (isPlaying)
            list.unshift(name);
        else
            list.push(name);
        root.recent = list;
    }

    function noteRemoved(name: string): void {
        root.recent = root.recent.filter(n => n !== name);
    }

    function noteState(name: string, isPlaying: bool): void {
        if (isPlaying && root.recent[0] !== name) {
            const list = root.recent.filter(n => n !== name);
            list.unshift(name);
            root.recent = list;
        }
        root.revision++;
    }

    // mod.rs:1920-1926: paused_since is set the first time the followed
    // player is seen paused, cleared otherwise.
    function updateLinger(): void {
        if (root.paused) {
            if (root.pausedSince < 0) {
                root.pausedSince = Date.now();
                root.lingerExpired = false;
            }
            const left = root.pausedSince + root.pausedLingerMs - Date.now();
            if (left <= 0) {
                root.lingerExpired = true;
                lingerTimer.stop();
            } else if (!lingerTimer.running) {
                lingerTimer.interval = Math.ceil(left);
                lingerTimer.start();
            }
        } else {
            root.pausedSince = -1;
            root.lingerExpired = false;
            lingerTimer.stop();
        }
    }

    onPausedChanged: root.updateLinger()
    onPlayingChanged: root.updateLinger()
    Component.onCompleted: root.updateLinger()

    Timer {
        id: lingerTimer
        repeat: false
        onTriggered: root.updateLinger()
    }

    // Quickshell's position does not update reactively by itself: emit its
    // change signal while playing (documented on MprisPlayer.position).
    Timer {
        interval: root.positionPollMs
        repeat: true
        running: root.playing && root.player !== null && root.player.positionSupported
        triggeredOnStart: true
        onTriggered: root.player.positionChanged() // VERIFY: emitting the NOTIFY signal from QML, as the Quickshell docs suggest
    }

    // One watcher per player: records when each starts playing.
    Instantiator {
        model: Mpris.players // VERIFY: ObjectModel as an Instantiator model with a `modelData` role

        delegate: Connections {
            id: watcher
            required property MprisPlayer modelData
            property string name: ""

            target: watcher.modelData

            function onPlaybackStateChanged(): void {
                root.noteState(watcher.name, watcher.modelData.isPlaying);
            }

            // VERIFY: isPlaying has its own NOTIFY (isPlayingChanged); harmless if it duplicates the above.
            function onIsPlayingChanged(): void {
                root.noteState(watcher.name, watcher.modelData.isPlaying);
            }

            Component.onCompleted: {
                watcher.name = watcher.modelData.dbusName;
                root.noteAdded(watcher.name, watcher.modelData.isPlaying);
            }
            Component.onDestruction: root.noteRemoved(watcher.name)
        }
    }
}
