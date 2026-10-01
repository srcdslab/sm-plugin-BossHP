/**
 * This is the include file for BossHP
 * To check that BossHP is installed and running, verify that the "BossHP" library exists
 */

#if defined _BossHUD_included
	#endinput
#endif
#define _BossHUD_included

#include "CEntity.inc"

enum DisplayType {
	DISPLAY_CENTER = 0,
	DISPLAY_GAME = 1,
	DISPLAY_HINT = 2
}

/**
 * Gets the current health of a boss
 *
 * @param bossEnt    Entity index of the boss
 * @return           Current health of the boss, -1 if invalid
 */
native int BossHUD_GetBossHealth(int bossEnt);

/**
 * Gets the maximum health of a boss
 *
 * @param bossEnt    Entity index of the boss
 * @return           Maximum health of the boss, -1 if invalid
 */
native int BossHUD_GetBossMaxHealth(int bossEnt);

/**
 * Gets the total number of hits on a boss
 *
 * @param bossEnt    Entity index of the boss
 * @return           Total number of hits, -1 if invalid
 */
native int BossHUD_GetBossHits(int bossEnt);

/**
 * Gets the top hits on a boss
 *
 * @param bossEnt    Entity index of the boss
 * @param maxPlayers Maximum number of players to return
 * @param topHits    Array to store the top hits (client indices)
 * @return           Number of players who hit the boss
 */
native int BossHUD_GetBossTopHits(int bossEnt, int maxPlayers, int[] topHits);

/**
 * Checks if a boss is active
 *
 * @param bossEnt    Entity index of the boss
 * @return           1 if active, 0 if not
 */
native int BossHUD_IsBossActive(int bossEnt);

/**
 * Gets the name of a boss
 *
 * @param bossEnt    Entity index of the boss
 * @param buffer     Buffer to store the name
 * @param maxlen     Maximum length of the buffer
 * @return           1 if successful, 0 if invalid
 */
native int BossHUD_GetBossName(int bossEnt, char[] buffer, int maxlen);

/**
 * Gets the total number of players who hit the boss
 *
 * @param bossEnt    Entity index of the boss
 * @return           Number of players who hit the boss, -1 if invalid
 */
native int BossHUD_GetBossHitsCount(int bossEnt);

/**
 * Gets the number of hits from a specific player on a boss
 *
 * @param bossEnt    Entity index of the boss
 * @param client     Client index
 * @return           Number of hits from the player, -1 if invalid
 */
native int BossHUD_GetBossHitsByClient(int bossEnt, int client);

/**
 * Gets the rank of a player in boss hits
 *
 * @param bossEnt    Entity index of the boss
 * @param client     Client index
 * @return           Rank of the player (1-based), -1 if invalid
 */
native int BossHUD_GetBossHitsRank(int bossEnt, int client);

public SharedPlugin __pl_BossHUD = 
{
	name = "BossHUD",
	file = "BossHUD.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};


#if !defined REQUIRE_PLUGIN
public void __pl_BossHUD_SetNTVOptional()
{
	MarkNativeAsOptional("BossHUD_GetBossHealth");
	MarkNativeAsOptional("BossHUD_GetBossMaxHealth");
	MarkNativeAsOptional("BossHUD_GetBossHits");
	MarkNativeAsOptional("BossHUD_GetBossTopHits");
	MarkNativeAsOptional("BossHUD_IsBossActive");
	MarkNativeAsOptional("BossHUD_GetBossName");
	MarkNativeAsOptional("BossHUD_GetBossHitsCount");
	MarkNativeAsOptional("BossHUD_GetBossHitsByClient");
	MarkNativeAsOptional("BossHUD_GetBossHitsRank");
}
#endif
