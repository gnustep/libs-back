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

#include <math.h>

#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSColor.h>

#include "ARTGState.h"

#include "ARTWindowBuffer.h"
#include "blit.h"
#include "ftfont.h"

#include <libart_lgpl/art_svp_intersect.h>


#ifndef PI
#define PI 3.14159265358979323846264338327950288
#endif


/*

** subclassResponsibility **
Note that these aren't actually subclassResponsibility anymore; instead
of crashing, they just print a warning.

- (void) dissolveGState: (GSGState *)source
               fromRect: (NSRect)aRect
                toPoint: (NSPoint)aPoint
                  delta: (float)delta

- (void) DPSashow: (float)x : (float)y : (const char*)s
- (void) DPSawidthshow: (float)cx : (float)cy : (int)c : (float)ax : (float)ay 
- (void) DPSwidthshow: (float)x : (float)y : (int)c : (const char*)s
DPSxshow, DPSyshow, DPSxyshow


** Other unimplemented stuff **

FontInfo:
-(void) set

Context:
- (NSColor *) NSReadPixel: (NSPoint) location

*/


/* Portions based on gnustep-back code, eg.: */
/* GSGState - Generic graphic state

   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Mar 2002
   
   This file is part of the GNU Objective C User Interface Library.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */


draw_info_t ART_DI;


#if 0
/* useful when debugging */
static void dump_bpath(ArtBpath *vp)
{
	int i;
	printf("** dumping %p **\n",vp);
	for (i=0;;i++)
	{
		if (vp[i].code==ART_MOVETO_OPEN)
			printf("  moveto_open");
		else if (vp[i].code==ART_MOVETO)
			printf("  moveto");
		else if (vp[i].code==ART_LINETO)
			printf("  lineto");
		else if (vp[i].code==ART_CURVETO)
			printf("  curveto");
		else
			printf("  unknown %i",vp[i].code);

		printf(" (%g %g) (%g %g) (%g %g)\n",
			vp[i].x1,vp[i].y1,
			vp[i].x2,vp[i].y2,
			vp[i].x3,vp[i].y3);
		if (vp[i].code==ART_END)
			break;
	}
}

{
	int i;
	NSBezierPathElement type;
	NSPoint pts[3];
	for (i=0;i<[newPath elementCount];i++)
	{
		type=[newPath elementAtIndex: i associatedPoints: pts];
		switch (type)
		{
		case NSMoveToBezierPathElement:
			printf("moveto (%g %g)\n",pts[0].x,pts[0].y);
			break;
		case NSLineToBezierPathElement:
			printf("lineto (%g %g)\n",pts[0].x,pts[0].y);
			break;
		case NSCurveToBezierPathElement:
			printf("curveto (%g %g) (%g %g) (%g %g)\n",
				pts[0].x,pts[0].y,
				pts[1].x,pts[1].y,
				pts[2].x,pts[2].y);
			break;
		}
	}
}

#endif


@implementation ARTGState


/* TODO:
optimize all this. passing device_color_t structures around by value is
very expensive
*/
-(void) setColor: (device_color_t *)color  state: (color_state_t)cState
{
	device_color_t c;
	unsigned char r,g,b;

	[super setColor: color  state: cState];
	if (cState&(COLOR_FILL|COLOR_STROKE))
	{
		c=fillColor;
		gsColorToRGB(&c); /* TODO: check this */
		if (c.field[0]>1.0) c.field[0]=1.0;
		if (c.field[0]<0.0) c.field[0]=0.0;
		r=c.field[0]*255;
		if (c.field[1]>1.0) c.field[1]=1.0;
		if (c.field[1]<0.0) c.field[1]=0.0;
		g=c.field[1]*255;
		if (c.field[2]>1.0) c.field[2]=1.0;
		if (c.field[2]<0.0) c.field[2]=0.0;
		b=c.field[2]*255;

		if (cState&COLOR_FILL)
		{
			fill_color[0]=r;
			fill_color[1]=g;
			fill_color[2]=b;
			fill_color[3]=fillColor.field[AINDEX]*255;
		}
		if (cState&COLOR_STROKE)
		{
			stroke_color[0]=r;
			stroke_color[1]=g;
			stroke_color[2]=b;
			stroke_color[3]=strokeColor.field[AINDEX]*255;
		}
	}
}

/* specially optimized versions (since these are common and simple) */
-(void) DPSsetgray: (float)gray
{
  if (gray < 0.0) gray = 0.0;
  if (gray > 1.0) gray = 1.0;

  fillColor.space = strokeColor.space = gray_colorspace;
  fillColor.field[0] = strokeColor.field[0] = gray;
  cstate = COLOR_FILL | COLOR_STROKE;

  stroke_color[0] = stroke_color[1] = stroke_color[2] =
    fill_color[0] = fill_color[1] = fill_color[2] = gray * 255;
}

-(void) DPSsetalpha: (float)a
{
  if (a < 0.0) a = 0.0;
  if (a > 1.0) a = 1.0;
  fillColor.field[AINDEX] = strokeColor.field[AINDEX] = a;
  stroke_color[3] = fill_color[3] = a * 255;
}

