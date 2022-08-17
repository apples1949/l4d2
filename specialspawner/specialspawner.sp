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

Address
	g_pStaticDirection[2];

Handle
	g_hSpawnTimer,
	g_hForceSuicideTimer;

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
	g_iCurrentClass = -1;

bool
	g_bIsLinux,
	g_bLateLoad,
	g_bInSpawnTime,
	g_bScaleWeights,
	g_bLeftSafeArea;

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
	g_hRusherDistance = CreateConVar("ss_rusher_distance", "1200.0", "路程超过多少算跑图", _, true, 500.0);
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
	vStaticDirectionPatch(false);

	g_hSpawnRange.RestoreDefault();
	g_hDiscardRange.RestoreDefault();

	FindConVar("z_spawn_flow_limit").RestoreDefault();
	FindConVar("z_attack_flow_range").RestoreDefault();

	FindConVar("z_safe_spawn_range").RestoreDefault();
	FindConVar("z_spawn_safety_range").RestoreDefault();

	FindConVar("z_finale_spawn_safety_range").RestoreDefault();
	FindConVar("z_finale_spawn_tank_safety_range").RestoreDefault();
}

void vInitData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_bIsLinux = hGameData.GetOffset("OS") == 1;

	vInitPatchs(hGameData);

	delete hGameData;
}

