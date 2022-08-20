#pragma tabsize 1
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define DEBUG 0
#define BENCHMARK	0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

#define GAMEDATA	"specialspawner"

#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5

#define SPAWN_NO_PREFERENCE					   -1
#define SPAWN_ANYWHERE							0
#define SPAWN_BEHIND_SURVIVORS					1
#define SPAWN_NEAR_IT_VICTIM					2
#define SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS	3
#define SPAWN_SPECIALS_ANYWHERE					4
#define SPAWN_FAR_AWAY_FROM_SURVIVORS			5
#define SPAWN_ABOVE_SURVIVORS					6
#define SPAWN_IN_FRONT_OF_SURVIVORS				7
#define SPAWN_VERSUS_FINALE_DISTANCE			8
#define SPAWN_LARGE_VOLUME						9
#define SPAWN_NEAR_POSITION						10

ArrayList
	g_aSpawnQueue;

Handle
	g_hSpawnTimer,
	g_hRetrySpawnTimer,
	g_hForceSuicideTimer,
	g_hSDK_TerrorNavArea_FindRandomSpot,
	g_hSDK_IsVisibleToPlayer,
	//g_hSDK_TerrorNavArea_IsEntirelyVisible,
	g_hSDK_TerrorNavArea_IsPartiallyVisible;

enum struct SurData
{
	float flow;
	float vPos[3];
}

enum struct SpawnData
{
	float fDist;
	float vPos[3];
}

ArrayList
	g_aSurData,
	g_aSpawnData;

ConVar
	g_hSILimit,
	g_hSpawnSize,
	g_hSpawnLimits[6],
	g_hSpawnWeights[6],
	g_hScaleWeights,
	g_hSpawnTimeMode,
	g_hSpawnTimeMin,
	g_hSpawnTimeMax,
	g_hSIbase,
	g_hSIextra,
	g_hGroupbase,
	g_hGroupextra,
	g_hRusherDistance,
	g_hTankSpawnAction,
	g_hTankSpawnLimits,
	g_hTankSpawnWeights,
	g_hForceSuicideTime,
	g_hSpawnRange,
	g_hDiscardRange;

float
	g_fSpawnTimeMin,
	g_fSpawnTimeMax,
	g_fRusherDistance,
	g_fForceSuicideTime,
	g_fSpawnTimes[MAXPLAYERS + 1],
	g_fSpecialActionTime[MAXPLAYERS + 1];

static const char
	g_sZombieClass[6][] =
	{
		"smoker",
		"boomer",
		"hunter",
		"spitter",
		"jockey",
		"charger"
	};