- (void) DPSsetrgbcolor: (float)r : (float)g : (float)b
{
  if (r < 0.0) r = 0.0; if (r > 1.0) r = 1.0;
  if (g < 0.0) g = 0.0; if (g > 1.0) g = 1.0;
  if (b < 0.0) b = 0.0; if (b > 1.0) b = 1.0;

  fillColor.space = strokeColor.space = rgb_colorspace;
  fillColor.field[0] = strokeColor.field[0] = r;
  fillColor.field[1] = strokeColor.field[1] = g;
  fillColor.field[2] = strokeColor.field[2] = b;
  cstate = COLOR_FILL | COLOR_STROKE;

  stroke_color[0] = fill_color[0] = r * 255;
  stroke_color[1] = fill_color[1] = g * 255;
  stroke_color[2] = fill_color[2] = b * 255;
}


/* ----------------------------------------------------------------------- */
/* Text operations */
/* ----------------------------------------------------------------------- */
- (void) DPSashow: (float)x : (float)y : (const char*)s
{ /* TODO: adds (x,y) in user space to each glyph's x/y advancement */
	NSLog(@"ignoring DPSashow: %g : %g : '%s'",x,y,s);
}

- (void) DPSawidthshow: (float)cx : (float)cy : (int)c : (float)ax : (float)ay 
		      : (const char*)s
{ /* TODO: add (ax,ay) in user space to each glyph's x/y advancement and
 additionally add (cx,cy) to the character c's advancement */
	NSLog(@"ignoring DPSawidthshow: %g : %g : %i : %g : %g : '%s'",
		cx,cy,c,ax,ay,s);
}

- (void) DPScharpath: (const char*)s : (int)b
{ /* TODO: handle b? will freetype ever give us a stroke-only font? */
	NSPoint p;

	if ([path isEmpty]) return;
	p=[self currentPoint];

	[(id<FTFontInfo>)[font fontInfo]
		outlineString: s
		at: p.x:p.y
		gstate: self];
	[self DPSclosepath];
}

- (void) DPSshow: (const char*)s
{
	NSPoint p;
	int x,y;

	if (!wi || !wi->data) return;
	if (all_clipped)
		return;

	if ([path isEmpty]) return;
	p=[path currentPoint];

	x=p.x;
	y=wi->sy-p.y;
	[(id<FTFontInfo>)[font fontInfo]
		drawString: s
		at: x:y
		to: clip_x0:clip_y0:clip_x1:clip_y1:CLIP_DATA:wi->bytes_per_line
		color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
		transform: ctm
		drawinfo: &DI];
}

- (void) DPSwidthshow: (float)x : (float)y : (int)c : (const char*)s
{ /* TODO: add (x,y) user-space to the character c's advancement */
	NSLog(@"ignoring DPSwidthshow: %g : %g : %i : '%s'",x,y,c,s);
}

- (void) DPSxshow: (const char*)s : (const float*)numarray : (int)size
{
	NSPoint p;
	int x,y;

	if (!wi || !wi->data) return;
	if (all_clipped)
		return;

	if ([path isEmpty]) return;
	p=[path currentPoint];

	x=p.x;
	y=wi->sy-p.y;
	[(id<FTFontInfo>)[font fontInfo]
		drawString: s
		at: x:y
		to: clip_x0:clip_y0:clip_x1:clip_y1:CLIP_DATA:wi->bytes_per_line
		color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
		transform: ctm
		deltas: numarray : size : 1];
}

- (void) DPSxyshow: (const char*)s : (const float*)numarray : (int)size
{
	NSPoint p;
	int x,y;

	if (!wi || !wi->data) return;
	if (all_clipped)
		return;

	if ([path isEmpty]) return;
	p=[path currentPoint];

	x=p.x;
	y=wi->sy-p.y;
	[(id<FTFontInfo>)[font fontInfo]
		drawString: s
		at: x:y
		to: clip_x0:clip_y0:clip_x1:clip_y1:CLIP_DATA:wi->bytes_per_line
		color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
		transform: ctm
		deltas: numarray : size : 3];
}

- (void) DPSyshow: (const char*)s : (const float*)numarray : (int)size
{
	NSPoint p;
	int x,y;

	if (!wi || !wi->data) return;
	if (all_clipped)
		return;

	if ([path isEmpty]) return;
	p=[path currentPoint];

	x=p.x;
	y=wi->sy-p.y;
	[(id<FTFontInfo>)[font fontInfo]
		drawString: s
		at: x:y
		to: clip_x0:clip_y0:clip_x1:clip_y1:CLIP_DATA:wi->bytes_per_line
		color: fill_color[0]:fill_color[1]:fill_color[2]:fill_color[3]
		transform: ctm
		deltas: numarray : size : 2];
}


/* ----------------------------------------------------------------------- */
/* Gstate operations */
/* ----------------------------------------------------------------------- */
- (void) DPSinitgraphics
{
	[super DPSinitgraphics];

	line_width=1.0;
	linecapstyle=ART_PATH_STROKE_CAP_BUTT;
	linejoinstyle=ART_PATH_STROKE_JOIN_MITER;
	miter_limit=10.0;
	if (dash.n_dash)
	{
		free(dash.dash);
		dash.dash=NULL;
		dash.n_dash=0;
		do_dash=0;
	}
}

- (void) DPScurrentlinecap: (int*)linecap
{
	switch (linecapstyle)
	{
	default:
	case ART_PATH_STROKE_CAP_BUTT:
		*linecap=NSButtLineCapStyle;
		break;
	case ART_PATH_STROKE_CAP_ROUND:
		*linecap=NSRoundLineCapStyle;
		break;
	case ART_PATH_STROKE_CAP_SQUARE:
		*linecap=NSSquareLineCapStyle;
		break;
	}
}

