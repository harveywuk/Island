pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs

// A progress ring, as the compact capsule's battery / timer rings
// (crates/shoji-island/src/island/battery.rs:210-218): a track of the colour
// at alpha 64/255 and the fill from 12 o'clock clockwise, round-capped.
// Children (a glyph, a number) go in a box the ring's size; centre them
// with `anchors.centerIn: parent`.
Item {
    id: root

    property real progress: 0            // 0..1
    property real size: Theme.compactRing
    property real thickness: 2.5         // battery.rs:245 ring(.., COMPACT_RING, 2.5, ..)
    property color color: Theme.timerTint
    property color trackColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 64 / 255)
    readonly property real clamped: Math.max(0, Math.min(1, root.progress))
    default property alias content: inner.data

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer // VERIFY: Qt 6.6+; older Qt ignores it with a warning
        antialiasing: true

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2
                radiusY: (root.height - root.thickness) / 2
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.clamped > 0 ? root.color : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: (root.width - root.thickness) / 2
                radiusY: (root.height - root.thickness) / 2
                // 0° is 3 o'clock and angles run clockwise (y down).
                startAngle: -90
                sweepAngle: 360 * root.clamped
            }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
