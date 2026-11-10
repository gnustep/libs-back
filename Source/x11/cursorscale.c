/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR LGPL-2.1-or-later
 */

#include <math.h>
#include <string.h>
#include "x11/XGCursorScale.h"

int
XGCursorThemeSize(double factor, int allFactorsOne)
{
  if (allFactorsOne)
    {
      return 0;
    }
  if (factor <= 0.0)
    {
      factor = 1.0;
    }
  return (int)lround(XG_CURSOR_BASE_SIZE * factor);
}

int
XGCursorScaledLength(double points, double factor)
{
  long length = lround(points * factor);

  return (length < 1) ? 1 : (int)length;
}

static double
coverage(int i, double lo, double hi)
{
  double a = (i > lo) ? i : lo;
  double b = (i + 1 < hi) ? i + 1 : hi;

  return (b > a) ? b - a : 0.0;
}

void
XGCursorScaleARGB(const uint32_t *src, int sw, int sh,
                  uint32_t *dst, int dw, int dh)
{
  double sx = (double)sw / dw;
  double sy = (double)sh / dh;
  int dx, dy;

  if (sw == dw && sh == dh)
    {
      memcpy(dst, src, (size_t)sw * sh * sizeof(uint32_t));
      return;
    }

  for (dy = 0; dy < dh; dy++)
    {
      double y0 = dy * sy, y1 = (dy + 1) * sy;
      int ys = (int)floor(y0), ye = (int)ceil(y1);

      if (ye > sh)
        {
          ye = sh;
        }
      for (dx = 0; dx < dw; dx++)
        {
          double x0 = dx * sx, x1 = (dx + 1) * sx;
          int xs = (int)floor(x0), xe = (int)ceil(x1);
          double sum[4] = { 0, 0, 0, 0 };
          double total = 0.0;
          uint32_t out = 0;
          int x, y, c;

          if (xe > sw)
            {
              xe = sw;
            }
          for (y = ys; y < ye; y++)
            {
              double wy = coverage(y, y0, y1);

              for (x = xs; x < xe; x++)
                {
                  double w = wy * coverage(x, x0, x1);
                  uint32_t p = src[y * sw + x];

                  for (c = 0; c < 4; c++)
                    {
                      sum[c] += w * ((p >> (8 * c)) & 0xff);
                    }
                  total += w;
                }
            }
          for (c = 0; c < 4 && total > 0.0; c++)
            {
              uint32_t v = (uint32_t)(sum[c] / total + 0.5);

              out |= ((v > 255) ? 255 : v) << (8 * c);
            }
          dst[dy * dw + dx] = out;
        }
    }
}
