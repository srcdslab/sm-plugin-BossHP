// Boss triggers: "trigger" creates the boss, "showtrigger" shows it, "killtrigger" removes it and
// "hurttrigger" reports the damage dealt to it. They are all "<entity>:<output>" pairs, matched by
// targetname or HammerID ("#1234"), where the output can also be "OnTakeDamage".

enum BossTrigger
{
	BossTrigger_Spawn = 0,
	BossTrigger_Show,
	BossTrigger_Kill,
	BossTrigger_Hurt,

	BossTrigger_Count
}

// Config keys of the triggers
char g_sTriggerKeys[BossTrigger_Count][] = { "trigger", "showtrigger", "killtrigger", "hurttrigger" };

// Returns false when the trigger is not set in the config
bool GetConfigTrigger(CConfig Config, BossTrigger iType, char[] sTrigger, int iTriggerLen, char[] sOutput, int iOutputLen)
{
	switch (iType)
	{
		case BossTrigger_Spawn: { Config.GetTrigger(sTrigger, iTriggerLen); Config.GetOutput(sOutput, iOutputLen); }
		case BossTrigger_Show: { Config.GetShowTrigger(sTrigger, iTriggerLen); Config.GetShowOutput(sOutput, iOutputLen); }
		case BossTrigger_Kill: { Config.GetKillTrigger(sTrigger, iTriggerLen); Config.GetKillOutput(sOutput, iOutputLen); }
		case BossTrigger_Hurt: { Config.GetHurtTrigger(sTrigger, iTriggerLen); Config.GetHurtOutput(sOutput, iOutputLen); }
	}

	return sTrigger[0] != '\0';
}

void SetConfigTrigger(CConfig Config, BossTrigger iType, const char[] sTrigger, const char[] sOutput, float fDelay)
{
	switch (iType)
	{
		case BossTrigger_Spawn: { Config.SetTrigger(sTrigger); Config.SetOutput(sOutput); Config.fTriggerDelay = fDelay; }
		case BossTrigger_Show: { Config.SetShowTrigger(sTrigger); Config.SetShowOutput(sOutput); Config.fShowTriggerDelay = fDelay; }
		case BossTrigger_Kill: { Config.SetKillTrigger(sTrigger); Config.SetKillOutput(sOutput); Config.fKillTriggerDelay = fDelay; }
		case BossTrigger_Hurt: { Config.SetHurtTrigger(sTrigger); Config.SetHurtOutput(sOutput); }
	}
}

bool HasConfigTrigger(CConfig Config, BossTrigger iType)
{
	char sTrigger[64], sOutput[64];
	return GetConfigTrigger(Config, iType, sTrigger, sizeof(sTrigger), sOutput, sizeof(sOutput));
}

bool MatchTrigger(const char[] sTrigger, const char[] sTargetname, int iHammerID)
{
	if (sTrigger[0] == '#')
		return StringToInt(sTrigger[1]) == iHammerID;

	return sTargetname[0] && strcmp(sTargetname, sTrigger, false) == 0;
}

// ##     ##  #######   #######  ##    ##  ######
// ##     ## ##     ## ##     ## ##   ##  ##    ##
// ##     ## ##     ## ##     ## ##  ##   ##
// ######### ##     ## ##     ## #####     ######
// ##     ## ##     ## ##     ## ##  ##         ##
// ##     ## ##     ## ##     ## ##   ##  ##    ##
// ##     ##  #######   #######  ##    ##  ######

void HookTrigger(int entity, BossTrigger iType, const char[] sOutput, bool bOnce)
{
	if (strcmp(sOutput, "OnTakeDamage", false) == 0)
	{
		switch (iType)
		{
			case BossTrigger_Spawn: SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostSpawn);
			case BossTrigger_Show: SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostShow);
			case BossTrigger_Kill: SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostKill);
			case BossTrigger_Hurt: SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostHurt);
		}
		return;
	}

	switch (iType)
	{
		case BossTrigger_Spawn: HookSingleEntityOutput(entity, sOutput, OnEntityOutputSpawn, bOnce);
		case BossTrigger_Show: HookSingleEntityOutput(entity, sOutput, OnEntityOutputShow, bOnce);
		case BossTrigger_Kill: HookSingleEntityOutput(entity, sOutput, OnEntityOutputKill, bOnce);
		case BossTrigger_Hurt: HookSingleEntityOutput(entity, sOutput, OnEntityOutputHurt, bOnce);
	}
}