- (void) DPScurrentlinejoin: (int*)linejoin
{
	switch (linejoinstyle)
	{
	default:
	case ART_PATH_STROKE_JOIN_MITER:
		*linejoin=NSMiterLineJoinStyle;
		break;
	case ART_PATH_STROKE_JOIN_ROUND:
		*linejoin=NSRoundLineJoinStyle;
		break;
	case ART_PATH_STROKE_JOIN_BEVEL:
		*linejoin=NSBevelLineJoinStyle;
		break;
	}
}

- (void) DPScurrentlinewidth: (float*)width
{
	*width=line_width;
}

- (void) DPScurrentmiterlimit: (float*)limit
{
	*limit=miter_limit;
}

- (void) DPScurrentstrokeadjust: (int*)b
{
	/* TODO We never stroke-adjust, see DPSsetstrokeadjust. */
	*b=0;
}

- (void) DPSsetdash: (const float*)pat : (int)size : (float)offs
{
	int i;

	if (dash.n_dash)
	{
		free(dash.dash);
		dash.dash=NULL;
		dash.n_dash=0;
		do_dash=0;
	}

	if (size>0)
	{
		dash.offset=offs;
		dash.n_dash=size;
		dash.dash=malloc(sizeof(double)*size);
		if (!dash.dash)
		{
			/* Revert to no dash. Better than crashing. */
			dash.n_dash=0;
			dash.offset=0;
			do_dash=0;
		}
		else
		{
			for (i=0;i<size;i++)
				dash.dash[i]=pat[i];
			do_dash=1;
		}
	}
}

- (void) DPSsetlinecap: (int)linecap
{
	switch (linecap)
	{
	default:
	case NSButtLineCapStyle:
		linecapstyle=ART_PATH_STROKE_CAP_BUTT;
		break;
	case NSRoundLineCapStyle:
		linecapstyle=ART_PATH_STROKE_CAP_ROUND;
		break;
	case NSSquareLineCapStyle:
		linecapstyle=ART_PATH_STROKE_CAP_SQUARE;
		break;
	}
}

- (void) DPSsetlinejoin: (int)linejoin
{
	switch (linejoin)
	{
	default:
	case NSMiterLineJoinStyle:
		linejoinstyle=ART_PATH_STROKE_JOIN_MITER;
		break;
	case NSRoundLineJoinStyle:
		linejoinstyle=ART_PATH_STROKE_JOIN_ROUND;
		break;
	case NSBevelLineJoinStyle:
		linejoinstyle=ART_PATH_STROKE_JOIN_BEVEL;
		break;
	}
}

- (void) DPSsetlinewidth: (float)width
{
	line_width=width;
	/* TODO? handle line_width=0 properly */
	if (line_width<=0) line_width=1;
}

- (void) DPSsetmiterlimit: (float)limit
{
	miter_limit=limit;
}

- (void) DPSsetstrokeadjust: (int)b
{
	/* Since we anti-alias stroke-adjustment isn't really applicable.
	TODO:
	However, it might be useful to handle stroke-adjusting by snapping
	to whole pixels when rendering to avoid anti-aliasing of rectangles
	and straight lines. */
}


-(ArtVpath *) _vpath_from_current_path: (BOOL)fill
{
	ArtBpath *bpath,*bp2;
	ArtVpath *vp;
	int i,j,c,cur_start,cur_line;
	NSPoint points[3];
	NSBezierPathElement t;
	double matrix[6];


	c=[path elementCount];
	if (!c)
		return NULL;

	if (fill)
		bpath=art_new(ArtBpath,2*c+1);
	else
		bpath=art_new(ArtBpath,c+1);

	cur_start=-1;
	cur_line=0;
	for (i=j=0;i<c;i++)
	{
		t=[path elementAtIndex: i associatedPoints: points];
		switch (t)
		{
		case NSMoveToBezierPathElement:
			/* When filling, the path must be closed, so if
			it isn't already closed, we fix that here. */
			if (fill)
 			{
				if (cur_start!=-1 && cur_line)
				{
					if (bpath[j-1].x3!=bpath[cur_start].x3 ||
					    bpath[j-1].y3!=bpath[cur_start].y3)
					{
						bpath[j].x3=bpath[cur_start].x3;
						bpath[j].y3=bpath[cur_start].y3;
						bpath[j].code=ART_LINETO;
						j++;
					}
				}
				bpath[j].code=ART_MOVETO;
			}
			else
			{
				bpath[j].code=ART_MOVETO_OPEN;
			}
			bpath[j].x3=points[0].x;
			bpath[j].y3=points[0].y;
			cur_start=j;
			j++;
			cur_line=0;
			break;

		case NSLineToBezierPathElement:
			cur_line++;
			bpath[j].code=ART_LINETO;
			bpath[j].x3=points[0].x;
			bpath[j].y3=points[0].y;
			j++;
			break;

		case NSCurveToBezierPathElement:
			cur_line++;
			bpath[j].code=ART_CURVETO;
			bpath[j].x1=points[0].x;
			bpath[j].y1=points[0].y;
			bpath[j].x2=points[1].x;
			bpath[j].y2=points[1].y;
			bpath[j].x3=points[2].x;
			bpath[j].y3=points[2].y;
			j++;
			break;

		case NSClosePathBezierPathElement:
			if (cur_start!=-1 && cur_line)
			{
				bpath[cur_start].code=ART_MOVETO;
				bpath[j].code=ART_LINETO;
				bpath[j].x3=bpath[cur_start].x3;
				bpath[j].y3=bpath[cur_start].y3;
				j++;
			}
			break;

		default:
			NSLog(@"invalid type %i\n",t);
			art_free(bpath);
			return NULL;
		}
	}

	if (fill && cur_start!=-1 && cur_line)
	{
		if (bpath[j-1].x3!=bpath[cur_start].x3 ||
		    bpath[j-1].y3!=bpath[cur_start].y3)
		{
			bpath[j].x3=bpath[cur_start].x3;
			bpath[j].y3=bpath[cur_start].y3;
			bpath[j].code=ART_LINETO;
			j++;
		}
	}
	bpath[j].code=ART_END;

/*	matrix[0]= ctm->matrix.m11;
	matrix[1]=-ctm->matrix.m12;
	matrix[2]= ctm->matrix.m21;
	matrix[3]=-ctm->matrix.m22;
	matrix[4]= ctm->matrix.tx;
	matrix[5]=-ctm->matrix.ty+wi->sy;*/
	matrix[0]= 1;
	matrix[1]= 0;
	matrix[2]= 0;
	matrix[3]=-1;
	matrix[4]= 0;
	matrix[5]= wi->sy;

	bp2=art_bpath_affine_transform(bpath,matrix);
	art_free(bpath);

	vp=art_bez_path_to_vec(bp2,0.5);
	art_free(bp2);

	return vp;
}


