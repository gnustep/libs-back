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
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02111 USA.
 */

#include "GNUstepBase/Unicode.h"
#include <AppKit/NSAffineTransform.h>
#include "cairo/CairoFontInfo.h"
#include "cairo/CairoFontEnumerator.h"

#include <math.h>
#include <cairo-ft.h>

@implementation CairoFontInfo 

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
  memset(_cachedSizes, 0, sizeof(NSSize) * size);
  _cachedGlyphs = malloc(sizeof(unsigned int) * size);
  memset(_cachedGlyphs, 0, sizeof(unsigned int) * size);
}

- (BOOL) setupAttributes
{
  cairo_font_extents_t font_extents;
  cairo_font_face_t *face;
  cairo_matrix_t font_matrix;
  cairo_matrix_t ctm;
  cairo_font_options_t *options;

  /* do not forget to check for font specific
   * cache size from face info FIXME FIXME
   */
  ASSIGN(_faceInfo, [CairoFontEnumerator fontWithName: fontName]);
  if (!_faceInfo)
    {
      return NO;
    }

  _cachedSizes = NULL;
  [self setCacheSize: [_faceInfo cacheSize]];

  /* setting GSFontInfo:
   * weight, traits, familyName,
   * mostCompatibleStringEncoding, encodingScheme,
   */

  weight = [_faceInfo weight];
  traits = [_faceInfo traits];
  familyName = [[_faceInfo familyName] copy];
  mostCompatibleStringEncoding = NSUTF8StringEncoding;
  encodingScheme = @"iso10646-1";

  /* setting GSFontInfo:
   * xHeight, pix_width, pix_height
   */
  cairo_matrix_init(&font_matrix, matrix[0], matrix[1], matrix[2],
		    -matrix[3], matrix[4], matrix[5]);
  cairo_matrix_init_identity(&ctm);
  // FIXME: Should get default font options from somewhere
  options = cairo_font_options_create();
  face = [_faceInfo fontFace];
  if (!face)
    {
      return NO;
    }
  _scaled = cairo_scaled_font_create(face, &font_matrix, &ctm, options);
  cairo_font_options_destroy(options);
  if (!_scaled)
    {
      return NO;
    }
  cairo_scaled_font_extents(_scaled, &font_extents);
  // FIXME: Need some adjustment here
  ascender = font_extents.ascent + 3;
  descender = font_extents.descent;
  xHeight = font_extents.height;
  maximumAdvancement = NSMakeSize(font_extents.max_x_advance, 
				  font_extents.max_y_advance);
  fontBBox = NSMakeRect(0, descender, 
			maximumAdvancement.width, ascender + descender);

  return YES;
}

- (id) initWithFontName: (NSString *)name 
		 matrix: (const float *)fmatrix 
	     screenFont: (BOOL)p_screenFont
{
  //NSLog(@"initWithFontName %@",name);
  [super init];

  _screenFont = p_screenFont;
  fontName = [name copy];
  memcpy(matrix, fmatrix, sizeof(matrix));

  if (_screenFont)
    {
      /* Round up; makes the text more legible. */
      matrix[0] = ceil(matrix[0]);
      if (matrix[3] < 0.0)
	matrix[3] = floor(matrix[3]);
      else
	matrix[3] = ceil(matrix[3]);
    }

  if (![self setupAttributes])
    {
      RELEASE(self);
      return nil;
    }

  return self;
}

- (void) dealloc
{
  RELEASE(_faceInfo);
  if (_scaled)
    {
      cairo_scaled_font_destroy(_scaled);
    }
  free(_cachedSizes);
  free(_cachedGlyphs);
  [super dealloc];
}

- (BOOL) glyphIsEncoded: (NSGlyph)glyph
{
  /* subclass should override */
  return YES;
}

