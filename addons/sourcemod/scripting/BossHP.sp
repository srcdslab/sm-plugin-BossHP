#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <BossHP>
#include <outputinfo>
#include <smlib>
#include <multicolors>

#define MathCounterBackupSize 10

Handle g_hForward_OnBossInitialized = INVALID_HANDLE;
Handle g_hForward_OnBossProcessed = INVALID_HANDLE;
Handle g_hForward_OnBossDead = INVALID_HANDLE;
Handle g_hForward_OnAllBossProcessStart = INVALID_HANDLE;
Handle g_hForward_OnAllBossProcessEnd = INVALID_HANDLE;

ArrayList g_aConfig = null;
ArrayList g_aBoss = null;
StringMap g_aHadOnce = null;

ConVar g_cvVerboseLog;

char g_sConfigLoaded[PLATFORM_MAX_PATH];

bool g_bConfigLoaded = false;
bool g_bConfigError = false;

public Plugin myinfo =
{
	name 			= "BossHP",
	author 			= "BotoX, Cloud Strife, maxime1907",
	description 	= "Advanced management of entities via configurations",
	version 		= BossHP_VERSION,
	url 			= ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("BossHP_IsBossEnt", Native_IsBossEntity);
	RegPluginLibrary("BossHP");
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", OnRoundEnd, EventHookMode_PostNoCopy);
	HookEntityOutput("env_entity_maker", "OnEntitySpawned", OnEnvEntityMakerEntitySpawned);

	RegAdminCmd("sm_bosshp_reload", Command_ReloadConfig, ADMFLAG_CONFIG, "Reload the BossHP Map Config File.");
	RegAdminCmd("sm_bosshp", Command_IsConfigLoaded, ADMFLAG_GENERIC, "Check if the BossHP Map Config File is loaded.");

	g_cvVerboseLog = CreateConVar("sm_bosshp_verbose", "0", "Verbosity level of logs (0 = error, 1 = info, 2 = debug)", _, true, 0.0, true, 2.0);

	g_hForward_OnAllBossProcessStart = CreateGlobalForward("BossHP_OnAllBossProcessStart", ET_Ignore, Param_Cell);
	g_hForward_OnAllBossProcessEnd = CreateGlobalForward("BossHP_OnAllBossProcessEnd", ET_Ignore, Param_Cell);
	g_hForward_OnBossInitialized = CreateGlobalForward("BossHP_OnBossInitialized", ET_Ignore, Param_Cell);
	g_hForward_OnBossProcessed = CreateGlobalForward("BossHP_OnBossProcessed", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hForward_OnBossDead = CreateGlobalForward("BossHP_OnBossDead", ET_Ignore, Param_Cell);

	AutoExecConfig(true);
}

public void OnConfigsExecuted()
{
	g_bConfigLoaded = false;
	g_bConfigError = false;
	LoadConfig();
}

public void OnMapEnd()
{
	Cleanup();
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bConfigLoaded && g_cvVerboseLog.IntValue > 0)
		CPrintToChatAll("{lightgreen}[BossHP]{default} The current map is supported by this plugin.");
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ProcessRoundEnd();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SDKHook_OnEntitySpawned") == FeatureStatus_Available)
		return;

	SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawnedPost);
}

public void OnEntityDestroyed(int entity)
{
	if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SDKHook_OnEntitySpawned") == FeatureStatus_Available)
		return;

	SDKUnhook(entity, SDKHook_SpawnPost, OnEntitySpawnedPost);
}

public void OnEntitySpawnedPost(int entity)
{
	if (!IsValidEntity(entity))
		return;

	// 1 frame later required to get some properties
	RequestFrame(ProcessEntitySpawned, entity);
}

public void OnEntitySpawned(int entity, const char[] classname)
{
	ProcessEntitySpawned(entity);
}

public void OnEnvEntityMakerEntitySpawned(const char[] output, int caller, int activator, float delay)
{
	ProcessEnvEntityMakerEntitySpawned(output, caller, activator, delay);
}

public void OnEntityOutput(const char[] output, int caller, int activator, float delay)
{
	OnTrigger(caller, output);
}

public void OnEntityOutputShow(const char[] output, int caller, int activator, float delay)
{
	OnShowTrigger(caller, output);
}

public void OnEntityOutputKill(const char[] output, int caller, int activator, float delay)
{
	OnKillTrigger(caller, output);
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnTrigger(victim, "OnTakeDamage", SDKHook_OnTakeDamagePost);
}

public void OnTakeDamagePostShow(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnShowTrigger(victim, "OnTakeDamage", SDKHook_OnTakeDamagePost);
}

public void OnTakeDamagePostKill(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnKillTrigger(victim, "OnTakeDamage", SDKHook_OnTakeDamagePost);
}

public void OnGameFrame()
{
	ProcessGameFrame();
}

public Action Command_IsConfigLoaded(int client, int args)
{
	if (!g_bConfigLoaded)
		CReplyToCommand(client, "{lightgreen}[BossHP]{default} Map config file is {red}not loaded.");
	else
	{
		if (!g_bConfigError)
			CReplyToCommand(client, "{lightgreen}[BossHP]{default} Map config file {green}is loaded.");
		else
			CReplyToCommand(client, "{lightgreen}[BossHP]{default} Map config file is {green}loaded {fullred}but has errors.");

		if (CheckCommandAccess(client, "sm_bosshp", ADMFLAG_ROOT))
			CReplyToCommand(client, "{lightgreen}[BossHP]{default} Actual cfg: {olive}%s", g_sConfigLoaded);
	}

	return Plugin_Handled;
}

public Action Command_ReloadConfig(int client, int args)
{
	OnConfigsExecuted();
	ReplyToCommand(client, "[BossHP] Map config file has been reloaded.");
	return Plugin_Handled;
}

// ######## ##     ## ##    ##  ######  ######## ####  #######  ##    ##  ######  
// ##       ##     ## ###   ## ##    ##    ##     ##  ##     ## ###   ## ##    ## 
// ##       ##     ## ####  ## ##          ##     ##  ##     ## ####  ## ##       
// ######   ##     ## ## ## ## ##          ##     ##  ##     ## ## ## ##  ######  
// ##       ##     ## ##  #### ##          ##     ##  ##     ## ##  ####       ## 
// ##       ##     ## ##   ### ##    ##    ##     ##  ##     ## ##   ### ##    ## 
// ##        #######  ##    ##  ######     ##    ####  #######  ##    ##  ######

