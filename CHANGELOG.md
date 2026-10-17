# Changelog — OnePanel_Reputation

All notable changes to **OnePanel_Reputation** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.2] - 2026-10-17
### Added
- **Grey Button Category Headers**: Replaced text-only headers with Blizzard grey metallic button banners (`UIPanelButtonTemplate`) featuring centered 13pt gold titles, matching the Character Stats and Skills subpanel visual language.
- **Modern Gradient Progress Bars**: Integrated authentic Dragonflight/Camelot gradient fill textures (`ui-castingbar-filling-*`, `common-stat-bar-white`), metallic frames (`ui-castingbar-frame`), inset tracks (`ui-castingbar-background`), and dynamic leading-edge sparks (`ui-castingbar-pip`).
- **Unified High-Legibility Typography**: Standardized all faction names, standing tags, detail drawer headers, descriptions, and progress counters on Friz Quadrata TT (`Fonts\FRIZQT__.TTF`) with clean `(1, -1)` drop shadows, removing dark outline bleeding.

## [0.0.1] - 2026-10-10
### Added
- **Collapsible Category Hierarchy**: Expansion header grouping with expansion/collapse state memory.
- **Dynamic Search Engine**: Real-time filtering matching faction names, headers, and standings.
- **Calibrated Contrast Progress Bars**: Deeper background fill hues ensuring crisp white text legibility across all 8 standing levels.
- **Interactive Faction Management Flyout**: Support for XP bar tracking, At War toggle, and Inactive list management.
- **OnePanel Host Integration**: Docked via `OnePanel:RegisterPlugin` as the master Reputation tab.
