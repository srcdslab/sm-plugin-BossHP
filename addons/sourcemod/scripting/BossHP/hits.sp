// Boss hits: per player hits (or damage for breakable bosses), top hits table and rewards

ConVar g_cvTopHitsPlayers;
ConVar g_cvTopHitsTitle;
ConVar g_cvTopHitsPosition;
ConVar g_cvTopHitsColor;
ConVar g_cvTopHitsConsole;
ConVar g_cvTopHitsMoney;
ConVar g_cvTopHitsReward;
ConVar g_cvDeathNotice;

Handle g_hTopHitsSync = INVALID_HANDLE;

int g_iTopHitsColor[3];
float g_fTopHitsPosition[2];

// Hide the connect/disconnect messages of the fake client used for the boss death notice
bool g_bHideFakeClientMessages = false;

void Hits_OnPluginStart()
{
	g_cvTopHitsPlayers = CreateConVar("sm_bosshp_tophits_players", "3", "Number of players in the top hits table", _, true, 1.0, true, 10.0);
	g_cvTopHitsTitle = CreateConVar("sm_bosshp_tophits_uppercase", "1", "Write the title of the top hits table in uppercase", _, true, 0.0, true, 1.0);
	g_cvTopHitsPosition = CreateConVar("sm_bosshp_tophits_position", "0.02 0.3", "X and Y position of the top hits table");
	g_cvTopHitsColor = CreateConVar("sm_bosshp_tophits_color", "255 255 0", "RGB color of the top hits table");
	g_cvTopHitsConsole = CreateConVar("sm_bosshp_tophits_console", "1", "Print the hits of every player in the console when a boss dies", _, true, 0.0, true, 1.0);
	g_cvTopHitsMoney = CreateConVar("sm_bosshp_tophits_money", "1", "Give $1 to a player for each boss hit", _, true, 0.0, true, 1.0);
	g_cvTopHitsReward = CreateConVar("sm_bosshp_tophits_reward", "0", "Log a stats event for the players in the top hits table", _, true, 0.0, true, 1.0);
	g_cvDeathNotice = CreateConVar("sm_bosshp_death_notice", "1", "Show a kill feed entry when a boss dies", _, true, 0.0, true, 1.0);

	g_cvTopHitsPosition.AddChangeHook(Hits_OnConVarChanged);
	g_cvTopHitsColor.AddChangeHook(Hits_OnConVarChanged);
	Hits_ReadConVars();

	HookEvent("player_connect_client", Event_FakeClientMessage, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_FakeClientMessage, EventHookMode_Pre);

	g_hTopHitsSync = CreateHudSynchronizer();
}

void Hits_OnMapStart()
{
	// Team names used by the stats events
	GetTeams();
}

void Hits_OnMapEnd()
{
	g_bHideFakeClientMessages = false;
}

void Hits_OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	Hits_ReadConVars();
}

void Hits_ReadConVars()
{
	char sValue[64];

	g_cvTopHitsPosition.GetString(sValue, sizeof(sValue));
	StringToPosition(sValue, g_fTopHitsPosition);

	g_cvTopHitsColor.GetString(sValue, sizeof(sValue));
	StringToColor(sValue, g_iTopHitsColor);
}

public Action Event_FakeClientMessage(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bHideFakeClientMessages && event.GetBool("bot"))
		event.BroadcastDisabled = true;

	return Plugin_Continue;
}

// ##     ## #### ########  ######
// ##     ##  ##     ##    ##    ##
// ##     ##  ##     ##    ##
// #########  ##     ##     ######
// ##     ##  ##     ##          ##
// ##     ##  ##     ##    ##    ##
// ##     ## ####    ##     ######

void Hits_Get(CBoss Boss, int iHits[MAXPLAYERS + 1])
{
	if (!Boss.GetArray("aHits", iHits, sizeof(iHits)))
	{
		for (int i = 0; i < sizeof(iHits); i++)
			iHits[i] = 0;
	}
}

void Hits_Add(CBoss Boss, int client, int iAmount)
{
	int iHits[MAXPLAYERS + 1];
	Hits_Get(Boss, iHits);
	iHits[client] += iAmount;
	Boss.SetArray("aHits", iHits, sizeof(iHits));

	if (g_cvTopHitsMoney.BoolValue)
		SetEntProp(client, Prop_Send, "m_iAccount", GetEntProp(client, Prop_Send, "m_iAccount") + 1);
}

// Fills aClients with the clients who hit the boss, best first, and returns their count
int Hits_GetRanking(const int iHits[MAXPLAYERS + 1], int aClients[MAXPLAYERS])
{
	int iCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (iHits[client] <= 0)
			continue;

		// Insertion sort, players with the same hits keep the client index order
		int i = iCount++;
		while (i > 0 && iHits[aClients[i - 1]] < iHits[client])
		{
			aClients[i] = aClients[i - 1];
			i--;
		}
		aClients[i] = client;
	}

	return iCount;
}

