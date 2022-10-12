#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_NAME				"Skip Tank Taunt"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.5"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?t=336707"

ConVar
	g_cvAnimationPlaybackRate;

float
	g_fAnimationPlaybackRate;

bool
	g_bLateLoad,
	g_bTankClimb[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	g_cvAnimationPlaybackRate = CreateConVar("tank_animation_playbackrate", "5.0", "Obstacle animation playback rate", _, true, 0.0);
	g_cvAnimationPlaybackRate.AddChangeHook(CvarChanged);
	AutoExecConfig(true);

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);

	if (g_bLateLoad) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8) {
					AnimHookEnable(i, OnTankAnimPre);
					if (IsFakeClient(i))
						SDKHook(i, SDKHook_PreThink, OnPreThink);
				}
			}
		}
	}
}

public void OnConfigsExecuted() {
	GetCvars();
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	GetCvars();
}

void GetCvars() {
	g_fAnimationPlaybackRate = g_cvAnimationPlaybackRate.FloatValue;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			g_bTankClimb[i] = false;
			AnimHookDisable(i, OnTankAnimPre);
			SDKUnhook(i, SDKHook_PreThink, OnPreThink);
		}
	}
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client)) {
		g_bTankClimb[client] = false;
		AnimHookDisable(client, OnTankAnimPre);
		AnimHookEnable(client, OnTankAnimPre);
		if (IsFakeClient(client)) {
			SDKUnhook(client, SDKHook_PreThink, OnPreThink);
			SDKHook(client, SDKHook_PreThink, OnPreThink);
		}
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client) {
		g_bTankClimb[client] = false;
		AnimHookDisable(client, OnTankAnimPre);
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	if (event.GetInt("oldteam") != 3)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client) {
		g_bTankClimb[client] = false;
		AnimHookDisable(client, OnTankAnimPre);
		SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	}
}

/**
* From left4dhooks.l4d2.cfg
* L4D2_ACT_TERROR_CLIMB_24_FROM_STAND	718
* L4D2_ACT_TERROR_CLIMB_36_FROM_STAND	719
* L4D2_ACT_TERROR_CLIMB_38_FROM_STAND	720
* L4D2_ACT_TERROR_CLIMB_48_FROM_STAND	721
* L4D2_ACT_TERROR_CLIMB_50_FROM_STAND	722
* L4D2_ACT_TERROR_CLIMB_60_FROM_STAND	723
* L4D2_ACT_TERROR_CLIMB_70_FROM_STAND	724
* L4D2_ACT_TERROR_CLIMB_72_FROM_STAND	725
* L4D2_ACT_TERROR_CLIMB_84_FROM_STAND	726
* L4D2_ACT_TERROR_CLIMB_96_FROM_STAND	727
* L4D2_ACT_TERROR_CLIMB_108_FROM_STAND	728
* L4D2_ACT_TERROR_CLIMB_115_FROM_STAND	729
* L4D2_ACT_TERROR_CLIMB_120_FROM_STAND	730
* L4D2_ACT_TERROR_CLIMB_130_FROM_STAND	731
* L4D2_ACT_TERROR_CLIMB_132_FROM_STAND	732
* L4D2_ACT_TERROR_CLIMB_144_FROM_STAND	733
* L4D2_ACT_TERROR_CLIMB_150_FROM_STAND	734
* L4D2_ACT_TERROR_CLIMB_156_FROM_STAND	735
* L4D2_ACT_TERROR_CLIMB_166_FROM_STAND	736
* L4D2_ACT_TERROR_CLIMB_168_FROM_STAND	737
**/
void OnPreThink(int client) {
	switch (GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
		case true: {
			if (g_bTankClimb[client]) {
				SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", g_fAnimationPlaybackRate);
			}
			/*switch (GetEntProp(client, Prop_Send, "m_nSequence")) {
				case 16, 17, 18, 19, 20, 21, 22, 23:
					SetEntPropFloat(client, Prop_Send, "m_flPlaybackRate", g_fAnimationPlaybackRate);
			}*/
		}

		case false:
			SDKUnhook(client, SDKHook_PreThink, OnPreThink);
	}
}

/**
* From left4dhooks.l4d2.cfg
* L4D2_ACT_TERROR_HULK_VICTORY		792
* L4D2_ACT_TERROR_HULK_VICTORY_B	793
* L4D2_ACT_TERROR_RAGE_AT_ENEMY		794
* L4D2_ACT_TERROR_RAGE_AT_KNOCKDOWN	795
**/
Action OnTankAnimPre(int client, int &anim) {
	g_bTankClimb[client] = 718 <= anim <= 737;

	switch (anim) {
		case L4D2_ACT_TERROR_HULK_VICTORY, 
		L4D2_ACT_TERROR_HULK_VICTORY_B, 
		L4D2_ACT_TERROR_RAGE_AT_ENEMY, 
		L4D2_ACT_TERROR_RAGE_AT_KNOCKDOWN: {
			if (GetClientTeam(client) == 3 && IsPlayerAlive(client) && GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
				anim = 0;
				SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0);
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}