void vInitPatchs(GameData hGameData = null)
{
	Address pAddr = hGameData.GetMemSig("ZombieManager::GetRandomPZSpawnPosition");
	if (!pAddr)
		SetFailState("Failed to find address: \"ZombieManager::GetRandomPZSpawnPosition\"");

	int iOffset = hGameData.GetOffset("StaticDirection_Offset_1");
	if (iOffset == -1)
		SetFailState("Failed to find offset: \"StaticDirection_Offset_1\"");

	int iByteMatch = hGameData.GetOffset("StaticDirection_Byte_1");
	if (iByteMatch == -1)
		SetFailState("Failed to find byte: \"StaticDirection_Byte_1\"");

	g_pStaticDirection[0] = pAddr + view_as<Address>(iOffset);
	int iByteOrigin = LoadFromAddress(g_pStaticDirection[0], NumberType_Int8);
	if (iByteOrigin != iByteMatch)
		SetFailState("Failed to load \"CTerrorPlayer::StaticDirection\", byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);

	iOffset = hGameData.GetOffset("StaticDirection_Offset_2");
	if (iOffset == -1)
		SetFailState("Failed to find offset: \"StaticDirection_Offset_2\"");

	iByteMatch = hGameData.GetOffset("StaticDirection_Byte_2");
	if (iByteMatch == -1)
		SetFailState("Failed to find byte: \"StaticDirection_Byte_2\"");

	g_pStaticDirection[1] = pAddr + view_as<Address>(iOffset);
	iByteOrigin = LoadFromAddress(g_pStaticDirection[0], NumberType_Int8);
	if (iByteOrigin != iByteMatch)
		SetFailState("Failed to load \"CTerrorPlayer::StaticDirection\", byte mis-match @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
}

void vStaticDirectionPatch(bool bPatch)
{
	static bool bPatched;
	if (!bPatched && bPatch) {
		bPatched = true;
		StoreToAddress(g_pStaticDirection[0], g_iPreferredDirection, g_bIsLinux ? NumberType_Int32 : NumberType_Int8);
		StoreToAddress(g_pStaticDirection[1], g_iPreferredDirection, g_bIsLinux ? NumberType_Int32 : NumberType_Int8);
	}
	else if (bPatched && !bPatch) {
		bPatched = false;
		StoreToAddress(g_pStaticDirection[0], SPAWN_SPECIALS_ANYWHERE, g_bIsLinux ? NumberType_Int32 : NumberType_Int8);
		StoreToAddress(g_pStaticDirection[1], SPAWN_SPECIALS_ANYWHERE, g_bIsLinux ? NumberType_Int32 : NumberType_Int8);
	}
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	static int iValue;
	if (!g_bInSpawnTime) {
		if (strcmp(key, "MaxSpecials", false) == 0) {
			retVal = 0;
			return Plugin_Handled;
		}

		return Plugin_Continue;
	}

	iValue = retVal;
	if (strcmp(key, "MaxSpecials", false) == 0)
		iValue = g_iSILimit;
	else if (strcmp(key, "PreferredSpecialDirection", false) == 0)
		iValue = g_iPreferredDirection;
	else if (strcmp(key, "ShouldIgnoreClearStateForSpawn", false) == 0)
		iValue = 1;
	else if (strcmp(key, "ShouldConstrainLargeVolumeSpawn", false) == 0)
		iValue = 0;

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
	PrintToServer("[SS] Kill Inactive SI: %N", client);
	#endif
	ForcePlayerSuicide(client);
	g_aSpawnQueue.Push(iClass - 1);
	CreateTimer(0.1, tmrRetrySpawn, _, TIMER_FLAG_NO_MAPCHANGE);
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
	g_hDiscardRange.IntValue = 1500;

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

public void OnMapEnd()
{
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
	userid = event.GetInt("userid");
	client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != 3)
		return;
	
	int iClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	if (iClass == 8 && !bFindTank(client))
		vTankSpawnDeathActoin(false);

	if (iClass != 4 && IsFakeClient(client))
		RequestFrame(OnNextFrame_KickBot, userid);
}

Action tmrTankSpawn(Handle timer, int client)
{
	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || bFindTank(client))
		return Plugin_Stop;

	if (!g_iSILimit)
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
	if (bIsTankAlive) {
		if (!bLoad && g_iTankSpawnAction) {
			bLoad = true;
			for (int i; i < 6; i++) {
				g_iSpawnLimitsCache[i] = g_iSpawnLimits[i];
				g_iSpawnWeightsCache[i] = g_iSpawnWeights[i];
			}
			vLoadCacheTankCustom();
		}
	}
	else {
		if (bLoad) {
			bLoad = false;
			vLoadCacheSpawnLimits();
			vLoadCacheSpawnWeights();
		}
	}
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
}

Action tmrAutoSpawnInfected(Handle timer)
{ 
	g_hSpawnTimer = null;
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
	static int iClass;
	static bool bFind;
	static float flow;
	static float vPos[3];
	static ArrayList aList;

	iGetSIClass();
	g_aSpawnQueue.Clear();
	for (i = 0; i < iSize; i++) {
		iClass = iGenerateIndex();
		if (iClass == -1)
			break;

		g_aSpawnQueue.Push(iClass);
		g_iSpawnCounts[iClass]++;
	}

	iSize = g_aSpawnQueue.Length;
	if (!iSize)
		return;

	aList = new ArrayList(2);
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			flow = L4D2Direct_GetFlowDistance(i);
			if (flow && flow != -9999.0)
				aList.Set(aList.Push(flow), i, 1);
		}
	}

	iCount = aList.Length;
	if (!iCount) {
		delete aList;
		return;
	}

	aList.Sort(Sort_Descending, Sort_Float);
	client = aList.Get(0, 1);
	bFind = false;

	if (iCount >= 2) {
		flow = aList.Get(0, 0);

		static float lastFlow;
		lastFlow = aList.Get(iCount - 1, 0);
		if (flow - lastFlow > g_fRusherDistance) {
			#if DEBUG
			PrintToServer("[SS] Rusher->%N", client);
			#endif

			bFind = true;
		}
	}

	delete aList;
	bFind = false;
	g_bInSpawnTime = true;
	flow = GetEngineTime();
	g_iPreferredDirection = bFind ? SPAWN_IN_FRONT_OF_SURVIVORS : SPAWN_ANYWHERE;
	vStaticDirectionPatch(true);

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
	vStaticDirectionPatch(false);

	if (g_aSpawnQueue.Length) {
		#if DEBUG
		PrintToServer("[SS] Retry Spawn SI");
		#endif
		CreateTimer(0.1, tmrRetrySpawn, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action tmrRetrySpawn(Handle timer)
{
	static int i;
	static int iSize;
	static int client;
	static bool bFind;
	static int iClass;
	static float vPos[3];

	if (!g_bLeftSafeArea)
		return Plugin_Stop;

	iSize = g_aSpawnQueue.Length;
	if (!iSize)
		return Plugin_Stop;

	client = L4D_GetHighestFlowSurvivor();
	if (!client)
		return Plugin_Stop;

	bFind = false;
	g_bInSpawnTime = true;
	g_iPreferredDirection = SPAWN_IN_FRONT_OF_SURVIVORS;
	//vStaticDirectionPatch(true);

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
	//vStaticDirectionPatch(false);
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
