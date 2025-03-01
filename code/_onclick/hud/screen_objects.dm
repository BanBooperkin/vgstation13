/*
	Screen objects
	Todo: improve/re-implement

	Screen objects are only used for the hud and should not appear anywhere "in-game".
	They are used with the client/screen list and the screen_loc var.
	For more information, see the byond documentation on the screen_loc and screen vars.
*/

/obj/abstract
	vis_flags = 0

/obj/abstract/screen
	name = ""
	icon = 'icons/mob/screen1.dmi'
	layer = HUD_BASE_LAYER
	var/obj/master = null	//A reference to the object in the slot. Grabs or items, generally.
	var/gun_click_time = -100 //I'm lazy.
	var/globalscreen = 0 //This screen object is not unique to one screen, can be seen by many
	appearance_flags = NO_CLIENT_COLOR
	plane = HUD_PLANE

/obj/abstract/screen/Destroy()
	animate(src)
	master = null
	..()

/obj/abstract/screen/text
	icon = null
	icon_state = null
	mouse_opacity = 0
	screen_loc = "CENTER-7,CENTER-7"
	maptext_height = 480
	maptext_width = 480

/obj/abstract/screen/schematics
	var/datum/rcd_schematic/ourschematic

/obj/abstract/screen/schematics/New(var/atom/loc, var/datum/rcd_schematic/ourschematic)
	if(!ourschematic)
		qdel(src)
		return
	..()
	src.ourschematic = ourschematic
	icon = ourschematic.icon
	icon_state = ourschematic.icon_state
	name = ourschematic.name
	overlays += ourschematic.overlays
	transform = transform*0.8

/obj/abstract/screen/schematics/Click()
	if(ourschematic)
		ourschematic.clicked(usr)

/obj/abstract/screen/schematics/Destroy()
	ourschematic = null
	overlays = list()
	..()

/obj/abstract/screen/inventory
	var/slot_id	//The indentifier for the slot. It has nothing to do with ID cards.
	var/hand_index

/obj/abstract/screen/holomap
	icon = 'icons/480x480.dmi'
	icon_state = "blank"

/obj/abstract/screen/holomap/Click(location,control,params)
	var/obj/structure/deathsquad_gravpult/G = locate() in get_turf(usr)
	if (!G) return
	var/list/params_list = params2list(params)
	if (params_list.len)
		var/new_aim = clamp(text2num(params_list["icon-y"]), 0, 480)
		if (new_aim>6)
			G.aim = new_aim
			G.update_aim()



///////////////////////////////////////INTERFACE SCREEN OBJECT/////////////////////////////
//Alright, here's some documentation,
//Unlike most (all?) other screen objects, this one ISN'T added to client screens along with their HUD.
//Instead, it is stored by objects (such as computers, or other machines), and sent to users on demand
//This allows things such as useable buttons on holomaps, or other contextual prompts.
//Basically alternatives to pop-up windows. Good for immersions, etc.
//
//So here's how it works:
//1- a user opened your machine's interface, make and store a new /obj/abstract/screen/interface (check New() bellow to understand the different parameters)
//2- you can give your object a name so it wears it upon mouse_over
//3- add the object to your user's screen like so: user.client.screen += your_button
//4- once the user click on the button, interface_act() gets called. If your machine has multiple buttons, set different "action" vars to differentiate them.
//5- once the user has finished using your interface, DON'T forget to remove the object from their screen, and qdel() it.

/obj/abstract/screen/interface
	name = "Button"
	mouse_opacity = 1
	layer = HUD_ABOVE_ITEM_LAYER
	var/mob/user = null
	var/obj/machine = null
	var/action = ""

/obj/abstract/screen/interface/New(turf/loc,u,m,a,i,i_s="",l="CENTER,CENTER",px=0,py=0)
	user = u			//the user whose screen the button is gonna appear on, so we can relay the info to the machine
	machine = m			//the machine we're the interface of (ex: gravpult)
	action = a			//your action, use any string (ex:"Launch").
	icon = i			//your icon
	icon_state = i_s	//your icon_state
	screen_loc = l		//where your button will appear on the user's screen, check DM documentation for nomenclature.
	pixel_x = px		//pixel_x should you need it
	pixel_y = py		//pixel_y should you need it

/obj/abstract/screen/interface/Click(location,control,params)
	machine.interface_act(user,action)

/obj/proc/interface_act(var/user)//if your machine has multiple buttons, you may want to use a switch(). Think of this proc as some sort of Topic().
	return

///////////////////////////////////////

/obj/abstract/screen/close
	name = "close"
	globalscreen = 1

/obj/abstract/screen/close/Click()
	if(master)
		if(istype(master, /obj/item/weapon/storage))
			var/obj/item/weapon/storage/S = master
			S.close(usr)
		else if(istype(master, /obj/item/device/rcd))
			var/obj/item/device/rcd/rcd = master
			rcd.show_default(usr)
	return 1

