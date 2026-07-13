/* Tests for the art backend's software compositing kernels in
 * Source/art/blit.m.
 *
 * blit.m has no template of its own; blit-main.m defines a set of pixel-format
 * macros and includes it once per format.  These tests do the same for the
 * 24-bit RGB format (separate alpha planes) and then drive the Porter-Duff
 * operators directly on small pixel buffers.  They are plain integer
 * arithmetic with no libart or X dependency, but they are art-backend code, so
 * the test is built only when the art backend is the one being built.
 *
 * The fully opaque and fully transparent cases are exact; the partial-coverage
 * cases are checked against the same fixed-point scaling the operators use.
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

/* The fixed-point "* a / 255" the operators use for a single channel. */
static int
scale255(int c, int a)
{
  return (c * a + 0xff) >> 8;
}

int
main(void)
{
  unsigned char src[3], dst[3], srca[1], dsta[1];
  composite_run_t c;

  c.src = src; c.srca = srca; c.dst = dst; c.dsta = dsta; c.fraction = 0;

  /* read_pixels_o: pack an opaque RGB run into the RGBA scratch buffer. */
  {
    unsigned char in[3] = {10, 20, 30};
    unsigned char out[4] = {0, 0, 0, 0};
    composite_run_t r = {0};

    r.src = in;
    r.dst = out;
    rgb_read_pixels_o(&r, 1);
    PASS(out[0] == 10 && out[1] == 20 && out[2] == 30 && out[3] == 0xff,
         "read_pixels_o copies RGB and sets alpha to 255");
  }

  /* source-over: opaque source replaces the destination. */
  src[0] = 100; src[1] = 150; src[2] = 200; srca[0] = 255;
  dst[0] = 10;  dst[1] = 20;  dst[2] = 30;  dsta[0] = 128;
  rgb_sover_aa(&c, 1);
  PASS(dst[0] == 100 && dst[1] == 150 && dst[2] == 200 && dsta[0] == 255,
       "sover with an opaque source replaces the destination");

  /* source-over: a fully transparent source leaves the destination alone. */
  src[0] = 100; src[1] = 150; src[2] = 200; srca[0] = 0;
  dst[0] = 10;  dst[1] = 20;  dst[2] = 30;  dsta[0] = 128;
  rgb_sover_aa(&c, 1);
  PASS(dst[0] == 10 && dst[1] == 20 && dst[2] == 30 && dsta[0] == 128,
       "sover with a transparent source leaves the destination unchanged");

  /* source-over: partial source over opaque destination (premultiplied):
   * out = src + dst * (255 - srca)/255, alpha saturates to 255. */
  src[0] = 100; src[1] = 100; src[2] = 100; srca[0] = 128;
  dst[0] = 200; dst[1] = 200; dst[2] = 200; dsta[0] = 255;
  rgb_sover_aa(&c, 1);
  {
    int expect = 100 + scale255(200, 255 - 128);
    PASS(dst[0] == expect && dst[1] == expect && dst[2] == expect
         && dsta[0] == 255,
         "sover blends a partial source over the destination");
  }

  /* source-in: masked by the destination alpha. Opaque dst keeps the source. */
  src[0] = 50; src[1] = 60; src[2] = 70; srca[0] = 200;
  dst[0] = 1;  dst[1] = 2;  dst[2] = 3;  dsta[0] = 255;
  rgb_sin_aa(&c, 1);
  PASS(dst[0] == 50 && dst[1] == 60 && dst[2] == 70 && dsta[0] == 200,
       "sin with an opaque destination keeps the source");

  /* source-in: a transparent destination clears the result. */
  src[0] = 50; src[1] = 60; src[2] = 70; srca[0] = 200;
  dst[0] = 1;  dst[1] = 2;  dst[2] = 3;  dsta[0] = 0;
  rgb_sin_aa(&c, 1);
  PASS(dst[0] == 0 && dst[1] == 0 && dst[2] == 0 && dsta[0] == 0,
       "sin with a transparent destination clears the result");

  /* source-out: masked by (1 - destination alpha). Opaque dst clears it. */
  src[0] = 50; src[1] = 60; src[2] = 70; srca[0] = 200;
  dst[0] = 1;  dst[1] = 2;  dst[2] = 3;  dsta[0] = 255;
  rgb_sout_aa(&c, 1);
  PASS(dst[0] == 0 && dst[1] == 0 && dst[2] == 0 && dsta[0] == 0,
       "sout with an opaque destination clears the result");

  /* source-out: a transparent destination keeps the whole source. */
  src[0] = 50; src[1] = 60; src[2] = 70; srca[0] = 200;
  dst[0] = 1;  dst[1] = 2;  dst[2] = 3;  dsta[0] = 0;
  rgb_sout_aa(&c, 1);
  PASS(dst[0] == 50 && dst[1] == 60 && dst[2] == 70 && dsta[0] == 200,
       "sout with a transparent destination keeps the source");

  /* source-out with an opaque source (sout_oa): the destination alpha is
   * inverted and the source is scaled by it, rounded to nearest (+ 0x80) as
   * this operator does. */
  src[0] = 50; src[1] = 50; src[2] = 50;
  dst[0] = 1;  dst[1] = 2;  dst[2] = 3;  dsta[0] = 152;
  rgb_sout_oa(&c, 1);
  {
    int expect = (50 * (255 - 152) + 0x80) >> 8;
    PASS(dst[0] == expect && dst[1] == expect && dst[2] == expect
         && dsta[0] == (255 - 152),
         "sout_oa scales the source over the inverted destination alpha");
  }

  return 0;
}

#else

int
main(void)
{
  return 0;
}

#endif
