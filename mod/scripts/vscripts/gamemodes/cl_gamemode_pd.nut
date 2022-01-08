global function Cl_PD_Init
global function ServerCallback_GameModePD_Battery
global function ServerCallback_GameModePD_BatteryDestroy
global function ServerCallback_AnnounceTitanDropping

const asset BATTERY = $"models/titans/medium/titan_medium_battery_static.mdl"

const float RADIUS = 2.0
// Animation cycles per second
const float CYCLES = 2.0
// Angles per second
const float ANGLES = 45.0
const float SCALE = 1.5

struct {
    entity mover
    var topology

    table< int, entity > cache
} file;

void function Cl_PD_Init() {

}

void function ServerCallback_AnnounceTitanDropping()
{
	string announcementString = "Titan Dropping"
	string announcementSubString = "Run towards it to deposit your batteries"
	
	AnnouncementData announcement = Announcement_Create( announcementString )
	Announcement_SetSubText( announcement, announcementSubString )
	Announcement_SetTitleColor( announcement, <1,0,0> )
	Announcement_SetPurge( announcement, true )
	Announcement_SetPriority( announcement, 200 ) //Be higher priority than Titanfall ready indicator etc
	Announcement_SetSoundAlias( announcement, SFX_HUD_ANNOUNCE_QUICK )
	Announcement_SetStyle( announcement, ANNOUNCEMENT_STYLE_QUICK )
	AnnouncementFromClass( GetLocalViewPlayer(), announcement )
}

void function ServerCallback_GameModePD_Battery(int ehandle, float x, float y, float z) {
    vector origin = <x,y,z>
    entity player = GetLocalClientPlayer()
    entity battery = CreateClientSidePropDynamic(origin, <0,0,0>, BATTERY)

    battery.kv.modelscale = SCALE

    //CreateRUI(player, origin)
    AddHighlight(battery)
    
    file.cache[ehandle] <- battery
    // TODO: Sync all battery animations, this may be too many threads
    thread StartAnimating(battery)
}

void function ServerCallback_GameModePD_BatteryDestroy(int ehandle) {
    entity battery = file.cache[ehandle]
    
    if(IsValid(battery) && battery != null) {
        battery.Destroy()
        delete file.cache[ehandle]
    }
}

// Minecraft style dropped entity
void function StartAnimating(entity toAnimate) {
    vector originalOrigin = toAnimate.GetOrigin()
    vector originalAngles = toAnimate.GetAngles()

    // this will go -RADIUS -> RADIUS
    // Ratio is abs(zOffset) / RADIUS
    float zOffset = 0.0
    float posOffset = 0.0
    float angleOffset = 0.0
    float currTime = Time()

    while(IsValid(toAnimate)) {
        // delta time since last frame so it isnt frame dependant lmao
        float delta = (Time() - currTime) // s since last frame
        float step = CYCLES * delta
        float ratio = fAbs(zOffset) / RADIUS
        float smooth = sineEasing(ratio) // how much it'll increment every second
        float angleStep = ANGLES * delta

        zOffset += step
        angleOffset += angleStep
        currTime = Time()
        posOffset = smooth * 2

        toAnimate.SetOrigin(originalOrigin + <0,0,posOffset>)
        toAnimate.SetAngles(originalAngles + <0,angleOffset,0>)

        if (IsValid(file.mover)) {
            vector target = GetLocalClientPlayer().EyePosition()
            vector dir = Normalize(target - originalOrigin)
            DebugDrawLine( originalOrigin, dir * 10, 255, 255, 255, true, 1.0 )
            print("Being run " + VectorToString(VectorToAngles(dir)))

            //file.mover.SetAngles(VectorToAngles(dir))
            UpdateTopology(file.topology, originalOrigin, VectorToAngles(dir), 28,15)
        }

        WaitFrame()
    }
}

void function CreateRUI(entity player, vector origin) {
    print("What")

    entity movers = CreateClientsideScriptMover( $"models/dev/empty_model.mdl", origin + <0,0,30>, <0,0,0> )
    var topo = CreateTopology(origin + <0,0,30>, <0,0,0>, 28,15)

    var rui = RuiCreate( $"ui/callsign_basic.rpak", topo, RUI_DRAW_WORLD, 0 )

    CallingCard callingCard = PlayerCallingCard_GetActive( player )
    CallsignIcon callsignIcon = PlayerCallsignIcon_GetActive( player )

    RuiSetImage( rui, "cardImage", callingCard.image )
    RuiSetInt( rui, "layoutType", callingCard.layoutType )
    RuiSetImage( rui, "iconImage", callsignIcon.image )
    RuiSetString( rui, "playerLevel", PlayerXPDisplayGenAndLevel( player.GetGen(), player.GetLevel() ) )
    RuiSetString( rui, "playerName", player.GetPlayerName() )
    RuiSetBool( rui, "isLobbyCard", true )

    file.topology = topo
}

void function AddHighlight(entity toHighlight) {
    toHighlight.Highlight_SetVisibilityType( HIGHLIGHT_VIS_LOS )
	toHighlight.Highlight_SetCurrentContext( 0 )
	int highlightId = toHighlight.Highlight_GetState( 0 )
	toHighlight.Highlight_SetFunctions( 0, 114, true, 114, 8.0, highlightId, false )
	toHighlight.Highlight_SetParam( 0, 0, <0.2,0.8,0.2> ) // green bec why not
	toHighlight.Highlight_StartOn()
}

// Eases in via sine function from -1 to 1
// makes it look smooth
// math turned out to be useful wow
float function sineEasing(float x) {
    return (-(2 * (cos(PI * x) - 1) / 2)) - 1.0
}

//abs of a float
float function fAbs(float x) {
    float res = 0.0;
    if (x < 0) {
        res = -x
    } else {
        res = x;
    }
    return res
}

var function CreateTopology( vector org, vector ang, float width, float height ) {
    // adjust so the RUI is drawn with the org as its center point
    org += ( (AnglesToRight( ang )*-1) * (width*0.5) )
    org += ( AnglesToUp( ang ) * (height*0.5) )

    // right and down vectors that get added to base org to create the display size
    vector right = ( AnglesToRight( ang ) * width )
    vector down = ( (AnglesToUp( ang )*-1) * height )

    return RuiTopology_CreatePlane( org, right, down, true )
}

void function UpdateTopology( var topo, vector org, vector ang, float width, float height ) {
    // adjust so the RUI is drawn with the org as its center point
    org += ( (AnglesToRight( ang )*-1) * (width*0.5) )
    org += ( AnglesToUp( ang ) * (height*0.5) )

    // right and down vectors that get added to base org to create the display size
    vector right = ( AnglesToRight( ang ) * width )
    vector down = ( (AnglesToUp( ang )*-1) * height )

    RuiTopology_UpdatePos(topo, org, right, down)
}