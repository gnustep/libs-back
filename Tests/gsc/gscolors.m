/* Tests for the device colour-space conversions in Source/gsc/gscolors.c.
 *
 * gscolors.c is backend-independent (it is part of the shared gsc code built
 * for every backend), so this test compiles the source in directly and runs
 * on every configuration with no per-backend guard.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

#include "gsc/gscolors.c"

/* Colour components are floats; compare with a small tolerance. */
static BOOL
eq(float a, float b)
{
  float d = a - b;

  return (d < 0.0001 && d > -0.0001) ? YES : NO;
}

static BOOL
isRGB(device_color_t c, float r, float g, float b)
{
  return (c.space == rgb_colorspace
    && eq(c.field[0], r) && eq(c.field[1], g) && eq(c.field[2], b))
    ? YES : NO;
}

int
main(void)
{
  START_SET("gscolors conversions")

  device_color_t	c;

  /* --- gray <-> rgb --- */
  gsMakeColor(&c, gray_colorspace, 0.4, 0, 0, 0);
  gsColorToRGB(&c);
  PASS(isRGB(c, 0.4, 0.4, 0.4), "gray converts to an equal-component rgb");

  gsMakeColor(&c, rgb_colorspace, 0.3, 0.59, 0.11 * 2, 0);
  gsColorToGray(&c);
  PASS(c.space == gray_colorspace
    && eq(c.field[0], 0.3 * 0.3 + 0.59 * 0.59 + (0.11 * 2) * 0.11),
    "rgb converts to gray using the 0.3/0.59/0.11 luma weights");

  /* --- hsb -> rgb, known values --- */
  gsMakeColor(&c, hsb_colorspace, 0.0, 1.0, 1.0, 0);
  gsColorToRGB(&c);
  PASS(isRGB(c, 1.0, 0.0, 0.0), "hsb hue 0 is red");

  gsMakeColor(&c, hsb_colorspace, 1.0 / 3.0, 1.0, 1.0, 0);
  gsColorToRGB(&c);
  PASS(isRGB(c, 0.0, 1.0, 0.0), "hsb hue 1/3 is green");

  gsMakeColor(&c, hsb_colorspace, 2.0 / 3.0, 1.0, 1.0, 0);
  gsColorToRGB(&c);
  PASS(isRGB(c, 0.0, 0.0, 1.0), "hsb hue 2/3 is blue");

  gsMakeColor(&c, hsb_colorspace, 0.5, 0.0, 0.7, 0);
  gsColorToRGB(&c);
  PASS(isRGB(c, 0.7, 0.7, 0.7),
    "hsb with zero saturation is a gray of the brightness");

  /* --- rgb -> hsb -> rgb round trips --- */
  {
    float t[][3] = {
      {1.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, {0.0, 0.0, 1.0},
      {0.2, 0.5, 0.8}, {0.9, 0.3, 0.6}, {0.5, 0.5, 0.5}
    };
    int i;
    BOOL ok = YES;

    for (i = 0; i < 6; i++)
      {
	gsMakeColor(&c, rgb_colorspace, t[i][0], t[i][1], t[i][2], 0);
	gsColorToHSB(&c);
	PASS(c.space == hsb_colorspace, "rgb->hsb sets the hsb colour space");
	gsColorToRGB(&c);
	if (!isRGB(c, t[i][0], t[i][1], t[i][2]))
	  {
	    ok = NO;
	  }
      }
    PASS(ok == YES, "rgb -> hsb -> rgb round-trips");
  }

  /* --- cmyk -> rgb, known values --- */
  gsMakeColor(&c, cmyk_colorspace, 0.0, 0.0, 0.0, 0.0);
  gsColorToRGB(&c);
  PASS(isRGB(c, 1.0, 1.0, 1.0), "cmyk all-zero is white");

  gsMakeColor(&c, cmyk_colorspace, 0.0, 0.0, 0.0, 1.0);
  gsColorToRGB(&c);
  PASS(isRGB(c, 0.0, 0.0, 0.0), "cmyk k=1 is black");

  gsMakeColor(&c, cmyk_colorspace, 1.0, 0.0, 0.0, 0.0);
  gsColorToRGB(&c);
  PASS(isRGB(c, 0.0, 1.0, 1.0), "cmyk cyan is (0,1,1) rgb");

  /* --- rgb -> cmyk -> rgb round trips, and the black-generation invariant --- */
  {
    float t[][3] = {
      {1.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, {0.0, 0.0, 1.0},
      {0.2, 0.5, 0.8}, {0.9, 0.3, 0.6}
    };
    int i;
    BOOL round = YES;
    BOOL invariant = YES;

    for (i = 0; i < 5; i++)
      {
	float r = t[i][0], g = t[i][1], b = t[i][2];
	float cc, mm, yy, kk;

	gsMakeColor(&c, rgb_colorspace, r, g, b, 0);
	gsColorToCMYK(&c);
	PASS(c.space == cmyk_colorspace, "rgb->cmyk sets the cmyk colour space");
	cc = c.field[0]; mm = c.field[1]; yy = c.field[2]; kk = c.field[3];
	/* under-colour removal keeps component + black == 1 - rgb */
	if (!eq(cc + kk, 1.0 - r) || !eq(mm + kk, 1.0 - g)
	  || !eq(yy + kk, 1.0 - b))
	  {
	    invariant = NO;
	  }
	gsColorToRGB(&c);
	if (!isRGB(c, r, g, b))
	  {
	    round = NO;
	  }
      }
    PASS(invariant == YES,
      "rgb->cmyk keeps component+black equal to 1-rgb per channel");
    PASS(round == YES, "rgb -> cmyk -> rgb round-trips");
  }

  END_SET("gscolors conversions")
  return 0;
}
