// Boss lifecycle: a trigger adds the boss, it is initialized once its entities exist,
// then processed every frame until it dies or is removed

void Bosses_Cleanup()
{
	if (g_aBoss)
	{
		for (int i = 0; i < g_aBoss.Length; i++)
		{
			CBoss Boss = g_aBoss.Get(i);
			delete Boss;
		}
		delete g_aBoss;
	}

	delete g_aHadOnce;
}

// Removes every boss, called on a new round and when the config is loaded
void Bosses_Reset()
{
	Bosses_Cleanup();

	if (!g_aConfig)
		return;

	g_aBoss = new ArrayList();
	g_aHadOnce = new StringMap();
}

CBoss BossAdd(CConfig Config, int entity)
{
	CBoss Boss = view_as<CBoss>(INVALID_HANDLE);

	if (Config.IsBreakable)
		Boss = new CBossBreakable();
	else if (Config.IsCounter)
		Boss = new CBossCounter();
	else if (Config.IsHPBar)
		Boss = new CBossHPBar();

	if (Boss == INVALID_HANDLE)
		return Boss;

	Boss.iEntity = entity;
	Boss.dConfig = Config;
	Boss.bActive = false;

	float fTriggerDelay = Config.fTriggerDelay;
	if (fTriggerDelay > 0)
		Boss.fWaitUntil = GetGameTime() + fTriggerDelay;

	if (HasConfigTrigger(Config, BossTrigger_Show))
		Boss.bShow = false;

	g_aBoss.Push(Boss);
	return Boss;
}

// Removes the boss at this index, bDead when it was beaten (top hits and BossHP_OnBossDead)
void BossRemove(int iIndex, const char[] sReason, bool bDead)
{
	CBoss Boss = g_aBoss.Get(iIndex);

	if (g_cvVerboseLog.IntValue > 0)
	{
		char sBoss[64];
		Boss.dConfig.GetName(sBoss, sizeof(sBoss));
		LogMessage("Deleting boss %s (%d) (%s)", sBoss, iIndex, sReason);
	}

	if (bDead)
	{
		Hits_OnBossDead(Boss);
		CreateForward_OnBossDead(Boss);
	}

	delete Boss;
	g_aBoss.Erase(iIndex);
}

void Bosses_OnGameFrame()
{
	if (!g_aBoss || g_aBoss.Length <= 0)
		return;

	CreateForward_OnAllBossProcessStart(g_aBoss);

	float fGameTime = GetGameTime();

	for (int i = 0; i < g_aBoss.Length; i++)
	{
		CBoss Boss = g_aBoss.Get(i);

		if (Boss.fKillAt && Boss.fKillAt < fGameTime)
		{
			BossRemove(i--, "KillAt", true);
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
			BossRemove(i--, "dead", true);
	}

	CreateForward_OnAllBossProcessEnd(g_aBoss);
}

// ######## ##    ## ######## #### ######## #### ########  ######
// ##       ###   ##    ##     ##     ##     ##  ##       ##    ##
// ##       ####  ##    ##     ##     ##     ##  ##       ##
// ######   ## ## ##    ##     ##     ##     ##  ######    ######
// ##       ##  ####    ##     ##     ##     ##  ##             ##
// ##       ##   ###    ##     ##     ##     ##  ##       ##    ##
// ######## ##    ##    ##    ####    ##    #### ########  ######

// Entities the health of the boss is read from, returns their count
int GetBossEntities(CBoss Boss, int iEntities[3])
{
	if (Boss.IsBreakable)
	{
		iEntities[0] = view_as<CBossBreakable>(Boss).iBreakableEnt;
		return 1;
	}

	if (Boss.IsCounter)
	{
		iEntities[0] = view_as<CBossCounter>(Boss).iCounterEnt;
		return 1;
	}

	if (Boss.IsHPBar)
	{
		CBossHPBar HPBar = view_as<CBossHPBar>(Boss);
		iEntities[0] = HPBar.iCounterEnt;
		iEntities[1] = HPBar.iIteratorEnt;
		iEntities[2] = HPBar.iBackupEnt;
		return 3;
	}

	return 0;
}

bool IsBossHealthEntity(CBoss Boss, int entity)
{
	int iEntities[3];
	int iCount = GetBossEntities(Boss, iEntities);

	for (int i = 0; i < iCount; i++)
	{
		if (iEntities[i] == entity)
			return true;
	}

	return false;
}

// Finds the boss of an entity: its trigger entity or one of its health entities
bool IsBossEntity(int entity, CBoss &Boss = view_as<CBoss>(INVALID_HANDLE))
{
	if (!g_aBoss || !IsValidEntity(entity))
		return false;

	for (int i = 0; i < g_aBoss.Length; i++)
	{
		CBoss _Boss = g_aBoss.Get(i);
		if (_Boss.iEntity == entity || IsBossHealthEntity(_Boss, entity))
		{
			Boss = _Boss;
			return true;
		}
	}

	return false;
}

// Finds a health entity of the boss. With name fixup, takes the first template instance
// ("<name>&0001") not used by another boss, and returns its template number in iTemplateNum.
int FindBossEntity(CBoss Boss, const char[] sName, const char[] sClassname, bool bNameFixup, int &iTemplateNum)
{
	if (!bNameFixup)
		return FindEntityByTargetname(INVALID_ENT_REFERENCE, sName, sClassname);

	char sPattern[64];
	FormatEx(sPattern, sizeof(sPattern), "%s&*", sName);

	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByTargetname(entity, sPattern, sClassname)) != INVALID_ENT_REFERENCE)
	{
		if (!IsEntityUsedByOtherBoss(Boss, entity))
			break;
	}

	if (entity == INVALID_ENT_REFERENCE)
		return INVALID_ENT_REFERENCE;

	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	iTemplateNum = SplitTemplateName(sTargetname);
	return iTemplateNum == -1 ? INVALID_ENT_REFERENCE : entity;
}

