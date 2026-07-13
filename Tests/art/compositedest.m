/* Tests for the art backend's software compositing kernels in
 * Source/art/blit.m, covering the destination-side and remaining Porter-Duff
 * operators that Tests/art/compositing.m does not: source-atop, dest-over,
 * dest-in, dest-out, dest-atop and xor.
 *
 * As blit-main.m does, this defines the pixel-format macros and includes blit.m
 * once for the 24-bit RGB format, then drives the operators directly on small
 * pixel buffers.  The colours in these runs are premultiplied by their alpha,
 * as the compositing path stores them.  The arithmetic is plain fixed point
 * with no libart or X dependency, but it is art-backend code, so the test is
 * built only when the art backend is the one being built.
 *
 * The fully opaque and fully transparent cases are exact; the partial-coverage
 * cases are checked against the same fixed-point scaling each operator uses
 * (round-to-nearest with + 0x80 for the plain masking operators, and the
 * + 0xff the two-term operators use).
 */
#import <Foundation/NSObject.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_GRAPHICS) && defined(GRAPHICS_art) \
  && BUILD_GRAPHICS == GRAPHICS_art

/* Instantiate the kernels for the RGB format, exactly as blit-main.m does. */
#define NPRE(r, pre) pre##_##r
#define M2PRE(a, b) NPRE(a, b)
#define MPRE(r) M2PRE(r, FORMAT_INSTANCE)

#define FORMAT_INSTANCE rgb
#define FORMAT_HOW DI_24_RGB

#define BLEND_TYPE unsigned char
#define BLEND_READ(p,nr,ng,nb) nr=p[0]; ng=p[1]; nb=p[2];
#define BLEND_READ_ALPHA(p,pa,nr,ng,nb,na) nr=p[0]; ng=p[1]; nb=p[2]; na=pa[0];
#define BLEND_WRITE(p,nr,ng,nb) p[0]=nr; p[1]=ng; p[2]=nb;
#define BLEND_WRITE_ALPHA(p,pa,nr,ng,nb,na) p[0]=nr; p[1]=ng; p[2]=nb; pa[0]=na;
#define BLEND_INC(p) p+=3;

#define ALPHA_READ(s,sa,d) d=sa[0];
#define ALPHA_INC(s,sa) s+=3; sa++;

#define COPY_TYPE unsigned char
#define COPY_TYPE_PIXEL(a) unsigned char a[3];
#define COPY_ASSEMBLE_PIXEL(v,r,g,b) v[0]=r; v[1]=g; v[2]=b;
#define COPY_WRITE(dst,v) dst[0]=v[0]; dst[1]=v[1]; dst[2]=v[2];
#define COPY_INC(dst) dst+=3;

/* blit.m has no includes of its own; its includer supplies these, as
 * blit-main.m does. */
#include <math.h>
#include <string.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDebug.h>
#include "art/blit.h"

/* Gamma tables used only by the gamma-corrected blit path (not by the
 * compositing kernels tested here); blit-main.m owns the real ones. */
static unsigned char gamma_table[256], inv_gamma_table[256];

#include "art/blit.m"

/* The two fixed-point "* a / 255" roundings used by these operators. */
static int
scale80(int c, int a)
{
  return (c * a + 0x80) >> 8;
}

/* The two-term operators round the combined sum once, not each term. */
static int
blend2(int a, int wa, int b, int wb)
{
  return (a * wa + b * wb + 0xff) >> 8;
}

