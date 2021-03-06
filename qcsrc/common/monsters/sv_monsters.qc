// =========================
//  SVQC Monster Properties
// =========================


void monster_item_spawn()
{
	if(self.monster_loot)
		self.monster_loot();

	self.gravity = 1;
	self.velocity = randomvec() * 175 + '0 0 325';
	self.classname = "droppedweapon"; // hax

	SUB_SetFade(self, time + autocvar_g_monsters_drop_time, 1);
}

void monster_dropitem()
{
	if(!self.candrop || !self.monster_loot)
		return;

	vector org = self.origin + ((self.mins + self.maxs) * 0.5);
	entity e = spawn();

	setorigin(e, org);

	e.monster_loot = self.monster_loot;

	other = e;
	MUTATOR_CALLHOOK(MonsterDropItem);
	e = other;

	if(e)
	{
		e.think = monster_item_spawn;
		e.nextthink = time + 0.3;
	}
}

void monsters_setframe(float _frame)
{
	if(self.frame == _frame)
		return;

	self.anim_start_time = time;
	self.frame = _frame;
	self.SendFlags |= MSF_ANIM;
}

float monster_isvalidtarget (entity targ, entity ent)
{
	if(!targ || !ent)
		return FALSE; // someone doesn't exist

	if(targ == ent)
		return FALSE; // don't attack ourselves

	traceline(ent.origin, targ.origin, MOVE_NORMAL, ent);

	if(trace_ent != targ)
		return FALSE;

	if(targ.vehicle_flags & VHF_ISVEHICLE)
	if not((get_monsterinfo(ent.monsterid)).spawnflags & MON_FLAG_RANGED)
		return FALSE; // melee attacks are useless against vehicles

	if(time < game_starttime)
		return FALSE; // monsters do nothing before the match has started

	if(vlen(targ.origin - ent.origin) >= ent.target_range)
		return FALSE; // enemy is too far away

	if(targ.takedamage == DAMAGE_NO)
		return FALSE; // enemy can't be damaged

	if(targ.items & IT_INVISIBILITY)
		return FALSE; // enemy is invisible

	if(substring(targ.classname, 0, 10) == "onslaught_")
		return FALSE; // don't attack onslaught targets

	if(IS_SPEC(targ) || IS_OBSERVER(targ))
		return FALSE; // enemy is a spectator

	if not(targ.vehicle_flags & VHF_ISVEHICLE)
	if(targ.deadflag != DEAD_NO || ent.deadflag != DEAD_NO || targ.health <= 0 || ent.health <= 0)
		return FALSE; // enemy/self is dead

	if(ent.monster_owner == targ)
		return FALSE; // don't attack our master

	if(targ.monster_owner == ent)
		return FALSE; // don't attack our pet

	if not(targ.vehicle_flags & VHF_ISVEHICLE)
	if(targ.flags & FL_NOTARGET)
		return FALSE; // enemy can't be targeted

	if not(autocvar_g_monsters_typefrag)
	if(targ.BUTTON_CHAT)
		return FALSE; // no typefragging!

	if(SAME_TEAM(targ, ent))
		return FALSE; // enemy is on our team
		
	if (targ.frozen == 1 || (targ.frozen == 2 && ent.monsterid != MON_SPIDER))
		return FALSE; // ignore frozen

	if(autocvar_g_monsters_target_infront || ent.spawnflags & MONSTERFLAG_INFRONT)
	if(ent.enemy != targ)
	{
		float dot;

		makevectors (ent.angles);
		dot = normalize (targ.origin - ent.origin) * v_forward;

		if(dot <= 0.3)
			return FALSE;
	}

	return TRUE;
}

entity FindTarget (entity ent)
{
	if(MUTATOR_CALLHOOK(MonsterFindTarget)) { return ent.enemy; } // Handled by a mutator

	entity head, closest_target = world;
	head = findradius(ent.origin, ent.target_range);

	while(head) // find the closest acceptable target to pass to
	{
		if(head.monster_attack)
		if(monster_isvalidtarget(head, ent))
		{
			// if it's a player, use the view origin as reference (stolen from RadiusDamage functions in g_damage.qc)
			vector head_center = CENTER_OR_VIEWOFS(head);
			vector ent_center = CENTER_OR_VIEWOFS(ent);

			//if(ctf_CheckPassDirection(head_center, ent_center, ent.v_angle, head.WarpZone_findradius_nearest))
			if(closest_target)
			{
				vector closest_target_center = CENTER_OR_VIEWOFS(closest_target);
				if(vlen(ent_center - head_center) < vlen(ent_center - closest_target_center))
					{ closest_target = head; }
			}
			else { closest_target = head; }
		}

		head = head.chain;
	}

	return closest_target;
}

