#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <colors>
#include <left4dhooks>

Handle
	g_hTimer;

ConVar
	g_cvPrintTime;

float
	g_fPrintTime;

bool
	g_bLateLoad,
	g_bLeftSafeArea;

int
	g_iTotaldmgSI,
	g_iTotalkillSI,
	g_iTotalkillCI,
	g_iTotalFF,
	g_iTotalRF;

enum struct esData {
	int dmgSI;
	int killSI;
	int killCI;
	int headSI;
	int headCI;
	int teamFF;
	int teamRF;

	int totalTankDmg;
	int lastTankHealth;
	int tankDmg[MAXPLAYERS + 1];
	int tankClaw[MAXPLAYERS + 1];
	int tankRock[MAXPLAYERS + 1];
	int tankHittable[MAXPLAYERS + 1];

	void CleanInfected() {
		this.dmgSI = 0;
		this.killSI = 0;
		this.killCI = 0;
		this.headSI = 0;
		this.headCI = 0;
		this.teamFF = 0;
		this.teamRF = 0;
	}

	void CleanTank() {
		this.totalTankDmg = 0;
		this.lastTankHealth = 0;

		for (int i = 1; i <= MaxClients; i++) {
			this.tankDmg[i] = 0;
			this.tankClaw[i] = 0;
			this.tankRock[i] = 0;
			this.tankHittable[i] = 0;
		}
	}
}

esData
	g_esData[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "击杀排行统计",
	description = "击杀排行统计",
	author = "白色幽灵 WhiteGT",
	version = "0.6",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	g_cvPrintTime = CreateConVar("sm_mvp_time", "240.0", "轮播时间间隔", FCVAR_NOTIFY, true, 0.0);
	g_cvPrintTime.AddChangeHook(CvarChanged);

	//AutoExecConfig(true,"l4d_mvp");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_MapTransition);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("infected_death", Event_InfectedDeath);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_incapacitated_start", Event_PlayerIncapacitatedStart);
	
	RegConsoleCmd("sm_mvp", cmdDisplay, "Show Mvp");

	if (g_bLateLoad && L4D_HasAnySurvivorLeftSafeArea())
		L4D_OnFirstSurvivorLeftSafeArea_Post(0);
}

public void OnConfigsExecuted() {
	g_fPrintTime = g_cvPrintTime.FloatValue;
}

void CvarChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	g_fPrintTime = g_cvPrintTime.FloatValue;

	delete g_hTimer;
	if (g_fPrintTime > 0.0 && g_bLeftSafeArea)
		g_hTimer = CreateTimer(g_fPrintTime, tmrPrintStatistics);
}

Action cmdDisplay(int client, int args) {
	if (!client || !IsClientInGame(client))
		return Plugin_Handled;

	PrintStatistics();
	return Plugin_Handled;
}

public void L4D_OnFirstSurvivorLeftSafeArea_Post(int client) {
	delete g_hTimer;
	if (g_fPrintTime > 0.0 && !g_bLeftSafeArea)
		g_hTimer = CreateTimer(g_fPrintTime, tmrPrintStatistics);

	g_bLeftSafeArea = true;
}

Action tmrPrintStatistics(Handle timer) {
	g_hTimer = null;

	PrintStatistics();

	if (g_fPrintTime > 0.0)
		g_hTimer = CreateTimer(g_fPrintTime, tmrPrintStatistics);

	return Plugin_Continue;
}

public void OnClientDisconnect(int client) {
	g_iTotaldmgSI -= g_esData[client].dmgSI;
	g_iTotalkillSI -= g_esData[client].killSI;
	g_iTotalkillCI -= g_esData[client].killCI;
	g_iTotalFF -= g_esData[client].teamFF;
	g_iTotalRF -= g_esData[client].teamRF;
	
	g_esData[client].CleanInfected();
	g_esData[client].CleanTank();

	for (int i = 1; i <= MaxClients; i++) {
		g_esData[i].tankDmg[client] = 0;
		g_esData[i].tankClaw[client] = 0;
		g_esData[i].tankRock[client] = 0;
		g_esData[i].tankHittable[client] = 0;
	}
}

