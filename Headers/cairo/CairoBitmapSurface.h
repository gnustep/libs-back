/*
   Copyright (C) 2026 Free Software Foundation, Inc.

   Author: Todd White <todd.white@thalion.global>
   Date: August 2026

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#ifndef CairoBitmapSurface_h
#define CairoBitmapSurface_h

#include "cairo/CairoSurface.h"

@class NSBitmapImageRep;

/* A surface that draws into the bytes of an NSBitmapImageRep.  Cairo keeps
 * its own buffer, in its own pixel layout, and the drawing is written back to
 * the representation when the surface is flushed.
 */
@interface CairoBitmapSurface : CairoSurface
{
  NSBitmapImageRep *_rep;
}

/* Whether a representation is in a layout this surface can write back to. */
+ (BOOL) handlesBitmap: (NSBitmapImageRep *)rep;

@end

#endif
