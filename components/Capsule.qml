pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs

// The Island's black shape: a rounded rectangle with the iOS key line and a
// soft shadow (crates/shoji-island/src/theme.rs:1721-1731; key line width
// island/mod.rs:173, the surface style island/mod.rs:9395-9404). Its size
// and radius are set from outside (springs); children are clipped to the
// rounded shape.
Item {
    id: root

    property real radius: height / 2
    property color color: Theme.surface
    property color keyLineColor: Theme.keyLine
    property real keyLineWidth: Theme.keyLineWidth
    property bool shadowEnabled: true
    readonly property real clampedRadius: Math.max(0, Math.min(root.radius, root.width / 2, root.height / 2))
    // Where children go: a box the capsule's size, clipped to its shape.
    default property alias content: clipBox.data
    readonly property Item contentItem: clipBox

    // The fill, with the shadow under it. The shadow is drawn from this
    // rectangle alone, so it does not re-render when content changes.
    Rectangle {
        id: fill
        anchors.fill: parent
        radius: root.clampedRadius
        color: root.color
        antialiasing: true
        layer.enabled: root.shadowEnabled && root.width > 0 && root.height > 0
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.shadow
            shadowBlur: Theme.shadowBlur
            blurMax: Theme.shadowBlurMax
            shadowVerticalOffset: Theme.shadowOffsetY
            shadowHorizontalOffset: 0
            // VERIFY: autoPadding grows the layer so the shadow is not cut
            // at the rectangle's edge when used as layer.effect.
            autoPaddingEnabled: true
        }
    }

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

    // The key line, over the content, inside the edge.
    Rectangle {
        anchors.fill: parent
        radius: root.clampedRadius
        color: "transparent"
        border.color: root.keyLineColor
        border.width: root.keyLineWidth
        antialiasing: true
        visible: root.keyLineWidth > 0 && root.width > 0
    }
}
