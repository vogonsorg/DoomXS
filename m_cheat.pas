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

unit m_cheat;

interface

{
    m_cheat.h, m_cheat.c
}

  { Emacs style mode select   -*- C++ -*-  }
  {----------------------------------------------------------------------------- }
  { }
  { $Id:$ }
  { }
  { Copyright (C) 1993-1996 by id Software, Inc. }
  { }
  { This source is available for distribution and/or modification }
  { only under the terms of the DOOM Source Code License as }
  { published by id Software. All rights reserved. }
  { }
  { The source is distributed in the hope that it will be useful, }
  { but WITHOUT ANY WARRANTY; without even the implied warranty of }
  { FITNESS FOR A PARTICULAR PURPOSE. See the DOOM Source Code License }
  { for more details. }
  { }
  { DESCRIPTION: }
  {	Cheat code checking. }
  { }
  {----------------------------------------------------------------------------- }

  { }
  { CHEAT SEQUENCE PACKAGE }
  { }

type
  cheatseq_t = record
    sequence: string;
    p: string;
  end;
  Pcheatseq_t = ^cheatseq_t;

function cht_CheckCheat(cht: Pcheatseq_t; key: char): boolean;

procedure cht_GetParam(cht: Pcheatseq_t; var buffer: string);

function get_cheatseq_string(const A: array of char): string; overload; // VJ

function get_cheatseq_string(const A: string): string; overload; // VJ

function get_cheatseq_string(const x: integer): string; overload; // VJ

implementation

uses d_delphi,
  i_system;

function get_cheatseq_string(const A: array of char): string; // VJ
var i: integer;
begin
  result := '';
  i := 0;
  repeat
    result := result + A[i];
    inc(i);
  until A[i] = Chr($FF);
end;

function get_cheatseq_string(const A: string): string;  // VJ
var i: integer;
begin
  result := '';
  i := 1;
  repeat
    result := result + A[i];
    inc(i);
  until A[i] = Chr($FF);
end;

function get_cheatseq_string(const x: integer): string; // VJ
begin
  result := '';
  if x <> 0 then
    I_Error('get_cheatseq_string(): invalid parameter: %d', [x]);
end;

function SCRAMBLE(a: integer): integer;
begin
  result := _SHL(a and 1, 7) +
            _SHL(a and 2, 5) +
            (a and 4) +
            _SHL(a and 8, 1) +
            _SHR(a and 16, 1) +
            (a and 32) +
            _SHR(a and 64, 5) +
            _SHR(a and 128, 7);
end;

var
  firsttime: boolean = true;
  cheat_xlate_table: array[0..255] of char;

//
// Called in st_stuff module, which handles the input.
// Returns a 1 if the cheat was successful, 0 if failed.
//
function cht_CheckCheat(cht: Pcheatseq_t; key: char): boolean;
var
  i: integer;
begin
  result := false;

  if firsttime then
  begin
    firsttime := false;
    for i := 0 to 255 do
      cheat_xlate_table[i] := Chr(SCRAMBLE(i));
  end;

  if (cht.p = '') then
    cht.p := cht.sequence; // initialize if first time

  if length(cht.p) = 0 then
    cht.p := key
  else if (cht.p[1] = #0) then
    cht.p[1] := key
  else if (length(cht.p) > 1) and (cht.p[2] = #0) then
  begin
    cht.p[2] := key;
    result := true;
  end
  else if cheat_xlate_table[Ord(key)] = cht.p[1] then
    Delete(cht.p, 1, 1)
  else
    cht.p := cht.sequence;

  if length(cht.p) > 0 then
  begin
    if cht.p[1] = #1 then
      Delete(cht.p, 1, 1)
    else if cht.p[1] = Chr($FF) then // end of sequence character
    begin
      cht.p := cht.sequence;
      result := true;
    end;
  end
  else
    result := true;
end;

procedure cht_GetParam(cht: Pcheatseq_t; var buffer: string);
begin
  buffer := cht.p;
end;

end.

