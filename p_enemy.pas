//------------------------------------------------------------------------------
//
//  DoomXS - A basic Windows source port of Doom
//  based on original Linux Doom as published by "id Software"
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2021-2022 by Jim Valavanis
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.
//
//------------------------------------------------------------------------------
//  Site: https://sourceforge.net/projects/doomxs/
//------------------------------------------------------------------------------

unit p_enemy;

interface

uses
  doomdef,
  p_local,
  p_mobj_h,
  s_sound,
  d_player,
  p_pspr_h,
  doomstat,
  sounds;

procedure A_Fall(actor: Pmobj_t);

procedure A_KeenDie(mo: Pmobj_t);

procedure A_Look(actor: Pmobj_t);

procedure A_Chase(actor: Pmobj_t);

procedure A_FaceTarget(actor: Pmobj_t);

procedure A_PosAttack(actor: Pmobj_t);

procedure A_SPosAttack(actor: Pmobj_t);

procedure A_CPosAttack(actor: Pmobj_t);

procedure A_CPosRefire(actor: Pmobj_t);

procedure A_SpidRefire(actor: Pmobj_t);

procedure A_BspiAttack(actor: Pmobj_t);

procedure A_TroopAttack(actor: Pmobj_t);

procedure A_SargAttack(actor: Pmobj_t);

procedure A_HeadAttack(actor: Pmobj_t);

procedure A_CyberAttack(actor: Pmobj_t);

procedure A_BruisAttack(actor: Pmobj_t);

procedure A_SkelMissile(actor: Pmobj_t);

procedure A_Tracer(actor: Pmobj_t);

procedure A_SkelWhoosh(actor: Pmobj_t);

procedure A_SkelFist(actor: Pmobj_t);

procedure A_VileChase(actor: Pmobj_t);

procedure A_VileStart(actor: Pmobj_t);

procedure A_Fire(actor: Pmobj_t);

procedure A_StartFire(actor: Pmobj_t);

procedure A_FireCrackle(actor: Pmobj_t);

procedure A_VileTarget(actor: Pmobj_t);

procedure A_VileAttack(actor: Pmobj_t);

procedure A_FatRaise(actor: Pmobj_t);

procedure A_FatAttack1(actor: Pmobj_t);

procedure A_FatAttack2(actor: Pmobj_t);

procedure A_FatAttack3(actor: Pmobj_t);

procedure A_SkullAttack(actor: Pmobj_t);

procedure A_PainAttack(actor: Pmobj_t);

procedure A_PainDie(actor: Pmobj_t);

procedure A_Scream(actor: Pmobj_t);

procedure A_XScream(actor: Pmobj_t);

procedure A_Pain(actor: Pmobj_t);

procedure A_Explode(thingy: Pmobj_t);

procedure A_BossDeath(mo: Pmobj_t);

procedure A_Hoof(mo: Pmobj_t);

procedure A_Metal(mo: Pmobj_t);

procedure A_BabyMetal(mo: Pmobj_t);

procedure A_OpenShotgun2(player: Pplayer_t; psp: Pplayer_t);

procedure A_LoadShotgun2(player: Pplayer_t; psp: Ppspdef_t);

procedure A_CloseShotgun2(player: Pplayer_t; psp: Ppspdef_t);

procedure A_BrainAwake(mo: Pmobj_t);

procedure A_BrainPain(mo: Pmobj_t);

procedure A_BrainScream(mo: Pmobj_t);

procedure A_BrainExplode(mo: Pmobj_t);

procedure A_BrainDie(mo: Pmobj_t);

procedure A_BrainSpit(mo: Pmobj_t);

procedure A_SpawnFly(mo: Pmobj_t);

procedure A_SpawnSound(mo: Pmobj_t);

procedure A_PlayerScream(mo: Pmobj_t);


procedure P_NoiseAlert(target: Pmobj_t; emmiter: Pmobj_t);

implementation

uses
  d_delphi,
  doomdata,
  d_think,
  d_main,
  g_game,
  m_fixed,
  tables,
  i_system,
  info_h,
  info,
  m_rnd,
  p_map,
  p_maputl,
  p_setup,
  p_sight,
  p_switch,
  p_tick,
  p_mobj,
  p_doors,
  p_spec,
  p_inter,
  p_floor,
  p_pspr,
  r_defs,
  r_main;

type
  dirtype_t = (
    DI_EAST,
    DI_NORTHEAST,
    DI_NORTH,
    DI_NORTHWEST,
    DI_WEST,
    DI_SOUTHWEST,
    DI_SOUTH,
    DI_SOUTHEAST,
    DI_NODIR,
    NUMDIRS
    );

const
  opposite: array[0..8] of dirtype_t = (
    DI_WEST, DI_SOUTHWEST, DI_SOUTH, DI_SOUTHEAST,
    DI_EAST, DI_NORTHEAST, DI_NORTH, DI_NORTHWEST, DI_NODIR
  );

  diags: array[0..3] of dirtype_t = (
    DI_NORTHWEST, DI_NORTHEAST, DI_SOUTHWEST, DI_SOUTHEAST
  );

procedure A_Fall(actor: Pmobj_t);
begin
  // actor is on ground, it can be walked over
  actor.flags := actor.flags and not MF_SOLID;

  // So change this if corpse objects
  // are meant to be obstacles.
end;

// ENEMY THINKING
// Enemies are allways spawned
// with targetplayer = -1, threshold = 0
// Most monsters are spawned unaware of all players,
// but some can be made preaware

// Called by P_NoiseAlert.
// Recursively traverse adjacent sectors,
// sound blocking lines cut off traversal.
var
  soundtarget: Pmobj_t;

procedure P_RecursiveSound(sec: Psector_t; soundblocks: integer);
var
  i: integer;
  check: Pline_t;
  other: Psector_t;
begin
  // wake up all monsters in this sector
  if (sec.validcount = validcount) and (sec.soundtraversed <= soundblocks + 1) then
    Exit; // already flooded

  sec.validcount := validcount;
  sec.soundtraversed := soundblocks + 1;
  sec.soundtarget := soundtarget;

  for i := 0 to sec.linecount - 1 do
  begin
    check := sec.lines[i];
    if check.flags and ML_TWOSIDED = 0 then
      Continue;

    P_LineOpening(check);

    if openrange <= 0 then
      Continue; // closed door

    if sides[check.sidenum[0]].sector = sec then
      other := sides[check.sidenum[1]].sector
    else
      other := sides[check.sidenum[0]].sector;

    if check.flags and ML_SOUNDBLOCK <> 0 then
    begin
      if soundblocks = 0 then
        P_RecursiveSound(other, 1);
    end
    else
      P_RecursiveSound(other, soundblocks);
  end;
