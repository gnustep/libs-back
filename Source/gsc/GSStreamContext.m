/* -*- C++ -*-
   GSStreamContext - Drawing context to a stream.

   Copyright (C) 1995, 2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Nov 1995
   
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

#include "config.h"
#include "gsc/GSContext.h"
#include "gsc/GSStreamContext.h"
#include "gsc/GSStreamGState.h"
#include <AppKit/GSFontInfo.h>
#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSView.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSValue.h>
#include <string.h>


@interface GSStreamContext (Private)

- (void) output: (const char*)s;

@end

@implementation GSStreamContext 

- (void) dealloc
{
  if (gstream)
    fclose(gstream);
  [super dealloc];
}

- initWithContextInfo: (NSDictionary *)info
{
  [super initWithContextInfo: info];
  if (info && [info objectForKey: @"NSOutputFile"])
    {
      NSString *path = [info objectForKey: @"NSOutputFile"];
      gstream = fopen([path fileSystemRepresentation], "w");
      if (!gstream)
        {
	  NSDebugLLog(@"GSContext", @"%@: Could not open printer file %@",
		      DPSinvalidfileaccess, path);
	  return nil;
	}
    }
  else
    {
      NSDebugLLog(@"GSContext", @"%@: No stream file specified",
		  DPSconfigurationerror);
      return nil;
    }

  /* Create a default gstate */
  gstate = [[GSStreamGState allocWithZone: [self zone]] 
	      initWithDrawContext: self];

  return self;
}

- (BOOL)isDrawingToScreen
{
  return NO;
}

@end

@implementation GSStreamContext (Ops)
/* ----------------------------------------------------------------------- */
/* Color operations */
/* ----------------------------------------------------------------------- */
- (void) DPSsetalpha: (float)a
{
  [super DPSsetalpha: a];
  /* This needs to be defined base on the the language level, etc. in
     the Prolog section. */
  fprintf(gstream, "%g GSsetalpha\n", a);
}

- (void) DPSsetcmykcolor: (float)c : (float)m : (float)y : (float)k
{
  [super DPSsetcmykcolor: c : m : y : k];
  fprintf(gstream, "%g %g %g %g setcmykcolor\n", c, m, y, k);
}

- (void) DPSsetgray: (float)gray
{
  [super DPSsetgray: gray];
  fprintf(gstream, "%g setgray\n", gray);
}

- (void) DPSsethsbcolor: (float)h : (float)s : (float)b
{
  [super DPSsethsbcolor: h : s : b];
  fprintf(gstream, "%g %g %g sethsbcolor\n", h, s, b);
}

- (void) DPSsetrgbcolor: (float)r : (float)g : (float)b
{
  [super DPSsetrgbcolor: r : g : b];
  fprintf(gstream, "%g %g %g setrgbcolor\n", r, g, b);
}

- (void) GSSetFillColor: (const float *)values
{
  [self notImplemented: _cmd];
}

- (void) GSSetStrokeColor: (const float *)values
{
  [self notImplemented: _cmd];
}


/* ----------------------------------------------------------------------- */
/* Text operations */
/* ----------------------------------------------------------------------- */
- (void) DPSashow: (float)x : (float)y : (const char*)s
{
  fprintf(gstream, "%g %g (", x, y);
  [self output:s];
  fprintf(gstream, ") ashow\n");
}

- (void) DPSawidthshow: (float)cx : (float)cy : (int)c : (float)ax : (float)ay : (const char*)s
{
  fprintf(gstream, "%g %g %d %g %g (",cx, cy, c, ax, ay);
  [self output:s];
  fprintf(gstream, ") awidthshow\n");
}

- (void) DPScharpath: (const char*)s : (int)b
{
  fprintf(gstream, "(");
  [self output:s];
  fprintf(gstream, ") %d charpath\n", b);
}

- (void) DPSshow: (const char*)s
{
  fprintf(gstream, "(");
  [self output:s];
  fprintf(gstream, ") show\n");
}

- (void) DPSwidthshow: (float)x : (float)y : (int)c : (const char*)s
{
  fprintf(gstream, "%g %g %d (", x, y, c);
  [self output:s];
  fprintf(gstream, ") widthshow\n");
}

- (void) DPSxshow: (const char*)s : (const float*)numarray : (int)size
{
  [self notImplemented: _cmd];
}

