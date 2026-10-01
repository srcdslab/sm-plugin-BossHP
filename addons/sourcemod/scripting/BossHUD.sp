#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientprefs>
#include <BossHP>
#include <loghelper>
#include <BossHUD>
#include <multicolors>

#undef REQUIRE_PLUGIN
#tryinclude <DynamicChannels>
#define REQUIRE_PLUGIN

#pragma newdecls required

#define MAX_TEXT_LENGTH	64

ConVar g_cVHudPosition, g_cVHudColor, g_cVHudSymbols;
ConVar g_cVDisplayType;
ConVar g_cVTopHitsPos, g_cVTopHitsColor, g_cVTopHitsTitle, g_cVPlayersInTable;
ConVar g_cVStatsReward, g_cVBossHitMoney, g_cvBossDeathNotice;
ConVar g_cVHudMinHealth, g_cVHudMaxHealth;
ConVar g_cVHudTimeout, g_cvHUDChannel;
ConVar g_cVIgnoreFakeClients;
ConVar g_cVFramesToSkip;
ConVar g_cvBossHitsNotifyConsole;

Cookie g_cShowHealth;

Handle g_hHudSync = INVALID_HANDLE, g_hHudTopHitsSync = INVALID_HANDLE, g_hTimerHudMsgAll = INVALID_HANDLE;

StringMap g_smBossMap = null;
ArrayList g_aEntity = null;

bool g_bShowHealth[MAXPLAYERS + 1] =  { true, ... };
bool g_bHudSymbols;
bool g_bTopHitsTitle = true;
bool g_bBossHitMoney = true;
bool g_bStatsReward = false;
bool g_bBossDeathNotice = true;
bool g_bIgnoreFakeClients = true;
bool g_bHookMessagesDeathNotice = false;
bool g_bBossHitsNotifyConsole = false;

int g_iEntityId[MAXPLAYERS+1] = { -1, ... };
int g_iHudColor[3], g_iTopHitsColor[3];

float g_fHudPos[2], g_fTopHitsPos[2];

bool g_bLate = false;
bool g_bDynamicChannels = false;
bool bDynamicAvailable = false;

char g_sHUDText[256];
char g_sHUDTextSave[256];

bool g_bLastBossHudPrinted = true;
bool g_bLastHudPrinted = true;

float g_fTimeout = 0.5;

int g_iMinHealthDetect = 1000;
int g_iMaxHealthDetect = 100000;
int g_iHUDChannel = 1;
int g_iPlayersInTable = 3;
int g_iFramesToSkip = 7;

DisplayType g_iDisplayType;

public Plugin myinfo = {
	name = "BossHUD",
	author = "AntiTeal, Cloud Strife, maxime1907",
	description = "Show the health of bosses and breakables",
	version = "3.8.8",
	url = "antiteal.com"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;

	CreateNative("BossHUD_GetBossHealth", Native_GetBossHealth);
	CreateNative("BossHUD_GetBossMaxHealth", Native_GetBossMaxHealth);
	CreateNative("BossHUD_GetBossHits", Native_GetBossHits);
	CreateNative("BossHUD_GetBossTopHits", Native_GetBossTopHits);
	CreateNative("BossHUD_IsBossActive", Native_IsBossActive);
	CreateNative("BossHUD_GetBossName", Native_GetBossName);
	CreateNative("BossHUD_GetBossHitsCount", Native_GetBossHitsCount);
	CreateNative("BossHUD_GetBossHitsByClient", Native_GetBossHitsByClient);
	CreateNative("BossHUD_GetBossHitsRank", Native_GetBossHitsRank);

	RegPluginLibrary("BossHUD");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("BossHUD.phrases");

	g_cShowHealth = new Cookie("bhud_showhealth", "Toggle boss health display", CookieAccess_Private);

	SetCookieMenuItem(CookieMenu_BHud, INVALID_HANDLE, "BossHUD Settings");

	RegConsoleCmd("sm_bhud", Command_BHud, "Toggle boss health display");
	RegConsoleCmd("sm_bosshud", Command_BHud, "Toggle boss health display");

	RegAdminCmd("sm_currenthp", Command_CHP, ADMFLAG_GENERIC, "See Current HP");
	RegAdminCmd("sm_subtracthp", Command_SHP, ADMFLAG_GENERIC, "Subtract Current HP");
	RegAdminCmd("sm_addhp", Command_AHP, ADMFLAG_GENERIC, "Add Current HP");

	HookEntityOutput("func_physbox", "OnHealthChanged", Hook_OnDamage);
	HookEntityOutput("func_physbox_multiplayer", "OnHealthChanged", Hook_OnDamage);
	HookEntityOutput("func_breakable", "OnHealthChanged", Hook_OnDamage);
	HookEntityOutput("math_counter", "OutValue", Hook_OnDamage);

	HookEvent("round_end", Event_OnRoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_connect_client", Event_JoinLeaveMessage, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_JoinLeaveMessage, EventHookMode_Pre);

	g_cVHudPosition = CreateConVar("sm_bhud_position", "-1.0 0.09", "The X and Y position for the hud.");
	g_cVHudColor = CreateConVar("sm_bhud_color", "255 0 0", "RGB color value for the hud.");
	g_cVHudSymbols = CreateConVar("sm_bhud_symbols", "0", "Determines whether >> and << are wrapped around the text.", _, true, 0.0, true, 1.0);
	g_cVDisplayType = CreateConVar("sm_bhud_displaytype", "2", "Display type of HUD. (0 = center, 1 = game, 2 = hint)", _, true, 0.0, true, 2.0);
	g_cVHudMinHealth = CreateConVar("sm_bhud_health_min", "1000", "Determines what minimum hp entities should have to be detected.", _, true, 0.0, true, 1000000.0);
	g_cVHudMaxHealth = CreateConVar("sm_bhud_health_max", "100000", "Determines what maximum hp entities should have to be detected.", _, true, 0.0, true, 1000000.0);
	g_cVHudTimeout = CreateConVar("sm_bhud_timeout", "0.5", "Determines when the entity health is supposed to fade away when it doesnt change.", _, true, 0.0, true, 10.0);
	g_cvHUDChannel = CreateConVar("sm_bhud_hud_channel", "1", "The channel for the hud if using DynamicChannels", _, true, 0.0, true, 5.0);
	g_cvBossHitsNotifyConsole = CreateConVar("sm_bhud_notify_console", "1", "Enable/Disable the print in console to all players of total boss hits", _, true, 0.0, true, 1.0);

	g_cVTopHitsPos = CreateConVar("sm_bhud_tophits_position", "0.02 0.3", "The X and Y position for the hud.");
	g_cVTopHitsColor = CreateConVar("sm_bhud_tophits_color", "255 255 0", "RGB color value for the hud.");
	g_cVTopHitsTitle = CreateConVar("sm_bhud_tophits_uppertitle", "1", "Enable/Disable the upper title of the top hits table.", _, true, 0.0, true, 1.0);
	g_cVPlayersInTable = CreateConVar("sm_bhud_tophits_players", "3", "Amount players on the top hits table", _, true, 1.0, true, 10.0);
	g_cVBossHitMoney = CreateConVar("sm_bhud_tophits_money", "1", "Enable/Disable payment of boss hits", _, true, 0.0, true, 1.0);
	g_cvBossDeathNotice = CreateConVar("sm_bhud_boss_death_notice", "1", "Enable/Disable the boss death notice", _, true, 0.0, true, 1.0);
	g_cVStatsReward = CreateConVar("sm_bhud_tophits_reward", "0", "Enable/Disable give of the stats points.", _, true, 0.0, true, 1.0);
	g_cVIgnoreFakeClients = CreateConVar("sm_bhud_ignore_fakeclients", "1", "Enable/Disable not filtering fake clients.", _, true, 0.0, true, 1.0);
	g_cVFramesToSkip = CreateConVar("sm_bhud_frame_to_skip", "7", "Number of frames to skip before displaying the HUD.", _, true, 0.0, true, 66.0);

	g_cVHudMinHealth.AddChangeHook(OnConVarChange);
	g_cVHudMaxHealth.AddChangeHook(OnConVarChange);
	g_cVHudPosition.AddChangeHook(OnConVarChange);
	g_cVHudColor.AddChangeHook(OnConVarChange);
	g_cVHudSymbols.AddChangeHook(OnConVarChange);
	g_cVDisplayType.AddChangeHook(OnConVarChange);
	g_cVHudTimeout.AddChangeHook(OnConVarChange);
	g_cVTopHitsPos.AddChangeHook(OnConVarChange);
	g_cVTopHitsColor.AddChangeHook(OnConVarChange);
	g_cvHUDChannel.AddChangeHook(OnConVarChange);
	g_cVTopHitsTitle.AddChangeHook(OnConVarChange);
	g_cVPlayersInTable.AddChangeHook(OnConVarChange);
	g_cVBossHitMoney.AddChangeHook(OnConVarChange);
	g_cvBossDeathNotice.AddChangeHook(OnConVarChange);
	g_cVStatsReward.AddChangeHook(OnConVarChange);
	g_cVIgnoreFakeClients.AddChangeHook(OnConVarChange);
	g_cVFramesToSkip.AddChangeHook(OnConVarChange);
	g_cvBossHitsNotifyConsole.AddChangeHook(OnConVarChange);

	AutoExecConfig(true);
	GetConVars();

	CleanupAndInit();

	if (!g_bLate)
		return;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i) || !AreClientCookiesCached(i))
			continue;

		ReadClientCookies(i);
	}

	g_bLate = false;
}