end;

// P_NoiseAlert
// If a monster yells at a player,
// it will alert other monsters to the player.
procedure P_NoiseAlert(target: Pmobj_t; emmiter: Pmobj_t);
begin
  soundtarget := target;
  Inc(validcount);
  P_RecursiveSound(Psubsector_t(emmiter.subsector).sector, 0);
end;

// P_CheckMeleeRange
function P_CheckMeleeRange(actor: Pmobj_t): boolean;
var
  pl: Pmobj_t;
  dist: fixed_t;
begin
  pl := actor.target;
  if pl = nil then
  begin
    Result := False;
    Exit;
  end;

  dist := P_AproxDistance(pl.x - actor.x, pl.y - actor.y);

  if dist >= MELEERANGE - 20 * FRACUNIT + pl.info.radius then
  begin
    Result := False;
    Exit;
  end;

  Result := P_CheckSight(actor, actor.target);
end;

// P_CheckMissileRange
function P_CheckMissileRange(actor: Pmobj_t): boolean;
var
  dist: fixed_t;
begin
  if not P_CheckSight(actor, actor.target) then
  begin
    Result := False;
    Exit;
  end;

  if actor.flags and MF_JUSTHIT <> 0 then
  begin
    // the target just hit the enemy,
    // so fight back!
    actor.flags := actor.flags and not MF_JUSTHIT;
    Result := True;
    Exit;
  end;

  if actor.reactiontime <> 0 then
  begin
    Result := False; // do not attack yet
    Exit;
  end;

  // OPTIMIZE: get this from a global checksight
  dist := P_AproxDistance(actor.x - actor.target.x, actor.y - actor.target.y) -
    64 * FRACUNIT;

  if actor.info.meleestate = 0 then
    dist := dist - 128 * FRACUNIT;  // no melee attack, so fire more

  dist := _SHR(dist, FRACBITS);

  if actor.typ = MT_VILE then
    if dist > 14 * 64 then
    begin
      Result := False; // too far away
      Exit;
    end;

  if actor.typ = MT_UNDEAD then
  begin
    if dist < 196 then
    begin
      Result := False; // close for fist attack
      Exit;
    end;
    dist := _SHR(dist, 1);
  end;


  if (actor.typ = MT_CYBORG) or (actor.typ = MT_SPIDER) or
    (actor.typ = MT_SKULL) then
    dist := _SHR(dist, 1);

  if dist > 200 then
    dist := 200;

  if (actor.typ = MT_CYBORG) and (dist > 160) then
    dist := 160;

  if P_Random < dist then
    Result := False
  else
    Result := True;
end;

// P_Move
// Move in the current direction,
// returns False if the move is blocked.
const
  xspeed: array[0..7] of fixed_t =
    (FRACUNIT, 47000, 0, -47000, -FRACUNIT, -47000, 0, 47000);

  yspeed: array[0..7] of fixed_t =
    (0, 47000, FRACUNIT, 47000, 0, -47000, -FRACUNIT, -47000);

function P_Move(actor: Pmobj_t): boolean;
var
  tryx: fixed_t;
  tryy: fixed_t;
  ld: Pline_t;
  try_ok: boolean;
begin
  if actor.movedir = Ord(DI_NODIR) then
  begin
    Result := False;
    Exit;
  end;

  if Ord(actor.movedir) >= 8 then
    I_Error('P_Move(): Weird actor->movedir = %d', [Ord(actor.movedir)]);

  tryx := actor.x + actor.info.speed * xspeed[actor.movedir];
  tryy := actor.y + actor.info.speed * yspeed[actor.movedir];

  try_ok := P_TryMove(actor, tryx, tryy);

  if not try_ok then
  begin
    // open any specials
    if (actor.flags and MF_FLOAT <> 0) and floatok then
    begin
      // must adjust height
      if actor.z < tmfloorz then
        actor.z := actor.z + FLOATSPEED
      else
        actor.z := actor.z - FLOATSPEED;

      actor.flags := actor.flags or MF_INFLOAT;
      Result := True;
      Exit;
    end;

    if numspechit = 0 then
    begin
      Result := False;
      Exit;
    end;

    actor.movedir := Ord(DI_NODIR);
    Result := False;
    while numspechit > 0 do
    begin
      Dec(numspechit);
      ld := spechit[numspechit];
      // if the special is not a door
      // that can be opened,
      // return False
      if P_UseSpecialLine(actor, ld, 0) then
        Result := True;
    end;
    Exit;
  end
  else
    actor.flags := actor.flags and not MF_INFLOAT;

  if actor.flags and MF_FLOAT = 0 then
    actor.z := actor.floorz;
  Result := True;
end;

// TryWalk
// Attempts to move actor on
// in its current (ob->moveangle) direction.
// If blocked by either a wall or an actor
// returns FALSE
// If move is either clear or blocked only by a door,
// returns TRUE and sets...
// If a door is in the way,
// an OpenDoor call is made to start it opening.
function P_TryWalk(actor: Pmobj_t): boolean;
begin
  if not P_Move(actor) then
    Result := False
  else
  begin
    actor.movecount := P_Random and 15;
    Result := True;
  end;
end;

procedure P_NewChaseDir(actor: Pmobj_t);
var
  deltax: fixed_t;
  deltay: fixed_t;
  d: array[0..2] of dirtype_t;
  tdir: dirtype_t;
  olddir: dirtype_t;
  turnaround: dirtype_t;
  idx: integer;