int
main(void)
{
  unsigned char src[3], dst[3], srca[1], dsta[1];
  composite_run_t c;

  c.src = src; c.srca = srca; c.dst = dst; c.dsta = dsta; c.fraction = 0;

  /* source-atop: src shows only where the destination is, the destination
   * keeps its own alpha.  out = src * da + dst * (1 - sa), da' = da. */
  src[0] = 60; src[1] = 60; src[2] = 60; srca[0] = 128;
  dst[0] = 200; dst[1] = 200; dst[2] = 200; dsta[0] = 200;
  rgb_satop_aa(&c, 1);
  {
    int expect = blend2(60, 200, 200, 255 - 128);
    PASS(dst[0] == expect && dst[1] == expect && dst[2] == expect
         && dsta[0] == 200,
         "satop blends the source where the destination is opaque");
  }

  /* source-atop: a transparent destination leaves nothing to draw onto. */
  src[0] = 60; src[1] = 60; src[2] = 60; srca[0] = 128;
  dst[0] = 5; dst[1] = 6; dst[2] = 7; dsta[0] = 0;
  rgb_satop_aa(&c, 1);
  PASS(dst[0] == 5 && dst[1] == 6 && dst[2] == 7 && dsta[0] == 0,
       "satop with a transparent destination leaves it unchanged");

  /* dest-over: the destination stays and the source shows through where the
   * destination is transparent.  out = dst + src * (1 - da). */
  src[0] = 80; src[1] = 80; src[2] = 80; srca[0] = 200;
  dst[0] = 100; dst[1] = 100; dst[2] = 100; dsta[0] = 100;
  rgb_dover_aa(&c, 1);
  {
    int expect = 100 + scale80(80, 255 - 100);
    int expecta = 100 + scale80(200, 255 - 100);
    PASS(dst[0] == expect && dst[1] == expect && dst[2] == expect
         && dsta[0] == expecta,
         "dover shows the source through the transparent destination");
  }

  /* dest-over: an opaque destination hides the source entirely. */
  src[0] = 80; src[1] = 80; src[2] = 80; srca[0] = 200;
  dst[0] = 100; dst[1] = 110; dst[2] = 120; dsta[0] = 255;
  rgb_dover_aa(&c, 1);
  PASS(dst[0] == 100 && dst[1] == 110 && dst[2] == 120 && dsta[0] == 255,
       "dover with an opaque destination leaves it unchanged");

  /* dest-in: the destination is kept only where the source is.
   * out = dst * sa, da' = da * sa. */
  src[0] = 0; src[1] = 0; src[2] = 0; srca[0] = 128;
  dst[0] = 200; dst[1] = 200; dst[2] = 200; dsta[0] = 180;
  rgb_din_aa(&c, 1);
  PASS(dst[0] == scale80(200, 128) && dsta[0] == scale80(180, 128),
       "din keeps the destination scaled by the source coverage");

  /* dest-in: a transparent source clears the destination. */
  src[0] = 0; src[1] = 0; src[2] = 0; srca[0] = 0;
  dst[0] = 200; dst[1] = 200; dst[2] = 200; dsta[0] = 180;
  rgb_din_aa(&c, 1);
  PASS(dst[0] == 0 && dst[1] == 0 && dst[2] == 0 && dsta[0] == 0,
       "din with a transparent source clears the destination");

  /* dest-out: the destination is kept only where the source is not.
   * out = dst * (1 - sa), da' = da * (1 - sa). */
  src[0] = 0; src[1] = 0; src[2] = 0; srca[0] = 100;
  dst[0] = 200; dst[1] = 200; dst[2] = 200; dsta[0] = 180;
  rgb_dout_aa(&c, 1);
  PASS(dst[0] == scale80(200, 255 - 100) && dsta[0] == scale80(180, 255 - 100),
       "dout keeps the destination scaled by the inverse source coverage");

  /* dest-out: an opaque source clears the destination. */
  src[0] = 0; src[1] = 0; src[2] = 0; srca[0] = 255;
  dst[0] = 200; dst[1] = 200; dst[2] = 200; dsta[0] = 180;
  rgb_dout_aa(&c, 1);
  PASS(dst[0] == 0 && dst[1] == 0 && dst[2] == 0 && dsta[0] == 0,
       "dout with an opaque source clears the destination");

  /* dest-atop: the destination shows where the source is, the source shows
   * where the destination is not.  out = dst * sa + src * (1 - da), da' = sa. */
  src[0] = 90; src[1] = 90; src[2] = 90; srca[0] = 128;
  dst[0] = 150; dst[1] = 150; dst[2] = 150; dsta[0] = 200;
  rgb_datop_aa(&c, 1);
  {
    int expect = blend2(150, 128, 90, 255 - 200);
    PASS(dst[0] == expect && dst[1] == expect && dst[2] == expect
         && dsta[0] == 128,
         "datop keeps the destination under the source and takes its alpha");
  }

  /* dest-atop: an opaque source over a transparent destination copies the
   * source. */
  src[0] = 90; src[1] = 91; src[2] = 92; srca[0] = 255;
  dst[0] = 1; dst[1] = 2; dst[2] = 3; dsta[0] = 0;
  rgb_datop_aa(&c, 1);
  PASS(dst[0] == 90 && dst[1] == 91 && dst[2] == 92 && dsta[0] == 255,
       "datop with an opaque source and empty destination copies the source");

  /* xor: each shows only where the other is not.
   * out = src * (1 - da) + dst * (1 - sa). */
  src[0] = 80; src[1] = 80; src[2] = 80; srca[0] = 128;
  dst[0] = 150; dst[1] = 150; dst[2] = 150; dsta[0] = 200;
  rgb_xor_aa(&c, 1);
  {
    int si = 255 - 128, di = 255 - 200;
    int expect = blend2(150, si, 80, di);
    int expecta = blend2(di, 255 - si, si, 255 - di);
    PASS(dst[0] == expect && dst[1] == expect && dst[2] == expect
         && dsta[0] == expecta,
         "xor shows each of source and destination where the other is not");
  }

  /* xor: an opaque source over a transparent destination copies the source. */
  src[0] = 80; src[1] = 81; src[2] = 82; srca[0] = 255;
  dst[0] = 1; dst[1] = 2; dst[2] = 3; dsta[0] = 0;
  rgb_xor_aa(&c, 1);
  PASS(dst[0] == 80 && dst[1] == 81 && dst[2] == 82 && dsta[0] == 255,
       "xor with an opaque source and empty destination copies the source");

  return 0;
}

#else

int
main(void)
{
  return 0;
}

#endif
