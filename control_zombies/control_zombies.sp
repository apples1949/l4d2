#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>

#define DEBUG 			1
#define BENCHMARK		0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

#define PLUGIN_NAME				"Control Zombies In Co-op"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"3.5.1"
#define PLUGIN_URL				"https://steamcommunity.com/id/sorallll"

/*****************************************************************************************************/
// ====================================================================================================
// colors.inc
// ====================================================================================================
#define SERVER_INDEX 0
#define NO_INDEX 	-1
#define NO_PLAYER 	-2
#define BLUE_INDEX 	 2
#define RED_INDEX 	 3
#define MAX_COLORS 	 6
#define MAX_MESSAGE_LENGTH 254
static const char CTag[][] = {"{default}", "{green}", "{lightgreen}", "{red}", "{blue}", "{olive}"};
static const char CTagCode[][] = {"\x01", "\x04", "\x03", "\x03", "\x03", "\x05"};
static const bool CTagReqSayText2[] = {false, false, true, true, true, false};
static const int CProfile_TeamIndex[] = {NO_INDEX, NO_INDEX, SERVER_INDEX, RED_INDEX, BLUE_INDEX, NO_INDEX};

/**
 * @note Prints a message to a specific client in the chat area.
 * @note Supports color tags.
 *
 * @param client	Client index.
 * @param szMessage	Message (formatting rules).
 * @return			No return
 * 
 * On error/Errors:	If the client is not connected an error will be thrown.
 */
stock void CPrintToChat(int client, const char[] szMessage, any ...) {
	if (client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if (!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	char szCMessage[MAX_MESSAGE_LENGTH];

	SetGlobalTransTarget(client);
	FormatEx(szBuffer, sizeof szBuffer, "\x01%s", szMessage);
	VFormat(szCMessage, sizeof szCMessage, szBuffer, 3);
	
	int index = CFormat(szCMessage, sizeof szCMessage);
	if (index == NO_INDEX)
		PrintToChat(client, "%s", szCMessage);
	else
		CSayText2(client, index, szCMessage);
}

/**
 * @note Prints a message to all clients in the chat area.
 * @note Supports color tags.
 *
 * @param client	Client index.
 * @param szMessage	Message (formatting rules)
 * @return			No return
 */
stock void CPrintToChatAll(const char[] szMessage, any ...) {
	char szBuffer[MAX_MESSAGE_LENGTH];

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			SetGlobalTransTarget(i);
			VFormat(szBuffer, sizeof szBuffer, szMessage, 2);
			CPrintToChat(i, "%s", szBuffer);
		}
	}
}

/**
 * @note Replaces color tags in a string with color codes
 *
 * @param szMessage	String.
 * @param maxlength	Maximum length of the string buffer.
 * @return			Client index that can be used for SayText2 author index
 * 
 * On error/Errors:	If there is more then one team color is used an error will be thrown.
 */
stock int CFormat(char[] szMessage, int maxlength) {	
	int iRandomPlayer = NO_INDEX;
	
	for (int i; i < MAX_COLORS; i++) {													//	Para otras etiquetas de color se requiere un bucle.
		if (StrContains(szMessage, CTag[i], false) == -1)								//	Si no se encuentra la etiqueta, omitir.
			continue;
		else if (!CTagReqSayText2[i])
			ReplaceString(szMessage, maxlength, CTag[i], CTagCode[i], false);			//	Si la etiqueta no necesita Saytext2 simplemente reemplazará.
		else {																			//	La etiqueta necesita Saytext2.	
			if (iRandomPlayer == NO_INDEX) {											//	Si no se especificó un cliente aleatorio para la etiqueta, reemplaca la etiqueta y busca un cliente para la etiqueta.
				iRandomPlayer = CFindRandomPlayerByTeam(CProfile_TeamIndex[i]);			//	Busca un cliente válido para la etiqueta, equipo de infectados oh supervivientes.
				if (iRandomPlayer == NO_PLAYER)
					ReplaceString(szMessage, maxlength, CTag[i], CTagCode[5], false);	//	Si no se encuentra un cliente valido, reemplasa la etiqueta con una etiqueta de color verde.
				else 
					ReplaceString(szMessage, maxlength, CTag[i], CTagCode[i], false);	// 	Si el cliente fue encontrado simplemente reemplasa.
			}
			else																		//	Si en caso de usar dos colores de equipo infectado y equipo de superviviente juntos se mandará un mensaje de error.
				ThrowError("Using two team colors in one message is not allowed");		//	Si se ha usadó una combinación de colores no validad se registrara en la carpeta logs.
		}
	}

	return iRandomPlayer;
}

/**
 * @note Founds a random player with specified team
 *
 * @param color_team	Client team.
 * @return				Client index or NO_PLAYER if no player found
 */
stock int CFindRandomPlayerByTeam(int color_team) {
	if (color_team == SERVER_INDEX)
		return 0;
	else {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && GetClientTeam(i) == color_team)
				return i;
		}
	}

	return NO_PLAYER;
}

/**
 * @note Sends a SayText2 usermessage to a client
 *
 * @param szMessage	Client index
 * @param maxlength	Author index
 * @param szMessage	Message
 * @return			No return.
 */
stock void CSayText2(int client, int author, const char[] szMessage) {
	BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	bf.WriteByte(author);
	bf.WriteByte(true);
	bf.WriteString(szMessage);
	EndMessage();
}
/*****************************************************************************************************/
#define GAMEDATA 			"control_zombies"
#define CVAR_FLAGS 			FCVAR_NOTIFY
#define SOUND_CLASSMENU		"ui/helpful_event_1.wav"

#define COLOR_NORMAL		0
#define COLOR_INCAPA		1
#define COLOR_BLACKW		2
#define COLOR_VOMITED		3

#define SI_SMOKER			0
#define SI_BOOMER			1
#define SI_HUNTER			2
#define SI_SPITTER			3
#define SI_JOCKEY			4
#define SI_CHARGER			5

esData
	g_esData[MAXPLAYERS + 1];

Handle
	g_hTimer,
	g_hSDK_CTerrorPlayer_OnRevived,
	g_hSDK_CBaseEntity_IsInStasis,
	g_hSDK_Tank_LeaveStasis,
	g_hSDK_CCSPlayer_State_Transition,
	g_hSDK_CTerrorPlayer_MaterializeFromGhost,
	g_hSDK_CTerrorPlayer_SetClass,
	g_hSDK_CBaseAbility_CreateForPlayer,
	g_hSDK_CTerrorPlayer_CleanupPlayerState,
	g_hSDK_CTerrorPlayer_TakeOverZombieBot,
	g_hSDK_CTerrorPlayer_ReplaceWithBot,
	g_hSDK_CTerrorPlayer_SetPreSpawnClass,
	g_hSDK_CTerrorPlayer_RoundRespawn,
	g_hSDK_SurvivorBot_SetHumanSpectator,
	g_hSDK_CTerrorPlayer_TakeOverBot,
	g_hSDK_CTerrorGameRules_IsMissionFinalMap,
	g_hSDK_CTerrorGameRules_HasPlayerControlledZombies;

Address
	g_pStatsCondition;

DynamicDetour
	g_ddCTerrorPlayer_OnEnterGhostState,
	g_ddCTerrorPlayer_MaterializeFromGhost,
	g_ddCTerrorPlayer_PlayerZombieAbortControl,
	g_ddForEachTerrorPlayer_SpawnablePZScan;

ConVar
	g_cvGameMode,
	g_cvMaxTankPlayer,
	g_cvMapFilterTank,
	g_cvSurvivorLimit,
	g_cvSurvivorChance,
	g_cvSbAllBotGame,
	g_cvAllowAllBotSur,
	g_cvSurvivorMaxInc,
	g_cvExchangeTeam,
	g_cvPZSuicideTime,
	g_cvPZRespawnTime,
	g_cvPZPunishTime,
	g_cvPZPunishHealth,
	g_cvAutoDisplayMenu,
	g_cvPZTeamLimit,
	g_cvCmdCooldownTime,
	g_cvCmdEnterCooling,
	g_cvLotTargetPlayer,
	g_cvPZChangeTeamTo,
	g_cvGlowColorEnable,
	g_cvGlowColor[4],
	g_cvUserFlagBits,
	g_cvImmunityLevels,
	g_cvSILimit,
	g_cvSpawnLimits[6],
	g_cvSpawnWeights[6],
	g_cvScaleWeights;

static const char
	g_sZombieClass[][] = {
		"smoker",
		"boomer",
		"hunter",
		"spitter",
		"jockey", 
		"charger"
	};

char
	g_sGameMode[32];

bool
	g_bLateLoad,
	g_bLeftSafeArea,
	g_bSbAllBotGame,
	g_bAllowAllBotSur,
	g_bExchangeTeam,
	g_bGlowColorEnable,
	g_bScaleWeights,
	g_bOnPassPlayerTank,
	g_bOnMaterializeFromGhost;

int
	g_iControlled = -1,
	g_iSILimit,
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iSpawnablePZ,
	g_iTransferTankBot,
	g_iOff_m_hHiddenWeapon,
	g_iOff_m_preHangingHealth,
	g_iOff_m_preHangingHealthBuffer,
	g_iSurvivorMaxInc,
	g_iMaxTankPlayer,
	g_iMapFilterTank,
	g_iSurvivorLimit,
	g_iPZRespawnTime,
	g_iPZSuicideTime,
	g_iPZPunishTime,
	g_iPZTeamLimit,
	g_iPZChangeTeamTo,
	g_iAutoDisplayMenu,
	g_iCmdEnterCooling,
	g_iLotTargetPlayer,
	g_iGlowColor[4],
	g_iSpawnLimits[6],
	g_iSpawnWeights[6],
	g_iUserFlagBits[7],
	g_iImmunityLevels[7];

float
	g_fPZPunishHealth,
	g_fSurvivorChance,
	g_fCmdCooldownTime;

enum struct esPlayer {
	char AuthId[32];

	bool isPlayerPB;
	bool classCmdUsed;

	int tankBot;
	int bot;
	int player;
	int lastTeamID;
	int modelIndex;
	int modelEntRef;
	int materialized;
	int enteredGhost;
	int currentRespawnTime;

	float lastUsedTime;
	float bugExploitTime[2];
	float respawnStartTime;
	float suicideStartTime;
}

esPlayer
	g_esPlayer[MAXPLAYERS + 1];

// 如果签名失效, 请到此处更新https://github.com/Psykotikism/L4D1-2_Signatures
public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

#if DEBUG
bool g_bLeft4Dhooks;
Handle g_hSDK_CTerrorPlayer_PlayerZombieAbortControl;
native any L4D_GetLastKnownArea(int client);
native any L4D_GetNearestNavArea(const float vecPos[3], float maxDist = 300.0, bool anyZ = false, bool checkLOS = false, bool checkGround = false, int teamID = 2);
public void OnLibraryAdded(const char[] name) {
	if (strcmp(name, "left4dhooks") == 0)
		g_bLeft4Dhooks = true;
}

public void OnLibraryRemoved(const char[] name) {
	if (strcmp(name, "left4dhooks") == 0)
		g_bLeft4Dhooks = false;
}
#endif

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	if (!IsDedicatedServer()) {
		strcopy(error, err_max, "插件仅支持专用服务器.");
		return APLRes_SilentFailure;
	}

	CreateNative("CZ_RespawnPZ", Native_RespawnPZ);
	CreateNative("CZ_SetSpawnablePZ", Native_SetSpawnablePZ);

	RegPluginLibrary("control_zombies");

	#if DEBUG
	MarkNativeAsOptional("L4D_GetLastKnownArea");
	MarkNativeAsOptional("L4D_GetNearestNavArea");
	#endif

	g_bLateLoad = late;
	return APLRes_Success;
}

any Native_RespawnPZ(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 3 || IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isGhost"))
		return false;

	int zombieClass = GetNativeCell(2);
	if (zombieClass < 1 || zombieClass > 8 || zombieClass == 7)
		return false;

	return RespawnPZ(client, zombieClass);
}

any Native_SetSpawnablePZ(Handle plugin, int numParams) {
	g_iSpawnablePZ = GetNativeCell(1);
	return 0;
}

