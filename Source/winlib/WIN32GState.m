/* WIN32GState - Implements graphic state drawing for MSWindows

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by: <author name="Fred Kiefer><email>FredKiefer@gmx.de</email></author>
   Date: March 2002
   
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

#include <AppKit/NSAffineTransform.h>
#include <AppKit/NSBezierPath.h>
#include <AppKit/NSColor.h>
#include <AppKit/NSFont.h>
#include <AppKit/NSGraphics.h>

#include "winlib/WIN32GState.h"
#include "winlib/WIN32Context.h"
#include "winlib/WIN32FontInfo.h"
#include "win32/WIN32Server.h"

#include <math.h>

static inline
int WindowHeight(HWND window)
{
  RECT rect;

  if (!window)
    {
      NSLog(@"No window for coordinate transformation.");
      return 0;
    }

  if (!GetClientRect(window, &rect))
    {
      NSLog(@"No window rectangle for coordinate transformation.");
      return 0;
    }

  return rect.bottom - rect.top;
}

static inline
POINT GSWindowPointToMS(WIN32GState *s, NSPoint p)
{
  POINT p1;
  int h;

  h = WindowHeight([s window]);

  p.x += s->offset.x;
  p.y += s->offset.y;
  p1.x = p.x;
  p1.y = h -p.y;

  return p1;
}

static inline
RECT GSWindowRectToMS(WIN32GState *s, NSRect r)
{
  RECT r1;
  int h;

  h = WindowHeight([s window]);

  r.origin.x += s->offset.x;
  r.origin.y += s->offset.y;

  r1.left = r.origin.x;
  r1.right = r.origin.x + r.size.width;
  r1.bottom = h - r.origin.y;
  r1.top = h - r.origin.y - r.size.height;

  return r1;
}

static inline
POINT GSViewPointToWin(WIN32GState *s, NSPoint p)
{
  p = [s->ctm pointInMatrixSpace: p];
  return GSWindowPointToMS(s, p);
}

static inline
RECT GSViewRectToWin(WIN32GState *s, NSRect r)
{
  r = [s->ctm rectInMatrixSpace: r];
  return GSWindowRectToMS(s, r);
}

@interface WIN32GState (WinOps)
- (void) setStyle: (HDC)hDC;
- (void) restoreStyle: (HDC)hDC;
- (HDC) getHDC;
- (void) releaseHDC: (HDC)hDC;
@end

@implementation WIN32GState 

- (id) deepen
{
  [super deepen];

  if (clipRegion)
    {
      HRGN newClipRegion;

      newClipRegion = CreateRectRgn(0, 0, 1, 1);
      CombineRgn(newClipRegion, clipRegion, NULL, RGN_COPY);
      clipRegion = newClipRegion;
    }

  oldBrush = NULL;
  oldPen = NULL;
  oldClipRegion = NULL;

  return self;
}

- (void) dealloc
{
  DeleteObject(clipRegion);
  [super dealloc];
}

- (void) setWindow: (HWND)number
{
  window = number;
}

- (HWND) window
{
  return window;
}

- (void) setColor: (device_color_t *)acolor state: (color_state_t)cState
{
  device_color_t color;
  [super setColor: acolor state: cState];
  color = *acolor;
  gsColorToRGB(&color);
  if (cState & COLOR_FILL)
    wfcolor = RGB(color.field[0]*255, color.field[1]*255, color.field[2]*255);
  if (cState & COLOR_STROKE)
    wscolor = RGB(color.field[0]*255, color.field[1]*255, color.field[2]*255);
}

- (void) copyBits: (WIN32GState*)source 
	 fromRect: (NSRect)aRect 
	  toPoint: (NSPoint)aPoint
{
  HDC otherDC;
  HDC hDC;
  POINT p;
  RECT rect;
  int h;
  int y1;

  p = GSViewPointToWin(self, aPoint);
  rect = GSViewRectToWin(source, aRect);
  h = rect.bottom - rect.top;

  if (viewIsFlipped)
    y1 = p.y;
  else
    y1 = p.y - h;

  otherDC = [source getHDC];
  if (!otherDC)
    {
      return;
    } 
  hDC = [self getHDC];
  if (!hDC)
    {
      [source releaseHDC: otherDC]; 
      return;
    } 
    
  if (!BitBlt(hDC, p.x, y1, (rect.right - rect.left), h, 
	      otherDC, rect.left, rect.top, SRCCOPY))
    {
      NSLog(@"Copy bitmap failed %d", GetLastError());
      NSLog(@"Orig Copy Bits to %f, %f from %@", aPoint.x, aPoint.y, 
	    NSStringFromRect(aRect)); 
      NSLog(@"Copy Bits to %d %d from %d %d size %d %d", p.x , y1, 
	    rect.left, rect.top, (rect.right - rect.left), h);
    }
  [self releaseHDC: hDC];
  [source releaseHDC: otherDC]; 
}

- (void) compositeGState: (GSGState *)source 
                fromRect: (NSRect)aRect
                 toPoint: (NSPoint)aPoint
                      op: (NSCompositingOperation)op
{
  // FIXME
  [self copyBits: (WIN32GState *)source fromRect: aRect toPoint: aPoint];
}

- (void) dissolveGState: (GSGState *)source
	       fromRect: (NSRect)aRect
		toPoint: (NSPoint)aPoint 
		  delta: (float)delta
{
  // FIXME
  [self copyBits: (WIN32GState *)source fromRect: aRect toPoint: aPoint];
}

- (void) compositerect: (NSRect)aRect
                    op: (NSCompositingOperation)op
{
  float gray;

  [self DPScurrentgray: &gray];
  if (fabs(gray - 0.667) < 0.005)
    [self DPSsetgray: 0.333];
  else    
    [self DPSsetrgbcolor: 0.121 : 0.121 : 0];

  switch (op)
    {
    case   NSCompositeClear:
      break;
    case   NSCompositeHighlight:
      {
	HDC hDC;
	RECT rect = GSViewRectToWin(self, aRect);

	hDC = [self getHDC];
	if (!hDC)
	  {
	    return;
	  } 

	InvertRect(hDC, &rect);
	[self releaseHDC: hDC];
	break;
      }
    case   NSCompositeCopy:
    // FIXME
    case   NSCompositeSourceOver:
    case   NSCompositeSourceIn:
    case   NSCompositeSourceOut:
    case   NSCompositeSourceAtop:
    case   NSCompositeDestinationOver:
    case   NSCompositeDestinationIn:
    case   NSCompositeDestinationOut:
    case   NSCompositeDestinationAtop:
    case   NSCompositeXOR:
    case   NSCompositePlusDarker:
    case   NSCompositePlusLighter:
    default:
      [self DPSrectfill: NSMinX(aRect) : NSMinY(aRect) 
	    : NSWidth(aRect) : NSHeight(aRect)];
      break;
    }
}


static
HBITMAP GSCreateBitmap(HDC hDC, int pixelsWide, int pixelsHigh,
		       int bitsPerSample, int samplesPerPixel,
		       int bitsPerPixel, int bytesPerRow,
		       BOOL isPlanar, BOOL hasAlpha,
		       NSString *colorSpaceName,
		       const unsigned char *const data[5])
{
  HBITMAP hbitmap;
  BITMAPINFO *bitmap;
  BITMAPINFOHEADER *bmih;
  int xres, yres;
  UINT fuColorUse;

  if (isPlanar || ![colorSpaceName isEqualToString: NSDeviceRGBColorSpace])
    {
      NSLog(@"Bitmap type currently not supported %d %@", isPlanar, colorSpaceName);
      return NULL;
    }

  // default is 8 bit grayscale 
  if (!bitsPerSample)
    bitsPerSample = 8;
  if (!samplesPerPixel)
    samplesPerPixel = 1;

  // FIXME - does this work if we are passed a planar image but no hints ?
  if (!bitsPerPixel)
    bitsPerPixel = bitsPerSample * samplesPerPixel;
  if (!bytesPerRow)
    bytesPerRow = (bitsPerPixel * pixelsWide) / 8;

  // make sure its sane - also handles row padding if hint missing
  while((bytesPerRow * 8) < (bitsPerPixel * pixelsWide))
    bytesPerRow++;

  if (!(GetDeviceCaps(hDC, RASTERCAPS) &  RC_DI_BITMAP)) 
    {
      return NULL;
    }

  hbitmap = CreateCompatibleBitmap(hDC, pixelsWide, pixelsHigh);
  if (!hbitmap)
    {
      return NULL;
    }

  if (bitsPerPixel > 8)
    {
      bitmap = objc_malloc(sizeof(BITMAPV4HEADER));
    }
  else 
    {
      bitmap = objc_malloc(sizeof(BITMAPINFOHEADER) +  
			   (1 << bitsPerPixel) * sizeof(RGBQUAD));
    }
  bmih = (BITMAPINFOHEADER*)bitmap;

  bmih->biSize = sizeof(BITMAPINFOHEADER);
  bmih->biWidth = pixelsWide;
  bmih->biHeight = -pixelsHigh;
  bmih->biPlanes = 1;
  bmih->biBitCount = bitsPerPixel;
  bmih->biCompression = BI_RGB;
  bmih->biSizeImage = 0;
  xres = GetDeviceCaps(hDC, HORZRES) / GetDeviceCaps(hDC, HORZSIZE);
  yres = GetDeviceCaps(hDC, VERTRES) / GetDeviceCaps(hDC, VERTSIZE);
  bmih->biXPelsPerMeter = xres;
  bmih->biYPelsPerMeter = yres;
  bmih->biClrUsed = 0;
  bmih->biClrImportant = 0;
  fuColorUse = 0;

  if (bitsPerPixel <= 8)
    {
      // FIXME How to get a colour palette?
      NSLog(@"Need to define colour map for images with %d bits", bitsPerPixel);
      //bitmap->bmiColors;
      fuColorUse = DIB_RGB_COLORS;
    }
  else if (bitsPerPixel == 32)
    {
      BITMAPV4HEADER *bmih;

      bmih = (BITMAPV4HEADER*)bitmap;
      bmih->bV4Size = sizeof(BITMAPV4HEADER);
      bmih->bV4V4Compression = BI_BITFIELDS;
      bmih->bV4RedMask = 0x000000FF;
      bmih->bV4GreenMask = 0x0000FF00;
      bmih->bV4BlueMask = 0x00FF0000;
      bmih->bV4AlphaMask = 0xFF000000;
    }
  else if (bitsPerPixel == 16)
    {
/*
      BITMAPV4HEADER *bmih;

      bmih = (BITMAPV4HEADER*)bitmap;
      bmih->bV4Size = sizeof(BITMAPV4HEADER);
      bmih->bV4V4Compression = BI_BITFIELDS;
      bmih->bV4RedMask = 0xF000;
      bmih->bV4GreenMask = 0x0F00;
      bmih->bV4BlueMask = 0x00F0;
      bmih->bV4AlphaMask = 0x000F;
*/
      NSLog(@"Unsure how to handle images with %d bits", bitsPerPixel);
    }

  if (!SetDIBits(hDC, hbitmap, 0, pixelsHigh, data[0], 
		 bitmap, fuColorUse))
    {
      objc_free(bitmap);
      DeleteObject(hbitmap);
      return NULL;
    }

  objc_free(bitmap);
  return hbitmap;
}

