//////////////////////////////////////////////
//                                          //
//            MIDROUND RULESETS             ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround//Can be drafted once in a while during a round
	var/list/living_players = list()
	var/list/living_antags = list()
	var/list/dead_players = list()
	var/list/list_observers = list()
	var/max_candidates = 0

/datum/dynamic_ruleset/midround/from_ghosts/
	weight = 0
	var/makeBody = TRUE

/datum/dynamic_ruleset/midround/trim_candidates()
	//unlike the previous two types, these rulesets are not meant for /mob/new_player
	//and since I want those rulesets to be as flexible as possible, I'm not gonna put much here,
	//but be sure to check dynamic_rulesets_debug.dm for an example.
	//
	//all you need to know is that here, the candidates list contains 4 lists itself, indexed with the following defines:
	//candidates = list(CURRENT_LIVING_PLAYERS, CURRENT_LIVING_ANTAGS, CURRENT_DEAD_PLAYERS, CURRENT_OBSERVERS)
	//so for example you can get the list of all current dead players with var/list/dead_players = candidates[CURRENT_DEAD_PLAYERS]
	//make sure to properly typecheck the mobs in those lists, as the dead_players list could contain ghosts, or dead players still in their bodies.
	//we're still gonna trim the obvious (mobs without clients, jobbanned players, etc)
	living_players = trim_list(candidates[CURRENT_LIVING_PLAYERS])
	living_antags = trim_list(candidates[CURRENT_LIVING_ANTAGS])
	dead_players = trim_list(candidates[CURRENT_DEAD_PLAYERS], trim_prefs_set_to_no = FALSE)
	list_observers = trim_list(candidates[CURRENT_OBSERVERS], trim_prefs_set_to_no = FALSE)

/datum/dynamic_ruleset/midround/proc/trim_list(var/list/L = list(), trim_prefs_set_to_no = TRUE)
	var/list/trimmed_list = L.Copy()
	var/role_id = initial(role_category.id)
	var/role_pref = initial(role_category.required_pref)
	for(var/mob/M in trimmed_list)
		if (!M.client)//are they connected?
			trimmed_list.Remove(M)
			continue
		var/preference = get_role_desire_str(M.client.prefs.roles[role_pref])
		if(preference == "Never" || (preference == "No" && trim_prefs_set_to_no)) // are they willing or at least not unwilling?
			trimmed_list.Remove(M)
			continue
		if (jobban_isbanned(M, role_id) || isantagbanned(M))//are they not antag-banned?
			trimmed_list.Remove(M)
			continue
		if (M.mind)
			if ((M.mind.assigned_role && (M.mind.assigned_role in restricted_from_jobs)) || (M.mind.role_alt_title && (M.mind.role_alt_title in restricted_from_jobs)))//does their job allow for it?
				trimmed_list.Remove(M)
				continue
			if ((M.mind.assigned_role && (M.mind.assigned_role in protected_from_jobs)) || (M.mind.role_alt_title && (M.mind.role_alt_title in protected_from_jobs)))
				var/probability = initial(role_category.protected_traitor_prob)
				if (prob(probability))
					candidates.Remove(M)
			if ((exclusive_to_jobs.len > 0) && !(M.mind.assigned_role in exclusive_to_jobs))//is the rule exclusive to their job?
				trimmed_list.Remove(M)
				continue
	return trimmed_list

//You can then for example prompt dead players in execute() to join as strike teams or whatever
//Or autotator someone

//IMPORTANT, since /datum/dynamic_ruleset/midround may accept candidates from both living, dead, and even antag players, you need to manually check whether there are enough candidates
// (see /datum/dynamic_ruleset/midround/autotraitor/ready(var/forced = 0) for example)
/datum/dynamic_ruleset/midround/ready(var/forced = 0)
	if (!forced)
		if(!check_enemy_jobs(TRUE,TRUE))
			return 0
	return 1

// Done via review_applications.
/datum/dynamic_ruleset/midround/from_ghosts/choose_candidates()
	return TRUE

/datum/dynamic_ruleset/midround/from_ghosts/ready(var/forced = 0)
	if (required_candidates > (dead_players.len + list_observers.len) && !forced)
		return 0
	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/execute()
	var/list/possible_candidates = list()
	possible_candidates.Add(dead_players)
	possible_candidates.Add(list_observers)
	send_applications(possible_candidates)
	return 1

