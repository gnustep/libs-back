/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

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

#ifndef ARTGState_h
#define ARTGState_h

#include "art/ARTContext.h"
#include "gsc/GSGState.h"

#ifndef RDS
#include "x11/XGServer.h"
#include "x11/XGServerWindow.h"
#else
#include "rds/RDSClient.h"
#endif


#include <libart_lgpl/libart.h>


@class ARTWindowBuffer;


@interface ARTGState : GSGState
{
	unsigned char fill_color[4],stroke_color[4];

	float line_width;
	int linecapstyle,linejoinstyle;
	float miter_limit;

	struct _ArtVpathDash dash;
	int do_dash;


	ARTWindowBuffer *wi;

	int clip_x0,clip_y0,clip_x1,clip_y1;
	BOOL all_clipped;
#define CLIP_DATA (wi->data+clip_x0*wi->bytes_per_pixel+clip_y0*wi->bytes_per_line)
	int clip_sx,clip_sy;

	ArtSVP *clip_path;
}

@end


extern struct draw_info_s ART_DI;
#define DI ART_DI


#endif

