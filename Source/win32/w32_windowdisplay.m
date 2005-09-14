/* WIN32Server - Implements window handling for MSWindows

   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   Part of this code have been re-written by:
   Tom MacSween <macsweent@sympatico.ca>
   Date August 2005
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
   */


#include "w32_Events.h"

static void invalidateWindow(HWND hwnd, RECT rect);

static void 
invalidateWindow(HWND hwnd, RECT rect)
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
	  NSLog(@"validated window %d %@", hwnd, 
		NSStringFromRect(MSWindowRectToGS((HWND)hwnd, rect)));
	  NSLog(@"validateWindow failed %d", GetLastError());
      }
      ReleaseDC((HWND)hwnd, hdc);
    }
  else 
    {
      NSWindow *window = GSWindowWithNumber((int)hwnd);
      NSRect r = MSWindowRectToGS((HWND)hwnd, rect);
      
      /*
	NSLog(@"Invalidated window %d %@ (%d, %d, %d, %d)", hwnd, 
	NSStringFromRect(r), rect.left, rect.top, rect.right, rect.bottom);
      */
      // Repaint the window's client area. 
      [[window contentView] setNeedsDisplayInRect: r];
    }
}


@implementation WIN32Server (w32_windowdisplay)

/*
  WM_SHOWWINDOW Notification

  The WM_SHOWWINDOW message is sent to a window when the window is
  about to be hidden or shown.  A window receives this message through
  its WindowProc function.

  Syntax

  WM_SHOWWINDOW

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
  Specifies whether a window is being shown. If wParam is TRUE, the
  window is being shown. If wParam is FALSE, the window is being
  hidden. lParam Specifies the status of the window being shown. If
  lParam is zero, the message was sent because of a call to the
  ShowWindow function; otherwise, lParam is one of the following
  values.
 
  SW_OTHERUNZOOM
    The window is being uncovered because a maximize window was restored or 
    minimized. 
  SW_OTHERZOOM
    The window is being covered by another window that has been maximized. 
  SW_PARENTCLOSING
    The window's owner window is being minimized.
  SW_PARENTOPENING
    The window's owner window is being restored.

  Return Value

  If an application processes this message, it should return zero.

  Remarks

  The DefWindowProc function hides or shows the window, as specified
  by the message. If a window has the WS_VISIBLE style when it is
  created, the window receives this message after it is created, but
  before it is displayed. A window also receives this message when its
  visibility state is changed by the ShowWindow or ShowOwnedPopups
  function.  The WM_SHOWWINDOW message is not sent under the following
  circumstances:

  When a top-level, overlapped window is created with the WS_MAXIMIZE
  or WS_MINIMIZE style. When the SW_SHOWNORMAL flag is specified in
  the call to the ShowWindow function.

*/
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
	      ShowWindow(hwnd,SW_SHOW);
	      flags._eventHandled=YES;
	    }
	    break;
	  case SW_PARENTCLOSING:
	    {
	      ShowWindow(hwnd,SW_SHOW);
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

#ifdef __SHOWWINDOW__
  printf("[wParam] show window %s\n",wParam ? "TRUE" : "FALSE");
  printf("[lParam] requested SW_FLAG %d\n",wParam);
  //printf("is Main Menu %d\n",_is_menu);
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  fflush(stdout);
#endif    
}

/*

  WM_NCPAINT
  The WM_NCPAINT message is sent to a window when its frame must be
  painted.  A window receives this message through its WindowProc
  function.

  LRESULT CALLBACK WindowProc(
  HWND hwnd, // handle to window
  UINT uMsg, // WM_NCPAINT
  WPARAM wParam, // handle to update region (HRGN)
  LPARAM lParam // not used
  );

  Parameters

  wParam
  Handle to the update region of the window. The update region is
  clipped to the window frame. When wParam is 1, the entire window
  frame needs to be updated.
  lParam
  This parameter is not used.

  Return Values
  An application returns zero if it processes this message.

  Remarks
  The DefWindowProc function paints the window frame.

  An application can intercept the WM_NCPAINT message and paint its
  own custom window frame. The clipping region for a window is always
  rectangular, even if the shape of the frame is altered.  The wParam
  value can be passed to GetDCEx as in the following example.

  case WM_NCPAINT:
  {
  HDC hdc;
  hdc = GetDCEx(hwnd, (HRGN)wParam, DCX_WINDOW|DCX_INTERSECTRGN);
  // Paint into this DC
  ReleaseDC(hwnd, hdc);
  } 
*/