- (void)DPSimage: (NSAffineTransform*) matrix 
		: (int) pixelsWide : (int) pixelsHigh
		: (int) bitsPerSample : (int) samplesPerPixel 
		: (int) bitsPerPixel : (int) bytesPerRow : (BOOL) isPlanar
		: (BOOL) hasAlpha : (NSString *) colorSpaceName
		: (const unsigned char *const [5]) data
{
  NSAffineTransform *old_ctm = nil;
  HDC hDC;
  HBITMAP hbitmap;
  HGDIOBJ old;
  HDC hDC2;
  POINT p;
  int h;
  int y1;

  if (window == NULL)
    {
      NSLog(@"No window in DPSImage");
      return;
    }

  hDC = GetDC((HWND)window);
  if (!hDC)
    {
      NSLog(@"No DC for window %d in DPSImage. Error %d", 
	    (int)window, GetLastError());
    }

  hbitmap = GSCreateBitmap(hDC, pixelsWide, pixelsHigh,
			   bitsPerSample, samplesPerPixel,
			   bitsPerPixel, bytesPerRow,
			   isPlanar, hasAlpha,
			   colorSpaceName, data);
  if (!hbitmap)
    {
      NSLog(@"Created bitmap failed %d", GetLastError());
    }

  hDC2 = CreateCompatibleDC(hDC); 
  if (!hDC2)
    {
      NSLog(@"No Compatible DC for window %d in DPSImage. Error %d", 
	    (int)window, GetLastError());
    }
  old = SelectObject(hDC2, hbitmap);
  if (!old)
    {
      NSLog(@"SelectObject failed for window %d in DPSImage. Error %d", 
	    (int)window, GetLastError());
    }

  //SetMapMode(hDC2, GetMapMode(hDC));
  ReleaseDC((HWND)window, hDC);

  hDC = [self getHDC];

  h = pixelsHigh;
  // Apply the additional transformation
  if (matrix)
    {
      old_ctm = [ctm copy];
      [ctm appendTransform: matrix];
    }
  p = GSViewPointToWin(self, NSMakePoint(0, 0));
  if (old_ctm != nil)
    {
      RELEASE(ctm);
      // old_ctm is already retained
      ctm = old_ctm;
    }
  if (viewIsFlipped)
    y1 = p.y;
  else
    y1 = p.y - h;

  if (!BitBlt(hDC, p.x, y1, pixelsWide, pixelsHigh,
	      hDC2, 0, 0, SRCCOPY))
    {
      NSLog(@"Copy bitmap failed %d", GetLastError());
      NSLog(@"DPSimage with %d %d %d %d to %d, %d", pixelsWide, pixelsHigh, 
	    bytesPerRow, bitsPerPixel, p.x, y1);
    }
  
  [self releaseHDC: hDC];

  SelectObject(hDC2, old);
  DeleteDC(hDC2);
  DeleteObject(hbitmap);
}

