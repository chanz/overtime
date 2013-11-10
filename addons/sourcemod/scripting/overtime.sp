/***************************************************************************************

	Copyright (C) 2012 BCServ (plugins@bcserv.eu)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
***************************************************************************************/

/***************************************************************************************


	C O M P I L E   O P T I O N S


***************************************************************************************/
// enforce semicolons after each code statement
#pragma semicolon 1

/***************************************************************************************


	P L U G I N   I N C L U D E S


***************************************************************************************/
#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <smlib/pluginmanager>


/***************************************************************************************


	P L U G I N   I N F O


***************************************************************************************/
public Plugin:myinfo = {
	name 						= "Overtime",
	author 						= "Chanz",
	description 				= "Extends the time limit before it reaches 0.0, if the game is a tie/draw",
	version 					= "1.1",
	url 						= "http://bcserv.eu/"
}

/***************************************************************************************


	P L U G I N   D E F I N E S


***************************************************************************************/


/***************************************************************************************


	G L O B A L   V A R S


***************************************************************************************/
// Server Variables


// Plugin Internal Variables


// Console Variables
new Handle:g_cvarEnable = INVALID_HANDLE;
new Handle:g_cvarExtendTime = INVALID_HANDLE;
new Handle:g_cvarCheckInterval = INVALID_HANDLE;
new Handle:g_cvarSound = INVALID_HANDLE;
new Handle:g_cvarMessage = INVALID_HANDLE;

// Native Cvars
new Handle:g_cvarTimeLimit = INVALID_HANDLE;
new Handle:g_cvarTeamPlay = INVALID_HANDLE;

// Console Variables: Runtime Optimizers
new g_iPlugin_Enable 					= 1;
new g_iPlugin_TeamPlay = -1;
new Float:g_flPlugin_ExtendTime = 0.0;
new Float:g_flPlugin_CheckInterval = 0.5;
new String:g_szPlugin_Sound[PLATFORM_MAX_PATH] = "";
new String:g_szPlugin_Message[192] = "";

// Timers


// Library Load Checks


// Game Variables
new EngineVersion:g_evEngine_Version = Engine_Unknown; // Guessed SDK version
new Handle:g_hTimer_CheckInterval = INVALID_HANDLE;

// Map Variables


// Client Variables


// M i s c


/***************************************************************************************


	F O R W A R D   P U B L I C S


***************************************************************************************/
public OnPluginStart()
{
	// Initialization for SMLib
	PluginManager_Initialize("overtime", "[SM] ");
	
	// Translations
	// LoadTranslations("common.phrases");
	
	
	// Command Hooks (AddCommandListener) (If the command already exists, like the command kill, then hook it!)
	
	
	// Register New Commands (PluginManager_RegConsoleCmd) (If the command doesn't exist, hook it here)
	
	
	// Register Admin Commands (PluginManager_RegAdminCmd)
	
	
	// Cvars: Create a global handle variable.
	g_cvarEnable = PluginManager_CreateConVar("enable", "1", "Enables or disables this plugin");
	g_cvarExtendTime = PluginManager_CreateConVar("extend", "5.0", "In minutes, how long the current game/round is extended");
	g_cvarCheckInterval = PluginManager_CreateConVar("interval", "0.5", "Interval in seconds how often to check the time limit");
	g_cvarSound = PluginManager_CreateConVar("sound", "/vo/npc/male01/evenodds.wav", "Sound to play when the overtime is reached");
	g_cvarMessage = PluginManager_CreateConVar("message", "[SM] OVERTIME!", "Shows this message, when overtime is reached");

	// Find Cvar
	g_cvarTimeLimit = FindConVar("mp_timelimit");
	g_cvarTeamPlay = FindConVar("mp_teamplay");
	
	// Hook ConVar Change
	HookConVarChange(g_cvarEnable, ConVarChange_Enable);
	HookConVarChange(g_cvarExtendTime, ConVarChange_ExtendTime);
	HookConVarChange(g_cvarCheckInterval, ConVarChange_CheckInterval);
	HookConVarChange(g_cvarSound, ConVarChange_Sound);
	HookConVarChange(g_cvarMessage, ConVarChange_Message);

	// Event Hooks
	

	// Library
	
	
	// Features
	g_evEngine_Version = GetEngineVersion();
	
	// Create ADT Arrays
	
	
	// Timers
	
	
}

