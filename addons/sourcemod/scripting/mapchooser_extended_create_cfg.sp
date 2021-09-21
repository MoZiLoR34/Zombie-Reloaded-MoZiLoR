/*
 * =============================================================================
 * File:		  Mapchooser Extended Create mapchooser_extended.cfg
 * Type:		  Base
 * Description:   Plugin's base file.
 *
 * Copyright (C)   Anubis Edition. All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#define VERSION "1.0-A"

ConVar g_Cvar_MinPlayers;
ConVar g_Cvar_MaxPlayers;
ConVar g_Cvar_Cooldown;

int g_MinPlayers;
int g_MaxPlayers;
int g_Cooldown;

char g_GameModName[64];

public Plugin myinfo =
{
	name = "Create mapchooser_extended.cfg",
	author = "Anubis",
	description = "Mapchooser Extended Create mapchooser_extended.cfg",
	version = VERSION,
	url = "stewartbh@live.com"
};

public void OnPluginStart()
{
	g_Cvar_MinPlayers = CreateConVar("sm_mce_minplayers_default", "1", "Specify default minplayer to create the file.");
	g_Cvar_MaxPlayers = CreateConVar("sm_mce_maxplayers_default", "64", "Specify default maxplayer to create the file.");
	g_Cvar_Cooldown = CreateConVar("sm_mce_cooldown_default", "1", "Specify default cooldown to create the file");

	g_MinPlayers = g_Cvar_MinPlayers.IntValue;
	g_MaxPlayers = g_Cvar_MaxPlayers.IntValue;
	g_Cooldown = g_Cvar_Cooldown.IntValue;

	g_Cvar_MinPlayers.AddChangeHook(OnConVarChanged);
	g_Cvar_MaxPlayers.AddChangeHook(OnConVarChanged);
	g_Cvar_Cooldown.AddChangeHook(OnConVarChanged);

	RegAdminCmd("sm_mcecreatecfg", Command_CrateCfg, ADMFLAG_ROOT, "Create mapchooser_extended.cfg the file");
	GetGameFolderName(g_GameModName, sizeof(g_GameModName));

	AutoExecConfig(true, "mapchooser_extended_create_cfg");
}

public void OnConVarChanged(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	g_MinPlayers = g_Cvar_MinPlayers.IntValue;
	g_MaxPlayers = g_Cvar_MaxPlayers.IntValue;
	g_Cooldown = g_Cvar_Cooldown.IntValue;
}

public Action Command_CrateCfg(int client, int argc)
{
	if (argc < 1)
	{
		ReplyToCommand(client, "[MCE] Usage: sm_mcecreatecfg <prefix>. Exemple prefix ze zm.");
		return;
	}
	char s_ArgPrefix[64];
	char s_FilePath[PLATFORM_MAX_PATH];
	char s_MapListPath[PLATFORM_MAX_PATH];
	Format(s_MapListPath, sizeof(s_MapListPath), "addons/sourcemod/configs/mapchooser_extended/maps/%s.txt", g_GameModName);
	Handle h_MapListCfg;
	Handle h_MapList = OpenFile(s_MapListPath, "a");

	GetCmdArg(1, s_ArgPrefix, sizeof(s_ArgPrefix));

	BuildPath(Path_SM, s_FilePath, sizeof(s_FilePath), "configs/mapchooser_extended.cfg");

	h_MapListCfg = CreateKeyValues("mapchooser_extended");

	if(!FileExists(s_FilePath)) KeyValuesToFile(h_MapListCfg, s_FilePath);
	else FileToKeyValues(h_MapListCfg, s_FilePath);

	LogMessage("Found CFG Map File: \"%s\"", s_FilePath);

	Handle h_MapDir = OpenDirectory("maps/");
	char s_MapName[PLATFORM_MAX_PATH];
	char s_Extension[2][PLATFORM_MAX_PATH];
	char s_Prefix[2][PLATFORM_MAX_PATH];
	FileType fileType;

	while (ReadDirEntry(h_MapDir, s_MapName, sizeof(s_MapName), fileType))
	{
		if (fileType == FileType_File)
		{
			ExplodeString(s_MapName, "_", s_Prefix, 2, sizeof(s_Prefix[]));
			ExplodeString(s_MapName, ".", s_Extension, 2, sizeof(s_Extension[]));

			if (StrEqual(s_Extension[1], "bsp", false) && StrEqual(s_Prefix[0], s_ArgPrefix, false))
			{
				char s_Key[PLATFORM_MAX_PATH];
				Format(s_Key, sizeof(s_Key), "%s", s_Extension[0]);

				if(!KvJumpToKey(h_MapListCfg, s_Key))
				{
					KvRewind(h_MapListCfg);
					KvJumpToKey(h_MapListCfg, s_Key, true);
					KvSetNum(h_MapListCfg, "MinPlayers", g_MinPlayers);
					KvSetNum(h_MapListCfg, "MaxPlayers", g_MaxPlayers);
					KvSetNum(h_MapListCfg, "Cooldown", g_Cooldown);
					KvRewind(h_MapListCfg);
				}

				WriteFileLine(h_MapList, "%s", s_Key);
			}
		}
	}

	KvRewind(h_MapListCfg);
	KeyValuesToFile(h_MapListCfg, s_FilePath);
	CloseHandle(h_MapList);
	CloseHandle(h_MapListCfg);
	CloseHandle(h_MapDir);
	ReplyToCommand(client, "[MCE] Created: < configs/mapchooser_extended.cfg > and < configs/mapchooser_extended/maps/%s.txt >.", g_GameModName);
}