/obj/abstract/screen/grab
	name = "grab"

/obj/abstract/screen/grab/Click()
	var/obj/item/weapon/grab/G = master
	G.s_click(src)
	return 1

/obj/abstract/screen/grab/attack_hand()
	return

/obj/abstract/screen/grab/attackby()
	return

/obj/abstract/screen/storage
	name = "storage"
	globalscreen = 1

/obj/abstract/screen/storage/Click(location, control, params)
	if(usr.attack_delayer.blocked())
		return
	if(usr.incapacitated())
		return 1
	if (istype(usr.loc,/obj/mecha)) // stops inventory actions in a mech
		if(istype(master,/obj/item/weapon/storage)) //should always be true, but sanity
			var/obj/item/weapon/storage/S = master
			if(!S.distance_interact(usr))
				return 1
			//else... continue onward to master.attackby
		else
			//master isn't storage, exit
			return 1
	if(master)
		var/obj/item/I = usr.get_active_hand()
		if(I)
			master.attackby(I, usr, params)
			//usr.next_move = world.time+2
	return 1

/obj/abstract/screen/gun
	name = "gun"
	icon = 'icons/mob/screen1.dmi'
	master = null
	dir = 2

	move
		name = "Allow Walking"
		icon_state = "no_walk0"
		screen_loc = ui_gun2

	run
		name = "Allow Running"
		icon_state = "no_run0"
		screen_loc = ui_gun3

	item
		name = "Allow Item Use"
		icon_state = "no_item0"
		screen_loc = ui_gun1

	mode
		name = "Toggle Gun Mode"
		icon_state = "gun0"
		screen_loc = ui_gun_select
		//dir = 1

/obj/abstract/screen/gun/MouseEntered(location,control,params)
	openToolTip(usr,src,params,title = name,content = desc)

/obj/abstract/screen/gun/MouseExited()
	closeToolTip(usr)

/proc/get_random_zone_sel()
	return pick("l_foot", "r_foot", "l_leg", "r_leg", "l_hand", "r_hand", "l_arm", "r_arm", "chest", "groin", "eyes", "mouth", "head")

/obj/abstract/screen/zone_sel
	name = "damage zone"
	icon_state = "zone_sel"
	screen_loc = ui_zonesel
	var/selecting = LIMB_CHEST

/obj/abstract/screen/zone_sel/Click(location, control,params)
	var/list/PL = params2list(params)
	var/icon_x = text2num(PL["icon-x"])
	var/icon_y = text2num(PL["icon-y"])
	var/old_selecting = selecting //We're only going to update_icon() if there's been a change

	switch(icon_y)
		if(1 to 3) //Feet
			switch(icon_x)
				if(10 to 15)
					selecting = LIMB_RIGHT_FOOT
				if(17 to 22)
					selecting = LIMB_LEFT_FOOT
				else
					return 1
		if(4 to 9) //Legs
			switch(icon_x)
				if(10 to 15)
					selecting = LIMB_RIGHT_LEG
				if(17 to 22)
					selecting = LIMB_LEFT_LEG
				else
					return 1
		if(10 to 13) //Hands and groin
			switch(icon_x)
				if(8 to 11)
					selecting = LIMB_RIGHT_HAND
				if(12 to 20)
					selecting = LIMB_GROIN
				if(21 to 24)
					selecting = LIMB_LEFT_HAND
				else
					return 1
		if(14 to 22) //Chest and arms to shoulders
			switch(icon_x)
				if(8 to 11)
					selecting = LIMB_RIGHT_ARM
				if(12 to 20)
					selecting = LIMB_CHEST
				if(21 to 24)
					selecting = LIMB_LEFT_ARM
				else
					return 1
		if(23 to 30) //Head, but we need to check for eye or mouth
			if(icon_x in 12 to 20)
				selecting = LIMB_HEAD
				switch(icon_y)
					if(23 to 24)
						if(icon_x in 15 to 17)
							selecting = "mouth"
					if(26) //Eyeline, eyes are on 15 and 17
						if(icon_x in 14 to 18)
							selecting = "eyes"
					if(25 to 27)
						if(icon_x in 15 to 17)
							selecting = "eyes"

	if(old_selecting != selecting)
		update_icon()
	return 1

/obj/abstract/screen/zone_sel/update_icon()
	overlays.len = 0
	overlays += image('icons/mob/zone_sel.dmi', "[selecting]")

/obj/abstract/screen/clicker
	icon = 'icons/mob/screen1.dmi'
	icon_state = "blank"
	plane = CLICKCATCHER_PLANE
	mouse_opacity = 2
	globalscreen = 1
	screen_loc = ui_entire_screen

