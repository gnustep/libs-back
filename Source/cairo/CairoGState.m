/*
 * CairoGState.m

 * Copyright (C) 2003 Free Software Foundation, Inc.
 * August 31, 2003
 * Written by Banlu Kemiyatorn <object at gmail dot com>
 * Rewrite: Fred Kiefer <fredkiefer@gmx.de>
 * Date: Jan 2006
 *
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

#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSGraphics.h>
#include "cairo/CairoGState.h"
#include "cairo/CairoFontInfo.h"
#include "cairo/CairoSurface.h"
#include "cairo/CairoContext.h"
#include <math.h>

#define FIXME()  NSLog(@":::FIXME::: %@ %s", [self description], sel_get_name(_cmd))

@implementation CairoGState 

+ (void) initialize
{
  if (self == [CairoGState class])
    {
    }
}

- (void) dealloc
{
  if (_ct)
    {
      cairo_destroy(_ct);
    }
  RELEASE(_surface);

  [super dealloc];
}

- (id) copyWithZone: (NSZone *)zone
{
  CairoGState *copy = (CairoGState *)[super copyWithZone: zone];

  if (_ct)
    {
      cairo_path_t *cpath;
      cairo_status_t status;
      cairo_matrix_t local_matrix;
 
      // FIXME: Need some way to do a copy
      //cairo_copy(copy->_ct, _ct);
      copy->_ct = cairo_create(cairo_get_target(_ct));
      cairo_get_matrix(_ct, &local_matrix);
      cairo_set_matrix(copy->_ct, &local_matrix);
      cpath = cairo_copy_path(_ct);
      cairo_append_path(copy->_ct, cpath);
      cairo_path_destroy(cpath);
      
      cairo_set_operator(copy->_ct, cairo_get_operator(_ct));
      cairo_set_source(copy->_ct, cairo_get_source(_ct));
      cairo_set_tolerance(copy->_ct, cairo_get_tolerance(_ct));
      cairo_set_antialias(copy->_ct, cairo_get_antialias(_ct));
      cairo_set_line_width(copy->_ct, cairo_get_line_width(_ct));
      cairo_set_line_cap(copy->_ct, cairo_get_line_cap(_ct));
      cairo_set_line_join(copy->_ct, cairo_get_line_join(_ct));
      cairo_set_miter_limit(copy->_ct, cairo_get_miter_limit(_ct));
      //NSLog(@"copy gstate old %d new %d", _ct, copy->_ct);
 
      status = cairo_status(copy->_ct);
      if (status != CAIRO_STATUS_SUCCESS)
        {
	  NSLog(@"Cairo status %s in copy", cairo_status_to_string(status));
	}
    }

  RETAIN(_surface);

  return copy;
}

- (void) GSCurrentDevice: (void **)device: (int *)x : (int *)y
{
  if (x)
    *x = offset.x;
  if (y)
    *y = offset.y;
  if (device)
    {
      if (_surface)
	{
	  *device = _surface->gsDevice;
	}
      else
	{
	  *device = NULL;
	  NSLog(@":::FIXME::: surface isn't set. %@ %s", [self description],
		sel_get_name(_cmd));
	}
    }
}

- (void) GSSetDevice: (void *)device : (int)x : (int)y
{
  DESTROY(_surface);
  _surface = [[CairoSurface alloc] initWithDevice: device];
  [self setOffset: NSMakePoint(x, y)];
  [self DPSinitgraphics];
}

- (void) setOffset: (NSPoint)theOffset
{
  NSSize size = {0, 0};

  if (_surface != nil)
    {
      size = [_surface size];
    }
  [super setOffset: theOffset];
  cairo_surface_set_device_offset([_surface surface], -theOffset.x, 
				  theOffset.y - size.height);
}

/*
 * Color operations
 */
- (void) setColor: (device_color_t *)color state: (color_state_t)cState
{
  device_color_t c;

  [super setColor: color state: cState];
  if (_ct == NULL)
    {
      /* Window device isn't set yet */
      return;
    }
  c = *color;
  gsColorToRGB(&c);
  // FIXME: The underlying concept does not allow to determine if alpha is set or not.
  if (c.field[AINDEX] > 0.0)
    {
      cairo_set_source_rgba(_ct, c.field[0], c.field[1], c.field[2], 
			    c.field[AINDEX]);
    }
  else 
    {
      cairo_set_source_rgb(_ct, c.field[0], c.field[1], c.field[2]);
    }
}

