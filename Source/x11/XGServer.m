/* -*- mode:ObjC -*-
   XGServer - X11 Server Class

   Copyright (C) 1998,2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Mar 2002
   
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
#include <AppKit/NSApplication.h>
#include <AppKit/NSView.h>
#include <AppKit/NSWindow.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSData.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSDebug.h>

#ifdef HAVE_WRASTER_H
#include "wraster.h"
#else
#include "x11/wraster.h"
#endif

#include "x11/XGServer.h"
#include "x11/XGInputServer.h"

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

extern int XGErrorHandler(Display *display, XErrorEvent *err);

@interface XGServer (Window)
- (void) _setupRootWindow;
@end

@interface XGServer (Private)
- (void) setupRunLoopInputSourcesForMode: (NSString*)mode; 
@end

#define XDPY (((RContext *)context)->dpy)
#define XSCR (((RContext *)context)->screen_number)

/**
   <unit>
   <heading>XGServer</heading>
   </unit>
*/
@implementation XGServer 

/* Initialize AppKit backend */
+ (void)initializeBackend
{
  NSDebugLog(@"Initializing GNUstep x11 backend.\n");
  [GSDisplayServer setDefaultServerClass: [XGServer class]];
}

/**
   Returns a pointer to the current X-Windows display variable for
   the current context.
*/
+ (Display*) currentXDisplay
{
  return [(XGServer*)GSCurrentServer() xDisplay];
}

- (RContextAttributes *) _getXDefaults
{
  int dummy;
  RContextAttributes *attribs;

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  attribs = (RContextAttributes *)malloc(sizeof(RContextAttributes));

  attribs->flags = 0;
  if ([defaults boolForKey: @"NSDefaultVisual"])
    attribs->flags |= RC_DefaultVisual;
  if ((dummy = [defaults integerForKey: @"NSDefaultVisual"]))
    {
      attribs->flags |= RC_VisualID;
      attribs->visualid = dummy;
    }
  if ((dummy = [defaults integerForKey: @"NSColorsPerChannel"]))
    {
      attribs->flags |= RC_ColorsPerChannel;
      attribs->colors_per_channel = dummy;
    }

  return attribs;
}

- _initXContext
{
  Display		*dpy;
  int			screen_number;
  NSString		*display_name;
  RContext		*rcontext;
  RContextAttributes	*attribs;
  XColor		testColor;
  unsigned char		r, g, b;
  
  display_name = [server_info objectForKey: @"DisplayName"];
  if (display_name == nil)
    {
      NSString	*host;
      NSString	*dnum = @"0.0";

      host = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSHost"];
      if (host == nil)
	{
	  NSString	*d = [[[NSProcessInfo processInfo] environment]
	    objectForKey: @"DISPLAY"];

	  if (d == nil)
	    {
	      host = @"";
	    }
	  else
	    {
	      if ([d hasPrefix: @":"] == YES)
		{
		  host = @"";	// local host
		}
	      else
		{
		  NSArray	*a = [d componentsSeparatedByString: @":"];

		  if ([a count] != 2)
		    {
		      NSLog(@"X DISPLAY environment variable has bad format"
			@" assuming local X server (DISPLAY=:0.0)");
		      host = @"";
		    }
		  else
		    {
		      host = [a objectAtIndex: 0];
		      dnum = [a lastObject];
		      if ([dnum isEqual: @"0"] == NO
			&& [dnum hasPrefix: @"0."] == NO)
			{
			  NSLog(@"Only one display per host fully supported.");
			}
		    }
		}
	      if ([host isEqual: @""] == NO)
		{
		  /**
		   * If we are using the DISPLAY environment variable to
		   * determine where to display, set the NSHost default
		   * so that other parts of the system know where we are
		   * displaying.
		   */
		  [[NSUserDefaults standardUserDefaults] registerDefaults:
		    [NSDictionary dictionaryWithObject: host
						forKey: @"NSHost"]];
		}
	    }
	}
      if ([host isEqual: @""] == NO)
	{
	  /**
	   * If the NSHost default told us to display somewhere, we need
	   * to generate a display name for X from the host name and the
	   * default display and screen numbers (zero).
	   */
	  display_name = [NSString stringWithFormat: @"%@:%@", host, dnum];
	}
    }

  if (display_name)
    {
      dpy = XOpenDisplay([display_name cString]);
    }
  else
    { 
      dpy = XOpenDisplay(NULL);
      display_name = [NSString stringWithCString: XDisplayName(NULL)];
    }

  /* Use the fact that the screen number is specified like an extension
     e.g. hostname:0.1 */
  screen_number = [[display_name pathExtension] intValue];

  if (dpy == NULL)
    {
      char *dname = XDisplayName([display_name cString]);
      [NSException raise: @"DPSconfigurationerror"
		  format: @"Unable to connect to X Server `%s'", dname];
    }
  else
    NSDebugLog(@"Opened display %@", display_name);

  /* Get the visual information */
  attribs = NULL;
  //attribs = [self _getXDefaults];
  rcontext = RCreateContext(dpy, screen_number, attribs);
  context  = (void *)rcontext;

  /*
   * If we have shared memory available, only use it when the XGPS-Shm
   * default is set to YES
   */
  if (rcontext->attribs->use_shared_memory == True
    && [[NSUserDefaults standardUserDefaults] boolForKey: @"XGPS-Shm"] != YES)
    rcontext->attribs->use_shared_memory = False;

  /*
   *	Crude tests to see if we can accelerate creation of pixels from
   *	8-bit red, green and blue color values.
   */
  if (rcontext->depth == 12 || rcontext->depth == 16)
    {
      drawMechanism = XGDM_FAST16;
      r = 8;
      g = 9;
      b = 7;
      testColor.pixel = (((r << 5) + g) << 6) + b;
      XQueryColor(rcontext->dpy, rcontext->cmap, &testColor);
      if (((testColor.red >> 11) != r)
	|| ((testColor.green >> 11) != g)
	|| ((testColor.blue >> 11) != b))
	{
	  NSLog(@"WARNING - XGServer is unable to use the "
	    @"fast algorithm for writing to a 16-bit display on "
	    @"this host - perhaps you'd like to adjust the code "
	    @"to work ... and submit a patch.");
	  drawMechanism = XGDM_PORTABLE;
	}
    }
  else if (rcontext->depth == 15)
    {
      drawMechanism = XGDM_FAST15;
      r = 8;
      g = 9;
      b = 7;
      testColor.pixel = (((r << 5) + g) << 5) + b;
      XQueryColor(rcontext->dpy, rcontext->cmap, &testColor);
      if (((testColor.red >> 11) != r)
	|| ((testColor.green >> 11) != g)
	|| ((testColor.blue >> 11) != b))
	{
	  NSLog(@"WARNING - XGServer is unable to use the "
	    @"fast algorithm for writing to a 15-bit display on "
	    @"this host - perhaps you'd like to adjust the code "
	    @"to work ... and submit a patch.");
	  drawMechanism = XGDM_PORTABLE;
	}
    }
  else if (rcontext->depth == 24 || rcontext->depth == 32)
    {
      drawMechanism = XGDM_FAST32;
      r = 32;
      g = 33;
      b = 31;
      testColor.pixel = (((r << 8) + g) << 8) + b;
      XQueryColor(rcontext->dpy, rcontext->cmap, &testColor);
      if (((testColor.red >> 8) == r)
        && ((testColor.green >> 8) == g)
        && ((testColor.blue >> 8) == b))
	{
	  drawMechanism = XGDM_FAST32;
	}
      else if (((testColor.red >> 8) == b)
	&& ((testColor.green >> 8) == g)
	&& ((testColor.blue >> 8) == r))
	{
	  drawMechanism = XGDM_FAST32_BGR;
	}
      else
	{
	  NSLog(@"WARNING - XGServer is unable to use the "
	    @"fast algorithm for writing to a 32-bit display on "
	    @"this host - perhaps you'd like to adjust the code "
	    @"to work ... and submit a patch.");
	  drawMechanism = XGDM_PORTABLE;
	}
    }
  else
    {
      NSLog(@"WARNING - XGServer is unable to use a "
	@"fast algorithm for writing to the display on "
	@"this host - perhaps you'd like to adjust the code "
	@"to work ... and submit a patch.");
      drawMechanism = XGDM_PORTABLE;
    }

  XSetErrorHandler(XGErrorHandler);

  if (GSDebugSet(@"XSynchronize") == YES)
    XSynchronize(dpy, True);

  [self _setupRootWindow];
  inputServer = [[XIMInputServer allocWithZone: [self zone]] 
		  initWithDelegate: nil display: dpy name: @"XIM"];
  return self;
}