void Cleanup(bool bCleanConfig = true)
{
	if (g_aConfig && bCleanConfig)
	{
		for (int i = 0; i < g_aConfig.Length; i++)
		{
			CConfig Config = g_aConfig.Get(i);
			delete Config;
		}
		delete g_aConfig;
	}

	if (g_aBoss)
	{
		for (int i = 0; i < g_aBoss.Length; i++)
		{
			CBoss Boss = g_aBoss.Get(i);
			delete Boss;
		}
		delete g_aBoss;
	}

	if (g_aHadOnce)
	{
		g_aHadOnce.Clear();
		delete g_aHadOnce;
	}
}

stock void LoadConfig()
{
	char sMapName[PLATFORM_MAX_PATH], sMapName_lower[PLATFORM_MAX_PATH];
	GetCurrentMap(sMapName, sizeof(sMapName));
	String_ToLower(sMapName, sMapName_lower, sizeof(sMapName_lower));

	char sConfigFile[PLATFORM_MAX_PATH], sConfigFile_override[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/bosshp/%s.cfg", sMapName);
	BuildPath(Path_SM, sConfigFile_override, sizeof(sConfigFile_override), "configs/bosshp/%s_override.cfg", sMapName);

	KeyValues KvConfig = new KeyValues("bosses");

	if (!FileExists(sConfigFile_override))
		BuildPath(Path_SM, sConfigFile_override, sizeof(sConfigFile_override), "configs/bosshp/%s_override.cfg", sMapName_lower);

	if (FileExists(sConfigFile_override))
	{
		if (!KvConfig.ImportFromFile(sConfigFile_override))
		{
			LogMessage("Unable to load config override: \"%s\"", sConfigFile_override);
			delete KvConfig;
			return;
		}
		else
		{
			g_bConfigLoaded = true;
			g_sConfigLoaded = sConfigFile_override;
			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Loaded override mapconfig: \"%s\"", sConfigFile_override);
		}
	}
	else
	{
		if (!FileExists(sConfigFile))
			BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/bosshp/%s.cfg", sMapName_lower);

		if (!KvConfig.ImportFromFile(sConfigFile))
		{
			LogMessage("Unable to load config: \"%s\"", sConfigFile);
			delete KvConfig;
			return;
		}
		else
		{
			g_bConfigLoaded = true;
			g_sConfigLoaded = sConfigFile;
			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Loaded mapconfig: \"%s\"", sConfigFile);
		}
	}

	KvConfig.Rewind();

	if (!KvConfig.GotoFirstSubKey())
	{
		delete KvConfig;
		g_bConfigError = true;
		LogError("GotoFirstSubKey() failed!");
		return;
	}

	g_aConfig = new ArrayList();

	do
	{
		char sSection[64];
		KvConfig.GetSectionName(sSection, sizeof(sSection));

		char sName[64];
		KvConfig.GetString("name", sName, sizeof(sName));
		if (!sName[0])
		{
			g_bConfigError = true;
			LogError("Could not find \"name\" in \"%s\"", sSection);
			continue;
		}

		// Prevent error and bad display
		ReplaceString(sName, sizeof(sName), "%", "");

		char sMethod[64];
		KvConfig.GetString("method", sMethod, sizeof(sMethod));
		if (!sMethod[0])
		{
			g_bConfigError = true;
			LogError("Could not find \"method\" in \"%s\"", sSection);
			continue;
		}

		char sTrigger[64 * 2];
		KvConfig.GetString("trigger", sTrigger, sizeof(sTrigger));
		if (!sTrigger[0])
		{
			g_bConfigError = true;
			LogError("Could not find \"trigger\" in \"%s\"", sSection);
			continue;
		}

		int iTriggerDelim;
		if ((iTriggerDelim = FindCharInString(sTrigger, ':')) == -1)
		{
			g_bConfigError = true;
			LogError("Delimiter ':' not found in \"trigger\"(%s) in \"%s\"", sTrigger, sSection);
			continue;
		}
		sTrigger[iTriggerDelim] = 0;

		float fTriggerDelay = 0.0;
		int iTriggerDelayDelim;
		if ((iTriggerDelayDelim = FindCharInString(sTrigger[iTriggerDelim + 1], ':')) != -1)
		{
			iTriggerDelayDelim += iTriggerDelim + 1;
			fTriggerDelay = StringToFloat(sTrigger[iTriggerDelayDelim + 1]);
			sTrigger[iTriggerDelayDelim] = 0;
		}

		char sShowTrigger[64 * 2];
		int iShowTriggerDelim;
		float fShowTriggerDelay = 0.0;
		int iShowTriggerDelayDelim;
		KvConfig.GetString("showtrigger", sShowTrigger, sizeof(sShowTrigger));
		if (sShowTrigger[0])
		{
			if ((iShowTriggerDelim = FindCharInString(sShowTrigger, ':')) == -1)
			{
				g_bConfigError = true;
				LogError("Delimiter ':' not found in \"showtrigger\"(%s) in \"%s\"", sShowTrigger, sSection);
				continue;
			}
			sShowTrigger[iShowTriggerDelim] = 0;

			if ((iShowTriggerDelayDelim = FindCharInString(sShowTrigger[iShowTriggerDelim + 1], ':')) != -1)
			{
				iShowTriggerDelayDelim += iShowTriggerDelim + 1;
				fShowTriggerDelay = StringToFloat(sShowTrigger[iShowTriggerDelayDelim + 1]);
				sShowTrigger[iShowTriggerDelayDelim] = 0;
			}
		}

		char sKillTrigger[64 * 2];
		int iKillTriggerDelim;
		float fKillTriggerDelay = 0.0;
		int iKillTriggerDelayDelim;
		KvConfig.GetString("killtrigger", sKillTrigger, sizeof(sKillTrigger));
		if (sKillTrigger[0])
		{
			if ((iKillTriggerDelim = FindCharInString(sKillTrigger, ':')) == -1)
			{
				g_bConfigError = true;
				LogError("Delimiter ':' not found in \"killtrigger\"(%s) in \"%s\"", sKillTrigger, sSection);
				continue;
			}
			sKillTrigger[iKillTriggerDelim] = 0;

			if ((iKillTriggerDelayDelim = FindCharInString(sKillTrigger[iKillTriggerDelim + 1], ':')) != -1)
			{
				iKillTriggerDelayDelim += iKillTriggerDelim + 1;
				fKillTriggerDelay = StringToFloat(sKillTrigger[iKillTriggerDelayDelim + 1]);
				sKillTrigger[iKillTriggerDelayDelim] = 0;
			}
		}

		bool bMultiTrigger = view_as<bool>(KvConfig.GetNum("multitrigger", 0));
		bool bNameFixup = view_as<bool>(KvConfig.GetNum("namefixup", 0));
		bool bIgnore = view_as<bool>(KvConfig.GetNum("ignore_on_boss_hits", 0));
		bool bShowBeaten = view_as<bool>(KvConfig.GetNum("showbeaten", 1));
		bool bShowHealth = view_as<bool>(KvConfig.GetNum("showhealth", 1));

		float fTimeout = KvConfig.GetFloat("timeout", -1.0);

		int iOffset = KvConfig.GetNum("offset", 0);

		CConfig Config = view_as<CConfig>(INVALID_HANDLE);

		if (strcmp(sMethod, "breakable", false) == 0)
		{
			char sBreakable[64];
			if (!KvConfig.GetString("breakable", sBreakable, sizeof(sBreakable)))
			{
				g_bConfigError = true;
				LogError("Could not find \"breakable\" in \"%s\"", sSection);
				continue;
			}

			CConfigBreakable BreakableConfig = new CConfigBreakable();

			BreakableConfig.SetBreakable(sBreakable);

			Config = view_as<CConfig>(BreakableConfig);
		}
		else if (strcmp(sMethod, "counter", false) == 0)
		{
			char sCounter[64];
			if (!KvConfig.GetString("counter", sCounter, sizeof(sCounter)))
			{
				g_bConfigError = true;
				LogError("Could not find \"counter\" in \"%s\"", sSection);
				continue;
			}

			CConfigCounter CounterConfig = new CConfigCounter();

			CounterConfig.SetCounter(sCounter);

			Config = view_as<CConfig>(CounterConfig);
		}
		else if (strcmp(sMethod, "hpbar", false) == 0)
		{
			char sIterator[64];
			if (!KvConfig.GetString("iterator", sIterator, sizeof(sIterator)))
			{
				g_bConfigError = true;
				LogError("Could not find \"iterator\" in \"%s\"", sSection);
				continue;
			}

			char sCounter[64];
			if (!KvConfig.GetString("counter", sCounter, sizeof(sCounter)))
			{
				g_bConfigError = true;
				LogError("Could not find \"counter\" in \"%s\"", sSection);
				continue;
			}

			char sBackup[64];
			if (!KvConfig.GetString("backup", sBackup, sizeof(sBackup)))
			{
				g_bConfigError = true;
				LogError("Could not find \"backup\" in \"%s\"", sSection);
				continue;
			}

			CConfigHPBar HPBarConfig = new CConfigHPBar();

			HPBarConfig.SetIterator(sIterator);
			HPBarConfig.SetCounter(sCounter);
			HPBarConfig.SetBackup(sBackup);

			Config = view_as<CConfig>(HPBarConfig);
		}

		if (Config == INVALID_HANDLE)
		{
			g_bConfigError = true;
			LogError("Invalid \"method\"(%s) in \"%s\"", sMethod, sSection);
			continue;
		}

		Config.SetName(sName);
		Config.bMultiTrigger = bMultiTrigger;
		Config.bNameFixup = bNameFixup;
		Config.bIgnore = bIgnore;
		Config.bShowBeaten = bShowBeaten;
		Config.bShowHealth = bShowHealth;
		Config.fTimeout = fTimeout;
		Config.iOffset = iOffset;

		Config.SetTrigger(sTrigger);
		Config.SetOutput(sTrigger[iTriggerDelim + 1]);
		Config.fTriggerDelay = fTriggerDelay;

		if (sShowTrigger[0])
		{
			Config.SetShowTrigger(sShowTrigger);
			Config.SetShowOutput(sShowTrigger[iShowTriggerDelim + 1]);
			Config.fShowTriggerDelay = fShowTriggerDelay;
		}

		if (sKillTrigger[0])
		{
			Config.SetKillTrigger(sKillTrigger);
			Config.SetKillOutput(sKillTrigger[iKillTriggerDelim + 1]);
			Config.fKillTriggerDelay = fKillTriggerDelay;
		}

		g_aConfig.Push(Config);
	} while (KvConfig.GotoNextKey(false));

	delete KvConfig;

	if (!g_aConfig.Length)
	{
		delete g_aConfig;
		g_bConfigError = true;
		LogError("Empty mapconfig: \"%s\"", sConfigFile);
		return;
	}

	Cleanup(false);

	g_aBoss = new ArrayList();
	g_aHadOnce = new StringMap();
}

