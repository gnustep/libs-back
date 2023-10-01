/*
   HeadlessFontInfo.m

   Copyright (C) 2003, 2023 Free Software Foundation, Inc.

   Based on work by: Marcian Lytwyn <gnustep@advcsi.com> for Keysight
   Based on work by: Banlu Kemiyatorn <object at gmail dot com>
   Based on work by: Alex Malmberg

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

#include "GNUstepBase/Unicode.h"
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include "headless/HeadlessFontInfo.h"
#include "headless/HeadlessFontEnumerator.h"

#include <math.h>

@implementation HeadlessFontInfo

- (id) initWithFontName: (NSString *)name
		 matrix: (const CGFloat *)fmatrix
	     screenFont: (BOOL)p_screenFont
{
  self = [super init];
  if (!self)
    return nil;

#ifndef _MSC_VER
  // Accessing instance variables across module boundaries is not supported by the Visual Studio
  // toolchain; this could be implemented using e.g. setFontName: and setMatrix: method on the
  // base case. 
  fontName = [name copy];
  memcpy(matrix, fmatrix, sizeof(matrix));
#endif

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (BOOL) glyphIsEncoded: (NSGlyph)glyph
{
  return NO;
}

- (NSSize) advancementForGlyph: (NSGlyph)glyph
{
  return NSZeroSize;
}

- (NSRect) boundingRectForGlyph: (NSGlyph)glyph
{
  return NSZeroRect;
}

- (CGFloat) widthOfString: (NSString *)string
{
  return 0.0;
}

- (void) appendBezierPathWithGlyphs: (NSGlyph *)glyphs
			      count: (int)length
		       toBezierPath: (NSBezierPath *)path
{
}

@end