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

ConVar
	g_hBypassAbsorbWeapon;

bool
	g_bBypassAbsorbWeapon;

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

	g_hBypassAbsorbWeapon = CreateConVar("bypass_absorb_weapon", "1", "Whether to bypass the absorb weapon count");
	g_hBypassAbsorbWeapon.AddChangeHook(vConVarChanged);

	RegServerCmd("setitemcount", cmdSetItemCount);
	RegServerCmd("resetitemcount", cmdResetItemCount);

	vResetWeaponRules();
}

public void OnConfigsExecuted()
{
	vGetCvars();
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	vGetCvars();
}

void vGetCvars()
{
	g_bBypassAbsorbWeapon = g_hBypassAbsorbWeapon.BoolValue;
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
	for (int i; i < view_as<int>(L4D2WeaponId_MAX); i++)
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

	if (!dDetour.Enable(Hook_Post, DD_CWeaponSpawn_GiveItem_Post))
		SetFailState("Failed to detour post: \"DD::CWeaponSpawn::GiveItem\" (%s)", PLUGIN_VERSION);

	delete hGameData;
}

bool g_bRemoveSpawner;
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
		RemoveEntity(pThis);
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

	if (!g_bBypassAbsorbWeapon && g_iSpawner[pThis][UseCount] >= g_iItemCountRules[weaponId]) {
		RemoveEntity(pThis);
		hReturn.Value = 0;
		return MRES_Supercede;
	}

	if (!g_iSpawner[pThis][UseCount] || !g_bBypassAbsorbWeapon)
		SetEntProp(pThis, Prop_Data, "m_itemCount", g_iItemCountRules[weaponId] - g_iSpawner[pThis][UseCount]);

	g_bRemoveSpawner = GetEntProp(pThis, Prop_Data, "m_itemCount") <= 1;
	g_iSpawner[pThis][UseCount]++;
	return MRES_Ignored;
}

MRESReturn DD_CWeaponSpawn_GiveItem_Post(int pThis, DHookReturn hReturn, DHookParam hParams)
{
	if (g_bRemoveSpawner && IsValidEntity(pThis))
		RemoveEntity(pThis);

	g_bRemoveSpawner = false;
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
