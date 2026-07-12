/* Tests the cairo backend's current device for an offscreen drawing context.
 * When an NSImage is focused the backend creates a drawing surface sized to the
 * image, and GSCurrentDevice reports a non-null device with the drawing offset
 * that positions the image (its y offset is the image height, from the cairo
 * y-flip).  This exercises the surface/device set-up that backs offscreen
 * drawing.
 *
 * It needs a window server (to load the backend), so it opens the display named
 * by the environment and skips when there is none, and it guards on the cairo
 * graphics backend being the one built.
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

@interface NSObject (CairoDevice)
- (void) GSCurrentDevice: (void **)device : (int *)x : (int *)y;
@end

/* Focus an image of the given size and report the current device and offset. */
static void
deviceForImage(int w, int h, void **device, int *x, int *y)
{
  NSImage *img = [[NSImage alloc] initWithSize: NSMakeSize(w, h)];

  [img lockFocus];
  [[NSGraphicsContext currentContext] GSCurrentDevice: device : x : y];
  [img unlockFocus];
  [img release];
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  void *device;
  int x, y;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping surface device tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];

  device = NULL; x = -1; y = -1;
  deviceForImage(37, 21, &device, &x, &y);
  PASS(device != NULL, "an offscreen image context has a drawing device");
  PASS(x == 0 && y == 21,
    "the drawing offset positions the image by its height");

  device = NULL; x = -1; y = -1;
  deviceForImage(8, 64, &device, &x, &y);
  PASS(device != NULL && x == 0 && y == 64,
    "the offset tracks a differently sized image");

  DESTROY(pool);
  return 0;
}

#else

int
main(int argc, const char **argv)
{
  return 0;
}

#endif
