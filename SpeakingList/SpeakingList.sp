#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <clientprefs>

Cookie
	g_ckSpeakingList;

ConVar
	g_hDefault,
	g_hTeamfilter;

bool
	g_bLateLoad,
	g_bTeamfilter,
	g_bIsSpeaking[MAXPLAYERS + 1];

int
	g_iDefault,
	g_iSpeakingList[MAXPLAYERS + 1];

char
	g_sSpeakingPlayers[3][MAX_NAME_LENGTH * (MAXPLAYERS + 1)];

public Plugin myinfo =
{
	name = "SpeakingList",
	author = "Accelerator",
	description = "Voice Announce. Print To Center Message who Speaking. With cookies",
	version = "1.6",
	url = "http://core-ss.org"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_ckSpeakingList = new Cookie("speaking-list", "SpeakList", CookieAccess_Protected);

	g_hDefault = CreateConVar("speaklist_default", "1", "Default setting for Speak List [1-Enable/0-Disable]");
	g_hTeamfilter = CreateConVar("speaklist_teamfilter", "0", "Use Team Filter for Speak List [1-Enable/0-Disable]");

	g_hDefault.AddChangeHook(vConVarChanged);
	g_hTeamfilter.AddChangeHook(vConVarChanged);
	
	RegConsoleCmd("sm_speaklist", cmdSpeakList);

	if (g_bLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i))
				OnClientCookiesCached(i);
		}
	}

	CreateTimer(0.7, tmrUpdateSpeaking, _, TIMER_REPEAT);
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
	g_iDefault = g_hDefault.IntValue;
	g_bTeamfilter = g_hTeamfilter.BoolValue;
}

Action cmdSpeakList(int client, int args)
{
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;
	
	if (g_iSpeakingList[client]) {
		g_iSpeakingList[client] = 0;
		if (AreClientCookiesCached(client))
			g_ckSpeakingList.Set(client, "0");

		PrintToChat(client, "语音列表已关闭.");
	}
	else {
		g_iSpeakingList[client] = 1;
		if (AreClientCookiesCached(client))
			g_ckSpeakingList.Set(client, "1");

		PrintToChat(client, "语音列表已启用.");
	}

	return Plugin_Handled;
}

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client))
		return;

	g_bIsSpeaking[client] = false;

	char cookie[2];
	g_ckSpeakingList.Get(client, cookie, sizeof cookie);
	g_iSpeakingList[client] = !cookie[0] ? g_iDefault : StringToInt(cookie);
}

public void OnClientDisconnect(int client)
{
	g_iSpeakingList[client] = 0;
	g_bIsSpeaking[client] = false;
}

public void OnClientSpeaking(int client)
{
	g_bIsSpeaking[client] = true;
}

public void OnClientSpeakingEnd(int client)
{
	g_bIsSpeaking[client] = false;
}

Action tmrUpdateSpeaking(Handle timer)
{
	static int i;
	static int iTeam;
	static int iCount;
	static int iCountTeam[3];

	iCount = 0;
	iCountTeam[0] = 0;
	iCountTeam[1] = 0;
	iCountTeam[2] = 0;
	g_sSpeakingPlayers[0][0] = '\0';
	g_sSpeakingPlayers[1][0] = '\0';
	g_sSpeakingPlayers[2][0] = '\0';

	for (i = 1; i <= MaxClients; i++) {
		if (!g_bIsSpeaking[i] || !IsClientInGame(i) || IsFakeClient(i) || GetClientListeningFlags(i) & VOICE_MUTED)
			continue;

		iTeam = GetClientTeam(i) - 1;
		if (iTeam < 0 || iTeam > 2)
			continue;
				
		Format(g_sSpeakingPlayers[iTeam], sizeof g_sSpeakingPlayers[], "%s\n%N", g_sSpeakingPlayers[iTeam], i);

		iCount++;
		iCountTeam[iTeam]++;
	}

	if (!iCount)
		return Plugin_Continue;

	for (i = 1; i <= MaxClients; i++) {
		if (!g_iSpeakingList[i] || !IsClientInGame(i))
			continue;
	
		if (g_bTeamfilter) {
			iTeam = GetClientTeam(i) - 1;
			if (iTeam < 0 || iTeam > 2)
				continue;

			if (iCountTeam[iTeam] > 0)
				PrintCenterText(i, "语音中:%s", g_sSpeakingPlayers[iTeam]);
		}
		else
			PrintCenterText(i, "语音中:%s%s%s", g_sSpeakingPlayers[0], g_sSpeakingPlayers[1], g_sSpeakingPlayers[2]);
	}

	return Plugin_Continue;
}