/* will free the passed in svp */
-(void) _clip_add_svp: (ArtSVP *)svp
{
	if (clip_path)
	{
		ArtSVP *svp2;
/*		ArtSvpWriter *svpw;

		svpw=art_svp_writer_rewind_new(ART_WIND_RULE_INTERSECT);
		art_svp_intersector(svp,svpw);
		art_svp_intersector(clip_path,svpw);
		svp2=art_svp_writer_rewind_reap(svpw);*/
		svp2=art_svp_intersect(svp,clip_path);
		art_svp_free(svp);
		art_svp_free(clip_path);
		clip_path=svp2;
	}
	else
	{
		clip_path=svp;
	}
}

-(void) _clip: (int)rule
{
	ArtVpath *vp;
	ArtSVP *svp;

	vp=[self _vpath_from_current_path: NO];
	if (!vp)
		return;
	svp=art_svp_from_vpath(vp);
	art_free(vp);

	{
		ArtSVP *svp2;
		ArtSvpWriter *svpw;

		svpw=art_svp_writer_rewind_new(rule);
		art_svp_intersector(svp,svpw);
		svp2=art_svp_writer_rewind_reap(svpw);
		art_svp_free(svp);
		svp=svp2;
	}

	[self _clip_add_svp: svp];
}

-(ArtSVP *) _clip_svp: (ArtSVP *)svp
{
	ArtSVP *svp2;
//	ArtSvpWriter *svpw;

	if (!clip_path)
		return svp;
/* TODO */
/*	svpw=art_svp_writer_rewind_new(ART_WIND_RULE_INTERSECT);
	art_svp_intersector(svp,svpw);
	art_svp_intersector(clip_path,svpw);
	svp2=art_svp_writer_rewind_reap(svpw);
	art_svp_free(svp);*/

	svp2=art_svp_intersect(svp,clip_path);
	art_svp_free(svp);

	return svp2;
}


- (void) DPSclip
{
	[self _clip: ART_WIND_RULE_NONZERO];
}

- (void) DPSeoclip
{
	[self _clip: ART_WIND_RULE_ODDEVEN];
}


-(void) _fill: (int)rule
{
	ArtVpath *vp;
	ArtSVP *svp;

	if (!wi || !wi->data) return;
	if (all_clipped) return;
	if (!fill_color[3]) return;

	vp=[self _vpath_from_current_path: YES];
	if (!vp)
		return;
	svp=art_svp_from_vpath(vp);
	art_free(vp);

	{
		ArtSVP *svp2;
		ArtSvpWriter *svpw;

		svpw=art_svp_writer_rewind_new(rule);
		art_svp_intersector(svp,svpw);
		svp2=art_svp_writer_rewind_reap(svpw);
		art_svp_free(svp);
		svp=svp2;
	}

	if (clip_path)
		svp=[self _clip_svp: svp];


	artcontext_render_svp(svp,clip_x0,clip_y0,clip_x1,clip_y1,
		fill_color[0],fill_color[1],fill_color[2],fill_color[3],
		CLIP_DATA,wi->bytes_per_line,
		wi->has_alpha?wi->alpha+clip_x0+clip_y0*wi->sx:NULL,wi->sx,
		wi->has_alpha,
		&DI);

	art_svp_free(svp);

	[path removeAllPoints];
}

- (void) DPSeofill
{
	[self _fill: ART_WIND_RULE_ODDEVEN];
}

- (void) DPSfill
{
	[self _fill: ART_WIND_RULE_NONZERO];
}


