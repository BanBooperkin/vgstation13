////////////////////////////////////////////////////////////////////////////////
/// Syringes.
////////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/reagent_containers/syringe
	name = "syringe"
	desc = "A syringe."
	icon = 'icons/obj/syringe.dmi'
	item_state = "syringe_0"
	icon_state = "0"
	amount_per_transfer_from_this = 5
	sharpness = 1
	sharpness_flags = SHARP_TIP
	possible_transfer_amounts = null //list(5,10,15)
	volume = 15
	starting_materials = list(MAT_GLASS = 1000)
	w_type = RECYK_GLASS

	var/mode = SYRINGE_DRAW
	var/can_draw_blood = TRUE
	var/can_stab = TRUE

	// List of types that can be injected regardless of the CONTAINEROPEN flag
	// TODO Remove snowflake
	var/injectable_types = list(/obj/item/weapon/reagent_containers/food,
	                            /obj/item/slime_extract,
	                            /obj/item/clothing/mask/cigarette,
	                            /obj/item/weapon/storage/fancy/cigarettes,
	                            /obj/item/gum,
	                            /obj/item/weapon/implantcase/chem,
	                            /obj/item/weapon/reagent_containers/pill/time_release,
	                            /obj/item/clothing/mask/facehugger/lamarr,
	                            /obj/item/asteroid/hivelord_core,
								/obj/item/weapon/reagent_containers/blood,
								/obj/item/weapon/light,
								/obj/item/weapon/fossil/egg)

/obj/item/weapon/reagent_containers/syringe/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(istype(W, /obj/item/weapon/pen) || istype(W, /obj/item/device/flashlight/pen))
		set_tiny_label(user)

/obj/item/weapon/reagent_containers/syringe/suicide_act(var/mob/living/user)
	to_chat(viewers(user), "<span class='danger'>[user] appears to be injecting an air bubble using a [src.name]! It looks like \he's trying to commit suicide.</span>")
	return(SUICIDE_ACT_OXYLOSS)

/obj/item/weapon/reagent_containers/syringe/on_reagent_change()
	update_icon()

/obj/item/weapon/reagent_containers/syringe/pickup(mob/user)
	..()
	update_icon()

/obj/item/weapon/reagent_containers/syringe/dropped(mob/user)
	..()
	update_icon()

/obj/item/weapon/reagent_containers/syringe/attack_self(mob/user as mob)
	switch(mode)
		if(SYRINGE_DRAW)
			mode = SYRINGE_INJECT
		if(SYRINGE_INJECT)
			mode = SYRINGE_DRAW
		if(SYRINGE_BROKEN)
			return
	update_icon()

/obj/item/weapon/reagent_containers/syringe/attack_hand(var/mob/user)
	..()
	update_icon()

/obj/item/weapon/reagent_containers/syringe/attack_paw(var/mob/user)
	return attack_hand(user)

/obj/item/weapon/reagent_containers/syringe/attack(mob/M as mob, mob/user as mob, def_zone)
	return //Stop trying to drink from syringes!

/obj/item/weapon/reagent_containers/syringe/afterattack(obj/target, mob/user, proximity_flag, click_parameters)
	if(proximity_flag == 0) // not adjacent
		return

	if(!target.reagents && !is_type_in_list(target, injectable_types))
		return

	if(mode == SYRINGE_BROKEN)
		to_chat(user, "<span class='warning'>\The [src] is broken!</span>")
		return

	if (user.a_intent == I_HURT && ismob(target))
		if(clumsy_check(user) && prob(50))
			target = user

		if (target != user && !can_stab) // You still can stab yourself if you're clumsy, honk
			to_chat(user, "<span class='notice'>You can't grasp \the [src] properly for stabbing!</span>")
			return

		syringestab(target, user)
		return

	if (mode == SYRINGE_DRAW)
		handle_draw(target, user)
	else if (mode == SYRINGE_INJECT)
		handle_inject(target, user)

/obj/item/weapon/reagent_containers/syringe/update_icon()
	if(mode == SYRINGE_BROKEN)
		icon_state = "broken"
		overlays.len = 0
		return
	var/rounded_vol = round(reagents.total_volume,5)
	if(0 < reagents.total_volume && reagents.total_volume < 5)
		rounded_vol = 5
	overlays.len = 0
	if(ismob(loc))
		var/injoverlay
		switch(mode)
			if (SYRINGE_DRAW)
				injoverlay = "draw"
			if (SYRINGE_INJECT)
				injoverlay = "inject"
		overlays += injoverlay
	icon_state = "[rounded_vol]"
	item_state = "syringe_[rounded_vol]"

	if(reagents.total_volume)
		var/image/filling = image('icons/obj/reagentfillings.dmi', src, "syringe10")

		filling.icon_state = "syringe[rounded_vol]"

		filling.icon += mix_color_from_reagents(reagents.reagent_list)
		overlays += filling

