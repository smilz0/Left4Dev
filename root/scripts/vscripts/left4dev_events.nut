//------------------------------------------------------
//     Author : smilzo
//     https://steamcommunity.com/id/smilz0
//------------------------------------------------------

Msg("Including left4dev_events...\n");

//IncludeScript("left4lib_hooks");

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
