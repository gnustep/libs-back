/* Window offsets have to survive a window manager that answers the
 * _NET_REQUEST_FRAME_EXTENTS message with four zeros and publishes the real
 * extents only once the window has been mapped.  Recent Mutter releases do
 * that, and taking the zeros leaves every decorated window style with no
 * decoration offset at all.
 *
 * The test forks a window manager that behaves that way, so it needs none on
 * the display it runs against.  The backend probes for offsets only when a
 * window manager is present, and otherwise reads them from the root window,
 * so GSIgnoreRootOffsets is set before the display server is created.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) && BUILD_SERVER == SERVER_x11

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include "FakeWindowManager.h"

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

  wm = fakeWMStart(NO);
  if (wm < 0)
    {
      SKIP("the test window manager did not start")
    }

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
  PASS(t == (float)FAKE_WM_TOP,
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