begin
  if actor.target = nil then
    I_Error('P_NewChaseDir(): called with no target');

  olddir := dirtype_t(actor.movedir);
  turnaround := opposite[Ord(olddir)];

  deltax := actor.target.x - actor.x;
  deltay := actor.target.y - actor.y;

  if deltax > 10 * FRACUNIT then
    d[1] := DI_EAST
  else if deltax < -10 * FRACUNIT then
    d[1] := DI_WEST
  else
    d[1] := DI_NODIR;

  if deltay < -10 * FRACUNIT then
    d[2] := DI_SOUTH
  else if deltay > 10 * FRACUNIT then
    d[2] := DI_NORTH
  else
    d[2] := DI_NODIR;

  // try direct route
  if (d[1] <> DI_NODIR) and (d[2] <> DI_NODIR) then
  begin
    if deltay < 0 then
      idx := 2
    else
      idx := 0;
    if deltax > 0 then
      Inc(idx);
    actor.movedir := Ord(diags[idx]);
    if (actor.movedir <> Ord(turnaround)) and P_TryWalk(actor) then
      Exit;
  end;

  // try other directions
  if (P_Random > 200) or (abs(deltay) > abs(deltax)) then
  begin
    tdir := d[1];
    d[1] := d[2];
    d[2] := tdir;
  end;

  if d[1] = turnaround then
    d[1] := DI_NODIR;
  if d[2] = turnaround then
    d[2] := DI_NODIR;

  if d[1] <> DI_NODIR then
  begin
    actor.movedir := Ord(d[1]);
    if P_TryWalk(actor) then
      Exit; // either moved forward or attacked
  end;

  if d[2] <> DI_NODIR then
  begin
    actor.movedir := Ord(d[2]);
    if P_TryWalk(actor) then
      Exit;
  end;

  // there is no direct path to the player,
  // so pick another direction.
  if olddir <> DI_NODIR then
  begin
    actor.movedir := Ord(olddir);
    if P_TryWalk(actor) then
      Exit;
  end;

  // randomly determine direction of search
  if P_Random and 1 <> 0 then
  begin
    for tdir := DI_EAST to DI_SOUTHEAST do
    begin
      if tdir <> turnaround then
      begin
        actor.movedir := Ord(tdir);
        if P_TryWalk(actor) then
          Exit;
      end;
    end;
  end
  else
  begin
    for tdir := DI_SOUTHEAST downto DI_EAST do
    begin
      if tdir <> turnaround then
      begin
        actor.movedir := Ord(tdir);
        if P_TryWalk(actor) then
          Exit;
      end;
    end;
  end;

  if turnaround <> DI_NODIR then
  begin
    actor.movedir := Ord(turnaround);
    if P_TryWalk(actor) then
      Exit;
  end;

  actor.movedir := Ord(DI_NODIR); // can not move
end;


// P_LookForPlayers
// If allaround is False, only look 180 degrees in front.
// Returns True if a player is targeted.
function P_LookForPlayers(actor: Pmobj_t; allaround: boolean): boolean;
var
  c: integer;
  stop: integer;
  player: Pplayer_t;
  an: angle_t;
  dist: fixed_t;
  initial: boolean;
begin
  c := 0;
  stop := (actor.lastlook - 1) and 3;

  initial := True;
  while True do
  begin
    if initial then
      initial := False
    else
      actor.lastlook := (actor.lastlook + 1) and 3;

    if not playeringame[actor.lastlook] then
      Continue;

    if (c = 2) or (actor.lastlook = stop) then
    begin
      // done looking
      Result := False;
      Exit;
    end;
    Inc(c);

    player := @players[actor.lastlook];

    if player.health <= 0 then
      Continue;   // dead

    if not P_CheckSight(actor, player.mo) then
      Continue;   // out of sight

    if not allaround then
    begin
      an := R_PointToAngle2(actor.x, actor.y,
        player.mo.x, player.mo.y) - actor.angle;

      if (an > ANG90) and (an < ANG270) then
      begin
        dist := P_AproxDistance(player.mo.x - actor.x, player.mo.y - actor.y);
        // if real close, react anyway
        if dist > MELEERANGE then
          Continue; // behind back
      end;
    end;

    actor.target := player.mo;
    Result := True;
    Exit;
  end;

  Result := False;
end;

// A_KeenDie
// DOOM II special, map 32.
// Uses special tag 666.
procedure A_KeenDie(mo: Pmobj_t);
var
  th: Pthinker_t;
  mo2: Pmobj_t;
  junk: line_t;
begin
  A_Fall(mo);

  // scan the remaining thinkers
  // to see if all Keens are dead

  th := thinkercap.next;
  while th <> @thinkercap do
  begin
    if @th.func.acp1 = @P_MobjThinker then
    begin
      mo2 := Pmobj_t(th);
      if (mo2 <> mo) and (mo2.typ = mo.typ) and (mo2.health > 0) then
        Exit; // other Keen not dead
    end;
    th := th.next;
  end;

  junk.tag := 666;
  EV_DoDoor(@junk, open);
end;

// ACTION ROUTINES

// A_Look
// Stay in state until a player is sighted.
procedure A_Look(actor: Pmobj_t);
var
  targ: Pmobj_t;
  seeyou: boolean;
  sound: integer;
begin
  actor.threshold := 0; // any shot will wake up
  targ := Psubsector_t(actor.subsector).sector.soundtarget;
  seeyou := False;
  if (targ <> nil) and (targ.flags and MF_SHOOTABLE <> 0) then
  begin
    actor.target := targ;

    if actor.flags and MF_AMBUSH <> 0 then
    begin
      if P_CheckSight(actor, targ) then
        seeyou := True;
    end
    else
      seeyou := True;
  end;

  if not seeyou then
  begin
    if not P_LookForPlayers(actor, False) then
      Exit;
  end;

  // go into chase state
  if actor.info.seesound <> 0 then
  begin
    case sfxenum_t(actor.info.seesound) of
      sfx_posit1,
      sfx_posit2,
      sfx_posit3:
        sound := Ord(sfx_posit1) + P_Random mod 3;

      sfx_bgsit1,
      sfx_bgsit2:
        sound := Ord(sfx_bgsit1) + P_Random mod 2;
    else
      sound := actor.info.seesound;
    end;

    if (actor.typ = MT_SPIDER) or (actor.typ = MT_CYBORG) then
      // full volume
      S_StartSound(nil, sound)
    else
      S_StartSound(actor, sound);
  end;

  P_SetMobjState(actor, statenum_t(actor.info.seestate));
end;

// A_Chase
// Actor has a melee attack,
// so it tries to close as fast as possible
procedure A_Chase(actor: Pmobj_t);
var
  delta: integer;
  nomissile: boolean;
