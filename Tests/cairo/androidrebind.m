/* The activity's surface goes back to a window that is still on screen when
 * the window holding it is taken off.
 *
 * An activity is given one surface, so the server binds it to one window and
 * takes it away again as windows are ordered in and out.  A panel ordered in
 * takes the surface from the window under it; when the panel closes there is
 * still a window on screen, and it has to be given the surface back.  Without
 * that the activity keeps a surface nothing draws into and the screen stays as
 * it was when the panel closed.
 *
 * AImageReader hands out a real ANativeWindow without an activity, so the
 * binding runs here with no activity to drive it.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_android) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_android && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <android/native_window.h>
#include <media/NdkImageReader.h>

/* The server class lives in the backend bundle, which is dlopened when the
 * application starts, so the selectors are declared rather than the class
 * named: a class literal would leave the reference undefined at link time.
 */
@interface NSObject (AndroidRebindTest)
- (void) setActivityWindow: (ANativeWindow *)native;
- (int) windowBoundToActivity;
@end

#define W 32
#define H 16

int
main(void)
{
  START_SET("android rebind")
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  AImageReader		*reader = NULL;
  ANativeWindow		*window = NULL;
  GSDisplayServer	*server;
  int			 lower, upper;

  NS_DURING
    {
      [NSApplication sharedApplication];
    }
  NS_HANDLER
    {
      SKIP("the application would not start")
    }
  NS_ENDHANDLER

  server = GSCurrentServer();
  if (NO == [server respondsToSelector: @selector(windowBoundToActivity)])
    {
      SKIP("not the android server")
    }

  if (AImageReader_new(W, H, AIMAGE_FORMAT_RGBA_8888, 4, &reader) != AMEDIA_OK
      || AImageReader_getWindow(reader, &window) != AMEDIA_OK
      || window == NULL)
    {
      SKIP("no AImageReader window on this device")
    }

  [server setActivityWindow: window];

  lower = [server window: NSMakeRect(0, 0, W, H)
			: NSBackingStoreBuffered
			: 8
			: 0];
  [server stylewindow: NSTitledWindowMask : lower];
  [server orderwindow: NSWindowAbove : 0 : lower];
  PASS([server windowBoundToActivity] == lower,
    "the first window on screen is given the activity's surface");

  upper = [server window: NSMakeRect(0, 0, W, H)
			: NSBackingStoreBuffered
			: 8
			: 0];
  [server stylewindow: NSTitledWindowMask : upper];
  [server orderwindow: NSWindowAbove : 0 : upper];
  PASS([server windowBoundToActivity] == upper,
    "a window ordered in over it takes the surface");

  [server orderwindow: NSWindowOut : 0 : upper];
  PASS([server windowBoundToActivity] == lower,
    "taking that window off gives the surface back to the one still on screen");

  [server orderwindow: NSWindowOut : 0 : lower];
  PASS([server windowBoundToActivity] == 0,
    "with no window on screen the surface is bound to none");

  [server termwindow: upper];
  [server termwindow: lower];
  [server setActivityWindow: NULL];
  AImageReader_delete(reader);
  [arp release];
  END_SET("android rebind")
  return 0;
}

#else

int
main(void)
{
  START_SET("android rebind")
  SKIP("not an android server with cairo graphics")
  END_SET("android rebind")
  return 0;
}

#endif
