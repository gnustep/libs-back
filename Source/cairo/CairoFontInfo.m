/*
 * CairoFontInfo.m
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 * August 31, 2003
 * Written by Banlu Kemiyatorn <object at gmail dot com>
 * Base on original code of Alex Malmberg
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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
 */

#include "cairo/CairoFontInfo.h"
#include <AppKit/NSAffineTransform.h>
#include <math.h>
#include <cairo.h>

@implementation CairoFontInfo 

+ (void) initializeBackend
{
  //NSLog(@"CairoFontInfo : Initializing...");
  [GSFontEnumerator setDefaultClass: [CairoFontEnumerator class]];
  [GSFontInfo setDefaultClass: self];
}

- (void) setCacheSize: (unsigned int)size
{
  _cacheSize = size;
  if (_cachedSizes)
    {
      free(_cachedSizes);
    }
  if (_cachedGlyphs)
    {
      free(_cachedGlyphs);
    }
  _cachedSizes = malloc(sizeof(NSSize) * size);
  _cachedGlyphs = malloc(sizeof(unsigned int) * size);
}

- (void) createCairoFontWithIdentity: (void *)ident
{
  /* subclass should override */
  cairo_matrix_t *font_matrix;
  cairo_font_extents_t font_extents;

  cairo_select_font(_cf,[_faceInfo cairoCName],[_faceInfo cairoSlant],
		    [_faceInfo cairoWeight]);
  xrFont = cairo_current_font(_cf);
  font_matrix = cairo_matrix_create();
  cairo_matrix_set_affine(font_matrix, matrix[0], matrix[1], matrix[2],
			  -matrix[3], matrix[4], matrix[5]);
  cairo_transform_font(_cf, font_matrix);
  /*
     NSLog(@"%g %g %g %g %g %g",matrix[0],matrix[1],matrix[2],matrix[3],matrix[4],matrix[5]);
   */

  cairo_current_font_extents(_cf, &font_extents);
  ascender = font_extents.ascent;
  descender = font_extents.descent;
  xHeight = font_extents.height;
  maximumAdvancement = NSMakeSize(font_extents.max_x_advance, 
				  font_extents.max_y_advance);
  cairo_matrix_destroy(font_matrix);
}

- (id) initWithFontName: (NSString *)name 
		 matrix: (const float *)fmatrix 
	     screenFont: (BOOL)p_screenFont
{
  //NSLog(@"initWithFontName %@",name);
  [super init];

  /* do not forget to check for font specific
   * cache size from face info FIXME FIXME
   */
  ASSIGN(_faceInfo, [CairoFontManager fontWithName: name]);
  if (!_faceInfo)
    {
      RELEASE(self);
      return nil;
    }

  _cachedSizes = NULL;
  [self setCacheSize: [_faceInfo cacheSize]];
  _screenFont = p_screenFont;

  /* setting GSFontInfo:
   * weight, traits, fontName, familyName,
   * matrix, mostCompatibleStringEncoding, encodingScheme,
   */

  weight = [_faceInfo weight];
  traits = [_faceInfo traits];
  fontName = [name copy];
  familyName = [[_faceInfo familyName] copy];
  memcpy(matrix, fmatrix, sizeof(matrix));
  mostCompatibleStringEncoding = NSUTF8StringEncoding;
  encodingScheme = @"iso10646-1";

  if (_screenFont)
    {
      /* Round up; makes the text more legible. */
      matrix[0] = ceil(matrix[0]);
      if (matrix[3] < 0.0)
	matrix[3] = floor(matrix[3]);
      else
	matrix[3] = ceil(matrix[3]);
    }

  /* setting GSFontInfo:
   * xHeight, pix_width, pix_height
   */

  _cf = cairo_create ();
  [self createCairoFontWithIdentity: _faceInfo];

  fontBBox = NSMakeRect(0, descender, 
			maximumAdvancement.width, ascender + descender);
  //NSLog(NSStringFromRect(fontBBox));
  return self;
}

- (void) dealloc
{
  RELEASE(_faceInfo);
  cairo_destroy(_cf);
  free(_cachedSizes);
  free(_cachedGlyphs);
  [super dealloc];
}

- (BOOL) glyphIsEncoded: (NSGlyph)glyph
{
  /* subclass should override */
  return YES;
}

