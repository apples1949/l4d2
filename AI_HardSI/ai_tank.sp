#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define SPEEDBOOST	90.0

ConVar
	g_hTankBhop,
	g_hTankAttackRange,
	g_hTankThrowForce,
	g_hAimOffsetSensitivityTank;

bool
	g_bTankBhop;

float
	g_fTankAttackRange,
	g_fTankThrowForce,
	g_fAimOffsetSensitivityTank;

public Plugin myinfo = {
	name = "AI TANK",
	author = "Breezy",
	description = "Improves the AI behaviour of special infected",
	version = "1.0",
	url = "github.com/breezyplease"
};

public void OnPluginStart() {
	g_hTankBhop = CreateConVar("ai_tank_bhop", "1", "Flag to enable bhop facsimile on AI tanks");
	g_hAimOffsetSensitivityTank = CreateConVar("ai_aim_offset_sensitivity_tank", "22.5", "If the tank has a target, it will not straight throw if the target's aim on the horizontal axis is within this radius", _, true, 0.0, true, 180.0);
	g_hTankAttackRange = FindConVar("tank_attack_range");
	g_hTankThrowForce = FindConVar("z_tank_throw_force");

	g_hTankBhop.AddChangeHook(vCvarChanged);
	g_hTankAttackRange.AddChangeHook(vCvarChanged);
	g_hTankThrowForce.AddChangeHook(vCvarChanged);
	g_hAimOffsetSensitivityTank.AddChangeHook(vCvarChanged);
}

public void OnConfigsExecuted() {
	vGetCvars();
}

void vCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	vGetCvars();
}

void vGetCvars() {
	g_bTankBhop = g_hTankBhop.BoolValue;
	g_fTankAttackRange = g_hTankAttackRange.FloatValue;
	g_fTankThrowForce = g_hTankThrowForce.FloatValue;
	g_fAimOffsetSensitivityTank = g_hAimOffsetSensitivityTank.FloatValue;
}

int g_iCurTarget[MAXPLAYERS + 1];
public Action L4D2_OnChooseVictim(int specialInfected, int &curTarget) {
	g_iCurTarget[specialInfected] = curTarget;
	return Plugin_Continue;
}

float g_fRunTopSpeed[MAXPLAYERS + 1];
public Action L4D_OnGetRunTopSpeed(int target, float &retVal) {
	g_fRunTopSpeed[target] = retVal;
	return Plugin_Continue;
}

bool g_bModify[MAXPLAYERS + 1];
public Action OnPlayerRunCmd(int client, int &buttons) {
	if (!g_bTankBhop)
		return Plugin_Continue;

	if (!IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client) || GetEntProp(client, Prop_Send, "m_zombieClass") != 8 || GetEntProp(client, Prop_Send, "m_isGhost") == 1)
		return Plugin_Continue;

	if (GetEntityMoveType(client) == MOVETYPE_LADDER || GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1 || !GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))
		return Plugin_Continue;

	static float vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);

	static float fSpeed;
	fSpeed = SquareRoot(Pow(vVel[0], 2.0) + Pow(vVel[1], 2.0));
	if (fSpeed <= 0.5 * g_fRunTopSpeed[client])
		return Plugin_Continue;

	static float vAng[3];
	if (GetEntityFlags(client) & FL_ONGROUND) {
		g_bModify[client] = false;

		if (g_fTankAttackRange < fNearestSurDistance(client) < 1000.0) {
			GetClientEyeAngles(client, vAng);
			return aBunnyHop(client, buttons, vAng);
		}
	}
	else {
		if (g_bModify[client] || fSpeed < g_fRunTopSpeed[client] + SPEEDBOOST)
			return Plugin_Continue;

		static int iTarget;
		iTarget = GetClientAimTarget(client, true);
		if (!bIsAliveSur(iTarget))
			iTarget = g_iCurTarget[client];

		if (!bIsAliveSur(iTarget))
			return Plugin_Continue;

		static float vPos[3];
		static float vTarg[3];
		GetClientAbsOrigin(client, vPos);
		GetClientAbsOrigin(iTarget, vTarg);
		fSpeed = GetVectorDistance(vPos, vTarg);
		if (fSpeed < g_fTankAttackRange || fSpeed > 500.0)
			return Plugin_Continue;

		GetVectorAngles(vVel, vAng);
		vVel = vAng;
		vAng[0] = vAng[2] = 0.0;
		GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
		NormalizeVector(vAng, vAng);

		static float vDir[2][3];
		vDir[0] = vPos;
		vDir[1] = vTarg;
		vPos[2] = vTarg[2] = 0.0;
		MakeVectorFromPoints(vPos, vTarg, vPos);
		NormalizeVector(vPos, vPos);
		if (RadToDeg(ArcCosine(GetVectorDotProduct(vAng, vPos))) < 90.0)
			return Plugin_Continue;

		MakeVectorFromPoints(vDir[0], vDir[1], vDir[0]);
		TeleportEntity(client, NULL_VECTOR, vVel, vDir[0]);
		g_bModify[client] = true;
	}
	
	return Plugin_Continue;
}

