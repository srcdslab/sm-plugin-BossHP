// Health HUD: displays the health of bosses and of any damaged entity with health

// Non-boss entity with health, displayed on the HUD when a player damages it
methodmap CEntity < Basic
{
	public CEntity()
	{
		Basic myclass = new Basic();

		myclass.SetInt("iRef", INVALID_ENT_REFERENCE);
		myclass.SetString("sName", "");
		myclass.SetBool("bActive", false);
		myclass.SetFloat("fLastHitTime", GetGameTime());

		return view_as<CEntity>(myclass);
	}

	public bool GetName(char[] buffer, int length)
	{
		return this.GetString("sName", buffer, length);
	}

	public void SetName(const char[] buffer)
	{
		this.SetString("sName", buffer);
	}

	// Entity reference, use EntRefToEntIndex() to get the entity index
	property int iRef {
		public get() { return this.GetInt("iRef"); }
		public set(int ref) { this.SetInt("iRef", ref); }
	}

	property float fLastHitTime {
		public get() { return this.GetFloat("fLastHitTime"); }
		public set(float lasthittime) { this.SetFloat("fLastHitTime", lasthittime); }
	}

	property bool bActive {
		public get() { return this.GetBool("bActive"); }
		public set(bool active) { this.SetBool("bActive", active); }
	}
}

enum DisplayType
{
	DISPLAY_CENTER = 0,
	DISPLAY_GAME = 1,
	DISPLAY_HINT = 2
}

ConVar g_cvHudType;
ConVar g_cvHudPosition;
ConVar g_cvHudColor;
ConVar g_cvHudChannel;
ConVar g_cvHudSymbols;
ConVar g_cvHudFrames;
ConVar g_cvEntityTimeout;
ConVar g_cvEntityHealthMin;
ConVar g_cvEntityHealthMax;

Cookie g_cShowHealth;

Handle g_hHudSync = INVALID_HANDLE;

// Non-boss entities with health (CEntity)
ArrayList g_aEntity = null;

bool g_bShowHealth[MAXPLAYERS + 1] = { true, ... };
bool g_bDynamicChannels = false;

// Last entity damaged by each client, used by the admin health commands
int g_iClientEntityRef[MAXPLAYERS + 1] = { INVALID_ENT_REFERENCE, ... };

int g_iHudColor[3];
float g_fHudPosition[2];

void HUD_OnPluginStart()
{
	g_cvHudType = CreateConVar("sm_bosshp_hud_type", "2", "HUD display type (0 = center, 1 = game text, 2 = hint)", _, true, 0.0, true, 2.0);
	g_cvHudPosition = CreateConVar("sm_bosshp_hud_position", "-1.0 0.09", "X and Y position of the HUD (game text only)");
	g_cvHudColor = CreateConVar("sm_bosshp_hud_color", "255 0 0", "RGB color of the HUD (game text only)");
	g_cvHudChannel = CreateConVar("sm_bosshp_hud_channel", "1", "DynamicChannels group of the HUD (game text only)", _, true, 0.0, true, 5.0);
	g_cvHudSymbols = CreateConVar("sm_bosshp_hud_symbols", "0", "Wrap the health of damaged entities with >> and <<", _, true, 0.0, true, 1.0);
	g_cvHudFrames = CreateConVar("sm_bosshp_hud_frames", "7", "Refresh the HUD every N frames", _, true, 1.0, true, 66.0);
	g_cvEntityTimeout = CreateConVar("sm_bosshp_entity_timeout", "0.5", "Seconds before the health of a damaged entity fades away", _, true, 0.0, true, 10.0);
	g_cvEntityHealthMin = CreateConVar("sm_bosshp_entity_health_min", "1000", "Minimum health of an entity to show it on the HUD", _, true, 0.0, true, 1000000.0);
	g_cvEntityHealthMax = CreateConVar("sm_bosshp_entity_health_max", "100000", "Maximum health of an entity to show it on the HUD", _, true, 0.0, true, 1000000.0);

	g_cvHudPosition.AddChangeHook(HUD_OnConVarChanged);
	g_cvHudColor.AddChangeHook(HUD_OnConVarChanged);
	HUD_ReadConVars();

	g_cShowHealth = new Cookie("bosshp_hud", "Display boss health", CookieAccess_Private);
	SetCookieMenuItem(HUD_CookieMenu, 0, "BossHP");

	RegConsoleCmd("sm_bhp", Command_ToggleHud, "Toggle the boss health display");
	RegAdminCmd("sm_currenthp", Command_CurrentHP, ADMFLAG_GENERIC, "Show the health of the last entity you damaged");
	RegAdminCmd("sm_subtracthp", Command_SubtractHP, ADMFLAG_GENERIC, "Subtract health from the last entity you damaged");
	RegAdminCmd("sm_addhp", Command_AddHP, ADMFLAG_GENERIC, "Add health to the last entity you damaged");

	g_hHudSync = CreateHudSynchronizer();
	g_aEntity = new ArrayList();
}

