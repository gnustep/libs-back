/*
   Copyright (C) 2002 Free Software Foundation, Inc.

   Author:  Alexander Malmberg <alexander@malmberg.org>

   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#ifndef ftfont_h
#define ftfont_h

@class NSAffineTransform;

@protocol FTFontInfo
-(void) drawString: (const char *)s
	at: (int)x : (int)y
	to: (int)x0 : (int)y0 : (int)x1 : (int)y1
	: (unsigned char *)buf : (int)bpl
	: (unsigned char *)abuf : (int)abpl
	color: (unsigned char)r : (unsigned char)g : (unsigned char)b
	: (unsigned char)alpha
	transform: (NSAffineTransform *)transform
	drawinfo: (struct draw_info_s *)di;

-(void) drawGlyphs: (const NSGlyph *)glyphs : (int)length
	at: (int)x : (int)y
	to: (int)x0 : (int)y0 : (int)x1 : (int)y1
	: (unsigned char *)buf : (int)bpl
	color: (unsigned char)r : (unsigned char)g : (unsigned char)b
	: (unsigned char)alpha
	transform: (NSAffineTransform *)transform
	drawinfo: (struct draw_info_s *)di;

/* TODO: see if this is really necessary */
-(void) drawString: (const char *)s
	at: (int)x:(int)y
	to: (int)x0:(int)y0:(int)x1:(int)y1:(unsigned char *)buf:(int)bpl
	color:(unsigned char)r:(unsigned char)g:(unsigned char)b:(unsigned char)alpha
	transform: (NSAffineTransform *)transform
	deltas: (const float *)delta_data : (int)delta_size : (int)delta_flags;

-(void) outlineString: (const char *)s
	at: (float)x : (float)y
	gstate: (void *)func_param;

+(void) initializeBackend;
@end

@class FTFontInfo;

#endif

