#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_NAME				"Command Once"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"在服务器首次OnConfigsExecuted()触发后执行所有使用该命令设置的内容"
#define PLUGIN_VERSION			"1.0.2"
#define PLUGIN_URL				""

#define DEBUG					0
#define ARGS_BUFFER_LENGTH		8192

ArrayList
	g_aCmdList;

bool
	g_bExecuted;

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

	RegAdminCmd("sm_exec_once", 	cmdExec_Once,	ADMFLAG_RCON,	"手动执行");
	RegAdminCmd("sm_reset_once",	cmdReset_Once,	ADMFLAG_RCON,	"重置命令");
	RegServerCmd("cmd_once", cmdOnce, "在服务器首次OnConfigsExecuted()触发后执行所有使用该命令设置的内容");
}

Action cmdExec_Once(int client, int args) {
	int count = iExecuteCommandList();
	ReplyToCommand(client, "已执行 %d 条命令", count);
	return Plugin_Handled;
}

Action cmdReset_Once(int client, int args) {
	int count = g_aCmdList.Length;

	g_aCmdList.Clear();
	g_bExecuted = false;

	ReplyToCommand(client, "已重置 %d 条命令", count);
	return Plugin_Handled;
}

Action cmdOnce(int args) {
	if (g_bExecuted)
		return Plugin_Handled;

	static char cmd[ARGS_BUFFER_LENGTH];
	if (!GetCmdArgString(cmd, sizeof cmd))
		return Plugin_Handled;

	if (g_aCmdList.FindString(cmd) == -1)
		g_aCmdList.PushString(cmd);

	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	if (!g_bExecuted) {
		g_bExecuted = true;
		iExecuteCommandList();
	}
}

// https://forums.alliedmods.net/showthread.php?p=2607757
int iExecuteCommandList() {
	ArrayList aCmdList = g_aCmdList.Clone();
	//g_aCmdList.Clear();

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
	return length;
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
