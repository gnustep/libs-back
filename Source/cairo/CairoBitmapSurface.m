/*
   CairoBitmapSurface.m

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

#include <AppKit/NSBitmapImageRep.h>
#include <AppKit/NSGraphics.h>

#include "cairo/CairoBitmapSurface.h"

#include <stdint.h>

/* Cairo holds a pixel as a native word with the alpha in the top byte; a
 * representation holds it as four bytes with the alpha last.
 */
static void
readRow(const unsigned char *from, uint32_t *to, int wide)
{
  int i;

  for (i = 0; i < wide; i++)
    {
      to[i] = ((uint32_t)from[3] << 24) | ((uint32_t)from[0] << 16)
	| ((uint32_t)from[1] << 8) | (uint32_t)from[2];
      from += 4;
    }
}

static void
writeRow(const uint32_t *from, unsigned char *to, int wide)
{
  int i;

  for (i = 0; i < wide; i++)
    {
      to[0] = (unsigned char)((from[i] >> 16) & 0xff);
      to[1] = (unsigned char)((from[i] >> 8) & 0xff);
      to[2] = (unsigned char)(from[i] & 0xff);
      to[3] = (unsigned char)((from[i] >> 24) & 0xff);
      to += 4;
    }
}

@implementation CairoBitmapSurface

+ (BOOL) handlesBitmap: (NSBitmapImageRep *)rep
{
  NSString *space;

  if (rep == nil || [rep isPlanar] || [rep bitmapFormat] != 0)
    {
      return NO;
    }
  if ([rep bitsPerSample] != 8 || [rep samplesPerPixel] != 4
    || ![rep hasAlpha] || [rep bitsPerPixel] != 32)
    {
      return NO;
    }
  space = [rep colorSpaceName];
  return ([space isEqualToString: NSDeviceRGBColorSpace]
    || [space isEqualToString: NSCalibratedRGBColorSpace]);
}

- (id) initWithDevice: (void *)device
{
  NSBitmapImageRep *rep = (NSBitmapImageRep *)device;

  if (![[self class] handlesBitmap: rep])
    {
      DESTROY(self);
      return self;
    }

  _surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32,
					(int)[rep pixelsWide],
					(int)[rep pixelsHigh]);
  if (cairo_surface_status(_surface) != CAIRO_STATUS_SUCCESS)
    {
      DESTROY(self);
      return self;
    }

  ASSIGN(_rep, rep);
  gsDevice = device;
  [self read];

  return self;
}

- (void) dealloc
{
  [self flush];
  DESTROY(_rep);
  [super dealloc];
}

- (NSSize) size
{
  return NSMakeSize([_rep pixelsWide], [_rep pixelsHigh]);
}

- (void) setSize: (NSSize)newSize
{
  /* The size is that of the representation, which does not change. */
}

- (BOOL) isDrawingToScreen
{
  return NO;
}

/* Take up what the representation already holds, so that drawing adds to it
 * rather than replacing it.
 */
- (void) read
{
  const unsigned char *from;
  unsigned char *to;
  int y;
  int wide;
  int high;
  int stride;

  to = cairo_image_surface_get_data(_surface);
  if (to == NULL)
    {
      return;
    }
  from = [_rep bitmapData];
  if (from == NULL)
    {
      return;
    }
  wide = (int)[_rep pixelsWide];
  high = (int)[_rep pixelsHigh];
  stride = cairo_image_surface_get_stride(_surface);
  cairo_surface_flush(_surface);
  for (y = 0; y < high; y++)
    {
      readRow(from + y * [_rep bytesPerRow], (uint32_t *)(to + y * stride),
	wide);
    }
  cairo_surface_mark_dirty(_surface);
}

- (void) flush
{
  const unsigned char *from;
  unsigned char *to;
  int y;
  int wide;
  int high;
  int stride;

  if (_surface == NULL || _rep == nil)
    {
      return;
    }
  cairo_surface_flush(_surface);
  from = cairo_image_surface_get_data(_surface);
  if (from == NULL)
    {
      return;
    }
  to = [_rep bitmapData];
  if (to == NULL)
    {
      return;
    }
  wide = (int)[_rep pixelsWide];
  high = (int)[_rep pixelsHigh];
  stride = cairo_image_surface_get_stride(_surface);
  for (y = 0; y < high; y++)
    {
      writeRow((const uint32_t *)(from + y * stride),
	to + y * [_rep bytesPerRow], wide);
    }
}

@end