void ProcessRoundEnd()
{
	Cleanup(false);

	g_aBoss = new ArrayList();
	g_aHadOnce = new StringMap();
}

stock void GetEntityOrConfigOutput(CConfig Config, char[] sOutput, int iOutputSize)
{
	Config.GetOutput(sOutput, iOutputSize);
}

void OnTrigger(int entity, const char[] output, SDKHookType HookType = view_as<SDKHookType>(-1))
{
	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

	if (g_cvVerboseLog.IntValue > 1)
		LogMessage("OnTrigger(%d:\"%s\":#%d, \"%s\")", entity, sTargetname, iHammerID, output);

	for (int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);

		char sTrigger[64];
		Config.GetTrigger(sTrigger, sizeof(sTrigger));

		int iTriggerHammerID = -1;
		if (sTrigger[0] == '#')
		{
			iTriggerHammerID = StringToInt(sTrigger[1]);

			if (iTriggerHammerID != iHammerID)
				continue;
		}
		else if (!sTargetname[0] || strcmp(sTargetname, sTrigger, false) != 0)
			continue;

		char sOutput[64];
		GetEntityOrConfigOutput(Config, sOutput, sizeof(sOutput));

		if (strcmp(output, sOutput, false) != 0)
			continue;

		bool Once = !Config.bMultiTrigger;
		char sTemp[8];

		if (Once)
		{
			IntToString(i, sTemp, sizeof(sTemp));
			bool bHadOnce = false;
			if (g_aHadOnce.GetValue(sTemp, bHadOnce) && bHadOnce)
				continue;
		}

		if (HookType != view_as<SDKHookType>(-1) && Once)
		{
			if (HookType == SDKHook_OnTakeDamagePost)
				SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}

		CBoss Boss = BossAdd(Config, entity);

		if (Boss != INVALID_HANDLE)
		{
			if (Once)
				g_aHadOnce.SetValue(sTemp, true);

			if (g_cvVerboseLog.IntValue > 0)
			{
				if (iTriggerHammerID == -1)
					LogMessage("Triggered boss %s(%d) from output %s", sTargetname, entity, output);
				else
					LogMessage("Triggered boss #%d(%d) from output %s", iTriggerHammerID, entity, output);
			}
		}
	}
}

