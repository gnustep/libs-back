/* -*- mode:ObjC -*-
   HeadlessServer - X11 Server Class

   Copyright (C) 1998,2002,2023 Free Software Foundation, Inc.

   Re-written by: Gregory John Casamento <greg.casamento@gmail.com>
   Based on work by: Marcian Lytwyn <gnustep@advcsi.com> for Keysight
   Based on work Written by:  Adam Fedor <fedor@gnu.org>
   Date: Mar 2002, Aug 2023
   
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

#include "xheadless/HeadlessServer.h"
#include "xheadless/HeadlessInputServer.h"

extern int XGErrorHandler(Display *display, XErrorEvent *err);

@interface HeadlessServer (Window)
- (void) _setupRootWindow;
@end

@interface HeadlessServer (Private)
- (void) setupRunLoopInputSourcesForMode: (NSString*)mode; 
@end

@interface HeadlessScreenContext : NSObject
{
  RContext *rcontext;
  XGDrawMechanism drawMechanism;
}

- (instancetype) initForDisplay: (Display *)dpy screen: (int)screen_number;
- (XGDrawMechanism) drawMechanism;
- (RContext *) context;
@end

@implementation HeadlessScreenContext

- (RContextAttributes *) _getXDefaults
{
  return NULL;
}

- initForDisplay: (Display *)dpy screen: (int)screen_number
{
  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (XGDrawMechanism) drawMechanism
{
  return drawMechanism;
}

- (RContext *) context
{
  return rcontext;
}

@end


/**
   <unit>
   <heading>HeadlessServer</heading>

   <p> HeadlessServer is a concrete subclass of GSDisplayServer that handles
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

@implementation HeadlessServer 

/* Initialize AppKit backend */
+ (void) initializeBackend
{
  NSDebugLog(@"Initializing GNUstep x11 backend.\n");
  [GSDisplayServer setDefaultServerClass: [HeadlessServer class]];
  signal(SIGTERM, terminate);
  signal(SIGINT, terminate);
}

/**
   Returns a pointer to the current X-Windows display variable for
   the current context.
*/
+ (Display*) currentXDisplay
{
  return [(HeadlessServer*)GSCurrentServer() xDisplay];
}

- (id) _initXContext
{
  int screen_number = 0, display_number = 0;
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

  dpy = malloc(sizeof(Display)); //XOpenDisplay(NULL);

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

  [self _setupRootWindow];
  inputServer = nil;
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
  //XCloseDisplay(dpy);
  free(dpy);
  [super dealloc];
}

/**
  Returns a pointer to the X windows display variable
*/
- (Display *) xDisplay
{
  return dpy;
}

- (HeadlessScreenContext *) _screenContextForScreen: (int)screen_number
{
  return nil;
}

/**
   Returns a pointer to a structure which describes aspects of the
   X windows display 
*/
- (void *) xrContextForScreen: (int)screen_number
{
  return [[self _screenContextForScreen: screen_number] context];
}

- (Visual *) visualForScreen: (int)screen_number
{
    return NULL;
}

- (int) depthForScreen: (int)screen_number
{
    return 0;
}

/**
   Returns the XGDrawMechanism, which roughly describes the depth of
   the screen and how pixels should be drawn to the screen for maximum
   speed.
*/
- (XGDrawMechanism) drawMechanismForScreen: (int)screen_number
{
 return [[self _screenContextForScreen: screen_number] drawMechanism];
}

/**
 * Used by the art backend to determine the drawing mechanism.
 */
- (void) getForScreen: (int)screen_number pixelFormat: (int *)bpp_number 
                masks: (int *)red_mask : (int *)green_mask : (int *)blue_mask
{
}

/**
   Returns the root window of the display 
*/
- (Window) xDisplayRootWindowForScreen: (int)screen_number;
{
  return 0;
}

/**
   Returns the closest color in the current colormap to the indicated
   X color
*/
- (XColor) xColorFromColor: (XColor)color forScreen: (int)screen_number
{
  return color;
}

/**
   Returns the application root window, which is used for many things
   such as window hints 
*/
- (Window) xAppRootWindow
{
  return 0;
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
}

- glContextClass
{
  return nil;
}

- glPixelFormatClass
{
  return nil;
}


@end

@implementation HeadlessServer (InputMethod)
- (NSString *) inputMethodStyle
{
  return nil;
}

- (NSString *) fontSize: (int *)size
{
  return nil;
}

- (BOOL) clientWindowRect: (NSRect *)rect
{
  return NO;
}

- (BOOL) statusArea: (NSRect *)rect
{
  return NO;
}

- (BOOL) preeditArea: (NSRect *)rect
{
  return NO;
}

- (BOOL) preeditSpot: (NSPoint *)p
{
  return NO;
}

- (BOOL) setStatusArea: (NSRect *)rect
{
  return NO;
}

- (BOOL) setPreeditArea: (NSRect *)rect
{
  return NO;
}

- (BOOL) setPreeditSpot: (NSPoint *)p
{
  return NO;
}

@end // XGServer (InputMethod)

//==== End: Additional Code for NSTextView ====================================