- (void) GSSetPatterColor: (NSImage*)image 
{
  // FIXME: Create a cairo surface from the image and set it as source.
  [super GSSetPatterColor: image];
}

- (NSPoint) pointInMatrixSpace: (NSPoint)aPoint
{
  return [[self GSCurrentCTM] pointInMatrixSpace: aPoint];
}

- (NSPoint) deltaPointInMatrixSpace: (NSPoint)aPoint
{
  return [[self GSCurrentCTM] deltaPointInMatrixSpace: aPoint];
}

- (NSRect) rectInMatrixSpace: (NSRect)rect
{
  return [[self GSCurrentCTM] rectInMatrixSpace: rect];
}

/*
 * Text operations
 */

- (void) DPScharpath: (const char *)s : (int)b
{
  char *c = malloc(b + 1);

  memcpy(c, s, b);
  c[b] = 0;
  cairo_text_path(_ct, c);
  free(c);
}

- (void) DPSshow: (const char *)s
{
  cairo_show_text(_ct, s);
}

- (void) GSSetFont: (GSFontInfo *)fontref
{
  cairo_matrix_t font_matrix;
  const float *matrix; 

  [super GSSetFont: fontref];

  matrix = [font matrix];
  cairo_set_font_face(_ct, [((CairoFontInfo *)font)->_faceInfo fontFace]);
  cairo_matrix_init(&font_matrix, matrix[0], matrix[1], matrix[2],
		    -matrix[3], matrix[4], matrix[5]);
  cairo_set_font_matrix(_ct, &font_matrix);
}

- (void) GSSetFontSize: (float)size
{
  cairo_set_font_size(_ct, size);
}

- (void) GSShowText: (const char *)string : (size_t)length
{
  char *c = malloc(length + 1);

  memcpy(c, string, length);
  c[length] = 0;
  cairo_show_text(_ct, c);
  free(c);
}

- (void) GSShowGlyphs: (const NSGlyph *)glyphs : (size_t)length
{
  [(CairoFontInfo *)font drawGlyphs: glyphs
		    length: length
		    on: _ct];
}

/*
 * GState operations
 */

- (void) DPSinitgraphics
{
  cairo_status_t status;

  [super DPSinitgraphics];

  if (_ct)
    {
      cairo_destroy(_ct);
    }
  if (!_surface)
    {
      return;
    }
  _ct = cairo_create([_surface surface]);
  status = cairo_status(_ct);
  if (status != CAIRO_STATUS_SUCCESS)
    {
      NSLog(@"Cairo status %s in DPSinitgraphics", cairo_status_to_string(status));
    }
  [self DPSinitmatrix];

  /* Cairo's default line width is 2.0 */
  cairo_set_line_width(_ct, 1.0);
  cairo_set_operator(_ct, CAIRO_OPERATOR_OVER);
}

- (void) DPScurrentflat: (float *)flatness
{
  *flatness = cairo_get_tolerance(_ct);
}

- (void) DPScurrentlinecap: (int *)linecap
{
  cairo_line_cap_t lc;

  lc = cairo_get_line_cap(_ct);
  *linecap = lc;
  /*
     switch (lc)
     {
     case CAIRO_LINE_CAP_BUTT:
     *linecap = 0;
     break;
     case CAIRO_LINE_CAP_ROUND:
     *linecap = 1;
     break;
     case CAIRO_LINE_CAP_SQUARE:
     *linecap = 2;
     break;
     default:
     NSLog(@"ERROR Line cap unknown");
     exit(-1);
     }
   */
}

- (void) DPScurrentlinejoin: (int *)linejoin
{
  cairo_line_join_t lj;

  lj = cairo_get_line_join(_ct);
  *linejoin = lj;
  /*
     switch (lj)
     {
     case CAIRO_LINE_JOIN_MITER:
     *linejoin = 0;
     break;
     case CAIRO_LINE_JOIN_ROUND:
     *linejoin = 1;
     break;
     case CAIRO_LINE_JOIN_BEVEL:
     *linejoin = 2;
     break;
     default:
     NSLog(@"ERROR Line join unknown");
     exit(-1);
     }
   */
}

- (void) DPScurrentlinewidth: (float *)width
{
  *width = cairo_get_line_width(_ct);
}

- (void) DPScurrentmiterlimit: (float *)limit
{
  *limit = cairo_get_miter_limit(_ct);
}

- (NSPoint) currentPoint
{
  double dx, dy;

  cairo_get_current_point(_ct, &dx, &dy);
  return NSMakePoint(dx, dy);
}

- (void) DPScurrentstrokeadjust: (int *)b
{
  FIXME();
}