void OnShowTrigger(int entity, const char[] output, SDKHookType HookType = view_as<SDKHookType>(-1))
{
	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

	int iTemplateNum = -1;
	int iTemplateLoc = FindCharInString(sTargetname, '&', true);
	if (iTemplateLoc != -1)
	{
		iTemplateNum = StringToInt(sTargetname[iTemplateLoc + 1]);
		sTargetname[iTemplateLoc] = 0;
	}

	for (int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);

		char sShowTrigger[64];
		Config.GetShowTrigger(sShowTrigger, sizeof(sShowTrigger));

		if (!sShowTrigger[0])
			continue;

		int iShowTriggerHammerID = -1;
		if (sShowTrigger[0] == '#')
		{
			iShowTriggerHammerID = StringToInt(sShowTrigger[1]);

			if (iShowTriggerHammerID != iHammerID)
				continue;
		}
		else if (!sTargetname[0] || strcmp(sTargetname, sShowTrigger, false) != 0)
			continue;

		char sShowOutput[64];
		Config.GetShowOutput(sShowOutput, sizeof(sShowOutput));

		if (strcmp(output, sShowOutput, false) != 0)
			continue;

		if (g_cvVerboseLog.IntValue > 0)
		{
			if (iShowTriggerHammerID == -1)
				LogMessage("Triggered show boss %s(%d) from output %s", sTargetname, entity, output);
			else
				LogMessage("Triggered show boss #%d(%d) from output %s", iShowTriggerHammerID, entity, output);
		}

		if (HookType != view_as<SDKHookType>(-1) && !Config.bMultiTrigger)
		{
			if (HookType == SDKHook_OnTakeDamagePost)
				SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}

		float fShowTriggerDelay = Config.fShowTriggerDelay;

		for (int j = 0; j < g_aBoss.Length; j++)
		{
			CBoss Boss = g_aBoss.Get(j);

			if (Boss.dConfig != Config)
				continue;

			if (Boss.iTemplateNum != iTemplateNum)
				continue;

			if (fShowTriggerDelay > 0)
			{
				Boss.fShowAt = GetGameTime() + fShowTriggerDelay;
				if (g_cvVerboseLog.IntValue > 0)
					LogMessage("Scheduled show(%f) boss %d", fShowTriggerDelay, j);
			}
			else
			{
				Boss.bShow = true;
				if (g_cvVerboseLog.IntValue > 0)
					LogMessage("Showing boss %d", j);
			}
		}
	}
}

void OnKillTrigger(int entity, const char[] output, SDKHookType HookType = view_as<SDKHookType>(-1))
{
	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

	int iTemplateNum = -1;
	int iTemplateLoc = FindCharInString(sTargetname, '&', true);
	if (iTemplateLoc != -1)
	{
		iTemplateNum = StringToInt(sTargetname[iTemplateLoc + 1]);
		sTargetname[iTemplateLoc] = 0;
	}

	for (int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);

		char sKillTrigger[64];
		Config.GetKillTrigger(sKillTrigger, sizeof(sKillTrigger));

		if (!sKillTrigger[0])
			continue;

		int iKillTriggerHammerID = -1;
		if (sKillTrigger[0] == '#')
		{
			iKillTriggerHammerID = StringToInt(sKillTrigger[1]);

			if (iKillTriggerHammerID != iHammerID)
				continue;
		}
		else if (!sTargetname[0] || strcmp(sTargetname, sKillTrigger, false) != 0)
			continue;

		char sKillOutput[64];
		Config.GetKillOutput(sKillOutput, sizeof(sKillOutput));

		if (strcmp(output, sKillOutput, false) != 0)
			continue;

		if (g_cvVerboseLog.IntValue > 0)
		{
			if (iKillTriggerHammerID == -1)
				LogMessage("Triggered kill boss %s(%d) from output %s", sTargetname, entity, output);
			else
				LogMessage("Triggered kill boss #%d(%d) from output %s", iKillTriggerHammerID, entity, output);
		}

		if (HookType != view_as<SDKHookType>(-1) && !Config.bMultiTrigger)
		{
			if (HookType == SDKHook_OnTakeDamagePost)
				SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
		}

		float fKillTriggerDelay = Config.fKillTriggerDelay;

		for (int j = 0; j < g_aBoss.Length; j++)
		{
			CBoss Boss = g_aBoss.Get(j);

			if (Boss.dConfig != Config)
				continue;

			if (Boss.iTemplateNum != iTemplateNum)
				continue;

			if (fKillTriggerDelay > 0)
			{
				Boss.fKillAt = GetGameTime() + fKillTriggerDelay;
				if (g_cvVerboseLog.IntValue > 0)
					LogMessage("Scheduled kill(%f) boss %d", fKillTriggerDelay, j);
			}
			else
			{
				// CreateForward_OnBossDead(Boss);
				delete Boss;
				g_aBoss.Erase(j);
				j--;
				if (g_cvVerboseLog.IntValue > 0)
					LogMessage("Killed boss %d", j + 1);
			}
		}
	}
}

void ProcessEnvEntityMakerEntitySpawned(const char[] output, int caller, int activator, float delay)
{
	if (!g_aConfig)
		return;

	char sClassname[64];
	if (!GetEntityClassname(caller, sClassname, sizeof(sClassname)))
		return;

	if (strcmp(sClassname, "env_entity_maker", false) != 0)
	{
		g_bConfigError = true;
		LogError("[SOURCEMOD BUG] output: \"%s\", caller: %d, activator: %d, delay: %f, classname: \"%s\"",
			output, caller, activator, delay, sClassname);
		return;
	}

	char sPointTemplate[64];
	if (GetEntPropString(caller, Prop_Data, "m_iszTemplate", sPointTemplate, sizeof(sPointTemplate)) <= 0)
		return;

	int iPointTemplate = FindEntityByTargetname(INVALID_ENT_REFERENCE, sPointTemplate, "point_template");
	if (iPointTemplate == INVALID_ENT_REFERENCE)
		return;

	OnEntityOutput("OnEntitySpawned", iPointTemplate, caller, delay);
}

