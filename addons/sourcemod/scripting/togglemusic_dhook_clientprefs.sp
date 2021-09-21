#pragma semicolon 1
//#undef REQUIRE_PLUGIN
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <clientprefs>
#include <regex>
#include <csgocolors>

#define PLUGIN_VERSION "3.7.9-A"

//Create ConVar handles
Handle g_hClientCookie = INVALID_HANDLE;
Handle g_hClientVolCookie;
Handle g_hClientMusicCookie;
Handle hAcceptInput;
Regex regPattern;
RegexError regError;
ConVar g_ConVar_Debug;

//Global Handles & Variables
float g_fCmdTime[MAXPLAYERS + 1];
float g_fClientVol[MAXPLAYERS + 1];
bool g_bDisabled[MAXPLAYERS + 1];
int randomChannel;
int g_iDebug;
StringMap g_smSourceEnts;
StringMap g_smChannel;
StringMap g_smCommon;
StringMap g_smRecent;
StringMap g_smVolume;
bool g_bStopSound[MAXPLAYERS+1]; bool g_bHooked;

public Plugin myinfo = 
{
	name = "Toggle Music Sounds", 
	author = "Mitch, Agent Wesker, Anubis.", 
	description = "Allows clients to toggle ambient sounds played by the map", 
	version = PLUGIN_VERSION, 
	url = "https://www.steam-gamers.net/"
};

public void OnPluginStart()
{
	LoadTranslations("togglemusic_dhook.phrases");
	
	g_hClientCookie = RegClientCookie("sm_stopsound", "Toggle hearing weapon sounds", CookieAccess_Private);
	SetCookieMenuItem(StopSoundCookieHandler, g_hClientCookie, "Toggle Weapon Sounds");
	
	CreateConVar("sm_togglemusic_version", PLUGIN_VERSION, "Toggle Map Music Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	RegConsoleCmd("sm_stopsound", Command_StopSound, "Toggle hearing weapon sounds");
	RegConsoleCmd("sm_music", Command_Music, "Toggles map music");
	RegConsoleCmd("sm_stopmusic", Command_StopMusic, "Toggles map music");
	RegConsoleCmd("sm_volume", Command_Volume, "Brings volume menu");
	
	g_ConVar_Debug = CreateConVar("sm_togglemusic_debug", "0", "Debug mode (0 = off, 1 = on)", 0, true, 0.0, true, 1.0);
	g_iDebug = GetConVarInt(g_ConVar_Debug);
	HookConVarChange(g_ConVar_Debug, OnConVarChanged);
	
	if (g_smSourceEnts == null)
		g_smSourceEnts = new StringMap();
		
	if (g_smChannel == null)
		g_smChannel = new StringMap();
		
	if (g_smCommon == null)
		g_smCommon = new StringMap();
		
	if (g_smRecent == null)
		g_smRecent = new StringMap();
		
	if (g_smVolume == null)
		g_smVolume = new StringMap();
		
	if (g_hClientVolCookie == null)
		g_hClientVolCookie = RegClientCookie("togglemusic_volume", "ToggleMusic Volume Pref", CookieAccess_Protected);
		
	if (g_hClientMusicCookie == null)
		g_hClientMusicCookie = RegClientCookie("togglemusic_music", "ToggleMusic Music Pref", CookieAccess_Protected);
		
	char preError[256];
	char prePattern[256] = "(([-_a-zA-Z0-9]+[/]?)+[.][a-zA-Z0-9]{3})";
	regPattern = CompileRegex(prePattern, PCRE_CASELESS, preError, sizeof(preError), regError);
	if (regError != REGEX_ERROR_NONE)
		LogError(preError);
		
	if (hAcceptInput == null)
	{
		
		EngineVersion eVer = GetEngineVersion();
		char tmpOffset[148];
		
		if (eVer == Engine_CSGO) {
			tmpOffset = "sdktools.games\\engine.csgo";
			AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
			}
		else if (eVer == Engine_CSS) {
			tmpOffset = "sdktools.games\\engine.css";
			AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
			}
		else if (eVer == Engine_TF2) {
			tmpOffset = "sdktools.games\\engine.tf";
			AddTempEntHook("Shotgun Shot", DODS_Hook_FireBullets);
			}
		else if (eVer == Engine_Contagion) {
			tmpOffset = "sdktools.games\\engine.contagion";
			AddTempEntHook("Shotgun Shot", DODS_Hook_FireBullets);
			}
		else if (eVer == Engine_Left4Dead2) {
			tmpOffset = "sdktools.games\\engine.Left4Dead2";
			AddTempEntHook("Shotgun Shot", DODS_Hook_FireBullets);
			}
		else if (eVer == Engine_AlienSwarm) {
			tmpOffset = "sdktools.games\\engine.swarm";
			AddTempEntHook("Shotgun Shot", DODS_Hook_FireBullets);
			}
		// TF2/HL2:DM and misc weapon sounds will be caught here.
		AddNormalSoundHook(Hook_NormalSound);
		Handle temp = LoadGameConfigFile(tmpOffset);
		
		if (temp == null)
			SetFailState("Gamedata Missing!");
			
		if (eVer == Engine_CSGO)
			HookEvent("round_poststart", Event_RoundStarted_CSGO); // CSGO Only
			
		else
			HookEvent("round_start", Event_RoundStarted); // Supported on all Games
			
		int offset = GameConfGetOffset(temp, "AcceptInput");
		hAcceptInput = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, AcceptInput);
		DHookAddParam(hAcceptInput, HookParamType_CharPtr);
		DHookAddParam(hAcceptInput, HookParamType_CBaseEntity);
		DHookAddParam(hAcceptInput, HookParamType_CBaseEntity);
		DHookAddParam(hAcceptInput, HookParamType_Object, 20);
		DHookAddParam(hAcceptInput, HookParamType_Int);
		
		delete temp;
	}
	
	//Set volume level to default (late load)
	for (int j = 1; j <= MaxClients; j++)
		OnClientPostAdminCheck(j);
}

