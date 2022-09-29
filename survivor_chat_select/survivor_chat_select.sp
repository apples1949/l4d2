#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <adminmenu>
#include <left4dhooks>

#define PLUGIN_VERSION "1.7.3"
#define PLUGIN_NAME 	"Survivor Chat Select"
#define PLUGIN_PREFIX	"\x01[\x04SCS\x01]"

#define GAMEDATA		"survivor_chat_select"

#define	 NICK		0, 0
#define	 ROCHELLE	1, 1
#define	 COACH		2, 2
#define	 ELLIS		3, 3
#define	 BILL		4, 4
#define	 ZOEY		5, 5
#define	 FRANCIS	6, 6
#define	 LOUIS		7, 7

Handle
	g_hSDK_CDirector_IsInTransition,
	g_hSDK_KeyValues_GetString;

StringMap
	g_smSurvivorModels;

Cookie
	g_ckClientID,
	g_ckClientModel;

TopMenu
	hTopMenu;

Address
	g_pDirector,
	g_pSavedPlayersCount,
	g_pSavedSurvivorBotsCount;

ConVar
	g_cvCookie,
	g_cvAutoModel,
	g_cvTabHUDBar,
	g_cvAdminsOnly,
	g_cvInTransition,
	g_cvPrecacheAllSur;

int
	g_iTabHUDBar,
	g_iOrignalSet,
	g_iSelectedClient[MAXPLAYERS + 1];

bool
	g_bCookie,
	g_bAutoModel,
	g_bAdminsOnly,
	g_bInTransition,
	g_bHideNameChange,
	g_bShouldIgnoreOnce[MAXPLAYERS + 1];

static const char
	g_sSurvivorNames[][] = {
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis",
	},
	g_sSurvivorModels[][] = {
		"models/survivors/survivor_gambler.mdl",
		"models/survivors/survivor_producer.mdl",
		"models/survivors/survivor_coach.mdl",
		"models/survivors/survivor_mechanic.mdl",
		"models/survivors/survivor_namvet.mdl",
		"models/survivors/survivor_teenangst.mdl",
		"models/survivors/survivor_biker.mdl",
		"models/survivors/survivor_manager.mdl"
	};

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = "DeatChaos25, Mi123456 & Merudo, Lux, SilverShot",
	description = "Select a survivor character by typing their name into the chat.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2399163#post2399163"
}

