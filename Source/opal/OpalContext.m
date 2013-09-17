/*
   OpalContext.m

   Copyright (C) 2013 Free Software Foundation, Inc.

   Author: Ivan Vucica <ivan@vucica.net>
   Date: June 2013

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

#import "opal/OpalContext.h"
#import "opal/OpalFontInfo.h"
#import "opal/OpalFontEnumerator.h"
#import "opal/OpalSurface.h"
#import "opal/OpalGState.h"

#define OGSTATE ((OpalGState *)gstate)

@implementation OpalContext

+ (void) initializeBackend
{
  [NSGraphicsContext setDefaultContextClass: self];

  [GSFontEnumerator setDefaultClass: [OpalFontEnumerator class]];
  [GSFontInfo setDefaultClass: [OpalFontInfo class]];
}

+ (Class) GStateClass
{
  return [OpalGState class];
}

- (void) GSSetDevice: (void *)device
                    : (int)x
                    : (int)y
{
  OpalSurface *surface;

  surface = [[OpalSurface alloc] initWithDevice: device];

  [OGSTATE GSSetSurface: surface
                       : x
                       : y];

  [surface release];
}

- (BOOL) isDrawingToScreen
{
  // NOTE: This was returning NO because it was not looking at the
  // return value of GSCurrentSurface. Now it returns YES, which
  // seems to have broken image drawing (yellow rectangles are drawn instead)
  OpalSurface *surface = [OGSTATE GSCurrentSurface: NULL : NULL : NULL];

  return [surface isDrawingToScreen];
}

- (void) DPSgsave
{
  [super DPSgsave];
  [OGSTATE DPSgsave];
}
- (void) DPSgrestore
{
  [super DPSgrestore];
  [OGSTATE DPSgrestore];
}

/*
// FIXME: we should add this as soon as we implement -drawGState:...
- (BOOL) supportsDrawGState
{
  return YES;
}
*/

/**
  This handles 'expose' event notifications that arrive from
  X11.
 */
+ (void) handleExposeRect: (NSRect)rect forDriver: (void *)driver
{
  if ([(id)driver isKindOfClass: [OpalSurface class]])
    {
      [(OpalSurface *)driver handleExposeRect: rect];
    }
}

- (void *) graphicsPort
{
  OpalSurface * surface;
  [OGSTATE GSCurrentSurface: &surface : NULL : NULL];
  return [surface cgContext];
}

#if BUILD_SERVER == SERVER_x11
#ifdef XSHM
+ (void) _gotShmCompletion: (Drawable)d
{
  [XWindowBuffer _gotShmCompletion: d];
}

- (void) gotShmCompletion: (Drawable)d
{
  [XWindowBuffer _gotShmCompletion: d];
}
#endif // XSHM
#endif // BUILD_SERVER = SERVER_x11

@end

