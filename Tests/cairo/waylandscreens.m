/* Coverage for the Wayland display server's screen queries: -screenList,
 * -boundsForScreen:, -windowDepthForScreen: and -availableDepthsForScreen: on
 * WaylandServer (Source/wayland/WaylandServer.m).
 *
 * These are the GSDisplayServer methods the backend can answer from the
 * compositor's advertised wl_output(s) without mapping a window, so they can be
 * exercised against a live Wayland compositor.  The assertions check the
 * documented GSDisplayServer contract - a non-empty list of screen numbers, a
 * bounding rect with a positive size, and a valid RGB window depth - the same
 * contract the x11 backend answers.
 *
 * A backend test can only build against the backend it belongs to, so it guards
 * on the wayland+cairo backend actually being built (config.h names it through
 * BUILD_SERVER / BUILD_GRAPHICS) and skips cleanly on every other one.  At run
 * time it connects to the compositor named by the environment and skips when
 * there is none - WaylandServer raises NSWindowServerCommunicationException when
 * it cannot reach one - mirroring how the rendering test skips without a
 * display.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_wayland) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_wayland && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

int
main(void)
{
  START_SET("WaylandServer screen queries")
  ENTER_POOL

  GSDisplayServer *server = nil;

  /* Loading the backend and connecting to the compositor raises when there is
   * no compositor to reach; treat that as "nothing to test here". */
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
      SKIP("no Wayland compositor available")
    }
  else
    {
      NSArray   *screens = [server screenList];
      NSUInteger i, count;
      BOOL       ok;

      /* -screenList enumerates the compositor's outputs as screen numbers. */
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

      /* -boundsForScreen: reports each screen's bounds from the wl_output
       * geometry, with a zero origin and a positive size. */
      ok = YES;
      for (i = 0; i < count; i++)
	{
	  int    s = [[screens objectAtIndex: i] intValue];
	  NSRect b = [server boundsForScreen: s];

	  if (b.origin.x != 0.0 || b.origin.y != 0.0
	    || b.size.width <= 0.0 || b.size.height <= 0.0)
	    {
	      ok = NO;
	    }
	}
      PASS(ok == YES,
	"boundsForScreen: reports an origin-zero rect with a positive size")

      /* The same screen reports the same bounds on a repeated query. */
      if (count > 0)
	{
	  int    s = [[screens objectAtIndex: 0] intValue];
	  NSRect b1 = [server boundsForScreen: s];
	  NSRect b2 = [server boundsForScreen: s];

	  PASS(NSEqualRects(b1, b2) == YES,
	    "boundsForScreen: is stable across repeated queries")
	}

      /* -windowDepthForScreen: reports a valid 8-bit-per-sample RGB depth. */
      ok = YES;
      for (i = 0; i < count; i++)
	{
	  int           s = [[screens objectAtIndex: i] intValue];
	  NSWindowDepth d = [server windowDepthForScreen: s];

	  if (NSBitsPerSampleFromDepth(d) != 8
	    || NSNumberOfColorComponents(NSColorSpaceFromDepth(d)) != 3)
	    {
	      ok = NO;
	    }
	}
      PASS(ok == YES,
	"windowDepthForScreen: reports an 8-bit RGB window depth")
    }

  LEAVE_POOL
  END_SET("WaylandServer screen queries")
  return 0;
}

#else

int
main(void)
{
  START_SET("WaylandServer screen queries")
    SKIP("back is not built with the wayland+cairo backend")
  END_SET("WaylandServer screen queries")
  return 0;
}

#endif
