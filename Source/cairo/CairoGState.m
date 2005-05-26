/*
 * CairoGState.m

 * Copyright (C) 2003 Free Software Foundation, Inc.
 * August 31, 2003
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

static cairo_matrix_t *local_matrix;

/* Be warned that CairoGState didn't derived GSGState */
@implementation CairoGState 

+ (void) initialize
{
  if (self == [CairoGState class])
    {
      local_matrix = cairo_matrix_create();
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

  copy->_ct = cairo_create();
  cairo_copy(copy->_ct, _ct);
  /*
     NSLog(@"copy state %p(%p) to %p(%p)",self,
     cairo_current_target_surface(_ct),
     copy,
     cairo_current_target_surface(copy->_ct)
     );
   */

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
  //NSLog(@"destate %p",self);
  cairo_destroy(_ct);
  RELEASE(_font);
  RELEASE(_surface);

  [super dealloc];
}

static void
_flipCairoSurfaceMatrix(cairo_t *ct, CairoSurface *surface)
{
  cairo_matrix_set_identity(local_matrix);
  cairo_matrix_scale(local_matrix, 1, -1);

  if (surface != nil)
    {
      cairo_matrix_translate(local_matrix, 0, -[surface size].height);
    }
  cairo_set_matrix(ct, local_matrix);
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
  CairoInfo cairo_info;

  ASSIGN(_surface, [CairoSurface surfaceForDevice: device depthInfo: &cairo_info]);
  _offset = NSMakePoint(x, y);
/*
  NSLog(@"before: surface %p on state %p",
	cairo_current_target_surface(_ct), self);
*/
  [_surface setAsTargetOfCairo: _ct];
  _flipCairoSurfaceMatrix(_ct, _surface);
/*
  NSLog(@"after: surface %p on state %p %@",
	cairo_current_target_surface (_ct), self,
	NSStringFromSize([_surface size]));
*/
}

@end 

@implementation CairoGState (Ops)
/*
 * Color operations
 */
- (void) DPScurrentalpha: (float *)a
{
  *a = cairo_current_alpha(_ct);
}

- (void) DPScurrentcmykcolor: (float *)c : (float *)m : (float *)y :(float *)k
{
  double color[3];

  cairo_current_rgb_color(_ct, &color[0], &color[1], &color[2]);
  *c = 1 - color[0];
  *m = 1 - color[1];
  *y = 1 - color[2];
  *k = 0;
}

- (void) DPScurrentgray: (float *)gray
{
  double dr, dg, db;

  cairo_current_rgb_color(_ct, &dr, &dg, &db);
  *gray = (dr + dg + db) / 3.0;
}

- (void) DPScurrenthsbcolor: (float *)h : (float *)s : (float *)b
{
  NSColor *color;
  double dr, dg, db;
  float alpha;

  cairo_current_rgb_color(_ct, &dr, &dg, &db);
  color = [NSColor colorWithCalibratedRed: dr
		                    green: dg
		                     blue: db
		                    alpha: 1.0];
  [color getHue: h
	 saturation: s
	 brightness: b
	 alpha: &alpha];
}

- (void) DPScurrentrgbcolor: (float *)r : (float *)g : (float *)b
{
  double dr, dg, db;

  cairo_current_rgb_color(_ct, &dr, &dg, &db);
  *r = dr;
  *g = dg;
  *b = db;
}

- (void) DPSsetalpha: (float)a
{
  cairo_set_alpha(_ct, a);
}

- (void) DPSsetcmykcolor: (float)c : (float)m : (float)y : (float)k
{
  double r, g, b;

  r = 1 - c;
  g = 1 - m;
  b = 1 - y;
  cairo_set_rgb_color(_ct, r, g, b);
}

- (void) DPSsetgray: (float)gray
{
  cairo_set_rgb_color(_ct, gray, gray, gray);
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
  cairo_set_rgb_color(_ct, r, g, b);
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
  free (c);
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
  cairo_set_font(_ct, ((CairoFontInfo *)_font)->xrFont);
}

- (void) GSSetFontSize: (float)size
{
  FIXME();
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
  double dx, dy;

  cairo_current_point(_ct, &dx, &dy);

  [_font drawGlyphs: glyphs
             length: length
                 on: _ct
                atX: dx
                  y: dy];
}

/*
 * GState operations
 */

- (void) DPSinitgraphics
{
  DESTROY(_font);

  if (_ct)
    {
      cairo_destroy(_ct);
    }
  _ct = cairo_create();
  /* Cairo's default line width is 2.0 */
  _flipCairoSurfaceMatrix(_ct, _surface);
  //NSLog(@"in flip %p (%p)", self, cairo_current_target_surface(_ct));
  cairo_set_line_width(_ct, 1.0);
}

- (void) DPScurrentflat: (float *)flatness
{
  *flatness = cairo_current_tolerance(_ct);
}

- (void) DPScurrentlinecap: (int *)linecap
{
  cairo_line_cap_t lc;

  lc = cairo_current_line_cap(_ct);
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

  lj = cairo_current_line_join(_ct);
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
  *width = cairo_current_line_width(_ct);
}

- (void) DPScurrentmiterlimit: (float *)limit
{
  *limit = cairo_current_miter_limit(_ct);
}

- (void) DPScurrentpoint: (float *)x : (float *)y
{
  double dx, dy;

  cairo_current_point(_ct, &dx, &dy);
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
  cairo_matrix_set_affine(local_matrix, m[0], m[1], m[2], m[3], m[4], m[5]);
  cairo_concat_matrix(_ct, local_matrix);
}

- (void) DPSinitmatrix
{
  cairo_matrix_set_identity(local_matrix);
  cairo_set_matrix(_ct, local_matrix);
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
  cairo_matrix_set_identity(local_matrix);
  cairo_matrix_scale(local_matrix, 1, -1);
  cairo_transform_font(_ct, local_matrix);
}

/*
static void
_log_matrix(cairo_t * ct)
{
  double da, db, dc, dd, dtx, dty;

  cairo_current_matrix(ct, local_matrix);
  cairo_matrix_get_affine(local_matrix, &da, &db, &dc, &dd, &dtx, &dty);

  NSLog(@"%g %g %g %g %g %g", da, db, dc, dd, dtx, dty);
}
*/

- (NSAffineTransform *) GSCurrentCTM
{
  NSAffineTransform *transform;
  NSAffineTransformStruct tstruct;
  double da, db, dc, dd, dtx, dty;

  transform = [NSAffineTransform transform];
  cairo_current_matrix(_ct, local_matrix);
  cairo_matrix_get_affine(local_matrix, &da, &db, &dc, &dd, &dtx, &dty);
  tstruct.m11 = da;
  tstruct.m12 = db;
  tstruct.m21 = dc;
  tstruct.m22 = dd;
  tstruct.tX = dtx;
  tstruct.tY = dty;
  [transform setTransformStruct:tstruct];
  return transform;
}

- (void) GSSetCTM: (NSAffineTransform *)ctm
{
  NSAffineTransformStruct tstruct;

  tstruct = [ctm transformStruct];
  cairo_matrix_set_affine(local_matrix,
			  tstruct.m11, tstruct.m12,
			  tstruct.m21, tstruct.m22, tstruct.tX, tstruct.tY);
  cairo_set_matrix(_ct, local_matrix);
}

- (void) GSConcatCTM: (NSAffineTransform *)ctm
{
  NSAffineTransformStruct tstruct;

  tstruct =  [ctm transformStruct];
  cairo_matrix_set_affine(local_matrix,
			  tstruct.m11, tstruct.m12,
			  tstruct.m21, tstruct.m22, tstruct.tX, tstruct.tY);
  cairo_concat_matrix(_ct, local_matrix);
}

/*
 * Paint operations
 */

- (NSPoint) currentPoint
{
  double dx, dy;

  //FIXME();
  cairo_current_point(_ct, &dx, &dy);
  return NSMakePoint(dx, dy);
}

- (void) DPSarc: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2
{
  //NSLog(@"%g %g", angle1, angle2);
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

static void
_c2cmoveto(void *cl, double x, double y)
{
  cairo_t *ct = (cairo_t *)cl;
  cairo_move_to(ct, x, y);
}

static void
_c2clineto(void *cl, double x, double y)
{
  cairo_t *ct = (cairo_t *)cl;
  cairo_line_to(ct, x, y);
}

static void
_c2cclosepath(void *cl)
{
  cairo_t *ct = (cairo_t *)cl;
  cairo_close_path(ct);
}

- (void) DPSflattenpath
{
  /* recheck this in plrm */
  cairo_t *fct = cairo_create();

  cairo_copy(fct, _ct);
  cairo_new_path(_ct);
  cairo_current_path_flat(fct, _c2cmoveto, _c2clineto, _c2cclosepath, _ct);
  cairo_destroy(fct);
}

- (void) DPSinitclip
{
  cairo_init_clip(_ct);
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

/*
static NSString *
_opName(NSCompositingOperation op)
{
  switch (op)
    {
    case NSCompositeClear:
      return @"NSCompositeClear";

    case NSCompositeCopy:
      return @"NSCompositeCopy";

    case NSCompositeSourceOver:
      return @"NSCompositeSourceOver";

    case NSCompositeSourceIn:
      return @"NSCompositeSourceIn";

    case NSCompositeSourceOut:
      return @"NSCompositeSourceOut";

    case NSCompositeSourceAtop:
      return @"NSCompositeSourceAtop";

    case NSCompositeDestinationOver:
      return @"NSCompositeDestinationOver";

    case NSCompositeDestinationIn:
      return @"NSCompositeDestinationIn";

    case NSCompositeDestinationOut:
      return @"NSCompositeDestinationOut";

    case NSCompositeDestinationAtop:
      return @"NSCompositeDestinationAtop";

    case NSCompositeXOR:
      return @"NSCompositeXOR";

    case NSCompositePlusDarker:
      return @"NSCompositePlusDarker";

    case NSCompositeHighlight:
      return @"NSCompositeHighlight";

    case NSCompositePlusLighter:
      return @"NSCompositePlusLighter";

    default:
      return @"default";

    }
}
*/

static void
_set_op(cairo_t * ct, NSCompositingOperation op)
{
  switch (op)
    {
    case NSCompositeClear:
      cairo_set_operator(ct, CAIRO_OPERATOR_CLEAR);
      break;
    case NSCompositeCopy:
      cairo_set_operator(ct, CAIRO_OPERATOR_SRC);
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
      cairo_set_operator(ct, CAIRO_OPERATOR_OVER_REVERSE);
      break;
    case NSCompositeDestinationIn:
      cairo_set_operator(ct, CAIRO_OPERATOR_IN_REVERSE);
      break;
    case NSCompositeDestinationOut:
      cairo_set_operator(ct, CAIRO_OPERATOR_OUT_REVERSE);
      break;
    case NSCompositeDestinationAtop:
      cairo_set_operator(ct, CAIRO_OPERATOR_ATOP_REVERSE);
      break;
    case NSCompositeXOR:
      cairo_set_operator(ct, CAIRO_OPERATOR_XOR);
      break;
    case NSCompositePlusDarker:
      break;
    case NSCompositeHighlight:
      cairo_set_operator(ct, CAIRO_OPERATOR_SATURATE);
      break;
    case NSCompositePlusLighter:
      cairo_set_operator(ct, CAIRO_OPERATOR_ADD);
      break;
    default:
      cairo_set_operator(ct, CAIRO_OPERATOR_SRC);
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
  cairo_t *ict;
  cairo_surface_t *surface;

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

  switch (bitsPerSample * samplesPerPixel)
    {
    case 32:
      format = CAIRO_FORMAT_ARGB32;
      break;
    case 24:
      format = CAIRO_FORMAT_RGB24;
      break;
    default:
      NSLog(@"Image format not support");
      return;
    }
//      [self DPSinitclip];

  tstruct = [matrix transformStruct];
  /*
     NSLog(@"%g %g %g %g %g %g",
     tstruct.m11, tstruct.m12,
     tstruct.m21, tstruct.m22,
     tstruct.tX, tstruct.tY);
  */

  ict = cairo_create();
  [_surface setAsTargetOfCairo: ict];
  _flipCairoSurfaceMatrix(ict, _surface);
  cairo_matrix_set_affine(local_matrix,
			  tstruct.m11, tstruct.m12,
			  tstruct.m21, tstruct.m22, tstruct.tX, tstruct.tY);
  cairo_concat_matrix(ict, local_matrix);

  surface = cairo_surface_create_for_image((void*)data, 
					   format,
					   pixelsWide,
					   pixelsHigh,
					   bytesPerRow);
  cairo_matrix_set_identity(local_matrix);
  cairo_matrix_scale(local_matrix, 1, -1);
  cairo_matrix_translate(local_matrix, 0, -pixelsHigh);
  cairo_surface_set_matrix(surface, local_matrix);
  cairo_show_surface(ict,
		     surface,
		     pixelsWide,
		     pixelsHigh);
  cairo_surface_destroy(surface);
  cairo_destroy(ict);
}

- (void) compositerect: (NSRect)aRect op: (NSCompositingOperation)op
{
  _set_op(_ct, op);
  cairo_rectangle(_ct, NSMinX(aRect), NSMinY(aRect), NSWidth(aRect),
		  NSHeight(aRect));
  cairo_fill(_ct);
}

- (void) compositeGState: (CairoGState *)source 
		fromRect: (NSRect)aRect 
		 toPoint: (NSPoint)aPoint 
		      op: (NSCompositingOperation)op
		fraction: (float)delta
{
  cairo_surface_t *src;

  /*
    NSLog(NSStringFromRect(aRect));
    NSLog(@"src %p(%p,%@) des %p(%p,%@)",source,cairo_current_target_surface(source->_ct),NSStringFromSize([source->_surface size]),
    self,cairo_current_target_surface(_ct),NSStringFromSize([_surface size]));
  */
  cairo_save(_ct);
  _set_op(_ct, op);
  cairo_set_alpha(_ct, delta);
  cairo_translate(_ct, aPoint.x, aPoint.y);

  cairo_matrix_set_identity(local_matrix);
  cairo_matrix_scale(local_matrix, 1, -1);
  cairo_matrix_translate(local_matrix, 0, -[source->_surface size].height);
  // cairo_matrix_translate(local_matrix, NSMinX(aRect), NSMinY(aRect));
  src = cairo_current_target_surface(source->_ct);
  cairo_surface_set_matrix(src, local_matrix);
  cairo_show_surface(_ct, src, NSWidth(aRect), NSHeight(aRect));
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
