/* Tests for the art backend's software compositing kernels in
 * Source/art/blit.m, covering the additive and dissolve operators the other
 * two art compositing tests do not: plus-lighter (saturating add),
 * plus-darker (subtractive add) and dissolve (a fraction-weighted
 * source-over).
 *
 * As blit-main.m does, this defines the pixel-format macros and includes blit.m
 * once for the 24-bit RGB format, then drives the operators directly on small
 * pixel buffers.  The dissolve operators scale the source by the run's
 * fraction, so the tests set composite_run_t.fraction.  The arithmetic is plain
 * fixed point with no libart or X dependency, but it is art-backend code, so
 * the test is built only when the art backend is the one being built.
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

/* The "* a / 255" rounding the dissolve operators use for a single channel. */
static int
r255(int c, int a)
{
  return (c * a + 0xff) >> 8;
}

int
main(void)
{
  unsigned char src[3], dst[3], srca[1], dsta[1];
  composite_run_t c;

  c.src = src; c.srca = srca; c.dst = dst; c.dsta = dsta; c.fraction = 0;

  /* plus-lighter: channels add and saturate at 255. */
  src[0] = 50; src[1] = 50; src[2] = 50; srca[0] = 40;
  dst[0] = 100; dst[1] = 100; dst[2] = 100; dsta[0] = 60;
  rgb_plusl_aa(&c, 1);
  PASS(dst[0] == 150 && dst[1] == 150 && dst[2] == 150 && dsta[0] == 100,
       "plusl adds the source and destination channels");

  src[0] = 200; src[1] = 200; src[2] = 200; srca[0] = 200;
  dst[0] = 100; dst[1] = 100; dst[2] = 100; dsta[0] = 100;
  rgb_plusl_aa(&c, 1);
  PASS(dst[0] == 255 && dst[1] == 255 && dst[2] == 255 && dsta[0] == 255,
       "plusl saturates the sum at 255");

  /* plus-lighter, opaque source over a destination with alpha: the alpha
   * becomes fully opaque. */
  src[0] = 50; src[1] = 50; src[2] = 50; srca[0] = 0;
  dst[0] = 100; dst[1] = 100; dst[2] = 100; dsta[0] = 70;
  rgb_plusl_oa(&c, 1);
  PASS(dst[0] == 150 && dst[1] == 150 && dst[2] == 150 && dsta[0] == 255,
       "plusl_oa adds and sets the destination opaque");

  /* plus-lighter, both opaque, no alpha plane written. */
  src[0] = 50; src[1] = 50; src[2] = 50;
  dst[0] = 200; dst[1] = 200; dst[2] = 200;
  rgb_plusl_ao_oo(&c, 1);
  PASS(dst[0] == 250 && dst[1] == 250 && dst[2] == 250,
       "plusl_ao_oo adds the channels without an alpha plane");

  /* plus-darker: channels add with a 255 bias and clamp at 0. */
  src[0] = 200; src[1] = 200; src[2] = 200; srca[0] = 40;
  dst[0] = 200; dst[1] = 200; dst[2] = 200; dsta[0] = 60;
  rgb_plusd_aa(&c, 1);
  PASS(dst[0] == 145 && dst[1] == 145 && dst[2] == 145 && dsta[0] == 100,
       "plusd adds the channels with the darkening bias");

  src[0] = 50; src[1] = 50; src[2] = 50; srca[0] = 40;
  dst[0] = 100; dst[1] = 100; dst[2] = 100; dsta[0] = 60;
  rgb_plusd_aa(&c, 1);
  PASS(dst[0] == 0 && dst[1] == 0 && dst[2] == 0 && dsta[0] == 100,
       "plusd clamps the darkened sum at 0");

  /* plus-darker, opaque source over a destination with alpha. */
  src[0] = 200; src[1] = 200; src[2] = 200; srca[0] = 0;
  dst[0] = 200; dst[1] = 200; dst[2] = 200; dsta[0] = 60;
  rgb_plusd_oa(&c, 1);
  PASS(dst[0] == 145 && dst[1] == 145 && dst[2] == 145 && dsta[0] == 255,
       "plusd_oa darkens and sets the destination opaque");

  /* plus-darker, both opaque, no alpha plane written. */
  src[0] = 50; src[1] = 50; src[2] = 50;
  dst[0] = 100; dst[1] = 100; dst[2] = 100;
  rgb_plusd_ao_oo(&c, 1);
  PASS(dst[0] == 0 && dst[1] == 0 && dst[2] == 0,
       "plusd_ao_oo darkens the channels without an alpha plane");

  /* dissolve: the source is scaled by the run fraction, then laid over the
   * destination.  With a source over an empty destination the result is just
   * the scaled source. */
  c.fraction = 128;
  src[0] = 200; src[1] = 200; src[2] = 200; srca[0] = 255;
  dst[0] = 0; dst[1] = 0; dst[2] = 0; dsta[0] = 0;
  rgb_dissolve_aa(&c, 1);
  {
    int sas = r255(255, 128);
    int esr = r255(200, 128);
    PASS(dst[0] == esr && dst[1] == esr && dst[2] == esr && dsta[0] == sas,
         "dissolve over an empty destination gives the fraction-scaled source");
  }

  /* dissolve over an opaque destination: scaled source over the destination. */
  c.fraction = 128;
  src[0] = 200; src[1] = 200; src[2] = 200; srca[0] = 255;
  dst[0] = 100; dst[1] = 100; dst[2] = 100; dsta[0] = 200;
  rgb_dissolve_aa(&c, 1);
  {
    int sas = r255(255, 128);
    int esr = r255(200, 128) + r255(100, 255 - sas);
    int eda = sas + r255(200, 255 - sas);
    PASS(dst[0] == esr && dst[1] == esr && dst[2] == esr && dsta[0] == eda,
         "dissolve lays the fraction-scaled source over the destination");
  }

  /* dissolve with an opaque source: the source coverage is the fraction. */
  c.fraction = 128;
  src[0] = 200; src[1] = 200; src[2] = 200;
  dst[0] = 100; dst[1] = 100; dst[2] = 100; dsta[0] = 200;
  rgb_dissolve_oa(&c, 1);
  {
    int esr = r255(200, 128) + r255(100, 255 - 128);
    int eda = 128 + r255(200, 255 - 128);
    PASS(dst[0] == esr && dst[1] == esr && dst[2] == esr && dsta[0] == eda,
         "dissolve_oa uses the fraction as the source coverage");
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