void ProcessEntitySpawned(int entity)
{
	if (!g_aConfig || !IsValidEntity(entity))
		return;

	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	if (g_cvVerboseLog.IntValue > 1)
		LogMessage("ProcessEntitySpawned(%s)", sTargetname);

	int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

	for (int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);

		char sTrigger[64];
		Config.GetTrigger(sTrigger, sizeof(sTrigger));

		int iTriggerHammerID = -1;
		if (sTrigger[0] == '#')
			iTriggerHammerID = StringToInt(sTrigger[1]);

		if ((iTriggerHammerID == -1 && sTargetname[0] && strcmp(sTargetname, sTrigger, false) == 0) || iTriggerHammerID == iHammerID)
		{
			char sOutput[64];
			GetEntityOrConfigOutput(Config, sOutput, sizeof(sOutput));

			if (strcmp(sOutput, "OnTakeDamage", false) == 0)
			{
				SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
			}
			else
			{
				bool Once = !Config.bMultiTrigger;
				HookSingleEntityOutput(entity, sOutput, OnEntityOutput, Once);
			}

			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Hooked trigger %s:%s", sTrigger, sOutput);
		}

		char sShowTrigger[64];
		Config.GetShowTrigger(sShowTrigger, sizeof(sShowTrigger));

		int iShowTriggerHammerID = -1;
		if (sShowTrigger[0] == '#')
			iShowTriggerHammerID = StringToInt(sShowTrigger[1]);

		if ((iShowTriggerHammerID == -1 && sShowTrigger[0] && strcmp(sTargetname, sShowTrigger, false) == 0) || iShowTriggerHammerID == iHammerID)
		{
			char sShowOutput[64];
			Config.GetShowOutput(sShowOutput, sizeof(sShowOutput));

			if (strcmp(sShowOutput, "OnTakeDamage", false) == 0)
			{
				SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostShow);
			}
			else
			{
				bool Once = !Config.bMultiTrigger;
				HookSingleEntityOutput(entity, sShowOutput, OnEntityOutputShow, Once);
			}

			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Hooked showtrigger %s:%s", sShowTrigger, sShowOutput);
		}

		char sKillTrigger[64];
		Config.GetKillTrigger(sKillTrigger, sizeof(sKillTrigger));

		int iKillTriggerHammerID = -1;
		if (sKillTrigger[0] == '#')
			iKillTriggerHammerID = StringToInt(sKillTrigger[1]);

		if ((iKillTriggerHammerID == -1 && sKillTrigger[0] && strcmp(sTargetname, sKillTrigger, false) == 0) || iKillTriggerHammerID == iHammerID)
		{
			char sKillOutput[64];
			Config.GetKillOutput(sKillOutput, sizeof(sKillOutput));

			if (strcmp(sKillOutput, "OnTakeDamage", false) == 0)
			{
				SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostKill);
			}
			else
			{
				bool Once = !Config.bMultiTrigger;
				HookSingleEntityOutput(entity, sKillOutput, OnEntityOutputKill, Once);
			}

			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Hooked killtrigger %s:%s", sKillTrigger, sKillOutput);
		}
	}
}

void ProcessGameFrame()
{
	if (!g_aBoss || g_aBoss.Length <= 0)
		return;

	CreateForward_OnAllBossProcessStart(g_aBoss);

	float fGameTime = GetGameTime();

	for (int i = 0; i < g_aBoss.Length; i++)
	{
		CBoss Boss = g_aBoss.Get(i);
		CConfig _Config = Boss.dConfig;

		if (Boss.fKillAt && Boss.fKillAt < fGameTime)
		{
			if (g_cvVerboseLog.IntValue > 0)
			{
				char sBoss[64];
				_Config.GetName(sBoss, sizeof(sBoss));
				LogMessage("Deleting boss %s (%d) (KillAt)", sBoss, i);
			}
			CreateForward_OnBossDead(Boss);
			delete Boss;
			g_aBoss.Erase(i);
			i--;
			continue;
		}

		if (!Boss.bActive)
		{
			if (Boss.fWaitUntil)
			{
				if (Boss.fWaitUntil > fGameTime)
					continue;
				Boss.fWaitUntil = 0.0;
			}

			if (!BossInit(Boss))
				continue;
		}

		if (!BossProcess(Boss))
		{
			if (g_cvVerboseLog.IntValue > 0)
			{
				char sBoss[64];
				_Config.GetName(sBoss, sizeof(sBoss));
				LogMessage("Deleting boss %s (%d) (dead)", sBoss, i);
			}
			CreateForward_OnBossDead(Boss);
			delete Boss;
			g_aBoss.Erase(i);
			i--;
		}
	}

	CreateForward_OnAllBossProcessEnd(g_aBoss);
}

stock CBoss BossAdd(CConfig Config, int entity)
{
	CBoss Boss = view_as<CBoss>(INVALID_HANDLE);

	if (Config.IsBreakable)
		Boss = new CBossBreakable();
	else if (Config.IsCounter)
		Boss = new CBossCounter();
	else if (Config.IsHPBar)
		Boss = new CBossHPBar();

	if (Boss != INVALID_HANDLE)
	{
		Boss.iEntity = entity;
		Boss.dConfig = Config;
		Boss.bActive = false;

		float fTriggerDelay = Config.fTriggerDelay;
		if (fTriggerDelay > 0)
			Boss.fWaitUntil = GetGameTime() + fTriggerDelay;

		char sShowTrigger[8];
		Config.GetShowTrigger(sShowTrigger, sizeof(sShowTrigger));
		if (sShowTrigger[0])
			Boss.bShow = false;

		g_aBoss.Push(Boss);
	}
	return Boss;
}

