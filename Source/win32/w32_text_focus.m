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

@implementation WIN32Server (w32_text_focus)

/*
  WM_SETTEXT Message

  An application sends a WM_SETTEXT message to set the text of a window.

  Syntax

  To send this message, call the SendMessage function as
  follows. lResult = SendMessage( // returns LRESULT in lResult (HWND)
  hWndControl, // handle to destination control (UINT) WM_SETTEXT, //
  message ID (WPARAM) wParam, // = (WPARAM) () wParam; (LPARAM) lParam
  // = (LPARAM) () lParam; ); Parameters

  wParam 
    This parameter is not used. 
  lParam 
    Pointer to a null-terminated string that is the window text. Return
  Value

  The return value is TRUE if the text is set. It is FALSE (for an
  edit control), LB_ERRSPACE (for a list box), or CB_ERRSPACE (for a
  combo box) if insufficient space is available to set the text in the
  edit control. It is CB_ERR if this message is sent to a combo box
  without an edit control.

  Remarks

  The DefWindowProc function sets and displays the window text. For an
  edit control, the text is the contents of the edit control. For a
  combo box, the text is the contents of the edit-control portion of
  the combo box. For a button, the text is the button name. For other
  windows, the text is the window title.

  This message does not change the current selection in the list box
  of a combo box. An application should use the CB_SELECTSTRING
  message to select the item in a list box that matches the text in
  the edit control.

*/

//- (LRESULT) decodeWM_SETTEXTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
//{
//printf("WM_SETTEXT\n");
//printf("Window text is: %s\n",(LPSTR)lParam);

//BOOL result=SetWindowText(hwnd,(LPSTR)lParam);    
    
  //      if (result==0)
            //printf("error on setWindow text %ld\n",GetLastError());
        
//return 0;
//}

/*

  WM_SETFOCUS Notification

  The WM_SETFOCUS message is sent to a window after it has gained the
  keyboard focus.

  Syntax

  WM_SETFOCUS

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam  
    Handle to the window that has lost the keyboard focus. This
    parameter can be NULL.
  lParam
    This parameter is not used.

  Return Value

  An application should return zero if it processes this message.

  Remarks

  To display a caret, an application should call the appropriate caret
  functions when it receives the WM_SETFOCUS message.

*/

- (LRESULT) decodeWM_SETFOCUSParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // reused from original author (added debug output)
  /* This message comes when the window already got focus, so we send a focus
     in event to the front end, but also mark the window as having current focus
     so that the front end doesn't try to focus the window again. */
   
  int key_num, win_num;
  NSPoint eventLocation;

  key_num = [[NSApp keyWindow] windowNumber];
  win_num = (int)hwnd;
  
  currentFocus = hwnd;
  eventLocation = NSMakePoint(0,0);
  if (currentFocus == desiredFocus)
    {
      /* This was from a request from the front end. Mark as done. */
      desiredFocus = 0;
    }
  else
    {
      /* We need to do this directly and not send an event to the frontend - 
	 that's too slow and allows the window state to get out of sync,
	 causing bad recursion problems */
      NSWindow *window = GSWindowWithNumber((int)hwnd);
      if ([window canBecomeKeyWindow] == YES)
	{
	  NSDebugLLog(@"Focus", @"Making %d key", win_num);
	  [window makeKeyWindow];
	  [window makeMainWindow];
	  [NSApp activateIgnoringOtherApps: YES];
	}
    }
    
#ifdef  __SETFOCUS__
  NSDebugLLog(@"Focus", @"Got focus:%d (current = %d, key = %d)", 
	      win_num, currentFocus, key_num);
  NSDebugLLog(@"Focus", @"  result of focus request");
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  fflush(stdout);
#endif   
  return 0;
}


