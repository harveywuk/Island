pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs

// Content arriving in (or leaving) the Island: shape first, then content.
// A port of `revealed` and `reveal_blur` (crates/shoji-island/src/island/
// mod.rs:440-460) with the 60 ms exponential follow of docs/DESIGN.md:341-345.
//
// `amount` is where the content should be (0 gone, 1 there). What is drawn
// follows it 60 ms behind; at a drawn amount a:
//   opacity   = smoothstep(0, 1, a)
//   y         = -(1 - a) · 8          (drifts down out of the top edge)
//   blur (pt) = 6 · r · √r,  r = max(0, 1 - a / 0.9)   (sharp by 90 %)
// Content is not scaled (as in the Rust). Children go inside it.
Item {
    id: root

    property real amount: 1
    // The followed amount, read-only in spirit; starts where `amount` is.
    property real shown: amount
    property real lagMs: Motion.arrivalLagMs
    readonly property real blurPt: {
        const rest = Math.max(0, 1 - Math.max(0, Math.min(1, shown)) / Motion.arrivalSharpAt);
        return Motion.arrivalBlur * rest * Math.sqrt(rest);
    }

    Component.onCompleted: root.shown = root.amount

    FrameAnimation {
        id: follow
        running: Math.abs(root.shown - root.amount) > 0.0005
        onTriggered: {
            const dt = Math.max(0, Math.min(1 / 15, follow.frameTime));
            const k = 1 - Math.exp(-dt * 1000 / Math.max(1, root.lagMs));
            const next = root.shown + (root.amount - root.shown) * k;
            root.shown = Math.abs(next - root.amount) <= 0.0005 ? root.amount : next;
        }
    }

    opacity: Motion.smoothstep(0, 1, shown)
    visible: opacity > 0.001
    transform: Translate {
        y: -(1 - Math.max(0, Math.min(1, root.shown))) * Motion.arrivalDrift
    }

    // Blurred only while it needs to be, so settled content is its own
    // raster (and costs nothing extra).
    layer.enabled: root.blurPt > 0.05
    layer.effect: MultiEffect {
        // VERIFY: blur is 0..1 of blurMax (px of the effect's internal
        // scale), not a Gaussian sigma; blurMax 2·6 approximates 6 pt.
        blurEnabled: true
        blurMax: Math.round(Motion.arrivalBlur * 2)
        blur: root.blurPt / Motion.arrivalBlur
        autoPaddingEnabled: true
    }
}
