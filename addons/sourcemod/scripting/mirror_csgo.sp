/*  Mirror
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

#pragma semicolon 1
#include <sourcemod>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = {
	name		= "Mirror",
	author		= "Franc1sco franug and Nanochip",
	description = "Rotational Thirdperson View",
	version		= PLUGIN_VERSION,
	url			= "http://steamcommunity.com/id/franug"
};

bool mirror[MAXPLAYERS + 1] = { false, ... };
Handle mp_forcecamera;

public void OnPluginStart()
{
	CreateConVar("sm_mirror_version", PLUGIN_VERSION, "Mirror Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_UNLOGGED|FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	mp_forcecamera = FindConVar("mp_forcecamera");
	RegConsoleCmd("sm_mirror", Cmd_Mirror, "Toggle Rotational Thirdperson view");
}

public Action Cmd_Mirror(int client, int args)
{
	if (!IsPlayerAlive(client))
	{
		ReplyToCommand(client, "[SM] You may not use this command while dead.");
		return Plugin_Handled;
	}
	
	if (!mirror[client])
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0); 
		SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		SetEntProp(client, Prop_Send, "m_iFOV", 120);
		SendConVarValue(client, mp_forcecamera, "1");
		mirror[client] = true;
		ReplyToCommand(client, "[SM] Enabled Mirror.");
	}
	else
	{
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
		SetEntProp(client, Prop_Send, "m_iFOV", 90);
		decl String:valor[6];
		GetConVarString(mp_forcecamera, valor, 6);
		SendConVarValue(client, mp_forcecamera, valor);
		mirror[client] = false;
		ReplyToCommand(client, "[SM] Disabled Mirror.");
	}
	return Plugin_Handled;
}