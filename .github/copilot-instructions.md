# Copilot Instructions for BossHP SourceMod Plugin

## Repository Overview

This repository contains **BossHP**, a SourceMod plugin for Source engine games that provides advanced management of boss entities through configurable health monitoring systems. The plugin tracks boss health using various methods (breakable entities, math_counter entities, or complex HP bar systems) displays boss health to players on a HUD, ranks the players who hit each boss, and provides events/forwards and natives for other plugins.

**Key Features:**
- Multiple boss health tracking methods (breakable, counter, hpbar)
- Per-map configuration system
- Template-based multi-instance boss support
- Boss health HUD (center, game text or hint), with the health of any damaged entity with health
- Top hits table when a boss dies, with optional money and stats rewards
- Event forwarding system and natives for other plugins
- Extensive logging and debugging capabilities

## Technical Environment

- **Language**: SourcePawn (.sp files)
- **Platform**: SourceMod 1.11.0+ (latest stable release)
- **Build System**: Native GitHub Actions (.github/workflows/ci.yml)
- **Compiler**: SourcePawn compiler (spcomp) via rumblefrog/setup-sp
- **Dependencies**: outputinfo extension, clientprefs, smlib, basic plugin, multicolors, loghelper, DynamicChannels (optional at runtime)

## Project Structure

```
addons/sourcemod/
├── scripting/
│   ├── BossHP.sp                 # Entry point: shared state, SourceMod callbacks
│   ├── BossHP/
│   │   ├── utils.sp             # Shared helpers (entity lookup, math_counter health, strings)
│   │   ├── triggers.sp          # trigger/showtrigger/killtrigger/hurttrigger matching and hooks
│   │   ├── config.sp            # Map config loading and parsing, config commands
│   │   ├── boss.sp              # Boss lifecycle: add, init, process, remove
│   │   ├── api.sp               # Forwards and natives
│   │   ├── hud.sp               # Health HUD, damaged entities, admin health commands
│   │   └── hits.sp              # Boss hits, top hits table, rewards, death notice
│   └── include/
│       ├── BossHP.inc           # Public API definitions and forwards
│       ├── CBoss.inc            # Boss entity methodmap classes
│       └── CConfig.inc          # Configuration methodmap classes
├── configs/bosshp/              # Per-map configuration files
│   └── [mapname].cfg            # Map-specific boss configurations
├── translations/
│   └── BossHP.phrases.txt       # Plugin translations
└── plugins/                     # Compiled output directory
    └── BossHP.smx               # Compiled plugin
```

