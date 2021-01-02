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

unit p_telept;

interface

uses p_local,
  p_mobj_h,
  r_defs;

{
    p_telept.c
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
// $Log:$
//
// DESCRIPTION:
//	Teleportation.
//
//-----------------------------------------------------------------------------


//
// TELEPORTATION
//
function EV_Teleport(line: Pline_t; side: integer; thing: Pmobj_t): integer;

implementation

uses d_delphi,
  doomdef,
  d_think, d_player,
  info_h,
  m_fixed,
  p_setup, p_tick, p_mobj, p_map,
  s_sound, sounds,
  tables;

function EV_Teleport(line: Pline_t; side: integer; thing: Pmobj_t): integer;
var
  i: integer;
  tag: integer;
  m: Pmobj_t;
  fog: Pmobj_t;
  an: LongWord;
  thinker: Pthinker_t;
  sector: Psector_t;
  oldx: fixed_t;
  oldy: fixed_t;
  oldz: fixed_t;
begin
  // don't teleport missiles
  if boolval(thing.flags and MF_MISSILE) then
  begin
    result := 0;
    exit;
  end;

  // Don't teleport if hit back of line,
  //  so you can get out of teleporter.
  if side = 1 then
  begin
    result := 0;
    exit;
  end;

  tag := line.tag;
  for i := 0 to numsectors - 1 do
  begin
    if sectors[i].tag = tag then
    begin
      thinker := thinkercap.next;
      while thinker <> @thinkercap do
      begin
        // not a mobj
        if @thinker._function.acp1 <> @P_MobjThinker then
        begin
          thinker := thinker.next;
          continue;
        end;

        m := Pmobj_t(thinker);

        // not a teleportman
        if m._type <> MT_TELEPORTMAN then
        begin
          thinker := thinker.next;
          continue;
        end;

        sector := Psubsector_t(m.subsector).sector;
        // wrong sector
        if sector <> @sectors[i] then // VJ (was (sector-sectors != i ))
        begin
          thinker := thinker.next;
          continue;
        end;

        oldx := thing.x;
        oldy := thing.y;
        oldz := thing.z;

        if not P_TeleportMove(thing, m.x, m.y) then
        begin
          result := 0;
          exit;
        end;

        thing.z := thing.floorz;  //fixme: not needed?
        if boolval(thing.player) then
          Pplayer_t(thing.player).viewz := thing.z + Pplayer_t(thing.player).viewheight;

        // spawn teleport fog at source and destination
        fog := P_SpawnMobj(oldx, oldy, oldz, MT_TFOG);
        S_StartSound (fog, Ord(sfx_telept));
        an := _SHRW(m.angle, ANGLETOFINESHIFT);
        fog := P_SpawnMobj(m.x + 20 * finecosine[an],
                           m.y + 20 * finesine[an],
                           thing.z, MT_TFOG);

        // emit sound, where?
        S_StartSound (fog, Ord(sfx_telept));

        // don't move for a bit
        if boolval(thing.player) then
          thing.reactiontime := 18;

        thing.angle := m.angle;
        thing.momx := 0;
        thing.momy := 0;
        thing.momz := 0;
        result := 1;
        exit;
      end;
    end;
  end;
  result := 0;
end;

end.
 
