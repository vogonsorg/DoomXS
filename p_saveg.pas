//------------------------------------------------------------------------------
//
//  DoomXS - A basic Windows source port of Doom
//  based on original Linux Doom as published by "id Software"
//  Copyright (C) 1993-1996 by id Software, Inc.
//  Copyright (C) 2021 by Jim Valavanis
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

unit p_saveg;

interface

uses d_delphi;

{
    p_saveg.h, p_saveg.pas
}

// Emacs style mode select   -*- C++ -*-
//-----------------------------------------------------------------------------
//
// $Id:$
//
// Copyright (C) 1993-1996 by id Software, Inc.
//
// This source is available for distribution and/or modification
// only under the terms of the DOOM Source Code License as
// published by id Software. All rights reserved.
//
// The source is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// FITNESS FOR A PARTICULAR PURPOSE. See the DOOM Source Code License
// for more details.
//
// DESCRIPTION:
//	Savegame I/O, archiving, persistence.
//
//-----------------------------------------------------------------------------

// Persistent storage/archiving.
// These are the load / save game routines.
procedure P_ArchivePlayers;

procedure P_UnArchivePlayers;

procedure P_ArchiveWorld;

procedure P_UnArchiveWorld;

procedure P_ArchiveThinkers;

procedure P_UnArchiveThinkers;

procedure P_ArchiveSpecials;

procedure P_UnArchiveSpecials;

var
  save_p: PByteArray;

implementation

uses doomdef, doomstat,
  d_player, d_think,
  g_game,
  m_fixed,
  info_h, info,
  i_system,
  p_local, p_pspr_h, p_setup, p_mobj_h, p_mobj, p_tick, p_maputl, p_spec,
  p_ceilng, p_doors, p_floor, p_plats, p_lights,
  r_defs,
  z_zone;

// Pads save_p to a 4-byte boundary
//  so that the load/save works on SGI&Gecko.

procedure PADSAVEP;
begin
  save_p := PByteArray(integer(save_p) + ((4 - (integer(save_p) and 3) and 3)));
end;

//
// P_ArchivePlayers
//
procedure P_ArchivePlayers;
var
  i: integer;
  j: integer;
  dest: Pplayer_t;
begin
  for i := 0 to MAXPLAYERS - 1 do
  begin
    if not playeringame[i] then
      continue;

    PADSAVEP;

    dest := Pplayer_t(save_p);
    memcpy(dest, @players[i], SizeOf(player_t));
    save_p := PByteArray(integer(save_p) + SizeOf(player_t));
    for j := 0 to Ord(NUMPSPRITES) - 1 do
      if boolval(dest.psprites[j].state) then
        dest.psprites[j].state := Pstate_t(pOperation(dest.psprites[j].state, @states[0], '-', SizeOf(dest.psprites[j].state^)));
  end;
end;

//
// P_UnArchivePlayers
//
procedure P_UnArchivePlayers;
var
  i: integer;
  j: integer;
begin
  for i := 0 to MAXPLAYERS - 1 do
  begin
    if not playeringame[i] then
      continue;

    PADSAVEP;

    memcpy(@players[i], save_p, SizeOf(player_t));
    incp(pointer(save_p), SizeOf(player_t));

    // will be set when unarc thinker
    players[i].mo := nil;
    players[i]._message := '';
    players[i].attacker := nil;

    for j := 0 to Ord(NUMPSPRITES) - 1 do
      if boolval(players[i].psprites[j].state) then
        players[i].psprites[j].state := @states[integer(players[i].psprites[j].state)];
  end;
end;

//
// P_ArchiveWorld
//
procedure P_ArchiveWorld;
var
  i: integer;
  j: integer;
  sec: Psector_t;
  li: Pline_t;
  si: Pside_t;
  put: PSmallIntArray;
