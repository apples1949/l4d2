#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>
#include <sourcescramble>

#define PLUGIN_NAME				"Transition Restore Fix"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"Restoring transition data by player's UserId instead of character"
#define PLUGIN_VERSION			"1.2.2"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?t=336287"

#define GAMEDATA				"transition_restore_fix"

Handle
	g_hSDK_KeyValues_GetString,
	g_hSDK_KeyValues_SetString,
	g_hSDK_CDirector_IsInTransition;

ConVar
	g_cvKeepIdentity,
	g_cvPrecacheAllSur;

ArrayList
	g_aUsedBotData;

Address
	g_pThis,
	g_pData,
	g_pDirector,
	g_pSavedPlayersCount,
	g_pSavedSurvivorBotsCount,
	g_pSavedLevelRestartSurvivorBotsCount;

MemoryPatch
	g_mpRestoreByUserId;

DynamicDetour
	g_ddCDirector_Restart;

bool
	g_bCDirector_Restart;

enum struct PlayerSaveData {
	char ModelName[PLATFORM_MAX_PATH];
	char character[4];
}

PlayerSaveData
	g_esSavedData;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	vInitGameData();
	g_aUsedBotData = new ArrayList();

	CreateConVar("transition_restore_fix_version", PLUGIN_VERSION, "Transition Restore Fix plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cvKeepIdentity = CreateConVar("restart_keep_identity", "1", "Whether to keep the current character and model after the mission lost and restarts? (0=restore to pre-transition identity, 1=game default)", FCVAR_NOTIFY);
	g_cvPrecacheAllSur = FindConVar("precache_all_survivors");

	g_cvKeepIdentity.AddChangeHook(vCvarChanged);

	AutoExecConfig(true, "transition_restore_fix");
}

public void OnPluginEnd() {
	if (g_pThis)
		StoreToAddress(g_pThis, g_pData, NumberType_Int32);
}

public void OnConfigsExecuted() {
	vToggleDetour(g_cvKeepIdentity.BoolValue);
}

void vCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	vToggleDetour(g_cvKeepIdentity.BoolValue);
}

void vToggleDetour(bool bEnable) {
	static bool bEnabled;
	if (!bEnabled && bEnable) {
		bEnabled = true;

		if (!g_ddCDirector_Restart.Enable(Hook_Pre, DD_CDirector_Restart_Pre))
			SetFailState("Failed to detour pre: \"DD::CDirector::Restart\"");
		
		if (!g_ddCDirector_Restart.Enable(Hook_Post, DD_CDirector_Restart_Post))
			SetFailState("Failed to detour post: \"DD::CDirector::Restart\"");
	}
	else if (bEnabled && !bEnable) {
		bEnabled = false;

		if (!g_ddCDirector_Restart.Disable(Hook_Pre, DD_CDirector_Restart_Pre))
			SetFailState("Failed to disable detour pre: \"DD::CDirector::Restart\"");

		if (!g_ddCDirector_Restart.Disable(Hook_Post, DD_CDirector_Restart_Post))
			SetFailState("Failed to disable detour post: \"DD::CDirector::Restart\"");
	}
}

public void OnMapStart() {
	g_cvPrecacheAllSur.SetInt(1);
}

void vInitGameData() {
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\"");

	g_pSavedPlayersCount = hGameData.GetAddress("SavedPlayersCount");
	if (!g_pSavedPlayersCount)
		SetFailState("Failed to find address: \"SavedPlayersCount\"");

	g_pSavedSurvivorBotsCount = hGameData.GetAddress("SavedSurvivorBotsCount");
	if (!g_pSavedSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedSurvivorBotsCount\"");

	g_pSavedLevelRestartSurvivorBotsCount = hGameData.GetAddress("SavedLevelRestartSurvivorBotsCount");
	if (!g_pSavedLevelRestartSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedLevelRestartSurvivorBotsCount\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString"))
		SetFailState("Failed to find signature: \"KeyValues::GetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_KeyValues_GetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::GetString\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString"))
		SetFailState("Failed to find signature: \"KeyValues::SetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_KeyValues_SetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::SetString\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: \"CDirector::IsInTransition\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CDirector_IsInTransition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::IsInTransition\"");

	vInitPatchs(hGameData);
	vSetupDetours(hGameData);

	delete hGameData;
}

void vInitPatchs(GameData hGameData = null) {
	g_mpRestoreByUserId = MemoryPatch.CreateFromConf(hGameData, "CTerrorPlayer::TransitionRestore::RestoreByUserId");
	if (!g_mpRestoreByUserId.Validate())
		SetFailState("Failed to verify patch: \"CTerrorPlayer::TransitionRestore::RestoreByUserId\"");

	MemoryPatch patch = MemoryPatch.CreateFromConf(hGameData, "RestoreTransitionedSurvivorBots::MaxRestoreSurvivorBots");
	if (!patch.Validate())
		SetFailState("Failed to verify patch: \"RestoreTransitionedSurvivorBots::MaxRestoreSurvivorBots\"");
	else if (patch.Enable()) {
		StoreToAddress(patch.Address + view_as<Address>(2), hGameData.GetOffset("OS") ? MaxClients : MaxClients + 1, NumberType_Int8);
		PrintToServer("[%s] Enabled patch: \"RestoreTransitionedSurvivorBots::MaxRestoreSurvivorBots\"", GAMEDATA);
	}
}

