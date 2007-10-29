/* WIN32Server - Implements window handling for MSWindows

   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   Part of this code have been re-written by:
   Tom MacSween <macsweent@sympatico.ca>
   Date August 2005

   This file is part of the GNU Objective C User Interface Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

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


#include "w32_Events.h"

static void invalidateWindow(WIN32Server *svr, HWND hwnd, RECT rect);

static void 
invalidateWindow(WIN32Server *svr, HWND hwnd, RECT rect)
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)hwnd, GWL_USERDATA);

  if (win->useHDC)
    {
      HDC hdc = GetDC((HWND)hwnd);
      WINBOOL result;

      result = BitBlt(hdc, rect.left, rect.top, 
		      (rect.right - rect.left), (rect.bottom - rect.top), 
		      win->hdc, rect.left, rect.top, SRCCOPY);
      if (!result)
        {
	  NSLog(@"validateWindow failed %d", GetLastError());
      }
      ReleaseDC((HWND)hwnd, hdc);
    }
  else 
    {
      NSWindow *window = GSWindowWithNumber((int)hwnd);
      NSRect r = MSWindowRectToGS(svr, (HWND)hwnd, rect);
      
      /*
	NSLog(@"Invalidated window %d %@ (%d, %d, %d, %d)", hwnd, 
	NSStringFromRect(r), rect.left, rect.top, rect.right, rect.bottom);
      */
      // Repaint the window's client area. 
      [[[window contentView] superview] setNeedsDisplayInRect: r];
    }
}

@implementation WIN32Server (w32_windowdisplay)

/* styles are mapped between the two systems 
 * I have not changed current inplimentation of mouse or keyboard
 * events. */
- (DWORD) windowStyleForGSStyle: (unsigned int) style
{

/*
    NSUtilityWindowMask         16
    NSDocModalWindowMask        32
    NSBorderlessWindowMask      0
    NSTitledWindowMask          1
    NSClosableWindowMask        2
    NSMiniaturizableWindowMask  4
    NSResizableWindowMask       8
    NSIconWindowMask            64
    NSMiniWindowMask            128

  NSMenu(style) =  NSTitledWindowMask | NSClosableWindowMask =3;
*/

   DWORD wstyle = 0;
        
   if ([self handlesWindowDecorations] == NO)
      return WS_POPUP;
        
   switch (style)
   {
      case 0:
         wstyle=WS_POPUP;
         break;
      case NSTitledWindowMask: // 1
         wstyle = WS_CAPTION;
         break;
      case NSClosableWindowMask: // 2
         wstyle =WS_CAPTION+WS_SYSMENU;
         break;
      case NSMiniaturizableWindowMask: //4
         wstyle =WS_MINIMIZEBOX+WS_SYSMENU;
         break;
      case NSResizableWindowMask: // 8
         wstyle=WS_SIZEBOX;
      case NSMiniWindowMask: //128
      case NSIconWindowMask: // 64
         wstyle = WS_ICONIC; 
         break;
      //case NSUtilityWindowMask: //16
      //case NSDocModalWindowMask: //32
         break;
      // combinations
      case NSTitledWindowMask+NSClosableWindowMask: //3
         wstyle =WS_CAPTION+WS_SYSMENU;
         break;
      case NSTitledWindowMask+NSClosableWindowMask+NSMiniaturizableWindowMask: //7
         wstyle =WS_CAPTION+WS_MINIMIZEBOX+WS_SYSMENU;
         break;
      case NSTitledWindowMask+NSResizableWindowMask: // 9
         wstyle = WS_CAPTION+WS_SIZEBOX;
         break;
      case NSTitledWindowMask+NSClosableWindowMask+NSResizableWindowMask: // 11
         wstyle =WS_CAPTION+WS_SIZEBOX+WS_SYSMENU;
         break;
      case NSTitledWindowMask+NSResizableWindowMask+NSMiniaturizableWindowMask: //13
         wstyle = WS_SIZEBOX+WS_MINIMIZEBOX+WS_SYSMENU+WS_CAPTION;
         break;   
      case NSTitledWindowMask+NSClosableWindowMask+NSResizableWindowMask+
                                                NSMiniaturizableWindowMask: //15
         wstyle =WS_CAPTION+WS_SIZEBOX+WS_MINIMIZEBOX+WS_SYSMENU;
         break;
        
      default:
         wstyle =WS_POPUP; //WS_CAPTION+WS_SYSMENU;
         break;
   }

   //NSLog(@"Window wstyle %d for style %d", wstyle, style);
   return wstyle;
}

