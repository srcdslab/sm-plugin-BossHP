// Map config: configs/bosshp/<map>.cfg (or <map>_override.cfg), one section per boss

char g_sConfigLoaded[PLATFORM_MAX_PATH];

void Config_OnPluginStart()
{
	RegAdminCmd("sm_bosshp_reload", Command_ReloadConfig, ADMFLAG_CONFIG, "Reload the BossHP Map Config File.");
	RegAdminCmd("sm_bosshp", Command_IsConfigLoaded, ADMFLAG_GENERIC, "Check if the BossHP Map Config File is loaded.");
}

public Action Command_IsConfigLoaded(int client, int args)
{
	if (!g_bConfigLoaded)
		CReplyToCommand(client, CHAT_PREFIX ... "Map config file is {red}not loaded.");
	else
	{
		if (!g_bConfigError)
			CReplyToCommand(client, CHAT_PREFIX ... "Map config file {green}is loaded.");
		else
			CReplyToCommand(client, CHAT_PREFIX ... "Map config file is {green}loaded {fullred}but has errors.");

		if (CheckCommandAccess(client, "sm_bosshp", ADMFLAG_ROOT))
			CReplyToCommand(client, CHAT_PREFIX ... "Actual cfg: {olive}%s", g_sConfigLoaded);
	}

	return Plugin_Handled;
}

public Action Command_ReloadConfig(int client, int args)
{
	Config_Load();
	ReplyToCommand(client, CONSOLE_PREFIX ... "Map config file has been reloaded.");
	return Plugin_Handled;
}

void Config_Cleanup()
{
	if (!g_aConfig)
		return;

	for (int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);
		delete Config;
	}
	delete g_aConfig;
}

// Path of the map config, the override is used first and both are also searched in lowercase
bool Config_FindFile(char[] sPath, int iMaxLen)
{
	char sMapName[PLATFORM_MAX_PATH], sMapNameLower[PLATFORM_MAX_PATH];
	GetCurrentMap(sMapName, sizeof(sMapName));
	String_ToLower(sMapName, sMapNameLower, sizeof(sMapNameLower));

	static const char sFormats[][] = { "configs/bosshp/%s_override.cfg", "configs/bosshp/%s.cfg" };

	for (int i = 0; i < sizeof(sFormats); i++)
	{
		BuildPath(Path_SM, sPath, iMaxLen, sFormats[i], sMapName);
		if (FileExists(sPath))
			return true;

		BuildPath(Path_SM, sPath, iMaxLen, sFormats[i], sMapNameLower);
		if (FileExists(sPath))
			return true;
	}

	return false;
}

