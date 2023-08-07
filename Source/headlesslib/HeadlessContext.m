/*
   HeadlessContext.m

   Copyright (C) 2003 Free Software Foundation, Inc.

   August 31, 2003
   Written by Banlu Kemiyatorn <object at gmail dot com>

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
#include <AppKit/NSPrintInfo.h>
#include <AppKit/NSPrintOperation.h>

#include "headlesslib/HeadlessGState.h"
#include "headlesslib/HeadlessContext.h"
#include "headlesslib/HeadlessSurface.h"
#include "headlesslib/HeadlessFontInfo.h"
#include "headlesslib/HeadlessFontEnumerator.h"
#include "config.h"

#define CGSTATE ((HeadlessGState *)gstate)


#define _CAIRO_GSTATE_CLASSNAME HeadlessGState
#define _CAIRO_SURFACE_CLASSNAME HeadlessModernSurface
#include "headlesslib/HeadlessModernSurface.h"

@implementation HeadlessContext

+ (void) initializeBackend
{
  [NSGraphicsContext setDefaultContextClass: self];

  [GSFontEnumerator setDefaultClass: [HeadlessFontEnumerator class]];
  [GSFontInfo setDefaultClass: [HeadlessFontInfo class]];
}

+ (Class) GStateClass
{
  return [_CAIRO_GSTATE_CLASSNAME class];
}

+ (BOOL) handlesPS
{
  return YES;
}

- (BOOL) supportsDrawGState
{
  return YES;
}

- (id) initWithContextInfo: (NSDictionary *)info
{
  self = [super initWithContextInfo:info];
  if (self)
  {
    [self setImageInterpolation:NSImageInterpolationDefault];
  }
  return(self);
}

- (BOOL) isDrawingToScreen
{
  HeadlessSurface *surface = nil;
  [CGSTATE GSCurrentSurface: &surface : NULL : NULL];
  return [surface isDrawingToScreen];
}

- (void) flushGraphics
{
}


/* Private backend methods */
+ (void) handleExposeRect: (NSRect)rect forDriver: (void *)driver
{
}

#if BUILD_SERVER == SERVER_x11

#ifdef XSHM

+ (void) _gotShmCompletion: (Drawable)d
{
}

- (void) gotShmCompletion: (Drawable)d
{
}

#endif // XSHM

#endif // BUILD_SERVER = SERVER_x11

@end 

@implementation HeadlessContext (Ops) 

- (BOOL) isCompatibleBitmap: (NSBitmapImageRep*)bitmap
{
  NSString *colorSpaceName;

  if ([bitmap bitmapFormat] != 0)
    {
      return NO;
    }

  if ([bitmap isPlanar])
    {
      return NO;
    }

  if ([bitmap bitsPerSample] != 8)
    {
      return NO;
    }

  colorSpaceName = [bitmap colorSpaceName];
  if (![colorSpaceName isEqualToString: NSDeviceRGBColorSpace] &&
      ![colorSpaceName isEqualToString: NSCalibratedRGBColorSpace])
    {
      return NO;
    }
  else
    {
      return YES;
    }
}

- (void) GSCurrentDevice: (void **)device : (int *)x : (int *)y
{
  HeadlessSurface *surface;

  [CGSTATE GSCurrentSurface: &surface : x : y];
  if (device)
    {
      *device = surface->gsDevice;
    }
}

- (void) GSSetDevice: (void *)device : (int)x : (int)y
{
  HeadlessSurface *surface;

  surface = [[_CAIRO_SURFACE_CLASSNAME alloc] initWithDevice: device];

  [CGSTATE GSSetSurface: surface : x : y];
  [surface release];
}

- (void) beginPrologueBBox: (NSRect)boundingBox
              creationDate: (NSString*)dateCreated
                 createdBy: (NSString*)anApplication
                     fonts: (NSString*)fontNames
                   forWhom: (NSString*)user
                     pages: (int)numPages
                     title: (NSString*)aTitle
{
}

- (void) showPage
{
  [CGSTATE showPage];
}

@end

#undef _CAIRO_SURFACE_CLASSNAME
#undef _CAIRO_GSTATE_CLASSNAME