begin
  put := PSmallIntArray(save_p);

  // do sectors
  i := 0;
  while i < numsectors do
  begin
    sec := Psector_t(@sectors[i]);
	  put[0] := sec.floorheight div FRACUNIT;
    incp(pointer(put), SizeOf(SmallInt));
    put[0] := sec.ceilingheight div FRACUNIT;
    incp(pointer(put), SizeOf(SmallInt));
    put[0] := sec.floorpic;
    incp(pointer(put), SizeOf(SmallInt));
    put[0] := sec.ceilingpic;
    incp(pointer(put), SizeOf(SmallInt));
    put[0] := sec.lightlevel;
    incp(pointer(put), SizeOf(SmallInt));
    put[0] := sec.special; // needed?
    incp(pointer(put), SizeOf(SmallInt));
    put[0] := sec.tag;  // needed?
    incp(pointer(put), SizeOf(SmallInt));
    inc(i);
  end;

  // do lines
  i := 0;
  while i < numlines do
  begin
    li := Pline_t(@lines[i]);
    put[0] := li.flags;
    incp(pointer(put), SizeOf(SmallInt));
    put[0] := li.special;
    incp(pointer(put), SizeOf(SmallInt));
    put[0] := li.tag;
    incp(pointer(put), SizeOf(SmallInt));
    for j := 0 to 1 do
    begin
      if li.sidenum[j] = -1 then
        continue;

      si := @sides[li.sidenum[j]];

      put[0] := si.textureoffset div FRACUNIT;
      incp(pointer(put), SizeOf(SmallInt));
      put[0] := si.rowoffset div FRACUNIT;;
      incp(pointer(put), SizeOf(SmallInt));
      put[0] := si.toptexture;
      incp(pointer(put), SizeOf(SmallInt));
      put[0] := si.bottomtexture;
      incp(pointer(put), SizeOf(SmallInt));
      put[0] := si.midtexture;
      incp(pointer(put), SizeOf(SmallInt));
    end;
    inc(i);
  end;

  save_p := PByteArray(put);
end;

//
// P_UnArchiveWorld
//
procedure P_UnArchiveWorld;
var
  i: integer;
  j: integer;
  sec: Psector_t;
  li: Pline_t;
  si: Pside_t;
  get: PSmallIntArray;
begin
  get := PSmallIntArray(save_p);

  // do sectors
  i := 0;
  while i < numsectors do
  begin
    sec := Psector_t(@sectors[i]);
    sec.floorheight := get[0] * FRACUNIT;
    incp(pointer(get), SizeOf(SmallInt));
    sec.ceilingheight := get[0] * FRACUNIT;
    incp(pointer(get), SizeOf(SmallInt));
    sec.floorpic := get[0];
    incp(pointer(get), SizeOf(SmallInt));
    sec.ceilingpic := get[0];
    incp(pointer(get), SizeOf(SmallInt));
    sec.lightlevel := get[0];
    incp(pointer(get), SizeOf(SmallInt));
    sec.special := get[0]; // needed?
    incp(pointer(get), SizeOf(SmallInt));
    sec.tag := get[0]; // needed?
    incp(pointer(get), SizeOf(SmallInt));
    sec.specialdata := nil;
    sec.soundtarget := nil;
    inc(i);
  end;

  // do lines
  i := 0;
  while i < numlines do
  begin
    li := Pline_t(@lines[i]);
    li.flags := get[0];
    incp(pointer(get), SizeOf(SmallInt));
    li.special := get[0];
    incp(pointer(get), SizeOf(SmallInt));
    li.tag := get[0];
    incp(pointer(get), SizeOf(SmallInt));
    for j := 0 to 1 do
    begin
      if li.sidenum[j] = -1 then
        continue;
      si := @sides[li.sidenum[j]];
      si.textureoffset := get[0] * FRACUNIT;
      incp(pointer(get), SizeOf(SmallInt));
      si.rowoffset := get[0] * FRACUNIT;
      incp(pointer(get), SizeOf(SmallInt));
      si.toptexture := get[0];
      incp(pointer(get), SizeOf(SmallInt));
      si.bottomtexture := get[0];
      incp(pointer(get), SizeOf(SmallInt));
      si.midtexture := get[0];
      incp(pointer(get), SizeOf(SmallInt));
    end;
    inc(i);
  end;
  save_p := PByteArray(get);
end;

//
// Thinkers
//
type
  thinkerclass_t = (tc_end, tc_mobj);

//
// P_ArchiveThinkers
//
procedure P_ArchiveThinkers;
var
  th: Pthinker_t;
  mobj: Pmobj_t;