void vSetupDetours(GameData hGameData = null) {
	g_ddCDirector_Restart = DynamicDetour.FromConf(hGameData, "DD::CDirector::Restart");
	if (!g_ddCDirector_Restart)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirector::Restart\"");

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::TransitionRestore");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::TransitionRestore\"");

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_TransitionRestore_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::TransitionRestore\"");

	if (!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_TransitionRestore_Post))
		SetFailState("Failed to detour post: \"DD::CTerrorPlayer::TransitionRestore\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::PlayerSaveData::Restore");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::PlayerSaveData::Restore\"");

	if (!dDetour.Enable(Hook_Pre, DD_PlayerSaveData_Restore_Pre))
		SetFailState("Failed to detour pre: \"DD::PlayerSaveData::Restore\"");

	if (!dDetour.Enable(Hook_Post, DD_PlayerSaveData_Restore_Post))
		SetFailState("Failed to detour post: \"DD::PlayerSaveData::Restore\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirector::IsHumanSpectatorValid");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirector::IsHumanSpectatorValid\"");

	if (!dDetour.Enable(Hook_Pre, DD_CDirector_IsHumanSpectatorValid_Pre))
		SetFailState("Failed to detour pre: \"DD::CDirector::IsHumanSpectatorValid\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots\"");

	if (!dDetour.Enable(Hook_Pre, DD_CDSManager_FillRemainingSurvivorTeamSlotsWithBots_Pre))
		SetFailState("Failed to detour pre: \"DD::CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots\"");
}

MRESReturn DD_CDirector_Restart_Pre(Address pThis, DHookReturn hReturn) {
	g_aUsedBotData.Clear();
	g_bCDirector_Restart = true;
	return MRES_Ignored;
}

MRESReturn DD_CDirector_Restart_Post(Address pThis, DHookReturn hReturn) {
	g_bCDirector_Restart = false;
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_TransitionRestore_Pre(int pThis, DHookReturn hReturn) {
	if (IsFakeClient(pThis) || GetClientTeam(pThis) > 2)
		return MRES_Ignored;

	Address pData = pFindPlayerDataByUserId(GetClientUserId(pThis));
	if (!pData)
		return MRES_Ignored;

	char teamNumber[4];
	SDKCall(g_hSDK_KeyValues_GetString, pData, teamNumber, sizeof teamNumber, "teamNumber", "0");
	if (StringToInt(teamNumber) != 2)
		return MRES_Ignored;

	g_mpRestoreByUserId.Enable();
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_TransitionRestore_Post(int pThis, DHookReturn hReturn) {
	g_mpRestoreByUserId.Disable();
	return MRES_Ignored;
}

MRESReturn DD_PlayerSaveData_Restore_Pre(Address pThis, DHookParam hParams) {
	if (!g_bCDirector_Restart)
		return MRES_Ignored;

	int player = hParams.Get(1);
	if (GetClientTeam(player) > 2)
		return MRES_Ignored;

	Address pData;
	char ModelName[PLATFORM_MAX_PATH];
	GetClientModel(player, ModelName, sizeof ModelName);
	pData = pFindBotDataByModelName(ModelName);
	if (pData) {
		if (IsFakeClient(player) || !pFindPlayerDataByUserId(GetClientUserId(player))) {
			g_pThis = pThis;
			g_pData = LoadFromAddress(pThis, NumberType_Int32);
			StoreToAddress(pThis, pData, NumberType_Int32);
		}
	}

	if (!pData) {
		pData = LoadFromAddress(pThis, NumberType_Int32);

		char teamNumber[4];
		SDKCall(g_hSDK_KeyValues_GetString, pData, teamNumber, sizeof teamNumber, "teamNumber", "0");
		if (StringToInt(teamNumber) != 2)
			return MRES_Ignored;
	}

	char character[4];
	SDKCall(g_hSDK_KeyValues_GetString, pData, ModelName, sizeof ModelName, "ModelName", "");
	SDKCall(g_hSDK_KeyValues_GetString, pData, character, sizeof character, "character", "0");
	strcopy(g_esSavedData.ModelName, sizeof PlayerSaveData::ModelName, ModelName);
	strcopy(g_esSavedData.character, sizeof PlayerSaveData::character, character);

	GetClientModel(player, ModelName, sizeof ModelName);
	SDKCall(g_hSDK_KeyValues_SetString, pData, "ModelName", ModelName);

	IntToString(GetEntProp(player, Prop_Send, "m_survivorCharacter"), character, sizeof character);
	SDKCall(g_hSDK_KeyValues_SetString, pData, "character", character);

	return MRES_Ignored;
}

MRESReturn DD_PlayerSaveData_Restore_Post(Address pThis, DHookParam hParams) {
	if (!g_bCDirector_Restart)
		return MRES_Ignored;

	if (g_esSavedData.character[0]) {
		Address pData = LoadFromAddress(pThis, NumberType_Int32);
		if (pData) {
			SDKCall(g_hSDK_KeyValues_SetString, pData, "ModelName", g_esSavedData.ModelName);
			SDKCall(g_hSDK_KeyValues_SetString, pData, "character", g_esSavedData.character);
		}

		g_esSavedData.ModelName[0] = '\0';
		g_esSavedData.character[0] = '\0';
	}

	if (g_pThis)
		StoreToAddress(g_pThis, g_pData, NumberType_Int32);

	g_pThis = Address_Null;
	g_pData = Address_Null;
	return MRES_Ignored;
}

/**
* Prevents players joining the game during transition from taking over the Survivor Bot of transitioning players
**/
MRESReturn DD_CDirector_IsHumanSpectatorValid_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams) {
	if (!GetClientOfUserId(GetEntProp(hParams.Get(1), Prop_Send, "m_humanSpectatorUserID")))
		return MRES_Ignored;

	hReturn.Value = 1;
	return MRES_Supercede;
}

/**
* Prevent CDirectorSessionManager::FillRemainingSurvivorTeamSlotsWithBots from triggering before RestoreTransitionedSurvivorBots(void) during transition
**/
MRESReturn DD_CDSManager_FillRemainingSurvivorTeamSlotsWithBots_Pre(Address pThis, DHookReturn hReturn) {
	if (!SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector))
		return MRES_Ignored;

	if (!LoadFromAddress(g_pSavedSurvivorBotsCount, NumberType_Int32))
		return MRES_Ignored;

	hReturn.Value = 0;
	return MRES_Supercede;
}

