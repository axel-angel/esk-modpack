void nade_timer_think()
{
	self.skin = 8 - (self.owner.wait - time) / (autocvar_g_nades_nade_lifetime / 10);
	self.nextthink = time;
	if(!self.owner || wasfreed(self.owner))
		remove(self);
	
}

void nade_burn_spawn(entity _nade)
{
	float p;
	
	if(_nade.nade_type == NADE_TYPE_NAPALM)
		p = PROJECTILE_NADE_NAPALM_BURN;
	else
		switch(_nade.realowner.team)
		{
			case NUM_TEAM_1: p = PROJECTILE_NADE_RED_BURN; break;
			case NUM_TEAM_2: p = PROJECTILE_NADE_BLUE_BURN; break;
			case NUM_TEAM_3: p = PROJECTILE_NADE_YELLOW_BURN; break;
			case NUM_TEAM_4: p = PROJECTILE_NADE_PINK_BURN; break;
			default:		 p = PROJECTILE_NADE_BURN; break;
		}
	
	CSQCProjectile(_nade, TRUE, p, TRUE);
}

void nade_spawn(entity _nade)
{
	float p;
	entity timer = spawn();
	setmodel(timer, "models/ok_nade_counter/ok_nade_counter.md3");
	setattachment(timer, _nade, "");
	timer.classname = "nade_timer";
	timer.colormap = _nade.colormap;
	timer.glowmod = _nade.glowmod;
	timer.think = nade_timer_think;
	timer.nextthink = time;
	timer.wait = _nade.wait;
	timer.owner = _nade;	
	timer.skin = 10;
	
	_nade.effects |= EF_LOWPRECISION;
	
	if(_nade.nade_type == NADE_TYPE_NAPALM)
		p = PROJECTILE_NADE_NAPALM;
	else
	{
		switch(_nade.realowner.team)
		{
			case NUM_TEAM_1: p = PROJECTILE_NADE_RED; break;
			case NUM_TEAM_2: p = PROJECTILE_NADE_BLUE; break;
			case NUM_TEAM_3: p = PROJECTILE_NADE_YELLOW; break;
			case NUM_TEAM_4: p = PROJECTILE_NADE_PINK; break;
			default:		 p = PROJECTILE_NADE; break;
		}
	}
		
	CSQCProjectile(_nade, TRUE, p, TRUE);
}


void napalm_damage(float dist, float damage, float edgedamage, float burntime)
{
	entity e;
	float d;
	vector p;
	
	if ( damage < 0 )
		return;

	RandomSelection_Init();
	for(e = WarpZone_FindRadius(self.origin, dist, TRUE); e; e = e.chain)
		if(e.takedamage == DAMAGE_AIM) 
		if(self.realowner != e || autocvar_g_nades_napalm_selfdamage) 
		if(!IS_PLAYER(e) || !self.realowner || DIFF_TEAM(e, self))
		if not (e.frozen) 
		{
			p = e.origin;
			p_x += e.mins_x + random() * (e.maxs_x - e.mins_x);
			p_y += e.mins_y + random() * (e.maxs_y - e.mins_y);
			p_z += e.mins_z + random() * (e.maxs_z - e.mins_z);
			d = vlen(WarpZone_UnTransformOrigin(e, self.origin) - p);
			if(d < dist)
			{
				e.fireball_impactvec = p;
				RandomSelection_Add(e, 0, string_null, 1 / (1 + d), !Fire_IsBurning(e));
			}
		}
	if(RandomSelection_chosen_ent)
	{
		d = vlen(WarpZone_UnTransformOrigin(RandomSelection_chosen_ent, self.origin) - RandomSelection_chosen_ent.fireball_impactvec);
		d = damage + (edgedamage - damage) * (d / dist);
		Fire_AddDamage(RandomSelection_chosen_ent, self.realowner, d * burntime, burntime, self.projectiledeathtype | HITTYPE_BOUNCE);
		//trailparticles(self, particleeffectnum("fireball_laser"), self.origin, RandomSelection_chosen_ent.fireball_impactvec);
		pointparticles(particleeffectnum("fireball_laser"), self.origin, RandomSelection_chosen_ent.fireball_impactvec - self.origin, 1);
	}
}


