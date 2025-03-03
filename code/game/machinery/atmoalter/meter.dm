/obj/machinery/meter
	name = "meter"
	desc = "A gas flow meter."
	icon = 'icons/obj/meter.dmi'
	icon_state = "meterX"
	var/atom/target = null //A pipe for the base type
	anchored = 1.0
	power_channel = STATIC_ENVIRON
	var/frequency = 0
	var/id
	idle_power_usage = 15

/obj/machinery/meter/Initialize()
	. = ..()
	if (!target)
		set_target(locate(/obj/machinery/atmospherics/pipe) in loc)

/obj/machinery/meter/proc/set_target(atom/new_target)
	clear_target()
	target = new_target
	GLOB.destroyed_event.register(target, src, .proc/clear_target)

/obj/machinery/meter/proc/clear_target()
	if(target)
		GLOB.destroyed_event.unregister(target, src)
		target = null

/obj/machinery/meter/Destroy()
	clear_target()
	. = ..()

/obj/machinery/meter/Process()
	if(!target)
		icon_state = "meterX"
		return 0

	if(stat & (BROKEN|NOPOWER))
		icon_state = "meter0"
		return 0

	var/datum/gas_mixture/environment = target.return_air()
	if(!environment)
		icon_state = "meterX"
		return 0

	var/env_pressure = environment.return_pressure()
	if(env_pressure <= 0.15*ONE_ATMOSPHERE)
		icon_state = "meter0"
	else if(env_pressure <= 1.8*ONE_ATMOSPHERE)
		var/val = round(env_pressure/(ONE_ATMOSPHERE*0.3) + 0.5)
		icon_state = "meter1_[val]"
	else if(env_pressure <= 30*ONE_ATMOSPHERE)
		var/val = round(env_pressure/(ONE_ATMOSPHERE*5)-0.35) + 1
		icon_state = "meter2_[val]"
	else if(env_pressure <= 59*ONE_ATMOSPHERE)
		var/val = round(env_pressure/(ONE_ATMOSPHERE*5) - 6) + 1
		icon_state = "meter3_[val]"
	else
		icon_state = "meter4"

	if(frequency)
		var/datum/radio_frequency/radio_connection = radio_controller.return_frequency(frequency)

		if(!radio_connection) return

		var/datum/signal/signal = new
		signal.source = src
		signal.transmission_method = 1
		signal.data = list(
			"tag" = id,
			"device" = "AM",
			"pressure" = round(env_pressure),
			"sigtype" = "status"
		)
		radio_connection.post_signal(src, signal)

/obj/machinery/meter/examine(mob/user)
	. = ..()

	if(get_dist(user, src) > 3 && !(istype(user, /mob/living/silicon/ai) || isghost(user)))
		. += "\n<span class='warning'>You are too far away to read it.</span>"

	else if(stat & (NOPOWER|BROKEN))
		. += "\n<span class='warning'>The display is off.</span>"

	else if(src.target)
		var/datum/gas_mixture/environment = target.return_air()
		if(environment)
			. += "\nThe pressure gauge reads [round(environment.return_pressure(), 0.01)] kPa; [round(environment.temperature,0.01)]K ([round(environment.temperature-T0C,0.01)]&deg;C)"
		else
			. += "\nThe sensor error light is blinking."
	else
		. += "\nThe connect error light is blinking."


/obj/machinery/meter/Click()

	if(istype(usr, /mob/living/silicon/ai)) // ghosts can call ..() for examine
		usr.examinate(src)
		return 1

	return ..()

/obj/machinery/meter/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(!isWrench(W))
		return ..()
	playsound(src.loc, 'sound/items/Ratchet.ogg', 50, 1)
	to_chat(user, "<span class='notice'>You begin to unfasten \the [src]...</span>")
	if (do_after(user, 40, src))
		user.visible_message( \
			"<span class='notice'>\The [user] unfastens \the [src].</span>", \
			"<span class='notice'>You have unfastened \the [src].</span>", \
			"You hear ratchet.")
		new /obj/item/pipe_meter(src.loc)
		qdel(src)

// TURF METER - REPORTS A TILE'S AIR CONTENTS

/obj/machinery/meter/turf/Initialize()
	if (!target)
		set_target(loc)
	. = ..()

/obj/machinery/meter/turf/attackby(obj/item/weapon/W as obj, mob/user as mob)
