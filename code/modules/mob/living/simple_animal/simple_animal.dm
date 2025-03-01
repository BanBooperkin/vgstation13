var/const/ANIMAL_CHILD_CAP = 50
var/global/list/animal_count = list() //Stores types, and amount of animals of that type associated with the type (example: /mob/living/simple_animal/dog = 10)
//Animals can't breed if amount of children exceeds 50

/mob/living/simple_animal
	name = "animal"
	icon = 'icons/mob/animal.dmi'
	health = 20
	maxHealth = 20
	treadmill_speed = 0.5 //Ian & pals aren't as good at powering a treadmill

	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat/animal

	var/icon_living = ""
	var/icon_dead = ""
	var/icon_gib = null	//We only try to show a gibbing animation if this exists.
	var/icon_attack = null //We only try to show an attacking animation if it exists
	var/icon_attack_time //How long the ahove animation runs, in deciseconds
	var/icon_dying = null //We only try to show a dying animation if it exists.
	var/icon_dying_time //How long the above animation runs in deciseconds

	var/list/speak = list()
	//var/list/speak_emote = list()//	Emotes while speaking IE: Ian [emote], [text] -- Ian barks, "WOOF!". Spoken text is generated from the speak variable.
	var/speak_chance = 0
	var/list/emote_hear = list()	//Hearable emotes
	var/list/emote_see = list()		//Unlike speak_emote, the list of things in this variable only show by themselves with no spoken text. IE: Ian barks, Ian yaps
	var/list/emote_sound = list()   //Plays a random sound if the mob triggers speak or emote_hear
	var/last_speech_time = 0 //When did they last talk?

	var/speak_override = FALSE

	var/turns_per_move = 1
	var/turns_since_move = 0

	var/stop_automated_movement = 0 //Use this to temporarely stop random movement or to if you write special movement code for animals.
	var/wander = 1	// Does the mob wander around when idle?
	var/stop_automated_movement_when_pulled = 1 //When set to 1 this stops the animal from moving when someone is pulling it.
	//Interaction
	var/response_help   = "pokes"
	var/response_disarm = "shoves"
	var/response_harm   = "hits"
	var/harm_intent_damage = 3

	//Temperature effect
	var/minbodytemp = 250
	var/maxbodytemp = 350
	var/heat_damage_per_tick = 3	//amount of damage applied if animal's body temperature is higher than maxbodytemp
	var/cold_damage_per_tick = 2	//same as heat_damage_per_tick, only if the bodytemperature it's lower than minbodytemp
	var/fire_alert = 0
	var/oxygen_alert = 0
	var/toxins_alert = 0
	var/temperature_alert = 0

	var/show_stat_health = 1	//does the percentage health show in the stat panel for the mob

	//Atmos effect - Yes, you can make creatures that require plasma or co2 to survive. N2O is a trace gas and handled separately, hence why it isn't here. It'd be hard to add it. Hard and me don't mix (Yes, yes make all the dick jokes you want with that.) - Errorage
	var/min_oxy = 5
	var/max_oxy = 0					//Leaving something at 0 means it's off - has no maximum
	var/min_tox = 0
	var/max_tox = 1
	var/min_co2 = 0
	var/max_co2 = 5
	var/min_n2 = 0
	var/max_n2 = 0
	var/unsuitable_atoms_damage = 2	//This damage is taken when atmos doesn't fit all the requirements above


	mob_bump_flag = SIMPLE_ANIMAL
	mob_swap_flags = MONKEY|SLIME|SIMPLE_ANIMAL
	mob_push_flags = MONKEY|SLIME|SIMPLE_ANIMAL
	status_flags = CANPUSH //They cannot be conventionally stunned. AIs normally ignore this but stuns used to be able to disable player-controlled ones

	//LETTING SIMPLE ANIMALS ATTACK? WHAT COULD GO WRONG. Defaults to zero so Ian can still be cuddly
	var/melee_damage_lower = 0
	var/melee_damage_upper = 0
	var/melee_damage_type = BRUTE
	var/attacktext = "attacks"
	var/attack_sound = null
	var/friendly = "nuzzles" //If the mob does no damage with its attack
