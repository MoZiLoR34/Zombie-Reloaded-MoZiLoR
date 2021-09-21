#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_EXTENSIONS
#include <zombiereloaded>
#define REQUIRE_EXTENSIONS

#pragma newdecls required

#define PLUGIN_AUTHOR "Agent Wesker & Rules of _P"
#define PLUGIN_VERSION "1.7"

//#define DEBUG

//Bit Macros thanks to https://forums.alliedmods.net/showthread.php?t=139916
#define SetBit(%1,%2)      (%1[%2>>5] |= (1<<(%2 & 31)))
#define ClearBit(%1,%2)    (%1[%2>>5] &= ~(1<<(%2 & 31)))
#define CheckBit(%1,%2)    (%1[%2>>5] & (1<<(%2 & 31)))

//Global Variables
Handle g_hFlameTimer[MAXPLAYERS+1];
ConVar g_ConVar_BurnCost;
ConVar g_ConVar_TagPenalty;
ConVar g_ConVar_TagDelay;
ConVar g_ConVar_BurnEffect;
char g_sBurnEffect[512];
float g_fBurnCost;
float g_fTagPenalty;
float g_fTagDelay;
float g_fTagTime[MAXPLAYERS+1];
bool g_bZRLoaded = false;
int g_iFlameEntity[MAXPLAYERS + 1];
int g_iStamOffset = -1;
int g_iTagged[(64 >> 5) + 1];
int g_iJumping[(64 >> 5) + 1];
int g_iBurning[(64 >> 5) + 1];

public Plugin myinfo = 
{
	name = "ZR Tagging",
	author = PLUGIN_AUTHOR,
	description = "Tagging system for CS:GO based on Rules of _P plugin",
	version = PLUGIN_VERSION,
	url = "https://steam-gamers.net/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("ZR_IsClientZombie");
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bZRLoaded = GetFeatureStatus(FeatureType_Native, "ZR_IsClientZombie") == FeatureStatus_Available;
}