begin
  if actor.reactiontime <> 0 then
    actor.reactiontime := actor.reactiontime - 1;

  // modify target threshold
  if actor.threshold <> 0 then
  begin
    if (actor.target = nil) or (actor.target.health <= 0) then
      actor.threshold := 0
    else
      actor.threshold := actor.threshold - 1;
  end;

  // turn towards movement direction if not there yet
  if actor.movedir < 8 then
  begin
    actor.angle := actor.angle and $E0000000;
    delta := actor.angle - _SHLW(actor.movedir, 29);

    if delta > 0 then
      actor.angle := actor.angle - ANG90 div 2
    else if delta < 0 then
      actor.angle := actor.angle + ANG90 div 2;
  end;

  if (actor.target = nil) or (actor.target.flags and MF_SHOOTABLE = 0) then
  begin
    // look for a new target
    if P_LookForPlayers(actor, True) then
      Exit; // got a new target

    P_SetMobjState(actor, statenum_t(actor.info.spawnstate));
    Exit;
  end;

  // do not attack twice in a row
  if actor.flags and MF_JUSTATTACKED <> 0 then
  begin
    actor.flags := actor.flags and not MF_JUSTATTACKED;
    if (gameskill <> sk_nightmare) and not fastparm then
      P_NewChaseDir(actor);
    Exit;
  end;

  // check for melee attack
  if (actor.info.meleestate <> 0) and P_CheckMeleeRange(actor) then
  begin
    if actor.info.attacksound <> 0 then
      S_StartSound(actor, actor.info.attacksound);

    P_SetMobjState(actor, statenum_t(actor.info.meleestate));
    Exit;
  end;

  nomissile := False;
  // check for missile attack
  if actor.info.missilestate <> 0 then
  begin
    if (gameskill < sk_nightmare) and not fastparm and (actor.movecount <> 0) then
      nomissile := True
    else if not P_CheckMissileRange(actor) then
      nomissile := True;
    if not nomissile then
    begin
      P_SetMobjState(actor, statenum_t(actor.info.missilestate));
      actor.flags := actor.flags or MF_JUSTATTACKED;
      Exit;
    end;
  end;

  // possibly choose another target
  if netgame and (actor.threshold = 0) and not P_CheckSight(actor, actor.target) then
    if P_LookForPlayers(actor, True) then
      Exit;  // got a new target

  // chase towards player
  actor.movecount := actor.movecount - 1;
  if (actor.movecount < 0) or not P_Move(actor) then
    P_NewChaseDir(actor);

  // make active sound
  if (actor.info.activesound <> 0) and (P_Random < 3) then
    S_StartSound(actor, actor.info.activesound);
end;

// A_FaceTarget
procedure A_FaceTarget(actor: Pmobj_t);
begin
  if actor.target = nil then
    Exit;

  actor.flags := actor.flags and not MF_AMBUSH;

  actor.angle :=
    R_PointToAngle2(actor.x, actor.y, actor.target.x, actor.target.y);

  if actor.target.flags and MF_SHADOW <> 0 then
    actor.angle := actor.angle + _SHLW(P_Random - P_Random, 21);
end;

// A_PosAttack
procedure A_PosAttack(actor: Pmobj_t);
var
  angle: angle_t;
  damage: integer;
  slope: integer;
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);
  angle := actor.angle;
  slope := P_AimLineAttack(actor, angle, MISSILERANGE);

  S_StartSound(actor, Ord(sfx_pistol));
  angle := angle + _SHLW(P_Random - P_Random, 20);
  damage := ((P_Random mod 5) + 1) * 3;
  P_LineAttack(actor, angle, MISSILERANGE, slope, damage);
end;

procedure A_SPosAttack(actor: Pmobj_t);
var
  i: integer;
  angle: angle_t;
  bangle: angle_t;
  damage: integer;
  slope: integer;
begin
  if actor.target = nil then
    Exit;

  S_StartSound(actor, Ord(sfx_shotgn));
  A_FaceTarget(actor);
  bangle := actor.angle;
  slope := P_AimLineAttack(actor, bangle, MISSILERANGE);

  for i := 0 to 2 do
  begin
    angle := bangle + _SHLW(P_Random - P_Random, 20);
    damage := ((P_Random mod 5) + 1) * 3;
    P_LineAttack(actor, angle, MISSILERANGE, slope, damage);
  end;
end;

procedure A_CPosAttack(actor: Pmobj_t);
var
  angle: angle_t;
  bangle: angle_t;
  damage: integer;
  slope: integer;
begin
  if actor.target = nil then
    Exit;

  S_StartSound(actor, Ord(sfx_shotgn));
  A_FaceTarget(actor);
  bangle := actor.angle;

  slope := P_AimLineAttack(actor, bangle, MISSILERANGE);

  angle := bangle + _SHLW(P_Random - P_Random, 20);
  damage := ((P_Random mod 5) + 1) * 3;
  P_LineAttack(actor, angle, MISSILERANGE, slope, damage);
end;

procedure A_CPosRefire(actor: Pmobj_t);
begin
  // keep firing unless target got out of sight
  A_FaceTarget(actor);

  if P_Random < 40 then
    Exit;

  if (actor.target = nil) or (actor.target.health <= 0) or
    not P_CheckSight(actor, actor.target) then
    P_SetMobjState(actor, statenum_t(actor.info.seestate));
end;

procedure A_SpidRefire(actor: Pmobj_t);
begin
  // keep firing unless target got out of sight
  A_FaceTarget(actor);

  if P_Random < 10 then
    Exit;

  if (actor.target = nil) or (actor.target.health <= 0) or
    not P_CheckSight(actor, actor.target) then
    P_SetMobjState(actor, statenum_t(actor.info.seestate));
end;

procedure A_BspiAttack(actor: Pmobj_t);
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);

  // launch a missile
  P_SpawnMissile(actor, actor.target, MT_ARACHPLAZ);
end;

// A_TroopAttack
procedure A_TroopAttack(actor: Pmobj_t);
var
  damage: integer;
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);
  if P_CheckMeleeRange(actor) then
  begin
    S_StartSound(actor, Ord(sfx_claw));
    damage := (P_Random mod 8 + 1) * 3;
    P_DamageMobj(actor.target, actor, actor, damage);
    Exit;
  end;

  // launch a missile
  P_SpawnMissile(actor, actor.target, MT_TROOPSHOT);
end;

procedure A_SargAttack(actor: Pmobj_t);
var
  damage: integer;
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);
  if P_CheckMeleeRange(actor) then
  begin
    damage := ((P_Random mod 10) + 1) * 4;
    P_DamageMobj(actor.target, actor, actor, damage);
  end;
end;

procedure A_HeadAttack(actor: Pmobj_t);
var
  damage: integer;
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);
  if P_CheckMeleeRange(actor) then
  begin
    damage := (P_Random mod 6 + 1) * 10;
    P_DamageMobj(actor.target, actor, actor, damage);
    Exit;
  end;

  // launch a missile
  P_SpawnMissile(actor, actor.target, MT_HEADSHOT);
end;

procedure A_CyberAttack(actor: Pmobj_t);
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);
  P_SpawnMissile(actor, actor.target, MT_ROCKET);
end;

