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
#import "gsc/GSStreamContext.h"

#define OGSTATE self //((OpalGState *)gstate)

@implementation OpalContext

+ (void) initializeBackend
{
  NSDebugLLog(@"OpalContext", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  [NSGraphicsContext setDefaultContextClass: self];

  [GSFontEnumerator setDefaultClass: [OpalFontEnumerator class]];
  [GSFontInfo setDefaultClass: [OpalFontInfo class]];
}

- (id) initWithContextInfo: (NSDictionary *)info
{
  NSDebugLLog(@"OpalContext", @"%p (%@): %s - info %@", self, [self class], __PRETTY_FUNCTION__, info);
  NSString *contextType;
  NSZone   *z = [self zone];

  contextType = [info objectForKey:
                  NSGraphicsContextRepresentationFormatAttributeName];

  if (([object_getClass(self) handlesPS] == NO) && contextType
      && [contextType isEqual: NSGraphicsContextPSFormat])
    {
      /* Don't call self, since we aren't initialized */
      [super dealloc];
      return [[GSStreamContext allocWithZone: z] initWithContextInfo: info];
    }

  self = [super initWithContextInfo: info];
  if (!self)
    return nil;

  // Special handling for window drawing
  id dest;
  dest = [info objectForKey: NSGraphicsContextDestinationAttributeName];
  if ((dest != nil) && [dest isKindOfClass: [NSWindow class]])
    {
      /* A context is only associated with one server. Do not retain
         the server, however */
      _server = GSCurrentServer();
      [_server setWindowdevice: [(NSWindow*)dest windowNumber]
                    forContext: self];
    }

  if ([[info objectForKey: NSDeviceIsScreen] boolValue])
    {
      _isScreen = YES;
    }

  // TODO: we may want to create a default OpalSurface, in case GSSetDevice is not called

  [self DPSinitgraphics];
  [self DPSinitclip];

  return self;
}

+ (BOOL) handlesPS
{
  // TODO
  return NO;
}

- (void) GSSetDevice: (void *)device
                    : (int)x
                    : (int)y
{
  NSDebugLLog(@"OpalContext", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  OpalSurface *surface;

  surface = [[OpalSurface alloc] initWithDevice: device];

  [OGSTATE GSSetSurface: surface
                       : x
                       : y];

  [surface release];
}

- (BOOL) isDrawingToScreen
{
  if (_isScreen) // TODO: should not be needed
    return YES;

  OpalSurface *surface = nil;
  [OGSTATE GSCurrentSurface: &surface : NULL : NULL];
  return [surface isDrawingToScreen];
}

/**
  This handles 'expose' event notifications that arrive from
  X11.
 */
+ (void) handleExposeRect: (NSRect)rect forDriver: (void *)driver
{
  NSDebugLLog(@"OpalContext", @"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
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

@implementation OpalContext(GSCReplicas)
/* This section includes replicas of methods implemented in GSContext. */
- (NSInteger) GSDefineGState
{
  /* TODO: in GSContext this inserts a new graphics state on top of a stack. */
  return _backGStateStackHeight++;
}
- (void) GSUndefineGState: (NSInteger)gst
{
  /* TODO: in GSContext this pops a graphics state from the stack. 
     Sadly, it might also pop gstate from elsewhere on the stack. */
  if(_backGStateStackHeight-1 != gst)
    NSLog(@"%s: trying to pop something apart from the top of the gstate stack", __PRETTY_FUNCTION__);
  _backGStateStackHeight--;
}
- (void) GSReplaceGState: (NSInteger)gst
{
  /* In GSContext, this allows replacing a graphics state from a stack.
     We can't do this in Opal. */
  NSLog(@"Warning: App or library performed a call to %s.", 
        __PRETTY_FUNCTION__);
  if(_backGStateStackHeight-1 != gst)
    NSLog(@"%s: trying to replace gstate not on top of the stack", __PRETTY_FUNCTION__);
}

@end