void MonsterTouch ()
{
	if(other == world)
		return;

	if(self.enemy != other)
	if not(other.flags & FL_MONSTER)
	if(monster_isvalidtarget(other, self))
		self.enemy = other;
}

string get_monster_model_datafilename(string m, float sk, string fil)
{
	if(m)
		m = strcat(m, "_");
	else
		m = "models/monsters/*_";
	if(sk >= 0)
		m = strcat(m, ftos(sk));
	else
		m = strcat(m, "*");
	return strcat(m, ".", fil);
}

void PrecacheMonsterSounds(string f)
{
	float fh;
	string s;
	fh = fopen(f, FILE_READ);
	if(fh < 0)
		return;
	while((s = fgets(fh)))
	{
		if(tokenize_console(s) != 3)
		{
			dprint("Invalid sound info line: ", s, "\n");
			continue;
		}
		PrecacheGlobalSound(strcat(argv(1), " ", argv(2)));
	}
	fclose(fh);
}

void precache_monstersounds()
{
	string m = (get_monsterinfo(self.monsterid)).model;
	float globhandle, n, i;
	string f;

	globhandle = search_begin(strcat(m, "_*.sounds"), TRUE, FALSE);
	if (globhandle < 0)
		return;
	n = search_getsize(globhandle);
	for (i = 0; i < n; ++i)
	{
		//print(search_getfilename(globhandle, i), "\n");
		f = search_getfilename(globhandle, i);
		PrecacheMonsterSounds(f);
	}
	search_end(globhandle);
}

void ClearMonsterSounds()
{
#define _MSOUND(m) if(self.monstersound_##m) { strunzone(self.monstersound_##m); self.monstersound_##m = string_null; }
	ALLMONSTERSOUNDS
#undef _MSOUND
}

.string GetMonsterSoundSampleField(string type)
{
	GetMonsterSoundSampleField_notFound = 0;
	switch(type)
	{
#define _MSOUND(m) case #m: return monstersound_##m;
		ALLMONSTERSOUNDS
#undef _MSOUND
	}
	GetMonsterSoundSampleField_notFound = 1;
	return string_null;
}

float LoadMonsterSounds(string f, float first)
{
	float fh;
	string s;
	var .string field;
	fh = fopen(f, FILE_READ);
	if(fh < 0)
	{
		dprint("Monster sound file not found: ", f, "\n");
		return 0;
	}
	while((s = fgets(fh)))
	{
		if(tokenize_console(s) != 3)
			continue;
		field = GetMonsterSoundSampleField(argv(0));
		if(GetMonsterSoundSampleField_notFound)
			continue;
		if(self.field)
			strunzone(self.field);
		self.field = strzone(strcat(argv(1), " ", argv(2)));
	}
	fclose(fh);
	return 1;
}

.float skin_for_monstersound;
void UpdateMonsterSounds()
{
	entity mon = get_monsterinfo(self.monsterid);

	if(self.skin == self.skin_for_monstersound)
		return;
	self.skin_for_monstersound = self.skin;
	ClearMonsterSounds();
	//LoadMonsterSounds("sound/monsters/default.sounds", 1);
	if(!autocvar_g_debug_defaultsounds)
	if(!LoadMonsterSounds(get_monster_model_datafilename(mon.model, self.skin, "sounds"), 0))
		LoadMonsterSounds(get_monster_model_datafilename(mon.model, 0, "sounds"), 0);
}

void MonsterSound(.string samplefield, float sound_delay, float delaytoo, float chan)
{
	if(delaytoo && time < self.msound_delay)
		return; // too early
	GlobalSound(self.samplefield, chan, VOICETYPE_PLAYERSOUND);

	self.msound_delay = time + sound_delay;
}

void monster_makevectors(entity e)
{
	vector v;

	v = e.origin + (e.mins + e.maxs) * 0.5;
	self.v_angle = vectoangles(v - (self.origin + self.view_ofs));
	self.v_angle_x = -self.v_angle_x;

	makevectors(self.v_angle);
}

