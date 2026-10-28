pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// The Island's content box: the capsule's geometry, its children clipped to
// the rounded shape. The black fill, the key line and the shadow are drawn
// by the liquid (components/Liquid.qml, shaders/island-goo.frag) under it,
// as the Rust's (island/mod.rs:9977-10032 black_liquid), so the capsule and
// its bubbles are one shape. Its size and radius are set from outside
// (springs).
Item {
    id: root

    property real radius: height / 2
    readonly property real clampedRadius: Math.max(0, Math.min(root.radius, root.width / 2, root.height / 2))
    // Where children go: a box the capsule's size, clipped to its shape.
    default property alias content: clipBox.data
    readonly property Item contentItem: clipBox

    // Content, clipped to the rounded shape with a mask.
    Item {
        id: clipBox
        anchors.fill: parent
        layer.enabled: root.width > 0 && root.height > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskShape
            // VERIFY: threshold / spread values that keep an antialiased
            // edge with a Rectangle mask.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: root.clampedRadius
        color: "black"
        antialiasing: true
        visible: false
        layer.enabled: true
    }
}
