#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar
	g_hBoomerBhop,
	g_hVomitRange;

bool
	g_bBoomerBhop;

float
	g_fVomitRange;

public Plugin myinfo = {
	name = "AI BOOMER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart() {
	g_hBoomerBhop = CreateConVar("ai_boomer_bhop", "1", "Flag to enable bhop facsimile on AI boomers");
	g_hVomitRange = FindConVar("z_vomit_range");
	
	g_hBoomerBhop.AddChangeHook(vCvarChanged);
	g_hVomitRange.AddChangeHook(vCvarChanged);

	FindConVar("z_vomit_fatigue").SetInt(0);
	FindConVar("z_boomer_near_dist").SetInt(1);

	HookEvent("ability_use", Event_AbilityUse);
}

public void OnPluginEnd() {
	FindConVar("z_vomit_fatigue").RestoreDefault();
	FindConVar("z_boomer_near_dist").RestoreDefault();
}

public void OnConfigsExecuted() {
	vGetCvars();
}

void vCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars();
}

void vGetCvars() {
	g_bBoomerBhop = g_hBoomerBhop.BoolValue;
	g_fVomitRange = g_hVomitRange.FloatValue;
}

void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsFakeClient(client))
		return;

	static char sUse[16];
	event.GetString("ability", sUse, sizeof sUse);
	if (strcmp(sUse, "ability_vomit") == 0)
		vBoomer_OnVomit(client);
}

public Action OnPlayerRunCmd(int client, int &buttons) {
	if (!g_bBoomerBhop)
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 2 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if (GetEntityFlags(client) & FL_ONGROUND && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") || bTargetSur(client))) {
		static float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		if (SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0)) <= 0.5 * GetEntPropFloat(client, Prop_Send, "m_flMaxspeed"))
			return Plugin_Continue;
	
		if (0.50 * g_fVomitRange < fNearestSurDistance(client) < 1000.0) {
			static float vAng[3];
			GetClientEyeAngles(client, vAng);
			return aBunnyHop(client, buttons, vAng);
		}
	}

	return Plugin_Continue;
}

bool bTargetSur(int client) {
	return bIsAliveSur(GetClientAimTarget(client, true));
}

Action aBunnyHop(int client, int &buttons, const float vAng[3]) {
	static float vVec[3];
	static Action aResult;

	aResult = Plugin_Continue;
	if (buttons & IN_FORWARD || buttons & IN_BACK) {
		GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
		if (bClientPush(client, buttons, vVec, buttons & IN_FORWARD ? 180.0 : -90.0))
			aResult = Plugin_Changed;
	}

	if (buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT) {
		GetAngleVectors(vAng, NULL_VECTOR, vVec, NULL_VECTOR);
		if (bClientPush(client, buttons, vVec, buttons & IN_MOVELEFT ? -90.0 : 90.0))
			aResult = Plugin_Changed;
	}

	return aResult;
}

bool bClientPush(int client, int &buttons, float vVec[3], float fForce) {
	NormalizeVector(vVec, vVec);
	ScaleVector(vVec, fForce);

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	AddVectors(vVel, vVec, vVel);
	if (bWontFall(client, vVel)) {
		buttons |= IN_DUCK;
		buttons |= IN_JUMP;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
		return true;
	}

	return false;
}

