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

#include <AppKit/NSBezierPath.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSGraphics.h>
#include "cairo/CairoGState.h"
#include "cairo/CairoFontInfo.h"
#include "cairo/CairoSurface.h"
#include "cairo/CairoContext.h"
#include "NSBezierPathCairo.h"
#include <math.h>

#define FIXME()  NSLog(@":::FIXME::: %@ %s", [self description], sel_get_name(_cmd))

/* Be warned that CairoGState didn't derived GSGState */
@implementation CairoGState 

+ (void) initialize
{
  if (self == [CairoGState class])
    {
    }
}

- (void) forwardInvocation: (NSInvocation *)anInvocation
{
  /* only for trapping any unknown message. */
  NSLog (@":::UNKNOWN::: %@ %@", self, anInvocation);
  exit(1);
}

- (id) copyWithZone: (NSZone *)zone
{
  CairoGState *copy = (CairoGState *)NSCopyObject(self, 0, zone);

  if (_ct)
    {
      cairo_path_t *path;
      cairo_status_t status;
      cairo_matrix_t local_matrix;
 
      // FIXME: Need some way to do a copy
      //cairo_copy(copy->_ct, _ct);
      copy->_ct = cairo_create(cairo_get_target(_ct));
      cairo_get_matrix(_ct, &local_matrix);
      cairo_set_matrix(copy->_ct, &local_matrix);
      path = cairo_copy_path(_ct);
      cairo_append_path(copy->_ct, path);
      cairo_path_destroy(path);
      
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

  RETAIN(_font);
  RETAIN(_surface);

  return copy;
}

- (id) init
{
  [self DPSinitgraphics];
  return self;
}

- (id) initWithDrawContext: (CairoContext *)drawContext
{
  //NSLog (@"CairoGState initWithDrawContext:%@", drawContext);
  [self init];

  return self;
}

- (void) dealloc
{
  if (_ct)
    {
      cairo_destroy(_ct);
    }
  RELEASE(_font);
  RELEASE(_surface);

  [super dealloc];
}

static void
_flipCairoSurfaceMatrix(cairo_t *ct, CairoSurface *surface)
{
  cairo_matrix_t local_matrix;

  cairo_matrix_init_scale(&local_matrix, 1, -1);

  if (surface != nil)
    {
      cairo_matrix_translate(&local_matrix, 0, -[surface size].height);
    }
  cairo_set_matrix(ct, &local_matrix);
}

- (void) setOffset: (NSPoint)theOffset
{
  _offset = theOffset;
}

- (NSPoint) offset
{
  return _offset;
}

- (void) GSCurrentDevice: (void **)device: (int *)x : (int *)y
{
  if (x)
    *x = 0;
  if (y)
    *y = 0;
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
  _offset = NSMakePoint(x, y);

  [self DPSinitgraphics];
}

@end 

@implementation CairoGState (Ops)

// FIXME: Hack to be able to set alpha
static float last_r, last_g, last_b;

/*
 * Color operations
 */
- (void) DPScurrentalpha: (float *)a
{
  //FIXME
  *a = 1.0;
  //*a = cairo_current_alpha(_ct);
}

- (void) DPScurrentcmykcolor: (float *)c : (float *)m : (float *)y :(float *)k
{
  float r, g, b;

  [self DPScurrentrgbcolor: &r: &g: &b];
  *c = 1 - r;
  *m = 1 - g;
  *y = 1 - b;
  *k = 0;
}

- (void) DPScurrentgray: (float *)gray
{
  float r, g, b;

  [self DPScurrentrgbcolor: &r: &g: &b];
  *gray = (r + g + b) / 3.0;
}

- (void) DPScurrenthsbcolor: (float *)h : (float *)s : (float *)b
{
  NSColor *color;
  float fr, fg, fb;
  float alpha;

  [self DPScurrentrgbcolor: &fr: &fg: &fb];
  color = [NSColor colorWithCalibratedRed: fr
		                    green: fg
		                     blue: fb
		                    alpha: 1.0];
  [color getHue: h
	 saturation: s
	 brightness: b
	 alpha: &alpha];
}

- (void) DPScurrentrgbcolor: (float *)r : (float *)g : (float *)b
{
  //FIXME: cairo removed this function
  //cairo_current_rgb_color(_ct, &dr, &dg, &db);
  *r = last_r;
  *g = last_g;
  *b = last_b;
}

- (void) DPSsetalpha: (float)a
{
  float r, g, b;

  // FIXME: Hack to be able to set alpha
  r = last_r;
  g = last_g;
  b = last_b;
  cairo_set_source_rgba(_ct, r, g, b, a);
}

- (void) DPSsetcmykcolor: (float)c : (float)m : (float)y : (float)k
{
  double r, g, b;

  r = 1 - c;
  g = 1 - m;
  b = 1 - y;
  [self DPSsetrgbcolor: r : g : b];
}

- (void) DPSsetgray: (float)gray
{
  [self DPSsetrgbcolor: gray : gray : gray];
}

- (void) DPSsethsbcolor: (float)h : (float)s : (float)b
{
  NSColor *color;
  float red, green, blue, alpha;
 
  color = [NSColor colorWithCalibratedHue: h
		               saturation: s
		               brightness: b
		                    alpha: 1.0];
  [color getRed: &red
	  green: &green
	   blue: &blue
	  alpha: &alpha];
  [self DPSsetrgbcolor: red : green : blue];
}

- (void) DPSsetrgbcolor: (float)r : (float)g: (float)b
{
  // FIXME: Hack to be able to set alpha
  last_r = r;
  last_g = g;
  last_b = b;
  cairo_set_source_rgb(_ct, r, g, b);
}

- (void) GSSetFillColorspace: (void *)spaceref
{
  FIXME();
}

- (void) GSSetStrokeColorspace: (void *)spaceref
{
  FIXME();
}

- (void) GSSetFillColor: (const float *)values
{
  FIXME();
}

- (void) GSSetStrokeColor: (const float *)values
{
  FIXME();
}

/*
 * Text operations
 */

- (void) DPSashow: (float)x : (float)y : (const char *)s
{
  FIXME();
}

- (void) DPSawidthshow: (float)cx : (float)cy : (int)c : (float)ax 
		      : (float)ay : (const char *)s
{
  FIXME();
}

- (void) DPScharpath: (const char *)s : (int)b
{
  char *c = malloc(b + 1);

  memcpy(c, s, b);
  c[b + 1] = 0;

  cairo_text_path(_ct, c);
  free(c);
}

- (void) DPSshow: (const char *)s
{
  cairo_show_text(_ct, s);
}

- (void) DPSwidthshow: (float)x : (float)y : (int)c : (const char *)s
{
  FIXME();
}

- (void) DPSxshow: (const char *)s : (const float *)numarray : (int)size
{
  FIXME();
}

- (void) DPSxyshow: (const char *)s : (const float *)numarray : (int)size
{
  FIXME();
}

- (void) DPSyshow: (const char *)s : (const float *)numarray : (int)size
{
  FIXME();
}

- (void) GSSetCharacterSpacing: (float)extra
{
  FIXME();
}

- (void) GSSetFont: (GSFontInfo *)fontref
{
  if (_font == fontref)
    {
      return;
    }

  ASSIGN(_font, fontref);
  //cairo_set_font_face(_ct, [((CairoFontInfo *)_font)->_faceInfo fontFace]);
  //cairo_set_font_matrix(_ct, ((CairoFontInfo *)_font)->matrix);
}

- (void) GSSetFontSize: (float)size
{
  cairo_set_font_size(_ct, size);
}

- (NSAffineTransform *) GSGetTextCTM
{
  return [self GSCurrentCTM];
}

- (NSPoint) GSGetTextPosition
{
  float x, y;

  [self DPScurrentpoint: &x : &y];
  return NSMakePoint(x, y);
}

- (void) GSSetTextCTM: (NSAffineTransform *)ctm
{
  [self GSSetCTM: ctm];
}

- (void) GSSetTextDrawingMode: (GSTextDrawingMode)mode
{
  FIXME();
}

- (void) GSSetTextPosition: (NSPoint)loc
{
  FIXME();
}

- (void) GSShowText: (const char *)string : (size_t)length
{
  FIXME();
}

- (void) GSShowGlyphs: (const NSGlyph *)glyphs : (size_t)length
{
  [_font drawGlyphs: glyphs
             length: length
                 on: _ct];
}

/*
 * GState operations
 */

- (void) DPSinitgraphics
{
  cairo_status_t status;

  DESTROY(_font);

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
  _flipCairoSurfaceMatrix(_ct, _surface);
  //NSLog(@"in flip %p (%p)", self, cairo_get_target(_ct));
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

- (void) DPScurrentpoint: (float *)x : (float *)y
{
  double dx, dy;

  cairo_get_current_point(_ct, &dx, &dy);
  *x = dx;
  *y = dy;
}

- (void) DPScurrentstrokeadjust: (int *)b
{
  FIXME();
}

- (void) DPSsetdash: (const float *)pat : (int)size : (float)offset
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
  cairo_set_dash(_ct, dpat, size, offset);
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

- (void) DPSconcat: (const float *)m
{
  cairo_matrix_t local_matrix;

  cairo_matrix_init(&local_matrix, m[0], m[1], m[2], m[3], m[4], m[5]);
  cairo_transform(_ct, &local_matrix);
}

- (void) DPSinitmatrix
{
  cairo_identity_matrix(_ct);
  _flipCairoSurfaceMatrix(_ct, _surface);
}

- (void) DPSrotate: (float)angle
{
  cairo_rotate(_ct, angle);
}

- (void) DPSscale: (float)x : (float)y
{
  cairo_scale(_ct, x, y);
}

- (void) DPStranslate: (float)x : (float)y
{
  cairo_translate(_ct, x, y);
}

- (void) _flipCairoFont
{
  cairo_matrix_t local_matrix;

  cairo_matrix_init_scale(&local_matrix, 1, -1);
  cairo_set_font_matrix(_ct, &local_matrix);
}

- (NSAffineTransform *) GSCurrentCTM
{
  NSAffineTransform *transform;
  NSAffineTransformStruct tstruct;
  cairo_matrix_t flip_matrix;
  cairo_matrix_t local_matrix;

  transform = [NSAffineTransform transform];
  cairo_get_matrix(_ct, &local_matrix);
/*
  NSLog(@"Before flip %f %f, %f, %f, %f, %f", local_matrix.xx, local_matrix.yx, 
	local_matrix.xy, local_matrix.yy, local_matrix.x0, local_matrix.y0);
*/
  if (_surface)
  {
     cairo_matrix_init_translate(&flip_matrix, 0, -[_surface size].height);
     cairo_matrix_multiply(&local_matrix, &local_matrix, &flip_matrix);
   }
  cairo_matrix_init_scale(&flip_matrix, 1, -1);
  cairo_matrix_multiply(&local_matrix, &local_matrix, &flip_matrix);
/*
  NSLog(@"After flip %f %f, %f, %f, %f, %f", local_matrix.xx, local_matrix.yx, 
	local_matrix.xy, local_matrix.yy, local_matrix.x0, local_matrix.y0);
*/ 
  tstruct.m11 = local_matrix.xx;
  tstruct.m12 = local_matrix.yx;
  tstruct.m21 = local_matrix.xy;
  tstruct.m22 = local_matrix.yy;
  tstruct.tX = local_matrix.x0;
  tstruct.tY = local_matrix.y0;
  [transform setTransformStruct:tstruct];
  return transform;
}

- (void) GSSetCTM: (NSAffineTransform *)ctm
{
  NSAffineTransformStruct tstruct;
  cairo_matrix_t local_matrix;

  _flipCairoSurfaceMatrix(_ct, _surface);
  tstruct = [ctm transformStruct];
  cairo_matrix_init(&local_matrix,
		    tstruct.m11, tstruct.m12,
		    tstruct.m21, tstruct.m22, 
		    tstruct.tX, tstruct.tY);
  cairo_transform(_ct, &local_matrix);
}

- (void) GSConcatCTM: (NSAffineTransform *)ctm
{
  NSAffineTransformStruct tstruct;
  cairo_matrix_t local_matrix;

  tstruct =  [ctm transformStruct];
  cairo_matrix_init(&local_matrix,
		    tstruct.m11, tstruct.m12,
		    tstruct.m21, tstruct.m22, 
		    tstruct.tX, tstruct.tY);
  cairo_transform(_ct, &local_matrix);
}

/*
 * Paint operations
 */

- (NSPoint) currentPoint
{
  double dx, dy;

  cairo_get_current_point(_ct, &dx, &dy);
  return NSMakePoint(dx, dy);
}

- (void) DPSarc: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2
{
  cairo_arc(_ct, x, y, r, angle1 * M_PI / 180, angle2 * M_PI / 180);
}

- (void) DPSarcn: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2
{
  cairo_arc_negative(_ct, x, y, r, angle1 * M_PI / 180, angle2 * M_PI / 180);
}

- (void) DPSarct: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)r
{
  FIXME();
  /*
     cairo_arc_to(_ct, x1, y1, x2, y2, r);
   */
  /*
     NSBezierPath *newPath;

     newPath = [[NSBezierPath alloc] init];
     if ((path != nil) && ([path elementCount] != 0))
     {
     [newPath lineToPoint: [self currentPoint]];
     }
     [newPath appendBezierPathWithArcFromPoint: NSMakePoint(x1, y1)
     toPoint: NSMakePoint(x2, y2)
     radius: r];
     [newPath transformUsingAffineTransform: ctm];
     CHECK_PATH;
     [path appendBezierPath: newPath];
     RELEASE(newPath);
   */
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
  cairo_path_t *path;

  path = cairo_copy_path_flat(_ct);
  cairo_new_path(_ct);
  cairo_append_path(_ct, path);
  cairo_path_destroy(path);
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

- (void) DPSpathbbox: (float *)llx : (float *)lly : (float *)urx : (float *)ury
{
  NSBezierPath *path = [NSBezierPath bezierPathFromCairo: _ct];
  NSRect rect = [path controlPointBounds];

  if (llx)
    *llx = NSMinX(rect);
  if (lly)
    *lly = NSMinY(rect);
  if (urx)
    *urx = NSMaxX(rect);
  if (ury)
    *ury = NSMaxY(rect);
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
  NSBezierPath *path = [NSBezierPath bezierPathFromCairo: _ct];

  path = [path bezierPathByReversingPath];
  cairo_new_path(_ct);
  [path appendBezierPathToCairo: _ct];
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

- (void) GSSendBezierPath: (NSBezierPath *)path
{
  cairo_new_path(_ct);
  [path appendBezierPathToCairo: _ct];
}

- (void) GSRectClipList: (const NSRect *)rects : (int)count
{
  int i;
  NSRect union_rect;

  if (count == 0)
    return;

  /* FIXME see gsc
     The specification is not clear if the union of the rects 
     should produce the new clip rect or if the outline of all rects 
     should be used as clip path.
   */
  union_rect = rects[0];
  for (i = 1; i < count; i++)
    union_rect = NSUnionRect(union_rect, rects[i]);

  [self DPSrectclip: NSMinX(union_rect) : NSMinY(union_rect)
	           : NSWidth(union_rect) : NSHeight(union_rect)];
}

- (void) GSRectFillList: (const NSRect *)rects : (int)count
{
  int i;

  for (i = 0; i < count; i++)
    {
      [self DPSrectfill: NSMinX(rects[i]) : NSMinY(rects[i])
	               : NSWidth(rects[i]) : NSHeight(rects[i])];
    }
}

static void
_set_op(cairo_t * ct, NSCompositingOperation op)
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
        cairo_current_target_surface (_ct));
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
	      tmp[index++] = d[2];
	      tmp[index++] = d[1];
	      tmp[index++] = d[0];
	      tmp[index++] = d[3];
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
	      tmp[index++] = d[2];
	      tmp[index++] = d[1];
	      tmp[index++] = d[0];
	      tmp[index++] = 0;
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

  cairo_save(_ct);
  cairo_set_operator(_ct, CAIRO_OPERATOR_SOURCE);
  _flipCairoSurfaceMatrix(_ct, _surface);
  tstruct = [matrix transformStruct];

  cairo_matrix_init(&local_matrix,
		    tstruct.m11, tstruct.m12,
		    tstruct.m21, tstruct.m22, 
		    tstruct.tX, tstruct.tY);
  cairo_transform(_ct, &local_matrix);

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

  cairo_set_source_surface(_ct, surface, 0, 0);
  if (_viewIsFlipped)
    {
      cairo_rectangle(_ct, 0, -pixelsHigh, pixelsWide, pixelsHigh);
    }
  else 
    {
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

  /*
    NSLog(NSStringFromRect(aRect));
    NSLog(NSStringFromPoint(aPoint));
    NSLog(@"src %p(%p,%@) des %p(%p,%@)", 
    source,cairo_get_target(source->_ct),NSStringFromSize([source->_surface size]),
    self,cairo_get_target(_ct),NSStringFromSize([_surface size]));
  */

  cairo_save(_ct);
  _set_op(_ct, op);

  src = cairo_get_target(source->_ct);
  if (src == cairo_get_target(_ct))
    {
      //NSLog(@"Copy onto self");
    }

  minx = NSMinX(aRect);
  miny = NSMinY(aRect);
  width = NSWidth(aRect);
  height = NSHeight(aRect);
  /*
  cairo_user_to_device(source->_ct, &minx, &miny);
  cairo_user_to_device_distance(source->_ct, &width, &height);
  cairo_device_to_user(_ct, &minx, &miny);
  cairo_device_to_user_distance(_ct, &width, &height);
  NSLog(@"Rect %@  = %f, %f, %f, %f", NSStringFromRect(aRect), minx, miny, width, height);
  */
  if (_viewIsFlipped)
    {
      cairo_set_source_surface(_ct, src, aPoint.x - minx, aPoint.y - miny - height);
      cairo_rectangle (_ct, aPoint.x, aPoint.y - height, width, height);
    }
  else 
    {
      cairo_set_source_surface(_ct, src, aPoint.x - minx, aPoint.y - miny);
      cairo_rectangle (_ct, aPoint.x, aPoint.y, width, height);
    }

  if (delta < 1.0)
  {
      cairo_pattern_t *pattern;

      pattern = cairo_pattern_create_rgba(1.0, 1.0, 1.0, delta);
      cairo_mask(_ct, pattern);
      cairo_pattern_destroy(pattern);
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