public void OnAllPluginsLoaded()
{
	g_bDynamicChannels = LibraryExists("DynamicChannels");
	VerifyNatives();
}

public void OnLibraryAdded(const char[] name)
{
	if (strcmp(name, "DynamicChannels", false) == 0)
	{
		g_bDynamicChannels = true;
		VerifyNatives();
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (strcmp(name, "DynamicChannels", false) == 0)
	{
		g_bDynamicChannels = false;
		VerifyNatives();
	}
}

stock void VerifyNatives()
{
	bDynamicAvailable = g_bDynamicChannels && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "GetDynamicChannel") == FeatureStatus_Available;
}

public void OnPluginEnd()
{
	Cleanup();
}

public void Event_OnRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	CleanupAndInit();
}

public void Event_JoinLeaveMessage(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bBossDeathNotice || !g_bHookMessagesDeathNotice)
		return;

	if (!event.GetBool("bot"))
		return;

	event.BroadcastDisabled = true;
}

public void OnConVarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	GetConVars();
}

public void OnMapStart()
{
	CleanupAndInit();
}

public void OnMapEnd()
{
	Cleanup();
}

public void OnClientCookiesCached(int client)
{
	ReadClientCookies(client);
}

public void CookieMenu_BHud(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
			FormatEx(buffer, maxlen, "Display boss health: %s", g_bShowHealth[client] ? "Enabled" : "Disabled");
		}
		case CookieMenuAction_SelectOption:
		{
			ToggleBhud(client);
			ShowCookieMenu(client);
		}
	}
}

public void Hook_OnDamage(const char[] output, int caller, int activator, float delay)
{
	if (!IsValidClient(activator, g_bIgnoreFakeClients))
		return;

	CBoss boss;
	bool bIsBoss = BossHP_IsBossEnt(caller, boss);

	if (!bIsBoss)
	{
		for (int i = 0; i < g_aEntity.Length; i++)
		{
			CEntity _Entity = g_aEntity.Get(i);
			if (_Entity.iIndex == caller)
			{
				_Entity.bActive = true;
				_Entity.fLastHitTime = GetGameTime();
				break;
			}
		}
		g_iEntityId[activator] = caller;
	}
	else if (bIsBoss && !boss.dConfig.bIgnore)
	{
		char szBossName[64];
		BuildName(boss, szBossName, sizeof(szBossName));

		int iHits[MAXPLAYERS + 1];
		g_smBossMap.GetArray(szBossName, iHits, MAXPLAYERS + 1);

		if (boss.IsBreakable)
		{
			// Breakable entities damages aren't based on the number of hits
			int iHealth = GetEntityHealth(caller);
			int iDamageMade = boss.iLastHealth - iHealth;
			if (iDamageMade > 0)
				iHits[activator] += iDamageMade;
		}
		else
		{
			iHits[activator]++;
		}

		if (g_bBossHitMoney)
		{
			int cash = GetClientMoney(activator);
			SetClientMoney(activator, ++cash);
		}
		g_smBossMap.SetArray(szBossName, iHits, MAXPLAYERS + 1, true);
		g_iEntityId[activator] = caller;
	}
	delete boss;
}

public void BossHP_OnBossInitialized(CBoss boss)
{
	if (boss.dConfig != INVALID_HANDLE && boss.dConfig.bIgnore)
		return;

	char szName[300];
	BuildName(boss, szName, sizeof(szName));

	int hits[MAXPLAYERS + 1] =  { 0, ... };
	g_smBossMap.SetArray(szName, hits, MAXPLAYERS + 1, false);
}