@end

@implementation WIN32GState (PathOps)

- (void) _paintPath: (ctxt_object_t) drawType
{
  unsigned count;
  HDC hDC;

  hDC = [self getHDC];
  if (!hDC)
    {
      return;
    } 

  count = [path elementCount];
  if (count)
    {
      NSBezierPathElement type;
      NSPoint   points[3];
      unsigned	j, i = 0;
      POINT p;

      BeginPath(hDC);

      for(j = 0; j < count; j++) 
        {
	  type = [path elementAtIndex: j associatedPoints: points];
	  switch(type) 
	    {
	    case NSMoveToBezierPathElement:
	      p = GSWindowPointToMS(self, points[0]);
	      MoveToEx(hDC, p.x, p.y, NULL);
	      break;
	    case NSLineToBezierPathElement:
	      p = GSWindowPointToMS(self, points[0]);
	      // FIXME This gives one pixel to few
	      LineTo(hDC, p.x, p.y);
	      break;
	    case NSCurveToBezierPathElement:
	      {
		POINT bp[3];
		
		for (i = 1; i < 3; i++)
		  {
		    bp[i] = GSWindowPointToMS(self, points[i]);
		  }
		PolyBezierTo(hDC, bp, 3);
	      }
	      break;
	    case NSClosePathBezierPathElement:
	      CloseFigure(hDC);
	      break;
	    default:
	      break;
	    }
	}  
      EndPath(hDC);

      // Now operate on the path
      switch (drawType)
	{
	case path_stroke:
	  StrokePath(hDC);
	  break;
	case path_eofill:
	  SetPolyFillMode(hDC, ALTERNATE);
	  FillPath(hDC);
	  break;
	case path_fill:
	  SetPolyFillMode(hDC, WINDING);
	  FillPath(hDC);
	  break;
	case path_eoclip:
	  {
	    HRGN region;

	    SetPolyFillMode(hDC, ALTERNATE);
	    region = PathToRegion(hDC);
	    if (clipRegion)
	    {
	      CombineRgn(clipRegion, clipRegion, region, RGN_AND);
	      DeleteObject(region);
	    }
	    else
	      {
		clipRegion = region;
	      }
	    break;
	  }
	case path_clip:
	  {
	    HRGN region;

	    SetPolyFillMode(hDC, WINDING);
	    region = PathToRegion(hDC);
	    if (clipRegion)
	    {
	      CombineRgn(clipRegion, clipRegion, region, RGN_AND);
	      DeleteObject(region);
	    }
	    else
	      {
		clipRegion = region;
	      }
	    break;
	  }
	default:
	  break;
	}
    }
  [self releaseHDC: hDC];

  /*
   * clip does not delete the current path, so we only clear the path if the
   * operation was not a clipping operation.
   */
  if ((drawType != path_clip) && (drawType != path_eoclip))
    {
      [path removeAllPoints];
    }
}