void napalm_ball_think()
{
	if(time > self.pushltime)
	{
		remove(self);
		return;
	}
	
	vector midpoint = ((self.absmin + self.absmax) * 0.5);
	if(pointcontents(midpoint) == CONTENT_WATER)
	{
		self.velocity = self.velocity * 0.5;
					
		if(pointcontents(midpoint + '0 0 16') == CONTENT_WATER)
			{ self.velocity_z = 200; }
	}
	
	self.angles = vectoangles(self.velocity);

	napalm_damage(autocvar_g_nades_napalm_ball_radius,autocvar_g_nades_napalm_ball_damage,
				  autocvar_g_nades_napalm_ball_damage,autocvar_g_nades_napalm_burntime);

	self.nextthink = time + 0.1;
}


void nade_napalm_ball()
{
	entity proj;
	vector kick;
	
	spamsound(self, CH_SHOTS, "weapons/fireball_fire.wav", VOL_BASE, ATTEN_NORM);
	
	proj = spawn ();
	proj.owner = self.owner;
	proj.realowner = self.realowner;
	proj.team = self.owner.team;
	proj.classname = "grenade";
	proj.bot_dodge = TRUE;
	proj.bot_dodgerating = autocvar_g_nades_napalm_ball_damage;
	proj.movetype = MOVETYPE_BOUNCE;
	proj.projectiledeathtype = DEATH_NADE_NAPALM;
	PROJECTILE_MAKETRIGGER(proj);
	setmodel(proj, "null");
	proj.scale = 1;//0.5;
	setsize(proj, '-4 -4 -4', '4 4 4');
	setorigin(proj, self.origin);
	proj.think = napalm_ball_think;
	proj.nextthink = time;
	proj.damageforcescale = autocvar_g_nades_napalm_ball_damageforcescale;
	proj.effects = EF_LOWPRECISION | EF_FLAME;
	
	kick_x =(random() - 0.5) * 2 * autocvar_g_nades_napalm_ball_spread;
	kick_y = (random() - 0.5) * 2 * autocvar_g_nades_napalm_ball_spread;
	kick_z = (random()/2+0.5) * autocvar_g_nades_napalm_ball_spread;
	proj.velocity = kick;
	
	proj.pushltime = time + autocvar_g_nades_napalm_ball_lifetime;

	proj.angles = vectoangles(proj.velocity);
	proj.flags = FL_PROJECTILE;
    proj.missile_flags = MIF_SPLASH | MIF_PROXY | MIF_ARC;
    
	//CSQCProjectile(proj, TRUE, PROJECTILE_NAPALM_FIRE, TRUE);
}


void napalm_fountain_think()
{
	if(time >= self.ltime) 
	{
		remove(self);
		return;
	}
	
	vector midpoint = ((self.absmin + self.absmax) * 0.5);
	if(pointcontents(midpoint) == CONTENT_WATER)
	{
		self.velocity = self.velocity * 0.5;
					
		if(pointcontents(midpoint + '0 0 16') == CONTENT_WATER)
			{ self.velocity_z = 200; }
			
		UpdateCSQCProjectile(self);
	}
	
	napalm_damage(autocvar_g_nades_napalm_fountain_radius, autocvar_g_nades_napalm_fountain_damage,
		autocvar_g_nades_napalm_fountain_edgedamage, autocvar_g_nades_napalm_burntime);
	
	self.nextthink = time + 0.1;
	if(time >= self.fire_fountain_time)
	{
		self.fire_fountain_time = time + autocvar_g_nades_napalm_fountain_delay;
		nade_napalm_ball();
	}
}