procedure A_BruisAttack(actor: Pmobj_t);
var
  damage: integer;
begin
  if actor.target = nil then
    Exit;

  if P_CheckMeleeRange(actor) then
  begin
    S_StartSound(actor, Ord(sfx_claw));
    damage := (P_Random mod 8 + 1) * 10;
    P_DamageMobj(actor.target, actor, actor, damage);
    Exit;
  end;

  // launch a missile
  P_SpawnMissile(actor, actor.target, MT_BRUISERSHOT);
end;

// A_SkelMissile
procedure A_SkelMissile(actor: Pmobj_t);
var
  mo: Pmobj_t;
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);
  actor.z := actor.z + 16 * FRACUNIT; // so missile spawns higher
  mo := P_SpawnMissile(actor, actor.target, MT_TRACER);
  actor.z := actor.z - 16 * FRACUNIT; // back to normal

  mo.x := mo.x + mo.momx;
  mo.y := mo.y + mo.momy;
  mo.tracer := actor.target;
end;

const
  TRACEANGLE = $c000000;

procedure A_Tracer(actor: Pmobj_t);
var
  exact: angle_t;
  dist: fixed_t;
  slope: fixed_t;
  dest: Pmobj_t;
  th: Pmobj_t;
begin
  if (gametic - demostarttic) and 3 <> 0 then
    // [crispy] fix revenant internal demo bug
    Exit;

  // spawn a puff of smoke behind the rocket
  P_SpawnPuff(actor.x, actor.y, actor.z);

  th := P_SpawnMobj(actor.x - actor.momx, actor.y - actor.momy, actor.z, MT_SMOKE);

  th.momz := FRACUNIT;
  th.tics := th.tics - P_Random and 3;
  if th.tics < 1 then
    th.tics := 1;

  // adjust direction
  dest := actor.tracer;

  if (dest = nil) or (dest.health <= 0) then
    Exit;

  // change angle
  exact := R_PointToAngle2(actor.x, actor.y, dest.x, dest.y);

  if exact <> actor.angle then
  begin
    if exact - actor.angle > ANG180 then
    begin
      actor.angle := actor.angle - TRACEANGLE;
      if exact - actor.angle < ANG180 then
        actor.angle := exact;
    end
    else
    begin
      actor.angle := actor.angle + TRACEANGLE;
      if exact - actor.angle > ANG180 then
        actor.angle := exact;
    end;
  end;

  exact := actor.angle shr ANGLETOFINESHIFT;
  actor.momx := FixedMul(actor.info.speed, finecosine[exact]);
  actor.momy := FixedMul(actor.info.speed, finesine[exact]);

  // change slope
  dist := P_AproxDistance(dest.x - actor.x, dest.y - actor.y);

  dist := dist div actor.info.speed;

  if dist < 1 then
    dist := 1;
  slope := (dest.z + 40 * FRACUNIT - actor.z) div dist;

  if slope < actor.momz then
    actor.momz := actor.momz - FRACUNIT div 8
  else
    actor.momz := actor.momz + FRACUNIT div 8;
end;

procedure A_SkelWhoosh(actor: Pmobj_t);
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);
  S_StartSound(actor, Ord(sfx_skeswg));
end;

procedure A_SkelFist(actor: Pmobj_t);
var
  damage: integer;
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);

  if P_CheckMeleeRange(actor) then
  begin
    damage := ((P_Random mod 10) + 1) * 6;
    S_StartSound(actor, Ord(sfx_skepch));
    P_DamageMobj(actor.target, actor, actor, damage);
  end;
end;

// PIT_VileCheck
// Detect a corpse that could be raised.
var
  corpsehit: Pmobj_t;
  viletryx: fixed_t;
  viletryy: fixed_t;

function PIT_VileCheck(thing: Pmobj_t): boolean;
var
  maxdist: integer;
  check: boolean;
begin
  if thing.flags and MF_CORPSE = 0 then
  begin
    Result := True; // not a monster
    Exit;
  end;

  if thing.tics <> -1 then
  begin
    Result := True; // not lying still yet
    Exit;
  end;

  if thing.info.raisestate = Ord(S_NULL) then
  begin
    Result := True; // monster doesn't have a raise state
    Exit;
  end;

  maxdist := thing.info.radius + mobjinfo[Ord(MT_VILE)].radius;

  if (abs(thing.x - viletryx) > maxdist) or (abs(thing.y - viletryy) > maxdist) then
  begin
    Result := True; // not actually touching
    Exit;
  end;

  corpsehit := thing;
  corpsehit.momx := 0;
  corpsehit.momy := 0;
  corpsehit.height := _SHL(corpsehit.height, 2);
  check := P_CheckPosition(corpsehit, corpsehit.x, corpsehit.y);
  corpsehit.height := _SHR(corpsehit.height, 2);

  if not check then
    Result := True    // doesn't fit here
  else
    Result := False;  // got one, so stop checking
end;

// A_VileChase
// Check for ressurecting a body
procedure A_VileChase(actor: Pmobj_t);
var
  xl: integer;
  xh: integer;
  yl: integer;
  yh: integer;
  bx: integer;
  by: integer;
  info: Pmobjinfo_t;
  temp: Pmobj_t;
begin
  if actor.movedir <> Ord(DI_NODIR) then
  begin
    // check for corpses to raise
    viletryx := actor.x + actor.info.speed * xspeed[actor.movedir];
    viletryy := actor.y + actor.info.speed * yspeed[actor.movedir];

    xl := _SHR((viletryx - bmaporgx - MAXRADIUS * 2), MAPBLOCKSHIFT);
    xh := _SHR((viletryx - bmaporgx + MAXRADIUS * 2), MAPBLOCKSHIFT);
    yl := _SHR((viletryy - bmaporgy - MAXRADIUS * 2), MAPBLOCKSHIFT);
    yh := _SHR((viletryy - bmaporgy + MAXRADIUS * 2), MAPBLOCKSHIFT);

    for bx := xl to xh do
    begin
      for by := yl to yh do
      begin
        // Call PIT_VileCheck to check
        // whether object is a corpse
        // that canbe raised.
        if not P_BlockThingsIterator(bx, by, PIT_VileCheck) then
        begin
          // got one!
          temp := actor.target;
          actor.target := corpsehit;
          A_FaceTarget(actor);
          actor.target := temp;

          P_SetMobjState(actor, S_VILE_HEAL1);
          S_StartSound(corpsehit, Ord(sfx_slop));
          info := corpsehit.info;

          P_SetMobjState(corpsehit, statenum_t(info.raisestate));
          corpsehit.height := _SHL(corpsehit.height, 2);
          corpsehit.flags := info.flags;
          corpsehit.health := info.spawnhealth;
          corpsehit.target := nil;
          Exit;
        end;
      end;
    end;
  end;

  // Return to normal attack.
  A_Chase(actor);