public void OnPluginStart() {
	InitData();
	LoadTranslations("common.phrases");
	CreateConVar("control_zombies_version", PLUGIN_VERSION, "Control Zombies In Co-op plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cvMaxTankPlayer = 			CreateConVar("cz_max_tank_player", 					"1", 					"坦克玩家达到多少后插件将不再控制玩家接管(0=不接管坦克)", CVAR_FLAGS, true, 0.0);
	g_cvMapFilterTank = 			CreateConVar("cz_map_filter_tank", 					"3", 					"在哪些地图上才允许叛变和接管坦克(0=禁用叛变和接管坦克,1=非结局地图,2=结局地图,3=所有地图)", CVAR_FLAGS, true, 0.0);
	g_cvSurvivorLimit = 			CreateConVar("cz_allow_survivor_limit", 			"1", 					"至少有多少名正常生还者(未被控,未倒地,未死亡)时,才允许玩家接管坦克", CVAR_FLAGS, true, 0.0);
	g_cvSurvivorChance = 			CreateConVar("cz_survivor_allow_chance", 			"0.0", 					"准备叛变的玩家数量为0时,自动抽取生还者和感染者玩家的几率(排除闲置旁观玩家)(0.0=不自动抽取)", CVAR_FLAGS);
	g_cvExchangeTeam = 				CreateConVar("cz_exchange_team", 					"0", 					"特感玩家杀死生还者玩家后是否互换队伍?(0=否,1=是)", CVAR_FLAGS);
	g_cvPZSuicideTime = 			CreateConVar("cz_pz_suicide_time", 					"120", 					"特感玩家复活后自动处死的时间(0=不会处死复活后的特感玩家)", CVAR_FLAGS, true, 0.0);
	g_cvPZRespawnTime = 			CreateConVar("cz_pz_respawn_time", 					"10", 					"特感玩家自动复活时间(0=插件不会接管特感玩家的复活)", CVAR_FLAGS, true, 0.0);
	g_cvPZPunishTime = 				CreateConVar("cz_pz_punish_time", 					"15", 					"特感玩家在ghost状态下切换特感类型后下次复活延长的时间(0=插件不会延长复活时间)", CVAR_FLAGS, true, 0.0);
	g_cvPZPunishHealth = 			CreateConVar("cz_pz_punish_health", 				"0.5", 					"特感玩家在ghost状态下切换特感类型是否进行血量惩罚(0.0=不惩罚.计算方式为当前血量乘以该值)", CVAR_FLAGS, true, 0.0);
	g_cvAutoDisplayMenu = 			CreateConVar("cz_atuo_display_menu", 				"1", 					"在感染玩家进入灵魂状态后自动向其显示更改类型的菜单?(0=不显示,-1=每次都显示,大于0=每回合总计显示的最大次数)", CVAR_FLAGS, true, -1.0);
	g_cvPZTeamLimit = 				CreateConVar("cz_pz_team_limit", 					"2", 					"感染玩家数量达到多少后将限制使用sm_team3命令(-1=感染玩家不能超过生还玩家,大于等于0=感染玩家不能超过该值)", CVAR_FLAGS, true, -1.0);
	g_cvCmdCooldownTime = 			CreateConVar("cz_cmd_cooldown_time", 				"60.0", 				"sm_team2,sm_team3命令的冷却时间(0.0-无冷却)", CVAR_FLAGS, true, 0.0);
	g_cvCmdEnterCooling = 			CreateConVar("cz_return_enter_cooling", 			"31", 					"什么情况下sm_team2,sm_team3命令会进入冷却(1=使用其中一个命令,2=坦克玩家掉控,4=坦克玩家死亡,8=坦克玩家未及时重生,16=特感玩家杀掉生还者玩家,31=所有)", CVAR_FLAGS);
	g_cvLotTargetPlayer = 			CreateConVar("cz_lot_target_player", 				"7", 					"抽取哪些玩家来接管坦克?(0=不抽取,1=叛变玩家,2=生还者,4=感染者)", CVAR_FLAGS);
	g_cvPZChangeTeamTo = 			CreateConVar("cz_pz_change_team_to", 				"0", 					"换图,过关以及任务失败时是否自动将特感玩家切换到哪个队伍?(0=不切换,1=旁观者,2=生还者)", CVAR_FLAGS);
	g_cvGlowColorEnable = 			CreateConVar("cz_survivor_color_enable", 			"1", 					"是否给生还者创发光建模型?(0=否,1=是)", CVAR_FLAGS);
	g_cvGlowColor[COLOR_NORMAL] = 	CreateConVar("cz_survivor_color_normal", 			"0 180 0", 				"特感玩家看到的正常状态生还者发光颜色", CVAR_FLAGS);
	g_cvGlowColor[COLOR_INCAPA] = 	CreateConVar("cz_survivor_color_incapacitated", 	"180 0 0", 				"特感玩家看到的倒地状态生还者发光颜色", CVAR_FLAGS);
	g_cvGlowColor[COLOR_BLACKW] = 	CreateConVar("cz_survivor_color_blackwhite", 		"255 255 255", 			"特感玩家看到的黑白状态生还者发光颜色", CVAR_FLAGS);
	g_cvGlowColor[COLOR_VOMITED] = 	CreateConVar("cz_survivor_color_nowit", 			"155 0 180", 			"特感玩家看到的被Boomer喷或炸中过的生还者发光颜色", CVAR_FLAGS);
	g_cvUserFlagBits = 				CreateConVar("cz_user_flagbits", 					";z;;z;z;;z", 			"哪些标志能绕过sm_team2,sm_team3,sm_pb,sm_tt,sm_pt,sm_class,鼠标中键重置冷却的使用限制(留空表示所有人都不会被限制)", CVAR_FLAGS);
	g_cvImmunityLevels = 			CreateConVar("cz_immunity_levels", 					"99;99;99;99;99;99;99", "要达到什么免疫级别才能绕过sm_team2,sm_team3,sm_pb,sm_tt,sm_pt,sm_class,鼠标中键重置冷的使用限制", CVAR_FLAGS);

	// https://github.com/brxce/hardcoop/blob/master/addons/sourcemod/scripting/modules/SS_SpawnQueue.sp
	g_cvSILimit = 					CreateConVar("cz_si_limit", 						"31", 					"同时存在的最大特感数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_SMOKER] = 	CreateConVar("cz_smoker_limit",						"6", 					"同时存在的最大smoker数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_BOOMER] = 	CreateConVar("cz_boomer_limit",						"6", 					"同时存在的最大boomer数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_HUNTER] = 	CreateConVar("cz_hunter_limit",						"6", 					"同时存在的最大hunter数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_SPITTER] = 	CreateConVar("cz_spitter_limit", 					"6", 					"同时存在的最大spitter数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_JOCKEY] = 	CreateConVar("cz_jockey_limit",						"6", 					"同时存在的最大jockey数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_CHARGER] = 	CreateConVar("cz_charger_limit", 					"6", 					"同时存在的最大charger数量", CVAR_FLAGS, true, 0.0, true, 32.0);
	g_cvSpawnWeights[SI_SMOKER] = 	CreateConVar("cz_smoker_weight", 					"100", 					"smoker产生比重", CVAR_FLAGS, true, 0.0);
	g_cvSpawnWeights[SI_BOOMER] = 	CreateConVar("cz_boomer_weight", 					"50", 					"boomer产生比重", CVAR_FLAGS, true, 0.0);
	g_cvSpawnWeights[SI_HUNTER] = 	CreateConVar("cz_hunter_weight", 					"100", 					"hunter产生比重", CVAR_FLAGS, true, 0.0);
	g_cvSpawnWeights[SI_SPITTER] = 	CreateConVar("cz_spitter_weight", 					"50", 					"spitter产生比重", CVAR_FLAGS, true, 0.0);
	g_cvSpawnWeights[SI_JOCKEY] = 	CreateConVar("cz_jockey_weight", 					"100", 					"jockey产生比重", CVAR_FLAGS, true, 0.0);
	g_cvSpawnWeights[SI_CHARGER] = 	CreateConVar("cz_charger_weight", 					"50", 					"charger产生比重", CVAR_FLAGS, true, 0.0);
	g_cvScaleWeights = 				CreateConVar("cz_scale_weights", 					"1",					"[0 = 关闭 | 1 = 开启] 缩放相应特感的产生比重", CVAR_FLAGS);

	AutoExecConfig(true, "controll_zombies");
	// 想要生成cfg的,把上面那一行的注释去掉保存后重新编译就行

	g_cvGameMode = FindConVar("mp_gamemode");
	g_cvGameMode.AddChangeHook(CvarChanged_Mode);
	g_cvSbAllBotGame = FindConVar("sb_all_bot_game");
	g_cvSbAllBotGame.AddChangeHook(CvarChanged);
	g_cvAllowAllBotSur = FindConVar("allow_all_bot_survivor_team");
	g_cvAllowAllBotSur.AddChangeHook(CvarChanged);
	g_cvSurvivorMaxInc = FindConVar("survivor_max_incapacitated_count");
	g_cvSurvivorMaxInc.AddChangeHook(CvarChanged_Color);

	g_cvMaxTankPlayer.AddChangeHook(CvarChanged);
	g_cvMapFilterTank.AddChangeHook(CvarChanged);
	g_cvSurvivorLimit.AddChangeHook(CvarChanged);
	g_cvSurvivorChance.AddChangeHook(CvarChanged);
	g_cvExchangeTeam.AddChangeHook(CvarChanged);
	g_cvPZSuicideTime.AddChangeHook(CvarChanged);
	g_cvPZRespawnTime.AddChangeHook(CvarChanged);
	g_cvPZPunishTime.AddChangeHook(CvarChanged);
	g_cvPZPunishHealth.AddChangeHook(CvarChanged);
	g_cvAutoDisplayMenu.AddChangeHook(CvarChanged);
	g_cvPZTeamLimit.AddChangeHook(CvarChanged);
	g_cvCmdCooldownTime.AddChangeHook(CvarChanged);
	g_cvCmdEnterCooling.AddChangeHook(CvarChanged);
	g_cvLotTargetPlayer.AddChangeHook(CvarChanged);
	g_cvPZChangeTeamTo.AddChangeHook(CvarChanged);

	g_cvGlowColorEnable.AddChangeHook(CvarChanged_Color);
	int i;
	for (; i < 4; i++)
		g_cvGlowColor[i].AddChangeHook(CvarChanged_Color);

	g_cvUserFlagBits.AddChangeHook(CvarChanged_Access);
	g_cvImmunityLevels.AddChangeHook(CvarChanged_Access);

	g_cvSILimit.AddChangeHook(CvarChanged_Spawn);
	for (i = 0; i < 6; i++) {
		g_cvSpawnLimits[i].AddChangeHook(CvarChanged_Spawn);
		g_cvSpawnWeights[i].AddChangeHook(CvarChanged_Spawn);
	}
	g_cvScaleWeights.AddChangeHook(CvarChanged_Spawn);

	//RegAdminCmd("sm_cz", cmdCz, ADMFLAG_ROOT, "测试");

	RegConsoleCmd("sm_team2", 	cmdTeam2, 			"切换到Team 2.");
	RegConsoleCmd("sm_team3", 	cmdTeam3, 			"切换到Team 3.");
	RegConsoleCmd("sm_pb", 		cmdPanBian, 		"提前叛变.");
	RegConsoleCmd("sm_tt", 		cmdTakeOverTank, 	"接管坦克.");
	RegConsoleCmd("sm_pt", 		cmdTransferTank, 	"转交坦克.");
	RegConsoleCmd("sm_class", 	cmdChangeClass,		"更改特感类型.");

	if (g_bLateLoad) {
		g_iRoundStart = 1;
		g_iPlayerSpawn = 1;
		g_bLeftSafeArea = HasAnySurLeftSafeArea();
	}

	PluginStateChanged();
}

public void OnPluginEnd() {
	StatsConditionPatch(false);

	for (int i = 1; i <= MaxClients; i++)
		RemoveSurGlow(i);
}

public void OnConfigsExecuted() {
	GetCvars_General();
	GetCvars_Color();
	GetCvars_Spawn();
	GetCvars_Access();
	PluginStateChanged();
}

void CvarChanged_Mode(ConVar convar, const char[] oldValue, const char[] newValue) {
	PluginStateChanged();
}

void PluginStateChanged() {
	g_cvGameMode.GetString(g_sGameMode, sizeof g_sGameMode);

	int last = g_iControlled;
	g_iControlled = SDKCall(g_hSDK_CTerrorGameRules_HasPlayerControlledZombies);
	if (g_iControlled == 1) {
		Toggle(false);
		if (last != g_iControlled) {
			delete g_hTimer;
			for (int i = 1; i <= MaxClients; i++) {
				ResetClientData(i);
				RemoveSurGlow(i);
			}
		}
	}
	else {
		Toggle(true);
		if (last != g_iControlled) {
			if (HasPZ()) {
				float time = g_bLeftSafeArea ? GetEngineTime() : 0.0;
				for (int i = 1; i <= MaxClients; i++) {
					if (!IsClientInGame(i))
						continue;

					switch (GetClientTeam(i)) {
						case 2:
							CreateSurGlow(i);

						case 3: {
							if (!IsFakeClient(i) && !IsPlayerAlive(i)) {
								CalculatePZRespawnTime(i);
								g_esPlayer[i].respawnStartTime = time;
							}
						}
					}
				}

				delete g_hTimer;
				g_hTimer = CreateTimer(0.1, tmrPlayerStatus, _, TIMER_REPEAT);
			}
		}
	}
}

void Toggle(bool enable) {
	static bool enabled;
	if (!enabled && enable) {
		enabled = true;
		ToggleDetours(true);

		HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
		HookEvent("player_left_checkpoint", Event_PlayerLeftStartArea);
		HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
		HookEvent("player_team", Event_PlayerTeam);
		HookEvent("player_spawn", Event_PlayerSpawn);
		HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		HookEvent("tank_frustrated", Event_TankFrustrated);
		HookEvent("player_bot_replace", Event_PlayerBotReplace);
		HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

		AddCommandListener(Listener_callvote, "callvote");
	}
	else if (enabled && !enable) {
		enabled = false;
		ToggleDetours(false);

		UnhookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
		UnhookEvent("player_left_checkpoint", Event_PlayerLeftStartArea, EventHookMode_PostNoCopy);
		UnhookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("map_transition", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("finale_vehicle_leaving", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("player_team", Event_PlayerTeam);
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
		UnhookEvent("tank_frustrated", Event_TankFrustrated);
		UnhookEvent("player_bot_replace", Event_PlayerBotReplace);
		UnhookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

		RemoveCommandListener(Listener_callvote, "callvote");
	}
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_General();
}

void GetCvars_General() {
	g_iMaxTankPlayer = g_cvMaxTankPlayer.IntValue;
	g_iMapFilterTank = g_cvMapFilterTank.IntValue;
	g_iSurvivorLimit = g_cvSurvivorLimit.IntValue;
	g_fSurvivorChance = g_cvSurvivorChance.FloatValue;
	g_bSbAllBotGame = g_cvSbAllBotGame.BoolValue;
	g_bAllowAllBotSur = g_cvAllowAllBotSur.BoolValue;
	g_bExchangeTeam = g_cvExchangeTeam.BoolValue;
	g_iPZRespawnTime = g_cvPZRespawnTime.IntValue;
	g_iPZSuicideTime = g_cvPZSuicideTime.IntValue;
	g_iPZPunishTime = g_cvPZPunishTime.IntValue;
	g_fPZPunishHealth = g_cvPZPunishHealth.FloatValue;
	g_iAutoDisplayMenu = g_cvAutoDisplayMenu.IntValue;
	g_iPZTeamLimit = g_cvPZTeamLimit.IntValue;
	g_fCmdCooldownTime = g_cvCmdCooldownTime.FloatValue;
	g_iCmdEnterCooling = g_cvCmdEnterCooling.IntValue;
	g_iLotTargetPlayer = g_cvLotTargetPlayer.IntValue;
	g_iPZChangeTeamTo = g_cvPZChangeTeamTo.IntValue;
}

void CvarChanged_Color(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Color();
}

void GetCvars_Color() {
	bool last = g_bGlowColorEnable;
	g_bGlowColorEnable = g_cvGlowColorEnable.BoolValue;
	g_iSurvivorMaxInc = g_cvSurvivorMaxInc.IntValue;

	int i;
	for (; i < 4; i++)
		g_iGlowColor[i] = GetColor(g_cvGlowColor[i]);

	if (last != g_bGlowColorEnable) {
		if (g_bGlowColorEnable) {
			if (HasPZ()) {
				for (i = 1; i <= MaxClients; i++)
					CreateSurGlow(i);
			}
		}
		else {
			for (i = 1; i <= MaxClients; i++)
				RemoveSurGlow(i);
		}
	}
}

int GetColor(ConVar convar) {
	char sTemp[12];
	convar.GetString(sTemp, sizeof sTemp);

	if (sTemp[0] == '\0')
		return 1;

	char sColors[3][4];
	int color = ExplodeString(sTemp, " ", sColors, sizeof sColors, sizeof sColors[]);

	if (color != 3)
		return 1;
		
	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);

	return color > 0 ? color : 1;
}

void CvarChanged_Access(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Access();
}

void GetCvars_Access() {
	GetFlagBits();
	GetImmunitys();
}

void GetFlagBits() {
	char sTemp[512];
	g_cvUserFlagBits.GetString(sTemp, sizeof sTemp);

	char sUserFlagBits[7][32];
	ExplodeString(sTemp, ";", sUserFlagBits, sizeof sUserFlagBits, sizeof sUserFlagBits[]);

	for (int i; i < 7; i++)
		g_iUserFlagBits[i] = ReadFlagString(sUserFlagBits[i]);
}

void GetImmunitys() {
	char sTemp[512];
	g_cvImmunityLevels.GetString(sTemp, sizeof sTemp);

	char sImmunityLevels[7][12];
	ExplodeString(sTemp, ";", sImmunityLevels, sizeof sImmunityLevels, sizeof sImmunityLevels[]);

	for (int i; i < 7; i++)
		g_iImmunityLevels[i] = StringToInt(sImmunityLevels[i]);
}

bool CheckClientAccess(int client, int iIndex) {
	if (!g_iUserFlagBits[iIndex])
		return true;

	static int bits;
	if ((bits = GetUserFlagBits(client)) & ADMFLAG_ROOT == 0 && bits & g_iUserFlagBits[iIndex] == 0)
		return false;

	if (!CacheSteamID(client))
		return false;

	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, g_esPlayer[client].AuthId);
	if (admin == INVALID_ADMIN_ID)
		return true;

	return admin.ImmunityLevel >= g_iImmunityLevels[iIndex];
}

bool CacheSteamID(int client) {
	if (g_esPlayer[client].AuthId[0] != '\0')
		return true;

	if (GetClientAuthId(client, AuthId_Steam2, g_esPlayer[client].AuthId, sizeof esPlayer::AuthId))
		return true;

	g_esPlayer[client].AuthId[0] = '\0';
	return false;
}

void CvarChanged_Spawn(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars_Spawn();
}

void GetCvars_Spawn() {
	g_iSILimit = g_cvSILimit.IntValue;
	for (int i; i < 6; i++) {
		g_iSpawnLimits[i] = g_cvSpawnLimits[i].IntValue;
		g_iSpawnWeights[i] = g_cvSpawnWeights[i].IntValue;
	}
	g_bScaleWeights = g_cvScaleWeights.BoolValue;
}
/*
Action cmdCz(int client, int args) {
	return Plugin_Handled;
}*/

Action cmdTeam2(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!CheckClientAccess(client, 0)) {
		// ReplyToCommand(client, "无权使用该指令");
		// return Plugin_Handled;
		float time = GetEngineTime();
		if (g_esPlayer[client].lastUsedTime > time) {
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_esPlayer[client].lastUsedTime - time);
			return Plugin_Handled;
		}
	}

	if (GetClientTeam(client) != 3) {
		PrintToChat(client, "只有感染者才能使用该指令");
		return Plugin_Handled;
	}

	if (g_iCmdEnterCooling & (1 << 0))
		g_esPlayer[client].lastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
	ChangeTeamToSur(client);
	return Plugin_Handled;
}