public void BossHP_OnBossDead(CBoss boss)
{
	if (boss.dConfig != INVALID_HANDLE && boss.dConfig.bIgnore || !boss.dConfig.bShowBeaten)
		return;

	char szName[300];
	BuildName(boss, szName, sizeof(szName));

	int iHits[MAXPLAYERS + 1], iHits_Sorted[MAXPLAYERS + 1];
	g_smBossMap.GetArray(szName, iHits, MAXPLAYERS + 1);
	CopyArray(iHits_Sorted, MAXPLAYERS + 1, iHits, MAXPLAYERS + 1);
	g_smBossMap.Remove(szName);
	SortIntegers(iHits_Sorted, MAXPLAYERS + 1, Sort_Descending);

	int hitlen = GetHitArraySize(iHits, MAXPLAYERS + 1);

	if (hitlen <= 0)
		return;

	int tophitlen = (g_iPlayersInTable < hitlen) ? g_iPlayersInTable:hitlen;
	int[] TopHits = new int[tophitlen];
	GetTopHits(TopHits, iHits, iHits_Sorted, tophitlen, MAXPLAYERS+1);

	int len = 300 + 128 * tophitlen;
	char[] szMessage = new char[len];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i))
			continue;

		BuildMessage(boss, boss.IsBreakable, TopHits, tophitlen, iHits, szMessage, len, i);
	}

	if (g_bStatsReward)
	{
		for (int i = 0; i < tophitlen; i++)
		{
			LogPlayerEvent(TopHits[i], "triggered", i == 0 ? "top_boss_dmg" : (i == 1 ? "second_boss_dmg" : (i == 2 ? "third_boss_dmg" : "super_boss_dmg")));
		}
	}

	if (g_bBossDeathNotice)
	{
		// We need to check numbers of terrorists/zombies alive
		bool bHasAliveT = false;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;

			if (GetClientTeam(i) != CS_TEAM_T || !IsPlayerAlive(i))
				continue;

			bHasAliveT = true;
			break;
		}

		// No terrorists/zombies alive, we need to stop here to prevent a round draw
		if (!bHasAliveT)
			return;

		boss.dConfig.GetName(szName, sizeof(szName));

		char sBossName[64];
		int iFakeClient = -1;

		// Generate boss name
		FormatEx(sBossName, sizeof(sBossName), "BOSS [%s]", szName);

		// Create a fake client if server still have 7+ slots free. (Dont block players from connecting)
		if (GetClientCount(false) < MaxClients - 7)
		{
			g_bHookMessagesDeathNotice = true;
			iFakeClient = CreateFakeClient(sBossName);

			// Validate fake client creation
			if (iFakeClient > 0)
			{
				DataPack data = new DataPack();
				data.WriteCell(iFakeClient);
				data.WriteString(sBossName);

				// Request a frame delay to ensure the fake client is fully connected
				RequestFrame(OnFakeClientReady, data);
			}
			else
			{
				// If fake client creation failed, reset the hook flag
				g_bHookMessagesDeathNotice = false;
			}
		}
	}
}

public void OnFakeClientReady(DataPack data)
{
	data.Reset();
	int iFakeClient = data.ReadCell();
	char sBossName[64];
	data.ReadString(sBossName, sizeof(sBossName));
	delete data;

	// Verify the client is still valid after the frame delay
	if (iFakeClient > 0 && IsClientInGame(iFakeClient))
	{
		// Now switch the team
		CS_SwitchTeam(iFakeClient, CS_TEAM_T);

		// Create a new data pack for the death notice timer
		DataPack noticeData = new DataPack();
		noticeData.WriteCell(iFakeClient);
		noticeData.WriteString(sBossName);

		// We need a small delay related to server processing
		CreateTimer(0.5, Timer_ShowDeathNotice, noticeData);
	}
	else
	{
		// If client is no longer valid, reset the hook flag
		g_bHookMessagesDeathNotice = false;
	}
}

public Action Timer_ShowDeathNotice(Handle timer, DataPack data)
{
	char szName[64];

	data.Reset();
	int iFakeClient = data.ReadCell();
	data.ReadString(szName, sizeof(szName));
	delete data;

	int iUserID = GetClientUserId(iFakeClient);
	int client = GetClientOfUserId(iUserID);

	if (client < 1 || client > MaxClients)
	{
		LogError("Fake client for boss '%s' no longer exists (UserID: %d)", szName, iUserID);
		g_bHookMessagesDeathNotice = false;
		return Plugin_Handled;
	}

	Event event = CreateEvent("player_death");
	if (!event)
	{
		g_bHookMessagesDeathNotice = false;
		return Plugin_Handled;
	}

	event.SetInt("userid", iUserID);
	event.SetInt("attacker", 0);
	event.SetString("weapon", "worldspawn");
	event.Fire();

	// Create a new timer to kick the client after a delay
	DataPack kickData = new DataPack();
	kickData.WriteCell(iUserID);
	kickData.WriteString(szName);
	CreateTimer(1.0, Timer_KickFakeClient, kickData);

	return Plugin_Handled;
}

