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

## On-Disk Structure

Themes live under:

```text
~/.config/bsdrunner/
├── current-theme
└── themes/
    ├── default/
    │   ├── palette.conf
    │   ├── kitty.conf
    │   ├── rofi.rasi
    │   └── waybar.css
    ├── haas-bioroid/
    │   ├── palette.conf
    │   ├── kitty.conf
    │   ├── rofi.rasi
    │   └── waybar.css
    ├── jinteki/
    │   ├── palette.conf
    │   ├── kitty.conf
    │   ├── rofi.rasi
    │   ├── waybar.css
    │   ├── dolphin.colors
    │   ├── qt6ct.conf
    │   └── wallpapers/
    ├── nbn/
    │   ├── palette.conf
    │   ├── kitty.conf
    │   ├── rofi.rasi
    │   └── waybar.css
    └── weyland/
        ├── palette.conf
        ├── kitty.conf
        ├── rofi.rasi
        └── waybar.css
```

Rules:

- `current-theme` stores the active theme name
- `default` means "no corp theme"
- files under `themes/` are source files, not the active runtime files
- active app configs still live in normal locations like `~/.config/kitty/kitty.conf`

## Theme Responsibilities

Each theme folder should be responsible for:

- `palette.conf`: named colors and semantic accents
- `kitty.conf`: terminal-specific theme overrides
- `rofi.rasi`: launcher styling
- `waybar.css`: bar-specific color and panel overrides
- `dolphin.colors`: KDE/Qt color scheme for Dolphin and related Qt apps
- `qt6ct.conf`: qt6ct palette file for Qt application theming outside Plasma
- `wallpapers/`: optional wallpaper assets for the theme

Later additions may include:

- `waybar.css`
- wallpaper references
- icon or asset notes

## Theme Switching Model

The intended switching model is:

1. keep stable, neutral base configs in normal app locations
2. choose a theme name from `themes/`
3. copy or render theme fragments into active config files
4. allow `default` to restore the neutral visual baseline

Current implementation:

- `install-dotfiles.sh --theme <name>` writes `current-theme`
- Kitty is rendered from the stable base `kitty.conf` plus the selected theme fragment
- Rofi is activated by copying the selected `rofi.rasi` to `~/.config/rofi/config.rasi`
- Waybar is rendered from the stable base `style.css` plus the selected `waybar.css` fragment
- if a theme ships `wallpapers/`, install writes a matching `~/.config/bsdrunner/current-wallpaper`
- when a theme ships multiple wallpapers, the `swww` helper rotates them by workspace number
- Dolphin theming is not automated yet; `.colors` files are theme assets for manual testing
- qt6ct theming is not automated yet; `qt6ct.conf` assets are for manual testing first
- wallpapers are bundled as theme assets and can be activated through `swww` during install

Important:

- switching themes should never replace `hyprland.conf`
- theme switching should not be required for the desktop to boot
- a broken theme should be recoverable by switching back to `default`
- `swww` is treated as part of the expected themed runtime
- themes may ship multiple wallpaper assets even if only one is selected by default

## Manual Qt/Dolphin Test

On your FreeBSD laptop, if `qt6ct` is already active and `~/.config/qt6ct/qt6ct.conf` points at a file like:

```ini
style=Breeze
color_scheme_path=/usr/share/qt6ct/colors/darker.conf
```

then the safest Jinteki test is to keep the global Qt style alone and swap only the color scheme path.

1. Copy the Jinteki qt6ct palette into your user palette directory:

```sh
mkdir -p ~/.config/qt6ct/colors
cp ~/.config/bsdrunner/themes/jinteki/qt6ct.conf ~/.config/qt6ct/colors/jinteki.conf
```

2. Edit `~/.config/qt6ct/qt6ct.conf` and change:

```ini
color_scheme_path=/usr/share/qt6ct/colors/darker.conf
```

to:

```ini
color_scheme_path=/home/YOUR_USER/.config/qt6ct/colors/jinteki.conf
```

3. Fully quit Dolphin and reopen it.

4. If the result looks wrong, revert by restoring the original `color_scheme_path`.

This keeps the test reversible and avoids overwriting any system-provided qt6ct color files.

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

Current implementation status:

- `palette.conf`: scaffolded
- `kitty.conf`: first-pass theme fragment defined
- `rofi.rasi`: first-pass theme defined
- `waybar.css`: first-pass theme fragment defined
- `dolphin.colors`: first-pass KDE color scheme defined
- `qt6ct.conf`: first-pass qt6ct palette defined
- `wallpapers/`: four bundled Jinteki wallpaper images