void HUD_OnLateLoad()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && !IsFakeClient(client) && AreClientCookiesCached(client))
			HUD_ReadClientCookies(client);
	}

	// Track the entities spawned before the plugin was loaded
	static const char sClassnames[][] = { "func_breakable", "func_physbox", "func_physbox_multiplayer", "math_counter" };
	for (int i = 0; i < sizeof(sClassnames); i++)
	{
		int entity = INVALID_ENT_REFERENCE;
		while ((entity = FindEntityByClassname(entity, sClassnames[i])) != INVALID_ENT_REFERENCE)
			HUD_TrackEntity(EntIndexToEntRef(entity));
	}
}

void HUD_OnMapEnd()
{
	HUD_ClearEntities();

	for (int client = 0; client <= MaxClients; client++)
		g_iClientEntityRef[client] = INVALID_ENT_REFERENCE;
}

void HUD_OnLibraryChanged(const char[] name)
{
	if (strcmp(name, "DynamicChannels", false) == 0)
		HUD_UpdateDynamicChannels();
}

void HUD_UpdateDynamicChannels()
{
	g_bDynamicChannels = LibraryExists("DynamicChannels") && GetFeatureStatus(FeatureType_Native, "GetDynamicChannel") == FeatureStatus_Available;
}

void HUD_OnClientConnected(int client)
{
	g_bShowHealth[client] = true;
	g_iClientEntityRef[client] = INVALID_ENT_REFERENCE;
}

void HUD_OnClientDisconnect(int client)
{
	g_iClientEntityRef[client] = INVALID_ENT_REFERENCE;
}

void HUD_ReadClientCookies(int client)
{
	char sValue[8];
	g_cShowHealth.Get(client, sValue, sizeof(sValue));
	g_bShowHealth[client] = sValue[0] == '\0' || StringToInt(sValue) != 0;
}

void HUD_OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	HUD_ReadConVars();
}

void HUD_ReadConVars()
{
	char sValue[64];

	g_cvHudPosition.GetString(sValue, sizeof(sValue));
	StringToPosition(sValue, g_fHudPosition);

	g_cvHudColor.GetString(sValue, sizeof(sValue));
	StringToColor(sValue, g_iHudColor);
}

public void HUD_CookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
			FormatEx(buffer, maxlen, "%T: %T", "Display boss health", client, g_bShowHealth[client] ? "Enabled" : "Disabled", client);
		}
		case CookieMenuAction_SelectOption:
		{
			HUD_ToggleClient(client);
			ShowCookieMenu(client);
		}
	}
}

void HUD_ToggleClient(int client)
{
	g_bShowHealth[client] = !g_bShowHealth[client];
	g_cShowHealth.Set(client, g_bShowHealth[client] ? "1" : "0");

	CPrintToChat(client, CHAT_PREFIX ... "%T %T", "Show health has been", client, g_bShowHealth[client] ? "Enabled" : "Disabled", client);
}