- (void) DPSxyshow: (const char*)s : (const float*)numarray : (int)size
{
  [self notImplemented: _cmd];
}

- (void) DPSyshow: (const char*)s : (const float*)numarray : (int)size
{
  [self notImplemented: _cmd];
}


- (void) GSSetCharacterSpacing: (float)extra
{
  [self notImplemented: _cmd];
}

- (void) GSSetFont: (void *)fontref
{
  const float *m = [(GSFontInfo *)fontref matrix];
  fprintf(gstream, "/%s findfont ", [[(GSFontInfo *)fontref fontName] cString]);
  fprintf(gstream, "[%g %g %g %g %g %g] ", m[0], m[1], m[2], m[3], m[4], m[5]);
  fprintf(gstream, " makefont setfont\n");
}

- (void) GSSetFontSize: (float)size
{
  [self notImplemented: _cmd];
}

- (void) GSShowText: (const char *)string : (size_t)length
{
  [self notImplemented: _cmd];
}

- (void) GSShowGlyphs: (const NSGlyph *)glyphs : (size_t)length
{
  [self notImplemented: _cmd];
}


/* ----------------------------------------------------------------------- */
/* Gstate Handling */
/* ----------------------------------------------------------------------- */
- (void) DPSgrestore
{
  [super DPSgrestore];
  fprintf(gstream, "grestore\n");
}

- (void) DPSgsave
{
  [super DPSgsave];
  fprintf(gstream, "gsave\n");
}

- (void) DPSgstate
{
  [super DPSgsave];
  fprintf(gstream, "gstaten");
}

- (void) DPSinitgraphics
{
  [super DPSinitgraphics];
  fprintf(gstream, "initgraphics\n");
}

- (void) DPSsetgstate: (int)gst
{
  [self notImplemented: _cmd];
}

- (int) GSDefineGState
{
  [self notImplemented: _cmd];
  return 0;
}

- (void) GSUndefineGState: (int)gst
{
  [self notImplemented: _cmd];
}

- (void) GSReplaceGState: (int)gst
{
  [self notImplemented: _cmd];
}

/* ----------------------------------------------------------------------- */
/* Gstate operations */
/* ----------------------------------------------------------------------- */
- (void) DPSsetdash: (const float*)pat : (int)size : (float)offset
{
  int i;
  fprintf(gstream, "[");
  for (i = 0; i < size; i++)
    fprintf(gstream, "%f ", pat[i]);
  fprintf(gstream, "] %g setdash\n", offset);
}

- (void) DPSsetflat: (float)flatness
{
  [super DPSsetflat: flatness];
  fprintf(gstream, "%g setflat\n", flatness);
}

- (void) DPSsethalftonephase: (float)x : (float)y
{
  [super DPSsethalftonephase: x : y];
  fprintf(gstream, "%g %g sethalftonephase\n", x, y);
}

- (void) DPSsetlinecap: (int)linecap
{
  [super DPSsetlinecap: linecap];
  fprintf(gstream, "%d setlinecap\n", linecap);
}

- (void) DPSsetlinejoin: (int)linejoin
{
  [super DPSsetlinejoin: linejoin];
  fprintf(gstream, "%d setlinejoin\n", linejoin);
}

- (void) DPSsetlinewidth: (float)width
{
  [super DPSsetlinewidth: width];
  fprintf(gstream, "%g setlinewidth\n", width);
}

- (void) DPSsetmiterlimit: (float)limit
{
  [super DPSsetmiterlimit: limit];
  fprintf(gstream, "%g setmiterlimit\n", limit);
}

- (void) DPSsetstrokeadjust: (int)b
{
  [super DPSsetstrokeadjust: b];
  fprintf(gstream, "%d setstrokeadjust\n", b);
}


/* ----------------------------------------------------------------------- */
/* Matrix operations */
/* ----------------------------------------------------------------------- */
- (void) DPSconcat: (const float*)m
{
  [super DPSconcat: m];
  fprintf(gstream, "[%g %g %g %g %g %g] concat\n",
          m[0], m[1], m[2], m[3], m[4], m[5]);
}

- (void) DPSinitmatrix
{
  [super DPSinitmatrix];
  fprintf(gstream, "initmatrix\n");
}

- (void) DPSrotate: (float)angle
{
  [super DPSrotate: angle];
  fprintf(gstream, "%g rotate\n", angle);
}

