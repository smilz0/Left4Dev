//------------------------------------------------------
//     Author : smilzo
//     https://steamcommunity.com/id/smilz0
//------------------------------------------------------

Msg("Including left4dev_events...\n");

IncludeScript("left4lib_hooks");

/*
::Left4Dev.Events.OnGameEvent_player_falldamage <- function (params)
{
	local userid = params["userid"];
	local damage = 0;
	local causer = null;
	
	local player = g_MapScript.GetPlayerFromUserID(userid);
	
	if (!player || !player.IsValid())
		return;
	
	if ("damage" in params)
		damage = params["damage"];
	
	if ("causer" in params)
	{
		causer = params["causer"];
		causer = g_MapScript.GetPlayerFromUserID(causer);
	}
	
	if (causer && causer.IsValid())
	{
		if (causer.IsPlayer())
			printl("OnGameEvent_player_falldamage - " + player.GetPlayerName() + " - " + damage + " - " + causer.GetPlayerName());
		else
			printl("OnGameEvent_player_falldamage - " + player.GetPlayerName() + " - " + damage + " - " + causer.GetClassname());
	}
	else
		printl("OnGameEvent_player_falldamage - " + player.GetPlayerName() + " - " + damage);
}
*/

// "userid"	"short"		// user ID on server
// "index"	"byte"		// player slot (entity index-1)	
::Left4Dev.Events.OnGameEvent_player_connect_full <- function (params)
{
	local userid = params["userid"];
	local player = g_MapScript.GetPlayerFromUserID(userid);
	
	Left4Dev.PlayerIn(player);
}

::Left4Dev.Events.OnGameEvent_player_disconnect <- function (params)
{
	if ("userid" in params)
	{
		local userid = params["userid"].tointeger();
		local player = g_MapScript.GetPlayerFromUserID(userid);
	
		if (player && player.IsValid() && IsPlayerABot(player))
			return;
	
		Left4Dev.PlayerOut(userid, player);
	}
}

// "userid"	"short"		// user ID on server
::Left4Dev.Events.OnGameEvent_player_spawn <- function (params)
{
	local userid = params["userid"];
	local player = g_MapScript.GetPlayerFromUserID(userid);
	
	if (IsPlayerABot(player))
		return;
	
	local steamid = player.GetNetworkIDString();
	Left4Dev.PlayerIn(player);
}

// short	bot			user ID of the bot
// short	player		user ID of the player
::Left4Dev.Events.OnGameEvent_bot_player_replace <- function (params)
{
	local userid = params["player"];
	local player = g_MapScript.GetPlayerFromUserID(userid);
	
	local steamid = player.GetNetworkIDString();
	Left4Dev.PlayerIn(player);
}

::Left4Dev.Events.OnGameEvent_round_start <- function (params)
{
	Left4Dev.OnRoundStart(params);
}

::Left4Dev.Events.OnGameEvent_round_end <- function (params)
{
	local winner = params["winner"];
	local reason = params["reason"];
	local message = params["message"];
	local time = params["time"];
	
	Left4Dev.OnRoundEnd(winner, reason, message, time, params);
}

::Left4Dev.Events.OnGameEvent_map_transition <- function (params)
{
	Left4Dev.OnMapTransition(params);
}

::Left4Dev.Events.OnGameEvent_player_say <- function (params)
{
	local player = 0;
	if ("userid" in params)
		player = params["userid"];
	if (player != 0)
		player = g_MapScript.GetPlayerFromUserID(player);
	else
		player = null;
	local text = params["text"];
	local args = {};
	if (text != null && text != "")
		args = split(text, " ");
	
	Left4Dev.OnPlayerSay(player, text, args, params);
}

::Left4Dev.UserConsoleCommand <- function (playerScript, arg)
{
	local args = {};
	if (arg != null && arg != "")
		args = split(arg, ",");
	
	Left4Dev.OnUserConsoleCommand(playerScript, args, arg);
}

HooksHub.SetUserConsoleCommand("L4D", ::Left4Dev.UserConsoleCommand);

::Left4Dev.AllowTakeDamage <- function (damageTable)
{
	Left4Dev.HandleDamage(damageTable);
}


__CollectEventCallbacks(::Left4Dev.Events, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
