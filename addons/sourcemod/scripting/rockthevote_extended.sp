/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Rock The Vote Plugin
 * Creates a map vote when the required number of players have requested one.
 *
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
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
 *
 * Version: $Id$
 */

#include <sourcemod>
#include <sdktools_functions>
#include <mapchooser>
#include <nextmap>
#include <colors_csgo>

#pragma semicolon 1
#pragma newdecls required

#define MCE_VERSION "1.13.1-A"

public Plugin myinfo =
{
	name = "Rock The Vote Extended",
	author = "Powerlord and AlliedModders LLC, Anubis edition",
	description = "Provides RTV Map Voting",
	version = MCE_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=156974"
};

ConVar g_Cvar_Needed;
ConVar g_Cvar_MinPlayers;
ConVar g_Cvar_InitialDelay;
ConVar g_Cvar_Interval;
ConVar g_Cvar_ChangeTime;
ConVar g_Cvar_RTVPostVoteAction;
ConVar g_Cvar_AllowBots;
ConVar g_Cvar_AllowSpec;

float g_Needed;
int g_MinPlayers;
float g_InitialDelay;
float g_Interval;
int g_ChangeTime;
int g_RTVPostVoteAction;

bool g_CanRTV = false;		// True if RTV loaded maps and is active.
bool g_RTVAllowed = false;	// True if RTV is available to players. Used to delay rtv votes.
int g_Voters = 0;				// Total voters connected. Doesn't include fake clients.
int g_Votes = 0;				// Total number of "say rtv" votes
int g_VotesNeeded = 0;			// Necessary votes before map vote begins. (voters * percent_needed)
bool g_Voted[MAXPLAYERS+1] = {false, ...};

bool g_InChange = false;

 // Isvalid Client
bool bzrAllowBots = false;
bool bzrAllowSpec = false;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("rockthevote.phrases");
	LoadTranslations("basevotes.phrases");

	g_Cvar_Needed = CreateConVar("sm_rtv_needed", "0.60", "Percentage of players needed to rockthevote (Def 60%)", 0, true, 0.05, true, 1.0);
	g_Cvar_MinPlayers = CreateConVar("sm_rtv_minplayers", "0", "Number of players required before RTV will be enabled.", 0, true, 0.0, true, float(MAXPLAYERS));
	g_Cvar_InitialDelay = CreateConVar("sm_rtv_initialdelay", "30.0", "Time (in seconds) before first RTV can be held", 0, true, 0.00);
	g_Cvar_Interval = CreateConVar("sm_rtv_interval", "240.0", "Time (in seconds) after a failed RTV before another can be held", 0, true, 0.00);
	g_Cvar_ChangeTime = CreateConVar("sm_rtv_changetime", "0", "When to change the map after a succesful RTV: 0 - Instant, 1 - RoundEnd, 2 - MapEnd", _, true, 0.0, true, 2.0);
	g_Cvar_RTVPostVoteAction = CreateConVar("sm_rtv_postvoteaction", "0", "What to do with RTV's after a mapvote has completed. 0 - Allow, success = instant change, 1 - Deny", _, true, 0.0, true, 1.0);
	g_Cvar_AllowBots = CreateConVar("sm_rtv_allowbots", "0", "Allow bots to be counted on RTV? 1-Yes 0-No.");
	g_Cvar_AllowSpec = CreateConVar("sm_rtv_allowspec", "1", "Allow dead/observer/spectator to be counted and vote on RTV? 1-Yes 0-No.");

	g_Needed = g_Cvar_Needed.FloatValue;
	g_MinPlayers = g_Cvar_MinPlayers.IntValue;
	g_InitialDelay = g_Cvar_InitialDelay.FloatValue;
	g_Interval = g_Cvar_Interval.FloatValue;
	g_ChangeTime = g_Cvar_ChangeTime.IntValue;
	g_RTVPostVoteAction = g_Cvar_RTVPostVoteAction.IntValue;
	bzrAllowBots = g_Cvar_AllowBots.BoolValue;
	bzrAllowSpec = g_Cvar_AllowSpec.BoolValue;

	RegConsoleCmd("sm_rtv", Command_RTV);
	RegAdminCmd("sm_forcertv", Command_ForceRTV, ADMFLAG_CHANGEMAP, "Force an RTV vote");
	RegAdminCmd("sm_disablertv", Command_DisableRTV, ADMFLAG_CHANGEMAP, "Disable the RTV command");
	RegAdminCmd("sm_enablertv", Command_EnableRTV, ADMFLAG_CHANGEMAP, "Enable the RTV command");
	RegConsoleCmd("sm_playersrtv", Command_PlayersRTV, "Count Players Online in Game");

	HookEvent("player_team", OnPlayerChangedTeam);

	AutoExecConfig(true, "rockthevote_extended");
}