float monster_melee(entity targ, float damg, float anim, float er, float anim_finished, float deathtype, float dostop)
{
	float rdmg = damg * random();

	if (self.health <= 0)
		return FALSE; // attacking while dead?!

	if(dostop)
	{
		self.velocity_x = 0;
		self.velocity_y = 0;
		self.state = MONSTER_STATE_ATTACK_MELEE;
		self.SendFlags |= MSF_MOVE;
	}

	monsters_setframe(anim);

	if(anim_finished != 0)
		self.attack_finished_single = time + anim_finished;

	monster_makevectors(targ);

	traceline(self.origin + self.view_ofs, self.origin + v_forward * er, 0, self);

	if(trace_ent.takedamage)
		Damage(trace_ent, self, self, rdmg * monster_skill, deathtype, trace_ent.origin, normalize(trace_ent.origin - self.origin));

	return TRUE;
}

void Monster_CheckMinibossFlag ()
{
	if(MUTATOR_CALLHOOK(MonsterCheckBossFlag))
		return;

	float chance = random() * 100;

	// g_monsters_miniboss_chance cvar or spawnflags 64 causes a monster to be a miniboss
	if ((self.spawnflags & MONSTERFLAG_MINIBOSS) || (chance < autocvar_g_monsters_miniboss_chance))
	{
		self.health += autocvar_g_monsters_miniboss_healthboost;
		if not(self.weapon)
			self.weapon = WEP_NEX;
	}
}

float Monster_CanRespawn(entity ent)
{
	other = ent;
	if(MUTATOR_CALLHOOK(MonsterRespawn))
		return TRUE; // enabled by a mutator

	if(ent.spawnflags & MONSTERFLAG_NORESPAWN)
		return FALSE;

	if not(autocvar_g_monsters_respawn)
		return FALSE;

	return TRUE;
}

void Monster_Fade ()
{
	if(Monster_CanRespawn(self))
	{
		self.monster_respawned = TRUE;
		self.think = self.monster_spawnfunc;
		self.nextthink = time + self.respawntime;
		self.ltime = 0;
		self.deadflag = DEAD_RESPAWNING;
		if(self.spawnflags & MONSTER_RESPAWN_DEATHPOINT)
		{
			self.pos1 = self.origin;
			self.pos2 = self.angles;
		}
		self.event_damage = func_null;
		self.takedamage = DAMAGE_NO;
		setorigin(self, self.pos1);
		self.angles = self.pos2;
		self.health = self.max_health;

		self.SendFlags |= MSF_MOVE;
		self.SendFlags |= MSF_STATUS;
	}
	else
		SUB_SetFade(self, time + 3, 1);
}

float Monster_CanJump (vector vel)
{
	if(self.state)
		return FALSE; // already attacking
	if not(self.flags & FL_ONGROUND)
		return FALSE; // not on the ground
	if(self.health <= 0)
		return FALSE; // called when dead?
	if(time < self.attack_finished_single)
		return FALSE; // still attacking

	vector old = self.velocity;

	self.velocity = vel;
	tracetoss(self, self);
	self.velocity = old;
	if (trace_ent != self.enemy)
		return FALSE;

	return TRUE;
}

float monster_leap (float anm, void() touchfunc, vector vel, float anim_finished)
{
	if(!Monster_CanJump(vel))
		return FALSE;

	monsters_setframe(anm);
	self.state = MONSTER_STATE_ATTACK_LEAP;
	self.touch = touchfunc;
	self.origin_z += 1;
	self.velocity = vel;
	self.flags &= ~FL_ONGROUND;

	self.attack_finished_single = time + anim_finished;

	return TRUE;
}

void monster_checkattack(entity e, entity targ)
{
	if(e == world)
		return;
	if(targ == world)
		return;

	if not(e.monster_attackfunc)
		return;

	if(time < e.attack_finished_single)
		return;

	if(vlen(targ.origin - e.origin) <= e.attack_range)
	if(e.monster_attackfunc(MONSTER_ATTACK_MELEE))
	{
		MonsterSound(monstersound_melee, 0, FALSE, CH_VOICE);
		return;
	}

	if(vlen(targ.origin - e.origin) > e.attack_range)
	if(e.monster_attackfunc(MONSTER_ATTACK_RANGED))
	{
		MonsterSound(monstersound_ranged, 0, FALSE, CH_VOICE);
		return;
	}
}