/**
   Opens the X display (using a helper method) and sets up basic
   display mechanisms, such as visuals and colormaps.
*/
- (id) initWithAttributes: (NSDictionary *)info
{
  [self _initXContext];
  [super initWithAttributes: info];

  [self setupRunLoopInputSourcesForMode: NSDefaultRunLoopMode]; 
  [self setupRunLoopInputSourcesForMode: NSConnectionReplyMode]; 
  [self setupRunLoopInputSourcesForMode: NSModalPanelRunLoopMode]; 
  [self setupRunLoopInputSourcesForMode: NSEventTrackingRunLoopMode]; 
  return self;
}

/**
   Closes all X resources, the X display and dealloc other ivars.
*/
- (void) dealloc
{
  NSDebugLog(@"Destroying X11 Server");
  DESTROY(inputServer);
  [self _destroyServerWindows];
  XCloseDisplay(XDPY);
  [super dealloc];
}

/**
   Returns the XGDrawMechanism, which roughly describes the depth of
   the screen and how pixels should be drawn to the screen for maximum
   speed.
*/
- (XGDrawMechanism) drawMechanism
{
  return drawMechanism;
}

/**
   Returns a pointer to a structure which describes aspects of the
   X windows display 
*/
- (void *) xrContext
{
  return context;
}

/*
  Returns a pointer to the X windows display variable
*/
- (Display *) xDisplay
{
  return XDPY;
}

/**
   Returns the root window of the display 
*/
- (Window) xDisplayRootWindow
{
  return RootWindow(XDPY, XSCR);
}

/**
   Returns the application root window, which is used for many things
   such as window hints 
*/
- (Window) xAppRootWindow
{
  return generic.appRootWindow;
}

/**
   Returns the closest color in the current colormap to the indicated
   X color
*/
- (XColor)xColorFromColor: (XColor)color
{
  Status ret;
  RColor rcolor;
  Colormap colormap = XDefaultColormap(XDPY, XSCR);
  XAllocColor(XDPY, colormap, &color);
  rcolor.red   = color.red / 256;
  rcolor.green = color.green / 256;
  rcolor.blue  = color.blue / 256;
  ret = RGetClosestXColor((RContext *)context, &rcolor, &color);
  if (ret == False)
    NSLog(@"Failed to alloc color (%d,%d,%d)\n",
          (int)rcolor.red, (int)rcolor.green, (int)rcolor.blue);
  return color;
}

/**
  Wait for all contexts to finish processing. Only used with XDPS graphics.
*/
+ (void) waitAllContexts
{
  if ([[GSCurrentContext() class] 
	respondsToSelector: @selector(waitAllContexts)])
    [[GSCurrentContext() class] waitAllContexts];
}

@end
