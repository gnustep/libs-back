/*
   XGSlideView

   Copyright (C) 2002 Free Software Foundation, Inc.

   Created by: Enrico Sersale <enrico@imago.ro>
   Date: Jan 2002

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include <AppKit/NSApplication.h>
#include <AppKit/NSCell.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSScreen.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>

#include "x11/XGServer.h"
#include "x11/XGServerWindow.h"
#include "x11/XGSlideView.h"
#include <math.h>
#include <X11/extensions/shape.h>

#define DWZ 48
#define ALPHA_THRESHOLD 158

#define XDPY [XGServer currentXDisplay]

#ifndef max
#define max(a,b) ((a) > (b) ? (a): (b))
#endif

#ifndef min
#define min(a,b) ((a) < (b) ? (a): (b))
#endif

#define DMAX 1800
#define MAXSTEPS 100

@interface XGSlideRawWindow : NSWindow
@end

@interface NSImage (BackEnd)
- (Pixmap) xPixmapMask;
@end

@interface XGSlideView (Private)
- (void) _setupWindow: (NSPoint)slideStart;
- (BOOL) _slideFrom: (NSPoint)fromPoint to: (NSPoint)toPoint;
@end

@implementation XGSlideView (Private)

- (void) _setupWindow: (NSPoint)slideStart
{
  NSSize imageSize = [[slideCell image] size];
  Pixmap pixmap = 0;

  [_window setFrame: NSMakeRect (slideStart.x, slideStart.y,
    imageSize.width, imageSize.height) display: NO];

  if ([[[slideCell image] backgroundColor] alphaComponent] * 256
    <= ALPHA_THRESHOLD)
    {
      [self lockFocus];
      pixmap = [[slideCell image] xPixmapMask];
      [self unlockFocus];
    }

  if (pixmap)
    {
      XShapeCombineMask(XDPY, slideWindev->ident, ShapeBounding, 0, 0,
	pixmap, ShapeSet);
      XFreePixmap(XDPY, pixmap);
    }
  else
    {
      XShapeCombineMask(XDPY, slideWindev->ident, ShapeBounding,
	0, 0, 0, ShapeSet);
    }

  [_window orderFrontRegardless];
}

- (BOOL) _slideFrom: (NSPoint)fromPoint to: (NSPoint)toPoint
{
  float sheight = [[NSScreen mainScreen] frame].size.height;
  float iheight = [[slideCell image] size].height;
  NSPoint fPoint = NSMakePoint(fromPoint.x, sheight - fromPoint.y - iheight);
  NSPoint tPoint = NSMakePoint(toPoint.x, sheight - toPoint.y - iheight);
  float distx = max(fPoint.x, tPoint.x) - min(fPoint.x, tPoint.x);
  float disty = max(fPoint.y, tPoint.y) - min(fPoint.y, tPoint.y);
  float dist = sqrt((distx * distx) + (disty * disty));
  float r = DMAX / dist;
  int steps = (int)(MAXSTEPS / r);
  float unitx = distx / steps;
  float unity = disty / steps;
  float xp = fPoint.x;
  float yp = fPoint.y;
  float *xpositions
    = NSZoneMalloc (NSDefaultMallocZone(), sizeof(float) * steps);
  float *ypositions
    = NSZoneMalloc (NSDefaultMallocZone(), sizeof(float) * steps);
  NSEvent *theEvent;
  int i;

  unitx = (tPoint.x > fPoint.x) ? unitx : -unitx;
  unity = (tPoint.y > fPoint.y) ? unity : -unity;

  for (i = 0; i < steps; i++)
    {
      xp += unitx;
      yp += unity;
      xpositions[i] = xp;
      ypositions[i] = yp;
    }

      XFlush(XDPY);
  [NSEvent startPeriodicEventsAfterDelay: 0.02 withPeriod: 0.02];
  for (i = 0; i < steps; i++)
    {
      theEvent = [NSApp nextEventMatchingMask: NSPeriodicMask
				    untilDate: [NSDate distantFuture]
				       inMode: NSEventTrackingRunLoopMode
				      dequeue: YES];
      XMoveWindow (XDPY, slideWindev->ident, xpositions[i], ypositions[i]);
    }
  [NSEvent stopPeriodicEvents];

  NSZoneFree (NSDefaultMallocZone(), xpositions);
  NSZoneFree (NSDefaultMallocZone(), ypositions);

  [[self window] orderOut: nil];

  return YES;
}

@end

@implementation XGSlideView

+ (BOOL) _slideImage: (NSImage *)image
	        from: (NSPoint)fromPoint
		  to: (NSPoint)toPoint
{
  static XGSlideView	*v = nil;
  BOOL			result = NO;

  if (image != nil)
    {
      if (v == nil)
	{
	  v = [[self alloc] init];
	}
      [NSApp preventWindowOrdering];
      [v->slideCell setImage: image];
      [v _setupWindow: fromPoint];
      result = [v _slideFrom: fromPoint to: toPoint];
    }
  return result;
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSRect		winRect = {{0, 0}, {DWZ, DWZ}};
      XGSlideRawWindow	*slideWindow = [XGSlideRawWindow alloc];

      slideCell = [[NSCell alloc] initImageCell: nil];
      [slideCell setBordered: NO];

      slideWindow = [slideWindow initWithContentRect: winRect
					   styleMask: NSBorderlessWindowMask
					     backing: NSBackingStoreNonretained
					       defer: NO];
      [slideWindow setContentView: self];
      RELEASE (self);

      slideWindev
	= [XGServer _windowWithTag: [slideWindow windowNumber]];
    }

  return self;
}

- (void) dealloc
{
  RELEASE (slideCell);
  [super dealloc];
}

- (void) drawRect: (NSRect)rect
{
  [slideCell drawWithFrame: rect inView: self];
}


@end

@implementation XGSlideRawWindow

- (BOOL) canBecomeMainWindow
{
  return NO;
}

- (BOOL) canBecomeKeyWindow
{
  return NO;
}

- (void) _initDefaults
{
  [super _initDefaults];
  [self setReleasedWhenClosed: YES];
  [self setExcludedFromWindowsMenu: YES];
}

@end