public Action Command_ToggleHud(int client, int args)
{
	if (!IsInGameCommand(client))
		return Plugin_Handled;

	HUD_ToggleClient(client);
	return Plugin_Handled;
}

// ##     ## ##     ## ########
// ##     ## ##     ## ##     ##
// ##     ## ##     ## ##     ##
// ######### ##     ## ##     ##
// ##     ## ##     ## ##     ##
// ##     ## ##     ## ##     ##
// ##     ##  #######  ########

void HUD_OnGameFrame()
{
	static int iFrame = 0;
	if (++iFrame < g_cvHudFrames.IntValue)
		return;
	iFrame = 0;

	char sText[512];
	HUD_FormatBosses(sText, sizeof(sText));
	HUD_FormatEntities(sText, sizeof(sText));

	if (!sText[0])
		return;

	DisplayType iType = view_as<DisplayType>(g_cvHudType.IntValue);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || IsFakeClient(client) || !g_bShowHealth[client])
			continue;

		SendHudMsg(client, sText, iType, g_hHudSync, g_cvHudChannel.IntValue, g_iHudColor, g_fHudPosition, 3.0);
	}
}

void HUD_FormatBosses(char[] sText, int iMaxLen)
{
	if (!g_aBoss)
		return;

	float fGameTime = GetGameTime();

	for (int i = 0; i < g_aBoss.Length; i++)
	{
		CBoss Boss = g_aBoss.Get(i);
		CConfig Config = Boss.dConfig;

		if (!Boss.bActive || !Boss.bShow || !Config.bShowHealth)
			continue;

		int iHealth = Boss.iHealth;
		if (iHealth <= 0)
			continue;

		float fTimeout = Config.fTimeout;
		if (fTimeout >= 0.0 && fGameTime - Boss.fLastChange >= fTimeout)
			continue;

		// The base health is raised by BossProcess when the boss heals above it
		int iPercentage = RoundToCeil(float(iHealth) / float(Boss.iBaseHealth) * 100.0);

		char sName[64];
		Config.GetName(sName, sizeof(sName));

		char sLine[128];
		FormatEx(sLine, sizeof(sLine), "%s: %d [%d%%]", sName, iHealth, iPercentage);
		AppendLine(sText, iMaxLen, sLine);
	}
}

void HUD_FormatEntities(char[] sText, int iMaxLen)
{
	float fGameTime = GetGameTime();
	float fTimeout = g_cvEntityTimeout.FloatValue;
	bool bSymbols = g_cvHudSymbols.BoolValue;

	for (int i = 0; i < g_aEntity.Length; i++)
	{
		CEntity Entity = g_aEntity.Get(i);
		if (!Entity.bActive)
			continue;

		int entity = EntRefToEntIndex(Entity.iRef);
		if (entity == INVALID_ENT_REFERENCE)
			continue;

		char sName[64];
		Entity.GetName(sName, sizeof(sName));

		char sLine[128];
		if (bSymbols)
			FormatEx(sLine, sizeof(sLine), ">> %s: %d <<", sName, GetEntityHealthValue(entity));
		else
			FormatEx(sLine, sizeof(sLine), "%s: %d", sName, GetEntityHealthValue(entity));
		AppendLine(sText, iMaxLen, sLine);

		if (fGameTime - Entity.fLastHitTime >= fTimeout)
			Entity.bActive = false;
	}
}

