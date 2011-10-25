/* -*- mode:ObjC -*-
   XGServer - X11 Server Class

   Copyright (C) 1998,2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Mar 2002
   
   This file is part of the GNU Objective C User Interface Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
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

#include <signal.h>
/* Terminate cleanly if we get a signal to do so */
static void
terminate(int sig)
{
  if (nil != NSApp)
    {
      [NSApp terminate: NSApp];
    }
  else
    {
      exit(1);
    }
}

#include "x11/XGServer.h"
#include "x11/XGInputServer.h"
#ifdef HAVE_GLX
#include "x11/XGOpenGL.h"
#endif 

#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysym.h>

extern int XGErrorHandler(Display *display, XErrorEvent *err);

static NSString *
_parse_display_name(NSString *name, int *dn, int *sn)
{
  int d, s;
  NSString *host;
  NSArray *a;

  host = @"";
  d = s = 0;
  a = [name componentsSeparatedByString: @":"];
  if (name == nil)
    {
      NSLog(@"X DISPLAY environment variable not set,"
            @" assuming local X server (DISPLAY=:0.0)");
    }
  else if ([name hasPrefix: @":"] == YES)
    {
      int bnum;
      bnum = sscanf([name cString], ":%d.%d", &d, &s);
      if (bnum == 1)
        s = 0;
      if (bnum < 1)
        d = 0;
    }  
  else if ([a count] != 2)
    {
      NSLog(@"X DISPLAY environment variable has bad format,"
            @" assuming local X server (DISPLAY=:0.0)");
    }
  else
    {
      int bnum;
      NSString *dnum;
      host = [a objectAtIndex: 0];
      dnum = [a lastObject];
      bnum = sscanf([dnum cString], "%d.%d", &d, &s);
      if (bnum == 1)
        s = 0;
      if (bnum < 1)
        d = 0;
    }
  if (dn)
    *dn = d;
  if (sn)
    *sn = s;
  return host;
}

@interface XGServer (Window)
- (void) _setupRootWindow;
@end

@interface XGServer (Private)
- (void) setupRunLoopInputSourcesForMode: (NSString*)mode; 
@end

/**
   <unit>
   <heading>XGServer</heading>

   <p> XGServer is a concrete subclass of GSDisplayServer that handles
   X-Window client communications. The class is broken into four sections.
   The main class handles setting up and closing down the display, as well
   as providing wrapper methods to access display and screen pointers. The
   WindowOps category handles window creating, display, movement, and
   other functions detailed in the GSDisplayServer(WindowOps) category.
   The EventOps category handles events received from X-Windows and the
   window manager. It implements the methods defined in the
   GSDisplayServer(EventOps) category. The last section 
   </unit>
*/
@implementation XGServer 

/* Initialize AppKit backend */
+ (void) initializeBackend
{
  NSDebugLog(@"Initializing GNUstep x11 backend.\n");
  [GSDisplayServer setDefaultServerClass: [XGServer class]];
  signal(SIGTERM, terminate);
  signal(SIGINT, terminate);
}

/**
   Returns a pointer to the current X-Windows display variable for
   the current context.
*/
+ (Display*) currentXDisplay
{
  return [(XGServer*)GSCurrentServer() xDisplay];
}