begin
  // save off the current thinkers
  th := thinkercap.next;
  while th <> @thinkercap do
  begin
    if @th._function.acp1 = @P_MobjThinker then
    begin
      save_p[0] := Ord(tc_mobj);
      incp(pointer(save_p));
	    PADSAVEP;
      mobj := Pmobj_t(save_p);
	    memcpy(mobj, th, SizeOf(mobj^));
      incp(pointer(save_p), SizeOf(mobj^));
      mobj.state := Pstate_t(pOperation(mobj.state, @states[0], '-', SizeOf(mobj.state^)));

      if boolval(mobj.player) then
        mobj.player := Pplayer_t(pOperation(mobj.player, @players[0], '-', SizeOf(players[0])) + 1);
    end;
	// I_Error ("P_ArchiveThinkers: Unknown thinker function");
    th := th.next;
  end;

  // add a terminating marker
  save_p[0] := Ord(tc_end);
  incp(pointer(save_p));
end;


// P_UnArchiveThinkers
//
procedure P_UnArchiveThinkers;
var
  tclass: byte;
  currentthinker: Pthinker_t;
  next: Pthinker_t;
  mobj: Pmobj_t;
begin
  // remove all the current thinkers
  currentthinker := thinkercap.next;
  while currentthinker <> @thinkercap do
  begin
    next := currentthinker.next;

    if @currentthinker._function.acp1 = @P_MobjThinker then
      P_RemoveMobj(Pmobj_t(currentthinker))
    else
      Z_Free(currentthinker);

    currentthinker := next;
  end;
  P_InitThinkers;

  // read in saved thinkers
  while true do
  begin
    tclass := save_p[0];
    incp(pointer(save_p));
    case tclass of
      Ord(tc_end):
        exit; // end of list

      Ord(tc_mobj):
        begin
          PADSAVEP;
          mobj := Z_Malloc(SizeOf(mobj^), PU_LEVEL, nil);
          memcpy(mobj, save_p, SizeOf(mobj^));
          incp(pointer(save_p), SizeOf(mobj^));
          mobj.state := @states[integer(mobj.state)];
          mobj.target := nil;
          if boolval(mobj.player) then
          begin
            mobj.player := @players[integer(mobj.player) - 1];

            Pplayer_t(mobj.player).mo := mobj;
          end;
          P_SetThingPosition(mobj);
          mobj.info := @mobjinfo[Ord(mobj._type)];
          mobj.floorz := Psubsector_t(mobj.subsector).sector.floorheight;
          mobj.ceilingz := Psubsector_t(mobj.subsector).sector.ceilingheight;
          @mobj.thinker._function.acp1 := @P_MobjThinker;
          P_AddThinker(@mobj.thinker);
        end;
      else
        I_Error('P_UnArchiveThinkers(): Unknown tclass %d in savegame', [tclass]);
    end;
  end;
end;

//
// P_ArchiveSpecials
//
type
  specials_e = (
    tc_ceiling,
    tc_door,
    tc_floor,
    tc_plat,
    tc_flash,
    tc_strobe,
    tc_glow,
    tc_endspecials
  );



//
// Things to handle:
//
// T_MoveCeiling, (ceiling_t: sector_t * swizzle), - active list
// T_VerticalDoor, (vldoor_t: sector_t * swizzle),
// T_MoveFloor, (floormove_t: sector_t * swizzle),
// T_LightFlash, (lightflash_t: sector_t * swizzle),
// T_StrobeFlash, (strobe_t: sector_t *),
// T_Glow, (glow_t: sector_t *),
// T_PlatRaise, (plat_t: sector_t *), - active list
//
procedure P_ArchiveSpecials;
var
  th: Pthinker_t;
  th1: Pthinker_t;
  ceiling: Pceiling_t;
  door: Pvldoor_t;
  floor: Pfloormove_t;
  plat: Pplat_t;
  flash: Plightflash_t;
  strobe: Pstrobe_t;
  glow: Pglow_t;
  i: integer;
