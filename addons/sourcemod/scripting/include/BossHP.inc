/**
 * This is the include file for BossHP
 * To check that BossHP is installed and running, verify that the "BossHP" library exists
 */

#if defined _BossHP_included
	#endinput
#endif
#define _BossHP_included

// Version information
#define BossHP_V_MAJOR   "1"
#define BossHP_V_MINOR   "4"
#define BossHP_V_PATCH   "3"

#define BossHP_VERSION   BossHP_V_MAJOR..."."...BossHP_V_MINOR..."."...BossHP_V_PATCH

#include "CConfig.inc"
#include "CBoss.inc"

/**
 * Called before all boss processing.
 *
 * @param aBoss     ArrayList of CBoss.
 * @noreturn
 */
forward void BossHP_OnAllBossProcessStart(ArrayList aBoss);

/**
 * Called after all boss processing.
 *
 * @param aBoss     ArrayList of CBoss.
 * @noreturn
 */
forward void BossHP_OnAllBossProcessEnd(ArrayList aBoss);

/**
 * Called after boss initialization.
 *
 * @param boss      CBoss object.
 * @noreturn
 */
forward void BossHP_OnBossInitialized(CBoss boss);

/**
 * Called after boss processing.
 *
 * @param boss                CBoss object.
 * @param bHealthChanged      Has boss health changed.
 * @param bShow               Can you show boss hp.
 * @noreturn
 */
forward void BossHP_OnBossProcessed(CBoss boss, bool bHealthChanged, bool bShow);

/**
 * Called after boss dies.
 *
 * @param boss      CBoss object.
 * @noreturn
 */
forward void BossHP_OnBossDead(CBoss boss);

/**
 * Check if the given entity is boss entity index
 *
 * @param entity     Any valid entity index.
 * @param boss       Optional param which refer to current boss.
 * @return           True if entity is boss or false otherwise.
 */
native bool BossHP_IsBossEnt(int entity, CBoss &boss = view_as<CBoss>(INVALID_HANDLE));

public SharedPlugin __pl_BossHP = 
{
	name = "BossHP",
	file = "BossHP.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_BossHP_SetNTVOptional()
{
	MarkNativeAsOptional("BossHP_IsBossEnt");
}
#endif
