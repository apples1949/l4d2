#pragma semicolon 1
#pragma newdecls optional

//#define DEBUG

#define PLUGIN_AUTHOR "xZk"
#define PLUGIN_VERSION "2.2.5"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks_stocks>

#define CFG_WHITELIST "data/weapon_cleaner_whitelist.cfg"
#define MAXENTITIES 2048

static const char g_sItemGun[][] = {
	"pistol"			   //0 
	,"pistol_magnum"	   //1 
	,"chainsaw"			   //2 
	,"smg"				   //3	 
	,"smg_silenced"		   //4 
	,"smg_mp5"			   //5 
	,"pumpshotgun"		   //6	 
	,"shotgun_chrome"	   //7 
	,"rifle"			   //8 
	,"rifle_desert"		   //9 
	,"rifle_ak47"		   //10
	,"rifle_sg552"		   //11
	,"hunting_rifle"	   //12
	,"sniper_military"	   //13
	,"sniper_scout"		   //14
	,"sniper_awp"		   //15
	,"autoshotgun"		   //16
	,"shotgun_spas"		   //17
	,"rifle_m60"		   //18		 
	,"grenade_launcher"	   //19	  
};

static const char g_sModelGun[][] = {
	// "models/w_models/weapons/w_pistol_A.mdl"
	// "models/w_models/weapons/w_pistol_B.mdl"
	"models/w_models/weapons/w_pistol_A.mdl"			//0 
	,"models/w_models/weapons/w_desert_eagle.mdl"		//1 
	,"models/weapons/melee/w_chainsaw.mdl"				//2 
	,"models/w_models/weapons/w_smg_uzi.mdl"			//3	 
	,"models/w_models/weapons/w_smg_a.mdl"				//4 
	,"models/w_models/weapons/w_smg_mp5.mdl"			//5 
	,"models/w_models/weapons/w_shotgun.mdl"			//6	 
	,"models/w_models/weapons/w_pumpshotgun_A.mdl"		//7 
	,"models/w_models/weapons/w_rifle_m16a2.mdl"		//8 
	,"models/w_models/weapons/w_desert_rifle.mdl"		//9 
	,"models/w_models/weapons/w_rifle_ak47.mdl"			//10
	,"models/w_models/weapons/w_rifle_sg552.mdl"		//11
	,"models/w_models/weapons/w_sniper_mini14.mdl"		//12
	,"models/w_models/weapons/w_sniper_military.mdl"	//13
	,"models/w_models/weapons/w_sniper_scout.mdl"		//14
	,"models/w_models/weapons/w_sniper_awp.mdl"			//15
	,"models/w_models/weapons/w_autoshot_m4super.mdl"	//16
	,"models/w_models/weapons/w_shotgun_spas.mdl"		//17
	,"models/w_models/weapons/w_m60.mdl"				//18
	,"models/w_models/weapons/w_grenade_launcher.mdl"	//19  
};													  


static const char g_sItemMelee[][] = {
	"fireaxe",
	"frying_pan",
	"machete",
	"baseball_bat",
	"crowbar",
	"cricket_bat",
	"tonfa",
	"katana",
	"electric_guitar",
	"golfclub",
	"knife",
	"shovel",
	"pitchfork",
	"riotshield"
};

static const char g_sModelMelee[][] = {
	"models/weapons/melee/w_fireaxe.mdl",
	"models/weapons/melee/w_frying_pan.mdl",
	"models/weapons/melee/w_machete.mdl",
	"models/weapons/melee/w_bat.mdl",
	"models/weapons/melee/w_crowbar.mdl",
	"models/weapons/melee/w_cricket_bat.mdl",
	"models/weapons/melee/w_tonfa.mdl",
	"models/weapons/melee/w_katana.mdl",
	"models/weapons/melee/w_electric_guitar.mdl",
	"models/weapons/melee/w_golfclub.mdl",
	"models/w_models/weapons/w_knife_t.mdl",
	"models/weapons/melee/w_shovel.mdl",
	"models/weapons/melee/w_pitchfork.mdl",
	"models/weapons/melee/w_riotshield.mdl"
};

static const char g_sItemGrenade[][] = {
	"pipe_bomb",	
	"molotov",	
	"vomitjar"
};

static const char g_sModelGrenade[][] = {
	"models/w_models/weapons/w_eq_pipebomb.mdl"	
	,"models/w_models/weapons/w_eq_molotov.mdl"	
	,"models/w_models/weapons/w_eq_bile_flask.mdl"
};

static const char g_sItemPack[][] = {
	"first_aid_kit",		
	"defibrillator",		
	"upgradepack_explosive",
	"upgradepack_incendiary"
};

static const char g_sModelPack[][] = {
	"models/w_models/weapons/w_eq_medkit.mdl"//models/w_models/weapons/w_eq_Medkit.mdl
	,"models/w_models/weapons/w_eq_defibrillator.mdl"
	,"models/w_models/weapons/w_eq_explosive_ammopack.mdl"
	,"models/w_models/weapons/w_eq_incendiary_ammopack.mdl"
};

