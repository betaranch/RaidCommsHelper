# RaidCommsHelper

A World of Warcraft addon for raid leaders to quickly send templated announcements with keybind support.

## Features

- **Quick Message Templates** - Organize messages into folders and send them with one click or keybind
- **Keybind Support** - Bind up to 12 message slots to keys for instant raid communication
- **Smart Chat Routing** - Automatically uses Raid Warning, Raid, Party, or Say based on your group and permissions
- **Template Variables** - Use placeholders like `{target}`, `{zone}`, `{time}` in your messages
- **Versatility Tracking** - Track and display group member versatility stats (useful for WoW Remix content)
- **Summon Panel** - Quick access to warlock summons and meeting stone coordination

## Installation

1. Download the latest release
2. Extract `RaidCommsHelper` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
3. Restart WoW or type `/reload`

## Usage

### Slash Commands

| Command | Description |
|---------|-------------|
| `/rch` | Open the main window |
| `/rch folder <name>` | Switch active message folder |
| `/rch list` | List all folders |
| `/rch send <n>` | Send message #n from active folder |
| `/rch test <template>` | Test template variable expansion |
| `/rch reset` | Reset all settings to defaults |

### Keybinds

Open **Options > Keybindings** and search for "RaidCommsHelper" to bind:
- Toggle Window
- Message Slots 1-12
- Open Vers Panel

### Template Variables

Use these in your message templates:

| Variable | Description |
|----------|-------------|
| `{target}` | Your current target's name |
| `{focus}` | Your focus target's name |
| `{zone}` | Current zone name |
| `{time}` | Current server time |
| `{group}` | Your group number |

## Examples

**Pull Timer:**
```
PULL IN 10 SECONDS - {target}
```

**Boss Assignment:**
```
TANKS: {target} - HEALERS: Check assignments
```

## License

MIT License - Feel free to use and modify.

## Links

- [CurseForge](https://www.curseforge.com/wow/addons/raidcommshelper)
- [GitHub](https://github.com/betaranch/RaidCommsHelper)
- [Issues](https://github.com/betaranch/RaidCommsHelper/issues)