public StopSoundCookieHandler(client, CookieMenuAction:action, any:info, char []buffer, maxlen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
		}
		
		case CookieMenuAction_SelectOption:
		{
			if(CheckCommandAccess(client, "sm_stopsound", 0))
			{
				makeMusicMenu(client);
			}
			else
			{
				ReplyToCommand(client, "[SM] You have no access!");
			}
		}
	}
}

public void OnConVarChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if (convar == g_ConVar_Debug)
		g_iDebug = StringToInt(newVal);
}

public void OnMapStart()
{
	g_smSourceEnts.Clear();
	g_smChannel.Clear();
	g_smCommon.Clear();
	g_smRecent.Clear();
	g_smVolume.Clear();
	randomChannel = SNDCHAN_USER_BASE - 75;
}

public Event_RoundStarted_CSGO(Event event, const char[] name, bool dontBroadcast)
{
	SetVolumeRoundstart();
}

public Event_RoundStarted(Event event, const char[] name, bool dontBroadcast)
{
	LoopTillFullyLoaded(INVALID_HANDLE);
}

public Action LoopTillFullyLoaded(Handle hTimer)
{
	if(1 > GetGameTime()) // Fix for Crashes on older Engines
	{
		CreateTimer(1.0, LoopTillFullyLoaded, INVALID_HANDLE, TIMER_DATA_HNDL_CLOSE | TIMER_FLAG_NO_MAPCHANGE);
		return;
	}
	
	else
		SetVolumeRoundstart();
}

public void SetVolumeRoundstart()
{
	g_smRecent.Clear();
	g_smVolume.Clear();
	//snd_setsoundparam was patched out of CS:GO
}

public void OnClientCookiesCached(int client)
{
	OnClientPostAdminCheck(client);
	g_fCmdTime[client] = 0.0;
	if (g_bDisabled[client])
		CreateTimer(15.0, ClientMusicNotice, client);
}

public void OnClientPostAdminCheck(int client)
{
	if (AreClientCookiesCached(client))
	{
		char sCookieValue[12];
		char sValue[8];
		GetClientCookie(client, g_hClientVolCookie, sCookieValue, sizeof(sCookieValue));
		GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
		g_bStopSound[client] = (sValue[0] != '\0' && StringToInt(sValue));

		if (sCookieValue[0])
			g_fClientVol[client] = StringToFloat(sCookieValue);

		else
			g_fClientVol[client] = 1.0;

		sCookieValue = "";
		GetClientCookie(client, g_hClientMusicCookie, sCookieValue, sizeof(sCookieValue));
		if (sCookieValue[0])
		{
			if (StringToInt(sCookieValue) > 0)
			{
				g_bDisabled[client] = true;
				
			}

			else
				g_bDisabled[client] = false;
				
		}

		else
			g_bDisabled[client] = false;

		CheckHooks();
		return;
	}
	g_fClientVol[client] = 1.0;
	g_bDisabled[client] = false;
}

