/**
 * This is the include file for BossHP
 * To check that BossHP is installed and running, verify that the "BossHP" library exists
 */

#if defined _BossHP_included
	#endinput
#endif
#define _BossHP_included

// Version information
#define BossHP_V_MAJOR   "2"
#define BossHP_V_MINOR   "0"
#define BossHP_V_PATCH   "0"

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
 * Called when a boss "hurttrigger" fires (entity output or OnTakeDamage).
 *
 * @param boss        CBoss object.
 * @param config      CConfig object of the boss.
 * @param activator   Client/entity that caused the damage (may be 0 or invalid).
 * @param damage      Damage dealt (1.0 for entity outputs, actual damage for OnTakeDamage).
 * @noreturn
 */
forward void BossHP_OnBossDamaged(CBoss boss, CConfig config, int activator, float damage);

/**
 * Check if the given entity is boss entity index
 *
 * @param entity     Any valid entity index.
 * @param boss       Optional param which refer to current boss.
 * @return           True if entity is boss or false otherwise.
 */
native bool BossHP_IsBossEnt(int entity, CBoss &boss = view_as<CBoss>(INVALID_HANDLE));

/**
 * Gets the current health of a boss
 *
 * @param bossEnt    Any entity of the boss.
 * @return           Current health of the boss, -1 if not a boss.
 */
native int BossHP_GetBossHealth(int bossEnt);

/**
 * Gets the maximum health of a boss
 *
 * @param bossEnt    Any entity of the boss.
 * @return           Maximum health of the boss, -1 if not a boss.
 */
native int BossHP_GetBossMaxHealth(int bossEnt);

/**
 * Gets the name of a boss
 *
 * @param bossEnt    Any entity of the boss.
 * @param buffer     Buffer to store the name.
 * @param maxlen     Maximum length of the buffer.
 * @return           True on success, false if not a boss.
 */
native bool BossHP_GetBossName(int bossEnt, char[] buffer, int maxlen);

/**
 * Gets the total number of hits (or damage for breakable bosses) on a boss
 *
 * @param bossEnt    Any entity of the boss.
 * @return           Total number of hits, -1 if not a boss.
 */
native int BossHP_GetBossHits(int bossEnt);

/**
 * Gets the number of players who hit a boss
 *
 * @param bossEnt    Any entity of the boss.
 * @return           Number of players who hit the boss, -1 if not a boss.
 */
native int BossHP_GetBossHitsCount(int bossEnt);

/**
 * Gets the number of hits (or damage for breakable bosses) from a player on a boss
 *
 * @param bossEnt    Any entity of the boss.
 * @param client     Client index.
 * @return           Number of hits from the player, -1 if not a boss or invalid client.
 */
native int BossHP_GetBossHitsByClient(int bossEnt, int client);

/**
 * Gets the rank of a player in the hits of a boss
 *
 * @param bossEnt    Any entity of the boss.
 * @param client     Client index.
 * @return           Rank of the player (1-based), -1 if not a boss or invalid client.
 */
native int BossHP_GetBossHitsRank(int bossEnt, int client);

/**
 * Gets the players with the most hits on a boss
 *
 * @param bossEnt    Any entity of the boss.
 * @param maxPlayers Maximum number of players to return.
 * @param topHits    Array to store the client indices, best first.
 * @return           Number of players who hit the boss, -1 if not a boss.
 */
native int BossHP_GetBossTopHits(int bossEnt, int maxPlayers, int[] topHits);

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
	MarkNativeAsOptional("BossHP_GetBossHealth");
	MarkNativeAsOptional("BossHP_GetBossMaxHealth");
	MarkNativeAsOptional("BossHP_GetBossName");
	MarkNativeAsOptional("BossHP_GetBossHits");
	MarkNativeAsOptional("BossHP_GetBossHitsCount");
	MarkNativeAsOptional("BossHP_GetBossHitsByClient");
	MarkNativeAsOptional("BossHP_GetBossHitsRank");
	MarkNativeAsOptional("BossHP_GetBossTopHits");
}
#endif