//	var/environment_smash = 0 //Set to 1 to allow breaking of crates,lockers,racks,tables; 2 for walls; 3 for Rwalls
	var/environment_smash_flags = 0

	var/speed = 1 //Higher speed is slower, decimal speed is faster. DO NOT SET THIS TO NEGATIVES OR 0. MAKING THIS SMALLER THAN 1 MAKES YOUR MOB SUPER FUCKING FAST BE WARNED.

	//Hot simple_animal baby making vars
	var/childtype = null
	var/child_amount = 1
	var/scan_ready = 1
	var/can_breed = 0

	//Null rod stuff
	var/supernatural = 0
	var/purge = 0

	//For those that we want to just pop back up a little while after they're killed
	var/canRegenerate = 0 //If 1, it qualifies for regeneration
	var/isRegenerating = 0 //To stop life calling the proc multiple times
	var/minRegenTime = 0
	var/maxRegenTime = 0

	universal_speak = 1
	universal_understand = 1

	var/life_tick = 0
	var/list/colourmatrix = list()
	var/colour //Used for retaining color in breeding.

	var/is_pet = FALSE //We're somebody's precious, precious pet.

	var/pacify_aura = FALSE

/mob/living/simple_animal/apply_beam_damage(var/obj/effect/beam/B)
	var/lastcheck=last_beamchecks["\ref[B]"]

	var/damage = ((world.time - lastcheck)/10)  * (B.get_damage()/2)

	// Actually apply damage
	health -= damage

	// Update check time.
	last_beamchecks["\ref[B]"]=world.time

/mob/living/simple_animal/rejuvenate(animation = 0)
	var/turf/T = get_turf(src)
	if(animation)
		T.turf_animation('icons/effects/64x64.dmi',"rejuvinate",-16,0,MOB_LAYER+1,'sound/effects/rejuvinate.ogg',anim_plane = EFFECTS_PLANE)
	src.health = src.maxHealth
	return 1

/mob/living/simple_animal/New()
	..()
	if(!(mob_property_flags & (MOB_UNDEAD|MOB_CONSTRUCT|MOB_ROBOTIC|MOB_HOLOGRAPHIC)))
		create_reagents(100)
	verbs -= /mob/verb/observe
	if(!real_name)
		real_name = name

	animal_count[src.type]++

/mob/living/simple_animal/Destroy()
	if (stat != DEAD)
		animal_count[src.type]--//dealing with mobs getting deleted while still alive
	..()

/mob/living/simple_animal/Login()
	if(src && src.client)
		src.client.reset_screen()
	walk(src,0) //If the mob was in the process of moving somewhere, this should override it so PC mobs aren't banded back
	..()

/mob/living/simple_animal/updatehealth()
	return

/mob/living/simple_animal/airflow_stun()
	return

/mob/living/simple_animal/airflow_hit(atom/A)
	return

// For changing wander behavior
/mob/living/simple_animal/proc/wander_move(var/turf/dest)
	if(space_check())
		if(istype(src, /mob/living/simple_animal/hostile))
			var/mob/living/simple_animal/hostile/H = src
			set_glide_size(DELAY2GLIDESIZE(H.move_to_delay))
		else
			set_glide_size(DELAY2GLIDESIZE(0.5 SECONDS))
		Move(dest)

/mob/living/simple_animal/proc/check_environment_susceptibility()
	return TRUE

