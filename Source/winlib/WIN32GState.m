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
POINT GSWindowPointToMS(WIN32GState *s, NSPoint p)
{
  POINT p1;
  RECT rect;
  int h;

  GetClientRect((HWND)[s window], &rect);
  h = rect.bottom - rect.top;

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
  RECT rect;
  int h;

  GetClientRect((HWND)[s window], &rect);
  h = rect.bottom - rect.top;
 
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
- (void) setStyle: (HDC)hdc;
- (HDC) getHDC;
- (void) releaseHDC: (HDC)hdc;
@end

@implementation WIN32GState 

- (void) setWindow: (HWND)number
{
  window = (HWND)number;
}

- (HWND) window
{
  return window;
}

- (void) setColor: (device_color_t)color state: (color_state_t)cState
{
  [super setColor: color state: cState];
  color = gsColorToRGB(color);
  if (cState & COLOR_FILL)
    wfcolor = RGB(color.field[0]*255, color.field[1]*255, color.field[2]*255);
  if (cState & COLOR_STOKE)
    wscolor = RGB(color.field[0]*255, color.field[1]*255, color.field[2]*255);
}

- (void) copyBits: (WIN32GState*)source fromRect: (NSRect)aRect 
	  toPoint: (NSPoint)aPoint
{
  HDC otherDC;
  HDC hdc;
  POINT p;
  RECT rect;
  int h;
  int y1;

  //NSLog(@"Orig Copy Bits to %f, %f from %@", aPoint.x, aPoint.y, NSStringFromRect(aRect)); 
  p = GSViewPointToWin(self, aPoint);
  rect = GSViewRectToWin(source, aRect);
  h = rect.bottom - rect.top;

  if (viewIsFlipped)
    y1 = p.y;
  else
    y1 = p.y - h;

  otherDC = [source getHDC];
  hdc = [self getHDC];
    
  if (!BitBlt(hdc, p.x, y1, (rect.right - rect.left), h, 
	      otherDC, rect.left, rect.top, SRCCOPY))
    {
      NSLog(@"Copy Bits to %d %d from %d %d size %d %d", p.x , y1, rect.left, rect.top, 
	    (rect.right - rect.left), h);
      NSLog(@"Copy bitmap failed %d", GetLastError());
    }
  [self releaseHDC: hdc];
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
  HDC hdc;
  float gray;
  RECT rect = GSViewRectToWin(self, aRect);

  [self DPScurrentgray: &gray];
  if (fabs(gray - 0.667) < 0.005)
    [self DPSsetgray: 0.333];
  else    
    [self DPSsetrgbcolor: 0.121 : 0.121 : 0];

  hdc = [self getHDC];
  switch (op)
    {
    case   NSCompositeClear:
      break;
    case   NSCompositeHighlight:
      InvertRect(hdc, &rect);
      break;
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
  [self releaseHDC: hdc];
}

- (void)DPSimage: (NSAffineTransform*) matrix 
		: (int) pixelsWide : (int) pixelsHigh
		: (int) bitsPerSample : (int) samplesPerPixel 
		: (int) bitsPerPixel : (int) bytesPerRow : (BOOL) isPlanar
		: (BOOL) hasAlpha : (NSString *) colorSpaceName
		: (const unsigned char *const [5]) data
{
  NSRect rect;
  NSAffineTransform *old_ctm = nil;
  HDC hdc;

  rect = NSZeroRect;
  rect.size.width = (float) pixelsWide;
  rect.size.height = (float) pixelsHigh;

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

  /* make sure its sane - also handles row padding if hint missing */
  while((bytesPerRow * 8) < (bitsPerPixel * pixelsWide))
    bytesPerRow++;

  // Apply the additional transformation
  if (matrix)
    {
      old_ctm = [ctm copy];
      [ctm appendTransform: matrix];
    }

  if (!isPlanar && [colorSpaceName isEqualToString: NSDeviceRGBColorSpace])
    {
      HBITMAP hbitmap;
      BITMAP bitmap;
      HGDIOBJ old;
      HDC hdc2;
      POINT p;
      int h;
      int y1;

      p = GSViewPointToWin(self, NSMakePoint(0, 0));
      bitmap.bmType = 0;
      bitmap.bmWidth = pixelsWide;
      bitmap.bmHeight = pixelsHigh;
      bitmap.bmWidthBytes = bytesPerRow;
      bitmap.bmPlanes = 1;
      bitmap.bmBitsPixel = bitsPerPixel;
      bitmap.bmBits = (LPVOID)data;

      h = pixelsHigh;
      hbitmap = CreateBitmapIndirect(&bitmap);
      if (!hbitmap)
	NSLog(@"Created bitmap failed %d", GetLastError());

      if (window == NULL)
	NSLog(@"No window in DPSImage");

      hdc = GetDC((HWND)window);
      hdc2 = CreateCompatibleDC(hdc); 
      old = SelectObject(hdc2, hbitmap);
      //SetMapMode(hdc2, GetMapMode(hdc));
      ReleaseDC((HWND)window, hdc);

      hdc = [self getHDC];
      if (viewIsFlipped)
	y1 = p.y;
      else
	y1 = p.y - h;

      if (!BitBlt(hdc, p.x, y1, pixelsWide, pixelsHigh,
		  hdc2, 0, 0, SRCCOPY))
	{
	  NSLog(@"DPSimage with %d %d %d %d to %d, %d", pixelsWide, pixelsHigh, 
		bytesPerRow, bitsPerPixel, p.x, y1);
	  NSLog(@"Copy bitmap failed %d", GetLastError());
	}

      SelectObject(hdc2, old);
      DeleteDC(hdc2);
      DeleteObject(hbitmap);

      [self releaseHDC: hdc];
    }

  if (old_ctm != nil)
    {
      RELEASE(ctm);
      // old_ctm is already retained
      ctm = old_ctm;
    }
}

@end

@implementation WIN32GState (PathOps)

- (void) _paintPath: (ctxt_object_t) drawType
{
  unsigned count;
  HDC hdc;

  hdc = [self getHDC];

  count = [path elementCount];
  if (count)
    {
      NSBezierPathElement type;
      NSPoint   points[3];
      unsigned	j, i = 0;
      POINT p;

      BeginPath(hdc);

      for(j = 0; j < count; j++) 
        {
	  type = [path elementAtIndex: j associatedPoints: points];
	  switch(type) 
	    {
	    case NSMoveToBezierPathElement:
	      p = GSWindowPointToMS(self, points[0]);
	      MoveToEx(hdc, p.x, p.y, NULL);
	      break;
	    case NSLineToBezierPathElement:
	      p = GSWindowPointToMS(self, points[0]);
	      // FIXME This gives one pixel to few
	      LineTo(hdc, p.x, p.y);
	      break;
	    case NSCurveToBezierPathElement:
	      {
		POINT bp[3];
		
		for (i = 1; i < 3; i++)
		  {
		    bp[i] = GSWindowPointToMS(self, points[i]);
		  }
		PolyBezierTo(hdc, bp, 3);
	      }
	      break;
	    case NSClosePathBezierPathElement:
	      CloseFigure(hdc);
	      break;
	    default:
	      break;
	    }
	}  
      EndPath(hdc);

      // Now operate on the path
      switch (drawType)
	{
	case path_stroke:
	  StrokePath(hdc);
	  break;
	case path_eofill:
	  SetPolyFillMode(hdc, ALTERNATE);
	  FillPath(hdc);
	  break;
	case path_fill:
	  SetPolyFillMode(hdc, WINDING);
	  FillPath(hdc);
	  break;
	case path_eoclip:
	  {
	    HRGN region;

	    SetPolyFillMode(hdc, ALTERNATE);
	    region = PathToRegion(hdc);
	    ExtSelectClipRgn(hdc, region, RGN_COPY);
	    DeleteObject(clipRegion);
	    clipRegion = region;
	    break;
	  }
	case path_clip:
	  {
	    HRGN region;

	    SetPolyFillMode(hdc, WINDING);
	    region = PathToRegion(hdc);
	    ExtSelectClipRgn(hdc, region, RGN_COPY);
	    DeleteObject(clipRegion);
	    clipRegion = region;
	    break;
	  }
	default:
	  break;
	}
    }
  [self releaseHDC: hdc];

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
  HDC hdc;

  hdc = [self getHDC];
  SelectClipRgn(hdc, NULL);
  DeleteObject(clipRegion);
  clipRegion = NULL;
  [self releaseHDC: hdc];
}

- (void)DPSrectfill: (float)x : (float)y : (float)w : (float)h 
{
  HDC hdc;
  HBRUSH brush;
  RECT rect;

  rect = GSViewRectToWin(self, NSMakeRect(x, y, w, h));
  hdc = [self getHDC];
  brush = GetCurrentObject(hdc, OBJ_BRUSH);
  FillRect(hdc, &rect, brush);
  [self releaseHDC: hdc];

  /*
  NSPoint origin = [ctm pointInMatrixSpace: NSMakePoint(x, y)];
  NSSize  size = [ctm sizeInMatrixSpace: NSMakeSize(w, h)];

  if (viewIsFlipped)
    origin.y -= size.height;
  ASSIGN(path, [NSBezierPath bezierPathWithRect: 
			       NSMakeRect(origin.x, origin.y, 
					  size.width, size.height)]);
  //NSLog(@"Fill rect %@", NSStringFromRect(NSMakeRect(origin.x, origin.y, 
  //					  size.width, size.height)));
  [self DPSfill];
  */
}

- (void)DPSrectstroke: (float)x : (float)y : (float)w : (float)h 
{
  NSPoint origin = [ctm pointInMatrixSpace: NSMakePoint(x, y)];
  NSSize  size = [ctm sizeInMatrixSpace: NSMakeSize(w, h)];

  if (size.width > 0)
    size.width--;
  if (size.height > 0)
    size.height--;
  if (viewIsFlipped)
    origin.y -= size.height;
  else
    origin.y += 1;

  ASSIGN(path, [NSBezierPath bezierPathWithRect: 
			       NSMakeRect(origin.x, origin.y, 
					  size.width, size.height)]);
  //NSLog(@"Stroke rect %@", NSStringFromRect(NSMakeRect(origin.x, origin.y, 
  //					  size.width, size.height)));
  [self DPSstroke];
}

- (void)DPSrectclip: (float)x : (float)y : (float)w : (float)h 
{
  NSPoint origin = [ctm pointInMatrixSpace: NSMakePoint(x, y)];
  NSSize  size = [ctm sizeInMatrixSpace: NSMakeSize(w, h)];

  size.width++;
  size.height++;
  if (viewIsFlipped)
    origin.y -= size.height;
  ASSIGN(path, [NSBezierPath bezierPathWithRect: 
			       NSMakeRect(origin.x, origin.y, 
					  size.width, size.height)]);
  //NSLog(@"Clip rect %@", NSStringFromRect(NSMakeRect(origin.x, origin.y, 
  //					  size.width, size.height)));
  [self DPSclip];
}

- (void)DPSshow: (const char *)s 
{
  NSPoint current = [path currentPoint];
  POINT p;
  HDC hdc;
  //float ascent = [font ascender];

  p = GSWindowPointToMS(self, current);
  hdc = [self getHDC];
  [(WIN32FontInfo*)[font fontInfo] draw: s lenght:  strlen(s)
		   onDC: hdc at: p];
  //TextOut(hdc, p.x, p.y - ascent, s, strlen(s)); 
  [self releaseHDC: hdc];
}
@end

@implementation WIN32GState (GStateOps)

- (void)DPSinitgraphics 
{
  [ctm makeIdentityMatrix];
  DESTROY(path);
  fillColor = gsMakeColor(gray_colorspace, 0, 0, 0, 0);
  [self setColor: fillColor state: COLOR_BOTH];
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

- (void) setStyle: (HDC)hdc
{
  HPEN pen;
  HBRUSH brush;
  LOGBRUSH br; 
  int join;
  int cap;
  DWORD penStyle;
  SetBkMode(hdc, TRANSPARENT);
  /*
  br.lbStyle = BS_SOLID;
  br.lbColor = color;
  brush = CreateBrushIndirect(&br);
  */
  brush = CreateSolidBrush(wfcolor);
  oldBrush = SelectObject(hdc, brush);

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

  oldPen = SelectObject(hdc, pen);

  SetMiterLimit(hdc, miterlimit, NULL);

  SetTextColor(hdc, wfcolor);
  SelectClipRgn(hdc, clipRegion);
}

- (void) restoreStyle: (HDC)hdc
{
  HGDIOBJ old;

  old = SelectObject(hdc, oldBrush);
  DeleteObject(old);

  old = SelectObject(hdc, oldPen);
  DeleteObject(old);
}

- (HDC) getHDC
{
  WIN_INTERN *win;
  HDC hdc;

  if (NULL == window)
    {
      return NULL;
    }

  win = (WIN_INTERN *)GetWindowLong((HWND)window, GWL_USERDATA);
  if (win && win->useHDC)
    {
      hdc = win->hdc;
    }
  else
    {
      hdc = GetDC((HWND)window);    
    }
  [self setStyle: hdc];
  return hdc;
}

- (void) releaseHDC: (HDC)hdc
{
  WIN_INTERN *win;

  if (NULL == window)
    {
      return;
    }
  [self restoreStyle: hdc];
  win = (WIN_INTERN *)GetWindowLong((HWND)window, GWL_USERDATA);
  if (win && !win->useHDC)
    ReleaseDC((HWND)window, hdc);
}

@end