public void OnMapStart()
{
	g_Voters = 0;
	g_Votes = 0;
	g_VotesNeeded = 0;
	g_InChange = false;

	/* Handle late load */
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			OnClientConnected(i);
		}
	}
}

public void OnMapEnd()
{
	g_CanRTV = false;
	g_RTVAllowed = false;
}

public void OnConfigsExecuted()
{
	g_CanRTV = true;
	g_RTVAllowed = false;

	g_Needed = g_Cvar_Needed.FloatValue;
	g_MinPlayers = g_Cvar_MinPlayers.IntValue;
	g_InitialDelay = g_Cvar_InitialDelay.FloatValue;
	g_Interval = g_Cvar_Interval.FloatValue;
	g_ChangeTime = g_Cvar_ChangeTime.IntValue;
	g_RTVPostVoteAction = g_Cvar_RTVPostVoteAction.IntValue;
	bzrAllowBots = g_Cvar_AllowBots.BoolValue;
	bzrAllowSpec = g_Cvar_AllowSpec.BoolValue;

	CreateTimer(g_InitialDelay, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnClientConnected(int client)
{
	if(IsFakeClient(client))
		return;

	g_Voted[client] = false;

	return;
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;

	if(g_Voted[client])
	{
		g_Votes--;
	}

	int i_players = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			i_players++;
		}
	}

	g_Voters = i_players;

	g_VotesNeeded = RoundToFloor(float(g_Voters) * g_Needed);

	if (!g_CanRTV)
	{
		return;
	}

	if (g_Votes &&
		g_Voters &&
		g_Votes >= g_VotesNeeded &&
		g_RTVAllowed )
	{
		if (g_RTVPostVoteAction == 1 && HasEndOfMapVoteFinished())
		{
			return;
		}

		StartRTV();
	}
}

public Action Command_PlayersRTV(int client, int arg)
{
	int i_players = 0;

	CPrintToChat(client, "{red}----------{grey}Players Count{red}----------");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			i_players++;
			CPrintToChat(client, " Online - {grey}%N {default}.", i);
		}
	}
	CPrintToChat(client, "{red}----------{grey}Players Total {red}----------");
	CPrintToChat(client, " Total Online -{grey} %i {default}.", i_players);
	CPrintToChat(client, "{red}------------------------------------");
}

public void OnPlayerChangedTeam(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_Voted[client] && !bzrAllowSpec)
	{
		g_Votes--;
	}
	if(!IsValidClient(client))
		return;

	int i_players = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			i_players++;
		}
	}

	g_Voters = i_players;

	g_VotesNeeded = RoundToFloor(float(g_Voters) * g_Needed);

	if (g_Votes &&
		g_Voters &&
		g_Votes >= g_VotesNeeded &&
		g_RTVAllowed )
	{
		if (g_RTVPostVoteAction == 1 && HasEndOfMapVoteFinished())
		{
			return;
		}

		StartRTV();
	}
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (!g_CanRTV || !client)
	{
		return;
	}

	if (strcmp(sArgs, "rtv", false) == 0 || strcmp(sArgs, "rockthevote", false) == 0)
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		AttemptRTV(client);

		SetCmdReplySource(old);
	}
}