int
	g_iSILimit,
	g_iSpawnSize,
	g_iSpawnLimits[6],
	g_iSpawnWeights[6],
	g_iSpawnTimeMode,
	g_iTankSpawnAction,
	g_iPreferredDirection,
	g_iSILimitCache = -1,
	g_iSpawnLimitsCache[6] =
	{	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iSpawnWeightsCache[6] =
	{
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iTankSpawnLimits[6] =
	{	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iTankSpawnWeights[6] =
	{	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iSpawnSizeCache = -1,
	g_iSpawnCounts[6],
	g_iSIbase,
	g_iSIextra,
	g_iGroupbase,
	g_iGroupextra,
	g_iCurrentClass = -1,
	g_iMaxSurData,
	g_iOff_NavCount,
	g_iOff_m_flow,
	g_iOff_m_attributeFlags,
	g_iOff_m_spawnAttributes;

bool
	g_bLateLoad,
	g_bInSpawnTime,
	g_bScaleWeights,
	g_bLeftSafeArea;

TheNavAreas
	g_pTheNavAreas;

ArrayList
	g_aAreas;

bool
	g_bIsFinalMap;

float
	g_fSpawnDist;

public Plugin myinfo =
{
	name = "Special Spawner",
	author = "Tordecybombo, breezy",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "1.3.4",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	vInitData();
	g_aSpawnQueue = new ArrayList();
	g_aAreas = new ArrayList(2);
	g_aSurData = new ArrayList(sizeof SurData);
	g_aSpawnData = new ArrayList(sizeof SpawnData);

	g_hSILimit = CreateConVar("ss_si_limit", "12", "同时存在的最大特感数量", _, true, 1.0, true, 32.0);
	g_hSpawnSize = CreateConVar("ss_spawn_size", "4", "一次产生多少只特感", _, true, 1.0, true, 32.0);
	g_hSpawnLimits[SI_SMOKER] = CreateConVar("ss_smoker_limit",	"2", "同时存在的最大smoker数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_BOOMER] = CreateConVar("ss_boomer_limit",	"2", "同时存在的最大boomer数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_HUNTER] = CreateConVar("ss_hunter_limit",	"4", "同时存在的最大hunter数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_SPITTER] = CreateConVar("ss_spitter_limit", "2", "同时存在的最大spitter数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_JOCKEY] = CreateConVar("ss_jockey_limit",	"4", "同时存在的最大jockey数量", _, true, 0.0, true, 32.0);
	g_hSpawnLimits[SI_CHARGER] = CreateConVar("ss_charger_limit", "4", "同时存在的最大charger数量", _, true, 0.0, true, 32.0);

	g_hSpawnWeights[SI_SMOKER] = CreateConVar("ss_smoker_weight", "80", "smoker产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_BOOMER] = CreateConVar("ss_boomer_weight", "125", "boomer产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_HUNTER] = CreateConVar("ss_hunter_weight", "100", "hunter产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_SPITTER] = CreateConVar("ss_spitter_weight", "125", "spitter产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_JOCKEY] = CreateConVar("ss_jockey_weight", "100", "jockey产生比重", _, true, 0.0);
	g_hSpawnWeights[SI_CHARGER] = CreateConVar("ss_charger_weight", "100", "charger产生比重", _, true, 0.0);
	g_hScaleWeights = CreateConVar("ss_scale_weights", "1",	"[ 0 = 关闭 | 1 = 开启 ] 缩放相应特感的产生比重", _, true, 0.0, true, 1.0);
	g_hSpawnTimeMin = CreateConVar("ss_time_min", "10.0", "特感的最小产生时间", _, true, 0.1);
	g_hSpawnTimeMax = CreateConVar("ss_time_max", "15.0", "特感的最大产生时间", _, true, 1.0);
	g_hSpawnTimeMode = CreateConVar("ss_time_mode", "2", "特感的刷新时间模式[ 0 = 随机 | 1 = 递增 | 2 = 递减 ]", _, true, 0.0, true, 2.0);

	g_hSIbase = CreateConVar("ss_base_limit", "4", "生还者团队玩家不超过4人时有多少个特感", _, true, 0.0, true, 32.0);
	g_hSIextra = CreateConVar("ss_extra_limit", "1", "生还者团队玩家每增加一个可增加多少个特感", _, true, 0.0, true, 32.0);
	g_hGroupbase = CreateConVar("ss_groupbase_limit", "4", "生还者团队玩家不超过4人时一次产生多少只特感", _, true, 0.0, true, 32.0);
	g_hGroupextra = CreateConVar("ss_groupextra_limit", "2", "生还者团队玩家每增加多少玩家一次多产生一只", _, true, 1.0, true, 32.0);
	g_hRusherDistance = CreateConVar("ss_rusher_distance", "1500.0", "路程超过多少算跑图", _, true, 500.0);
	g_hTankSpawnAction = CreateConVar("ss_tankspawn_action", "1", "坦克产生后是否对当前刷特参数进行修改, 坦克死完后恢复?[ 0 = 忽略(保持原有的刷特状态) | 1 = 自定义 ]", _, true, 0.0, true, 1.0);
	g_hTankSpawnLimits = CreateConVar("ss_tankspawn_limits", "4;1;4;1;4;4", "坦克产生后每种特感数量的自定义参数");
	g_hTankSpawnWeights = CreateConVar("ss_tankspawn_weights", "80;300;100;80;100;100", "坦克产生后每种特感比重的自定义参数");
	g_hForceSuicideTime = CreateConVar("ss_forcesuicide_time", "25.0", "特感自动处死时间", _, true, 1.0);

	g_hSpawnRange = FindConVar("z_spawn_range");
	g_hSpawnRange.Flags &= ~FCVAR_NOTIFY;
	g_hDiscardRange = FindConVar("z_discard_range");
	g_hDiscardRange.Flags &= ~FCVAR_NOTIFY;

	g_hSpawnSize.AddChangeHook(vLimitsConVarChanged);
	for (int i; i < 6; i++) {
		g_hSpawnLimits[i].AddChangeHook(vLimitsConVarChanged);
		g_hSpawnWeights[i].AddChangeHook(vGeneralConVarChanged);
	}

	g_hSILimit.AddChangeHook(vTimesConVarChanged);
	g_hSpawnTimeMin.AddChangeHook(vTimesConVarChanged);
	g_hSpawnTimeMax.AddChangeHook(vTimesConVarChanged);
	g_hSpawnTimeMode.AddChangeHook(vTimesConVarChanged);

	g_hScaleWeights.AddChangeHook(vGeneralConVarChanged);
	g_hSIbase.AddChangeHook(vGeneralConVarChanged);
	g_hSIextra.AddChangeHook(vGeneralConVarChanged);
	g_hGroupbase.AddChangeHook(vGeneralConVarChanged);
	g_hGroupextra.AddChangeHook(vGeneralConVarChanged);
	g_hRusherDistance.AddChangeHook(vGeneralConVarChanged);
	g_hForceSuicideTime.AddChangeHook(vGeneralConVarChanged);

	g_hTankSpawnAction.AddChangeHook(vTankSpawnConVarChanged);
	g_hTankSpawnLimits.AddChangeHook(vTankCustomConVarChanged);
	g_hTankSpawnWeights.AddChangeHook(vTankCustomConVarChanged);

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_team", Event_PlayerTeam);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

	RegAdminCmd("sm_weight", cmdSetWeight, ADMFLAG_RCON, "Set spawn weights for SI classes");
	RegAdminCmd("sm_limit", cmdSetLimit, ADMFLAG_RCON, "Set individual, total and simultaneous SI spawn limits");
	RegAdminCmd("sm_timer", cmdSetTimer, ADMFLAG_RCON, "Set a variable or constant spawn time (seconds)");

	RegAdminCmd("sm_resetspawns", cmdResetSpawns, ADMFLAG_RCON, "Reset by slaying all special infected and restarting the timer");
	RegAdminCmd("sm_forcetimer", cmdStartSpawnTimerManually, ADMFLAG_RCON, "Manually start the spawn timer");
	RegAdminCmd("sm_type", cmdType, ADMFLAG_ROOT, "随机轮换模式");

	if (g_bLateLoad && bHasAnySurvivorLeftSafeArea())
		L4D_OnFirstSurvivorLeftSafeArea_Post(0);
}

public void OnPluginEnd()
{
	g_hSpawnRange.RestoreDefault();
	g_hDiscardRange.RestoreDefault();

	FindConVar("z_spawn_flow_limit").RestoreDefault();
	FindConVar("z_attack_flow_range").RestoreDefault();

	FindConVar("z_safe_spawn_range").RestoreDefault();
	FindConVar("z_spawn_safety_range").RestoreDefault();

	FindConVar("z_finale_spawn_safety_range").RestoreDefault();
	FindConVar("z_finale_spawn_tank_safety_range").RestoreDefault();
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	static int iValue;
	iValue = retVal;
	if (!g_bInSpawnTime) {
		if (strcmp(key, "MaxSpecials", false) == 0) {
			retVal = 0;
		}
	}
	else {
		if (strcmp(key, "MaxSpecials", false) == 0)
			iValue = g_iSILimit;
		else if (strcmp(key, "PreferredSpecialDirection", false) == 0)
			iValue = g_iPreferredDirection;
	}

	if (iValue != retVal) {
		retVal = iValue;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client)
{
	if (g_bLeftSafeArea)
		return;

	g_bLeftSafeArea = true;

	if (g_iCurrentClass >= 6) {
		PrintToChatAll("\x03当前轮换\x01: \n");
		PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[g_iCurrentClass - 6]);
	}
	else if (g_iCurrentClass > -1)
		PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[g_iCurrentClass]);

	vStartCustomSpawnTimer(0.1);
	delete g_hForceSuicideTimer;
	g_hForceSuicideTimer = CreateTimer(2.5, tmrForceSuicide, _, TIMER_REPEAT);
}

bool bHasAnySurvivorLeftSafeArea()
{
	int entity = GetPlayerResourceEntity();
	if (entity == INVALID_ENT_REFERENCE)
		return false;

	return !!GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea");
}

Action tmrForceSuicide(Handle timer)
{
	static int i;
	static int victim;
	static int iClass;
	static float fEngineTime;

	fEngineTime = GetEngineTime();
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != 3 || !IsPlayerAlive(i))
			continue;

		iClass = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (iClass < 1 || iClass > 6)
			continue;

		if (GetEntProp(i, Prop_Send, "m_hasVisibleThreats")) {
			g_fSpecialActionTime[i] = fEngineTime;
			continue;
		}

		victim = iGetSurVictim(i, iClass);
		if (victim > 0) {
			if (GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
				vKillInactiveSI(i, iClass);
			else
				g_fSpecialActionTime[i] = fEngineTime;
		}
		else if (fEngineTime - g_fSpecialActionTime[i] > g_fForceSuicideTime)
			vKillInactiveSI(i, iClass);
	}

	return Plugin_Continue;
}

void vKillInactiveSI(int client, int iClass)
{
	#if DEBUG
	PrintToServer("[SS] Kill Inactive SI -> %N", client);
	#endif
	ForcePlayerSuicide(client);
	g_aSpawnQueue.Push(iClass - 1);
	if (!g_hRetrySpawnTimer)
		CreateTimer(0.1, tmrRetrySpawn, true, TIMER_FLAG_NO_MAPCHANGE);
}

int iGetSurVictim(int client, int iClass)
{
	switch (iClass) {
		case 1:
			return GetEntPropEnt(client, Prop_Send, "m_tongueVictim");

		case 3:
			return GetEntPropEnt(client, Prop_Send, "m_pounceVictim");

		case 5:
			return GetEntPropEnt(client, Prop_Send, "m_jockeyVictim");

		case 6: {
			iClass = GetEntPropEnt(client, Prop_Send, "m_pummelVictim");
			if (iClass > 0)
				return iClass;

			iClass = GetEntPropEnt(client, Prop_Send, "m_carryVictim");
			if (iClass > 0)
				return iClass;
		}
	}

	return -1;
}


Action cmdSetLimit(int client, int args)
{
	if (args == 1) {
		char sArg[16];
		GetCmdArg(1, sArg, sizeof sArg);	
		if (strcmp(sArg, "reset", false) == 0) {
			vResetLimits();
			ReplyToCommand(client, "[SS] Spawn Limits reset to default values");
		}
	}
	else if (args == 2) {
		char sArg[32];
		GetCmdArg(1, sArg, sizeof sArg);

		int iLimit = GetCmdArgInt(2);	
		if (iLimit < 0)
			ReplyToCommand(client, "[SS] Limit value must be >= 0");
		else {
			if (strcmp(sArg, "all", false) == 0) {
				for (int i; i < 6; i++)
					g_hSpawnLimits[i].IntValue = iLimit;

				PrintToChatAll("\x01[SS] All SI limits have been set to \x05%d", iLimit);
			} 
			else if (strcmp(sArg, "max", false) == 0) {
				g_hSILimit.IntValue = iLimit;
				PrintToChatAll("\x01[SS] -> \x04Max \x01SI limit set to \x05%i", iLimit);				   
			} 
			else if (strcmp(sArg, "group", false) == 0 || strcmp(sArg, "wave", false) == 0) {
				g_hSpawnSize.IntValue = iLimit;
				PrintToChatAll("\x01[SS] -> SI will spawn in \x04groups\x01 of \x05%i", iLimit);
			} 
			else  {
				for (int i; i < 6; i++) {
					if (strcmp(g_sZombieClass[i], sArg, false) == 0) {
						g_hSpawnLimits[i].IntValue = iLimit;
						PrintToChatAll("\x01[SS] \x04%s \x01limit set to \x05%i", sArg, iLimit);
					}
				}
			}
		}	 
	} 
	else {
		ReplyToCommand(client, "\x04!limit/sm_limit \x05<class> <limit>");
		ReplyToCommand(client, "\x05<class> \x01[ all | max | group/wave | smoker | boomer | hunter | spitter | jockey | charger ]");
		ReplyToCommand(client, "\x05<limit> \x01[ >= 0 ]");
	}

	return Plugin_Handled;
}

Action cmdSetWeight(int client, int args)
{
	if (args == 1) {
		char sArg[16];
		GetCmdArg(1, sArg, sizeof sArg);	
		if (strcmp(sArg, "reset", false) == 0) {
			vResetWeights();
			ReplyToCommand(client, "[SS] Spawn weights reset to default values");
		} 
	} 
	else if (args == 2) {
		if (GetCmdArgInt(2) < 0) {
			ReplyToCommand(client, "weight value >= 0");
			return Plugin_Handled;
		} 
		else  {
			char sArg[32];
			GetCmdArg(1, sArg, sizeof sArg);

			int iWeight = GetCmdArgInt(2);
			if (strcmp(sArg, "all", false) == 0) {
				for (int i; i < 6; i++)
					g_hSpawnWeights[i].IntValue = iWeight;			

				ReplyToCommand(client, "\x01[SS] -> \x04All spawn weights \x01set to \x05%d", iWeight);	
			} 
			else  {
				for (int i; i < 6; i++) {
					if (strcmp(sArg, g_sZombieClass[i], false) == 0) {
						g_hSpawnWeights[i].IntValue = iWeight;
						ReplyToCommand(client, "\x01[SS] \x04%s \x01weight set to \x05%d", g_sZombieClass[i], iWeight);				
					}
				}	
			}
		}
	} 
	else 
	{
		ReplyToCommand(client, "\x04!weight/sm_weight \x05<class> <value>");
		ReplyToCommand(client, "\x05<class> \x01[ reset | all | smoker | boomer | hunter | spitter | jockey | charger ]");	
		ReplyToCommand(client, "\x05value \x01[ >= 0 ]");	
	}

	return Plugin_Handled;
}

Action cmdSetTimer(int client, int args)
{
	if (args == 1) {
		float fTime = GetCmdArgFloat(1);
		if (fTime < 0.0)
			fTime = 1.0;

		g_hSpawnTimeMin.FloatValue = fTime;
		g_hSpawnTimeMax.FloatValue = fTime;
		ReplyToCommand(client, "\x01[SS] Spawn timer set to constant \x05%.1f \x01seconds", fTime);
	} 
	else if (args == 2) {
		float fMin = GetCmdArgFloat(1);
		float fMax = GetCmdArgFloat(2);
		if (fMin > 0.1 && fMax > 1.0 && fMax > fMin) {
			g_hSpawnTimeMin.FloatValue = fMin;
			g_hSpawnTimeMax.FloatValue = fMax;
			ReplyToCommand(client, "\x01[SS] Spawn timer will be between \x05%.1f \x01and \x05%.1f \x01seconds", fMin, fMax);
		} 
		else 
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn time must greater than min(>= 0.1) spawn time");
	} 
	else 
		ReplyToCommand(client, "[SS] timer <constant> || timer <min> <max>");

	return Plugin_Handled;
}

Action cmdResetSpawns(int client, int args)
{	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
			ForcePlayerSuicide(i);
	}

	vStartCustomSpawnTimer(g_fSpawnTimes[0]);
	ReplyToCommand(client, "[SS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.1f seconds.", g_fSpawnTimeMin);
	return Plugin_Handled;
}

Action cmdStartSpawnTimerManually(int client, int args)
{
	if (args < 1) {
		vStartSpawnTimer();
		ReplyToCommand(client, "[SS] Spawn timer started manually.");
		return Plugin_Handled;
	}

	float fTime = GetCmdArgFloat(1);
	if (fTime < 0.0)
		fTime = 0.1;

	vStartCustomSpawnTimer(fTime);
	ReplyToCommand(client, "[SS] Spawn timer started manually. Next potential spawn in %.1f seconds.", fTime);
	return Plugin_Handled;
}

Action cmdType(int client, int args)
{
	if (args != 1) {
		ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
		ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
		return Plugin_Handled;
	}

	char sArg[16];
	GetCmdArg(1, sArg, sizeof sArg);
	if (strcmp(sArg, "off", false) == 0) {
		g_iCurrentClass = -1;
		ReplyToCommand(client, "已关闭单一特感模式");
		vResetLimits();
	}
	else if (strcmp(sArg, "random", false) == 0) {
		PrintToChatAll("\x03当前轮换\x01: \n");
		PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[iSetRandomType()]);
	}
	else {
		int iClass = iGetZombieClass(sArg);
		if (iClass == -1) {
			ReplyToCommand(client, "\x04!type/sm_type \x05<class>.");
			ReplyToCommand(client, "\x05<type> \x01[ off | random | smoker | boomer | hunter | spitter | jockey | charger ]");
		}
		else if (iClass == g_iCurrentClass)
			ReplyToCommand(client, "目标特感类型与当前特感类型相同");
		else {
			vSiTypeMode(iClass);
			PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[iClass]);
		}
	}

	return Plugin_Handled;
}