#define OBSTACLE_HEIGHT 18.0
bool bWontFall(int client, const float vVel[3]) {
	static float vPos[3];
	static float vEnd[3];
	GetClientAbsOrigin(client, vPos);
	AddVectors(vPos, vVel, vEnd);

	static float vMins[3];
	static float vMaxs[3];
	GetClientMins(client, vMins);
	GetClientMaxs(client, vMaxs);

	static bool bDidHit;
	static Handle hTrace;
	static float vVec[3];

	bDidHit = false;
	vPos[2] += OBSTACLE_HEIGHT;
	vEnd[2] += OBSTACLE_HEIGHT;
	hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	vEnd[2] -= 2.0 * OBSTACLE_HEIGHT;
	if (TR_DidHit(hTrace)) {
		bDidHit = true;
		TR_GetPlaneNormal(hTrace, vVec);
		if (RadToDeg(ArcCosine(GetVectorDotProduct(vVel, vVec))) > 150.0) {
			TR_GetEndPosition(vVec, hTrace);
			if (GetVectorDistance(vPos, vVec) < 64.0) {
				delete hTrace;
				return false;
			}
		}
	}

	delete hTrace;
	if (!bDidHit)
		vVec = vEnd;

	static float vDown[3];
	vDown[0] = vVec[0];
	vDown[1] = vVec[1];
	vDown[2] = vVec[2] - 100000.0;

	hTrace = TR_TraceHullFilterEx(vVec, vDown, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	if (TR_DidHit(hTrace)) {
		TR_GetEndPosition(vEnd, hTrace);
		if (vVec[2] - vEnd[2] > 128.0) {
			delete hTrace;
			return false;
		}

		static int iEnt;
		if ((iEnt = TR_GetEntityIndex(hTrace)) > MaxClients) {
			static char cls[13];
			GetEdictClassname(iEnt, cls, sizeof cls);
			if (strcmp(cls, "trigger_hurt") == 0) {
				delete hTrace;
				return false;
			}
		}
		delete hTrace;
		return true;
	}

	delete hTrace;
	return false;
}

bool bTraceEntityFilter(int entity, int contentsMask) {
	if (entity <= MaxClients)
		return false;

	static char cls[9];
	GetEntityClassname(entity, cls, sizeof cls);
	if ((cls[0] == 'i' && strcmp(cls[1], "nfected") == 0) || (cls[0] == 'w' && strcmp(cls[1], "itch") == 0))
		return false;

	return true;
}

float fNearestSurDistance(int client) {
	static int i;
	static int iCount;
	static float vPos[3];
	static float vTarg[3];
	static float fDists[MAXPLAYERS + 1];
	
	iCount = 0;
	GetClientAbsOrigin(client, vPos);
	for (i = 1; i <= MaxClients; i++) {
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
			GetClientAbsOrigin(i, vTarg);
			fDists[iCount++] = GetVectorDistance(vPos, vTarg);
		}
	}

	if (!iCount)
		return -1.0;

	SortFloats(fDists, iCount, Sort_Ascending);
	return fDists[0];
}

#define CROUCHING_EYE 44.0
#define PLAYER_HEIGHT 72.0
void vBoomer_OnVomit(int client) {
	static int iTarget;
	iTarget = GetClientAimTarget(client, true);
	if (!bIsAliveSur(iTarget))
		iTarget = iGetClosestSur(client, iTarget, g_fVomitRange);

	if (iTarget == -1)
		return;

	static float vPos[3];
	static float vTarg[3];
	static float vVelocity[3];
	GetClientAbsOrigin(client, vPos);
	GetClientAbsOrigin(iTarget, vTarg);
	MakeVectorFromPoints(vPos, vTarg, vVelocity);

	static float vLength;
	vLength = GetVectorLength(vVelocity);
	if (vLength < g_fVomitRange)
		vLength = 0.5 * g_fVomitRange;
	else {
		float fHeight = vTarg[2] - vPos[2];
		if (fHeight > PLAYER_HEIGHT)
			vLength = vLength - 0.5 * g_fVomitRange + fHeight;
	}

	static float vAngles[3];
	GetVectorAngles(vVelocity, vAngles);
	NormalizeVector(vVelocity, vVelocity);
	ScaleVector(vVelocity, vLength);
	TeleportEntity(client, NULL_VECTOR, vAngles, vVelocity);
}

bool bIsAliveSur(int client) {
	return 0 < client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

int iGetClosestSur(int client, int iExclude = -1, float fDistance) {
	static int i;
	static int iCount;
	static float fDist;
	static float vPos[3];
	static float vTarg[3];
	static int iTargets[MAXPLAYERS + 1];
	
	iCount = 0;
	GetClientEyePosition(client, vPos);
	iCount = GetClientsInRange(vPos, RangeType_Visibility, iTargets, MAXPLAYERS);
	
	if (!iCount)
		return -1;
			
	static int iTarget;
	static ArrayList aTargets;
	aTargets = new ArrayList(2);
	for (i = 0; i < iCount; i++) {
		iTarget = iTargets[i];
		if (iTarget && iTarget != iExclude && GetClientTeam(iTarget) == 2 && IsPlayerAlive(iTarget) && !GetEntProp(iTarget, Prop_Send, "m_isIncapacitated")) {
			GetClientAbsOrigin(iTarget, vTarg);
			fDist = GetVectorDistance(vPos, vTarg);
			if (fDist < fDistance)
				aTargets.Set(aTargets.Push(fDist), iTarget, 1);
		}
	}

	if (!aTargets.Length) {
		delete aTargets;
		return -1;
	}

	aTargets.Sort(Sort_Ascending, Sort_Float);
	iTarget = aTargets.Get(0, 1);
	delete aTargets;
	return iTarget;
}