public void OnMapEnd() {
	delete g_hTimer;
	g_bLeftSafeArea = false;

	ClearData();
	ClearTankData();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	PrintStatistics();

	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	delete g_hTimer;
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast) {
	delete g_hTimer;
	PrintStatistics();
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker))
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || victim == attacker || !IsClientInGame(victim))
		return;

	switch (GetClientTeam(victim)) {
		case 2: {
			switch (GetClientTeam(attacker)) {
				case 2: {
					int dmg = event.GetInt("dmg_health");
					g_iTotalFF += dmg;
					g_esData[attacker].teamFF += dmg;

					g_iTotalRF += dmg;
					g_esData[victim].teamRF += dmg;
				}

				case 3: {
					if (GetEntProp(attacker, Prop_Send, "m_zombieClass") == 8) {
						char weapon[32];
						event.GetString("weapon", weapon, sizeof weapon);
						if (strcmp(weapon, "tank_claw") == 0)
							g_esData[attacker].tankClaw[victim]++;
						else if (strcmp(weapon, "tank_rock") == 0)
							g_esData[attacker].tankRock[victim]++;
						else
							g_esData[attacker].tankHittable[victim]++;
					}
				}
			}
		}
		
		case 3: {
			if (GetClientTeam(attacker) == 2) {
				int dmg = event.GetInt("dmg_health");
				switch (GetEntProp(victim, Prop_Send, "m_zombieClass")) {
					case 1, 2, 3, 4, 5, 6: {
						g_iTotaldmgSI += dmg;
						g_esData[attacker].dmgSI += dmg;
					}
		
					case 8: {
						if (!GetEntProp(victim, Prop_Send, "m_isIncapacitated")) {
							g_esData[victim].totalTankDmg += dmg;
							g_esData[victim].tankDmg[attacker] += dmg;

							g_esData[victim].lastTankHealth = event.GetInt("health");
						}
					}
				}
			}
		}
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int class = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if (class == 8) {
		g_esData[victim].totalTankDmg += g_esData[victim].lastTankHealth;
		g_esData[victim].tankDmg[attacker] += g_esData[victim].lastTankHealth;

		PrintTankStatistics(victim);
	}

	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	if (event.GetBool("headshot"))
		g_esData[attacker].headSI++;

	switch (class) {
		case 1, 2, 3, 4, 5, 6: {
			g_iTotalkillSI++;
			g_esData[attacker].killSI++;
		}
		/*
		case 8:
			g_esData[attacker].killSI++;*/
	}
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	if (event.GetBool("headshot"))
		g_esData[attacker].headCI++;

	g_iTotalkillCI++;
	g_esData[attacker].killCI++;
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client && IsClientInGame(client))
		g_esData[client].CleanTank();
}

void Event_PlayerIncapacitatedStart(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 3 || GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 2)
		return;
	
	char weapon[32];
	event.GetString("weapon", weapon, sizeof weapon);
	if (strcmp(weapon, "tank_claw") == 0)
		g_esData[attacker].tankClaw[victim]++;
	else if (strcmp(weapon, "tank_rock") == 0)
		g_esData[attacker].tankRock[victim]++;
	else
		g_esData[attacker].tankHittable[victim]++;
}

