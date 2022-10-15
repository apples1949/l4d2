#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <l4d2_ems_hud>

#define PLUGIN_NAME				"Server Info Hud"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.2"
#define PLUGIN_URL				""

enum struct esData {
	int totalSI;
	int totalCI;

	void Clean() {
		this.totalSI = 0;
		this.totalCI = 0;
	}
}

esData
	g_esData;

Handle
	g_hTimer;

bool
	g_bLateLoad;

float
	g_fMapRunTime,
	g_fMapMaxFlow;

int
	g_iMaxChapters,
	g_iCurrentChapter;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	CreateConVar("server_info_version", PLUGIN_VERSION, "Server Info Hud plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	HookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_death",	Event_PlayerDeath,	EventHookMode_Pre);
	HookEvent("infected_death",	Event_InfectedDeath);

	if (g_bLateLoad) {
		delete g_hTimer;
		g_hTimer = CreateTimer(1.0, tmrUpdate, _, TIMER_REPEAT);
	}
}

public void OnConfigsExecuted() {
	g_fMapRunTime = GetEngineTime();
	g_fMapMaxFlow = L4D2Direct_GetMapMaxFlowDistance();

	g_iMaxChapters = L4D_GetMaxChapters();
	g_iCurrentChapter = L4D_GetCurrentChapter();
}

public void OnMapStart() {
	EnableHUD();
}

public void OnMapEnd() {
	delete g_hTimer;
	g_esData.Clean();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	delete g_hTimer;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	delete g_hTimer;
	g_hTimer = CreateTimer(1.0, tmrUpdate, _, TIMER_REPEAT);
}

Action tmrUpdate(Handle timer) {
	HUDSetLayout(HUD_SCORE_1, HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEXT, "➣统计: %d特感 %d僵尸", g_esData.totalSI, g_esData.totalCI);
	HUDPlace(HUD_SCORE_1, 0.73, 0.86, 1.0, 0.03);

	HUDSetLayout(HUD_SCORE_2, HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEXT, "➣运行: %dm", RoundToFloor((GetEngineTime() - g_fMapRunTime) / 60.0));
	HUDPlace(HUD_SCORE_2, 0.73, 0.89, 1.0, 0.03);

	HUDSetLayout(HUD_SCORE_3, HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEXT, "➣地图: %d/%d", g_iCurrentChapter, g_iMaxChapters);
	HUDPlace(HUD_SCORE_3, 0.73, 0.92, 1.0, 0.03);

	static int client;
	static float highestFlow;
	highestFlow = (client = L4D_GetHighestFlowSurvivor()) != -1 ? L4D2Direct_GetFlowDistance(client) : L4D2_GetFurthestSurvivorFlow();
	if (highestFlow)
		highestFlow = highestFlow / g_fMapMaxFlow * 100;

	HUDSetLayout(HUD_SCORE_4, HUD_FLAG_BLINK|HUD_FLAG_NOBG|HUD_FLAG_ALIGN_LEFT|HUD_FLAG_TEXT, "➣路程: %d％", RoundToCeil(highestFlow));
	HUDPlace(HUD_SCORE_4, 0.73, 0.95, 1.0, 0.03);

	return Plugin_Continue;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;
	
	g_esData.totalSI++;
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	g_esData.totalCI++;
}