int iGetZombieClass(const char[] sClass)
{
	for (int i; i < 6; i++) {
		if (strcmp(sClass, g_sZombieClass[i], false) == 0)
			return i;
	}
	return -1;
}

int iSetRandomType()
{
	static int iClass;
	static int iZombieClass[6] = {0, 1, 2, 3, 4, 5};
	if (iClass == 0)
		SortIntegers(iZombieClass, 6, Sort_Random);

	vSiTypeMode(iZombieClass[iClass]);
	g_iCurrentClass += 6;

	static int iTemp;
	iTemp = iClass;

	iClass++;
	iClass -= RoundToFloor(iClass / 6.0) * 6;
	return iZombieClass[(iTemp - RoundToFloor(iTemp / 6.0) * 6)];
}

void vSiTypeMode(int iClass)
{
	for (int i; i < 6; i++)		
		g_hSpawnLimits[i].IntValue = i != iClass ? 0 : g_iSILimit;

	g_iCurrentClass = iClass;
}

public void OnConfigsExecuted()
{
	vGetLimitCvars();
	vGetTimesCvars();
	vGetGeneralCVars();
	vGetTankSpawnCvars();
	vGetTankCustomCvars();
	vSetDirectorConvars();
}

void vLimitsConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetLimitCvars();
}