void PrintStatistics() {
	int count;
	int client;
	int[] clients = new int[MaxClients];
	for (client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && (!IsFakeClient(client) || GetClientTeam(client) == 2))
			clients[count++] = client;
	}

	if (!count)
		return;

	int infoMax = count < 4 ? count : 4;
	SortCustom1D(clients, count, SortSIKill);

	int i;
	int dmgSI;
	int killSI;
	int headSI;
	int killCI;
	int headCI;
	int teamFF;
	int teamRF;

	char str[12];
	int dataSort[MAXPLAYERS + 1];
	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].killSI;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int killSILen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].headSI;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int headSILen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].killCI;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int killCILen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].teamFF;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int teamFFLen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		dataSort[count++] = g_esData[client].teamRF;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int teamRFLen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	int curLen;
	int spaceCount;
	char buffer[254];

	PrintToChatAll("统计");

	for (i = 0; i < infoMax; i++) {
		client = clients[i];
		killSI = g_esData[client].killSI;
		killCI = g_esData[client].killCI;
		headSI = g_esData[client].headSI;
		teamFF = g_esData[client].teamFF;
		teamRF = g_esData[client].teamRF;

		curLen = 2 * killSILen - 2 * IntToString(killSI, str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		strcopy(buffer, sizeof buffer, "\x04★ \x01特感: ");
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s\x05%s", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
	
		Format(buffer, sizeof buffer, "%s%s", buffer, " \x01爆头: ");
		curLen = 2 * headSILen - 2 * IntToString(headSI, str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s\x05%s", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);

		Format(buffer, sizeof buffer, "%s%s", buffer, " \x01丧尸: ");
		curLen = 2 * killCILen - 2 * IntToString(killCI, str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s\x05%s", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);

		Format(buffer, sizeof buffer, "%s%s", buffer, " \x01友伤: ");
		curLen = 2 * teamFFLen - 2 * IntToString(teamFF, str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s\x05%s", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);

		Format(buffer, sizeof buffer, "%s%s", buffer, " \x01被黑: ");
		curLen = 2 * teamRFLen - 2 * IntToString(teamRF, str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s\x05%s", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);

		Format(buffer, sizeof buffer, "%s  \x05%N", buffer, client);

		PrintToChatAll("%s", buffer);
	}

	SortCustom1D(clients, count, SortSIDamage);
	client = clients[0];
	dmgSI = g_esData[client].dmgSI;
	killSI = g_esData[client].killSI;
	if (killSI > 0)
		PrintToChatAll("\x04★ \x01特感杀手: \x05%N \x01伤害: \x05%d\x01(\x04%d%%\x01) 击杀: \x05%d\x01(\x04%d%%\x01)", client, dmgSI, RoundToNearest(float(dmgSI) / float(g_iTotaldmgSI) * 100.0), killSI, RoundToNearest(float(killSI) / float(g_iTotalkillSI) * 100.0));

	SortCustom1D(clients, count, SortCIKill);
	client = clients[0];
	killCI = g_esData[client].killCI;
	headCI = g_esData[client].headCI;
	if (killCI > 0)
		PrintToChatAll("\x04★ \x01清尸狂人: \x05%N \x01击杀: \x05%d\x01(\x04%d%%\x01) 爆头: \x05%d\x01(\x04%d%%\x01)", client, killCI, RoundToNearest(float(killCI) / float(g_iTotalkillCI) * 100.0), headCI, RoundToNearest(float(headCI) / float(killCI) * 100.0));

	SortCustom1D(clients, count, SortTeamFF);
	client = clients[0];
	teamFF = g_esData[client].teamFF;
	if (teamFF > 0)
		PrintToChatAll("\x04★ \x01黑枪之王: \x05%N \x01友伤: \x05%d\x01(\x04%d%%\x01)", client, teamFF, RoundToNearest(float(teamFF) / float(g_iTotalFF) * 100.0));

	SortCustom1D(clients, count, SortTeamRF);
	client = clients[0];
	teamRF = g_esData[client].teamRF;
	if (teamRF > 0)
		PrintToChatAll("\x04★ \x01挨枪之王: \x05%N \x01被黑: \x05%d\x01(\x04%d%%\x01)", client, teamRF, RoundToNearest(float(teamRF) / float(g_iTotalRF) * 100.0));
}

void PrintTankStatistics(int tank) {
	if (g_esData[tank].totalTankDmg <= 0)
		return;

	ArrayList aClients = new ArrayList(2);

	int i = 1;
	for (; i <= MaxClients; i++) {
		if (IsClientInGame(i) && (!IsFakeClient(i) || GetClientTeam(i) == 2) && IsActive(tank, i))
			aClients.Set(aClients.Push(g_esData[tank].tankDmg[i]), i, 1);
	}

	int length = aClients.Length;
	if (!length) {
		delete aClients;
		return;
	}

	aClients.Sort(Sort_Descending, Sort_Integer);

	char str[12];
	int damage = aClients.Get(0, 0);
	int dmgLen = IntToString(damage, str, sizeof str);

	int count;
	int client;
	int dataSort[MAXPLAYERS + 1];
	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		dataSort[count++] = g_esData[tank].tankClaw[client];
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int clawLen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	int percent;
	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		damage = aClients.Get(i, 0);
		percent = RoundToNearest(float(damage) / float(g_esData[tank].totalTankDmg) * 100.0);
		dataSort[count++] = percent;
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int percLen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		dataSort[count++] = g_esData[tank].tankRock[client];
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int rockLen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		dataSort[count++] = g_esData[tank].tankHittable[client];
	}

	SortIntegers(dataSort, count, Sort_Descending);
	int hitLen = IntToString(count ? dataSort[0] : 0, str, sizeof str);

	char name[MAX_NAME_LENGTH];
	FormatEx(name, sizeof name, "[%s] %N", IsFakeClient(tank) ? "AI" : "PZ", tank);
	CPrintToChatAll("{default}[{red}%s{default}] {olive}%N {default}伤害承受: {red}%d", IsFakeClient(tank) ? "AI" : "PZ", tank, g_esData[tank].totalTankDmg);

	int curLen;
	int spaceCount;
	char buffer[254];
	for (i = 0; i < length; i++) {
		client = aClients.Get(i, 1);
		damage = aClients.Get(i, 0);
		percent = RoundToNearest(float(damage) / float(g_esData[tank].totalTankDmg) * 100.0);

		curLen = 2 * dmgLen - 2 * IntToString(damage, str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		strcopy(buffer, sizeof buffer, "{green}★ {default}[");
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s{red}%s", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
	
		Format(buffer, sizeof buffer, "%s%s", buffer, "{default}] (");
		curLen = 2 * percLen - 2 * IntToString(percent, str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s{red}%s%%", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
	
		Format(buffer, sizeof buffer, "%s%s", buffer, "{default}) 吃拳: ");
		curLen = 2 * clawLen - 2 * IntToString(g_esData[tank].tankClaw[client], str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s{red}%s", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);

		Format(buffer, sizeof buffer, "%s%s", buffer, " {default}吃饼: ");
		curLen = 2 * rockLen - 2 * IntToString(g_esData[tank].tankRock[client], str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s{red}%s", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);

		Format(buffer, sizeof buffer, "%s%s", buffer, " {default}吃铁: ");
		curLen = 2 * hitLen - 2 * IntToString(g_esData[tank].tankHittable[client], str, sizeof str);
		spaceCount = RoundToCeil(curLen / 2.0);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);
		Format(buffer, sizeof buffer, "%s{red}%s", buffer, str);
		AppendSpaceChar(buffer, sizeof buffer, spaceCount);

		Format(buffer, sizeof buffer, "%s {olive}%N", buffer, client);


		CPrintToChatAll("%s", buffer);
	}

	delete aClients;
}

bool IsActive(int tank, int client) {
	return g_esData[tank].tankDmg[client] > 0 || g_esData[tank].tankClaw[client] > 0 || g_esData[tank].tankRock[client] > 0 || g_esData[tank].tankHittable[client] > 0;
}

void AppendSpaceChar(char[] str, int maxlength, int numSpace) {
	for (int i; i < numSpace; i++)
		Format(str, maxlength, "%s%s", str, " ");
}

int SortSIDamage(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].dmgSI < g_esData[elem1].dmgSI)
		return -1;
	else if (g_esData[elem1].dmgSI < g_esData[elem2].dmgSI)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

int SortSIKill(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].killSI < g_esData[elem1].killSI)
		return -1;
	else if (g_esData[elem1].killSI < g_esData[elem2].killSI)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

int SortCIKill(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].killCI < g_esData[elem1].killCI)
		return -1;
	else if (g_esData[elem1].killCI < g_esData[elem2].killCI)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

int SortTeamFF(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].teamFF < g_esData[elem1].teamFF)
		return -1;
	else if (g_esData[elem1].teamFF < g_esData[elem2].teamFF)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

int SortTeamRF(int elem1, int elem2, const int[] array, Handle hndl) {
	if (g_esData[elem2].teamRF < g_esData[elem1].teamRF)
		return -1;
	else if (g_esData[elem1].teamRF < g_esData[elem2].teamRF)
		return 1;

	if (elem1 > elem2)
		return -1;
	else if (elem2 > elem1)
		return 1;

	return 0;
}

void ClearData() {
	g_iTotaldmgSI = 0;
	g_iTotalkillSI = 0;
	g_iTotalkillCI = 0;
	g_iTotalFF = 0;
	g_iTotalRF = 0;

	for (int i = 1; i <= MaxClients; i++)
		g_esData[i].CleanInfected();
}

void ClearTankData() {
	for (int i = 1; i <= MaxClients; i++)
		g_esData[i].CleanTank();
}