public void OnPluginStart() {
	InitGameData();
	g_smSurvivorModels = new StringMap();
	HookUserMessage(GetUserMessageId("SayText2"), umSayText2, true);

	g_ckClientID = new Cookie("Player_Character", "Player's default character ID.", CookieAccess_Protected);
	g_ckClientModel = new Cookie("Player_Model", "Player's default character model.", CookieAccess_Protected);

	RegConsoleCmd("sm_zoey", 		cmdZoeyUse, 	"Changes your survivor character into Zoey");
	RegConsoleCmd("sm_nick", 		cmdNickUse, 	"Changes your survivor character into Nick");
	RegConsoleCmd("sm_ellis", 		cmdEllisUse, 	"Changes your survivor character into Ellis");
	RegConsoleCmd("sm_coach", 		cmdCoachUse, 	"Changes your survivor character into Coach");
	RegConsoleCmd("sm_rochelle", 	cmdRochelleUse, "Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_bill", 		cmdBillUse, 	"Changes your survivor character into Bill");
	RegConsoleCmd("sm_francis", 	cmdBikerUse, 	"Changes your survivor character into Francis");
	RegConsoleCmd("sm_louis", 		cmdLouisUse, 	"Changes your survivor character into Louis");

	RegConsoleCmd("sm_z", 			cmdZoeyUse, 	"Changes your survivor character into Zoey");
	RegConsoleCmd("sm_n", 			cmdNickUse, 	"Changes your survivor character into Nick");
	RegConsoleCmd("sm_e", 			cmdEllisUse, 	"Changes your survivor character into Ellis");
	RegConsoleCmd("sm_c", 			cmdCoachUse, 	"Changes your survivor character into Coach");
	RegConsoleCmd("sm_r", 			cmdRochelleUse, "Changes your survivor character into Rochelle");
	RegConsoleCmd("sm_b", 			cmdBillUse, 	"Changes your survivor character into Bill");
	RegConsoleCmd("sm_f", 			cmdBikerUse, 	"Changes your survivor character into Francis");
	RegConsoleCmd("sm_l", 			cmdLouisUse, 	"Changes your survivor character into Louis");

	RegConsoleCmd("sm_csm", 		cmdCsm, 		"Brings up a menu to select a client's character");

	RegAdminCmd("sm_setleast", 	cmdSetLeast, ADMFLAG_ROOT, 	"");
	RegAdminCmd("sm_csc", cmdCsc, ADMFLAG_ROOT, 	"Brings up a menu to select a client's character");

	HookEvent("round_start", 		Event_RoundStart, 		EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", Event_BotPlayerReplace, EventHookMode_Pre);
	HookEvent("player_bot_replace", Event_PlayerBotReplace, EventHookMode_Pre);
	HookEvent("player_spawn", 		Event_PlayerSpawn);

	g_cvCookie = 		CreateConVar("l4d_scs_cookie", 			"0","保存玩家的模型角色喜好?", FCVAR_NOTIFY);
	g_cvAutoModel = 	CreateConVar("l4d_scs_auto_model", 		"1","开关8人独立模型?", FCVAR_NOTIFY);
	g_cvTabHUDBar = 	CreateConVar("l4d_scs_tab_hud_bar", 	"1","在哪些地图上显示一代人物的TAB状态栏? \n0=默认, 1=一代图, 2=二代图, 3=一代和二代图.", FCVAR_NOTIFY);
	g_cvAdminsOnly = 	CreateConVar("l4d_csm_admins_only", 	"1","只允许管理员使用csm命令?", FCVAR_NOTIFY);
	g_cvInTransition = 	CreateConVar("l4d_csm_in_transition", 	"1","启用8人独立模型后不对正在过渡的玩家设置?", FCVAR_NOTIFY);
	g_cvPrecacheAllSur = FindConVar("precache_all_survivors");

	g_cvCookie.AddChangeHook(CvarChanged);
	g_cvAutoModel.AddChangeHook(CvarChanged);
	g_cvTabHUDBar.AddChangeHook(CvarChanged);
	g_cvAdminsOnly.AddChangeHook(CvarChanged);
	g_cvInTransition.AddChangeHook(CvarChanged);

	AutoExecConfig(true, "survivor_chat_select");

	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu())))
		OnAdminMenuReady(topmenu);

	for (int i; i < sizeof g_sSurvivorModels; i++)
		g_smSurvivorModels.SetValue(g_sSurvivorModels[i], i);
}

public void OnAdminMenuReady(Handle aTopMenu) {
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
	if (topmenu == hTopMenu)
		return;

	hTopMenu = topmenu;
	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
	if (player_commands != INVALID_TOPMENUOBJECT)
		hTopMenu.AddItem("sm_csc", AdminMenu_Csc, player_commands, "sm_csc", ADMFLAG_ROOT);
}

void AdminMenu_Csc(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength) {
	switch (action) {
		case TopMenuAction_DisplayOption:
			FormatEx(buffer, maxlength, "更改玩家人物模型", "", param);

		case TopMenuAction_SelectOption:
			cmdCsc(param, 0);
	}
}

Action cmdSetLeast(int client, int args) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
			SetLeastCharacter(i);
	}

	return Plugin_Handled;
}

