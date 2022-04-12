#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define MAX_MELEE		16
#define GAMEDATA		"l4d2_melee_spawn_control"
#define MELEE_MANIFEST	"scripts\\melee\\melee_manifest.txt"
#define DEFAULT_MELEES	"fireaxe;frying_pan;machete;baseball_bat;crowbar;cricket_bat;tonfa;katana;electric_guitar;knife;golfclub;shovel;pitchfork"

StringMap
	g_aMapDefaultMelees;

Handle
	g_hSDK_CTerrorGameRules_GetMissionInfo,
	g_hSDK_KeyValues_GetString,
	g_hSDK_KeyValues_SetString,
	g_hSDK_CTerrorGameRules_GetMissionFirstMap;

ConVar
	g_hBaseMelees,
	g_hExtraMelees;

public Plugin myinfo=
{
	name = "l4d2 melee spawn control",
	author = "IA/NanaNana",
	description = "Unlock melee weapons",
	version = "1.5",
	url = "https://forums.alliedmods.net/showthread.php?p=2719531"
}

public void OnPluginStart()
{
	vInitGameData();
	g_aMapDefaultMelees = new StringMap();

	g_hBaseMelees = CreateConVar("l4d2_melee_spawn", "", "Melee weapon list for unlock, use ';' to separate between names, e.g: pitchfork;shovel. Empty for no change");
	g_hExtraMelees = CreateConVar("l4d2_add_melee", "", "Add melee weapons to map basis melee spawn or l4d2_melee_spawn, use ';' to separate between names. Empty for don't add");
}

MRESReturn DD_CMeleeWeaponInfoStore_LoadScripts_Pre(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	int infoPointer = SDKCall(g_hSDK_CTerrorGameRules_GetMissionInfo);
	if(!infoPointer)
		return MRES_Ignored;

	char sMissionFirstMap[64];
	int iKeyValue = SDKCall(g_hSDK_CTerrorGameRules_GetMissionFirstMap, 0);\
	if(!iKeyValue)
		return MRES_Ignored;

	SDKCall(g_hSDK_KeyValues_GetString, iKeyValue, sMissionFirstMap, sizeof sMissionFirstMap, "map", "");
	if(!sMissionFirstMap[0])
		return MRES_Ignored;

	char sMissionBaseMelees[512];
	if(!g_aMapDefaultMelees.GetString(sMissionFirstMap, sMissionBaseMelees, sizeof sMissionBaseMelees))
	{
		char sMapCurrentMelees[512];
		SDKCall(g_hSDK_KeyValues_GetString, infoPointer, sMapCurrentMelees, sizeof sMapCurrentMelees, "meleeweapons", "");

		if(!sMapCurrentMelees[0])
			bReadMeleeManifest(sMissionBaseMelees, sizeof sMissionBaseMelees); //Dark Wood (Extended), Divine Cybermancy
		else
			strcopy(sMissionBaseMelees, sizeof sMissionBaseMelees, sMapCurrentMelees);

		if(!sMissionBaseMelees[0])
			strcopy(sMissionBaseMelees, sizeof sMissionBaseMelees, DEFAULT_MELEES);

		g_aMapDefaultMelees.SetString(sMissionFirstMap, sMissionBaseMelees, false);
	}

	char sMapSetMelees[512];
	sMapSetMelees = sGetMapSetMelees(sMissionBaseMelees);
	if(!sMapSetMelees[0])
		return MRES_Ignored;

	SDKCall(g_hSDK_KeyValues_SetString, infoPointer, "meleeweapons", sMapSetMelees);
	return MRES_Ignored;
}

MRESReturn DD_CDirectorItemManager_IsMeleeWeaponAllowedToExistPost(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
	/**char sScriptName[32];
	hParams.GetString(1, sScriptName, sizeof sScriptName);
	if(strcmp(sScriptName, "knife", false) == 0)
	{
		hReturn.Value = 1;
		return MRES_Override;
	}
	
	return MRES_Ignored;*/

	hReturn.Value = 1;
	return MRES_Override;
}

bool bReadMeleeManifest(char[] sManifest, int maxlength)
{
	File hFile = OpenFile(MELEE_MANIFEST, "r", true, NULL_STRING);
	if(!hFile)
		return false;

	char sLine[PLATFORM_MAX_PATH];
	char sPath[PLATFORM_MAX_PATH];

	while(!hFile.EndOfFile() && hFile.ReadLine(sLine, sizeof sLine))
	{
		TrimString(sLine);

		if(!KV_GetValue(sLine, "file", sPath))
			continue;

		if(!SplitStringRight(sPath, "scripts/melee/", sPath, sizeof sPath))
			continue;
	
		if(SplitString(sPath, ".txt", sPath, sizeof sPath) == -1)
			continue;
		
		Format(sManifest, maxlength, "%s;%s", sManifest, sPath);
	}
	
	delete hFile;

	strcopy(sManifest, maxlength, sManifest[1]);
	return true;
}

// [L4D1 & L4D2] Map changer with rating system (https://forums.alliedmods.net/showthread.php?t=311161)
bool KV_GetValue(char[] str, char[] key, char buffer[PLATFORM_MAX_PATH])
{
	buffer[0] = '\0';
	int posKey, posComment, sizeKey;
	char substr[64];
	FormatEx(substr, sizeof substr, "\"%s\"", key);
	
	posKey = StrContains(str, substr, false);
	if( posKey != -1 )
	{
		posComment = StrContains(str, "//", true);
		
		if( posComment == -1 || posComment > posKey )
		{
			sizeKey = strlen(substr);
			buffer = UnQuote(str[posKey + sizeKey]);
			return true;
		}
	}
	return false;
}