/mob/living/simple_animal/Life()
	if(timestopped)
		return 0 //under effects of time magick
	..()

	//Health
	if(stat == DEAD)
		if(health > 0)
			icon_state = icon_living
			src.resurrect()
			stat = CONSCIOUS
			animal_count[src.type]++//re-added to the count
			setDensity(TRUE)
			update_canmove()
		if(canRegenerate && !isRegenerating)
			src.delayedRegen()
		return 0

	if(health < 1 && stat != DEAD)
		death()
		return 0

	life_tick++

	health = min(health, maxHealth)

	if(stunned)
		AdjustStunned(-1)
	if(knockdown)
		AdjustKnockdown(-1)
	if(paralysis)
		AdjustParalysis(-1)
	update_canmove()

	handle_jitteriness()
	jitteriness = max(0, jitteriness - 1)

	//Eyes
	if(sdisabilities & BLIND)	//disabled-blind, doesn't get better on its own
		blinded = 1
	else if(eye_blind)			//blindness, heals slowly over time
		eye_blind = max(eye_blind-1,0)
		blinded = 1
	else if(eye_blurry)	//blurry eyes heal slowly
		eye_blurry = max(eye_blurry-1, 0)

	//Ears
	if(sdisabilities & DEAF)	//disabled-deaf, doesn't get better on its own
		ear_deaf = max(ear_deaf, 1)
	else if(ear_deaf)			//deafness, heals slowly over time
		ear_deaf = max(ear_deaf-1, 0)
	else if(ear_damage < 25)	//ear damage heals slowly under this threshold.
		ear_damage = max(ear_damage-0.05, 0)

	remove_confused(1)

	if(say_mute)
		say_mute = max(say_mute-1, 0)

	if(purge)
		purge -= 1

	isRegenerating = 0

	//Movement
	if((!client||deny_client_move) && !stop_automated_movement && wander && !anchored && (ckey == null) && !(flags & INVULNERABLE))
		if(isturf(src.loc) && canmove)		//This is so it only moves if it's not inside a closet, gentics machine, etc.
			turns_since_move++
			if(turns_since_move >= turns_per_move)
				if(!(stop_automated_movement_when_pulled && pulledby)) //Some animals don't move when pulled
					lazy_invoke_event(/lazy_event/on_before_move)
					var/destination = get_step(src, pick(cardinal))
					wander_move(destination)
					turns_since_move = 0
					lazy_invoke_event(/lazy_event/on_after_move)

	handle_automated_speech()

	var/datum/gas_mixture/environment
	if(loc)
		environment = loc.return_air()

	handle_environment(environment)
	handle_regular_hud_updates()

	if(can_breed)
		make_babies()

	if(reagents)
		reagents.metabolize(src)
	return 1

/mob/living/simple_animal/handle_regular_hud_updates()
	if(!..())
		return FALSE

	if(oxygen_alert)
		throw_alert(SCREEN_ALARM_BREATH, /obj/abstract/screen/alert/carbon/breath)
	else
		clear_alert(SCREEN_ALARM_BREATH)
	if(toxins_alert)
		throw_alert(SCREEN_ALARM_TOXINS, /obj/abstract/screen/alert/tox)
	else
		clear_alert(SCREEN_ALARM_TOXINS)
	if(fire_alert)
		throw_alert(SCREEN_ALARM_FIRE, /obj/abstract/screen/alert/carbon/burn/fire, fire_alert)
	else
		clear_alert(SCREEN_ALARM_FIRE)
	if(temperature_alert)
		throw_alert(SCREEN_ALARM_TEMPERATURE, temperature_alert < 0 ? /obj/abstract/screen/alert/carbon/temp/cold : /obj/abstract/screen/alert/carbon/temp/hot, temperature_alert)
	else
		clear_alert(SCREEN_ALARM_TEMPERATURE)
	return TRUE

/mob/living/simple_animal/proc/handle_environment(datum/gas_mixture/environment)
	toxins_alert = 0
	if(flags & INVULNERABLE)
		return

	var/atmos_suitable = 1

	if(environment && check_environment_susceptibility())
		if(abs(environment.temperature - bodytemperature) > 40)
			bodytemperature += ((environment.temperature - bodytemperature) / 5)

		if(min_oxy)
			if(environment.molar_density(GAS_OXYGEN) < min_oxy / CELL_VOLUME)
				atmos_suitable = 0
				oxygen_alert = 1
			else
				oxygen_alert = 0

		if(max_oxy)
			if(environment.molar_density(GAS_OXYGEN) > max_oxy / CELL_VOLUME)
				atmos_suitable = 0

		if(min_tox)
			if(environment.molar_density(GAS_PLASMA) < min_tox / CELL_VOLUME)
				atmos_suitable = 0

		if(max_tox)
			if(environment.molar_density(GAS_PLASMA) > max_tox / CELL_VOLUME)
				atmos_suitable = 0
				toxins_alert = 1

		if(min_n2)
			if(environment.molar_density(GAS_NITROGEN) < min_n2 / CELL_VOLUME)
				atmos_suitable = 0

		if(max_n2)
			if(environment.molar_density(GAS_NITROGEN) > max_n2 / CELL_VOLUME)
				atmos_suitable = 0
				toxins_alert = 1

		if(min_co2)
			if(environment.molar_density(GAS_CARBON) < min_co2 / CELL_VOLUME)
				atmos_suitable = 0

		if(max_co2)
			if(environment.molar_density(GAS_CARBON) > max_co2 / CELL_VOLUME)
				atmos_suitable = 0
				toxins_alert = 1

	if(!atmos_suitable)
		adjustBruteLoss(unsuitable_atoms_damage)

	if(bodytemperature < minbodytemp)
		temperature_alert = TEMP_ALARM_COLD_STRONG
		adjustBruteLoss(cold_damage_per_tick)
	else if(bodytemperature > maxbodytemp)
		temperature_alert = TEMP_ALARM_HEAT_STRONG
		adjustBruteLoss(heat_damage_per_tick)
	else
		temperature_alert = 0

