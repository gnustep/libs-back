/* Drawing through AppKit reaches the android backend's image surface.
 *
 * A window is made, its device is set, rectangles are filled through AppKit, and
 * the pixels are read back out of the cairo image surface the backend drew into.
 *
 * The figures are axis-aligned and unantialiased, so the expected values are
 * exact.  ARGB32 is premultiplied and in native byte order, so opaque black is
 * 0xff000000 and opaque white is 0xffffffff.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_android) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_android && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
#include <cairo.h>
#include <stdint.h>

#include "android/AndroidServer.h"
#include "cairo/CairoSurface.h"

/* The pixel at (x, y) in cairo's own coordinates: y counts down from the top
 * of the surface, which is the opposite of the AppKit rect used to draw. */
static uint32_t
pixelAt(cairo_surface_t *s, int x, int y)
{
  unsigned char *data = cairo_image_surface_get_data(s);
  int		 stride = cairo_image_surface_get_stride(s);

  return *(uint32_t *)(data + y * stride + x * 4);
}

int
main(void)
{
  START_SET("android rendering")
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  GSDisplayServer	*server = nil;
  NSWindow		*window;
  struct AndroidWindow	*record;
  cairo_surface_t	*cs = NULL;

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

  if (nil == server)
    {
      SKIP("no display server available")
    }

  window = [[NSWindow alloc]
	     initWithContentRect: NSMakeRect(0, 0, 20, 10)
		       styleMask: NSBorderlessWindowMask
			 backing: NSBackingStoreBuffered
			   defer: NO];
  PASS([window windowNumber] > 0, "the server made a window")

  [window orderFront: nil];
  [[window contentView] lockFocus];
  [[NSColor blackColor] set];
  NSRectFill(NSMakeRect(0, 0, 20, 10));
  [[NSColor whiteColor] set];
  NSRectFill(NSMakeRect(4, 2, 6, 3));
  [[window contentView] unlockFocus];
  [window flushWindow];

  record = (struct AndroidWindow *)
    [server windowDevice: [window windowNumber]];
  PASS(record != NULL, "the server hands out a device for the window")
  PASS(record != NULL && record->surface != nil,
    "setting the window device attached a cairo surface")

  if (record != NULL && record->surface != nil)
    {
      cs = [record->surface surface];
    }
  PASS(cs != NULL && cairo_surface_status(cs) == CAIRO_STATUS_SUCCESS,
    "the attached surface is in a good state")

  if (cs != NULL)
    {
      cairo_surface_flush(cs);

      /* The white rect covers AppKit x 4..9, y 2..4.  cairo's y counts from
       * the top of a 10-high surface, so those are cairo rows 5..7. */
      PASS(pixelAt(cs, 0, 0) == 0xff000000u,
        "the corner outside the white rect is opaque black")
      PASS(pixelAt(cs, 4, 5) == 0xffffffffu,
        "the first pixel of the white rect is opaque white")
      PASS(pixelAt(cs, 9, 7) == 0xffffffffu,
        "the last pixel of the white rect is opaque white")
      PASS(pixelAt(cs, 3, 5) == 0xff000000u,
        "the pixel one column left of the white rect is still black")
      PASS(pixelAt(cs, 10, 7) == 0xff000000u,
        "the pixel one column right of the white rect is still black")
      PASS(pixelAt(cs, 4, 4) == 0xff000000u,
        "the pixel one row above the white rect is still black")
      PASS(pixelAt(cs, 4, 8) == 0xff000000u,
        "the pixel one row below the white rect is still black")
    }

  [window release];
  [arp release];
  END_SET("android rendering")
  return 0;
}

#else

int
main(void)
{
  START_SET("android rendering")
    SKIP("back is not built with the android+cairo backend")
  END_SET("android rendering")
  return 0;
}

#endif