static const char g_sItemConsumable[][] = {
	"pain_pills",		
	"adrenaline"
};

static const char g_sModelConsumable[][] = {
	"models/w_models/weapons/w_eq_painpills.mdl"
	,"models/w_models/weapons/w_eq_adrenaline.mdl"
};

static const char g_sItemCarry[][] = {
	"fireworkcrate",
	"gascan",
	"oxygentank",
	"propanetank",
	"gnome",
	"cola_bottles"
};

static const char g_sModelCarry[][] = {
	"models/props_junk/explosive_box001.mdl"
	,"models/props_junk/gascan001a.mdl"
	,"models/props_equipment/oxygentank01.mdl"
	,"models/props_junk/propanecanister001.mdl"
	,"models/props_junk/gnome.mdl"
	,"models/w_models/weapons/w_cola.mdl"
};

ConVar
	g_cvEnable,
	g_cvDrop,
	g_cvClass,
	g_cvSpawn,
	g_cvPhysics,
	g_cvAmmo,
	g_cvDelay,
	g_cvEffectMode,
	g_cvEffectTime,
	g_cvEffectGlowColor,
	g_cvEffectGlowRange,
	g_cvVisible,
	g_cvVisibleMode;

bool
	g_bEnable,
	g_bDrop,
	g_bVisible,
	g_bPhisics,
	g_bAmmo;

int
	g_iRoundStart,
	g_iPlayerSpawn,
	g_iSpawn,
	g_iClassWeapon,
	g_iCleanDelay,
	g_iEffectMode,
	g_iEffectGlowRange,
	g_iVisibleMode,
	g_iEffectGlowColor[3];

float
	g_fEffectTime;

StringMap
	g_smCleanList,
	g_smWhiteList;

Handle
	g_hCleaningTimer,
	g_hCheckSpawnTimer;

int
	g_iItemTime[MAXENTITIES + 1] = {-1, ...},
	g_iWeaponRef[MAXENTITIES + 1];

bool
	g_bLateLoad,
	g_bSpawnedWeapons;

public Plugin myinfo = {
	name = "Weapon Cleaner", 
	author = PLUGIN_AUTHOR, 
	description = "Clean drop weapons on the ground with delay timer, like KF", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=315058"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	g_smCleanList = new StringMap();
	g_smWhiteList = new StringMap();
	vInitCleanTrie();
	vLoadWhiteList();
	
	g_cvEnable= CreateConVar("weapon_cleaner_enable", "1", "0:Disable, 1:Enable Plugin", FCVAR_NONE);
	g_cvSpawn= CreateConVar("weapon_cleaner_spawn", "2", "0:Detect all weapons when spawned, 1:Ignore weapons spawned by map, 2: Ignore weapons when the round starts (thirparty plugins)");
	g_cvDrop= CreateConVar("weapon_cleaner_drop", "0", "0: Clean all weapons not equipped in the game, 1: Clean only dropped weapons when taking another weapon");
	g_cvClass= CreateConVar("weapon_cleaner_class", "1", "1:Clean only Weapons that do not belong to the spawn class, 2:Clean only Weapons of the class with suffix: \"_spawn\", 3:All weapons with any class name(\"weapon_*\")", FCVAR_NONE, true, 1.0, true, 3.0);
	g_cvPhysics= CreateConVar("weapon_cleaner_physics", "1", "0:Ignore prop_physics weapons, 1:Allow detect prop_physics");
	g_cvAmmo= CreateConVar("weapon_cleaner_ammo", "0", "0:Ignore ammo pile, 1:Allow detect ammo pile(weapon_ammo_spawn)");
	g_cvDelay= CreateConVar("weapon_cleaner_delay", "60", "Set delay to clean each weapon in seconds", FCVAR_NONE, true, 1.0);
	g_cvEffectMode= CreateConVar("weapon_cleaner_effect_mode", "0", "0:Disable effects on weapons in timer cleaning, 1:Set blink effect(RenderFx), 2:Set glow effect(L4D2), 3:All effects modes");
	g_cvEffectTime= CreateConVar("weapon_cleaner_effect_time", "0.8", "Set percentage of delay time to activate effects on weapons, ex:(\"0.2\")=>(0.2*delay=0.2*300s=60s) or Set time in seconds value if: (value >= 1), ex:(\"60\")s", FCVAR_NONE, true, 0.01);
	g_cvEffectGlowColor= CreateConVar("weapon_cleaner_effect_glowcolor", "128,128,128", "Set glow color in RGB Format (L4D2)");
	g_cvEffectGlowRange= CreateConVar("weapon_cleaner_effect_glowrange", "1000", "Set maximum range of glow (L4D2)");
	g_cvVisible= CreateConVar("weapon_cleaner_visible", "0", "0:Disable, 1:Enable visibility filter on weapons");
	g_cvVisibleMode= CreateConVar("weapon_cleaner_visible_mode", "0", "0:Pause timer if is visible weapon , 1:Pause timer if someone is aiming at the weapon, 2:Reset timer if is visible weapon, 3:Reset timer if someone is aiming at the weapon", FCVAR_NONE, true, 0.0, true, 3.0);
	//AutoExecConfig(true, "weapon_cleaner");
	
	RegAdminCmd("sm_wc_reload", cmdReloadWhiteList, ADMFLAG_CHEATS, "reload config data Whitelist");
	RegAdminCmd("sm_wclean", cmdCleanWeapon, ADMFLAG_CHEATS, "clean weapons no equipped by name or/and classname, examples: 'sm_wclean pistol' 'sm_wclean weapon_pistol' 'sm_wclean pistol weapon_spawn'");
	RegAdminCmd("sm_wcleanall", cmdCleanAllWeapons, ADMFLAG_CHEATS, "clean all weapons no equipped");
	RegAdminCmd("sm_wclear", cmdClearWeapon, ADMFLAG_CHEATS, "clear weapons all weapons by name or/and classname, examples: 'sm_wclean pistol' 'sm_wclear weapon_pistol' 'sm_wclean pistol weapon_spawn'");
	RegAdminCmd("sm_wclearall", cmdClearAllWeapons, ADMFLAG_CHEATS, "clear all weapons");
	
	g_cvEnable.AddChangeHook(vCvarChanged_Enable);
	g_cvSpawn.AddChangeHook(vCvarsChanged);
	g_cvDrop.AddChangeHook(vCvarsChanged);
	g_cvClass.AddChangeHook(vCvarsChanged);
	g_cvPhysics.AddChangeHook(vCvarsChanged);
	g_cvAmmo.AddChangeHook(vCvarsChanged);
	g_cvDelay.AddChangeHook(vCvarsChanged);
	g_cvVisible.AddChangeHook(vCvarsChanged);
	g_cvVisibleMode.AddChangeHook(vCvarsChanged);
	g_cvEffectMode.AddChangeHook(vCvarsChanged);
	g_cvEffectTime.AddChangeHook(vCvarsChanged);
	g_cvEffectGlowColor.AddChangeHook(vCvarsChanged);
	g_cvEffectGlowRange.AddChangeHook(vCvarsChanged);
	
	vEnablePlugin();
}