- (void) DPSsetdash: (const float *)pat : (int)size : (float)doffset
{
  double *dpat;
  int i;

  i = size;
  dpat = malloc(sizeof(double) * size);
  while (i)
    {
      i--;
      dpat[i] = pat[i];
    }
  cairo_set_dash(_ct, dpat, size, doffset);
  free(dpat);
}

- (void) DPSsetflat: (float)flatness
{
  cairo_set_tolerance(_ct, flatness);
}

- (void) DPSsetlinecap: (int)linecap
{
  cairo_set_line_cap(_ct, (cairo_line_cap_t)linecap);
}

- (void) DPSsetlinejoin: (int)linejoin
{
  cairo_set_line_join(_ct, (cairo_line_join_t)linejoin);
}

- (void) DPSsetlinewidth: (float)width
{
  cairo_set_line_width(_ct, width);
}

- (void) DPSsetmiterlimit: (float)limit
{
  cairo_set_miter_limit(_ct, limit);
}

- (void) DPSsetstrokeadjust: (int)b
{
  FIXME();
}

/*
 * Matrix operations
 */

// FIXME: All matrix and path operations need to call the super implemantion
// to get the complex methods of the super class to work correctly.

- (void) DPSconcat: (const float *)m
{
  cairo_matrix_t local_matrix;

  if (_ct)
    {
      cairo_matrix_init(&local_matrix, m[0], m[1], m[2], m[3], m[4], m[5]);
      cairo_transform(_ct, &local_matrix);
    }
}

- (void) DPSinitmatrix
{
  if (_ct)
    {
      cairo_identity_matrix(_ct);
      if (!viewIsFlipped)
        {
	  cairo_matrix_t local_matrix;
	  
	  // cairo draws the other way around.
	  cairo_matrix_init_scale(&local_matrix, 1, -1);
	  
	  if (_surface != nil)
	    {
	      cairo_matrix_translate(&local_matrix, 0,  -[_surface size].height);
	    }
	  cairo_set_matrix(_ct, &local_matrix);
	}
    }
}

- (void) DPSrotate: (float)angle
{
  if (_ct)
    {
      cairo_rotate(_ct, angle);
    }
}

- (void) DPSscale: (float)x : (float)y
{
  if (_ct)
    {
      cairo_scale(_ct, x, y);
    }
}

- (void) DPStranslate: (float)x : (float)y
{
  if (_ct)
    {
      cairo_translate(_ct, x, y);
    }
}

- (NSAffineTransform *) GSCurrentCTM
{
  NSAffineTransform *transform;
  NSAffineTransformStruct tstruct;
  cairo_matrix_t flip_matrix;
  cairo_matrix_t local_matrix;

  transform = [NSAffineTransform transform];
  if (_ct)
    {
      cairo_get_matrix(_ct, &local_matrix);

      // Undo changes in DPSinitmatrix
      if (!viewIsFlipped)
        {
	  cairo_matrix_init_scale(&flip_matrix, 1, -1);
	  cairo_matrix_multiply(&local_matrix, &local_matrix, &flip_matrix);
	  
	  if (_surface)
	    {
	      cairo_matrix_init_translate(&flip_matrix, 0, [_surface size].height);
	      cairo_matrix_multiply(&local_matrix, &local_matrix, &flip_matrix);
	    }
	}
      
      tstruct.m11 = local_matrix.xx;
      tstruct.m12 = local_matrix.yx;
      tstruct.m21 = local_matrix.xy;
      tstruct.m22 = local_matrix.yy;
      tstruct.tX = local_matrix.x0;
      tstruct.tY = local_matrix.y0;
      [transform setTransformStruct: tstruct];
    }

  return transform;
}

- (void) GSSetCTM: (NSAffineTransform *)newCtm
{
  [self DPSinitmatrix];
  [self GSConcatCTM: newCtm];
}

- (void) GSConcatCTM: (NSAffineTransform *)newCtm
{
  NSAffineTransformStruct tstruct;
  cairo_matrix_t local_matrix;

  if (_ct)
    {
      tstruct =  [newCtm transformStruct];
      cairo_matrix_init(&local_matrix,
			tstruct.m11, tstruct.m12,
			tstruct.m21, tstruct.m22, 
			tstruct.tX, tstruct.tY);
      cairo_transform(_ct, &local_matrix);
    }
}

/*
 * Paint operations
 */

- (void) DPSarc: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2
{
  cairo_arc(_ct, x, y, r, angle1 * M_PI / 180, angle2 * M_PI / 180);
}