- (void) DPSscale: (float)x : (float)y
{
  [super DPSscale: x : y];
  fprintf(gstream, "%g %g scale\n", x, y);
}

- (void) DPStranslate: (float)x : (float)y
{
  [super DPStranslate: x : y];
  fprintf(gstream, "%g %g translate\n", x, y);
}

- (void) GSSetCTM: (NSAffineTransform *)ctm
{
  float m[6];
  [ctm getMatrix: m];
  fprintf(gstream, "[%g %g %g %g %g %g] setmatrix\n",
          m[0], m[1], m[2], m[3], m[4], m[5]);
}

- (void) GSConcatCTM: (NSAffineTransform *)ctm
{
  float m[6];
  [ctm getMatrix: m];
  fprintf(gstream, "[%g %g %g %g %g %g] concat\n",
          m[0], m[1], m[2], m[3], m[4], m[5]);
}


/* ----------------------------------------------------------------------- */
/* Paint operations */
/* ----------------------------------------------------------------------- */
- (void) DPSarc: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2
{
  fprintf(gstream, "%g %g %g %g %g arc\n", x, y, r, angle1, angle2);
}

- (void) DPSarcn: (float)x : (float)y : (float)r : (float)angle1 : (float)angle2
{
  fprintf(gstream, "%g %g %g %g %g arcn\n", x, y, r, angle1, angle2);
}

- (void) DPSarct: (float)x1 : (float)y1 : (float)x2 : (float)y2 : (float)r
{
  fprintf(gstream, "%g %g %g %g %g arct\n", x1, y1, x2, y2, r);
}

- (void) DPSclip
{
  fprintf(gstream, "clip\n");
}

- (void) DPSclosepath
{
  fprintf(gstream, "closepath\n");
}

- (void)DPScurveto: (float)x1 : (float)y1 : (float)x2 : (float)y2 
                  : (float)x3 : (float)y3
{
  fprintf(gstream, "%g %g %g %g %g %g curveto\n", x1, y1, x2, y2, x3, y3);
}

- (void) DPSeoclip
{
  fprintf(gstream, "eoclip\n");
}

- (void) DPSeofill
{
  fprintf(gstream, "eofill\n");
}

- (void) DPSfill
{
  fprintf(gstream, "fill\n");
}

- (void) DPSflattenpath
{
  fprintf(gstream, "flattenpath\n");
}

- (void) DPSinitclip
{
  fprintf(gstream, "initclip\n");
}

- (void) DPSlineto: (float)x : (float)y
{
  fprintf(gstream, "%g %g lineto\n", x, y);
}

- (void) DPSmoveto: (float)x : (float)y
{
  fprintf(gstream, "%g %g moveto\n", x, y);
}

- (void) DPSnewpath
{
  fprintf(gstream, "newpath\n");
}

- (void) DPSpathbbox: (float*)llx : (float*)lly : (float*)urx : (float*)ury
{
}

- (void) DPSrcurveto: (float)x1 : (float)y1 : (float)x2 : (float)y2 
                    : (float)x3 : (float)y3
{
  fprintf(gstream, "%g %g %g %g %g %g rcurveto\n", x1, y1, x2, y2, x3, y3);
}

- (void) DPSrectclip: (float)x : (float)y : (float)w : (float)h
{
  fprintf(gstream, "%g %g %g %g rectclip\n", x, y, w, h);
}

- (void) DPSrectfill: (float)x : (float)y : (float)w : (float)h
{
  fprintf(gstream, "%g %g %g %g rectfill\n", x, y, w, h);
}

- (void) DPSrectstroke: (float)x : (float)y : (float)w : (float)h
{
  fprintf(gstream, "%g %g %g %g rectstroke\n", x, y, w, h);
}

- (void) DPSreversepath
{
  fprintf(gstream, "reversepath\n");
}

- (void) DPSrlineto: (float)x : (float)y
{
  fprintf(gstream, "%g %g rlineto\n", x, y);
}

- (void) DPSrmoveto: (float)x : (float)y
{
  fprintf(gstream, "%g %g rmoveto\n", x, y);
}

- (void) DPSstroke
{
  fprintf(gstream, "stroke\n");
}

