/* Regression test for gsColorToCMYK() on a gray colour in
 * Source/gsc/gscolors.c.
 *
 * A device gray value is a brightness (0 = black, 1 = white, matching
 * gsGrayToRGB, which maps gray v to rgb (v,v,v)).  In CMYK the black channel
 * runs the other way, so gray v must become (0,0,0, 1-v): the gray -> cmyk
 * conversion has to agree with going gray -> rgb -> cmyk, and a
 * gray -> cmyk -> rgb round trip must return the original gray.
 *
 * gscolors.c is backend-independent, so this runs on every backend with no
 * per-backend guard.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

#include "gsc/gscolors.c"

static BOOL
eq(float a, float b)
{
  float d = a - b;

  return (d < 0.0001 && d > -0.0001) ? YES : NO;
}

int
main(void)
{
  START_SET("gray -> cmyk")

  device_color_t	direct;
  device_color_t	viaRGB;

  /* black and white land on the right end of the black channel */
  gsMakeColor(&direct, gray_colorspace, 0.0, 0, 0, 0);
  gsColorToCMYK(&direct);
  PASS(eq(direct.field[3], 1.0), "black (gray 0) becomes cmyk k=1");

  gsMakeColor(&direct, gray_colorspace, 1.0, 0, 0, 0);
  gsColorToCMYK(&direct);
  PASS(eq(direct.field[3], 0.0), "white (gray 1) becomes cmyk k=0");

  /* the direct gray -> cmyk path agrees with gray -> rgb -> cmyk */
  gsMakeColor(&direct, gray_colorspace, 0.75, 0, 0, 0);
  gsColorToCMYK(&direct);
  gsMakeColor(&viaRGB, gray_colorspace, 0.75, 0, 0, 0);
  gsColorToRGB(&viaRGB);
  gsColorToCMYK(&viaRGB);
  PASS(eq(direct.field[0], viaRGB.field[0])
    && eq(direct.field[1], viaRGB.field[1])
    && eq(direct.field[2], viaRGB.field[2])
    && eq(direct.field[3], viaRGB.field[3]),
    "gray -> cmyk matches gray -> rgb -> cmyk");
  PASS(eq(direct.field[0], 0.0) && eq(direct.field[1], 0.0)
    && eq(direct.field[2], 0.0) && eq(direct.field[3], 0.25),
    "gray 0.75 becomes cmyk (0,0,0,0.25)");

  /* gray -> cmyk -> rgb returns the original gray */
  gsMakeColor(&direct, gray_colorspace, 0.75, 0, 0, 0);
  gsColorToCMYK(&direct);
  gsColorToRGB(&direct);
  PASS(direct.space == rgb_colorspace
    && eq(direct.field[0], 0.75) && eq(direct.field[1], 0.75)
    && eq(direct.field[2], 0.75),
    "gray -> cmyk -> rgb returns the original gray");

  END_SET("gray -> cmyk")
  return 0;
}
