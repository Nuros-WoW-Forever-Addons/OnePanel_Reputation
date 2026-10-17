# OnePanel_Reputation

**OnePanel_Reputation** is a modular faction standing and reputation tracking plugin for the **OnePanel** suite, featuring real-time search filtering, collapsible expansion categories, high-contrast progress bars, and interactive faction management.

Part of the **OneSuite** family of addons.

---

## 🚀 Features

- 📜 **Collapsible Expansion Categories**:
  - Neatly groups factions by expansion and zone (Classic, The Burning Crusade, Wrath of the Lich King, etc.) with 1-click header collapsing.
- 🔍 **Real-Time Search Filtering**:
  - Instant text search box at the top of the window filtering factions dynamically as you type.
- 📊 **High-Contrast Progress Bars**:
  - Color-coded standing bars (Hated, Hostile, Unfriendly, Neutral, Friendly, Honored, Revered, Exalted).
  - Calibrated deep-tone bar fills ensuring white text and numbers maintain maximum readability.
  - Dual numerical display: exact standing values (`12,450 / 21,000`) and percentage (`59%`).
- ⚔️ **Interactive Faction Details Panel**:
  - Click any faction row to inspect lore descriptions and manage settings:
    - **Show as Experience Bar**: Track faction standing directly on the primary HUD watch bar.
    - **At War**: Toggle hostile combat status with neutral factions.
    - **Move to Inactive**: Hide completed or inactive factions into a collapsed Inactive group.
- 📑 **Seamless OnePanel Docking**: Automatically registers into OnePanel; accessible via the native `U` keybind or `/op`.

---

## 🛠️ Installation

Copy the `OnePanel_Reputation` directory (along with `OnePanel` and `OnePanelUtils`) into your World of Warcraft `Interface/AddOns/` directory:

```text
World of Warcraft/Interface/AddOns/OnePanel_Reputation/
├── OnePanel_Reputation.toc
├── Core.lua
├── CHANGELOG.md
├── CONTEXT.md
└── README.md
```

Then start or reload World of Warcraft (`/reload`).

---

## 💻 Slash Commands & Access

`OnePanel_Reputation` docks directly inside the OnePanel master frame:

| Command / Hotkey | Description |
|---|---|
| `U` (Default Keybind) | Open OnePanel directly to the Reputation tab |
| `/op` or `/onepanel` | Toggle the OnePanel master window |

---

For detailed version history and release notes, see [CHANGELOG.md](CHANGELOG.md).
