pragma ComponentBehavior: Bound

import QtQuick
import qs

// The Island's black surface as one liquid shape: the capsule and its
// detached bubbles as metaballs, with the key line inside the edge and the
// soft shadow below (shaders/island-goo.frag, from the Rust's
// assets/src/effect/island-goo.frag; wiring island/mod.rs:9833-10010).
//
// Place it as the first child of the window (under the capsule and the
// bubbles), filling the window, and give it the capsule and the bubbles. It
// reads their x / y / width / height, so they must share its parent's
// coordinates (or set originX / originY to this item's offset from theirs).
// See docs/SHADERS.md.
ShaderEffect {
    id: root

    required property Capsule capsuleItem
    property Bubble leftBubbleItem: null
    property Bubble rightBubbleItem: null
    // Where this item's (0, 0) is in the items' parent coordinates.
    property real originX: root.x
    property real originY: root.y

    // ---------------------------------------------------------- uniforms
    // Names match shaders/island-goo.frag's uniform block. Rects are
    // (x, y, w, h) in logical px from this item's top-left; w = 0 leaves a
    // bubble out.
    readonly property vector4d capsule: Qt.vector4d(root.capsuleItem.x - root.originX, root.capsuleItem.y - root.originY,
                                                    root.capsuleItem.width, root.capsuleItem.height)
    readonly property real capsuleRadius: root.capsuleItem.clampedRadius
    readonly property vector4d leftBubble: root._bubbleRect(root.leftBubbleItem)
    readonly property vector4d rightBubble: root._bubbleRect(root.rightBubbleItem)
    // island/mod.rs:9877-9881: each bubble's smooth-minimum radius.
    readonly property real leftSmoothness: root.leftBubbleItem ? root.leftBubbleItem.reach : Theme.gooRestReach
    readonly property real rightSmoothness: root.rightBubbleItem ? root.rightBubbleItem.reach : Theme.gooRestReach
    // The screen's top edge as a shape the liquid joins (island/mod.rs:
    // 9888-9898 edge_join); 0 leaves it out. The window starts at the
    // screen's edge, so `edge` is 0. For a drip / pull-down animation later.
    property real edge: 0
    property real edgeSmoothness: 0
    // theme.rs:1721-1731 (the Island branch: no Control Centre menu shadow).
    property color fill: Theme.surface
    property color keyLine: Theme.keyLine
    property color rimTop: Theme.rimTop
    property color shadowColor: Theme.shadow
    // Device pixels per logical px (the shader's `scale`: Item.scale is
    // taken), and this item's size in logical px.
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
    readonly property vector2d extent: Qt.vector2d(root.width, root.height)

    function _bubbleRect(bubble: Bubble): vector4d {
        if (!bubble || !bubble.visible || bubble.width <= 0 || bubble.height <= 0)
            return Qt.vector4d(0, 0, 0, 0);
        return Qt.vector4d(bubble.x - root.originX, bubble.y - root.originY, bubble.width, bubble.height);
    }

    visible: root.width > 0 && root.height > 0 && root.capsuleItem.width > 0 && root.capsuleItem.height > 0
    // Premultiplied output; nothing under it in the window to blend with
    // but the transparent surface.
    blending: true
    fragmentShader: Qt.resolvedUrl("../shaders/island-goo.frag.qsb")
}
