/* _NET_WORKAREA reports the area a window manager leaves usable, in X
 * coordinates, where y grows downwards.  A screen frame is in OpenStep
 * coordinates, where y grows upwards, so the work area's origin is flipped
 * against the full screen height.
 *
 * A work area at the top of the screen and one at the bottom have the same
 * height and differ only in origin, so they give different screen frames.
 *
 * The property is read for a single monitor only, so the monitor count is
 * checked first and the test skips otherwise.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) && BUILD_SERVER == SERVER_x11

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdlib.h>

#define STRUT 40

/* Publish a work area reserving STRUT rows, at the top of the screen or at
 * the bottom, and answer the screen frame the backend then reports.
 */
static NSRect
frameForWorkAreaAtTop(GSDisplayServer *srv, Display *dpy, BOOL atTop)
{
  long		v[4];
  int		screen = DefaultScreen(dpy);
  int		height = DisplayHeight(dpy, screen);

  v[0] = 0;
  v[1] = atTop ? STRUT : 0;
  v[2] = DisplayWidth(dpy, screen);
  v[3] = height - STRUT;

  XChangeProperty(dpy, DefaultRootWindow(dpy),
    XInternAtom(dpy, "_NET_WORKAREA", False),
    XA_CARDINAL, 32, PropModeReplace, (unsigned char *)v, 4);
  XSync(dpy, False);

  [srv screenList];
  return [srv boundsForScreen: 0];
}

int
main(int argc, const char **argv)
{
  START_SET("work area origin")

  extern void	initialize_gnustep_backend(void);
  GSDisplayServer *srv = nil;
  Display	*dpy;
  NSRect	top;
  NSRect	bottom;
  int		height;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      SKIP("no window server available")
    }

  NS_DURING
    {
      initialize_gnustep_backend();
      srv = [GSDisplayServer serverWithAttributes: nil];
    }
  NS_HANDLER
    {
      NSLog(@"the display server did not start: %@", localException);
      SKIP("It looks like the GNUstep backend is not installed")
    }
  NS_ENDHANDLER

  if (srv == nil || [srv isMemberOfClass: [GSDisplayServer class]])
    {
      SKIP("no concrete display server")
    }
  [GSDisplayServer setCurrentServer: srv];
  dpy = (Display *)[srv serverDevice];

  if ([[srv screenList] count] != 1)
    {
      SKIP("the work area is only used for a single monitor")
    }

  height = DisplayHeight(dpy, DefaultScreen(dpy));
  bottom = frameForWorkAreaAtTop(srv, dpy, NO);
  top = frameForWorkAreaAtTop(srv, dpy, YES);

  PASS(top.size.height == height - STRUT
    && bottom.size.height == height - STRUT,
    "a work area shorter than the screen shortens the screen frame");

  PASS(top.origin.y == 0,
    "a panel at the top of the screen leaves the frame at the origin");

  PASS(bottom.origin.y == STRUT,
    "a panel at the bottom of the screen moves the frame up by its height");

  PASS(NSMinY(top) != NSMinY(bottom),
    "a panel at the top and one at the bottom give different screen frames");

  END_SET("work area origin")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("work area origin")
    SKIP("back is not built with the x11 server")
  END_SET("work area origin")
  return 0;
}

#endif
