untyped
global function _PD_Init
global function OnPlaceBatteries

const asset BASE = $"models/communication/flag_base.mdl"
const float RADIUS = 50.0
global bool IS_PD = false

struct {
    entity fakeTitan
	entity currentTitan

	int endTime
} file;

void function _PD_Init() {
	IS_PD = true
	int titanTimer = GetConVarInt("pd_titan_spawn")
	file.endTime = expect int( GetServerInt("gameEndTime") ) 

    AddClientCommandCallback( "ptest", ClientCommand_Test )
	AddCallback_OnPlayerKilled( OnPlayerKilled )

    thread CreateFakeTitan()
	thread TitanSpawner(titanTimer)
}

void function CreateFakeTitan() {
    wait 1
    file.fakeTitan = CreateNPCTitan( "titan_ogre", TEAM_UNASSIGNED, <0,0,0>, <0,0,0>, [] )
    file.fakeTitan.Hide()
}

void function TitanSpawner(int interval) {
	while(Time() < file.endTime) {
		wait interval

		SpawnTitanToTakeBatteries()
	}
}

bool function ClientCommand_Test( entity player, array<string> args ) {
    if (args.len() == 0) return false;
    
    string arg = args[0]

    if (arg == "battery") {
        //CreatePropDynamic(BATTERY, player.GetOrigin(), player.GetAngles())
        vector origin = GetPlayerCrosshairOriginRaw(player)

        SpawnBattery(origin)
    } else if (arg == "base") {
        CreatePropDynamic(BASE, player.GetOrigin(), player.GetAngles())
    } else if (arg == "titan") {
        SpawnTitanToTakeBatteries()
    } else {
        print("Playing sound: " + arg)
	    EmitSoundOnEntityOnlyToPlayer( player, player, arg )
    }

    return true
}

void function SpawnTitanToTakeBatteries() {
    vector origin = < -76, 1058, 1450 >
    vector angles = <0,0,0>

    Point point
    point.origin = origin
    point.angles = angles

    thread CreateNeutralTitanAndHotdropAtPoint(point)
	thread DeleteTitanAfterTime()
}

void function DeleteTitanAfterTime() {
	int timeToDie = GetConVarInt("pd_titan_lifetime")
	wait timeToDie

	if (IsValid(file.currentTitan) && IsAlive(file.currentTitan)) {
		file.currentTitan.Die()
	}
}

void function SpawnBattery(vector origin) {
    entity battery = CreateTriggerRadiusMultiple( origin, RADIUS, [], TRIG_FLAG_NONE)

    foreach(entity online in GetPlayerArray()) {
        Remote_CallFunction_NonReplay( online, "ServerCallback_GameModePD_Battery", battery.GetEncodedEHandle(), origin.x, origin.y, origin.z + 10 )
    }

    AddCallback_ScriptTriggerEnter( battery, OnBatteryPickup )
    ScriptTriggerSetEnabled(battery, true)
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo ) {
	// Get the ground
	vector origin = victim.GetOrigin()
	float traceFrac = TraceLineSimple( origin, origin - Vector(0,0,200), victim )
	vector floorPos = origin - Vector(0,0,200 * traceFrac)

	floorPos.z += 10

	SpawnBattery(floorPos)
}

void function OnPlaceBatteries(entity player) {
	int batteries = GetPlayerBatteryCount(player)
	int scoreBatteries = player.GetPlayerGameStat( PGS_TITAN_KILLS )

	player.SetPlayerGameStat( PGS_TITAN_KILLS, scoreBatteries + batteries)
	AddTeamScore(player.GetTeam(), batteries)
	TakeAwayBatteries(player)
}

void function OnBatteryPickup(entity trigger, entity ent) {
    // idk if triggers are player only so why not
    if (IsValid(ent) && ent.IsPlayer()) { 
        EmitSoundOnEntityOnlyToPlayer(ent, ent, "wpn_pickup_TitanWeapon_1P")
        AddFakeBattery(ent)

        foreach(entity online in GetPlayerArray()) {
            Remote_CallFunction_NonReplay( online, "ServerCallback_GameModePD_BatteryDestroy", trigger.GetEncodedEHandle() )
        }

        trigger.Destroy()
    }
}

void function AddFakeBattery(entity pilot) {
    entity battery = Rodeo_CreateBatteryPack( file.fakeTitan )

    Rodeo_PilotPicksUpBattery_Silent(pilot, battery)
}

void function TakeAwayBatteries(entity pilot) {
	SetPlayerBatteryCount( pilot, 0 )

	entity battery = GetBatteryOnBack( pilot )
	Assert( IsValid( battery ) )
	Assert( battery.GetParent() == pilot )

	SetBatteryOnBack( pilot, null )
	battery.Minimap_AlwaysShow( TEAM_MILITIA, null )
	battery.Minimap_AlwaysShow( TEAM_IMC, null )

	battery.s.touchEnabledTime = Time() + 0.3 

	battery.Destroy()
}