bool BossInit(CBoss _Boss)
{
	CConfig _Config = _Boss.dConfig;
	bool bNameFixup = _Config.bNameFixup;
	int iTemplateNum = -1;

	if (_Boss.IsBreakable)
	{
		CBossBreakable Boss = view_as<CBossBreakable>(_Boss);
		CConfigBreakable Config = view_as<CConfigBreakable>(_Config);

		char sBreakable[64];
		Config.GetBreakable(sBreakable, sizeof(sBreakable));

		int iBreakableEnt = INVALID_ENT_REFERENCE;

		if (!bNameFixup)
		{
			iBreakableEnt = FindEntityByTargetname(iBreakableEnt, sBreakable, "*");
			if (iBreakableEnt == INVALID_ENT_REFERENCE)
				return false;
		}
		else
		{
			StrCat(sBreakable, sizeof(sBreakable), "&*");
			while ((iBreakableEnt = FindEntityByTargetname(iBreakableEnt, sBreakable, "*")) != INVALID_ENT_REFERENCE)
			{
				bool bSkip = false;
				for (int i = 0; i < g_aBoss.Length; i++)
				{
					CBoss _tBoss = g_aBoss.Get(i);
					if (!_tBoss.IsBreakable)
						continue;

					CBossBreakable tBoss = view_as<CBossBreakable>(_tBoss);
					if (tBoss.iBreakableEnt == iBreakableEnt)
					{
						bSkip = true;
						break;
					}
				}

				if (!bSkip)
					break;
			}

			if (iBreakableEnt == INVALID_ENT_REFERENCE)
				return false;

			GetEntPropString(iBreakableEnt, Prop_Data, "m_iName", sBreakable, sizeof(sBreakable));

			int iTemplateLoc = FindCharInString(sBreakable, '&', true);
			if (iTemplateLoc == -1)
				return false;

			iTemplateNum = StringToInt(sBreakable[iTemplateLoc + 1]);
		}

		Boss.iBreakableEnt = iBreakableEnt;
	}
	else if (_Boss.IsCounter)
	{
		CBossCounter Boss = view_as<CBossCounter>(_Boss);
		CConfigCounter Config = view_as<CConfigCounter>(_Config);

		char sCounter[64];
		Config.GetCounter(sCounter, sizeof(sCounter));

		int iCounterEnt = INVALID_ENT_REFERENCE;

		if (!bNameFixup)
		{
			iCounterEnt = FindEntityByTargetname(iCounterEnt, sCounter, "math_counter");
			if (iCounterEnt == INVALID_ENT_REFERENCE)
				return false;
		}
		else
		{
			StrCat(sCounter, sizeof(sCounter), "&*");
			while ((iCounterEnt = FindEntityByTargetname(iCounterEnt, sCounter, "math_counter")) != INVALID_ENT_REFERENCE)
			{
				char sBuf[64];
				GetEntPropString(iCounterEnt, Prop_Data, "m_iName", sBuf, sizeof(sBuf));

				bool bSkip = false;
				for (int i = 0; i < g_aBoss.Length; i++)
				{
					CBoss _tBoss = g_aBoss.Get(i);
					if (!_tBoss.IsCounter)
						continue;

					CBossCounter tBoss = view_as<CBossCounter>(_tBoss);
					if (tBoss.iCounterEnt == iCounterEnt)
					{
						bSkip = true;
						break;
					}
				}

				if (!bSkip)
					break;
			}

			if (iCounterEnt == INVALID_ENT_REFERENCE)
				return false;

			GetEntPropString(iCounterEnt, Prop_Data, "m_iName", sCounter, sizeof(sCounter));

			int iTemplateLoc = FindCharInString(sCounter, '&', true);
			if (iTemplateLoc == -1)
				return false;

			iTemplateNum = StringToInt(sCounter[iTemplateLoc + 1]);
		}

		Boss.iCounterEnt = iCounterEnt;

		int iCounterOnHitMinCount = GetOutputCount(iCounterEnt, "m_OnHitMin");
		int iCounterOnHitMaxCount = GetOutputCount(iCounterEnt, "m_OnHitMax");

		Config.bCounterReverse = iCounterOnHitMaxCount > iCounterOnHitMinCount;
	}
	else if (_Boss.IsHPBar)
	{
		CBossHPBar Boss = view_as<CBossHPBar>(_Boss);
		CConfigHPBar Config = view_as<CConfigHPBar>(_Config);

		char sIterator[64];
		char sCounter[64];
		char sBackup[64];

		Config.GetIterator(sIterator, sizeof(sIterator));
		Config.GetCounter(sCounter, sizeof(sCounter));
		Config.GetBackup(sBackup, sizeof(sBackup));

		int iIteratorEnt = INVALID_ENT_REFERENCE;
		int iCounterEnt = INVALID_ENT_REFERENCE;
		int iBackupEnt = INVALID_ENT_REFERENCE;

		if (!bNameFixup)
		{
			iIteratorEnt = FindEntityByTargetname(iIteratorEnt, sIterator, "math_counter");
			if (iIteratorEnt == INVALID_ENT_REFERENCE)
				return false;

			iCounterEnt = FindEntityByTargetname(iCounterEnt, sCounter, "math_counter");
			if (iCounterEnt == INVALID_ENT_REFERENCE)
				return false;

			iBackupEnt = FindEntityByTargetname(iBackupEnt, sBackup, "math_counter");
			if (iBackupEnt == INVALID_ENT_REFERENCE)
				return false;
		}
		else
		{
			StrCat(sIterator, sizeof(sIterator), "&*");
			while ((iIteratorEnt = FindEntityByTargetname(iIteratorEnt, sIterator, "math_counter")) != INVALID_ENT_REFERENCE)
			{
				bool bSkip = false;
				for (int i = 0; i < g_aBoss.Length; i++)
				{
					CBoss _tBoss = g_aBoss.Get(i);
					if (!_tBoss.IsHPBar)
						continue;

					CBossHPBar tBoss = view_as<CBossHPBar>(_tBoss);
					if (tBoss.iIteratorEnt == iIteratorEnt)
					{
						bSkip = true;
						break;
					}
				}

				if (!bSkip)
					break;
			}

			if (iIteratorEnt == INVALID_ENT_REFERENCE)
				return false;

			GetEntPropString(iIteratorEnt, Prop_Data, "m_iName", sIterator, sizeof(sIterator));

			int iTemplateLoc = FindCharInString(sIterator, '&', true);
			if (iTemplateLoc == -1)
				return false;

			StrCat(sCounter, sizeof(sCounter), sIterator[iTemplateLoc]);
			StrCat(sBackup, sizeof(sBackup), sIterator[iTemplateLoc]);

			iCounterEnt = FindEntityByTargetname(iCounterEnt, sCounter, "math_counter");
			if (iCounterEnt == INVALID_ENT_REFERENCE)
				return false;

			iBackupEnt = FindEntityByTargetname(iBackupEnt, sBackup, "math_counter");
			if (iBackupEnt == INVALID_ENT_REFERENCE)
				return false;

			iTemplateNum = StringToInt(sIterator[iTemplateLoc + 1]);
		}

		Boss.iIteratorEnt = iIteratorEnt;
		Boss.iCounterEnt = iCounterEnt;
		Boss.iBackupEnt = iBackupEnt;

		int iIteratorOnHitMinCount = GetOutputCount(iIteratorEnt, "m_OnHitMin");
		int iIteratorOnHitMaxCount = GetOutputCount(iIteratorEnt, "m_OnHitMax");

		Config.bIteratorReverse = iIteratorOnHitMaxCount > iIteratorOnHitMinCount;

		int iCounterOnHitMinCount = GetOutputCount(iCounterEnt, "m_OnHitMin");
		int iCounterOnHitMaxCount = GetOutputCount(iCounterEnt, "m_OnHitMax");

		Config.bCounterReverse = iCounterOnHitMaxCount > iCounterOnHitMinCount;
	}

	_Boss.bActive = true;

	if (iTemplateNum != -1)
	{
		_Boss.iTemplateNum = iTemplateNum;

		char sShowTrigger[64];
		_Config.GetShowTrigger(sShowTrigger, sizeof(sShowTrigger));

		if (sShowTrigger[0])
		{
			Format(sShowTrigger, sizeof(sShowTrigger), "%s&%04d", sShowTrigger, iTemplateNum);

			char sShowOutput[64];
			_Config.GetShowOutput(sShowOutput, sizeof(sShowOutput));

			int entity = INVALID_ENT_REFERENCE;
			while ((entity = FindEntityByTargetname(entity, sShowTrigger)) != INVALID_ENT_REFERENCE)
			{
				if (strcmp(sShowOutput, "OnTakeDamage", false) == 0)
				{
					SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostShow);
				}
				else
				{
					HookSingleEntityOutput(entity, sShowOutput, OnEntityOutputShow, true);
				}

				if (g_cvVerboseLog.IntValue > 0)
					LogMessage("Hooked showtrigger %s:%s", sShowTrigger, sShowOutput);
			}
		}

		char sKillTrigger[64];
		_Config.GetKillTrigger(sKillTrigger, sizeof(sKillTrigger));

		if (sKillTrigger[0])
		{
			Format(sKillTrigger, sizeof(sKillTrigger), "%s&%04d", sKillTrigger, iTemplateNum);

			char sKillOutput[64];
			_Config.GetKillOutput(sKillOutput, sizeof(sKillOutput));

			int entity = INVALID_ENT_REFERENCE;
			while ((entity = FindEntityByTargetname(entity, sKillTrigger)) != INVALID_ENT_REFERENCE)
			{
				if (strcmp(sKillOutput, "OnTakeDamage", false) == 0)
				{
					SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostKill);
				}
				else
				{
					HookSingleEntityOutput(entity, sKillOutput, OnEntityOutputKill, true);
				}

				if (g_cvVerboseLog.IntValue > 0)
					LogMessage("Hooked killtrigger %s:%s", sKillTrigger, sKillOutput);
			}
		}
	}

	char sBoss[64];
	_Config.GetName(sBoss, sizeof(sBoss));
	if (g_cvVerboseLog.IntValue > 0)
		LogMessage("Initialized boss %s (template = %d)", sBoss, iTemplateNum);
	CreateForward_OnBossInitialized(_Boss);

	return true;
}

