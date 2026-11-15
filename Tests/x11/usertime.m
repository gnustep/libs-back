/* _NET_WM_USER_TIME on a window given the input focus.  -lastTime answers
 * CurrentTime (0) before the backend has seen an event, and again once the
 * last one is out of date.  In this property 0 means the window should not
 * get the focus when it is mapped, so the backend must not write it: Mutter
 * stacks such a window below the focused one, and an application's first
 * window opens behind whatever the user was looking at.  A real time must
 * still be written, and must not be replaced by 0 later.
 *
 * Only the property the backend sets is read, so what a real window manager
 * does with it is not tested here.  The stand-in window manager is there
 * because the backend writes the property only under an EWMH window manager.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) && BUILD_SERVER == SERVER_x11

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include "FakeWindowManager.h"

/* -lastTime goes out of date after 0.5 seconds (XGServerEvent.m). */
#define OUT_OF_DATE_WAIT 0.7
/* Long enough for the window manager to map a window that was ordered in. */
#define MAP_WAIT 0.2

@interface GSDisplayServer (UserTimeTest)
- (void) setLastTime: (Time)last;
@end

static NSWindow *
orderedInWindow(void)
{
  NSWindow	*win;

  win = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 100, 300, 200)
				    styleMask: NSTitledWindowMask
				      backing: NSBackingStoreBuffered
					defer: NO];
  [win setReleasedWhenClosed: NO];
  [win orderFront: nil];
  XSync((Display *)[GSCurrentServer() serverDevice], False);
  [NSThread sleepForTimeInterval: MAP_WAIT];
  return win;
}

/* Gives the window the focus, then answers its _NET_WM_USER_TIME, or -1 when
 * it has none.  The backend's own connection is flushed first: what it set
 * may still be in its buffer.
 */
static long
userTimeAfterFocus(Display *dpy, NSWindow *win)
{
  GSDisplayServer	*srv = GSCurrentServer();
  Window		w = (Window)[srv windowDevice: [win windowNumber]];
  Atom			atom = XInternAtom(dpy, "_NET_WM_USER_TIME", False);
  Atom			type = None;
  int			format = 0;
  unsigned long		count = 0;
  unsigned long		after = 0;
  unsigned char		*data = NULL;
  long			value = -1;

  [srv setinputfocus: [win windowNumber]];
  XSync((Display *)[srv serverDevice], False);

  if (XGetWindowProperty(dpy, w, atom, 0, 1, False, XA_CARDINAL, &type,
    &format, &count, &after, &data) == Success && data != NULL)
    {
      if (type == XA_CARDINAL && format == 32 && count == 1)
	{
	  value = *(long *)data;
	}
      XFree(data);
    }
  return value;
}

int
main(int argc, const char **argv)
{
  START_SET("_NET_WM_USER_TIME")

  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  Display		*dpy;
  pid_t			wm;
  BOOL			started = NO;
  NSWindow		*first;
  NSWindow		*withInput;
  NSWindow		*late;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      SKIP("no window server available")
    }
  dpy = XOpenDisplay(NULL);
  if (dpy == NULL)
    {
      SKIP("no window server available")
    }

  wm = fakeWMStart(FakeWMDecorating);
  if (wm < 0)
    {
      SKIP("the test window manager did not start")
    }

  NS_DURING
    {
      [NSApplication sharedApplication];
      started = YES;
    }
  NS_HANDLER
    {
      NSLog(@"the application did not start: %@", localException);
    }
  NS_ENDHANDLER
  if (started == NO || GSCurrentServer() == nil
    || [GSCurrentServer() isMemberOfClass: [GSDisplayServer class]])
    {
      kill(wm, SIGKILL);
      SKIP("It looks like the GNUstep backend is not installed")
    }

  first = orderedInWindow();
  PASS(userTimeAfterFocus(dpy, first) == -1,
    "a window focused before any event gets no user time, not 0");

  withInput = orderedInWindow();
  [GSCurrentServer() setLastTime: 5000];
  PASS(userTimeAfterFocus(dpy, withInput) == 5000,
    "a window focused just after an event gets that event's time");

  [NSThread sleepForTimeInterval: OUT_OF_DATE_WAIT];
  late = orderedInWindow();
  PASS(userTimeAfterFocus(dpy, late) == -1,
    "a window focused once the last event is out of date gets no user time");

  PASS(userTimeAfterFocus(dpy, withInput) == 5000,
    "focusing a window again later leaves the time it has");

  kill(wm, SIGKILL);
  XCloseDisplay(dpy);
  [pool release];

  END_SET("_NET_WM_USER_TIME")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("_NET_WM_USER_TIME")
    SKIP("back is not built with the x11 server")
  END_SET("_NET_WM_USER_TIME")
  return 0;
}

#endif
