pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// One of the Island's symbols (assets/island/<name>.svg), drawn crisp at
// `size`. The symbols are white (or already coloured, e.g. "play-orange");
// set `tint` to recolour a white one.
//
//   Icon { name: "bell"; size: Theme.indicatorGlyph }
//   Icon { name: "speaker"; size: 20; tint: Theme.timerTint }
Item {
    id: root

    property string name: ""
    property real size: 20
    // Transparent = draw the SVG as it is.
    property color tint: "transparent"
    readonly property bool tinted: root.tint.a > 0
    readonly property url source: root.name === "" ? "" : Qt.resolvedUrl("../assets/island/" + root.name + ".svg")
    readonly property bool ready: image.status === Image.Ready

    implicitWidth: size
    implicitHeight: size

    Image {
        id: image
        anchors.fill: parent
        source: root.source
        // Rasterise the SVG at the drawn size (times the screen's scale) so
        // it is sharp, not a scaled bitmap.
        sourceSize.width: Math.ceil(root.width * Screen.devicePixelRatio)
        sourceSize.height: Math.ceil(root.height * Screen.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: false
        asynchronous: false
        visible: !root.tinted
        layer.enabled: root.tinted
    }

    // Tinting: a fill of the colour, masked by the symbol's alpha.
    Rectangle {
        id: fill
        anchors.fill: parent
        color: root.tint
        visible: false
        layer.enabled: root.tinted
    }

    MultiEffect {
        anchors.fill: parent
        visible: root.tinted
        source: fill
        maskEnabled: true
        maskSource: image
        // VERIFY: mask thresholds; 0..1 with a small spread keeps the SVG's
        // antialiased edge.
        maskThresholdMin: 0.0
        maskSpreadAtMin: 1.0
    }
}