/* Fills in vp. If the rectangle is axis- (and optionally pixel)-aligned,
also fills in the axis coordinates (x0/y0 is min) and returns 1. Otherwise
returns 0. (Actually, if pixel is NO, it's enough that the edges remain
within one pixel.) */
-(int) _axis_rectangle: (float)x : (float)y : (float)w : (float)h
		 vpath: (ArtVpath *)vp
		  axis: (int *)px0 : (int *)py0 : (int *)px1 : (int *)py1
		 pixel: (BOOL)pixel;
{
	float matrix[6];
	float det;
	int i;
	int x0,y0,x1,y1;

	if (w<0) x+=w,w=-w;
	if (h<0) y+=h,h=-h;

	matrix[0]= ctm->matrix.m11;
	matrix[1]=-ctm->matrix.m12;
	matrix[2]= ctm->matrix.m21;
	matrix[3]=-ctm->matrix.m22;
	matrix[4]= ctm->matrix.tx;
	matrix[5]=-ctm->matrix.ty+wi->sy;

	/* If the matrix is 'inverted', ie. if the determinant is negative,
	we need to flip the order of the vertices. Since it's a rectangle
	we can just swap vertex 1 and 3. */
	det=matrix[0]*matrix[3]-matrix[1]*matrix[2];

	vp[0].code=ART_MOVETO;
	vp[0].x=x*matrix[0]+y*matrix[2]+matrix[4];
	vp[0].y=x*matrix[1]+y*matrix[3]+matrix[5];

	i=det>0?3:1;
	vp[i].code=ART_LINETO;
	vp[i].x=vp[0].x+w*matrix[0];
	vp[i].y=vp[0].y+w*matrix[1];

	vp[2].code=ART_LINETO;
	vp[2].x=vp[0].x+w*matrix[0]+h*matrix[2];
	vp[2].y=vp[0].y+w*matrix[1]+h*matrix[3];

	i^=2;
	vp[i].code=ART_LINETO;
	vp[i].x=vp[0].x+h*matrix[2];
	vp[i].y=vp[0].y+h*matrix[3];

	vp[4].code=ART_LINETO;
	vp[4].x=vp[0].x;
	vp[4].y=vp[0].y;

	vp[5].code=ART_END;
	vp[5].x=vp[5].y=0;

	/* Check if this rectangle is axis-aligned and on whole pixel
	boundaries. */
	x0=vp[0].x+0.5;
	x1=vp[2].x+0.5;
	y0=vp[0].y+0.5;
	y1=vp[2].y+0.5;

	if (pixel)
	{
		if (x0>x1)
			*px0=x1,*px1=x0;
		else
			*px0=x0,*px1=x1;
		if (y0>y1)
			*py0=y1,*py1=y0;
		else
			*py0=y0,*py1=y1;

		if (fabs(vp[0].x-vp[1].x)<0.01 && fabs(vp[1].y-vp[2].y)<0.01 &&
		    fabs(vp[0].x-x0)<0.01 && fabs(vp[0].y-y0)<0.01 &&
		    fabs(vp[2].x-x1)<0.01 && fabs(vp[2].y-y1)<0.01)
		{
			return 1;
		}

		if (fabs(vp[0].y-vp[1].y)<0.01 && fabs(vp[1].x-vp[2].x)<0.01 &&
		    fabs(vp[0].x-x0)<0.01 && fabs(vp[0].y-y0)<0.01 &&
		    fabs(vp[2].x-x1)<0.01 && fabs(vp[2].y-y1)<0.01)
		{
			return 1;
		}
	}
	else
	{
		/* This is used when clipping, so we need to make sure we
		contain all pixels. */
		if (vp[0].x<vp[2].x)
			*px0=floor(vp[0].x),*px1=ceil(vp[2].x);
		else
			*px0=floor(vp[2].x),*px1=ceil(vp[0].x);
		if (vp[0].y<vp[2].y)
			*py0=floor(vp[0].y),*py1=ceil(vp[2].y);
		else
			*py0=floor(vp[2].y),*py1=ceil(vp[0].y);

		if (floor(vp[0].x)==floor(vp[1].x) && floor(vp[0].y)==floor(vp[3].y) &&
		    floor(vp[1].y)==floor(vp[2].y) && floor(vp[2].x)==floor(vp[3].x))
		{
			return 1;
		}

		if (floor(vp[0].y)==floor(vp[1].y) && floor(vp[0].x)==floor(vp[3].x) &&
		    floor(vp[1].x)==floor(vp[2].x) && floor(vp[2].y)==floor(vp[3].y))
		{
			return 1;
		}
	}

	return 0;
}


- (void) DPSinitclip;
{
	if (!wi)
	{
		all_clipped=YES;
		return;
	}

	clip_x0=clip_y0=0;
	clip_x1=wi->sx;
	clip_y1=wi->sy;
	all_clipped=NO;
	clip_sx=clip_x1-clip_x0;
	clip_sy=clip_y1-clip_y0;

	if (clip_path)
	{
		art_svp_free(clip_path);
		clip_path=NULL;
	}
}