public Action Timer_KickFakeClient(Handle timer, DataPack data)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	char szName[64];
	data.ReadString(szName, sizeof(szName));
	delete data;

	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		g_bHookMessagesDeathNotice = false;
		return Plugin_Handled;
	}

	if (!IsClientSourceTV(client) && IsFakeClient(client))
	{
		KickClient(client);
	}
	else
	{
		// This should never happen but we need to be sure.
		LogError("Attempted to kick client %d but it is a SourceTV client, not a real player. Kicking it is not possible.", client);

		// Problem: the fake client was not kicked for some reason, we can not let it stay in the server.
		// Solution: check if a real player has the same name as the fake client and kick it.
		char sName[64];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;

			if (IsClientSourceTV(i))
				continue;

			GetClientName(i, sName, sizeof(sName));
			if (strcmp(sName, szName, false) == 0)
			{
				LogError("Found client %d with the same name as death boss '%s'. Kicking it.", i, szName);
				KickClient(i);
				// We do not break the loop, we want to take 0 risk.
			}
		}
	}

	CreateTimer(1.0, Timer_ResetDeathNoticeHook, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action Timer_ResetDeathNoticeHook(Handle timer)
{
	g_bHookMessagesDeathNotice = false;
	return Plugin_Handled;
}

public void BossHP_OnAllBossProcessStart()
{
	g_sHUDText[0] = 0;
}

public void BossHP_OnBossProcessed(CBoss _Boss, bool bHealthChanged, bool bShow)
{
	if (!bShow)
		return;

	CConfig _Config = _Boss.dConfig;
	float fLastChange = _Boss.fLastChange;
	int iBaseHealth = _Boss.iBaseHealth;
	int iHealth = _Boss.iHealth;
	float fTimeout = _Config.fTimeout;

	float fGameTime = GetGameTime();
	if (fTimeout < 0.0 || fGameTime - fLastChange < fTimeout)
	{
		char sFormat[MAX_TEXT_LENGTH];
		if (g_sHUDText[0])
		{
			sFormat[0] = '\n';
			_Config.GetName(sFormat[1], sizeof(sFormat) - 1);
		}
		else
			_Config.GetName(sFormat, sizeof(sFormat));

		int FormatLen = strlen(sFormat);
		sFormat[FormatLen++] = ':';
		sFormat[FormatLen++] = ' ';

		// Update the base health of the boss if the current health is greater than the base health
		// That will allow to show the correct percentage of the boss health
		if (iHealth > iBaseHealth)
		{
			_Boss.iBaseHealth = iHealth;
			iBaseHealth = iHealth;
		}

		int iHPPercentage = RoundToCeil((float(iHealth) / float(iBaseHealth)) * 100.0);

		if (iHPPercentage > 100) iHPPercentage = 100;
		if (iHPPercentage <= 0) iHPPercentage = 0;

		FormatLen += IntToString(iHealth, sFormat[FormatLen], sizeof(sFormat) - FormatLen);

		char sFormatTemp[256], sFormatFinal[256];
		FormatEx(sFormatTemp, sizeof(sFormatTemp), "[%dPERCENTAGE]", iHPPercentage);
		FormatEx(sFormatFinal, sizeof(sFormatFinal), "%s %s", sFormat, sFormatTemp);

		sFormat[FormatLen] = 0;
		iHPPercentage = 0;
		StrCat(g_sHUDText, sizeof(g_sHUDText), sFormatFinal);

		g_bLastBossHudPrinted = false;
	}
}

public void BossHP_OnAllBossProcessEnd()
{
	/*
	if (!g_bLastBossHudPrinted)
		g_bLastBossHudPrinted = true;
	*/
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SDKHook_OnEntitySpawned") == FeatureStatus_Available)
		return;

	SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawnedPost);
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
	RequestFrame(ProcessEntitySpawned, entity);
}

public void OnEntityDestroyed(int entity)
{
	if (!g_aEntity || g_aEntity.Length == 0)
		return;

	RequestFrame(ProcessEntityDestroyed, entity);

	if (CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "SDKHook_OnEntitySpawned") == FeatureStatus_Available)
		return;

	SDKUnhook(entity, SDKHook_SpawnPost, OnEntitySpawnedPost);
}

public void PrepareBossHUD()
{
	if (g_bLastBossHudPrinted)
		g_sHUDText[0] = 0;

	if (g_aEntity)
	{
		float fGameTime = GetGameTime();
		for (int i = 0; i < g_aEntity.Length; i++)
		{
			CEntity _Entity = g_aEntity.Get(i);
			if (_Entity.bActive)
			{
				int iHealth = GetEntityHealth(_Entity.iIndex, _Entity);

				_Entity.iHealth = iHealth;

				char szString[128];

				char szName[64];
				_Entity.GetName(szName, sizeof(szName));

				if (g_bHudSymbols)
					FormatEx(szString, sizeof(szString), ">> %s: %i <<", szName, _Entity.iHealth);
				else
					FormatEx(szString, sizeof(szString), "%s: %i", szName, _Entity.iHealth);

				if (g_sHUDText[0])
					StrCat(g_sHUDText, sizeof(g_sHUDText), "\n");
				StrCat(g_sHUDText, sizeof(g_sHUDText), szString);

				g_bLastHudPrinted = false;

				if (fGameTime - _Entity.fLastHitTime >= g_fTimeout)
					_Entity.bActive = false;
			}
		}
	}

	g_sHUDTextSave[0] = '\0';

	if (g_sHUDText[0] || !g_bLastHudPrinted)
	{
		if (!g_sHUDTextSave[0])
			g_sHUDTextSave = g_sHUDText;

		g_bLastHudPrinted = true;
		g_bLastBossHudPrinted = true;
	}
}

public void OnGameFrame()
{
	static int iFrame = 0;
	iFrame++;

	if (iFrame % g_iFramesToSkip != 0)
		return;

	PrepareBossHUD();

	if (g_sHUDText[0] == '\0')
		return;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		if (IsFakeClient(client))
			continue;
		if (!g_bShowHealth[client])
			continue;

		SendHudMsg(client, g_sHUDTextSave, g_iDisplayType, INVALID_HANDLE, g_iHudColor, g_fHudPos, 3.0, 255);
	}

	iFrame = 0;
}

public void ColorStringToArray(const char[] sColorString, int aColor[3])
{
	char asColors[4][4];
	ExplodeString(sColorString, " ", asColors, sizeof(asColors), sizeof(asColors[]));

	aColor[0] = StringToInt(asColors[0]);
	aColor[1] = StringToInt(asColors[1]);
	aColor[2] = StringToInt(asColors[2]);
}

public void GetConVars()
{
	char StringPos[2][8];
	char ColorValue[64];
	char PosValue[16];

	g_cVHudPosition.GetString(PosValue, sizeof(PosValue));
	ExplodeString(PosValue, " ", StringPos, sizeof(StringPos), sizeof(StringPos[]));

	g_fHudPos[0] = StringToFloat(StringPos[0]);
	g_fHudPos[1] = StringToFloat(StringPos[1]);

	g_cVTopHitsPos.GetString(PosValue, sizeof(PosValue));
	ExplodeString(PosValue, " ", StringPos, sizeof(StringPos), sizeof(StringPos[]));

	g_fTopHitsPos[0] = StringToFloat(StringPos[0]);
	g_fTopHitsPos[1] = StringToFloat(StringPos[1]);

	g_cVHudColor.GetString(ColorValue, sizeof(ColorValue));
	ColorStringToArray(ColorValue, g_iHudColor);

	g_cVTopHitsColor.GetString(ColorValue, sizeof(ColorValue));
	ColorStringToArray(ColorValue, g_iTopHitsColor);

	g_fTimeout = g_cVHudTimeout.FloatValue;

	g_bHudSymbols = g_cVHudSymbols.BoolValue;
	g_iDisplayType = view_as<DisplayType>(g_cVDisplayType.IntValue);

	g_iMinHealthDetect = g_cVHudMinHealth.IntValue;
	g_iMaxHealthDetect = g_cVHudMaxHealth.IntValue;
	g_iHUDChannel = g_cvHUDChannel.IntValue;
	g_bTopHitsTitle = g_cVTopHitsTitle.BoolValue;
	g_iPlayersInTable = g_cVPlayersInTable.IntValue;
	g_bBossHitMoney = g_cVBossHitMoney.BoolValue;
	g_bBossDeathNotice = g_cvBossDeathNotice.BoolValue;
	g_bStatsReward = g_cVStatsReward.BoolValue;
	g_bIgnoreFakeClients = g_cVIgnoreFakeClients.BoolValue;
	g_iFramesToSkip = g_cVFramesToSkip.IntValue;
	g_bBossHitsNotifyConsole = g_cvBossHitsNotifyConsole.BoolValue;
}

