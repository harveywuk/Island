pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Colours, sizes and type of the Island, written fresh from the Rust Island.
// Paths are relative to crates/shoji-island/src/ unless stated otherwise.
// 1 pt in the Rust = 1 logical px here.
Singleton {
    id: root

    // ---------------------------------------------------------------- colours
    // theme.rs:1721-1731 (IslandMaterial::Black): the iOS Island's black capsule.
    readonly property color surface: "#000000"
    // Labels are GNOME's OSD text (adwaita/mod.rs:110 OSD_FG = white) at the
    // dim / dimmer opacities (adwaita/mod.rs:155, :162).
    readonly property color label: "#ffffff"
    readonly property real dimOpacity: 0.55       // adwaita/mod.rs:155 DIM
    readonly property real dimmerOpacity: 0.30    // adwaita/mod.rs:162 DIMMER
    readonly property color secondaryLabel: Qt.rgba(1, 1, 1, dimOpacity)
    readonly property color tertiaryLabel: Qt.rgba(1, 1, 1, dimmerOpacity)
    // theme.rs:1728 key line (non high-contrast); Qt reads #AARRGGBB, the
    // Rust #RRGGBBAA "#ffffff24" is white at 0x24/0xff.
    readonly property color keyLine: Qt.rgba(1, 1, 1, 0x24 / 255)
    // theme.rs:1730 shadow, dark appearance ("#00000080").
    readonly property color shadow: Qt.rgba(0, 0, 0, 0x80 / 255)
    // island/mod.rs:10011-10018 rim_top: the key line's colour along the
    // top (the Island branch, outside Control Centre: the key line itself).
    readonly property color rimTop: keyLine
    // The shadow's shape (a contact drop and a wider one 8 px lower) is the
    // liquid shader's (shaders/island-goo.frag, from the Rust's
    // assets/src/effect/island-goo.frag paint_main), not tokens here.

    // ------------------------------------------------------------- the goo
    // island/mod.rs:9877-9881 reach(): the smooth-minimum radius joining a
    // bubble to the capsule, rest + travel * travelling (logical px).
    readonly property real gooRestReach: 2
    readonly property real gooTravelReach: 20

    // island/mod.rs:10637 (test): the shell's accent, deep -> light.
    readonly property color accentDeep: "#4a5fd7"
    readonly property color accent: "#7a8eff"   // the light end, used on the dark Island
    // island/mod.rs:1029-1031: privacy colours.
    readonly property color privacyCamera: "#30d158"
    readonly property color privacyMicrophone: "#ff9f0a"
    readonly property color privacyScreen: "#bf5af2"

    // Activity tints.
    readonly property color timerTint: "#ff9f0a"       // island/timer.rs:12
    readonly property color focusTint: "#7d7aff"       // island/timer.rs:47
    readonly property color breakTint: "#30d158"       // island/timer.rs:48
    readonly property color batteryGreen: "#30d158"    // island/battery.rs:40
    readonly property color batteryOrange: "#ff9f0a"   // island/battery.rs:41
    readonly property color batteryRed: "#ff453a"      // island/battery.rs:42
    readonly property color purple: "#bf5af2"          // island/notices.rs:253
    readonly property color levelBubble: "#1b1f40"     // island/notices.rs:346-365
    readonly property color levelText: "#e9ebfe"       // island/notices.rs:346-365

    // ------------------------------------------------------------------ sizes
    readonly property real topMargin: 8                // island/mod.rs:154 TOP_MARGIN
    readonly property real idleWidth: 160              // island/mod.rs:159 IDLE.0
    readonly property real idleHeight: 64              // island/mod.rs:159 IDLE.1
    readonly property real bubbleSize: 48              // island/mod.rs:162 BUBBLE
    readonly property real compactRing: 36             // island/mod.rs:164 COMPACT_RING
    readonly property real compactLead: idleHeight / 2 // island/mod.rs:167 COMPACT_LEAD
    readonly property real expandedWidth: 408          // island/mod.rs:169 EXPANDED.0
    readonly property real expandedHeight: 84          // island/mod.rs:169 EXPANDED.1
    readonly property real expandedRadius: 42          // island/mod.rs:171 EXPANDED_RADIUS
    readonly property real keyLineWidth: 1             // island/mod.rs:173 KEY_LINE
    readonly property real bubbleGap: 8                // island/mod.rs:1117 BUBBLE_GAP
    readonly property real liftWidth: 8                // island/mod.rs:1113 LIFT.0
    readonly property real liftHeight: 2               // island/mod.rs:1113 LIFT.1
    // island/mod.rs:187-195 reserved_top(): TOP_MARGIN + IDLE.1 + 12.
    readonly property int exclusiveZone: topMargin + idleHeight + 12
    // island/mod.rs:1128 ENVELOPE: the largest the Island gets; the window is
    // this wide and only the drawing inside animates.
    readonly property real envelopeWidth: 680
    readonly property real envelopeHeight: 720

    // The idle face: island/mod.rs:1065 IDLE_CLOCK (24 / 600); the expanded
    // clock 34 / 600 over the date 17 / 400 (island/mod.rs:9606-9607).
    readonly property real idleClockSize: 24
    readonly property real expandedClockSize: 34
    readonly property real expandedDateSize: 17
    // island/mod.rs:1036 TIME_MIDDLE: the figures' middle, 1 above the capsule's.
    readonly property real timeMiddle: idleHeight / 2 - 1
    // island/mod.rs:1039-1043: notification indicator slot, end inset, glyph, dot.
    readonly property real indicator: 24
    readonly property real indicatorEnd: 10
    readonly property real indicatorGlyph: 16
    readonly property real unreadDot: 6
    // island/mod.rs:1032 PRIVACY_DOT, :1063 PRIVACY_DOT_OFFSET: privacy dot and its offset from the centre.
    readonly property real privacyDot: 7
    readonly property real privacyDotOffset: 43

    // Now Playing (island/now_playing.rs).
    readonly property real nowPlayingCompactWidth: 280   // :20
    readonly property real nowPlayingExpandedHeight: 160 // :33
    readonly property real nowPlayingCompactMargin: 12   // :36
    readonly property real nowPlayingCompactArt: 38      // :37
    readonly property real nowPlayingExpandedMargin: 20  // :38
    readonly property real nowPlayingExpandedArt: 52     // :39
    readonly property real nowPlayingTimeWidth: 36       // :40
    readonly property real artworkCorner: 0.24           // :42 (fraction of the art's size)

    // Timer / battery expanded heights (island/timer.rs:14, island/battery.rs:25).
    readonly property real timerExpandedHeight: 84
    readonly property real batteryExpandedHeight: 84
    readonly property real batteryCardPad: 20            // island/battery.rs:28-33
    readonly property real batteryRow: 44                // island/battery.rs:28-33
    readonly property real batteryLow: 0.20              // island/battery.rs:37
    readonly property real batteryNearlyEmpty: 0.10      // island/battery.rs:38

    // Notices (island/notices.rs).
    readonly property real bannerWidth: 360              // :242-243
    readonly property real bannerHeight: 64              // :242-243
    readonly property real bannerIcon: 32                // :752-756
    readonly property real bannerIconInset: 22           // :752-756
    readonly property real bannerIconRadius: 7           // :752-756
    readonly property real noticeGlyph: 20               // :246
    readonly property real noticeTrailPad: 16            // :248
    readonly property real noticeWideWidth: 340          // :252, :256 (copied / connection)
    readonly property real noticeButtonsHeight: 42       // :254
    readonly property real levelSlot: 32                 // :346-365
    readonly property real levelBubbleHeight: 24         // :346-365
    readonly property real openBannerWidth: 408          // :759-763
    readonly property real openBannerPad: 16             // :759-763 (top / bottom)

    // ------------------------------------------------------------------ type
    // island-motion/src/fonts.rs:8-10 and adwaita/mod.rs:514-516: Adwaita Sans
    // for text and display, Adwaita Mono for code; Qt falls back through
    // fontconfig, so the Rust's Inter -> Cantarell -> sans-serif chain is the
    // system's job here.
    readonly property string fontFamily: "Adwaita Sans"
    readonly property string monoFamily: "Adwaita Mono"

    // ------------------------------------------------------------ the time
    // 24-hour unless the locale's short time has an AM/PM marker.
    readonly property bool twentyFourHour: !Qt.locale().timeFormat(Locale.ShortFormat).toLowerCase().includes("a")

    // "15:41", or "3:41" without AM or PM in 12 hours, as iOS's Island
    // (island/mod.rs:268-271, island-motion/src/clock.rs:68-70).
    function clock(date: date): string {
        const h = date.getHours();
        const m = date.getMinutes();
        const mm = (m < 10 ? "0" : "") + m;
        if (root.twentyFourHour)
            return (h < 10 ? "0" : "") + h + ":" + mm;
        const h12 = h % 12 === 0 ? 12 : h % 12;
        return h12 + ":" + mm;
    }

    // "Saturday 17 October" (island/mod.rs:273-286), in the locale's names.
    function longDate(date: date): string {
        const locale = Qt.locale();
        return locale.dayName(date.getDay(), Locale.LongFormat) + " " + date.getDate() + " "
            + locale.monthName(date.getMonth(), Locale.LongFormat);
    }
}