- (void) DPSrectclip: (float)x : (float)y : (float)w : (float)h
{
	ArtVpath vp[6];
	ArtSVP *svp;
	int x0,y0,x1,y1;
	int axis_aligned;

	if (all_clipped)
		return;

	if (!wi)
	{
		all_clipped=YES;
		return;
	}

	axis_aligned=[self _axis_rectangle: x : y : w : h vpath: vp
	 	axis: &x0 : &y0 : &x1 : &y1
		pixel: NO];

	if (!axis_aligned)
	{
		svp=art_svp_from_vpath(vp);
		[self _clip_add_svp: svp];
		return;
	}

	if (x0>clip_x0)
		clip_x0=x0;
	if (y0>clip_y0)
		clip_y0=y0;

	if (x1<clip_x1)
		clip_x1=x1;
	if (y1<clip_y1)
		clip_y1=y1;

	if (clip_x0>=clip_x1 || clip_y0>=clip_y1)
	{
		all_clipped=YES;
	}

	clip_sx=clip_x1-clip_x0;
	clip_sy=clip_y1-clip_y0;
}

- (void) DPSrectfill: (float)x : (float)y : (float)w : (float)h
{
	ArtVpath vp[6];
	ArtSVP *svp;
	int x0,y0,x1,y1;
	int axis_aligned;

	if (!wi || !wi->data) return;
	if (all_clipped) return;
	if (!fill_color[3]) return;

	axis_aligned=[self _axis_rectangle: x : y : w : h vpath: vp
	 	axis: &x0 : &y0 : &x1 : &y1
		pixel: YES];

	if (!axis_aligned || clip_path)
	{
	/* Not properly aligned. Handle the general case. */
		svp=art_svp_from_vpath(vp);

		if (clip_path)
			svp=[self _clip_svp: svp];

		artcontext_render_svp(svp,clip_x0,clip_y0,clip_x1,clip_y1,
			fill_color[0],fill_color[1],fill_color[2],fill_color[3],
			CLIP_DATA,wi->bytes_per_line,
			wi->has_alpha?wi->alpha+clip_x0+clip_y0*wi->sx:NULL,wi->sx,
			wi->has_alpha,
			&DI);

		art_svp_free(svp);
		return;
	}

	/* optimize axis- and pixel-aligned rectangles */
	{
		unsigned char *dst=CLIP_DATA;
		render_run_t ri;

		x0-=clip_x0;
		x1-=clip_x0;
		if (x0<=0)
			x0=0;
		else
			dst+=x0*DI.bytes_per_pixel;
		if (x1>clip_sx) x1=clip_sx;

		x1-=x0;
		if (x1<=0)
			return;

		y0-=clip_y0;
		y1-=clip_y0;
		if (y0<=0)
			y0=0;
		else
			dst+=y0*wi->bytes_per_line;
		if (y1>clip_sy) y1=clip_sy;

		if (y1<=y0)
			return;

		ri.dst=dst;
		ri.r=fill_color[0];
		ri.g=fill_color[1];
		ri.b=fill_color[2];
		ri.a=fill_color[3];
		if (wi->has_alpha)
		{
			ri.dsta=wi->alpha+x0+y0*wi->sx;

			if (fill_color[3]==255)
			{
				for (;y0<y1;y0++,ri.dst+=wi->bytes_per_line,ri.dsta+=wi->sx)
					RENDER_RUN_OPAQUE_A(&ri,x1);
			}
			else
			{
				for (;y0<y1;y0++,ri.dst+=wi->bytes_per_line,ri.dsta+=wi->sx)
					RENDER_RUN_ALPHA_A(&ri,x1);
			}
		}
		else
		{
			if (fill_color[3]==255)
			{
				for (;y0<y1;y0++,ri.dst+=wi->bytes_per_line)
					RENDER_RUN_OPAQUE(&ri,x1);
			}
			else
			{
				for (;y0<y1;y0++,ri.dst+=wi->bytes_per_line)
					RENDER_RUN_ALPHA(&ri,x1);
			}
		}
	}
}

- (void) DPSrectstroke: (float)x : (float)y : (float)w : (float)h
{
	ArtVpath *vp,*vp2;
	ArtSVP *svp;
	double matrix[6];
	double temp_scale;

	if (!wi || !wi->data) return;
	if (all_clipped) return;
	if (!stroke_color[3]) return;

	vp=art_new(ArtVpath,6);

	if (line_width==(int)line_width && ((int)line_width)&1)
	{ /* TODO: only do this if stroke-adjust is on? */
	/* TODO: check coordinates to see how much we should adjust */
		x+=0.5;
		y+=0.5;
		w-=1;
		h-=1;
	}

	vp[0].code=ART_MOVETO;
	vp[0].x=x; vp[0].y=y;

	vp[1].code=ART_LINETO;
	vp[1].x=x+w; vp[1].y=y;

	vp[2].code=ART_LINETO;
	vp[2].x=x+w; vp[2].y=y+h;

	vp[3].code=ART_LINETO;
	vp[3].x=x; vp[3].y=y+h;

	vp[4].code=ART_LINETO;
	vp[4].x=x; vp[4].y=y;

	vp[5].code=ART_END;
	vp[5].x=vp[5].y=0;

	matrix[0]=ctm->matrix.m11;
	matrix[1]=-ctm->matrix.m12;
	matrix[2]=ctm->matrix.m21;
	matrix[3]=-ctm->matrix.m22;
	matrix[4]=ctm->matrix.tx;
	matrix[5]=-ctm->matrix.ty+wi->sy;

	/* TODO: this is a hack, but it's better than nothing */
	temp_scale=sqrt(fabs(matrix[0]*matrix[3]-matrix[1]*matrix[2]));
	if (temp_scale<=0) temp_scale=1;

	vp2=art_vpath_affine_transform(vp,matrix);
	art_free(vp);
	vp=vp2;

	if (do_dash)
	{
		/* try to adjust the offset so dashes appear on pixel boundaries
		(otherwise it turns into an antialiased blur) */
		int i;

		dash.offset+=(((int)line_width)&1)/2.0;

		for (i=0;i<dash.n_dash;i++)
			dash.dash[i]*=temp_scale;
		dash.offset*=temp_scale;
		vp2=art_vpath_dash(vp,&dash);
		dash.offset/=temp_scale;
		for (i=0;i<dash.n_dash;i++)
			dash.dash[i]/=temp_scale;
		art_free(vp);
		vp=vp2;

		dash.offset-=(((int)line_width)&1)/2.0;
	}

	svp=art_svp_vpath_stroke(vp,linejoinstyle,linecapstyle,temp_scale*line_width,miter_limit,0.5);
	art_free(vp);

	if (clip_path)
		svp=[self _clip_svp: svp];

	artcontext_render_svp(svp,clip_x0,clip_y0,clip_x1,clip_y1,
		stroke_color[0],stroke_color[1],stroke_color[2],stroke_color[3],
		CLIP_DATA,wi->bytes_per_line,
		wi->has_alpha?wi->alpha+clip_x0+clip_y0*wi->sx:NULL,wi->sx,
		wi->has_alpha,
		&DI);

	art_svp_free(svp);
}