- (void) GSSendBezierPath: (NSBezierPath *)path
{
  NSBezierPathElement type;
  NSPoint pts[3];
  int i, count;
  float pattern[10];
  float phase;

  [self DPSnewpath];
  [self DPSsetlinewidth: [path lineWidth]];
  [self DPSsetlinejoin: [path lineJoinStyle]];
  [self DPSsetlinecap: [path lineCapStyle]];
  [self DPSsetmiterlimit: [path miterLimit]];
  [self DPSsetflat: [path flatness]];

  [path getLineDash: pattern count: &count phase: &phase];
  // Always sent the dash pattern. When NULL this will reset to a solid line.
  [self DPSsetdash: pattern : count : phase];

  count = [path elementCount];
  for(i = 0; i < count; i++) 
    {
      type = [path elementAtIndex: i associatedPoints: pts];
      switch(type) 
        {
	case NSMoveToBezierPathElement:
	  [self DPSmoveto: pts[0].x : pts[0].y];
	  break;
	case NSLineToBezierPathElement:
	  [self DPSlineto: pts[0].x : pts[0].y];
	  break;
	case NSCurveToBezierPathElement:
	  [self DPScurveto: pts[0].x : pts[0].y
	   : pts[1].x : pts[1].y : pts[2].x : pts[2].y];
	  break;
	case NSClosePathBezierPathElement:
	  [self DPSclosepath];
	  break;
	default:
	  break;
	}
    }
}

- (void) GSRectClipList: (const NSRect *)rects: (int)count
{
  [self notImplemented: _cmd];
}

- (void) GSRectFillList: (const NSRect *)rects: (int)count
{
  [self notImplemented: _cmd];
}

/* ----------------------------------------------------------------------- */
/* Window system ops */
/* ----------------------------------------------------------------------- */
- (void) DPScurrentgcdrawable: (void**)gc : (void**)draw : (int*)x : (int*)y
{
  NSLog(@"DPSinvalidcontext: getting gcdrawable from stream context");
}

- (void) DPScurrentoffset: (int*)x : (int*)y
{
  NSLog(@"DPSinvalidcontext: getting drawable offset from stream context");
}

- (void) DPSsetgcdrawable: (void*)gc : (void*)draw : (int)x : (int)y
{
  NSLog(@"DPSinvalidcontext: setting gcdrawable from stream context");
}

- (void) DPSsetoffset: (short int)x : (short int)y
{
  NSLog(@"DPSinvalidcontext: setting drawable offset from stream context");
}


/*-------------------------------------------------------------------------*/
/* Graphics Extensions Ops */
/*-------------------------------------------------------------------------*/
- (void) DPScomposite: (float)x : (float)y : (float)w : (float)h 
                     : (int)gstateNum : (float)dx : (float)dy : (int)op
{
  fprintf(gstream, "%g %g %g %g %d %g %g %d composite\n", x, y, w, h, 
	  gstateNum, dx, dy, op);
}

- (void) DPScompositerect: (float)x : (float)y : (float)w : (float)h : (int)op
{
  fprintf(gstream, "%g %g %g %g %d compositerect\n", x, y, w, h, op);
}

- (void) DPSdissolve: (float)x : (float)y : (float)w : (float)h 
                    : (int)gstateNum : (float)dx : (float)dy : (float)delta
{
  fprintf(gstream, "%g %g %g %g %d %g %g %g dissolve\n", x, y, w, h, 
	  gstateNum, dx, dy, delta);
}


- (void) GSDrawImage: (NSRect)rect : (void *)imageref
{
  [self notImplemented: _cmd];
}


/* ----------------------------------------------------------------------- */
/* Client functions */
/* ----------------------------------------------------------------------- */
- (void) DPSPrintf: (const char *)fmt  : (va_list)args
{
  vfprintf(gstream, fmt, args);
}

- (void) DPSWriteData: (const char *)buf : (unsigned int)count
{
  /* Not sure here. Should we translate to ASCII if it's not
     already? */
}

@end

static char *hexdigits = "0123456789abcdef";

void
writeHex(FILE *gstream, const unsigned char *data, int count)
{
  int i;
  for (i = 0; i < count; i++)
    {
      fprintf(gstream, "%c%c", hexdigits[(int)(data[0]/16)],
	      hexdigits[(data[0] % 16)]);
      if (i && i % 40 == 0)
	fprintf(gstream, "\n");
    }
}