/*deprecated remove from code */

- (void) decodeWM_SHOWWINDOWParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  //SW_OTHERUNZOOM //window is being uncovered
  //SW_OTHERZOOM  //window is being covered by window that has maximized. 
  //SW_PARENTCLOSING // window's owner window is being minimized.
  //SW_PARENTOPENING //The window's owner window is being restored.
  //zero - 0  //call to the ShowWindow function

  switch ((int)wParam)
    {
    case TRUE:
      {
	switch ((int)lParam) 
            
	  {            
	  case 0:
	    {
	      ShowWindow(hwnd, SW_SHOW);
	      flags._eventHandled=YES;
	    }
	    break;
	  case SW_PARENTCLOSING:
	    {
	      ShowWindow(hwnd, SW_SHOW);
	      flags._eventHandled=YES;
	    }
	    break;
                
	  default:
	    break;
	  }
        
      }
      break;
        
    case FALSE:
      {
      }
      break;
        
    default:
      break;
    }
}

- (void) decodeWM_NCPAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
}

- (LRESULT) decodeWM_ERASEBKGNDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // GS handles this for now...
  return (LRESULT)1;
}

- (void) decodeWM_PAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // reused from original author (added debug code)
  RECT rect;
   //LPPAINTSTRUCT lpPaint;
   //HDC theHdc;

   /*BOOL InvalidateRect(
   HWND hWnd,           // handle to window
   CONST RECT* lpRect,  // rectangle coordinates
   BOOL bErase          // erase state
);*/

   //theHdc=BeginPaint(hwnd, lpPaint);
   //if (flags.HOLD_PAINT_FOR_SIZING==FALSE)
   // {
  if (GetUpdateRect(hwnd, &rect, NO))
    {
      //InvalidateRect(hwnd, rect, YES);
	   
      invalidateWindow(self, hwnd, rect);
      // validate the whole window, for in some cases an infinite series
      // of WM_PAINT is triggered
      ValidateRect(hwnd, NULL);
    }
   // } 
  flags._eventHandled=YES;
   //flags.HOLD_PAINT_FOR_SIZING=FALSE;

   //printf("WM_PAINT\n");
}

- (void) decodeWM_SYNCPAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
}


- (void) decodeWM_CAPTURECHANGEDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
}

- (HICON) decodeWM_GETICONParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
   return currentAppIcon;
}

- (HICON) decodeWM_SETICONParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
    return currentAppIcon;
}

- (void) resizeBackingStoreFor: (HWND)hwnd
{
  // reused from original author (added debug code)
  RECT r;
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)hwnd, GWL_USERDATA);
  
  // FIXME: We should check if the size really did change.
  if (win->useHDC)
    {
      HDC hdc, hdc2;
      HBITMAP hbitmap;
      HGDIOBJ old;
      
      old = SelectObject(win->hdc, win->old);
      DeleteObject(old);
      DeleteDC(win->hdc);
      win->hdc = NULL;
      win->old = NULL;
      
      GetClientRect((HWND)hwnd, &r);
      hdc = GetDC((HWND)hwnd);
      hdc2 = CreateCompatibleDC(hdc);
      hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, r.bottom - r.top);
      win->old = SelectObject(hdc2, hbitmap);
      win->hdc = hdc2;
      
      ReleaseDC((HWND)hwnd, hdc);
    }
}

@end
