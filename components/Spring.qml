pragma ComponentBehavior: Bound

import QtQuick
import qs

// A damped spring stepped once per rendered frame, in closed form, so its
// motion is the same at any frame rate. A port of island-motion's
// Spring::step (crates/island-motion/src/lib.rs:33-54).
//
// Unit mass, built from a response T (s) and a damping ratio ζ
// (lib.rs:21-27):
//     k = (2π / T)²          c = 4πζ / T
//     ω = √k                 ζ = c / (2ω)
// With y = x - target, the exact solution after dt is, for ζ < 1
// (ω_d = ω √(1 - ζ²)):
//     y' = e^(-ζωdt) · ( y cos ω_d dt + (v + ζωy) / ω_d · sin ω_d dt )
//     v' = e^(-ζωdt) · ( v cos ω_d dt - (ζωv + ω²y) / ω_d · sin ω_d dt )
// and for ζ ≥ 1 (critically damped; the Island has no overdamped spring):
//     y' = (y + (v + ωy) dt) · e^(-ωdt)
//     v' = (v - ω(v + ωy) dt) · e^(-ωdt)
// It stops (snaps to target) within restDistance and below restVelocity
// (lib.rs:66-69).
//
// Use: Spring { id: w; target: 160; response: Motion.expandResponse;
//               damping: Motion.expandDamping }   then bind to w.value.
// Changing `target` starts it from where it is, keeping its velocity, as the
// Rust's animate_to does. `snap(target)` jumps there with no motion.
FrameAnimation {
    id: root

    property real target: 0
    property real value: 0
    property real velocity: 0
    // Response in ms and damping ratio; default the expand spring.
    property real response: Motion.expandResponse
    property real damping: Motion.expandDamping
    // In the value's own units (and per second); pixel springs can pass
    // larger ones than the Rust's 0..1 defaults.
    property real restDistance: Motion.restDistance
    property real restVelocity: Motion.restVelocity
    // A frame longer than this (a stall, a hidden window) is stepped as this
    // long, so the motion is still seen rather than jumping to its end.
    property real maxStep: 1 / 15

    readonly property bool atRest: !root.running

    // Jumps the value to v with no velocity (target is left alone, so a
    // binding on it survives); it then springs on to target if they differ.
    function snap(v: real): void {
        root.value = v;
        root.velocity = 0;
        if (root.value === root.target)
            root.stop();
        else
            root.start();
    }

    function step(dt: real): void {
        const T = Math.max(1, root.response) / 1000;
        const stiffness = Math.pow(2 * Math.PI / T, 2);
        const dampingC = 4 * Math.PI * root.damping / T;
        const omega = Math.sqrt(stiffness);
        const zeta = dampingC / (2 * omega);
        const y = root.value - root.target;
        const v = root.velocity;
        let yNext;
        let vNext;
        if (zeta < 1) {
            const decay = Math.exp(-zeta * omega * dt);
            const omegaD = omega * Math.sqrt(1 - zeta * zeta);
            const s = Math.sin(omegaD * dt);
            const c = Math.cos(omegaD * dt);
            yNext = decay * (y * c + (v + zeta * omega * y) / omegaD * s);
            vNext = decay * (v * c - (zeta * omega * v + omega * omega * y) / omegaD * s);
        } else {
            const decay = Math.exp(-omega * dt);
            yNext = (y + (v + omega * y) * dt) * decay;
            vNext = (v - omega * (v + omega * y) * dt) * decay;
        }
        if (Math.abs(yNext) < root.restDistance && Math.abs(vNext) < root.restVelocity) {
            root.value = root.target;
            root.velocity = 0;
            root.stop();
        } else {
            root.value = root.target + yNext;
            root.velocity = vNext;
        }
    }

    running: false
    onTargetChanged: {
        if (root.value !== root.target)
            root.start();
    }
    // frameTime: seconds since the previous frame (QtQuick FrameAnimation, Qt 6.4+).
    onTriggered: root.step(Math.max(0, Math.min(root.maxStep, root.frameTime)))
}