Action cmdCsc(int client, int args) {
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	char Id[16];
	char name[MAX_NAME_LENGTH];

	Menu menu = new Menu(Csc_MenuHandler);
	menu.SetTitle("目标玩家:");

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;

		FormatEx(Id, sizeof Id, "%d", GetClientUserId(i));
		FormatEx(name, sizeof name, "%N", i);
		menu.AddItem(Id, name);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int Csc_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			char item[16];
			menu.GetItem(param2, item, sizeof item);
			g_iSelectedClient[client] = StringToInt(item);

			ShowMenuAdmin(client);
		}
	
		case MenuAction_Cancel: {
			if (param2 == MenuCancel_ExitBack && hTopMenu != null)
				DisplayTopMenu(hTopMenu, client, TopMenuPosition_LastCategory);
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void ShowMenuAdmin(int client) {
	Menu menu = new Menu(ShowMenuAdmin_MenuHandler);
	menu.SetTitle("人物:");

	menu.AddItem("0", "Nick");
	menu.AddItem("1", "Rochelle");
	menu.AddItem("2", "Coach");
	menu.AddItem("3", "Ellis");
	menu.AddItem("4", "Bill");
	menu.AddItem("5", "Zoey");
	menu.AddItem("6", "Francis");
	menu.AddItem("7", "Louis");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int ShowMenuAdmin_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			switch (param2) {
				case 0:
					SetCharacter(GetClientOfUserId(g_iSelectedClient[client]), NICK, false);

				case 1:
					SetCharacter(GetClientOfUserId(g_iSelectedClient[client]), ROCHELLE, false);

				case 2:
					SetCharacter(GetClientOfUserId(g_iSelectedClient[client]), COACH, false);

				case 3:
					SetCharacter(GetClientOfUserId(g_iSelectedClient[client]), ELLIS, false);

				case 4:
					SetCharacter(GetClientOfUserId(g_iSelectedClient[client]), BILL, false);

				case 5:
					SetCharacter(GetClientOfUserId(g_iSelectedClient[client]), ZOEY, false);

				case 6:
					SetCharacter(GetClientOfUserId(g_iSelectedClient[client]), FRANCIS, false);

				case 7:
					SetCharacter(GetClientOfUserId(g_iSelectedClient[client]), LOUIS, false);
			}
		}
	
		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action cmdCsm(int client, int args) {
	if (!CanUse(client)) 
		return Plugin_Handled;

	Menu menu = new Menu(Csm_MenuHandler);
	menu.SetTitle("选择人物:");

	menu.AddItem("0", "Nick");
	menu.AddItem("1", "Rochelle");
	menu.AddItem("2", "Coach");
	menu.AddItem("3", "Ellis");
	menu.AddItem("4", "Bill");
	menu.AddItem("5", "Zoey");
	menu.AddItem("6", "Francis");
	menu.AddItem("7", "Louis");

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int Csm_MenuHandler(Menu menu, MenuAction action, int client, int param2) {
	switch (action) {
		case MenuAction_Select: {
			switch (param2) {
				case 0:
					SetCharacter(client, NICK);

				case 1:
					SetCharacter(client, ROCHELLE);

				case 2:
					SetCharacter(client, COACH);

				case 3:
					SetCharacter(client, ELLIS);

				case 4:
					SetCharacter(client, BILL);

				case 5:
					SetCharacter(client, ZOEY);

				case 6:
					SetCharacter(client, FRANCIS);

				case 7:
					SetCharacter(client, LOUIS);
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

bool CanUse(int client, bool checkAdmin = true) {
	if (!client || !IsClientInGame(client)) {
		ReplyToCommand(client, "角色选择菜单仅适用于游戏中的玩家.");
		return false;
	}

	if (checkAdmin && g_bAdminsOnly && GetUserFlagBits(client) == 0) {
		ReplyToCommand(client, "只有管理员才能使用该菜单.");
		return false;
	}

	if (GetClientTeam(client) != 2) {
		ReplyToCommand(client, "角色选择菜单仅适用于幸存者.");
		return false;
	}

	if (L4D_IsPlayerStaggering(client)) {
		ReplyToCommand(client, "硬直状态下无法使用该指令.");
		return false;
	}

	if (IsGettingUp(client)) {
		ReplyToCommand(client, "起身过程中无法使用该指令.");
		return false;
	}

	if (IsPinned(client)) {
		ReplyToCommand(client, "被控制时无法使用该指令.");
		return false;
	}

	return true;
}

//https://github.com/LuxLuma/L4D2_Adrenaline_Recovery
bool IsGettingUp(int client) {
	char sModel[31];
	GetClientModel(client, sModel, sizeof sModel);
	switch (sModel[29]) {
		case 'b': {	//nick
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 680, 667, 671, 672, 630, 620, 627:
					return true;
			}
		}

		case 'd': {	//rochelle
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}

		case 'c': {	//coach
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 669, 661, 660, 656, 630, 627, 621:
					return true;
			}
		}

		case 'h': {	//ellis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 684, 676, 675, 671, 625, 635, 632:
					return true;
			}
		}

		case 'v': {	//bill
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}

		case 'n': {	//zoey
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 824, 823, 819, 809, 547, 544, 537:
					return true;
			}
		}

		case 'e': {	//francis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 775, 767, 766, 762, 541, 539, 531:
					return true;
			}
		}

		case 'a': {	//louis
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 772, 764, 763, 759, 538, 535, 528:
					return true;
			}
		}

		case 'w': {	//adawong
			switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 687, 679, 678, 674, 638, 635, 629:
					return true;
			}
		}
	}

	return false;
}