static
BOOL _cairo_extents_for_NSGlyph(cairo_scaled_font_t *scaled_font, NSGlyph glyph,
				cairo_text_extents_t *ctext)
{
  unichar ustr[2];
  char str[4];
  unsigned char *b;
  unsigned int size = 4;
  int length = 1;

  ustr[0] = glyph;
  ustr[1] = 0;

  b = (unsigned char *)str;
  if (!GSFromUnicode(&b, &size, ustr, length, 
		     NSUTF8StringEncoding, NULL, GSUniTerminate))
    {
      NSLog(@"Conversion failed for %@", 
	    [NSString stringWithCharacters: ustr length: length]);
      return NO;
    }

  cairo_scaled_font_text_extents(scaled_font, str, ctext);
  return cairo_scaled_font_status(scaled_font) == CAIRO_STATUS_SUCCESS;
}

- (NSSize) advancementForGlyph: (NSGlyph)glyph
{
  cairo_text_extents_t ctext;
  int entry;

  entry = glyph % _cacheSize;

  if (_cachedGlyphs[entry] == glyph)
    {
      return _cachedSizes[entry];
    }

  if (_cairo_extents_for_NSGlyph(_scaled, glyph, &ctext))
    {
      _cachedGlyphs[entry] = glyph;
      _cachedSizes[entry] = NSMakeSize(ctext.x_advance, ctext.y_advance);

      return _cachedSizes[entry];
    }

  return NSZeroSize;
}

- (NSRect) boundingRectForGlyph: (NSGlyph)glyph
{
  cairo_text_extents_t ctext;

  if (_cairo_extents_for_NSGlyph(_scaled, glyph, &ctext))
    {
      return NSMakeRect(ctext.x_bearing, ctext.y_bearing,
			ctext.width, ctext.height);
    }

  return NSZeroRect;
}

- (float) widthOfString: (NSString *)string
{
  cairo_text_extents_t ctext;

	cairo_scaled_font_text_extents(_scaled, [string UTF8String], &ctext);
  if (cairo_scaled_font_status(_scaled) == CAIRO_STATUS_SUCCESS)
    {
      return ctext.width;
    }

  return 0.0;
}

- (NSGlyph) glyphWithName: (NSString *) glyphName
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
}

- (void) drawGlyphs: (const NSGlyph*)glyphs
	     length: (int)length 
	         on: (cairo_t*)ct
{
  cairo_matrix_t font_matrix;
  unichar ustr[length+1];
  char str[3*length+1];
  unsigned char *b;
  int i;
  unsigned int size = 3*length+1;

  for (i = 0; i < length; i++)
    {
      ustr[i] = glyphs[i];
    }
  ustr[length] = 0;

  b = (unsigned char *)str;
  if (!GSFromUnicode(&b, &size, ustr, length, 
		     NSUTF8StringEncoding, NULL, GSUniTerminate))
    {
      NSLog(@"Conversion failed for %@", 
	    [NSString stringWithCharacters: ustr length: length]);
      return;
    }

  cairo_matrix_init(&font_matrix, matrix[0], matrix[1], matrix[2],
		    -matrix[3], matrix[4], matrix[5]);
  cairo_set_font_matrix(ct, &font_matrix);
  if (cairo_status(ct) != CAIRO_STATUS_SUCCESS)
    {
	NSLog(@"Error while setting font matrix: %s", 
	      cairo_status_to_string(cairo_status(ct)));
	return;
    }
  cairo_set_font_face(ct, [_faceInfo fontFace]);
  if (cairo_status(ct) != CAIRO_STATUS_SUCCESS)
    {
	NSLog(@"Error while setting font face: %s", 
	      cairo_status_to_string(cairo_status(ct)));
	return;
    }

  // FIXME: Need some adjustment here
  cairo_rel_move_to(ct, 0.0, -5.0);
  cairo_show_text(ct, str);
  if (cairo_status(ct) != CAIRO_STATUS_SUCCESS)
    {
	NSLog(@"Error drawing string: '%s' for string %s", 
	      cairo_status_to_string(cairo_status(ct)), str);
    }
}
 
@end