void monster_use ()
{
	if not(self.enemy)
	if(self.health > 0)
	if(monster_isvalidtarget(activator, self))
		self.enemy = activator;
}

.float last_trace;
.float last_enemycheck; // for checking enemy
vector monster_pickmovetarget(entity targ)
{
	// enemy is always preferred target
	if(self.enemy)
	{
		makevectors(self.angles);
		self.monster_movestate = MONSTER_MOVE_ENEMY;
		self.last_trace = time + 1.2;
		return self.enemy.origin;
	}

	switch(self.monster_moveflags)
	{
		case MONSTER_MOVE_OWNER:
		{
			self.monster_movestate = MONSTER_MOVE_OWNER;
			self.last_trace = time + 0.3;
			return (self.monster_owner) ? self.monster_owner.origin : self.origin;
		}
		case MONSTER_MOVE_SPAWNLOC:
		{
			self.monster_movestate = MONSTER_MOVE_SPAWNLOC;
			self.last_trace = time + 2;
			return self.pos1;
		}
		case MONSTER_MOVE_NOMOVE:
		{
			self.monster_movestate = MONSTER_MOVE_NOMOVE;
			self.last_trace = time + 2;
			return self.origin;
		}
		default:
		case MONSTER_MOVE_WANDER:
		{
			vector pos;
			self.monster_movestate = MONSTER_MOVE_WANDER;
			self.last_trace = time + 2;

			self.angles_y = rint(random() * 500);
			makevectors(self.angles);
			pos = self.origin + v_forward * 600;

			if(self.flags & FL_FLY || self.flags & FL_SWIM)
			if(self.spawnflags & MONSTERFLAG_FLY_VERTICAL)
			{
				pos_z = random() * 200;
				if(random() >= 0.5)
					pos_z *= -1;
			}

			if(targ)
			{
				self.last_trace = time + 0.5;
				pos = targ.origin;
			}

			return pos;
		}
	}
}