/mob/living/simple_animal/gib(var/animation = 0, var/meat = 1)
	if(icon_gib)
		anim(target = src, a_icon = icon, flick_anim = icon_gib, sleeptime = 15)

	if(meat && meat_type)
		for(var/i = 0; i < (src.size - meat_taken); i++)
			drop_meat(get_turf(src))

	..()


/mob/living/simple_animal/blob_act()
	..()
	adjustBruteLoss(20)
	return

/mob/living/simple_animal/say_quote(var/text)
	if(speak_emote && speak_emote.len)
		var/emote = pick(speak_emote)
		if(emote)
			if(emote_sound.len && world.time > last_speech_time + 10) //Delay before next sound
				playsound(loc, "[pick(emote_sound)]", 80, 1)
				last_speech_time = world.time
			return "[emote], [text]"
	return "says, [text]";

/mob/living/simple_animal/emote(var/act, var/type, var/desc, var/auto, var/message = null, var/ignore_status = FALSE)
	if(timestopped)
		return //under effects of time magick
	if(stat)
		return
	if(act == "scream")
		desc = "makes a loud and pained whimper!"  //ugly hack to stop animals screaming when crushed :P
		act = "me"
	..(act, type, desc)


/mob/living/simple_animal/proc/handle_automated_speech()

	if(!speak_chance || !(speak.len || emote_hear.len || emote_see.len))
		return

	var/someone_in_earshot=0
	if(!client && ckey == null) // Remove this if earshot is used elsewhere.
		// All we're doing here is seeing if there's any CLIENTS nearby.
		for(var/mob/M in get_hearers_in_view(7, src))
			if(M.client)
				someone_in_earshot=1
				break

	if(someone_in_earshot && !istype(loc, /obj/item/device/mobcapsule))
		if(rand(0,200) < speak_chance)
			var/mode = pick(
			speak.len;      1,
			emote_hear.len; 2,
			emote_see.len;  3
			)

			switch(mode)
				if(1)
					say(pick(speak)) // The sound is in say_quote
				if(2)
					emote("me", MESSAGE_HEAR, "[pick(emote_hear)].")
					if(emote_sound.len)
						playsound(loc, "[pick(emote_sound)]", 80, 1)
				if(3)
					emote("me", MESSAGE_SEE, "[pick(emote_see)].")

/mob/living/simple_animal/attack_animal(mob/living/simple_animal/M)
	M.unarmed_attack_mob(src)

/mob/living/simple_animal/bullet_act(var/obj/item/projectile/Proj)
	if(!Proj)
		return PROJECTILE_COLLISION_DEFAULT
	Proj.on_hit(src, 0)
	adjustBruteLoss(Proj.damage)
	return PROJECTILE_COLLISION_DEFAULT

/mob/living/simple_animal/attack_hand(mob/living/carbon/human/M as mob)
	. = ..()

	switch(M.a_intent)
		if(I_HELP)
			if(health > 0)
				visible_message("<span class='notice'>[M] [response_help] [src].</span>")

		if(I_GRAB)
			M.grab_mob(src)

		if(I_DISARM)
			visible_message("<span class ='notice'>[M] [response_disarm] [src].</span>")

		if(I_HURT)
			M.unarmed_attack_mob(src)
			//adjustBruteLoss(harm_intent_damage)
			//visible_message("<span class='warning'>[M] [response_harm] [src]!</span>")