bool IsPinned(int client) {
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	return false;
}

Action cmdZoeyUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;

	SetCharacter(client, ZOEY);
	return Plugin_Handled;
}

Action cmdNickUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;
	
	SetCharacter(client, NICK);
	return Plugin_Handled;
}

Action cmdEllisUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;
	
	SetCharacter(client, ELLIS);
	return Plugin_Handled;
}

Action cmdCoachUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;
	
	SetCharacter(client, COACH);
	return Plugin_Handled;
}

Action cmdRochelleUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;
	
	SetCharacter(client, ROCHELLE);
	return Plugin_Handled;
}

Action cmdBillUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;
	
	SetCharacter(client, BILL);
	return Plugin_Handled;
}

Action cmdBikerUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;
	
	SetCharacter(client, FRANCIS);
	return Plugin_Handled;
}

Action cmdLouisUse(int client, int args) {
	if (!CanUse(client))
		return Plugin_Handled;
	
	SetCharacter(client, LOUIS);
	return Plugin_Handled;
}

Action umSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	if (!g_bHideNameChange)
		return Plugin_Continue;

	msg.ReadByte();
	msg.ReadByte();

	char sMessage[254];
	msg.ReadString(sMessage, sizeof sMessage, true);
	if (strcmp(sMessage, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnMapStart() {
	g_cvPrecacheAllSur.SetInt(1);

	for (int i; i < 8; i++)
		PrecacheModel(g_sSurvivorModels[i], true);
}

public void OnConfigsExecuted() {
	GetCvars();
	g_iOrignalSet = L4D2_GetSurvivorSetMap();
	g_pDirector = L4D_GetPointer(POINTER_DIRECTOR);
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_bCookie = g_cvCookie.BoolValue;
	g_bAutoModel= g_cvAutoModel.BoolValue;
	g_iTabHUDBar = g_cvTabHUDBar.IntValue;
	g_bAdminsOnly = g_cvAdminsOnly.BoolValue;
	g_bInTransition = g_cvInTransition.BoolValue;
}

void Event_RoundStart(Event event, char[] name, bool dontBroadcast) {
	for (int i; i <= MaxClients; i++)
		g_bShouldIgnoreOnce[i] = false;
}

void Event_BotPlayerReplace(Event event, char[] name, bool dontBroadcast) {
	if (!g_bAutoModel)
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != 2) 
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || !IsClientInGame(bot)) {
		SetLeastCharacter(player);
		return;
	}

	g_bShouldIgnoreOnce[bot] = false;
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast) {
	if (!g_bAutoModel)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot || !IsClientInGame(bot))
		return;

	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || GetClientTeam(player) != 2)
		return;

	if (IsFakeClient(player)) {
		SetLeastCharacter(bot);
		RequestFrame(NextFrame_ResetVar, bot);
		return;
	}

	g_bShouldIgnoreOnce[bot] = true;
	RequestFrame(NextFrame_ResetVar, bot);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 2)
		return;

	if (g_bAutoModel && !g_bShouldIgnoreOnce[client] && !IsPlayerAlive(client) && !GetBotOfIdlePlayer(client))
		RequestFrame(NextFrame_PlayerSpawn, event.GetInt("userid"));

	if (g_bCookie)
		CreateTimer(0.6, tmrLoadCookie, event.GetInt("userid"), TIMER_FLAG_NO_MAPCHANGE);
}

void NextFrame_ResetVar(int bot) {
	g_bShouldIgnoreOnce[bot] = false;
}

int GetBotOfIdlePlayer(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

void NextFrame_PlayerSpawn(int client) {
	if (!g_bAutoModel || !(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 2 || g_bShouldIgnoreOnce[client])
		return;

	SetLeastCharacter(client);
}

Action tmrLoadCookie(Handle timer, int client) {
	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client) || GetClientTeam(client) != 2)
		return Plugin_Stop;

	if (!AreClientCookiesCached(client)) {
		ReplyToCommand(client, "%s 无法载入你的人物角色,请输入 \x05!csm \x01来设置你的人物角色.", PLUGIN_PREFIX);
		return Plugin_Stop;
	}

	char sID[2];
	g_ckClientID.Get(client, sID, sizeof sID);

	char sModel[128];
	g_ckClientModel.Get(client, sModel, sizeof sModel);

	if (sID[0] && sModel[0]) {
		SetEntProp(client, Prop_Send, "m_survivorCharacter", StringToInt(sID));
		SetEntityModel(client, sModel);
	}

	return Plugin_Continue;
}

