.float touchexplode_time;

void PlayerTouchExplode(entity p1, entity p2)
{
	vector org;
	org = (p1.origin + p2.origin) * 0.5;
	org_z += (p1.mins_z + p2.mins_z) * 0.5;

	sound(self, CH_TRIGGER, "weapons/grenade_impact.wav", VOL_BASE, ATTEN_NORM);
	pointparticles(particleeffectnum("explosion_small"), org, '0 0 0', 1);

	entity e;
	e = spawn();
	setorigin(e, org);
	RadiusDamage(e, world, autocvar_g_touchexplode_damage, autocvar_g_touchexplode_edgedamage, autocvar_g_touchexplode_radius, world, autocvar_g_touchexplode_force, DEATH_TOUCHEXPLODE, world);
	remove(e);
}

MUTATOR_HOOKFUNCTION(touchexplode_PlayerThink)
{
	if(time > self.touchexplode_time)
	if not(gameover)
	if not(self.frozen)
	if(IS_PLAYER(self))
	if(self.deadflag == DEAD_NO)
	if not(IS_INDEPENDENT_PLAYER(self))
	FOR_EACH_PLAYER(other) if(self != other)
	{
		if(time > other.touchexplode_time)
		if not(other.frozen)
		if(other.deadflag == DEAD_NO)
		if not(IS_INDEPENDENT_PLAYER(other))
		if(boxesoverlap(self.absmin, self.absmax, other.absmin, other.absmax))
		{
			PlayerTouchExplode(self, other);
			self.touchexplode_time = other.touchexplode_time = time + 0.2;
		}
	}

	return FALSE;
}

MUTATOR_DEFINITION(mutator_touchexplode)
{
	MUTATOR_HOOK(PlayerPreThink, touchexplode_PlayerThink, CBC_ORDER_ANY);

	return FALSE;
}