public OnClientDisconnect_Post(client)
{
	g_bStopSound[client] = false;
	CheckHooks();
}

public Action ClientMusicNotice(Handle timer, int client)
{
	if (IsClientInGame(client))
		CPrintToChat(client, "%t", "Chat_Notice");
}

//Return types
//https://wiki.alliedmods.net/Sourcehook_Development#Hook_Functions
//
public MRESReturn AcceptInput(int entity, Handle hReturn, Handle hParams)
{
	//Abort if the entity is missing
	if (!IsValidEntity(entity)) { return MRES_Ignored; }
	
	char eClassname[128], eCommand[128], eParam[128], soundFile[PLATFORM_MAX_PATH];
	int eActivator;
	
	DHookGetParamString(hParams, 1, eCommand, sizeof(eCommand));
	
	int type, iParam = -1;
	type = DHookGetParamObjectPtrVar(hParams, 4, 16, ObjectValueType_Int);
	
	if (type == 1)
	{
		iParam = RoundFloat(DHookGetParamObjectPtrVar(hParams, 4, 0, ObjectValueType_Float));
	} else if (type == 2)
	{
		DHookGetParamObjectPtrString(hParams, 4, 0, ObjectValueType_String, eParam, sizeof(eParam));
		StringToIntEx(eParam, iParam);
	}
	
	if (!DHookIsNullParam(hParams, 2)) {
		eActivator = DHookGetParam(hParams, 2);
		if (eActivator < -1) { eActivator = -1; }
	} else { eActivator = -1; }
	
	GetEntityClassname(entity, eClassname, sizeof(eClassname));
	
	if (StrEqual(eClassname, "point_clientcommand", false)) {
		//Don't allow client sounds to override this plugin
		if ((StrContains(eParam, ".mp3", false) != -1) || (StrContains(eParam, ".wav", false) != -1))
		{
			int matchCount = MatchRegex(regPattern, eParam, regError);
			if (matchCount > 0) {
				if (GetRegexSubString(regPattern, 0, soundFile, sizeof(soundFile))) {
					AddToStringTable(FindStringTable("soundprecache"), FakePrecacheSound(soundFile, true));
					PrecacheSound(FakePrecacheSound(soundFile, true), false);
					ClientSendSound(soundFile, eActivator, true);
				}
			}
			DHookSetReturn(hReturn, false);
			return MRES_Supercede;
		}
		return MRES_Ignored;
	}
	
	GetEntPropString(entity, Prop_Data, "m_iszSound", soundFile, sizeof(soundFile));
	int eFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
	if (g_iDebug == 1) {
		char eName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", eName, sizeof(eName));
		PrintToServer("Cmd %s Name %s Activator %i Param %s Song %s", eCommand, eName, eActivator, eParam, soundFile);
		PrintToChatAll("Cmd %s Name %s Activator %i Param %s Song %s", eCommand, eName, eActivator, eParam, soundFile);
	}
	
	if (StrEqual(eCommand, "PlaySound", false) || StrEqual(eCommand, "FadeIn", false) || (StrEqual(eCommand, "Volume", false) && (iParam > 0)) || StrEqual(eCommand, "ToggleSound", false))
	{
		int temp;
		bool common = g_smCommon.GetValue(soundFile, temp);
		
		if (!((StrContains(soundFile, ".mp3", false) != -1) || (StrContains(soundFile, ".wav", false) != -1))) {
			//Workaround for client soundscripts (?)
			return MRES_Ignored;
		}
		
		if (eFlags & 1)
		{
			int curVol;
			if (g_smVolume.GetValue(soundFile, curVol) && (StrEqual(eCommand, "Volume", false) || StrEqual(eCommand, "ToggleSound", false)))
			{
				if ((curVol != iParam) && StrEqual(eCommand, "Volume", false))
				{
					//Different volume but already playing? Ignore
					DHookSetReturn(hReturn, false);
					return MRES_Supercede;
				} else if (StrEqual(eCommand, "ToggleSound", false)) {
					//Sound was played already, so toggle the sound off
					g_smVolume.Remove(soundFile);
					StopSoundAll(soundFile, entity, common);
					DHookSetReturn(hReturn, false);
					return MRES_Supercede;
				}
			} else {
				if (StrEqual(eCommand, "PlaySound", false) || StrEqual(eCommand, "ToggleSound", false))
				{
					g_smVolume.SetValue(soundFile, 10, true);
				} else if (StrEqual(eCommand, "Volume", false))
				{
					g_smVolume.SetValue(soundFile, iParam, true);
				}
			}
		}
		
		if (g_smRecent.GetValue(soundFile, temp))
		{
			g_smRecent.Remove(soundFile);
			g_smCommon.SetValue(soundFile, 1, true);
			common = true;
			AddToStringTable(FindStringTable("soundprecache"), FakePrecacheSound(soundFile, true));
			PrecacheSound(FakePrecacheSound(soundFile, true), false);
			//Debug vv
			//PrintToServer("COMMON SOUND DETECTED %s", soundFile);
		} else {
			AddToStringTable(FindStringTable("soundprecache"), FakePrecacheSound(soundFile, common));
			PrecacheSound(FakePrecacheSound(soundFile, common), false);
		}
		
		//Debug vv
		//int customChannel;
		//g_smChannel.GetValue(soundFile, customChannel);
		//PrintToServer("Cmd %s Name %s Param %s Channel %i Song %s", eCommand, eName, eParam, customChannel, FakePrecacheSound(soundFile, common));
		
		SendSoundAll(soundFile, entity, common);
		
		if (!common && !(eFlags & 1))
		{
			g_smRecent.SetValue(soundFile, 1, true);
			DataPack dataPack;
			CreateDataTimer(0.6, CheckCommonSounds, dataPack);
			dataPack.WriteString(soundFile);
			dataPack.WriteCell(entity);
		}
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	}
	else if (StrEqual(eCommand, "StopSound", false) || StrEqual(eCommand, "FadeOut", false) || (StrEqual(eCommand, "Volume", false) && (iParam == 0)))
	{
		int temp;
		bool common = g_smCommon.GetValue(soundFile, temp);
		StopSoundAll(soundFile, entity, common);
		
		if (eFlags & 1)
		{
			g_smVolume.Remove(soundFile);
		}
		
		return MRES_Ignored;
	}
	
	return MRES_Ignored;
}

