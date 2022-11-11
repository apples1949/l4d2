#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define PLUGIN_NAME				"Versus Coop Mode"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				""

#define GAMEDATA	"versus_coop_mode"

#define PATCH_SWAPTEAMS_PATCH1		"SwapTeams::Patch1"
#define PATCH_SWAPTEAMS_PATCH2		"SwapTeams::Patch2"
#define PATCH_CLEANUPMAP_PATCH		"CleanUpMap::ShouldCreateEntity::Patch"
#define PATCH_RESTARTVSMODE_PATCH1	"CDirectorVersusMode::RestartVsMode::Patch1"
#define PATCH_RESTARTVSMODE_PATCH2	"CDirectorVersusMode::RestartVsMode::Patch2"
#define DETOUR_RESTARTVSMODE		"DD::CDirectorVersusMode::RestartVsMode"

MemoryPatch
	g_mpRestartVsMode_Patch1,
	g_mpRestartVsMode_Patch2;

bool
	g_bTransition;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	InitGameData();
	CreateConVar("versus_coop_mode_version", PLUGIN_VERSION, "Versus Coop Mode plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookUserMessage(GetUserMessageId("VGUIMenu"), umVGUIMenu, true);
	HookEvent("round_start",	Event_RoundStart,		EventHookMode_PostNoCopy);
	HookEvent("map_transition",	Event_MapTransition,	EventHookMode_PostNoCopy);
}

void InitGameData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	InitPatchs(hGameData);
	SetupDetours(hGameData);

	delete hGameData;
}

void InitPatchs(GameData hGameData = null) {
	MemoryPatch patch = MemoryPatch.CreateFromConf(hGameData, PATCH_SWAPTEAMS_PATCH1);
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"%s\"", PATCH_SWAPTEAMS_PATCH1);
	else if (patch.Enable())
		PrintToServer("Enabled patch: \"%s\"", PATCH_SWAPTEAMS_PATCH1);

	patch = MemoryPatch.CreateFromConf(hGameData, PATCH_SWAPTEAMS_PATCH2);
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"%s\"", PATCH_SWAPTEAMS_PATCH2);
	else if (patch.Enable())
		PrintToServer("Enabled patch: \"%s\"", PATCH_SWAPTEAMS_PATCH2);

	patch = MemoryPatch.CreateFromConf(hGameData, PATCH_CLEANUPMAP_PATCH);
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"%s\"", PATCH_CLEANUPMAP_PATCH);
	else if (patch.Enable())
		PrintToServer("Enabled patch: \"%s\"", PATCH_CLEANUPMAP_PATCH);

	g_mpRestartVsMode_Patch1 = MemoryPatch.CreateFromConf(hGameData, PATCH_RESTARTVSMODE_PATCH1);
	if (!g_mpRestartVsMode_Patch1.Validate())
		SetFailState("Failed to verify patch: \"%s\"", PATCH_RESTARTVSMODE_PATCH1);

	g_mpRestartVsMode_Patch2 = MemoryPatch.CreateFromConf(hGameData, PATCH_RESTARTVSMODE_PATCH2);
	if (!g_mpRestartVsMode_Patch2.Validate())
		SetFailState("Failed to verify patch: \"%s\"", PATCH_RESTARTVSMODE_PATCH2);
}

void SetupDetours(GameData hGameData = null) {
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, DETOUR_RESTARTVSMODE);
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"%s\"", DETOUR_RESTARTVSMODE);

	if (!dDetour.Enable(Hook_Pre, DD_CDirectorVersusMode_RestartVsMode_Pre))
		SetFailState("Failed to detour pre: \"%s\"", DETOUR_RESTARTVSMODE);
		
	if (!dDetour.Enable(Hook_Post, DD_CDirectorVersusMode_RestartVsMode_Post))
		SetFailState("Failed to detour post: \"%s\"", DETOUR_RESTARTVSMODE);
}

MRESReturn DD_CDirectorVersusMode_RestartVsMode_Pre(Address pThis, DHookReturn hReturn) {
	if (g_bTransition && LoadFromAddress(pThis + view_as<Address>(6), NumberType_Int32))
		g_mpRestartVsMode_Patch1.Enable();
	else
		g_mpRestartVsMode_Patch2.Enable();

	return MRES_Ignored;
}

MRESReturn DD_CDirectorVersusMode_RestartVsMode_Post(Address pThis, DHookReturn hReturn) {
	g_mpRestartVsMode_Patch1.Disable();
	g_mpRestartVsMode_Patch2.Disable();
	return MRES_Ignored;
}

Action umVGUIMenu(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	static char buffer[254];
	msg.ReadString(buffer, sizeof buffer);
	if (strcmp(buffer, "fullscreen_vs_scoreboard") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnMapEnd() {
	g_bTransition = false;
}

void Event_RoundStart(Event event, char[] name, bool dontBroadcast) {
	g_bTransition = false;
}
 
void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) {
	g_bTransition = true;
}