/datum/dynamic_ruleset/midround/from_ghosts/review_applications()
	message_admins("Applicant list: [english_list(applicants)]")
	var/candidate_checks = required_candidates
	if (max_candidates)
		candidate_checks = max_candidates
	for (var/i = candidate_checks, i > 0, i--)
		if(applicants.len <= 0)
			if(i == candidate_checks)
				//We have found no candidates so far and we are out of applicants.
				mode.refund_midround_threat(cost)
				mode.threat_log += "[worldtime2text()]: Rule [name] refunded [cost] (all applications invalid)"
				mode.executed_rules -= src
			break
		var/mob/applicant = pick(applicants)
		applicants -= applicant
		if(!isobserver(applicant))
			if(applicant.stat == DEAD) //Not an observer? If they're dead, make them one.
				applicant = applicant.ghostize(FALSE)
			else //Not dead? Disregard them, pick a new applicant
				message_admins("[name]: Rule could not use [applicant], not dead.")
				i++
				continue

		if(!applicant)
			message_admins("[name]: Applicant was null. This may be caused if the mind changed bodies after applying.")
			i++
			continue
		message_admins("DEBUG: Selected [applicant] for rule.")

		var/mob/new_character = applicant

		if (makeBody)
			new_character = generate_ruleset_body(applicant)

		finish_setup(new_character, candidate_checks - (i-1)) // i = N, N - 1.... so that N - (i-1) = 1, 2, ...

	applicants.Cut()

/datum/dynamic_ruleset/midround/from_ghosts/proc/finish_setup(var/mob/new_character, var/index)
	var/datum/role/new_role = new role_category
	new_role.AssignToRole(new_character.mind,1)
	setup_role(new_role)

/datum/dynamic_ruleset/midround/from_ghosts/proc/setup_role(var/datum/role/new_role)
	new_role.OnPostSetup()
	new_role.Greet(GREET_MIDROUND)
	new_role.ForgeObjectives()
	new_role.AnnounceObjectives()

// -- Faction based --

/datum/dynamic_ruleset/midround/from_ghosts/faction_based
	weight = 0
	var/datum/faction/my_fac = null // If the midround lawset will try to add our antag to a faction
	var/created_a_faction = 0

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/review_applications()
	var/datum/faction/active_fac = find_active_faction_by_type(my_fac)
	if (!active_fac)
		active_fac = ticker.mode.CreateFaction(my_fac, null, 1)
		created_a_faction = 1
	my_fac = active_fac
	. = ..()
	if (created_a_faction)
		active_fac.OnPostSetup()
	return my_fac

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/setup_role(var/datum/role/new_role)
	my_fac.HandleRecruitedRole(new_role)
	new_role.Greet(GREET_MIDROUND)
	new_role.ForgeObjectives()
	new_role.AnnounceObjectives()

//////////////////////////////////////////////
//                                          //
//           SYNDICATE TRAITORS             ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/autotraitor
	name = "Syndicate Sleeper Agent"
	role_category = /datum/role/traitor
	protected_from_jobs = list("Security Officer", "Warden", "Detective", "Head of Security", "Captain","Head of Personnel",
							"Cyborg", "Merchant", "Chief Engineer", "Chief Medical Officer", "Research Director", "Brig Medic")
	restricted_from_jobs = list("AI","Mobile MMI")
	required_candidates = 1
	weight = BASE_RULESET_WEIGHT
	cost = 10
	requirements = list(50,40,30,20,10,10,10,10,10,10)
	repeatable = TRUE
	high_population_requirement = 10
	flags = TRAITOR_RULESET

/datum/dynamic_ruleset/midround/autotraitor/acceptable(var/population=0,var/threat=0)
	var/player_count = mode.living_players.len
	var/antag_count = mode.living_antags.len
	var/max_traitors = round(player_count / 10) + 1
	if ((antag_count < max_traitors) && prob(mode.midround_threat_level))//adding traitors if the antag population is getting low
		return ..()
	else
		return 0

/datum/dynamic_ruleset/midround/autotraitor/trim_candidates()
	..()
	for(var/mob/living/player in living_players)
		if(isAI(player) || isMoMMI(player))
			living_players -= player //Your assigned role doesn't change when you are turned into a MoMMI or AI
			continue
		if(isanimal(player) && !isborer(player))
			living_players -= player //No animal traitors except borers.
			continue
		if(isalien(player))
			living_players -= player //Xenos don't bother with the syndicate
			continue
		if(player.z == map.zCentcomm)
			living_players -= player//we don't autotator people on Z=2
			continue
		if(player.mind && (player.mind.antag_roles.len > 0))
			living_players -= player//we don't autotator people with roles already

