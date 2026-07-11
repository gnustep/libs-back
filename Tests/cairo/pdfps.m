/* Tests that the cairo backend produces PDF and PostScript output.  A view is
 * drawn to PDF and EPS data through the AppKit printing path, which drives the
 * cairo PDF and PS surfaces, and the resulting documents are checked for a
 * valid header, a non-trivial body and the expected document structure.
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
#include <string.h>
#include <stdlib.h>

@interface GSPdfPsTestView : NSView
@end

@implementation GSPdfPsTestView
- (void) drawRect: (NSRect)r
{
  [[NSColor redColor] set];
  NSRectFill(r);
  [[NSColor blueColor] set];
  [NSBezierPath strokeLineFromPoint: NSMakePoint(0, 0)
                            toPoint: NSMakePoint(80, 80)];
}
@end

static BOOL
dataStartsWith(NSData *d, const char *magic)
{
  size_t n = strlen(magic);

  return d != nil && [d length] >= n && memcmp([d bytes], magic, n) == 0;
}

static BOOL
dataContains(NSData *d, const char *needle)
{
  NSData *n;

  if (d == nil)
    return NO;
  n = [NSData dataWithBytes: needle length: strlen(needle)];
  return [d rangeOfData: n
                options: 0
                  range: NSMakeRange(0, [d length])].location != NSNotFound;
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  GSPdfPsTestView *v;
  NSData *pdf, *eps;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping PDF/PS output tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];
  v = [[GSPdfPsTestView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)];

  pdf = [v dataWithPDFInsideRect: [v bounds]];
  PASS(dataStartsWith(pdf, "%PDF") && [pdf length] > 100
       && dataContains(pdf, "%%EOF"),
       "dataWithPDFInsideRect produces a well-formed PDF document");

  eps = [v dataWithEPSInsideRect: [v bounds]];
  PASS(dataStartsWith(eps, "%!PS") && [eps length] > 100
       && dataContains(eps, "%%BoundingBox") && dataContains(eps, "%%EOF"),
       "dataWithEPSInsideRect produces a well-formed EPS document");

  [v release];
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
