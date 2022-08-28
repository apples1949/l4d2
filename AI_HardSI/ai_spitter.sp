#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar
	g_hSpitterBhop;

bool
	g_bSpitterBhop;

public Plugin myinfo = {
	name = "AI SPITTER",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart() {
	g_hSpitterBhop = CreateConVar("ai_spitter_bhop", "1", "Flag to enable bhop facsimile on AI spitters");
	g_hSpitterBhop.AddChangeHook(vCvarChanged);
}

public void OnConfigsExecuted() {
	vGetCvars();
}

void vCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars();
}

void vGetCvars() {
	g_bSpitterBhop = g_hSpitterBhop.BoolValue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3]) {
	if (!g_bSpitterBhop)
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 4 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if (bIsGrounded(client) && GetEntityMoveType(client) != MOVETYPE_LADDER && GetEntProp(client, Prop_Data, "m_nWaterLevel") < 2 && GetEntProp(client, Prop_Send, "m_hasVisibleThreats")) {
		static float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
		if (SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0)) < GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") - 10.0)
			return Plugin_Continue;
	
		if (150.0 < fNearestSurDistance(client) < 1000.0) {
			//buttons |= IN_DUCK;
			//buttons |= IN_JUMP;

			static float vAng[3];
			GetClientEyeAngles(client, vAng);
			//vBunnyHop(client, buttons, vAng);
			return aBunnyHop(client, buttons, vAng)/*Plugin_Changed*/;
		}
	}

	return Plugin_Continue;
}

bool bIsGrounded(int client) {
	int iEnt = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	return iEnt != -1 && IsValidEntity(iEnt);
	//return GetEntityFlags(client) & FL_ONGROUND != 0;
}

Action aBunnyHop(int client, int &buttons, const float vAng[3]) {
	float vFwd[3];
	float vRig[3];
	float vDir[3];
	float vVel[3];
	bool bPressed;
	if (buttons & IN_FORWARD || buttons & IN_BACK) {
		GetAngleVectors(vAng, vFwd, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vFwd, vFwd);
		ScaleVector(vFwd, buttons & IN_FORWARD ? 180.0 : -90.0);
		bPressed = true;
	}

	if (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT) {
		GetAngleVectors(vAng, NULL_VECTOR, vRig, NULL_VECTOR);
		NormalizeVector(vRig, vRig);
		ScaleVector(vRig, buttons & IN_MOVERIGHT ? 90.0 : -90.0);
		bPressed = true;
	}

	if (bPressed) {
		AddVectors(vFwd, vRig, vDir);
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		AddVectors(vVel, vDir, vVel);
		if (!bWontFall(client, vVel))
			return Plugin_Continue;

		buttons |= IN_DUCK;
		buttons |= IN_JUMP;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

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
	static float vPlane[3];

	bDidHit = false;
	vPos[2] += 10.0;
	vEnd[2] += 10.0;
	hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	if (TR_DidHit(hTrace)) {
		bDidHit = true;
		TR_GetEndPosition(vVec, hTrace);
		if (GetVectorDistance(vPos, vVec) < GetVectorLength(vVel)) {
			TR_GetPlaneNormal(hTrace, vPlane);
			if (RadToDeg(ArcCosine(GetVectorDotProduct(vVel, vPlane))) > 135.0) {
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
				PrintToChatAll("trigger_hurt");
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
/*
void vBunnyHop(int client, int &buttons, float vAng[3]) {
	if (buttons & IN_FORWARD)
		vClientPush(client, vAng, 120.0);
		
	if (buttons & IN_BACK) {
		vAng[1] += 180.0;
		vClientPush(client, vAng, 60.0);
	}
	
	if (buttons & IN_MOVELEFT) {
		vAng[1] += 90.0;
		vClientPush(client, vAng, 60.0);
	}

	if (buttons & IN_MOVERIGHT) {
		vAng[1] -= 90.0;
		vClientPush(client, vAng, 60.0);
	}
}

void vClientPush(int client, const float vAng[3], float fForce) {
	static float vVec[3];
	GetAngleVectors(vAng, vVec, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vVec, vVec);
	ScaleVector(vVec, fForce);

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	AddVectors(vVel, vVec, vVel);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
}*/

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