Action cmdTeam3(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 3)
		return Plugin_Handled;

	if (!CheckClientAccess(client, 1)) {
		// ReplyToCommand(client, "无权使用该指令");
		// return Plugin_Handled;
		float time = GetEngineTime();
		if (g_esPlayer[client].lastUsedTime > time) {
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_esPlayer[client].lastUsedTime - time);
			return Plugin_Handled;
		}

		int team3 = _GetTeamCount(3);
		int team2 = _GetTeamCount(2);
		if ((g_iPZTeamLimit >= 0 && team3 >= g_iPZTeamLimit) || (g_iPZTeamLimit == -1 && team3 >= team2)) {
			PrintToChat(client, "已到达感染玩家数量限制");
			return Plugin_Handled;
		}
	}
		
	if (g_iCmdEnterCooling & (1 << 0))
		g_esPlayer[client].lastUsedTime = GetEngineTime() + g_fCmdCooldownTime;

	g_esData[client].Clean();

	int bot;
	if (GetClientTeam(client) != 1 || !(bot = GetBotOfIdlePlayer(client)))
		bot = client;

	g_esData[client].Save(bot, false);

	ChangeClientTeam(client, 3);
	return Plugin_Handled;
}

Action cmdPanBian(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!CheckClientAccess(client, 2)) {
		ReplyToCommand(client, "无权使用该指令");
		return Plugin_Handled;
	}

	if (!MapFilterTank()) {
		ReplyToCommand(client, "当前地图已禁用该指令");
		return Plugin_Handled;
	}

	if (!g_esPlayer[client].isPlayerPB) {
		g_esPlayer[client].isPlayerPB = true;
		CPrintToChat(client, "已加入叛变列表");
		CPrintToChat(client, "再次输入该指令可退出叛变列表");
		CPrintToChat(client, "坦克出现后将会随机从叛变列表中抽取1人接管");
		CPrintToChat(client, "{olive}当前叛变玩家列表:");

		for (int i = 1; i <= MaxClients; i++) {
			if (g_esPlayer[i].isPlayerPB && IsClientInGame(i) && !IsFakeClient(i))
				CPrintToChat(client, "-> {red}%N", i);
		}
	}
	else {
		g_esPlayer[client].isPlayerPB = false;
		CPrintToChat(client, "已退出叛变列表");
	}

	return Plugin_Handled;
}

bool MapFilterTank() {
	if (!SDKCall(g_hSDK_CTerrorGameRules_IsMissionFinalMap))
		return g_iMapFilterTank & (1 << 0) != 0;

	return g_iMapFilterTank & (1 << 1) != 0;
}

Action cmdTakeOverTank(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!IsRoundStarted()) {
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	
	if (!CheckClientAccess(client, 3)) {
		ReplyToCommand(client, "无权使用该指令");
		return Plugin_Handled;
		/*float time = GetEngineTime();
		if (g_esPlayer[client].lastUsedTime > time) {
			PrintToChat(client, "\x01请等待 \x05%.1f秒 \x01再使用该指令", g_esPlayer[client].lastUsedTime - time);
			return Plugin_Handled;
		}*/
	}

	if (!MapFilterTank()) {
		ReplyToCommand(client, "当前地图已禁用该指令");
		return Plugin_Handled;
	}

	int tank;
	if (args) {
		char arg[32];
		GetCmdArg(1, arg, sizeof arg);
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof target_name, tn_is_ml)) <= 0) {
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}

		if (IsFakeClient(target_list[0]) && GetClientTeam(target_list[0]) == 3 && GetEntProp(target_list[0], Prop_Send, "m_zombieClass") == 8)
			tank = target_list[0];
	}
	else {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8) {
				tank = i;
				break;
			}
		}
	}

	if (!tank) {
		ReplyToCommand(client, "无可供接管的坦克存在");
		return Plugin_Handled;
	}

	if (!TakeOverLimit(tank, client, client))
		return Plugin_Handled;

	int team = GetClientTeam(client);
	switch (team) {
		case 2: {
				g_esData[client].Clean();
				g_esData[client].Save(client, false);
				ChangeClientTeam(client, 3);
		}
			
		case 3: {
			if (IsPlayerAlive(client)) {
				SDKCall(g_hSDK_CTerrorPlayer_CleanupPlayerState, client);
				ForcePlayerSuicide(client);
			}
		}

		default:
			ChangeClientTeam(client, 3);
	}

	if (GetClientTeam(client) == 3)
		g_esPlayer[client].lastTeamID = team != 3 ? 2 : 3;

	if (TakeOverZombieBot(client, tank) == 8 && IsPlayerAlive(client)) {
		if (g_iCmdEnterCooling & (1 << 0))
			g_esPlayer[client].lastUsedTime = GetEngineTime() + g_fCmdCooldownTime;

		CPrintToChatAll("{green}★ {default}[{olive}AI{default}] {red}%N {default}已被 {red}%N {olive}接管", tank, client);
	}

	return Plugin_Handled;
}

bool TakeOverLimit(int tank, int target, int reply) {
	if (!CanTarget(reply, target)) {
		PrintToChat(reply, "权限不足");
		return false;
	}

	switch (GetClientTeam(target)) {
		case 2: {
			if (!AllowSurTakeOver()) {
				PrintToChat(reply, "生还者接管坦克将会导致任务失败, 请等待生还者玩家足够后再尝试");
				return false;
			}
		}
		
		case 3: {
			if (IsPlayerAlive(target) && GetEntProp(target, Prop_Send, "m_zombieClass") == 8) {
				PrintToChat(reply, "拟接管玩家目前已经是坦克");
				return false;
			}
		}
	}

	if (GetTankCount(1) - (IsFakeClient(tank) ? 0 : 1) >= g_iMaxTankPlayer) {
		PrintToChat(reply, "\x01坦克玩家数量已达到预设值 ->\x05%d", g_iMaxTankPlayer);
		return false;
	}

	if (GetNormalSur() < g_iSurvivorLimit) {
		PrintToChat(reply, "\x01完全正常的生还者数量小于预设值 ->\x05%d", g_iSurvivorLimit);
		return false;
	}

	return true;
}

bool CanTarget(int client, int target) {
	return client == target || CanUserTarget(client, target) && !CanUserTarget(target, client);
}

Action cmdTransferTank(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!IsRoundStarted()) {
		ReplyToCommand(client, "回合尚未开始");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!MapFilterTank()) {
		ReplyToCommand(client, "当前地图已禁用该指令");
		return Plugin_Handled;
	}

	bool access = CheckClientAccess(client, 4);
	bool isAliveTank = GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
	if (!access && !isAliveTank) {
		ReplyToCommand(client, "你当前不是存活的坦克");
		return Plugin_Handled;
	}

	if (args && isAliveTank) {
		char arg[32];
		GetCmdArg(1, arg, sizeof arg);
		char target_name[MAX_TARGET_LENGTH];
		int target_list[MAXPLAYERS], target_count;
		bool tn_is_ml;
		if ((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, target_name, sizeof target_name, tn_is_ml)) <= 0) {
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}

		OfferTankMenu(client, target_list[0], client, access);
	}
	else {
		if (GetTankCount(-1)) {
			if (access)
				ShowTankListMenu(client);
			else
				ShowPlayerListMenu(client, client);
		}
		else
			ReplyToCommand(client, "无存活的坦克存在");
	}

	return Plugin_Handled;
}

void OfferTankMenu(int tank, int target, int reply, bool access = false) {
	if (!TakeOverLimit(tank, target, reply))
		return;

	if (access)
		TransferTank(tank, target, reply);
	else {
		Menu menu = new Menu(OfferTank_MenuHandler);
		menu.SetTitle("是否接受 %N 的坦克控制权转移?", tank);

		char info[12];
		FormatEx(info, sizeof info, "%d", GetClientUserId(tank));
		menu.AddItem(info, "是");
		menu.AddItem("no", "否");
		menu.ExitButton = false;
		menu.ExitBackButton = false;
		menu.Display(target, 15);
	}
}

int OfferTank_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
				ReplyToCommand(client, "你当前已经是坦克");
			else {
				char item[12];
				menu.GetItem(param2, item, sizeof item);
				if (item[0] == 'n')
					return 0;

				int tank = GetClientOfUserId(StringToInt(item));
				if (tank && IsClientInGame(tank) && GetClientTeam(tank) == 3 && IsPlayerAlive(tank) && GetEntProp(tank, Prop_Send, "m_zombieClass") == 8)
					TransferTank(tank, client, client);
				else
					ReplyToCommand(client, "目标玩家已不是存活的坦克");
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowTankListMenu(int client) {
	char uid[12];
	char disp[MAX_NAME_LENGTH + 24];
	Menu menu = new Menu(ShowTankList_MenuHandler);
	menu.SetTitle("选择要转交的坦克");
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
			continue;
		
		FormatEx(uid, sizeof uid, "%d", GetClientUserId(i));
		FormatEx(disp, sizeof disp, "%d HP - %N", GetEntProp(i, Prop_Data, "m_iHealth"), i);
		menu.AddItem(uid, disp);
	}

	menu.ExitBackButton = false;
	menu.Display(client, 30);
}