- (NSSize) advancementForGlyph: (NSGlyph)glyph
{
  /* subclass should override */
  cairo_glyph_t cglyph;
  cairo_text_extents_t ctext;
  int entry;

  glyph -= 29;
  entry = glyph % _cacheSize;

  if (_cachedGlyphs[entry] == glyph)
    {
      return _cachedSizes[entry];
    }

  cglyph.index = glyph;
  cglyph.x = 0;
  cglyph.y = 0;
  cairo_glyph_extents(_cf, &cglyph, 1, &ctext);
  _cachedGlyphs[entry] = glyph;
  _cachedSizes[entry] = NSMakeSize(ctext.x_advance, ctext.y_advance);

  //NSLog(NSStringFromSize(_cachedSizes[entry]));
  return _cachedSizes[entry];
}

- (NSRect) boundingRectForGlyph: (NSGlyph)glyph
{
  /* subclass should override */
  cairo_glyph_t cglyph;
  cairo_text_extents_t ctext;

  glyph -= 29;
  cglyph.index = glyph;
  cglyph.x = 0;
  cglyph.y = 0;
  cairo_glyph_extents(_cf, &cglyph, 1, &ctext);

  return NSMakeRect(ctext.x_bearing, ctext.y_bearing,
		    ctext.width, ctext.height);
}

- (NSPoint) positionOfGlyph: (NSGlyph)g 
	    precededByGlyph: (NSGlyph)prev 
		  isNominal: (BOOL *)nominal
{
  NSSize size;

  /* subclass should override */
  if (nominal)
    *nominal = YES;

  if (g == NSControlGlyph || prev == NSControlGlyph)
    {
      return NSZeroPoint;
    }

  size = [self advancementForGlyph: prev];
  return NSMakePoint(size.width, size.height);
}

- (float) widthOfString: (NSString *)string
{
  /* subclass should override */
  cairo_text_extents_t ctext;

  cairo_text_extents(_cf, [string UTF8String], &ctext);
  //NSLog (@"widthOfString %@ = %g", string, ctext.width);
  return ctext.width;
}

-(NSGlyph) glyphWithName: (NSString *) glyphName
{
  /* subclass should override */
  /* terrible! FIXME */
  NSGlyph g = [glyphName cString][0];

  return g;
}

/* need cairo to export its cairo_path_t first */
- (void) appendBezierPathWithGlyphs: (NSGlyph *)glyphs 
			      count: (int)count 
		       toBezierPath: (NSBezierPath *)path
{
  /* TODO LATER
     cairo_t *ct;
     int i;
     NSPoint start = [path currentPoint];
     cairo_glyph_t *cairo_glyphs;

     cairo_glyphs = malloc(sizeof(cairo_glyph_t) * count);
     ct = cairo_create();


     cairo_destroy(ct);
   */

#if 0
  int i;
  NSGlyph glyph;

  FT_Matrix ftmatrix;
  FT_Vector ftdelta;

  NSPoint p = [path currentPoint];

  ftmatrix.xx = 65536;
  ftmatrix.xy = 0;
  ftmatrix.yx = 0;
  ftmatrix.yy = 65536;
  ftdelta.x = p.x * 64.0;
  ftdelta.y = p.y * 64.0;

  for (i = 0; i < count; i++, glyphs++)
    {
      FT_Face face;
      FT_Glyph gl;
      FT_OutlineGlyph og;

      glyph = *glyphs - 1;

      if (FTC_Manager_Lookup_Size(ftc_manager, &_imgd.font, &face, 0))
	continue;
      if (FT_Load_Glyph(face, glyph, FT_LOAD_DEFAULT))
	continue;

      if (FT_Get_Glyph(face->glyph, &gl))
	continue;

      if (FT_Glyph_Transform(gl, &ftmatrix, &ftdelta))
	{
	  NSLog(@"glyph transformation failed!");
	  continue;
	}
      og = (FT_OutlineGlyph)gl;

      ftdelta.x += gl->advance.x >> 10;
      ftdelta.y += gl->advance.y >> 10;

      FT_Outline_Decompose(&og->outline, &bezierpath_funcs, path);
      FT_Done_Glyph(gl);
    }

  if (count)
    {
      [path moveToPoint: NSMakePoint(ftdelta.x / 64.0,
				     ftdelta.y / 64.0)];
    }
#endif
}

- (void) set
{
  NSLog(@"ignore -set method of font '%@'\n", fontName);
}

@end