void vGetLimitCvars()
{
	g_iSpawnSize = g_hSpawnSize.IntValue;
	for (int i; i < 6; i++)
		g_iSpawnLimits[i] = g_hSpawnLimits[i].IntValue;
}

void vTimesConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetTimesCvars();
}

void vGetTimesCvars()
{
	g_iSILimit = g_hSILimit.IntValue;
	g_fSpawnTimeMin = g_hSpawnTimeMin.FloatValue;
	g_fSpawnTimeMax = g_hSpawnTimeMax.FloatValue;
	g_iSpawnTimeMode = g_hSpawnTimeMode.IntValue;
	
	if (g_fSpawnTimeMin > g_fSpawnTimeMax)
		g_fSpawnTimeMin = g_fSpawnTimeMax;
		
	vCalculateSpawnTimes();
}

void vCalculateSpawnTimes()
{
	if (g_iSILimit > 1 && g_iSpawnTimeMode > 0) {
		float fUnit = (g_fSpawnTimeMax - g_fSpawnTimeMin) / (g_iSILimit - 1);
		switch (g_iSpawnTimeMode) {
			case 1:  {
				g_fSpawnTimes[0] = g_fSpawnTimeMin;
				for (int i = 1; i <= MaxClients; i++)
					g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] + fUnit) : g_fSpawnTimeMax;
			}

			case 2:  {	
				g_fSpawnTimes[0] = g_fSpawnTimeMax;
				for (int i = 1; i <= MaxClients; i++)
					g_fSpawnTimes[i] = i < g_iSILimit ? (g_fSpawnTimes[i - 1] - fUnit) : g_fSpawnTimeMax;
			}
		}	
	} 
	else
		g_fSpawnTimes[0] = g_fSpawnTimeMax;
}

void vGeneralConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetGeneralCVars();
}

void vGetGeneralCVars()
{
	g_bScaleWeights = g_hScaleWeights.BoolValue;

	for (int i; i < 6; i++)
		g_iSpawnWeights[i] = g_hSpawnWeights[i].IntValue;

	g_iSIbase = g_hSIbase.IntValue;
	g_iSIextra = g_hSIextra.IntValue;
	g_iGroupbase = g_hGroupbase.IntValue;
	g_iGroupextra = g_hGroupextra.IntValue;
	g_fRusherDistance = g_hRusherDistance.FloatValue;
	g_fForceSuicideTime = g_hForceSuicideTime.FloatValue;
}

void vTankSpawnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int iLast = g_iTankSpawnAction;
	vGetTankSpawnCvars();

	if (iLast != g_iTankSpawnAction)
		vTankSpawnDeathActoin(bFindTank(-1));
}

void vGetTankSpawnCvars()
{
	g_iTankSpawnAction = g_hTankSpawnAction.IntValue;
}

void vTankCustomConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetTankCustomCvars();
}

void vGetTankCustomCvars()
{
	char sTemp[64];
	g_hTankSpawnLimits.GetString(sTemp, sizeof sTemp);

	char sValues[6][8];
	ExplodeString(sTemp, ";", sValues, sizeof sValues, sizeof sValues[]);
	
	int i;
	int iValue;
	for (; i < 6; i++) {
		if (sValues[i][0] == '\0') {
			g_iTankSpawnLimits[i] = -1;
			continue;
		}
		
		if ((iValue = StringToInt(sValues[i])) < -1 || iValue > g_iSILimit) {
			g_iTankSpawnLimits[i] = -1;
			sValues[i][0] = '\0';
			continue;
		}
	
		g_iTankSpawnLimits[i] = iValue;
		sValues[i][0] = '\0';
	}
	
	g_hTankSpawnWeights.GetString(sTemp, sizeof sTemp);
	ExplodeString(sTemp, ";", sValues, sizeof sValues, sizeof sValues[]);
	
	for (i = 0; i < 6; i++) {
		if (sValues[i][0] == '\0' || (iValue = StringToInt(sValues[i])) < 0) {
			g_iTankSpawnWeights[i] = -1;
			continue;
		}

		g_iTankSpawnWeights[i] = iValue;
	}
}

void vSetDirectorConvars()
{
	g_hSpawnRange.IntValue = 1000;
	g_hDiscardRange.IntValue = 2500;

	FindConVar("z_spawn_flow_limit").IntValue = 999999;
	FindConVar("z_attack_flow_range").IntValue = 999999;

	FindConVar("z_safe_spawn_range").IntValue = 1;
	FindConVar("z_spawn_safety_range").IntValue = 1;

	FindConVar("z_finale_spawn_safety_range").IntValue = 1;
	FindConVar("z_finale_spawn_tank_safety_range").IntValue = 1;
}