bool IsEntityUsedByOtherBoss(CBoss Boss, int entity)
{
	for (int i = 0; i < g_aBoss.Length; i++)
	{
		CBoss _Boss = g_aBoss.Get(i);
		if (_Boss != Boss && IsBossHealthEntity(_Boss, entity))
			return true;
	}

	return false;
}

// #### ##    ## #### ########
//  ##  ###   ##  ##     ##
//  ##  ####  ##  ##     ##
//  ##  ## ## ##  ##     ##
//  ##  ##  ####  ##     ##
//  ##  ##   ###  ##     ##
// #### ##    ## ####    ##

// Finds the entities of the boss, returns false while they do not exist yet
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

		int iBreakableEnt = FindBossEntity(_Boss, sBreakable, "*", bNameFixup, iTemplateNum);
		if (iBreakableEnt == INVALID_ENT_REFERENCE)
			return false;

		Boss.iBreakableEnt = iBreakableEnt;
	}
	else if (_Boss.IsCounter)
	{
		CBossCounter Boss = view_as<CBossCounter>(_Boss);
		CConfigCounter Config = view_as<CConfigCounter>(_Config);

		char sCounter[64];
		Config.GetCounter(sCounter, sizeof(sCounter));

		int iCounterEnt = FindBossEntity(_Boss, sCounter, "math_counter", bNameFixup, iTemplateNum);
		if (iCounterEnt == INVALID_ENT_REFERENCE)
			return false;

		Boss.iCounterEnt = iCounterEnt;
		Config.bCounterReverse = IsCounterReverse(iCounterEnt);
	}
	else if (_Boss.IsHPBar)
	{
		CBossHPBar Boss = view_as<CBossHPBar>(_Boss);
		CConfigHPBar Config = view_as<CConfigHPBar>(_Config);

		char sIterator[64], sCounter[64], sBackup[64];
		Config.GetIterator(sIterator, sizeof(sIterator));
		Config.GetCounter(sCounter, sizeof(sCounter));
		Config.GetBackup(sBackup, sizeof(sBackup));

		// The iterator gives the template, the counter and the backup are spawned with it
		int iIteratorEnt = FindBossEntity(_Boss, sIterator, "math_counter", bNameFixup, iTemplateNum);
		if (iIteratorEnt == INVALID_ENT_REFERENCE)
			return false;

		if (iTemplateNum != -1)
		{
			Format(sCounter, sizeof(sCounter), "%s&%04d", sCounter, iTemplateNum);
			if (sBackup[0])
				Format(sBackup, sizeof(sBackup), "%s&%04d", sBackup, iTemplateNum);
		}

		int iCounterEnt = FindEntityByTargetname(INVALID_ENT_REFERENCE, sCounter, "math_counter");
		if (iCounterEnt == INVALID_ENT_REFERENCE)
			return false;

		// "backup" is optional
		int iBackupEnt = INVALID_ENT_REFERENCE;
		if (sBackup[0])
		{
			iBackupEnt = FindEntityByTargetname(INVALID_ENT_REFERENCE, sBackup, "math_counter");
			if (iBackupEnt == INVALID_ENT_REFERENCE)
				return false;
		}

		Boss.iIteratorEnt = iIteratorEnt;
		Boss.iCounterEnt = iCounterEnt;
		Boss.iBackupEnt = iBackupEnt;

		Config.bIteratorReverse = IsCounterReverse(iIteratorEnt);
		Config.bCounterReverse = IsCounterReverse(iCounterEnt);
	}

	_Boss.bActive = true;

	if (iTemplateNum != -1)
	{
		_Boss.iTemplateNum = iTemplateNum;
		Triggers_HookTemplate(_Config, iTemplateNum);
	}

	if (g_cvVerboseLog.IntValue > 0)
	{
		char sBoss[64];
		_Config.GetName(sBoss, sizeof(sBoss));
		LogMessage("Initialized boss %s (template = %d)", sBoss, iTemplateNum);
	}

	Hits_OnBossInitialized(_Boss);
	HUD_OnBossInitialized(_Boss);
	CreateForward_OnBossInitialized(_Boss);

	return true;
}