- (void) DPSarcn: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2
{
  cairo_arc_negative(_ct, x, y, r, angle1 * M_PI / 180, angle2 * M_PI / 180);
}

- (void)DPSarct: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)r 
{
  // FIXME: Still missing in cairo
  //cairo_arc_to(_ct, x1, y1, x2, y2, r);
}

- (void) DPSclip
{
  cairo_clip(_ct);
}

- (void) DPSclosepath
{
  cairo_close_path(_ct);
}

- (void) DPScurveto: (float)x1 : (float)y1 : (float)x2 
		   : (float)y2 : (float)x3 : (float)y3
{
  cairo_curve_to(_ct, x1, y1, x2, y2, x3, y3);
}

- (void) DPSeoclip
{
  cairo_set_fill_rule(_ct, CAIRO_FILL_RULE_EVEN_ODD);
  cairo_clip(_ct);
  cairo_set_fill_rule(_ct, CAIRO_FILL_RULE_WINDING);
}

- (void) DPSeofill
{
  cairo_set_fill_rule(_ct, CAIRO_FILL_RULE_EVEN_ODD);
  cairo_fill(_ct);
  cairo_set_fill_rule(_ct, CAIRO_FILL_RULE_WINDING);
}

- (void) DPSfill
{
  cairo_fill(_ct);
}

- (void) DPSflattenpath
{
  cairo_path_t *cpath;

  cpath = cairo_copy_path_flat(_ct);
  cairo_new_path(_ct);
  cairo_append_path(_ct, cpath);
  cairo_path_destroy(cpath);
}

- (void) DPSinitclip
{
  cairo_reset_clip(_ct);
}

- (void) DPSlineto: (float)x : (float)y
{
  cairo_line_to(_ct, x, y);
}

- (void) DPSmoveto: (float)x : (float)y
{
  cairo_move_to(_ct, x, y);
}

- (void) DPSnewpath
{
  cairo_new_path(_ct);
}

- (NSBezierPath *) bezierPath
{
  int i;
  cairo_path_t *cpath;
  cairo_path_data_t *data;
  NSBezierPath *bpath =[NSBezierPath bezierPath];

  cpath = cairo_copy_path(_ct);

  for (i=0; i < cpath->num_data; i += cpath->data[i].header.length) 
    {
      data = &cpath->data[i];
      switch (data->header.type) 
        {
	  case CAIRO_PATH_MOVE_TO:
	    [bpath moveToPoint: NSMakePoint(data[1].point.x, data[1].point.y)];
	    break;
	  case CAIRO_PATH_LINE_TO:
	    [bpath lineToPoint: NSMakePoint(data[1].point.x, data[1].point.y)];
	    break;
	  case CAIRO_PATH_CURVE_TO:
	    [bpath curveToPoint: NSMakePoint(data[1].point.x, data[1].point.y) 
		   controlPoint1: NSMakePoint(data[2].point.x, data[2].point.y) 
		   controlPoint2: NSMakePoint(data[3].point.x, data[3].point.y)];
	    break;
	  case CAIRO_PATH_CLOSE_PATH:
	    [bpath closePath];
	    break;
	}
    }

  cairo_path_destroy(cpath);

  return bpath;
}

- (void) DPSrcurveto: (float)x1 : (float)y1 : (float)x2 
		    : (float)y2 : (float)x3 : (float)y3
{
  cairo_rel_curve_to(_ct, x1, y1, x2, y2, x3, y3);
}

- (void) DPSrectclip: (float)x : (float)y : (float)w : (float)h
{
  cairo_new_path(_ct);
  cairo_move_to(_ct, x, y);
  cairo_rel_line_to(_ct, w, 0);
  cairo_rel_line_to(_ct, 0, h);
  cairo_rel_line_to(_ct, -w, 0);
  cairo_close_path(_ct);
  cairo_clip(_ct);
  cairo_new_path(_ct);
}

- (void) DPSrectfill: (float)x : (float)y : (float)w : (float)h
{
  cairo_save(_ct);
  cairo_new_path(_ct);
  cairo_move_to(_ct, x, y);
  cairo_rel_line_to(_ct, w, 0);
  cairo_rel_line_to(_ct, 0, h);
  cairo_rel_line_to(_ct, -w, 0);
  cairo_close_path(_ct);
  cairo_fill(_ct);
  cairo_restore(_ct);
}

