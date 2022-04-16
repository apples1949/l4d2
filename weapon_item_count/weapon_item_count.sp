#pragma semicolon 1
#pragma newdecls required
#include <dhooks>
#include <left4dhooks_stocks>

#define PLUGIN_VERSION 	"1.2"

#define GAMEDATA	"weapon_item_count"

enum
{
	EntRef,
	UseCount
};

int
	g_iSpawner[2048 + 1][2];

int
	g_iItemCountRules[view_as<int>(L4D2WeaponId_MAX)];

public Plugin myinfo =
{
	name = "设置物品拾取次数",
	author = "",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	vInitGameData();

	RegServerCmd("setitemcount", cmdSetItemCount);
	RegServerCmd("resetitemcount", cmdResetItemCount);

	vResetWeaponRules();
}

Action cmdSetItemCount(int args)
{
	if (args < 2) {
		PrintToServer("Usage: setitemcount <match> <count>");
		return Plugin_Handled;
	}

	char sArg[64];
	GetCmdArg(1, sArg, sizeof sArg);
	L4D2WeaponId match = L4D2_GetWeaponIdByWeaponName2(sArg);
	if (!L4D2_IsValidWeaponId(match))
		return Plugin_Handled;

	GetCmdArg(2, sArg, sizeof sArg);
	int count = StringToInt(sArg);
	if (count >= 0)
		g_iItemCountRules[match] = count;

	return Plugin_Handled;
}

Action cmdResetItemCount(int args)
{
	vResetWeaponRules();
	return Plugin_Handled;
}
	
void vResetWeaponRules()
{
	for(int i; i < view_as<int>(L4D2WeaponId_MAX); i++)
		g_iItemCountRules[i] = -1;
}

void vInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CWeaponSpawn::GiveItem");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CWeaponSpawn::GiveItem\" (%s)", PLUGIN_VERSION);

	if (!dDetour.Enable(Hook_Pre, DD_CWeaponSpawn_GiveItem_Pre))
		SetFailState("Failed to detour pre: \"DD::CWeaponSpawn::GiveItem\" (%s)", PLUGIN_VERSION);

	delete hGameData;
}

MRESReturn DD_CWeaponSpawn_GiveItem_Pre(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if (pThis <= MaxClients || !IsValidEntity(pThis))
		return MRES_Ignored;

	static char cls[64];
	if (!GetEntityNetClass(pThis, cls, sizeof cls))
		return MRES_Ignored;

	if (strcmp(cls, "CWeaponSpawn") != 0)
		return MRES_Ignored;

	if (!GetEntProp(pThis, Prop_Data, "m_itemCount")) {
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	hParams.GetString(2, cls, sizeof cls);
	L4D2WeaponId weaponId = L4D2_GetWeaponIdByWeaponName(cls);
	if (weaponId <= L4D2WeaponId_None || g_iItemCountRules[weaponId] < 0)
		return MRES_Ignored;

	if (!g_iItemCountRules[weaponId]) {
		RemoveEntity(pThis);
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	if (!bIsValidEntRef(g_iSpawner[pThis][EntRef])) {
		g_iSpawner[pThis][EntRef] = EntIndexToEntRef(pThis);
		g_iSpawner[pThis][UseCount] = 0;
	}

	if (g_iSpawner[pThis][UseCount] >= g_iItemCountRules[weaponId]) {
		RemoveEntity(pThis);
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	SetEntProp(pThis, Prop_Data, "m_itemCount", g_iItemCountRules[weaponId] - g_iSpawner[pThis][UseCount]);
	g_iSpawner[pThis][UseCount]++;
	return MRES_Ignored;
}

L4D2WeaponId L4D2_GetWeaponIdByWeaponName2(const char[] weaponName)
{
	static char namebuf[64] = "weapon_";
	L4D2WeaponId weaponId = L4D2_GetWeaponIdByWeaponName(weaponName);

	if (weaponId == L4D2WeaponId_None) {
		strcopy(namebuf[7], sizeof namebuf - 7, weaponName);
		weaponId = L4D2_GetWeaponIdByWeaponName(namebuf);
	}

	return view_as<L4D2WeaponId>(weaponId);
}

static bool bIsValidEntRef(int entity)
{
	return entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE;
}