void SetCharacter(int client, int character, int modelIndex, bool saveData = true) {
	if (!CanUse(client, false))
		return;

	SetCharacterInfo(client, character, modelIndex);

	if (saveData && g_bCookie) {
		char sProp[2];
		IntToString(character, sProp, sizeof sProp);
		g_ckClientID.Set(client, sProp);
		g_ckClientModel.Set(client, g_sSurvivorModels[modelIndex]);
		ReplyToCommand(client, "%s 你的人物角色现在已经被设为 \x03%s\x01.", PLUGIN_PREFIX, g_sSurvivorNames[modelIndex]);
	}
}

public void OnEntityCreated(int entity, const char[] classname) {
	if (!g_bAutoModel)
		return;

	if (entity < 1 || entity > MaxClients)
		return;

	if (classname[0] == 'p' && strcmp(classname[1], "layer", false) == 0) {
		if (!g_bInTransition || !IsTransitioning(GetClientUserId(entity)))
			SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
	}

	if (classname[0] == 's' && strcmp(classname[1], "urvivor_bot", false) == 0) {
		if (!g_bInTransition || !RestoringBots())
			SDKHook(entity, SDKHook_SpawnPost, OnSpawnPost);
	}
}

bool RestoringBots() {
	return SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector) && LoadFromAddress(g_pSavedSurvivorBotsCount, NumberType_Int32);
}

void OnSpawnPost(int client) {
	SDKUnhook(client, SDKHook_SpawnPost, OnSpawnPost);

	if (g_bAutoModel && GetClientTeam(client) != 4)
		RequestFrame(NextFrame_SpawnPost, GetClientUserId(client));
}

void NextFrame_SpawnPost(int client) {
	if (!g_bAutoModel)
		return;

	if (!(client = GetClientOfUserId(client)) || !IsClientInGame(client))
		return;

	int idlePlayer = GetIdlePlayerOfBot(client);
	if (g_bInTransition && IsLoading(idlePlayer))
		return;

	if (GetClientTeam(client) != 2) {
		if (AllowSetCharacter(idlePlayer))
			SetLeastCharacter(idlePlayer);
	}
	else if (!g_bShouldIgnoreOnce[client])
		SetLeastCharacter(client);
}

bool IsLoading(int client) {
	return client && IsClientConnected(client) && !IsClientInGame(client);
}

bool IsTransitioning(int userid) {
	if (!SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector))
		return false;

	int dataCount = LoadFromAddress(g_pSavedPlayersCount, NumberType_Int32);
	if (!dataCount)
		return false;

	Address keyValue = view_as<Address>(LoadFromAddress(g_pSavedPlayersCount + view_as<Address>(4), NumberType_Int32));
	if (!keyValue)
		return false;

	Address ptr;
	char value[12];
	for (int i; i < dataCount; i++) {
		ptr = view_as<Address>(LoadFromAddress(keyValue + view_as<Address>(4 * i), NumberType_Int32));
		if (!ptr)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, ptr, value, sizeof value, "userID", "0");
		if (StringToInt(value) != userid)
			continue;
	
		SDKCall(g_hSDK_KeyValues_GetString, ptr, value, sizeof value, "teamNumber", "0");
		if (StringToInt(value) != 2)
			continue;

		SDKCall(g_hSDK_KeyValues_GetString, ptr, value, sizeof value, "restoreState", "0");
		if (!StringToInt(value))
			return true;
	}

	return false;
}

bool AllowSetCharacter(int client) {
	return client && IsClientInGame(client) && GetClientTeam(client) == 2 && !g_bShouldIgnoreOnce[client];
}

