// Public API: forwards and natives (see include/BossHP.inc)

GlobalForward g_hForward_OnBossInitialized = null;
GlobalForward g_hForward_OnBossProcessed = null;
GlobalForward g_hForward_OnBossDead = null;
GlobalForward g_hForward_OnBossDamaged = null;
GlobalForward g_hForward_OnAllBossProcessStart = null;
GlobalForward g_hForward_OnAllBossProcessEnd = null;

void API_AskPluginLoad2()
{
	CreateNative("BossHP_IsBossEnt", Native_IsBossEntity);
	CreateNative("BossHP_GetBossHealth", Native_GetBossHealth);
	CreateNative("BossHP_GetBossMaxHealth", Native_GetBossMaxHealth);
	CreateNative("BossHP_GetBossName", Native_GetBossName);
	CreateNative("BossHP_GetBossHits", Native_GetBossHits);
	CreateNative("BossHP_GetBossHitsCount", Native_GetBossHitsCount);
	CreateNative("BossHP_GetBossHitsByClient", Native_GetBossHitsByClient);
	CreateNative("BossHP_GetBossHitsRank", Native_GetBossHitsRank);
	CreateNative("BossHP_GetBossTopHits", Native_GetBossTopHits);

	RegPluginLibrary("BossHP");
}

void API_OnPluginStart()
{
	g_hForward_OnAllBossProcessStart = new GlobalForward("BossHP_OnAllBossProcessStart", ET_Ignore, Param_Cell);
	g_hForward_OnAllBossProcessEnd = new GlobalForward("BossHP_OnAllBossProcessEnd", ET_Ignore, Param_Cell);
	g_hForward_OnBossInitialized = new GlobalForward("BossHP_OnBossInitialized", ET_Ignore, Param_Cell);
	g_hForward_OnBossProcessed = new GlobalForward("BossHP_OnBossProcessed", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	g_hForward_OnBossDead = new GlobalForward("BossHP_OnBossDead", ET_Ignore, Param_Cell);
	g_hForward_OnBossDamaged = new GlobalForward("BossHP_OnBossDamaged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float);
}

// ########  #######  ########  ##      ##    ###    ########  ########   ######
// ##       ##     ## ##     ## ##  ##  ##   ## ##   ##     ## ##     ## ##    ##
// ##       ##     ## ##     ## ##  ##  ##  ##   ##  ##     ## ##     ## ##
// ######   ##     ## ########  ##  ##  ## ##     ## ########  ##     ##  ######
// ##       ##     ## ##   ##   ##  ##  ## ######### ##   ##   ##     ##       ##
// ##       ##     ## ##    ##  ##  ##  ## ##     ## ##    ##  ##     ## ##    ##
// ##        #######  ##     ##  ###  ###  ##     ## ##     ## ########   ######

void CreateForward_OnBossInitialized(CBoss boss)
{
	Call_StartForward(g_hForward_OnBossInitialized);
	Call_PushCell(boss);
	Call_Finish();
}

void CreateForward_OnBossProcessed(CBoss boss, bool bHealthChanged, bool bShow)
{
	Call_StartForward(g_hForward_OnBossProcessed);
	Call_PushCell(boss);
	Call_PushCell(bHealthChanged);
	Call_PushCell(bShow);
	Call_Finish();
}

void CreateForward_OnBossDead(CBoss boss)
{
	Call_StartForward(g_hForward_OnBossDead);
	Call_PushCell(boss);
	Call_Finish();
}

void CreateForward_OnBossDamaged(CBoss boss, CConfig config, int activator, float damage)
{
	Call_StartForward(g_hForward_OnBossDamaged);
	Call_PushCell(boss);
	Call_PushCell(config);
	Call_PushCell(activator);
	Call_PushFloat(damage);
	Call_Finish();
}

void CreateForward_OnAllBossProcessStart(ArrayList aBoss)
{
	Call_StartForward(g_hForward_OnAllBossProcessStart);
	Call_PushCell(aBoss);
	Call_Finish();
}

void CreateForward_OnAllBossProcessEnd(ArrayList aBoss)
{
	Call_StartForward(g_hForward_OnAllBossProcessEnd);
	Call_PushCell(aBoss);
	Call_Finish();
}

// ##    ##    ###    ######## #### ##     ## ########  ######
// ###   ##   ## ##      ##     ##  ##     ## ##       ##    ##
// ####  ##  ##   ##     ##     ##  ##     ## ##       ##
// ## ## ## ##     ##    ##     ##  ##     ## ######    ######
// ##  #### #########    ##     ##   ##   ##  ##             ##
// ##   ### ##     ##    ##     ##    ## ##   ##       ##    ##
// ##    ## ##     ##    ##    ####    ###    ########  ######

public int Native_IsBossEntity(Handle plugin, int numParams)
{
	CBoss Boss;
	if (!IsBossEntity(GetNativeCell(1), Boss))
		return false;

	SetNativeCellRef(2, Boss);
	return true;
}

public int Native_GetBossHealth(Handle plugin, int numParams)
{
	CBoss Boss;
	if (!IsBossEntity(GetNativeCell(1), Boss))
		return -1;

	return Boss.iHealth;
}

public int Native_GetBossMaxHealth(Handle plugin, int numParams)
{
	CBoss Boss;
	if (!IsBossEntity(GetNativeCell(1), Boss))
		return -1;

	return Boss.iBaseHealth;
}

public int Native_GetBossName(Handle plugin, int numParams)
{
	int iMaxLen = GetNativeCell(3);

	CBoss Boss;
	if (iMaxLen <= 0 || !IsBossEntity(GetNativeCell(1), Boss))
		return false;

	char[] sName = new char[iMaxLen];
	Boss.dConfig.GetName(sName, iMaxLen);
	SetNativeString(2, sName, iMaxLen);
	return true;
}

public int Native_GetBossHits(Handle plugin, int numParams)
{
	CBoss Boss;
	if (!IsBossEntity(GetNativeCell(1), Boss))
		return -1;

	return Hits_GetTotal(Boss);
}

public int Native_GetBossHitsCount(Handle plugin, int numParams)
{
	CBoss Boss;
	if (!IsBossEntity(GetNativeCell(1), Boss))
		return -1;

	int iHits[MAXPLAYERS + 1];
	Hits_Get(Boss, iHits);

	int aClients[MAXPLAYERS];
	return Hits_GetRanking(iHits, aClients);
}

public int Native_GetBossHitsByClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(2);

	CBoss Boss;
	if (!IsValidClient(client) || !IsBossEntity(GetNativeCell(1), Boss))
		return -1;

	int iHits[MAXPLAYERS + 1];
	Hits_Get(Boss, iHits);
	return iHits[client];
}

public int Native_GetBossHitsRank(Handle plugin, int numParams)
{
	int client = GetNativeCell(2);

	CBoss Boss;
	if (!IsValidClient(client) || !IsBossEntity(GetNativeCell(1), Boss))
		return -1;

	return Hits_GetRank(Boss, client);
}

public int Native_GetBossTopHits(Handle plugin, int numParams)
{
	int iMaxPlayers = GetNativeCell(2);

	CBoss Boss;
	if (!IsBossEntity(GetNativeCell(1), Boss))
		return -1;

	int iHits[MAXPLAYERS + 1];
	Hits_Get(Boss, iHits);

	int aClients[MAXPLAYERS];
	int iCount = Hits_GetRanking(iHits, aClients);

	if (iMaxPlayers > iCount)
		iMaxPlayers = iCount;

	if (iMaxPlayers > 0)
		SetNativeArray(3, aClients, iMaxPlayers);

	return iCount;
}
