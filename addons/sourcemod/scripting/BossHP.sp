#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <BossHP>
#include <outputinfo>
#include <smlib>
#include <multicolors>
#include <loghelper>

#undef REQUIRE_PLUGIN
#tryinclude <DynamicChannels>
#define REQUIRE_PLUGIN

#define CHAT_PREFIX "{lightgreen}[BossHP]{default} "
#define CONSOLE_PREFIX "[BossHP] "

// State shared by the modules
ArrayList g_aConfig = null;     // CConfig of the current map
ArrayList g_aBoss = null;       // CBoss of the current round
StringMap g_aHadOnce = null;    // Configs (by index) whose single-use trigger already fired this round

bool g_bConfigLoaded = false;
bool g_bConfigError = false;

ConVar g_cvVerboseLog;
ConVar g_cvIgnoreBots;

bool g_bLate = false;

// Plugin entry point: owns the SourceMod callbacks and dispatches them to the modules
#include "BossHP/utils.sp"
#include "BossHP/triggers.sp"   // trigger, showtrigger, killtrigger and hurttrigger
#include "BossHP/config.sp"     // Map config parsing
#include "BossHP/boss.sp"       // Boss lifecycle and health
#include "BossHP/api.sp"        // Forwards and natives
#include "BossHP/hud.sp"        // Health HUD and admin health commands
#include "BossHP/hits.sp"       // Boss hits, top hits table and rewards

public Plugin myinfo =
{
	name 			= "BossHP",
	author 			= "BotoX, Cloud Strife, maxime1907, AntiTeal",
	description 	= "Advanced management of entities via configurations, with a boss health HUD and top hits",
	version 		= BossHP_VERSION,
	url 			= "https://github.com/srcdslab/sm-plugin-BossHP"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;

	API_AskPluginLoad2();
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("BossHP.phrases");

	g_cvVerboseLog = CreateConVar("sm_bosshp_verbose", "0", "Verbosity level of logs (0 = error, 1 = info, 2 = debug)", _, true, 0.0, true, 2.0);
	g_cvIgnoreBots = CreateConVar("sm_bosshp_ignore_bots", "1", "Ignore the damage dealt by bots (boss hits and entity health)", _, true, 0.0, true, 1.0);

	HookEvent("round_end", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEntityOutput("env_entity_maker", "OnEntitySpawned", OnEnvEntityMakerEntitySpawned);

	// Damage from players, used for the boss hits and to show the health of other entities
	HookEntityOutput("func_breakable", "OnHealthChanged", OnEntityOutputDamage);
	HookEntityOutput("func_physbox", "OnHealthChanged", OnEntityOutputDamage);
	HookEntityOutput("func_physbox_multiplayer", "OnHealthChanged", OnEntityOutputDamage);
	HookEntityOutput("math_counter", "OutValue", OnEntityOutputDamage);

	Config_OnPluginStart();
	API_OnPluginStart();
	HUD_OnPluginStart();
	Hits_OnPluginStart();

	AutoExecConfig(true);

	if (g_bLate)
	{
		HUD_OnLateLoad();
		Hits_OnMapStart();
	}
}

public void OnConfigsExecuted()
{
	Config_Load();
}

public void OnMapStart()
{
	Hits_OnMapStart();
}

public void OnMapEnd()
{
	Bosses_Cleanup();
	Config_Cleanup();
	HUD_OnMapEnd();
	Hits_OnMapEnd();
}

public void OnAllPluginsLoaded()
{
	HUD_UpdateDynamicChannels();
}

public void OnLibraryAdded(const char[] name)
{
	HUD_OnLibraryChanged(name);
}

public void OnLibraryRemoved(const char[] name)
{
	HUD_OnLibraryChanged(name);
}

public void OnClientConnected(int client)
{
	HUD_OnClientConnected(client);
	Hits_OnClientConnected(client);
}

public void OnClientDisconnect(int client)
{
	HUD_OnClientDisconnect(client);
}

public void OnClientCookiesCached(int client)
{
	HUD_ReadClientCookies(client);
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bConfigLoaded && g_cvVerboseLog.IntValue > 0)
		CPrintToChatAll(CHAT_PREFIX ... "The current map is supported by this plugin.");
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	Bosses_Reset();
}

public void OnGameFrame()
{
	Bosses_OnGameFrame();
	HUD_OnGameFrame();
}

// ######## ##    ## ######## #### ######## #### ########  ######
// ##       ###   ##    ##     ##     ##     ##  ##       ##    ##
// ##       ####  ##    ##     ##     ##     ##  ##       ##
// ######   ## ## ##    ##     ##     ##     ##  ######    ######
// ##       ##  ####    ##     ##     ##     ##  ##             ##
// ##       ##   ###    ##     ##     ##     ##  ##       ##    ##
// ######## ##    ##    ##    ####    ##    #### ########  ######

public void OnEntityCreated(int entity, const char[] classname)
{
	if (GetFeatureStatus(FeatureType_Native, "SDKHook_OnEntitySpawned") == FeatureStatus_Available)
		return;

	SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawnedPost);
}

public void OnEntitySpawnedPost(int entity)
{
	if (!IsValidEntity(entity))
		return;

	// 1 frame later required to get some properties
	RequestFrame(Triggers_OnEntitySpawned, entity);

	char sClassname[64];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	HUD_OnEntitySpawned(entity, sClassname);
}

public void OnEntitySpawned(int entity, const char[] classname)
{
	Triggers_OnEntitySpawned(entity);
	HUD_OnEntitySpawned(entity, classname);
}

public void OnEntityDestroyed(int entity)
{
	HUD_OnEntityDestroyed(entity);
}

// Any health change of an entity with health: boss hits, or the health of the entity on the HUD
public void OnEntityOutputDamage(const char[] output, int caller, int activator, float delay)
{
	bool bValidClient = IsValidClient(activator, g_cvIgnoreBots.BoolValue);

	CBoss Boss;
	if (IsBossEntity(caller, Boss))
	{
		// Called for every health change, so the health of breakable bosses stays in sync
		Hits_OnBossEntityDamaged(Boss, bValidClient ? activator : -1);
	}
	else if (bValidClient)
	{
		HUD_OnEntityDamaged(caller);
	}

	if (bValidClient)
		HUD_SetClientEntity(activator, caller);
}