int ShowTankList_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[12];
			menu.GetItem(param2, item, sizeof item);
			int target = GetClientOfUserId(StringToInt(item));
			if (target && IsClientInGame(target) && GetClientTeam(target) == 3 && IsPlayerAlive(target) && GetEntProp(target, Prop_Send, "m_zombieClass") == 8)
				ShowPlayerListMenu(client, target);
			else {
				ReplyToCommand(client, "目标坦克已失效, 请重新选择");
				ShowTankListMenu(client);
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowPlayerListMenu(int client, int target) {
	char info[32];
	char uid[2][12];
	char disp[MAX_NAME_LENGTH + 12];
	Menu menu = new Menu(ShowPlayerList_MenuHandler);
	menu.SetTitle("选择要给予控制权的玩家");
	FormatEx(uid[0], sizeof uid[], "%d", GetClientUserId(target));
	for (int i = 1; i <= MaxClients; i++) {
		if (i == target || !IsClientInGame(i) || IsFakeClient(i))
			continue;

		FormatEx(uid[1], sizeof uid[], "%d", GetClientUserId(i));
		switch (GetClientTeam(i)) {
			case 1:
				FormatEx(disp, sizeof disp, "%s - %N", GetBotOfIdlePlayer(i) ? "闲置" : "观众", i);

			case 2:
				FormatEx(disp, sizeof disp, "生还 - %N", i);
					
			case 3:
				FormatEx(disp, sizeof disp, "感染 - %N", i);
		}

		ImplodeStrings(uid, sizeof uid, "|", info, sizeof info);
		menu.AddItem(info, disp);
	}

	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

int ShowPlayerList_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[32];
			char info[2][16];
			menu.GetItem(param2, item, sizeof item);
			ExplodeString(item, "|", info, sizeof info, sizeof info[]);
			int tank = GetClientOfUserId(StringToInt(info[0]));
			if (!tank || !IsClientInGame(tank) || GetClientTeam(tank) != 3 || !IsPlayerAlive(tank) || GetEntProp(tank, Prop_Send, "m_zombieClass") != 8) {
				ReplyToCommand(client, "目标坦克已失效");
				return 0;
			}

			int target = GetClientOfUserId(StringToInt(info[1]));
			if (!target || !IsClientInGame(target)) {
				ReplyToCommand(client, "目标玩家已失效, 请重新选择");
				ShowPlayerListMenu(client, tank);
			}
			else
				OfferTankMenu(tank, target, client, CheckClientAccess(client, 4));
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void TransferTank(int tank, int target, int reply) {
	if (!TakeOverLimit(tank, target, reply))
		return;

	int team = GetClientTeam(target);
	switch (team) {
		case 2: {
				g_esData[target].Clean();
				g_esData[target].Save(target, false);
				ChangeClientTeam(target, 3);
		}
			
		case 3: {
			if (IsPlayerAlive(target)) {
				SDKCall(g_hSDK_CTerrorPlayer_CleanupPlayerState, target);
				ForcePlayerSuicide(target);
			}
		}

		default:
			ChangeClientTeam(target, 3);
	}

	if (GetClientTeam(target) == 3)
		g_esPlayer[target].lastTeamID = team != 3 ? 2 : 3;

	int ghost = GetEntProp(tank, Prop_Send, "m_isGhost");
	if (ghost)
		SetEntProp(tank, Prop_Send, "m_isGhost", 0);

	if (IsFakeClient(tank))
		g_iTransferTankBot = tank;
	else {
		Event event = CreateEvent("tank_frustrated", true);
		event.SetInt("userid", GetClientUserId(tank));
		event.Fire(false);

		g_iTransferTankBot = 0;
		g_bOnPassPlayerTank = true;
		SDKCall(g_hSDK_CTerrorPlayer_ReplaceWithBot, tank, false);
		g_bOnPassPlayerTank = false;
		SDKCall(g_hSDK_CTerrorPlayer_SetPreSpawnClass, tank, 3);
		SDKCall(g_hSDK_CCSPlayer_State_Transition, tank, 8);
	}

	if (g_iTransferTankBot && TakeOverZombieBot(target, g_iTransferTankBot) == 8 && IsPlayerAlive(target)) {
		if (g_iCmdEnterCooling & (1 << 0))
			g_esPlayer[target].lastUsedTime = GetEngineTime() + g_fCmdCooldownTime;

		if (ghost)
			SDKCall(g_hSDK_CCSPlayer_State_Transition, target, 8);

		CPrintToChatAll("{green}★ {default}坦克控制权已由 {red}%N {default}转交给 {olive}%N", tank, target);
	}
}

Action cmdChangeClass(int client, int args) {
	if (g_iControlled == 1) {
		ReplyToCommand(client, "仅支持战役模式");
		return Plugin_Handled;
	}

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	
	if (!CheckClientAccess(client, 5)) {
		ReplyToCommand(client, "无权使用该指令");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_isGhost") == 0) {
		PrintToChat(client, "灵魂状态下的特感才能使用该指令");
		return Plugin_Handled;
	}

	if (g_esPlayer[client].materialized != 0) {
		PrintToChat(client, "第一次灵魂状态下才能使用该指令");
		return Plugin_Handled;
	}
	
	if (args == 1) {
		char arg[16];
		GetCmdArg(1, arg, sizeof arg);
		int zombieClass;
		int class = GetZombieClass(arg);
		if (class == -1) {
			CPrintToChat(client, "{olive}!class{default}/{olive}sm_class {default}<{red}class{default}>.");
			CPrintToChat(client, "<{olive}class{default}> [ {red}smoker {default}| {red}boomer {default}| {red}hunter {default}| {red}spitter {default}| {red}jockey {default}| {red}charger {default}]");
		}
		else if (++class == (zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass")))
			CPrintToChat(client, "目标特感类型与当前特感类型相同");
		else if (zombieClass == 8)
			CPrintToChat(client, "{red}Tank {default}无法更改特感类型");
		else
			SetClassAndPunish(client, class);
	}
	else {
		if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
			SelectClassMenu(client);
		else
			CPrintToChat(client, "{red}Tank {default}无法更改特感类型");
	}
	
	return Plugin_Handled;
}

void DisplayClassMenu(int client) {
	Menu menu = new Menu(DisplayClass_MenuHandler);
	menu.SetTitle("!class付出一定代价更改特感类型?");
	menu.AddItem("yes", "是");
	menu.AddItem("no", "否");
	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, 15);
}

int DisplayClass_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (param2 == 0 && GetClientTeam(param1) == 3 && !IsFakeClient(param1) && IsPlayerAlive(param1) && GetEntProp(param1, Prop_Send, "m_isGhost"))
				SelectClassMenu(param1);
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void SelectClassMenu(int client) {
	char info[2];
	Menu menu = new Menu(SelectClass_MenuHandler);
	menu.SetTitle("选择要切换的特感");
	int zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass") - 1;
	for (int i; i < 6; i++) {
		if (i != zombieClass) {
			FormatEx(info, sizeof info, "%d", i);
			menu.AddItem(info, g_sZombieClass[i]);
		}
	}
	menu.ExitButton = true;
	menu.ExitBackButton = false;
	menu.Display(client, 30);
}

int SelectClass_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			int zombieClass;
			if (GetClientTeam(param1) == 3 && !IsFakeClient(param1) && IsPlayerAlive(param1) && (zombieClass = GetEntProp(param1, Prop_Send, "m_zombieClass")) != 8 && GetEntProp(param1, Prop_Send, "m_isGhost")) {
				char item[2];
				menu.GetItem(param2, item, sizeof item);
				int class = StringToInt(item);
				if (++class != zombieClass)
					SetClassAndPunish(param1, class);
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void SetClassAndPunish(int client, int zombieClass) {
	SetZombieClass(client, zombieClass);
	if (g_fPZPunishHealth)
		SetEntityHealth(client, RoundToCeil(GetClientHealth(client) * g_fPZPunishHealth));
	g_esPlayer[client].classCmdUsed = true;
}

int GetZombieClass(const char[] sClass) {
	for (int i; i < 6; i++) {
		if (strcmp(sClass, g_sZombieClass[i], false) == 0)
			return i;
	}
	return -1;
}

Action Listener_callvote(int client, const char[] command, int argc) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;
		
	if (GetClientTeam(client) == 3) {
		CPrintToChat(client, "{red}感染者无人权");
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// https://gist.github.com/ProdigySim/04912e5e76f69027f8c4
// Spawn State - These look like flags, but get used like static values quite often.
// These names were pulled from reversing client.dll--specifically CHudGhostPanel::OnTick()'s uses of the "#L4D_Zombie_UI_*" strings
//
// SPAWN_OK             0
// SPAWN_DISABLED       1  "Spawning has been disabled..." (e.g. director_no_specials 1)
// WAIT_FOR_SAFE_AREA   2  "Waiting for the Survivors to leave the safe area..."
// WAIT_FOR_FINALE      4  "Waiting for the finale to begin..."
// WAIT_FOR_TANK        8  "Waiting for Tank battle conclusion..."
// SURVIVOR_ESCAPED    16  "The Survivors have escaped..."
// DIRECTOR_TIMEOUT    32  "The Director has called a time-out..." (lol wat)
// WAIT_FOR_STAMPEDE   64  "Waiting for the next stampede of Infected..."
// CAN_BE_SEEN        128  "Can't spawn here" "You can be seen by the Survivors"
// TOO_CLOSE          256  "Can't spawn here" "You are too close to the Survivors"
// RESTRICTED_AREA    512  "Can't spawn here" "This is a restricted area"
// INSIDE_ENTITY     1024  "Can't spawn here" "Something is blocking this spot"
public void OnPlayerRunCmdPost(int client) {
	if (g_iControlled == 1 || IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client))
		return;

	static int iFlags;
	iFlags = GetEntProp(client, Prop_Data, "m_afButtonPressed");
	if (GetEntProp(client, Prop_Send, "m_isGhost")) {
		if (iFlags & IN_ZOOM) {
			if (g_esPlayer[client].materialized == 0 && CheckClientAccess(client, 5))
				SelectAscendingClass(client);
		}
		else if (iFlags & IN_ATTACK) {
			if (GetEntProp(client, Prop_Send, "m_ghostSpawnState") == 1)
				SDKCall(g_hSDK_CTerrorPlayer_MaterializeFromGhost, client);
		}
	}
	else {
		if (iFlags & IN_ZOOM && CheckClientAccess(client, 6))
			ResetInfectedAbility(client, 0.1); // 管理员鼠标中键重置技能冷却
	}
}

void SelectAscendingClass(int client) {
	static int zombieClass;
	zombieClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (zombieClass != 8)
		SetClassAndPunish(client, zombieClass - RoundToFloor(zombieClass / 6.0) * 6 + 1);
}

// https://forums.alliedmods.net/showthread.php?p=1542365
void ResetInfectedAbility(int client, float time) {
	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (ability > MaxClients) {
		SetEntPropFloat(ability, Prop_Send, "m_duration", time);
		SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + time);
	}
}

public void OnMapStart() {
	PrecacheSound(SOUND_CLASSMENU);
	for (int i = 1; i <= MaxClients; i++)
		g_esPlayer[i].bugExploitTime[0] = g_esPlayer[i].bugExploitTime[1] = 0.0;
}

public void OnMapEnd() {
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bLeftSafeArea = false;
	delete g_hTimer;
}

public void OnClientPutInServer(int client) {
	if (IsFakeClient(client))
		return;

	ResetClientData(client);
}

public void OnClientDisconnect(int client) {
	RemoveSurGlow(client);
	if (IsFakeClient(client))
		return;

	g_esPlayer[client].AuthId[0] = '\0';
	if (!IsClientInGame(client) || GetClientTeam(client) != 3)
		g_esPlayer[client].lastTeamID = 0;
}

void ResetClientData(int client) {
	g_esData[client].Clean();

	g_esPlayer[client].enteredGhost = 0;
	g_esPlayer[client].materialized = 0;
	g_esPlayer[client].respawnStartTime = 0.0;
	g_esPlayer[client].suicideStartTime = 0.0;
	
	g_esPlayer[client].isPlayerPB = false;
	g_esPlayer[client].classCmdUsed = false;
}

// ------------------------------------------------------------------------------
// Event
void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast) { 
	if (g_bLeftSafeArea || !IsRoundStarted())
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		CreateTimer(0.1, tmrPlayerLeftStartArea, _, TIMER_FLAG_NO_MAPCHANGE);
}

bool IsRoundStarted() {
	return g_iRoundStart && g_iPlayerSpawn;
}

Action tmrPlayerLeftStartArea(Handle timer) {
	if (g_bLeftSafeArea || !IsRoundStarted() || !HasAnySurLeftSafeArea())
		return Plugin_Stop;

	g_bLeftSafeArea = true;
	if (g_iControlled)
		return Plugin_Stop;

	if (g_iPZRespawnTime > 0) {
		float time = GetEngineTime();
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 3 || IsPlayerAlive(i))
				continue;
			
			g_esPlayer[i].currentRespawnTime = 0;
			g_esPlayer[i].respawnStartTime = time;
		}
	}

	delete g_hTimer;
	g_hTimer = CreateTimer(0.1, tmrPlayerStatus, _, TIMER_REPEAT);
	return Plugin_Continue;
}

bool HasAnySurLeftSafeArea() {
	int iEnt = GetPlayerResourceEntity();
	if (iEnt == -1)
		return false;

	return !!GetEntProp(iEnt, Prop_Send, "m_hasAnySurvivorLeftSafeArea");
}

void CalculatePZRespawnTime(int client) {
	g_esPlayer[client].currentRespawnTime = g_iPZRespawnTime;

	if (g_iPZPunishTime > 0 && g_esPlayer[client].classCmdUsed)
		g_esPlayer[client].currentRespawnTime += g_iPZPunishTime;
		
	g_esPlayer[client].classCmdUsed = false;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		RemoveInfectedClips();
	g_iRoundStart = 1;

	delete g_hTimer;
	for (int i = 1; i <= MaxClients; i++) {
		g_esPlayer[i].respawnStartTime = 0.0;
		g_esPlayer[i].suicideStartTime = 0.0;
	}
}

// 移除一些限制特感的透明墙体, 增加活动空间
void RemoveInfectedClips() {
	int iEnt = MaxClients + 1;
	while ((iEnt = FindEntityByClassname(iEnt, "func_playerinfected_clip")) != -1)
		RemoveEntity(iEnt);
		
	iEnt = MaxClients + 1;
	while ((iEnt = FindEntityByClassname(iEnt, "func_playerghostinfected_clip")) != -1)
		RemoveEntity(iEnt);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
	g_bLeftSafeArea = false;

	delete g_hTimer;
	for (int i = 1; i <= MaxClients; i++) {
		ResetClientData(i);

		if (g_iPZChangeTeamTo || g_esPlayer[i].lastTeamID == 2)
			ForceChangeTeamTo(i);
	}
}

