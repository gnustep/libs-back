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

+ (NSBezierPath *) bezierPathFromCairo: (cairo_t *)ct
{
  int i;
  cairo_path_t *cpath;
  cairo_path_data_t *data;
  NSBezierPath *path =[NSBezierPath bezierPath];

  cpath = cairo_copy_path (ct);

  for (i=0; i < cpath->num_data; i += cpath->data[i].header.length) 
    {
      data = &cpath->data[i];
      switch (data->header.type) 
        {
	  case CAIRO_PATH_MOVE_TO:
	    [path moveToPoint: NSMakePoint(data[1].point.x, data[1].point.y)];
	    break;
	  case CAIRO_PATH_LINE_TO:
	    [path lineToPoint: NSMakePoint(data[1].point.x, data[1].point.y)];
	    break;
	  case CAIRO_PATH_CURVE_TO:
	    [path curveToPoint: NSMakePoint(data[1].point.x, data[1].point.y) 
		 controlPoint1: NSMakePoint(data[2].point.x, data[2].point.y) 
		 controlPoint2: NSMakePoint(data[3].point.x, data[3].point.y)];
	    break;
	  case CAIRO_PATH_CLOSE_PATH:
	    [path closePath];
	    break;
	}
    }

  cairo_path_destroy(cpath);

  return path;
}

static cairo_t *__ct = NULL;

+ (void) initializeCairoBezierPath
{
  cairo_surface_t *surface;

  surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 100, 100);
  __ct = cairo_create(surface);
  cairo_surface_destroy(surface);
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
