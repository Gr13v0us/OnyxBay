/mob/living/carbon/human/proc/get_unarmed_attack(mob/living/carbon/human/target, hit_zone)
	for(var/datum/unarmed_attack/u_attack in species.unarmed_attacks)
		if(u_attack.is_usable(src, target, hit_zone))
			if(pulling_punches)
				var/datum/unarmed_attack/soft_variant = u_attack.get_sparring_variant()
				if(soft_variant)
					return soft_variant
			return u_attack
	return null

#define FINALIZE_UNARMED(damage, maximize) (damage * (maximize ? 140 : rand(60, 140)) / 100)
/mob/living/carbon/human/attack_hand(mob/living/M)

	var/mob/living/carbon/human/H = M
	if(istype(H))
		var/obj/item/organ/external/temp = H.organs_by_name[BP_R_HAND]
		if(H.hand)
			temp = H.organs_by_name[BP_L_HAND]
		if(!temp || (!temp.is_usable() && !M.nabbing))
			to_chat(H, "<span class='warning'>You can't use your hand.</span>")
			return

	..()

	// Should this all be in Touch()?
	if(istype(H))
		if(H != src && check_shields(0, null, H, H.zone_sel.selecting, H.name))
			H.do_attack_animation(src)
			return 0

		if(istype(H.gloves, /obj/item/clothing/gloves/boxing/hologlove))
			H.do_attack_animation(src)
			var/damage = rand(0, 9)
			if(!damage)
				playsound(loc, 'sound/weapons/punchmiss.ogg', 25, 1, -1)
				visible_message("<span class='danger'>\The [H] has attempted to punch \the [src]!</span>")
				return 0
			var/obj/item/organ/external/affecting = get_organ(ran_zone(H.zone_sel.selecting))
			var/armor_block = run_armor_check(affecting, "melee")

			if(MUTATION_HULK in H.mutations)
				damage += 5

			playsound(loc, SFX_FIGHTING_PUNCH, rand(80, 100), 1, -1)

			visible_message("<span class='danger'>[H] has punched \the [src]!</span>")

			apply_damage(damage, PAIN, affecting, armor_block)
			if(damage >= 9)
				visible_message("<span class='danger'>[H] has weakened \the [src]!</span>")
				apply_effect(4, WEAKEN, armor_block)

			return

	if(istype(M,/mob/living/carbon))
		var/mob/living/carbon/C = M
		C.spread_disease_to(src, "Contact")

	if(istype(H))
		for (var/obj/item/grab/G in H)
			if (G.assailant == H && G.affecting == src)
				if(G.resolve_openhand_attack())
					return 1


	switch(M.a_intent)
		if(I_HELP)
			if(istype(H) && (is_asystole() || (status_flags & FAKEDEATH)))
				if (!cpr_time)
					return 0

				cpr_time = 0
				spawn(30)
					cpr_time = 1

				H.visible_message("<span class='notice'>\The [H] is trying to perform CPR on \the [src].</span>")

				if(!do_after(H, 30, src))
					return

				H.visible_message("<span class='notice'>\The [H] performs CPR on \the [src]!</span>")
				if(prob(5))
					var/obj/item/organ/external/chest = get_organ(BP_CHEST)
					if(chest)
						chest.fracture()
				if(stat != DEAD)
					if(prob(15))
						resuscitate()

					if(!H.check_has_mouth())
						to_chat(H, "<span class='warning'>You don't have a mouth, you cannot do mouth-to-mouth resustication!</span>")
						return
					if(!check_has_mouth())
						to_chat(H, "<span class='warning'>They don't have a mouth, you cannot do mouth-to-mouth resustication!</span>")
						return
					if((H.head && (H.head.body_parts_covered & FACE)) || (H.wear_mask && (H.wear_mask.body_parts_covered & FACE)))
						to_chat(H, "<span class='warning'>You need to remove your mouth covering for mouth-to-mouth resustication!</span>")
						return 0
					if((head && (head.body_parts_covered & FACE)) || (wear_mask && (wear_mask.body_parts_covered & FACE)))
						to_chat(H, "<span class='warning'>You need to remove \the [src]'s mouth covering for mouth-to-mouth resustication!</span>")
						return 0
					if (!H.internal_organs_by_name[H.species.breathing_organ])
						to_chat(H, "<span class='danger'>You need lungs for mouth-to-mouth resustication!</span>")
						return
					if(!need_breathe())
						return
					var/obj/item/organ/internal/lungs/L = internal_organs_by_name[species.breathing_organ]
					if(L)
						var/datum/gas_mixture/breath = H.get_breath_from_environment()
						var/fail = L.handle_breath(breath, 1)
						if(!fail)
							to_chat(src, "<span class='notice'>You feel a breath of fresh air enter your lungs. It feels good.</span>")

			else if(!(M == src && apply_pressure(M, M.zone_sel.selecting)))
				help_shake_act(M)
			return 1

		if(I_GRAB)
			visible_message(SPAN("danger", "[M] attempted to grab \the [src]!"))
			return H.make_grab(H, src)

		if(I_HURT)
			if(M.zone_sel.selecting == "mouth" && wear_mask && istype(wear_mask, /obj/item/weapon/grenade))
				var/obj/item/weapon/grenade/G = wear_mask
				if(!G.active)
					visible_message(SPAN("danger", "\The [M] pulls the pin from \the [src]'s [G.name]!"))
					G.activate(M)
					update_inv_wear_mask()
				else
					to_chat(M, SPAN("warning", "The [G] is already primed! Run!"))
				return

			if(!istype(H))
				attack_generic(H, rand(1, 3), "punched")
				return

			var/attack_damage = 5

			var/accurate = 0
			var/specmod = 1
			var/hit_zone = H.zone_sel.selecting
			var/miss_type = 0
			var/attack_message
			var/obj/item/organ/external/affecting = get_organ(hit_zone)

			// See what attack they use
			var/datum/unarmed_attack/attack = H.get_unarmed_attack(src, hit_zone)
			if(!attack)
				return 0
			if(world.time < H.last_attack + attack.delay)
				to_chat(H, SPAN("notice", "You can't attack again so soon."))
				return 0
			else
				H.last_attack = world.time

			if(!affecting || affecting.is_stump())
				to_chat(M, SPAN("danger", "They are missing that limb!"))
				return 1

			if(a_intent == I_HELP) // We didn't see this coming, so we get the full blow
				accurate = 1

			if(istype(H.gloves, /obj/item/clothing/gloves)) // Syndie Gloves Go Robust
				var/obj/item/clothing/gloves/GL = H.gloves
				if(!isnull(GL.unarmed_damage_override))
					attack_damage = GL.unarmed_damage_override
				//FINALIZE_UNARMED(damage, maximize)

			if(M.grabbed_by.len)
				// Someone got a good grip on them, they won't be able to do much damage
				attack_damage = max(2, attack_damage - 2)

			if(grabbed_by.len || !MayMove() || src == H || H.species.species_flags & SPECIES_FLAG_NO_BLOCK)
				accurate = 1 // certain circumstances make it impossible for us to evade punches

				if(grabbed_by.len)
					for(var/obj/item/grab/G in grabbed_by)
						if(G.assailant == H)
							var/obj/item/organ/external/O = G.get_targeted_organ()
							switch(hit_zone)
								if(BP_MOUTH)
									attack_message = "[H] lands a jab against [src]'s jaw!"
									specmod = 2
								if(BP_CHEST)
									if(G.target_zone == BP_CHEST && O.damage > O.max_damage && should_have_organ(BP_HEART))
										H.visible_message(SPAN("danger", "[H] shoves \his hand into [src]'s chest!"))
										custom_pain("You can feel a hand ripping your inwards!", 50, affecting = O)
										H.next_move = world.time + 40 //also should prevent user from triggering this repeatedly
										if(!do_after(H, 40))
											return 0
										if(!(G && G.affecting == src)) //check that we still have a grab
											return 0

										for(var/obj/item/organ/internal/heart/I in internal_organs)
											if(I && istype(I))
												I.cut_away(src)
												O.implants -= I
												H.put_in_active_hand(I)
												H.visible_message(SPAN("danger", "[H] rips [src]'s [I.name] out!"))
												playsound(src.loc, 'sound/effects/squelch1.ogg', 50, 1)
												admin_attack_log(H, src, "Ripped their victim's heart out", "Got their heart ripped out", "ripped out")
												return 0
										H.visible_message(SPAN("danger", "[H] did not find anything useful in [src]'s chest!"))
										return 0

			// Process evasion and blocking
			if(!accurate)
				/* ~Hubblenaut
					This place is kind of convoluted and will need some explaining.
					ran_zone() will pick out of 11 zones, thus the chance for hitting
					our target where we want to hit them is circa 9.1%.

					Now since we want to statistically hit our target organ a bit more
					often than other organs, we add a base chance of 20% for hitting it.

					This leaves us with the following chances:

					If aiming for chest:
						27.3% chance you hit your target organ
						70.5% chance you hit a random other organ
						 2.2% chance you miss

					If aiming for something else:
						23.2% chance you hit your target organ
						56.8% chance you hit a random other organ
						15.0% chance you miss

					Note: We don't use get_zone_with_miss_chance() here since the chances
						  were made for projectiles.
					TODO: proc for melee combat miss chances depending on organ?
				*/
				if(prob(80))
					hit_zone = ran_zone(hit_zone)
				if(prob(15) && hit_zone != BP_CHEST) // Missed!
					if(!lying)
						attack_message = "[H] attempted to strike [src], but missed!"
					else
						attack_message = "[H] attempted to strike [src], but \he rolled out of the way!"
						set_dir(pick(GLOB.cardinal))
					miss_type = 1

			if(!miss_type && parrying)
				if(handle_parry(H, null))
					//attack_message = "[H] went for [src]'s [affecting.name] but was parried!"
					miss_type = 2
			if(!miss_type && blocking)
				if(handle_block_normal(H))
					//attack_message = "[H] went for [src]'s [affecting.name] but was blocked!"
					miss_type = 2

			//if(!miss_type && block)
			//	attack_message = "[H] went for [src]'s [affecting.name] but was blocked!"
			//	miss_type = 2

			H.do_attack_animation(src)

			if(miss_type < 2)
				if(!attack_message)
					attack.show_attack(H, src, hit_zone, FINALIZE_UNARMED(attack_damage, accurate))
				else
					H.visible_message(SPAN("danger", "[attack_message]"))

			playsound(loc, ((miss_type) ? (miss_type == 1 ? attack.miss_sound : 'sound/weapons/thudswoosh.ogg') : attack.attack_sound), 25, 1, -1)
			admin_attack_log(H, src, "[miss_type ? (miss_type == 1 ? "Has missed" : "Was blocked by") : "Has [pick(attack.attack_verb)]"] their victim.", "[miss_type ? (miss_type == 1 ? "Missed" : "Blocked") : "[pick(attack.attack_verb)]"] their attacker", "[miss_type ? (miss_type == 1 ? "has missed" : "was blocked by") : "has [pick(attack.attack_verb)]"]")

			if(miss_type)
				return 0

			attack_damage = FINALIZE_UNARMED(attack_damage, accurate)
			var/real_damage = attack_damage // We don't want species' damage modifiers to apply additional effects but damage
			real_damage += attack.get_unarmed_damage(H)
			real_damage *= damage_multiplier
			attack_damage *= damage_multiplier
			if(MUTATION_HULK in H.mutations)
				real_damage *= 2 // Hulks do twice the damage
				attack_damage *= 2
			real_damage = max(1, real_damage)

			var/armour = run_armor_check(hit_zone, "melee")
			// Apply additional unarmed effects.
			attack.apply_effects(H, src, armour, attack_damage, hit_zone, specmod)

			// Finally, apply damage to target
			apply_damage(real_damage, (attack.deal_halloss ? PAIN : BRUTE), hit_zone, armour, damage_flags = attack.damage_flags())

		if(I_DISARM)
			if(H.species)
				admin_attack_log(M, src, "Disarmed their victim.", "Was disarmed.", "disarmed")
				H.species.disarm_attackhand(H, src)

	return
