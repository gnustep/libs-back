/*
 * Copyright (c) 2026 Simon Peter
 *
 * SPDX-License-Identifier: BSD-2-Clause OR LGPL-2.1-or-later
 */

#ifndef _XGCursorScale_h_INCLUDE
#define _XGCursorScale_h_INCLUDE

#include <stdint.h>

#define XG_CURSOR_BASE_SIZE 24

int XGCursorThemeSize(double factor, int allFactorsOne);

int XGCursorScaledLength(double points, double factor);

void XGCursorScaleARGB(const uint32_t *src, int sw, int sh,
                       uint32_t *dst, int dw, int dh);

#endif