@implementation GSStreamContext (Graphics)

- (void) NSDrawBitmap: (NSRect)rect : (int)pixelsWide : (int)pixelsHigh
		     : (int)bitsPerSample : (int)samplesPerPixel 
		     : (int)bitsPerPixel : (int)bytesPerRow : (BOOL)isPlanar
		     : (BOOL)hasAlpha : (NSString *)colorSpaceName
		     : (const unsigned char *const [5])data
{
  int bytes, spp;
  float y;
  BOOL flipped = NO;

  /* In a flipped view, we don't want to flip the image again, which would
     make it come out upsidedown. FIXME: This can't be right, can it? */
  if ([[NSView focusView] isFlipped])
    flipped = YES;

  /* Save scaling */
  fprintf(gstream, "matrix\ncurrentmatrix\n");
  y = NSMinY(rect);
  if (flipped)
    y += NSWidth(rect);
  fprintf(gstream, "%f %f translate %f %f scale\n", 
	  NSMinX(rect), y, NSWidth(rect),  NSHeight(rect));

  if (bitsPerSample == 0)
    bitsPerSample = 8;
  bytes = 
    (bitsPerSample * pixelsWide * pixelsHigh + 7) / 8;
  if (bytes * samplesPerPixel != bytesPerRow * pixelsHigh) 
    {
      NSLog(@"Image Rendering Error: Dodgy bytesPerRow value %d", bytesPerRow);
      NSLog(@"   pixelsHigh=%d, bytes=%d, samplesPerPixel=%d",
	    bytesPerRow, pixelsHigh, bytes);
      return;
    }
  if(hasAlpha)
    spp = samplesPerPixel - 1;
  else
    spp = samplesPerPixel;

  if(samplesPerPixel > 1) 
    {
      if(isPlanar || hasAlpha) 
	{
	  if(bitsPerSample != 8) 
	    {
	      NSLog(@"Image format conversion not supported for bps!=8");
	      return;
	    }
	}
      fprintf(gstream, "%d %d %d [%d 0 0 %d 0 %d]\n",
	      pixelsWide, pixelsHigh, bitsPerSample, pixelsWide,
	      (flipped) ? pixelsHigh : -pixelsHigh, pixelsHigh);
      fprintf(gstream, "{currentfile %d string readhexstring pop}\n",
	      pixelsWide*spp);
      fprintf(gstream, "false %d colorimage\n", spp);
    } 
  else
    {
      fprintf(gstream, "%d %d %d [%d 0 0 %d 0 %d]\n",
	      pixelsWide, pixelsHigh, bitsPerSample, pixelsWide,
	      (flipped) ? pixelsHigh : -pixelsHigh, pixelsHigh);
      fprintf(gstream, "currentfile image\n");
    }
  
  // The context is now waiting for data on its standard input
  if(isPlanar || hasAlpha) 
    {
      // We need to do a format conversion.
      // We do this on the fly, sending data to the context as soon as
      // it is computed.
      int i, j, alpha;
      unsigned char val;

      for(j=0; j<bytes; j++) 
	{
	  if(hasAlpha) 
	    {
	      if(isPlanar)
		alpha = data[spp][j];
	      else
		alpha = data[0][spp+j*samplesPerPixel];
	    }
	  for (i = 0; i < spp; i++) 
	    {
	      if(isPlanar)
		val = data[i][j];
	      else
		val = data[0][i+j*samplesPerPixel];
	      if(hasAlpha)
		val = 255 - ((255-val)*(long)alpha)/255;
	      writeHex(gstream, &val, 1);
	    }
	  if (j && j % 40 == 0)
	    fprintf(gstream, "\n");
	}
      fprintf(gstream, "\n");
    } 
  else 
    {
      // The data is already in the format the context expects it in
      writeHex(gstream, data[0], bytes*samplesPerPixel);
    }

  /* Restore original scaling */
  fprintf(gstream, "setmatrix\n");
}

@end

@implementation GSStreamContext (Private)

- (void) output: (const char*)s
{
  const char *t = s;

  while (*t)
    {
      switch (*t)
      {
	case '(':
	    fputs("\\(", gstream);
	    break;
	case ')':
	    fputs("\\)", gstream);
	    break;
	default:
	    fputc(*t, gstream);
	    break;
      }
      t++;
    }
}

@end
