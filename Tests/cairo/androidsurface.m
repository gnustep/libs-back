/* AndroidCairoSurface, checked directly.
 *
 * The real source file is compiled in, with a small CairoSurface stand-in, as
 * Tests/cairo/shmbuffer.m does for the wayland surface, so this needs no
 * gui-linked back bundle and no display server.
 *
 * A backend test can only build against the backend it belongs to, so it guards
 * on config.h's BUILD_SERVER and BUILD_GRAPHICS and skips everywhere else.  The
 * matching GNUmakefile.preamble adds cairo's headers and libraries under the
 * same condition.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_android) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_android && BUILD_GRAPHICS == GRAPHICS_cairo

#include <string.h>
#include <stdint.h>

#include "cairo/CairoSurface.h"
#include "android/AndroidServer.h"

/* Minimal stand-in for CairoSurface (the real one lives in CairoSurface.m). */
@implementation CairoSurface
- (id) initWithDevice: (void *)device { gsDevice = device; return self; }
- (void) dealloc
{
  if (_surface != NULL) { cairo_surface_destroy(_surface); }
  [super dealloc];
}
- (NSSize) size { return NSMakeSize(0, 0); }
- (void) setSize: (NSSize)newSize { (void)newSize; }
- (cairo_surface_t *) surface { return _surface; }
- (void) handleExposeRect: (NSRect)rect { (void)rect; }
- (void) flush { }
- (BOOL) isDrawingToScreen { return YES; }
@end

#include "cairo/AndroidCairoSurface.m"

int
main(void)
{
  START_SET("AndroidCairoSurface")
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  struct AndroidWindow	 win;
  AndroidCairoSurface	*s;
  cairo_surface_t	*cs;
  cairo_t		*cr;
  uint32_t		*data;

  memset(&win, 0, sizeof(win));
  win.window_id = 7;
  win.frame = NSMakeRect(0, 0, 40, 30);

  s = [[AndroidCairoSurface alloc] initWithDevice: &win];
  PASS(s != nil, "a surface is created for a window with a non-empty frame")

  cs = [s surface];
  PASS(cs != NULL && cairo_surface_status(cs) == CAIRO_STATUS_SUCCESS,
    "the cairo surface is created without error")
  PASS(cs != NULL && cairo_surface_get_type(cs) == CAIRO_SURFACE_TYPE_IMAGE,
    "the surface is an image surface, which needs no window system")
  PASS(cs != NULL && cairo_image_surface_get_format(cs) == CAIRO_FORMAT_ARGB32,
    "the surface format is ARGB32")
  PASS_EQUAL([NSValue valueWithSize: [s size]],
             [NSValue valueWithSize: NSMakeSize(40, 30)],
    "the surface size is the window frame size")
  PASS(cs != NULL && cairo_image_surface_get_stride(cs)
         == cairo_format_stride_for_width(CAIRO_FORMAT_ARGB32, 40),
    "the stride is the one cairo asks for, not width times four")
  PASS([s isDrawingToScreen] == NO,
    "an offscreen surface says it is not drawing to screen")
  PASS(win.surface == (CairoSurface *)s,
    "the window record points back at its surface")

  /* Painting has to reach the data the surface owns; a surface that is created
   * but never written to would pass every check above. */
  if (cs != NULL)
    {
      cr = cairo_create(cs);
      cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
      cairo_set_source_rgba(cr, 0.0, 0.0, 1.0, 1.0);
      cairo_paint(cr);
      cairo_destroy(cr);
      cairo_surface_flush(cs);
      data = (uint32_t *)cairo_image_surface_get_data(cs);
      PASS(data != NULL && data[0] == 0xff0000ffu,
        "painting opaque blue leaves 0xff0000ff in the first pixel")
    }

  [s setSize: NSMakeSize(11, 5)];
  cs = [s surface];
  PASS(cs != NULL && cairo_image_surface_get_width(cs) == 11
       && cairo_image_surface_get_height(cs) == 5,
    "setSize: reallocates the surface at the new size")
  PASS_EQUAL([NSValue valueWithSize: [s size]],
             [NSValue valueWithSize: NSMakeSize(11, 5)],
    "size reports the new size after setSize:")

  [s release];

  memset(&win, 0, sizeof(win));
  win.window_id = 8;
  win.frame = NSMakeRect(0, 0, 0, 0);
  s = [[AndroidCairoSurface alloc] initWithDevice: &win];
  PASS(s == nil, "a zero-area window produces no surface")

  [arp release];
  END_SET("AndroidCairoSurface")
  return 0;
}

#else

int
main(void)
{
  START_SET("AndroidCairoSurface")
    SKIP("back is not built with the android+cairo backend")
  END_SET("AndroidCairoSurface")
  return 0;
}

#endif