- (void) DPSrectstroke: (float)x : (float)y : (float)w : (float)h
{
  cairo_save(_ct);
  cairo_new_path(_ct);
  cairo_move_to(_ct, x, y);
  cairo_rel_line_to(_ct, w, 0);
  cairo_rel_line_to(_ct, 0, h);
  cairo_rel_line_to(_ct, -w, 0);
  cairo_close_path(_ct);
  cairo_stroke(_ct);
  cairo_restore(_ct);
}

- (void) DPSreversepath
{
  NSBezierPath *bpath = [self bezierPath];

  bpath = [bpath bezierPathByReversingPath];
  [self GSSendBezierPath: bpath];
}

- (void) DPSrlineto: (float)x : (float)y
{
  cairo_rel_line_to(_ct, x, y);
}

- (void) DPSrmoveto: (float)x : (float)y
{
  cairo_rel_move_to(_ct, x, y);
}

- (void) DPSstroke
{
  cairo_stroke(_ct);
}

- (void) GSSendBezierPath: (NSBezierPath *)bpath
{
  int i, n;
  int count = 10;
  float dash_pattern[10];
  float phase;
  NSPoint pts[3];
  NSBezierPathElement e;
  SEL elmsel = @selector(elementAtIndex: associatedPoints:);
  IMP elmidx = [bpath methodForSelector: elmsel];

  cairo_new_path(_ct);

  n = [bpath elementCount];
  for (i = 0; i < n; i++)
    {
      e = (NSBezierPathElement)(*elmidx)(bpath, elmsel, i, pts);
      switch (e)
	{
	case NSMoveToBezierPathElement:
	  cairo_move_to(_ct, pts[0].x, pts[0].y);
	  break;
	case NSLineToBezierPathElement:
	  cairo_line_to(_ct, pts[0].x, pts[0].y);
	  break;
	case NSCurveToBezierPathElement:
	  cairo_curve_to(_ct, pts[0].x, pts[0].y, pts[1].x, pts[1].y,
			 pts[2].x, pts[2].y);
	  break;
	case NSClosePathBezierPathElement:
	  cairo_close_path(_ct);
	  break;
	}
    }

  cairo_set_line_width(_ct, [bpath lineWidth]);
  cairo_set_line_join(_ct, (cairo_line_join_t)[bpath lineJoinStyle]);
  cairo_set_line_cap(_ct, (cairo_line_cap_t)[bpath lineCapStyle]);
  cairo_set_miter_limit(_ct, [bpath miterLimit]);
  cairo_set_tolerance(_ct, [bpath flatness]);

  [bpath getLineDash: dash_pattern count: &count phase: &phase];
  [self DPSsetdash: dash_pattern : count : phase];
}

- (NSDictionary *) GSReadRect: (NSRect)r
{
  NSMutableDictionary *dict;
  NSSize ssize;
  NSAffineTransform *matrix;
  double x, y;
  int ix, iy;
  cairo_format_t format = CAIRO_FORMAT_ARGB32;
  cairo_surface_t *surface;
  cairo_surface_t *isurface;
  cairo_t *ct;
  int size;
  int i;
  NSMutableData *data;
  unsigned char *cdata;

  x = NSWidth(r);
  y = NSHeight(r);
  cairo_user_to_device_distance(_ct, &x, &y);
  ix = floor(x);
  iy = -floor(y);
  ssize = NSMakeSize(ix, iy);

/*
  NSLog(@"rect %@ size %@", NSStringFromRect(r), NSStringFromSize(ssize));
 */

  dict = [NSMutableDictionary dictionary];
  [dict setObject: [NSValue valueWithSize: ssize] forKey: @"Size"];
  [dict setObject: NSDeviceRGBColorSpace forKey: @"ColorSpace"];
  
  [dict setObject: [NSNumber numberWithUnsignedInt: 8] forKey: @"BitsPerSample"];
  [dict setObject: [NSNumber numberWithUnsignedInt: 32]
	forKey: @"Depth"];
  [dict setObject: [NSNumber numberWithUnsignedInt: 4] 
	forKey: @"SamplesPerPixel"];
  [dict setObject: [NSNumber numberWithUnsignedInt: 1]
	forKey: @"HasAlpha"];

  matrix = [self GSCurrentCTM];
  [matrix translateXBy: -r.origin.x - offset.x 
	  yBy: r.origin.y + NSHeight(r) - offset.y];
  [dict setObject: matrix forKey: @"Matrix"];

  size = ix*iy*4;
  data = [NSMutableData dataWithLength: size];
  if (data == nil)
    return nil;
  cdata = [data mutableBytes];

  surface = cairo_get_target(_ct);
  isurface = cairo_image_surface_create_for_data(cdata, format, ix, iy, 4*ix);
  ct = cairo_create(isurface);

  if (viewIsFlipped)
    {
      cairo_matrix_t local_matrix;

      cairo_matrix_init_scale(&local_matrix, 1, -1);
      cairo_matrix_translate(&local_matrix, 0, -iy);
      cairo_set_matrix(ct, &local_matrix);
    }

  cairo_set_source_surface(ct, surface, -r.origin.x, -r.origin.y);
  cairo_rectangle(ct, 0, 0, ix, iy);
  cairo_fill(ct);
  cairo_destroy(ct);
  cairo_surface_destroy(isurface);

  for (i = 0; i < ix * iy; i++)
    {
      unsigned char d = cdata[4*i];

#if GS_WORDS_BIGENDIAN
      cdata[4*i] = cdata[4*i + 1];
      cdata[4*i + 1] = cdata[4*i + 2];
      cdata[4*i + 2] = cdata[4*i + 3];
      cdata[4*i + 3] = d;
#else
      cdata[4*i] = cdata[4*i + 2];
      //cdata[4*i + 1] = cdata[4*i + 1];
      cdata[4*i + 2] = d;
      //cdata[4*i + 3] = cdata[4*i + 3];
#endif 
    }

  [dict setObject: data forKey: @"Data"];

  return dict;
}