begin
  // save off the current thinkers
  th1 := thinkercap.next;
  while th1 <> @thinkercap do
  begin
    th := th1;
    th1 := th1.next;
    if not Assigned(th._function.acv) then
    begin
      i := 0;
      while i < MAXCEILINGS do
      begin
        if activeceilings[i] = Pceiling_t(th) then
          break;
        inc(i);
      end;

	    if i < MAXCEILINGS then
      begin
        save_p[0] := Ord(tc_ceiling);
        incp(pointer(save_p));
        PADSAVEP;
        ceiling := Pceiling_t(save_p);
        memcpy(ceiling, th, SizeOf(ceiling^));
        incp(pointer(save_p), SizeOf(ceiling^));
        ceiling.sector := Psector_t(pOperation(ceiling.sector, @sectors[0], '-', SizeOf(sectors[0])));
      end;
      continue;
    end;

    if @th._function.acp1 = @T_MoveCeiling then
    begin
      save_p[0] := Ord(tc_ceiling);
      incp(pointer(save_p));
      PADSAVEP;
      ceiling := Pceiling_t(save_p);
      memcpy(ceiling, th, SizeOf(ceiling^));
      incp(pointer(save_p), SizeOf(ceiling^));
      ceiling.sector := Psector_t(pOperation(ceiling.sector, @sectors[0], '-', SizeOf(sectors[0])));
      continue;
    end;

    if @th._function.acp1 = @T_VerticalDoor then
    begin
      save_p[0] := Ord(tc_door);
      incp(pointer(save_p));
      PADSAVEP;
      door := Pvldoor_t(save_p);
      memcpy(door, th, SizeOf(door^));
      incp(pointer(save_p), SizeOf(door^));
      door.sector := Psector_t(pOperation(door.sector, @sectors[0], '-', SizeOf(door.sector^)));
      continue;
    end;

    if @th._function.acp1 = @T_MoveFloor then
    begin
	    save_p[0] := Ord(tc_floor);
      incp(pointer(save_p));
      PADSAVEP;
      floor := Pfloormove_t(save_p);
      memcpy(floor, th, SizeOf(floor^));
      incp(pointer(save_p), SizeOf(floor^));
      floor.sector := Psector_t(pOperation(floor.sector, @sectors[0], '-', SizeOf(floor.sector^)));
      continue;
    end;

    if @th._function.acp1 = @T_PlatRaise then
    begin
      save_p[0] := Ord(tc_plat);
	    incp(pointer(save_p));
	    PADSAVEP;
	    plat := Pplat_t(save_p);
	    memcpy(plat, th, SizeOf(plat^));
	    incp(pointer(save_p), SizeOf(plat^));
	    plat.sector := Psector_t(pOperation(plat.sector, @sectors[0], '-', SizeOf(plat.sector^)));
	    continue;
    end;

    if @th._function.acp1 = @T_LightFlash then
    begin
      save_p[0] := Ord(tc_flash);
      incp(pointer(save_p));
      PADSAVEP;
      flash := Plightflash_t(save_p);
      memcpy(flash, th, SizeOf(flash^));
      incp(pointer(save_p), SizeOf(flash^));
      flash.sector := Psector_t(pOperation(flash.sector, @sectors[0], '-', SizeOf(flash.sector^)));
      continue;
    end;

    if @th._function.acp1 = @T_StrobeFlash then
    begin
      save_p[0] := Ord(tc_strobe);
      incp(pointer(save_p));
      PADSAVEP;
      strobe := Pstrobe_t(save_p);
      memcpy(strobe, th, SizeOf(strobe^));
      incp(pointer(save_p), SizeOf(strobe^));
      strobe.sector := Psector_t(POperation(strobe.sector, @sectors[0], '-', SizeOf(strobe.sector^)));
      continue;
    end;

    if @th._function.acp1 = @T_Glow then
    begin
      save_p[0] := Ord(tc_glow);
      incp(pointer(save_p));
      PADSAVEP;
      glow := Pglow_t(save_p);
      memcpy(glow, th, SizeOf(glow^));
      incp(pointer(save_p), SizeOf(glow^));
      glow.sector := Psector_t(pOperation(glow.sector, @sectors[0], '-', SizeOf(glow.sector^)));
      continue;
    end;
  end;

  // add a terminating marker
  save_p[0] := Ord(tc_endspecials);
  incp(pointer(save_p));
end;