public int GetSourceEntity(int entity)
{
	char seName[64];
	GetEntPropString(entity, Prop_Data, "m_sSourceEntName", seName, sizeof(seName));
	if (seName[0])
	{
		int entRef;
		if (g_smSourceEnts.GetValue(seName, entRef))
		{
			int sourceEnt = EntRefToEntIndex(entRef);
			if (IsValidEntity(sourceEnt))
			{
				return sourceEnt;
			}
		}
	}
	return entity;
}

public Action CheckCommonSounds(Handle timer, DataPack dataPack)
{
	dataPack.Reset();
	char soundFile[PLATFORM_MAX_PATH];
	dataPack.ReadString(soundFile, sizeof(soundFile));
	g_smRecent.Remove(soundFile);
	int temp;
	if (g_smCommon.GetValue(soundFile, temp))
	{
		temp = dataPack.ReadCell();
		StopSoundAll(soundFile, temp, false);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "ambient_generic", false))
	{
		//Is this a valid entity?
		if (IsValidEdict(entity))
		{
			//Hook the entity, we must wait until post spawn
			DHookEntity(hAcceptInput, false, entity);
			SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
		}
	} else if (StrEqual(classname, "point_clientcommand", false)) {
		//Is this a valid entity?
		if (IsValidEntity(entity))
		{
			DHookEntity(hAcceptInput, false, entity);
		}
	}
}

