/*
   HeadlessFontInfo.m
 
   Copyright (C) 2003 Free Software Foundation, Inc.

   August 31, 2003
   Written by Banlu Kemiyatorn <object at gmail dot com>
   Base on original code of Alex Malmberg

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

#include "GNUstepBase/Unicode.h"
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include "headlesslib/HeadlessFontInfo.h"
#include "headlesslib/HeadlessFontEnumerator.h"

#include <math.h>

typedef void *cairo_t;

@implementation HeadlessFontInfo 

- (BOOL) setupAttributes
{
  return YES;
}

- (id) initWithFontName: (NSString *)name 
                 matrix: (const CGFloat *)fmatrix 
             screenFont: (BOOL)p_screenFont
{
  self = [super init];
  if (!self)
    return nil;

  fontName = [name copy];
  memcpy(matrix, fmatrix, sizeof(matrix));

  if (![self setupAttributes])
    {
      RELEASE(self);
      return nil;
    }

  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (BOOL) glyphIsEncoded: (NSGlyph)glyph
{
  /* FIXME: There is no proper way to determine with the toy font API,
     whether a glyph is supported or not. We will just ignore ligatures 
     and report all other glyph as existing.
  return !NSEqualSizes([self advancementForGlyph: glyph], NSZeroSize);
  */
  if ((glyph >= 0xFB00) && (glyph <= 0xFB05))
    return NO;
  else
    return YES;
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

- (void) drawGlyphs: (const NSGlyph*)glyphs
             length: (int)length 
                 on: (cairo_t*)ct
{
}

@end