void Config_Load()
{
	// Bosses keep a reference to their config, they are removed with it
	Bosses_Cleanup();
	Config_Cleanup();

	g_bConfigLoaded = false;
	g_bConfigError = false;

	char sConfigFile[PLATFORM_MAX_PATH];
	if (!Config_FindFile(sConfigFile, sizeof(sConfigFile)))
	{
		if (g_cvVerboseLog.IntValue > 0)
			LogMessage("No mapconfig: \"%s\"", sConfigFile);
		return;
	}

	KeyValues KvConfig = new KeyValues("bosses");
	if (!KvConfig.ImportFromFile(sConfigFile))
	{
		LogMessage("Unable to load config: \"%s\"", sConfigFile);
		delete KvConfig;
		return;
	}

	g_bConfigLoaded = true;
	strcopy(g_sConfigLoaded, sizeof(g_sConfigLoaded), sConfigFile);
	if (g_cvVerboseLog.IntValue > 0)
		LogMessage("Loaded mapconfig: \"%s\"", sConfigFile);

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
		CConfig Config = Config_Parse(KvConfig);
		if (Config == INVALID_HANDLE)
		{
			g_bConfigError = true;
			continue;
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

	Bosses_Reset();
}

// Parses the current section, returns INVALID_HANDLE (and logs why) when it is invalid
CConfig Config_Parse(KeyValues KvConfig)
{
	char sSection[64];
	KvConfig.GetSectionName(sSection, sizeof(sSection));

	char sName[64];
	KvConfig.GetString("name", sName, sizeof(sName));
	if (!sName[0])
	{
		LogError("Could not find \"name\" in \"%s\"", sSection);
		return view_as<CConfig>(INVALID_HANDLE);
	}

	// Prevent error and bad display
	ReplaceString(sName, sizeof(sName), "%", "");

	char sMethod[64];
	KvConfig.GetString("method", sMethod, sizeof(sMethod));
	if (!sMethod[0])
	{
		LogError("Could not find \"method\" in \"%s\"", sSection);
		return view_as<CConfig>(INVALID_HANDLE);
	}

	char sTriggers[BossTrigger_Count][64], sOutputs[BossTrigger_Count][64];
	float fDelays[BossTrigger_Count];

	for (BossTrigger iType = BossTrigger_Spawn; iType < BossTrigger_Count; iType++)
	{
		if (!Config_ParseTrigger(KvConfig, sSection, iType, sTriggers[iType], sizeof(sTriggers[]), sOutputs[iType], sizeof(sOutputs[]), fDelays[iType]))
			return view_as<CConfig>(INVALID_HANDLE);
	}

	if (!sTriggers[BossTrigger_Spawn][0])
	{
		LogError("Could not find \"trigger\" in \"%s\"", sSection);
		return view_as<CConfig>(INVALID_HANDLE);
	}

	CConfig Config = view_as<CConfig>(INVALID_HANDLE);

	if (strcmp(sMethod, "breakable", false) == 0)
	{
		char sBreakable[64];
		if (!Config_GetRequiredString(KvConfig, sSection, "breakable", sBreakable, sizeof(sBreakable)))
			return view_as<CConfig>(INVALID_HANDLE);

		char sScriptHealth[64];
		KvConfig.GetString("scripthealth", sScriptHealth, sizeof(sScriptHealth));
		if (sScriptHealth[0] && !IsValidScriptVariable(sScriptHealth))
		{
			LogError("Invalid \"scripthealth\"(%s) in \"%s\"", sScriptHealth, sSection);
			return view_as<CConfig>(INVALID_HANDLE);
		}

		CConfigBreakable BreakableConfig = new CConfigBreakable();
		BreakableConfig.SetBreakable(sBreakable);
		BreakableConfig.SetScriptHealth(sScriptHealth);

		Config = view_as<CConfig>(BreakableConfig);
	}
	else if (strcmp(sMethod, "counter", false) == 0)
	{
		char sCounter[64];
		if (!Config_GetRequiredString(KvConfig, sSection, "counter", sCounter, sizeof(sCounter)))
			return view_as<CConfig>(INVALID_HANDLE);

		CConfigCounter CounterConfig = new CConfigCounter();
		CounterConfig.SetCounter(sCounter);

		Config = view_as<CConfig>(CounterConfig);
	}
	else if (strcmp(sMethod, "hpbar", false) == 0)
	{
		char sIterator[64], sCounter[64];
		if (!Config_GetRequiredString(KvConfig, sSection, "iterator", sIterator, sizeof(sIterator)) ||
			!Config_GetRequiredString(KvConfig, sSection, "counter", sCounter, sizeof(sCounter)))
			return view_as<CConfig>(INVALID_HANDLE);

		// "backup" is optional: without it, each iterator step is worth the counter's range
		char sBackup[64];
		KvConfig.GetString("backup", sBackup, sizeof(sBackup));

		CConfigHPBar HPBarConfig = new CConfigHPBar();
		HPBarConfig.SetIterator(sIterator);
		HPBarConfig.SetCounter(sCounter);
		HPBarConfig.SetBackup(sBackup);

		Config = view_as<CConfig>(HPBarConfig);
	}
	else
	{
		LogError("Invalid \"method\"(%s) in \"%s\"", sMethod, sSection);
		return view_as<CConfig>(INVALID_HANDLE);
	}

	Config.SetName(sName);
	Config.bMultiTrigger = view_as<bool>(KvConfig.GetNum("multitrigger", 0));
	Config.bNameFixup = view_as<bool>(KvConfig.GetNum("namefixup", 0));
	Config.bIgnore = view_as<bool>(KvConfig.GetNum("ignore_on_boss_hits", 0));
	Config.bShowBeaten = view_as<bool>(KvConfig.GetNum("showbeaten", 1));
	Config.bShowHealth = view_as<bool>(KvConfig.GetNum("showhealth", 1));
	Config.fTimeout = KvConfig.GetFloat("timeout", -1.0);
	Config.iOffset = KvConfig.GetNum("offset", 0);

	for (BossTrigger iType = BossTrigger_Spawn; iType < BossTrigger_Count; iType++)
	{
		if (sTriggers[iType][0])
			SetConfigTrigger(Config, iType, sTriggers[iType], sOutputs[iType], fDelays[iType]);
	}

	return Config;
}

bool Config_GetRequiredString(KeyValues KvConfig, const char[] sSection, const char[] sKey, char[] sValue, int iMaxLen)
{
	KvConfig.GetString(sKey, sValue, iMaxLen);
	if (sValue[0])
		return true;

	LogError("Could not find \"%s\" in \"%s\"", sKey, sSection);
	return false;
}

// Parses "<entity>:<output>[:<delay>]", sTrigger stays empty when the key is not set
bool Config_ParseTrigger(KeyValues KvConfig, const char[] sSection, BossTrigger iType, char[] sTrigger, int iTriggerLen, char[] sOutput, int iOutputLen, float &fDelay)
{
	fDelay = 0.0;
	sTrigger[0] = '\0';
	sOutput[0] = '\0';

	char sValue[64 * 2];
	KvConfig.GetString(g_sTriggerKeys[iType], sValue, sizeof(sValue));
	if (!sValue[0])
		return true;

	int iDelim = FindCharInString(sValue, ':');
	if (iDelim == -1)
	{
		LogError("Delimiter ':' not found in \"%s\"(%s) in \"%s\"", g_sTriggerKeys[iType], sValue, sSection);
		return false;
	}
	sValue[iDelim] = '\0';

	// A hurttrigger reports every hit, it has no delay
	if (iType != BossTrigger_Hurt)
	{
		int iDelayDelim = FindCharInString(sValue[iDelim + 1], ':');
		if (iDelayDelim != -1)
		{
			iDelayDelim += iDelim + 1;
			fDelay = StringToFloat(sValue[iDelayDelim + 1]);
			sValue[iDelayDelim] = '\0';
		}
	}

	strcopy(sTrigger, iTriggerLen, sValue);
	strcopy(sOutput, iOutputLen, sValue[iDelim + 1]);
	return true;
}

// Only allow plain identifiers since the name is injected into a VScript snippet
bool IsValidScriptVariable(const char[] sVariable)
{
	for (int i = 0; sVariable[i]; i++)
	{
		if (!IsCharAlpha(sVariable[i]) && sVariable[i] != '_' && (i == 0 || !IsCharNumeric(sVariable[i])))
			return false;
	}

	return sVariable[0] != '\0';
}