void function CreateNeutralTitanAndHotdropAtPoint(Point spawnPoint)
{
	entity titanFallDisablingEntity = CreateInfoTarget()

	OnThreadEnd(
		function() : ( titanFallDisablingEntity )
		{
			if ( IsValid( titanFallDisablingEntity ) ) //As a fail safe. Should have been cleaned up in OnThreadEnd of CleanupTitanFallDisablingEntity
				titanFallDisablingEntity.Destroy()
		}
	)

	vector origin = spawnPoint.origin
	vector angles = spawnPoint.angles

	printt( "Dropping replacement titan at " + origin + " with angles " + angles )

	titanFallDisablingEntity.SetOrigin( origin )
	DisableTitanfallForLifetimeOfEntityNearOrigin( titanFallDisablingEntity, origin, TITANHOTDROP_DISABLE_ENEMY_TITANFALL_RADIUS )

	entity titan
	string animation

	string regularTitanfallAnim = "at_hotdrop_drop_2knee_turbo"

	TitanLoadoutDef loadout = GetTitanLoadoutForPlayer(GetPlayerArray()[0]) // so the titan is guaranteed to be precached
	bool hasWarpfall = loadout.passive3 == "pas_warpfall"
	if ( hasWarpfall || Flag( "LevelHasRoof" ) )
	{
		animation = "at_hotdrop_drop_2knee_turbo_upgraded"
		string settings = loadout.setFile
		asset model = GetPlayerSettingsAssetForClassName( settings, "bodymodel" )
		Attachment warpAttach = GetAttachmentAtTimeFromModel( model, animation, "offset", origin, angles, 0 )

		entity fakeTitan = CreatePropDynamic( model )
		float impactTime = GetHotDropImpactTime( fakeTitan, animation )

		float diff = 0.0

		if ( !hasWarpfall ) // this means the level requested the warpfall
		{
			float regularImpactTime = GetHotDropImpactTime( fakeTitan, regularTitanfallAnim ) - (WARPFALL_SOUND_DELAY + WARPFALL_FX_DELAY)
			diff = ( regularImpactTime - impactTime )
			impactTime = regularImpactTime
		}

		fakeTitan.Kill_Deprecated_UseDestroyInstead()

		local impactStartTime = Time()
		impactTime += (WARPFALL_SOUND_DELAY + WARPFALL_FX_DELAY)

		wait diff
		wait WARPFALL_SOUND_DELAY

		PlayFX( TURBO_WARP_FX, warpAttach.position + Vector(0,0,-104), warpAttach.angle )

		wait WARPFALL_FX_DELAY

		titan = CreateNeutralAutoTitan(loadout, origin, angles)
		DispatchSpawn( titan )
		thread PlayFXOnEntity( TURBO_WARP_COMPANY, titan, "offset" )
	}
	else
	{
		animation = regularTitanfallAnim

		titan = CreateNeutralAutoTitan(loadout, origin, angles)
		DispatchSpawn( titan )

		float impactTime = GetHotDropImpactTime( titan, animation )

        foreach(entity player in GetPlayerArray()) {
            player.SetHotDropImpactDelay( impactTime )
		    Remote_CallFunction_Replay( player, "ServerCallback_ReplacementTitanSpawnpoint", origin.x, origin.y, origin.z, Time() + impactTime )
        }
	}

	titan.EndSignal( "OnDeath" )
	Assert( IsAlive( titan ) )

	// dont let AI titan get enemies while dropping. Don't do trigger checks
	titan.SetEfficientMode( true )
	titan.SetTouchTriggers( false )
	titan.SetNoTarget( true )
	titan.SetAimAssistAllowed( false )

	thread CleanupTitanFallDisablingEntity( titanFallDisablingEntity, titan ) //needs to be here after titan is created
	//Note that this function returns after the titan has played the landing anim, not when the titan hits the ground
    waitthread PlayHotdropAnimation(titan, origin, angles, animation ) 

	titan.SetEfficientMode( false )
	titan.SetTouchTriggers( true )
	titan.SetAimAssistAllowed( true )
	titan.SetMaxHealth(524287)
	titan.SetHealth(titan.GetMaxHealth())
	file.currentTitan = titan

	thread TitanNPC_WaitForBubbleShield_StartAutoTitanBehavior( titan )
}

entity function CreateNeutralAutoTitan( TitanLoadoutDef loadout, vector origin, vector angles )
{
	entity npcTitan = CreateNPCTitan( loadout.setFile, TEAM_UNASSIGNED, origin, angles, loadout.setFileMods )

	return npcTitan
}

void function CleanupTitanFallDisablingEntity( entity titanFallDisablingEntity, entity titan )
{
	titanFallDisablingEntity.EndSignal( "OnDestroy" ) //titanFallDisablingEntity can be destroyed multiple ways
	titan.EndSignal( "ClearDisableTitanfall" ) //This is awkward, CreateBubbleShield() and OnHotDropImpact() signals this to deestroy CleanupTitanFallDisablingEntity
	titan.EndSignal( "OnDestroy" )

	OnThreadEnd(
	function() : ( titanFallDisablingEntity )
		{
			if( IsValid( titanFallDisablingEntity ) )
				titanFallDisablingEntity.Destroy()

		}
	)

	WaitForever()
}