public void OnClientDisconnect(int client)
{
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		return;
		
	CreateTimer(0.1, tmrTankDisconnectCheck, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapStart()
{
	g_bIsFinalMap = L4D_IsMissionFinalMap();

	g_aAreas.Clear();

	NavArea pArea;
	float flow;
	int iNavAreaCount = g_pTheNavAreas.Count;
	if (!iNavAreaCount)
		SetFailState("当前地图Nav区域数量为0, 可能是某些测试地图");

	TheNavAreas pTheNavAreas = view_as<TheNavAreas>(g_pTheNavAreas.Dereference);
	for (int i; i < iNavAreaCount; i++) {
		pArea = pTheNavAreas.GetArea(i, false);
		if (pArea.IsNull())
			continue;

		g_aAreas.Set(g_aAreas.Push(flow), pArea, 1);
	}

	g_aAreas.Sort(Sort_Ascending, Sort_Float);
}

public void OnMapEnd()
{
	g_fSpawnDist = g_fRusherDistance;
	g_bLeftSafeArea = false;

	vEndSpawnTimer();
	delete g_hForceSuicideTimer;
	vTankSpawnDeathActoin(false);

	if (g_iCurrentClass >= 6)
		iSetRandomType();
	else if (g_iCurrentClass > -1)
		vSiTypeMode(g_iCurrentClass);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	vEndSpawnTimer();
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) 
{
	if (!g_bLeftSafeArea)
		return;

	g_fSpecialActionTime[GetClientOfUserId(event.GetInt("userid"))] = GetEngineTime();
	g_fSpecialActionTime[GetClientOfUserId(event.GetInt("attacker"))] = GetEngineTime();
}

Handle g_hUpdateTimer;
void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	if (event.GetInt("team") == 2 || event.GetInt("oldteam") == 2) {
		delete g_hUpdateTimer;
		g_hUpdateTimer = CreateTimer(2.0, tmrSpecialsUpdate);
	}
}

Action tmrSpecialsUpdate(Handle timer)
{
	g_hUpdateTimer = null;
	vSetMaxSpecialsCount();
	return Plugin_Continue;
}

void vSetMaxSpecialsCount()
{
	int iPlayers;
	int iTempLimit;
	int iTempSize;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			iPlayers++;
	}

	iPlayers -= 4;

	if (iPlayers < 1) {
		iTempLimit = g_iSIbase;
		iTempSize = g_iGroupbase;
	}
	else {
		iTempLimit = g_iSIbase + g_iSIextra * iPlayers;
		iTempSize = g_iGroupbase + RoundToNearest(1.0 * iPlayers / g_iGroupextra);
	}

	if (iTempLimit == g_iSILimit && iTempSize == g_iSpawnSize)
		return;

	g_hSILimit.IntValue = iTempLimit;
	g_hSpawnSize.IntValue = iTempSize;
	PrintToChatAll("\x01[\x05%d特\x01/\x05次\x01] \x05%d特 \x01[\x03%.1f\x01~\x03%.1f\x01]\x04秒", iTempSize, iTempLimit, g_fSpawnTimeMin, g_fSpawnTimeMax);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		g_fSpecialActionTime[client] = GetEngineTime();
	else
		CreateTimer(0.1, tmrTankSpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	static int userid;
	static int client;
	static int iClass;

	userid = event.GetInt("userid");
	client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;

	iClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (iClass == 8 && !bFindTank(client))
		vTankSpawnDeathActoin(false);

	if (iClass != 4 && IsFakeClient(client))
		RequestFrame(OnNextFrame_KickBot, userid);
}

Action tmrTankSpawn(Handle timer, int client)
{
	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || bFindTank(client))
		return Plugin_Stop;

	int iTotalLimit;
	int iTotalWeight;
	for (int i; i < 6; i++) {
		iTotalLimit += g_iSpawnLimits[i];
		iTotalWeight += g_iSpawnWeights[i];
	}

	if (iTotalLimit && iTotalWeight)
		vTankSpawnDeathActoin(true);

	return Plugin_Continue;
}

void OnNextFrame_KickBot(any client)
{
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
		KickClient(client);
}

bool bFindTank(int client)
{
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
			return true;
	}
	return false;
}

Action tmrTankDisconnectCheck(Handle timer)
{
	if (bFindTank(-1))
		return Plugin_Stop;

	vTankSpawnDeathActoin(false);
	return Plugin_Continue;
}

void vTankSpawnDeathActoin(bool bIsTankAlive)
{
	static bool bLoad;
	if (!bIsTankAlive) {
		if (bLoad) {
			bLoad = false;
			vLoadCacheSpawnLimits();
			vLoadCacheSpawnWeights();
		}
	}
	else {
		if (!bLoad && g_iTankSpawnAction) {
			bLoad = true;
			for (int i; i < 6; i++) {
				g_iSpawnLimitsCache[i] = g_iSpawnLimits[i];
				g_iSpawnWeightsCache[i] = g_iSpawnWeights[i];
			}
			vLoadCacheTankCustom();
		}
	}
}

void vLoadCacheSpawnLimits()
{
	if (g_iSILimitCache != -1) {
		g_hSILimit.IntValue = g_iSILimitCache;
		g_iSILimitCache = -1;
	}

	if (g_iSpawnSizeCache != -1) {
		g_hSpawnSize.IntValue = g_iSpawnSizeCache;
		g_iSpawnSizeCache = -1;
	}

	for (int i; i < 6; i++) {		
		if (g_iSpawnLimitsCache[i] != -1) {
			g_hSpawnLimits[i].IntValue = g_iSpawnLimitsCache[i];
			g_iSpawnLimitsCache[i] = -1;
		}
	}
}

void vLoadCacheSpawnWeights()
{
	for (int i; i < 6; i++) {		
		if (g_iSpawnWeightsCache[i] != -1) {
			g_hSpawnWeights[i].IntValue = g_iSpawnWeightsCache[i];
			g_iSpawnWeightsCache[i] = -1;
		}
	}
}

void vLoadCacheTankCustom()
{
	for (int i; i < 6; i++) {
		if (g_iTankSpawnLimits[i] != -1)
			g_hSpawnLimits[i].IntValue = g_iTankSpawnLimits[i];
			
		if (g_iTankSpawnWeights[i] != -1)
			g_hSpawnWeights[i].IntValue = g_iTankSpawnWeights[i];
	}
}

void vResetLimits()
{
	for (int i; i < 6; i++)
		g_hSpawnLimits[i].RestoreDefault();
}

void vResetWeights()
{
	for (int i; i < 6; i++)
		g_hSpawnWeights[i].RestoreDefault();
}

void vStartCustomSpawnTimer(float fTime)
{
	vEndSpawnTimer();
	g_hSpawnTimer = CreateTimer(fTime, tmrAutoSpawnInfected);
}

void vStartSpawnTimer()
{
	vEndSpawnTimer();
	g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[iGetTotalSI()] : GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrAutoSpawnInfected);
}

void vEndSpawnTimer()
{
	delete g_hSpawnTimer;
	delete g_hRetrySpawnTimer;
}

Action tmrAutoSpawnInfected(Handle timer)
{ 
	g_hSpawnTimer = null;
	delete g_hRetrySpawnTimer;
	SetRandomSeed(GetSysTickCount());

	#if BENCHMARK
	g_profiler = new Profiler();
	g_profiler.Start();
	#endif
	int iTotalSI = iGetTotalSI();
	vGenerateAndExecuteSpawnQueue(iTotalSI);
	#if BENCHMARK
	g_profiler.Stop();
	PrintToServer("[SS] ProfilerTime: %f", g_profiler.Time);
	#endif

	g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[iTotalSI] : GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrAutoSpawnInfected);
	return Plugin_Continue;
}