void nade_napalm_boom()
{
	entity fountain;
	local float c;
	for (c = 0; c < autocvar_g_nades_napalm_ball_count; c ++) 
		nade_napalm_ball();
	
	
	fountain = spawn();
	fountain.owner = self.owner;
	fountain.realowner = self.realowner;
	fountain.origin = self.origin;
	setorigin(fountain, fountain.origin);
	fountain.think = napalm_fountain_think;
	fountain.nextthink = time;
	fountain.ltime = time + autocvar_g_nades_napalm_fountain_lifetime;
	fountain.pushltime = fountain.ltime;
	fountain.team = self.team;
	fountain.movetype = MOVETYPE_TOSS;
	fountain.projectiledeathtype = DEATH_NADE_NAPALM;
	fountain.bot_dodge = TRUE;
	fountain.bot_dodgerating = autocvar_g_nades_napalm_fountain_damage;
	fountain.fire_fountain_time = time;
	setsize(fountain, '-16 -16 -16', '16 16 16');
	CSQCProjectile(fountain, TRUE, PROJECTILE_NAPALM_FOUNTAIN, TRUE);
}

void nade_boom()
{
	string expef;
	float napalm_blast;
	
	napalm_blast = (self.nade_type != NADE_TYPE_NAPALM || autocvar_g_nades_napalm_blast);

	if ( self.nade_type == NADE_TYPE_NAPALM )
		//Some nice effects for this: 
		//EF_FLAME  onslaught_generator_gib_explode explosion_big explosion_medium explosion_small
		expef = "explosion_medium";
	else
		switch(self.realowner.team)
		{
			case NUM_TEAM_1: expef = "nade_red_explode"; break;
			case NUM_TEAM_2: expef = "nade_blue_explode"; break;
			case NUM_TEAM_3: expef = "nade_yellow_explode"; break;
			case NUM_TEAM_4: expef = "nade_pink_explode"; break;
			default: 		 expef = "nade_explode"; break;
		}
	
	
	pointparticles(particleeffectnum(expef), self.origin + '0 0 1', '0 0 0', 1);
		
	sound(self, CH_SHOTS_SINGLE, "misc/null.wav", VOL_BASE, ATTEN_NORM);
	sound(self, CH_SHOTS, "weapons/rocket_impact.wav", VOL_BASE, ATTEN_NORM);
	
	self.takedamage = DAMAGE_NO;
	
	if(napalm_blast)
	{
		RadiusDamage(self, self.realowner, autocvar_g_nades_nade_damage, autocvar_g_nades_nade_edgedamage,
				 autocvar_g_nades_nade_radius, self, autocvar_g_nades_nade_force, self.projectiledeathtype, self.enemy);
		Damage_DamageInfo(self.origin, autocvar_g_nades_nade_damage, autocvar_g_nades_nade_edgedamage, autocvar_g_nades_nade_radius, '1 1 1' * autocvar_g_nades_nade_force, self.projectiledeathtype, 0, self);
	}
	
	if(self.nade_type == NADE_TYPE_NAPALM)
		nade_napalm_boom();

	remove(self);
}

void nade_touch()
{
	PROJECTILE_TOUCH;
	//setsize(self, '-2 -2 -2', '2 2 2');
	//UpdateCSQCProjectile(self);
	if(self.health == self.max_health)
	{
		spamsound(self, CH_SHOTS, strcat("weapons/grenade_bounce", ftos(1 + rint(random() * 5)), ".wav"), VOL_BASE, ATTEN_NORM);
		return;
	}

	self.enemy = other;
	nade_boom();
}

void nade_beep()
{
	sound(self, CH_SHOTS_SINGLE, "overkill/grenadebip.ogg", VOL_BASE, 0.5 *(ATTEN_LARGE + ATTEN_MAX));
	self.think = nade_boom;
	self.nextthink = max(self.wait, time);
}

void nade_damage(entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if(DEATH_ISWEAPON(deathtype, WEP_LASER))
		return;

	if(DEATH_ISWEAPON(deathtype, WEP_NEX) || DEATH_ISWEAPON(deathtype, WEP_MINSTANEX))
	{
		force *= 6;
		damage = self.max_health * 0.55;
	}

	if(DEATH_ISWEAPON(deathtype, WEP_UZI) || DEATH_ISWEAPON(deathtype, WEP_HMG))
		damage = self.max_health * 0.1;
		
	if(DEATH_ISWEAPON(deathtype, WEP_SHOTGUN))
	if(deathtype & HITTYPE_SECONDARY)
	{
		damage = self.max_health * 0.1;
		force *= 10;
	}
	else
		damage = self.max_health * 1.1;
		
	self.velocity += force;

	if(!damage || (self.flags & FL_ONGROUND && IS_PLAYER(attacker)))
		return;

	if(self.health == self.max_health)
	{
		sound(self, CH_SHOTS_SINGLE, "misc/null.wav", VOL_BASE, 0.5 *(ATTEN_LARGE + ATTEN_MAX));
		self.nextthink = max(time + autocvar_g_nades_nade_lifetime, time);
		self.think = nade_beep;
	}

	self.health   -= damage;
	self.realowner = attacker;

	if(self.health <= 0)
		W_PrepareExplosionByDamage(attacker, nade_boom);
	else
		nade_burn_spawn(self);
}