/datum/dynamic_ruleset/midround/autotraitor/ready(var/forced = 0)
	if (required_candidates > living_players.len)
		return 0
	return ..()

/datum/dynamic_ruleset/midround/autotraitor/choose_candidates()
	var/mob/M = pick(living_players)
	assigned += M
	living_players -= M
	return (assigned.len > 0)

/datum/dynamic_ruleset/midround/autotraitor/execute()
	var/mob/M = pick(assigned)
	var/datum/role/traitor/newTraitor = new
	newTraitor.AssignToRole(M.mind,1)
	newTraitor.OnPostSetup()
	newTraitor.Greet(GREET_AUTOTATOR)
	newTraitor.ForgeObjectives()
	newTraitor.AnnounceObjectives()
	return 1

/datum/dynamic_ruleset/midround/autotraitor/previous_rounds_odds_reduction(var/result)
	return result


//////////////////////////////////////////////
//                                          //
//         Malfunctioning AI                ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                              		    //
//////////////////////////////////////////////
/datum/dynamic_ruleset/midround/malf
	name = "Malfunctioning AI"
	role_category = /datum/role/malfAI
	enemy_jobs = list("Security Officer", "Warden","Detective","Head of Security", "Captain", "Scientist", "Chemist", "Research Director", "Chief Engineer")
	exclusive_to_jobs = list("AI")
	required_pop = list(25,25,25,20,20,20,15,15,15,15)
	required_candidates = 1
	weight = BASE_RULESET_WEIGHT
	cost = 35
	requirements = list(90,80,70,60,50,40,40,30,30,20)
	high_population_requirement = 65
	flags = HIGHLANDER_RULESET

/datum/dynamic_ruleset/midround/malf/trim_candidates()
	..()
	candidates = candidates[CURRENT_LIVING_PLAYERS]
	for(var/mob/living/player in candidates)
		if(!isAI(player))
			candidates -= player
			continue
		if(player.z == map.zCentcomm)
			candidates -= player//we don't autotator people on Z=2
			continue
		if(player.mind && (player.mind.antag_roles.len > 0))
			candidates -= player//we don't autotator people with roles already

/datum/dynamic_ruleset/midround/malf/execute()
	var/datum/faction/malf/unction = find_active_faction_by_type(/datum/faction/malf)
	if (!unction)
		unction = ticker.mode.CreateFaction(/datum/faction/malf, null, 1)
	if(!assigned || !assigned.len)
		return 0
	var/mob/living/silicon/ai/M = pick(assigned)
	var/datum/role/malfAI/malf = unction.HandleNewMind(M.mind)
	malf.OnPostSetup()
	malf.Greet()
	for(var/mob/living/silicon/robot/R in M.connected_robots)
		unction.HandleRecruitedMind(R.mind)
	unction.forgeObjectives()
	unction.AnnounceObjectives()
	return 1

//////////////////////////////////////////////
//                                          //
//              RAGIN' MAGES                ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////1.01 - Disabled because it caused a bit too many wizards in rounds

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/raginmages
	name = "Ragin' Mages"
	role_category = /datum/role/wizard
	my_fac = /datum/faction/wizard
	enemy_jobs = list("Security Officer","Detective","Head of Security", "Captain")
	required_pop = list(20,20,15,15,15,15,15,10,10,0)
	required_candidates = 1
	weight = BASE_RULESET_WEIGHT/2
	cost = 20
	requirements = list(90,90,70,40,30,20,10,10,10,10)
	high_population_requirement = 50
	logo = "raginmages-logo"
	repeatable = TRUE

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/raginmages/acceptable(var/population=0,var/threat=0)
	if(locate(/datum/dynamic_ruleset/roundstart/cwc) in mode.executed_rules)
		message_admins("Rejected Ragin' Mages as there was a Civil War.")
		return 0 //This is elegantly skipped by specific ruleset.
		//This means that all ragin mages in CWC will be called only by that ruleset.
	else
		return ..()

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/raginmages/ready(var/forced = 0)
	if(wizardstart.len == 0)
		log_admin("Cannot accept Wizard ruleset. Couldn't find any wizard spawn points.")
		message_admins("Cannot accept Wizard ruleset. Couldn't find any wizard spawn points.")
		return 0
	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/raginmages/setup_role(var/datum/role/new_role)
	if (!created_a_faction)
		new_role.OnPostSetup() //Each individual role to show up gets a postsetup
	..()