void vGenerateAndExecuteSpawnQueue(int iTotalSI)
{
	if (iTotalSI >= g_iSILimit)
		return;

	static int iSize;
	static int iAllowedSI;

	iAllowedSI = g_iSILimit - iTotalSI;
	iSize = g_iSpawnSize > iAllowedSI ? iAllowedSI : g_iSpawnSize;

	static int i;
	static int client;
	static int iCount;
	static int iIndex;
	//static bool bRush;
	static bool bFind;
	static float flow;
	static float vPos[3];
	static NavArea area;
	static ArrayList aList;

	iGetSIClass();
	g_aSpawnQueue.Clear();
	for (i = 0; i < iSize; i++) {
		iIndex = iGenerateIndex();
		if (iIndex == -1)
			break;

		g_aSpawnQueue.Push(iIndex);
		g_iSpawnCounts[iIndex]++;
	}

	iSize = g_aSpawnQueue.Length;
	if (!iSize)
		return;

	aList = new ArrayList(3);
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated")) {
			GetClientAbsOrigin(i, vPos);
			area = view_as<NavArea>(L4D_GetNearestNavArea(vPos, 1000.0));
			if (!area)
				continue;

			flow = area.m_flow;
			if (flow != -9999.0) {
				aList.Set((iIndex = aList.Push(flow)), i, 1);
				aList.Set(iIndex, area, 2);
			}
		}
	}

	iCount = aList.Length;
	if (!iCount) {
		delete aList;
		return;
	}

	static float lastFlow;
	aList.Sort(Sort_Descending, Sort_Float);
	client = aList.Get(0, 1);
	bRush = false;

	flow = aList.Get(0, 0);
	lastFlow = aList.Get(iCount - 1, 0);
	if (flow - lastFlow > g_fRusherDistance) {
		#if DEBUG
		PrintToServer("[SS] Rusher -> %N", client);
		#endif

		//bRush = true;
		lastFlow = flow;
	}

	bFind = false;
	g_bInSpawnTime = true;
	vCollectSpawnAreas(/*bRush ? client : 0, */aList.Get(0, 2), lastFlow - g_fRusherDistance, flow + g_fRusherDistance); //if (bRush) vCollectSpawnAreas(client);
	delete aList;
	//g_iPreferredDirection = bRush ? SPAWN_IN_FRONT_OF_SURVIVORS : SPAWN_ANYWHERE;

	for (i = 0; i < iSize;) {
		iIndex = g_aSpawnQueue.Get(i);
		if (bGetRandomSpawnPos(vPos)/*bRush ? bGetRandomSpawnPos(vPos) : L4D_GetRandomPZSpawnPosition(client, iIndex + 1, 10, vPos)*/)
			bFind = true;

		if (bFind && L4D2_SpawnSpecial(iIndex + 1, vPos, NULL_VECTOR) > 0) {
			g_aSpawnQueue.Erase(i);
			iSize--;
			continue;
		}

		i++;
	}

	g_bInSpawnTime = false;

	if (g_aSpawnQueue.Length) {
		#if DEBUG
		PrintToServer("[SS] Retry Spawn SI -> %d", g_aSpawnQueue.Length);
		#endif
		g_hRetrySpawnTimer = CreateTimer(0.1, tmrRetrySpawn, false, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action tmrRetrySpawn(Handle timer, bool bCheckRush)
{
	static int i;
	static int iSize;
	static int client;
	static bool bFind;
	static int iClass;
	static float vPos[3];

	g_hRetrySpawnTimer = null;

	if (!g_bLeftSafeArea)
		return Plugin_Stop;

	iClass = iGetTotalSI();
	if (bCheckRush) {
		vGenerateAndExecuteSpawnQueue(iClass);
		return Plugin_Stop;
	}

	iSize = g_aSpawnQueue.Length;
	if (!iSize)
		return Plugin_Stop;

	client = L4D_GetHighestFlowSurvivor();
	if (!client)
		return Plugin_Stop;

	if (iClass >= g_iSILimit)
		return Plugin_Stop;

	bFind = false;
	g_bInSpawnTime = true;
	g_iPreferredDirection = SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS;

	for (i = 0; i < iSize;) {
		iClass = g_aSpawnQueue.Get(i);
		if (L4D_GetRandomPZSpawnPosition(client, iClass + 1, 10, vPos))
			bFind = true;

		if (bFind && L4D2_SpawnSpecial(iClass + 1, vPos, NULL_VECTOR) > 0) {
			g_aSpawnQueue.Erase(i);
			iSize--;
			continue;
		}

		i++;
	}

	g_bInSpawnTime = false;
	return Plugin_Continue;
}

int iGetTotalSI()
{
	int iCount;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientInKickQueue(i) || GetClientTeam(i) != 3)
			continue;
	
		if (IsPlayerAlive(i)) {
			if (1 <= GetEntProp(i, Prop_Send, "m_zombieClass") <= 6)
				iCount++;
		}
		else if (IsFakeClient(i))
			KickClient(i);
	}
	return iCount;
}

void iGetSIClass()
{
	int i;
	for (; i < 6; i++)
		g_iSpawnCounts[i] = 0;

	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientInKickQueue(i)|| GetClientTeam(i) != 3 || !IsPlayerAlive(i))
			continue;

		switch (GetEntProp(i, Prop_Send, "m_zombieClass")) {
			case 1:
				g_iSpawnCounts[SI_SMOKER]++;

			case 2:
				g_iSpawnCounts[SI_BOOMER]++;

			case 3:
				g_iSpawnCounts[SI_HUNTER]++;

			case 4:
				g_iSpawnCounts[SI_SPITTER]++;

			case 5:
				g_iSpawnCounts[SI_JOCKEY]++;
		
			case 6:
				g_iSpawnCounts[SI_CHARGER]++;
		}
	}
}

int iGenerateIndex()
{	
	static int i;
	static int iTotalWeight;
	static int iStandardizedWeight;
	static int iTempWeights[6];
	static float fUnit;
	static float fRandom;
	static float fIntervalEnds[6];

	iTotalWeight = 0;
	iStandardizedWeight = 0;

	for (i = 0; i < 6; i++) {
		iTempWeights[i] = g_iSpawnCounts[i] < g_iSpawnLimits[i] ? (g_bScaleWeights ? ((g_iSpawnLimits[i] - g_iSpawnCounts[i]) * g_iSpawnWeights[i]) : g_iSpawnWeights[i]) : 0;
		iTotalWeight += iTempWeights[i];
	}

	fUnit = 1.0 / iTotalWeight;
	for (i = 0; i < 6; i++) {
		if (iTempWeights[i] >= 0) {
			iStandardizedWeight += iTempWeights[i];
			fIntervalEnds[i] = iStandardizedWeight * fUnit;
		}
	}

	fRandom = GetRandomFloat(0.0, 1.0);
	for (i = 0; i < 6; i++) {
		if (iTempWeights[i] > 0 && fIntervalEnds[i] >= fRandom)
			return i;
	}

	return -1;
}

