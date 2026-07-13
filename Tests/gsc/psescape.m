/* Tests that GSStreamContext escapes PostScript string specials in the text
 * show operators.  A GSStreamContext writes PostScript to a file, wrapping a
 * shown string in ( ).  Any '(', ')' or '\' in the string has to be escaped
 * with a backslash, or the emitted string is not well formed -- in particular
 * a trailing backslash would escape the closing ')' and leave the string
 * unterminated.
 *
 * GSStreamContext lives in the backend bundle, so the test needs a backend
 * loaded (hence a window server); it opens the display named by the
 * environment and skips when there is none.  The code under test is the same
 * for every backend; it is built for the cairo backend, which is the one that
 * loads on the test display.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_cairo) \
  && BUILD_GRAPHICS == GRAPHICS_cairo

#import <AppKit/AppKit.h>
#include <stdlib.h>

@interface NSObject (GSStreamContextShow)
- initWithContextInfo: (NSDictionary *)info;
- (void) DPSshow: (const char*)s;
@end

static NSString *
emitShow(Class cls, const char *s)
{
  NSString *path = [NSTemporaryDirectory()
    stringByAppendingPathComponent: @"gsc_psescape.ps"];
  NSDictionary *info = [NSDictionary dictionaryWithObject: path
                                                  forKey: @"NSOutputFile"];
  id ctxt = [[cls alloc] initWithContextInfo: info];

  if (ctxt == nil)
    return nil;
  [ctxt DPSshow: s];
  [ctxt release];    /* dealloc closes and flushes the stream */
  return [NSString stringWithContentsOfFile: path
                                   encoding: NSISOLatin1StringEncoding
                                      error: NULL];
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  Class cls;

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping PostScript escaping tests");
      DESTROY(pool);
      return 0;
    }

  [NSApplication sharedApplication];
  cls = NSClassFromString(@"GSStreamContext");
  PASS(cls != Nil, "the GSStreamContext class is available");
  if (cls == Nil)
    {
      DESTROY(pool);
      return 0;
    }

  {
    NSString *out = emitShow(cls, "a(b)c");
    PASS(out != nil
      && [out rangeOfString: @"\\("].location != NSNotFound
      && [out rangeOfString: @"\\)"].location != NSNotFound,
      "show escapes parentheses in the string");
  }

  {
    /* A backslash must be doubled, or PostScript reads it as an escape. */
    NSString *out = emitShow(cls, "a\\b");
    PASS(out != nil && [out rangeOfString: @"a\\\\b"].location != NSNotFound,
      "show escapes a backslash in the string");
  }

  {
    /* The dangerous case: an unescaped trailing backslash turns the closing
     * ) into an escaped ) and leaves the PostScript string unterminated. */
    NSString *out = emitShow(cls, "end\\");
    PASS(out != nil
      && [out rangeOfString: @"(end\\\\) show"].location != NSNotFound,
      "show escapes a trailing backslash so the string stays terminated");
  }

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
