#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define DEBUG					0

#define PLUGIN_NAME				"Command Once"
#define PLUGIN_AUTHOR			"sorallll"
#define PLUGIN_DESCRIPTION		"在服务器读取完cfg后执行一次所有使用该命令设置的内容"
#define PLUGIN_VERSION			"1.0.0"
#define PLUGIN_URL				""

ArrayList
	g_aMatch,
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
	g_aMatch = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	g_aCmdList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	CreateConVar("command_once_version", PLUGIN_VERSION, "Command Once plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegServerCmd("cmd_once", cmdOnce, "在服务器读取完cfg后执行一次所有使用该命令设置的内容");
}

Action cmdOnce(int args) {
	if (g_bExecuted)
		return Plugin_Handled;

	char command[PLATFORM_MAX_PATH];
	GetCmdArg(1, command, sizeof command);
	StringToLowerCase(command);
	if (g_aMatch.FindString(command) != -1) {
		LogError("命令(%s)已存在, 请勿重复设置", command);
		return Plugin_Handled;
	}

	g_aMatch.PushString(command);
	GetCmdArgString(command, sizeof command);
	g_aCmdList.PushString(command);
	return Plugin_Handled;
}

/**
 * Converts the given string to lower case
 *
 * @param szString	Input string for conversion and also the output
 * @return			void
 */
void StringToLowerCase(char[] szInput) {
	int iIterator;
	while (szInput[iIterator] != EOS) {
		szInput[iIterator] = CharToLower(szInput[iIterator]);
		++iIterator;
	}
}

public void OnConfigsExecuted() {
	if (!g_bExecuted) {
		vExecuteCommands();
		g_bExecuted = true;
	}
}

// https://forums.alliedmods.net/showthread.php?p=2607757
void vExecuteCommands() {
	char sCommand[PLATFORM_MAX_PATH];
	ArrayList aCmdList = g_aCmdList.Clone();
	//g_aCmdList.Clear();

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
