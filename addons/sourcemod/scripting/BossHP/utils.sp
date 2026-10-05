// Helpers shared by every module

bool IsValidClient(int client, bool bNoBots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return false;

	return !bNoBots || !IsFakeClient(client);
}

// For the commands that need a player, the server console gets an error instead
bool IsInGameCommand(int client)
{
	if (client)
		return true;

	ReplyToCommand(client, CONSOLE_PREFIX ... "This command can only be used in-game.");
	return false;
}

// Finds the next entity by targetname, by HammerID ("#1234") or by targetname prefix ("name*")
int FindEntityByTargetname(int entity, const char[] sTargetname, const char[] sClassname = "*")
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

// Removes the "&0001" suffix that point_template adds with name fixup, and returns its number (-1 without suffix)
int SplitTemplateName(char[] sTargetname)
{
	int iTemplateLoc = FindCharInString(sTargetname, '&', true);
	if (iTemplateLoc == -1)
		return -1;

	int iTemplateNum = StringToInt(sTargetname[iTemplateLoc + 1]);
	sTargetname[iTemplateLoc] = '\0';
	return iTemplateNum;
}

// ##     ##    ###    ######## ##     ##     ######   #######  ##     ## ##    ## ######## ######## ########
// ###   ###   ## ##      ##    ##     ##    ##    ## ##     ## ##     ## ###   ##    ##    ##       ##     ##
// #### ####  ##   ##     ##    ##     ##    ##       ##     ## ##     ## ####  ##    ##    ##       ##     ##
// ## ### ## ##     ##    ##    #########    ##       ##     ## ##     ## ## ## ##    ##    ######   ########
// ##     ## #########    ##    ##     ##    ##       ##     ## ##     ## ##  ####    ##    ##       ##   ##
// ##     ## ##     ##    ##    ##     ##    ##    ## ##     ## ##     ## ##   ###    ##    ##       ##    ##
// ##     ## ##     ##    ##    ##     ##     ######   #######   #######  ##    ##    ##    ######## ##     ##

// The counter counts up to its max when more outputs are bound to OnHitMax than to OnHitMin
bool IsCounterReverse(int entity)
{
	return GetOutputCount(entity, "m_OnHitMax") > GetOutputCount(entity, "m_OnHitMin");
}

// Health of a math_counter: distance from its value to the limit it counts towards
int GetCounterHealth(int entity, bool bReverse)
{
	int iValue = RoundFloat(GetOutputValueFloat(entity, "m_OutValue"));

	if (bReverse)
		return RoundFloat(GetEntPropFloat(entity, Prop_Data, "m_flMax")) - iValue;

	return iValue - RoundFloat(GetEntPropFloat(entity, Prop_Data, "m_flMin"));
}

//  ######  ######## ########  #### ##    ##  ######    ######
// ##    ##    ##    ##     ##  ##  ###   ## ##    ##  ##    ##
// ##          ##    ##     ##  ##  ####  ## ##        ##
//  ######     ##    ########   ##  ## ## ## ##   ####  ######
//       ##    ##    ##   ##    ##  ##  #### ##    ##        ##
// ##    ##    ##    ##    ##   ##  ##   ### ##    ##  ##    ##
//  ######     ##    ##     ## #### ##    ##  ######    ######

void AppendLine(char[] sText, int iMaxLen, const char[] sLine)
{
	if (sText[0])
		StrCat(sText, iMaxLen, "\n");
	StrCat(sText, iMaxLen, sLine);
}

void StringToPosition(const char[] sValue, float fPosition[2])
{
	char sParts[2][16];
	ExplodeString(sValue, " ", sParts, sizeof(sParts), sizeof(sParts[]));

	fPosition[0] = StringToFloat(sParts[0]);
	fPosition[1] = StringToFloat(sParts[1]);
}

void StringToColor(const char[] sValue, int iColor[3])
{
	char sParts[3][8];
	ExplodeString(sValue, " ", sParts, sizeof(sParts), sizeof(sParts[]));

	for (int i = 0; i < 3; i++)
		iColor[i] = StringToInt(sParts[i]);
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