void ForceChangeTeamTo(int client) {
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3) {
		switch (g_iPZChangeTeamTo) {
			case 1:
				ChangeClientTeam(client, 1);
					
			case 2:
				ChangeTeamToSur(client);
		}
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return;

	RemoveSurGlow(client);
	g_esPlayer[client].materialized = 0;

	if (IsFakeClient(client))
		return;

	g_esPlayer[client].respawnStartTime = 0.0;
	g_esPlayer[client].suicideStartTime = 0.0;

	int team = event.GetInt("team");
	if (team == 3) {
		if (g_bLeftSafeArea && g_iPZRespawnTime > 0) {
			CalculatePZRespawnTime(client);
			g_esPlayer[client].respawnStartTime = GetEngineTime();
		}

		CreateTimer(0.1, tmrLadderAndGlow, userid, TIMER_FLAG_NO_MAPCHANGE);
	}

	switch (event.GetInt("oldteam")) {
		case 0: {
			if (team == 3 && (g_iPZChangeTeamTo || g_esPlayer[client].lastTeamID == 2))
				RequestFrame(NextFrame_ChangeTeamTo, userid);

			g_esPlayer[client].lastTeamID = 0;
		}
		
		case 3: {
			g_esPlayer[client].lastTeamID = 0;

			if (team == 2 && GetEntProp(client, Prop_Send, "m_isGhost"))
				SetEntProp(client, Prop_Send, "m_isGhost", 0); // SDKCall(g_hSDK_CTerrorPlayer_MaterializeFromGhost, client);
			
			CreateTimer(0.1, tmrLadderAndGlow, userid, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

Action tmrLadderAndGlow(Handle timer, int client) {
	if (g_iControlled == 0 && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client)) {
		if (GetClientTeam(client) == 3) {
			// g_cvGameMode.ReplicateToClient(client, "versus");
			if (_GetTeamCount(3) == 1) {
				for (int i = 1; i <= MaxClients; i++)
					CreateSurGlow(i);

				delete g_hTimer;
				g_hTimer = CreateTimer(0.1, tmrPlayerStatus, _, TIMER_REPEAT);
			}
		}
		else {
			g_cvGameMode.ReplicateToClient(client, g_sGameMode);

			int i = 1;
			for (; i <= MaxClients; i++)
				RemoveSurGlow(i);

			if (!HasPZ())
				delete g_hTimer;
			else {
				for (i = 1; i <= MaxClients; i++)
					CreateSurGlow(i);
			}
		}
	}

	return Plugin_Continue;
}

void NextFrame_ChangeTeamTo(int client) {
	if (g_iControlled == 0 && (client = GetClientOfUserId(client)))
		ForceChangeTeamTo(client);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		RemoveInfectedClips();
	g_iPlayerSpawn = 1;

	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
		return;
	
	g_esPlayer[client].tankBot = 0;
	g_esPlayer[client].respawnStartTime = 0.0;

	if (g_bOnPassPlayerTank)
		g_iTransferTankBot = client;
	else if (!g_bOnMaterializeFromGhost)
		RequestFrame(NextFrame_PlayerSpawn, userid); // player_bot_replace在player_spawn之后触发, 延迟一帧进行接管判断
}

void NextFrame_PlayerSpawn(int client) {
	if (g_iControlled == 1 || !(client = GetClientOfUserId(client)) || !IsClientInGame(client) || IsClientInKickQueue(client) || !IsPlayerAlive(client))
		return;

	switch (GetClientTeam(client)) {
		case 2: {
			if (HasPZ())
				CreateSurGlow(client);
		}
		
		case 3: {
			if (g_iRoundStart && IsFakeClient(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
				int player;
				if (g_esPlayer[client].tankBot != 2 && GetTankCount(1) < g_iMaxTankPlayer) {
					if ((player = TakeOverTank(client))) {
						EnterGhostMode(player, true);
						CreateTimer(1.0, tmrTankPlayer, GetClientUserId(player), TIMER_REPEAT);

						CPrintToChatAll("{green}★ {default}[{olive}AI{default}] {red}%N {default}已被 {red}%N {olive}接管", client, player);
					}
				}

				if (!player && (GetEntProp(client, Prop_Data, "m_bIsInStasis") == 1 || SDKCall(g_hSDK_CBaseEntity_IsInStasis, client)))
					SDKCall(g_hSDK_Tank_LeaveStasis, client); // 解除战役模式下特感方有玩家存在时坦克卡住的问题
			}
		}
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return;

	g_esPlayer[client].materialized = 0;
	g_esPlayer[client].suicideStartTime = 0.0;

	switch (GetClientTeam(client)) {
		case 2:	{
			RemoveSurGlow(client);
			if (g_bExchangeTeam && !IsFakeClient(client)) {
				int attacker = GetClientOfUserId(event.GetInt("attacker"));
				if (0 < attacker <= MaxClients && IsClientInGame(attacker) && !IsFakeClient(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8) {
					ChangeClientTeam(client, 3);
					CPrintToChat(client, "{green}★ {red}生还者玩家 {default}被 {red}特感玩家 {default}杀死后, {olive}二者互换队伍");

					if (g_iCmdEnterCooling & (1 << 4))
						g_esPlayer[client].lastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
					RequestFrame(NextFrame_ChangeTeamToSurvivor, GetClientUserId(attacker));
					CPrintToChat(attacker, "{green}★ {red}特感玩家 {default}杀死 {red}生还者玩家 {default}后, {olive}二者互换队伍");
				}
			}
		}
		
		case 3: {
			if (!IsFakeClient(client)) {
				if (g_bLeftSafeArea && g_iPZRespawnTime > 0) {
					CalculatePZRespawnTime(client);
					g_esPlayer[client].respawnStartTime = GetEngineTime();
				}

				if (g_esPlayer[client].lastTeamID == 2 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
					if (g_iCmdEnterCooling & (1 << 2))
						g_esPlayer[client].lastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
					RequestFrame(NextFrame_ChangeTeamToSurvivor, userid);
					CPrintToChat(client, "{green}★ {olive}玩家Tank {default}死亡后自动切换回 {blue}生还者队伍");
				}
			}
		}
	}
}

Action tmrPlayerStatus(Handle timer) {
	if (g_iControlled == 1)
		return Plugin_Continue;

	static int i;
	static int modelIndex;
	static char model[PLATFORM_MAX_PATH];
	static float time;
	static float interval;
	static float lastQueryTime[MAXPLAYERS + 1];
	static float lastCountDown[MAXPLAYERS + 1];
	static bool tankFrustrated[MAXPLAYERS + 1];

	#if BENCHMARK
	g_profiler = new Profiler();
	g_profiler.Start();
	#endif

	time = GetEngineTime();

	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i))
			continue;

		switch (GetClientTeam(i)) {
			case 2: {
				if (!g_bGlowColorEnable || !IsPlayerAlive(i) || !IsValidEntRef(g_esPlayer[i].modelEntRef))
					continue;

				if (g_esPlayer[i].modelIndex != (modelIndex = GetEntProp(i, Prop_Data, "m_nModelIndex"))) {
					g_esPlayer[i].modelIndex = modelIndex;
					GetClientModel(i, model, sizeof model);
					SetEntityModel(g_esPlayer[i].modelEntRef, model);
				}

				SetGlowColor(i);
			}

			case 3: {
				if (IsFakeClient(i))
					continue;

				if (time - lastQueryTime[i] >= 1.0) {
					QueryClientConVar(i, "mp_gamemode", queryMpGamemode, GetClientSerial(i));
					lastQueryTime[i] = time;
				}

				if (!g_bLeftSafeArea)
					continue;

				if (!IsPlayerAlive(i)) {
					if (g_esPlayer[i].respawnStartTime) {
						if ((interval = time - g_esPlayer[i].respawnStartTime) >= g_esPlayer[i].currentRespawnTime) {
							if (AttemptRespawnPZ(i)) {
								// PrintToConsole(i, "重生预设-> %d秒 实际耗时->%.5f秒", g_esPlayer[i].currentRespawnTime, interval);
								g_esPlayer[i].respawnStartTime = 0.0;
							}
							else {
								g_esPlayer[i].respawnStartTime = time + 5.0;
								CPrintToChat(i, "{red}复活失败 {default}将在{red}5秒{default}后继续尝试");
							}
						}
						else {
							if (time - lastCountDown[i] >= 1.0) {
								PrintCenterText(i, "%d 秒后重生", RoundToCeil(g_esPlayer[i].currentRespawnTime - interval));
								lastCountDown[i] = time;
							}
						}
					}
				}
				else {
					if (GetEntProp(i, Prop_Send, "m_zombieClass") != 8) {
						if (g_esPlayer[i].suicideStartTime && time - g_esPlayer[i].suicideStartTime >= g_iPZSuicideTime) {
							ForcePlayerSuicide(i);
							CPrintToChat(i, "{olive}特感玩家复活处死时间{default}-> {red}%d秒", g_iPZSuicideTime);
							// CPrintToChat(i, "{olive}处死预设{default}-> {red}%d秒 {olive}实际耗时{default}-> {red}%.5f秒", g_iPZSuicideTime, interval = time - g_esPlayer[i].suicideStartTime);
							g_esPlayer[i].suicideStartTime = 0.0;
						}
					}
					else if (!GetEntProp(i, Prop_Send, "m_isGhost")) {
						if (tankFrustrated[i] && GetEntProp(i, Prop_Send, "m_frustration") > 99 && GetEntityFlags(i) & FL_ONFIRE == 0) {
							// CTerrorPlayer::UpdateZombieFrustration(CTerrorPlayer *__hidden this)函数里面的原生方法
							Event event = CreateEvent("tank_frustrated", true);
							event.SetInt("userid", GetClientUserId(i));
							event.Fire(false);

							SDKCall(g_hSDK_CTerrorPlayer_ReplaceWithBot, i, false);
							SDKCall(g_hSDK_CTerrorPlayer_SetPreSpawnClass, i, 3);
							SDKCall(g_hSDK_CCSPlayer_State_Transition, i, 8);
						}
						else {
							tankFrustrated[i] = GetEntProp(i, Prop_Send, "m_frustration") > 99;
							// 这里延迟0.1秒等待系统自动掉控, 如果出了Bug系统没进行掉控操作, 则由插件进行
						}
					}
				}
			}
		}
	}

	#if BENCHMARK
	g_profiler.Stop();
	PrintToServer("ProfilerTime: %f", g_profiler.Time);
	#endif
	
	return Plugin_Continue;
}

// 与Silvers的[L4D & L4D2] Coop Markers - Flow Distance插件进行兼容 (https://forums.alliedmods.net/showthread.php?p=2682584)
void queryMpGamemode(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value) {
    if (result == ConVarQuery_Okay && GetClientFromSerial(value) == client && strcmp(cvarValue, "versus", false) != 0)
		g_cvGameMode.ReplicateToClient(client, "versus");
}

void Event_TankFrustrated(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (g_esPlayer[client].lastTeamID != 2 || IsFakeClient(client))
		return;

	if (g_iCmdEnterCooling & (1 << 1))
		g_esPlayer[client].lastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
	RequestFrame(NextFrame_ChangeTeamToSurvivor, GetClientUserId(client));
	CPrintToChat(client, "{green}★ {default}丢失 {olive}Tank控制权 {default}后自动切换回 {blue}生还者队伍");
}

void Event_PlayerBotReplace(Event event, const char[] name, bool dontBroadcast) {
	int botUID = event.GetInt("bot");
	int playerUID = event.GetInt("player");
	int bot = GetClientOfUserId(botUID);
	int player = GetClientOfUserId(playerUID);

	g_esPlayer[player].bot = botUID;
	g_esPlayer[bot].player = playerUID;

	if (GetClientTeam(bot) == 3 && GetEntProp(bot, Prop_Send, "m_zombieClass") == 8) {
		if (IsFakeClient(player))
			g_esPlayer[bot].tankBot = 1; // 防卡功能中踢出FakeClient后, 第二次触发Tank产生并替换原有的Tank(BOT替换BOT)
		else
			g_esPlayer[bot].tankBot = 2; // 主动或被动放弃Tank控制权(BOT替换玩家)
	}
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
		return;

	g_esPlayer[client].lastTeamID = 0;

	if (GetClientTeam(client) == 2) {
		int jockey = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
		if (jockey != -1)
			CheatCommand(jockey, "dismount", "");
	}
}

#define CD_TIME 30
Action tmrTankPlayer(Handle timer, int client) {
	static int i;
	static int times[MAXPLAYERS + 1] = {CD_TIME, ...};

	if ((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8 && GetEntProp(client, Prop_Send, "m_isGhost")) {
		i = times[client]--;
		if (i > 0)
			PrintHintText(client, "%d 秒后强制脱离灵魂状态", i);
		else if (i <= 0) {
			if (g_iCmdEnterCooling & (1 << 3))
				g_esPlayer[client].lastUsedTime = GetEngineTime() + g_fCmdCooldownTime;
			if (g_esPlayer[client].lastTeamID == 2)
				ChangeTeamToSur(client);
			else {
				SDKCall(g_hSDK_CTerrorPlayer_MaterializeFromGhost, client);
				SetEntPropFloat(client, Prop_Send, "m_flNextAttack", GetGameTime() + 5.0);
			}
			i = times[client] = CD_TIME;
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}

	i = times[client] = CD_TIME;
	return Plugin_Stop;
}

bool HasPZ() {
	static int i;
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 3)
			return true;
	}
	return false;
}

int _GetTeamCount(int team = -1) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && (team == -1 || GetClientTeam(i) == team))
			count++;
	}
	return count;
}

int GetTankCount(int filter = -1) {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
			continue;

		if (filter == -1 || !IsFakeClient(i) == view_as<bool>(filter))
			count++;
	}
	return count;
}

void TeleportToSurvivor(int client) {
	int target = 1;
	ArrayList aClients = new ArrayList(2);

	for (; target <= MaxClients; target++) {
		if (target == client || !IsClientInGame(target) || GetClientTeam(target) != 2 || !IsPlayerAlive(target))
			continue;
	
		aClients.Set(aClients.Push(!GetEntProp(target, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(target, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), target, 1);
	}

	if (!aClients.Length)
		target = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		target = aClients.Length - 1;
		target = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(target, 0)), target), 1);
	}

	delete aClients;

	if (target) {
		SetInvincibilityTime(client, 1.0);
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags")|FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(target, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
}

void SetInvincibilityTime(int client, float flDuration) {
	static int m_invulnerabilityTimer = -1;
	if (m_invulnerabilityTimer == -1)
		m_invulnerabilityTimer = FindSendPropInfo("CTerrorPlayer", "m_noAvoidanceTimer") - 12;

	SetEntDataFloat(client, m_invulnerabilityTimer + 4, flDuration);
	SetEntDataFloat(client, m_invulnerabilityTimer + 8, GetGameTime() + flDuration);
}

int FindUselessSurBot(bool bAlive) {
	int client;
	ArrayList aClients = new ArrayList(2);

	for (int i = MaxClients; i >= 1; i--) {
		if (!IsValidSurBot(i))
			continue;

		client = GetClientOfUserId(g_esPlayer[i].player);
		aClients.Set(aClients.Push(IsPlayerAlive(i) == bAlive ? (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 2 ? 0 : 1) : (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == 2 ? 2 : 3)), i, 1);
	}

	if (!aClients.Length)
		client = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		client = aClients.Length - 1;
		client = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(client, 0)), client), 1);
	}

	delete aClients;
	return client;
}