void monster_move(float runspeed, float walkspeed, float stopspeed, float manim_run, float manim_walk, float manim_idle)
{
	fixedmakevectors(self.angles);

	if(self.target2)
		self.goalentity = find(world, targetname, self.target2);

	entity targ;

	if(self.frozen)
	{
		self.revive_progress = bound(0, self.revive_progress + frametime * self.revive_speed, 1);
		self.health = max(1, self.max_health * self.revive_progress);

		self.SendFlags |= MSF_STATUS;

		movelib_beak_simple(stopspeed);
		
		monsters_setframe(manim_idle);
		
		self.enemy = world;
		self.nextthink = time + self.ticrate;

		if(self.revive_progress >= 1)
			Unfreeze(self); // wait for next think before attacking

		// don't bother updating angles here?
		if(self.origin != self.oldorigin)
		{
			self.oldorigin = self.origin;
			self.SendFlags |= MSF_MOVE;
		}

		return; // no moving while frozen
	}

	if(self.flags & FL_SWIM)
	{
		if(self.waterlevel < WATERLEVEL_WETFEET)
		{
			if(time >= self.last_trace)
			{
				self.fish_wasdrowning = TRUE;
				self.last_trace = time + 0.4;

				Damage (self, world, world, 2, DEATH_DROWN, self.origin, '0 0 0');
				self.angles = '90 90 0';
				if(random() < 0.5)
				{
					self.velocity_y += random() * 50;
					self.velocity_x -= random() * 50;
				}
				else
				{
					self.velocity_y -= random() * 50;
					self.velocity_x += random() * 50;
				}
				self.velocity_z += random() * 150;
			}


			self.movetype = MOVETYPE_BOUNCE;
			//self.velocity_z = -200;

			self.SendFlags |= MSF_MOVE | MSF_ANG;

			return;
		}
		else if(self.fish_wasdrowning)
		{
			self.fish_wasdrowning = FALSE;
			self.angles_x = 0;
			self.movetype = MOVETYPE_WALK;
		}
	}

	targ = self.goalentity;

	monster_target = targ;
	monster_speed_run = runspeed;
	monster_speed_walk = walkspeed;

	if(MUTATOR_CALLHOOK(MonsterMove) || gameover || (round_handler_IsActive() && !round_handler_IsRoundStarted()) || time < game_starttime || (autocvar_g_campaign && !campaign_bots_may_start) || time < self.spawn_time)
	{
		runspeed = walkspeed = 0;
		if(time >= self.spawn_time)
			monsters_setframe(manim_idle);
		movelib_beak_simple(stopspeed);
		if(self.oldorigin != self.origin)
		{
			self.oldorigin = self.origin;
			self.SendFlags |= MSF_MOVE;
		}
		return;
	}

	targ = monster_target;
	runspeed = monster_speed_run;
	walkspeed = monster_speed_walk;

	if(teamplay)
	if(autocvar_g_monsters_teams)
	if(DIFF_TEAM(self.monster_owner, self))
		self.monster_owner = world;

	if(self.enemy && self.enemy.health < 1)
		self.enemy = world; // enough!

	if(time >= self.last_enemycheck)
	{
		if not(monster_isvalidtarget(self.enemy, self))
			self.enemy = world;

		if not(self.enemy)
		{
			self.enemy = FindTarget(self);
			if(self.enemy)
				MonsterSound(monstersound_sight, 0, FALSE, CH_VOICE);
		}

		self.last_enemycheck = time + 0.5;
	}

	if(self.state == MONSTER_STATE_ATTACK_MELEE && time >= self.attack_finished_single)
		self.state = 0;

	if(self.state != MONSTER_STATE_ATTACK_MELEE) // don't move if set
	if(time >= self.last_trace || self.enemy) // update enemy instantly
		self.moveto = monster_pickmovetarget(targ);

	if not(self.enemy)
		MonsterSound(monstersound_idle, 5, TRUE, CH_VOICE);

	if(self.state != MONSTER_STATE_ATTACK_LEAP && self.state != MONSTER_STATE_ATTACK_MELEE)
		self.steerto = steerlib_attract2(self.moveto, 0.5, 500, 0.95);

	if(self.state == MONSTER_STATE_ATTACK_LEAP && (self.flags & FL_ONGROUND))
	{
		self.state = 0;
		self.touch = MonsterTouch;
	}

	//self.steerto = steerlib_attract2(self.moveto, 0.5, 500, 0.95);

	float turny = 0;
	vector real_angle = vectoangles(self.steerto) - self.angles;

	if(self.state != MONSTER_STATE_ATTACK_LEAP && self.state != MONSTER_STATE_ATTACK_MELEE)
		turny = 20;

	if(self.flags & FL_SWIM)
		turny = vlen(self.angles - self.moveto);

	if(turny)
	{
		turny = bound(turny * -1, shortangle_f(real_angle_y, self.angles_y), turny);
		self.angles_y += turny;
	}

	if(self.state == MONSTER_STATE_ATTACK_MELEE)
		self.moveto = self.origin;

	if(self.enemy && self.enemy.vehicle)
		runspeed = 0;

	if(((self.flags & FL_FLY) || (self.flags & FL_SWIM)) && self.spawnflags & MONSTERFLAG_FLY_VERTICAL)
		v_forward = normalize(self.moveto - self.origin);
	else
		self.moveto_z = self.origin_z;

	if(vlen(self.origin - self.moveto) > 64)
	{
		if(self.flags & FL_FLY || self.flags & FL_SWIM)
			movelib_move_simple(v_forward, ((self.enemy) ? runspeed : walkspeed), 0.6);
		else
			movelib_move_simple_gravity(v_forward, ((self.enemy) ? runspeed : walkspeed), 0.6);

		if(time > self.pain_finished)
		if(time > self.attack_finished_single)
		if(vlen(self.velocity) > 10)
			monsters_setframe((self.enemy) ? manim_run : manim_walk);
		else
			monsters_setframe(manim_idle);
	}
	else
	{
		entity e = find(world, targetname, self.target2);
		if(e.target2)
			self.target2 = e.target2;
		else if(e.target)
			self.target2 = e.target;

		movelib_beak_simple(stopspeed);
		if(time > self.attack_finished_single)
		if(time > self.pain_finished)
		if (vlen(self.velocity) <= 30)
			monsters_setframe(manim_idle);
	}

	monster_checkattack(self, self.enemy);

	if(self.angles != self.oldangles)
	{
		self.oldangles = self.angles;
		self.SendFlags |= MSF_ANG;
	}

	if(self.origin != self.oldorigin)
	{
		self.oldorigin = self.origin;
		self.SendFlags |= MSF_MOVE;
	}
}

