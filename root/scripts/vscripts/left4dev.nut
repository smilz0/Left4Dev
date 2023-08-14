//------------------------------------------------------
//     Author : smilzo
//     https://steamcommunity.com/id/smilz0
//------------------------------------------------------

Msg("Including left4dev...\n");

if (!IncludeScript("left4lib_users"))
	error("[L4D][ERROR] Failed to include 'left4lib_users', please make sure the 'Left 4 Lib' addon is installed and enabled!\n");
if (!IncludeScript("left4lib_timers"))
	error("[L4D][ERROR] Failed to include 'left4lib_timers', please make sure the 'Left 4 Lib' addon is installed and enabled!\n");
if (!IncludeScript("left4lib_concepts"))
	error("[L4D][ERROR] Failed to include 'left4lib_concepts', please make sure the 'Left 4 Lib' addon is installed and enabled!\n");

// Log levels
const LOG_LEVEL_NONE = 0; // Log always
const LOG_LEVEL_ERROR = 1;
const LOG_LEVEL_WARN = 2;
const LOG_LEVEL_INFO = 3;
const LOG_LEVEL_DEBUG = 4;

::Left4Dev <-
{
	Initialized = false
	ModeName = ""
	MapName = ""
	Difficulty = "" // easy, normal, hard, impossible
	Events = {}
}

IncludeScript("left4dev_settings");

::Left4Dev.Log <- function (level, text)
{
	if (level > Left4Dev.Settings.loglevel)
		return;
	
	if (level == LOG_LEVEL_DEBUG)
		printl("[L4D][DEBUG] " + text);
	else if (level == LOG_LEVEL_INFO)
		printl("[L4D][INFO] " + text);
	else if (level == LOG_LEVEL_WARN)
		error("[L4D][WARNING] " + text + "\n");
	else if (level == LOG_LEVEL_ERROR)
		error("[L4D][ERROR] " + text + "\n");
	else
		error("[L4D][" + level + "] " + text + "\n");
}

// Left4Dev main initialization function
::Left4Dev.Initialize <- function ()
{
	if (Left4Dev.Initialized)
	{
		Left4Dev.Log(LOG_LEVEL_DEBUG, "Left4Dev already initialized");
		return;
	}
	
	Left4Dev.ModeName = SessionState.ModeName;
	Left4Dev.MapName = SessionState.MapName;
	Left4Dev.Difficulty = Convars.GetStr("z_difficulty").tolower();

	Left4Dev.Log(LOG_LEVEL_INFO, "Initializing for game mode: " + Left4Dev.ModeName + " - map name: " + Left4Dev.MapName + " - difficulty: " + Left4Dev.Difficulty);
	
	Left4Dev.Log(LOG_LEVEL_DEBUG, "Loading settings...");
	Left4Utils.LoadSettingsFromFile("left4dev/cfg/settings.txt", "Left4Dev.Settings.", Left4Dev.Log);
	Left4Utils.SaveSettingsToFile("left4dev/cfg/settings.txt", ::Left4Dev.Settings, Left4Dev.Log);
	Left4Utils.PrintSettings(::Left4Dev.Settings, Left4Dev.Log, "[Settings] ");
	
	Left4Dev.Initialized = true;
}

::Left4Dev.Events.OnGameEvent_round_start <- function (params)
{
	Left4Dev.Log(LOG_LEVEL_DEBUG, "OnGameEvent_round_start");
	
	// Apparently, when scriptedmode is enabled and this director option isn't set, there is a big stutter (for the host)
	// when a witch is chasing a survivor and that survivor enters the saferoom. Simply having a value for this key, removes the stutter
	if (!("AllowWitchesInCheckpoints" in DirectorScript.GetDirectorOptions()))
		DirectorScript.GetDirectorOptions().AllowWitchesInCheckpoints <- false;
	
	if (Left4Dev.Settings.concepts)
		::ConceptsHub.SetHandler("LEFT4DEV", ::Left4Dev.OnConcept);
	
	if (Left4Dev.Settings.damage)
		::HooksHub.SetAllowTakeDamage("L4D", ::Left4Dev.AllowTakeDamage);
	
	Left4Timers.AddTimer("L4DFlow", 1, Left4Dev.L4DFlow, {}, true);
}

