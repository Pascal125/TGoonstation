
/mob/new_player/proc/new_player_panel()

	var/output = "<center><p><a href='byond://?src=\ref[src];show_preferences=1'>Setup Character</A></p>"

	if(!ticker || ticker.current_state <= GAME_STATE_PREGAME)
		if(ready)
			output += "<p>\[ <b>Ready</b> | <a href='byond://?src=\ref[src];ready=0'>Not Ready</a> \]</p>"
		else
			output += "<p>\[ <a href='byond://?src=\ref[src];ready=1'>Ready</a> | <b>Not Ready</b> \]</p>"

	else
		output += "<p><a href='byond://?src=\ref[src];manifest=1'>View the Crew Manifest</A></p>"
		output += "<p><a href='byond://?src=\ref[src];late_join=1'>Join Game!</A></p>"

	output += "<p><a href='byond://?src=\ref[src];observe=1'>Observe</A></p>"

	if(!IsGuestKey(src.key))
		establish_db_connection()

		if(dbcon.IsConnected())
			output += "<p><a href='byond://?src=\ref[src];showpoll=1'>Show Player Polls</A></p>"

	output += "</center>"

	//src << browse(output,"window=playersetup;size=210x240;can_close=0")
	var/datum/browser/popup = new(src, "playersetup", "<div align='center'>New Player Options</div>", 220, 265)
	popup.set_window_options("can_close=0")
	popup.set_content(output)
	popup.open(0)
	return


/mob/new_player/Topic(href, href_list[])
	if(src != usr)
		return 0

	if(!client)
		return 0

	if(href_list["show_preferences"])
		client.preferences.ShowChoices(src)
		return 1

	if(href_list["ready"])
		if(!ticker || ticker.current_state <= GAME_STATE_PREGAME) // Make sure we don't ready up after the round has started
			ready = text2num(href_list["ready"])
		else
			ready = 0

	if(href_list["refresh"])
		src << browse(null, "window=playersetup") //closes the player setup window
		new_player_panel()

	if(href_list["observe"])

		if(alert(src,"Are you sure you wish to observe? You will not be able to play this round!","Player Setup","Yes","No") == "Yes")
			if(!client)
				return 1
			var/mob/dead/observer/observer = new()

			src.spawning = 1

			close_spawn_windows()
			boutput(src, "<span style=\"color:blue\">Now teleporting.</span>")
			var/ASLoc = observer_start.len ? pick(observer_start) : locate(1, 1, 1)
			if (ASLoc)
				observer.set_loc(ASLoc)
			else
				observer.set_loc(locate(1, 1, 1))
			observer.apply_looks_of(client)

			if(src.mind)
				src.mind.dnr = 1
				src.mind.transfer_to(observer)
			else
				src.mind = new /datum/mind()
				src.mind.dnr = 1
				src.mind.transfer_to(observer)

			if(client.preferences.be_random_name)
				client.preferences.randomize_name()
			observer.name = client.preferences.real_name
			observer.real_name = observer.name
			src.client.loadResources()


			qdel(src)
			return 1

	if(href_list["late_join"])
		if(!ticker || ticker.current_state != GAME_STATE_PLAYING)
			usr << "<span class='danger'>The round is either not ready, or has already finished...</span>"
			return

		LateChoices()

	if(href_list["manifest"])
		return
		//ViewManifest()

	if(href_list["SelectedJob"])

		if (src.spawning)
			return

		if (!enter_allowed)
			boutput(usr, "<span style=\"color:blue\">There is an administrative lock on entering the game!</span>")
			return

		if (ticker.mode && !istype(ticker.mode, /datum/game_mode/construction))
			var/list/alljobs = job_controls.staple_jobs | job_controls.special_jobs
			var/datum/job/JOB = locate(href_list["SelectedJob"]) in alljobs
			AttemptLateSpawn(JOB)
		else
			var/datum/game_mode/construction/C = ticker.mode
			var/datum/job/JOB = locate(href_list["SelectedJob"]) in C.enabled_jobs
			AttemptLateSpawn(JOB)
		return

	if(!ready && href_list["preference"])
		if(client)
			client.preferences.process_link(src, href_list)
	else if(!href_list["late_join"])
		new_player_panel()

	if(href_list["showpoll"])
		//handle_player_polling()
		return
/*
	if(href_list["pollid"])
		var/pollid = href_list["pollid"]
		if(istext(pollid))
			pollid = text2num(pollid)
		if(isnum(pollid) && IsInteger(pollid))
			src.poll_player(pollid)
		return

	if(href_list["votepollid"] && href_list["votetype"])
		var/pollid = text2num(href_list["votepollid"])
		var/votetype = href_list["votetype"]
		switch(votetype)
			if(POLLTYPE_OPTION)
				var/optionid = text2num(href_list["voteoptionid"])
				if(vote_on_poll(pollid, optionid))
					usr << "<span class='notice'>Vote successful.</span>"
				else
					usr << "<span class='danger'>Vote failed, please try again or contact an administrator.</span>"
			if(POLLTYPE_TEXT)
				var/replytext = href_list["replytext"]
				if(log_text_poll_reply(pollid, replytext))
					usr << "<span class='notice'>Feedback logging successful.</span>"
				else
					usr << "<span class='danger'>Feedback logging failed, please try again or contact an administrator.</span>"
			if(POLLTYPE_RATING)
				var/id_min = text2num(href_list["minid"])
				var/id_max = text2num(href_list["maxid"])

				if( (id_max - id_min) > 100 )	//Basic exploit prevention
					usr << "The option ID difference is too big. Please contact administration or the database admin."
					return

				for(var/optionid = id_min; optionid <= id_max; optionid++)
					if(!isnull(href_list["o[optionid]"]))	//Test if this optionid was replied to
						var/rating
						if(href_list["o[optionid]"] == "abstain")
							rating = null
						else
							rating = text2num(href_list["o[optionid]"])
							if(!isnum(rating) || !IsInteger(rating))
								return

						if(!vote_on_numval_poll(pollid, optionid, rating))
							usr << "<span class='danger'>Vote failed, please try again or contact an administrator.</span>"
							return
				usr << "<span class='notice'>Vote successful.</span>"
			if(POLLTYPE_MULTI)
				var/id_min = text2num(href_list["minoptionid"])
				var/id_max = text2num(href_list["maxoptionid"])

				if( (id_max - id_min) > 100 )	//Basic exploit prevention
					usr << "The option ID difference is too big. Please contact administration or the database admin."
					return

				for(var/optionid = id_min; optionid <= id_max; optionid++)
					if(!isnull(href_list["option_[optionid]"]))	//Test if this optionid was selected
						var/i = vote_on_multi_poll(pollid, optionid)
						switch(i)
							if(0)
								continue
							if(1)
								usr << "<span class='danger'>Vote failed, please try again or contact an administrator.</span>"
								return
							if(2)
								usr << "<span class='danger'>Maximum replies reached.</span>"
								break
				usr << "<span class='notice'>Vote successful.</span>"
				*/