- (void) DPSstroke;
{
/* TODO: Resolve line-width and dash scaling issues. The way this is
currently done is the most obvious libart approach:

1. convert the NSBezierPath to an ArtBpath
2. transform the Bpath
3. convert the Bpath to a Vpath, approximating the curves with lines
  (1-3 are done in -_vpath_from_current_path:)

4. apply dashing to the Vpath
  (art_vpath_dash, called below)
5. stroke and convert the Vpath to an svp
  (art_svp_vpath_stroke, called below)

To do this correctly, we need to do dashing and stroking (4 and part of 5)
in user space. It is possible to do the transform _after_ step 5 (although
it's less efficient), but we want to do any curve approximation (3, and 5 if
there are round line ends or joins) in device space.

The best way to solve this is probably to keep doing the transform first,
and to add transform-aware dashing and stroking functions to libart.

Currently, a single scale value is applied to dashing and stroking. This
will give correct results as long as both axises are scaled the same.

*/
	ArtVpath *vp;
	ArtSVP *svp;
	double temp_scale;

	if (!wi || !wi->data) return;
	if (all_clipped) return;
	if (!stroke_color[3]) return;

	/* TODO: this is wrong. we should transform _after_ we dash and
	stroke */
	vp=[self _vpath_from_current_path: NO];
	if (!vp)
		return;

	/* TODO: this is a hack, but it's better than nothing */
	/* since we flip vertically, the signs here should really be
	inverted, but the fabs() means that it doesn't matter */
	temp_scale=sqrt(fabs(ctm->matrix.m11*ctm->matrix.m22-ctm->matrix.m12*ctm->matrix.m21));
	if (temp_scale<=0) temp_scale=1;

	if (do_dash)
	{
		ArtVpath *vp2;
		int i;
		for (i=0;i<dash.n_dash;i++)
			dash.dash[i]*=temp_scale;
		dash.offset*=temp_scale;
		vp2=art_vpath_dash(vp,&dash);
		dash.offset/=temp_scale;
		for (i=0;i<dash.n_dash;i++)
			dash.dash[i]/=temp_scale;
		art_free(vp);
		vp=vp2;
	}

	svp=art_svp_vpath_stroke(vp,linejoinstyle,linecapstyle,temp_scale*line_width,miter_limit,0.5);
	art_free(vp);

	if (clip_path)
		svp=[self _clip_svp: svp];

	artcontext_render_svp(svp,clip_x0,clip_y0,clip_x1,clip_y1,
		stroke_color[0],stroke_color[1],stroke_color[2],stroke_color[3],
		CLIP_DATA,wi->bytes_per_line,
		wi->has_alpha?wi->alpha+clip_x0+clip_y0*wi->sx:NULL,wi->sx,
		wi->has_alpha,
		&DI);

	art_svp_free(svp);

	[path removeAllPoints];
}

@end


@interface ARTGState (testing)
-(void) GScurrentpath: (NSBezierPath **)p;
@end

@implementation ARTGState (testing)
-(void) GScurrentpath: (NSBezierPath **)p
{
	*p=[path copy];
}
@end


static ArtSVP *copy_svp(ArtSVP *svp)
{
	int i;
	ArtSVP *svp2;
	ArtSVPSeg *dst,*src;

	if (!svp->n_segs)
		return NULL;

	svp2=malloc(sizeof(ArtSVP)+sizeof(ArtSVPSeg)*(svp->n_segs-1));
	if (!svp2)
	{
		NSLog(@"out of memory copying svp");
		return NULL;
	}

	svp2->n_segs=svp->n_segs;

	for (i=0,src=svp->segs,dst=svp2->segs;i<svp->n_segs;i++,src++,dst++)
	{
		dst->n_points=src->n_points;
		dst->dir=src->dir;
		dst->bbox=src->bbox;
		if (src->n_points)
		{
			dst->points=malloc(sizeof(ArtPoint)*src->n_points);
			memcpy(dst->points,src->points,sizeof(ArtPoint)*src->n_points);
		}
		else
			dst->points=NULL;
	}

	return svp2;
}


