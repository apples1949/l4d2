#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define UNRESERVE_VERSION "2.0.0"

ConVar
	g_hUnreserve,
	g_hAutoLobby;

bool
	g_bUnreserved;

public Plugin myinfo = {
	name = "L4D 1/2 Remove Lobby Reservation",
	author = "Downtown1, Anime4000",
	description = "Removes lobby reservation when server is full",
	version = UNRESERVE_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=87759"
}

public void OnPluginStart() {
	CreateConVar("l4d_unreserve_version", UNRESERVE_VERSION, "Version of the Lobby Unreserve plugin.", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_hUnreserve = CreateConVar("l4d_unreserve_full", "1", "Automatically unreserve server after a full lobby joins", FCVAR_SPONLY|FCVAR_NOTIFY);
	g_hAutoLobby = CreateConVar("l4d_autolobby", "1", "Automatically adjust sv_allow_lobby_connect_only. When lobby full it set to 0, when server empty it set to 1", FCVAR_SPONLY|FCVAR_NOTIFY);
	
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	RegAdminCmd("sm_unreserve", cmdUnreserve, ADMFLAG_BAN, "sm_unreserve - manually force removes the lobby reservation");
}

Action cmdUnreserve(int client, int args) {
	if (g_bUnreserved)
		ReplyToCommand(client, "[UL] Server has already been unreserved.");
	else {
		L4D_LobbyUnreserve();
		g_bUnreserved = true;
		SetAllowLobby(0);
		ReplyToCommand(client, "[UL] Lobby reservation has been removed.");
	}

	return Plugin_Handled;
}

public void OnClientPutInServer(int client) {
	if (!g_bUnreserved && g_hUnreserve.BoolValue && IsServerLobbyFull()) {
		if (FindConVar("sv_hosting_lobby").IntValue > 0) {
			LogMessage("[UL] A full lobby has connected, automatically unreserving the server.");
			g_bUnreserved = true;
			L4D_LobbyUnreserve();
			SetAllowLobby(0);
		}
	}
}

//OnClientDisconnect will fired when changing map, issued by gH0sTy at http://docs.sourcemod.net/api/index.php?fastload=show&id=390&
void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || IsFakeClient(client) || RealClientsInServer(client))
		return;

	PrintToServer("[UL] No human want to play in this server. :(");
	g_bUnreserved = false;
	SetAllowLobby(1);
}

void SetAllowLobby(int value) {
	if (g_hAutoLobby.BoolValue)
		FindConVar("sv_allow_lobby_connect_only").IntValue = value;
}

bool IsServerLobbyFull() {
	return GetHumanCount() >= LoadFromAddress(L4D_GetPointer(POINTER_SERVER) + view_as<Address>(380), NumberType_Int32);
}

int GetHumanCount() {
	int humans;
	for (int i = 1; i < MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i))
			humans++;
	}
	return humans;
}

bool RealClientsInServer(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientConnected(i) && !IsFakeClient(i))
			return true;
	}
	return false;
}