// Single-use triggers only fire once, entity outputs are unhooked by HookSingleEntityOutput itself
void UnhookTriggerDamage(int entity, BossTrigger iType)
{
	switch (iType)
	{
		case BossTrigger_Spawn: SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostSpawn);
		case BossTrigger_Show: SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostShow);
		case BossTrigger_Kill: SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostKill);
		case BossTrigger_Hurt: SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePostHurt);
	}
}

// Hooks the triggers of every config that targets this entity
void Triggers_OnEntitySpawned(int entity)
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

		for (BossTrigger iType = BossTrigger_Spawn; iType < BossTrigger_Count; iType++)
		{
			char sTrigger[64], sOutput[64];
			if (!GetConfigTrigger(Config, iType, sTrigger, sizeof(sTrigger), sOutput, sizeof(sOutput)))
				continue;

			if (!MatchTrigger(sTrigger, sTargetname, iHammerID))
				continue;

			// A hurttrigger reports every hit
			HookTrigger(entity, iType, sOutput, iType != BossTrigger_Hurt && !Config.bMultiTrigger);

			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Hooked %s %s:%s", g_sTriggerKeys[iType], sTrigger, sOutput);
		}
	}
}

// Hooks the show, kill and hurt triggers spawned with the same template as the boss ("<trigger>&0001")
void Triggers_HookTemplate(CConfig Config, int iTemplateNum)
{
	for (BossTrigger iType = BossTrigger_Show; iType < BossTrigger_Count; iType++)
	{
		char sTrigger[64], sOutput[64];
		if (!GetConfigTrigger(Config, iType, sTrigger, sizeof(sTrigger), sOutput, sizeof(sOutput)))
			continue;

		Format(sTrigger, sizeof(sTrigger), "%s&%04d", sTrigger, iTemplateNum);

		int entity = INVALID_ENT_REFERENCE;
		while ((entity = FindEntityByTargetname(entity, sTrigger)) != INVALID_ENT_REFERENCE)
		{
			HookTrigger(entity, iType, sOutput, iType != BossTrigger_Hurt);

			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Hooked %s %s:%s", g_sTriggerKeys[iType], sTrigger, sOutput);
		}
	}
}

public void OnEntityOutputSpawn(const char[] output, int caller, int activator, float delay)
{
	OnTriggerFired(BossTrigger_Spawn, caller, output, activator);
}

public void OnEntityOutputShow(const char[] output, int caller, int activator, float delay)
{
	OnTriggerFired(BossTrigger_Show, caller, output, activator);
}

public void OnEntityOutputKill(const char[] output, int caller, int activator, float delay)
{
	OnTriggerFired(BossTrigger_Kill, caller, output, activator);
}

public void OnEntityOutputHurt(const char[] output, int caller, int activator, float delay)
{
	OnTriggerFired(BossTrigger_Hurt, caller, output, activator);
}

public void OnTakeDamagePostSpawn(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnTriggerFired(BossTrigger_Spawn, victim, "OnTakeDamage", attacker, damage, true);
}

public void OnTakeDamagePostShow(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnTriggerFired(BossTrigger_Show, victim, "OnTakeDamage", attacker, damage, true);
}

public void OnTakeDamagePostKill(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnTriggerFired(BossTrigger_Kill, victim, "OnTakeDamage", attacker, damage, true);
}

public void OnTakeDamagePostHurt(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	OnTriggerFired(BossTrigger_Hurt, victim, "OnTakeDamage", attacker, damage, true);
}

// A point_template spawned by an env_entity_maker fires the "OnEntitySpawned" trigger of the template
public void OnEnvEntityMakerEntitySpawned(const char[] output, int caller, int activator, float delay)
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

	OnTriggerFired(BossTrigger_Spawn, iPointTemplate, "OnEntitySpawned", caller);
}

// ######## #### ########  ########
// ##        ##  ##     ## ##
// ##        ##  ##     ## ##
// ######    ##  ########  ######
// ##        ##  ##   ##   ##
// ##        ##  ##    ##  ##
// ##       #### ##     ## ########