- (void)DPSclip 
{
  [self _paintPath: path_clip];
}

- (void)DPSeoclip 
{
  [self _paintPath: path_eoclip];
}

- (void)DPSeofill 
{
  [self _paintPath: path_eofill];
}

- (void)DPSfill 
{
  [self _paintPath: path_fill];
}

- (void)DPSstroke 
{
  [self _paintPath: path_stroke];
}


- (void) DPSinitclip;
{
  if (clipRegion)
    {
      DeleteObject(clipRegion);
      clipRegion = NULL;
    }
}

- (void)DPSrectfill: (float)x : (float)y : (float)w : (float)h 
{
  HDC hDC;
  HBRUSH brush;
  RECT rect;

  hDC = [self getHDC];
  if (!hDC)
    {
      return;
    } 

  brush = GetCurrentObject(hDC, OBJ_BRUSH);
  rect = GSViewRectToWin(self, NSMakeRect(x, y, w, h));
  FillRect(hDC, &rect, brush);
  [self releaseHDC: hDC];
}

- (void)DPSrectstroke: (float)x : (float)y : (float)w : (float)h 
{
  NSRect rect = [ctm rectInMatrixSpace: NSMakeRect(x, y, w, h)]; 
  NSBezierPath *oldPath = path;

  // Samll adjustment so that the line is visible
  if (rect.size.width > 0)
    rect.size.width--;
  if (rect.size.height > 0)
    rect.size.height--;
  rect.origin.y += 1;

  path = [NSBezierPath bezierPathWithRect: rect];
  [self DPSstroke];
  path = oldPath;
}