//////////////////////////////////////////////
//                                          //
//          NUCLEAR OPERATIVES (MIDROUND)   ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/nuclear
	name = "Nuclear Assault"
	role_category = /datum/role/nuclear_operative
	role_category_override = "Nuke Operative" // this is what is used on the ban page
	my_fac = /datum/faction/syndicate/nuke_op/
	enemy_jobs = list("AI", "Cyborg", "Security Officer", "Warden","Detective","Head of Security", "Captain")
	required_pop = list(25, 25, 25, 25, 25, 20, 15, 15, 10, 10)
	required_candidates = 5 // Placeholder, see op. cap
	max_candidates = 5
	weight = BASE_RULESET_WEIGHT
	cost = 35
	requirements = list(90, 90, 80, 40, 40, 40, 30, 20, 20, 10)
	high_population_requirement = 60
	var/operative_cap = list(2, 2, 3, 3, 4, 5, 5, 5, 5, 5)
	logo = "nuke-logo"
	flags = HIGHLANDER_RULESET

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/nuclear/ready(var/forced = 0)
	if (forced)
		required_candidates = 1
	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/nuclear/acceptable(var/population = 0,var/threat = 0)
	if(locate(/datum/dynamic_ruleset/roundstart/nuclear) in mode.executed_rules)
		return 0 //Unavailable if nuke ops were already sent at roundstart
	var/indice_pop = min(10,round(living_players.len/5) + 1)
	required_candidates = operative_cap[indice_pop]
	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/nuclear/finish_setup(var/mob/new_character, var/index)
	var/datum/faction/syndicate/nuke_op/nuclear = find_active_faction_by_type(/datum/faction/syndicate/nuke_op)
	nuclear.forgeObjectives()
	if(index == 1) //Our first guy is the leader
		var/datum/role/nuclear_operative/leader/new_role = new
		new_role.AssignToRole(new_character.mind, 1)
		setup_role(new_role)
	else
		return ..()

//////////////////////////////////////////////
//                                          //
//          BLOB STORM			 (MIDROUND) ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/blob_storm
	name = "Blob Overmind Storm"
	role_category = /datum/role/blob_overmind/
	my_fac = /datum/faction/blob_conglomerate/
	enemy_jobs = list("AI", "Cyborg", "Security Officer", "Station Engineer","Chief Engineer", "Roboticist","Head of Security", "Captain")
	required_pop = list(25,20,20,15,15,15,10,10,10,10)
	required_candidates = 1
	weight = BASE_RULESET_WEIGHT
	weekday_rule_boost = list("Tue")
	cost = 30
	requirements = list(90,90,80,40,40,40,30,20,20,10)
	high_population_requirement = 70
	logo = "blob-logo"
	flags = HIGHLANDER_RULESET

	makeBody = FALSE

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/blob_storm/acceptable(population, threat_level)
	max_candidates = max(1, round(population/25))
	return ..()

// -- The offsets are here so that the cone of meteors always meet the station. Blob meteors shouldn't miss the station, else a blob would spawn outside of the main z-level.

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/blob_storm/finish_setup(var/mob/new_character, var/index)
	var/chosen_dir = meteor_wave(rand(20, 40), types = thing_storm_types["blob storm"], offset_origin = 150, offset_dest = 230)
	var/obj/item/projectile/meteor/blob/core/meteor = spawn_meteor(chosen_dir, /obj/item/projectile/meteor/blob/core, offset_origin = 150, offset_dest = 230)
	meteor.AssignMob(new_character)
	return 1 // The actual role (and faction) are created upon impact.


/datum/dynamic_ruleset/midround/from_ghosts/faction_based/blob_storm/review_applications()
	command_alert(/datum/command_alert/meteor_storm)
	. = ..()
	spawn (120 SECONDS)
		command_alert(/datum/command_alert/blob_storm/overminds/end)