// iChannelGroup is the DynamicChannels group, used instead of hHudSync when DynamicChannels is loaded
void SendHudMsg(int client, const char[] sMessage, DisplayType iType, Handle hHudSync, int iChannelGroup, const int iColor[3], const float fPosition[2], float fDuration)
{
	if (iType == DISPLAY_GAME)
	{
		SetHudTextParams(fPosition[0], fPosition[1], fDuration, iColor[0], iColor[1], iColor[2], 255, 0, 0.0, 0.0, 0.0);

	#if defined _DynamicChannels_included_
		if (g_bDynamicChannels)
		{
			ShowHudText(client, GetDynamicChannel(iChannelGroup), "%s", sMessage);
			return;
		}
	#endif

		ClearSyncHud(client, hHudSync);
		ShowSyncHudText(client, hHudSync, "%s", sMessage);
	}
	else if (iType == DISPLAY_HINT && !IsVoteInProgress())
	{
		// The hint text is formatted again by the client
		char sHint[512];
		strcopy(sHint, sizeof(sHint), sMessage);
		ReplaceString(sHint, sizeof(sHint), "%", "%%");
		PrintHintText(client, "%s", sHint);
	}
	else
	{
		PrintCenterText(client, "%s", sMessage);
	}
}

// ######## ##    ## ######## #### ######## #### ########  ######
// ##       ###   ##    ##     ##     ##     ##  ##       ##    ##
// ##       ####  ##    ##     ##     ##     ##  ##       ##
// ######   ## ## ##    ##     ##     ##     ##  ######    ######
// ##       ##  ####    ##     ##     ##     ##  ##             ##
// ##       ##   ###    ##     ##     ##     ##  ##       ##    ##
// ######## ##    ##    ##    ####    ##    #### ########  ######

bool IsHealthEntityClass(const char[] sClassname)
{
	return strcmp(sClassname, "func_breakable", false) == 0 || strcmp(sClassname, "func_physbox", false) == 0 ||
		strcmp(sClassname, "func_physbox_multiplayer", false) == 0 || strcmp(sClassname, "math_counter", false) == 0;
}

void HUD_OnEntitySpawned(int entity, const char[] sClassname)
{
	if (!IsHealthEntityClass(sClassname))
		return;

	// 1 frame later required to get the health
	RequestFrame(HUD_TrackEntity, EntIndexToEntRef(entity));
}

void HUD_TrackEntity(int ref)
{
	int entity = EntRefToEntIndex(ref);
	if (entity == INVALID_ENT_REFERENCE || HUD_FindEntity(ref) != -1)
		return;

	int iHealth = GetEntityHealthValue(entity);
	if (iHealth <= g_cvEntityHealthMin.IntValue || iHealth >= g_cvEntityHealthMax.IntValue)
		return;

	// Already tracked as a boss
	if (IsBossEntity(entity))
		return;

	char sName[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
	if (!sName[0])
		strcopy(sName, sizeof(sName), "Health");

	CEntity Entity = new CEntity();
	Entity.SetName(sName);
	Entity.iRef = ref;

	g_aEntity.Push(Entity);
}

void HUD_OnEntityDestroyed(int entity)
{
	if (!g_aEntity.Length)
		return;

	HUD_UntrackEntity(entity);
}

void HUD_UntrackEntity(int entity)
{
	if (!IsValidEntity(entity))
		return;

	int i = HUD_FindEntity(EntIndexToEntRef(entity));
	if (i == -1)
		return;

	CEntity Entity = g_aEntity.Get(i);
	delete Entity;
	g_aEntity.Erase(i);
}

void HUD_ClearEntities()
{
	for (int i = 0; i < g_aEntity.Length; i++)
	{
		CEntity Entity = g_aEntity.Get(i);
		delete Entity;
	}
	g_aEntity.Clear();
}

int HUD_FindEntity(int ref)
{
	for (int i = 0; i < g_aEntity.Length; i++)
	{
		CEntity Entity = g_aEntity.Get(i);
		if (Entity.iRef == ref)
			return i;
	}

	return -1;
}

// Called when a non-boss entity is damaged by a player
void HUD_OnEntityDamaged(int entity)
{
	int i = HUD_FindEntity(EntIndexToEntRef(entity));
	if (i == -1)
		return;

	CEntity Entity = g_aEntity.Get(i);
	Entity.bActive = true;
	Entity.fLastHitTime = GetGameTime();
}

// The boss health is already displayed, stop showing its entities as generic entities
void HUD_OnBossInitialized(CBoss Boss)
{
	int iEntities[3];
	int iCount = GetBossEntities(Boss, iEntities);

	for (int i = 0; i < iCount; i++)
		HUD_UntrackEntity(iEntities[i]);
}

void HUD_SetClientEntity(int client, int entity)
{
	g_iClientEntityRef[client] = EntIndexToEntRef(entity);
}

bool IsMathCounter(int entity)
{
	char sClassname[64];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));
	return strcmp(sClassname, "math_counter", false) == 0;
}