void monster_dead_think()
{
	self.think = monster_dead_think;
	self.nextthink = time + self.ticrate;

	self.deadflag = DEAD_DEAD;

	if(self.ltime != 0)
	if(time >= self.ltime)
	{
		Monster_Fade();
		return;
	}

	if(self.oldorigin != self.origin)
	{
		self.oldorigin = self.origin;
		self.SendFlags |= MSF_MOVE;
	}
}

void monsters_setstatus()
{
	self.stat_monsters_total = monsters_total;
	self.stat_monsters_killed = monsters_killed;
}

void Monster_Appear()
{
	self.enemy = activator;
	self.spawnflags &= ~MONSTERFLAG_APPEAR;
	self.monster_spawnfunc();
}

float Monster_CheckAppearFlags(entity ent)
{
	if not(ent.spawnflags & MONSTERFLAG_APPEAR)
		return FALSE;

	ent.think = func_null;
	ent.nextthink = 0;
	ent.use = Monster_Appear;
	ent.flags = FL_MONSTER; // set so this monster can get butchered

	return TRUE;
}

void monsters_reset()
{
	setorigin(self, self.pos1);
	self.angles = self.pos2;
	
	Unfreeze(self); // remove any icy remains

	self.health = self.max_health;
	self.velocity = '0 0 0';
	self.enemy = world;
	self.goalentity = world;
	self.attack_finished_single = 0;
	self.moveto = self.origin;

	self.SendFlags |= MSF_STATUS;
}

float monster_send(entity to, float sf)
{
	WriteByte(MSG_ENTITY, ENT_CLIENT_MONSTER);
	WriteByte(MSG_ENTITY, sf);
	if(sf & MSF_SETUP)
	{
		WriteByte(MSG_ENTITY, self.monsterid);

		WriteCoord(MSG_ENTITY, self.origin_x);
		WriteCoord(MSG_ENTITY, self.origin_y);
		WriteCoord(MSG_ENTITY, self.origin_z);

		WriteAngle(MSG_ENTITY, self.angles_x);
		WriteAngle(MSG_ENTITY, self.angles_y);

		WriteByte(MSG_ENTITY, self.skin);
		WriteByte(MSG_ENTITY, self.team);
	}

	if(sf & MSF_ANG)
	{
		WriteShort(MSG_ENTITY, rint(self.angles_x));
		WriteShort(MSG_ENTITY, rint(self.angles_y));
	}

	if(sf & MSF_MOVE)
	{
		WriteShort(MSG_ENTITY, rint(self.origin_x));
		WriteShort(MSG_ENTITY, rint(self.origin_y));
		WriteShort(MSG_ENTITY, rint(self.origin_z));

		WriteShort(MSG_ENTITY, rint(self.velocity_x));
		WriteShort(MSG_ENTITY, rint(self.velocity_y));
		WriteShort(MSG_ENTITY, rint(self.velocity_z));

		WriteShort(MSG_ENTITY, rint(self.angles_y));
	}

	if(sf & MSF_ANIM)
	{
		WriteCoord(MSG_ENTITY, self.anim_start_time);
		WriteByte(MSG_ENTITY, self.frame);
	}

	if(sf & MSF_STATUS)
	{
		WriteByte(MSG_ENTITY, self.skin);

		WriteByte(MSG_ENTITY, self.team);

		WriteByte(MSG_ENTITY, self.deadflag);

		if(self.health <= 0)
			WriteByte(MSG_ENTITY, 0);
		else
			WriteByte(MSG_ENTITY, ceil((self.health / self.max_health) * 255));
	}

	return TRUE;
}

void monster_link(void() spawnproc)
{
	Net_LinkEntity(self, TRUE, 0, monster_send);
	self.think	  = spawnproc;
	self.nextthink	= time;
}

void monsters_corpse_damage (entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	self.health -= damage;

	Violence_GibSplash_At(hitloc, force, 2, bound(0, damage, 200) / 16, self, attacker);

	if(self.health <= -100) // 100 health until gone?
	{
		Violence_GibSplash_At(hitloc, force, 2, bound(0, damage, 200) / 16, self, attacker);

		self.think = SUB_Remove;
		self.nextthink = time + 0.1;
	}
}

