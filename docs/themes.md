# Corp Themes

`BSDRunner` takes its visual direction from **Android: Netrunner** as published by Fantasy Flight Games.

The goal is not to recreate card art directly, but to build a desktop language that feels like each corporation:

- Haas-Bioroid
- Jinteki
- NBN
- Weyland Consortium

## Design Rule

Keep function and theme separate.

- `hyprland.conf` should stay stable and mostly about behavior
- corp identity should live in theme files and theme assets
- a broken theme should never prevent the desktop from starting

## Theme Layers

Each corp theme should eventually be able to style:

- `kitty`
- `rofi`
- `waybar`
- wallpaper choices
- accent colors for future scripts or templates

The base Hyprland startup path should remain theme-neutral.

## Haas-Bioroid

Mood:

- clinical
- premium
- engineered
- precise

Visual cues:

- brushed steel
- white surfaces
- pale cyan highlights
- restrained geometry

Suggested palette:

- background: `#0f1418`
- surface: `#1b2329`
- text: `#d7e3ea`
- accent: `#8fd3ff`
- accent-strong: `#dff6ff`
- warning: `#ffb86b`

Typography direction:

- clean sans for UI
- minimal contrast
- spacious layout

## Jinteki

Mood:

- elegant
- threatening
- organic
- intimate

Visual cues:

- lacquer black
- crimson gradients
- surgical red
- soft glow against dark fields

Suggested palette:

- background: `#11090a`
- surface: `#1c0f12`
- text: `#f3d7da`
- accent: `#c61f3a`
- accent-strong: `#ff5a6f`
- warning: `#ffb36b`

Typography direction:

- sharp, high-contrast layouts
- narrow spacing
- selective use of red

## NBN

Mood:

- broadcast
- saturated
- noisy
- commercial

Visual cues:

- yellow and orange panels
- black framing
- ticker-like emphasis
- media graphics energy

Suggested palette:

- background: `#14110b`
- surface: `#221a0d`
- text: `#fff0c7`
- accent: `#f3c316`
- accent-strong: `#ff8b1f`
- warning: `#ff4f4f`

Typography direction:

- bold labels
- strong separators
- more aggressive information density

## Weyland Consortium

Mood:

- industrial
- territorial
- militarized
- extractive

Visual cues:

- dark green
- olive and concrete
- hazard amber
- heavy blocks and hard edges

Suggested palette:

- background: `#0f130f`
- surface: `#1a2219`
- text: `#d9e0cf`
- accent: `#5d8c45`
- accent-strong: `#b4a14d`
- warning: `#d96b2b`

Typography direction:

- dense, weighty UI
- less glow, more structure
- stronger borders than the other corps

## Recommended Rollout

Implement the corp themes in this order:

1. `kitty`
2. `rofi`
3. `waybar`
4. wallpapers and optional assets

That keeps the theme work visible without risking the base session.

## First Theme

Recommended first implementation: `Jinteki`

Why:

- it is immediately distinctive
- it can feel dramatic without needing many components
- it will look good first in `kitty` and `rofi`, where contrast matters

Recommended second implementation: `Haas-Bioroid`

Why:

- it is easier to make polished and broadly usable
- it can become the most practical “daily driver” theme