//////////////////////////////////////////////
//                                          //
//            REVSQUAD (MIDROUND)           ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/revsquad
	name = "Revolutionary Squad"
	role_category = /datum/role/revolutionary/leader
	enemy_jobs = list("AI", "Cyborg", "Security Officer", "Warden","Detective","Head of Security", "Captain")
	required_pop = list(25,25,25,25,25,20,15,15,10,10)
	required_candidates = 3
	weight = BASE_RULESET_WEIGHT
	cost = 30
	requirements = list(90, 90, 90, 90, 40, 40, 30, 20, 10, 10)
	high_population_requirement = 50
	my_fac = /datum/faction/revolution
	logo = "rev-logo"
	flags = HIGHLANDER_RULESET

	var/required_heads = 3

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/revsquad/ready(var/forced = 0)
	if(forced)
		required_heads = 1
	if (find_active_faction_by_type(/datum/faction/revolution))
		return FALSE //Never send 2 rev types
	if(!..())
		return FALSE
	var/head_check = 0
	for(var/mob/player in mode.living_players)
		if(!player.mind)
			continue
		if(player.mind.assigned_role in command_positions)
			head_check++
	return (head_check >= required_heads)


//////////////////////////////////////////////
//                                          //
//         SPACE NINJA (MIDROUND)         ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/ninja
	name = "Space Ninja Attack"
	role_category = /datum/role/ninja
	enemy_jobs = list("Security Officer","Detective", "Warden", "Head of Security", "Captain")
	required_pop = list(15,15,15,15,15,10,10,10,5,5)
	required_candidates = 1
	weight = BASE_RULESET_WEIGHT
	cost = 20
	requirements = list(90,90,60,20,10,10,10,10,10,10)
	high_population_requirement = 20
	logo = "ninja-logo"
	repeatable = TRUE

/datum/dynamic_ruleset/midround/from_ghosts/ninja/acceptable(var/population=0,var/threat=0)
	var/player_count = mode.living_players.len
	var/antag_count = mode.living_antags.len
	var/max_traitors = round(player_count / 10) + 1
	if ((antag_count < max_traitors) && prob(mode.midround_threat_level))
		return ..()
	else
		return 0

/datum/dynamic_ruleset/midround/from_ghosts/ninja/setup_role(var/datum/role/newninja)
	var/datum/faction/spider_clan/spoider = find_active_faction_by_type(/datum/faction/spider_clan)
	if (!spoider)
		spoider = ticker.mode.CreateFaction(/datum/faction/spider_clan, null, 1)
	spoider.HandleRecruitedRole(newninja)

	return ..()

//////////////////////////////////////////////
//                                          //
//         RAMBLER       (MIDROUND)         ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/rambler
	name = "Soul Rambler Migration"
	role_category = /datum/role/rambler
	enemy_jobs = list("Librarian","Detective", "Chaplain", "Internal Affairs Agent")
	required_pop = list(0,0,10,10,15,15,20,20,20,25)
	required_candidates = 1
	weight = BASE_RULESET_WEIGHT
	timeslot_rule_boost = list(SLEEPTIME)
	cost = 5
	requirements = list(5,5,15,15,25,25,55,55,55,75)
	logo = "rambler-logo"
	repeatable = FALSE //Listen, this psyche is not big enough for two metaphysical seekers.
	flags = MINOR_RULESET

/datum/dynamic_ruleset/midround/from_ghosts/rambler/acceptable(var/population=0,var/threat=0)
	if(!mode.executed_rules)
		return FALSE
		//We have nothing to investigate!
	if(population>0)
		weight = clamp(300/(population^2),1,10) //1-5: 10; 8.3, 6.1, 4.6, 3.7, 3, ... , 1.2 (15)
	//We don't cotton to freaks in highpop
	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/rambler/generate_ruleset_body(mob/applicant)
	var/mob/living/carbon/human/frankenstein/new_frank = new(pick(latejoin))
	var/gender = pick(MALE, FEMALE)
	new_frank.randomise_appearance_for(gender)
	new_frank.key = applicant.key
	new_frank.dna.ready_dna(new_frank)
	new_frank.setGender(gender)
	return new_frank

//////////////////////////////////////////////
//                                          //
//               TIME AGENT                 //
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/time_agent
	name = "time agent anomaly"
	role_category = /datum/role/time_agent
	required_candidates = 1
	weight = 4
	cost = 10
	requirements = list(70, 60, 50, 40, 30, 20, 10, 10, 10, 10)
	logo = "time-logo"