static void
_set_op(cairo_t *ct, NSCompositingOperation op)
{
  switch (op)
    {
    case NSCompositeClear:
      cairo_set_operator(ct, CAIRO_OPERATOR_CLEAR);
      break;
    case NSCompositeCopy:
      cairo_set_operator(ct, CAIRO_OPERATOR_SOURCE);
      break;
    case NSCompositeSourceOver:
      cairo_set_operator(ct, CAIRO_OPERATOR_OVER);
      break;
    case NSCompositeSourceIn:
      cairo_set_operator(ct, CAIRO_OPERATOR_IN);
      break;
    case NSCompositeSourceOut:
      cairo_set_operator(ct, CAIRO_OPERATOR_OUT);
      break;
    case NSCompositeSourceAtop:
      cairo_set_operator(ct, CAIRO_OPERATOR_ATOP);
      break;
    case NSCompositeDestinationOver:
      cairo_set_operator(ct, CAIRO_OPERATOR_DEST_OVER);
      break;
    case NSCompositeDestinationIn:
      cairo_set_operator(ct, CAIRO_OPERATOR_DEST_IN);
      break;
    case NSCompositeDestinationOut:
      cairo_set_operator(ct, CAIRO_OPERATOR_DEST_OUT);
      break;
    case NSCompositeDestinationAtop:
      cairo_set_operator(ct, CAIRO_OPERATOR_DEST_ATOP);
      break;
    case NSCompositeXOR:
      cairo_set_operator(ct, CAIRO_OPERATOR_XOR);
      break;
    case NSCompositePlusDarker:
      // FIXME
      break;
    case NSCompositeHighlight:
      cairo_set_operator(ct, CAIRO_OPERATOR_SATURATE);
      break;
    case NSCompositePlusLighter:
      cairo_set_operator(ct, CAIRO_OPERATOR_ADD);
      break;
    default:
      cairo_set_operator(ct, CAIRO_OPERATOR_SOURCE);
    }
}