- (void)DPSrectclip: (float)x : (float)y : (float)w : (float)h 
{
  RECT rect;
  HRGN region;

  rect = GSViewRectToWin(self, NSMakeRect(x, y, w, h));
  region = CreateRectRgnIndirect(&rect);
  if (clipRegion)
    {
      CombineRgn(clipRegion, clipRegion, region, RGN_AND);
      DeleteObject(region);
    }
  else
    {
      clipRegion = region;
    }
  [self DPSnewpath];
}

- (void)DPSshow: (const char *)s 
{
  NSPoint current = [path currentPoint];
  POINT p;
  HDC hDC;

  hDC = [self getHDC];
  if (!hDC)
    {
      return;
    } 

  p = GSWindowPointToMS(self, current);
  [(WIN32FontInfo*)font draw: s lenght:  strlen(s)
		   onDC: hDC at: p];
  [self releaseHDC: hDC];
}

- (void) GSShowGlyphs: (const NSGlyph *)glyphs : (size_t)length 
{
  NSPoint current = [path currentPoint];
  POINT p;
  HDC hDC;

  hDC = [self getHDC];
  if (!hDC)
    {
      return;
    } 

  p = GSWindowPointToMS(self, current);
  [(WIN32FontInfo*)font drawGlyphs: glyphs
			    length: length
			      onDC: hDC
				at: p];
  [self releaseHDC: hDC];
}
@end

@implementation WIN32GState (GStateOps)

- (void)DPSinitgraphics 
{
  [super DPSinitgraphics];
}

- (void) DPSsetdash: (const float*)pattern : (int)count : (float)phase
{
  if (!path)
    {
      path = [NSBezierPath new];
    }

  [path setLineDash: pattern count: count phase: phase];
}

- (void)DPScurrentmiterlimit: (float *)limit 
{
  *limit = miterlimit;
}

- (void)DPSsetmiterlimit: (float)limit 
{
  miterlimit = limit;
}

- (void)DPScurrentlinecap: (int *)linecap 
{
  *linecap = lineCap;
}

- (void)DPSsetlinecap: (int)linecap 
{
  lineCap = linecap;
}

- (void)DPScurrentlinejoin: (int *)linejoin 
{
  *linejoin = joinStyle;
}

