/* -*- mode:ObjC -*-
   XGContext - Drawing context using the Xlib Library.

   Copyright (C) 1998,1999,2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Nov 1998
   
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

#include "config.h"
#include <AppKit/AppKitExceptions.h>
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSDebug.h>

#include "x11/XGServer.h"
#include "xlib/XGContext.h"
#include "xlib/XGPrivate.h"
#include "xlib/XGGState.h"

#ifdef HAVE_XFT
#include "xlib/GSXftFontInfo.h"
#endif

#include "xlib/XGFontSetFontInfo.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

/**
   <unit>
   <heading>XGContext</heading>
   <p>
   The documentation below mostly describes methods that are specific to 
   this backend and wouldn't necessarily be used in other backends. The methods
   that this class does implement that would need to be in every backend are
   the methods of its NSGraphicContext superclass. See the documentation
   for NSGraphicContext for more information.
   </p>
   </unit>
*/
@implementation XGContext 

/* Initialize AppKit backend */
+ (void)initializeBackend
{
  Class fontClass = Nil;
  Class fontEnumerator = Nil;
  BOOL  enableFontSet;

  NSDebugLog(@"Initializing GNUstep xlib backend.\n");

  [NSGraphicsContext setDefaultContextClass: [XGContext class]];

#ifdef HAVE_XFT
  if ([[NSUserDefaults standardUserDefaults] boolForKey: @"GSFontAntiAlias"])
    {
      fontClass = [GSXftFontInfo class];
#ifdef HAVE_FC
      fontEnumerator = [FcFontEnumerator class];      
#endif
    }
#endif
  enableFontSet = [[NSUserDefaults standardUserDefaults] boolForKey:
							   @"GSXEnableFontSet"];
  if (fontClass == Nil)
    {
      if (enableFontSet == NO)
	{
	  fontClass = [XGFontInfo class];
	}
      else
	{
#ifdef X_HAVE_UTF8_STRING
	  fontClass = [XGFontSetFontInfo class];
#else
	  NSLog(@"Can't use GSXEnableFontSet: You need XFree86 >= 4.0.2");
	  fontClass = [XGFontInfo class];
#endif
	}
    }
  [GSFontInfo setDefaultClass: fontClass];

  if (fontEnumerator == Nil)
    {
      if (enableFontSet == NO)
	{
	  fontEnumerator = [XGFontEnumerator class];
	}
      else
	{
#ifdef X_HAVE_UTF8_STRING
	  // Commented out till the implementation of XGFontSetEnumerator
	  // completes.
	  //fontEnumerator = [XGFontSetEnumerator class];
	  fontEnumerator = [XGFontEnumerator class];
#else
	  fontEnumerator = [XGFontEnumerator class];
#endif
	}
    }
  [GSFontEnumerator setDefaultClass: fontEnumerator];
}

- (id) initWithContextInfo: (NSDictionary *)info
{
  NSString *contextType;
  contextType = [info objectForKey: 
		  NSGraphicsContextRepresentationFormatAttributeName];

  self = [super initWithContextInfo: info];
  if (contextType)
    {
      /* Most likely this is a PS or PDF context, so just return what
	 super gave us */
      return self;
    }

  /* Create a default gstate */
  gstate = [[XGGState allocWithZone: [self zone]] initWithDrawContext: self];

  return self;
}

- (void) flushGraphics
{
  XFlush([(XGServer *)server xDisplay]);
}

- (NSDictionary *) GSReadRect: (NSRect)rect
{
  return [(XGGState *)gstate GSReadRect: rect];
}

@end

@implementation XGContext (Ops)

/* ----------------------------------------------------------------------- */
/* Window system ops */
/* ----------------------------------------------------------------------- */
- (void) GSCurrentDevice: (void **)device : (int *)x : (int *)y
{
  void *windevice = [(XGGState *)gstate windevice];
  if (device)
    *device =  windevice;
  if (x && y)
    {
      NSPoint offset = [gstate offset];
      *x = offset.x;
      *y = offset.y;
    }
}

- (void) GSSetDevice: (void *)device : (int)x : (int)y
{
  [(XGGState *)gstate setWindowDevice: device];
  [gstate setOffset: NSMakePoint(x, y)];
}

@end