/obj/item/weapon/reagent_containers/syringe/proc/handle_draw(var/atom/target, var/mob/user)
	if (!target)
		return

	if (src.is_full())
		to_chat(user, "<span class='warning'>\The [src] is full.</span>")
		return

	// Drawing from mobs draws from their blood or equivalent
	if (ismob(target))
		if (!can_draw_blood)
			to_chat(user, "This needle isn't designed for drawing fluids from living things.")
			return

		if (istype(target, /mob/living/carbon/slime))
			to_chat(user, "<span class='warning'>You are unable to locate any blood.</span>")
			return

		if (reagents.has_reagent(BLOOD)) // TODO Current reagent system can't handle multiple blood sources properly
			to_chat(user, "<span class='warning'>There is already a blood sample in this syringe!</span>")
			return
		if(ishuman(target))
			var/mob/living/carbon/human/H = target
			if(H.species && (H.species.chem_flags & NO_INJECT))
				user.visible_message("<span class='warning'>[user] attempts to poke [H] with \the [src] but it won't go in!</span>", "<span class='notice'>You fail to pierce [H] with \the [src]</span>")
				return

		if (iscarbon(target))
			var/mob/living/carbon/T = target
			if (!T.dna)
				to_chat(user, "<span class='warning'>You are unable to locate any blood.</span>")
				warning("Tried to draw blood or equivalent from [target] (\ref[target]) but it's missing their DNA datum!")
				return

			if (M_HUSK in T.mutations) // Target has been husked
				to_chat(user, "<span class='warning'>You are unable to locate any blood.</span>")
				return

			var/amount = src.reagents.maximum_volume - src.reagents.total_volume
			var/datum/reagent/B = T.take_blood(src, amount)
			if (B)
				user.visible_message("<span class='notice'>[user] takes a blood sample from [target].</span>",
									 "<span class='notice'>You take a blood sample from [target].</span>")
			else
				user.visible_message("<span class='warning'>[user] inserts the syringe into [target], draws back the plunger and gets... nothing?</span>",\
					"<span class='warning'>You insert the syringe into [target], draw back the plunger and get... nothing?</span>")
		else if (ismouse(target))
			var/mob/living/simple_animal/mouse/T = target
			var/datum/reagent/B = T.take_blood(src, 5)
			if (B)
				user.visible_message("<span class='notice'>[user] takes a small blood sample from [target].</span>",
									 "<span class='notice'>You take a small blood sample from [target].</span>")
			else
				user.visible_message("<span class='warning'>[user] inserts the syringe into [target], draws back the plunger and gets... nothing?</span>",\
					"<span class='warning'>You insert the syringe into [target], draw back the plunger and get... nothing?</span>")
	// Drawing from objects draws their contents
	else if (isobj(target))
		if (!target.is_open_container() && !istype(target, /obj/item/slime_extract) && !istype(target, /obj/item/weapon/reagent_containers/blood))
			to_chat(user, "<span class='warning'>You cannot directly remove reagents from this object.")
			return

		if (istype(target, /obj/item/weapon/reagent_containers/blood))
			var/obj/item/weapon/reagent_containers/blood/L = target
			if (L.mode == BLOODPACK_CUT)
				to_chat(user, "<span class='warning'>With so many cuts in it... not a good idea.</span>")
				return

		var/tx_amount = 0
		if (istype(target, /obj/item/weapon/reagent_containers) || istype(target, /obj/structure/reagent_dispensers))
			tx_amount = transfer_sub(target, src, amount_per_transfer_from_this, user)
		else
			tx_amount = target.reagents.trans_to(src, amount_per_transfer_from_this)

		if (tx_amount > 0)
			to_chat(user, "<span class='notice'>You fill \the [src] with [tx_amount] units of the solution.</span>")
		else if (tx_amount == 0)
			to_chat(user, "<span class='warning'>\The [target] is empty.</span>")

	if (src.is_full())
		mode = SYRINGE_INJECT
		update_icon()