bool BossProcess(CBoss _Boss)
{
	CConfig _Config = _Boss.dConfig;

	bool bInvalid = false;
	int iHealth = 0;
	int iLastHealth = _Boss.iHealth;
	float fLastChange = _Boss.fLastChange;

	if (_Boss.IsBreakable)
	{
		CBossBreakable Boss = view_as<CBossBreakable>(_Boss);

		int iBreakableEnt = Boss.iBreakableEnt;

		if (IsValidEntity(iBreakableEnt))
			iHealth = GetEntProp(iBreakableEnt, Prop_Data, "m_iHealth");
		else
			bInvalid = true;
	}
	else if (_Boss.IsCounter)
	{
		CBossCounter Boss = view_as<CBossCounter>(_Boss);
		CConfigCounter Config = view_as<CConfigCounter>(_Config);

		int iCounterEnt = Boss.iCounterEnt;

		if (IsValidEntity(iCounterEnt))
		{
			int iCounterVal = RoundFloat(GetOutputValueFloat(iCounterEnt, "m_OutValue"));

			if (!Config.bCounterReverse)
			{
				int iCounterMin = RoundFloat(GetEntPropFloat(iCounterEnt, Prop_Data, "m_flMin"));
				iHealth = iCounterVal - iCounterMin;
			}
			else
			{
				int iCounterMax = RoundFloat(GetEntPropFloat(iCounterEnt, Prop_Data, "m_flMax"));
				iHealth = iCounterMax - iCounterVal;
			}
		}
		else
			bInvalid = true;
	}
	else if (_Boss.IsHPBar)
	{
		CBossHPBar Boss = view_as<CBossHPBar>(_Boss);
		CConfigHPBar Config = view_as<CConfigHPBar>(_Config);

		int iIteratorEnt = Boss.iIteratorEnt;
		int iCounterEnt = Boss.iCounterEnt;
		int iBackupEnt = Boss.iBackupEnt;

		if (IsValidEntity(iIteratorEnt) && IsValidEntity(iCounterEnt) && IsValidEntity(iBackupEnt))
		{
			int iIteratorVal = RoundFloat(GetOutputValueFloat(iIteratorEnt, "m_OutValue"));
			int iCounterVal = RoundFloat(GetOutputValueFloat(iCounterEnt, "m_OutValue"));
			int iBackupVal = RoundFloat(GetOutputValueFloat(iBackupEnt, "m_OutValue"));

			if (!Config.bIteratorReverse)
			{
				int iIteratorMin = RoundFloat(GetEntPropFloat(iIteratorEnt, Prop_Data, "m_flMin"));
				iHealth = (iIteratorVal - iIteratorMin - 1) * iBackupVal;
			}
			else
			{
				int iIteratorMax = RoundFloat(GetEntPropFloat(iIteratorEnt, Prop_Data, "m_flMax"));
				iHealth = (iIteratorMax - iIteratorVal - 1) * iBackupVal;
			}

			if (!Config.bCounterReverse)
			{
				int iCounterMin = RoundFloat(GetEntPropFloat(iCounterEnt, Prop_Data, "m_flMin"));
				iHealth += iCounterVal - iCounterMin;
			}
			else
			{
				int iCounterMax = RoundFloat(GetEntPropFloat(iCounterEnt, Prop_Data, "m_flMax"));
				iHealth += iCounterMax - iCounterVal;
			}
		}
		else
			bInvalid = true;
	}

	if (iHealth < 0)
		iHealth = 0;

	int iOffset = _Config.iOffset;
	if (iOffset != 0)
		iHealth += iOffset;

	bool bHealthChanged = (iHealth != iLastHealth);
	if (bHealthChanged)
	{
		fLastChange = GetGameTime();
		_Boss.fLastChange = fLastChange;
	}

	// Boss hasn't initialized HP yet.
	if (iHealth == 0 && iLastHealth == 0)
	{
		// Boss invalid: Delete boss
		if (bInvalid)
			return false;

		return true;
	}

	if (iLastHealth == 0)
		_Boss.iBaseHealth = iHealth;

	_Boss.iLastHealth = iLastHealth;
	_Boss.iHealth = iHealth;

	bool bShow = _Boss.bShow;
	if (!bShow && _Boss.fShowAt && _Boss.fShowAt < GetGameTime())
	{
		bShow = true;
		_Boss.bShow = true;
	}

	CreateForward_OnBossProcessed(_Boss, bHealthChanged, bShow);

	// Boss dead/invalid: Delete boss
	if (!iHealth || bInvalid)
		return false;

	return true;
}