void toss_nade(entity e, vector _velocity, float _time)
{
	entity _nade = e.nade;
	e.nade = world;
	
	remove(e.fake_nade);
	e.fake_nade = world;
	
	makevectors(e.v_angle);
	
	W_SetupShot(e, FALSE, FALSE, "", CH_WEAPON_A, 0, DEATH_NADE);
	
	Kill_Notification(NOTIF_ONE_ONLY, e, MSG_CENTER_CPID, CPID_NADES);
	
	setorigin(_nade, w_shotorg + (v_right * 25) * -1);
	setmodel(_nade, "models/weapons/v_ok_grenade.md3");
	setattachment(_nade, world, "");
	PROJECTILE_MAKETRIGGER(_nade);
	setsize(_nade, '-16 -16 -16', '16 16 16');
	_nade.movetype = MOVETYPE_BOUNCE;
	
	tracebox(_nade.origin, _nade.mins, _nade.maxs, _nade.origin, FALSE, _nade);
	if (trace_startsolid)
		setorigin(_nade, e.origin);
	
	if(e.crouch)
		_nade.velocity = '0 0 -10';
	else if(autocvar_g_nades_nade_newton_style == 1)
		_nade.velocity = e.velocity + _velocity;
	else if(autocvar_g_nades_nade_newton_style == 2)
		_nade.velocity = _velocity;
	else
		_nade.velocity = W_CalculateProjectileVelocity(e.velocity, _velocity, TRUE);
	
	_nade.touch = nade_touch;
	_nade.health = autocvar_g_nades_nade_health;
	_nade.max_health = _nade.health;
	_nade.takedamage = DAMAGE_AIM;
	_nade.event_damage = nade_damage;
	_nade.teleportable = TRUE;
	_nade.pushable = TRUE;
	_nade.gravity = 1;
	_nade.missile_flags = MIF_SPLASH | MIF_ARC;
	_nade.damagedbycontents = TRUE;
	_nade.angles = vectoangles(_nade.velocity);
	_nade.flags = FL_PROJECTILE;
	_nade.projectiledeathtype = DEATH_NADE;

	nade_spawn(_nade);

	if(_time)
	{
		_nade.think = nade_boom;
		_nade.nextthink = _time;
	}

	e.nade_refire = time + autocvar_g_nades_nade_refire;
}

void nades_GiveBonus(entity player, float score)
{
	if (autocvar_g_nades)
	if (autocvar_g_nades_bonus)
	if (IS_REAL_CLIENT(player))
	if (IS_PLAYER(player) && player.bonus_nades < autocvar_g_nades_bonus_max)
	if (player.frozen == 0)
	if (player.deadflag == DEAD_NO)
	{
		if ( player.bonus_nade_score < 1 )
			player.bonus_nade_score += score/autocvar_g_nades_bonus_score_max;
		
		if ( player.bonus_nade_score >= 1 )
		{
			Send_Notification(NOTIF_ONE, player, MSG_CENTER, CENTER_NADE_BONUS);
			play2(player,"kh/alarm.wav");
			player.bonus_nades++;
			player.bonus_nade_score -= 1;
		}
	}
}

void nades_RemoveBonus(entity player)
{
	player.bonus_nades = player.bonus_nade_score = 0;
}