#undef FINALIZE_UNARMED

/mob/living/carbon/human/proc/afterattack(atom/target as mob|obj|turf|area, mob/living/user as mob|obj, inrange, params)
	return

/mob/living/carbon/human/attack_generic(mob/user, damage, attack_message, environment_smash, damtype = BRUTE, armorcheck = "melee", blockable = TRUE)
	if(!damage || !istype(user))
		return
	user.do_attack_animation(src)

	if(blocking && blockable)
		if(handle_block_normal(user, damage))
			return 0

	var/dam_zone = pick(organs_by_name)
	var/obj/item/organ/external/affecting = get_organ(ran_zone(dam_zone))
	var/armor_block = run_armor_check(affecting, armorcheck)
	visible_message(SPAN("danger", "[user] has [attack_message] [src]!"))
	admin_attack_log(user, src, "Attacked their victim", "Was attacked", "has [attack_message]")
	apply_damage(damage, damtype, affecting, armor_block)
	updatehealth()
	return 1

//Breaks all grips and pulls that the mob currently has.
/mob/living/carbon/human/proc/break_all_grabs(mob/living/carbon/user,silent = 0)
	var/success = 0
	if(pulling)
		if(!silent)
			visible_message("<span class='danger'>[user] has broken [src]'s grip on [pulling]!</span>")
		success = 1
		stop_pulling()

	if(istype(l_hand, /obj/item/grab))
		var/obj/item/grab/lgrab = l_hand
		if(lgrab.affecting)
			if(!silent)
				visible_message("<span class='danger'>[user] has broken [src]'s grip on [lgrab.affecting]!</span>")
			success = 1
		spawn(1)
			qdel(lgrab)
	if(istype(r_hand, /obj/item/grab))
		var/obj/item/grab/rgrab = r_hand
		if(rgrab.affecting)
			if(!silent)
				visible_message("<span class='danger'>[user] has broken [src]'s grip on [rgrab.affecting]!</span>")
			success = 1
		spawn(1)
			qdel(rgrab)
	return success