char[] UnQuote(char[] Str)
{
	int pos;
	static char buf[64];
	strcopy(buf, sizeof buf, Str);
	TrimString(buf);
	if (buf[0] == '\"') {
		strcopy(buf, sizeof buf, buf[1]);
	}
	pos = FindCharInString(buf, '\"');
	if( pos != -1 ) {
		buf[pos] = '\x0';
	}
	return buf;
}

// https://forums.alliedmods.net/showpost.php?p=2094396&postcount=6
bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen)
{
	int index = StrContains(source, split); // get start index of split string

	if( index == -1 ) // split string not found..
		return false;
	
	index += strlen(split); // get end index of split string

	if( index == strlen(source) - 1 ) // no right side exist
		return false;
	
	strcopy(part, partLen, source[index]); // copy everything after source[ index ] to part
	return true;
}

char[] sGetMapSetMelees(const char[] sMissionBaseMelees)
{
	char sBaseMelees[512];
	char sExtraMelees[512];
	g_hBaseMelees.GetString(sBaseMelees, sizeof sBaseMelees);
	g_hExtraMelees.GetString(sExtraMelees, sizeof sExtraMelees);

	if(!sBaseMelees[0])
	{
		if(!sExtraMelees[0])
			return sExtraMelees;

		strcopy(sBaseMelees, sizeof sBaseMelees, sMissionBaseMelees);
	}

	ArrayList aMeleeScripts = new ArrayList(ByteCountToCells(32));

	PushMeleeList(sBaseMelees, aMeleeScripts);

	if(sExtraMelees[0])
		PushMeleeList(sExtraMelees, aMeleeScripts);

	char buffer[32];
	sBaseMelees[0] = '\0';
	int length = aMeleeScripts.Length > 16 ? 16 : aMeleeScripts.Length;
	for(int i; i < length; i++)
	{
		if(i)
			StrCat(sBaseMelees, sizeof sBaseMelees, ";");

		aMeleeScripts.GetString(i, buffer, sizeof buffer);
		StrCat(sBaseMelees, sizeof sBaseMelees, buffer);
	}

	delete aMeleeScripts;
	return sBaseMelees;
}

void PushMeleeList(const char[] source, ArrayList array)
{
	int reloc_idx, idx;
	char buffer[32];
	char path[PLATFORM_MAX_PATH];

	while ((idx = SplitString(source[reloc_idx], ";", buffer, sizeof buffer)) != -1)
	{
		reloc_idx += idx;
		TrimString(buffer);
		if (!buffer[0])
			continue;

		if (array.FindString(buffer) != -1)
			continue;
			
		StringToLowerCase(buffer);
		FormatEx(path, sizeof path, "scripts/melee/%s.txt", buffer);
		if (!FileExists(path, true, NULL_STRING))
			continue;

		array.PushString(buffer);
	}

	if (reloc_idx > 0)
	{
		strcopy(buffer, sizeof buffer, source[reloc_idx]);

		TrimString(buffer);
		if (buffer[0] && array.FindString(buffer) == -1)
		{
			StringToLowerCase(buffer);
			FormatEx(path, sizeof path, "scripts/melee/%s.txt", buffer);
			if (FileExists(path, true, NULL_STRING))
				array.PushString(buffer);
		}
	}
}

/**
 * Converts the given string to lower case
 *
 * @param szString     Input string for conversion and also the output
 * @return             void
 */
stock void StringToLowerCase(char[] szInput) 
{
	int iIterator;

	while (szInput[iIterator] != EOS)
	{
		szInput[iIterator] = CharToLower(szInput[iIterator]);
		++iIterator;
	}
}

void vInitGameData()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if(!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if(!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	StartPrepSDKCall(SDKCall_Static);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::GetMissionInfo"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::GetMissionInfo\"");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if(!(g_hSDK_CTerrorGameRules_GetMissionInfo = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::GetMissionInfo\"");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString"))
		SetFailState("Failed to find signature: \"KeyValues::GetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	if(!(g_hSDK_KeyValues_GetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::GetString\"");

	StartPrepSDKCall(SDKCall_Raw);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::SetString"))
		SetFailState("Failed to find signature: \"KeyValues::SetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	if(!(g_hSDK_KeyValues_SetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::SetString\"");

	StartPrepSDKCall(SDKCall_Static);
	if(!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorGameRules::GetMissionFirstMap"))
		SetFailState("Failed to find signature: \"CTerrorGameRules::GetMissionFirstMap\"");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain, VDECODE_FLAG_ALLOWWORLD);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if(!(g_hSDK_CTerrorGameRules_GetMissionFirstMap = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorGameRules::GetMissionFirstMap\"");

	vSetupDetours(hGameData);

	delete hGameData;
}

void vSetupDetours(GameData hGameData = null)
{
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CMeleeWeaponInfoStore::LoadScripts");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CMeleeWeaponInfoStore::LoadScripts\"");
		
	if(!dDetour.Enable(Hook_Pre, DD_CMeleeWeaponInfoStore_LoadScripts_Pre))
		SetFailState("Failed to detour pre: \"DD::CMeleeWeaponInfoStore::LoadScripts\"");

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CDirectorItemManager::IsMeleeWeaponAllowedToExist");
	if(!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CDirectorItemManager::IsMeleeWeaponAllowedToExist\"");
		
	if(!dDetour.Enable(Hook_Post, DD_CDirectorItemManager_IsMeleeWeaponAllowedToExistPost))
		SetFailState("Failed to detour post: \"DD::CDirectorItemManager::IsMeleeWeaponAllowedToExist\"");
}
