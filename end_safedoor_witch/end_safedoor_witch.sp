#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>

#define PLUGIN_NAME				"End Safedoor Witch"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		""
#define PLUGIN_VERSION			"1.0.4"
#define PLUGIN_URL				"https://forums.alliedmods.net/showthread.php?t=335777"

// witch向门外偏移的距离
#define WITCH_OFFSET	33.0

int
	g_iRoundStart,
	g_iPlayerSpawn;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	HookEvent("round_end",		Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",	Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",	Event_PlayerSpawn,	EventHookMode_PostNoCopy);
}

public void OnMapEnd() {
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 0 && g_iPlayerSpawn == 1)
		CreateTimer(1.0, tmrSpawnWitch, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iRoundStart = 1;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (g_iRoundStart == 1 && g_iPlayerSpawn == 0)
		CreateTimer(1.0, tmrSpawnWitch, _, TIMER_FLAG_NO_MAPCHANGE);
	g_iPlayerSpawn = 1;
}

Action tmrSpawnWitch(Handle timer) {
	int ent = INVALID_ENT_REFERENCE;
	if ((ent = FindEntityByClassname(MaxClients + 1, "info_changelevel")) == -1)
		ent = FindEntityByClassname(MaxClients + 1, "trigger_changelevel");

	if (ent == -1)
		return Plugin_Stop;

	int door = L4D_GetCheckpointLast();
	if (door == -1)
		return Plugin_Stop;

	float vOrigin[3];
	GetAbsOrigin(ent, vOrigin, true);
	vOrigin[2] = 0.0;

	float height;
	float vPos[3];
	float vOff[3];
	float vAng[3];
	float vFwd[3];
	float vVec[2][3];
	float vEnd[2][3];

	GetEntPropVector(door, Prop_Data, "m_vecAbsOrigin", vPos);
	vVec[0] = vPos;
	vVec[0][2] = 0.0;
	MakeVectorFromPoints(vVec[0], vOrigin, vVec[0]);
	NormalizeVector(vVec[0], vVec[0]);

	GetEntPropVector(door, Prop_Data, "m_angRotationClosed", vOff);
	GetAngleVectors(vOff, vVec[1], NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vVec[1], vVec[1]);

	if (RadToDeg(ArcCosine(GetVectorDotProduct(vVec[0], vVec[1]))) < 90.0)
		vOff[1] += 180.0;

	GetEntPropVector(door, Prop_Data, "m_angRotationOpenBack", vAng);
	GetAngleVectors(vAng, vFwd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vFwd, vFwd);
	ScaleVector(vFwd, 24.0);
	AddVectors(vPos, vFwd, vPos);

	if (GetEndPoint(vPos, vAng, 32.0, vEnd[0], door)) {
		vAng[1] += 180.0;
		if (GetEndPoint(vPos, vAng, 32.0, vEnd[1], door)) {
			NormalizeVector(vFwd, vFwd);
			ScaleVector(vFwd, GetVectorDistance(vEnd[0], vEnd[1]) * 0.5);
			AddVectors(vEnd[1], vFwd, vPos);
		}
	}

	GetAngleVectors(vOff, vFwd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vFwd, vFwd);
	ScaleVector(vFwd, WITCH_OFFSET);
	AddVectors(vPos, vFwd, vPos);

	vPos[2] -= 25.0;
	height = GetGroundHeight(vPos, door);
	if (height && vPos[2] - height < 104.0)
		vPos[2] = height + 5.0;

	SpawnWitch(vPos, vOff);
	return Plugin_Continue;
}

float GetGroundHeight(const float vPos[3], int ent) {
	float vEnd[3];
	Handle hTrace = TR_TraceRayFilterEx(vPos, view_as<float>({90.0, 0.0, 0.0}), MASK_ALL, RayType_Infinite, _TraceEntityFilter, ent);
	if (TR_DidHit(hTrace))
		TR_GetEndPosition(vEnd, hTrace);

	delete hTrace;
	return vEnd[2];
}

bool GetEndPoint(const float vStart[3], const float vAng[3], float scale, float vBuffer[3], int ent) {
	float vEnd[3];
	GetAngleVectors(vAng, vEnd, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(vEnd, vEnd);
	ScaleVector(vEnd, scale);
	AddVectors(vStart, vEnd, vEnd);

	Handle hTrace = TR_TraceHullFilterEx(vStart, vEnd, view_as<float>({-5.0, -5.0, 0.0}), view_as<float>({5.0, 5.0, 5.0}), MASK_ALL, _TraceEntityFilter, ent);
	if (TR_DidHit(hTrace)) {
		TR_GetEndPosition(vBuffer, hTrace);
		delete hTrace;
		return true;
	}

	delete hTrace;
	return false;
}

bool _TraceEntityFilter(int entity, int contentsMask, any data) {
	if (entity == data || entity <= MaxClients)
		return false;

	char cls[9];
	GetEntityClassname(entity, cls, sizeof cls);
	if ((cls[0] == 'i' && strcmp(cls[1], "nfected") == 0) || (cls[0] == 'w' && strcmp(cls[1], "itch") == 0))
		return false;

	return true;
}

// https://forums.alliedmods.net/showthread.php?p=1471101
void SpawnWitch(const float vPos[3], const float vAng[3]) {
	int witch = CreateEntityByName("witch");
	if (witch != -1) {
		TeleportEntity(witch, vPos, vAng, NULL_VECTOR);
		SetEntPropFloat(witch, Prop_Send, "m_rage", 0.5);
		SetEntProp(witch, Prop_Data, "m_nSequence", 4);
		DispatchSpawn(witch);
		SetEntProp(witch, Prop_Send, "m_CollisionGroup", 1);
		CreateTimer(0.3, tmrSolidCollision, EntIndexToEntRef(witch), TIMER_FLAG_NO_MAPCHANGE);
	}
}

Action tmrSolidCollision(Handle timer, int witch) {
	if (EntRefToEntIndex(witch) != INVALID_ENT_REFERENCE)
		SetEntProp(witch, Prop_Send, "m_CollisionGroup", 0);

	return Plugin_Continue;
}