public void OnPluginEnd() {
	vDisablePlugin();
}

public void OnMapEnd() {
	vStopCleanTimer();
	vStopCheckSpawnTimer();
	g_bSpawnedWeapons = false;
}

Action cmdReloadWhiteList(int client, int args) {
	if (!g_bEnable)
		return Plugin_Continue;
	
	vLoadWhiteList();
	ReplyToCommand(client, "reloaded: %s", CFG_WHITELIST);
	return Plugin_Handled;
}

Action cmdCleanWeapon(int client, int args) {
	if (!g_bEnable)
		return Plugin_Continue;
	
	if (args > 0) {
		int count;
		char arg1[32], arg2[32];
		GetCmdArg(1, arg1, sizeof arg1);
		GetCmdArg(2, arg2, sizeof arg2);
		if (strncmp(arg1, "weapon_", 7) == 0)
			count = iCleanWeapons(arg1, arg2);
		else
			count = iCleanWeapons(arg2, arg1);
		
		ReplyToCommand(client, "cleaned (%i) %s %s",count, arg1, arg2);
	}
	else
		ReplyToCommand(client, "Usage: sm_wclean <name> | <classname>");

	return Plugin_Handled;
}

Action cmdCleanAllWeapons(int client, int args) {
	if (!g_bEnable)
		return Plugin_Continue;
	
	int count = iCleanWeapons();
	ReplyToCommand(client, "cleaned all (%i) weapons no equipped", count);
	return Plugin_Handled;
}

Action cmdClearWeapon(int client, int args) {
	if (!g_bEnable)
		return Plugin_Continue;
	
	if (args > 0) {
		int count;
		char arg1[32], arg2[32];
		GetCmdArg(1, arg1, sizeof arg1);
		GetCmdArg(2, arg2, sizeof arg2);
		if (strncmp(arg1, "weapon_", 7) == 0)
			count = iCleanWeapons(arg1, arg2, true);
		else
			count = iCleanWeapons(arg2, arg1, true);
		
		ReplyToCommand(client, "cleaned all (%i) %s %s", count, arg1, arg2);
	}
	else
		ReplyToCommand(client, "Usage: sm_wclear <name> | <classname>");

	return Plugin_Handled;
}

Action cmdClearAllWeapons(int client, int args) {
	if (!g_bEnable)
		return Plugin_Continue;
	
	int count = iCleanWeapons(_, _, true);
	ReplyToCommand(client, "cleaned all (%i) weapons", count);
	return Plugin_Handled;
}

