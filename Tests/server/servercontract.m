/* The GSDisplayServer contract, checked against whichever display server the
 * backend was built with.
 *
 * Every server answers the same questions about its screens, its windows and
 * the pointer, so this is written once here rather than once per server: it
 * takes the current server, asks only what the interface promises, and skips
 * when no server can be reached.  Where servers legitimately differ the check
 * is written as the contract rather than as one server's answer -- window
 * decorations are the example, since a server that does not draw them reports
 * no insets, while one that does reports insets that are not negative.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

int
main(void)
{
  START_SET("display server contract")

  GSDisplayServer *server = nil;
  NSArray *screens;
  unsigned count;
  unsigned i;
  BOOL ok;

  NS_DURING
    {
      [NSApplication sharedApplication];
      server = GSCurrentServer();
      if (nil == server)
	{
	  server = [GSDisplayServer serverWithAttributes: nil];
	}
    }
  NS_HANDLER
    {
      server = nil;
    }
  NS_ENDHANDLER

  if (nil == server)
    {
      SKIP("no display server available")
    }

  screens = [server screenList];
  count = [screens count];
  if (0 == count)
    {
      SKIP("the display server reports no screen")
    }

  /* A server that does not implement the screen queries has nothing here to
   * answer for; ask it one and skip the set when it refuses. */
  ok = YES;
  NS_DURING
    {
      NSWindowDepth *depths;

      depths = [server availableDepthsForScreen:
	[[screens objectAtIndex: 0] intValue]];
      if (depths) NSZoneFree(NSDefaultMallocZone(), depths);
    }
  NS_HANDLER
    {
      ok = NO;
    }
  NS_ENDHANDLER
  if (NO == ok)
    {
      SKIP("the display server does not implement the screen queries")
    }

  /* ---- screens ---- */

  PASS(count > 0, "screenList returns at least one screen")

  ok = YES;
  for (i = 0; i < count; i++)
    {
      if (![[screens objectAtIndex: i] isKindOfClass: [NSNumber class]])
	{
	  ok = NO;
	}
    }
  PASS(ok == YES, "screenList holds NSNumber screen identifiers")

  /* A listed screen has an extent. */
  ok = YES;
  for (i = 0; i < count; i++)
    {
      NSRect b = [server boundsForScreen: [[screens objectAtIndex: i] intValue]];

      if (b.size.width <= 0.0 || b.size.height <= 0.0)
	{
	  ok = NO;
	}
    }
  PASS(ok == YES, "boundsForScreen: reports a positive size for every screen")

  /* Asking twice gives the same answer. */
  {
    int s = [[screens objectAtIndex: 0] intValue];

    PASS(NSEqualRects([server boundsForScreen: s],
                      [server boundsForScreen: s]) == YES,
      "boundsForScreen: is stable across repeated queries")
  }

  /* A screen that is not there has no bounds, whichever way it is named. */
  PASS(NSEqualRects([server boundsForScreen: 999999], NSZeroRect) == YES,
    "boundsForScreen: returns NSZeroRect for a screen that is not present")
  PASS(NSEqualRects([server boundsForScreen: -1], NSZeroRect) == YES,
    "boundsForScreen: returns NSZeroRect for a negative screen number")

  /* Every screen has an RGB depth. */
  ok = YES;
  for (i = 0; i < count; i++)
    {
      NSWindowDepth d
	= [server windowDepthForScreen: [[screens objectAtIndex: i] intValue]];

      if (NSBitsPerSampleFromDepth(d) <= 0
	|| NSNumberOfColorComponents(NSColorSpaceFromDepth(d)) != 3)
	{
	  ok = NO;
	}
    }
  PASS(ok == YES, "windowDepthForScreen: reports an RGB window depth")

  /* The depth list is zero-terminated and holds the screen's own depth. */
  {
    int s = [[screens objectAtIndex: 0] intValue];
    NSWindowDepth want = [server windowDepthForScreen: s];
    const NSWindowDepth *depths = [server availableDepthsForScreen: s];
    BOOL terminated = NO;
    BOOL found = NO;
    int j;

    PASS(depths != NULL, "availableDepthsForScreen: returns a depth list")
    if (depths != NULL)
      {
	for (j = 0; j < 64; j++)
	  {
	    if (0 == depths[j])
	      {
		terminated = YES;
		break;
	      }
	    if (depths[j] == want)
	      {
		found = YES;
	      }
	  }
	NSZoneFree(NSDefaultMallocZone(), depths);
      }
    PASS(terminated == YES, "availableDepthsForScreen: list is zero-terminated")
    PASS(found == YES,
      "availableDepthsForScreen: list includes the screen depth")
  }

  /* ---- windows ---- */

  {
    int s = [[screens objectAtIndex: 0] intValue];
    NSRect frame = NSMakeRect(100, 100, 200, 150);
    int win;
    int win2;

    win = [server window: frame
			 : NSBackingStoreBuffered
			 : NSTitledWindowMask
			 : s];
    PASS(win > 0, "window:::: returns a positive window number")

    win2 = [server window: frame
			  : NSBackingStoreBuffered
			  : NSTitledWindowMask
			  : s];
    PASS(win2 > 0 && win2 != win, "a second window gets a distinct number")

    /* The size asked for is the size reported.  The origin is not checked:
     * a server that cannot place its own windows is free to put it
     * elsewhere. */
    {
      NSRect b = [server windowbounds: win];

      PASS(b.size.width == frame.size.width
	&& b.size.height == frame.size.height,
	"windowbounds: reports the requested size")
      PASS(NSEqualRects(b, [server windowbounds: win]) == YES,
	"windowbounds: is stable across repeated queries")
    }

    /* The level set is the level read back. */
    [server setwindowlevel: NSFloatingWindowLevel : win];
    PASS([server windowlevel: win] == NSFloatingWindowLevel,
      "windowlevel: reads back a set floating level")
    [server setwindowlevel: NSNormalWindowLevel : win];
    PASS([server windowlevel: win] == NSNormalWindowLevel,
      "windowlevel: reads back a set normal level")

    /* Decoration insets are never negative, and a server that does not draw
     * decorations reports none at all. */
    {
      float l = -1.0, r = -1.0, t = -1.0, b = -1.0;

      [server styleoffsets: &l : &r : &t : &b : NSTitledWindowMask];
      PASS(l >= 0.0 && r >= 0.0 && t >= 0.0 && b >= 0.0,
	"styleoffsets::::: reports insets that are not negative")
      if (NO == [server handlesWindowDecorations])
	{
	  PASS(l == 0.0 && r == 0.0 && t == 0.0 && b == 0.0,
	    "styleoffsets::::: reports no insets when the server does not"
	    " decorate")
	}
    }

    /* A window asked for with no area still has an extent. */
    {
      int z = [server window: NSMakeRect(0, 0, 0, 0)
			    : NSBackingStoreBuffered
			    : NSTitledWindowMask
			    : s];
      NSRect zb = [server windowbounds: z];

      PASS(zb.size.width > 0.0 && zb.size.height > 0.0,
	"a zero-area frame yields a window with a positive size")
      [server termwindow: z];
    }

    /* A window number the server does not know has no level and no bounds,
     * and is not an error to ask about. */
    PASS([server windowlevel: 999999] == 0,
      "windowlevel: on an unknown window number returns 0")
    PASS(NSEqualRects([server windowbounds: 999999], NSZeroRect) == YES,
      "windowbounds: on an unknown window number returns NSZeroRect")
    PASS_RUNS(({
	[server setwindowlevel: NSNormalWindowLevel : 999999];
	[server windowdevice: 999999];
	[server termwindow: 999999];
      }),
      "window operations on an unknown window number do not raise")

    [server termwindow: win2];
    [server termwindow: win];
  }

  /* ---- pointer ---- */

  {
    int s = [[screens objectAtIndex: 0] intValue];
    NSRect b = [server boundsForScreen: s];
    NSPoint p = [server mouselocation];
    int onWin = 0;
    NSPoint q = [server mouseLocationOnScreen: s window: &onWin];

    PASS(p.x >= 0.0 && p.y >= 0.0
      && p.x <= b.size.width && p.y <= b.size.height,
      "mouselocation reports a point on the screen")
    PASS(q.x >= 0.0 && q.y >= 0.0
      && q.x <= b.size.width && q.y <= b.size.height,
      "mouseLocationOnScreen:window: reports a point on the screen")
  }

  END_SET("display server contract")

  return 0;
}