public OnMapStart()
{
	// hax against valvefail (thx psychonic for fix)
	if (g_evEngine_Version == Engine_SourceSDK2007){
		SetConVarString(Plugin_VersionCvar, Plugin_Version);
	}

	// Timer
	g_hTimer_CheckInterval = CreateTimer(g_flPlugin_CheckInterval, Timer_CheckTimeLimit, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public OnConfigsExecuted()
{
	// Set your ConVar runtime optimizers here
	g_iPlugin_Enable = GetConVarInt(g_cvarEnable);
	g_flPlugin_ExtendTime = GetConVarFloat(g_cvarExtendTime);
	g_iPlugin_TeamPlay = GetConVarInt(g_cvarTeamPlay);
	g_flPlugin_CheckInterval = GetConVarFloat(g_cvarCheckInterval);
	GetConVarString(g_cvarSound, g_szPlugin_Sound, sizeof(g_szPlugin_Sound));
	GetConVarString(g_cvarMessage, g_szPlugin_Message, sizeof(g_szPlugin_Message));

	SetupSound(g_szPlugin_Sound);
}


/**************************************************************************************


	C A L L B A C K   F U N C T I O N S


**************************************************************************************/
/**************************************************************************************

	C O N  V A R  C H A N G E

**************************************************************************************/
/* Callback to get when the plugin is disabled */
public ConVarChange_Enable(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_iPlugin_Enable = StringToInt(newVal);
}
public ConVarChange_ExtendTime(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_flPlugin_ExtendTime = StringToFloat(newVal);
}
public ConVarChange_CheckInterval(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_flPlugin_CheckInterval = StringToFloat(newVal);

	CloseHandle(g_hTimer_CheckInterval);
	g_hTimer_CheckInterval = CreateTimer(g_flPlugin_CheckInterval, Timer_CheckTimeLimit, INVALID_HANDLE, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}
public ConVarChange_Sound(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	strcopy(g_szPlugin_Sound, sizeof(g_szPlugin_Sound), newVal);
	SetupSound(g_szPlugin_Sound);
}
public ConVarChange_Message(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	strcopy(g_szPlugin_Message, sizeof(g_szPlugin_Message), newVal);
}

/**************************************************************************************

	C O M M A N D S

**************************************************************************************/
/* Example Command Callback
public Action:Command_(client, args)
{
	
	return Plugin_Handled;
}
*/


/**************************************************************************************

	E V E N T S

**************************************************************************************/
/*
Depending on mp_teamplay we do the following:
mp_teamplay 1: we count the score (frags) of each player in one team together, then do that for the other team too.
mp_teamplay 0: we get the score (frags) of the 2 best players.
In both cases: if the values are equal we extend the time limit.
*/
public Action:Timer_CheckTimeLimit(Handle:timer)
{
	if (g_iPlugin_Enable == 0) {
		return Plugin_Continue;
	}

	// No timelimit - nothing to do
	new Float:timelimit = GetConVarFloat(g_cvarTimeLimit);
	if (timelimit <= 0.0) {
		return Plugin_Continue;
	}

	// We can't get how much time is left - nothing to do
	new timeleft;
	if (!GetMapTimeLeft(timeleft) || timeleft <= 0) {
		return Plugin_Continue;
	}

	//PrintToChatAll("timeleft: %d", timeleft);

	// Its not the last second - nothing to do
	if (timeleft > 1) {
		return Plugin_Continue;
	}

	new countPlayers = 0;
	LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH|CLIENTFILTER_NOBOTS|CLIENTFILTER_NOOBSERVERS) {
		countPlayers++;
	}
	// Only one or less players - nothing to do
	if (countPlayers <= 1){
		return Plugin_Continue;
	}

	new scoreOne = 0;
	new scoreTwo = 0;

	switch (g_iPlugin_TeamPlay) {

		case 0: {

			new temp = 0;
			LOOP_CLIENTS(client, CLIENTFILTER_INGAMEAUTH) {

				temp = Client_GetScore(client);
				if (temp > scoreOne) {

					// move the old best val into the snd best val.
					scoreTwo = scoreOne;
					// save the new best val.
					scoreOne = temp;
				}
				else if (temp > scoreTwo) {
					// in case we meet a value that is not the best, but better than the 2nd best, we save it.
					scoreTwo = temp;
				}
			}
		}
		case 1: {

			LOOP_CLIENTS(client, CLIENTFILTER_TEAMONE) {
				scoreOne += Client_GetScore(client);
			}

			LOOP_CLIENTS(client, CLIENTFILTER_TEAMTWO) {
				scoreTwo += Client_GetScore(client);
			}
		}
	}

	if (scoreOne == scoreTwo && scoreOne != 0 && scoreTwo != 0) {
		// OVER TIME!
		EmitSoundToAll(g_szPlugin_Sound);
		PrintToChatAll(g_szPlugin_Message);
		SetConVarFloat(g_cvarTimeLimit, timelimit + g_flPlugin_ExtendTime, false, false);
		return Plugin_Continue;
	}

	return Plugin_Continue;
}



/***************************************************************************************


	P L U G I N   F U N C T I O N S


***************************************************************************************/



/***************************************************************************************

	S T O C K

***************************************************************************************/
stock SetupSound(const String:path[PLATFORM_MAX_PATH]){

	// Prechache and DL table
	PrecacheSound(path, true);
	File_AddToDownloadsTable(path, false);
}

