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

unit d_textur;

interface

{
    d_textur.h
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
  {	Typedefs related to to textures etc., }
  {	 isolated here to make it easier separating modules. }
  {     }
  {----------------------------------------------------------------------------- }

//
// Flats?
//
// a pic is an unmasked block of pixels
type
  pic_t = record
    width : byte;
    height : byte;
    data : byte;
  end;
  Ppic_t = ^pic_t;

implementation

end.