//
// P_UnArchiveSpecials
//
procedure P_UnArchiveSpecials;
var
  tclass: byte;
  ceiling: Pceiling_t;
  door: Pvldoor_t;
  floor: Pfloormove_t;
  plat: Pplat_t;
  flash: Plightflash_t;
  strobe: Pstrobe_t;
  glow: Pglow_t;
begin
  // read in saved thinkers
  while true do
  begin
    tclass := save_p[0];
    incp(pointer(save_p));
    case tclass of
      Ord(tc_endspecials):
        exit; // end of list

      Ord(tc_ceiling):
        begin
          PADSAVEP;
          ceiling := Z_Malloc(SizeOf(ceiling^), PU_LEVEL, nil);
          memcpy(ceiling, save_p, SizeOf(ceiling^));
          incp(pointer(save_p), SizeOf(ceiling^));
          ceiling.sector := @sectors[integer(ceiling.sector)];
          ceiling.sector.specialdata := ceiling;

          if Assigned(ceiling.thinker._function.acp1) then // VJ works ???
            @ceiling.thinker._function.acp1 := @T_MoveCeiling;

          P_AddThinker(@ceiling.thinker);
          P_AddActiveCeiling(ceiling);
        end;

      Ord(tc_door):
        begin
          PADSAVEP;
          door := Z_Malloc(SizeOf(door^), PU_LEVEL, nil);
          memcpy(door, save_p, SizeOf(door^));
          incp(pointer(save_p), SizeOf(door^));
          door.sector := @sectors[integer(door.sector)];
          door.sector.specialdata := door;
          @door.thinker._function.acp1 := @T_VerticalDoor;
          P_AddThinker(@door.thinker);
        end;

      Ord(tc_floor):
        begin
          PADSAVEP;
          floor := Z_Malloc(SizeOf(floor^), PU_LEVEL, nil);
          memcpy(floor, save_p, SizeOf(floor^));
          incp(pointer(save_p), SizeOf(floor^));
          floor.sector := @sectors[integer(floor.sector)];
          floor.sector.specialdata := floor;
          @floor.thinker._function.acp1 := @T_MoveFloor;
          P_AddThinker(@floor.thinker);
        end;

      Ord(tc_plat):
        begin
          PADSAVEP;
          plat := Z_Malloc(SizeOf(plat^), PU_LEVEL, nil);
          memcpy(plat, save_p, SizeOf(plat^));
          incp(pointer(save_p), SizeOf(plat^));
          plat.sector := @sectors[integer(plat.sector)];
          plat.sector.specialdata := plat;

          if Assigned(plat.thinker._function.acp1) then  // VJ ??? from serialization
            @plat.thinker._function.acp1 := @T_PlatRaise;

          P_AddThinker(@plat.thinker);
          P_AddActivePlat(plat);
        end;

      Ord(tc_flash):
        begin
          PADSAVEP;
          flash := Z_Malloc(Sizeof(flash^), PU_LEVEL, nil);
          memcpy(flash, save_p, SizeOf(flash^));
          incp(pointer(save_p), SizeOf(flash^));
          flash.sector := @sectors[integer(flash.sector)];
          @flash.thinker._function.acp1 := @T_LightFlash;
          P_AddThinker(@flash.thinker);
        end;

      Ord(tc_strobe):
        begin
          PADSAVEP;
          strobe := Z_Malloc(SizeOf(strobe^), PU_LEVEL, nil);
          memcpy(strobe, save_p, SizeOf(strobe^));
          incp(pointer(save_p), SizeOf(strobe^));
          strobe.sector := @sectors[integer(strobe.sector)];
          @strobe.thinker._function.acp1 := @T_StrobeFlash;
          P_AddThinker(@strobe.thinker);
        end;

      Ord(tc_glow):
        begin
          PADSAVEP;
          glow := Z_Malloc(SizeOf(glow^), PU_LEVEL, nil);
          memcpy(glow, save_p, SizeOf(glow^));
          incp(pointer(save_p), SizeOf(glow^));
          glow.sector := @sectors[integer(glow.sector)];
          @glow.thinker._function.acp1 := @T_Glow;
          P_AddThinker(@glow.thinker);
        end;

      else
        I_Error('P_UnarchiveSpecials(): Unknown tclass %d in savegame', [tclass]);
    end;
  end;
end;

end.