void monster_die(entity attacker)
{
	self.think = monster_dead_think;
	self.nextthink = self.ticrate;
	self.ltime = time + 5;
	
	Unfreeze(self); // remove any icy remains
	self.health = 0; // reset by Unfreeze

	monster_dropitem();

	MonsterSound(monstersound_death, 0, FALSE, CH_VOICE);

	if(!(self.spawnflags & MONSTERFLAG_SPAWNED) && !self.monster_respawned)
		monsters_killed += 1;
		
	if(IS_PLAYER(attacker))
	if( autocvar_g_monsters_score_spawned || 
			( !(self.spawnflags & MONSTERFLAG_SPAWNED) && !self.monster_respawned) )
		PlayerScore_Add(attacker, SP_SCORE, +autocvar_g_monsters_score_kill);


	if(self.candrop && self.weapon)
		W_ThrowNewWeapon(self, self.weapon, 0, self.origin, randomvec() * 150 + '0 0 325');

	if(IS_CLIENT(self.realowner))
	if not(self.monster_respawned)
		self.realowner.monstercount -= 1;

	self.event_damage	= monsters_corpse_damage;
	self.solid			= SOLID_CORPSE;
	self.takedamage		= DAMAGE_AIM;
	self.enemy			= world;
	self.movetype		= MOVETYPE_TOSS;
	self.moveto			= self.origin;
	self.touch			= MonsterTouch; // reset incase monster was pouncing
	self.reset			= func_null;
	self.state			= 0;
	self.attack_finished_single = 0;

	if not(self.flags & FL_FLY)
		self.velocity = '0 0 0';

	self.SendFlags |= MSF_MOVE;

	// number of monsters spawned with mobspawn command
	totalspawned -= 1;

	MON_ACTION(self.monsterid, MR_DEATH);
}

void monsters_damage (entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if(self.frozen && deathtype != DEATH_KILL)
		return;

	if(time < self.pain_finished && deathtype != DEATH_KILL)
		return;

	if(time < self.spawnshieldtime && deathtype != DEATH_KILL)
		return;

	vector v;
	float take, save;

	v = healtharmor_applydamage(self.armorvalue, self.m_armor_blockpercent, damage, deathtype);
	take = v_x;
	save = v_y;

	self.health -= take;

	self.dmg_time = time;

	if(sound_allowed(MSG_BROADCAST, attacker) && deathtype != DEATH_DROWN)
		spamsound (self, CH_PAIN, "misc/bodyimpact1.wav", VOL_BASE, ATTEN_NORM);  // FIXME: PLACEHOLDER

	self.velocity += force * self.damageforcescale;

	if(deathtype != DEATH_DROWN)
	{
		Violence_GibSplash_At(hitloc, force, 2, bound(0, take, 200) / 16, self, attacker);
		if (take > 50)
			Violence_GibSplash_At(hitloc, force * -0.1, 3, 1, self, attacker);
		if (take > 100)
			Violence_GibSplash_At(hitloc, force * -0.2, 3, 1, self, attacker);
	}

	if(self.health <= 0)
	{
		if(deathtype == DEATH_KILL)
			self.candrop = FALSE; // killed by mobkill command

		// TODO: fix this?
		activator = attacker;
		other = self.enemy;
		SUB_UseTargets();
		self.target2 = self.oldtarget2; // reset to original target on death, incase we respawn

		monster_die(attacker);
		
		frag_attacker = attacker;
		frag_target = self;
		MUTATOR_CALLHOOK(MonsterDies);

		if(self.health <= -100 || deathtype == DEATH_KILL) // check if we're already gibbed
		{
			Violence_GibSplash(self, 1, 0.5, attacker);

			self.think = SUB_Remove;
			self.nextthink = time + 0.1;
		}
	}

	self.SendFlags |= MSF_STATUS;
}

void monster_think()
{
	self.think = monster_think;
	self.nextthink = self.ticrate;
	
	if(self.ltime)
	if(time >= self.ltime)
	{
		Damage(self, self, self, self.health + self.max_health, DEATH_KILL, self.origin, self.origin);
		return;
	}

	MON_ACTION(self.monsterid, MR_THINK);
}