public void OnEntitySpawned(int entity)
{
	char seName[64], eName[64];
	if(HasEntProp(entity, Prop_Data, "m_sSourceEntName")) {
		GetEntPropString(entity, Prop_Data, "m_sSourceEntName", seName, sizeof(seName));
		int eFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		
		if (!(eFlags & 1) && seName[0])
		{
			for (int i = 0; i <= GetEntityCount(); i++)
			{
				if (IsValidEntity(i))
				{
					GetEntPropString(i, Prop_Data, "m_iName", eName, sizeof(eName));
					if (StrEqual(seName, eName, false))
					{
						g_smSourceEnts.SetValue(seName, EntIndexToEntRef(i), true);
						
					}
				}
			}
		}
	}
}

public Action Command_Music(int client, any args)
{
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;
	
	makeMusicMenu(client);
	
	g_fCmdTime[client] = GetGameTime() + 1.5;
	
	return Plugin_Handled;
}

public Action Command_StopMusic(int client, any args)
{
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;
	
	if(AreClientCookiesCached(client))
	{
		MusicToggle(client);
	}
	else
	{
		ReplyToCommand(client, "[SM] Your Cookies are not yet cached. Please try again later...");
	}

	g_fCmdTime[client] = GetGameTime() + 1.5;
	
	return Plugin_Handled;
}

public Action Command_StopSound(int client, any args)
{
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;

	if(AreClientCookiesCached(client))
	{
		WeponsToggle(client);
	}
	else
	{
		ReplyToCommand(client, "[SM] Your Cookies are not yet cached. Please try again later...");
	}

	g_fCmdTime[client] = GetGameTime() + 1.5;

	return Plugin_Handled;
}

public Action Command_Volume(int client, any args)
{
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;
	
	makeVolumeMenu(client);
	
	g_fCmdTime[client] = GetGameTime() + 1.5;
	
	return Plugin_Handled;
}

static void makeMusicMenu(int client)
{
	// Create menu handle.
	new Handle:musicMenu = CreateMenu(Music_Menu);

	int cookievalue = GetIntCookie(client, g_hClientCookie);

	// Make client global translations target.
	SetGlobalTransTarget(client);

	decl String:title[256];
	decl String:musicmap_sounds[32];
	decl String:mapvolume[32];
	decl String:weapons_sounds[32];

	// Translate each line into client's language.
	Format(title, sizeof(title), "%t\n ", "Title_Stop_Sounds");

	//Menu Variavel
	if (g_bDisabled[client] == true)
	{
		Format(musicmap_sounds, sizeof(musicmap_sounds), "%t %t", "Musicmap_Sounds", "OFF"); //Off
	}
	if (g_bDisabled[client] == false)
	{
		Format(musicmap_sounds, sizeof(musicmap_sounds), "%t %t", "Musicmap_Sounds", "ON"); //On
	}
	if(cookievalue == 1)
	{
		Format(weapons_sounds, sizeof(weapons_sounds), "%t %t", "WeaponsSounds", "OFF"); //Off
	}
	if(cookievalue == 0)
	{
		Format(weapons_sounds, sizeof(weapons_sounds), "%t %t", "WeaponsSounds", "ON"); //On
	}

	Format(mapvolume, sizeof(mapvolume), "%t %i%", "Map_volume", RoundFloat(g_fClientVol[client] * 100));

	// Add items to menu.
	SetMenuTitle(musicMenu, title);
	AddMenuItem(musicMenu, "musicmap_sounds", musicmap_sounds);
	AddMenuItem(musicMenu, "weapons_sounds", weapons_sounds);
	AddMenuItem(musicMenu, "mapvolume", mapvolume);

	// Create a "Back" button to the main menu.
	SetMenuExitButton(musicMenu, true);

	// Display menu to client.
	DisplayMenu(musicMenu, client, 20);
}

public int Music_Menu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select && IsValidClient(client))
	{
		if (param == 0)
		{
			MusicToggle(client);
			makeMusicMenu(client);
		}
		else if (param == 1) {
			WeponsToggle(client);
			makeMusicMenu(client);
		}
		else if (param == 2) {
			makeVolumeMenu(client);
			return;
		}
	}
	else if (action == MenuAction_End)
	{
		delete(menu);
	}
}