end;

// A_VileStart
procedure A_VileStart(actor: Pmobj_t);
begin
  S_StartSound(actor, Ord(sfx_vilatk));
end;

// A_Fire
// Keep fire in front of player unless out of sight
procedure A_Fire(actor: Pmobj_t);
var
  dest: Pmobj_t;
  an: LongWord;
begin
  dest := actor.tracer;
  if dest = nil then
    Exit;

  // don't move it if the vile lost sight
  if not P_CheckSight(actor.target, dest) then
    Exit;

  an := dest.angle shr ANGLETOFINESHIFT;

  P_UnsetThingPosition(actor);
  actor.x := dest.x + FixedMul(24 * FRACUNIT, finecosine[an]);
  actor.y := dest.y + FixedMul(24 * FRACUNIT, finesine[an]);
  actor.z := dest.z;
  P_SetThingPosition(actor);
end;

procedure A_StartFire(actor: Pmobj_t);
begin
  S_StartSound(actor, Ord(sfx_flamst));
  A_Fire(actor);
end;

procedure A_FireCrackle(actor: Pmobj_t);
begin
  S_StartSound(actor, Ord(sfx_flame));
  A_Fire(actor);
end;

// A_VileTarget
// Spawn the hellfire
procedure A_VileTarget(actor: Pmobj_t);
var
  fog: Pmobj_t;
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);

  fog := P_SpawnMobj(actor.target.x, actor.target.x, actor.target.z, MT_FIRE);

  actor.tracer := fog;
  fog.target := actor;
  fog.tracer := actor.target;
  A_Fire(fog);
end;

// A_VileAttack
procedure A_VileAttack(actor: Pmobj_t);
var
  fire: Pmobj_t;
  an: angle_t;
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);

  if not P_CheckSight(actor, actor.target) then
    Exit;

  S_StartSound(actor, Ord(sfx_barexp));
  P_DamageMobj(actor.target, actor, actor, 20);
  actor.target.momz := 1000 * FRACUNIT div actor.target.info.mass;

  an := actor.angle shr ANGLETOFINESHIFT;

  fire := actor.tracer;

  if fire = nil then
    Exit;

  // move the fire between the vile and the player
  fire.x := actor.target.x - FixedMul(24 * FRACUNIT, finecosine[an]);
  fire.y := actor.target.y - FixedMul(24 * FRACUNIT, finesine[an]);
  P_RadiusAttack(fire, actor, 70);
end;

// Mancubus attack,
// firing three missiles (bruisers)
// in three different directions?
// Doesn't look like it.
const
  FATSPREAD = ANG90 div 8;

procedure A_FatRaise(actor: Pmobj_t);
begin
  A_FaceTarget(actor);
  S_StartSound(actor, Ord(sfx_manatk));
end;

procedure A_FatAttack1(actor: Pmobj_t);
var
  mo: Pmobj_t;
  an: angle_t;
begin
  A_FaceTarget(actor);
  // Change direction  to ...
  actor.angle := actor.angle + FATSPREAD;
  P_SpawnMissile(actor, actor.target, MT_FATSHOT);

  mo := P_SpawnMissile(actor, actor.target, MT_FATSHOT);
  mo.angle := mo.angle + FATSPREAD;
  an := mo.angle shr ANGLETOFINESHIFT;
  mo.momx := FixedMul(mo.info.speed, finecosine[an]);
  mo.momy := FixedMul(mo.info.speed, finesine[an]);
end;

procedure A_FatAttack2(actor: Pmobj_t);
var
  mo: Pmobj_t;
  an: angle_t;
begin
  A_FaceTarget(actor);
  // Now here choose opposite deviation.
  actor.angle := actor.angle - FATSPREAD;
  P_SpawnMissile(actor, actor.target, MT_FATSHOT);

  mo := P_SpawnMissile(actor, actor.target, MT_FATSHOT);
  mo.angle := mo.angle - FATSPREAD * 2;
  an := mo.angle shr ANGLETOFINESHIFT;
  mo.momx := FixedMul(mo.info.speed, finecosine[an]);
  mo.momy := FixedMul(mo.info.speed, finesine[an]);
end;

procedure A_FatAttack3(actor: Pmobj_t);
var
  mo: Pmobj_t;
  an: angle_t;
begin
  A_FaceTarget(actor);

  mo := P_SpawnMissile(actor, actor.target, MT_FATSHOT);
  mo.angle := mo.angle - FATSPREAD div 2;
  an := mo.angle shr ANGLETOFINESHIFT;
  mo.momx := FixedMul(mo.info.speed, finecosine[an]);
  mo.momy := FixedMul(mo.info.speed, finesine[an]);

  mo := P_SpawnMissile(actor, actor.target, MT_FATSHOT);
  mo.angle := mo.angle + FATSPREAD div 2;
  an := mo.angle shr ANGLETOFINESHIFT;
  mo.momx := FixedMul(mo.info.speed, finecosine[an]);
  mo.momy := FixedMul(mo.info.speed, finesine[an]);
end;

// SkullAttack
// Fly at the player like a missile.
const
  SKULLSPEED = 20 * FRACUNIT;

procedure A_SkullAttack(actor: Pmobj_t);
var
  dest: Pmobj_t;
  an: angle_t;
  dist: integer;
begin
  if actor.target = nil then
    Exit;

  dest := actor.target;
  actor.flags := actor.flags or MF_SKULLFLY;

  S_StartSound(actor, actor.info.attacksound);
  A_FaceTarget(actor);
  an := actor.angle shr ANGLETOFINESHIFT;
  actor.momx := FixedMul(SKULLSPEED, finecosine[an]);
  actor.momy := FixedMul(SKULLSPEED, finesine[an]);
  dist := P_AproxDistance(dest.x - actor.x, dest.y - actor.y);
  dist := dist div SKULLSPEED;

  if dist < 1 then
    dist := 1;
  actor.momz := (dest.z + (_SHR(dest.height, 1)) - actor.z) div dist;
end;

// A_PainShootSkull
// Spawn a lost soul and launch it at the target
procedure A_PainShootSkull(actor: Pmobj_t; angle: angle_t);
var
  x: fixed_t;
  y: fixed_t;
  z: fixed_t;
  newmobj: Pmobj_t;
  an: angle_t;
  prestep: integer;
  count: integer;
  currentthinker: Pthinker_t;