// A hurttrigger replaces the entity outputs as the source of hits
bool Hits_HasHurtTrigger(CConfig Config)
{
	char sHurtTrigger[2];
	Config.GetHurtTrigger(sHurtTrigger, sizeof(sHurtTrigger));
	return sHurtTrigger[0] != '\0';
}

void Hits_OnBossInitialized(CBoss Boss)
{
	int iHits[MAXPLAYERS + 1];
	Boss.SetArray("aHits", iHits, sizeof(iHits));

	if (Boss.IsBreakable)
	{
		int iBreakableEnt = view_as<CBossBreakable>(Boss).iBreakableEnt;
		if (IsValidEntity(iBreakableEnt))
			Boss.SetInt("iHitsHealth", GetEntProp(iBreakableEnt, Prop_Data, "m_iHealth"));
	}
}

// Called when an entity output of the boss is fired by a player
void Hits_OnBossEntityDamaged(CBoss Boss, int client)
{
	CConfig Config = Boss.dConfig;
	if (Config.bIgnore || Hits_HasHurtTrigger(Config))
		return;

	int iAmount = 1;

	// Breakable bosses count the damage instead of the hits
	if (Boss.IsBreakable)
	{
		int iBreakableEnt = view_as<CBossBreakable>(Boss).iBreakableEnt;
		if (!IsValidEntity(iBreakableEnt))
			return;

		int iHealth = GetEntProp(iBreakableEnt, Prop_Data, "m_iHealth");
		iAmount = Boss.GetInt("iHitsHealth", iHealth) - iHealth;
		Boss.SetInt("iHitsHealth", iHealth);

		if (iAmount <= 0)
			return;
	}

	Hits_Add(Boss, client, iAmount);
}

// Called when the hurttrigger of the boss fires
void Hits_OnBossHurt(CBoss Boss, int activator, float fDamage)
{
	if (Boss.dConfig.bIgnore || !IsValidClient(activator, g_cvIgnoreBots.BoolValue))
		return;

	int iAmount = 1;
	if (Boss.IsBreakable && fDamage > 1.0)
		iAmount = RoundFloat(fDamage);

	Hits_Add(Boss, activator, iAmount);
}

void Hits_OnBossDead(CBoss Boss)
{
	CConfig Config = Boss.dConfig;
	if (Config.bIgnore || !Config.bShowBeaten)
		return;

	int iHits[MAXPLAYERS + 1];
	Hits_Get(Boss, iHits);

	int aClients[MAXPLAYERS];
	int iCount = Hits_GetRanking(iHits, aClients);
	if (!iCount)
		return;

	int iTopCount = g_cvTopHitsPlayers.IntValue;
	if (iTopCount > iCount)
		iTopCount = iCount;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client))
			Hits_PrintTopHits(client, Boss, iHits, aClients, iCount, iTopCount);
	}

	if (g_cvTopHitsReward.BoolValue)
	{
		static const char sEvents[][] = { "top_boss_dmg", "second_boss_dmg", "third_boss_dmg", "super_boss_dmg" };

		for (int i = 0; i < iTopCount; i++)
			LogPlayerEvent(aClients[i], "triggered", sEvents[i < 3 ? i : 3]);
	}

	if (g_cvDeathNotice.BoolValue)
		Hits_ShowDeathNotice(Boss);
}

void Hits_PrintTopHits(int client, CBoss Boss, const int iHits[MAXPLAYERS + 1], const int aClients[MAXPLAYERS], int iCount, int iTopCount)
{
	char sBoss[64];
	Boss.dConfig.GetName(sBoss, sizeof(sBoss));

	char sTitle[64], sUnit[32];
	FormatEx(sTitle, sizeof(sTitle), "%T", "Top Boss", client);
	FormatEx(sUnit, sizeof(sUnit), "%T", Boss.IsBreakable ? "Damage" : "Hits", client);

	char sHeader[160];
	if (g_cvTopHitsTitle.BoolValue)
	{
		char sUnitUpper[32];
		strcopy(sUnitUpper, sizeof(sUnitUpper), sUnit);
		StringToUpper(sTitle);
		StringToUpper(sUnitUpper);
		FormatEx(sHeader, sizeof(sHeader), "%s %s [%s]", sTitle, sUnitUpper, sBoss);
	}
	else
	{
		FormatEx(sHeader, sizeof(sHeader), "%s %s [%s]", sTitle, sUnit, sBoss);
	}

	bool bConsole = g_cvTopHitsConsole.BoolValue;

	char sMessage[1024], sConsole[4096];
	FormatEx(sMessage, sizeof(sMessage), "%s\n", sHeader);
	if (bConsole)
		FormatEx(sConsole, sizeof(sConsole), "=========== %s ===========\n", sHeader);

	for (int i = 0; i < iCount; i++)
	{
		int target = aClients[i];

		char sName[64];
		if (!IsClientInGame(target) || !GetClientName(target, sName, sizeof(sName)))
			FormatEx(sName, sizeof(sName), "Disconnected (#%d)", target);

		char sLine[128];
		FormatEx(sLine, sizeof(sLine), "%d. %s: %d %s\n", i + 1, sName, iHits[target], sUnit);

		if (i < iTopCount)
			StrCat(sMessage, sizeof(sMessage), sLine);

		if (bConsole)
			StrCat(sConsole, sizeof(sConsole), sLine);
		else if (i >= iTopCount)
			break;
	}

	SendHudMsg(client, sMessage, DISPLAY_GAME, g_hTopHitsSync, g_iTopHitsColor, g_fTopHitsPosition, 3.0);
	CPrintToChat(client, "{yellow}%s", sMessage);

	if (bConsole)
		PrintToConsole(client, "%s", sConsole);
}