- (void)DPSsetlinejoin: (int)linejoin 
{
  joinStyle = linejoin;
}

- (void)DPScurrentlinewidth: (float *)width 
{
  *width = lineWidth;
}

- (void)DPSsetlinewidth: (float)width 
{
  lineWidth = width;
}

- (void)DPScurrentstrokeadjust: (int *)b 
{
}

- (void)DPSsetstrokeadjust: (int)b 
{
}

@end

@implementation WIN32GState (WinOps)

- (void) setStyle: (HDC)hDC
{
  HPEN pen;
  HBRUSH brush;
  LOGBRUSH br; 
  int join;
  int cap;
  DWORD penStyle;
  SetBkMode(hDC, TRANSPARENT);
  /*
  br.lbStyle = BS_SOLID;
  br.lbColor = color;
  brush = CreateBrushIndirect(&br);
  */
  brush = CreateSolidBrush(wfcolor);
  oldBrush = SelectObject(hDC, brush);

  switch (joinStyle)
    {
    case NSBevelLineJoinStyle:
      join = PS_JOIN_BEVEL;
      break;
    case NSMiterLineJoinStyle:
      join = PS_JOIN_MITER;
      break;
    case NSRoundLineJoinStyle:
      join = PS_JOIN_ROUND;
      break;
    default:
      join = PS_JOIN_MITER;
      break;
    }

  switch (lineCap)
    {
    case NSButtLineCapStyle:
      cap = PS_ENDCAP_FLAT;
      break;
    case NSSquareLineCapStyle:
      cap = PS_ENDCAP_SQUARE;
      break;
    case NSRoundLineCapStyle:
      cap = PS_ENDCAP_ROUND;
      break;
    default:
      cap = PS_ENDCAP_SQUARE;
      break;
    }

  penStyle = PS_GEOMETRIC | PS_SOLID;
  if (path)
    {
      float pattern[10];
      int count = 10;
      float phase;

      [path getLineDash: pattern count: &count phase: &phase];

      if (count && (count < 10))
	{
	  penStyle = PS_GEOMETRIC | PS_DASH;
	}
    }

  pen = ExtCreatePen(penStyle | join | cap, 
		     lineWidth,
		     &br,
		     0, NULL);

  oldPen = SelectObject(hDC, pen);

  SetMiterLimit(hDC, miterlimit, NULL);

  SetTextColor(hDC, wfcolor);

  oldClipRegion = CreateRectRgn(0, 0, 1, 1);
  if (1 != GetClipRgn(hDC, oldClipRegion))
    {
      DeleteObject(oldClipRegion);
      oldClipRegion = NULL;
    }

  SelectClipRgn(hDC, clipRegion);
}

- (void) restoreStyle: (HDC)hDC
{
  HGDIOBJ old;

  SelectClipRgn(hDC, oldClipRegion);
  DeleteObject(oldClipRegion);
  oldClipRegion = NULL;

  old = SelectObject(hDC, oldBrush);
  DeleteObject(old);

  old = SelectObject(hDC, oldPen);
  DeleteObject(old);
}

- (HDC) getHDC
{
  WIN_INTERN *win;
  HDC hDC;

  if (NULL == window)
    {
      //Log(@"No window in getHDC");
      return NULL;
    }

  win = (WIN_INTERN *)GetWindowLong((HWND)window, GWL_USERDATA);
  if (win && win->useHDC)
    {
      hDC = win->hdc;
      //NSLog(@"getHDC found DC %d", hDC);
    }
  else
    {
      hDC = GetDC((HWND)window);    
      //NSLog(@"getHDC using window DC %d", hDC);
    }
  
  if (!hDC)
    {
      //Log(@"No DC in getHDC");
      return NULL;	
    }

  [self setStyle: hDC];
  return hDC;
}

- (void) releaseHDC: (HDC)hDC
{
  WIN_INTERN *win;

  if (NULL == window ||
      NULL == hDC)
    {
      return;
    }

  [self restoreStyle: hDC];
  win = (WIN_INTERN *)GetWindowLong((HWND)window, GWL_USERDATA);
  if (win && !win->useHDC)
    ReleaseDC((HWND)window, hDC);
}

@end