- (void) DPSimage: (NSAffineTransform *)matrix : (int)pixelsWide
		 : (int)pixelsHigh : (int)bitsPerSample 
		 : (int)samplesPerPixel : (int)bitsPerPixel
		 : (int)bytesPerRow : (BOOL)isPlanar
		 : (BOOL)hasAlpha : (NSString *)colorSpaceName
		 : (const unsigned char *const[5])data
{
  cairo_format_t format;
  NSAffineTransformStruct tstruct;
  cairo_surface_t *surface;
  unsigned char	*tmp;
  int i = 0;
  int j;
  int index;
  unsigned int pixels = pixelsHigh * pixelsWide;
  const unsigned char *bits = data[0];
  unsigned char *rowData;
  cairo_matrix_t local_matrix;

/*
  NSLog(@"%@ DPSimage %dx%d (%p)", self, pixelsWide, pixelsHigh,
        cairo_get_target(_ct));
*/
  if (isPlanar || !([colorSpaceName isEqualToString: NSDeviceRGBColorSpace] ||
		    [colorSpaceName isEqualToString: NSCalibratedRGBColorSpace]))
    {
      NSLog(@"Image format not support");
      return;
    }

  // default is 8 bit grayscale 
  if (!bitsPerSample)
    bitsPerSample = 8;
  if (!samplesPerPixel)
    samplesPerPixel = 1;

  // FIXME - does this work if we are passed a planar image but no hints ?
  if (!bitsPerPixel)
    bitsPerPixel = bitsPerSample * samplesPerPixel;
  if (!bytesPerRow)
    bytesPerRow = (bitsPerPixel * pixelsWide) / 8;

  /* make sure its sane - also handles row padding if hint missing */
  while ((bytesPerRow * 8) < (bitsPerPixel * pixelsWide))
    bytesPerRow++;

  switch (bitsPerPixel)
    {
    case 32:
      rowData = (unsigned char *)bits;
      tmp = objc_malloc(pixels * 4);
      index = 0;

      for (i = 0; i < pixelsHigh; i++)
        {
	  unsigned char *d = rowData;

	  for (j = 0; j < pixelsWide; j++)
	  {
#if GS_WORDS_BIGENDIAN
	      tmp[index++] = d[3];
	      tmp[index++] = d[0];
	      tmp[index++] = d[1];
	      tmp[index++] = d[2];
#else
	      tmp[index++] = d[2];
	      tmp[index++] = d[1];
	      tmp[index++] = d[0];
	      tmp[index++] = d[3];
#endif 
	      d += 4;
	    }
	  rowData += bytesPerRow;
	}
      bits = tmp;
      format = CAIRO_FORMAT_ARGB32;
      break;
    case 24:
      rowData = (unsigned char *)bits;
      tmp = objc_malloc(pixels * 4);
      index = 0;

      for (i = 0; i < pixelsHigh; i++)
        {
	  unsigned char *d = rowData;

	  for (j = 0; j < pixelsWide; j++)
	    {
#if GS_WORDS_BIGENDIAN
	      tmp[index++] = 0;
	      tmp[index++] = d[0];
	      tmp[index++] = d[1];
	      tmp[index++] = d[2];
#else
	      tmp[index++] = d[2];
	      tmp[index++] = d[1];
	      tmp[index++] = d[0];
	      tmp[index++] = 0;
#endif
	      d += 3;
	    }
	  rowData += bytesPerRow;
	}
      bits = tmp;
      format = CAIRO_FORMAT_RGB24;
      break;
    default:
      NSLog(@"Image format not support");
      return;
    }

  surface = cairo_image_surface_create_for_data((void*)bits,
						format,
						pixelsWide,
						pixelsHigh,
						pixelsWide * 4);

  if (surface == NULL)
    {
      NSLog(@"Image surface could not be created");
      if (bits != data[0])
        {
	  objc_free((unsigned char *)bits);
	}

      return;
    }

  cairo_save(_ct);
  cairo_set_operator(_ct, CAIRO_OPERATOR_SOURCE);
  tstruct = [matrix transformStruct];

  cairo_matrix_init(&local_matrix,
		    tstruct.m11, tstruct.m12,
		    tstruct.m21, tstruct.m22, 
		    tstruct.tX, tstruct.tY);
  cairo_transform(_ct, &local_matrix);
  if (viewIsFlipped)
    {
      cairo_pattern_t *cpattern;
      cairo_matrix_t local_matrix;
      
      cpattern = cairo_pattern_create_for_surface (surface);
      cairo_matrix_init_scale(&local_matrix, 1, -1);
      cairo_matrix_translate(&local_matrix, 0, -2*pixelsHigh);
      cairo_pattern_set_matrix(cpattern, &local_matrix);
      cairo_set_source(_ct, cpattern);
      cairo_pattern_destroy(cpattern);

      cairo_rectangle(_ct, 0, pixelsHigh, pixelsWide, pixelsHigh);
    }
  else 
    {
      cairo_pattern_t *cpattern;
      cairo_matrix_t local_matrix;
      
      cpattern = cairo_pattern_create_for_surface (surface);
      cairo_matrix_init_scale(&local_matrix, 1, -1);
      cairo_matrix_translate(&local_matrix, 0, -pixelsHigh);
      cairo_pattern_set_matrix(cpattern, &local_matrix);
      cairo_set_source(_ct, cpattern);
      cairo_pattern_destroy(cpattern);

      cairo_rectangle(_ct, 0, 0, pixelsWide, pixelsHigh);
    }
  cairo_fill(_ct);
  cairo_surface_destroy(surface);
  cairo_restore(_ct);

  if (bits != data[0])
    {
      objc_free((unsigned char *)bits);
    }
}