int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname="*")
{
	if (sTargetname[0] == '#') // HammerID
	{
		int HammerID = StringToInt(sTargetname[1]);

		while ((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if (GetEntProp(entity, Prop_Data, "m_iHammerID") == HammerID)
				return entity;
		}
	}
	else // Targetname
	{
		int Wildcard = FindCharInString(sTargetname, '*');
		char sTargetnameBuf[64];

		while ((entity = FindEntityByClassname(entity, sClassname)) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropString(entity, Prop_Data, "m_iName", sTargetnameBuf, sizeof(sTargetnameBuf)) <= 0)
				continue;

			if (strncmp(sTargetnameBuf, sTargetname, Wildcard) == 0)
				return entity;
		}
	}

	return INVALID_ENT_REFERENCE;
}

//########  #######  ########  ##      ##    ###    ########  ########   ######  
//##       ##     ## ##     ## ##  ##  ##   ## ##   ##     ## ##     ## ##    ## 
//##       ##     ## ##     ## ##  ##  ##  ##   ##  ##     ## ##     ## ##       
//######   ##     ## ########  ##  ##  ## ##     ## ########  ##     ##  ######  
//##       ##     ## ##   ##   ##  ##  ## ######### ##   ##   ##     ##       ## 
//##       ##     ## ##    ##  ##  ##  ## ##     ## ##    ##  ##     ## ##    ## 
//##        #######  ##     ##  ###  ###  ##     ## ##     ## ########   ######  

public void CreateForward_OnBossInitialized(CBoss boss)
{
	Call_StartForward(g_hForward_OnBossInitialized);
	Call_PushCell(boss);
	Call_Finish();
}

public void CreateForward_OnBossProcessed(CBoss boss, bool bHealthChanged, bool bShow)
{
	Call_StartForward(g_hForward_OnBossProcessed);
	Call_PushCell(boss);
	Call_PushCell(bHealthChanged);
	Call_PushCell(bShow);
	Call_Finish();
}

public void CreateForward_OnBossDead(CBoss boss)
{
	Call_StartForward(g_hForward_OnBossDead);
	Call_PushCell(boss);
	Call_Finish();
}

public void CreateForward_OnAllBossProcessStart(ArrayList aBoss)
{
	Call_StartForward(g_hForward_OnAllBossProcessStart);
	Call_PushCell(aBoss);
	Call_Finish();
}

public void CreateForward_OnAllBossProcessEnd(ArrayList aBoss)
{
	Call_StartForward(g_hForward_OnAllBossProcessEnd);
	Call_PushCell(aBoss);
	Call_Finish();
}


//  888b    888        d8888 88888888888 8888888 888     888 8888888888 .d8888b.
//  8888b   888       d88888     888       888   888     888 888       d88P  Y88b
//  88888b  888      d88P888     888       888   888     888 888       Y88b.
//  888Y88b 888     d88P 888     888       888   Y88b   d88P 8888888    "Y888b.
//  888 Y88b888    d88P  888     888       888    Y88b d88P  888           "Y88b.
//  888  Y88888   d88P   888     888       888     Y88o88P   888             "888
//  888   Y8888  d8888888888     888       888      Y888P    888       Y88b  d88P
//  888    Y888 d88P     888     888     8888888     Y8P     8888888888 "Y8888P"

public int Native_IsBossEntity(Handle plugin, int numParams)
{
	if (!g_aBoss || g_aBoss.Length <= 0)
		return false;

	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity))
		return false;

	CBoss _boss;
	int i = 0;
	while (i < g_aBoss.Length)
	{
		_boss = g_aBoss.Get(i);
		if (_boss.iEntity == entity)
			break;
		else
		{
			if (_boss.IsBreakable)
			{
				CBossBreakable boss = view_as<CBossBreakable>(_boss);
				if (boss.iBreakableEnt == entity)
					break;
			}
			if (_boss.IsCounter)
			{
				CBossCounter boss = view_as<CBossCounter>(_boss);
				if (boss.iCounterEnt == entity)
					break;
			}
			if (_boss.IsHPBar)
			{
				CBossHPBar boss = view_as<CBossHPBar>(_boss);
				if (boss.iCounterEnt == entity ||
					boss.iBackupEnt == entity ||
					boss.iIteratorEnt == entity)
					break;
			}
		}
		i++;
	}

	if (i < g_aBoss.Length)
	{
		SetNativeCellRef(2, _boss);
		return true;
	}

	return false;
}
