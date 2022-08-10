#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sourcescramble>

#define GAMEDATA	"incap_magnum"

public Plugin myinfo =
{
	name = "Incapped Magnum",
	author = "sorallll",
	version	= "1.0.1",
	description	= "将倒地武器修改为Magnum",
	url = "https://github.com/umlka/l4d2/tree/main/incap_magnum"
};

public void OnPluginStart()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	Address pIncappedWeaponName = hGameData.GetMemSig("CTerrorPlayer::OnIncapacitatedAsSurvivor");
	if (!pIncappedWeaponName)
		SetFailState("Failed to find address: \"CTerrorPlayer::OnIncapacitatedAsSurvivor\"");

	int iOffset = hGameData.GetOffset("IncappedWeaponName");
	if (iOffset == -1)
		SetFailState("Failed to find offset: \"IncappedWeaponName\"");

	pIncappedWeaponName += view_as<Address>(iOffset);
	StoreToAddress(pIncappedWeaponName, view_as<int>(GetAddressOfString("weapon_pistol_magnum")), NumberType_Int32);
}