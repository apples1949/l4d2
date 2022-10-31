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
	g_cvDirectorNoSpec;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	g_cvDirectorNoBoss = FindConVar("director_no_bosses");
	g_cvDirectorNoSpec = FindConVar("director_no_specials");
}

public void OnPluginEnd() {
	g_cvDirectorNoBoss.RestoreDefault();
	g_cvDirectorNoSpec.RestoreDefault();
}

public void OnConfigsExecuted() {
	g_cvDirectorNoBoss.IntValue = 1;
	g_cvDirectorNoSpec.IntValue = 1;
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