/mob/living/simple_animal/MouseDropFrom(mob/living/carbon/M)
	if(M != usr || !istype(M) || !Adjacent(M) || M.incapacitated())
		return ..()

	if(locked_to) //Atom locking
		return

	var/strength_of_M = (M.size - 1) //Can only pick up mobs whose size is less or equal to this value. Normal human's size is 3, so his strength is 2 - he can pick up TINY and SMALL animals. Varediting human's size to 5 will allow him to pick up goliaths.

	if((M.a_intent != I_HELP) && (src.size <= strength_of_M) && (isturf(src.loc)) && (src.holder_type))
		scoop_up(M)
	else
		..()

/mob/living/simple_animal/attack_alien(mob/living/carbon/alien/humanoid/M as mob)

	switch(M.a_intent)

		if (I_HELP)
			visible_message("<span class='notice'>[M] caresses [src] with its scythe like arm.</span>")
		if (I_GRAB)
			M.grab_mob(src)
		if(I_HURT, I_DISARM)
			M.unarmed_attack_mob(src)

/mob/living/simple_animal/attack_larva(mob/living/carbon/alien/larva/L as mob)

	switch(L.a_intent)
		if(I_HELP)
			visible_message("<span class='notice'>[L] rubs it's head against [src]</span>")


		else
			L.do_attack_animation(src, L)
			var/damage = rand(5, 10)
			visible_message("<span class='danger'>[L] bites [src]!</span>")

			if(stat != DEAD)
				visible_message("<span class='danger'>[L] feeds on [src]!</span>", "<span class='notice'>You feed on [src]!</span>")
				adjustBruteLoss(damage)
				L.growth = min(L.growth + damage, LARVA_GROW_TIME)


/mob/living/simple_animal/attack_slime(mob/living/carbon/slime/M as mob)
	if (!ticker)
		to_chat(M, "You cannot attack people before the game has started.")
		return

	if(M.Victim)
		return // can't attack while eating!

	visible_message("<span class='danger'>[M.name] glomps [src]!</span>")
	add_logs(M, src, "glomped on", 0)

	var/damage = rand(1, 3)

	if(istype(M,/mob/living/carbon/slime/adult))
		damage = rand(20, 40)
	else
		damage = rand(5, 35)

	adjustBruteLoss(damage)


	return


/mob/living/simple_animal/attackby(var/obj/item/O, var/mob/user, var/no_delay = FALSE, var/originator = null)
	if(istype(O, /obj/item/stack/medical))
		user.delayNextAttack(4)
		if(stat != DEAD)
			var/obj/item/stack/medical/MED = O
			if(health < maxHealth)
				if(MED.use(1))
					adjustBruteLoss(-MED.heal_brute)
					src.visible_message("<span class='notice'>[user] applies \the [MED] to \the [src].</span>")
		else
			to_chat(user, "<span class='notice'>This [src] is dead, medical items won't bring it back to life.</span>")
	else if((meat_type || butchering_drops) && (stat == DEAD))	//if the animal has a meat, and if it is dead.
		if(O.sharpness_flags & SHARP_BLADE)
			if(user.a_intent != I_HELP)
				to_chat(user, "<span class='info'>You must be on <b>help</b> intent to do this!</span>")
			else
				butcher()
				return 1
	else if (user.is_pacified(VIOLENCE_DEFAULT,src))
		return
	if(supernatural && isholyweapon(O))
		purge = 3
	..()



/mob/living/simple_animal/base_movement_tally()
	return speed

/mob/living/simple_animal/movement_tally_multiplier()
	. = ..()
	if(purge) // Purged creatures will move more slowly. The more time before their purge stops, the slower they'll move. (muh dotuh)
		. *= purge

/mob/living/simple_animal/Stat()
	..()

	if(statpanel("Status") && show_stat_health)
		stat(null, "Health: [round((health / maxHealth) * 100)]%")

/mob/living/simple_animal/death(gibbed)
	if(stat == DEAD)
		return

	if(!gibbed)
		emote("deathgasp", message = TRUE)

	health = 0 // so /mob/living/simple_animal/Life() doesn't magically revive them
	stat = DEAD
	if(icon_dying && !gibbed)
		do_flick(src, icon_dying, icon_dying_time)
	icon_state = icon_dead
	setDensity(FALSE)

	animal_count[src.type]--
	var/list/animal_butchering_products = get_butchering_products()
	if(!src.butchering_drops && animal_butchering_products.len > 0) //If we already created a list of butchering drops, don't create another one
		butchering_drops = list()

		for(var/butchering_type in animal_butchering_products)
			butchering_drops += new butchering_type

	..(gibbed)


