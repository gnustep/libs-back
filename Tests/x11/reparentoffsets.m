/* A reparenting window manager puts the window inside a frame and publishes
 * _NET_FRAME_EXTENTS after the reparent.  A client that reads the property as
 * soon as it sees the ReparentNotify reads whatever was there before, which
 * for a window manager that answers the _NET_REQUEST_FRAME_EXTENTS message
 * with zeros is those zeros.  The window's own place inside the frame says
 * what the decoration really is, so that is what the offsets come from.
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
  START_SET("reparent offsets")

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

  wm = fakeWMStart(FakeWMReparenting);
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
    "a title bar offset comes from the reparent when the extents published"
    " before the window was mapped are still in place");

  kill(wm, SIGKILL);

  END_SET("reparent offsets")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("reparent offsets")
    SKIP("back is not built with the x11 server")
  END_SET("reparent offsets")
  return 0;
}

#endif
