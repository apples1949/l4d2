#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

#define PLUGIN_NAME				"L4D2 EMS HUD"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.1"
#define PLUGIN_URL				""

enum SlotType
{
	HUD_LEFT_TOP = 0,
	HUD_LEFT_BOT, 
	HUD_MID_TOP,
	HUD_MID_BOT,
	HUD_RIGHT_TOP,
	HUD_RIGHT_BOT, 
	HUD_TICKER,
	HUD_FAR_LEFT,    
	HUD_FAR_RIGHT,    
	HUD_MID_BOX,  
	HUD_SCORE_TITLE,    
	HUD_SCORE_1,
	HUD_SCORE_2, 
	HUD_SCORE_3,     
	HUD_SCORE_4,         
};

// custom flags for background, time, alignment, which team, pre or postfix, etc
#define HUD_FLAG_PRESTR			(1<<0)	//	do you want a string/value pair to start(pre) or end(post) with the static string (default is PRE)
#define HUD_FLAG_POSTSTR 		(1<<1)	//	ditto
#define HUD_FLAG_BEEP			(1<<2)	//	Makes a countdown timer blink
#define HUD_FLAG_BLINK			(1<<3)  //	do you want this field to be blinking
#define HUD_FLAG_AS_TIME		(1<<4)	//	to do..
#define HUD_FLAG_COUNTDOWN_WARN	(1<<5)	//	auto blink when the timer gets under 10 seconds
#define HUD_FLAG_NOBG	        (1<<6) 	//	dont draw the background box for this UI element
#define HUD_FLAG_ALLOWNEGTIMER	(1<<7) 	//	by default Timers stop on 0:00 to avoid briefly going negative over network, this keeps that from happening
#define HUD_FLAG_ALIGN_LEFT		(1<<8) 	//	Left justify this text
#define HUD_FLAG_ALIGN_CENTER	(1<<9)	//	Center justify this text
#define HUD_FLAG_ALIGN_RIGHT	(3<<8)	//	Right justify this text
#define HUD_FLAG_TEAM_SURVIVORS	(1<<10) //	only show to the survivor team
#define HUD_FLAG_TEAM_INFECTED	(1<<11) //	only show to the special infected team
#define HUD_FLAG_TEAM_MASK		(3<<10) //	link HUD_FLAG_TEAM_SURVIVORS and  HUD_FLAG_TEAM_INFECTED
#define HUD_FLAG_UNKNOWN1       (1<<12)	//	?
#define HUD_FLAG_TEXT			(1<<13)	//	?
#define HUD_FLAG_NOTVISIBLE		(1<<14) // if you want to keep the slot data but keep it from displaying

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

// native void HUDPlace(SlotType slot, float x_pos, float y_pos, float width, float height);
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

void HUDPlace(int slot, float x_pos, float y_pos, float width, float height) {
	GameRules_SetPropFloat("m_fScriptedHUDPosX", x_pos, slot, true);
	GameRules_SetPropFloat("m_fScriptedHUDPosY", y_pos, slot, true);
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