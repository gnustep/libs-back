/*
 * NSBezierPathCairo.m

 * Copyright (C) 2003 Free Software Foundation, Inc.
 * April 10, 2004
 * Written by Banlu Kemiyatorn <object at gmail dot com>
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.

 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include "NSBezierPathCairo.h"

@implementation NSBezierPath (Cairo)

static void
gs_cairo_move_to(void *data, double x, double y)
{
  NSBezierPath *path = (NSBezierPath *)data;
  [path moveToPoint: NSMakePoint(x, y)];
}

static void
gs_cairo_line_to(void *data, double x, double y)
{
  NSBezierPath *path = (NSBezierPath *)data;
  [path lineToPoint: NSMakePoint(x, y)];
}

static void
gs_cairo_curve_to(void *data,
		  double x1, double y1,
		  double x2, double y2, double x3, double y3)
{
  NSBezierPath *path = (NSBezierPath *)data;
  [path curveToPoint: NSMakePoint(x1, y1) 
	controlPoint1: NSMakePoint(x2, y2) 
	controlPoint2: NSMakePoint(x3, y3)];
}

static void
gs_cairo_close_path(void *data)
{
  NSBezierPath *path = (NSBezierPath *)data;
  [path closePath];
}

+ (NSBezierPath *) bezierPathFromCairo: (cairo_t *)ct
{
  NSBezierPath *path =[NSBezierPath bezierPath];

  cairo_current_path(ct, gs_cairo_move_to, gs_cairo_line_to,
		     gs_cairo_curve_to, gs_cairo_close_path, path);

  return path;
}

static cairo_t *__ct = NULL;

+ (void) initializeCairoBezierPath
{
  __ct = cairo_create();
}

- (void) appendBezierPathToCairo: (cairo_t *)ct
{
  int i, n;
  double *dpat;
  NSPoint pts[3];
  NSBezierPathElement e;
  SEL elmsel = @selector(elementAtIndex: associatedPoints:);
  IMP elmidx = [self methodForSelector:elmsel];

  n = [self elementCount];
  for (i = 0; i < n; i++)
    {
      e = (NSBezierPathElement)(*elmidx)(self, elmsel, i, pts);
      switch (e)
	{
	case NSMoveToBezierPathElement:
	  cairo_move_to(ct, pts[0].x, pts[0].y);
	  break;
	case NSLineToBezierPathElement:
	  cairo_line_to(ct, pts[0].x, pts[0].y);
	  break;
	case NSCurveToBezierPathElement:
	  cairo_curve_to(ct, pts[0].x, pts[0].y, pts[1].x, pts[1].y,
			 pts[2].x, pts[2].y);
	  break;
	case NSClosePathBezierPathElement:
	  cairo_close_path(ct);
	  break;
	}
    }

  cairo_set_line_width(ct, _lineWidth);
  cairo_set_line_join(ct, (cairo_line_join_t)_lineJoinStyle);
  cairo_set_line_cap(ct, (cairo_line_cap_t)_lineCapStyle);
  cairo_set_miter_limit(ct, _miterLimit);

  dpat = malloc(sizeof (double) * _dash_count);
  for (i = 0; i < _dash_count; i++)
    {
      dpat[i] = _dash_pattern[i];
    }
  cairo_set_dash(ct, dpat, _dash_count, _dash_phase);
  free (dpat);
}

- (BOOL) containsFillPoint: (NSPoint)p;
{
  BOOL ret;

  cairo_new_path(__ct);
  [self appendBezierPathToCairo: __ct];
  ret = cairo_in_fill(__ct, p.x, p.y);

  return ret;
}

- (BOOL) containsStrokePoint: (NSPoint)p;
{
  BOOL ret;

  cairo_new_path (__ct);
  [self appendBezierPathToCairo:__ct];
  ret = cairo_in_stroke(__ct, p.x, p.y);

  return ret;
}

@end
