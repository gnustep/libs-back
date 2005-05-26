/*
 * CairoFontInfo.m
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 * April 27, 2004
 * Written by Banlu Kemiyatorn <lastlifeintheuniverse at hotmail dot com>
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
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include "cairo/CairoFontInfo.h"
#include <cairo.h>
@class NSAffineTransform;


@implementation CairoFontInfo

/* TODO port this freetype code so it can be shared with other backends */
/* TODO or simply use cairo's text/glyph extense */

static FT_Library ft_library;
static FTC_Manager ftc_manager;

+ (void) initializeBackend
{
	NSLog(@"CairoFreeTypeFontInfo : Initializing...");
	[super initializeBackend];

	[GSFontInfo setDefaultClass: self];

	if (FT_Init_FreeType(&ft_library))
		NSLog(@"FT_Init_FreeType failed");
}

- (void) setFaceId:(void *)face_id
{
	_imgd.font.face_id = (FTC_FaceID)face_id;
}

- (id) initWithFontName:(NSString *)name
				 matrix:(const float *)fmatrix
			 screenFont:(BOOL)p_screenFont
{
	FT_Size size;
	FT_Face face;

	[super initWithFontName:name
					 matrix:fmatrix
				 screenFont:p_screenFont];

	_imgd.font.pix_width = fabs(matrix[0]);
	_imgd.font.pix_height = fabs(matrix[3]);
	if ((error=FTC_Manager_Lookup_Size(ftc_manager, &_imgd.font, &face, &size)))
	{
		NSLog(@"FTC_Manager_Lookup_Size() failed for '%@', error %08x!\n", name, error);
		return self;
	}

	ascender = fabs(((int)size->metrics.ascender) / 64.0);
	descender = fabs(((int)size->metrics.descender) / 64.0);
	xHeight = ascender * 0.5; /* TODO */
	maximumAdvancement = NSMakeSize((_size->metrics.max_advance / 64.0), ascender + descender);

	fontBBox = NSMakeRect(0, descender, maximumAdvancement.width, ascender + descender);
	descender = -descender;

	{
		float xx, yy;

		FTC_ImageTypeRec cur;

		cur = _imgd;

		xx = matrix[0];
		yy = matrix[3];

		if (xx == yy && xx < 16 && xx >= 8)
		{
			int rh = _faceInfo->_render_hints_hack;
			if (rh & 0x10000)
			{
				cur.flags = FT_LOAD_TARGET_NORMAL;
				rh = (rh >> 8) & 0xff;
			}
			else
			{
				cur.flags = FT_LOAD_TARGET_MONO;
				rh = rh & 0xff;
			}
			if (rh & 1)
				cur.flags |= FT_LOAD_FORCE_AUTOHINT;
			if (!(rh & 2))
				cur.flags |= FT_LOAD_NO_HINTING;
		}
		else if (xx < 8)
			cur.flags = FT_LOAD_TARGET_NORMAL | FT_LOAD_NO_HINTING;
		else
			cur.flags = FT_LOAD_TARGET_NORMAL;
		_advancementImgd = cur;
	}

	/* create font here */

	FT_New_Face(ft_library, [[_faceInfo->files] objectAtIndex:0]);
	_font = cairo_ft_font_create(&face);


	return self;
}

- (BOOL) glyphIsEncoded: (NSGlyph)glyph
{
	[self subclassResponsibility: _cmd];
	return NO;
}

- (NSSize) advancementForGlyph: (NSGlyph)glyph
{
	cairo_glyph_t cglyph;
	cairo_text_extents_t ctext;

	glyph--;


	if (screenFont)
	{
		int entry = glyph % CACHE_SIZE;

		if (cachedGlyph[entry] == glyph)
			return cachedSize[entry];

		if ((error=FTC_SBitCache_Lookup(ftc_sbitcache, &advancementImgd, glyph, &sbit, NULL)))
		{
			NSLog(@"FTC_SBitCache_Lookup() failed with error %08x (%08x, %08x, %ix%i, %08x)\n",
					error, glyph, advancementImgd.font.face_id,
					advancementImgd.font.pix_width, advancementImgd.font.pix_height,
					advancementImgd.flags
				 );
			return NSZeroSize;
		}

		cachedGlyph[entry] = glyph;
		cachedSize[entry] = NSMakeSize(sbit->xadvance, sbit->yadvance);
		return cachedSize[entry];
	}
	else
	{
		FT_Face face;
		FT_Glyph gl;
		FT_Matrix ftmatrix;
		FT_Vector ftdelta;
		float f;
		NSSize s;

		f = fabs(matrix[0] * matrix[3] - matrix[1] * matrix[2]);
		if (f > 1)
			f = sqrt(f);
		else
			f = 1.0;

		f = (int)f;

		ftmatrix.xx = matrix[0] / f * 65536.0;
		ftmatrix.xy = matrix[1] / f * 65536.0;
		ftmatrix.yx = matrix[2] / f * 65536.0;
		ftmatrix.yy = matrix[3] / f * 65536.0;
		ftdelta.x = ftdelta.y = 0;

		if (FTC_Manager_Lookup_Size(ftc_manager, &_imgd.font, &face, 0))
			return NSZeroSize;

		if (FT_Load_Glyph(face, glyph, FT_LOAD_NO_HINTING | FT_LOAD_NO_BITMAP))
			return NSZeroSize;

		if (FT_Get_Glyph(face->glyph, &gl))
			return NSZeroSize;

		if (FT_Glyph_Transform(gl, &ftmatrix, &ftdelta))
			return NSZeroSize;

		s = NSMakeSize(gl->advance.x / 65536.0, gl->advance.y / 65536.0);

		FT_Done_Glyph(gl);

		return s;
	}
}