void OnTriggerFired(BossTrigger iType, int entity, const char[] output, int activator, float fDamage = 1.0, bool bTakeDamage = false)
{
	if (!g_aConfig || !g_aBoss || !IsValidEntity(entity))
		return;

	char sTargetname[64];
	GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	int iHammerID = GetEntProp(entity, Prop_Data, "m_iHammerID");

	if (g_cvVerboseLog.IntValue > 1)
		LogMessage("OnTriggerFired(%s, %d:\"%s\":#%d, \"%s\")", g_sTriggerKeys[iType], entity, sTargetname, iHammerID, output);

	// The boss is created by the trigger entity itself, the other triggers target the boss spawned with the same template
	int iTemplateNum = -1;
	if (iType != BossTrigger_Spawn)
		iTemplateNum = SplitTemplateName(sTargetname);

	for (int i = 0; i < g_aConfig.Length; i++)
	{
		CConfig Config = g_aConfig.Get(i);

		char sTrigger[64], sOutput[64];
		if (!GetConfigTrigger(Config, iType, sTrigger, sizeof(sTrigger), sOutput, sizeof(sOutput)))
			continue;

		if (!MatchTrigger(sTrigger, sTargetname, iHammerID) || strcmp(output, sOutput, false) != 0)
			continue;

		switch (iType)
		{
			case BossTrigger_Spawn: OnSpawnTrigger(i, Config, entity, sTrigger, output, bTakeDamage);
			case BossTrigger_Show: OnShowTrigger(Config, entity, iTemplateNum, sTrigger, output, bTakeDamage);
			case BossTrigger_Kill: OnKillTrigger(Config, entity, iTemplateNum, sTrigger, output, bTakeDamage);
			case BossTrigger_Hurt: OnHurtTrigger(Config, iTemplateNum, output, activator, fDamage);
		}
	}
}

void OnSpawnTrigger(int iConfig, CConfig Config, int entity, const char[] sTrigger, const char[] output, bool bTakeDamage)
{
	bool bOnce = !Config.bMultiTrigger;

	char sConfig[8];
	IntToString(iConfig, sConfig, sizeof(sConfig));

	if (bOnce)
	{
		bool bHadOnce = false;
		if (g_aHadOnce.GetValue(sConfig, bHadOnce) && bHadOnce)
			return;

		if (bTakeDamage)
			UnhookTriggerDamage(entity, BossTrigger_Spawn);
	}

	if (BossAdd(Config, entity) == INVALID_HANDLE)
		return;

	if (bOnce)
		g_aHadOnce.SetValue(sConfig, true);

	if (g_cvVerboseLog.IntValue > 0)
		LogMessage("Triggered boss %s(%d) from output %s", sTrigger, entity, output);
}

void OnShowTrigger(CConfig Config, int entity, int iTemplateNum, const char[] sTrigger, const char[] output, bool bTakeDamage)
{
	if (g_cvVerboseLog.IntValue > 0)
		LogMessage("Triggered show boss %s(%d) from output %s", sTrigger, entity, output);

	if (bTakeDamage && !Config.bMultiTrigger)
		UnhookTriggerDamage(entity, BossTrigger_Show);

	float fDelay = Config.fShowTriggerDelay;

	for (int i = 0; i < g_aBoss.Length; i++)
	{
		CBoss Boss = g_aBoss.Get(i);
		if (Boss.dConfig != Config || Boss.iTemplateNum != iTemplateNum)
			continue;

		if (fDelay > 0)
		{
			Boss.fShowAt = GetGameTime() + fDelay;
			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Scheduled show(%f) boss %d", fDelay, i);
		}
		else
		{
			Boss.bShow = true;
			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Showing boss %d", i);
		}
	}
}

void OnKillTrigger(CConfig Config, int entity, int iTemplateNum, const char[] sTrigger, const char[] output, bool bTakeDamage)
{
	if (g_cvVerboseLog.IntValue > 0)
		LogMessage("Triggered kill boss %s(%d) from output %s", sTrigger, entity, output);

	if (bTakeDamage && !Config.bMultiTrigger)
		UnhookTriggerDamage(entity, BossTrigger_Kill);

	float fDelay = Config.fKillTriggerDelay;

	for (int i = 0; i < g_aBoss.Length; i++)
	{
		CBoss Boss = g_aBoss.Get(i);
		if (Boss.dConfig != Config || Boss.iTemplateNum != iTemplateNum)
			continue;

		if (fDelay > 0)
		{
			Boss.fKillAt = GetGameTime() + fDelay;
			if (g_cvVerboseLog.IntValue > 0)
				LogMessage("Scheduled kill(%f) boss %d", fDelay, i);
		}
		else
		{
			BossRemove(i--, "killtrigger", false);
		}
	}
}

void OnHurtTrigger(CConfig Config, int iTemplateNum, const char[] output, int activator, float fDamage)
{
	for (int i = 0; i < g_aBoss.Length; i++)
	{
		CBoss Boss = g_aBoss.Get(i);
		if (Boss.dConfig != Config || Boss.iTemplateNum != iTemplateNum)
			continue;

		if (g_cvVerboseLog.IntValue > 1)
			LogMessage("Triggered hurt boss %d from output %s (damage = %f)", i, output, fDamage);

		Hits_OnBossHurt(Boss, activator, fDamage);
		CreateForward_OnBossDamaged(Boss, Config, activator, fDamage);
	}
}
