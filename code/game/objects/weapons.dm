/obj/item/weapon
	name = "weapon"
	icon = 'icons/obj/weapons.dmi'
	hitsound = SFX_FIGHTING_SWING
	var/clumsy_unaffected = FALSE

/obj/item/weapon/Bump(mob/M as mob)
	spawn(0)
		..()
	return