bool IsValidSurBot(int client) {
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == 2 && !GetIdlePlayerOfBot(client);
}

int GetBotOfIdlePlayer(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && GetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

int TakeOverTank(int tank) {
	int client = 1;
	ArrayList aClients = new ArrayList(2);

	bool allowSur = AllowSurTakeOver();
	for (; client <= MaxClients; client++) {
		if (!IsClientInGame(client) || IsFakeClient(client))
			continue;

		switch (GetClientTeam(client)) {
			case 2: {
				if (!allowSur)
					continue;

				if (g_esPlayer[client].isPlayerPB) {
					if (g_iLotTargetPlayer & (1 << 0))
						aClients.Set(aClients.Push(0), client, 1);
				}
				else if (g_iLotTargetPlayer & (1 << 1))
					aClients.Set(aClients.Push(1), client, 1);
			}

			case 3: {
				if (IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8)
					continue;
			
				if (g_esPlayer[client].isPlayerPB) {
					if (g_iLotTargetPlayer & (1 << 0))
						aClients.Set(aClients.Push(0), client, 1);
				}
				else if (g_iLotTargetPlayer & (1 << 2))
					aClients.Set(aClients.Push(1), client, 1);
			}
		}
	}

	if (!aClients.Length)
		client = 0;
	else {
		if (aClients.FindValue(0) != -1) {
			aClients.Sort(Sort_Descending, Sort_Integer);
			client = aClients.Get(Math_GetRandomInt(aClients.FindValue(0), aClients.Length - 1), 1);
		}
		else if (Math_GetRandomFloat(0.0, 1.0) < g_fSurvivorChance)
			client = aClients.Get(Math_GetRandomInt(0, aClients.Length - 1), 1);
		else
			client = 0;
	}

	delete aClients;

	if (client && GetNormalSur() >= g_iSurvivorLimit) {
		int team = GetClientTeam(client);
		switch (team) {
			case 2: {
				g_esData[client].Clean();
				g_esData[client].Save(client, false);
				ChangeClientTeam(client, 3);
			}
			
			case 3: {
				if (IsPlayerAlive(client)) {
					SDKCall(g_hSDK_CTerrorPlayer_CleanupPlayerState, client);
					ForcePlayerSuicide(client);
				}
			}
		}

		if (GetClientTeam(client) == 3)
			g_esPlayer[client].lastTeamID = team != 3 ? 2 : 3;
	
		if (TakeOverZombieBot(client, tank) == 8 && IsPlayerAlive(client))
			return client;
	}

	return 0;
}

int GetNormalSur() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsPinned(i))
			count++;
	}
	return count;
}

bool AllowSurTakeOver() {
	if (g_bSbAllBotGame || g_bAllowAllBotSur)
		return true;

	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
			count++;
	}
	return count > 1;
}

bool IsPinned(int client) {
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	return false;
}

void CreateSurGlow(int client) {
	if (!g_bGlowColorEnable || !IsRoundStarted() || !IsClientInGame(client) || IsClientInKickQueue(client) || GetClientTeam(client) != 2 || !IsPlayerAlive(client) || IsValidEntRef(g_esPlayer[client].modelEntRef))
		return;

	int iEnt = CreateEntityByName("prop_dynamic_ornament");
	if (iEnt == -1)
		return;

	g_esPlayer[client].modelEntRef = EntIndexToEntRef(iEnt);
	g_esPlayer[client].modelIndex = GetEntProp(client, Prop_Data, "m_nModelIndex");

	static char model[PLATFORM_MAX_PATH];
	GetClientModel(client, model, sizeof model);
	DispatchKeyValue(iEnt, "model", model);
	DispatchKeyValue(iEnt, "solid", "0");
	DispatchKeyValue(iEnt, "glowrange", "20000");
	DispatchKeyValue(iEnt, "glowrangemin", "1");
	DispatchKeyValue(iEnt, "rendermode", "10");
	DispatchSpawn(iEnt);

	// [L4D & L4D2] Hats (https://forums.alliedmods.net/showthread.php?t=153781)
	AcceptEntityInput(iEnt, "DisableCollision");
	SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 0);
	SetEntProp(iEnt, Prop_Send, "m_noGhostCollision", 1);
	SetEntProp(iEnt, Prop_Data, "m_usSolidFlags", 0x0004, 2);
	SetEntProp(iEnt, Prop_Data, "m_iEFlags", 0);
	SetEntProp(iEnt, Prop_Data, "m_fEffects", 0x020);	// don't draw entity
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", view_as<float>({0.0, 0.0, 0.0}));
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", view_as<float>({0.0, 0.0, 0.0}));

	SetGlowColor(client);
	AcceptEntityInput(iEnt, "StartGlowing");

	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetParent", client);
	SetVariantString("!activator");
	AcceptEntityInput(iEnt, "SetAttached", client);

	SDKHook(iEnt, SDKHook_SetTransmit, Hook_SetTransmit);
}

Action Hook_SetTransmit(int entity, int client) {
	if (!IsFakeClient(client) && GetClientTeam(client) == 3)
		return Plugin_Continue;

	return Plugin_Handled;
}

void SetGlowColor(int client) {
	static int type;
	if (GetEntProp(g_esPlayer[client].modelEntRef, Prop_Send, "m_glowColorOverride") != g_iGlowColor[(type = GetColorType(client))])
		SetEntProp(g_esPlayer[client].modelEntRef, Prop_Send, "m_glowColorOverride", g_iGlowColor[type]);
}

int GetColorType(int client) {
	if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= g_iSurvivorMaxInc)
		return 2;
	else {
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			return 1;
		else
			return GetEntPropFloat(client, Prop_Send, "m_itTimer", 1) > GetGameTime() ? 3 : 0;
	}
}

void RemoveSurGlow(int client) {
	static int iEnt;
	iEnt = g_esPlayer[client].modelEntRef;
	g_esPlayer[client].modelEntRef = 0;

	if (IsValidEntRef(iEnt))
		RemoveEntity(iEnt);
}

bool IsValidEntRef(int iEnt) {
	return iEnt && EntRefToEntIndex(iEnt) != -1;
}

// ------------------------------------------------------------------------------
// 切换回生还者
void NextFrame_ChangeTeamToSurvivor(int client) {
	if (g_iControlled == 1 || !(client = GetClientOfUserId(client)) || !IsClientInGame(client))
		return;

	ChangeTeamToSur(client);
}

void ChangeTeamToSur(int client) {
	int team = GetClientTeam(client);
	if (team == 2)
		return;

	// 防止因切换而导致正处于Ghost状态的坦克丢失
	if (GetEntProp(client, Prop_Send, "m_isGhost"))
		SetEntProp(client, Prop_Send, "m_isGhost", 0); // SDKCall(g_hSDK_CTerrorPlayer_MaterializeFromGhost, client);

	int bot = GetClientOfUserId(g_esPlayer[client].bot);
	if (!bot || !IsValidSurBot(bot))
		bot = FindUselessSurBot(true);

	if (team != 1)
		ChangeClientTeam(client, 1);

	if (bot) {
		SDKCall(g_hSDK_SurvivorBot_SetHumanSpectator, bot, client);
		SDKCall(g_hSDK_CTerrorPlayer_TakeOverBot, client, true);
	}
	else
		ChangeClientTeam(client, 2);

	if (IsRoundStarted()) {
		if (!IsPlayerAlive(client))
			RoundRespawn(client);

		TeleportToSurvivor(client);
	}

	g_esData[client].Restore(client, false);
	g_esData[client].Clean();
}

enum struct esData {
	int recorded;
	int character;
	int health;
	int tempHealth;
	int bufferTime;
	int reviveCount;
	int thirdStrike;
	int goingToDie;
	
	char model[PLATFORM_MAX_PATH];

	int clip0;
	int ammo;
	int upgrade;
	int upgradeAmmo;
	int weaponSkin0;
	int clip1;
	int weaponSkin1;
	bool dualWielding;

	char slot0[32];
	char slot1[32];
	char slot2[32];
	char slot3[32];
	char slot4[32];
	char active[32];

	// Save Weapon 4.3 (forked)(https://forums.alliedmods.net/showthread.php?p=2398822#post2398822)
	void Clean() {
		if (!this.recorded)
			return;
	
		this.recorded = 0;
		this.character = -1;
		this.reviveCount = 0;
		this.thirdStrike = 0;
		this.goingToDie = 0;
		this.health = 0;
		this.tempHealth = 0;
		this.bufferTime = 0;
	
		this.model[0] = '\0';

		this.clip0 = 0;
		this.ammo = 0;
		this.upgrade = 0;
		this.upgradeAmmo = 0;
		this.weaponSkin0 = 0;
		this.clip1 = -1;
		this.weaponSkin1 = 0;
		this.dualWielding = false;
	
		this.slot0[0] = '\0';
		this.slot1[0] = '\0';
		this.slot2[0] = '\0';
		this.slot3[0] = '\0';
		this.slot4[0] = '\0';
		this.active[0] = '\0';
	}

