/* Tests for the PostScript type-0 (sampled) function evaluator in
 * Source/gsc/GSFunction.m.
 *
 * GSFunction is a plain Foundation object, so this test compiles the source in
 * directly and runs on every backend with no per-backend guard.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

#include "gsc/GSFunction.m"

static BOOL
eq(double a, double b)
{
  double d = a - b;

  return (d < 0.0001 && d > -0.0001) ? YES : NO;
}

/* Build a FunctionType 0 spec dictionary. */
static NSDictionary *
spec(NSArray *size, NSArray *domain, NSArray *range, int bps,
  const void *bytes, unsigned len, NSArray *encode, NSArray *decode)
{
  NSMutableDictionary *d = [NSMutableDictionary dictionary];

  [d setObject: [NSNumber numberWithInt: 0] forKey: @"FunctionType"];
  [d setObject: [NSNumber numberWithInt: bps] forKey: @"BitsPerSample"];
  [d setObject: [NSData dataWithBytes: bytes length: len] forKey: @"DataSource"];
  [d setObject: size forKey: @"Size"];
  [d setObject: domain forKey: @"Domain"];
  [d setObject: range forKey: @"Range"];
  if (encode)
    [d setObject: encode forKey: @"Encode"];
  if (decode)
    [d setObject: decode forKey: @"Decode"];
  return d;
}

#define N(x) [NSNumber numberWithDouble: (x)]