/*
	We want to ensure that a mob may only apply pressure to one organ of one mob at any given time. Currently this is done mostly implicitly through
	the behaviour of do_after() and the fact that applying pressure to someone else requires a grab:

	If you are applying pressure to yourself and attempt to grab someone else, you'll change what you are holding in your active hand which will stop do_mob()
	If you are applying pressure to another and attempt to apply pressure to yourself, you'll have to switch to an empty hand which will also stop do_mob()
	Changing targeted zones should also stop do_mob(), preventing you from applying pressure to more than one body part at once.
*/
/mob/living/carbon/human/proc/apply_pressure(mob/living/user, target_zone)
	var/obj/item/organ/external/organ = get_organ(target_zone)
	if(!organ || !(organ.status & ORGAN_BLEEDING) || BP_IS_ROBOTIC(organ))
		return 0

	if(organ.applied_pressure)
		var/message = "<span class='warning'>[ismob(organ.applied_pressure)? "Someone" : "\A [organ.applied_pressure]"] is already applying pressure to [user == src? "your [organ.name]" : "[src]'s [organ.name]"].</span>"
		to_chat(user, message)
		return 0

	if(user == src)
		user.visible_message("\The [user] starts applying pressure to \his [organ.name]!", "You start applying pressure to your [organ.name]!")
	else
		user.visible_message("\The [user] starts applying pressure to [src]'s [organ.name]!", "You start applying pressure to [src]'s [organ.name]!")
	spawn(0)
		organ.applied_pressure = user

		//apply pressure as long as they stay still and keep grabbing
		do_mob(user, src, INFINITY, target_zone, progress = 0)

		organ.applied_pressure = null

		if(user == src)
			user.visible_message("\The [user] stops applying pressure to \his [organ.name]!", "You stop applying pressure to your [organ.name]!")
		else
			user.visible_message("\The [user] stops applying pressure to [src]'s [organ.name]!", "You stop applying pressure to [src]'s [organ.name]!")

	return 1