public void ReadClientCookies(int client)
{
	char sValue[8];
	g_cShowHealth.Get(client, sValue, sizeof(sValue));
	g_bShowHealth[client] = (sValue[0] == '\0' ? true : view_as<bool>(StringToInt(sValue)));
}

public void ToggleBhud(int client)
{
	g_bShowHealth[client] = !g_bShowHealth[client];
	CPrintToChat(client, "{green}[SM]{default} %T %s", "Show health has been", client, g_bShowHealth[client] ? "Enabled" : "Disabled");

	g_bShowHealth[client] ? g_cShowHealth.Set(client, "1") : g_cShowHealth.Set(client, "0");
}

bool CEntityRemove(int entity)
{
	if (!g_aEntity)
		return false;

	for (int i = 0; i < g_aEntity.Length; i++)
	{
		CEntity _Entity = g_aEntity.Get(i);
		if (_Entity.iIndex == entity)
		{
			g_aEntity.Erase(i);
			delete _Entity;
			return true;
		}
	}

	return false;
}

void ProcessEntitySpawned(int entity)
{
	if (!IsValidEntity(entity))
		return;

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	if (!IsTrackedEntityClass(classname))
		return;

	int iHealth = GetEntityHealth(entity);
	if (iHealth <= g_iMinHealthDetect || iHealth >= g_iMaxHealthDetect)
		return;

	char szName[64];
	GetEntityName(entity, szName);

	if (strlen(szName) == 0)
		FormatEx(szName, sizeof(szName), "Health");

	if (strcmp(classname, "math_counter", false) == 0)
	{
		CEntity _Entity = new CEntity();
		_Entity.SetName(szName);
		_Entity.iIndex = entity;
		_Entity.iMaxHealth = RoundFloat(GetEntPropFloat(entity, Prop_Data, "m_flMax"));
		_Entity.iHealth = iHealth;

		g_aEntity.Push(_Entity);
	}
	else if (strcmp(classname, "func_physbox", false) == 0 || strcmp(classname, "func_physbox_multiplayer", false) == 0 || strcmp(classname, "func_breakable", false) == 0)
	{
		CEntity _Entity = new CEntity();
		_Entity.SetName(szName);
		_Entity.iIndex = entity;
		_Entity.iHealth = iHealth;

		g_aEntity.Push(_Entity);
	}
}

void ProcessEntityDestroyed(int entity)
{
	if (!IsValidEntity(entity))
		return;

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	if (!IsTrackedEntityClass(classname))
		return;

	CEntityRemove(entity);
}

public void CleanupAndInit()
{
	Cleanup();
	Init();
}

public void Init()
{
	g_aEntity = new ArrayList();
	g_smBossMap = CreateTrie();

	g_hHudSync = CreateHudSynchronizer();
	g_hHudTopHitsSync = CreateHudSynchronizer();
}

void Cleanup()
{
	if (g_aEntity != null)
	{
		for (int i = 0; i < g_aEntity.Length; i++)
		{
			CEntity _Entity = g_aEntity.Get(i);
			delete _Entity;
		}
		delete g_aEntity;
	}

	if (g_smBossMap != null)
	{
		g_smBossMap.Clear();
		delete g_smBossMap;
	}

	delete g_hHudSync;
	delete g_hHudTopHitsSync;

	if (g_hTimerHudMsgAll != INVALID_HANDLE)
	{
		KillTimer(g_hTimerHudMsgAll);
		g_hTimerHudMsgAll = INVALID_HANDLE;
	}

	g_bHookMessagesDeathNotice = false;
}

void GetEntityName(int entity, char szName[64])
{
	GetEntPropString(entity, Prop_Data, "m_iName", szName, sizeof(szName));
}

int GetEntityHealth(int entity, CEntity _Entity = null)
{
	int health = 0;

	if (!IsValidEntity(entity))
		return health;

	char szType[64];
	GetEntityClassname(entity, szType, sizeof(szType));

	if (strcmp(szType, "math_counter", false) == 0)
	{
		static int offset = -1;
		if (offset == -1)
			offset = FindDataMapInfo(entity, "m_OutValue");

		float rawValue = GetEntDataFloat(entity, offset);
		float maxValue = GetEntPropFloat(entity, Prop_Data, "m_flMax");

		if (_Entity != null) // If the entity is in our list, use its stored health value
			health = _Entity.iHealth;
		else if (maxValue > 0) // Health is the difference between max and current value
			health = RoundFloat(maxValue - rawValue);
		else // If maxValue is 0, use rawValue directly as health
			health = RoundFloat(rawValue);
	}
	else
	{
		health = GetEntProp(entity, Prop_Data, "m_iHealth");
	}

	if (health < 0)
		health = 0;

	return health;
}

Action Timer_SendHudMsgAll(Handle timer, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	char szMessage[256];
	pack.ReadString(szMessage, sizeof(szMessage));

	DisplayType type = view_as<DisplayType>(pack.ReadCell());

	Handle hHudSync = pack.ReadCell();

	int amount = pack.ReadCell();
	int iColors[3];
	for (int i = 0; i < amount; i++)
		iColors[i] = pack.ReadCell();

	amount = pack.ReadCell();
	float fPosition[2];
	for (int i = 0; i < amount; i++)
		fPosition[i] = pack.ReadFloat();

	float fDuration = pack.ReadFloat();
	int iTransparency = pack.ReadCell();
	int client = pack.ReadCell();

	CloseHandle(pack);

	SendHudMsgAll(szMessage, type, hHudSync, iColors, fPosition, fDuration, iTransparency, false, false, client);

	KillTimer(timer);
	return Plugin_Stop;
}