static void makeVolumeMenu(int client)
{
	// Create menu handle.
	new Handle:volumeMenu = CreateMenu(Volume_Menu);
	
	// Make client global translations target.
	SetGlobalTransTarget(client);
	
	decl String:volumemenutitle[256];
	decl String:v100[32];
	decl String:v75[32];
	decl String:v50[32];
	decl String:v25[32];
	decl String:v10[32];
	decl String:v05[32];
	
		
	// Translate each line into client's language.
	Format(volumemenutitle, sizeof(volumemenutitle), "%t\n%t %i%t\n ", "Volume Menu Title", "Map_volume", RoundFloat(g_fClientVol[client] * 100), "Porcento");
	Format(v100, sizeof(v100), "%t", "v100");
	Format(v75, sizeof(v75), "%t", "v75");
	Format(v50, sizeof(v50), "%t", "v50");
	Format(v25, sizeof(v25), "%t", "v25");
	Format(v10, sizeof(v10), "%t", "v10");
	Format(v05, sizeof(v05), "%t", "v05");
	
	// Add items to menu.
	SetMenuTitle(volumeMenu, volumemenutitle);
	AddMenuItem(volumeMenu, "100", v100);
	AddMenuItem(volumeMenu, "75", v75);
	AddMenuItem(volumeMenu, "50", v50);
	AddMenuItem(volumeMenu, "25", v25);
	AddMenuItem(volumeMenu, "10", v10);
	AddMenuItem(volumeMenu, "5", v05);

	// Create a "Back" button to the main menu.
	SetMenuExitBackButton(volumeMenu, true);

	// Display menu to client.
	DisplayMenu(volumeMenu, client, 20);
}

public int Volume_Menu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select && IsValidClient(client))
	{
		if (param == 0)
		{
			g_fClientVol[client] = 1.0;
		}
		else if (param == 1)
		{
			g_fClientVol[client] = 0.75;
		}
		else if (param == 2)
		{
			g_fClientVol[client] = 0.5;
		}
		else if (param == 3)
		{
			g_fClientVol[client] = 0.25;
		}
		else if (param == 4)
		{
			g_fClientVol[client] = 0.1;
		}
		else if (param == 5)
		{
			g_fClientVol[client] = 0.05;
		}
		
		char sCookieValue[12];
		FloatToString(g_fClientVol[client], sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, g_hClientVolCookie, sCookieValue);

		PrintCenterText(client, "%t %i%", "Center_Volume_Set", RoundFloat(g_fClientVol[client] * 100));
		CPrintToChat(client, "%t %i%", "Chat_Volume_Set", RoundFloat(g_fClientVol[client] * 100));
		
		
	}
	else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack && IsValidClient(client))
	{
		makeMusicMenu(client);
	}
	else if (action == MenuAction_End)
	{
		delete(menu);
	}
}

stock void SendSoundAll(char[] name, int entity, bool common = false)
{
	if (IsValidEntity(entity))
	{
		int eFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		
		if (eFlags & 1)
		{
			int customChannel;
			
			if (!g_smChannel.GetValue(name, customChannel))
			{
				g_smChannel.SetValue(name, randomChannel, false);
				customChannel = randomChannel;
				randomChannel++;
				if (randomChannel > SNDCHAN_USER_BASE)
				{
					randomChannel = SNDCHAN_USER_BASE - 75;
				}
			}
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!g_bDisabled[i] && IsValidClient(i))
				{
					EmitSoundToClient(i, FakePrecacheSound(name, common), i, customChannel, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fClientVol[i], SNDPITCH_NORMAL, -1, _, _, true);
				}
			}
		} else {
			int sourceEnt = GetSourceEntity(entity);
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!g_bDisabled[i] && IsValidClient(i))
				{
					EmitSoundToClient(i, FakePrecacheSound(name, common), sourceEnt, SNDCHAN_USER_BASE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fClientVol[i], SNDPITCH_NORMAL, -1, _, _, true);
				}
			}
		}
	}
}

stock void ClientSendSound(char[] name, int client, bool common = false)
{
	if (!IsValidClient2(client)) { return; }
	
	int customChannel;
	
	if (!g_smChannel.GetValue(name, customChannel))
	{
		g_smChannel.SetValue(name, randomChannel, false);
		customChannel = randomChannel;
		randomChannel++;
		if (randomChannel > SNDCHAN_USER_BASE)
		{
			randomChannel = SNDCHAN_USER_BASE - 75;
		}
	}
	
	if (!g_bDisabled[client])
	{
		EmitSoundToClient(client, FakePrecacheSound(name, common), client, customChannel, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fClientVol[client], SNDPITCH_NORMAL, -1, _, _, true);
	}
}