void SetLeastCharacter(int client) {
	switch (GetLeastCharacter(client)) {
		case 0:
			SetCharacterInfo(client, NICK);

		case 1:
			SetCharacterInfo(client, ROCHELLE);

		case 2:
			SetCharacterInfo(client, COACH);

		case 3:
			SetCharacterInfo(client, ELLIS);

		case 4:
			SetCharacterInfo(client, BILL);

		case 5:
			SetCharacterInfo(client, ZOEY);

		case 6:
			SetCharacterInfo(client, FRANCIS);

		case 7:
			SetCharacterInfo(client, LOUIS);	
	}
}

int GetLeastCharacter(int client) {
	int i = 1;
	int charBuffer;
	int leastChar[8];
	char sModel[PLATFORM_MAX_PATH];
	for (; i <= MaxClients; i++) {
		if (i == client || !IsClientInGame(i) || GetClientTeam(i) != 2)
			continue;

		GetClientModel(i, sModel, sizeof sModel);
		//StringToLowerCase(sModel);
		if (!g_smSurvivorModels.GetValue(sModel, charBuffer))
			continue;

		leastChar[charBuffer]++;
	}

	switch (g_iOrignalSet) {
		case 1: {
			charBuffer = 7;
			int surChar = leastChar[7];
			for (i = 7; i >= 0; i--) {
				if (leastChar[i] < surChar) {
					surChar = leastChar[i];
					charBuffer = i;
				}
			}
		}

		case 2: {
			charBuffer = 0;
			int surChar = leastChar[0];
			for (i = 0; i <= 7; i++) {
				if (leastChar[i] < surChar) {
					surChar = leastChar[i];
					charBuffer = i;
				}
			}
		}
	}

	return charBuffer;
}
/*
void StringToLowerCase(char[] szInput) {
	int iIterator;
	while (szInput[iIterator] != EOS) {
		szInput[iIterator] = CharToLower(szInput[iIterator]);
		++iIterator;
	}
}*/

void SetCharacterInfo(int client, int character, int modelIndex) {
	if (g_iTabHUDBar && g_iTabHUDBar & g_iOrignalSet)
		character = ConvertToInternalCharacter(character);

	SetEntProp(client, Prop_Send, "m_survivorCharacter", character);
	SetEntityModel(client, g_sSurvivorModels[modelIndex]);

	if (IsFakeClient(client)) {
		g_bHideNameChange = true;
		SetClientInfo(client, "name", g_sSurvivorNames[modelIndex]);
		g_bHideNameChange = false;
	}

	ReEquipWeapons(client);
}

// https://github.com/LuxLuma/Left-4-fix/blob/master/left%204%20fix/Defib_Fix/scripting/Defib_Fix.sp
int ConvertToInternalCharacter(int SurvivorCharacterType) {
	switch (SurvivorCharacterType) {
		case 4:
			return 0;

		case 5:
			return 1;

		case 6:
			return 3;

		case 7:
			return 2;

		case 9:
			return 8;
	}

	return SurvivorCharacterType;
}

void RemovePlayerSlot(int client, int weapon) {
	RemovePlayerItem(client, weapon);
	RemoveEntity(weapon);
}

