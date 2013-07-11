/*
   OpalGState.m

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

#import <CoreGraphics/CoreGraphics.h>
#import <X11/Xlib.h>
#import "opal/OpalGState.h"
#import "opal/OpalSurface.h"
#import "x11/XGServerWindow.h"

@implementation OpalGState

// MARK: Minimum required methods
// MARK: -

- (void) DPSinitclip
{

  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}

- (void) DPSclip
{

  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}

- (void) DPSfill
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  [_opalSurface dummyDraw];
}

- (void) DPSimage: (NSAffineTransform *)matrix
                 : (NSInteger)pixelsWide
		 : (NSInteger)pixelsHigh
                 : (NSInteger)bitsPerSample 
		 : (NSInteger)samplesPerPixel
                 : (NSInteger)bitsPerPixel
		 : (NSInteger)bytesPerRow
                 : (BOOL)isPlanar
		 : (BOOL)hasAlpha
                 : (NSString *)colorSpaceName
		 : (const unsigned char *const[5])data
{

  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}

- (void) compositeGState: (OpalGState *)source
                fromRect: (NSRect)srcRect 
                 toPoint: (NSPoint)destPoint 
                      op: (NSCompositingOperation)op
                fraction: (CGFloat)delta
{

  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}

- (void) compositerect: (NSRect)aRect
                    op: (NSCompositingOperation)op
{

  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}

@end

// MARK: Initialization methods
// MARK: -

@implementation OpalGState (InitializationMethods)

/* SOME NOTES:
   - GState approximates a cairo context: a drawing state.
   - Surface approximates a cairo surface: a place to draw things.

   - CGContext seems to be a mix of these two: surface + state.

   Should we unite these two somehow? Can we unite these two somehow?
   Possibly not. We still need to support bitmap contexts, pdf contexts
   etc which contain both state and contents.

   So, we will still need surfaces (containing CGContexts, hence including
   state) and GState as a wrapper around whatever context happens to be
   the current one.
 */

/**
  Makes the specified surface active in the current graphics state,
  ready for use in methods such as -DPSinitgraphics. Also, sets the
  device offset to specified coordinates.
 **/

- (void) GSSetSurface: (OpalSurface *)opalSurface
                     : (int)x
                     : (int)y
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  // FIXME: improper setter
  [_opalSurface release];
  _opalSurface = [opalSurface retain];

  // TODO: apply offset using [self setOffset:]

  [_opalSurface dummyDraw];

}

/**
  Sets up a new CG*Context() for drawing content.
  
  TODO: tell _opalSurface to create a new context
 **/
- (void) DPSinitgraphics
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);

  [super DPSinitgraphics];

  [_opalSurface dummyDraw];

}

@end

// MARK: Non-required unimplemented methods
// MARK: -

@implementation OpalGState (NonrequiredUnimplementedMethods)

/*
 Methods that follow have not been implemented.
 They are here to prevent GSGState implementations from
 executing.
 
 Sole criteria for picking them is looking at what methods
 are called by a dummy AppKit application with a single
 empty NSWindow.
 */

- (void) DPSsetlinewidth: (CGFloat) width
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void) setColor: (device_color_t *)color state: (color_state_t)cState
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void)DPSinitmatrix 
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void)DPSconcat: (const CGFloat *)m
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void) DPSsetalpha: (CGFloat)a
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void) DPSrectfill: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  [_opalSurface dummyDraw];
}
- (void) DPSrectclip: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void) DPSsetrgbcolor: (CGFloat)r : (CGFloat)g : (CGFloat)b
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void) GSSetCTM: (NSAffineTransform *)newctm
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void) DPSsetgray: (CGFloat)gray
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
/*
- (NSAffineTransform *) GSCurrentCTM
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
  return nil;
}
*/
- (void)DPSscale: (CGFloat)x : (CGFloat)y 
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}
- (void)DPStranslate: (CGFloat)x : (CGFloat)y 
{
  NSLog(@"%p (%@): %s", self, [self class], __PRETTY_FUNCTION__);
}

@end