stock void ClientStopSound(int client, char[] name = "", bool common = false)
{
	if (name[0]) {
		int customChannel;
		if (g_smChannel.GetValue(name, customChannel))
		{
			StopSound(client, customChannel, FakePrecacheSound(name, common));
		} else
		{
			StopSound(client, SNDCHAN_USER_BASE, FakePrecacheSound(name, common));
		}
	} else {
		ClientCommand(client, "playgamesound Music.StopAllExceptMusic");
		ClientCommand(client, "playgamesound Music.StopAllMusic");
	}
}

stock static void StopSoundAll(char[] name, int entity, bool common = false)
{
	if (IsValidEntity(entity))
	{
		int eFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		if (eFlags & 1)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!g_bDisabled[i] && IsValidClient(i)) {
					ClientStopSound(i, name, common);
				}
			}
		}
		else
		{
			int sourceEnt = GetSourceEntity(entity);
			StopSound(sourceEnt, SNDCHAN_USER_BASE, FakePrecacheSound(name, common));
		}
	}
}

stock static char[] FakePrecacheSound(const char[] sample, const bool common = false)
{
	char szSound[PLATFORM_MAX_PATH];
	strcopy(szSound, sizeof(szSound), sample);
	if (common)
	{
		if (szSound[0] != '*')
		{
			if (szSound[0] == '#')
			{
				Format(szSound, sizeof(szSound), "*%s", szSound[1]);
			} else
			{
				Format(szSound, sizeof(szSound), "*%s", szSound);
			}
		}
	} else
	{
		if (szSound[0] == '*')
		{
			Format(szSound, sizeof(szSound), "%s", szSound[1]);
		}
		if (szSound[0] == '#')
		{
			Format(szSound, sizeof(szSound), "%s", szSound[1]);
		}
	}
	return szSound;
}

stock static bool IsValidClient(int client) {
	if (!IsClientInGame(client)) {
		return false;
	}
	return true;
}

stock bool IsValidClient2(int client)
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

// Part of Teamgames-stocks.inc

stock RequestFrame2(RequestFrameCallback:func, framesAhead = 1, any:data = 0)
{
	if (framesAhead < 1)
		return;

	if (framesAhead == 1) {
		RequestFrame(func, data);
	} else {
		new Handle:pack = CreateDataPack();
#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 7
		WritePackFunction(pack, func);
#else
		WritePackCell(pack, func);
#endif
		WritePackCell(pack, framesAhead);
		WritePackCell(pack, data);

		RequestFrame(RequestFrame2_CallBack, pack);
	}
}

public RequestFrame2_CallBack(any:pack)
{
	ResetPack(Handle:pack);
#if SOURCEMOD_V_MAJOR >= 1 && SOURCEMOD_V_MINOR >= 7
	new RequestFrameCallback:func = RequestFrameCallback:ReadPackFunction(Handle:pack);
#else
	new RequestFrameCallback:func = RequestFrameCallback:ReadPackCell(Handle:pack);
#endif
	new framesAhead = ReadPackCell(Handle:pack) - 1;
	new data = ReadPackCell(Handle:pack);
	CloseHandle(Handle:pack);

	RequestFrame2(func, framesAhead, data);
}

CheckHooks()
{
	bool bShouldHook = false;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_bStopSound[i])
		{
			bShouldHook = true;
			break;
		}
	}
	
	// Fake (un)hook because toggling actual hooks will cause server instability.
	g_bHooked = bShouldHook;
}

public Action Hook_NormalSound(clients[64], &numClients, char sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	// Ignore non-weapon sounds.
	if (!g_bHooked || !(strncmp(sample, "weapons", 7) == 0 || strncmp(sample[1], "weapons", 7) == 0))
		return Plugin_Continue;
	
	int i, j;
	
	for (i = 0; i < numClients; i++)
	{
		if (g_bStopSound[clients[i]])
		{
			// Remove the client from the array.
			for (j = i; j < numClients-1; j++)
			{
				clients[j] = clients[j+1];
			}
			
			numClients--;
			i--;
		}
	}
	
	return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
}

