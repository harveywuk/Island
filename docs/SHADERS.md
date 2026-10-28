# Shaders

## The liquid (`shaders/island-goo.frag`)

The Island's black surface is drawn by one `ShaderEffect`,
`components/Liquid.qml`: the capsule and its detached bubbles as one liquid
shape (signed distance fields joined with a smooth minimum), with the 1 px
key line just inside the edge and the soft shadow below. A bubble leaving
the capsule draws a neck that thins and breaks; resting bubbles stay apart.
It is a port of the Rust Island's `paint_main` in
`crates/shoji-island/assets/src/effect/island-goo.frag` (wiring:
`crates/shoji-island/src/island/mod.rs:9833-10010`), Island branch only: the
Control Centre menu shadow uniforms are left out. Liquid Glass (which needs a
backdrop capture) is not ported.

`Capsule.qml` now only clips its content to the rounded shape; `Bubble.qml`
keeps its geometry and adds `reach`; neither draws fill, key line or shadow.

### Rebuilding the `.qsb`

Quickshell loads the precompiled `shaders/island-goo.frag.qsb`, which is
checked in. After editing `island-goo.frag`, run from the repository root:

```sh
/usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 \
    -o shaders/island-goo.frag.qsb shaders/island-goo.frag
```

(`qsb` ships with Qt's shader tools: `qt6-shadertools` / `qt6-shader-baker`.)
Check the uniform block with `qsb --dump shaders/island-goo.frag.qsb`: every
member after `qt_Matrix` / `qt_Opacity` must have a QML property of the
same name on `Liquid.qml` (ShaderEffect maps them by name).

### Uniforms

| Uniform | Type | Liquid.qml source |
| --- | --- | --- |
| `capsule` | vec4 | `capsuleItem` x, y, width, height (logical px) |
| `capsuleRadius` | float | `capsuleItem.clampedRadius` |
| `leftBubble`, `rightBubble` | vec4 | the bubble items' rects; width 0 = absent |
| `leftSmoothness`, `rightSmoothness` | float | `Bubble.reach` (mod.rs:9877-9881) |
| `edge`, `edgeSmoothness` | float | 0 and 0 (screen-edge join off; for a drip later) |
| `fill`, `keyLine`, `rimTop`, `shadowColor` | vec4 | `Theme.surface/keyLine/rimTop/shadow` |
| `dpr` | float | `Screen.devicePixelRatio` (the Rust's `scale`; `Item.scale` is taken) |
| `extent` | vec2 | the item's width, height (`p = qt_TexCoord0 * extent`) |

Colours reach the shader premultiplied (Qt's ShaderEffect does that); the
shader un-premultiplies them and writes premultiplied output × `qt_Opacity`.

`Bubble.reach` = `Theme.gooRestReach + Theme.gooTravelReach * travelling`,
`travelling = presence > 0.02 ? (1 - presence) * smoothstep(0, 0.35, presence) : 0`:
wide while a bubble travels (the neck), 2 px once it rests (cleanly apart).

## Integration (`components/IslandWindow.qml`)

Add `Liquid` as the **first** drawing child of the `PanelWindow`, before
`Capsule { id: capsule }` and the two `Bubble`s, so it draws under them:

```qml
    // ------------------------------------------------------------- drawing
    // The black surface, key line and shadow of the capsule and bubbles as
    // one liquid shape (docs/SHADERS.md). Under everything; no input.
    Liquid {
        x: 0
        y: 0
        width: root.width
        height: root.height
        capsuleItem: capsule
        leftBubbleItem: leftBubble
        rightBubbleItem: rightBubble
    }
```

That is all: Liquid reads `x / y / width / height / clampedRadius` from the
capsule and `x / y / width / height / visible / reach` from the bubbles, which
are its siblings (same parent, window coordinates). The window starts at the
screen's top edge, so the capsule's `y` (`Theme.topMargin`) is already the
distance from the edge and `edge` stays 0. If Liquid is ever placed in a
different parent from the capsule, set `originX` / `originY` to Liquid's
position in the capsule's parent coordinates.

Nothing else changes: the input mask (`Region { item: capsule … }`) is as
before, Liquid takes no pointer input (a ShaderEffect has no handlers), and
nothing sets the old `Capsule` properties `color`, `keyLineColor`,
`keyLineWidth` or `shadowEnabled` (removed), nor the old Theme tokens
`shadowBlur`, `shadowBlurMax`, `shadowOffsetY` (replaced by `rimTop`,
`gooRestReach`, `gooTravelReach`).

Optional later: bind `edgeSmoothness` to a pull / drip amount (mod.rs:
9888-9898 `edge_join`: `max(2.6 * TOP_MARGIN * smoothstep(0, 8, pulled) +
1.2 * pulled, EDGE_JOIN * drip)`) so the Island hangs from the screen edge.

## VERIFY on a real session

- The shadow and key line look as the Rust's (contact drop 1 px / σ 1.5 at
  40 %, key drop 8 px lower, 2 px in, σ 11; `#00000080`).
- `Screen.devicePixelRatio` inside the layer-shell window reports the
  output's scale (fractional scaling: the key line stays 1 device px wide).
- The goo neck forms and breaks as a bubble leaves; two resting bubbles stay
  separate (reach 2 px).
