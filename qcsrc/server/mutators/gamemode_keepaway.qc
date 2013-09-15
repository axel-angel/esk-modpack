// ===========================================================
//  Hidden game mode coding
//  Started: September, 2013
//
//  FIXME: For the time being, I used the keepaway mod file
// ===========================================================

// this wall of uselessness is to avoid error for unused takeaway vars
void keepaway_unused() {
	autocvar_g_keepaway_ballcarrier_effects = 0;
	autocvar_g_keepaway_ballcarrier_damage = 0;
	autocvar_g_keepaway_ballcarrier_force = 0;
	autocvar_g_keepaway_ballcarrier_highspeed = 0;
	autocvar_g_keepaway_ballcarrier_selfdamage = 0;
	autocvar_g_keepaway_ballcarrier_selfforce = 0;
	autocvar_g_keepaway_noncarrier_damage = 0;
	autocvar_g_keepaway_noncarrier_force = 0;
	autocvar_g_keepaway_noncarrier_selfdamage = 0;
	autocvar_g_keepaway_noncarrier_selfforce = 0;
	autocvar_g_keepaway_noncarrier_warn = 0;
	autocvar_g_keepaway_score_bckill = 0;
	autocvar_g_keepaway_score_killac = 0;
	autocvar_g_keepaway_score_timepoints = 0;
	autocvar_g_keepaway_score_timeinterval = 0;
	autocvar_g_keepawayball_damageforcescale = 0;
	autocvar_g_keepawayball_effects = 0;
	autocvar_g_keepawayball_respawntime = 0;
	autocvar_g_keepawayball_trail_color = 0;
}

// ==============
// Hook Functions
// ==============

MUTATOR_HOOKFUNCTION(hidden_PlayerDamage) // for changing damage and force values that are applied to players in g_damage.qc
{
	if (hidden_player == frag_attacker) // if the attacker is hidden
	{
		if(frag_target == frag_attacker) // damage done to yourself
		{
			frag_damage *= autocvar_g_keepaway_ballcarrier_selfdamage;
			frag_force *= autocvar_g_keepaway_ballcarrier_selfforce;
		}
		else // damage done to noncarriers
		{
			frag_damage *= autocvar_g_keepaway_ballcarrier_damage;
			frag_force *= autocvar_g_keepaway_ballcarrier_force;
		}
	}
	else
	{
		if(frag_target == frag_attacker) // damage done to yourself
		{
			frag_damage *= autocvar_g_keepaway_noncarrier_selfdamage;
			frag_force *= autocvar_g_keepaway_noncarrier_selfforce;
		}
		else // damage done to other noncarriers
		{
			frag_damage *= autocvar_g_keepaway_noncarrier_damage;
			frag_force *= autocvar_g_keepaway_noncarrier_force;
		}
	}
	return 0;
}

MUTATOR_HOOKFUNCTION(hidden_RemovePlayer)
{
	if (hidden_player == self) hidden_player = world;
	return 0;
}

// ==============
// Initialization
// ==============

void hidden_ScoreRules()
{
	ScoreRules_basics(0, SFL_SORT_PRIO_PRIMARY, 0, TRUE); // SFL_SORT_PRIO_PRIMARY
	ScoreInfo_SetLabel_PlayerScore(SP_KEEPAWAY_PICKUPS,			"pickups",		0);
	ScoreRules_basics_end();
}

void hidden_assignHidden()
{
	entity e;
	float count;
	hidden_player = world;

	// count players
	total_players = 0;
	FOR_EACH_PLAYER(e) {
		++total_players;
	}

	// choose one hidden among them
	count = total_players;
	FOR_EACH_PLAYER(e) {
		if (!hidden_player && (count == 1 || random() <= 1.0/count)) {
			e.alpha = autocvar_g_minstagib_invis_alpha;
			hidden_player = e;
			Send_Notification(NOTIF_ONE, e, MSG_CENTER, INFO_PLAYER_HIDDEN);
		}
		else {
			e.alpha = 1.0;
			--count;
			Send_Notification(NOTIF_ONE, e, MSG_CENTER, INFO_PLAYER_FORCE);
		}
	}
}

void hidden_roundStart() {
	allowed_to_spawn = FALSE;
	hidden_assignHidden();
}

void hidden_roundInit() {
		round_handler_Init(5, autocvar_g_freezetag_warmup,
				autocvar_g_freezetag_round_timelimit);
}

float hidden_canRoundStart() {
	entity e;
	total_players = 0;

	allowed_to_spawn = TRUE;
	FOR_EACH_PLAYER(e) { ++total_players; }

	if (total_players < 2) {
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_MISSING_PLAYERS, 2 - total_players);
		return 0;
	}

	Kill_Notification(NOTIF_ALL, world, MSG_CENTER_CPID, CPID_MISSING_PLAYERS);

	return 1;
}

float hidden_checkWinner() {
	entity e;
	float total_players_alive;
	float deltaT;
	deltaT = round_handler_GetEndTime() - time;
	total_players_alive = 0;

	if (!hidden_player)
		return -1;

	// forces win if timeout or if the hidden is dead
	if ( (round_handler_GetEndTime() > 0 && deltaT <= 0)
	  || hidden_player.health < 1 )
	{
		return 1;
	}

	FOR_EACH_PLAYER(e) {
		if (e.health >= 1) ++total_players_alive;
	}
	// tied if all dead
	if (total_players_alive == 0) {
		return -1;
	}

	// or hidden wins if he's the last alive
	if (total_players_alive == 1 && hidden_player.health >= 1) {
		return 2;
	}

	return 0;
}

float hidden_canRoundEnd() {
	float winner_team;

	winner_team = hidden_checkWinner();
	if (winner_team == -1)
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_ROUND_TIED);
	if (winner_team == 1)
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_ROUND_PLAYER_WIN, "Force");
	if (winner_team == 2)
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_ROUND_PLAYER_WIN, "Hidden");

	// round has ended
	if (winner_team != 0) {
		hidden_roundInit();
		return 1;
	}

	return 0;
}

void hidden_Initialize() // run at the start of a match, initiates game mode
{
	if(!g_keepaway)
		return;
		
	hidden_ScoreRules();

	// check round start/end + assign hidden at round start
	round_handler_Spawn(hidden_canRoundStart, hidden_canRoundEnd,
			hidden_roundStart);
	hidden_roundInit();
}


MUTATOR_DEFINITION(gamemode_keepaway)
{
	MUTATOR_HOOK(MakePlayerObserver, hidden_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientDisconnect, hidden_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDamage_Calculate, hidden_PlayerDamage, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDies, ca_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(PutClientInServer, ca_PutClientInServer, CBC_ORDER_ANY);
	MUTATOR_HOOK(reset_map_global, ca_reset_map_global, CBC_ORDER_ANY);
	MUTATOR_HOOK(reset_map_players, ca_reset_map_players, CBC_ORDER_ANY);

	MUTATOR_ONADD
	{
		if(time > 1) // game loads at time 1
			error("This is a game type and it cannot be added at runtime.");
		hidden_Initialize();
	}

	MUTATOR_ONROLLBACK_OR_REMOVE
	{
		// do nothing
	}

	MUTATOR_ONREMOVE
	{
		print("This is a game type and it cannot be removed at runtime.");
		return -1;
	}

	return 0;
}
