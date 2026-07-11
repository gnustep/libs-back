/* Tests that GSStreamContext emits the expected PostScript for the drawing
 * operators: the right operator name, the arguments in the right order, and the
 * numbers formatted locale-independently.  A GSStreamContext writes PostScript
 * to a file; the test drives one operator from each family and checks the
 * emitted lines.
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

@interface NSObject (GSStreamContextOps)
- initWithContextInfo: (NSDictionary *)info;
- (void) DPSsetrgbcolor: (CGFloat)r : (CGFloat)g : (CGFloat)b;
- (void) DPSsetgray: (CGFloat)g;
- (void) DPSsetcmykcolor: (CGFloat)c : (CGFloat)m : (CGFloat)y : (CGFloat)k;
- (void) DPSsethsbcolor: (CGFloat)h : (CGFloat)s : (CGFloat)b;
- (void) DPSsetalpha: (CGFloat)a;
- (void) DPSsetlinewidth: (CGFloat)w;
- (void) DPSsetlinecap: (int)c;
- (void) DPSsetlinejoin: (int)j;
- (void) DPSsetmiterlimit: (CGFloat)l;
- (void) DPSsetflat: (CGFloat)f;
- (void) DPSsetstrokeadjust: (int)b;
- (void) DPSsetdash: (const CGFloat*)p : (NSInteger)n : (CGFloat)o;
- (void) DPStranslate: (CGFloat)x : (CGFloat)y;
- (void) DPSscale: (CGFloat)x : (CGFloat)y;
- (void) DPSrotate: (CGFloat)a;
- (void) DPSconcat: (const CGFloat*)m;
- (void) DPSnewpath;
- (void) DPSmoveto: (CGFloat)x : (CGFloat)y;
- (void) DPSlineto: (CGFloat)x : (CGFloat)y;
- (void) DPSrmoveto: (CGFloat)x : (CGFloat)y;
- (void) DPSrlineto: (CGFloat)x : (CGFloat)y;
- (void) DPScurveto: (CGFloat)x1 : (CGFloat)y1 : (CGFloat)x2 : (CGFloat)y2 : (CGFloat)x3 : (CGFloat)y3;
- (void) DPSarc: (CGFloat)x : (CGFloat)y : (CGFloat)r : (CGFloat)a1 : (CGFloat)a2;
- (void) DPSarcn: (CGFloat)x : (CGFloat)y : (CGFloat)r : (CGFloat)a1 : (CGFloat)a2;
- (void) DPSclosepath;
- (void) DPSfill;
- (void) DPSeofill;
- (void) DPSstroke;
- (void) DPSrectfill: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h;
- (void) DPSrectclip: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h;
- (void) DPSrectstroke: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h;
- (void) DPSashow: (CGFloat)x : (CGFloat)y : (const char*)s;
- (void) DPSwidthshow: (CGFloat)x : (CGFloat)y : (int)c : (const char*)s;
- (void) DPSawidthshow: (CGFloat)cx : (CGFloat)cy : (int)c : (CGFloat)ax : (CGFloat)ay : (const char*)s;
- (void) DPScharpath: (const char*)s : (int)b;
- (void) DPSgsave;
- (void) DPSgrestore;
- (void) DPSgstate;
- (void) DPSinitmatrix;
- (void) GSSetCTM: (NSAffineTransform *)ctm;
- (void) GSConcatCTM: (NSAffineTransform *)ctm;
- (void) DPSarct: (CGFloat)x1 : (CGFloat)y1 : (CGFloat)x2 : (CGFloat)y2 : (CGFloat)r;
- (void) DPSrcurveto: (CGFloat)x1 : (CGFloat)y1 : (CGFloat)x2 : (CGFloat)y2 : (CGFloat)x3 : (CGFloat)y3;
- (void) DPSclip;
- (void) DPSeoclip;
- (void) DPSinitclip;
- (void) DPSflattenpath;
- (void) DPSreversepath;
- (void) DPScomposite: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h : (NSInteger)g : (CGFloat)dx : (CGFloat)dy : (NSCompositingOperation)op;
- (void) DPScompositerect: (CGFloat)x : (CGFloat)y : (CGFloat)w : (CGFloat)h : (NSCompositingOperation)op;
- (void) GSShowText: (const char *)s : (size_t)len;
@end

/* Every wanted line has to appear verbatim as a full line of the output. */
static BOOL
hasLines(NSArray *lines, NSArray *want)
{
  NSEnumerator *e = [want objectEnumerator];
  NSString *w;

  while ((w = [e nextObject]) != nil)
    {
      if (![lines containsObject: w])
        {
          NSLog(@"  missing PostScript line: '%@'", w);
          return NO;
        }
    }
  return YES;
}

