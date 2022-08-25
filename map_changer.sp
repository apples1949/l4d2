#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_VERSION	"1.0.2"
#define CVAR_FLAGS		FCVAR_NOTIFY

enum {
	FINAL_MAP,
	FIRST_MAP,
	MAP_TRANSLATE,
}

enum {
	FINALE_CHANGE_NONE			= 0,
	FINALE_CHANGE_VEHICLE_LEAVE	= 1,
	FINALE_CHANGE_FINALE_WIN	= 2,
	FINALE_CHANGE_CREDITS_START	= 4,
	FINALE_CHANGE_CREDITS_END	= 8
}

static const char
	g_sValveMaps[][][] = {
		//FINAL_MAP					FIRST_MAP
		{"c14m2_lighthouse",		"c1m1_hotel"},
		{"c1m4_atrium",				"c2m1_highway"},
		{"c2m5_concert",			"c3m1_plankcountry"},
		{"c3m4_plantation",			"c4m1_milltown_a"},
		{"c4m5_milltown_escape",	"c5m1_waterfront"},
		{"c5m5_bridge",				"c6m1_riverbank"},
		{"c6m3_port",				"c7m1_docks"},
		{"c7m3_port",				"c8m1_apartment"},
		{"c8m5_rooftop",			"c9m1_alleys"},
		{"c9m2_lots",				"c10m1_caves"},
		{"c10m5_houseboat",			"c11m1_greenhouse"},
		{"c11m5_runway",			"c12m1_hilltop"},
		{"c12m5_cornfield",			"c13m1_alpinecreek"},
		{"c13m4_cutthroatcreek",	"c14m1_junkyard"},
	};

char
	g_sNextMap[128];

bool
	g_bUMHooked,
	g_bIsFinalMap,
	g_bChangeLevel;

UserMsg
	g_umStatsCrawlMsg;

ConVar
	g_hFinaleChangeType;

int
	g_iFinaleChangeType;

public Plugin myinfo = {
	name = "Map Changer",
	author = "Alex Dragokas",
	version = PLUGIN_VERSION
}

native void L4D2_ChangeLevel(const char[] sMapName, bool bShouldResetScores=true);
public void OnLibraryAdded(const char[] name) {
	if (strcmp(name, "l4d2_changelevel") == 0)
		g_bChangeLevel = true;
}

public void OnLibraryRemoved(const char[] name) {
	if (strcmp(name, "l4d2_changelevel") == 0)
		g_bChangeLevel = false;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	MarkNativeAsOptional("L4D2_ChangeLevel");
	
	CreateNative("MC_SetNextMap", aNative_SetNextMap);
	CreateNative("MC_FinaleMapChange", aNative_FinaleMapChange);
	RegPluginLibrary("map_changer");
	return APLRes_Success;
}

any aNative_SetNextMap(Handle plugin, int numParams) {
	int maxlength;
	GetNativeStringLength(1, maxlength);
	maxlength += 1;
	char[] buffer = new char[maxlength];
	GetNativeString(1, buffer, maxlength);
	if (!IsMapValidEx(buffer))
		return 0;

	strcopy(g_sNextMap, sizeof g_sNextMap, buffer);
	return 1;
}

any aNative_FinaleMapChange(Handle plugin, int numParams) {
	if (g_bIsFinalMap)
		vFinaleMapChange();

	return 0;
}

public void OnPluginStart() {
	g_umStatsCrawlMsg = GetUserMessageId("StatsCrawlMsg");
	HookUserMessage(GetUserMessageId("DisconnectToLobby"), umDisconnectToLobby, true);

	HookEvent("finale_win", 			Event_FinaleWin,		EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_leaving",	Event_VehicleLeaving,	EventHookMode_PostNoCopy);

	g_hFinaleChangeType = CreateConVar("mapchanger_finale_change_type", "12", "0 - 结局不换地图(返回大厅); 1 - 救援载具离开时; 2 - 结局获胜时; 4 - 统计屏幕出现时; 8 - 统计屏幕结束时", CVAR_FLAGS);
	g_hFinaleChangeType.AddChangeHook(vCvarChanged);

	RegAdminCmd("sm_setnext", cmdSetNext, ADMFLAG_RCON, "设置下一张地图");
}

Action cmdSetNext(int client, int args) {
	if (!g_bIsFinalMap) {
		ReplyToCommand(client, "当前地图非结局地图.");
		return Plugin_Handled;
	}
		
	if (args != 1) {
		ReplyToCommand(client, "\x01!setnext/sm_setnext <\x05地图代码\x01>.");
		return Plugin_Handled;
	}

	char sArg[128];
	GetCmdArg(1, sArg, sizeof sArg);
	if (!IsMapValidEx(sArg)) {
		ReplyToCommand(client, "无效的地图名.");
		return Plugin_Handled;
	}

	strcopy(g_sNextMap, sizeof g_sNextMap, sArg);
	ReplyToCommand(client, "\x01下一张地图已设置为 \x05%s\x01.", g_sNextMap);
	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	vGetCvars();
}

void vCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars();
}

void vGetCvars() {
	g_iFinaleChangeType = g_hFinaleChangeType.IntValue;
}

public void OnMapEnd() {
	g_sNextMap[0] = '\0';
}

public void OnMapStart() {
	g_bIsFinalMap = L4D_IsMissionFinalMap();
}

void vHookUserMessageCredits() {
	if (g_iFinaleChangeType & FINALE_CHANGE_CREDITS_START) {
		g_bUMHooked = true;
		HookUserMessage(g_umStatsCrawlMsg, umStatsCrawlMsg, false);
	}
}

Action umStatsCrawlMsg(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	UnhookUserMessage(g_umStatsCrawlMsg, umStatsCrawlMsg, false);
	g_bUMHooked = false;
	vFinaleMapChange();
	return Plugin_Continue;
}

Action umDisconnectToLobby(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	if (g_iFinaleChangeType & FINALE_CHANGE_CREDITS_END) {
		vFinaleMapChange();
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bIsFinalMap)
		return;

	if (g_iFinaleChangeType & FINALE_CHANGE_FINALE_WIN)
		vFinaleMapChange();

	if (!g_bUMHooked)
		vHookUserMessageCredits();
}

void Event_VehicleLeaving(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bIsFinalMap)
		return;

	if (g_iFinaleChangeType & FINALE_CHANGE_VEHICLE_LEAVE)
		vFinaleMapChange();

	if (!g_bUMHooked)
		vHookUserMessageCredits();
}

void vFinaleMapChange() {
	if (IsMapValidEx(g_sNextMap))
		vChangeLevel(g_sNextMap);
	else {
		char sMap[128];
		GetCurrentMap(sMap, sizeof sMap);
		vChangeLevel(g_sValveMaps[iFindMapId(sMap, FINAL_MAP)][FIRST_MAP]);
	}
}

int iFindMapId(const char[] sMap, const int type) {
	for (int i; i < sizeof g_sValveMaps; i++) {
		if (strcmp(sMap, g_sValveMaps[i][type], false) == 0)
			return i;
	}
	return 0;
}

void vChangeLevel(const char[] sMap) {
	if (g_bChangeLevel)
		L4D2_ChangeLevel(sMap, true);
	else
		ServerCommand("changelevel %s", sMap);
}

bool IsMapValidEx(char[] map) {
	char foundmap[1];
	return FindMap(map, foundmap, sizeof foundmap) != FindMap_NotFound;
}