/datum/dynamic_ruleset/midround/from_ghosts/time_agent/acceptable(var/population=0,var/threat=0)
	var/player_count = mode.living_players.len
	var/antag_count = mode.living_antags.len
	var/max_traitors = round(player_count / 10) + 1
	if (antag_count < max_traitors)
		return ..()
	else
		return 0

/datum/dynamic_ruleset/midround/from_ghosts/time_agent/setup_role(var/datum/role/newagent)
	var/datum/faction/time_agent/agency = find_active_faction_by_type(/datum/faction/time_agent)
	if (!agency)
		agency = ticker.mode.CreateFaction(/datum/faction/time_agent, null, 1)
	agency.HandleRecruitedRole(newagent)

	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/time_agent/ready(var/forced=0)
	if(required_candidates > (dead_players.len + list_observers.len))
		return 0
	return ..()


//////////////////////////////////////////////
//                                          //
//               THE GRINCH (holidays)      ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/grinch
	name = "The Grinch"
	role_category = /datum/role/grinch
	restricted_from_jobs = list()
	enemy_jobs = list()
	required_pop = list(0,0,0,0,0,0,0,0,0,0)
	required_candidates = 1
	weight = BASE_RULESET_WEIGHT
	cost = 10
	requirements = list(40,20,10,10,10,10,10,10,10,10) // So that's not possible to roll it naturally
	high_population_requirement = 10
	flags = MINOR_RULESET

/datum/dynamic_ruleset/midround/from_ghosts/grinch/acceptable(var/population=0, var/threat=0)
	if(grinchstart.len == 0)
		log_admin("Cannot accept Grinch ruleset. Couldn't find any grinch spawn points.")
		message_admins("Cannot accept Grinch ruleset. Couldn't find any grinch spawn points.")
		return 0
	if (!..())
		return FALSE
	var/MM = text2num(time2text(world.timeofday, "MM")) 	// get the current month
	var/DD = text2num(time2text(world.timeofday, "DD")) 	// get the current day
	var/accepted = (MM == 12 && DD > 15) || (MM == 1 && DD < 9) 	// Between the 15th of December and the 9th of January
	return accepted

//////////////////////////////////////////////
//                                          //
//               LOOSE CATBEAST             ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                 Minor Role               //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/catbeast
	name = "Loose Catbeast"
	role_category = /datum/role/catbeast
	required_candidates = 1
	weight = BASE_RULESET_WEIGHT
	cost = 0
	requirements = list(0,0,0,0,0,0,0,0,0,0)
	high_population_requirement = 0
	logo = "catbeast-logo"
	flags = MINOR_RULESET

/datum/dynamic_ruleset/midround/from_ghosts/catbeast/acceptable(var/population=0,var/threat=0)
	if(mode.midround_threat>50) //We're threatening enough!
		message_admins("Rejected catbeast ruleset, [mode.midround_threat] threat was over 50.")
		return FALSE
	if(!..())
		message_admins("Rejected catbeast ruleset. Not enough threat somehow??")
		return FALSE
	return TRUE

//////////////////////////////////////////////
//                                          //
//          Vox Heist			 (MIDROUND) ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/heist
	name = "Vox Heist"
	role_category = /datum/role/vox_raider
	my_fac = /datum/faction/vox_shoal
	enemy_jobs = list("AI", "Cyborg", "Security Officer", "Warden","Detective","Head of Security", "Captain")
	required_pop = list(20,20,20,15,15,15,15,15,10,10)
	required_candidates = 5
	weight = BASE_RULESET_WEIGHT
	cost = 25
	requirements = list(50,50,50,30,30,30,30,20,10,10)
	high_population_requirement = 35
	var/vox_cap = list(2,2,3,3,4,5,5,5,5,5)
	logo = "vox-logo"

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/heist/acceptable(var/population=0,var/threat=0)
	var/indice_pop = min(10,round(living_players.len/5)+1)
	required_candidates = vox_cap[indice_pop]
	return ..()

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/heist/ready(var/forced = 0)
	if (forced)
		required_candidates = 1
	if (required_candidates > (dead_players.len + list_observers.len))
		return 0
	. = ..()
	required_candidates = initial(required_candidates)

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/heist/finish_setup(var/mob/new_character, var/index)
	var/datum/faction/vox_shoal/shoal = find_active_faction_by_type(/datum/faction/vox_shoal)
	shoal.forgeObjectives()
	if (index == 1) // Our first guy is the leader
		var/datum/role/vox_raider/chief_vox/new_role = new
		new_role.AssignToRole(new_character.mind,1)
		setup_role(new_role)
	else
		return ..()