Action sm_drop_Listener(int client, const char[] command, int argc) {
	if (bIsValidClient(client)) {
		int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if (bIsValidEnt(weapon) && bIsItemToClean(weapon)) {
			vRemoveEffects(weapon);
			vSetWeaponClean(weapon);
		}
	}

	return Plugin_Continue;
}

void vCvarChanged_Enable(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_bEnable = convar.BoolValue;
	if (g_bEnable && (strcmp(oldValue, "0") == 0))
		vReloadPlugin();
	else if (!g_bEnable && (strcmp(oldValue, "1") == 0))
		vDisablePlugin();
}

void vCvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars();
}

void vEnablePlugin() {
	g_bEnable = g_cvEnable.BoolValue;
	if (g_bEnable && g_bLateLoad) {
		vReloadPlugin();
	}
	else if (g_bEnable) {
		vHookEvents();
		AddCommandListener(sm_drop_Listener, "sm_drop");
	}
	vGetCvars();
}

void vHookEvents() {
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("weapon_drop", Event_WeaponDrop);
}

void vGetCvars() {
	g_bDrop			     = g_cvDrop.BoolValue;
	g_bPhisics		     = g_cvPhysics.BoolValue;
	g_bAmmo			     = g_cvAmmo.BoolValue;
	g_iSpawn			 = g_cvSpawn.IntValue;
	g_iClassWeapon	     = g_cvClass.IntValue;
	g_iCleanDelay		 = g_cvDelay.IntValue;
	g_bVisible		     = g_cvVisible.BoolValue;
	g_iVisibleMode	     = g_cvVisibleMode.IntValue;
	g_iEffectMode		 = g_cvEffectMode.IntValue;
	g_fEffectTime        = g_cvEffectTime.FloatValue;
	g_iEffectGlowRange   = g_cvEffectGlowRange.IntValue;
	char sTemp[16];
	g_cvEffectGlowColor.GetString(sTemp, sizeof sTemp);
	g_iEffectGlowColor = iStringRGBToIntRGB(sTemp);
}

void vInitCleanTrie() {
	int i;
	for (; i < sizeof g_sItemGun; i++)
		g_smCleanList.SetString(g_sModelGun[i], g_sItemGun[i]);

	for (i = 0; i < sizeof g_sItemMelee; i++)
		g_smCleanList.SetString(g_sModelMelee[i], g_sItemMelee[i]);

	for (i = 0; i < sizeof g_sItemGrenade; i++)
		g_smCleanList.SetString(g_sModelGrenade[i], g_sItemGrenade[i]);

	for (i = 0; i < sizeof g_sItemPack; i++)
		g_smCleanList.SetString(g_sModelPack[i], g_sItemPack[i]);

	for (i = 0; i < sizeof g_sItemConsumable; i++)
		g_smCleanList.SetString(g_sModelConsumable[i], g_sItemConsumable[i]);

	for (i = 0; i < sizeof g_sItemCarry; i++)
		g_smCleanList.SetString(g_sModelCarry[i], g_sItemCarry[i]);
}

