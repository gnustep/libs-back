/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR LGPL-2.1-or-later
 */

/* The size math of per-monitor cursors (Source/x11/cursorscale.c): a theme
 * cursor is loaded at 24 px x the factor of the monitor under the pointer,
 * except when every monitor runs at 1.0, where libXcursor keeps choosing as
 * before; image cursors are resampled from points to that monitor's pixels.
 * The source is compiled in, no display is needed. */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include "config.h"

#if defined(BUILD_SERVER) && defined(SERVER_x11) && BUILD_SERVER == SERVER_x11

#include "x11/cursorscale.c"

#define ARGB(a, r, g, b) (((uint32_t)(a) << 24) | ((uint32_t)(r) << 16) \
                          | ((uint32_t)(g) << 8) | (uint32_t)(b))

int
main(void)
{
  START_SET("cursor size per monitor")

  PASS(XGCursorThemeSize(1.0, 1) == 0,
       "all monitors at 1.0: libXcursor's own size (unchanged)");
  PASS(XGCursorThemeSize(1.0, 0) == 24,
       "a 1.0 monitor next to a scaled one: the base size");
  PASS(XGCursorThemeSize(1.25, 0) == 30,
       "a 1.25 monitor: 30 px");
  PASS(XGCursorThemeSize(2.0, 0) == 48,
       "a 2.0 monitor: 48 px");
  PASS(XGCursorThemeSize(1.1, 0) == 26,
       "a 1.1 monitor: rounded to whole pixels");
  PASS(XGCursorThemeSize(0.0, 0) == 24,
       "an unknown factor counts as 1.0");

  PASS(XGCursorScaledLength(16, 1.0) == 16, "16 pt at 1.0: 16 px");
  PASS(XGCursorScaledLength(16, 1.25) == 20, "16 pt at 1.25: 20 px");
  PASS(XGCursorScaledLength(21, 1.25) == 26, "21 pt at 1.25: 26 px");
  PASS(XGCursorScaledLength(0.2, 1.0) == 1, "never below one pixel");

  END_SET("cursor size per monitor")

  START_SET("cursor image resampling")
  {
    uint32_t src[4] = { ARGB(255, 255, 0, 0), ARGB(255, 0, 0, 255),
                        ARGB(0, 0, 0, 0),     ARGB(255, 255, 255, 255) };
    uint32_t same[4];
    uint32_t one;
    uint32_t big[16];
    int i, ok;

    XGCursorScaleARGB(src, 2, 2, same, 2, 2);
    PASS(memcmp(src, same, sizeof(src)) == 0, "the same size is a copy");

    XGCursorScaleARGB(src, 2, 2, &one, 1, 1);
    /* the average of the four premultiplied pixels */
    PASS(one == ARGB(191, 128, 64, 128),
         "shrinking averages the covered pixels (got %08x)", one);

    XGCursorScaleARGB(src, 2, 2, big, 4, 4);
    ok = 1;
    for (i = 0; i < 16; i++)
      {
        int x = i % 4, y = i / 4;

        if (big[i] != src[(y / 2) * 2 + x / 2])
          {
            ok = 0;
          }
      }
    PASS(ok, "doubling repeats each pixel 2x2");
  }
  {
    /* a one pixel wide opaque line in a 4x4 image survives 4 -> 3 */
    uint32_t src[16], dst[9];
    int i, opaque = 0;

    for (i = 0; i < 16; i++)
      {
        src[i] = (i % 4 == 1) ? ARGB(255, 0, 0, 0) : 0;
      }
    XGCursorScaleARGB(src, 4, 4, dst, 3, 3);
    for (i = 0; i < 9; i++)
      {
        if ((dst[i] >> 24) >= 128)
          {
            opaque++;
          }
      }
    PASS(opaque >= 3, "a thin stroke stays visible when shrinking");
  }
  END_SET("cursor image resampling")

  return 0;
}

#else

int
main(void)
{
  START_SET("cursor size per monitor")
    SKIP("the x11 backend is not being built")
  END_SET("cursor size per monitor")
  return 0;
}

#endif
