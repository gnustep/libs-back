/*
 * CairoFreeTypeFontInfo.h
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 * April 27, 2004
 * Written by Banlu Kemiyatorn <lastlifeintheuniverse at hotmail dot com>
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


#ifndef WOOM_CairoFreeTypeFontInfo_h
#define WOOM_CairoFreeTypeFontInfo_h

#include <Foundation/NSMapTable.h>
#include "nfont/GSNFont.h"
#include "cairo/CairoFontInfo.h"

#include <cairo.h>

#define CACHE_SIZE 257

@interface CairoFreeTypeFontInfo : CairoFontInfo
{
@public
	/* We will implement FTC in cairo instead
	FTC_ImageTypeRec _imgd;

	FTC_ImageTypeRec _advancementImgd;
	*/
}
@end

#endif