- (void) decodeWM_NCPAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
#ifdef __TESTEVENT__
  printf("WM_NCPAINT\n");
#endif
}


/*

  WM_ERASEBKGND Notification

  The WM_ERASEBKGND message is sent when the window background must be
  erased (for example, when a window is resized). The message is sent
  to prepare an invalidated portion of a window for painting.

  Syntax

  WM_ERASEBKGND

  WPARAM wParam 
  LPARAM lParam;

  Parameters

  wParam
  Handle to the device context.
  lParam
  This parameter is not used.

  Return Value

  An application should return nonzero if it erases the background;
  otherwise, it should return zero.

  Remarks

  The DefWindowProc function erases the background by using the class
  background brush specified by the hbrBackground member of the
  WNDCLASS structure. If hbrBackground is NULL, the application should
  process the WM_ERASEBKGND message and erase the background.  An
  application should return nonzero in response to WM_ERASEBKGND if it
  processes the message and erases the background; this indicates that
  no further erasing is required. If the application returns zero, the
  window will remain marked for erasing. (Typically, this indicates
  that the fErase member of the PAINTSTRUCT structure will be TRUE.)

*/

- (LRESULT) decodeWM_ERASEBKGNDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // GS handles this for now...
#ifdef __ERASEBKGND__
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  fflush(stdout);
#endif
  return (LRESULT)1;
}

/*

  WM_PAINT
  The WM_PAINT message is sent when the system or another application
  makes a request to paint a portion of an application's window. The
  message is sent when the UpdateWindow or RedrawWindow function is
  called, or by the DispatchMessage function when the application
  obtains a WM_PAINT message by using the GetMessage or PeekMessage
  function.  A window receives this message through its WindowProc
  function.

  LRESULT CALLBACK WindowProc(
  HWND hwnd, // handle to window
  UINT uMsg, // WM_PAINT
  WPARAM wParam, // not used
  LPARAM lParam // not used
  );
  Parameters
  wParam
    This parameter is not used.
  lParam
    This parameter is not used.

  Return Values
    An application returns zero if it processes this message.

  Remarks

  The WM_PAINT message is generated by the system and should not be
  sent by an application. To force a window to draw into a specific
  device context, use the WM_PRINT or WM_PRINTCLIENT message. Note
  that this requires the target window to support the WM_PRINTCLIENT
  message. Most common controls support the WM_PRINTCLIENT message.
  The DefWindowProc function validates the update region. The function
  may also send the WM_NCPAINT message to the window procedure if the
  window frame must be painted and send the WM_ERASEBKGND message if
  the window background must be erased.  The system sends this message
  when there are no other messages in the application's message queue.
  DispatchMessage determines where to send the message; GetMessage
  determines which message to dispatch.  GetMessage returns the
  WM_PAINT message when there are no other messages in the
  application's message queue, and DispatchMessage sends the message
  to the appropriate window procedure.  A window may receive internal
  paint messages as a result of calling RedrawWindow with the
  RDW_INTERNALPAINT flag set. In this case, the window may not have an
  update region. An application should call the GetUpdateRect function
  to determine whether the window has an update region. If
  GetUpdateRect returns zero, the application should not call the
  BeginPaint and EndPaint functions.  An application must check for
  any necessary internal painting by looking at its internal data
  structures for each WM_PAINT message, because a WM_PAINT message may
  have been caused by both a non-NULL update region and a call to
  RedrawWindow with the RDW_INTERNALPAINT flag set.  The system sends
  an internal WM_PAINT message only once. After an internal WM_PAINT
  message is returned from GetMessage or PeekMessage or is sent to a
  window by UpdateWindow, the system does not post or send further
  WM_PAINT messages until the window is invalidated or until
  RedrawWindow is called again with the RDW_INTERNALPAINT flag set.
  For some common controls, the default WM_PAINT message processing
  checks the wParam parameter. If wParam is non-NULL, the control
  assumes that the value is an HDC and paints using that device
  context.

*/
- (void) decodeWM_PAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // reused from original author (added debug code)
  RECT rect;

  if (GetUpdateRect(hwnd, &rect, NO))
    {
      invalidateWindow(hwnd, rect);
      // validate the whole window, for in some cases an infinite series
      // of WM_PAINT is triggered
      ValidateRect(hwnd, NULL);
    }
	  
  flags._eventHandled=YES;

