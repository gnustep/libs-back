/* Rendering tests for the Wayland shared-memory window surface
 * (Source/cairo/WaylandCairoShmSurface.m).  Unlike the offscreen rendering
 * test, this draws into a real window's content view, which is backed by the
 * wl_shm surface, then reads the pixels back: a solid fill paints the window and
 * filling the left half leaves the right half alone.  This exercises the shm
 * surface's cairo drawing and the GSReadRect read-back through the on-window
 * path (setWindowdevice / handleExposeRect).
 *
 * It guards on the wayland server with cairo and skips when no compositor can be
 * reached; colours are checked with a small tolerance.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_wayland) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_wayland && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <stdlib.h>

static BOOL
pixelIs(NSBitmapImageRep *rep, int x, int y, int r, int g, int b)
{
  unsigned char *d = [rep bitmapData];
  long bpr = [rep bytesPerRow];
  long spp = [rep samplesPerPixel];
  unsigned char *px = d + y * bpr + x * spp;

  return (abs((int)px[0] - r) <= 2
	  && abs((int)px[1] - g) <= 2
	  && abs((int)px[2] - b) <= 2);
}

int
main(void)
{
  START_SET("Wayland window surface rendering")
  ENTER_POOL

  GSDisplayServer *server = nil;

  NS_DURING
    {
      [NSApplication sharedApplication];
      server = GSCurrentServer();
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
      int       w = 40, h = 40;
      NSWindow *win = [[NSWindow alloc]
			initWithContentRect: NSMakeRect(100, 100, w, h)
				  styleMask: NSTitledWindowMask
				    backing: NSBackingStoreBuffered
				      defer: NO];
      NSView           *cv = [win contentView];
      NSBitmapImageRep *rep;

      [win orderFront: nil];

      /* Draw into the window: fill red, then the left half green. */
      [cv lockFocus];
      [[NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1] set];
      NSRectFill([cv bounds]);
      [[NSColor colorWithDeviceRed: 0 green: 1 blue: 0 alpha: 1] set];
      NSRectFill(NSMakeRect(0, 0, w / 2, h));
      [[NSGraphicsContext currentContext] flushGraphics];
      rep = [[[NSBitmapImageRep alloc]
	       initWithFocusedViewRect: [cv bounds]] autorelease];
      [cv unlockFocus];

      PASS(rep != nil && pixelIs(rep, w / 4, h / 2, 0, 255, 0),
	"the left half of the window surface is filled green")
      PASS(rep != nil && pixelIs(rep, 3 * w / 4, h / 2, 255, 0, 0),
	"the right half of the window surface stays red")

      [win close];
    }

  LEAVE_POOL
  END_SET("Wayland window surface rendering")
  return 0;
}

#else

int
main(void)
{
  START_SET("Wayland window surface rendering")
    SKIP("back is not built with the wayland+cairo backend")
  END_SET("Wayland window surface rendering")
  return 0;
}

#endif