/*

  WM_KILLFOCUS Notification

  The WM_KILLFOCUS message is sent to a window immediately before it
  loses the keyboard focus.

  Syntax

  WM_KILLFOCUS

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
    Handle to the window that receives the keyboard focus. This
    parameter can be NULL.
  lParam
    This parameter is not used.

  Return Value
  An application should return zero if it processes this message.

  Remarks

  If an application is displaying a caret, the caret should be
  destroyed at this point.  While processing this message, do not make
  any function calls that display or activate a window. This causes
  the thread to yield control and can cause the application to stop
  responding to messages. For more information, see Message Deadlocks.

*/

- (void) decodeWM_KILLFOCUSParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // reused from original author (added debug output)
  NSPoint eventLocation = NSMakePoint(0,0);
  NSEvent * ev=nil;

  ev = [NSEvent otherEventWithType:NSAppKitDefined
			  location: eventLocation
		     modifierFlags: 0
			 timestamp: 0
		      windowNumber: (int)hwnd
			   context: GSCurrentContext()
			   subtype: GSAppKitWindowFocusOut
			     data1: 0
			     data2: 0];
		      
  [EVENT_WINDOW(hwnd) sendEvent:ev];
  flags._eventHandled=YES;
		     
#ifdef __KILLFOCUS__
  NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "KILLFOCUS", hwnd);
  NSDebugLLog(@"Focus", @"Got KILLFOCUS (focus out) for %d", hwnd);
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  fflush(stdout);
#endif
}

/*

  WM_GETTEXT Message

  An application sends a WM_GETTEXT message to copy the text that
  corresponds to a window into a buffer provided by the caller.
  Syntax


  To send this message, call the SendMessage function as follows.
  lResult = SendMessage( // returns LRESULT in lResult (HWND)
  hWndControl, // handle to destination control (UINT) WM_GETTEXT, //
  message ID (WPARAM) wParam, // = (WPARAM) () wParam; (LPARAM) lParam
  // = (LPARAM) () lParam; ); Parameters

  wParam
  Specifies the maximum number of TCHARs to be copied, including the
  terminating null character. Windows NT/2000/XP:ANSI applications may
  have the string in the buffer reduced in size (to a minimum of half
  that of the wParam value) due to conversion from ANSI to Unicode.

  lParam
  Pointer to the buffer that is to receive the text.
  Return Value

  The return value is the number of TCHARs copied, not including the
  terminating null character.

  Remarks

  The DefWindowProc function copies the text associated with the
  window into the specified buffer and returns the number of
  characters copied. Note, for non- text static controls this gives
  you the text with which the control was originally created, that is,
  the ID number. However, it gives you the ID of the non-text static
  control as originally created. That is, if you subsequently used a
  STM_SETIMAGE to change it the original ID would still be returned.
  For an edit control, the text to be copied is the content of the
  edit control.  For a combo box, the text is the content of the edit
  control (or static-text) portion of the combo box. For a button, the
  text is the button name. For other windows, the text is the window
  title. To copy the text of an item in a list box, an application can
  use the LB_GETTEXT message.  When the WM_GETTEXT message is sent to
  a static control with the SS_ICON style, a handle to the icon will
  be returned in the first four bytes of the buffer pointed to by
  lParam. This is true only if the WM_SETTEXT message has been used to
  set the icon.  Rich Edit: If the text to be copied exceeds 64K, use
  either the EM_STREAMOUT or EM_GETSELTEXT message.  Windows 2000/XP:
  Sending a WM_GETTEXT message to a non-text static control, such as a
  static bitmap or static icon control, does not return a string
  value.  Instead, it returns zero. In addition, in previous versions
  of Microsoft® Windows® and Microsoft Windows NT®, applications could
  send a WM_GETTEXT message to a non-text static control to retrieve
  the control's ID. To retrieve a control's ID in Windows 2000/XP,
  applications can use GetWindowLong passing GWL_ID as the index value
  or GetWindowLongPtr using GWLP_ID.

*/
- (void) decodeWM_GETTEXTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
#ifdef __TESTEVENT__
  printf("WM_GETTEXT\n");
#endif
}

@end
