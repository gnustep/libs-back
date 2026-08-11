/* The android surface posts what was drawn into the window bound to it.
 *
 * AImageReader hands out a real ANativeWindow without an activity, so the whole
 * lock, blit and post path runs here and the posted pixels are read back and
 * asserted.  The figure is opaque red rather than a grey: cairo's ARGB32 is a
 * native-endian word, so its bytes are B, G, R, A, while the window's
 * RGBA_8888 is R, G, B, A.  A blit that copies without swizzling passes on any
 * colour whose red and blue are equal.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_android) \
  && defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_SERVER == SERVER_android && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <android/native_window.h>
#include <media/NdkImage.h>
#include <media/NdkImageReader.h>
#include <cairo.h>
#include <stdint.h>
#include <string.h>

#include "android/AndroidServer.h"

/* The surface class lives in the backend bundle, which is dlopened when the
 * application starts, so it is named here rather than linked: a class literal
 * would leave _OBJC_REF_CLASS_AndroidCairoSurface undefined at link time.  The
 * selectors are declared for the same reason. */
@interface NSObject (AndroidPostTest)
- (id) initWithDevice: (void *)device;
- (void) setNativeWindow: (ANativeWindow *)window;
- (ANativeWindow *) nativeWindow;
- (cairo_surface_t *) surface;
- (BOOL) isDrawingToScreen;
- (void) flush;
@end

#define W 32
#define H 16

int
main(void)
{
  START_SET("android post")
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  AImageReader		*reader = NULL;
  ANativeWindow		*window = NULL;
  AImage		*image = NULL;
  Class			 surfaceClass;
  id			 surface;
  struct AndroidWindow	 record;
  struct AndroidWindow	*record2;
  cairo_t		*cr;
  uint8_t		*plane = NULL;
  int			 planeLen = 0, rowStride = 0, pixelStride = 0;

  /* Starting the application loads the backend bundle, which is where the
   * surface class comes from. */
  NS_DURING
    {
      [NSApplication sharedApplication];
    }
  NS_HANDLER
    {
      SKIP("the application would not start")
    }
  NS_ENDHANDLER

  surfaceClass = NSClassFromString(@"AndroidCairoSurface");
  PASS(surfaceClass != Nil, "the backend bundle carries AndroidCairoSurface");
  if (surfaceClass == Nil)
    {
      SKIP("no surface class, the rest cannot be checked")
    }

  if (AImageReader_new(W, H, AIMAGE_FORMAT_RGBA_8888, 2, &reader) != AMEDIA_OK
      || AImageReader_getWindow(reader, &window) != AMEDIA_OK
      || window == NULL)
    {
      SKIP("no AImageReader window on this device")
    }

  memset(&record, 0, sizeof(record));
  record.window_id = 1;
  record.frame = NSMakeRect(0, 0, W, H);

  surface = [[surfaceClass alloc] initWithDevice: &record];
  PASS(surface != nil, "a surface is made for the window record");

  [surface setNativeWindow: window];
  PASS([surface nativeWindow] == window, "the native window reads back");
  PASS([surface isDrawingToScreen] == YES,
       "a surface with a window bound is drawing to screen");

  /* Opaque red over the whole surface, through cairo directly: what is under
   * test here is the post, not AppKit's route to it. */
  cr = cairo_create([surface surface]);
  cairo_set_source_rgba(cr, 1.0, 0.0, 0.0, 1.0);
  cairo_paint(cr);
  cairo_destroy(cr);

  [surface flush];

  PASS(AImageReader_acquireNextImage(reader, &image) == AMEDIA_OK
       && image != NULL,
       "the post produced an image in the reader");
  if (image == NULL)
    {
      AImageReader_delete(reader);
      SKIP("nothing was posted, the rest cannot be checked")
    }

  AImage_getPlaneRowStride(image, 0, &rowStride);
  AImage_getPlanePixelStride(image, 0, &pixelStride);
  AImage_getPlaneData(image, 0, &plane, &planeLen);
  PASS(plane != NULL && planeLen > 0, "the image has pixels");
  PASS(pixelStride == 4, "the plane is 4 bytes per pixel");

  /* R, G, B, A in memory: red is 255, 0, 0, 255.  A blit that copied cairo's
   * B, G, R, A would answer 0, 0, 255, 255 here. */
  PASS(plane[0] == 255, "the red channel of the first pixel is 255");
  PASS(plane[1] == 0, "the green channel is 0");
  PASS(plane[2] == 0, "the blue channel is 0");
  PASS(plane[3] == 255, "the alpha channel is 255");

  /* A pixel on the last row, reached through the image's own stride rather
   * than one computed from the width. */
  PASS(plane[(H - 1) * rowStride] == 255, "the last row was posted too");

  AImage_delete(image);
  image = NULL;
  DESTROY(surface);

  /* The same path, reached the way AppKit reaches it: through the server, by
   * window id, with the rect in the window's own coordinates. */
  {
    AndroidServer *server = nil;
    int		   win;

    NS_DURING
      {
	server = (AndroidServer *)GSCurrentServer();
      }
    NS_HANDLER
      {
	server = nil;
      }
    NS_ENDHANDLER

    if (server == nil)
      {
	AImageReader_delete(reader);
	SKIP("no display server, the binding cannot be checked")
      }

    win = [server window: NSMakeRect(0, 0, W, H) : NSBackingStoreBuffered
			: NSBorderlessWindowMask : 0];
    PASS(win > 0, "the server makes a window");

    [server setNativeWindow: window forWindow: win];
    PASS([server nativeWindowForWindow: win] == window,
	 "the native window reads back from the server");

    /* The screen is the activity's surface, not a window's: an activity is
     * given one surface and every window is written into it. */
    [server setActivityWindow: window];
    PASS(NSEqualRects([server boundsForScreen: 0], NSMakeRect(0, 0, W, H)),
	 "the screen bounds come from the activity's surface");

    /* Give the window a surface and paint it green, then post through the
     * server rather than through the surface.  The record is reached with
     * -_windowWithId:, which the server already declares, rather than by
     * inventing an accessor for the test. */
    /* Only a window that is on screen is written into the activity's surface,
     * so this one is ordered in before it is posted. */
    [server orderwindow: NSWindowAbove : 0 : win];
    [server setWindowdevice: win forContext: GSCurrentContext()];
    record2 = [server _windowWithId: win];
    PASS(record2 != NULL && record2->surface != nil,
	 "the server gave the window a surface");
    if (record2 == NULL || record2->surface == nil)
      {
	AImageReader_delete(reader);
	SKIP("no surface for the window, the post cannot be checked")
      }
    cr = cairo_create([record2->surface surface]);
    cairo_set_source_rgba(cr, 0.0, 1.0, 0.0, 1.0);
    cairo_paint(cr);
    cairo_destroy(cr);

    [server flushwindowrect: NSMakeRect(0, 0, W, H) : win];

    PASS(AImageReader_acquireNextImage(reader, &image) == AMEDIA_OK
	 && image != NULL,
	 "flushwindowrect:: posted through the server");
    if (image != NULL)
      {
	AImage_getPlaneData(image, 0, &plane, &planeLen);
	PASS(plane[0] == 0, "the red channel is 0 after the green paint");
	PASS(plane[1] == 255, "the green channel is 255");
	PASS(plane[2] == 0, "the blue channel is 0");
	AImage_delete(image);
      }
  }

  AImageReader_delete(reader);
  [arp release];
  END_SET("android post")
  return 0;
}

#else

int
main(void)
{
  START_SET("android post")
  SKIP("not an android server with cairo graphics")
  END_SET("android post")
  return 0;
}

#endif
