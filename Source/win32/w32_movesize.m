/* WIN32Server - Implements window handling for MSWindows

   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by: Tom MacSween <macsweent@sympatico.ca>
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

@implementation WIN32Server (w32_movesize)

/*
 * The WM_MOVE message is sent after a window has been moved. 
 * A window receives this message through its WindowProc function. 
 * 
 * Syntax
 * 
 * WM_MOVE
 * 
 *     WPARAM wParam
 *     LPARAM lParam;
 *     
 * Parameters
 * 
 * wParam
 *     This parameter is not used. 
 * lParam
 *     Specifies the x and y coordinates of the upper-left corner of the 
 *     client area of the window. The low-order word contains the x-coordinate 
 *    while the high-order word contains the y coordinate.
 *  
 * Return Value
 * 
 * If an application processes this message, it should return zero. 
 * 
 * Remarks
 * 
 * The parameters are given in screen coordinates for overlapped and pop-up 
 * windows and in parent-client coordinates for child windows. 
 * 
 * The following example demonstrates how to obtain the position from 
 * the lParam parameter.
 * 
 *     xPos = (int)(short) LOWORD(lParam);   // horizontal position 
 *     yPos = (int)(short) HIWORD(lParam);   // vertical position 
 * 
 * You can also use the MAKEPOINTS macro to convert the lParam parameter 
 * to a POINTS structure. 
 * 
 */
 