// ########  ########    ###    ######## ##     ##
// ##     ## ##         ## ##      ##    ##     ##
// ##     ## ##        ##   ##     ##    ##     ##
// ##     ## ######   ##     ##    ##    #########
// ##     ## ##       #########    ##    ##     ##
// ##     ## ##       ##     ##    ##    ##     ##
// ########  ######## ##     ##    ##    ##     ##

// Shows the boss in the kill feed by killing a fake client named after it
void Hits_ShowDeathNotice(CBoss Boss)
{
	// Without any terrorist alive, the fake client would cause a round draw
	bool bHasAliveT = false;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && GetClientTeam(client) == CS_TEAM_T && IsPlayerAlive(client))
		{
			bHasAliveT = true;
			break;
		}
	}

	if (!bHasAliveT)
		return;

	// Keep 7 slots free to not block players from connecting
	if (GetClientCount(false) >= MaxClients - 7)
		return;

	char sBoss[64], sName[MAX_NAME_LENGTH];
	Boss.dConfig.GetName(sBoss, sizeof(sBoss));
	FormatEx(sName, sizeof(sName), "BOSS [%s]", sBoss);

	g_bHideFakeClientMessages = true;

	int iFakeClient = CreateFakeClient(sName);
	if (iFakeClient <= 0)
	{
		g_bHideFakeClientMessages = false;
		return;
	}

	DataPack data = new DataPack();
	data.WriteCell(GetClientUserId(iFakeClient));
	data.WriteString(sName);

	// Wait for the fake client to be fully connected
	RequestFrame(Hits_OnFakeClientReady, data);
}

void Hits_OnFakeClientReady(DataPack data)
{
	data.Reset();
	int iUserId = data.ReadCell();

	int iFakeClient = GetClientOfUserId(iUserId);
	if (!iFakeClient || !IsClientInGame(iFakeClient))
	{
		delete data;
		g_bHideFakeClientMessages = false;
		return;
	}

	CS_SwitchTeam(iFakeClient, CS_TEAM_T);

	// Small delay related to server processing
	CreateTimer(0.5, Timer_FakeClientDeath, data, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
}

Action Timer_FakeClientDeath(Handle timer, DataPack data)
{
	data.Reset();
	int iUserId = data.ReadCell();

	char sName[MAX_NAME_LENGTH];
	data.ReadString(sName, sizeof(sName));

	if (!GetClientOfUserId(iUserId))
	{
		LogError("Fake client for boss \"%s\" no longer exists (UserID: %d)", sName, iUserId);
		g_bHideFakeClientMessages = false;
		return Plugin_Stop;
	}

	Event event = CreateEvent("player_death");
	if (event)
	{
		event.SetInt("userid", iUserId);
		event.SetInt("attacker", 0);
		event.SetString("weapon", "worldspawn");
		event.Fire();
	}

	DataPack kickData = new DataPack();
	kickData.WriteCell(iUserId);
	kickData.WriteString(sName);
	CreateTimer(1.0, Timer_KickFakeClient, kickData, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);

	return Plugin_Stop;
}

Action Timer_KickFakeClient(Handle timer, DataPack data)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());

	char sName[MAX_NAME_LENGTH];
	data.ReadString(sName, sizeof(sName));

	if (client && IsClientInGame(client))
	{
		if (IsFakeClient(client) && !IsClientSourceTV(client))
		{
			KickClient(client);
		}
		else
		{
			// This should never happen, but the fake client must not stay on the server
			LogError("Client %d of boss \"%s\" is not a fake client, kicking the fake clients with the same name instead.", client, sName);

			char sClientName[MAX_NAME_LENGTH];
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || !IsFakeClient(i) || IsClientSourceTV(i))
					continue;

				GetClientName(i, sClientName, sizeof(sClientName));
				if (strcmp(sClientName, sName, false) == 0)
					KickClient(i);
			}
		}
	}

	// Keep hiding the messages until the disconnect event is fired
	CreateTimer(1.0, Timer_ShowFakeClientMessages, _, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

Action Timer_ShowFakeClientMessages(Handle timer)
{
	g_bHideFakeClientMessages = false;
	return Plugin_Stop;
}

// ASCII only, multi-byte characters are kept as is
void StringToUpper(char[] sText)
{
	for (int i = 0; sText[i]; i++)
	{
		if ('a' <= sText[i] <= 'z')
			sText[i] -= 'a' - 'A';
	}
}
