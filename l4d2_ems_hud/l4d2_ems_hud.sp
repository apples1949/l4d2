#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_NAME				"L4D2 EMS HUD"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.2"
#define PLUGIN_URL				""

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	if (GetEngineVersion() != Engine_Left4Dead2) 
		LogError("Plugin only supports L4D2");

	CreateNative("HUDSetLayout", Native_HUDSetLayout);
	CreateNative("HUDPlace", Native_HUDPlace);
	CreateNative("HUDSlotIsUsed", Native_HUDSlotIsUsed);

	RegPluginLibrary("l4d2_ems_hud");

	return APLRes_Success;
}

// native void HUDSetLayout(SlotType slot, int flags, char[] dataval, any ...);
any Native_HUDSetLayout(Handle plugin, int numParams) {
	int slot = GetNativeCell(1);
	if (slot < 0 || slot > 15)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid SlotType");

	int written;
	static char buffer[128];
	int result = FormatNativeString(0, 3, 4, sizeof buffer, written, buffer);
	if (result == SP_ERROR_NONE)
		HUDSetLayout(slot, GetNativeCell(2), buffer);

	return 0;
}

// native void HUDPlace(SlotType slot, float x, float y, float width, float height);
any Native_HUDPlace(Handle plugin, int numParams) {
	int slot = GetNativeCell(1);
	if (slot < 0 || slot > 15)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid SlotType");

	HUDPlace(slot, GetNativeCell(2), GetNativeCell(3), GetNativeCell(4), GetNativeCell(5));
	return 0;
}

// native bool HUDSlotIsUsed(SlotType slot);
any Native_HUDSlotIsUsed(Handle plugin, int numParams) {
	int slot = GetNativeCell(1);
	if (slot < 0 || slot > 15)
		ThrowNativeError(SP_ERROR_PARAM, "Invalid SlotType");

	char str[1];
	return GameRules_GetPropString("m_szScriptedHUDStringSet", str, sizeof str, slot);
}

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	CreateConVar("l4d2_ems_hud_version", PLUGIN_VERSION, "L4D2 EMS HUD plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public void OnMapStart() {
	GameRules_SetProp("m_bChallengeModeActive", 1);
}

void HUDSetLayout(int slot, int flags, const char[] str) {
	GameRules_SetProp("m_iScriptedHUDFlags", flags, _, slot, true);
	GameRules_SetPropString("m_szScriptedHUDStringSet", str, true, slot);
}

void HUDPlace(int slot, float x, float y, float width, float height) {
	GameRules_SetPropFloat("m_fScriptedHUDPosX", x, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", y, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDWidth", width, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDHeight", height, slot, true);
}
/*
public void OnGameFrame() {
	static const char str[] = "test";
	for (int slot; slot < 15; slot++) {
		GameRules_SetProp("m_iScriptedHUDFlags", 8512, _, slot, true);
		GameRules_SetPropFloat("m_fScriptedHUDPosX", 0.750000 * slot / 10.0, slot, true);
		GameRules_SetPropFloat("m_fScriptedHUDPosY", 0.349999 * slot / 10.0, slot, true);
		GameRules_SetPropFloat("m_fScriptedHUDWidth", 1.500000 * slot / 10.0, slot, true);
		GameRules_SetPropFloat("m_fScriptedHUDHeight", 0.026000 * slot / 10.0, slot, true);

		GameRules_SetPropString("m_szScriptedHUDStringSet", str, true, slot);
    }
}*/