/* Posting part of the surface leaves the rest of the window showing the
 * current frame, not an older one.
 *
 * A window hands out one of several buffers in turn, so the buffer locked for
 * a post holds whatever was drawn into it some frames ago rather than what was
 * posted last.  A post that copies only the rectangle that changed therefore
 * has to copy into a buffer whose other pixels are stale, and the window is
 * asked how much has to be written.
 *
 * The first image is held while the second post is made, which is what forces
 * the second post onto a different buffer.  Releasing it first hands the same
 * buffer straight back, the stale pixels are the ones just posted, and the
 * test passes whether the code is right or not.
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

@interface NSObject (AndroidRepaintTest)
- (id) initWithDevice: (void *)device;
- (void) setNativeWindow: (ANativeWindow *)window;
- (cairo_surface_t *) surface;
- (void) flush;
- (void) handleExposeRect: (NSRect)rect;
@end

#define W 32
#define H 16

/* Paint the whole surface one colour, through cairo directly: what is under
 * test is the post, not AppKit's route to it. */
static void
paint_all(id surface, double r, double g, double b)
{
  cairo_t *cr = cairo_create([surface surface]);

  cairo_set_source_rgba(cr, r, g, b, 1.0);
  cairo_paint(cr);
  cairo_destroy(cr);
}

static void
paint_rect(id surface, double r, double g, double b, NSRect rect)
{
  cairo_t *cr = cairo_create([surface surface]);

  cairo_set_source_rgba(cr, r, g, b, 1.0);
  cairo_rectangle(cr, NSMinX(rect), NSMinY(rect),
    NSWidth(rect), NSHeight(rect));
  cairo_fill(cr);
  cairo_destroy(cr);
}

int
main(void)
{
  START_SET("android repaint")
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  AImageReader		*reader = NULL;
  ANativeWindow		*window = NULL;
  AImage		*image = NULL;
  AImage		*first = NULL;
  Class			 surfaceClass;
  id			 surface;
  struct AndroidWindow	 record;
  uint8_t		*plane = NULL;
  int			 planeLen = 0, rowStride = 0, pixelStride = 0;

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

  /* Room for more than one image at a time, so the first can be held while
   * the second is posted and the producer still has a buffer to write into. */
  if (AImageReader_new(W, H, AIMAGE_FORMAT_RGBA_8888, 4, &reader) != AMEDIA_OK
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

  /* The first frame: red everywhere. */
  paint_all(surface, 1.0, 0.0, 0.0);
  [surface flush];

  PASS(AImageReader_acquireNextImage(reader, &image) == AMEDIA_OK
       && image != NULL,
       "the first post produced an image");
  if (image == NULL)
    {
      AImageReader_delete(reader);
      SKIP("nothing was posted, the rest cannot be checked")
    }
  AImage_getPlaneRowStride(image, 0, &rowStride);
  AImage_getPlanePixelStride(image, 0, &pixelStride);
  AImage_getPlaneData(image, 0, &plane, &planeLen);
  PASS(pixelStride == 4 && plane != NULL, "the first image has pixels");
  PASS(plane[(H - 1) * rowStride] == 255,
       "the first post reached the last row");
  /* Held, not released: the next post must go to another buffer. */
  first = image;
  image = NULL;

  /* The second frame changes four pixels in the top left corner and posts only
   * those.  Everything else must still be the red of the frame before. */
  paint_rect(surface, 0.0, 0.0, 1.0, NSMakeRect(0, 0, 4, 4));
  [surface handleExposeRect: NSMakeRect(0, 0, 4, 4)];

  PASS(AImageReader_acquireNextImage(reader, &image) == AMEDIA_OK
       && image != NULL,
       "the partial post produced an image");
  if (image == NULL)
    {
      AImageReader_delete(reader);
      SKIP("nothing was posted the second time")
    }
  AImage_getPlaneRowStride(image, 0, &rowStride);
  AImage_getPlaneData(image, 0, &plane, &planeLen);

  /* The damage itself. */
  PASS(plane[2] == 255 && plane[0] == 0,
       "the rectangle that changed was posted blue");

  /* Away from the damage, in the same image.  This is the assertion the whole
   * file exists for: a post that wrote only the damaged rectangle leaves these
   * pixels holding whatever the buffer held before it was handed back. */
  PASS(plane[(H - 1) * rowStride] == 255,
       "the last row still holds the red of the current frame");
  PASS(plane[(H - 1) * rowStride + 2] == 0,
       "and it is red rather than the blue of the damage");
  PASS(plane[8 * rowStride + 16 * 4] == 255,
       "a pixel in the middle still holds the current frame");

  AImage_delete(image);
  if (first != NULL)
    {
      AImage_delete(first);
    }
  AImageReader_delete(reader);
  DESTROY(surface);
  [arp release];
  END_SET("android repaint")
  return 0;
}

#else

int
main(void)
{
  START_SET("android repaint")
  SKIP("this test is for the android server with cairo graphics")
  END_SET("android repaint")
  return 0;
}

#endif