//////////////////////////////////////////////
//                                          //
//             PLAGUE MICE                  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/plague_mice
	name = "Plague Mice Invasion"
	role_category = /datum/role/plague_mouse
	enemy_jobs = list("Chief Medical Officer", "Medical Doctor", "Virologist")
	required_pop = list(15,15,15,15,15,15,15,15,15,15)
	required_candidates = 1
	max_candidates = 5
	weight = BASE_RULESET_WEIGHT
	cost = 25
	requirements = list(90,70,50,40,30,20,10,10,10,10)
	high_population_requirement = 40
	flags = MINOR_RULESET
	my_fac = /datum/faction/plague_mice
	logo = "plague-logo"

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/plague_mice/generate_ruleset_body(var/mob/applicant)
	var/datum/faction/plague_mice/active_fac = find_active_faction_by_type(my_fac)
	var/mob/living/simple_animal/mouse/plague/new_mouse = new (active_fac.invasion)
	new_mouse.key = applicant.key
	return new_mouse

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/plague_mice/setup_role(var/datum/role/new_role)
	my_fac.HandleRecruitedRole(new_role)
	new_role.Greet(GREET_DEFAULT)
	new_role.AnnounceObjectives()

//////////////////////////////////////////////
//                                          //
//          SPIDER INFESTATION              ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/spider_infestation
	name = "Spider Infestation"
	role_category = /datum/role/giant_spider
	//no enemy jobs, it's just a bunch of spiders
	//might change later if they actually happen to stomp the crew but that seems pretty unlikely
	required_candidates = 1
	max_candidates = 12 // max amount of spiderlings spawned by a spider infestation random event
	weight = BASE_RULESET_WEIGHT
	cost = 25
	requirements = list(90,80,60,40,30,20,10,10,10,10)
	high_population_requirement = 50
	flags = MINOR_RULESET
	my_fac = /datum/faction/spider_infestation
	logo = "spider-logo"

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/spider_infestation/generate_ruleset_body(var/mob/applicant)
	var/datum/faction/spider_infestation/active_fac = find_active_faction_by_type(my_fac)
	if (!active_fac.invasion)
		active_fac.SetupSpawn()
	var/mob/living/simple_animal/hostile/giant_spider/spiderling/new_spider = new (active_fac.invasion)
	new_spider.key = applicant.key
	return new_spider

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/spider_infestation/setup_role(var/datum/role/new_role)
	my_fac.HandleRecruitedRole(new_role)
	new_role.Greet(GREET_DEFAULT)
	new_role.AnnounceObjectives()

//////////////////////////////////////////////
//                                          //
//             XENOMORPHS                   ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/xenomorphs
	name = "Alien Infestation"
	role_category = /datum/role/xenomorph
	enemy_jobs = list("AI", "Cyborg", "Security Officer", "Warden","Detective","Head of Security", "Captain", "Roboticist")
	required_pop = list(25,20,20,15,15,15,10,10,10,10)
	required_candidates = 1
	max_candidates = 3
	weight = 1
	cost = 30
	requirements = list(90,90,70,60,50,40,20,10,10,10)
	high_population_requirement = 35
	logo = "xeno-logo"
	my_fac = /datum/faction/xenomorph
	var/list/vents = list()

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/xenomorphs/ready()
	..()
	for(var/obj/machinery/atmospherics/unary/vent_pump/temp_vent in atmos_machines)
		if(temp_vent.loc.z == map.zMainStation && !temp_vent.welded && temp_vent.network)
			if(temp_vent.network.normal_members.len > 50)	//Stops Aliens getting stuck in small networks. See: Security, Virology
				vents += temp_vent


	if (vents.len == 0)
		message_admins("A suitable vent couldn't be found for alien larva. That's bad.")
		return
	return 1

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/xenomorphs/generate_ruleset_body(var/mob/applicant)
	var/obj/vent = pick(vents)
	var/mob/living/carbon/alien/larva/new_xeno = new(vent.loc)

	new_xeno.key = applicant.key
	new_xeno << sound('sound/voice/alienspawn.ogg')
	if(vents.len > 1)
		vents -= vent

	return new_xeno

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/xenomorph/setup_role(var/datum/role/new_role)
	my_fac.HandleRecruitedRole(new_role)

