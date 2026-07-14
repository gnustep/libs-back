/* Coverage for the win32 display server's screen queries: -screenList,
 * -boundsForScreen:, -windowDepthForScreen: and -availableDepthsForScreen: on
 * WIN32Server (Source/win32/WIN32Server.m).
 *
 * These are answered from the desktop's monitors without mapping a window.  The
 * checks follow the GSDisplayServer contract: a non-empty list of screen
 * numbers, a positive-size rect for each screen and NSZeroRect for a screen that
 * is not present, a valid RGB window depth, and a zero-terminated list of
 * available depths that includes the screen's depth.
 *
 * It guards on the win32 server with the cairo graphics backend being the one
 * built, and at run time it skips when the backend cannot be reached.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_win32) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_win32 && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

int
main(void)
{
  START_SET("WIN32Server screen queries")
  ENTER_POOL

  GSDisplayServer *server = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      server = GSCurrentServer();
      if (server == nil)
	{
	  server = [GSDisplayServer serverWithAttributes: nil];
	}
    }
  NS_HANDLER
    {
      server = nil;
    }
  NS_ENDHANDLER

  if (server == nil)
    {
      SKIP("no win32 server available")
    }
  else
    {
      NSArray   *screens = [server screenList];
      NSUInteger i, count;
      BOOL       ok;

      /* -screenList enumerates the desktop's monitors as screen numbers. */
      PASS(screens != nil && [screens count] > 0,
	"screenList returns at least one screen")

      count = [screens count];
      ok = YES;
      for (i = 0; i < count; i++)
	{
	  if (![[screens objectAtIndex: i] isKindOfClass: [NSNumber class]])
	    {
	      ok = NO;
	    }
	}
      PASS(ok == YES, "screenList holds NSNumber screen identifiers")

      /* -boundsForScreen: reports a positive-size rect for each screen. */
      ok = YES;
      for (i = 0; i < count; i++)
	{
	  int    s = [[screens objectAtIndex: i] intValue];
	  NSRect b = [server boundsForScreen: s];

	  if (b.size.width <= 0.0 || b.size.height <= 0.0)
	    {
	      ok = NO;
	    }
	}
      PASS(ok == YES,
	"boundsForScreen: reports a positive-size rect for each screen")

      /* The same screen reports the same bounds on a repeated query. */
      {
	int    s = [[screens objectAtIndex: 0] intValue];
	NSRect b1 = [server boundsForScreen: s];
	NSRect b2 = [server boundsForScreen: s];

	PASS(NSEqualRects(b1, b2) == YES,
	  "boundsForScreen: is stable across repeated queries")
      }

      /* A screen that is not present is answered with NSZeroRect. */
      PASS(NSEqualRects([server boundsForScreen: 999999], NSZeroRect) == YES,
	"boundsForScreen: returns NSZeroRect for a screen that is not present")

      /* -windowDepthForScreen: reports a valid RGB window depth. */
      ok = YES;
      for (i = 0; i < count; i++)
	{
	  int           s = [[screens objectAtIndex: i] intValue];
	  NSWindowDepth d = [server windowDepthForScreen: s];

	  if (NSBitsPerSampleFromDepth(d) <= 0
	    || NSNumberOfColorComponents(NSColorSpaceFromDepth(d)) != 3)
	    {
	      ok = NO;
	    }
	}
      PASS(ok == YES,
	"windowDepthForScreen: reports an RGB window depth")

      /* -availableDepthsForScreen: reports a zero-terminated list that includes
       * the screen's own depth. */
      {
	int                  s = [[screens objectAtIndex: 0] intValue];
	NSWindowDepth        want = [server windowDepthForScreen: s];
	const NSWindowDepth *depths = [server availableDepthsForScreen: s];
	BOOL                 terminated = NO;
	BOOL                 found = NO;
	int                  j;

	PASS(depths != NULL, "availableDepthsForScreen: returns a depth list")
	if (depths != NULL)
	  {
	    for (j = 0; j < 64; j++)
	      {
		if (depths[j] == 0)
		  {
		    terminated = YES;
		    break;
		  }
		if (depths[j] == want)
		  {
		    found = YES;
		  }
	      }
	    PASS(terminated == YES,
	      "availableDepthsForScreen: list is zero-terminated")
	    PASS(found == YES,
	      "availableDepthsForScreen: list includes the screen depth")
	    NSZoneFree(NSDefaultMallocZone(), (void *) depths);
	  }
      }
    }

  LEAVE_POOL
  END_SET("WIN32Server screen queries")
  return 0;
}

#else

int
main(void)
{
  START_SET("WIN32Server screen queries")
    SKIP("back is not built with the win32+cairo backend")
  END_SET("WIN32Server screen queries")
  return 0;
}

#endif
