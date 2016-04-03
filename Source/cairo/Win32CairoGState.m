/*
   Win32CairoGState.m

   Copyright (C) 2003 Free Software Foundation, Inc.

   August 8, 2012
 
   This file is part of GNUstep.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#include "cairo/Win32CairoGState.h"
#include "cairo/CairoSurface.h"
#include <cairo-win32.h>

@interface CairoGState (Private)
- (void) _setPath;
@end

@implementation Win32CairoGState 

static inline
POINT GSWindowPointToMS(GSGState *s, NSPoint p)
{
  POINT p1;
  
  p1.x = p.x - s->offset.x;
  p1.y = s->offset.y - p.y;
  
  return p1;
}

+ (void) initialize
{
  if (self == [Win32CairoGState class])
    {
    }
}

- (HDC) getHDC
{
  if (_surface)
    {
      cairo_surface_flush([_surface surface]);
      HDC hdc = cairo_win32_surface_get_dc([_surface surface]);
      NSDebugLLog(@"CairoGState",
                  @"%s:_surface: %p hdc: %p\n", __PRETTY_FUNCTION__,
                  _surface, hdc);
      
      // The WinUXTheme (and maybe others in the future?) draw directly into the HDC...
      // Controls are always given the _bounds to draw into regardless of the actual invalid
      // rectangle requested.  NSView only locks the focus for the invalid rectangle given,
      // which in the failure case, is a partial rectangle for the control.
      
      // This drawing outside of cairo seems to bypass the clipping area, causing controls
      // drawn using MSDN theme button backgrounds OUTSIDE of the actual invalid rectangle
      // when they happen to intersect THRU a control rather than including the entire control.
      // This is an unfortunate side effect of using unions i.e. NSUnionRect for the invalid rectangle,
      // which causes this problem.
      
      // As a side note, it turns out that Apple Cocoa keeps individual rectangles and invokes the
      // drawRect for each rectangle in turn.
      
      // Save the HDC...
      SaveDC(hdc);
      
      // and setup the clipping path region if we have one...
      [self _clipRegionForHDC: hdc];
      
      // Return the HDC...
      return hdc;
    }
  NSLog(@"%s:_surface is NULL\n", __PRETTY_FUNCTION__);
  return NULL;
}

- (void) releaseHDC: (HDC)hdc
{
  if (hdc && _surface)
    {
      if (hdc != cairo_win32_surface_get_dc([_surface surface]))
      {
        NSLog(@"%s:expHDC: %p recHDC: %p", __PRETTY_FUNCTION__, cairo_win32_surface_get_dc([_surface surface]), hdc);
      }
      else
      {
        // Restore the HDC...
        RestoreDC(hdc, -1);
        
        // and inform cairo that we modified it...
        cairo_surface_mark_dirty([_surface surface]);
      }
    }
}

- (void) _clipRegionForHDC: (HDC)hDC
{
  if (!hDC)
  {
    return;
  }
  
  if (_lastPath == nil)
  {
    return;
  }
  
  unsigned count = [_lastPath elementCount];
  if (count)
  {
    NSBezierPathElement type;
    NSPoint   points[3];
    unsigned	j, i = 0;
    POINT p;
    
    BeginPath(hDC);
    
    for (j = 0; j < count; j++)
    {
      type = [_lastPath elementAtIndex: j associatedPoints: points];
      switch(type)
      {
        case NSMoveToBezierPathElement:
          p = GSWindowPointToMS(self, points[0]);
          MoveToEx(hDC, p.x, p.y, NULL);
          break;
        case NSLineToBezierPathElement:
          p = GSWindowPointToMS(self, points[0]);
          // FIXME This gives one pixel too few
          LineTo(hDC, p.x, p.y);
          break;
        case NSCurveToBezierPathElement:
        {
          POINT bp[3];
          
          for (i = 0; i < 3; i++)
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
    
    // Select the clip path...
    SelectClipPath(hDC, RGN_AND);
  }
  
  // Clear the used clip path...
  DESTROY(_lastPath);
}

- (void) DPSinitclip
{
  // Destroy any clipping path we're holding...
  DESTROY(_lastPath);
  
  // and invoke super...
  [super DPSinitclip];
}

- (void) DPSclip
{
  // Invoke super...
  [super DPSclip];
  
  // Keep a copy for ourselves for theme drawing directly to HDC...
  if (_lastPath == nil)
  {
    _lastPath = [path copy];
  }
  else
  {
    [_lastPath appendBezierPath: path];
  }
}

@end