void vLoadWhiteList() {
	//get file
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "%s", CFG_WHITELIST);

	//create file
	KeyValues hFile = new KeyValues("whitelist");
	if (!FileExists(sPath)) {
		File hCfg = OpenFile(sPath, "w");
		hCfg.WriteLine("");
		delete hCfg;
		
		if (hFile.JumpToKey("guns", true))
		{
			for (int i; i < sizeof g_sItemGun; i++)
				hFile.SetNum(g_sItemGun[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if (hFile.JumpToKey("melees", true))
		{
			for (int i; i < sizeof g_sItemMelee; i++)
				hFile.SetNum(g_sItemMelee[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if (hFile.JumpToKey("grenades", true))
		{
			for (int i; i < sizeof g_sItemGrenade; i++)
				hFile.SetNum(g_sItemGrenade[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if (hFile.JumpToKey("packs", true))
		{
			for (int i; i < sizeof g_sItemPack; i++)
				hFile.SetNum(g_sItemPack[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if (hFile.JumpToKey("consumables", true))
		{
			for (int i; i < sizeof g_sItemConsumable; i++)
				hFile.SetNum(g_sItemConsumable[i], 0);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		if (hFile.JumpToKey("carryables", true))
		{
			for (int i; i < sizeof g_sItemCarry; i++)
				hFile.SetNum(g_sItemCarry[i], 1);
			hFile.Rewind();
			hFile.ExportToFile(sPath);
		}
		BuildPath(Path_SM, sPath, sizeof sPath, "%s", CFG_WHITELIST);
	}
	// Load config
	g_smWhiteList.Clear();
	if (hFile.ImportFromFile(sPath)) {
		if (hFile.JumpToKey("guns", true)) {
			for (int i; i < sizeof g_sItemGun; i++) {
				if (hFile.GetNum(g_sItemGun[i]) == 1)
					g_smWhiteList.SetValue(g_sItemGun[i], true);
			}
			hFile.Rewind();
		}
		if (hFile.JumpToKey("melees", true)) {
			for (int i; i < sizeof g_sItemMelee; i++) {
				if (hFile.GetNum(g_sItemMelee[i]) == 1)
					g_smWhiteList.SetValue(g_sItemMelee[i],true);
			}
			hFile.Rewind();
		}
		if (hFile.JumpToKey("grenades", true)) {
			for (int i; i < sizeof g_sItemGrenade; i++) {
				if (hFile.GetNum(g_sItemGrenade[i]) == 1)
					g_smWhiteList.SetValue(g_sItemGrenade[i],true);
			}
			hFile.Rewind();
		}
		if (hFile.JumpToKey("packs", true)) {
			for (int i; i < sizeof g_sItemPack; i++) {
				if (hFile.GetNum(g_sItemPack[i]) == 1)
					g_smWhiteList.SetValue(g_sItemPack[i],true);
			}
			hFile.Rewind();
		}
		if (hFile.JumpToKey("consumables", true)) {
			for (int i; i < sizeof g_sItemConsumable; i++) {
				if (hFile.GetNum(g_sItemConsumable[i]) == 1)
					g_smWhiteList.SetValue(g_sItemConsumable[i],true);
			}
			hFile.Rewind();
		}
		if (hFile.JumpToKey("carryables", true)) {
			for (int i; i < sizeof g_sItemCarry; i++) {
				if (hFile.GetNum(g_sItemCarry[i]) == 1)
					g_smWhiteList.SetValue(g_sItemCarry[i],true);
			}
		}
	}
	delete hFile;
}

int iCleanWeapons(char[] classname = "", char[] itemname = "", bool equipped = false) {
	
	int count, ent = MaxClients + 1;
	char name[64];
	char class[64];
	strcopy(class, sizeof class, classname[0] == '\0' ? "*" : classname);
	while ((ent = FindEntityByClassname(ent, class)) != -1) {
		GetEntityClassname(ent, name, sizeof name);
		if (!bIsWeapon(name) && !bIsPropPhysic(name))
			continue;
	
		if (itemname[0] != '\0') {
			vGetItemName(ent, name, sizeof name);
			if (strcmp(name, itemname) != 0)
				continue;
		}
		
		if (!equipped && bIsWeaponEquipped(ent))
			continue;

		RemoveEntity(ent);
		count++;
	}

	return count;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	vLoadWhiteList();
	vStopCleanTimer();
	vStopCheckSpawnTimer();
	g_bSpawnedWeapons = false;

	char cls[13];
	int iEnt = MaxClients + 1;
	while ((iEnt = FindEntityByClassname(iEnt, "*")) != -1) {
		GetEntityClassname(iEnt, cls, sizeof cls);
		if (strncmp(cls, "weapon_", 7) == 0 || strcmp(cls, "prop_physics") == 0)
			RemoveEntity(iEnt);
	}
}

//postcheck weapons spowned on map or when round started
void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {	
	if (g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		vCheckSpawn();
	g_iRoundStart = 1;

	vStartTimerClean();
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		vCheckSpawn();
	g_iPlayerSpawn = 1;
}

void vCheckSpawn() {
	switch (g_iSpawn) {
		case 1:
			g_bSpawnedWeapons = true;

		case 2:
			vStartCheckSpawnTimer();
	}
}

void Event_WeaponDrop(Event event, const char[] name, bool dontBroadcast) {
	int weapon = event.GetInt("propid");
	if (bIsValidEnt(weapon) && bIsItemToClean(weapon)) {
		vRemoveEffects(weapon);
		vSetWeaponClean(weapon);
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (!g_bEnable)
		return;
	
	if (g_iSpawn && !g_bSpawnedWeapons)
		return;

	if (classname[0] != 'w' && classname[0] != 'p')
		return;
	
	if (!g_bDrop && bIsWeapon(classname))
		SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
	else if (g_bPhisics && (strcmp(classname, "physics_prop") == 0 || strcmp(classname, "prop_physics") == 0))
		SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
}

public void OnEntityDestroyed(int entity) {
	if (!g_bEnable) 
		return;

	if (entity > MaxClients)
		vUnSetWeaponClean(entity);
}

public void OnClientPutInServer(int client) {
	if (!g_bEnable) 
		return;
		
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDropPost);
}

public void OnClientDisconnect(int client) {
	if (!g_bEnable) 
		return;

	if (!bIsValidSurvivor(client))
		return;
	
	for (int i; i < 5; i++) {
		int weapon = GetPlayerWeaponSlot(client, i);
		if (!bIsValidEnt(weapon) || !bIsItemToClean(weapon))
			continue;

		vRemoveEffects(weapon);
		vSetWeaponClean(weapon);
	}
}

void OnSpawnPost(int entity) {
	if (bIsValidEnt(entity) && bIsItemToClean(entity)) {
		vSetWeaponClean(entity);
		_debug("Spawn:%d", entity);
	}
}

void OnWeaponEquipPost(int client, int weapon) {
	
	if (!bIsValidSurvivor(client))
		return;
	
	if (weapon > MaxClients) {
		vRemoveEffects(weapon);
		vUnSetWeaponClean(weapon);
	}
	_debug("HOOK-player:%d Equip : %d", client, weapon);
}

void OnWeaponDropPost(int client, int weapon) {
	
	if (bIsValidSurvivor(client) && bIsValidEnt(weapon) && bIsItemToClean(weapon) && !bIsWeaponEquipped(weapon)) {
		vRemoveEffects(weapon);
		vSetWeaponClean(weapon);
		_debug("HOOK-player:%d Drop : %d", client, weapon);
	}
}

Action tmrCheckSpawn(Handle timer) {
	g_hCheckSpawnTimer = null;
	g_bSpawnedWeapons = true;
	return Plugin_Continue;
}

Action tmrCleaningWeapons(Handle timer) {
	static int i;
	static int weapon;
	for (i = MaxClients + 1; i < sizeof g_iWeaponRef; i++) {
		if (!g_iWeaponRef[i])
			continue;

		weapon = EntRefToEntIndex(g_iWeaponRef[i]);
		if (!bIsValidEnt(weapon)) {
			vUnSetWeaponClean(weapon);
			continue;
		}

		if (g_iItemTime[weapon] < 0) {
			vUnSetWeaponClean(weapon);
			continue;
		}

		if (!bIsItemToClean(weapon)) {
			vUnSetWeaponClean(weapon);
			continue;
		}

		if (bIsWeaponEquipped(weapon)) {
			_debug("USER: %d", weapon);
			vRemoveEffects(weapon);
			//g_iItemTime[weapon] = g_iCleanDelay;
			vUnSetWeaponClean(weapon);
			continue;
		}
		else if (g_iItemTime[weapon] == 0) {
			vUnSetWeaponClean(weapon);
			RemoveEntity(weapon);
			continue;
		}
		else if (g_bVisible && bIsVisibleToPlayers(weapon)) {
			vSetEffects(weapon);
			switch (g_iVisibleMode) {
				case 0: {  //Pause Timer
					_debug("Pause Time: %d", g_iItemTime[weapon]);
					continue;
				}

				case 1: {  //Pause Timer on aiming
					if (bIsAimToPlayers(weapon)) {
						_debug("Pause Time: %d", g_iItemTime[weapon]);
						continue;
					}
				}

				case 2: {  //Reset Timer
					g_iItemTime[weapon] = g_iCleanDelay;
					vRemoveEffects(weapon);
					_debug("Reset Time: %d", g_iItemTime[weapon]);
					continue;
				}

				case 3: {  //Reset Timer on aiming
					if (bIsAimToPlayers(weapon)) {
						g_iItemTime[weapon] = g_iCleanDelay;
						vRemoveEffects(weapon);
						_debug("Pause Time: %d", g_iItemTime[weapon]);
						continue;
					}
				}
			}
		}

		vSetEffects(weapon);
		g_iItemTime[weapon]--;
		_debug("Time: %d", g_iItemTime[weapon]);			
	}

	return Plugin_Continue;
}

void vStartCheckSpawnTimer() {
	vStopCheckSpawnTimer();
	g_hCheckSpawnTimer = CreateTimer(3.0, tmrCheckSpawn);
}

void vStopCheckSpawnTimer() {
	delete g_hCheckSpawnTimer;
}

void vStartTimerClean() {
	vStopCleanTimer();
	g_hCleaningTimer = CreateTimer(1.0, tmrCleaningWeapons, _, TIMER_REPEAT);
}

void vStopCleanTimer() {
	delete g_hCleaningTimer;
}

void vSetEffects(int item) {
	if (!bIsValidEnt(item) || g_iItemTime[item] <= 0 || !bIsItemToClean(item))
		return;

	int time_fx = RoundFloat(g_fEffectTime >= 1.0 ? g_fEffectTime : float(g_iCleanDelay) * g_fEffectTime);
	if (g_iItemTime[item] <= time_fx) {
		//old effects
		/*
		if (g_iEffectMode & 1) {
			if (g_iItemTime[item] == (time_fx / 4)) {
				SetEntityRenderFx(item, RENDERFX_STROBE_FASTER);
			} else if (g_iItemTime[item] == (time_fx / 2)) {
				SetEntityRenderFx(item, RENDERFX_STROBE_FAST);
			} else if (g_iItemTime[item] == time_fx) {
				SetEntityRenderFx(item, RENDERFX_STROBE_SLOW);
			}
		}
		*/
		if (g_iEffectMode & 1) {
			if (g_iItemTime[item] == time_fx)
				SetEntityRenderFx(item, RENDERFX_PULSE_SLOW);
			if (g_iItemTime[item] == time_fx / 2)
				SetEntityRenderFx(item, RENDERFX_PULSE_FAST);
			if (g_iItemTime[item] == time_fx / 3)
				SetEntityRenderFx(item, RENDERFX_PULSE_SLOW_WIDE);
			if (g_iItemTime[item] == time_fx / 4)
				SetEntityRenderFx(item, RENDERFX_PULSE_FAST_WIDE);
			if (g_iItemTime[item] == time_fx / 5)
				SetEntityRenderFx(item, RENDERFX_EXPLODE);
		}

		if (g_iEffectMode & 2) {
			//g_iGlowColor = StringToRGB(g_iEffectGlowColor);
			if (g_iItemTime[item] == (time_fx / 2))
				L4D2_SetEntityGlow(item, L4D2Glow_OnLookAt, g_iEffectGlowRange, 100, g_iEffectGlowColor, true);
			else if (g_iItemTime[item] == time_fx)
				L4D2_SetEntityGlow(item, L4D2Glow_OnLookAt, g_iEffectGlowRange, 100, g_iEffectGlowColor, false);
		}
	}
}

void vRemoveEffects(int item) {
	if (g_iItemTime[item] && bIsValidEnt(item) && bIsItemToClean(item)) {
		L4D2_RemoveEntityGlow(item);
		SetEntityRenderFx(item, RENDERFX_NONE);
	}
}

bool bIsVisibleToPlayers(int entity) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && (GetClientAimTarget(i, false) == entity || bIsEntVisibleCam(i, entity))) {
			return true;
		}
	}
	return false;
}

bool bIsAimToPlayers(int entity) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && GetClientAimTarget(i, false) == entity)
			return true;
	}
	return false;
}

bool bIsEntVisibleCam(int client, int entity, float fov = 60.0) {
	float vPos[3], vAng[3], vAim[3], vTarget[3], vEnt[3];
	GetClientEyePosition(client, vPos);
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", vEnt);
	if (bIsVisibleTo(vPos, vEnt)) {
		GetClientEyeAngles(client, vAng);
		SubtractVectors(vEnt, vPos, vTarget);
		GetAngleVectors(vAng, vAim, NULL_VECTOR, NULL_VECTOR);
		float ang  = ArcCosine(GetVectorDotProduct(vAim, vTarget) / (GetVectorLength(vAim) * GetVectorLength(vTarget))) * 360.0 / 2.0 / FLOAT_PI;
		return ang < fov;
	}
	return false;
}
// credits = "AtomicStryker"
bool bIsVisibleTo(const float vPos[3], const float vTarget[3]) {
	static float vAngles[3], vLookAt[3];
	MakeVectorFromPoints(vPos, vTarget, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	static Handle hTrace;
	static bool bIsVisible;
	hTrace = TR_TraceRayFilterEx(vPos, vAngles, MASK_ALL, RayType_Infinite, bTraceEntityFilter);
	bIsVisible = false;
	if (TR_DidHit(hTrace)) {
		static float vStart[3];
		TR_GetEndPosition(vStart, hTrace); // retrieve our trace endpoint

		if ((GetVectorDistance(vPos, vStart, false) + 25.0) >= GetVectorDistance(vPos, vTarget))
			bIsVisible = true; // if trace ray length plus tolerance equal or bigger absolute distance, you hit the target
	}

	delete hTrace;
	return bIsVisible;
}

bool bTraceEntityFilter(int entity, int contentsMask) {
	return entity > MaxClients && IsValidEntity(entity);
}

bool bIsWeaponEquipped(int weapon) {	
	static char cls[64];
	GetEntityClassname(weapon, cls, sizeof cls);
	if (!bIsWeapon(cls) || bIsWeaponSpawner(cls))
		return false;

	return bIsValidClient(GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity"));
}

void vGetItemName(int ent, char[] name, int size) {
	bool bWeapon = bIsWeapon(name);
	bool bSpawner = bIsSpawner(name);
	if (bWeapon && !bSpawner) {
		if (!bIsMelee(name))
			SplitStringRight(name, "weapon_", name, size);
		else
			GetEntPropString(ent, Prop_Data, "m_strMapSetScriptName", name, size);
		return;
	}
	else if (bWeapon && bSpawner || bIsPropPhysic(name)) {	
		static char modelname[64];
		GetEntPropString(ent, Prop_Data, "m_ModelName", modelname, sizeof modelname);
		if (g_smCleanList.GetString(modelname, name, size))
			return;
	}
	name[0] = '\0';
}

bool bIsClassEnable(const char[] cls) {
	if (!bIsSpawner(cls)) {
		if (g_iClassWeapon & 1)
			return true;
	}
	else {
		if (g_iClassWeapon & 2 && (g_bAmmo || !bIsAmmoPile(cls)) && !bIsScavengeItem(cls))
			return true;
	}

	return false;
}

bool bIsItemToClean(int item) {
	static char name[64];
	GetEntityClassname(item, name, sizeof name);
	if ((bIsWeapon(name) && bIsClassEnable(name)) || (g_bPhisics && bIsPropPhysic(name))) {
		bool exclude;
		vGetItemName(item, name, sizeof name);//weapon_first_aid_kit_spawn
		g_smWhiteList.GetValue(name, exclude);
		if (exclude)
			return false;

		if (strcmp(name, "weapon_gascan") != 0 && strcmp(name, "prop_physics") != 0 && strcmp(name, "physics_prop") != 0)
			return true;

		GetEntPropString(item, Prop_Data, "m_ModelName", name, sizeof name);
		if (strcmp(name, "models/props_junk/gascan001a.mdl", false) != 0)
			return true;

		return GetEntProp(item, Prop_Send, "m_nSkin") < 1;
	}

	return false;
}

void vSetWeaponClean(int weapon) {
	g_iItemTime[weapon] = g_iCleanDelay;
	g_iWeaponRef[weapon] = EntIndexToEntRef(weapon);
}

void vUnSetWeaponClean(int item) {
	g_iItemTime[item] = -1;
	g_iWeaponRef[item] = 0;
}

bool bIsMelee(const char[] cls) {
	return strcmp(cls[7], "melee") == 0;
}

bool bIsScavengeItem(const char[] cls) {
	return strcmp(cls[7], "scavenge_item_spawn") == 0;
}

bool bIsWeaponSpawner(const char[] cls) {
	return bIsWeapon(cls) && bIsSpawner(cls);
}

bool bIsSpawner(const char[] cls) {
	return strncmp(cls[strlen(cls) - 6], "_spawn", 7) == 0;
}

bool bIsAmmoPile(const char[] cls) {
	return strcmp(cls[7], "ammo_spawn") == 0;
}

bool bIsPropPhysic(const char[] cls) {
	return strcmp(cls, "prop_physics") == 0;
}

bool bIsWeapon(const char[] cls) {
	return strncmp(cls, "weapon_", 7) == 0;
}

bool bIsValidEnt(int entity) {
	return entity > MaxClients && IsValidEntity(entity);
}

bool bIsValidSurvivor(int client) {
	return bIsValidClient(client) && GetClientTeam(client) == 2;
}

bool bIsValidClient(int client) {
	return 0 < client <= MaxClients && IsClientInGame(client);
}

int[] iStringRGBToIntRGB(const char[] str_rgb) {
	int colorRGB[3];
	char str_color[16][3];
	char color_string[16];
	strcopy(color_string, sizeof color_string, str_rgb);
	TrimString(color_string);
	ExplodeString(color_string, ",", str_color, sizeof str_color[], sizeof str_color);
	colorRGB[0] = StringToInt(str_color[0]);
	colorRGB[1] = StringToInt(str_color[1]);
	colorRGB[2] = StringToInt(str_color[2]);
	return colorRGB;
}

bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen) {
	int index = StrContains(source, split); // get start index of split string 
	
	if (index == -1) // split string not found.. 
		return false;
	
	index += strlen(split); // get end index of split string
	
	if (index == strlen(source) - 1) // no right side exist
		return false;
	
	strcopy(part, partLen, source[index]); // copy everything after source[ index ] to part 
	return true;
}

void _debug(const char[] szFormat, int ...) {
	char szText[4096];
	VFormat(szText, sizeof szText, szFormat, 2);
	//server_print("#DEBUG: %s", szText);
	#if defined DEBUG
	PrintToChatAll("#DEBUG: %s", szText);
	#endif
}

void vReloadPlugin() {
	vHookEvents();
	AddCommandListener(sm_drop_Listener, "sm_drop");
	
	int i = MaxClients + 1;
	for (; i <= GetMaxEntities(); i++) {
		if (IsValidEntity(i) && bIsItemToClean(i) && !bIsWeaponEquipped(i)) {
			vSetWeaponClean(i);
		}
	}
	
	for (i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			SDKHook(i, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
			SDKHook(i, SDKHook_WeaponDropPost, OnWeaponDropPost);
		}
	}
	vStartTimerClean();
}

void vDisablePlugin() {
	UnHookEvents();
	RemoveCommandListener(sm_drop_Listener, "sm_drop");
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			SDKUnhook(i, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
			SDKUnhook(i, SDKHook_WeaponDropPost, OnWeaponDropPost);
		}
	}
	vStopCleanTimer();
}

void UnHookEvents() {
	UnhookEvent("round_end", Event_RoundEnd);
	UnhookEvent("round_start", Event_RoundStart);
	UnhookEvent("player_spawn", Event_PlayerSpawn);
	UnhookEvent("weapon_drop", Event_WeaponDrop);
}