#ifdef __PAINT__
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  printf("%s",[[self MSRectDetails:rect] cString]);
  fflush(stdout);
#endif
}


/*
  WM_SYNCPAINT
  The WM_SYNCPAINT message is used to synchronize painting while
  avoiding linking independent GUI threads.  A window receives this
  message through its WindowProc function.

  LRESULT CALLBACK WindowProc(
  HWND hwnd, // handle to window
  UINT uMsg, // WM_SYNCPAINT
  WPARAM wParam, // not used
  LPARAM lParam // not used
  );
  Parameters
    This message has no parameters.

  Return Values
    An application returns zero if it processes this message.

  Remarks

  When a window has been hidden, shown, moved, or sized, the system
  may determine that it is necessary to send a WM_SYNCPAINT message to
  the top-level windows of other threads. Applications must pass
  WM_SYNCPAINT to DefWindowProc for processing. The DefWindowProc
  function will send a WM_NCPAINT message to the window procedure if
  the window frame must be painted and send a WM_ERASEBKGND message if
  the window background must be erased.

*/

- (void) decodeWM_SYNCPAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
#ifdef __TESTEVENT__
  printf("WM_SYNCPAINT\n");
#endif
}

/*

  WM_CAPTURECHANGED Notification

  The WM_CAPTURECHANGED message is sent to the window that is losing
  the mouse capture.  A window receives this message through its
  WindowProc function.

  Syntax

  WM_CAPTURECHANGED

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
    This parameter is not used.
  lParam
    Handle to the window gaining the mouse capture.

  Return Value

  An application should return zero if it processes this message.

  Remarks

  A window receives this message even if it calls ReleaseCapture
  itself. An application should not attempt to set the mouse capture
  in response to this message.  When it receives this message, a
  window should redraw itself, if necessary, to reflect the new
  mouse-capture state.  
*/
- (void) decodeWM_CAPTURECHANGEDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
#ifdef  __TESTEVENT__
  printf("WM_CAPTURECHANGED\n");
#endif
}


/*

  WM_GETICON Notification

  The WM_GETICON message is sent to a window to retrieve a handle to
  the large or small icon associated with a window. The system
  displays the large icon in the ALT+TAB dialog, and the small icon in
  the window caption.  A window receives this message through its
  WindowProc function.

  Syntax

  WM_GETICON

  WPARAM wParam
  LPARAM lParam;

  Parameters
  wParam
    Specifies the type of icon being retrieved. This parameter can be
    one of the following values.
  ICON_BIG
    Retrieve the large icon for the window.
  ICON_SMALL
    Retrieve the small icon for the window.
  ICON_SMALL2
    Windows XP: Retrieves the small icon provided by the
    application. If the application does not provide one, the system
    uses the system-generated icon for that window.
  lParam
    This parameter is not used.

  Return Value
    The return value is a handle to the large or small icon, depending
    on the value of wParam. When an application receives this message,
    it can return a handle to a large or small icon, or pass the
    message to the DefWindowProc function.

  Remarks

  When an application receives this message, it can return a handle to
  a large or small icon, or pass the message to DefWindowProc.
  DefWindowProc returns a handle to the large or small icon associated
  with the window, depending on the value of wParam.

*/
- (void) decodeWM_GETICONParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
#ifdef __TESTEVENT__
  printf("WM_GETICON\n");
#endif
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
    
#ifdef __BACKING__
  NSDebugLLog(@"NSEvent", @"Change backing store to %d %d", r.right - r.left, r.bottom - r.top);
  printf("RESIZING BACKING Store\n");
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  printf("New Rect: %s",[[self MSRectDetails:r] cString]);
  fflush(stdout);
#endif
}

@end
