global function PDMode_Init

global const GAMEMODE_PD = "pd"
global const PD_NAME = "Player Destruction"
global const PD_DESC = "Killing other players drops batteries that you need to deposit for your team to win."

void function PDMode_Init() {
    AddCallback_OnCustomGamemodesInit( CreateGamemode )
	
	AddCallback_OnRegisteringCustomNetworkVars( PDRegisterNetworkVars )
}

void function CreateGamemode() {
    GameMode_Create( GAMEMODE_PD )
    GameMode_SetName( GAMEMODE_PD, PD_NAME )
    GameMode_SetDesc( GAMEMODE_PD, PD_DESC )
    
    // No titans so use titan thing for batteries
	GameMode_AddScoreboardColumnData( GAMEMODE_PD, "#SCOREBOARD_PILOT_KILLS", PGS_PILOT_KILLS, 2)
	GameMode_AddScoreboardColumnData( GAMEMODE_PD, "Batteries", PGS_TITAN_KILLS, 2 )
    // Green because batteries are green.. idk
	GameMode_SetColor( GAMEMODE_PD, [56, 181, 34, 255] )

    // Clueless Surely this'll work
	GameMode_SetDefaultTimeLimits( GAMEMODE_PD, 3, 0 )
	GameMode_SetDefaultScoreLimits( GAMEMODE_PD, 5, 0 )
	GameMode_SetEvacEnabled( GAMEMODE_PD, false )
    
    // IDK what this is but it works
    GameMode_SetGameModeAnnouncement( GAMEMODE_PD, "gnrc_modeDesc" )

    AddPrivateMatchMode( GAMEMODE_PD )

    #if SERVER
    GameMode_AddServerInit( GAMEMODE_PD, _PD_Init )
    GameMode_SetPilotSpawnpointsRatingFunc( GAMEMODE_PD, RateSpawnpoints_Generic )
    #elseif CLIENT
    GameMode_AddClientInit( GAMEMODE_PD, Cl_PD_Init )
    #endif
}

void function PDRegisterNetworkVars()
{
	if ( GAMETYPE != GAMEMODE_PD )
		return

	Remote_RegisterFunction( "ServerCallback_GameModePD_Battery" )
	Remote_RegisterFunction( "ServerCallback_GameModePD_BatteryDestroy" )
	Remote_RegisterFunction( "ServerCallback_AnnounceTitanDropping" )
}