@interface ARTGState (internal_stuff)
#ifdef RDS
-(void) _setup_stuff: (int)window  : (RDSClient *)remote;
#else
-(void) _setup_stuff: (gswindow_device_t *)win : (int)x : (int)y;
-(void) GSCurrentDevice: (void **)device : (int *)x : (int *)y;
#endif
@end

@implementation ARTGState (internal_stuff)


- (void) dealloc
{
	if (dash.dash)
		free(dash.dash);

	if (clip_path)
		art_svp_free(clip_path);

	DESTROY(wi);

	[super dealloc];
}


-(id) deepen
{
  [super deepen];

  if (dash.dash)
  {
	double *tmp=malloc(sizeof(double)*dash.n_dash);
	if (tmp)
	{
		memcpy(tmp,dash.dash,sizeof(double)*dash.n_dash);
		dash.dash=tmp;
	}
	else
	{
		dash.dash=NULL;
		dash.n_dash=0;
		do_dash=0;
	}
  }

  if (clip_path)
  {
	clip_path=copy_svp(clip_path);
  }

  wi=RETAIN(wi);

  return self;
}

#ifdef RDS
-(void) _setup_stuff: (int)window  : (RDSClient *)remote
{
	NSLog(@"_setup_stuff: %i : %p",window,remote);
	DESTROY(wi);
	wi=[ARTWindowBuffer artWindowBufferForWindow: window  remote: remote];
}
#else
-(void) _setup_stuff: (gswindow_device_t *)window : (int)x : (int)y
{
	[self setOffset: NSMakePoint(x, y)];
	DESTROY(wi);
	wi=[ARTWindowBuffer artWindowBufferForWindow: window];
}

-(void) GSCurrentDevice: (void **)device : (int *)x : (int *)y
{
	*x = *y = 0;
	if (wi)
		*device = wi->window;
	else
		*device = NULL;
}

#endif

@end


@implementation ARTContext

+ (void)initializeBackend
{
	NSLog(@"Initializing libart/freetype backend");

	[NSGraphicsContext setDefaultContextClass: [ARTContext class]];

	[FTFontInfo initializeBackend];
}



- (id) initWithContextInfo: (NSDictionary *)info
{
	NSString *contextType;
	contextType = [info objectForKey:
		NSGraphicsContextRepresentationFormatAttributeName];

	self = [super initWithContextInfo: info];
	if (contextType)
	{
		/* Most likely this is a PS or PDF context, so just return what
		   super gave us */
		return self;
	}

	/* Create a default gstate */
	gstate = [[ARTGState allocWithZone: [self zone]] initWithDrawContext: self];
	[gstate DPSsetalpha: 1.0];
	[gstate DPSsetlinewidth: 1.0];

#ifdef RDS
	artcontext_setup_draw_info(&DI,0x000000ff,0x0000ff00,0x00ff0000,32);
#else
	{
		Display *d=[(XGServer *)server xDisplay];
		Visual *v=DefaultVisual(d,DefaultScreen(d));
		int bpp=DefaultDepth(d,DefaultScreen(d));
		XImage *i=XCreateImage(d,v,bpp,ZPixmap,0,NULL,8,8,8,0);
		bpp=i->bits_per_pixel;
		XDestroyImage(i);

		artcontext_setup_draw_info(&DI,v->red_mask,v->green_mask,v->blue_mask,bpp);
	}
#endif
	[ARTWindowBuffer initializeBackendWithDrawInfo: &DI];

	return self;
}


- (void) flushGraphics
{ /* TODO: _really_ flush? (ie. force updates and wait for shm completion?) */
#ifndef RDS
	XFlush([(XGServer *)server xDisplay]);
#endif
}

+(void) waitAllContexts
{
}


#ifndef RDS
+(void) _gotShmCompletion: (Drawable)d
{
	[ARTWindowBuffer _gotShmCompletion: d];
}

-(void) gotShmCompletion: (Drawable)d
{
	[ARTWindowBuffer _gotShmCompletion: d];
}
#endif

//
// Read the Color at a Screen Position
//
- (NSColor *) NSReadPixel: (NSPoint) location
{
	NSLog(@"ignoring NSReadPixel: (%g %g)",location.x,location.y);
	return nil;
}

- (void) beep
{
#ifndef RDS
	XBell([(XGServer *)server xDisplay], 50);
#else
#warning TODO beep
#endif
}

/* Private backend methods */
+(void) handleExposeRect: (NSRect)rect forDriver: (void *)driver
{
	[(ARTWindowBuffer *)driver _exposeRect: rect];
}


/* TODO: this is just for testing */
-(void) GScurrentpath: (NSBezierPath **)p
{
	[(ARTGState *)gstate GScurrentpath: p];
}

@end

@implementation ARTContext (ops)
#ifdef RDS
-(void) _rds_set_device: (int)window  remote: (RDSClient *)remote
{
	NSLog(@"_rds_set_device: %i  remote: %@",window,remote);
	[(ARTGState *)gstate _setup_stuff: window : remote];
}
#else
- (void) GSSetDevice: (void*)device : (int)x : (int)y
{
	[(ARTGState *)gstate _setup_stuff: device : x : y];
}

-(void) GSCurrentDevice: (void **)device : (int *)x : (int *)y
{
	[(ARTGState *)gstate GSCurrentDevice: device : x : y];
}

#endif

@end