- (void) compositerect: (NSRect)aRect op: (NSCompositingOperation)op
{
  cairo_save(_ct);
  _set_op(_ct, op);
  cairo_rectangle(_ct, NSMinX(aRect), NSMinY(aRect), NSWidth(aRect),
		  NSHeight(aRect));
  cairo_fill(_ct);
  cairo_restore(_ct);
}

- (void) compositeGState: (CairoGState *)source 
		fromRect: (NSRect)aRect 
		 toPoint: (NSPoint)aPoint 
		      op: (NSCompositingOperation)op
		fraction: (float)delta
{
  cairo_surface_t *src;
  double minx, miny;
  double width, height;
  double dh;
  NSSize size;
  
  size = [source->_surface size];
  dh = size.height;

  cairo_save(_ct);
  cairo_new_path(_ct);
  _set_op(_ct, op);

  src = cairo_get_target(source->_ct);
  if (src == cairo_get_target(_ct))
    {
 /*
      NSLog(@"Copy onto self");
      NSLog(NSStringFromRect(aRect));
      NSLog(NSStringFromPoint(aPoint));
      NSLog(@"src %p(%p,%@) des %p(%p,%@)", 
	    source,cairo_get_target(source->_ct),NSStringFromSize([source->_surface size]),
	    self,cairo_get_target(_ct),NSStringFromSize([_surface size]));
  */
    }

  minx = NSMinX(aRect);
  miny = NSMinY(aRect);
  width = NSWidth(aRect);
  height = NSHeight(aRect);

  if (viewIsFlipped)
    {
      if (!source->viewIsFlipped)
        {
	  cairo_set_source_surface(_ct, src, aPoint.x - minx, aPoint.y - miny - dh);
	  //cairo_set_source_surface(_ct, src, aPoint.x - minx, aPoint.y - miny - height);
	}
      else 
        {
	  // Both flipped
	  cairo_pattern_t *cpattern;
	  cairo_matrix_t local_matrix;
	  
	  cpattern = cairo_pattern_create_for_surface(src);
	  cairo_matrix_init_scale(&local_matrix, 1, -1);
	  cairo_matrix_translate(&local_matrix, -aPoint.x + minx, -aPoint.y + miny);
	  cairo_pattern_set_matrix(cpattern, &local_matrix);
	  cairo_set_source(_ct, cpattern);
	  cairo_pattern_destroy(cpattern);
	}
      cairo_rectangle(_ct, aPoint.x, aPoint.y - height, width, height);
    }
  else 
    {
      if (!source->viewIsFlipped)
        {
	  // Both non-flipped. 
	  cairo_pattern_t *cpattern;
	  cairo_matrix_t local_matrix;

	  cpattern = cairo_pattern_create_for_surface(src);
	  cairo_matrix_init_scale(&local_matrix, 1, -1);
	  cairo_matrix_translate(&local_matrix, -aPoint.x + minx, -aPoint.y + miny - dh);
	  //cairo_matrix_translate(&local_matrix, -aPoint.x + minx, -aPoint.y + miny - height);
	  cairo_pattern_set_matrix(cpattern, &local_matrix);
	  cairo_set_source(_ct, cpattern);
	  cairo_pattern_destroy(cpattern);
	}
      else
        {
	  cairo_set_source_surface(_ct, src, aPoint.x - minx, aPoint.y - miny);
	}
      cairo_rectangle(_ct, aPoint.x, aPoint.y, width, height);
    }

  if (delta < 1.0)
  {
      cairo_pattern_t *cpattern;

      cpattern = cairo_pattern_create_rgba(1.0, 1.0, 1.0, delta);
      cairo_mask(_ct, cpattern);
      cairo_pattern_destroy(cpattern);
  }
  cairo_fill(_ct);
  cairo_restore(_ct);
}

- (void) compositeGState: (CairoGState *)source 
		fromRect: (NSRect)aRect 
		 toPoint: (NSPoint)aPoint 
		      op: (NSCompositingOperation)op
{
  [self compositeGState: source 
	       fromRect: aRect 
		toPoint: aPoint 
		     op: op
	       fraction: 1.0];
}

- (void) dissolveGState: (CairoGState *)source
	       fromRect: (NSRect)aRect
		toPoint: (NSPoint)aPoint 
		  delta: (float)delta
{
  [self compositeGState: source 
	       fromRect: aRect 
		toPoint: aPoint 
		     op: NSCompositeSourceOver
	       fraction: delta];
}

@end