### Key Files:
- **BossHP.sp**: Entry point only. Declares the state shared by the modules (`g_aConfig`, `g_aBoss`, ...) and owns every SourceMod callback (`OnPluginStart`, `OnGameFrame`, `OnClientConnected`, ...), which dispatch to the modules
- **BossHP/*.sp**: Modules included by BossHP.sp. Their entry points are prefixed with the module name (`Config_`, `Bosses_`, `Triggers_`, `API_`, `HUD_`, `Hits_`). Hook callbacks a module registers itself (entity outputs, SDKHooks, timers) live in that module
- **BossHP/triggers.sp**: The four trigger kinds share one code path, selected by the `BossTrigger` enum (`BossTrigger_Spawn`, `_Show`, `_Kill`, `_Hurt`)
- **BossHP.inc**: Public API with natives and forwards for other plugins
- **CBoss.inc**: Methodmap classes for different boss types (CBoss, CBossBreakable, CBossCounter, CBossHPBar)
- **CConfig.inc**: Methodmap classes for configuration management
- **.github/workflows/ci.yml**: Build system configuration and dependencies

## Code Style & Standards

### SourcePawn Conventions (CRITICAL):
```sourcepawn
#pragma semicolon 1              // Always required
#pragma newdecls required        // Always required

// Variable naming
int g_iGlobalVariable;           // Prefix globals with "g_", use type prefix
int iLocalVariable;              // camelCase for locals
float fDelayTime;                // Type prefixes: i(int), f(float), b(bool), s(string)

// Function naming
void ProcessEntitySpawned()      // PascalCase for functions
bool BossInit(CBoss boss)        // Descriptive names

// Memory management
delete arrayHandle;              // Use delete directly, no null check needed
arrayHandle = new ArrayList();   // Create new after delete
// NEVER use .Clear() on StringMap/ArrayList - causes memory leaks
```

### Project-Specific Patterns:

1. **Methodmap Usage**: Uses methodmap extensively for object-oriented patterns
```sourcepawn
methodmap CBoss < Basic
{
    property int iHealth { get; set; }
    property CConfig dConfig { get; set; }
}
```

2. **Memory Management**: Always use `delete` without null checks
```sourcepawn
delete g_aBoss;                  // Preferred
g_aBoss = new ArrayList();       // Recreate after delete
```

3. **Entity Finding**: Uses custom FindEntityByTargetname() supporting HammerID (#123) and wildcards
```sourcepawn
int entity = FindEntityByTargetname(INVALID_ENT_REFERENCE, "#1234", "math_counter");
```

4. **Configuration System**: Uses KeyValues with specific structure for boss definitions

## Boss System Architecture

### Boss Types:
1. **Breakable**: Monitors entity health (m_iHealth) directly; with "scripthealth", syncs it from a VScript variable first
2. **Counter**: Tracks math_counter values with min/max calculations  
3. **HPBar**: Complex system using iterator + counter + backup math_counter entities

### Configuration Format:
```
"bosses"
{
    "0"
    {
        "name"          "Boss Name"
        "method"        "breakable|counter|hpbar"
        "trigger"       "entity_name:output_name:delay"
        "showtrigger"   "entity_name:output_name:delay"  // Optional
        "killtrigger"   "entity_name:output_name:delay"  // Optional
        "hurttrigger"   "entity_name:output_name"        // Optional, counts the hits instead of the health entity outputs
        
        // Method-specific properties
        "breakable"     "breakable_entity_name"          // For breakable method
        "scripthealth"  "health"                         // Optional (breakable): VScript variable copied into m_iHealth
        "counter"       "math_counter_name"              // For counter method
        "iterator"      "iterator_counter_name"          // For hpbar method
        "backup"        "backup_counter_name"            // For hpbar method
        
        // Optional settings
        "multitrigger"  "1"                              // Allow multiple triggers
        "namefixup"     "1"                              // Template support (&0001 suffix)
        "offset"        "100"                            // Health offset
        "timeout"       "30.0"                           // Auto-cleanup time
    }
}
```

### Template System:
- When `namefixup` is enabled, supports multiple instances via `&XXXX` suffix
- Example: `boss_counter&0001`, `boss_counter&0002` for multiple instances
- Automatically detects and assigns template numbers

## API Reference

### Forwards (for other plugins):
```sourcepawn
forward void BossHP_OnAllBossProcessStart(ArrayList aBoss);
forward void BossHP_OnAllBossProcessEnd(ArrayList aBoss);
forward void BossHP_OnBossInitialized(CBoss boss);
forward void BossHP_OnBossProcessed(CBoss boss, bool bHealthChanged, bool bShow);
forward void BossHP_OnBossDead(CBoss boss);
forward void BossHP_OnBossDamaged(CBoss boss, CConfig config, int activator, float damage);
```

### Natives:
```sourcepawn
native bool BossHP_IsBossEnt(int entity, CBoss &boss = view_as<CBoss>(INVALID_HANDLE));
native int BossHP_GetBossHealth(int bossEnt);
native int BossHP_GetBossMaxHealth(int bossEnt);
native bool BossHP_GetBossName(int bossEnt, char[] buffer, int maxlen);
native int BossHP_GetBossHits(int bossEnt);
native int BossHP_GetBossHitsCount(int bossEnt);
native int BossHP_GetBossHitsByClient(int bossEnt, int client);
native int BossHP_GetBossHitsRank(int bossEnt, int client);
native int BossHP_GetBossTopHits(int bossEnt, int maxPlayers, int[] topHits);
```

### Boss Object Properties:
```sourcepawn
CBoss boss;
boss.iHealth         // Current health
boss.iBaseHealth     // Initial health
boss.iLastHealth     // Previous health
boss.bShow           // Should display to players
boss.dConfig         // Associated configuration
```

## Build System (GitHub Actions)

### Build Commands:
```bash
# Compile locally with spcomp (from addons/sourcemod/scripting, with
# dependency includes placed under include/)
spcomp -i include -o ../plugins/BossHP.smx BossHP.sp
```

CI builds automatically via `.github/workflows/ci.yml` on every push, pull
request, and manual dispatch — no local toolchain installation required.

### Development Dependencies:
- SourceMod 1.12.0-git7223 (auto-downloaded via rumblefrog/setup-sp)
- ext-outputinfo extension
- smlib include library
- basic plugin methodmap library
- multicolors plugin
- loghelper include
- DynamicChannels include

### CI/CD:
- GitHub Actions automatically builds on push/PR
- Creates releases with compiled .smx files
- Packages with configs and dependencies

## Development Workflow

### Adding New Boss Types:
1. Create new methodmap class in CBoss.inc extending CBoss
2. Create corresponding config class in CConfig.inc extending CConfig
3. Add method enum value in eConfigMethod
4. Implement BossInit() and BossProcess() logic in BossHP/boss.sp, and list its entities in GetBossEntities()
5. Update config parsing in Config_Parse() (BossHP/config.sp)

### Creating Map Configurations:
1. Create `configs/bosshp/mapname.cfg` file
2. Use KeyValues format with "bosses" root
3. Test with `sm_bosshp_reload` command
4. Enable verbose logging: `sm_bosshp_verbose 2`

### Debugging:
- Use `sm_bosshp` command to check config status
- Enable verbose logging for detailed output
- Check entity validity with IsValidEntity()
- Monitor forwards being called correctly

## Common Patterns

### Entity Output Hooking:
```sourcepawn
// Hook single entity output
HookSingleEntityOutput(entity, "OnBreak", OnEntityOutput, false);

// Hook SDKHooks for damage
SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
```

### Configuration Access:
```sourcepawn
CConfig config = boss.dConfig;
char sName[64];
config.GetName(sName, sizeof(sName));
bool bMultiTrigger = config.bMultiTrigger;
```

### Memory Cleanup:
```sourcepawn
// In cleanup functions
for (int i = 0; i < g_aBoss.Length; i++)
{
    CBoss boss = g_aBoss.Get(i);
    delete boss;
}
delete g_aBoss;
g_aBoss = new ArrayList();  // Recreate immediately
```

## Testing & Validation

### Manual Testing:
1. Load test map with boss configuration
2. Use `sm_bosshp` to verify config loading
3. Enable verbose logging to monitor boss detection
4. Trigger boss events and verify health tracking
5. Test with multiple boss instances if using templates

### Configuration Validation:
- Ensure all required fields are present
- Verify entity names exist in map
- Test trigger/output combinations
- Validate method-specific parameters

## Performance Considerations

- Boss processing occurs every game frame when active
- Use entity validity checks before accessing properties
- Minimize string operations in frequently called functions
- Cache configuration values rather than repeated lookups
- Consider timeout values to prevent memory leaks

## Error Handling

- All entity operations should check IsValidEntity()
- Configuration parsing sets g_bConfigError flag on issues
- Use try/catch patterns for risky operations
- Provide detailed error logging for debugging
- Gracefully handle missing entities or invalid configurations

## Version Information

- Current version defined in BossHP.inc: "1.6.0"
- Uses semantic versioning (MAJOR.MINOR.PATCH)
- Version checks available via BossHP_VERSION constant