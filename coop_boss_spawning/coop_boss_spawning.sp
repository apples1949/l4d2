#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <colors>
#include <left4dhooks>

#define PLUGIN_NAME				"Coop Boss Spawning"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				""

ConVar
	g_cvDirectorNoBoss,
	g_cvVersusBossFlowMin,
	g_cvVersusBossFlowMax;

float
	g_fVersusBossFlowMin,
	g_fVersusBossFlowMax;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	g_cvDirectorNoBoss =	FindConVar("director_no_bosses");
	g_cvVersusBossFlowMin =	FindConVar("versus_boss_flow_min");
	g_cvVersusBossFlowMax =	FindConVar("versus_boss_flow_max");
	g_cvVersusBossFlowMin.AddChangeHook(CvarChanged);
	g_cvVersusBossFlowMax.AddChangeHook(CvarChanged);

	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
}

public void OnPluginEnd() {
	g_cvDirectorNoBoss.RestoreDefault();
}

public void OnConfigsExecuted() {
	GetCvars();
	g_cvDirectorNoBoss.IntValue = 1;
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_fVersusBossFlowMin = g_cvVersusBossFlowMin.FloatValue;
	g_fVersusBossFlowMax = g_cvVersusBossFlowMax.FloatValue;
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal) {
	if (strcmp(key, "ProhibitBosses", false) == 0 || strcmp(key, "DisallowThreatType", false) == 0) {
		retVal = 0;
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client) {
	CPrintToChatAll("{olive}Tank{default}: {red}%d%%\n{olive}Witch{default}: {red}%d%%", RoundToCeil(L4D2Direct_GetVSTankFlowPercent(0) * 100.0), RoundToCeil(L4D2Direct_GetVSWitchFlowPercent(0) * 100.0));
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	CreateTimer(0.5, AdjustBossFlow, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action AdjustBossFlow(Handle timer) {
	SetTankFlowPercent(Math_GetRandomFloat(g_fVersusBossFlowMin, g_fVersusBossFlowMax));
	SetWitchFlowPercent(Math_GetRandomFloat(g_fVersusBossFlowMin, g_fVersusBossFlowMax));
	return Plugin_Continue;
}

void SetTankFlowPercent(float percent) {
	L4D2Direct_SetVSTankFlowPercent(0, percent);
	L4D2Direct_SetVSTankFlowPercent(1, percent);
	L4D2Direct_SetVSTankToSpawnThisRound(0, percent ? true : false);
	L4D2Direct_SetVSTankToSpawnThisRound(1, percent ? true : false);
}

void SetWitchFlowPercent(float percent) {
	L4D2Direct_SetVSWitchFlowPercent(0, percent);
	L4D2Direct_SetVSWitchFlowPercent(1, percent);
	L4D2Direct_SetVSWitchToSpawnThisRound(0, percent ? true : false);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, percent ? true : false);
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
float Math_GetRandomFloat(float min, float max)
{
	return (GetURandomFloat() * (max  - min)) + min;
}