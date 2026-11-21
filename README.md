# BossHP

SourceMod plugin for Counter-Strike: Source zombie escape maps: it tracks map bosses from a per-map
config, shows their health on a HUD, counts the hits of each player and shows a top hits table when a
boss dies. It also shows the health of other damaged entities (`func_breakable`, `math_counter`).

Since 2.0.0, BossHP includes the former **BossHUD** plugin: everything runs from a single
`BossHP.smx`. See [Migrating from BossHUD](#migrating-from-bosshud-to-bosshp-20).

## Features

- Boss tracking with three methods: `breakable` (entity health, or a VScript variable), `counter`
  (`math_counter`) and `hpbar` (counter + iterator, with an optional backup counter).
- Boss triggers: spawn, show, kill and hurt, from an entity output or `OnTakeDamage`, with an optional
  delay.
- Health HUD (center, game text or hint) for bosses and for other damaged entities, toggled per player
  with `sm_bhp` or `!settings` (saved in a cookie).
- Per player boss hits, top hits table (HUD, chat, console), $1 per hit, stats event for the top players
  (loghelper) and a kill feed entry when a boss dies.
- Forwards and natives for other plugins (`BossHP` library).
- Translations in 13 languages (`BossHP.phrases.txt`).

## Requirements

- SourceMod 1.12 or newer (release builds for 1.12 and 1.13).
- [OutputInfo](https://github.com/srcdslab/sm-ext-outputinfo) extension.
- Optional: [DynamicChannels](https://github.com/srcdslab/sm-plugin-DynamicChannels), to pick the
  game text channels (`sm_bosshp_hud_channel`, `sm_bosshp_tophits_channel`).

## Installation

1. Download the [latest release](https://github.com/srcdslab/sm-plugin-BossHP/releases) for your
   SourceMod version.
2. Copy `plugins/BossHP.smx` and `translations/BossHP.phrases.txt` to `addons/sourcemod/`.
3. Add the map configs to `addons/sourcemod/configs/bosshp/`.
4. Restart the server (or change the map). `cfg/sourcemod/plugin.BossHP.cfg` is created on the first
   load.

## Map configs

The config of a map is read from `addons/sourcemod/configs/bosshp/`, first `<map>_override.cfg`, then
`<map>.cfg` (each also tried in lowercase). Each section is one boss:

```
"bosses"
{
	"0"
	{
		"name"        "Bahamut"
		"method"      "counter"
		"trigger"     "calcVidaD:OnStartTouch"
		"counter"     "bahamut_vida"
	}
}
```

| Key | Description |
| --- | --- |
| `name` | Name shown on the HUD (required). |
| `method` | `breakable`, `counter` or `hpbar`. Inferred when not set: `breakable` if `breakable` is set, `hpbar` if `counter` and `iterator` are set, else `counter`. |
| `breakable` | Targetname of the breakable entity (`breakable` method). |
| `scripthealth` | VScript variable holding the health of a VScript-driven breakable boss (`breakable` method). |
| `counter` | Targetname of the health `math_counter` (`counter` and `hpbar` methods). |
| `iterator` | Targetname of the `math_counter` counting the health bars (`hpbar` method). |
| `backup` | Targetname of the `math_counter` holding the value of one bar (`hpbar` method, optional). |
| `trigger` | `<entity>:<output>[:<delay>]` that creates the boss. When not set, the boss is created when its breakable is damaged (`OnTakeDamage`) or its counter changes (`OutValue`). |
| `showtrigger` | `<entity>:<output>[:<delay>]`: the boss is shown on the HUD only once this fires. |
| `killtrigger` | `<entity>:<output>[:<delay>]`: the boss is removed when this fires. |
| `hurttrigger` | `<entity>:<output>`: each time this fires counts as a hit (`OnTakeDamage` counts the real damage). When set, the boss entity itself no longer counts hits. |
| `multitrigger` | `1` to let the triggers fire more than once (default `0`). |
| `namefixup` | `1` for bosses spawned by a `point_template` with name fixup (default `0`). |
| `offset` | Value added to the health (default `0`). |
| `timeout` | Seconds without a health change after which the boss is hidden from the HUD (default `-1`, never). |
| `showhealth` | `0` to hide the boss from the HUD (default `1`). |
| `showbeaten` | `0` to skip the top hits table when the boss dies (default `1`). |
| `ignore_on_boss_hits` | `1` to not count hits on this boss (default `0`). |

`addons/sourcemod/configs/bosshp/missing.sh` lists the configs whose map is not installed.

## Commands

| Command | Access | Description |
| --- | --- | --- |
| `sm_bhp` | everyone | Toggle the boss health HUD (also in `!settings`). |
| `sm_currenthp` | generic | Show the health of the last entity you damaged. |
| `sm_addhp <value>` | generic | Add health to the last entity you damaged. |
| `sm_subtracthp <value>` | generic | Subtract health from the last entity you damaged. |
| `sm_bosshp` | generic | Check if the map config is loaded. |
| `sm_bosshp_reload` | config | Reload the map config. |

## Cvars

| Cvar | Default | Description |
| --- | --- | --- |
| `sm_bosshp_verbose` | `0` | Log verbosity (0 = error, 1 = info, 2 = debug). |
| `sm_bosshp_ignore_bots` | `1` | Ignore the damage dealt by bots (boss hits and entity health). |
| `sm_bosshp_init_retry` | `0.1` | Seconds between two lookups of the entities of a triggered boss not found yet (0 = every frame). |
| `sm_bosshp_init_timeout` | `60.0` | Seconds after which a triggered boss whose entities are still not found is dropped and logged (0 = never). |
| `sm_bosshp_hud_type` | `2` | HUD type (0 = center, 1 = game text, 2 = hint). |
| `sm_bosshp_hud_position` | `"-1.0 0.09"` | X and Y position of the HUD (game text only). |
| `sm_bosshp_hud_color` | `"255 0 0"` | RGB color of the HUD (game text only). |
| `sm_bosshp_hud_channel` | `1` | DynamicChannels group of the HUD (game text only). |
| `sm_bosshp_hud_symbols` | `0` | Wrap the health of damaged entities with `>>` and `<<`. |
| `sm_bosshp_hud_frames` | `7` | Refresh the HUD every N frames. |
| `sm_bosshp_entity_timeout` | `0.5` | Seconds before the health of a damaged entity fades away. |
| `sm_bosshp_entity_health_min` | `1000` | Minimum health of an entity to show it on the HUD. |
| `sm_bosshp_entity_health_max` | `100000` | Maximum health of an entity to show it on the HUD. |
| `sm_bosshp_tophits_players` | `3` | Number of players in the top hits table. |
| `sm_bosshp_tophits_uppercase` | `1` | Write the title of the top hits table in uppercase. |
| `sm_bosshp_tophits_position` | `"0.02 0.3"` | X and Y position of the top hits table. |
| `sm_bosshp_tophits_color` | `"255 255 0"` | RGB color of the top hits table. |
| `sm_bosshp_tophits_channel` | `2` | DynamicChannels group of the top hits table, must differ from `sm_bosshp_hud_channel`. |
| `sm_bosshp_tophits_console` | `1` | Print the hits of every player in the console when a boss dies. |
| `sm_bosshp_tophits_money` | `1` | Give $1 to a player for each boss hit. |
| `sm_bosshp_tophits_reward` | `0` | Log a stats event for the players in the top hits table. |
| `sm_bosshp_death_notice` | `1` | Show a kill feed entry when a boss dies. |

## API

Include `BossHP.inc` and check the `BossHP` library. The full documentation is in
[`BossHP.inc`](addons/sourcemod/scripting/include/BossHP.inc).

Forwards: `BossHP_OnAllBossProcessStart`, `BossHP_OnAllBossProcessEnd`, `BossHP_OnBossInitialized`,
`BossHP_OnBossProcessed`, `BossHP_OnBossDead`, `BossHP_OnBossDamaged`.

Natives: `BossHP_IsBossEnt`, `BossHP_GetBossHealth`, `BossHP_GetBossMaxHealth`, `BossHP_GetBossName`,
`BossHP_GetBossHits`, `BossHP_GetBossHitsCount`, `BossHP_GetBossHitsByClient`, `BossHP_GetBossHitsRank`,
`BossHP_GetBossTopHits`.

## Migrating from BossHUD to BossHP 2.0

BossHUD 3.8.17 was merged into BossHP 2.0.0 (#51) and
[its repository](https://github.com/srcdslab/sm-plugin-BossHUD) is archived. There is no compatibility
layer: BossHUD must be removed and its names changed. **Do not run `BossHUD.smx` next to BossHP 2.0.**

### Steps

1. Remove `plugins/BossHUD.smx`, `translations/BossHUD.phrases.txt` and
   `cfg/sourcemod/plugin.BossHUD.cfg`.
2. Install BossHP 2.0 (`BossHP.smx` and `BossHP.phrases.txt`). Delete `cfg/sourcemod/plugin.BossHP.cfg`
   so it is regenerated with the new cvars (AutoExecConfig does not add cvars to an existing file).
3. Carry over the BossHUD values that differ from the new defaults, for example
   `sm_bhud_frame_to_skip 9` (`sm_bosshp_hud_frames` defaults to `7`) or
   `sm_bhud_tophits_position "0.01 0.3"` (`sm_bosshp_tophits_position` defaults to `"0.02 0.3"`).
4. Update the plugins that call `BossHUD_*` natives or check the `BossHUD` library.
5. Restart the server. SourceMod keeps phrase files cached: without a restart, run
   `sm_reload_translations`. Until the restart, the deleted `BossHUD.phrases.txt` logs
   `Fatal error parsing BossHUD.phrases.txt` on every map (harmless).

### Commands, cookie, files

| BossHUD | BossHP 2.0 |
| --- | --- |
| `BossHUD.smx` | `BossHP.smx` |
| `sm_bhud`, `sm_bosshud` | `sm_bhp` |
| `sm_currenthp`, `sm_subtracthp`, `sm_addhp` | unchanged |
| cookie `bhud_showhealth` | `bosshp_hud` (players' choices reset to enabled) |
| `BossHUD.phrases.txt` | `BossHP.phrases.txt` |
| `BossHUD` library, `BossHUD.inc` | `BossHP` library, `BossHP.inc` |

### Natives

| BossHUD | BossHP 2.0 |
| --- | --- |
| `BossHUD_GetBossHealth` | `BossHP_GetBossHealth` |
| `BossHUD_GetBossMaxHealth` | `BossHP_GetBossMaxHealth` |
| `BossHUD_GetBossName` | `BossHP_GetBossName` (now returns `bool`) |
| `BossHUD_GetBossHits` | `BossHP_GetBossHits` |
| `BossHUD_GetBossHitsCount` | `BossHP_GetBossHitsCount` |
| `BossHUD_GetBossHitsByClient` | `BossHP_GetBossHitsByClient` |
| `BossHUD_GetBossHitsRank` | `BossHP_GetBossHitsRank` |
| `BossHUD_GetBossTopHits` | `BossHP_GetBossTopHits` |
| `BossHUD_IsBossActive` | dropped, use `BossHP_IsBossEnt` |

### Cvars

| BossHUD | BossHP 2.0 |
| --- | --- |
| `sm_bhud_displaytype` | `sm_bosshp_hud_type` |
| `sm_bhud_position` | `sm_bosshp_hud_position` |
| `sm_bhud_color` | `sm_bosshp_hud_color` |
| `sm_bhud_hud_channel` | `sm_bosshp_hud_channel` (health HUD only) |
| _(new)_ | `sm_bosshp_tophits_channel` |
| `sm_bhud_symbols` | `sm_bosshp_hud_symbols` |
| `sm_bhud_frame_to_skip` | `sm_bosshp_hud_frames` (min `1`) |
| `sm_bhud_timeout` | `sm_bosshp_entity_timeout` |
| `sm_bhud_health_min` / `_max` | `sm_bosshp_entity_health_min` / `_max` |
| `sm_bhud_ignore_fakeclients` | `sm_bosshp_ignore_bots` |
| `sm_bhud_tophits_players` | `sm_bosshp_tophits_players` |
| `sm_bhud_tophits_uppertitle` | `sm_bosshp_tophits_uppercase` |
| `sm_bhud_tophits_position` / `_color` | `sm_bosshp_tophits_position` / `_color` |
| `sm_bhud_notify_console` | `sm_bosshp_tophits_console` |
| `sm_bhud_tophits_money` | `sm_bosshp_tophits_money` |
| `sm_bhud_tophits_reward` | `sm_bosshp_tophits_reward` |
| `sm_bhud_boss_death_notice` | `sm_bosshp_death_notice` |

## License

[GPL-3.0](LICENSE)