void nade_prime()
{
	
	if(self.nade)
		remove(self.nade);
		
	if(self.fake_nade)
		remove(self.fake_nade);
		
	entity n = spawn(), fn = spawn();
	
	setmodel(n, "null");
	setattachment(n, self, "bip01 l hand");

	n.classname = "nade";
	
	if(self.items & IT_STRENGTH && autocvar_g_nades_bonus_onstrength)
		n.nade_type = self.nade_type;
	else if (self.bonus_nades >= 1)
	{
		n.nade_type = self.nade_type;
		self.bonus_nades -= 1;
	}
	else
		 n.nade_type = autocvar_g_nades_nade_type;

	n.realowner = self;
	n.colormap = self.colormap;
	n.glowmod = self.glowmod;
	n.wait = time + autocvar_g_nades_nade_lifetime;
	n.lifetime = time;
	n.think = nade_beep;
	n.nextthink = max(n.wait - 3, time);
	n.projectiledeathtype = DEATH_NADE;
	
	if(n.nade_type == NADE_TYPE_NAPALM)
		fn.colormod = '2 0.5 0';
		
	setmodel(fn, "models/weapons/h_ok_grenade.iqm");
	setattachment(fn, self.weaponentity, "");
	fn.classname = "fake_nade";
	fn.realowner = fn.owner = self;
	fn.colormap = self.colormap;
	fn.glowmod = self.glowmod;
	fn.think = SUB_Remove;
	fn.nextthink = n.wait;
	
	self.nade = n;
	self.fake_nade = fn;
}

float CanThrowNade()
{
	if(self.vehicle)
		return FALSE;
		
	if(gameover)
		return FALSE;
		
	if(self.deadflag != DEAD_NO)
		return FALSE;
	
	if not(autocvar_g_nades)
		return FALSE; // allow turning them off mid match
		
	if(forbidWeaponUse())
		return FALSE;
		
	if not(IS_PLAYER(self))
		return FALSE;
		
	return TRUE;
}

void nades_CheckThrow()
{
	if(!CanThrowNade())
		return;
		
	if(!self.nade)
	{
		if(self.nade_refire < time)
		{
			Send_Notification(NOTIF_ONE, self, MSG_CENTER, CENTER_NADE_THROW);
			nade_prime();
			self.nade_refire = time + autocvar_g_nades_nade_refire;
		}
	}
	else
	{
		if(time - self.nade.lifetime >= 1)
		{
			makevectors(self.v_angle);
			float _force = time - self.nade.lifetime;
			_force /= autocvar_g_nades_nade_lifetime;
			_force = autocvar_g_nades_nade_minforce + (_force * (autocvar_g_nades_nade_maxforce - autocvar_g_nades_nade_minforce));
			toss_nade(self, (v_forward * 0.75 + v_up * 0.2 + v_right * 0.05) * _force, 0);
		}
	}
}

MUTATOR_HOOKFUNCTION(nades_VehicleEnter)
{
	if(other.nade)
		toss_nade(other, '0 0 100', max(other.nade.wait, time + 0.05));
	
	return FALSE;
}

MUTATOR_HOOKFUNCTION(nades_PlayerPreThink)
{
	if not(IS_PLAYER(self)) { return FALSE; }
	
	float key_pressed = self.BUTTON_HOOK;
	
	if(g_grappling_hook || client_hasweapon(self, WEP_HOOK, FALSE, FALSE) || (weaponsInMap & WEPSET_HOOK) || g_jetpack || self.items & IT_JETPACK)
		key_pressed = self.button16; // if hook/jetpack is enabled, use an alternate key
	
	if(self.nade)
		if(self.nade.wait - 0.1 <= time)
			toss_nade(self, '0 0 0', time + 0.05);
			
	if(CanThrowNade())
	if(self.nade_refire < time)
	{
		if(key_pressed)
		{
			if(!self.nade)
				nade_prime();
		}
		else if(time - self.nade.lifetime >= 1)
		{
			if(self.nade)
			{
				makevectors(self.v_angle);
				float _force = time - self.nade.lifetime;
				_force /= autocvar_g_nades_nade_lifetime;
				_force = autocvar_g_nades_nade_minforce + (_force * (autocvar_g_nades_nade_maxforce - autocvar_g_nades_nade_minforce));				
				toss_nade(self, (v_forward * 0.7 + v_up * 0.2 + v_right * 0.1) * _force, 0);
			}
		}
	}
	
	if(IS_PLAYER(self))
	{
		if ( autocvar_g_nades_bonus && autocvar_g_nades )
		{
			self.nade_type = autocvar_g_nades_bonus_type;
			
			if ( self.bonus_nade_score >= 0 && autocvar_g_nades_bonus_score_max )
				nades_GiveBonus(self,autocvar_g_nades_bonus_score_time/autocvar_g_nades_bonus_score_max);
		}
		else
		{
			self.bonus_nades = self.bonus_nade_score = 0;
		}
	}

	return FALSE;
}

