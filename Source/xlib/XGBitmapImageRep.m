/*
   XGBitmapImageRep.m

   NSBitmapImageRep for GNUstep GUI X/GPS Backend

   Copyright (C) 1996-1999 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@colorado.edu>
   Author:  Scott Christley <scottc@net-community.com>
   Date: Feb 1996
   Author:  Felipe A. Rodriguez <far@ix.netcom.com>
   Date: May 1998
   Author:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: Mar 1999
   Rewritten: Adam Fedor <fedor@gnu.org>
   Date: May 2000

   This file is part of the GNUstep GUI X/GPS Backend.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#include <config.h>
#include <stdlib.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>

#include "xlib/XGPrivate.h"
#include "x11/XGServerWindow.h"
#include <Foundation/NSData.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSUserDefaults.h>
#include <AppKit/NSBitmapImageRep.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>

@interface NSBitmapImageRep (BackEnd)
- (Pixmap) xPixmapMask;
@end


@implementation NSBitmapImageRep (Backend)

#ifdef WITH_WRASTER
+ (NSArray *) _wrasterFileTypes
{
  int i;
  NSMutableArray *warray;
  char **types = RSupportedFileFormats();
  
  i = 0;
  warray = [NSMutableArray arrayWithCapacity: 4];
  while (types[i] != NULL)
    {
      NSString *type = [NSString stringWithCString: types[i]];
      type = [type lowercaseString];
      if (strcmp(types[i], "TIFF") != 0)
	{
	  [warray addObject: type];
	  if (strcmp(types[i], "JPEG") == 0)
	    [warray addObject: @"jpg"];
	  else if (strcmp(types[i], "PPM") == 0)
	    [warray addObject: @"pgm"];
	}
      i++;
    }
  return warray;
}

- _initFromWrasterFile: (NSString *)filename number: (int)imageNumber
{
  RImage *image;
  RContext *context;

  if (imageNumber > 0)
    {
      /* RLoadImage doesn't handle this very well */
      RELEASE(self);
      return nil;
    }

  NSDebugLLog(@"NSImage", @"Loading %@ using wraster routines", filename);
  context = [(XGContext *)GSCurrentContext() xrContext];
  image = RLoadImage(context, (char *)[filename cString], imageNumber);
  if (!image)
    {
      RELEASE(self);
      return nil;
    }
  [self initWithBitmapDataPlanes: &(image->data)
		pixelsWide: image->width
		pixelsHigh: image->height
		bitsPerSample: 8
	        samplesPerPixel: (image->format == RRGBAFormat) ? 4 : 3
		hasAlpha: (image->format == RRGBAFormat) ? YES : NO
		isPlanar: NO
		colorSpaceName: NSDeviceRGBColorSpace
		bytesPerRow: 0
		bitsPerPixel: 0];

  /* Make NSBitmapImageRep own the data */
  _imageData = [NSMutableData dataWithBytesNoCopy: image->data
				    length: (_bytesPerRow*image->height)];
  RETAIN(_imageData);
  free(image);

  return self;
}
#endif /* WITH_WRASTER */

- (Pixmap) xPixmapMask
{
  unsigned char	*bData;
  XGContext	*ctxt = (XGContext*)GSCurrentContext();
  Display	*xDisplay = [ctxt xDisplay];
  Drawable	xDrawable;
  GC		gc;
  int           x, y;

  // Only produce pixmaps for meshed images with alpha
  if ((_numColors != 4) || _isPlanar)
    return 0;

  bData = [self bitmapData];

  [ctxt DPScurrentgcdrawable: (void**)&gc : (void**)&xDrawable : &x : &y];

  // FIXME: This optimistic computing works only, if there are no 
  // additional bytes at the end of a line.
  return  xgps_cursor_mask (xDisplay, xDrawable, bData, _pixelsWide, _pixelsHigh, _numColors);
}

@end


@implementation NSImage (Backend)

- (Pixmap) xPixmapMask
{
  NSArray *reps = [self representations];
  NSEnumerator *enumerator = [reps objectEnumerator];
  NSImageRep *rep;

  while ((rep = [enumerator nextObject]) != nil)
    {
      if ([rep isKindOfClass: [NSBitmapImageRep class]])
        {
	  return [(NSBitmapImageRep*)rep xPixmapMask];
	}
    }

  return 0;
}

@end