- (id) _initXContext
{
  int screen_number, display_number;
  NSString *display_name;

  display_name = [server_info objectForKey: GSDisplayName];
  if (display_name == nil)
    {
      NSString *host = [[NSUserDefaults standardUserDefaults]
                           stringForKey: @"NSHost"];
      NSString *dn = [server_info objectForKey: GSDisplayNumber];
      NSString *sn = [server_info objectForKey: GSScreenNumber];

      if (dn || sn)
        {
          if (dn == NULL)
            dn = @"0";
          if (sn == NULL)
            sn = @"0";
          if (host == nil)
            host = @"";
          display_name = [NSString stringWithFormat: @"%@:%@.%@", host, dn,sn];
        }
      else if ((host != nil) && ([host isEqual: @""] == NO))
        {
          /**
           * If the NSHost default told us to display somewhere, we need
           * to generate a display name for X from the host name and the
           * default display and screen numbers (zero).
           */
          display_name = [NSString stringWithFormat: @"%@:0.0", host];
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

  if (dpy == NULL)
    {
      char *dname = XDisplayName([display_name cString]);
      [NSException raise: NSWindowServerCommunicationException
                  format: @"Unable to connect to X Server `%s'", dname];
    }

  /* Parse display information */
  _parse_display_name(display_name, &display_number, &screen_number);
  NSDebugLog(@"Opened display %@, display %d screen %d", 
             display_name, display_number, screen_number);
  [server_info setObject: display_name forKey: GSDisplayName];
  [server_info setObject: [NSNumber numberWithInt: display_number]
                  forKey: GSDisplayNumber];
  [server_info setObject: [NSNumber numberWithInt: screen_number] 
                  forKey: GSScreenNumber];

  /* Setup screen*/
  if (screenList == NULL)
    screenList = NSCreateMapTable(NSIntMapKeyCallBacks,
                                 NSObjectMapValueCallBacks, 20);

  defScreen = screen_number;

  XSetErrorHandler(XGErrorHandler);

#ifdef HAVE_LIBXEXT
  {
    int xsync_evbase, xsync_errbase;
    int major, minor;
    if (XSyncQueryExtension(dpy, &xsync_evbase, &xsync_errbase))
      XSyncInitialize(dpy, &major, &minor);
  }
#endif

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
  [super initWithAttributes: info];
  [self _initXContext];

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
  NSFreeMapTable(screenList);
  XCloseDisplay(dpy);
  [super dealloc];
}

/**
  Returns a pointer to the X windows display variable
*/
- (Display *) xDisplay
{
  return dpy;
}

/**
   Returns the root window of the display 
*/
- (Window) xDisplayRootWindowForScreen: (int)screen_number;
{
  return RootWindow(dpy, screen_number);
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
  Wait for all contexts to finish processing. Only used with XDPS graphics.
*/
+ (void) waitAllContexts
{
  if ([[GSCurrentContext() class] 
        respondsToSelector: @selector(waitAllContexts)])
    [[GSCurrentContext() class] waitAllContexts];
}

- (void) beep
{
  XBell(dpy, 0);
}

- glContextClass
{
#ifdef HAVE_GLX
  return [XGGLContext class];
#else
  return nil;
#endif
}

- glPixelFormatClass
{
#ifdef HAVE_GLX
  return [XGGLPixelFormat class];
#else
  return nil;
#endif
}


@end

@implementation XGServer (InputMethod)
- (NSString *) inputMethodStyle
{
  return inputServer ? [(XIMInputServer *)inputServer inputMethodStyle]
    : (NSString*)nil;
}

- (NSString *) fontSize: (int *)size
{
  return inputServer ? [(XIMInputServer *)inputServer fontSize: size]
    : (NSString*)nil;
}

- (BOOL) clientWindowRect: (NSRect *)rect
{
  return inputServer
    ? [(XIMInputServer *)inputServer clientWindowRect: rect] : NO;
}

- (BOOL) statusArea: (NSRect *)rect
{
  return inputServer ? [(XIMInputServer *)inputServer statusArea: rect] : NO;
}

- (BOOL) preeditArea: (NSRect *)rect
{
  return inputServer ? [(XIMInputServer *)inputServer preeditArea: rect] : NO;
}

- (BOOL) preeditSpot: (NSPoint *)p
{
  return inputServer ? [(XIMInputServer *)inputServer preeditSpot: p] : NO;
}

- (BOOL) setStatusArea: (NSRect *)rect
{
  return inputServer
    ? [(XIMInputServer *)inputServer setStatusArea: rect] : NO;
}

- (BOOL) setPreeditArea: (NSRect *)rect
{
  return inputServer
    ? [(XIMInputServer *)inputServer setPreeditArea: rect] : NO;
}

- (BOOL) setPreeditSpot: (NSPoint *)p
{
  return inputServer
    ? [(XIMInputServer *)inputServer setPreeditSpot: p] : NO;
}

@end // XGServer (InputMethod)


//==== Additional code for NSTextView =========================================
//
//  WARNING  This section is not genuine part of the XGServer implementation.
//  -------
//
//  The methods implemented in this section override some of the internal
//  methods defined in NSTextView so that the class can support input methods
//  (XIM) in cooperation with XGServer.
//
//  Note that the orverriding is done by defining the methods in a category,
//  the name of which is not explicitly mentioned in NSTextView.h; the
//  category is called 'InputMethod'.
//

#include <AppKit/NSClipView.h>
#include <AppKit/NSTextView.h>

@implementation NSTextView (InputMethod)

- (void) _updateInputMethodState
{
  NSRect frame;
  int font_size;
  NSRect status_area;
  NSRect preedit_area;
  id displayServer = (XGServer *)GSCurrentServer();

  if (![displayServer respondsToSelector: @selector(inputMethodStyle)])
    return;

  if (![displayServer fontSize: &font_size])
    return;

  if ([[self superview] isKindOfClass: [NSClipView class]])
    frame = [[self superview] frame];
  else
    frame = [self frame];

  status_area.size.width  = 2 * font_size;
  status_area.size.height = font_size + 2;
  status_area.origin.x    = 0;
  status_area.origin.y    = frame.size.height - status_area.size.height;

  if ([[displayServer inputMethodStyle] isEqual: @"OverTheSpot"])
    {
      preedit_area.origin.x    = 0;
      preedit_area.origin.y    = 0;
      preedit_area.size.width  = frame.size.width;
      preedit_area.size.height = status_area.size.height;

      [displayServer setStatusArea: &status_area];
      [displayServer setPreeditArea: &preedit_area];
    }
  else if ([[displayServer inputMethodStyle] isEqual: @"OffTheSpot"])
    {
      preedit_area.origin.x    = status_area.size.width + 2;
      preedit_area.origin.y    = status_area.origin.y;
      preedit_area.size.width  = frame.origin.x + frame.size.width
        - preedit_area.origin.x;
      preedit_area.size.height = status_area.size.height;

      [displayServer setStatusArea: &status_area];
      [displayServer setPreeditArea: &preedit_area];
    }
  else
    {
      // Do nothing for the RootWindow style.
    }
}

- (void) _updateInputMethodWithInsertionPoint: (NSPoint)insertionPoint
{
  id displayServer = (XGServer *)GSCurrentServer();

  if (![displayServer respondsToSelector: @selector(inputMethodStyle)])
    return;

  if ([[displayServer inputMethodStyle] isEqual: @"OverTheSpot"])
    {
      id view;
      NSRect frame;
      NSPoint p;
      NSRect client_win_rect;
      NSPoint screenXY_of_frame;
      double x_offset;
      double y_offset;
      int font_size;
      NSRect doc_rect;
      NSRect doc_visible_rect;
      BOOL cond;
      float x = insertionPoint.x;
      float y = insertionPoint.y;

      [displayServer clientWindowRect: &client_win_rect];
      [displayServer fontSize: &font_size];

      cond = [[self superview] isKindOfClass: [NSClipView class]];
      if (cond)
        view = [self superview];
      else
        view = self;

      frame = [view frame];
      screenXY_of_frame = [[view window] convertBaseToScreen: frame.origin];

      // N.B. The window of NSTextView isn't necessarily the same as the input
      // method's client window.
      x_offset = screenXY_of_frame.x - client_win_rect.origin.x; 
      y_offset = (client_win_rect.origin.y + client_win_rect.size.height)
        - (screenXY_of_frame.y + frame.size.height) + font_size;

      x += x_offset;
      y += y_offset;
      if (cond) // If 'view' is of NSClipView, then
        {
          // N.B. Remember, (x, y) are the values with respect to NSTextView.
          // We need to know the corresponding insertion position with respect
          // to NSClipView.
          doc_rect = [(NSClipView *)view documentRect];
          doc_visible_rect = [view documentVisibleRect];
          y -= doc_visible_rect.origin.y - doc_rect.origin.y;
        }

      p = NSMakePoint(x, y);
      [displayServer setPreeditSpot: &p];
    }
}

@end // NSTextView
//==== End: Additional Code for NSTextView ====================================