int GetEntityHealthValue(int entity)
{
	int iHealth;
	if (IsMathCounter(entity))
		iHealth = GetCounterHealth(entity, IsCounterReverse(entity));
	else
		iHealth = GetEntProp(entity, Prop_Data, "m_iHealth");

	return iHealth < 0 ? 0 : iHealth;
}

//    ###    ########  ##     ## #### ##    ##
//   ## ##   ##     ## ###   ###  ##  ###   ##
//  ##   ##  ##     ## #### ####  ##  ####  ##
// ##     ## ##     ## ## ### ##  ##  ## ## ##
// ######### ##     ## ##     ##  ##  ##  ####
// ##     ## ##     ## ##     ##  ##  ##   ###
// ##     ## ########  ##     ## #### ##    ##

int GetClientEntity(int client)
{
	int entity = EntRefToEntIndex(g_iClientEntityRef[client]);
	if (entity == INVALID_ENT_REFERENCE)
	{
		CPrintToChat(client, CHAT_PREFIX ... "%T", "Invalid Entity", client, entity);
		return INVALID_ENT_REFERENCE;
	}

	return entity;
}

public Action Command_CurrentHP(int client, int args)
{
	if (!IsInGameCommand(client))
		return Plugin_Handled;

	int entity = GetClientEntity(client);
	if (entity == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	char sName[64], sClassname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	CPrintToChat(client, CHAT_PREFIX ... "%T %s %d (%s): %d HP", "Entity", client, sName, entity, sClassname, GetEntityHealthValue(entity));
	return Plugin_Handled;
}

public Action Command_SubtractHP(int client, int args)
{
	ChangeClientEntityHealth(client, args, "sm_subtracthp", false);
	return Plugin_Handled;
}

public Action Command_AddHP(int client, int args)
{
	ChangeClientEntityHealth(client, args, "sm_addhp", true);
	return Plugin_Handled;
}

void ChangeClientEntityHealth(int client, int args, const char[] sCommand, bool bAdd)
{
	if (!IsInGameCommand(client))
		return;

	if (args < 1)
	{
		CReplyToCommand(client, CHAT_PREFIX ... "%T: %s <health>", "Usage", client, sCommand);
		return;
	}

	int entity = GetClientEntity(client);
	if (entity == INVALID_ENT_REFERENCE)
		return;

	char sArg[16];
	GetCmdArg(1, sArg, sizeof(sArg));

	int iValue = StringToInt(sArg);
	if (iValue <= 0)
	{
		CReplyToCommand(client, CHAT_PREFIX ... "%T: %s <health>", "Usage", client, sCommand);
		return;
	}

	int iHealth = GetEntityHealthValue(entity);

	char sInput[16];
	if (IsMathCounter(entity))
		strcopy(sInput, sizeof(sInput), bAdd != IsCounterReverse(entity) ? "Add" : "Subtract");
	else
		strcopy(sInput, sizeof(sInput), bAdd ? "AddHealth" : "RemoveHealth");

	SetVariantInt(iValue);
	AcceptEntityInput(entity, sInput, client, client);

	CPrintToChat(client, CHAT_PREFIX ... "%T", bAdd ? "Health added" : "Health subtracted", client, iValue, iHealth, GetEntityHealthValue(entity));
}