public Action CSS_Hook_ShotgunShot(const char []te_name, const Players[], numClients, float delay)
{
	if (!g_bHooked)
		return Plugin_Continue;
	
	// Check which clients need to be excluded.
	decl newClients[MaxClients], client, i;
	int newTotal = 0;
	
	for (i = 0; i < numClients; i++)
	{
		client = Players[i];
		
		if (!g_bStopSound[client])
		{
			newClients[newTotal++] = client;
		}
	}
	
	// No clients were excluded.
	if (newTotal == numClients)
		return Plugin_Continue;
	
	// All clients were excluded and there is no need to broadcast.
	else if (newTotal == 0)
		return Plugin_Stop;
	
	// Re-broadcast to clients that still need it.
	float vTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(newClients, newTotal, delay);
	
	return Plugin_Stop;
}

public Action DODS_Hook_FireBullets(const char []te_name, const Players[], numClients, float delay)
{
	if (!g_bHooked)
		return Plugin_Continue;
	
	// Check which clients need to be excluded.
	decl newClients[MaxClients], client, i;
	int newTotal = 0;
	
	for (i = 0; i < numClients; i++)
	{
		client = Players[i];
		
		if (!g_bStopSound[client])
		{
			newClients[newTotal++] = client;
		}
	}
	
	// No clients were excluded.
	if (newTotal == numClients)
		return Plugin_Continue;
	
	// All clients were excluded and there is no need to broadcast.
	else if (newTotal == 0)
		return Plugin_Stop;
	
	// Re-broadcast to clients that still need it.
	float vTemp[3];
	TE_Start("FireBullets");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
	TE_WriteFloat("m_flSpread", TE_ReadFloat("m_flSpread"));
	TE_Send(newClients, newTotal, delay);
	
	return Plugin_Stop;
}

int GetIntCookie(int client, Handle handle)
{
    char sCookieValue[12];
    GetClientCookie(client, handle, sCookieValue, sizeof(sCookieValue));
    return StringToInt(sCookieValue);
}

MusicToggle(client)
{
	// Get the cookie value.	
	int Musicstate = GetIntCookie(client, g_hClientMusicCookie);
	
	// Make client global translations target.
	SetGlobalTransTarget(client);

	if (Musicstate == 0)
	{
	// Toggle the value.
		g_bDisabled[client] = true;
		char sCookieValue[12];
		IntToString(1, sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, g_hClientMusicCookie, sCookieValue);
		CPrintToChat(client, "%t %t", "ChatMusicMapSounds", "C_OFF");
		PrintCenterText(client, "%t %t", "CenterMusicMapSounds", "OFF");
		if (g_bDisabled[client])
		{
			ClientStopSound(client);
		}
		return true;
	}	
	if (Musicstate == 1)
	{
	// Toggle the value.
		g_bDisabled[client] = false;
		char sCookieValue[12];
		IntToString(0, sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, g_hClientMusicCookie, sCookieValue);
		CPrintToChat(client, "%t %t", "ChatMusicMapSounds", "C_ON");
		PrintCenterText(client, "%t %t", "CenterMusicMapSounds", "ON");
		return true;
	}
	return true;
}

WeponsToggle(client)
{
	// Get the cookie value.
	int Wpstate = GetIntCookie(client, g_hClientCookie);
	
	// Make client global translations target.
	SetGlobalTransTarget(client);

	if (Wpstate == 0)
	{
	// Toggle the value.
		SetClientCookie(client, g_hClientCookie, "1");
		OnClientCookiesCached(client);
		CPrintToChat(client, "%t %t", "ChatWeaponsSounds", "C_OFF");
		PrintCenterText(client, "%t %t", "CenterWeaponsSounds", "OFF");
		CheckHooks();
		return true;
	}	
	if (Wpstate == 1)
	{
	// Toggle the value.
		SetClientCookie(client, g_hClientCookie, "0");
		OnClientCookiesCached(client);
		CPrintToChat(client, "%t %t", "ChatWeaponsSounds", "C_ON");
		PrintCenterText(client, "%t %t", "CenterWeaponsSounds", "ON");
		CheckHooks();
		return true;
	}
	return true;
}