MUTATOR_HOOKFUNCTION(nades_PlayerSpawn)
{
	if(autocvar_g_nades_spawn)
		self.nade_refire = time + autocvar_g_spawnshieldtime;
	else
		self.nade_refire  = time + autocvar_g_nades_nade_refire;

	return FALSE;
}

MUTATOR_HOOKFUNCTION(nades_PlayerDies)
{
	if(frag_target.nade)
		toss_nade(frag_target, '0 0 100', max(frag_target.nade.wait, time + 0.05));
		
	float killcount_bonus = ((frag_attacker.killcount >= 1) ? bound(0, autocvar_g_nades_bonus_score_minor * frag_attacker.killcount, autocvar_g_nades_bonus_score_medium) : autocvar_g_nades_bonus_score_minor);
		
	if(IS_PLAYER(frag_attacker))
	{
		if (SAME_TEAM(frag_attacker, frag_target) || frag_attacker == frag_target)
			nades_RemoveBonus(frag_attacker);
		else if(frag_target.flagcarried)
			nades_GiveBonus(frag_attacker, autocvar_g_nades_bonus_score_medium);
		else
			nades_GiveBonus(frag_attacker, killcount_bonus);
	}
		
	nades_RemoveBonus(frag_target);
		
	return FALSE;
}


void nades_Clear(entity player)
{
	
	if(player.nade)
		remove(player.nade);
	if(player.fake_nade)
		remove(player.fake_nade);
	
	player.nade = player.fake_nade = world;
}

MUTATOR_HOOKFUNCTION(nades_RemovePlayer)
{
	nades_Clear(self);
	nades_RemoveBonus(self);
	return FALSE;
}

MUTATOR_HOOKFUNCTION(nades_SpectateCopy)
{
	self.nade_type = other.nade_type;
	self.bonus_nades = other.bonus_nades;
	self.bonus_nade_score = other.bonus_nade_score;
	return FALSE;
}

MUTATOR_HOOKFUNCTION(nades_BuildMutatorsString)
{
	ret_string = strcat(ret_string, ":Nades");
	return FALSE;
}

MUTATOR_HOOKFUNCTION(nades_BuildMutatorsPrettyString)
{
	ret_string = strcat(ret_string, ", Nades");
	return FALSE;
}

MUTATOR_DEFINITION(mutator_nades)
{
	MUTATOR_HOOK(VehicleEnter, nades_VehicleEnter, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerPreThink, nades_PlayerPreThink, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerSpawn, nades_PlayerSpawn, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDies, nades_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(MakePlayerObserver, nades_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientDisconnect, nades_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(SpectateCopy, nades_SpectateCopy, CBC_ORDER_ANY);
	MUTATOR_HOOK(BuildMutatorsString, nades_BuildMutatorsString, CBC_ORDER_ANY);
	MUTATOR_HOOK(BuildMutatorsPrettyString, nades_BuildMutatorsPrettyString, CBC_ORDER_ANY);
	
	MUTATOR_ONADD
	{
		precache_model("models/ok_nade_counter/ok_nade_counter.md3");
		
		precache_model("models/weapons/h_ok_grenade.iqm");
		precache_model("models/weapons/v_ok_grenade.md3");
		precache_sound("weapons/rocket_impact.wav");
		precache_sound("weapons/grenade_bounce1.wav");
		precache_sound("weapons/grenade_bounce2.wav");
		precache_sound("weapons/grenade_bounce3.wav");
		precache_sound("weapons/grenade_bounce4.wav");
		precache_sound("weapons/grenade_bounce5.wav");
		precache_sound("weapons/grenade_bounce6.wav");
		precache_sound("overkill/grenadebip.ogg");
	}

	return FALSE;
}