begin
  // count total number of skull currently on the level
  count := 0;

  currentthinker := thinkercap.next;
  while currentthinker <> @thinkercap do
  begin
    if (@currentthinker.func.acp1 = @P_MobjThinker) and
      (Pmobj_t(currentthinker).typ = MT_SKULL) then
      Inc(count);
    currentthinker := currentthinker.next;
  end;

  // if there are allready 20 skulls on the level,
  // don't spit another one
  if count > 20 then
    Exit;

  // okay, there's playe for another one
  an := angle shr ANGLETOFINESHIFT;

  prestep := 4 * FRACUNIT + 3 * (actor.info.radius +
    mobjinfo[Ord(MT_SKULL)].radius) div 2;

  x := actor.x + FixedMul(prestep, finecosine[an]);
  y := actor.y + FixedMul(prestep, finesine[an]);
  z := actor.z + 8 * FRACUNIT;

  newmobj := P_SpawnMobj(x, y, z, MT_SKULL);

  // Check for movements.
  if not P_TryMove(newmobj, newmobj.x, newmobj.y) then
  begin
    // kill it immediately
    P_DamageMobj(newmobj, actor, actor, 10000);
    Exit;
  end;

  newmobj.target := actor.target;
  A_SkullAttack(newmobj);
end;


// A_PainAttack
// Spawn a lost soul and launch it at the target

procedure A_PainAttack(actor: Pmobj_t);
begin
  if actor.target = nil then
    Exit;

  A_FaceTarget(actor);
  A_PainShootSkull(actor, actor.angle);
end;

procedure A_PainDie(actor: Pmobj_t);
begin
  A_Fall(actor);
  A_PainShootSkull(actor, actor.angle + ANG90);
  A_PainShootSkull(actor, actor.angle + ANG180);
  A_PainShootSkull(actor, actor.angle + ANG270);
end;

procedure A_Scream(actor: Pmobj_t);
var
  sound: integer;
begin
  case actor.info.deathsound of
    0: Exit;
    Ord(sfx_podth1),
    Ord(sfx_podth2),
    Ord(sfx_podth3):
      sound := Ord(sfx_podth1) + P_Random mod 3;

    Ord(sfx_bgdth1),
    Ord(sfx_bgdth2):
      sound := Ord(sfx_bgdth1) + P_Random mod 2;
    else
      sound := actor.info.deathsound;
  end;

  // Check for bosses.
  if (actor.typ = MT_SPIDER) or (actor.typ = MT_CYBORG) then
    // full volume
    S_StartSound(nil, sound)
  else
    S_StartSound(actor, sound);
end;

procedure A_XScream(actor: Pmobj_t);
begin
  S_StartSound(actor, Ord(sfx_slop));
end;

procedure A_Pain(actor: Pmobj_t);
begin
  if actor.info.painsound <> 0 then
    S_StartSound(actor, actor.info.painsound);
end;

// A_Explode
procedure A_Explode(thingy: Pmobj_t);
begin
  P_RadiusAttack(thingy, thingy.target, 128);
end;

// A_BossDeath
// Possibly trigger special effects
// if on first boss level
procedure A_BossDeath(mo: Pmobj_t);
var
  th: Pthinker_t;
  mo2: Pmobj_t;
  junk: line_t;
  i: integer;
begin
  if gamemode = commercial then
  begin
    if gamemap <> 7 then
      Exit;

    if (mo.typ <> MT_FATSO) and (mo.typ <> MT_BABY) then
      Exit;
  end
  else
  begin
    case gameepisode of
      1:
      begin
        if gamemap <> 8 then
          Exit;
        if mo.typ <> MT_BRUISER then
          Exit;
      end;
      2:
      begin
        if gamemap <> 8 then
          Exit;
        if mo.typ <> MT_CYBORG then
          Exit;
      end;
      3:
      begin
        if gamemap <> 8 then
          Exit;
        if mo.typ <> MT_SPIDER then
          Exit;
      end;
      4:
      begin
        case gamemap of
          6: if mo.typ <> MT_CYBORG then
              Exit;
          8: if mo.typ <> MT_SPIDER then
              Exit;
        end;
      end;
      else
      begin
        if gamemap <> 8 then
          Exit;
      end;
    end;
  end;

  // make sure there is a player alive for victory
  i := 0;
  while i < MAXPLAYERS do
  begin
    if playeringame[i] and (players[i].health > 0) then
      Break;
    Inc(i);
  end;

  if i = MAXPLAYERS then
    Exit;  // no one left alive, so do not end game

  // scan the remaining thinkers to see
  // if all bosses are dead
  th := thinkercap.next;
  while th <> @thinkercap do
  begin
    if @th.func.acp1 = @P_MobjThinker then
    begin
      mo2 := Pmobj_t(th);
      if (mo2 <> mo) and (mo2.typ = mo.typ) and (mo2.health > 0) then
      begin
        // other boss not dead
        Exit;
      end;
    end;
    th := th.next;
  end;

  // victory!
  if gamemode = commercial then
  begin
    if gamemap = 7 then
    begin
      if mo.typ = MT_FATSO then
      begin
        junk.tag := 666;
        EV_DoFloor(@junk, lowerFloorToLowest);
        Exit;
      end;
      if mo.typ = MT_BABY then
      begin
        junk.tag := 667;
        EV_DoFloor(@junk, raiseToTexture);
        Exit;
      end;
    end;
  end
  else
  begin
    case gameepisode of
      1:
      begin
        junk.tag := 666;
        EV_DoFloor(@junk, lowerFloorToLowest);
        Exit;
      end;
      4:
      begin
        if gamemap = 6 then
        begin
          junk.tag := 666;
          EV_DoDoor(@junk, blazeOpen);
          Exit;
        end
        else if gamemap = 8 then
        begin
          junk.tag := 666;
          EV_DoFloor(@junk, lowerFloorToLowest);
          Exit;
        end;
      end;
    end;
  end;
  G_ExitLevel;
end;

procedure A_Hoof(mo: Pmobj_t);
begin
  S_StartSound(mo, Ord(sfx_hoof));
  A_Chase(mo);
end;

procedure A_Metal(mo: Pmobj_t);
begin
  S_StartSound(mo, Ord(sfx_metal));
  A_Chase(mo);
end;

procedure A_BabyMetal(mo: Pmobj_t);
begin
  S_StartSound(mo, Ord(sfx_bspwlk));
  A_Chase(mo);
end;