public void OnPluginStart()
{

	g_iStamOffset = FindSendPropInfo("CCSPlayer", "m_flStamina");
	if (g_iStamOffset == -1)
	{	
		LogError("\"CCSPlayer::m_flStamina\" could not be found.");
		SetFailState("\"CCSPlayer::m_flStamina\" could not be found.");
	}
	
	g_ConVar_BurnCost = CreateConVar("sm_stamina_burncost", "40.0", "Stamina penalty applied when burned", 0, true, 0.0, true, 100.0);
	g_fBurnCost = GetConVarFloat(g_ConVar_BurnCost);
	HookConVarChange(g_ConVar_BurnCost, OnConVarChanged);
	
	g_ConVar_TagPenalty = CreateConVar("sm_tagging_penalty", "25.0", "Stamina penalty applied when shot", 0, true, 0.0, true, 100.0);
	g_fTagPenalty = GetConVarFloat(g_ConVar_TagPenalty);
	HookConVarChange(g_ConVar_TagPenalty, OnConVarChanged);
	
	g_ConVar_TagDelay = CreateConVar("sm_tagging_time", "1.5", "How long tagging lasts from being shot", 0, true, 0.0, true, 100.0);
	g_fTagDelay = GetConVarFloat(g_ConVar_TagDelay);
	HookConVarChange(g_ConVar_TagDelay, OnConVarChanged);
	
	g_ConVar_BurnEffect = CreateConVar("sm_tagging_burneffect", "env_fire_medium", "Particle name to simulate burning effect", 0);
	GetConVarString(g_ConVar_BurnEffect, g_sBurnEffect, sizeof(g_sBurnEffect));
	HookConVarChange(g_ConVar_BurnEffect, OnConVarChanged);
	
	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
	
	// Late load
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if (convar == g_ConVar_BurnCost) {
		g_fBurnCost = StringToFloat(newVal);
	} else if (convar == g_ConVar_TagPenalty) {
		g_fTagPenalty = StringToFloat(newVal);
	} else if (convar == g_ConVar_TagDelay) {
		g_fTagDelay = StringToFloat(newVal);
	} else if (convar == g_ConVar_BurnEffect) {
		strcopy(g_sBurnEffect, sizeof(g_sBurnEffect), newVal);
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetPlayer(client);
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetPlayer(client);
}

stock void ResetPlayer(int client)
{
	g_fTagTime[client] = 0.0;
	ClearBit(g_iTagged, client);
	ClearBit(g_iJumping, client);
	ClearBit(g_iBurning, client);
	if (g_hFlameTimer[client] != null)
	{
		KillTimer(g_hFlameTimer[client]);
		g_hFlameTimer[client] = null;
	}
	
	int entity = EntRefToEntIndex(g_iFlameEntity[client]);
	
	//Remove the particle if its valid
	if ((entity != 0) && IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public Action RemoveFire(Handle timer, any client)
{
	int entity = EntRefToEntIndex(g_iFlameEntity[client]);
	
	//Remove the particle if its valid
	if (IsValidEntity(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
	
	//Null the handle
	g_hFlameTimer[client] = null;

	//Burning is over, remove tagging
	ClearBit(g_iBurning, client);
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_hFlameTimer[i] != null)
		{
			KillTimer(g_hFlameTimer[i]);
			g_hFlameTimer[i] = null;
		}
	}
}

stock int MakeFire(int client)
{
	if (!IsValidClient(client))
		return -1;
		
	if (!IsPlayerAlive(client))
		return -1;
	
    int particle = CreateEntityByName("info_particle_system");
    
	if (!particle)
		return -1;
		
    if (IsValidEdict(particle))
    {
		char iTarget[16], sTargetname[64];
		float pOrigin[3];
		
		//Get client origin
		GetClientAbsOrigin(client, pOrigin);
		
		//Teleport particle to client origin
		TeleportEntity(particle, pOrigin, NULL_VECTOR, NULL_VECTOR);
  
		//Set targetname and effect name
		DispatchKeyValue(particle, "targetname", "burning_character");
		DispatchKeyValue(particle, "effect_name", g_sBurnEffect);
  
		//Spawn the particle
		DispatchSpawn(particle);

        //Get clients real targetname
		GetEntPropString(client, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

		//Set client to fake targetname
		Format(iTarget, sizeof(iTarget), "Client%d", client);
		DispatchKeyValue(client, "targetname", iTarget);
		
        //Set the particles parent to the client
        SetVariantString(iTarget);
        AcceptEntityInput(particle, "SetParent", particle, particle, 0);
        
        //Return client to his real targetname
        DispatchKeyValue(client, "targetname", sTargetname);
        
        //Start the animation
        ActivateEntity(particle);
        AcceptEntityInput(particle, "start");
        
        return particle;
    }
    
    return -1;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, 
		const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	//Client is not valid
	if (!IsValidClient(victim))
	{
		return;
	}

	//Fire penalty has priority over tagging
	if (damagetype & DMG_BURN)
	{
		char sWeapon[64];
		GetEntityClassname(inflictor, sWeapon, sizeof(sWeapon));
		
		//Ignited players only slow themselves
		int entOwner;
		if (StrEqual(sWeapon, "entityflame", false)) {
			entOwner = GetEntPropEnt(attacker, Prop_Send, "m_hEntAttached");
			if (entOwner != victim)
				return;
				
			if (entOwner > 0)
			{
				//Check existing flame entity
				int clientFlame = 0;
				if (g_iFlameEntity[victim] != 0)
					clientFlame = EntRefToEntIndex(g_iFlameEntity[victim]);
				
				//Get ignite time and clear the actual ignite from client
				float fireTime;
				if (IsValidEntity(inflictor))
				{
					fireTime = GetEntPropFloat(inflictor, Prop_Data, "m_flLifetime") - GetGameTime();
					SetEntPropFloat(inflictor, Prop_Data, "m_flLifetime", 0.0);
				} else
				{
					fireTime = 3.0;
				}
				
				int particle;
				if ((clientFlame != 0) && IsValidEntity(clientFlame))
				{
					particle = clientFlame;
				} else
				{
					particle = MakeFire(victim);
				}
			
				if (particle > 0)
				{
					//Override current timers
					if (g_hFlameTimer[victim] != null)
					{
						KillTimer(g_hFlameTimer[victim]);
						g_hFlameTimer[victim] = null;
					}
					g_iFlameEntity[victim] = EntIndexToEntRef(particle);
					SetBit(g_iBurning, victim);
					g_hFlameTimer[victim] = CreateTimer(fireTime, RemoveFire, victim);
				}
				
				return;
			}
		} else if (StrEqual(sWeapon, "inferno", false)) {
			//Burn damage should slow, but not molotovs
			if (g_bZRLoaded) {
				if (!ZR_IsClientZombie(victim))
					return;
			}
		}
		
		SetEntDataFloat(victim, g_iStamOffset, g_fBurnCost, true);

		return;
	}
	
	//Tagging, but only for zombies
	if ((damagetype & DMG_BULLET))
	{
		if (!IsValidClient(attacker))
		{
			return;
		}
		if (g_bZRLoaded)
		{
			if (!ZR_IsClientZombie(victim) || ZR_IsClientZombie(attacker))
			{
				return;
			}
		}
		SetBit(g_iTagged, victim);
		g_fTagTime[victim] = GetGameTime() + g_fTagDelay;
		//Don't overwrite burn slow
		//if (!CheckBit(g_iBurning, victim))
		//{
		//	SetEntDataFloat(victim, g_iStamOffset, g_fTagPenalty, true);
		//}
		return;
	}
	
	return;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	//Client is not tagged
	if (!CheckBit(g_iTagged, client) && !CheckBit(g_iBurning, client))
	{
		return Plugin_Continue;
	}

	//Client is not valid
	if (!IsValidClient(client) || !IsPlayerAlive(client))
	{
		ClearBit(g_iTagged, client);
		ClearBit(g_iBurning, client);
		return Plugin_Continue;
	}
	
	if (CheckBit(g_iBurning, client))
	{
		if (g_hFlameTimer[client] != null)
		{
			SetEntDataFloat(client, g_iStamOffset, g_fBurnCost, true);
		} else
		{
			ClearBit(g_iBurning, client);
		}
	}
	
	//Don't call this more than once
	bool onGround = IsClientOnObject(client);
	
	//Not holding jump & on the ground
	if (!(buttons & IN_JUMP) && onGround)
	{
		ClearBit(g_iJumping, client);
		
	} else if (!CheckBit(g_iJumping, client) && (buttons & IN_JUMP) && onGround)
	{
		//No jump state, holding +jump, on the ground
		SetBit(g_iJumping, client);
		SetEntDataFloat(client, g_iStamOffset, 0.0, true);
		return Plugin_Continue;
	}
	
	//Still tagged
	if (g_fTagTime[client] > GetGameTime())
	{
		//Not burning
		if (!CheckBit(g_iBurning, client))
		{
			SetEntDataFloat(client, g_iStamOffset, g_fTagPenalty, true);
		}
		return Plugin_Continue;
	}
	
	//Tagging is over, clear the bit
	ClearBit(g_iTagged, client);
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
	if ((client <= 0) || (client > MaxClients)) {
		return false;
	}
	if (!IsClientInGame(client)) {
		return false;
	}
	if (!IsPlayerAlive(client)) {
		return false;
	}
	return true;
}  

stock bool IsClientOnObject(int client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") > -1 ? true : false;
}