// ########  ########   #######   ######  ########  ######   ######
// ##     ## ##     ## ##     ## ##    ## ##       ##    ## ##    ##
// ##     ## ##     ## ##     ## ##       ##       ##       ##
// ########  ########  ##     ## ##       ######    ######   ######
// ##        ##   ##   ##     ## ##       ##             ##       ##
// ##        ##    ##  ##     ## ##    ## ##       ##    ## ##    ##
// ##        ##     ##  #######   ######  ######## ######   ######

// Updates the health of the boss, returns false when it is dead or its entities are gone
bool BossProcess(CBoss _Boss)
{
	CConfig _Config = _Boss.dConfig;

	bool bInvalid = false;
	int iHealth = 0;
	int iLastHealth = _Boss.iHealth;

	if (_Boss.IsBreakable)
	{
		CBossBreakable Boss = view_as<CBossBreakable>(_Boss);
		CConfigBreakable Config = view_as<CConfigBreakable>(_Config);

		int iBreakableEnt = Boss.iBreakableEnt;

		if (IsValidEntity(iBreakableEnt))
		{
			char sScriptHealth[64];
			Config.GetScriptHealth(sScriptHealth, sizeof(sScriptHealth));
			if (sScriptHealth[0])
				SyncScriptHealth(iBreakableEnt, sScriptHealth);

			iHealth = GetEntProp(iBreakableEnt, Prop_Data, "m_iHealth");
		}
		else
			bInvalid = true;
	}
	else if (_Boss.IsCounter)
	{
		CBossCounter Boss = view_as<CBossCounter>(_Boss);
		CConfigCounter Config = view_as<CConfigCounter>(_Config);

		int iCounterEnt = Boss.iCounterEnt;

		if (IsValidEntity(iCounterEnt))
			iHealth = GetCounterHealth(iCounterEnt, Config.bCounterReverse);
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

		bool bHasBackup = iBackupEnt != INVALID_ENT_REFERENCE;

		if (IsValidEntity(iIteratorEnt) && IsValidEntity(iCounterEnt) && (!bHasBackup || IsValidEntity(iBackupEnt)))
		{
			int iIteratorVal = RoundFloat(GetOutputValueFloat(iIteratorEnt, "m_OutValue"));
			int iCounterHealth = GetCounterHealth(iCounterEnt, Config.bCounterReverse);

			int iBackupVal;
			if (bHasBackup)
				iBackupVal = RoundFloat(GetOutputValueFloat(iBackupEnt, "m_OutValue"));
			else
			{
				// No backup configured: the map refills the counter on each iterator step,
				// so a step is worth the highest counter health seen during the current step.
				// Until the refill is seen, keep the value of the previous step.
				if (iIteratorVal != Boss.iStepIterator)
				{
					Boss.iStepIterator = iIteratorVal;
					Boss.iStepMax = 0;
				}

				if (iCounterHealth > Boss.iStepMax)
				{
					Boss.iStepMax = iCounterHealth;
					Boss.iStepValue = iCounterHealth;
				}

				iBackupVal = Boss.iStepValue;
			}

			// Remaining iterator steps, the current one is the counter
			iHealth = (GetCounterHealth(iIteratorEnt, Config.bIteratorReverse) - 1) * iBackupVal;
			iHealth += iCounterHealth;
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
		_Boss.fLastChange = GetGameTime();

	// Boss hasn't initialized HP yet.
	if (iHealth == 0 && iLastHealth == 0)
	{
		// Boss invalid: Delete boss
		if (bInvalid)
			return false;

		return true;
	}

	// Raise the base health when the boss heals above it, so the percentage stays within 100
	if (iLastHealth == 0 || iHealth > _Boss.iBaseHealth)
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

// Copy a VScript variable from the entity's script scope into its m_iHealth
void SyncScriptHealth(int entity, const char[] sVariable)
{
	char sCode[256];
	FormatEx(sCode, sizeof(sCode), "if (\"%s\" in this) self.SetHealth(%s.tointeger());", sVariable, sVariable);

	SetVariantString(sCode);
	AcceptEntityInput(entity, "RunScriptCode");
}
