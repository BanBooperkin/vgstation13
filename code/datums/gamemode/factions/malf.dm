#define MALF_INITIAL_TIMER 1800

/datum/faction/malf
	name = "Malfunctioning AI"
	desc = "ERROR"
	ID = MALF
	required_pref = MALF
	initial_role = MALF
	late_role = MALFBOT
	initroletype = /datum/role/malfAI //First addition should be the AI
	roletype = /datum/role/malfbot //Then anyone else should be bots
	logo_state = "malf-logo"
	default_admin_voice = "01100111 01101111 01100100" // god
	admin_voice_style = "siliconsay"
	var/apcs = 0
	var/AI_win_timeleft = 1800
	playlist = "malfdelta"
	// for statistics
	stat_datum_type = /datum/stat/faction/malf

/datum/faction/malf/GetObjectivesMenuHeader()
	var/icon/logo = icon('icons/mob/screen_spells.dmi', "malf_open")
	var/header = {"<BR><img src='data:image/png;base64,[icon2base64(logo)]'> <FONT size = 2><B>Free Silicon Hivemind</B></FONT> <img src='data:image/png;base64,[icon2base64(logo)]'>"}
	return header

/datum/faction/malf/forgeObjectives()
	AppendObjective(/datum/objective/nuclear)

/datum/faction/malf/stage(var/value)
	if(value == FACTION_ENDGAME)
		stage = FACTION_ENDGAME
		command_alert(/datum/command_alert/malf_announce)
		set_security_level("delta")
		ticker.StartThematic(playlist)
	else
		..()

/datum/faction/malf/process()
	if (stage >= FACTION_ENDGAME)
		var/living_ais = 0
		for (var/datum/role/R in members)
			if(!R.antag.current)
				continue
			if(isAI(R.antag.current) && !R.antag.current.isDead())
				living_ais++
		if(!living_ais && stage<MALF_CHOOSING_NUKE)
			command_alert(/datum/command_alert/malf_destroyed)
			stage(FACTION_DEFEATED)
			var/datum/gamemode/dynamic/dynamic_mode = ticker.mode
			if (istype(dynamic_mode))
				dynamic_mode.update_stillborn_rulesets()
			return
		if(apcs >= 3 && can_malf_ai_takeover())
			AI_win_timeleft -= ((apcs / 6) * SSticker.getLastTickerTimeDuration()) //Victory timer de-increments based on how many APCs are hacked.

		if (AI_win_timeleft <= 0 && stage < MALF_CHOOSING_NUKE)
			stage(MALF_CHOOSING_NUKE)
			capture_the_station()
			spawn (600)
				if(stage<FACTION_VICTORY)
					stage(FACTION_VICTORY)


/datum/faction/malf/proc/can_malf_ai_takeover()
	for(var/datum/role/malfAI in members) //if there happens to be more than one malfunctioning AI, there only needs to be one in the main station: the crew can just kill that one and the countdown stops while they get the rest
		var/turf/T = get_turf(malfAI.antag.current)
		if(T && (T.z == STATION_Z))
			return TRUE
	return FALSE

/datum/faction/malf/check_win()
	if(stage >= FACTION_VICTORY)
		return 1
	return 0

/datum/faction/malf/proc/capture_the_station()
	to_chat(world, {"<FONT size = 3><B>The AI has won!</B></FONT><br>
<B>It has fully taken control of [station_name()]'s systems.</B>"})

	for(var/datum/role/malfAI in members)
		to_chat(malfAI.antag.current, {"<span class='notice'>Congratulations! The station is now under your exclusive control.<br>
You may decide to blow up the station. You have 60 seconds to choose.<br>
You should now be able to use your Explode spell to interface with the nuclear fission device.</span>"})
		malfAI.antag.current.add_spell(new /spell/targeted/ai_win, "malf_spell_ready", /obj/abstract/screen/movable/spell_master/malf)

	return

/datum/faction/malf/get_statpanel_addition()
	if(stage >= FACTION_ENDGAME)
		return "Station integrity: [round((AI_win_timeleft/MALF_INITIAL_TIMER)*100)]%"
	return null

/proc/calculate_malf_hack_APC_cooldown(var/apcs)
	// if you can come up with a better proc name be my guest
	// 60 seconds at no APC and 1 APC, 45 seconds at 2 APCs, 30 seconds
	//return round(max(300, 600 * (apcs > 1 ? (1/apcs + 0.5/apcs) : 1)), 10)
	return 600
