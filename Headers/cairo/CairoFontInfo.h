/*
 * CairoFontInfo.h

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
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
 */


#ifndef WOOM_CairoFontInfo_h
#define WOOM_CairoFontInfo_h

#include <GNUstepGUI/GSFontInfo.h>
#include <Foundation/NSMapTable.h>

#include "cairo/CairoFontEnumerator.h"
#include "cairo/CairoFontManager.h"

#include <cairo.h>

@interface CairoFontInfo : GSFontInfo
{
@public
	cairo_t *_cf;
	cairo_font_t *xrFont;

	CairoFaceInfo *_faceInfo;

	BOOL _screenFont;

	/* will be used in GSNFont subclass
	NSMapTable *_ligatureMap;
	NSMapTable *_kerningMap;
	*/

	unsigned int _cacheSize;
	unsigned int *_cachedGlyphs;
	NSSize *_cachedSizes;
}
- (void) setCacheSize:(unsigned int)size;
@end

#endif
