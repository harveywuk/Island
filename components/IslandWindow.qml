pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// The Island's window: an overlay layer surface at the top of a screen,
// a fixed envelope (island/mod.rs:1128 ENVELOPE) in which only the drawing
// animates, with an input mask over just the capsule and its bubbles (the
// Rust's envelope input, which a layer surface cannot do otherwise).
//
// Contract (docs/PORT-PLAN.md ▸ Shared contract):
//   compactView, expandedView, noticeView : Component (null = none)
//   bubbles  : array of up to 2 Components; [0] goes right, [1] left
//              (island/activity.rs:114-115 fills right before left)
//   expanded : readonly bool
//   open(), close(), toggle(), holdOpen(ms)
// It shows noticeView if set, else expandedView when expanded, else
// compactView; the idle views stand in for a null slot. The capsule springs
// to the shown view's targetWidth / targetHeight / targetRadius (expand
// spring growing, collapse spring shrinking) and the content cross-fades
// (420 ms handover, 60 ms arrival lag, 8 px drift).
PanelWindow {
    id: root

    // ------------------------------------------------------------ the slots
    property Component compactView: null
    property Component expandedView: null
    property Component noticeView: null
    property var bubbles: []

    // The fallbacks when a slot is null. shell.qml sets them (IdleCompact /
    // IdleExpanded), so qs.components never imports qs.views (which imports
    // qs.components): no module cycle.
    property Component idleCompactView: null
    property Component idleExpandedView: null

    // Open when the pointer rests on it (noctalia's; island/mod.rs:1020-1023).
    property bool openOnHover: true

    readonly property bool expanded: root._expanded
    readonly property bool hovered: hover.hovered
    readonly property Component shownView: root.noticeView
        ?? (root._expanded ? (root.expandedView ?? root.idleExpandedView)
                           : (root.compactView ?? root.idleCompactView))
    // The capsule as drawn now (window coordinates), for anything placed
    // against it.
    readonly property rect capsuleRect: Qt.rect(capsule.x, capsule.y, capsule.width, capsule.height)

    // A bubble was clicked (0 = right, 1 = left: its index in `bubbles`).
    signal bubbleClicked(int index, var mouse)
    // A click on the capsule with another button (Qt.RightButton / MiddleButton);
    // a menu, later.
    signal secondaryClicked(int button)

    property bool _expanded: false

    function open(): void {
        closeTimer.stop();
        root._expanded = true;
    }

    function close(): void {
        openTimer.stop();
        holdTimer.stop();
        root._expanded = false;
    }

    function toggle(): void {
        if (root._expanded)
            root.close();
        else
            root.open();
    }

    // Open, and stay open for `ms` even if the pointer leaves (an alert).
    function holdOpen(ms: int): void {
        root.open();
        holdTimer.interval = Math.max(1, ms);
        holdTimer.restart();
    }

    // ------------------------------------------------------- the layer shell
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shoji-island"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors.top: true
    // island/mod.rs:187-195 reserved_top(): TOP_MARGIN + IDLE.1 + 12.
    exclusiveZone: Theme.exclusiveZone
    implicitWidth: Theme.envelopeWidth
    implicitHeight: Theme.envelopeHeight
    color: "transparent"
    focusable: false

    // Input only where the Island is; the rest of the envelope lets the
    // pointer through to what is under it.
    // VERIFY: nested Regions combine (union) with the parent by default
    // (Region.intersection = Intersection.Combine).
    mask: Region {
        item: capsule
        Region { item: rightBubble }
        Region { item: leftBubble }
    }

    // -------------------------------------------------------------- timers
    Timer {
        id: openTimer
        interval: Motion.hoverOpenMs
        onTriggered: if (root.openOnHover && hover.hovered) root.open()
    }
    Timer {
        id: closeTimer
        interval: Motion.hoverCloseMs
        onTriggered: if (!hover.hovered && !holdTimer.running) root.close()
    }
    Timer {
        id: holdTimer
        onTriggered: if (!hover.hovered) root.close()
    }

    // -------------------------------------------------------------- springs
    // The size the shown view wants, plus the hover lift (island/mod.rs:1113)
    // while compact.
    readonly property Item activeItem: activeSlot.current ? activeSlot.current.item : null
    readonly property bool lifted: hover.hovered && !root._expanded && root.noticeView === null
    readonly property real capsuleTargetWidth: (root.activeItem && root.activeItem.targetWidth > 0 ? root.activeItem.targetWidth : Theme.idleWidth)
        + (root.lifted ? Theme.liftWidth : 0)
    readonly property real capsuleTargetHeight: (root.activeItem && root.activeItem.targetHeight > 0 ? root.activeItem.targetHeight : Theme.idleHeight)
        + (root.lifted ? Theme.liftHeight : 0)
    readonly property real capsuleTargetRadius: {
        const item = root.activeItem;
        if (item && item.targetRadius !== undefined && item.targetRadius > 0)
            return item.targetRadius + (root.lifted ? Theme.liftHeight / 2 : 0);
        return root.capsuleTargetHeight / 2;
    }

    onCapsuleTargetWidthChanged: root._retarget()
    onCapsuleTargetHeightChanged: root._retarget()
    onCapsuleTargetRadiusChanged: root._retarget()

    // Growing uses the expand spring, shrinking the collapse one, as the
    // Rust's expand / collapse (island-motion/src/lib.rs:57-64). One choice
    // for all three, by area, so the shape moves as one.
    function _retarget(): void {
        const growing = root.capsuleTargetWidth * root.capsuleTargetHeight > widthSpring.target * heightSpring.target;
        const response = growing ? Motion.expandResponse : Motion.collapseResponse;
        const damping = growing ? Motion.expandDamping : Motion.collapseDamping;
        for (const s of [widthSpring, heightSpring, radiusSpring]) {
            s.response = response;
            s.damping = damping;
        }
        widthSpring.target = root.capsuleTargetWidth;
        heightSpring.target = root.capsuleTargetHeight;
        radiusSpring.target = root.capsuleTargetRadius;
    }

    Spring {
        id: widthSpring
        restDistance: 0.01
        restVelocity: 0.1
    }
    Spring {
        id: heightSpring
        restDistance: 0.01
        restVelocity: 0.1
    }
    Spring {
        id: radiusSpring
        restDistance: 0.01
        restVelocity: 0.1
    }

    // ------------------------------------------------------------ handover
    // Two content slots; the shown view arrives in one while the other
    // leaves. Coming back to what is leaving turns it round.
    QtObject {
        id: activeSlot
        property ContentSlot current: slotA
        readonly property ContentSlot other: activeSlot.current === slotA ? slotB : slotA
    }

    // Not before Component.onCompleted: the slots' bindings (set by
    // shell.qml) land during creation and would otherwise hand the first
    // view over before slotA is given it.
    property bool _ready: false
    onShownViewChanged: if (root._ready) root._handOver(root.shownView)

    function _handOver(view: Component): void {
        const current = activeSlot.current;
        if (current.view === view)
            return;
        const other = activeSlot.other;
        current.leave();
        other.arrive(view);
        activeSlot.current = other;
    }

    Component.onCompleted: {
        slotA.view = root.shownView;
        slotA.amount = 1;
        slotA.shown = 1;
        // A first frame at the idle size, then spring from it.
        widthSpring.target = root.capsuleTargetWidth;
        heightSpring.target = root.capsuleTargetHeight;
        radiusSpring.target = root.capsuleTargetRadius;
        widthSpring.snap(root.capsuleTargetWidth);
        heightSpring.snap(root.capsuleTargetHeight);
        radiusSpring.snap(root.capsuleTargetRadius);
        root._ready = true;
    }

    // One content layer: laid out at its view's own size (centred along the
    // top of the capsule) so content stays put while the shape springs
    // round it, as iOS's (island/mod.rs:9593-9600).
    component ContentSlot: Arrival {
        id: slot

        property Component view: null
        readonly property Item item: loader.item

        function arrive(next: Component): void {
            leaving.stop();
            if (slot.view !== next) {
                slot.view = next;
                slot.amount = 0;
                slot.shown = 0;
            }
            arriving.restart();
        }

        function leave(): void {
            arriving.stop();
            leaving.restart();
        }

        amount: 0
        width: loader.item && loader.item.targetWidth > 0 ? loader.item.targetWidth : Theme.idleWidth
        height: loader.item && loader.item.targetHeight > 0 ? loader.item.targetHeight : Theme.idleHeight

        Loader {
            id: loader
            anchors.fill: parent
            sourceComponent: slot.view
        }

        // Expanded content comes in while the compact goes, both blurred,
        // so one becomes the other and the Island never passes through an
        // empty shape (island/mod.rs:428-438: arrive over 0.2-0.75 of the
        // handover, leave over its first half).
        SequentialAnimation {
            id: arriving
            PauseAnimation { duration: Math.round(Motion.handoverMs * 0.2) }
            NumberAnimation {
                target: slot
                property: "amount"
                to: 1
                duration: Math.round(Motion.handoverMs * 0.8)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standard
            }
        }
        SequentialAnimation {
            id: leaving
            NumberAnimation {
                target: slot
                property: "amount"
                to: 0
                duration: Math.round(Motion.handoverMs * 0.5)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.leave
            }
            ScriptAction {
                // An ended activity keeps its last content while it fades
                // (DESIGN.md:364-365); then it goes.
                script: slot.view = null
            }
        }
    }

    // ------------------------------------------------------------- drawing
    Capsule {
        id: capsule
        x: Math.round((root.width - width) / 2)
        y: Theme.topMargin
        width: Math.max(0, widthSpring.value)
        height: Math.max(0, heightSpring.value)
        radius: Math.max(0, radiusSpring.value)

        ContentSlot {
            id: slotA
            x: Math.round((capsule.width - width) / 2)
            y: 0
        }
        ContentSlot {
            id: slotB
            x: Math.round((capsule.width - width) / 2)
            y: 0
        }

        // Pointer handlers on the capsule itself: a view's own buttons (its
        // children, on top) take their presses first; everything else here
        // opens, closes or holds the Island. Hover is seen over children too.
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (hover.hovered) {
                    closeTimer.stop();
                    if (root.openOnHover && !root._expanded)
                        openTimer.restart();
                } else {
                    openTimer.stop();
                    if (root._expanded && !holdTimer.running)
                        closeTimer.restart();
                }
            }
        }
        TapHandler {
            id: tap
            acceptedButtons: Qt.LeftButton
            // island/mod.rs:1072 HOLD_MS: touch and hold opens it; a long
            // press does not also tap.
            longPressThreshold: Motion.holdMs / 1000
            onPressedChanged: if (tap.pressed) openTimer.stop()
            onTapped: root.toggle()
            onLongPressed: root.open()
        }
        TapHandler {
            acceptedButtons: Qt.RightButton | Qt.MiddleButton
            // VERIFY: tapped(eventPoint, button) carries the button (Qt 6.2+).
            onTapped: (eventPoint, button) => root.secondaryClicked(button)
        }
    }

    // [0] right, [1] left (island/activity.rs:114-115).
    Bubble {
        id: rightBubble
        left: false
        component: root.bubbles && root.bubbles.length > 0 ? root.bubbles[0] : null
        folded: root._expanded || root.noticeView !== null
        capsuleX: capsule.x
        capsuleY: capsule.y
        capsuleWidth: capsule.width
        capsuleHeight: capsule.height
        onClicked: mouse => root.bubbleClicked(0, mouse)
    }
    Bubble {
        id: leftBubble
        left: true
        component: root.bubbles && root.bubbles.length > 1 ? root.bubbles[1] : null
        folded: root._expanded || root.noticeView !== null
        capsuleX: capsule.x
        capsuleY: capsule.y
        capsuleWidth: capsule.width
        capsuleHeight: capsule.height
        onClicked: mouse => root.bubbleClicked(1, mouse)
    }
}