// https://github.com/fdxx/l4d2_plugins/blob/main/l4d2_si_spawn_control.sp
void vInitData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_iOff_NavCount = hGameData.GetOffset("TheNavAreas::Count");
	if(g_iOff_NavCount == -1)
		SetFailState("Failed to find offset: TheNavAreas::Count");

	g_pTheNavAreas = view_as<TheNavAreas>(hGameData.GetAddress("TheNavAreas"));
	if (!g_pTheNavAreas)
		SetFailState("Failed to find address: TheNavAreas");	

	g_iOff_m_flow = hGameData.GetOffset("CTerrorPlayer::GetFlowDistance::m_flow");
	if (g_iOff_m_flow == -1)
		SetFailState("Failed to find offset: CTerrorPlayer::GetFlowDistance::m_flow");

	g_iOff_m_attributeFlags = hGameData.GetOffset("CNavArea::InheritAttributes::m_attributeFlags");
	if (g_iOff_m_attributeFlags == -1)
		SetFailState("Failed to find offset: CNavArea::InheritAttributes::m_attributeFlags");

	g_iOff_m_spawnAttributes = hGameData.GetOffset("TerrorNavArea::SetSpawnAttributes::m_spawnAttributes");
	if (g_iOff_m_spawnAttributes == -1)
		SetFailState("Failed to find offset: TerrorNavArea::SetSpawnAttributes::m_spawnAttributes");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavArea::FindRandomSpot"))
		SetFailState("Failed to find signature: TerrorNavArea::FindRandomSpot");
	PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
	if (!(g_hSDK_TerrorNavArea_FindRandomSpot = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: TerrorNavArea::FindRandomSpot");

	StartPrepSDKCall(SDKCall_Static);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "IsVisibleToPlayer"))
		SetFailState("Failed to find signature: IsVisibleToPlayer");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);									// 目标点位
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);								// 客户端
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);								// 客户端团队
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);								// 目标点位团队, 如果为0将考虑客户端的角度
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);										// 不清楚
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer, VDECODE_FLAG_ALLOWWORLD);	// 不清楚
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer);							// 目标点位 NavArea 区域
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Pointer);									// 如果为 false，将自动获取目标点位的 NavArea (GetNearestNavArea)
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_IsVisibleToPlayer = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: IsVisibleToPlayer");

	/*StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavArea::IsEntirelyVisible"))
		SetFailState("Failed to find signature: TerrorNavArea::IsEntirelyVisible");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_TerrorNavArea_IsEntirelyVisible = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: TerrorNavArea::IsEntirelyVisible");*/

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "TerrorNavArea::IsPartiallyVisible"))
		SetFailState("Failed to find signature: TerrorNavArea::IsPartiallyVisible");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_TerrorNavArea_IsPartiallyVisible = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: TerrorNavArea::IsPartiallyVisible");

	delete hGameData;
}

methodmap TheNavAreas < Handle
{
	property int Count {
		public get() {
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOff_NavCount), NumberType_Int32);
		}
	}

	property Address Dereference {
		public get() {
			return LoadFromAddress(view_as<Address>(this), NumberType_Int32);
		}
	}

	public NavArea GetArea(int i, bool bDereference = true) {
		if (!bDereference)
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(i * 4), NumberType_Int32);

		return LoadFromAddress(this.Dereference + view_as<Address>(i * 4), NumberType_Int32);
	}
}

methodmap NavArea < Handle
{
	public bool IsNull() {
		return view_as<Address>(this) == Address_Null;
	}

	property float m_flow {
		public get() {
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_flow), NumberType_Int32);
		}
	}

	property int m_attributeFlags {
		public get() {
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_attributeFlags), NumberType_Int32);
		}

		/*public set(int value) {
			StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_attributeFlags), value, NumberType_Int32);
		}*/
	}
	
	property int m_spawnAttributes {
		public get() {
			return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_spawnAttributes), NumberType_Int32);
		}

		/*public set(int value) {
			StoreToAddress(view_as<Address>(this) + view_as<Address>(g_iOff_m_spawnAttributes), value, NumberType_Int32);
		}*/
	}

	public void FindRandomSpot(float result[3]) {
		SDKCall(g_hSDK_TerrorNavArea_FindRandomSpot, this, result, sizeof result);
	}
}

void vCollectSpawnAreas(/*int client = 0, */int endArea, float minFlow, float maxFlow)
{
	#if DEBUG
	PrintToServer("[SS] NavArea Spawn");
	#endif

	static int i;
	static int iState;
	static int iLength;
	static NavArea pArea;
	static SpawnData data;
	static float fDist;
	static float fFlow;
	static float vPos[3];

	g_aSpawnData.Clear();
	vGetSurPosData(/*client*/);

	#if DEBUG
	int iCount;
	PrintToServer("[SS] NvaCount -> %d", g_aAreas.Length);
	#endif

	iState = g_aAreas.FindValue(endArea, 1);
	if (iState == -1)
		return;

	for (i = iState; i >= 0; i--) {
		pArea = g_aAreas.Get(i, 1);
		fFlow = pArea.m_flow;
		if (fFlow == -9999.0)
			continue;

		if (fFlow < minFlow)
			break;

		#if DEBUG
		iCount++;
		#endif
		if (!bIsValidAttributeFlags(pArea.m_attributeFlags))
			continue;

		if (!bIsValidSpawnFlags(pArea.m_spawnAttributes))
			continue;

		pArea.FindRandomSpot(vPos);
		if (bIsWillStuck(vPos))
			continue;
	
		if (!bIsNearPlayer(vPos, fDist))
			continue;

		if (/*bIsSurVisibleTo(vPos, pArea)*/bIsPartiallyVisible(pArea))
			continue;

		data.fDist = fDist;
		data.vPos = vPos;
		g_aSpawnData.PushArray(data);
	}

	iLength = g_aAreas.Length;
	for (i = iState + 1; i < iLength; i++) {
		pArea = g_aAreas.Get(i, 1);
		fFlow = pArea.m_flow;
		if (fFlow == -9999.0)
			continue;

		if (fFlow > maxFlow)
			break;

		#if DEBUG
		iCount++;
		#endif
		if (!bIsValidAttributeFlags(pArea.m_attributeFlags))
			continue;

		if (!bIsValidSpawnFlags(pArea.m_spawnAttributes))
			continue;

		pArea.FindRandomSpot(vPos);
		if (bIsWillStuck(vPos))
			continue;
	
		if (!bIsNearPlayer(vPos, fDist))
			continue;

		if (/*bIsSurVisibleTo(vPos, pArea)*/bIsPartiallyVisible(pArea))
			continue;

		data.fDist = fDist;
		data.vPos = vPos;
		g_aSpawnData.PushArray(data);
	}

	#if DEBUG
	PrintToServer("[SS] iCount -> %d", iCount);
	#endif
}