- (NSRect) boundingRectForGlyph: (NSGlyph)glyph
{
	FTC_ImageTypeRec *cur;
	FT_BBox bbox;
	FT_Glyph g;
	FT_Error error;

	glyph--;
	/* TODO: this is ugly */
	cur = &_imgd;
	if ((error=FTC_ImageCache_Lookup(ftc_imagecache, cur, glyph, &g, NULL)))
	{
		NSLog(@"FTC_ImageCache_Lookup() failed with error %08x",error);
		//		NSLog(@"boundingRectForGlyph: %04x -> %i\n", aGlyph, glyph);
		return fontBBox;
	}

	FT_Glyph_Get_CBox(g, ft_glyph_bbox_gridfit, &bbox);

	/*	printf("got cbox for %04x: %i, %i - %i, %i\n",
		aGlyph, bbox.xMin, bbox.yMin, bbox.xMax, bbox.yMax);*/

	return NSMakeRect(bbox.xMin / 64.0, bbox.yMin / 64.0,
			(bbox.xMax - bbox.xMin) / 64.0, (bbox.yMax - bbox.yMin) / 64.0);
}

-(NSPoint) positionOfGlyph: (NSGlyph)g
		   precededByGlyph: (NSGlyph)prev
				 isNominal: (BOOL *)nominal
{
	NSPoint a;
	FT_Face face;
	FT_Vector vec;
	FT_GlyphSlot glyph;

	g--;
	prev--;

	if (nominal)
		*nominal = YES;

	if (g == NSControlGlyph || prev == NSControlGlyph)
		return NSZeroPoint;

	if (FTC_Manager_Lookup_Size(ftc_manager, &_imgd.font, &face, 0))
		return NSZeroPoint;

	if (FT_Load_Glyph(face, prev, FT_LOAD_DEFAULT))
		return NSZeroPoint;

	glyph = face->glyph;
	a = NSMakePoint(glyph->advance.x / 64.0, glyph->advance.y / 64.0);

	if (FT_Get_Kerning(face, prev, g, ft_kerning_default, &vec))
		return a;

	if (vec.x == 0 && vec.y == 0)
		return a;

	if (nominal)
		*nominal = NO;

	a.x += vec.x / 64.0;
	a.y += vec.y / 64.0;
	return a;
}

- (float) widthOfString: (NSString*)string
{
	unichar ch;
	int i, c = [string length];
	int total;

	FTC_CMapDescRec cmap;
	unsigned int glyph;

	FTC_SBit sbit;

	FTC_ImageTypeRec *cur;

	cmap.face_id = _imgd.font.face_id;
	cmap.u.encoding = ft_encoding_unicode;
	cmap.type = FTC_CMAP_BY_ENCODING;

	total = 0;
	for (i = 0; i < c; i++)
	{
		ch = [string characterAtIndex: i];
		cur = &_imgd;
		glyph = FTC_CMapCache_Lookup(ftc_cmapcache, &cmap, ch);

		/* TODO: shouldn't use sbit cache for this */
		if (1)
		{
			if (FTC_SBitCache_Lookup(ftc_sbitcache, cur, glyph, &sbit, NULL))
				continue;

			total += sbit->xadvance;
		}
		else
		{
			NSLog(@"non-sbit code not implemented");
		}
	}
	return total;
}

-(NSGlyph) glyphWithName: (NSString *)glyphName
{
	FT_Face face;
	NSGlyph g;

	if (FTC_Manager_Lookup_Size(ftc_manager, &_imgd.font, &face, 0))
		return NSNullGlyph;

	g = FT_Get_Name_Index(face, (FT_String *)[glyphName lossyCString]);
	if (g)
		return g + 1;

	return NSNullGlyph;
}

/* need cairo to export its cairo_path_t first */
-(void) appendBezierPathWithGlyphs: (NSGlyph *)glyphs
							 count: (int)count
					  toBezierPath: (NSBezierPath *)path
{
	cairo_t *ct;
	int i;
	/* TODO LATER
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
		[path moveToPoint: NSMakePoint(ftdelta.x / 64.0, ftdelta.y / 64.0)];
	}
#endif
}

- (void) set
{
	NSLog(@"ignore -set method of font '%@'\n", fontName);
}

/*** CairoFontInfo Protocol ***/


@end