// 读取玩家过关时保存的userID
Address pFindPlayerDataByUserId(int userid) {
	int iSavedPlayersCount = LoadFromAddress(g_pSavedPlayersCount, NumberType_Int32);
	if (!iSavedPlayersCount)
		return Address_Null;

	Address pSavedPlayers = view_as<Address>(LoadFromAddress(g_pSavedPlayersCount + view_as<Address>(4), NumberType_Int32));
	if (!pSavedPlayers)
		return Address_Null;

	Address pThis;
	char userID[12];
	for (int i; i < iSavedPlayersCount; i++) {
		pThis = view_as<Address>(LoadFromAddress(pSavedPlayers + view_as<Address>(4 * i), NumberType_Int32));
		if (!pThis)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, pThis, userID, sizeof userID, "userID", "0");
		if (StringToInt(userID) == userid)
			return pThis;
	}

	return Address_Null;
}

//数据选用优先级
//没有用过且模型相同的数据 >= 没有用过且模型不相同的数据 >= 用过且模型相同的数据 >= 用过且模型不相同的数据
Address pFindBotDataByModelName(const char[] sModel) {
	int iSavedLevelRestartSurvivorBotsCount = LoadFromAddress(g_pSavedLevelRestartSurvivorBotsCount, NumberType_Int32);
	if (!iSavedLevelRestartSurvivorBotsCount)
		return Address_Null;

	Address pSavedLevelRestartSurvivorBots = view_as<Address>(LoadFromAddress(g_pSavedLevelRestartSurvivorBotsCount + view_as<Address>(4), NumberType_Int32));
	if (!pSavedLevelRestartSurvivorBots)
		return Address_Null;

	Address pThis;
	char teamNumber[4];
	char ModelName[PLATFORM_MAX_PATH];
	ArrayList aKeyValues = new ArrayList(2);
	for (int i; i < iSavedLevelRestartSurvivorBotsCount; i++) {
		pThis = view_as<Address>(LoadFromAddress(pSavedLevelRestartSurvivorBots + view_as<Address>(4 * i), NumberType_Int32));
		if (!pThis)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, pThis, teamNumber, sizeof teamNumber, "teamNumber", "0");
		if (StringToInt(teamNumber) != 2)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, pThis, ModelName, sizeof ModelName, "ModelName", "");
		aKeyValues.Set(aKeyValues.Push(g_aUsedBotData.FindValue(pThis) == -1 ? (strcmp(ModelName, sModel, false) == 0 ? 0 : 1) : strcmp(ModelName, sModel, false) == 0 ? 2 : 3), pThis, 1);
	}

	if (!aKeyValues.Length)
		pThis = Address_Null;
	else {
		aKeyValues.Sort(Sort_Ascending, Sort_Integer);

		pThis = aKeyValues.Get(0, 1);
		if (aKeyValues.Get(0, 0) < 2)
			g_aUsedBotData.Push(pThis);
	}

	delete aKeyValues;
	return pThis;
}
