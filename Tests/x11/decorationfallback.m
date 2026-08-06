/* A window manager that decorates nothing leaves every style without a
 * border, and nothing else draws a title bar or a close button, so the
 * windows cannot be moved or closed at all.  The gui library draws the
 * decorations when -handlesWindowDecorations answers NO, so that is what the
 * backend has to answer once it has found that out.
 *
 * A window manager that does decorate must still answer YES, and a decoration
 * default the user has set has to stand either way.
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
  START_SET("decoration fallback")

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

  wm = fakeWMStart(FakeWMUndecorated);
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
  PASS(l == 0.0 && r == 0.0 && t == 0.0 && b == 0.0,
    "a window manager that decorates nothing leaves a titled style with no"
    " offsets");

  PASS([srv handlesWindowDecorations] == NO,
    "the gui library draws the decorations when the window manager draws"
    " none");

  kill(wm, SIGKILL);

  END_SET("decoration fallback")

  return 0;
}

#else

int
main(int argc, const char **argv)
{
  START_SET("decoration fallback")
    SKIP("back is not built with the x11 server")
  END_SET("decoration fallback")
  return 0;
}

#endif
