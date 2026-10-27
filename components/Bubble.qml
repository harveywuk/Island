pragma ComponentBehavior: Bound

import QtQuick
import qs

// A detached bubble beside the capsule, for a second or third activity
// (crates/shoji-island/src/island/mod.rs:162 BUBBLE, :1117 BUBBLE_GAP,
// geometry from bubble_centre / bubble_rect at :9833-9865). It comes out of
// the capsule's round end and settles BUBBLE_GAP away, centred on the idle
// capsule's middle, and goes back into it the same way.
//
// Plain circles in this pass: no goo neck (that needs a shader).
//
// Positioned in the window's coordinates: give it the capsule's geometry.
// Its `component` is a view (contract: targetWidth / targetHeight); a bubble
// is BUBBLE tall and as wide as the view's targetWidth (at least BUBBLE).
Item {
    id: root

    property Component component: null
    property bool left: false
    // Folded into the capsule (the Island open, or a notice shown).
    property bool folded: false
    // The capsule, in the parent's coordinates.
    property real capsuleX: 0
    property real capsuleY: 0
    property real capsuleWidth: Theme.idleWidth
    property real capsuleHeight: Theme.idleHeight

    readonly property bool wanted: root.component !== null && !root.folded
    readonly property real presence: Math.max(0, Math.min(1, presenceSpring.value))
    readonly property bool shown: presence >= 0.02

    signal clicked(var mouse)

    // The component on show: kept while the bubble goes back in.
    property Component shownComponent: null
    onComponentChanged: if (root.component !== null) root.shownComponent = root.component
    Component.onCompleted: {
        root.shownComponent = root.component;
        presenceSpring.snap(root.wanted ? 1 : 0);
    }

    // island/spring.rs:11-13 drip(): out of and back into the capsule.
    Spring {
        id: presenceSpring
        target: root.wanted ? 1 : 0
        response: Motion.dripResponse
        damping: Motion.dripDamping
        onRunningChanged: if (!presenceSpring.running && !root.wanted && root.component === null) root.shownComponent = null
    }

    // The bubble's width springs when its content changes (DESIGN.md:360-363).
    readonly property real wantedWidth: Math.max(Theme.bubbleSize, slot.item && slot.item.targetWidth > 0 ? slot.item.targetWidth : Theme.bubbleSize)
    Spring {
        id: widthSpring
        target: root.wantedWidth
        restDistance: 0.05
        restVelocity: 0.5
        Component.onCompleted: widthSpring.snap(root.wantedWidth)
    }

    // mod.rs:9833-9865, with presence p:
    //   t' = 1 - (1 - p)²,   end = min(capsule h, w)
    //   centre = capsule end ± lerp(end / 2, -gap - width / 2, t')
    //   size   = lerp(end, (width, BUBBLE), p);  middle = lerp(capsule h, IDLE h, p) / 2
    readonly property real _end: Math.min(root.capsuleHeight, root.capsuleWidth)
    readonly property real _reach: 1 - Math.pow(1 - root.presence, 2)
    readonly property real _w: Motion.lerp(_end, widthSpring.value, root.presence)
    readonly property real _h: Motion.lerp(_end, Theme.bubbleSize, root.presence)
    readonly property real _centre: root.left
        ? root.capsuleX + Motion.lerp(_end / 2, -Theme.bubbleGap - widthSpring.value / 2, _reach)
        : root.capsuleX + root.capsuleWidth - Motion.lerp(_end / 2, -Theme.bubbleGap - widthSpring.value / 2, _reach)
    readonly property real _middle: root.capsuleY + Motion.lerp(root.capsuleHeight, Theme.idleHeight, root.presence) / 2

    // Zero-sized while gone, so the window's input mask leaves it out.
    x: root.shown ? root._centre - root._w / 2 : root.capsuleX
    y: root.shown ? root._middle - root._h / 2 : root.capsuleY
    width: root.shown ? root._w : 0
    height: root.shown ? root._h : 0
    visible: root.shown

    Capsule {
        id: shape
        anchors.fill: parent
        radius: height / 2

        Arrival {
            // Content comes in over the second half of the way out.
            amount: Motion.smoothstep(0.5, 1, root.presence)
            x: (shape.width - slot.width) / 2
            y: (shape.height - slot.height) / 2
            width: slot.width
            height: slot.height

            Loader {
                id: slot
                width: widthSpring.value
                height: Theme.bubbleSize
                sourceComponent: root.shownComponent
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
    }
}