//////////////////////////////////////////////
//                                          //
//             Prisoner                     ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/prisoner
	name = "Prisoner Transfer"
	role_category = /datum/role/prisoner
	restricted_from_jobs = list()
	enemy_jobs = list("Warden","Head of Security")
	required_enemies = list(1,1,1,1,1,1,1,1,1,1)
	required_pop = list(0,0,10,10,15,15,20,20,20,25)
	required_candidates = 1
	weight = 3
	cost = 0
	requirements = list(5,5,15,15,20,20,20,20,40,70)
	high_population_requirement = 10
	flags = MINOR_RULESET
	makeBody = FALSE

/datum/dynamic_ruleset/midround/from_ghosts/prisoner/setup_role(var/datum/role/new_role)
	new_role.OnPostSetup()
	if(prob(80))
		new_role.Greet(GREET_DEFAULT)
		new_role.ForgeObjectives()
		new_role.AnnounceObjectives()
	else
		to_chat(new_role.antag.current, "<B>You are an <span class='warning'>innocent</span> prisoner!</B>")
		to_chat(new_role.antag.current, "You are a Nanotrasen Employee that has been wrongfully accused of espionage! The exact details of your situation are hazy, but you know that you are innocent.")
		to_chat(new_role.antag.current, "You were transferred to this station through a request by the station's security team. You know nothing about this station or the people aboard it.")
		to_chat(new_role.antag.current, "<span class='danger'>Remember that you are not affiliated with the Syndicate. Protect yourself and work towards freedom, but remember that you have no place left to go.</span>")
		new_role.Drop()

/datum/dynamic_ruleset/midround/from_ghosts/prisoner/finish_setup(mob/new_character, index)
	command_alert(/datum/command_alert/prisoner_transfer)
	sleep(2 MINUTES)

	//the applicant left or something
	if(!new_character)
		return

	new_character = generate_ruleset_body(new_character)
	var/datum/role/new_role = new role_category
	new_role.AssignToRole(new_character.mind,1)
	setup_role(new_role)

	//Send the shuttle that they spawned on.
	var/obj/docking_port/destination/transport/station/stationdock = locate(/obj/docking_port/destination/transport/station) in all_docking_ports
	var/obj/docking_port/destination/transport/centcom/centcomdock = locate(/obj/docking_port/destination/transport/centcom) in all_docking_ports

	spawn(59 SECONDS)	//its 59 seconds to make sure they cant unbuckle themselves beforehand
		if(!transport_shuttle.move_to_dock(stationdock))
			message_admins("PRISONER TRANSFER SHUTTLE FAILED TO MOVE! PANIC!")
			return

		//Try to send the shuttle back every 15 seconds
		while(transport_shuttle.current_port == stationdock)
			sleep(150)
			if(!can_move_shuttle())
				continue

			sleep(50)	//everyone is off, wait 5 more seconds so people don't get ZAS'd out the airlock
			if(!can_move_shuttle())
				continue
			if(!transport_shuttle.move_to_dock(centcomdock))
				message_admins("The transport shuttle couldn't return to centcomm for some reason.")
				return

/datum/dynamic_ruleset/midround/from_ghosts/prisoner/proc/can_move_shuttle()
	var/contents = get_contents_in_object(transport_shuttle.linked_area)
	if (locate(/mob/living) in contents)
		return FALSE
	if (locate(/obj/item/weapon/disk/nuclear) in contents)
		return FALSE
	if (locate(/obj/machinery/nuclearbomb) in contents)
		return FALSE
	if (locate(/obj/item/beacon) in contents)
		return FALSE
	if (locate(/obj/effect/portal) in contents)
		return FALSE
	return TRUE

//////////////////////////////////////////////
//                                          //
//         JUDGE                            ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                          //
//////////////////////////////////////////////

/datum/dynamic_ruleset/midround/from_ghosts/faction_based/judge
	name = "Judge"
	role_category = /datum/role/judge
	my_fac = /datum/faction/justice
	required_pop = list(101,101,101,101,101,101,101,101,101,101)
	required_candidates = 1
	max_candidates = 5
	weight = BASE_RULESET_WEIGHT
	cost = 20
	requirements = list(10,10,10,10,10,10,10,10,10,10)
	logo = "gun-logo"
	repeatable = TRUE