public Action Command_RTV(int client, int args)
{
	if (!g_CanRTV || !client)
	{
		return Plugin_Handled;
	}

	AttemptRTV(client);

	return Plugin_Handled;
}

void AttemptRTV(int client)
{
	int i_players = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			i_players++;
		}
	}

	g_Voters = i_players;

	g_VotesNeeded = RoundToFloor(float(g_Voters) * g_Needed);
	
	if (!g_RTVAllowed  || (g_RTVPostVoteAction == 1 && HasEndOfMapVoteFinished()))
	{
		ReplyToCommand(client, "[SM] %t", "RTV Not Allowed");
		return;
	}

	if (!CanMapChooserStartVote())
	{
		ReplyToCommand(client, "[SM] %t", "RTV Started");
		return;
	}

	if (g_Voters < g_MinPlayers)
	{
		ReplyToCommand(client, "[SM] %t", "Minimal Players Not Met");
		return;
	}

	if (g_Voted[client])
	{
		ReplyToCommand(client, "[SM] %t", "Already Voted", g_Votes, g_VotesNeeded);
		return;
	}

	if (!IsValidClient(client))
	{
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	g_Votes++;
	g_Voted[client] = true;

	PrintToChatAll("[SM] %t", "RTV Requested", name, g_Votes, g_VotesNeeded);

	if (g_Votes >= g_VotesNeeded)
	{
		StartRTV();
	}
}

public Action Timer_DelayRTV(Handle timer)
{
	g_RTVAllowed = true;
}

void StartRTV()
{
	if (g_InChange)
	{
		return;
	}

	if (EndOfMapVoteEnabled() && HasEndOfMapVoteFinished())
	{
		/* Change right now then */
		char map[PLATFORM_MAX_PATH];
		if (GetNextMap(map, sizeof(map)))
		{
			GetMapDisplayName(map, map, sizeof(map));

			PrintToChatAll("[SM] %t", "Changing Maps", map);
			CreateTimer(5.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
			g_InChange = true;

			ResetRTV();

			g_RTVAllowed = false;
		}
		return;
	}

	if (CanMapChooserStartVote())
	{
		MapChange when = view_as<MapChange>(g_ChangeTime);
		InitiateMapChooserVote(when);

		ResetRTV();

		g_RTVAllowed = false;
		CreateTimer(g_Interval, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void ResetRTV()
{
	g_Votes = 0;

	for (int i=1; i<=MAXPLAYERS; i++)
	{
		g_Voted[i] = false;
	}
}

public Action Timer_ChangeMap(Handle hTimer)
{
	g_InChange = false;

	LogMessage("RTV changing map manually");

	char map[PLATFORM_MAX_PATH];
	if (GetNextMap(map, sizeof(map)))
	{
		ForceChangeLevel(map, "RTV after mapvote");
	}

	return Plugin_Stop;
}

public Action Command_ForceRTV(int client, int args)
{
	if(!g_CanRTV)
		return Plugin_Handled;

	ShowActivity2(client, "[RTVE] ", "%t", "Initiated Vote Map");

	StartRTV();

	return Plugin_Handled;
}

public Action Command_DisableRTV(int client, int args)
{
	if(!g_RTVAllowed)
		return Plugin_Handled;

	ShowActivity2(client, "[RTVE] ", "disabled RockTheVote.");

	g_RTVAllowed = false;

	return Plugin_Handled;
}

public Action Command_EnableRTV(int client, int args)
{
	if(g_RTVAllowed)
		return Plugin_Handled;

	ShowActivity2(client, "[RTVE] ", "enabled RockTheVote");

	g_RTVAllowed = true;

	return Plugin_Handled;
}

stock bool IsValidClient(int client)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bzrAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bzrAllowSpec && !IsPlayerAlive(client)) || (!bzrAllowSpec && IsClientObserver(client)))
		return false;
	return true;
}