/obj/item/weapon/reagent_containers/syringe/proc/handle_inject(var/atom/target, var/mob/user)
	if(is_empty())
		to_chat(user, "<span class='warning'>\The [src] is empty.</span>")
		return

	// TODO Remove snowflake
	if(!ismob(target) && !target.is_open_container() && !is_type_in_list(target, injectable_types))
		to_chat(user, "<span class='warning'>You cannot directly fill this object.</span>")
		return

	var/injection_result = target.on_syringe_injection(user, src)
	if(injection_result == INJECTION_RESULT_FAIL)
		return

	// The assumption is that on_syringe_injection did it
	if(injection_result != INJECTION_RESULT_SUCCESS_BUT_SKIP_REAGENT_TRANSFER)
		var/tx_amount = min(amount_per_transfer_from_this, reagents.total_volume)
		tx_amount = reagents.trans_to(target, tx_amount, log_transfer = TRUE, whodunnit = user)
		to_chat(user, "<span class='notice'>You inject [tx_amount] units of the solution. The syringe now contains [reagents.total_volume] units.</span>")

	if(is_empty())
		mode = SYRINGE_DRAW
		update_icon()

// Injecting people with a space suit/hardsuit is harder
/obj/item/weapon/reagent_containers/syringe/proc/get_injection_time(var/mob/target)
	if (istype(target, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = target
		return (H.wear_suit && istype(H.wear_suit, /obj/item/clothing/suit/space)) ? 60 : 30
	else
		return 30

/obj/item/weapon/reagent_containers/syringe/proc/get_injection_action(var/mob/target)
	if (istype(target, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = target
		return (H.wear_suit && istype(H.wear_suit,/obj/item/clothing/suit/space)) ? INJECTION_SUIT_PORT : INJECTION_BODY
	else
		return INJECTION_BODY

/obj/item/weapon/reagent_containers/syringe/proc/syringestab(mob/living/carbon/target as mob, mob/living/carbon/user as mob)
	if (ishuman(target))
		var/mob/living/carbon/human/H = target
		var/target_zone = check_zone(user.zone_sel.selecting, target)
		var/datum/organ/external/affecting = H.get_organ(target_zone)

		if (!affecting)
			return
		else if (affecting.status & ORGAN_DESTROYED)
			to_chat(user, "What [affecting.display_name]?")
			return

		var/hit_area = affecting.display_name
		if((user != target) && H.check_shields(7, src))
			return

		// Check for protection on the targeted area and show messages
		var/deflected = (target != user && target.getarmor(target_zone, "melee") > 5 && prob(50))

		add_attacklogs(user, target, (deflected ? "attempted to inject" : "injected"), object = src, addition = "Deflected: [deflected ? "YES" : "NO"]; Reagents: [english_list(get_reagent_names())]", admin_warn = !deflected)

		if (deflected)
			user.visible_message("<span class='danger'>[user] tries to stab [target] in \the [hit_area] with \the [src], but the attack is deflected by armor!</span>", "<span class='danger'>You try to stab [target] in \the [hit_area] with \the [src], but the attack is deflected by armor!</span>")
			user.u_equip(src, 1)
			qdel(src)
			return // Avoid the transfer since we're using qdel
		else
			user.visible_message("<span class='danger'>[user] stabs [target] in \the [hit_area] with \the [src]!</span>", "<span class='danger'>You stab [target] in \the [hit_area] with \the [src]!</span>")
			affecting.take_damage(3)
	else
		user.visible_message("<span class='danger'>[user] stabs [target] with \the [src]!</span>", "<span class='danger'>You stab [target] with \the [src]!</span>")
		target.take_organ_damage(3)// 7 is the same as crowbar punch

	// Break the syringe and transfer some of the reagents to the target
	src.reagents.reaction(target, INGEST)
	var/syringestab_amount_transferred = max(rand(min(reagents.total_volume, 2), (reagents.total_volume - 5)), 0) //nerfed by popular demand.
	src.reagents.trans_to(target, syringestab_amount_transferred)
	src.desc += " It is broken."
	src.mode = SYRINGE_BROKEN
	src.add_blood(target)
	src.add_fingerprint(usr)
	src.update_icon()

/obj/item/weapon/reagent_containers/syringe/restock()
	if(mode == 2) //SYRINGE_BROKEN
		mode = 0 //SYRINGE_DRAW
		update_icon()

/obj/item/weapon/reagent_containers/syringe/broken
	desc = "A syringe. It is broken."
	icon_state = "broken"
	mode = SYRINGE_BROKEN

/obj/item/weapon/reagent_containers/syringe/giant
	name = "giant syringe"
	desc = "A syringe commonly used for lethal injections."
	amount_per_transfer_from_this = 50
	possible_transfer_amounts = null
	volume = 50

	can_draw_blood = FALSE
	can_stab = FALSE

/obj/item/weapon/reagent_containers/syringe/giant/New()
	..()
	appearance_flags |= PIXEL_SCALE
	var/matrix/gisy = matrix()
	gisy.Scale(1.2,1.2)
	transform = gisy

/obj/item/weapon/reagent_containers/syringe/giant/get_injection_time(var/mob/target)
	if (istype(target, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = target
		return (H.wear_suit && istype(H.wear_suit, /obj/item/clothing/suit/space)) ? 330 : 300
	else
		return 300

/obj/item/weapon/reagent_containers/syringe/giant/update_icon()
	if (mode == SYRINGE_BROKEN)
		icon_state = "broken"
		return

	var/rounded_vol = round(reagents.total_volume, 50)
	icon_state = (ismob(loc) ? "[mode == SYRINGE_DRAW ? "d" : "i"][rounded_vol]" : "[rounded_vol]")
	item_state = "syringe_[rounded_vol]"

////////////////////////////////////////////////////////////////////////////////
/// Syringes. END
////////////////////////////////////////////////////////////////////////////////



/obj/item/weapon/reagent_containers/syringe/inaprovaline
	name = "syringe (inaprovaline)"
	desc = "Contains inaprovaline - used to stabilize patients."
/obj/item/weapon/reagent_containers/syringe/inaprovaline/New()
	..()
	reagents.add_reagent(INAPROVALINE, 15)
	mode = SYRINGE_INJECT
	update_icon()

/obj/item/weapon/reagent_containers/syringe/antitoxin
	name = "syringe (anti-toxin)"
	desc = "Contains anti-toxins."
/obj/item/weapon/reagent_containers/syringe/antitoxin/New()
	..()
	reagents.add_reagent(ANTI_TOXIN, 15)
	mode = SYRINGE_INJECT
	update_icon()

/obj/item/weapon/reagent_containers/syringe/antiviral
	name = "syringe (spaceacillin)"
	desc = "Contains a generic antipathogenic - used to reinforce the immune system and eliminate diseases."
/obj/item/weapon/reagent_containers/syringe/antiviral/New()
	..()
	reagents.add_reagent(SPACEACILLIN, 15)
	mode = SYRINGE_INJECT
	update_icon()

/obj/item/weapon/reagent_containers/syringe/charcoal
	name = "syringe (activated charcoal)"
	desc = "Contains activated charcoal - used to treat overdoses."
/obj/item/weapon/reagent_containers/syringe/charcoal/New()
	..()
	reagents.add_reagent("charcoal", 15)
	mode = SYRINGE_INJECT
	update_icon()

/obj/item/weapon/reagent_containers/syringe/giant/chloral
	name = "lethal injection syringe"
	desc = "Puts people into a sleep they'll never wake up from."
/obj/item/weapon/reagent_containers/syringe/giant/chloral/New()
	..()
	reagents.add_reagent(CHLORALHYDRATE, 50)
	mode = SYRINGE_INJECT
	update_icon()

/obj/item/weapon/reagent_containers/syringe/syndi
	name = "syringe (syndicate mix)"
	desc = "Contains cyanide, chloral hydrate and lexorin. Something tells you it might be lethal on arrival."
/obj/item/weapon/reagent_containers/syringe/syndi/New()
	..()
	reagents.add_reagent(CYANIDE, 5)
	reagents.add_reagent(CHLORALHYDRATE, 5)
	reagents.add_reagent(LEXORIN, 5)
	mode = SYRINGE_INJECT
	update_icon()


//Robot syringes
//Not special in any way, code wise. They don't have added variables or procs.
/obj/item/weapon/reagent_containers/syringe/robot/antitoxin
	name = "syringe (anti-toxin)"
	desc = "Contains anti-toxins."
/obj/item/weapon/reagent_containers/syringe/robot/antitoxin/New()
	..()
	reagents.add_reagent(ANTI_TOXIN, 15)
	mode = SYRINGE_INJECT
	update_icon()

/obj/item/weapon/reagent_containers/syringe/robot/inoprovaline
	name = "syringe (inoprovaline)"
	desc = "Contains inaprovaline - used to stabilize patients."
/obj/item/weapon/reagent_containers/syringe/robot/inoprovaline/New()
	..()
	reagents.add_reagent(INAPROVALINE, 15)
	mode = SYRINGE_INJECT
	update_icon()

/obj/item/weapon/reagent_containers/syringe/robot/charcoal
	name = "syringe (activated charcoal)"
	desc = "Contains activated charcoal - used to treat overdoses."
/obj/item/weapon/reagent_containers/syringe/robot/charcoal/New()
	..()
	reagents.add_reagent("charcoal", 15)
	mode = SYRINGE_INJECT
	update_icon()

/obj/item/weapon/reagent_containers/syringe/robot/mixed
	name = "syringe (mixed)"
	desc = "Contains inaprovaline & anti-toxins."
/obj/item/weapon/reagent_containers/syringe/robot/mixed/New()
	..()
	reagents.add_reagent(INAPROVALINE, 7)
	reagents.add_reagent(ANTI_TOXIN, 8)
	mode = SYRINGE_INJECT
	update_icon()
