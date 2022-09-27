#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define PLUGIN_NAME				"Command Once"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"在服务器首次OnConfigsExecuted()触发后执行所有使用该命令设置的内容"
#define PLUGIN_VERSION			"1.0.5"
#define PLUGIN_URL				"https://github.com/umlka/l4d2/tree/main/command_once"

ArrayList
	g_aCmdList;

bool
	g_bExecuted;

enum struct esCmd {
	char cmd[64];
	char value[255];
}

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart() {
	g_aCmdList = new ArrayList(sizeof esCmd);
	CreateConVar("command_once_version", PLUGIN_VERSION, "Command Once plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegAdminCmd("sm_exec_once", 	cmdExec_Once,	ADMFLAG_RCON,	"手动执行");
	RegAdminCmd("sm_reset_once",	cmdReset_Once,	ADMFLAG_RCON,	"重置命令");
	RegServerCmd("cmd_once", cmdOnce, "在服务器首次OnConfigsExecuted()触发后执行所有使用该命令设置的内容");
}

Action cmdExec_Once(int client, int args) {
	ExecuteCmdList();
	ReplyToCommand(client, "已执行 %d 条命令", g_aCmdList.Length);
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
	if (args < 1)
		return Plugin_Handled;

	if (g_bExecuted)
		return Plugin_Handled;

	char cmd[64];
	if (!GetCmdArg(1, cmd, sizeof cmd))
		return Plugin_Handled;

	char value[255];
	GetCmdArgString(value, sizeof value);
	strcopy(value, sizeof value, value[strlen(cmd)]);
	TrimString(value);

	esCmd command;
	strcopy(command.cmd, sizeof command.cmd, cmd);
	strcopy(command.value, sizeof command.value, value);
	g_aCmdList.PushArray(command);
	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	if (!g_bExecuted) {
		g_bExecuted = true;
		RequestFrame(NextFrame_Executed);
	}
}

// https://forums.alliedmods.net/showthread.php?p=2607757
void NextFrame_Executed() {
	ExecuteCmdList();
}

void ExecuteCmdList() {
	esCmd command;
	ArrayList aCmdList = g_aCmdList.Clone();
	int count = aCmdList.Length;
	for (int i; i < count; i++) {
		aCmdList.GetArray(i, command);
		InsertServerCommand("%s %s", command.cmd, command.value);
		ServerExecute();
	}

	delete aCmdList;
}