bool bGetRandomSpawnPos(float vPos[3])
{
	static int iLength;
	static bool bSuccess;
	static SpawnData data;

	bSuccess = false;
	iLength = g_aSpawnData.Length;
	if (!iLength)
		g_fSpawnDist = g_fRusherDistance;
	else
	{
		#if DEBUG
		PrintToServer("[SS] SpawnData -> %d", iLength);
		#endif
		bSuccess = true;
		g_aSpawnData.Sort(Sort_Ascending, Sort_Float);
		g_aSpawnData.GetArray(iLength >= 6 ? GetRandomInt(0, 5) : iLength >= 2 ? GetRandomInt(0, 1) : 0, data);

		//g_aSpawnData.GetArray(GetRandomInt(0, iLength - 1), data);
		vPos = data.vPos;
		g_fSpawnDist = data.fDist + 400.0;
	}

	return bSuccess;
}

#define NAV_MESH_JUMP			(1 << 1)
#define NAV_MESH_PLAYERCLIP		(1 << 18)
#define NAV_MESH_FLOW_BLOCKED	(1 << 27)
bool bIsValidAttributeFlags(int iFlags)
{
	if (iFlags & NAV_MESH_JUMP || iFlags & NAV_MESH_PLAYERCLIP || iFlags & NAV_MESH_FLOW_BLOCKED)
		return false;

	return true;
}

// https://developer.valvesoftware.com/wiki/List_of_L4D_Series_Nav_Mesh_Attributes:zh-cn
#define	TERROR_NAV_NO_NAME1				(1 << 0)
#define	TERROR_NAV_EMPTY				(1 << 1)
#define	TERROR_NAV_STOP_SCAN			(1 << 2)
#define	TERROR_NAV_NO_NAME2				(1 << 3)
#define	TERROR_NAV_NO_NAME3				(1 << 4)
#define	TERROR_NAV_BATTLESTATION		(1 << 5)
#define	TERROR_NAV_FINALE				(1 << 6)
#define	TERROR_NAV_PLAYER_START			(1 << 7)
#define	TERROR_NAV_BATTLEFIELD			(1 << 8)
#define	TERROR_NAV_IGNORE_VISIBILITY	(1 << 9)
#define	TERROR_NAV_NOT_CLEARABLE		(1 << 10)
#define	TERROR_NAV_CHECKPOINT			(1 << 11)
#define	TERROR_NAV_OBSCURED				(1 << 12)
#define	TERROR_NAV_NO_MOBS				(1 << 13)
#define	TERROR_NAV_THREAT				(1 << 14)
#define	TERROR_NAV_RESCUE_VEHICLE		(1 << 15)
#define	TERROR_NAV_RESCUE_CLOSET		(1 << 16)
#define	TERROR_NAV_ESCAPE_ROUTE			(1 << 17)
#define	TERROR_NAV_DOOR					(1 << 18)
#define	TERROR_NAV_NOTHREAT				(1 << 19)
#define	TERROR_NAV_LYINGDOWN			(1 << 20)
#define	TERROR_NAV_COMPASS_NORTH		(1 << 24)
#define	TERROR_NAV_COMPASS_NORTHEAST	(1 << 25)
#define	TERROR_NAV_COMPASS_EAST			(1 << 26)
#define	TERROR_NAV_COMPASS_EASTSOUTH	(1 << 27)
#define	TERROR_NAV_COMPASS_SOUTH		(1 << 28)
#define	TERROR_NAV_COMPASS_SOUTHWEST	(1 << 29)
#define	TERROR_NAV_COMPASS_WEST			(1 << 30)
#define	TERROR_NAV_COMPASS_WESTNORTH	(1 << 31)
bool bIsValidSpawnFlags(int iFlags)
{
	if (!iFlags)
		return false;

	if (iFlags & TERROR_NAV_STOP_SCAN || iFlags & TERROR_NAV_RESCUE_CLOSET)
		return false;

	if (g_bIsFinalMap && L4D2_GetCurrentFinaleStage() != 18) //防止结局地图特感产生在结局区域之外
		return iFlags & TERROR_NAV_FINALE != 0;

	return true;
}

void vGetSurPosData(/*int client = 0*/)
{
	static int i;
	static SurData data;

	g_aSurData.Clear();
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated")) {
			data.flow = L4D2Direct_GetFlowDistance(i);
			GetClientEyePosition(i, data.vPos);
			g_aSurData.PushArray(data);
		}
	}

	/*if (client) {
		data.flow = L4D2Direct_GetFlowDistance(client);
		GetClientEyePosition(client, data.vPos);
		g_aSurData.PushArray(data);
	}
	else {
		for (i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated")) {
				data.flow = L4D2Direct_GetFlowDistance(i);
				GetClientEyePosition(i, data.vPos);
				g_aSurData.PushArray(data);
			}
		}
	}*/
	
	g_iMaxSurData = g_aSurData.Length;
}

bool bIsNearPlayer(float vPos[3], float &fDist)
{
	static int i;
	static SurData data;
	for (i = 0; i < g_iMaxSurData; i++) {
		g_aSurData.GetArray(i, data);
		fDist = GetVectorDistance(data.vPos, vPos);
		if (fDist <= g_fSpawnDist)
			return true;
	}
	return false;
}

stock bool bIsSurVisibleTo(const float vPos[3], NavArea pArea)
{
	static int i;
	static float vTarget[3];

	vTarget = vPos;
	vTarget[2] += 62.0; //眼睛位置
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated") && SDKCall(g_hSDK_IsVisibleToPlayer, vTarget, i, 2, 3, 0.0, 0, pArea, true))
			return true;
	}

	return false;
}
/*
stock bool bIsEntirelyVisible(NavArea pArea)
{
	static int i;
	static float vPos[3];
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_isIncapacitated"))
			continue;
	
		GetClientEyePosition(i, vPos);
		if (SDKCall(g_hSDK_TerrorNavArea_IsEntirelyVisible, pArea, vPos))
			return true;
	}

	return false;
}*/

stock bool bIsPartiallyVisible(NavArea pArea)
{
	static int i;
	static float vPos[3];
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || GetEntProp(i, Prop_Send, "m_isIncapacitated"))
			continue;
	
		GetClientEyePosition(i, vPos);
		if (SDKCall(g_hSDK_TerrorNavArea_IsPartiallyVisible, pArea, vPos))
			return true;
	}

	return false;
}

bool bIsWillStuck(const float vPos[3])
{
	//似乎所有客户端的尺寸都一样
	static const float vMins[3] = {-16.0, -16.0, 0.0};
	static const float vMaxs[3] = {16.0, 16.0, 71.0};

	static bool bHit;
	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vPos, vPos, vMins, vMaxs, MASK_SOLID_BRUSHONLY, bTraceEntityFilter);
	bHit = TR_DidHit(hTrace);

	delete hTrace;
	return bHit;
}

bool bTraceEntityFilter(int entity, int contentsMask)
{
	return entity > MaxClients;
}
