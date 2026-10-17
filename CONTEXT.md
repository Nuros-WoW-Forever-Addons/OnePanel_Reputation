# AI Context & Living Specification — OnePanel_Reputation

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OnePanel_Reputation
- **Current Version**: 0.0.2
- **Suite**: Part of the **OneSuite** family (OnePanel Plugin)
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OnePanel_Reputation
  *(For any new addon, initialize with Exists: FALSE until first commit/push)*
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/OnePanel_Reputation/`
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OnePanel_Reputation-latest.zip` on push to `main`
- **Dependencies**: `OnePanel`, `OnePanelUtils`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Deliver a modern, searchable, highly readable Reputation management interface docked into OnePanel, replacing Blizzard's basic reputation frame with high-contrast progress bars, collapsible categories, and responsive faction controls.

---

## 🏗️ Architecture & Component Map

### File Structure
- `OnePanel_Reputation.toc`: Manifest, declares dependencies on `OnePanel` and `OnePanelUtils`.
- `Core.lua`: Complete plugin implementation:
  - Faction standing labels and high-contrast color lookup tables (`BAR_FILL_COLORS`, `STANDING_TEXT_COLORS`).
  - ScrollFrame list generator with recycled row widgets.
  - Live search input box logic.
  - Interactive faction details flyout frame (At War, Inactive, Watch XP bar).
  - Event listeners: `UPDATE_FACTION`, `QUEST_LOG_UPDATE`, `PLAYER_ENTERING_WORLD`.
  - Plugin registration with OnePanel (`OnePanel:RegisterPlugin`).

### Registration Payload with OnePanel
```lua
OnePanel:RegisterPlugin({
    id = "Reputation",
    name = "Reputation",
    icon = "Interface\\Icons\\Achievement_Reputation_01",
    order = 2,
    frame = reputationContainer,
    onShow = function() ... end,
    onHide = function() ... end,
})
```

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:

1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and active backlog items.
2. **Implementation**: Execute changes. For code refactoring or boilerplate, delegate to `qwen2.5-coder:32b` via the local `gx10_ollama` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test by pressing `U` or running `/op`.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.0.2
- **Grey Button Category Headers**: Replaced text-only expandable headers with Blizzard grey metallic button banners (`UIPanelButtonTemplate`, disabled metal appearance, centered 13pt gold typography, interactive expand/collapse clicks with `(X/Y Exalted)` count badges).
- **Dragonflight/Camelot Gradient Progress Bars**: Integrated authentic gradient fill textures (`ui-castingbar-filling-*`, `common-stat-bar-white`), metallic frames (`ui-castingbar-frame`), inset tracks (`ui-castingbar-background`), and dynamic leading-edge sparks (`ui-castingbar-pip`) across all faction list rows and the right-hand details drawer.
- **Unified High-Legibility Typography**: Standardized all faction names, standing tags, detail drawer headers, descriptions, and progress counters on Friz Quadrata TT (`Fonts\FRIZQT__.TTF`) with clean `(1, -1)` drop shadows, completely eliminating illegible dark outline bleeding.

### Spin 0.0.1
- High-contrast bar fill coloration calibrated for crisp white text readability.
- Real-time search filter box with auto-clearing and instant list refresh.
- Collapsible category headers with persistent expanded state memory.
- Interactive flyout dialog for faction toggles (Watch Bar, At War, Inactive).
- Integrated into OnePanel event bus (`ONEPANEL_EXPAND_STATE_CHANGED`).

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **Reputation Gain Delta Indicator**: Show recent reputation gains in chat or as a floating badge (`+250 Rep`) when completing quests or defeating mobs.
- [ ] **Paragon Standing Support**: Full support for Paragon reputation levels and reward bag tracking on Modern/WoW Forever clients.

### Priority 2: Medium Priority (Enhancements)
- [ ] **Faction Reward Preview**: Hover tooltip showing quartermaster rewards available at the next standing tier.
- [ ] **Quick Favorite / Pin Faction**: Pin favorite factions to the very top of the list regardless of expansion header.

### Priority 3: Low Priority / Exploration
- [ ] **Auto-Switch Watch Bar**: Option to automatically switch the watched HUD reputation bar to whatever faction was most recently increased.

---

## 🧪 Testing & Verification Guide

- **Open Panel**: Press `U` — confirm OnePanel opens with Reputation tab selected and faction list rendered.
- **Search Filtering**: Type a faction name (e.g. "Argent") — verify matching factions filter instantly.
- **Collapse/Expand**: Click expansion header arrow — verify child factions collapse smoothly.
- **Faction Details**: Click a faction row — confirm details flyout appears with correct standing and working toggles.

---

## ⚠️ Technical Constraints & Engine Gotchas

- **Faction Header Indexing**: Blizzard's `GetFactionInfo(i)` indices change dynamically when categories collapse or expand. Ensure the internal data cache maps stable faction IDs (`factionID`) rather than volatile display indices.
- **Taint Safety**: Do not modify Blizzard's native `ReputationFrame` global variables. Render independently inside OnePanel's container frame.