void SendHudMsgAll(
	char[] szMessage,
	DisplayType type = DISPLAY_CENTER,
	Handle hHudSync = INVALID_HANDLE,
	int iColors[3] = g_iHudColor,
	float fPosition[2] = g_fHudPos,
	float fDuration = 3.0,
	int iTransparency = 255,
	bool bDelayFastPrint = false,
	bool bFilterClients = false,
	int client
)
{
	if (bDelayFastPrint)
	{
		int currentTime = GetTime();

		static int lastTime = 0;
		static float fLastDuration = 0.0;

		int iLastDuration = RoundFloat(fLastDuration);

		if (lastTime + iLastDuration > currentTime)
		{
			DataPack pack = new DataPack();
			pack.WriteString(szMessage);
			pack.WriteCell(type);
			pack.WriteCell(hHudSync);

			pack.WriteCell(sizeof(iColors));
			for (int i = 0; i < sizeof(iColors); i++)
				pack.WriteCell(iColors[i]);

			pack.WriteCell(sizeof(fPosition));
			for (int i = 0; i < sizeof(fPosition); i++)
				pack.WriteFloat(fPosition[i]);

			pack.WriteFloat(fDuration);
			pack.WriteCell(iTransparency);
			pack.WriteCell(client);

			float fWaitTime = float(lastTime + iLastDuration - currentTime);
			g_hTimerHudMsgAll = CreateTimer(fWaitTime, Timer_SendHudMsgAll, pack, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);

			fLastDuration = fWaitTime + fDuration;
			lastTime = currentTime;
			return;
		}

		fLastDuration = fDuration;
		lastTime = currentTime;
	}

	if (!IsValidClient(client) || bFilterClients && !g_bShowHealth[client])
		return;

	SendHudMsg(client, szMessage, type, hHudSync, iColors, fPosition, fDuration, iTransparency);
}

void SendHudMsg(
	int client,
	char[] szMessage,
	DisplayType type = DISPLAY_CENTER,
	Handle hHudSync = INVALID_HANDLE,
	int iColors[3] = g_iHudColor,
	float fPosition[2] = g_fHudPos,
	float fDuration = 3.0,
	int iTransparency = 255
)
{
	if (type == DISPLAY_GAME)
	{
		if (hHudSync == INVALID_HANDLE && g_hHudSync != INVALID_HANDLE)
			hHudSync = g_hHudSync;

		if (hHudSync != INVALID_HANDLE)
		{
			SetHudTextParams(fPosition[0], fPosition[1], fDuration, iColors[0], iColors[1], iColors[2], iTransparency, 0, 0.0, 0.0, 0.0);
			char szMessageFinale[512];
			FormatEx(szMessageFinale, sizeof(szMessageFinale), "%s", szMessage);
			ReplaceString(szMessageFinale,sizeof(szMessageFinale), "PERCENTAGE", "%");

			int iHUDChannel = -1;

			if (g_iHUDChannel < 0 || g_iHUDChannel > 5)
				g_iHUDChannel = 1;

		#if defined _DynamicChannels_included_
			if (bDynamicAvailable)
				iHUDChannel = GetDynamicChannel(g_iHUDChannel);
		#endif

			if (bDynamicAvailable)
				ShowHudText(client, iHUDChannel, "%s", szMessageFinale);
			else
			{
				ClearSyncHud(client, hHudSync);
				ShowSyncHudText(client, hHudSync, "%s", szMessageFinale);
			}
		}
	}
	else if (type == DISPLAY_HINT && !IsVoteInProgress())
	{
		char szMessageFinale[512];
		FormatEx(szMessageFinale, sizeof(szMessageFinale), "%s", szMessage);
		ReplaceString(szMessageFinale,sizeof(szMessageFinale), "PERCENTAGE", "\%%");
		PrintHintText(client, "%s", szMessageFinale);
	}
	else
	{
		char szMessageFinale[512];
		FormatEx(szMessageFinale, sizeof(szMessageFinale), "%s", szMessage);
		ReplaceString(szMessageFinale,sizeof(szMessageFinale), "PERCENTAGE", "\%");
		PrintCenterText(client, "%s", szMessageFinale);
	}
}

public void BuildName(CBoss boss, char[] szName, int maxlen)
{
	CConfig config = boss.dConfig;
	config.GetName(szName, maxlen);
	if (config.IsBreakable)
	{
		CBossBreakable _boss = view_as<CBossBreakable>(boss);
		FormatEx(szName, maxlen, "%s%i", szName, _boss.iBreakableEnt);
	}
	else if (config.IsCounter)
	{
		CBossCounter _boss = view_as<CBossCounter>(boss);
		FormatEx(szName, maxlen, "%s%i", szName, _boss.iCounterEnt);
	}
	else if (config.IsHPBar)
	{
		CBossHPBar _boss = view_as<CBossHPBar>(boss);
		FormatEx(szName, maxlen, "%s%i", szName, _boss.iBackupEnt);
	}
}

public void GetTopHits(int[] TopHits, int[] iHits, int[] iHits_Sorted, int maxlen, int maxhitslen)
{
	for (int i = 0; i < maxlen && i < maxhitslen; i++)
	{
		for (int j = 1; j < maxhitslen; j++)
		{
			if (iHits_Sorted[i] == iHits[j])
			{
				int k = 0;
				while (k < i)
				{
					if (TopHits[k] == j)
						break;
					k++;
				}
				if (k >= i)
				{
					TopHits[i] = j;
					break;
				}
			}
		}
	}
}

public void CopyArray(int[] dest, int destlen, int[] source, int sourcelen)
{
	int len = (destlen < sourcelen) ? destlen:sourcelen;
	for (int i = 0; i < len; i++)
	{
		dest[i] = source[i];
	}
}

public int GetHitArraySize(int[] arr, int maxlen)
{
	int res = 0;
	for (int i = 0; i < maxlen; i++)
	{
		res += (arr[i] > 0) ? 1:0;
	}
	return res;
}

void SortPlayerHits(int[] playerIndices, int[] playerHits, int playerCount)
{
	// Sort players by hits in descending order
	for (int i = 0; i < playerCount - 1; i++)
	{
		for (int j = 0; j < playerCount - i - 1; j++)
		{
			if (playerHits[j] < playerHits[j + 1])
			{
				// Swap hits
				int tempHits = playerHits[j];
				playerHits[j] = playerHits[j + 1];
				playerHits[j + 1] = tempHits;

				// Swap indices
				int tempIndex = playerIndices[j];
				playerIndices[j] = playerIndices[j + 1];
				playerIndices[j + 1] = tempIndex;
			}
		}
	}
}

