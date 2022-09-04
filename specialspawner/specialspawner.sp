#pragma tabsize 1
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define DEBUG 		0
#define BENCHMARK	0
#if BENCHMARK
	#include <profiler>
	Profiler g_profiler;
#endif

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
	g_hRetryTimer,
	g_hUpdateTimer,
	g_hSuicideTimer;

ConVar
	g_cvSILimit,
	g_cvSpawnSize,
	g_cvSpawnLimits[6],
	g_cvSpawnWeights[6],
	g_cvScaleWeights,
	g_cvSpawnTimeMode,
	g_cvSpawnTimeMin,
	g_cvSpawnTimeMax,
	g_cvBaseLimit,
	g_cvExtraLimit,
	g_cvBaseSize,
	g_cvExtraSize,
	g_cvTankStatusAction,
	g_cvTankStatusLimits,
	g_cvTankStatusWeights,
	g_cvSuicideTime,
	g_cvRushDistance,
	g_cvSpawnRange,
	g_cvDiscardRange;

float
	g_fSpawnTimeMin,
	g_fSpawnTimeMax,
	g_fExtraLimit,
	g_fExtraSize,
	g_fSuicideTime,
	g_fRushDistance,
	g_fSpawnTimes[MAXPLAYERS + 1],
	g_fActionTimes[MAXPLAYERS + 1];