	void Save(int client, bool identity = true) {
		this.Clean();

		if (GetClientTeam(client) != 2)
			return;
		
		this.recorded = 1;

		if (identity) {
			this.character = GetEntProp(client, Prop_Send, "m_survivorCharacter");
			GetClientModel(client, this.model, sizeof esData::model);
		}

		if (!IsPlayerAlive(client)) {
			static ConVar cvZSurvivorRespa;
			if (!cvZSurvivorRespa)
				cvZSurvivorRespa = FindConVar("z_survivor_respawn_health");

			this.health = cvZSurvivorRespa.IntValue;
			return;
		}

		if (GetEntProp(client, Prop_Send, "m_isIncapacitated")) {
			if (!GetEntProp(client, Prop_Send, "m_isHangingFromLedge")) {
				static ConVar cvSurvivorReviveH;
				if (!cvSurvivorReviveH)
					cvSurvivorReviveH = FindConVar("survivor_revive_health");

				static ConVar cvSurvivorMaxInc;
				if (!cvSurvivorMaxInc)
					cvSurvivorMaxInc = FindConVar("survivor_max_incapacitated_count");

				this.health = 1;
				this.tempHealth = cvSurvivorReviveH.IntValue;
				this.bufferTime = 0;
				this.reviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount") + 1;
				this.thirdStrike = this.reviveCount >= cvSurvivorMaxInc.IntValue ? 1 : 0;
				this.goingToDie = 1;
			}
			else {
				static ConVar cvSurvivorIncapH;
				if (!cvSurvivorIncapH)
					cvSurvivorIncapH = FindConVar("survivor_incap_health");

				int m_preHangingHealth = GetEntData(client, g_iOff_m_preHangingHealth);													// 玩家挂边前的实血
				int m_preHangingHealthBuffer = GetEntData(client, g_iOff_m_preHangingHealthBuffer);										// 玩家挂边前的虚血
				int iPreTotal = m_preHangingHealth + m_preHangingHealthBuffer;															// 玩家挂边前的总血量
				int iRevivedTotal = RoundToFloor(GetEntProp(client, Prop_Data, "m_iHealth") / cvSurvivorIncapH.FloatValue * iPreTotal);	// 玩家挂边起身后的总血量

				int iDelta = iPreTotal - iRevivedTotal;
				if (m_preHangingHealthBuffer > iDelta) {
					this.health = m_preHangingHealth;
					this.tempHealth = m_preHangingHealthBuffer - iDelta;
				}
				else {
					this.health = m_preHangingHealth - (iDelta - m_preHangingHealthBuffer);
					this.tempHealth = 0;
				}

				this.bufferTime = 0;
				this.reviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
				this.thirdStrike = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
				this.goingToDie = GetEntProp(client, Prop_Send, "m_isGoingToDie");
			}
		}
		else {
			this.health = GetEntProp(client, Prop_Data, "m_iHealth");
			this.tempHealth = RoundToNearest(GetEntPropFloat(client, Prop_Send, "m_healthBuffer"));
			this.bufferTime = RoundToNearest(GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime"));
			this.reviveCount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
			this.thirdStrike = GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike");
			this.goingToDie = GetEntProp(client, Prop_Send, "m_isGoingToDie");
		}

		char sWeapon[32];
		int slot = GetPlayerWeaponSlot(client, 0);
		if (slot > MaxClients) {
			GetEntityClassname(slot, sWeapon, sizeof sWeapon);
			strcopy(this.slot0, sizeof esData::slot0, sWeapon);

			this.clip0 = GetEntProp(slot, Prop_Send, "m_iClip1");
			this.ammo = GetOrSetPlayerAmmo(client, slot);
			this.upgrade = GetEntProp(slot, Prop_Send, "m_upgradeBitVec");
			this.upgradeAmmo = GetEntProp(slot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
			this.weaponSkin0 = GetEntProp(slot, Prop_Send, "m_nSkin");
		}

		// Mutant_Tanks (https://github.com/Psykotikism/Mutant_Tanks)
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated")) {
			int iMelee = GetEntDataEnt2(client, g_iOff_m_hHiddenWeapon);
			switch (iMelee > MaxClients && IsValidEntity(iMelee)) {
				case true:
					slot = iMelee;

				case false:
					slot = GetPlayerWeaponSlot(client, 1);
			}
		}
		else
			slot = GetPlayerWeaponSlot(client, 1);

		if (slot > MaxClients) {
			GetEntityClassname(slot, sWeapon, sizeof sWeapon);
			if (strcmp(sWeapon[7], "melee") == 0)
				GetEntPropString(slot, Prop_Data, "m_strMapSetScriptName", sWeapon, sizeof sWeapon);
			else {
				if (strncmp(sWeapon[7], "pistol", 6) == 0 || strcmp(sWeapon[7], "chainsaw") == 0)
					this.clip1 = GetEntProp(slot, Prop_Send, "m_iClip1");

				this.dualWielding = strcmp(sWeapon[7], "pistol") == 0 && GetEntProp(slot, Prop_Send, "m_isDualWielding");
			}

			strcopy(this.slot1, sizeof esData::slot1, sWeapon);
			this.weaponSkin1 = GetEntProp(slot, Prop_Send, "m_nSkin");
		}

		slot = GetPlayerWeaponSlot(client, 2);
		if (slot > MaxClients && (slot != GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon") || GetEntPropFloat(slot, Prop_Data, "m_flNextPrimaryAttack") < GetGameTime())) {	//Method from HarryPotter (https://forums.alliedmods.net/showpost.php?p=2768411&postcount=5)
			GetEntityClassname(slot, sWeapon, sizeof sWeapon);
			strcopy(this.slot2, sizeof esData::slot2, sWeapon);
		}

		slot = GetPlayerWeaponSlot(client, 3);
		if (slot > MaxClients) {
			GetEntityClassname(slot, sWeapon, sizeof sWeapon);
			strcopy(this.slot3, sizeof esData::slot3, sWeapon);
		}

		slot = GetPlayerWeaponSlot(client, 4);
		if (slot > MaxClients) {
			GetEntityClassname(slot, sWeapon, sizeof sWeapon);
			strcopy(this.slot4, sizeof esData::slot4, sWeapon);
		}
	
		slot = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (slot > MaxClients) {
			GetEntityClassname(slot, sWeapon, sizeof sWeapon);
			strcopy(this.active, sizeof esData::active, sWeapon);
		}
	}

	void Restore(int client, bool identity = true) {
		if (!this.recorded)
			return;

		if (GetClientTeam(client) != 2)
			return;

		if (identity) {
			if (this.character != -1)
				SetEntProp(client, Prop_Send, "m_survivorCharacter", this.character);

			if (this.model[0] != '\0')
				SetEntityModel(client, this.model);
		}
		
		if (!IsPlayerAlive(client)) 
			return;

		if (GetEntProp(client, Prop_Send, "m_isIncapacitated"))
			SDKCall(g_hSDK_CTerrorPlayer_OnRevived, client); //SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);

		SetEntProp(client, Prop_Send, "m_iHealth", this.health);
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 1.0 * this.tempHealth);
		SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime() - 1.0 * this.bufferTime);
		SetEntProp(client, Prop_Send, "m_currentReviveCount", this.reviveCount);
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", this.thirdStrike);
		SetEntProp(client, Prop_Send, "m_isGoingToDie", this.goingToDie);

		if (!GetEntProp(client, Prop_Send, "m_bIsOnThirdStrike"))
			StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");

		int slot;
		int weapon;
		for (; slot < 5; slot++) {
			if ((weapon = GetPlayerWeaponSlot(client, slot)) > MaxClients) {
				RemovePlayerItem(client, weapon);
				RemoveEntity(weapon);
			}
		}

		bool given;
		if (this.slot0[0] != '\0') {
			GivePlayerItem(client, this.slot0);	//CheatCommand(client, "give", this.slot0);

			slot = GetPlayerWeaponSlot(client, 0);
			if (slot > MaxClients) {
				SetEntProp(slot, Prop_Send, "m_iClip1", this.clip0);
				GetOrSetPlayerAmmo(client, slot, this.ammo);

				if (this.upgrade > 0)
					SetEntProp(slot, Prop_Send, "m_upgradeBitVec", this.upgrade);

				if (this.upgradeAmmo > 0)
					SetEntProp(slot, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", this.upgradeAmmo);
				
				if (this.weaponSkin0 > 0)
					SetEntProp(slot, Prop_Send, "m_nSkin", this.weaponSkin0);
				
				given = true;
			}
		}

		if (this.slot1[0] != '\0') {
			switch (this.dualWielding) {
				case true: {
					GivePlayerItem(client, "weapon_pistol");	//CheatCommand(client, "give", "weapon_pistol");
					GivePlayerItem(client, "weapon_pistol");	//CheatCommand(client, "give", "weapon_pistol");
				}

				case false:
					GivePlayerItem(client, this.slot1);	//CheatCommand(client, "give", this.slot1);
			}

			slot = GetPlayerWeaponSlot(client, 1);
			if (slot > MaxClients) {
				if (this.clip1 != -1)
					SetEntProp(slot, Prop_Send, "m_iClip1", this.clip1);
				
				if (this.weaponSkin1 > 0)
					SetEntProp(slot, Prop_Send, "m_nSkin", this.weaponSkin1);
				
				given = true;
			}
		}

		if (this.slot2[0] != '\0') {
			GivePlayerItem(client, this.slot2);	//CheatCommand(client, "give", this.slot2);

			if (GetPlayerWeaponSlot(client, 2) > MaxClients)
				given = true;
		}

		if (this.slot3[0] != '\0') {
			GivePlayerItem(client, this.slot3);	//CheatCommand(client, "give", this.slot3);
	
			if (GetPlayerWeaponSlot(client, 3) > MaxClients)
				given = true;
		}

		if (this.slot4[0] != '\0') {
			GivePlayerItem(client, this.slot4);	//CheatCommand(client, "give", this.slot4);
	
			if (GetPlayerWeaponSlot(client, 4) > MaxClients)
				given = true;
		}
		
		if (given) {
			if (this.active[0] != '\0')
				FakeClientCommand(client, "use %s", this.active);
		}
		else
			GivePlayerItem(client, "weapon_pistol");	//CheatCommand(client, "give", "weapon_pistol");
	}
}

void CheatCommand(int client, const char[] command, const char[] arguments = "") {
	int bits = GetUserFlagBits(client);
	int flags = GetCommandFlags(command);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetUserFlagBits(client, bits);
	SetCommandFlags(command, flags);
}

int GetOrSetPlayerAmmo(int client, int weapon, int ammo = -1) {
	int m_iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (m_iPrimaryAmmoType != -1) {
		if (ammo != -1)
			SetEntProp(client, Prop_Send, "m_iAmmo", ammo, _, m_iPrimaryAmmoType);
		else
			return GetEntProp(client, Prop_Send, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	return 0;
}

// https://github.com/brxce/hardcoop/blob/master/addons/sourcemod/scripting/modules/SS_SpawnQueue.sp
bool AttemptRespawnPZ(int client) {
	int i = 1;
	int count;
	int class;
	int spawnCounts[6];
	for (; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsClientInKickQueue(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && 1 <= (class = GetEntProp(i, Prop_Send, "m_zombieClass")) <= 6) {
			count++;
			spawnCounts[class - 1]++;
		}
	}

	if (count >= g_iSILimit) {
		CPrintToChat(client, "{olive}当前存活特感数量{default}-> {red}%d {olive}达到设置总数上限{default}-> {red}%d {olive}将以随机特感类型复活", count, g_iSILimit);
		return RespawnPZ(client, Math_GetRandomInt(1, 6));
	}

	int totalWeight;
	int standardizedWeight;
	int tempSpawnWeights[6];
	for (i = 0; i < 6; i++) {
		tempSpawnWeights[i] = spawnCounts[i] < g_iSpawnLimits[i] ? (g_bScaleWeights ? ((g_iSpawnLimits[i] - spawnCounts[i]) * g_iSpawnWeights[i]) : g_iSpawnWeights[i]) : 0;
		totalWeight += tempSpawnWeights[i];
	}

	static float intervalEnds[6];
	float unit = 1.0 / totalWeight;
	for (i = 0; i < 6; i++) {
		if (tempSpawnWeights[i] < 0)
			continue;

		standardizedWeight += tempSpawnWeights[i];
		intervalEnds[i] = standardizedWeight * unit;
	}

	class = -1;
	float random = Math_GetRandomFloat(0.0, 1.0);
	for (i = 0; i < 6; i++) {
		if (tempSpawnWeights[i] <= 0)
			continue;

		if (intervalEnds[i] < random)
			continue;

		class = i;
		break;
	}

	if (class == -1) {
		CPrintToChat(client, "当前无满足要求的特感类型可供复活, 将以随机特感类型复活");
		return RespawnPZ(client, Math_GetRandomInt(1, 6));
	}

	return RespawnPZ(client, class + 1);
}

bool RespawnPZ(int client, int zombieClass) {
	SDKCall(g_hSDK_CTerrorPlayer_SetPreSpawnClass, client, zombieClass);
	SDKCall(g_hSDK_CCSPlayer_State_Transition, client, 8);
	return IsPlayerAlive(client);
}

// ------------------------------------------------------------------------------
//SDKCall
void InitData() {
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iOff_m_hHiddenWeapon = hGameData.GetOffset("CTerrorPlayer::OnIncapacitatedAsSurvivor::m_hHiddenWeapon");
	if (g_iOff_m_hHiddenWeapon == -1)
		SetFailState("Failed to find offset: \"CTerrorPlayer::OnIncapacitatedAsSurvivor::m_hHiddenWeapon\"");

	g_iOff_m_preHangingHealth = hGameData.GetOffset("CTerrorPlayer::OnRevived::m_preHangingHealth");
	if (g_iOff_m_preHangingHealth == -1)
		SetFailState("Failed to find offset: \"CTerrorPlayer::OnRevived::m_preHangingHealth\"");

	g_iOff_m_preHangingHealthBuffer = hGameData.GetOffset("CTerrorPlayer::OnRevived::m_preHangingHealthBuffer");
	if (g_iOff_m_preHangingHealthBuffer == -1)
		SetFailState("Failed to find offset: \"CTerrorPlayer::OnRevived::m_preHangingHealthBuffer\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::OnRevived"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::OnRevived\"");
	g_hSDK_CTerrorPlayer_OnRevived = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_OnRevived)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::OnRevived\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::IsInStasis")) // https://forums.alliedmods.net/showthread.php?t=302140
		SetFailState("Failed to find offset: \"CBaseEntity::IsInStasis\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CBaseEntity_IsInStasis = EndPrepSDKCall();
	if (!g_hSDK_CBaseEntity_IsInStasis)
		SetFailState("Failed to create SDKCall: \"CBaseEntity::IsInStasis\"");
	
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "Tank::LeaveStasis")) // https://forums.alliedmods.net/showthread.php?t=319342
		SetFailState("Failed to find signature: \"Tank::LeaveStasis\"");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_Tank_LeaveStasis = EndPrepSDKCall();
	if (!g_hSDK_Tank_LeaveStasis)
		SetFailState("Failed to create SDKCall: \"Tank::LeaveStasis\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CCSPlayer::State_Transition"))
		SetFailState("Failed to find signature: \"CCSPlayer::State_Transition\"");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_CCSPlayer_State_Transition = EndPrepSDKCall();
	if (!g_hSDK_CCSPlayer_State_Transition)
		SetFailState("Failed to create SDKCall: \"CCSPlayer::State_Transition\"");
		
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::MaterializeFromGhost"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::MaterializeFromGhost\"");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_CTerrorPlayer_MaterializeFromGhost = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_MaterializeFromGhost)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::MaterializeFromGhost\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::SetClass"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::SetClass\"");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_CTerrorPlayer_SetClass = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_SetClass)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::SetClass\"");
	
	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CBaseAbility::CreateForPlayer"))
		SetFailState("Failed to find signature: \"CBaseAbility::CreateForPlayer\"");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDK_CBaseAbility_CreateForPlayer = EndPrepSDKCall();
	if (!g_hSDK_CBaseAbility_CreateForPlayer)
		SetFailState("Failed to create SDKCall: \"CBaseAbility::CreateForPlayer\"");
	
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::CleanupPlayerState"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::CleanupPlayerState\"");
	g_hSDK_CTerrorPlayer_CleanupPlayerState = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_CleanupPlayerState)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::CleanupPlayerState\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverZombieBot"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::TakeOverZombieBot\"");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDK_CTerrorPlayer_TakeOverZombieBot = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_TakeOverZombieBot)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::TakeOverZombieBot\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::ReplaceWithBot"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::ReplaceWithBot\"");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CTerrorPlayer_ReplaceWithBot= EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_ReplaceWithBot)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::ReplaceWithBot\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::SetPreSpawnClass"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::SetPreSpawnClass\"");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDK_CTerrorPlayer_SetPreSpawnClass = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_SetPreSpawnClass)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::SetPreSpawnClass\"");
	
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::RoundRespawn\"");
	g_hSDK_CTerrorPlayer_RoundRespawn = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_RoundRespawn)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::RoundRespawn\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::SetHumanSpectator"))
		SetFailState("Failed to find signature: \"SurvivorBot::SetHumanSpectator\"");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	g_hSDK_SurvivorBot_SetHumanSpectator = EndPrepSDKCall();
	if (!g_hSDK_SurvivorBot_SetHumanSpectator)
		SetFailState("Failed to create SDKCall: \"SurvivorBot::SetHumanSpectator\"");

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverBot"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::TakeOverBot\"");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CTerrorPlayer_TakeOverBot = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_TakeOverBot)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::TakeOverBot\"");

	StartPrepSDKCall(SDKCall_GameRules);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::IsMissionFinalMap"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::IsMissionFinalMap\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CTerrorGameRules_IsMissionFinalMap = EndPrepSDKCall();
	if (!g_hSDK_CTerrorGameRules_IsMissionFinalMap)
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::IsMissionFinalMap\"");

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::HasPlayerControlledZombies"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::HasPlayerControlledZombies\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDK_CTerrorGameRules_HasPlayerControlledZombies = EndPrepSDKCall();
	if (!g_hSDK_CTerrorGameRules_HasPlayerControlledZombies)
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::HasPlayerControlledZombies\"");

	#if DEBUG
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::PlayerZombieAbortControl"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::PlayerZombieAbortControl\"");
	g_hSDK_CTerrorPlayer_PlayerZombieAbortControl = EndPrepSDKCall();
	if (!g_hSDK_CTerrorPlayer_PlayerZombieAbortControl)
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::PlayerZombieAbortControl\"");
	#endif

	InitPatchs(hGameData);
	SetupDetours(hGameData);

	delete hGameData;
}