::Left4Dev.Events.OnGameEvent_round_end <- function (params)
{
	local winner = params["winner"];
	local reason = params["reason"];
	local message = params["message"];
	local time = params["time"];
	
	Left4Dev.Log(LOG_LEVEL_DEBUG, "OnGameEvent_round_end - winner: " + winner + " - reason: " + reason + " - message: " + message + " - time: " + time);
	
	Left4Timers.RemoveTimer("L4DFlow");
	::ConceptsHub.RemoveHandler("LEFT4DEV");
}

::Left4Dev.Events.OnGameEvent_map_transition <- function (params)
{
	Left4Dev.Log(LOG_LEVEL_DEBUG, "OnGameEvent_map_transition");
	
	Left4Timers.RemoveTimer("L4DFlow");
	::ConceptsHub.RemoveHandler("LEFT4DEV");
}

::Left4Dev.HandleCommand <- function (player, cmd, args, text)
{
	if (player == null || !player.IsValid() || IsPlayerABot(player) || Left4Users.GetOnlineUserLevel(player.GetPlayerUserId()) < L4U_LEVEL.Admin)
		return;
	
	Left4Dev.Log(LOG_LEVEL_DEBUG, "Left4Dev.HandleCommand - " + player.GetPlayerName() + " - cmd: " + cmd + " - args: " + args.len());
	
	local numArgs = args.len() - 2; // args[0] = handler, args[1] = command; Only count the remaining args
	switch (cmd)
	{
		case "settings":
		{
			if (numArgs > 0)
			{
				local arg1 = args[2].tolower();
				
				if (arg1 in Left4Dev.Settings)
				{
					if (numArgs < 2)
						ClientPrint(player, 3, "\x01 Current value for " + arg1 + ": " + Left4Dev.Settings[arg1]);
					else
					{
						try
						{
							local value = args[3].tointeger();
							::Left4Dev.Settings[arg1] <- value;
							Left4Utils.SaveSettingsToFile("left4dev/cfg/settings.txt", ::Left4Dev.Settings, Left4Dev.Log);
							ClientPrint(player, 3, "\x05 Changed value for " + arg1 + " to: " + value);
							
							::Left4Dev.OnSettingChanged(arg1, value);
						}
						catch(exception)
						{
							Left4Dev.Log(LOG_LEVEL_ERROR, "Error changing value for: " + arg1 + " - new value: " + args[3] + " - error: " + exception);
							ClientPrint(player, 3, "\x04 Error changing value for " + arg1);
						}
					}
				}
				else
					ClientPrint(player, 3, "\x04 Invalid setting: " + arg1);
			}
			
			break;
		}
		case "runscript":
		{
			local scriptFile = "test.nut";
			if (numArgs > 0)
				scriptFile = args[2];
			
			/*
			local fileContents = FileToString(scriptFile);
			if (!fileContents)
				ClientPrint(player, 3, "\x04 File not found: " + scriptFile);
			else
			{
				try
				{
					local compiledscript = compilestring(fileContents);
					compiledscript();
				}
				catch(exception)
				{
					Left4Dev.Log(LOG_LEVEL_ERROR, exception);
				}
			}
			*/
			try
			{
				if (!IncludeScript(scriptFile))
					ClientPrint(player, 3, "\x04 File not found: " + scriptFile);
			}
			catch(exception)
			{
				//Left4Dev.Log(LOG_LEVEL_ERROR, exception);
			}
			
			break;
		}
		case "nearbyents":
		{
			local filter = "*";
			if (numArgs > 0)
				filter = args[2];
			
			local radius = 300;
			if (numArgs > 1)
				radius = args[3].tointeger();
			
			Left4Dev.Log(LOG_LEVEL_INFO, "-- ENTITIES -----------------------------------------------------------------------------------------------------------------------------------------------------------------------");
			Left4Dev.Log(LOG_LEVEL_INFO, "  ID  |               CLASS                      |                             NAME                             |                 ORIGIN              |   MODEL");
			Left4Dev.Log(LOG_LEVEL_INFO, "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
			local t = {};
			local ent = null;
			local i = -1;
			local orig = player.GetOrigin();
			while (ent = Entities.FindByClassnameWithin(ent, filter, orig, radius))
			{
				if (ent.IsValid())
					Left4Dev.Log(LOG_LEVEL_INFO, format("%5d", ent.GetEntityIndex()) + " | " + format("%40s", ent.GetClassname()) + " | " + format("%60s", ent.GetName()) + " | " + format("%011.4f", ent.GetOrigin().x) + "," + format("%011.4f", ent.GetOrigin().y) + "," + format("%011.4f", ent.GetOrigin().z) + " | " + ent.GetModelName());
				
				/*
				Left4Dev.Log(LOG_LEVEL_DEBUG, NetProps.GetPropEntity(ent, "m_hOwner"));
				
				if (ent.GetClassname() == "player")
					Left4Dev.Log(LOG_LEVEL_DEBUG, "m_iTeamNum: " + NetProps.GetPropInt(ent, "m_iTeamNum") + " - m_survivorCharacter: " + NetProps.GetPropInt(ent, "m_survivorCharacter"));
				else if (ent.GetClassname() == "point_prop_use_target")
					Left4Dev.Log(LOG_LEVEL_DEBUG, "m_useActionOwner: " + NetProps.GetPropEntity(ent, "m_useActionOwner"));
				*/
			}
			Left4Dev.Log(LOG_LEVEL_INFO, "-- /ENTITIES ----------------------------------------------------------------------------------------------------------------------------------------------------------------------");
			
			break;
		}
		case "origin":
		{
			if (numArgs > 2)
				player.SetOrigin(Vector(args[2].tofloat(), args[3].tofloat(), args[4].tofloat()));
			else
				Left4Dev.Log(LOG_LEVEL_INFO, "Origin: " + player.GetOrigin());
			
			break;
		}
		case "looking":
		{
			local target = Left4Utils.GetLookingTarget(player);
			if ((typeof target) == "instance" && target.IsValid())
				Left4Dev.Log(LOG_LEVEL_INFO, "Looking ent: " + ent.GetEntityIndex() + " - name: " + ent.GetName() + " - class: " + ent.GetClassname() + " - model: " + NetProps.GetPropString(ent, "m_ModelName") + " - origin: " + ent.GetOrigin());
			else if (target)
				Left4Dev.Log(LOG_LEVEL_INFO, "Looking pos: " + target);
			
			break;
		}
		case "skipintro":
		{
			Left4Dev.SkipIntro();
			
			break;
		}
		case "test":
		{
			local param1 = "";
			local param2 = "";
			
			if (numArgs > 0)
				param1 = args[2];
			if (numArgs > 1)
				param2 = args[3];
			
			Left4Dev.Test(player, param1, param2);
			
			break;
		}
	}
}

::Left4Dev.Test <- function (player, param1, param2)
{
	//
}

::Left4Dev.OnSettingChanged <- function (option, value)
{
	switch (option)
	{
		case "concepts":
		{
			if (value == 0)
				::ConceptsHub.RemoveHandler("LEFT4DEV");
			else
				::ConceptsHub.SetHandler("LEFT4DEV", ::Left4Dev.OnConcept);
			
			break;
		}
		case "damage":
		{
			if (value == 0)
				::HooksHub.RemoveAllowTakeDamage("L4D");
			else
				::HooksHub.SetAllowTakeDamage("L4D", ::Left4Dev.AllowTakeDamage);
			
			break;
		}
	}
}

::Left4Dev.OnConcept <- function (concept, query)
{
	if (concept == "TLK_IDLE" || concept == "PlayerExertionMinor" || concept.find("VSLib") != null)
		return;
	
	local who = "";
	local subject = "";

	if ("who" in query)
		who = query.who;
	if ("subject" in query)
		subject = query.subject;
		
	Left4Dev.Log(LOG_LEVEL_INFO, "Concept: " + concept + " - who: " + who + " - subject: " + subject);
	
	if (concept == "OfferItem")
		Left4Utils.PrintTable(query);
	
	//if ("worldtalk" in query)
	//	ClientPrint(null, 3, "worldtalk");
}

::Left4Dev.L4DFlow <- function (params)
{
	if (Left4Dev.Settings.flow)
		ClientPrint(null, 3, "Flow: " + Left4Dev.GetFlowPercent());
}

::Left4Dev.GetFlowPercent <- function ()
{
	local ret = 0;
	local ent = null;
	while (ent = Entities.FindByClassname(ent, "player"))
	{
		if (ent.IsValid() && NetProps.GetPropInt(ent, "m_iTeamNum") == TEAM_SURVIVORS && !ent.IsDead() && !ent.IsDying())
		{
			local flow = GetCurrentFlowPercentForPlayer(ent);
			if (flow > ret)
				ret = flow;
		}
	}
	return ret;
}

::Left4Dev.KillSurvivor <- function (surv)
{
	surv.SetReviveCount(2);
	surv.TakeDamage(200, 0, surv);
}

::Left4Dev.SkipIntro <- function ()
{
	local info_director = Entities.FindByClassname(null, "info_director");
	if (!info_director || !info_director.IsValid())
	{
		Left4Dev.Log(LOG_LEVEL_ERROR, "info_director not found!");
		return;
	}
	
	/* TODO: The Sacrifice still does it's fade without this
	local ent = null;
	while (ent = Entities.FindByClassname(ent, "env_fade"))
	{
		if (ent.IsValid())
			DoEntFire("!self", "Kill", "", 0, null, ent);
	}
	*/
	
	DoEntFire("!self", "ReleaseSurvivorPositions", "", 0, null, info_director);
	DoEntFire("!self", "FinishIntro", "", 0, null, info_director);
	
	ent = null;
	while (ent = Entities.FindByClassname(ent, "point_viewcontrol_survivor"))
	{
		if (ent.IsValid())
			DoEntFire("!self", "StartMovement", "", 0, null, ent);
	}
	
	ent = null;
	while (ent = Entities.FindByClassname(ent, "point_viewcontrol_multiplayer"))
	{
		if (ent.IsValid())
			DoEntFire("!self", "StartMovement", "", 0, null, ent);
	}
	
	local tbl = { classname = "env_fade", origin = Vector(0, 0, 0), angles = QAngle(0, 0, 0), spawnflags = 1, rendercolor = "0 0 0", renderamt = 255, holdtime = 1, duration = 1 };
	ent = g_ModeScript.CreateSingleSimpleEntityFromTable(tbl);
	if (!ent)
	{
		Left4Dev.Log(LOG_LEVEL_ERROR, "Could not create env_fade!");
		return;
	}
	ent.ValidateScriptScope();
	
	DoEntFire("!self", "Fade", "", 0, null, ent);
	DoEntFire("!self", "Kill", "", 2.5, null, ent);
}

::Left4Dev.AllowTakeDamage <- function (damageTable)
{
	local Attacker = null;						// hscript of the entity that attacked
	local Victim = null;						// hscript of the entity that was hit
	local Inflictor = null;						// hscript of the entity that was the inflictor
	local DamageDone = damageTable.DamageDone;	// how much damage done
	local DamageType = damageTable.DamageType;	// of what type
	local Location = null;						// where
	local Weapon = null;						// by what - often Null (say if attacker was a common)
	
	if ("Attacker" in damageTable && damageTable.Attacker && damageTable.Attacker.IsValid())
		Attacker = damageTable.Attacker;
	if ("Victim" in damageTable && damageTable.Victim && damageTable.Victim.IsValid())
		Victim = damageTable.Victim;
	if ("Inflictor" in damageTable && damageTable.Inflictor && damageTable.Inflictor.IsValid())
		Inflictor = damageTable.Inflictor;
	if ("Location" in damageTable && damageTable.Location)
		Location = damageTable.Location;
	if ("Weapon" in damageTable && damageTable.Weapon /*&& damageTable.Weapon.IsValid()*/)
		Weapon = damageTable.Weapon;
	
	if (Attacker)
	{
		if (Attacker.GetClassname() == "player")
			Attacker = Attacker.GetClassname() + " (" + Attacker.GetPlayerName() + ")";
		else
			Attacker = Attacker.GetClassname();
	}
	else
		Attacker = "(NULL)";
	
	if (Victim)
	{
		if (Victim.GetClassname() == "player")
			Victim = Victim.GetClassname() + " (" + Victim.GetPlayerName() + ")";
		else
			Victim = Victim.GetClassname();
	}
	else
		Victim = "(NULL)";
		
	if (Inflictor)
	{
		if (Inflictor.GetClassname() == "player")
			Inflictor = Inflictor.GetClassname() + " (" + Inflictor.GetPlayerName() + ")";
		else
			Inflictor = Inflictor.GetClassname();
	}
	else
		Inflictor = "(NULL)";
	
	if (!Location)
		Location = "(NULL)";
	
	if (Weapon)
		Weapon = Weapon.GetClassname();
	else
		Weapon = "(NULL)";
	
	Left4Dev.Log(LOG_LEVEL_INFO, "Damage: " + Attacker + " -> " + Victim + " - " + DamageDone + " HP - T: " + DamageType + " - I: " + Inflictor + " - W: " + Weapon + " - L: " + Location);
}

__CollectEventCallbacks(::Left4Dev.Events, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);

HooksHub.SetChatCommandHandler("l4d", ::Left4Dev.HandleCommand);
HooksHub.SetConsoleCommandHandler("l4d", ::Left4Dev.HandleCommand);

Left4Dev.Initialize();