static const char
	g_sZombieClass[6][] = {
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
	g_iTankStatusAction,
	g_iPreferredDirection,
	g_iSILimitCache = -1,
	g_iSpawnLimitsCache[6] = {	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iSpawnWeightsCache[6] = {
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iTankStatusLimits[6] = {	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iTankStatusWeights[6] = {	
		-1,
		-1,
		-1,
		-1,
		-1,
		-1
	},
	g_iSpawnSizeCache = -1,
	g_iSpawnCounts[6],
	g_iBaseLimit,
	g_iBaseSize,
	g_iCurrentClass = -1;

bool
	g_bLateLoad,
	g_bInSpawnTime,
	g_bScaleWeights,
	g_bLeftSafeArea,
	g_bFinaleStarted;

public Plugin myinfo = {
	name = "Special Spawner",
	author = "Tordecybombo, breezy",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "1.3.6",
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	g_aSpawnQueue = new ArrayList();

	g_cvSILimit	= 					CreateConVar("ss_si_limit", 			"12", 						"同时存在的最大特感数量", _, true, 1.0, true, 32.0);
	g_cvSpawnSize = 				CreateConVar("ss_spawn_size", 			"4", 						"一次产生多少只特感", _, true, 1.0, true, 32.0);
	g_cvSpawnLimits[SI_SMOKER] = 	CreateConVar("ss_smoker_limit",			"2", 						"同时存在的最大smoker数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_BOOMER] = 	CreateConVar("ss_boomer_limit",			"2",						"同时存在的最大boomer数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_HUNTER] = 	CreateConVar("ss_hunter_limit",			"4", 						"同时存在的最大hunter数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_SPITTER] = 	CreateConVar("ss_spitter_limit",		"2", 						"同时存在的最大spitter数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_JOCKEY] = 	CreateConVar("ss_jockey_limit",			"4", 						"同时存在的最大jockey数量", _, true, 0.0, true, 32.0);
	g_cvSpawnLimits[SI_CHARGER] = 	CreateConVar("ss_charger_limit", 		"4", 						"同时存在的最大charger数量", _, true, 0.0, true, 32.0);

	g_cvSpawnWeights[SI_SMOKER] = 	CreateConVar("ss_smoker_weight", 		"100", 						"smoker产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_BOOMER] = 	CreateConVar("ss_boomer_weight", 		"200", 						"boomer产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_HUNTER] = 	CreateConVar("ss_hunter_weight", 		"100", 						"hunter产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_SPITTER] = 	CreateConVar("ss_spitter_weight", 		"200",						"spitter产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_JOCKEY] = 	CreateConVar("ss_jockey_weight", 		"100", 						"jockey产生比重", _, true, 0.0);
	g_cvSpawnWeights[SI_CHARGER] = 	CreateConVar("ss_charger_weight", 		"100", 						"charger产生比重", _, true, 0.0);
	g_cvScaleWeights = 				CreateConVar("ss_scale_weights", 		"1",						"缩放相应特感的产生比重 [0 = 关闭 | 1 = 开启](开启后,总比重越大的越容易先刷出来, 动态控制特感刷出顺序)", _, true, 0.0, true, 1.0);
	g_cvSpawnTimeMin = 				CreateConVar("ss_time_min", 			"10.0", 					"特感的最小产生时间", _, true, 0.1);
	g_cvSpawnTimeMax = 				CreateConVar("ss_time_max", 			"15.0", 					"特感的最大产生时间", _, true, 1.0);
	g_cvSpawnTimeMode = 			CreateConVar("ss_time_mode", 			"1", 						"特感的刷新时间模式[0 = 随机 | 1 = 递增(杀的越快刷的越快) | 2 = 递减(杀的越慢刷的越快)]", _, true, 0.0, true, 2.0);

	g_cvBaseLimit = 				CreateConVar("ss_base_limit", 			"4", 						"生还者团队不超过4人时有多少个特感", _, true, 0.0, true, 32.0);
	g_cvExtraLimit = 				CreateConVar("ss_extra_limit", 			"1", 						"生还者团队每增加一人可增加多少个特感", _, true, 0.0, true, 32.0);
	g_cvBaseSize = 					CreateConVar("ss_base_size", 			"4", 						"生还者团队不超过4人时一次产生多少只特感", _, true, 0.0, true, 32.0);
	g_cvExtraSize = 				CreateConVar("ss_extra_size", 			"2", 						"生还者团队每增加多少玩家人一次多产生一只特感", _, true, 1.0, true, 32.0);
	g_cvTankStatusAction = 			CreateConVar("ss_tankstatus_action", 	"1", 						"坦克产生后是否对当前刷特参数进行修改, 坦克死完后恢复?[0 = 忽略(保持原有的刷特状态) | 1 = 自定义]", _, true, 0.0, true, 1.0);
	g_cvTankStatusLimits = 			CreateConVar("ss_tankstatus_limits", 	"2;1;4;1;4;4", 				"坦克产生后每种特感数量的自定义参数");
	g_cvTankStatusWeights = 		CreateConVar("ss_tankstatus_weights",	"100;400;100;200;100;100",	"坦克产生后每种特感比重的自定义参数");
	g_cvSuicideTime = 				CreateConVar("ss_suicide_time", 		"25.0", 					"特感自动处死时间", _, true, 1.0);
	g_cvRushDistance = 				CreateConVar("ss_rush_distance", 		"1200.0", 					"路程超过多少算跑图(最前面的玩家路程减去最后面的玩家路程, 忽略倒地玩家)", _, true, 0.0);

	g_cvSpawnRange = FindConVar("z_spawn_range");
	g_cvSpawnRange.Flags &= ~FCVAR_NOTIFY;
	g_cvDiscardRange = FindConVar("z_discard_range");
	g_cvDiscardRange.Flags &= ~FCVAR_NOTIFY;

	g_cvSpawnSize.AddChangeHook(vCvarChanged_Limits);
	for (int i; i < 6; i++) {
		g_cvSpawnLimits[i].AddChangeHook(vCvarChanged_Limits);
		g_cvSpawnWeights[i].AddChangeHook(vCvarChanged_General);
	}

	g_cvSILimit.AddChangeHook(vCvarChanged_Times);
	g_cvSpawnTimeMin.AddChangeHook(vCvarChanged_Times);
	g_cvSpawnTimeMax.AddChangeHook(vCvarChanged_Times);
	g_cvSpawnTimeMode.AddChangeHook(vCvarChanged_Times);

	g_cvScaleWeights.AddChangeHook(vCvarChanged_General);
	g_cvBaseLimit.AddChangeHook(vCvarChanged_General);
	g_cvExtraLimit.AddChangeHook(vCvarChanged_General);
	g_cvBaseSize.AddChangeHook(vCvarChanged_General);
	g_cvExtraSize.AddChangeHook(vCvarChanged_General);
	g_cvSuicideTime.AddChangeHook(vCvarChanged_General);
	g_cvRushDistance.AddChangeHook(vCvarChanged_General);

	g_cvTankStatusAction.AddChangeHook(vCvarChanged_TankStatus);
	g_cvTankStatusLimits.AddChangeHook(vCvarChanged_TankCustom);
	g_cvTankStatusWeights.AddChangeHook(vCvarChanged_TankCustom);

	AutoExecConfig(true);

	HookEvent("round_end", 				Event_RoundEnd, 	EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving", Event_RoundEnd, 	EventHookMode_PostNoCopy);
	HookEvent("round_start", 			Event_RoundStart, 	EventHookMode_PostNoCopy);
	HookEvent("player_hurt", 			Event_PlayerHurt);
	HookEvent("player_team", 			Event_PlayerTeam);
	HookEvent("player_spawn", 			Event_PlayerSpawn);
	HookEvent("player_death", 			Event_PlayerDeath, 	EventHookMode_Pre);

	RegAdminCmd("sm_weight", 		cmdSetWeight, 	ADMFLAG_RCON, "设置特感生成比重");
	RegAdminCmd("sm_limit", 		cmdSetLimit, 	ADMFLAG_RCON, "设置特感生成数量");
	RegAdminCmd("sm_timer", 		cmdSetTimer, 	ADMFLAG_RCON, "设置特感生成时间");

	RegAdminCmd("sm_resetspawn", 	cmdResetSpawn, 	ADMFLAG_RCON, "处死所有特感并重新开始生成计时");
	RegAdminCmd("sm_forcetimer", 	cmdForceTimer, 	ADMFLAG_RCON, "开始生成计时");
	RegAdminCmd("sm_type", 			cmdType, 		ADMFLAG_ROOT, "随机轮换模式");

	HookEntityOutput("trigger_finale", "FinaleStart", OnFinaleStart);

	if (g_bLateLoad && L4D_HasAnySurvivorLeftSafeArea())
		L4D_OnFirstSurvivorLeftSafeArea_Post(0);
}

public void OnPluginEnd() {
	g_cvSpawnRange.RestoreDefault();
	g_cvDiscardRange.RestoreDefault();

	//FindConVar("director_no_specials").RestoreDefault();

	FindConVar("z_spawn_flow_limit").RestoreDefault();
	FindConVar("z_attack_flow_range").RestoreDefault();

	FindConVar("z_safe_spawn_range").RestoreDefault();
	FindConVar("z_spawn_safety_range").RestoreDefault();

	FindConVar("z_finale_spawn_safety_range").RestoreDefault();
	FindConVar("z_finale_spawn_tank_safety_range").RestoreDefault();
}

void OnFinaleStart(const char[] output, int caller, int activator, float delay) {
	g_bFinaleStarted = true;
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) {
	static int value;
	if (!g_bInSpawnTime) {
		if (strcmp(key, "MaxSpecials", false) == 0) {
			retVal = 0;
			return Plugin_Handled;
		}

		return Plugin_Continue;	
	}
	
	value = retVal;
	if (strcmp(key, "MaxSpecials", false) == 0)
		value = g_iSILimit;
	else if (strcmp(key, "PreferredSpecialDirection", false) == 0)
		value = g_iPreferredDirection;

	if (value != retVal) {
		retVal = value;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client) {
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
	delete g_hSuicideTimer;
	g_hSuicideTimer = CreateTimer(2.0, tmrForceSuicide, _, TIMER_REPEAT);
}

Action tmrForceSuicide(Handle timer) {
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
			g_fActionTimes[i] = fEngineTime;
			continue;
		}

		victim = iGetSurVictim(i, iClass);
		if (victim > 0) {
			if (GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
				vKillInactiveSI(i);
			else
				g_fActionTimes[i] = fEngineTime;
		}
		else if (fEngineTime - g_fActionTimes[i] > g_fSuicideTime)
			vKillInactiveSI(i);
	}

	return Plugin_Continue;
}

void vKillInactiveSI(int client) {
	#if DEBUG
	PrintToServer("[SS] Kill inactive SI -> %N", client);
	#endif
	ForcePlayerSuicide(client);

	if (!g_hRetryTimer)
		CreateTimer(1.0, tmrRetrySpawn, true);
}

int iGetSurVictim(int client, int iClass) {
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

Action cmdSetLimit(int client, int args) {
	if (args == 1) {
		char sArg[16];
		GetCmdArg(1, sArg, sizeof sArg);	
		if (strcmp(sArg, "reset", false) == 0) {
			vResetLimits();
			ReplyToCommand(client, "[SS] Spawn Limits reset to default values");
		}
	}
	else if (args == 2) {
		int iLimit = GetCmdArgInt(2);	
		if (iLimit < 0)
			ReplyToCommand(client, "[SS] Limit value must be >= 0");
		else {
			char sArg[16];
			GetCmdArg(1, sArg, sizeof sArg);
			if (strcmp(sArg, "all", false) == 0) {
				for (int i; i < 6; i++)
					g_cvSpawnLimits[i].IntValue = iLimit;

				PrintToChatAll("\x01[SS] All SI limits have been set to \x05%d", iLimit);
			} 
			else if (strcmp(sArg, "max", false) == 0) {
				g_cvSILimit.IntValue = iLimit;
				PrintToChatAll("\x01[SS] -> \x04Max \x01SI limit set to \x05%i", iLimit);				   
			} 
			else if (strcmp(sArg, "group", false) == 0 || strcmp(sArg, "wave", false) == 0) {
				g_cvSpawnSize.IntValue = iLimit;
				PrintToChatAll("\x01[SS] -> SI will spawn in \x04groups\x01 of \x05%i", iLimit);
			} 
			else  {
				for (int i; i < 6; i++) {
					if (strcmp(g_sZombieClass[i], sArg, false) == 0) {
						g_cvSpawnLimits[i].IntValue = iLimit;
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

Action cmdSetWeight(int client, int args) {
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
			char sArg[16];
			GetCmdArg(1, sArg, sizeof sArg);
			int iWeight = GetCmdArgInt(2);
			if (strcmp(sArg, "all", false) == 0) {
				for (int i; i < 6; i++)
					g_cvSpawnWeights[i].IntValue = iWeight;			

				ReplyToCommand(client, "\x01[SS] -> \x04All spawn weights \x01set to \x05%d", iWeight);	
			} 
			else  {
				for (int i; i < 6; i++) {
					if (strcmp(sArg, g_sZombieClass[i], false) == 0) {
						g_cvSpawnWeights[i].IntValue = iWeight;
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

Action cmdSetTimer(int client, int args) {
	if (args == 1) {
		float fTime = GetCmdArgFloat(1);
		if (fTime < 0.1)
			fTime = 0.1;

		g_cvSpawnTimeMin.FloatValue = fTime;
		g_cvSpawnTimeMax.FloatValue = fTime;
		ReplyToCommand(client, "\x01[SS] Spawn timer set to constant \x05%.1f \x01seconds", fTime);
	} 
	else if (args == 2) {
		float fMin = GetCmdArgFloat(1);
		float fMax = GetCmdArgFloat(2);
		if (fMin > 0.1 && fMax > 1.0 && fMax > fMin) {
			g_cvSpawnTimeMin.FloatValue = fMin;
			g_cvSpawnTimeMax.FloatValue = fMax;
			ReplyToCommand(client, "\x01[SS] Spawn timer will be between \x05%.1f \x01and \x05%.1f \x01seconds", fMin, fMax);
		} 
		else 
			ReplyToCommand(client, "[SS] Max(>= 1.0) spawn time must greater than min(>= 0.1) spawn time");
	} 
	else 
		ReplyToCommand(client, "[SS] timer <constant> || timer <min> <max>");

	return Plugin_Handled;
}

Action cmdResetSpawn(int client, int args) {	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") != 8)
			ForcePlayerSuicide(i);
	}

	vStartCustomSpawnTimer(g_fSpawnTimes[0]);
	ReplyToCommand(client, "[SS] Slayed all special infected. Spawn timer restarted. Next potential spawn in %.1f seconds.", g_fSpawnTimeMin);
	return Plugin_Handled;
}

Action cmdForceTimer(int client, int args) {
	if (args < 1) {
		vStartSpawnTimer();
		ReplyToCommand(client, "[SS] Spawn timer started manually.");
		return Plugin_Handled;
	}

	float fTime = GetCmdArgFloat(1);
	vStartCustomSpawnTimer(fTime < 0.1 ? 0.1 : fTime);
	ReplyToCommand(client, "[SS] Spawn timer started manually. Next potential spawn in %.1f seconds.", fTime);
	return Plugin_Handled;
}

Action cmdType(int client, int args) {
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
			vSetSiType(iClass);
			PrintToChatAll("\x01[\x05%s\x01]\x04模式\x01", g_sZombieClass[iClass]);
		}
	}

	return Plugin_Handled;
}

int iGetZombieClass(const char[] sClass) {
	for (int i; i < 6; i++) {
		if (strcmp(sClass, g_sZombieClass[i], false) == 0)
			return i;
	}
	return -1;
}

int iSetRandomType() {
	static int iClass;
	static int iValue;
	static int iZombieClass[6] = {0, 1, 2, 3, 4, 5};
	if (iClass == 0)
		SortIntegers(iZombieClass, 6, Sort_Random);

	vSetSiType(iZombieClass[iClass]);
	g_iCurrentClass += 6;
	iValue = iClass;

	iClass++;
	iClass -= RoundToFloor(iClass / 6.0) * 6;
	return iZombieClass[(iValue - RoundToFloor(iValue / 6.0) * 6)];
}

void vSetSiType(int iClass) {
	for (int i; i < 6; i++)		
		g_cvSpawnLimits[i].IntValue = i != iClass ? 0 : g_iSILimit;

	g_iCurrentClass = iClass;
}

public void OnConfigsExecuted() {
	vGetCvars_Limits();
	vGetCvars_Times();
	vGetCvars_General();
	vGetCvars_TankStatus();
	vGetCvars_TankCustom();
	vSetDirectorConvars();
}

void vCvarChanged_Limits(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars_Limits();
}

void vGetCvars_Limits() {
	g_iSpawnSize = g_cvSpawnSize.IntValue;
	for (int i; i < 6; i++)
		g_iSpawnLimits[i] = g_cvSpawnLimits[i].IntValue;
}

void vCvarChanged_Times(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars_Times();
}

void vGetCvars_Times() {
	g_iSILimit = g_cvSILimit.IntValue;
	g_fSpawnTimeMin = g_cvSpawnTimeMin.FloatValue;
	g_fSpawnTimeMax = g_cvSpawnTimeMax.FloatValue;
	g_iSpawnTimeMode = g_cvSpawnTimeMode.IntValue;

	if (g_fSpawnTimeMin > g_fSpawnTimeMax)
		g_fSpawnTimeMin = g_fSpawnTimeMax;
		
	vCalculateSpawnTimes();
}

void vCalculateSpawnTimes() {
	if (g_iSILimit <= 1 || g_iSpawnTimeMode <= 0)
		g_fSpawnTimes[0] = g_fSpawnTimeMax;
	else {
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
}

void vCvarChanged_General(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars_General();
}

void vGetCvars_General() {
	g_bScaleWeights = g_cvScaleWeights.BoolValue;

	for (int i; i < 6; i++)
		g_iSpawnWeights[i] = g_cvSpawnWeights[i].IntValue;

	g_iBaseLimit = g_cvBaseLimit.IntValue;
	g_fExtraLimit = g_cvExtraLimit.FloatValue;
	g_iBaseSize = g_cvBaseSize.IntValue;
	g_fExtraSize = g_cvExtraSize.FloatValue;
	g_fSuicideTime = g_cvSuicideTime.FloatValue;
	g_fRushDistance = g_cvRushDistance.FloatValue;
}

void vCvarChanged_TankStatus(ConVar convar, const char[] oldValue, const char[] newValue) {
	int iLast = g_iTankStatusAction;

	vGetCvars_TankStatus();
	if (iLast != g_iTankStatusAction)
		vTankStatusActoin(bFindTank(-1));
}

void vGetCvars_TankStatus() {
	g_iTankStatusAction = g_cvTankStatusAction.IntValue;
}

void vCvarChanged_TankCustom(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars_TankCustom();
}

void vGetCvars_TankCustom() {
	char sTemp[64];
	g_cvTankStatusLimits.GetString(sTemp, sizeof sTemp);

	char buffers[6][8];
	ExplodeString(sTemp, ";", buffers, sizeof buffers, sizeof buffers[]);
	
	int i;
	int value;
	for (; i < 6; i++) {
		if (buffers[i][0] == '\0') {
			g_iTankStatusLimits[i] = -1;
			continue;
		}
		
		if ((value = StringToInt(buffers[i])) < -1 || value > g_iSILimit) {
			g_iTankStatusLimits[i] = -1;
			buffers[i][0] = '\0';
			continue;
		}
	
		g_iTankStatusLimits[i] = value;
		buffers[i][0] = '\0';
	}
	
	g_cvTankStatusWeights.GetString(sTemp, sizeof sTemp);
	ExplodeString(sTemp, ";", buffers, sizeof buffers, sizeof buffers[]);
	
	for (i = 0; i < 6; i++) {
		if (buffers[i][0] == '\0' || (value = StringToInt(buffers[i])) < 0) {
			g_iTankStatusWeights[i] = -1;
			continue;
		}

		g_iTankStatusWeights[i] = value;
	}
}

void vSetDirectorConvars() {
	g_cvSpawnRange.IntValue = 1000;
	//g_cvDiscardRange.IntValue = 2500;

	//FindConVar("director_no_specials").IntValue = 1;

	FindConVar("z_spawn_flow_limit").IntValue = 999999;
	FindConVar("z_attack_flow_range").IntValue = 999999;

	FindConVar("z_safe_spawn_range").IntValue = 1;
	FindConVar("z_spawn_safety_range").IntValue = 1;

	FindConVar("z_finale_spawn_safety_range").IntValue = 1;
	FindConVar("z_finale_spawn_tank_safety_range").IntValue = 1;
}

public void OnClientDisconnect(int client) {
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		return;
		
	CreateTimer(0.1, tmrTankDisconnect, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd() {
	g_bLeftSafeArea = false;
	g_bFinaleStarted = false;

	vEndSpawnTimer();
	delete g_hSuicideTimer;
	vTankStatusActoin(false);

	if (g_iCurrentClass >= 6)
		iSetRandomType();
	else if (g_iCurrentClass > -1)
		vSetSiType(g_iCurrentClass);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	vEndSpawnTimer();
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bLeftSafeArea)
		return;

	g_fActionTimes[GetClientOfUserId(event.GetInt("userid"))] = GetEngineTime();
	g_fActionTimes[GetClientOfUserId(event.GetInt("attacker"))] = GetEngineTime();
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;

	if (event.GetInt("team") == 2 || event.GetInt("oldteam") == 2) {
		delete g_hUpdateTimer;
		g_hUpdateTimer = CreateTimer(2.0, tmrUpdate);
	}
}

Action tmrUpdate(Handle timer) {
	g_hUpdateTimer = null;
	vSetMaxSpecialsCount();
	return Plugin_Continue;
}

void vSetMaxSpecialsCount() {
	int iCount;
	int iLimit;
	int iSize;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			iCount++;
	}

	iCount -= 4;
	if (iCount < 1) {
		iLimit = g_iBaseLimit;
		iSize = g_iBaseSize;
	}
	else {
		iLimit = g_iBaseLimit + RoundToNearest(g_fExtraLimit * iCount);
		iSize = g_iBaseSize + RoundToNearest(iCount / g_fExtraSize);
	}

	if (iLimit == g_iSILimit && iSize == g_iSpawnSize)
		return;

	g_cvSILimit.IntValue = iLimit;
	g_cvSpawnSize.IntValue = iSize;
	PrintToChatAll("\x01[\x05%d特\x01/\x05次\x01] \x05%d特 \x01[\x03%.1f\x01~\x03%.1f\x01]\x04秒", iSize <= iLimit ? iSize : iLimit, iLimit, g_fSpawnTimeMin, g_fSpawnTimeMax);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 8)
		g_fActionTimes[client] = GetEngineTime();
	else
		CreateTimer(0.1, tmrTankSpawn, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;

	static int iClass;
	iClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (iClass == 8 && !bFindTank(client))
		vTankStatusActoin(false);

	if (iClass != 4 && IsFakeClient(client))
		RequestFrame(OnNextFrame_KickBot, event.GetInt("userid"));
}

Action tmrTankSpawn(Handle timer, int client) {
	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || bFindTank(client))
		return Plugin_Stop;

	int iTotalLimit;
	int iTotalWeight;
	for (int i; i < 6; i++) {
		iTotalLimit += g_iSpawnLimits[i];
		iTotalWeight += g_iSpawnWeights[i];
	}

	if (iTotalLimit && iTotalWeight)
		vTankStatusActoin(true);

	return Plugin_Continue;
}

void OnNextFrame_KickBot(any client) {
	if ((client = GetClientOfUserId(client)) && IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
		KickClient(client);
}

bool bFindTank(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8)
			return true;
	}
	return false;
}

Action tmrTankDisconnect(Handle timer) {
	if (bFindTank(-1))
		return Plugin_Stop;

	vTankStatusActoin(false);
	return Plugin_Continue;
}

void vTankStatusActoin(bool bIsTankAlive) {
	static bool bLoad;
	if (!bIsTankAlive) {
		if (bLoad) {
			bLoad = false;
			vLoadCacheSpawnLimits();
			vLoadCacheSpawnWeights();
		}
	}
	else {
		if (!bLoad && g_iTankStatusAction) {
			bLoad = true;
			for (int i; i < 6; i++) {
				g_iSpawnLimitsCache[i] = g_iSpawnLimits[i];
				g_iSpawnWeightsCache[i] = g_iSpawnWeights[i];
			}
			vLoadCacheTankCustom();
		}
	}
}

void vLoadCacheSpawnLimits() {
	if (g_iSILimitCache != -1) {
		g_cvSILimit.IntValue = g_iSILimitCache;
		g_iSILimitCache = -1;
	}

	if (g_iSpawnSizeCache != -1) {
		g_cvSpawnSize.IntValue = g_iSpawnSizeCache;
		g_iSpawnSizeCache = -1;
	}

	for (int i; i < 6; i++) {		
		if (g_iSpawnLimitsCache[i] != -1) {
			g_cvSpawnLimits[i].IntValue = g_iSpawnLimitsCache[i];
			g_iSpawnLimitsCache[i] = -1;
		}
	}
}

void vLoadCacheSpawnWeights() {
	for (int i; i < 6; i++) {		
		if (g_iSpawnWeightsCache[i] != -1) {
			g_cvSpawnWeights[i].IntValue = g_iSpawnWeightsCache[i];
			g_iSpawnWeightsCache[i] = -1;
		}
	}
}

void vLoadCacheTankCustom() {
	for (int i; i < 6; i++) {
		if (g_iTankStatusLimits[i] != -1)
			g_cvSpawnLimits[i].IntValue = g_iTankStatusLimits[i];
			
		if (g_iTankStatusWeights[i] != -1)
			g_cvSpawnWeights[i].IntValue = g_iTankStatusWeights[i];
	}
}

void vResetLimits() {
	for (int i; i < 6; i++)
		g_cvSpawnLimits[i].RestoreDefault();
}

void vResetWeights() {
	for (int i; i < 6; i++)
		g_cvSpawnWeights[i].RestoreDefault();
}

void vStartCustomSpawnTimer(float fTime) {
	vEndSpawnTimer();
	g_hSpawnTimer = CreateTimer(fTime, tmrSpawnSpecial);
}

void vStartSpawnTimer() {
	vEndSpawnTimer();
	g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[iGetTotalSI()] : GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrSpawnSpecial);
}

void vEndSpawnTimer() {
	delete g_hSpawnTimer;
	delete g_hRetryTimer;
}

Action tmrSpawnSpecial(Handle timer) { 
	g_hSpawnTimer = null;
	delete g_hRetryTimer;

	int iTotalSI = iGetTotalSI();
	vExecuteSpawnQueue(iTotalSI, true);

	g_hSpawnTimer = CreateTimer(g_iSpawnTimeMode > 0 ? g_fSpawnTimes[iTotalSI] : GetRandomFloat(g_fSpawnTimeMin, g_fSpawnTimeMax), tmrSpawnSpecial);
	return Plugin_Continue;
}

void vExecuteSpawnQueue(int iTotalSI, bool bRetry) {
	if (iTotalSI >= g_iSILimit)
		return;

	#if BENCHMARK
	g_profiler = new Profiler();
	g_profiler.Start();
	#endif

	static int iSize;
	static int iAllowedSI;
	iAllowedSI = g_iSILimit - iTotalSI;
	iSize = g_iSpawnSize > iAllowedSI ? iAllowedSI : g_iSpawnSize;

	static int i;
	static int index;
	static int count;
	static int client;
	static bool bFind;
	static float flow;
	static float lastFlow;
	static float vPos[3];
	static ArrayList aList;

	iGetSITypeCount();
	g_aSpawnQueue.Clear();
	for (i = 0; i < iSize; i++) {
		index = iGenerateIndex();
		if (index == -1)
			break;

		g_aSpawnQueue.Push(index);
		g_iSpawnCounts[index]++;
	}

	iSize = g_aSpawnQueue.Length;
	if (!iSize)
		return;

	aList = new ArrayList(2);
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !GetEntProp(i, Prop_Send, "m_isIncapacitated")) {
			flow = L4D2Direct_GetFlowDistance(i);
			if (flow && flow != -9999.0)
				aList.Set(aList.Push(flow), i, 1);
		}
	}

	count = aList.Length;
	if (!count) {
		delete aList;
		return;
	}

	aList.Sort(Sort_Descending, Sort_Float);

	bFind = false;
	client = aList.Get(0, 1);
	flow = aList.Get(0, 0);
	lastFlow = aList.Get(count - 1, 0);
	if (flow - lastFlow > g_fRushDistance) {
		#if DEBUG
		PrintToServer("[SS] Rusher -> %N", client);
		#endif

		bFind = true;
	}

	delete aList;
	g_bInSpawnTime = true;
	g_cvSpawnRange.IntValue = bRetry ? 1000 : 1500;
	g_iPreferredDirection = g_bFinaleStarted ? SPAWN_NEAR_IT_VICTIM : (!bFind ? SPAWN_LARGE_VOLUME/*SPAWN_SPECIALS_ANYWHERE*/ : SPAWN_SPECIALS_IN_FRONT_OF_SURVIVORS);

	count = 0;
	bFind = false;
	for (i = 0; i < iSize; i++) {
		index = g_aSpawnQueue.Get(i) + 1;
		if (L4D_GetRandomPZSpawnPosition(client, index, 10, vPos))
			bFind = true;

		if (bFind && L4D2_SpawnSpecial(index, vPos, NULL_VECTOR) > 0)
			count++;
	}

	g_bInSpawnTime = false;

	#if BENCHMARK
	g_profiler.Stop();
	PrintToServer("[SS] ProfilerTime: %f", g_profiler.Time);
	#endif

	if (bRetry) {
		if (!count) {
			#if DEBUG
			PrintToServer("[SS] Retry spawn SI! spawned:%d failed:%d", count, g_aSpawnQueue.Length - count);
			#endif
			g_hRetryTimer = CreateTimer(1.0, tmrRetrySpawn, false);
		}
	}
	#if DEBUG
	else {
		if (!count)
			PrintToServer("[SS] Spawn SI failed! spawned:%d failed:%d", count, g_aSpawnQueue.Length - count);
	}
	#endif
}

Action tmrRetrySpawn(Handle timer, bool bRetry) {
	g_hRetryTimer = null;
	vExecuteSpawnQueue(iGetTotalSI(), bRetry);
	return Plugin_Continue;
}

int iGetTotalSI() {
	int count;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsClientInKickQueue(i) || GetClientTeam(i) != 3)
			continue;
	
		if (IsPlayerAlive(i)) {
			if (1 <= GetEntProp(i, Prop_Send, "m_zombieClass") <= 6)
				count++;
		}
		else if (IsFakeClient(i))
			KickClient(i);
	}
	return count;
}

void iGetSITypeCount() {
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

int iGenerateIndex() {	
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