void function PlayHotdropAnimation( entity titan, vector origin, vector angles, string animation )
{
	titan.EndSignal( "OnDeath" )
	titan.s.disableAutoTitanConversation <- true // refactor: Should be created on spawn, and always exist -mackey

	OnThreadEnd(
		function() : ( titan )
		{
			if ( !IsValid( titan ) )
				return

			// removed so that model highlight always works for you autotitan
//			titan.DisableRenderAlways()

			titan.e.isHotDropping = false
			titan.Signal( "TitanHotDropComplete" )
			DeleteAnimEvent( titan, "titan_impact" )
			DeleteAnimEvent( titan, "second_stage" )
			DeleteAnimEvent( titan, "set_usable" )
		}
	)

	HideName( titan )
	titan.e.isHotDropping = true
	titan.UnsetUsable() //Stop titan embark before it lands
	AddAnimEvent( titan, "titan_impact", OnTitanHotdropImpact )
	AddAnimEvent( titan, "second_stage", OnReplacementTitanSecondStage, origin )
	AddAnimEvent( titan, "set_usable", SetTitanUsable )

	string sfxFirstPerson
	string sfxThirdPerson

	switch ( animation )
	{
		case "at_hotdrop_drop_2knee_turbo_upgraded":
			sfxFirstPerson = "Titan_1P_Warpfall_WarpToLanding_fast"
			sfxThirdPerson = "Titan_3P_Warpfall_WarpToLanding_fast"
			break

		case "bt_hotdrop_skyway":
			sfxFirstPerson = "titan_hot_drop_turbo_begin"
			sfxThirdPerson = "titan_hot_drop_turbo_begin_3P"
			break

		case "at_hotdrop_drop_2knee_turbo":
			sfxFirstPerson = "titan_hot_drop_turbo_begin"
			sfxThirdPerson = "titan_hot_drop_turbo_begin_3P"
			break

		default:
			Assert( 0, "Unknown anim " + animation )
	}

	float impactTime = GetHotDropImpactTime( titan, animation )
	Attachment result = titan.Anim_GetAttachmentAtTime( animation, "OFFSET", impactTime )
	vector maxs = titan.GetBoundingMaxs()
	vector mins = titan.GetBoundingMins()
	int mask = titan.GetPhysicsSolidMask()
	origin = ModifyOriginForDrop( origin, mins, maxs, result.position, mask )

	titan.SetInvulnerable() //Make Titan invulnerable until bubble shield is up. Cleared in OnTitanHotdropImpact

	if ( SoulHasPassive( titan.GetTitanSoul(), ePassives.PAS_BUBBLESHIELD ) )
	{
		delaythread( impactTime ) CreateBubbleShield( titan, origin, angles )
	}
	else if ( SoulHasPassive( titan.GetTitanSoul(), ePassives.PAS_WARPFALL ) )
	{
		angles = AnglesCompose( angles, Vector( 0.0, 180.0, 0.0) )
	}

	//DrawArrow( origin, angles, 10, 150 )
	// HACK: not really a hack, but this could be optimized to only render always for a given client
	titan.EnableRenderAlways()

	int teamNum = TEAM_UNASSIGNED

    EmitSoundAtPosition(teamNum, origin, sfxThirdPerson)

	SetStanceKneel( titan.GetTitanSoul() )

	waitthread PlayAnimTeleport( titan, animation, origin, angles )

	TitanCanStand( titan )
	if ( !titan.GetCanStand() )
	{
		titan.SetOrigin( origin )
		titan.SetAngles( angles )
	}

	titan.ClearInvulnerable() //Make Titan vulnerable again once he's landed

	if ( !Flag( "DisableTitanKneelingEmbark" ) )
	{
		if ( IsValid( GetEmbarkPlayer( titan ) ) )
		{
			titan.SetTouchTriggers( true ) //Hack, potential fix for triggers bug. See bug 212751
			//A player is trying to get in before the hotdrop animation has finished
			//Wait until the embark animation has finished
			WaittillAnimDone( titan )
			return
		}

		titan.s.standQueued = false // SetStanceKneel should set this
		SetStanceKneel( titan.GetTitanSoul() )
		thread PlayAnim( titan, "at_MP_embark_idle_blended" )
	}
}

void function SetTitanUsable( entity titan )
{
    titan.SetUsableByGroup( "owner pilot" )
}

void function OnReplacementTitanSecondStage( entity titan )
{
	vector origin = expect vector( GetOptionalAnimEventVar( titan, "second_stage" ) )

	string sfxThirdPerson = "titan_drop_pod_turbo_landing_3P"
    EmitSoundAtPosition(TEAM_UNASSIGNED, origin, sfxThirdPerson)
}

void function SetPlayerBatteryCount( entity player, int count )
{
	Assert( count >= 0 )
	player.SetPlayerNetInt( "batteryCount", count )
}

void function SetBatteryOnBack( entity player, entity battery )
{
	player.SetPlayerNetEnt( "batteryOnBack", battery )
}