- (LRESULT) decodeWM_MOVEParams:(HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{

  NSPoint eventLocation;
  NSRect rect;
  RECT r;
  NSEvent *ev = nil;
  GetWindowRect(hwnd, &r);
    
  rect = MSScreenRectToGS(r, [EVENT_WINDOW(hwnd) styleMask], self);
    
  eventLocation = rect.origin;
        
  ev = [NSEvent otherEventWithType: NSAppKitDefined
			          location: eventLocation
			     modifierFlags: 0
			         timestamp: 0
			      windowNumber: (int)hwnd
			           context: GSCurrentContext()
			           subtype: GSAppKitWindowMoved
			             data1: rect.origin.x
                   data2: rect.origin.y];                   
         

  if(hwnd==(HWND)flags.menuRef)
    {
      //need native code here?
      if(flags.HOLD_MENU_FOR_MOVE==FALSE)
	{
	  [EVENT_WINDOW(hwnd) sendEvent:ev];
	}
      
    }
  else
    {
      if(flags.HOLD_TRANSIENT_FOR_MOVE==FALSE)
	[EVENT_WINDOW(hwnd) sendEvent:ev];
    }   
		  
#ifdef __WM_MOVE__
  printf("sending GS_EVENT %d  GS_SUBTYPE %d\n",[ev type],[ev subtype]);
  printf("HOLD_MENU_FOR_MOVE is %s\n",flags.HOLD_MENU_FOR_MOVE ? "TRUE" : "FALSE");
  printf("HOLD_MENU_FOR_SIZE is %s\n",flags.HOLD_MENU_FOR_SIZE ? "TRUE" : "FALSE");
  
  printf("%s\n",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  printf("EVENTLOCATION %s",[[self NSRectDetails:rect] cString]);
  printf("[hwnd rect] is %s",[[self NSRectDetails:[EVENT_WINDOW(hwnd) frame]] cString]);
  fflush(stdout);
#endif
  
  ev=nil;
  flags.HOLD_MENU_FOR_MOVE=FALSE;
  flags.HOLD_MINI_FOR_MOVE=FALSE;
  flags.HOLD_TRANSIENT_FOR_MOVE=FALSE;
  
  return 0;
}

/*
 * WM_SIZE Notification
 * The WM_SIZE message is sent to a window after its size has changed.
 * 
 * A window receives this message through its WindowProc function. 
 * 
 * Syntax
 * 
 * WM_SIZE
 * 
 *     WPARAM wParam
 *     LPARAM lParam;
 *     
 * Parameters
 *
 * wParam
 *   Specifies the type of resizing requested. This parameter can be one 
 *   of the following values. 
 * SIZE_MAXHIDE 4
 *        Message is sent to all pop-up windows when some other 
 *        window is maximized.
 * SIZE_MAXIMIZED 2
 *        The window has been maximized.
 * SIZE_MAXSHOW 3
 *        Message is sent to all pop-up windows when some other window has been 
 *        restored to its former size.
 * SIZE_MINIMIZED 1
 *        The window has been minimized.
 * SIZE_RESTORED 0
 *        The window has been resized, but neither the SIZE_MINIMIZED nor  
 *        SIZE_MAXIMIZED value applies.
 * lParam
 * The low-order word of lParam specifies the new width of the client area. 
 * The high-order word of lParam specifies the new height of the client area. 
 * 
 * Return Value
 * 
 * If an application processes this message, it should return zero. 
 * 
 * Remarks
 * 
 * If the SetScrollPos or MoveWindow function is called for a child window as a 
 * result of the WM_SIZE message, the bRedraw or bRepaint parameter should be 
 * nonzero to cause the window to be repainted. 
 * 
 * Although the width and height of a window are 32-bit values, 
 * the lParam parameter contains only the low-order 16 bits of each. 
 * 
*/
- (LRESULT) decodeWM_SIZEParams:(HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{ 
  NSPoint eventLocation;
  NSRect rect;
  RECT r;
  NSEvent *ev =nil;
  
  GetWindowRect(hwnd, &r);
  
  rect = MSScreenRectToGS(r, [EVENT_WINDOW(hwnd) styleMask], self);
  
  eventLocation = rect.origin;
  switch ((int)wParam)
    {
    case SIZE_MAXHIDE:
      {
	// stubbed for future development
#ifdef __WM_SIZE__
        printf("got SIZE_MAXHIDE message\n");
#endif
      }
      break;
    case SIZE_MAXIMIZED:
      {
	// stubbed for future development
#ifdef __WM_SIZE__
	printf("got SIZE_MAXIMIZED message\n");
#endif
      }
      break;
    case SIZE_MAXSHOW:
      {
	// stubbed for future development
#ifdef __WM_SIZE__
	printf("got SIZE_MAXSHOW message\n");
#endif
      }
      break;
    case SIZE_MINIMIZED:
      {
      
	if  (flags.HOLD_MINI_FOR_SIZE==TRUE) //// this is fix for [5,25 bug]
	  break;
          
	// make event
	ev = [NSEvent otherEventWithType: NSAppKitDefined
				location: eventLocation
			   modifierFlags: 0
			       timestamp: 0
			    windowNumber: (int)hwnd
				 context: GSCurrentContext()
				 subtype: GSAppKitWindowResized
				   data1: rect.size.width
				   data2: rect.size.height];
               
	if(hwnd==(HWND)flags.menuRef)
	  {
	    if(flags.HOLD_MENU_FOR_SIZE==FALSE)
	      {
		[EVENT_WINDOW(hwnd) sendEvent:ev];
		[self resizeBackingStoreFor:hwnd];
	      }
	  }
	else 
	  {   
	    if (flags.HOLD_TRANSIENT_FOR_SIZE==FALSE)
	      {
		[EVENT_WINDOW(hwnd) sendEvent:ev];
		[self resizeBackingStoreFor:hwnd];
		[EVENT_WINDOW(hwnd) miniaturize:self]; 
	      } 
	  }  
      }
      break;
    case SIZE_RESTORED:
      {
            
	// make event
	ev = [NSEvent otherEventWithType: NSAppKitDefined
				location: eventLocation
			   modifierFlags: 0
			       timestamp: 0
			    windowNumber: (int)hwnd
				 context: GSCurrentContext()
				 subtype: GSAppKitWindowResized
				   data1: rect.size.width
				   data2: rect.size.height];
               
	if(hwnd==(HWND)flags.menuRef)
	  {
	    if(flags.HOLD_MENU_FOR_SIZE==FALSE)
	      {
		[EVENT_WINDOW(hwnd) sendEvent:ev];
		[self resizeBackingStoreFor:hwnd];
	      }
	  }
	else
	  { 
	    if (flags.HOLD_TRANSIENT_FOR_SIZE==FALSE)
	      {
		[EVENT_WINDOW(hwnd) sendEvent:ev];
		[self resizeBackingStoreFor:hwnd];
		// fixes part one of bug [5,25] see notes
		[EVENT_WINDOW(hwnd) deminiaturize:self];
	      } 
	  } 
      }
      break;
      
    default:
      break;
    }
                      
#ifdef __WM_SIZE__
  printf("sending GS_EVENT %d  GS_SUBTYPE %d\n",[ev type],[ev subtype]);
  printf("[wParam] SIZE_FLAG is %d\n",(int)wParam);
  printf("HOLD_MENU_FOR_MOVE is %s\n",flags.HOLD_MENU_FOR_MOVE ? "TRUE" : "FALSE");
  printf("HOLD_MENU_FOR_SIZE is %s\n",flags.HOLD_MENU_FOR_SIZE ? "TRUE" : "FALSE");
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  printf("size to:%s",[[self NSRectDetails:rect] cString]);
  printf("[hwnd rect] is %s",[[self NSRectDetails:[EVENT_WINDOW(hwnd) frame]] cString]);
  fflush(stdout);
#endif 		  		  

  ev=nil;
  flags.HOLD_MENU_FOR_SIZE=FALSE;
  flags.HOLD_MINI_FOR_SIZE=FALSE;
  flags.HOLD_TRANSIENT_FOR_SIZE=FALSE;

  return 0;
}

/*
  WM_NCCALCSIZE Notification

  The WM_NCCALCSIZE message is sent when the size and position of a
  window's client area must be calculated. By processing this message,
  an application can control the content of the window's client area
  when the size or position of the window changes.

  A window receives this message through its WindowProc function. 

  Syntax

  WM_NCCALCSIZE

    WPARAM wParam
    LPARAM lParam;

  Parameters

  wParam
  If wParam is TRUE, it specifies that the application should indicate
  which part of the client area contains valid information. The system
  copies the valid information to the specified area within the new
  client area.  If wParam is FALSE, the application does not need to
  indicate the valid part of the client area.

  lParam
  If wParam is TRUE, lParam points to an NCCALCSIZE_PARAMS structure
  that contains information an application can use to calculate the
  new size and position of the client rectangle.  If wParam is FALSE,
  lParam points to a RECT structure. On entry, the structure contains
  the proposed window rectangle for the window. On exit, the structure
  should contain the screen coordinates of the corresponding window
  client area.

  Return Value

  If the wParam parameter is FALSE, the application should return zero. 

  If wParam is TRUE, the application should return zero or a
  combination of the following values.

  If wParam is TRUE and an application returns zero, the old client
  area is preserved and is aligned with the upper-left corner of the
  new client area.


  WVR_ALIGNTOP 
    Specifies that the client area of the window is to be preserved
    and aligned with the top of the new position of the window. For
    example, to align the client area to the upper-left corner, return
    the WVR_ALIGNTOP and WVR_ALIGNLEFT values.
    
  WVR_ALIGNLEFT 
    Specifies that the client area of the window is to be preserved
    and aligned with the left side of the new position of the
    window. For example, to align the client area to the lower-left
    corner, return the WVR_ALIGNLEFT and WVR_ALIGNBOTTOM values.
          
  WVR_ALIGNBOTTOM
    Specifies that the client area of the window is to be preserved
    and aligned with the bottom of the new position of the window. For
    example, to align the client area to the top-left corner, return
    the WVR_ALIGNTOP and WVR_ALIGNLEFT values.
  
  WVR_HREDRAW
    Used in combination with any other values, causes the window to be
    completely redrawn if the client rectangle changes size
    horizontally. This value is similar to CS_HREDRAW class style

 
  WVR_VREDRAW 
    Used in combination with any other values, causes the window to be
    completely redrawn if the client rectangle changes size
    vertically. This value is similar to CS_VREDRAW class style
 
  WVR_REDRAW

    This value causes the entire window to be redrawn. It is a
    combination of WVR_HREDRAW and WVR_VREDRAW values.  WVR_VALIDRECTS
    This value indicates that, upon return from WM_NCCALCSIZE, the
    rectangles specified by the rgrc[1] and rgrc[2] members of the
    NCCALCSIZE_PARAMS structure contain valid destination and source
    area rectangles, respectively. The system combines these
    rectangles to calculate the area of the window to be
    preserved. The system copies any part of the window image that is
    within the source rectangle and clips the image to the destination
    rectangle. Both rectangles are in parent-relative or
    screen-relative coordinates.

  This return value allows an application to implement more elaborate
  client-area preservation strategies, such as centering or preserving
  a subset of the client area.
 
  Remarks

    The window may be redrawn, depending on whether the CS_HREDRAW or
    CS_VREDRAW class style is specified. This is the default,
    backward-compatible processing of this message by the
    DefWindowProc function (in addition to the usual client rectangle
    calculation described in the preceding table).

*/

- (void) decodeWM_NCCALCSIZEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd 
{
  // stub for future dev
#ifdef __TESTEVENT__
  printf("WM_NCCALCSIZE\n");
#endif
}

/*

  WM_WINDOWPOSCHANGED Notification

  The WM_WINDOWPOSCHANGED message is sent to a window whose size,
  position, or place in the Z order has changed as a result of a call
  to the SetWindowPos function or another window-management function.
  A window receives this message through its WindowProc function.

  Syntax

  WM_WINDOWPOSCHANGED

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
  This parameter is not used.
  lParam
  Pointer to a WINDOWPOS structure that contains information about the
  window's new size and position. Return Value

  If an application processes this message, it should return zero.

  Remarks

  By default, the DefWindowProc function sends the WM_SIZE and WM_MOVE
  messages to the window. The WM_SIZE and WM_MOVE messages are not
  sent if an application handles the WM_WINDOWPOSCHANGED message
  without calling DefWindowProc. It is more efficient to perform any
  move or size change processing during the WM_WINDOWPOSCHANGED
  message without calling DefWindowProc.

*/

- (void) decodeWM_WINDOWPOSCHANGEDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
#ifdef __TESTEVENT__
  printf("WM_WINDOWPOSCHANGED\n");
#endif
}

/*
  WM_WINDOWPOSCHANGING Notification

  The WM_WINDOWPOSCHANGING message is sent to a window whose size,
  position, or place in the Z order is about to change as a result of
  a call to the SetWindowPos function or another window-management
  function.  A window receives this message through its WindowProc
  function.


  Syntax

  WM_WINDOWPOSCHANGING

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
  This parameter is not used.
  lParam
  Pointer to a WINDOWPOS structure that contains information about the
  window's new size and position. Return Value

  If an application processes this message, it should return zero.

Remarks
  For a window with the WS_OVERLAPPED or WS_THICKFRAME style, the
  DefWindowProc function sends the WM_GETMINMAXINFO message to the
  window. This is done to validate the new size and position of the
  window and to enforce the CS_BYTEALIGNCLIENT and CS_BYTEALIGNWINDOW
  client styles. By not passing the WM_WINDOWPOSCHANGING message to
  the DefWindowProc function, an application can override these
  defaults.  While this message is being processed, modifying any of
  the values in WINDOWPOS affects the window's new size, position, or
  place in the Z order. An application can prevent changes to the
  window by setting or clearing the appropriate bits in the flags
  member of WINDOWPOS.

*/

- (void) decodeWM_WINDOWPOSCHANGINGParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
#ifdef __TESTEVENT__
  printf("WM_WINDOWPOSCHANGING\n");
#endif
}

/*

  WM_GETMINMAXINFO Notification

  The WM_GETMINMAXINFO message is sent to a window when the size or
  position of the window is about to change. An application can use
  this message to override the window's default maximized size and
  position, or its default minimum or maximum tracking size.

  A window receives this message through its WindowProc function.

  Syntax

  WM_GETMINMAXINFO

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
  This parameter is not used.
  lParam
  Pointer to a MINMAXINFO structure that contains the default
  maximized position and dimensions, and the default minimum and
  maximum tracking sizes. An application can override the defaults by
  setting the members of this structure.

  Return Value

  If an application processes this message, it should return zero.

  Remarks

  The maximum tracking size is the largest window size that can be
  produced by using the borders to size the window. The minimum
  tracking size is the smallest window size that can be produced by
  using the borders to size the window.

  The MINMAXINFO structure contains information about a window's
  maximized size and position and its minimum and maximum tracking
  size.

  Syntax

  typedef struct {
  POINT ptReserved;
  POINT ptMaxSize;
  POINT ptMaxPosition;
  POINT ptMinTrackSize;
  POINT ptMaxTrackSize;
  } MINMAXINFO;
  Members

  ptReserved
    Reserved; do not use.

  ptMaxSize
    Specifies the maximized width (POINT. x) and the maximized height
    (POINT. y) of the window. For systems with multiple monitors, this
    refers to the primary monitor.  ptMaxPosition Specifies the
    position of the left side of the maximized window (POINT. x) and
    the position of the top of the maximized window (POINT. y). For
    systems with multiple monitors, this refers to the monitor on
    which the window maximizes.

  ptMinTrackSize
    Specifies the minimum tracking width (POINT. x) and the minimum
    tracking height (POINT. y) of the window. This is unchanged for
    systems with multiple monitors.  ptMaxTrackSize Specifies the
    maximum tracking width (POINT. x) and the maximum tracking height
    (POINT. y) of the window. For systems with multiple monitors, this
    is the size for a window that is made as large as the virtual
    screen.

*/

- (LRESULT) decodeWM_GETMINMAXINFOParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // reused from original author (added debug code)
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong(hwnd, GWL_USERDATA);
  MINMAXINFO *mm;

  if (win != NULL)
    {
      mm = (MINMAXINFO*)lParam;
      mm->ptMinTrackSize = win->minmax.ptMinTrackSize;
      mm->ptMaxTrackSize = win->minmax.ptMaxTrackSize;
      return 0;
    }
	  
#ifdef __GETMINMAXINFO__
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  printf("%s",[[self MINMAXDetails:mm] cString]);
  fflush(stdout);
#endif
  return 0; 
}