Action aBunnyHop(int client, int &buttons, float vAng[3]) {
	Action aResult = Plugin_Continue;

	if (buttons & IN_FORWARD || buttons & IN_BACK) {
		GetAngleVectors(vAng, vAng, NULL_VECTOR, NULL_VECTOR);
		if (bClientPush(client, buttons, vAng, buttons & IN_FORWARD ? 2.0 * SPEEDBOOST : -SPEEDBOOST))
			aResult = Plugin_Changed;
	}

	if (buttons & IN_MOVELEFT || buttons & IN_MOVERIGHT) {
		GetAngleVectors(vAng, NULL_VECTOR, vAng, NULL_VECTOR);
		if (bClientPush(client, buttons, vAng, buttons & IN_MOVELEFT ? -SPEEDBOOST : SPEEDBOOST))
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
	if (!bWontFall(client, vVel))
		return false;

	buttons |= IN_DUCK;
	buttons |= IN_JUMP;
	SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	return true;
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

	bDidHit = false;
	vPos[2] += OBSTACLE_HEIGHT;
	vEnd[2] += OBSTACLE_HEIGHT;
	hTrace = TR_TraceHullFilterEx(vPos, vEnd, vMins, vMaxs, MASK_PLAYERSOLID_BRUSHONLY, bTraceEntityFilter);
	//vEnd[2] -= OBSTACLE_HEIGHT;

	static float vVec[3];
	if (TR_DidHit(hTrace)) {
		bDidHit = true;
		TR_GetPlaneNormal(hTrace, vVec);
		if (RadToDeg(ArcCosine(GetVectorDotProduct(vVel, vVec))) > 150.0) {
			TR_GetEndPosition(vVec, hTrace);
			if (33.0 < GetVectorDistance(vPos, vVec) < 64.0) {
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
		if (vVec[2] - vEnd[2] > 120.0) {
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
	return true;
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

public Action L4D2_OnSelectTankAttack(int client, int &sequence) {
	if (sequence != 50 || !IsFakeClient(client))
		return Plugin_Continue;

	sequence = GetRandomInt(0, 1) ? 49 : 51;
	return Plugin_Handled;
}

#define PLAYER_HEIGHT 72.0
public Action L4D_TankRock_OnRelease(int tank, int rock, float vecPos[3], float vecAng[3], float vecVel[3], float vecRot[3]) {
	if (rock <= MaxClients || !IsValidEntity(rock))
		return Plugin_Continue;

	if (tank < 1 || tank > MaxClients || !IsClientInGame(tank)|| GetClientTeam(tank) != 3 || GetEntProp(tank, Prop_Send, "m_zombieClass") != 8)
		return Plugin_Continue;

	if (!IsFakeClient(tank) && (!CheckCommandAccess(tank, "", ADMFLAG_ROOT) || GetClientButtons(tank) & IN_SPEED == 0))
		return Plugin_Continue;

	static int iTarget;
	iTarget = GetClientAimTarget(tank, true);
	if (bIsAliveSur(iTarget) && !bIsIncapacitated(iTarget) && !bIsPinned(iTarget) && !bHitWall(tank, rock, iTarget) && !bWithinViewAngle(tank, iTarget, g_fAimOffsetSensitivityTank))
		return Plugin_Continue;
	
	iTarget = iGetClosestSur(tank, iTarget, rock, 2.0 * g_fTankThrowForce);
	if (iTarget == -1)
		return Plugin_Continue;

	static float vRock[3];
	static float vTarg[3];
	static float vVectors[3];
	GetClientAbsOrigin(iTarget, vTarg);
	GetClientAbsOrigin(tank, vRock);
	float fDelta = GetVectorDistance(vRock, vTarg) / g_fTankThrowForce * PLAYER_HEIGHT;

	vTarg[2] += fDelta;
	while (fDelta < PLAYER_HEIGHT) {
		if (!bHitWall(tank, rock, -1, vTarg))
			break;

		fDelta += 10.0;
		vTarg[2] += 10.0;
	}

	fDelta = vTarg[2] - vRock[2];
	if (fDelta > PLAYER_HEIGHT)
		vTarg[2] += fDelta / PLAYER_HEIGHT * 10.0;

	GetClientEyePosition(tank, vRock);
	MakeVectorFromPoints(vRock, vTarg, vVectors);
	GetVectorAngles(vVectors, vTarg);
	vecAng = vTarg;

	static float vLength;
	vLength = GetVectorLength(vVectors);
	vLength = vLength > g_fTankThrowForce ? vLength : g_fTankThrowForce;
	NormalizeVector(vVectors, vVectors);
	ScaleVector(vVectors, vLength + g_fRunTopSpeed[iTarget]);
	vecVel = vVectors;
	return Plugin_Changed;
}

bool bIsAliveSur(int client) {
	return 0 < client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool bIsIncapacitated(int client) {
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool bIsPinned(int client) {
	if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0)
		return true;
	/*if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0)
		return true;
	if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0)
		return true;*/
	return false;
}

bool bHitWall(int iTank, int iEnt, int iTarget = -1, const float vEnd[3] = NULL_VECTOR) {
	static float vSrc[3];
	static float vTarg[3];
	GetClientEyePosition(iTank, vSrc);

	if (iTarget == -1)
		vTarg = vEnd;
	else
		GetClientEyePosition(iTarget, vTarg);

	static float vMins[3];
	static float vMaxs[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", vMins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", vMaxs);

	static bool bDidHit;
	static Handle hTrace;
	hTrace = TR_TraceHullFilterEx(vSrc, vTarg, vMins, vMaxs, MASK_SOLID, bTraceEntityFilter, iEnt);
	bDidHit = TR_DidHit(hTrace);
	delete hTrace;
	return bDidHit;
}

int iGetClosestSur(int client, int iExclude = -1, int iEnt, float fDistance) {
	static int i;
	static int iCount;
	static int iIndex;
	static float fDist;
	static float vAng[3];
	static float vSrc[3];
	static float vTarg[3];
	static int iTargets[MAXPLAYERS + 1];
	
	iCount = 0;
	GetClientEyePosition(client, vSrc);
	iCount = GetClientsInRange(vSrc, RangeType_Visibility, iTargets, MAXPLAYERS);

	if (!iCount)
		return -1;

	static ArrayList aClients;
	aClients = new ArrayList(3);
	float fFOV = GetFOVDotProduct(g_fAimOffsetSensitivityTank);
	for (i = 0; i < iCount; i++) {
		if (iTargets[i] && iTargets[i] != iExclude && GetClientTeam(iTargets[i]) == 2 && IsPlayerAlive(iTargets[i]) && !bIsIncapacitated(iTargets[i]) && !bIsPinned(iTargets[i]) && !bHitWall(client, iEnt, iTargets[i])) {
			GetClientEyePosition(iTargets[i], vTarg);
			fDist = GetVectorDistance(vSrc, vTarg);
			if (fDist < fDistance) {
				iIndex = aClients.Push(fDist);
				aClients.Set(iIndex, iTargets[i], 1);

				GetClientEyeAngles(iTargets[i], vAng);
				aClients.Set(iIndex, !PointWithinViewAngle(vTarg, vSrc, vAng, fFOV) ? 0 : 1, 2);
			}
		}
	}

	if (!aClients.Length) {
		delete aClients;
		return -1;
	}

	aClients.Sort(Sort_Ascending, Sort_Float);
	iIndex = aClients.FindValue(0, 2);
	i = aClients.Get(iIndex != -1 && aClients.Get(iIndex, 0) < g_fTankThrowForce ? iIndex : GetRandomInt(0, RoundToCeil((aClients.Length - 1) * 0.8)), 1);
	delete aClients;
	return i;
}

bool bWithinViewAngle(int client, int iViewer, float fOffsetThreshold) {
	static float vSrc[3];
	static float vTarg[3];
	static float vAng[3];
	GetClientEyePosition(iViewer, vSrc);
	GetClientEyePosition(client, vTarg);
	GetClientEyeAngles(iViewer, vAng);
	return PointWithinViewAngle(vSrc, vTarg, vAng, GetFOVDotProduct(fOffsetThreshold));
}

// https://github.com/nosoop/stocksoup

/**
 * Checks if a point is in the field of view of an object.  Supports up to 180 degree FOV.
 * I forgot how the dot product stuff works.
 * 
 * Direct port of the function of the same name from the Source SDK:
 * https://github.com/ValveSoftware/source-sdk-2013/blob/beaae8ac45a2f322a792404092d4482065bef7ef/sp/src/public/mathlib/vector.h#L461-L477
 * 
 * @param vecSrcPosition	Source position of the view.
 * @param vecTargetPosition	Point to check if within view angle.
 * @param vecLookDirection	The direction to look towards.  Note that this must be a forward
 * 							angle vector.
 * @param flCosHalfFOV		The width of the forward view cone as a dot product result. For
 * 							subclasses of CBaseCombatCharacter, you can use the
 * 							`m_flFieldOfView` data property.  To manually calculate for a
 * 							desired FOV, use `GetFOVDotProduct(angle)` from math.inc.
 * @return					True if the point is within view from the source position at the
 * 							specified FOV.
 */
bool PointWithinViewAngle(const float vecSrcPosition[3], const float vecTargetPosition[3], const float vecLookDirection[3], float flCosHalfFOV) {
	static float vecDelta[3];
	SubtractVectors(vecTargetPosition, vecSrcPosition, vecDelta);
	static float cosDiff;
	cosDiff = GetVectorDotProduct(vecLookDirection, vecDelta);
	if (cosDiff < 0.0)
		return false;

	// a/sqrt(b) > c  == a^2 > b * c ^2
	return cosDiff * cosDiff >= GetVectorLength(vecDelta, true) * flCosHalfFOV * flCosHalfFOV;
}

/**
 * Calculates the width of the forward view cone as a dot product result from the given angle.
 * This manually calculates the value of CBaseCombatCharacter's `m_flFieldOfView` data property.
 *
 * For reference: https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/game/server/hl2/npc_bullseye.cpp#L151
 *
 * @param angle     The FOV value in degree
 * @return          Width of the forward view cone as a dot product result
 */
float GetFOVDotProduct(float angle) {
	return Cosine(DegToRad(angle) / 2.0);
}