procedure A_OpenShotgun2(player: Pplayer_t; psp: Pplayer_t);
begin
  S_StartSound(player.mo, Ord(sfx_dbopn));
end;

procedure A_LoadShotgun2(player: Pplayer_t; psp: Ppspdef_t);
begin
  S_StartSound(player.mo, Ord(sfx_dbload));
end;

procedure A_CloseShotgun2(player: Pplayer_t; psp: Ppspdef_t);
begin
  S_StartSound(player.mo, Ord(sfx_dbcls));
  A_ReFire(player, psp);
end;

const
  MAXBRAINTARGETS = 32;

var
  braintargets: array[0..MAXBRAINTARGETS - 1] of Pmobj_t;
  numbraintargets: integer;
  braintargeton: integer;

procedure A_BrainAwake(mo: Pmobj_t);
var
  thinker: Pthinker_t;
  m: Pmobj_t;
begin
  // find all the target spots
  numbraintargets := 0;
  braintargeton := 0;

  thinker := thinkercap.next;
  while thinker <> @thinkercap do
  begin
    if @thinker.func.acp1 = @P_MobjThinker then // is a mobj
    begin
      m := Pmobj_t(thinker);
      if m.typ = MT_BOSSTARGET then
      begin
        if numbraintargets >= MAXBRAINTARGETS then
          I_Error('A_BrainAwake(): numbraintargets = %d >= MAXBRAINTARGETS',
            [numbraintargets]);
        braintargets[numbraintargets] := m;
        Inc(numbraintargets);
      end;
    end;
    thinker := thinker.next;
  end;

  S_StartSound(nil, Ord(sfx_bossit));
end;

procedure A_BrainPain(mo: Pmobj_t);
begin
  S_StartSound(nil, Ord(sfx_bospn));
end;

procedure A_BrainScream(mo: Pmobj_t);
var
  x: integer;
  y: integer;
  z: integer;
  th: Pmobj_t;
begin
  x := mo.x - 196 * FRACUNIT;
  while x < mo.x + 320 * FRACUNIT do
  begin
    y := mo.y - 320 * FRACUNIT;
    z := 128 + P_Random * 2 * FRACUNIT;
    th := P_SpawnMobj(x, y, z, MT_ROCKET);
    th.momz := P_Random * 512;

    P_SetMobjState(th, S_BRAINEXPLODE1);

    th.tics := th.tics - (P_Random and 7);
    if th.tics < 1 then
      th.tics := 1;
    x := x + FRACUNIT * 8;
  end;

  S_StartSound(nil, Ord(sfx_bosdth));
end;

procedure A_BrainExplode(mo: Pmobj_t);
var
  x: integer;
  y: integer;
  z: integer;
  th: Pmobj_t;
begin
  x := mo.x + (P_Random - P_Random) * 2048;
  y := mo.y;
  z := 128 + P_Random * 2 * FRACUNIT;
  th := P_SpawnMobj(x, y, z, MT_ROCKET);
  th.momz := P_Random * 512;

  P_SetMobjState(th, S_BRAINEXPLODE1);

  th.tics := th.tics - (P_Random and 7);
  if th.tics < 1 then
    th.tics := 1;
end;

procedure A_BrainDie(mo: Pmobj_t);
begin
  G_ExitLevel;
end;

var
  easy: integer = 0;

procedure A_BrainSpit(mo: Pmobj_t);
var
  targ: Pmobj_t;
  newmobj: Pmobj_t;
begin
  easy := easy xor 1;
  if (gameskill <= sk_easy) and (easy = 0) then
    Exit;

  if numbraintargets = 0 then // JVAL
  begin
    A_BrainAwake(mo);
    Exit;
  end;

  // shoot a cube at current target
  targ := braintargets[braintargeton];
  braintargeton := (braintargeton + 1) mod numbraintargets;

  // spawn brain missile
  newmobj := P_SpawnMissile(mo, targ, MT_SPAWNSHOT);
  newmobj.target := targ;
  newmobj.reactiontime := ((targ.y - mo.y) div newmobj.momy) div newmobj.state.tics;

  S_StartSound(nil, Ord(sfx_bospit));
end;

procedure A_SpawnFly(mo: Pmobj_t);
var
  newmobj: Pmobj_t;
  fog: Pmobj_t;
  targ: Pmobj_t;
  r: integer;
  typ: mobjtype_t;
begin
  mo.reactiontime := mo.reactiontime - 1;
  if mo.reactiontime > 0 then
    Exit; // still flying

  targ := mo.target;

  if targ = nil then
  begin
    P_RemoveMobj(mo);
    Exit;
  end;

  // First spawn teleport fog.
  fog := P_SpawnMobj(targ.x, targ.y, targ.z, MT_SPAWNFIRE);
  S_StartSound(fog, Ord(sfx_telept));

  // Randomly select monster to spawn.
  r := P_Random;

  // Probability distribution (kind of :),
  // decreasing likelihood.
  if r < 50 then
    typ := MT_TROOP
  else if r < 90 then
    typ := MT_SERGEANT
  else if r < 120 then
    typ := MT_SHADOWS
  else if r < 130 then
    typ := MT_PAIN
  else if r < 160 then
    typ := MT_HEAD
  else if r < 162 then
    typ := MT_VILE
  else if r < 172 then
    typ := MT_UNDEAD
  else if r < 192 then
    typ := MT_BABY
  else if r < 222 then
    typ := MT_FATSO
  else if r < 246 then
    typ := MT_KNIGHT
  else
    typ := MT_BRUISER;

  newmobj := P_SpawnMobj(targ.x, targ.y, targ.z, typ);
  if P_LookForPlayers(newmobj, True) then
    P_SetMobjState(newmobj, statenum_t(newmobj.info.seestate));

  // telefrag anything in this spot
  P_TeleportMove(newmobj, newmobj.x, newmobj.y);

  // remove self (i.e., cube).
  P_RemoveMobj(mo);
end;

// travelling cube sound
procedure A_SpawnSound(mo: Pmobj_t);
begin
  S_StartSound(mo, Ord(sfx_boscub));
  A_SpawnFly(mo);
end;

procedure A_PlayerScream(mo: Pmobj_t);
var
  sound: integer;
begin
  // Default death sound.
  sound := Ord(sfx_pldeth);

  if (gamemode = commercial) and (mo.health < -50) then
  begin
    // IF THE PLAYER DIES
    // LESS THAN -50% WITHOUT GIBBING
    sound := Ord(sfx_pdiehi);
  end;

  S_StartSound(mo, sound);
end;

end.


