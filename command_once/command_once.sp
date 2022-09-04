#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_NAME				"Command Once"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"在服务器读取完cfg后执行一次所有使用该命令设置的内容"
#define PLUGIN_VERSION			"1.0.1"
#define PLUGIN_URL				""

#define DEBUG					0
#define ARGS_BUFFER_LENGTH		8192

ArrayList
	g_aCmdList;

bool
	g_bOnce;

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	g_aCmdList = new ArrayList(ByteCountToCells(ARGS_BUFFER_LENGTH));
	CreateConVar("command_once_version", PLUGIN_VERSION, "Command Once plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegServerCmd("cmd_once", cmdOnce, "在服务器读取完cfg后执行一次所有使用该命令设置的内容");
}

Action cmdOnce(int args) {
	if (g_bOnce)
		return Plugin_Handled;

	static char cmd[ARGS_BUFFER_LENGTH];
	if (!GetCmdArgString(cmd, sizeof cmd))
		return Plugin_Handled;

	if (g_aCmdList.FindString(cmd) == -1)
		g_aCmdList.PushString(cmd);

	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	if (!g_bOnce) {
		g_bOnce = true;
		vExecuteCommandList();
	}
}

// https://forums.alliedmods.net/showthread.php?p=2607757
void vExecuteCommandList() {
	ArrayList aCmdList = g_aCmdList.Clone();
	g_aCmdList.Clear();

	static char sCommand[ARGS_BUFFER_LENGTH];

	int length = aCmdList.Length;
	for (int i; i < length; i++) {
		aCmdList.GetString(i, sCommand, sizeof sCommand);
		InsertServerCommand("%s", sCommand);
		ServerExecute();
		#if DEBUG
		LogCustom("logs/command_once.log", "%s", sCommand);
		#endif
	}

	delete aCmdList;
}

#if DEBUG
void LogCustom(const char[] path, const char[] sMessage, any ...) {
	static char time[32];
	FormatTime(time, sizeof time, "%x %X");

	static char map[64];
	GetCurrentMap(map, sizeof map);

	static char buffer[254];
	VFormat(buffer, sizeof buffer, sMessage, 3);
	Format(buffer, sizeof buffer, "[%s] [%s] %s", time, map, buffer);

	static char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof sPath, path);
	File file = OpenFile(sPath, "a+");
	file.WriteLine("%s", buffer);
	file.Flush();
	delete file;
}
#endif