void InitPatchs(GameData hGameData = null) {
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if (iOffset == -1)
		SetFailState("Failed to find offset: \"RoundRespawn_Offset\"");

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if (iByteMatch == -1)
		SetFailState("Failed to find byte: \"RoundRespawn_Byte\"");

	g_pStatsCondition = hGameData.GetMemSig("CTerrorPlayer::RoundRespawn");
	if (!g_pStatsCondition)
		SetFailState("Failed to find address: \"CTerrorPlayer::RoundRespawn\"");

	g_pStatsCondition += view_as<Address>(iOffset);
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if (iByteOrigin != iByteMatch)
		SetFailState("Failed to load \"CTerrorPlayer::RoundRespawn\", byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
}

void SetupDetours(GameData hGameData = null) {
	g_ddCTerrorPlayer_OnEnterGhostState = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::OnEnterGhostState");
	if (!g_ddCTerrorPlayer_OnEnterGhostState)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::OnEnterGhostState\"");

	g_ddCTerrorPlayer_MaterializeFromGhost = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::MaterializeFromGhost");
	if (!g_ddCTerrorPlayer_MaterializeFromGhost)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::MaterializeFromGhost\"");

	g_ddCTerrorPlayer_PlayerZombieAbortControl = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::PlayerZombieAbortControl");
	if (!g_ddCTerrorPlayer_PlayerZombieAbortControl)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::PlayerZombieAbortControl\"");

	//Method from MicroLeo (https://forums.alliedmods.net/showthread.php?t=329183)
	Address pAddr = hGameData.GetMemSig("ForEachTerrorPlayer<SpawnablePZScan>");
	if (!pAddr)
		SetFailState("Failed to find address: \"ForEachTerrorPlayer<SpawnablePZScan>\" in \"z_spawn_old(CCommand const&)\"");
	if (!hGameData.GetOffset("OS")) {
		Address offset = view_as<Address>(LoadFromAddress(pAddr + view_as<Address>(1), NumberType_Int32));	// (addr+5) + *(addr+1) = call function addr
		if (!offset)
			SetFailState("Failed to find address: \"ForEachTerrorPlayer<SpawnablePZScan>\"");

		pAddr += offset + view_as<Address>(5); // sizeof(instruction)
	}

	g_ddForEachTerrorPlayer_SpawnablePZScan = new DynamicDetour(pAddr, CallConv_CDECL, ReturnType_Void, ThisPointer_Ignore);
	if (!g_ddForEachTerrorPlayer_SpawnablePZScan)
		SetFailState("Failed to create DynamicDetour: \"ForEachTerrorPlayer<SpawnablePZScan>\"");

	g_ddForEachTerrorPlayer_SpawnablePZScan.AddParam(HookParamType_CBaseEntity);
}

void EnterGhostMode(int client, bool savePos = false) {
	if (GetClientTeam(client) == 3 && !GetEntProp(client, Prop_Send, "m_isGhost")) {
		float vPos[3];
		float vAng[3];
		float vVel[3];
		if (savePos) {
			GetClientAbsOrigin(client, vPos);
			GetClientEyeAngles(client, vAng);
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		}

		SDKCall(g_hSDK_CCSPlayer_State_Transition, client, 8);
		if (savePos)
			TeleportEntity(client, vPos, vAng, vVel);
	}
}

void SetZombieClass(int client, int zombieClass) {
	int weapon = GetPlayerWeaponSlot(client, 0);
	if (weapon > MaxClients) {
		RemovePlayerItem(client, weapon);
		RemoveEntity(weapon);
	}

	int ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	if (ability > MaxClients)
		RemoveEntity(ability);

	SDKCall(g_hSDK_CTerrorPlayer_SetClass, client, zombieClass);
	ability = SDKCall(g_hSDK_CBaseAbility_CreateForPlayer, client);
	if (ability > MaxClients)
		SetEntPropEnt(client, Prop_Send, "m_customAbility", ability);
}

int TakeOverZombieBot(int client, int target) {
	AcceptEntityInput(client, "ClearParent");
	SDKCall(g_hSDK_CTerrorPlayer_TakeOverZombieBot, client, target);
	return GetEntProp(client, Prop_Send, "m_zombieClass");
}

void RoundRespawn(int client) {
	StatsConditionPatch(true);
	SDKCall(g_hSDK_CTerrorPlayer_RoundRespawn, client);
	StatsConditionPatch(false);
}

// https://forums.alliedmods.net/showthread.php?t=323220
void StatsConditionPatch(bool patch) {
	static bool patched;
	if (!patched && patch) {
		patched = true;
		StoreToAddress(g_pStatsCondition, 0xEB, NumberType_Int8);
	}
	else if (patched && !patch) {
		patched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}

void ToggleDetours(bool enable) {
	static bool enabled;
	if (!enabled && enable) {
		enabled = true;

		if (!g_ddCTerrorPlayer_OnEnterGhostState.Enable(Hook_Pre, DD_CTerrorPlayer_OnEnterGhostState_Pre))
			SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::OnEnterGhostState\"");
		
		if (!g_ddCTerrorPlayer_OnEnterGhostState.Enable(Hook_Post, DD_CTerrorPlayer_OnEnterGhostState_Post))
			SetFailState("Failed to detour post: \"DD::CTerrorPlayer::OnEnterGhostState\"");
			
		if (!g_ddCTerrorPlayer_MaterializeFromGhost.Enable(Hook_Pre, DD_CTerrorPlayer_MaterializeFromGhost_Pre))
			SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::MaterializeFromGhost\"");
		
		if (!g_ddCTerrorPlayer_MaterializeFromGhost.Enable(Hook_Post, DD_CTerrorPlayer_MaterializeFromGhost_Post))
			SetFailState("Failed to detour post: \"DD::CTerrorPlayer::MaterializeFromGhost\"");
			
		if (!g_ddCTerrorPlayer_PlayerZombieAbortControl.Enable(Hook_Pre, DD_CTerrorPlayer_PlayerZombieAbortControl_Pre))
			SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::PlayerZombieAbortControl\"");
		
		if (!g_ddCTerrorPlayer_PlayerZombieAbortControl.Enable(Hook_Post, DD_CTerrorPlayer_PlayerZombieAbortControl_Post))
			SetFailState("Failed to detour post: \"DD::CTerrorPlayer::PlayerZombieAbortControl\"");

		if (!g_ddForEachTerrorPlayer_SpawnablePZScan.Enable(Hook_Pre, DD_ForEachTerrorPlayer_SpawnablePZScan_Pre))
			SetFailState("Failed to detour pre: \"ForEachTerrorPlayer<SpawnablePZScan>\"");

		if (!g_ddForEachTerrorPlayer_SpawnablePZScan.Enable(Hook_Post, DD_ForEachTerrorPlayer_SpawnablePZScan_Post))
			SetFailState("Failed to detour post: \"ForEachTerrorPlayer<SpawnablePZScan>\"");
	}
	else if (enabled && !enable) {
		enabled = false;

		if (!g_ddCTerrorPlayer_OnEnterGhostState.Disable(Hook_Pre, DD_CTerrorPlayer_OnEnterGhostState_Pre) || !g_ddCTerrorPlayer_OnEnterGhostState.Disable(Hook_Post, DD_CTerrorPlayer_OnEnterGhostState_Post))
			SetFailState("Failed to disable detour: \"DD::CTerrorPlayer::OnEnterGhostState\"");
		
		if (!g_ddCTerrorPlayer_MaterializeFromGhost.Disable(Hook_Pre, DD_CTerrorPlayer_MaterializeFromGhost_Pre) || !g_ddCTerrorPlayer_MaterializeFromGhost.Disable(Hook_Post, DD_CTerrorPlayer_MaterializeFromGhost_Post))
			SetFailState("Failed to disable detour: \"DD::CTerrorPlayer::MaterializeFromGhost\"");
		
		if (!g_ddCTerrorPlayer_PlayerZombieAbortControl.Disable(Hook_Pre, DD_CTerrorPlayer_PlayerZombieAbortControl_Pre) || !g_ddCTerrorPlayer_PlayerZombieAbortControl.Disable(Hook_Post, DD_CTerrorPlayer_PlayerZombieAbortControl_Post))
			SetFailState("Failed to disable detour: \"DD::CTerrorPlayer::PlayerZombieAbortControl\"");

		if (!g_ddForEachTerrorPlayer_SpawnablePZScan.Disable(Hook_Pre, DD_ForEachTerrorPlayer_SpawnablePZScan_Pre) || !g_ddForEachTerrorPlayer_SpawnablePZScan.Disable(Hook_Post, DD_ForEachTerrorPlayer_SpawnablePZScan_Post))
			SetFailState("Failed to disable detour: \"DD_ForEachTerrorPlayer<SpawnablePZScan>\"");
	}
}

MRESReturn DD_CTerrorPlayer_OnEnterGhostState_Pre(int pThis) {
	if (!IsRoundStarted())
		return MRES_Supercede; // 阻止死亡状态下的特感玩家在团灭后下一回合开始前进入Ghost State
	
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_OnEnterGhostState_Post(int pThis) {
	if (IsFakeClient(pThis) || !GetEntProp(pThis, Prop_Send, "m_isGhost"))
		return MRES_Ignored;

	if (GetEntProp(pThis, Prop_Send, "m_zombieClass") == 8)
		g_esPlayer[pThis].bugExploitTime[1] = GetGameTime() + 3.0;

	if (g_esPlayer[pThis].materialized == 0)
		RequestFrame(NextFrame_EnterGhostState, GetClientUserId(pThis));
	
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_MaterializeFromGhost_Pre(int pThis) {
	g_bOnMaterializeFromGhost = true;

	if (!IsFakeClient(pThis) && g_esPlayer[pThis].bugExploitTime[1] > GetGameTime())
		return MRES_Supercede;

	#if DEBUG
	if (g_bLeft4Dhooks) {
		if (GetEntProp(pThis, Prop_Send, "m_zombieClass") != 1)
			return MRES_Ignored;

		static float vPos[3];
		GetClientAbsOrigin(pThis, vPos);
		if (L4D_GetLastKnownArea(pThis) != L4D_GetNearestNavArea(vPos, 300.0, false, false, false, 2)) {
			SDKCall(g_hSDK_CTerrorPlayer_PlayerZombieAbortControl, pThis);
			CPrintToChat(pThis, "{red}这里是受限制区域!");
			return MRES_Supercede;
		}
	}
	#endif

	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_MaterializeFromGhost_Post(int pThis) {
	g_bOnMaterializeFromGhost = false;

	if (GetEntProp(pThis, Prop_Send, "m_isGhost"))
		return MRES_Ignored;

	g_esPlayer[pThis].materialized++;

	if (!IsFakeClient(pThis)) {
		g_esPlayer[pThis].bugExploitTime[0] = GetGameTime() + 1.5;
		if (g_esPlayer[pThis].materialized == 1 && g_iPZRespawnTime > 0 && g_iPZPunishTime > 0 && g_esPlayer[pThis].classCmdUsed && GetEntProp(pThis, Prop_Send, "m_zombieClass") != 8)
			CPrintToChat(pThis, "{olive}下次重生时间 {default}-> {red}+%d秒", g_iPZPunishTime);
	}

	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_PlayerZombieAbortControl_Pre(int pThis) {
	if (!IsFakeClient(pThis) && g_esPlayer[pThis].bugExploitTime[0] > GetGameTime())
		return MRES_Supercede;

	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_PlayerZombieAbortControl_Post(int pThis) {
	if (IsFakeClient(pThis) || !GetEntProp(pThis, Prop_Send, "m_isGhost"))
		return MRES_Ignored;

	g_esPlayer[pThis].bugExploitTime[1] = GetGameTime() + 1.5;
	return MRES_Ignored;
}

MRESReturn DD_ForEachTerrorPlayer_SpawnablePZScan_Pre(DHookParam hParams) {
	/*StoreToAddress(hParams.GetAddress(1), !g_iSpawnablePZ || !IsClientInGame(g_iSpawnablePZ) || IsFakeClient(g_iSpawnablePZ) || GetClientTeam(g_iSpawnablePZ) != 3 ? 0 : view_as<int>(GetEntityAddress(g_iSpawnablePZ)), NumberType_Int32);
	return MRES_Supercede;*/
	SpawnablePZScan(true);
	return MRES_Ignored;
}

MRESReturn DD_ForEachTerrorPlayer_SpawnablePZScan_Post(DHookParam hParams) {
	SpawnablePZScan(false);
	return MRES_Ignored;
}

void NextFrame_EnterGhostState(int client) {
	if (g_iControlled == 0 && (client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") != 8 && GetEntProp(client, Prop_Send, "m_isGhost")) {
		if (g_esPlayer[client].enteredGhost == 0) {
			if (CheckClientAccess(client, 0))
				CPrintToChat(client, "{default}聊天栏输入 {olive}!team2 {default}可切换回{blue}生还者");
				
			if (CheckClientAccess(client, 5))
				CPrintToChat(client, "{red}灵魂状态下{default} 按下 {red}[鼠标中键] {default}可以快速切换特感");
		}

		DelaySelectClass(client);
		g_esPlayer[client].enteredGhost++;
	
		if (g_iPZSuicideTime > 0)
			g_esPlayer[client].suicideStartTime = GetEngineTime();
	}
}

void DelaySelectClass(int client) {
	if ((g_iAutoDisplayMenu == -1 || g_esPlayer[client].enteredGhost < g_iAutoDisplayMenu) && CheckClientAccess(client, 5)) {
		DisplayClassMenu(client);
		EmitSoundToClient(client, SOUND_CLASSMENU, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}
}

void SpawnablePZScan(bool protect) {
	static int i;
	static bool ghost[MAXPLAYERS + 1];
	static bool lifeState[MAXPLAYERS + 1];

	switch(protect) {
		case true:  {
			for (i = 1; i <= MaxClients; i++) {
				if (i == g_iSpawnablePZ || !IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != 3)
					continue;

				if (GetEntProp(i, Prop_Send, "m_isGhost")) {
					ghost[i] = true;
					SetEntProp(i, Prop_Send, "m_isGhost", 0);
				}
				else if (!IsPlayerAlive(i)) {
					lifeState[i] = true;
					SetEntProp(i, Prop_Send, "m_lifeState", 0);
				}
			}
		}

		case false:  {
			for (i = 1; i <= MaxClients; i++) {
				if (ghost[i])
					SetEntProp(i, Prop_Send, "m_isGhost", 1);

				if (lifeState[i])
					SetEntProp(i, Prop_Send, "m_lifeState", 1);
			
				ghost[i] = false;
				lifeState[i] = false;
			}
		}
	}
}

// https://github.com/bcserv/smlib/blob/transitional_syntax/scripting/include/smlib/math.inc
/**
 * Returns a random, uniform Integer number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 * Rewritten by MatthiasVance, thanks.
 *
 * @param min			Min value used as lower border
 * @param max			Max value used as upper border
 * @return				Random Integer number between min and max
 */
int Math_GetRandomInt(int min, int max) {
	int random = GetURandomInt();
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(2147483647) / float(max - min + 1))) + min - 1;
}

/**
 * Returns a random, uniform Float number in the specified (inclusive) range.
 * This is safe to use multiple times in a function.
 * The seed is set automatically for each plugin.
 *
 * @param min			Min value used as lower border
 * @param max			Max value used as upper border
 * @return				Random Float number between min and max
 */
float Math_GetRandomFloat(float min, float max) {
	return (GetURandomFloat() * (max  - min)) + min;
}