/mob/living/simple_animal/ex_act(severity)
	if(flags & INVULNERABLE)
		return
	..()
	switch (severity)
		if (1.0)
			adjustBruteLoss(500)
			gib()
			return

		if (2.0)
			adjustBruteLoss(60)


		if(3.0)
			adjustBruteLoss(30)

/mob/living/simple_animal/adjustBruteLoss(damage)

	if(lazy_invoke_event(/lazy_event/on_damaged, list("kind" = BRUTE, "amount" = damage)))
		return 0
	if (damage > 0)
		damageoverlaytemp = 20
	if(skinned())
		damage = damage * 2
	if(purge)
		damage = damage * 2

	health = clamp(health - damage, 0, maxHealth)
	if(health < 1 && stat != DEAD)
		death()

/mob/living/simple_animal/adjustFireLoss(damage)
	if(status_flags & GODMODE)
		return 0
	if(mutations.Find(M_RESIST_HEAT))
		return 0
	if(lazy_invoke_event(/lazy_event/on_damaged, list("kind" = BURN, "amount" = damage)))
		return 0
	if(skinned())
		damage = damage * 2
	if(purge)
		damage = damage * 2
	health = clamp(health - damage, 0, maxHealth)
	if(health < 1 && stat != DEAD)
		death()

/mob/living/simple_animal/proc/skinned()
	if(butchering_drops)
		var/datum/butchering_product/skin/skin = locate(/datum/butchering_product/skin) in butchering_drops
		if(istype(skin))
			if(skin.amount != skin.initial_amount)
				return 1
	return 0

/mob/living/simple_animal/proc/SA_attackable(target)
	return CanAttack(target)

/mob/living/simple_animal/proc/CanAttack(var/atom/target)
	if(see_invisible < target.invisibility)
		return 0
	if (isliving(target))
		var/mob/living/L = target
		if(!L.stat && L.health >= 0)
			return (0)
	if (istype(target,/obj/mecha))
		var/obj/mecha/M = target
		if (M.occupant)
			return (0)
	if (istype(target,/obj/machinery/bot))
		var/obj/machinery/bot/B = target
		if(B.health > 0)
			return (0)
	return (1)

//Call when target overlay should be added/removed
/mob/living/simple_animal/update_targeted()
	if(!targeted_by && target_locked)
		del(target_locked)
	overlays = null
	if (targeted_by && target_locked)
		overlays += target_locked



/mob/living/simple_animal/update_fire()
	return
/mob/living/simple_animal/IgniteMob()
	return 0
/mob/living/simple_animal/ExtinguishMob()
	return

/mob/living/simple_animal/revive(refreshbutcher = 1)
	if(refreshbutcher)
		butchering_drops = null
		meat_taken = 0
	if(meat_taken)
		maxHealth = initial(maxHealth)
		maxHealth -= (initial(maxHealth) / meat_amount) * meat_taken
	health = maxHealth
	..(0)

/mob/living/simple_animal/proc/make_babies() // <3 <3 <3
	if(gender != FEMALE || stat || !scan_ready || !childtype || !species_type)
		return
	scan_ready = 0
	spawn(400)
		scan_ready = 1
	var/alone = 1
	var/mob/living/simple_animal/partner
	var/children = 0
	for(var/mob/living/M in oview(7, src))
		if(M.isUnconscious()) //Check if it's concious FIRSTER.
			continue
		else if(istype(M, childtype)) //Check for children FIRST.
			children++
		else if(istype(M, species_type))
			if(M.client)
				continue
			else if(!istype(M, childtype) && M.gender == MALE) //Better safe than sorry ;_;
				partner = M
		else if(istype(M, /mob/living))
			if(!istype(M, /mob/dead/observer) || M.stat != DEAD) //Make babies with ghosts or dead people nearby!
				alone = 0
				continue
	if(alone && partner && children < 3)
		give_birth()

/mob/living/simple_animal/proc/give_birth()
	for(var/i=1; i<=child_amount; i++)
		if(animal_count[childtype] > ANIMAL_CHILD_CAP)
			return 0

		var/mob/living/simple_animal/child = new childtype(loc)
		if(istype(child))
			child.inherit_mind(src)
		if(colour)
			child.colour = colour
			child.update_icon()

	return 1

