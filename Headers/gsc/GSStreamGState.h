/* GSGStreamState - Implements graphic state drawing for PS stream

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by: Adam Fedor <fedor@gnu.org>
   Date: Sep 2002
   
   This file is part of the GNU Objective C User Interface Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#ifndef _GSStreamGState_h_INCLUDE
#define _GSStreamGState_h_INCLUDE

#include <gsc/GSGState.h>

@interface GSStreamGState : GSGState
{
@public
  int clinecap, clinejoin;
  float clinewidth, cmiterlimit;
  float cstrokeadjust;
}

@end

#endif /* _GSStreamGState_h_INCLUDE */