public void BuildMessage(CBoss boss, bool IsBreakable, int[] TopHits, int tophitslen, int[] iHits, char[] szMessage, int len, int client)
{
	char szName[256];
	boss.dConfig.GetName(szName, sizeof(szName));

	char sTitle[64], sDamage[32], sHits[32];
	FormatEx(sTitle, sizeof(sTitle), "%T", "Top Boss", client);
	FormatEx(sDamage, sizeof(sDamage), "%T", "Damage", client);
	FormatEx(sHits, sizeof(sHits), "%T", "Hits", client);

	// Create arrays to store player info for sorting
	int playerIndices[MAXPLAYERS + 1];
	int playerHits[MAXPLAYERS + 1];
	int playerCount = 0;

	// Collect all players who did damage
	for (int i = 1; i <= MaxClients; i++)
	{
		if (iHits[i] > 0)
		{
			playerIndices[playerCount] = i;
			playerHits[playerCount] = iHits[i];
			playerCount++;
		}
	}

	// Sort players by hits
	SortPlayerHits(playerIndices, playerHits, playerCount);

	// Prepare messages
	char szConsoleMsg[2048];
	if (g_bTopHitsTitle)
	{
		char sDamageUpper[32], sHitsUpper[32];
		FormatEx(sDamageUpper, sizeof(sDamageUpper), "%T", "Damage", client);
		FormatEx(sHitsUpper, sizeof(sHitsUpper), "%T", "Hits", client);

		StringToUpperCase(sTitle);
		StringToUpperCase(sDamageUpper);
		StringToUpperCase(sHitsUpper);

		FormatEx(szMessage, len, "%s %s [%s]\n", sTitle, IsBreakable ? sDamageUpper : sHitsUpper, szName);
		if (g_bBossHitsNotifyConsole)
			FormatEx(szConsoleMsg, sizeof(szConsoleMsg), "=========== %s %s [%s] ===========\n", sTitle, IsBreakable ? sDamageUpper : sHitsUpper, szName);
	}
	else
	{
		FormatEx(szMessage, len, "%T %s [%s]\n", "Top Boss", client, IsBreakable ? sDamage : sHits, szName);
		if (g_bBossHitsNotifyConsole)
			FormatEx(szConsoleMsg, sizeof(szConsoleMsg), "=========== %s %s [%s] ===========\n", sTitle, IsBreakable ? sDamage : sHits, szName);
	}

	// Print results for both console and chat/HUD
	int displayCount = (g_iPlayersInTable < playerCount) ? g_iPlayersInTable : playerCount;
	for (int i = 0; i < playerCount; i++)
	{
		int playerIndex = playerIndices[i];
		char clientName[64];
		if (!IsValidClient(playerIndex) || !GetClientName(playerIndex, clientName, sizeof(clientName)))
			FormatEx(clientName, sizeof(clientName), "Disconnected (#%d)", playerIndex);

		char tmp[128];
		FormatEx(tmp, sizeof(tmp), "%i. %s: %i %s\n", i + 1, clientName, playerHits[i], IsBreakable ? sDamage : sHits);

		if (i < displayCount)
			StrCat(szMessage, len, tmp);

		if (g_bBossHitsNotifyConsole)
			StrCat(szConsoleMsg, sizeof(szConsoleMsg), tmp);
	}

	// Send messages
	SendHudMsgAll(szMessage, DISPLAY_GAME, g_hHudTopHitsSync, g_iTopHitsColor, g_fTopHitsPos, 3.0, 255, false, false, client);
	CPrintToChat(client, "{yellow}%s", szMessage);

	if (g_bBossHitsNotifyConsole)
		PrintToConsole(client, szConsoleMsg);
}

public int GetClientMoney(int client)
{
	if (IsValidClient(client))
		return GetEntProp(client, Prop_Send, "m_iAccount");
	return -1;
}

public bool SetClientMoney(int client, int money)
{
	if (IsValidClient(client))
	{
		SetEntProp(client, Prop_Send, "m_iAccount", money);
		return true;
	}
	return false;
}

stock void StringToUpperCase(char[] input)
{
	int i = 0;
	int x;
	while ((x = input[i]) != '\0')
	{
		if ('a' <= x <= 'z')
			input[i] -= ('a' - 'A');
		i++;
	}
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

public Action Command_BHud(int client, int argc)
{
	ToggleBhud(client);
	return Plugin_Handled;
}

public Action Command_CHP(int client, int argc)
{
	if (!IsValidEntity(g_iEntityId[client]))
	{
		CPrintToChat(client, "{green}[SM]{default} %T", "Invalid Entity", client, g_iEntityId[client]);
		return Plugin_Handled;
	}

	char szName[64], szType[64];
	GetEntityName(g_iEntityId[client], szName);
	GetEntityClassname(g_iEntityId[client], szType, sizeof(szType));

	int health = GetEntityHealth(g_iEntityId[client]);

	CPrintToChat(client, "{green}[SM]{default} %T %s %i (%s): %i HP", "Entity", client, szName, g_iEntityId[client], szType, health);
	return Plugin_Handled;
}

public Action Command_SHP(int client, int argc)
{
	if (!IsValidEntity(g_iEntityId[client]))
	{
		CPrintToChat(client, "{green}[SM]{default} %T", "Invalid Entity", client, g_iEntityId[client]);
		return Plugin_Handled;
	}

	if (argc < 1)
	{
		CReplyToCommand(client, "{green}[SM]{default} %T: sm_subtracthp <health>", "Usage", client);
		return Plugin_Handled;
	}

	char arg[8];
	GetCmdArg(1, arg, sizeof(arg));

	int value = StringToInt(arg);

	int health = EntitySetHealth(client, g_iEntityId[client], value, false);

	CPrintToChat(client, "{green}[SM]{default} %i health subtracted. (%i HP to %i HP)", value, health, health - value);

	return Plugin_Handled;
}

public Action Command_AHP(int client, int argc)
{
	if (!IsValidEntity(g_iEntityId[client]))
	{
		CPrintToChat(client, "{green}[SM]{default} %T", "Invalid Entity", client, g_iEntityId[client]);
		return Plugin_Handled;
	}

	if (argc < 1)
	{
		CReplyToCommand(client, "{green}[SM]{default} %T: sm_addhp <health>", "Usage", client);
		return Plugin_Handled;
	}

	char arg[8];
	GetCmdArg(1, arg, sizeof(arg));

	int value = StringToInt(arg);

	int health = EntitySetHealth(client, g_iEntityId[client], value);

	CPrintToChat(client, "{green}[SM]{default} %T", "Health added", client, value, health, health + value);

	return Plugin_Handled;
}

int EntitySetHealth(int client, int entity, int value, bool bAdd = true)
{
	int health = GetEntityHealth(entity);
	int max;

	char szType[64];
	GetEntityClassname(entity, szType, sizeof(szType));

	SetVariantInt(value);

	if (strcmp(szType, "math_counter", false) == 0)
	{
		char sValue[64] = "Add";
		if (!bAdd)
			sValue = "Subtract";

		bool foundAndApplied = false;
		if (g_aEntity)
		{
			for (int i = 0; i < g_aEntity.Length; i++)
			{
				CEntity _Entity = g_aEntity.Get(i);
				if (_Entity.iIndex == entity)
				{
					if (max != _Entity.iMaxHealth)
					{
						AcceptEntityInput(entity, sValue, client, client);
						foundAndApplied = true;
					}
				}
			}
		}

		if (!foundAndApplied)
			AcceptEntityInput(entity, sValue, client, client);
	}
	else
	{
		char sValue[64] = "RemoveHealth";
		if (bAdd)
			sValue = "AddHealth";

		AcceptEntityInput(entity, sValue, client, client);
	}
	return health;
}

bool IsTrackedEntityClass(const char[] classname)
{
	return strcmp(classname, "func_physbox", false) == 0 || strcmp(classname, "func_physbox_multiplayer", false) == 0 ||
		strcmp(classname, "func_breakable", false) == 0 || strcmp(classname, "math_counter", false) == 0;
}

// Native: Gets the current health of a boss
public int Native_GetBossHealth(Handle plugin, int numParams)
{
	int bossEnt = GetNativeCell(1);

	CBoss boss;
	if (!BossHP_IsBossEnt(bossEnt, boss))
		return -1;

	return boss.iHealth;
}

// Native: Gets the maximum health of a boss
public int Native_GetBossMaxHealth(Handle plugin, int numParams)
{
	int bossEnt = GetNativeCell(1);

	CBoss boss;
	if (!BossHP_IsBossEnt(bossEnt, boss))
		return -1;

	return boss.iBaseHealth;
}

// Native: Gets the total number of hits on a boss
public int Native_GetBossHits(Handle plugin, int numParams)
{
	int bossEnt = GetNativeCell(1);

	char szName[300];
	CBoss boss;
	if (!BossHP_IsBossEnt(bossEnt, boss))
		return -1;

	BuildName(boss, szName, sizeof(szName));

	int iHits[MAXPLAYERS + 1];
	if (!g_smBossMap.GetArray(szName, iHits, MAXPLAYERS + 1))
		return -1;

	int total = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		total += iHits[i];
	}

	return total;
}