int
main(int argc, const char **argv)
{
  CREATE_AUTORELEASE_POOL(pool);
  Class cls;
  id x;
  NSString *path, *out;
  NSArray *lines;
  CGFloat dash[2] = {3.0, 2.0};
  CGFloat m[6] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0};
  NSAffineTransform *ctm = [NSAffineTransform transform];

  if (getenv("DISPLAY") == NULL || *getenv("DISPLAY") == '\0')
    {
      NSLog(@"no window server available; skipping operator tests");
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

  path = [NSTemporaryDirectory() stringByAppendingPathComponent: @"gsc_ops.ps"];
  x = [[cls alloc] initWithContextInfo:
    [NSDictionary dictionaryWithObject: path forKey: @"NSOutputFile"]];

  [x DPSsetrgbcolor: 1.0 : 0.0 : 0.0];
  [x DPSsetgray: 0.5];
  [x DPSsetcmykcolor: 0.1 : 0.2 : 0.3 : 0.4];
  [x DPSsethsbcolor: 0.5 : 0.6 : 0.7];
  [x DPSsetalpha: 0.8];
  [x DPSsetlinewidth: 2.0];
  [x DPSsetlinecap: 1];
  [x DPSsetlinejoin: 2];
  [x DPSsetmiterlimit: 10.0];
  [x DPSsetflat: 1.5];
  [x DPSsetstrokeadjust: 1];
  [x DPSsetdash: dash : 2 : 1.0];
  [x DPStranslate: 10.0 : 20.0];
  [x DPSscale: 2.0 : 3.0];
  [x DPSrotate: 45.0];
  [x DPSconcat: m];
  [x DPSnewpath];
  [x DPSmoveto: 1.0 : 2.0];
  [x DPSlineto: 3.0 : 4.0];
  [x DPSrmoveto: 5.0 : 6.0];
  [x DPSrlineto: 7.0 : 8.0];
  [x DPScurveto: 1.0 : 2.0 : 3.0 : 4.0 : 5.0 : 6.0];
  [x DPSarc: 1.0 : 2.0 : 3.0 : 0.0 : 90.0];
  [x DPSarcn: 1.0 : 2.0 : 3.0 : 90.0 : 0.0];
  [x DPSclosepath];
  [x DPSfill];
  [x DPSeofill];
  [x DPSstroke];
  [x DPSrectfill: 0.0 : 0.0 : 10.0 : 10.0];
  [x DPSrectclip: 0.0 : 0.0 : 10.0 : 10.0];
  [x DPSrectstroke: 0.0 : 0.0 : 10.0 : 10.0];
  [x DPSashow: 1.0 : 2.0 : "hi"];
  [x DPSwidthshow: 1.0 : 2.0 : 32 : "hi"];
  [x DPSawidthshow: 1.0 : 2.0 : 32 : 3.0 : 4.0 : "hi"];
  [x DPScharpath: "hi" : 1];
  [x GSShowText: "hi" : 2];
  [x DPSgsave];
  [x DPSgrestore];
  [x DPSgstate];
  [x DPSinitmatrix];
  [ctm translateXBy: 5.0 yBy: 6.0];        /* [1 0 0 1 5 6] */
  [x GSSetCTM: ctm];
  [x GSConcatCTM: ctm];
  [x DPSarct: 1.0 : 2.0 : 3.0 : 4.0 : 5.0];
  [x DPSrcurveto: 1.0 : 2.0 : 3.0 : 4.0 : 5.0 : 6.0];
  [x DPSclip];
  [x DPSeoclip];
  [x DPSinitclip];
  [x DPSflattenpath];
  [x DPSreversepath];
  [x DPScomposite: 0.0 : 0.0 : 10.0 : 20.0 : 7 : 3.0 : 4.0 : NSCompositeSourceOver];
  [x DPScompositerect: 0.0 : 0.0 : 10.0 : 20.0 : NSCompositeSourceOver];
  [x release];        /* dealloc closes and flushes the stream */

  out = [NSString stringWithContentsOfFile: path
                                  encoding: NSISOLatin1StringEncoding
                                     error: NULL];
  lines = [(out ? out : @"") componentsSeparatedByString: @"\n"];

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"1 0 0 setrgbcolor", @"0.5 setgray", @"0.1 0.2 0.3 0.4 setcmykcolor",
    @"0.5 0.6 0.7 sethsbcolor", @"0.8 GSsetalpha", nil]),
    "the colour operators emit the expected PostScript");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"2 setlinewidth", @"1 setlinecap", @"2 setlinejoin", @"10 setmiterlimit",
    @"1.5 setflat", @"true setstrokeadjust", @"[3 2 ] 1 setdash", nil]),
    "the line-attribute operators emit the expected PostScript");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"10 20 translate", @"2 3 scale", @"45 rotate", @"[1 2 3 4 5 6 ] concat",
    nil]),
    "the matrix operators emit the expected PostScript");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"newpath", @"1 2 moveto", @"3 4 lineto", @"5 6 rmoveto", @"7 8 rlineto",
    @"1 2 3 4 5 6 curveto", @"1 2 3 0 90 arc", @"1 2 3 90 0 arcn",
    @"closepath", nil]),
    "the path-construction operators emit the expected PostScript");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"fill", @"eofill", @"stroke", @"0 0 10 10 rectfill",
    @"0 0 10 10 rectclip", @"0 0 10 10 rectstroke", nil]),
    "the paint operators emit the expected PostScript");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"1 2 (hi) ashow", @"1 2 32 (hi) widthshow",
    @"1 2 32 3 4 (hi) awidthshow", @"(hi) show", nil]),
    "the text-show operators emit the argument order PostScript expects");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"gsave", @"grestore", @"gstate", nil]),
    "the graphics-state operators emit the expected PostScript");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"initmatrix", @"[1 0 0 1 5 6 ] setmatrix", @"[1 0 0 1 5 6 ] concat", nil]),
    "the CTM operators emit the expected PostScript");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"1 2 3 4 5 arct", @"1 2 3 4 5 6 rcurveto", @"clip", @"eoclip",
    @"initclip", @"flattenpath", @"reversepath", nil]),
    "the remaining path and clip operators emit the expected PostScript");

  PASS(hasLines(lines, [NSArray arrayWithObjects:
    @"(hi) 1 charpath", @"0 0 10 20 7 3 4 2 composite",
    @"0 0 10 20 2 compositerect", nil]),
    "charpath and the composite operators emit the expected PostScript");

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