/obj/abstract/screen/clicker/Click(location, control, params)
	var/list/modifiers = params2list(params)
	var/turf/T = screen_loc2turf(modifiers["screen-loc"], get_turf(usr), usr)
	T.Click(location, control, params)
	return 1

/proc/screen_loc2turf(scr_loc, turf/origin, mob/user)
	var/list/screenxy = splittext(scr_loc, ",")
	var/list/screenx = splittext(screenxy[1], ":")
	var/list/screeny = splittext(screenxy[2], ":")
	var/X = screenx[1]
	var/Y = screeny[1]
	var/view = world.view
	if(user && user.client)
		view = user.client.view
	X = clamp((origin.x + text2num(X) - (view + 1)), 1, world.maxx)
	Y = clamp((origin.y + text2num(Y) - (view + 1)), 1, world.maxy)
	return locate(X, Y, origin.z)

/obj/abstract/screen/Click(location, control, params)
	if(!usr)
		return 1

	if(map.special_ui(src,usr))
		return 1 //exit early, we found our UI on map

	switch(name)
		if("toggle")
			if(usr.hud_used.inventory_shown)
				usr.hud_used.inventory_shown = 0
				usr.client.screen -= usr.hud_used.other
			else
				usr.hud_used.inventory_shown = 1
				usr.client.screen += usr.hud_used.other

			usr.hud_used.hidden_inventory_update()

		if("equip")
			if (istype(usr.loc,/obj/mecha)) // stops inventory actions in a mech
				return 1
			if(ishuman(usr))
				var/mob/living/carbon/human/H = usr
				H.quick_equip()

		if("resist")
			if(isliving(usr))
				var/mob/living/L = usr
				L.resist()

		if("mov_intent")
			if (iscarbon(usr))
				var/mob/living/carbon/C = usr
				C.toggle_move_intent()

		if("m_intent")
			if(!usr.m_int)
				switch(usr.m_intent)
					if("run")
						usr.m_int = "13,14"
					if("walk")
						usr.m_int = "14,14"
					if("face")
						usr.m_int = "15,14"
			else
				usr.m_int = null
		if("walk")
			usr.m_intent = "walk"
			usr.m_int = "14,14"
		if("face")
			usr.m_intent = "face"
			usr.m_int = "15,14"
		if("run")
			usr.m_intent = "run"
			usr.m_int = "13,14"
		if("Reset Machine")
			usr.unset_machine()
		if("internal")
			if(iscarbon(usr))
				var/mob/living/carbon/C = usr
				C.toggle_internals(usr)
		if("act_intent")
			usr.a_intent_change("right")
		if("help")
			usr.a_intent = I_HELP
			usr.hud_used.action_intent.icon_state = "intent_help"
		if("harm")
			usr.a_intent = I_HURT
			usr.hud_used.action_intent.icon_state = "intent_hurt"
		if("grab")
			usr.a_intent = I_GRAB
			usr.hud_used.action_intent.icon_state = "intent_grab"
		if("disarm")
			usr.a_intent = I_DISARM
			usr.hud_used.action_intent.icon_state = "intent_disarm"

		if("pull")
			usr.stop_pulling()
		if("throw")
			if(!usr.stat && isturf(usr.loc) && !usr.restrained())
				usr:toggle_throw_mode()

		if("kick")
			if(ishuman(usr))
				var/mob/living/carbon/human/H = usr

				var/list/modifiers = params2list(params)
				if(modifiers["middle"] || modifiers["right"] || modifiers["ctrl"] || modifiers["shift"] || modifiers["alt"])
					H.set_attack_type() //Reset
				else
					H.set_attack_type(ATTACK_KICK)
		if("bite")
			if(ishuman(usr))
				var/mob/living/carbon/human/H = usr

				var/list/modifiers = params2list(params)
				if(modifiers["middle"] || modifiers["right"] || modifiers["ctrl"] || modifiers["shift"] || modifiers["alt"])
					H.set_attack_type() //Reset
				else
					H.set_attack_type(ATTACK_BITE)

		if("drop")
			usr.drop_item_v()

		if("module")
			if(isrobot(usr))
				var/mob/living/silicon/robot/R = usr
				if(R.module)
					R.hud_used.toggle_show_robot_modules()
					return 1
				R:pick_module()

		if("radio")
			if(issilicon(usr))
				usr:radio_menu()
		if("panel")
			if(issilicon(usr))
				usr:installed_modules()

		if("store")
			if(isrobot(usr))
				var/mob/living/silicon/robot/R = usr
				R.uneq_active()

		if(INV_SLOT_TOOL)
			if(istype(usr, /mob/living/silicon/robot/mommi))
				usr:toggle_module(INV_SLOT_TOOL)

		if(INV_SLOT_SIGHT)
			if(isrobot(usr))
				var/mob/living/silicon/robot/person = usr
				person.sensor_mode()
				person.update_sight_hud()

		if("module1")
			if(istype(usr, /mob/living/silicon/robot))
				usr:toggle_module(1)

		if("module2")
			if(istype(usr, /mob/living/silicon/robot))
				usr:toggle_module(2)

		if("module3")
			if(istype(usr, /mob/living/silicon/robot))
				usr:toggle_module(3)

		if("AI Core")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.view_core()

		if("Show Camera List")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				var/camera = input(AI, "Choose which camera you want to view", "Cameras") as null|anything in AI.get_camera_list()
				AI.ai_camera_list(camera)

		if("Track With Camera")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				var/target_name = input(AI, "Choose what you want to track", "Tracking") as null|anything in AI.trackable_atoms()
				AI.ai_camera_track(target_name)

		if("Toggle Camera Light")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.toggle_camera_light()

		if("Show Crew Manifest")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.ai_roster()

		if("Show Alerts")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.ai_alerts()

		if("Announcement")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.make_announcement()

		if("(Re)Call Emergency Shuttle")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.ai_call_or_recall_shuttle()

		if("State Laws")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.state_laws()

		if("PDA - Send Message")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.cmd_send_pdamesg()

		if("PDA - Show Message Log")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.cmd_show_message_log()

		if("Take Image")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.aicamera.toggle_camera_mode(AI)
			else if(isrobot(usr))
				var/mob/living/silicon/robot/R = usr
				R.aicamera.toggle_camera_mode(R)

		if("View Images")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.aicamera.viewpictures(AI)
			else if(isrobot(usr))
				var/mob/living/silicon/robot/R = usr
				R.aicamera.viewpictures(R)

		if("Configure Radio")
			if(isAI(usr))
				var/mob/living/silicon/ai/AI = usr
				AI.radio_interact()

		if("Allow Walking")
			if(gun_click_time > world.time - 30)	//give them 3 seconds between mode changes.
				return
			if(!istype(usr.get_active_hand(),/obj/item/weapon/gun))
				to_chat(usr, "You need your gun in your active hand to do that!")
				return
			usr.client.AllowTargetMove()
			gun_click_time = world.time

		if("Disallow Walking")
			if(gun_click_time > world.time - 30)	//give them 3 seconds between mode changes.
				return
			if(!istype(usr.get_active_hand(),/obj/item/weapon/gun))
				to_chat(usr, "You need your gun in your active hand to do that!")
				return
			usr.client.AllowTargetMove()
			gun_click_time = world.time

		if("Allow Running")
			if(gun_click_time > world.time - 30)	//give them 3 seconds between mode changes.
				return
			if(!istype(usr.get_active_hand(),/obj/item/weapon/gun))
				to_chat(usr, "You need your gun in your active hand to do that!")
				return
			usr.client.AllowTargetRun()
			gun_click_time = world.time

		if("Disallow Running")
			if(gun_click_time > world.time - 30)	//give them 3 seconds between mode changes.
				return
			if(!istype(usr.get_active_hand(),/obj/item/weapon/gun))
				to_chat(usr, "You need your gun in your active hand to do that!")
				return
			usr.client.AllowTargetRun()
			gun_click_time = world.time

		if("Allow Item Use")
			if(gun_click_time > world.time - 30)	//give them 3 seconds between mode changes.
				return
			if(!istype(usr.get_active_hand(),/obj/item/weapon/gun))
				to_chat(usr, "You need your gun in your active hand to do that!")
				return
			usr.client.AllowTargetClick()
			gun_click_time = world.time


		if("Disallow Item Use")
			if(gun_click_time > world.time - 30)	//give them 3 seconds between mode changes.
				return
			if(!istype(usr.get_active_hand(),/obj/item/weapon/gun))
				to_chat(usr, "You need your gun in your active hand to do that!")
				return
			usr.client.AllowTargetClick()
			gun_click_time = world.time

		if("Toggle Gun Mode")
			usr.client.ToggleGunMode()

		else
			return 0
	return 1

/obj/abstract/screen/inventory/Click()
	// At this point in client Click() code we have passed the 1/10 sec check and little else
	// We don't even know if it's a middle click
	if(usr.attack_delayer.blocked())
		return
	if(usr.incapacitated())
		return 1
	if (istype(usr.loc,/obj/mecha)) // stops inventory actions in a mech
		return 1

	if(hand_index)
		usr.activate_hand(hand_index)

	switch(name)
		if("swap")
			usr:swap_hand()
		if("hand")
			usr:swap_hand()
		else
			if(usr.attack_ui(slot_id))
				usr.update_inv_hands()
				usr.delayNextAttack(6)
	return 1

/client/proc/reset_screen()
	for(var/obj/abstract/screen/objects in src.screen)
		if(!objects.globalscreen)
			qdel(objects)
	src.screen = null

/obj/abstract/screen/acidable()
	return 0