// Native: Gets the top hits on a boss
public int Native_GetBossTopHits(Handle plugin, int numParams)
{
	int bossEnt = GetNativeCell(1);
	int maxPlayers = GetNativeCell(2);
	int[] topHits = new int[maxPlayers];

	char szName[300];
	CBoss boss;
	if (!BossHP_IsBossEnt(bossEnt, boss))
		return 0;

	BuildName(boss, szName, sizeof(szName));

	int iHits[MAXPLAYERS + 1];
	if (!g_smBossMap.GetArray(szName, iHits, MAXPLAYERS + 1))
		return 0;

	int iHits_Sorted[MAXPLAYERS + 1];
	CopyArray(iHits_Sorted, MAXPLAYERS + 1, iHits, MAXPLAYERS + 1);
	SortIntegers(iHits_Sorted, MAXPLAYERS + 1, Sort_Descending);

	GetTopHits(topHits, iHits, iHits_Sorted, maxPlayers, MAXPLAYERS + 1);

	SetNativeArray(3, topHits, maxPlayers);
	return GetHitArraySize(iHits, MAXPLAYERS + 1);
}

// Native: Checks if a boss is active
public int Native_IsBossActive(Handle plugin, int numParams)
{
	int bossEnt = GetNativeCell(1);

	CBoss boss;
	if (!BossHP_IsBossEnt(bossEnt, boss))
		return 0;

	return 1;
}

// Native: Gets the name of a boss
public int Native_GetBossName(Handle plugin, int numParams)
{
	int bossEnt = GetNativeCell(1);
	int maxlen = GetNativeCell(3);
	char[] buffer = new char[maxlen];

	CBoss boss;
	if (!BossHP_IsBossEnt(bossEnt, boss))
		return 0;

	boss.dConfig.GetName(buffer, maxlen);
	SetNativeString(2, buffer, maxlen);
	return 1;
}

// Native: Gets the total number of players who hit the boss
public int Native_GetBossHitsCount(Handle plugin, int numParams)
{
	int bossEnt = GetNativeCell(1);

	char szName[300];
	CBoss boss;
	if (!BossHP_IsBossEnt(bossEnt, boss))
		return -1;

	BuildName(boss, szName, sizeof(szName));

	int iHits[MAXPLAYERS + 1];
	if (!g_smBossMap.GetArray(szName, iHits, MAXPLAYERS + 1))
		return -1;

	return GetHitArraySize(iHits, MAXPLAYERS + 1);
}

// Native: Gets the number of hits from a specific player on a boss
public int Native_GetBossHitsByClient(Handle plugin, int numParams)
{
	int bossEnt = GetNativeCell(1);
	int client = GetNativeCell(2);

	if (!IsValidClient(client))
		return -1;

	char szName[300];
	CBoss boss;
	if (!BossHP_IsBossEnt(bossEnt, boss))
		return -1;

	BuildName(boss, szName, sizeof(szName));

	int iHits[MAXPLAYERS + 1];
	if (!g_smBossMap.GetArray(szName, iHits, MAXPLAYERS + 1))
		return -1;

	return iHits[client];
}

// Native: Gets the rank of a player in boss hits
public int Native_GetBossHitsRank(Handle plugin, int numParams)
{
	int bossEnt = GetNativeCell(1);
	int client = GetNativeCell(2);

	if (!IsValidClient(client))
		return -1;

	char szName[300];
	CBoss boss;
	if (!BossHP_IsBossEnt(bossEnt, boss))
		return -1;

	BuildName(boss, szName, sizeof(szName));

	int iHits[MAXPLAYERS + 1];
	if (!g_smBossMap.GetArray(szName, iHits, MAXPLAYERS + 1))
		return -1;

	int iHits_Sorted[MAXPLAYERS + 1];
	CopyArray(iHits_Sorted, MAXPLAYERS + 1, iHits, MAXPLAYERS + 1);
	SortIntegers(iHits_Sorted, MAXPLAYERS + 1, Sort_Descending);

	int rank = 1;
	for (int i = 0; i < MAXPLAYERS + 1; i++)
	{
		if (iHits_Sorted[i] == iHits[client])
			return rank;
		if (iHits_Sorted[i] > iHits[client])
			rank++;
	}

	return rank;
}
