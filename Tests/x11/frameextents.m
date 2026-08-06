/* Window offsets have to survive a window manager that answers the
 * _NET_REQUEST_FRAME_EXTENTS message with four zeros and publishes the real
 * extents only once the window has been mapped.  Recent Mutter releases do
 * that, and taking the zeros leaves every decorated window style with no
 * decoration offset at all.
 *
 * The test forks a small window manager that behaves that way, so it needs no
 * window manager on the display it runs against.  The backend only probes for
 * offsets when a window manager is present, and reads the cached offsets from
 * the root window unless GSIgnoreRootOffsets is set, so both are arranged
 * before the display server is created.
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
#include <unistd.h>
#include <signal.h>

#define TOP 37          /* the height of the window manager's title bar */

/* Announce an EWMH window manager and answer requests the unusable way.
 * Runs in the child, which never returns.
 */
static void
runWindowManager(void)
{
  Display	*dpy;
  Window	root;
  Window	check;
  Atom		supported[4];
  Atom		netCheck;
  Atom		netName;
  Atom		netRequest;
  Atom		netExtents;
  long		zero[4];
  long		real[4];

  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      _exit(1);
    }
  root = DefaultRootWindow(dpy);
  netCheck = XInternAtom(dpy, "_NET_SUPPORTING_WM_CHECK", False);
  netName = XInternAtom(dpy, "_NET_WM_NAME", False);
  netRequest = XInternAtom(dpy, "_NET_REQUEST_FRAME_EXTENTS", False);
  netExtents = XInternAtom(dpy, "_NET_FRAME_EXTENTS", False);

  zero[0] = zero[1] = zero[2] = zero[3] = 0;
  real[0] = real[1] = real[3] = 0;
  real[2] = TOP;

  check = XCreateSimpleWindow(dpy, root, -100, -100, 1, 1, 0, 0, 0);
  XChangeProperty(dpy, check, netCheck, XA_WINDOW, 32, PropModeReplace,
    (unsigned char *)&check, 1);
  XChangeProperty(dpy, check, netName,
    XInternAtom(dpy, "UTF8_STRING", False), 8, PropModeReplace,
    (unsigned char *)"testwm", 6);

  supported[0] = netCheck;
  supported[1] = netRequest;
  supported[2] = netExtents;
  supported[3] = netName;
  XChangeProperty(dpy, root, XInternAtom(dpy, "_NET_SUPPORTED", False),
    XA_ATOM, 32, PropModeReplace, (unsigned char *)supported, 4);

  XSelectInput(dpy, root, SubstructureRedirectMask | SubstructureNotifyMask);
  /* Announced last, so that a client seeing it finds the rest in place. */
  XChangeProperty(dpy, root, netCheck, XA_WINDOW, 32, PropModeReplace,
    (unsigned char *)&check, 1);
  XFlush(dpy);

  for (;;)
    {
      XEvent	e;

      XNextEvent(dpy, &e);
      if (e.type == ClientMessage && e.xclient.message_type == netRequest)
	{
	  XChangeProperty(dpy, e.xclient.window, netExtents, XA_CARDINAL, 32,
	    PropModeReplace, (unsigned char *)zero, 4);
	  XFlush(dpy);
	}
      else if (e.type == MapRequest)
	{
	  XChangeProperty(dpy, e.xmaprequest.window, netExtents, XA_CARDINAL,
	    32, PropModeReplace, (unsigned char *)real, 4);
	  XMapWindow(dpy, e.xmaprequest.window);
	  XFlush(dpy);
	}
      else if (e.type == MapNotify && e.xmap.window != check)
	{
	  XChangeProperty(dpy, e.xmap.window, netExtents, XA_CARDINAL, 32,
	    PropModeReplace, (unsigned char *)real, 4);
	  XFlush(dpy);
	}
    }
}

/* Wait for the child to announce itself, so the backend finds a window
 * manager when it starts.  Answers NO if it never appears.
 */
static BOOL
waitForWindowManager(void)
{
  Display	*dpy;
  Atom		netCheck;
  unsigned	i;

  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      return NO;
    }
  netCheck = XInternAtom(dpy, "_NET_SUPPORTING_WM_CHECK", False);
  for (i = 0; i < 200; i++)
    {
      Atom		type;
      int		format;
      unsigned long	nitems;
      unsigned long	after;
      unsigned char	*data = NULL;

      if (XGetWindowProperty(dpy, DefaultRootWindow(dpy), netCheck, 0, 1,
	    False, XA_WINDOW, &type, &format, &nitems, &after, &data)
	  == Success && data != NULL)
	{
	  XFree(data);
	  if (nitems == 1)
	    {
	      XCloseDisplay(dpy);
	      return YES;
	    }
	}
      usleep(50000);
    }
  XCloseDisplay(dpy);
  return NO;
}

int
main(int argc, const char **argv)
{
  START_SET("frame extents")

  extern void	initialize_gnustep_backend(void);
  GSDisplayServer *srv = nil;
  pid_t		wm;
  float		l = -1;
  float		r = -1;
  float		t = -1;
  float		b = -1;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      SKIP("no window server available")
    }

  wm = fork();
  if (wm == 0)
    {
      runWindowManager();
      _exit(0);
    }
  if (wm < 0)
    {
      SKIP("cannot fork a window manager")
    }
  if (waitForWindowManager() == NO)
    {
      kill(wm, SIGKILL);
      SKIP("the test window manager did not start")
    }

  /* The offsets are cached on the root window once they are known. */
  [[NSUserDefaults standardUserDefaults]
    setBool: YES forKey: @"GSIgnoreRootOffsets"];

  NS_DURING
    {
      initialize_gnustep_backend();
      srv = [GSDisplayServer serverWithAttributes: nil];
    }
  NS_HANDLER
    {
      NSLog(@"the display server did not start: %@", localException);
      kill(wm, SIGKILL);
      SKIP("It looks like the GNUstep backend is not installed")
    }
  NS_ENDHANDLER

  if (srv == nil || [srv isMemberOfClass: [GSDisplayServer class]])
    {
      kill(wm, SIGKILL);
      SKIP("no concrete display server")
    }
  [GSDisplayServer setCurrentServer: srv];

  [srv styleoffsets: &l : &r : &t : &b : NSTitledWindowMask];
  PASS(t == (float)TOP,
    "a title bar offset survives a window manager that answers the frame"
    " extents request with zeros");

  l = r = t = b = -1;
  [srv styleoffsets: &l : &r : &t : &b : NSBorderlessWindowMask];
  PASS(l == 0.0 && r == 0.0 && t == 0.0 && b == 0.0,
    "a borderless window has no offsets");

  kill(wm, SIGKILL);

  END_SET("frame extents")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("frame extents")
    SKIP("back is not built with the x11 server")
  END_SET("frame extents")
  return 0;
}

#endif
