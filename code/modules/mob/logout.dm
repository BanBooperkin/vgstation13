/mob/Logout()
	SStgui.on_logout(src)
	nanomanager.close_user_uis(src)

	if (isobj(loc))
		var/obj/location = loc
		location.on_logout(src)

	if((flags & HEAR) && !(flags & HEAR_ALWAYS))
		if(virtualhearer)
			qdel(virtualhearer)
			virtualhearer = null
	world.log << "[src] logout"

	remove_spell_channeling() //remove spell channeling before we log out

	nanomanager.user_logout(src) // this is used to clean up (remove) this user's Nano UIs

	player_list -= src

	log_access("Logout: [key_name(src)] ([formatLocation(loc)])")

	clear_fullscreens(FALSE, 0)

	RemoveAllUIs() // Removes mind UIs

	remove_screen_objs() //Used to remove hud elements

	if (src in science_goggles_wearers)
		science_goggles_wearers.Remove(src)
		if (client)
			for (var/obj/item/I in infected_items)
				client.images -= I.pathogen
			for (var/mob/living/L in infected_contact_mobs)
				client.images -= L.pathogen
			for (var/obj/effect/pathogen_cloud/C in pathogen_clouds)
				client.images -= C.pathogen
			for (var/obj/effect/decal/cleanable/C in infected_cleanables)
				client.images -= C.pathogen

	if(client && client.media)
		client.media.stop_music()

	if(admin_datums[src.ckey])
		message_admins("Admin logout: [key_name(src)]")
		if (ticker && ticker.current_state == GAME_STATE_PLAYING) //Only report this stuff if we are currently playing.
			var/admins_number = admins.len
			var/admin_number_afk = 0
			for(var/client/X in admins)
				if(X.is_afk())
					admin_number_afk++

			var/available_admins = admins_number - admin_number_afk

			if(available_admins == 0) // Apparently the admin logging out is no longer an admin at this point, so we have to check this towards 0 and not towards 1. Awell.
				send2adminirc("[key_name(src, showantag = FALSE)] logged out - no more non-AFK admins online. - [admin_number_afk] AFK.")
				send2admindiscord("[key_name(src, showantag = FALSE)] logged out. **No more non-AFK admins online.** - **[admin_number_afk]** AFK", TRUE)

	lazy_invoke_event(/lazy_event/on_logout, list("user" = src))

	..()