void monster_spawn()
{
	MON_ACTION(self.monsterid, MR_SETUP);

	if not(self.monster_respawned)
		Monster_CheckMinibossFlag();

	self.max_health = self.health;
	self.pain_finished = self.nextthink;
	self.anim_start_time = time;

	if not(self.noalign)
	{
		setorigin(self, self.origin + '0 0 20');
		tracebox(self.origin + '0 0 100', self.mins, self.maxs, self.origin - '0 0 10000', MOVE_WORLDONLY, self);
		setorigin(self, trace_endpos);
	}

	if not(self.monster_respawned)
	if not(self.skin)
		self.skin = rint(random() * 4);

	if not(self.attack_range)
		self.attack_range = autocvar_g_monsters_attack_range;

	self.pos1 = self.origin;

	//monster_setupsounds(self.netname);
	precache_monstersounds();
	UpdateMonsterSounds();
	//monster_precachesounds(self);

	if(teamplay)
		self.monster_attack = TRUE; // we can have monster enemies in team games
		
	MonsterSound(monstersound_spawn, 0, FALSE, CH_VOICE);

	self.think = monster_think;
	self.nextthink = time + self.ticrate;

	self.SendFlags |= MSF_SETUP;

	MUTATOR_CALLHOOK(MonsterSpawn);
}

float monster_initialize(float mon_id, float nodrop)
{
	if not(autocvar_g_monsters)
		return FALSE;

	entity mon = get_monsterinfo(mon_id);

	// support for quake style removing monsters based on skill
	switch(monster_skill)
	{
		case 0:
		case 1: if(self.spawnflags & MONSTERSKILL_NOTEASY)		return FALSE; break;
		case 2: if(self.spawnflags & MONSTERSKILL_NOTMEDIUM)	return FALSE; break;
		default:
		case 3: if(self.spawnflags & MONSTERSKILL_NOTHARD)		return FALSE; break;
	}

	if(self.team && !teamplay)
		self.team = 0;

	if not(self.spawnflags & MONSTERFLAG_SPAWNED) // naturally spawned monster
	if not(self.monster_respawned)
		monsters_total += 1;

	setsize(self, mon.mins, mon.maxs);
	self.flags				= FL_MONSTER;
	self.takedamage			= DAMAGE_AIM;
	self.bot_attack			= TRUE;
	self.iscreature			= TRUE;
	self.teleportable		= TRUE;
	self.damagedbycontents	= TRUE;
	self.monsterid			= mon_id;
	self.damageforcescale	= 0;
	self.event_damage		= monsters_damage;
	self.touch				= MonsterTouch;
	self.use				= monster_use;
	self.solid				= SOLID_BBOX;
	self.movetype			= MOVETYPE_WALK;
	self.spawnshieldtime	= time + autocvar_g_monsters_spawnshieldtime;
	self.enemy				= world;
	self.velocity			= '0 0 0';
	self.moveto				= self.origin;
	self.pos2				= self.angles;
	self.reset				= monsters_reset;
	self.netname			= mon.netname;
	self.monster_name		= M_NAME(mon_id);
	self.candrop			= TRUE;
	self.view_ofs			= '0 0 1' * (self.maxs_z * 0.5);
	self.oldtarget2			= self.target2;
	self.deadflag			= DEAD_NO;
	self.scale				= 1;
	self.noalign			= nodrop;
	self.spawn_time			= time;
	self.gravity			= 1;
	self.dphitcontentsmask	= DPCONTENTS_SOLID | DPCONTENTS_BODY | DPCONTENTS_BOTCLIP | DPCONTENTS_MONSTERCLIP;

	if(mon.spawnflags & MONSTER_TYPE_SWIM)
		self.flags |= FL_SWIM;

	if(mon.spawnflags & MONSTER_TYPE_FLY)
	{
		self.flags |= FL_FLY;
		self.movetype = MOVETYPE_FLY;
	}

	if(mon.spawnflags & MONSTER_SIZE_BROKEN)
		self.scale = 1.3;

	if not(self.ticrate)
		self.ticrate = autocvar_g_monsters_think_delay;

	self.ticrate = bound(sys_frametime, self.ticrate, 60);

	if not(self.m_armor_blockpercent)
		self.m_armor_blockpercent = 0.5;

	if not(self.target_range)
		self.target_range = autocvar_g_monsters_target_range;

	if not(self.respawntime)
		self.respawntime = autocvar_g_monsters_respawn_delay;

	if not(self.monster_moveflags)
		self.monster_moveflags = MONSTER_MOVE_WANDER;

	monster_link(monster_spawn);

	return TRUE;
}