void ReEquipWeapons(int client) {
	if (!IsPlayerAlive(client))
		return;

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (weapon <= MaxClients)
		return;

	char active[32];
	GetEntityClassname(weapon, active, sizeof active);

	char cls[32];
	for (int i; i <= 1; i++) {
		weapon = GetPlayerWeaponSlot(client, i);
		if (weapon <= MaxClients)
			continue;

		switch (i) {
			case 0: {
				GetEntityClassname(weapon, cls, sizeof cls);
	
				int clip1 = GetEntProp(weapon, Prop_Send, "m_iClip1");
				int iAmmo = GetOrSetPlayerAmmo(client, weapon);
				int iUpgrade = GetEntProp(weapon, Prop_Send, "m_upgradeBitVec");
				int iUpgradeAmmo = GetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded");
				int weaponSkin = GetEntProp(weapon, Prop_Send, "m_nSkin");

				RemovePlayerSlot(client, weapon);
				CheatCommand(client, "give", cls);

				weapon = GetPlayerWeaponSlot(client, 0);
				if (weapon > MaxClients) {
					SetEntProp(weapon, Prop_Send, "m_iClip1", clip1);
					GetOrSetPlayerAmmo(client, weapon, iAmmo);

					if (iUpgrade > 0)
						SetEntProp(weapon, Prop_Send, "m_upgradeBitVec", iUpgrade);

					if (iUpgradeAmmo > 0)
						SetEntProp(weapon, Prop_Send, "m_nUpgradedPrimaryAmmoLoaded", iUpgradeAmmo);
			
					if (weaponSkin > 0)
						SetEntProp(weapon, Prop_Send, "m_nSkin", weaponSkin);
				}
			}

			case 1: {
				int clip1 = -1;
				int weaponSkin;
				bool dualWielding;

				GetEntityClassname(weapon, cls, sizeof cls);

				if (strcmp(cls[7], "melee") == 0)
					GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", cls, sizeof cls);
				else {
					if (strncmp(cls[7], "pistol", 6) == 0 || strcmp(cls[7], "chainsaw") == 0)
						clip1 = GetEntProp(weapon, Prop_Send, "m_iClip1");

					dualWielding = strcmp(cls[7], "pistol") == 0 && GetEntProp(weapon, Prop_Send, "m_isDualWielding");
				}

				weaponSkin = GetEntProp(weapon, Prop_Send, "m_nSkin");

				RemovePlayerSlot(client, weapon);

				switch (dualWielding) {
					case true: {
						CheatCommand(client, "give", "weapon_pistol");
						CheatCommand(client, "give", "weapon_pistol");
					}

					case false:
						CheatCommand(client, "give", cls);
				}

				weapon = GetPlayerWeaponSlot(client, 1);
				if (weapon > MaxClients) {
					if (clip1 != -1)
						SetEntProp(weapon, Prop_Send, "m_iClip1", clip1);
				
					if (weaponSkin > 0)
						SetEntProp(weapon, Prop_Send, "m_nSkin", weaponSkin);
				}
			}
		}
	}

	FakeClientCommand(client, "use %s", active);
}

void CheatCommand(int client, const char[] sCommand, const char[] sArguments = "") {
	static int flagBits, cmdFlags;
	flagBits = GetUserFlagBits(client);
	cmdFlags = GetCommandFlags(sCommand);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	SetCommandFlags(sCommand, cmdFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCommand, sArguments);
	SetUserFlagBits(client, flagBits);
	SetCommandFlags(sCommand, cmdFlags);
}

int GetOrSetPlayerAmmo(int client, int weapon, int iAmmo = -1) {
	int m_iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
	if (m_iPrimaryAmmoType != -1) {
		if (iAmmo != -1)
			SetEntProp(client, Prop_Send, "m_iAmmo", iAmmo, _, m_iPrimaryAmmoType);
		else
			return GetEntProp(client, Prop_Send, "m_iAmmo", _, m_iPrimaryAmmoType);
	}
	return 0;
}

void InitGameData() {
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(sPath))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	//[L4D2] Real Zoey Unlock (1.2) (https://forums.alliedmods.net/showthread.php?p=2598539)
	int iOffset = GameConfGetOffset(hGameData, "ZoeyUnlock_Offset");
	if (iOffset != -1) {
		Address pZoeyUnlock = GameConfGetAddress(hGameData, "ZoeyUnlock");
		if (!pZoeyUnlock)
			SetFailState("Error finding the 'ZoeyUnlock' signature.");

		int iByte = LoadFromAddress(pZoeyUnlock + view_as<Address>(iOffset), NumberType_Int8);
		if (iByte == 0xE8) {
			for (int i; i < 5; i++)
				StoreToAddress(pZoeyUnlock + view_as<Address>(iOffset + i), 0x90, NumberType_Int8);
		}
		else if (iByte != 0x90)
			SetFailState("Error: the 'ZoeyUnlock_Offset' is incorrect.");
	}

	g_pSavedPlayersCount = hGameData.GetAddress("SavedPlayersCount");
	if (!g_pSavedPlayersCount)
		SetFailState("Failed to find address: \"SavedPlayersCount\"");

	g_pSavedSurvivorBotsCount = hGameData.GetAddress("SavedSurvivorBotsCount");
	if (!g_pSavedSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedSurvivorBotsCount\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: \"CDirector::IsInTransition\"");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CDirector_IsInTransition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::IsInTransition\"");

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "KeyValues::GetString"))
		SetFailState("Failed to find signature: \"KeyValues::GetString\"");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	if (!(g_hSDK_KeyValues_GetString = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"KeyValues::GetString\"");

	delete hGameData;
}