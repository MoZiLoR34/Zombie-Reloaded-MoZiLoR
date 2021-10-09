#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

ConVar g_cvEnable;
ConVar g_cvShow_damage_type;
ConVar g_cvShow_damage_mode;

public Plugin myinfo = 
{
	name = "Show Damage [Multi methods]",
	author = "TheBΦ$$♚#2967",
	description = "Show damage in hint message or HUD",
	version = "1.0",
	url = "http://sourcemod.net"
};

public void OnPluginStart()
{
	LoadTranslations("Simple_Show_Damage.phrases");

	g_cvEnable = CreateConVar("sm_show_damage_enable", "1", "Enable/Disable plugin?");
	g_cvShow_damage_type = CreateConVar("sm_show_damage_type", "0", "0 = Show damage in Hint message\n1 = Show damage in HUD message");
	g_cvShow_damage_mode = CreateConVar("sm_show_damage_mode", "0", "0 = Show damage to victim only\n1 = Show damage and remaining health of victim");

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	AutoExecConfig(true, "Simple_Show_Damage");
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int health = event.GetInt("health");
	int damage = event.GetInt("dmg_health");

	if (g_cvEnable.BoolValue)
	{
		if (IsValidClient(attacker) && attacker != victim && victim != 0)
		{
			if (!g_cvShow_damage_type.BoolValue)
			{
				if (!g_cvShow_damage_mode.BoolValue)
					PrintHintText(attacker, "%t <font color='#FF0000'>%i</font> %t <font color='#3DB1FF'>%N", "Damage Giver", damage, "Damage Taker", victim);
				else
					PrintHintText(attacker, "%t <font color='#FF0000'>%i</font> %t <font color='#3DB1FF'>%N</font>\n %t <font color='#00FF00'>%i</font>", "Damage Giver", damage, "Damage Taker", victim, "Health Remaining", health);
			}
			else
			{
				if (!g_cvShow_damage_mode.BoolValue)
				{
					if (health > 50)
						SetHudTextParams(-1.0, 0.45, 1.3, 0, 253, 30, 200, 1); // green
					else if ((health <= 50) && (health > 20))
						SetHudTextParams(-1.0, 0.45, 1.3, 253, 229, 0, 200, 1); // yellow
					else
						SetHudTextParams(-1.0, 0.45, 1.3, 255, 0, 0, 200, 1); // red
					ShowHudText(attacker, -1, "%i", damage);
				}
				else
				{
					if (health > 50)
						SetHudTextParams(0.43, 0.45, 1.3, 0, 253, 30, 200, 1); // green
					else if ((health <= 50) && (health > 20))
						SetHudTextParams(0.43, 0.45, 1.3, 253, 229, 0, 200, 1); // yellow
					else
						SetHudTextParams(0.43, 0.45, 1.3, 255, 0, 0, 200, 1); // red
					ShowHudText(attacker, -1, "%i", health);
	
					SetHudTextParams(0.57, 0.45, 1.3, 255, 255, 255, 200, 1); // white
					ShowHudText(attacker, -1, "%i", damage);
				}
			}
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

bool IsValidClient(int client)
{
	if (!(0 < client <= MaxClients)) return false;
	if (!IsClientInGame(client)) return false;
	return true;
}