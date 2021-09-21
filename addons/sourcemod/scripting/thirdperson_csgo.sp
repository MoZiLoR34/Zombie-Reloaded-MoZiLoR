/*  Thirdperson
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.6 CS:GO edition"

#pragma semicolon 1

new Third[MAXPLAYERS+1];
new Handle:gH_Enabled = INVALID_HANDLE;
new Handle:gH_Admins = INVALID_HANDLE;
new bool:gB_Enabled;
new bool:gB_Admins;

new Handle:tercera_cvar;

public Plugin:myinfo = 
{
	name = "Thirdperson",
	author = "shavit and Franc1sco franug",
	description = "Allow players/admins to toggle thirdperson on themselves/players.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
}

public OnPluginStart()
{
	new Handle:Version = CreateConVar("sm_csgothirdperson_version", PLUGIN_VERSION, "Thirdperson's version", FCVAR_NOTIFY|FCVAR_PLUGIN|FCVAR_DONTRECORD);
	SetConVarString(Version, PLUGIN_VERSION, _, true);
	
	gH_Enabled = CreateConVar("sm_thirdperson_enabled", "1", "Thirdperson's enabled?", FCVAR_PLUGIN, true, 0.0, true, 1.0);	
	gH_Admins = CreateConVar("sm_thirdperson_admins", "1", "Allow admins to toggle thirdperson to players?", FCVAR_PLUGIN, true, 0.0, true, 1.0);	
	
	gB_Enabled = true;
	gB_Admins = true;
	
	HookConVarChange(gH_Enabled, ConVarChanged);
	HookConVarChange(gH_Admins, ConVarChanged);
	
	RegConsoleCmd("sm_third", Command_TP, "Toggle thirdperson");
	RegConsoleCmd("sm_thirdperson", Command_TP, "Toggle thirdperson");
	RegConsoleCmd("sm_tp", Command_TP, "Toggle thirdperson");
	
	HookEvent("player_death", Player_Death, EventHookMode_Pre);
	HookEvent("player_spawn", Player_Spawn);
	
	LoadTranslations("common.phrases");
	
	tercera_cvar = FindConVar("sv_allow_thirdperson");
	if(tercera_cvar == INVALID_HANDLE)
		SetFailState("sv_allow_thirdperson not found!");
		
	SetConVarInt(tercera_cvar, 1);
	
	HookConVarChange(tercera_cvar, ConVarChanged);
	
	
	AutoExecConfig();
}

public ConVarChanged(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if(cvar == gH_Enabled)
	{
		gB_Enabled = StringToInt(newVal)? true:false;
	}
	
	else if(cvar == gH_Admins)
	{
		gB_Admins = StringToInt(newVal)? true:false;
	}
	else if(cvar == tercera_cvar)
	{
		if(StringToInt(newVal) != 1)
			SetConVarInt(tercera_cvar, 1);
	}
}

public Action:Command_TP(client, args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	new target = client, String:arg1[MAX_TARGET_LENGTH];
	
	GetCmdArg(1, arg1, MAX_TARGET_LENGTH);
	
	if(!gB_Enabled)
	{
		ReplyToCommand(client, " \x04[SM]\x01 Thirdperson is disabled.");
		return Plugin_Handled;
	}
	
	if(CheckCommandAccess(client, "tptarget", ADMFLAG_SLAY) && args == 1)
	{
		if(gB_Admins)
		{
			target = FindTarget(client, arg1);
			
			if(target == -1)
			{
				return Plugin_Handled;
			}
			
			if(IsValidClient(target, true))
			{
				ShowActivity(client, "toggled thirdperson to %s for the player %N", client, Third[target]? "enabled":"disabled", target);
			}
			
			else if(!IsPlayerAlive(target))
			{
				ReplyToCommand(client, " \x04[SM]\x01 The target has to be alive.");
			}
			
			return Plugin_Handled;
		}
		
		else
		{
			ReplyToCommand(client, " \x04[SM]\x01 Currently admins can't toggle thirdperson on players.");
			
			return Plugin_Handled;
		}
	}
	
	if(IsValidClient(target, true))
	{
		Toggle(target);
		ReplyToCommand(client, " \x04[SM]\x01 You are in %sperson.", Third[client]? "third":"first");
		
		return Plugin_Handled;
	}
	
	else if(!IsPlayerAlive(target))
	{
		ReplyToCommand(client, " \x04[SM]\x01 You have to be alive to toggle your thirdperson mode.");
		
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}

public Action:Player_Spawn(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(Third[client])
		ClientCommand(client, "thirdperson");
}

public Action:Player_Death(Handle:event, String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(Third[client])
		ClientCommand(client, "firstperson");
}

public OnClientPutInServer(client)
{
	Third[client] = false;
}

public Toggle(client)
{
	if(!Third[client])
	{
		ClientCommand(client, "thirdperson");
		Third[client] = true;
	}
	
	else
	{
		ClientCommand(client, "firstperson");
		Third[client] = false;
	}
}

stock bool:IsValidClient(client, bool:bAlive = false)
{
	if(client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && (bAlive == false || IsPlayerAlive(client)))
	{
		return true;
	}
	
	return false;
}