/mob/living/simple_animal/proc/grow_up(type_override = null)
	var/new_type = species_type
	if(type_override)
		new_type = type_override

	if(src.type == new_type) //Already grown up
		return

	var/mob/living/simple_animal/new_animal = new new_type(src.loc)

	if(locked_to) //Handle atom locking
		var/atom/movable/A = locked_to
		A.unlock_atom(src)
		A.lock_atom(new_animal, /datum/locking_category/simple_animal)

	if(name != initial(name)) //Not chicken
		new_animal.name = name
	if(mind)
		mind.transfer_to(new_animal)
	new_animal.inherit_mind(src)

	if(colour)
		new_animal.colour = colour
		new_animal.update_icon()

	forceMove(get_turf(src))
	qdel(src)

	return new_animal

/mob/living/simple_animal/proc/inherit_mind(mob/living/simple_animal/from)
	src.faction = from.faction

/mob/living/simple_animal/say_understands(var/mob/other,var/datum/language/speaking = null)
	if(other)
		other = other.GetSource()
	if(issilicon(other))
		return 1
	return ..()

/mob/living/simple_animal/proc/reagent_act(id, method, volume)
	if(isDead())
		return

	switch(id)
		if(SACID)
			if(!supernatural)
				adjustBruteLoss(volume * 0.5)
		if(PACID)
			if(!supernatural)
				adjustBruteLoss(volume * 0.5)

/mob/living/simple_animal/proc/delayedRegen()
	set waitfor = 0
	isRegenerating = 1
	sleep(rand(minRegenTime, maxRegenTime)) //Don't want it being predictable
	src.resurrect()
	src.revive()
	visible_message("<span class='warning'>[src] appears to wake from the dead, having healed all wounds.</span>")
	isRegenerating = 0

/mob/living/simple_animal/proc/pointed_at(var/mob/pointer)
	return

/mob/living/simple_animal/proc/space_check() //Returns a 1 if you can move in space or can kick off of something, 0 otherwise
	if(Process_Spacemove())
		return 1
	var/spaced = 1
	for(var/turf/T in range(src,1))
		if(!istype(T, /turf/space))
			spaced = 0
			break
		for(var/atom/A in T.contents)
			if(istype(A,/obj/structure/lattice) \
				|| istype(A, /obj/structure/window) \
				|| istype(A, /obj/structure/grille))
				spaced = 0
				break
	if(spaced)
		walk(src,0)
	return !spaced

/mob/living/simple_animal/say(message, bubble_type)
	if(speak_override && copytext(message, 1, 2) != "*")
		return ..(pick(speak))
	else
		return ..()


/mob/living/simple_animal/proc/name_mob(mob/user)
	var/n_name = copytext(sanitize(input(user, "What would you like to name \the [src]?", "Renaming \the [src]", null) as text|null), 1, MAX_NAME_LEN)
	if(n_name && !user.incapacitated())
		name = "[n_name]"
	var/image/heart = image('icons/mob/animal.dmi',src,"heart-ani2")
	heart.plane = ABOVE_HUMAN_PLANE
	flick_overlay(heart, list(user.client), 20)


/mob/living/simple_animal/make_meat(location)
	var/obj/item/weapon/reagent_containers/food/snacks/meat/animal/ourMeat = new meat_type(location)
	if(!istype(ourMeat))
		return
	if(species_type)
		var/mob/living/specimen = species_type
		ourMeat.name = "[initial(specimen.name)] meat"
		ourMeat.animal_name = initial(specimen.name)
	else
		ourMeat.name = "[initial(name)] meat"
		ourMeat.animal_name = initial(name)
	return ourMeat


/mob/living/simple_animal/meatEndStep(mob/user)
	if(meat_taken < meat_amount)
		to_chat(user, "<span class='info'>You cut a chunk of meat out of \the [src].</span>")
		return
	to_chat(user, "<span class='info'>You butcher \the [src].</span>")
	if(size > SIZE_TINY) //Tiny animals don't produce gibs
		gib(meat = 0) //"meat" argument only exists for mob/living/simple_animal/gib()
	else
		qdel(src)

/datum/locking_category/simple_animal