/*

  WM_EXITSIZEMOVE Notification

  The WM_EXITSIZEMOVE message is sent one time to a window, after it
  has exited the moving or sizing modal loop. The window enters the
  moving or sizing modal loop when the user clicks the window's title
  bar or sizing border, or when the window passes the WM_SYSCOMMAND
  message to the DefWindowProc function and the wParam parameter of
  the message specifies the SC_MOVE or SC_SIZE value.  The operation
  is complete when DefWindowProc returns.
 
  A window receives this message through its WindowProc function.

  Syntax

  WM_EXITSIZEMOVE

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
  This parameter is not used.
  lParam
  This parameter is not used.

  Return Value

  An application should return zero if it processes this message.
*/

- (LRESULT) decodeWM_EXITSIZEMOVEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // may have a small bug here note it for follow up
  /*
        decodeWM_MOVE and decodeWM_SIZE will send event if they have one.
        no posting is needed.
    */
  [self resizeBackingStoreFor: hwnd];
  [self decodeWM_MOVEParams:hwnd :wParam :lParam];
  [self decodeWM_SIZEParams:hwnd :wParam :lParam];
      
  //Make sure DefWindowProc gets called
	
#ifdef __EXITSIZEMOVE__
  NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "EXITSIZEMOVE", hwnd);
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  fflush(stdout);
#endif
	
  return 0;
}

/*

  WM_SIZING Notification

  The WM_SIZING message is sent to a window that the user is
  resizing. By processing this message, an application can monitor the
  size and position of the drag rectangle and, if needed, change its
  size or position.  A window receives this message through its
  WindowProc function.

  Syntax

  WM_SIZING

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
    Specifies which edge of the window is being sized. This parameter
    can be one of the following values.
  WMSZ_BOTTOM
    Bottom edge
  WMSZ_BOTTOMLEFT
    Bottom-left corner
  WMSZ_BOTTOMRIGHT
    Bottom-right corner
  WMSZ_LEFT
    Left edge
  WMSZ_RIGHT
    Right edge
  WMSZ_TOP
    Top edge
  WMSZ_TOPLEFT
    Top-left corner
  WMSZ_TOPRIGHT
    Top-right corner
  lParam
    Pointer to a RECT structure with the screen coordinates of the
    drag rectangle.  To change the size or position of the drag
    rectangle, an application must change the members of this
    structure.

  Return Value
  An application should return TRUE if it processes this message.

*/

- (LRESULT) decodeWM_SIZINGParams:(HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
  // stub for future dev
#ifdef __SIZING__
  printf("SIZING was called\n");

#endif
  return 0;
}

@end