int
main(void)
{
  START_SET("GSFunction type 0")
  ENTER_POOL

  /* --- 1-in 1-out, linear ramp over two samples --- */
  {
    unsigned char data[] = {0, 255};
    GSFunction *f = [[GSFunction alloc] initWith:
      spec([NSArray arrayWithObjects: N(2), nil],
	   [NSArray arrayWithObjects: N(0), N(1), nil],
	   [NSArray arrayWithObjects: N(0), N(1), nil],
	   8, data, 2, nil, nil)];
    double in, out;

    PASS(f != nil, "a minimal type-0 function is created");
    in = 0.0; [f eval: &in : &out];
    PASS(eq(out, 0.0), "ramp at domain minimum is 0");
    in = 1.0; [f eval: &in : &out];
    PASS(eq(out, 1.0), "ramp at domain maximum is 1");
    in = 0.5; [f eval: &in : &out];
    PASS(eq(out, 0.5), "ramp interpolates linearly at the midpoint");
    in = 0.25; [f eval: &in : &out];
    PASS(eq(out, 0.25), "ramp interpolates linearly at a quarter");
    /* inputs outside the domain clamp to the ends */
    in = -5.0; [f eval: &in : &out];
    PASS(eq(out, 0.0), "input below the domain clamps to the minimum");
    in = 99.0; [f eval: &in : &out];
    PASS(eq(out, 1.0), "input above the domain clamps to the maximum");
    RELEASE(f);
  }

  /* --- Range/Decode scales the output --- */
  {
    unsigned char data[] = {0, 255};
    GSFunction *f = [[GSFunction alloc] initWith:
      spec([NSArray arrayWithObjects: N(2), nil],
	   [NSArray arrayWithObjects: N(0), N(1), nil],
	   [NSArray arrayWithObjects: N(0), N(10), nil],
	   8, data, 2, nil, nil)];
    double in, out;

    in = 1.0; [f eval: &in : &out];
    PASS(eq(out, 10.0), "output is scaled into the range");
    in = 0.5; [f eval: &in : &out];
    PASS(eq(out, 5.0), "midpoint is scaled into the range");
    RELEASE(f);
  }

  /* --- Domain other than [0,1] is normalised --- */
  {
    unsigned char data[] = {0, 255};
    GSFunction *f = [[GSFunction alloc] initWith:
      spec([NSArray arrayWithObjects: N(2), nil],
	   [NSArray arrayWithObjects: N(0), N(2), nil],
	   [NSArray arrayWithObjects: N(0), N(1), nil],
	   8, data, 2, nil, nil)];
    double in, out;

    in = 1.0; [f eval: &in : &out];
    PASS(eq(out, 0.5), "a domain of [0,2] maps its midpoint to 0.5");
    in = 2.0; [f eval: &in : &out];
    PASS(eq(out, 1.0), "a domain of [0,2] maps its maximum to 1");
    RELEASE(f);
  }

  /* --- 16 bits per sample --- */
  {
    unsigned char data[] = {0x00, 0x00, 0xFF, 0xFF};
    GSFunction *f = [[GSFunction alloc] initWith:
      spec([NSArray arrayWithObjects: N(2), nil],
	   [NSArray arrayWithObjects: N(0), N(1), nil],
	   [NSArray arrayWithObjects: N(0), N(1), nil],
	   16, data, 4, nil, nil)];
    double in, out;

    PASS(f != nil, "a 16-bit function is created");
    in = 0.0; [f eval: &in : &out];
    PASS(eq(out, 0.0), "16-bit sample 0x0000 is 0");
    in = 1.0; [f eval: &in : &out];
    PASS(eq(out, 1.0), "16-bit sample 0xFFFF is 1");
    RELEASE(f);
  }

  /* --- rejects unsupported specs --- */
  {
    unsigned char data[] = {0, 255};
    NSMutableDictionary *d = [[spec([NSArray arrayWithObjects: N(2), nil],
	   [NSArray arrayWithObjects: N(0), N(1), nil],
	   [NSArray arrayWithObjects: N(0), N(1), nil],
	   8, data, 2, nil, nil) mutableCopy] autorelease];

    [d setObject: [NSNumber numberWithInt: 3] forKey: @"FunctionType"];
    PASS(nil == [[GSFunction alloc] initWith: d],
      "a non-zero FunctionType is rejected");
    [d setObject: [NSNumber numberWithInt: 0] forKey: @"FunctionType"];
    [d setObject: [NSNumber numberWithInt: 12] forKey: @"BitsPerSample"];
    PASS(nil == [[GSFunction alloc] initWith: d],
      "an unsupported BitsPerSample is rejected");
    [d setObject: [NSNumber numberWithInt: 8] forKey: @"BitsPerSample"];
    [d removeObjectForKey: @"DataSource"];
    PASS(nil == [[GSFunction alloc] initWith: d],
      "a missing DataSource is rejected");
  }

  /* --- 2-in 1-out bilinear interpolation --- */
  {
    /* corners indexed x + y*2: (0,0)=0 (1,0)=1 (0,1)=1 (1,1)=0 */
    unsigned char data[] = {0, 255, 255, 0};
    GSFunction *f = [[GSFunction alloc] initWith:
      spec([NSArray arrayWithObjects: N(2), N(2), nil],
	   [NSArray arrayWithObjects: N(0), N(1), N(0), N(1), nil],
	   [NSArray arrayWithObjects: N(0), N(1), nil],
	   8, data, 4, nil, nil)];
    double in[2], out;

    in[0] = 0; in[1] = 0; [f eval: in : &out];
    PASS(eq(out, 0.0), "bilinear corner (0,0)");
    in[0] = 1; in[1] = 0; [f eval: in : &out];
    PASS(eq(out, 1.0), "bilinear corner (1,0)");
    in[0] = 0; in[1] = 1; [f eval: in : &out];
    PASS(eq(out, 1.0), "bilinear corner (0,1)");
    in[0] = 1; in[1] = 1; [f eval: in : &out];
    PASS(eq(out, 0.0), "bilinear corner (1,1)");
    in[0] = 0.5; in[1] = 0.5; [f eval: in : &out];
    PASS(eq(out, 0.5), "bilinear centre is the average of the corners");
    RELEASE(f);
  }

  /* --- GSFunction2in3out must agree with the general evaluator --- */
  {
    /* 2x2 grid, 3 outputs, 8-bit: 4 samples * 3 comps = 12 bytes */
    unsigned char data[] = {
       0,  10,  20,     255, 100,  30,
      40, 200, 128,      60,  70, 250
    };
    NSDictionary *d =
      spec([NSArray arrayWithObjects: N(2), N(2), nil],
	   [NSArray arrayWithObjects: N(0), N(1), N(0), N(1), nil],
	   [NSArray arrayWithObjects: N(0), N(1), N(0), N(1), N(0), N(1), nil],
	   8, data, 12, nil, nil);
    GSFunction *base = [[GSFunction alloc] initWith: d];
    GSFunction2in3out *spc = [[GSFunction2in3out alloc] initWith: d];
    double pts[][2] = {
      {0,0}, {1,0}, {0,1}, {1,1}, {0.5,0.5}, {0.25,0.75}, {0.9,0.1}
    };
    int k;
    BOOL agree = YES;

    PASS(spc != nil, "a 2-in 3-out function is created");
    for (k = 0; k < 7; k++)
      {
	double ob[3], os[3];

	[base eval: pts[k] : ob];
	[spc eval: pts[k] : os];
	if (!eq(ob[0], os[0]) || !eq(ob[1], os[1]) || !eq(ob[2], os[2]))
	  {
	    agree = NO;
	  }
      }
    PASS(agree == YES,
      "GSFunction2in3out matches the general evaluator at every test point");

    /* affectedRect reflects the domain */
    {
      NSRect r = [spc affectedRect];

      PASS(eq(r.origin.x, 0.0) && eq(r.origin.y, 0.0)
	&& eq(r.size.width, 1.0) && eq(r.size.height, 1.0),
	"affectedRect covers the domain");
    }
    RELEASE(base);
    RELEASE(spc);
  }

  LEAVE_POOL
  END_SET("GSFunction type 0")
  return 0;
}
