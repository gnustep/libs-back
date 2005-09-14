/* WIN32Server - Implements window handling for MSWindows

   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   Part of this code have been written by:
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

@implementation WIN32Server (w32_General)
/*

  WM_CLOSE Notification

  The WM_CLOSE message is sent as a signal that a window or an
  application should terminate.

  A window receives this message through its WindowProc function.

  Syntax

  WM_CLOSE

  WPARAM wParam 
  LPARAM lParam; 

  Parameters

  wParam 
    This parameter is not used. 
  lParam 
    This parameter is not used. 

  Return Value
    If an application processes this message, it should return zero.

  Remarks

  An application can prompt the user for confirmation, prior to
  destroying a window, by processing the WM_CLOSE message and calling
  the DestroyWindow function only if the user confirms the choice.

  By default, the DefWindowProc function calls the DestroyWindow
  function to destroy the window.

*/
- (void) decodeWM_CLOSEParams:(WPARAM)wParam :(LPARAM)lParam :(HWND)hwnd;
{
  NSEvent * ev;
  NSPoint eventLocation = NSMakePoint(0,0);
  ev = [NSEvent otherEventWithType: NSAppKitDefined
		      location: eventLocation
		      modifierFlags: 0
		      timestamp: 0
		      windowNumber: (int)hwnd
		      context: GSCurrentContext()
		      subtype: GSAppKitWindowClose
		      data1: 0
		      data2: 0];
		    
  // need to send the event... or handle it directly.
  [EVENT_WINDOW(hwnd) sendEvent:ev];
  
  ev=nil;
  flags._eventHandled=YES;
       
#ifdef __CLOSE__
  NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "CLOSE", hwnd);
  printf("CLOSING\n");
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  printf("sending event %s \n",[[ev eventNameWithSubtype:YES] cString]);
  fflush(stdout);
#endif      	    
}
      
/*

  WM_NCDESTROY Notification

  The WM_NCDESTROY message informs a window that its nonclient area is
  being destroyed. The DestroyWindow function sends the WM_NCDESTROY
  message to the window following the WM_DESTROY message. WM_DESTROY
  is used to free the allocated memory object associated with the
  window.
  The WM_NCDESTROY message is sent after the child windows have been
  destroyed.  In contrast, WM_DESTROY is sent before the child windows
  are destroyed.  A window receives this message through its
  WindowProc function.

  Syntax

  WM_NCDESTROY

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
    This parameter is not used.
  lParam
    This parameter is not used.

  Return Value

  If an application processes this message, it should return zero.

  Remarks

  This message frees any memory internally allocated for the window.
*/
- (void) decodeWM_NCDESTROYParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
#ifdef __TESTEVENT__
printf("WM_NCDESTROY\n");
#endif
}

/*

WM_DESTROY Notification

  The WM_DESTROY message is sent when a window is being destroyed. It
  is sent to the window procedure of the window being destroyed after
  the window is removed from the screen.  This message is sent first
  to the window being destroyed and then to the child windows (if any)
  as they are destroyed. During the processing of the message, it can
  be assumed that all child windows still exist.  A window receives
  this message through its WindowProc function.

  Syntax

  WM_DESTROY

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
    This parameter is not used.
  lParam
    This parameter is not used.

  Return Value
    If an application processes this message, it should return zero.

  Remarks

  If the window being destroyed is part of the clipboard viewer chain
  (set by calling the SetClipboardViewer function), the window must
  remove itself from the chain by processing the ChangeClipboardChain
  function before returning from the WM_DESTROY message.
*/
- (void) decodeWM_DESTROYParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong(hwnd, GWL_USERDATA);

  // Clean up window-specific data objects. 
	
  if (win->useHDC)
    {
      HGDIOBJ old;
	    
      old = SelectObject(win->hdc, win->old);
      DeleteObject(old);
      DeleteDC(win->hdc);
    }
  objc_free(win);
  flags._eventHandled=YES;

#ifdef __DESTROY__
  printf("%s",[[self WindowDetail:EVENT_WINDOW(hwnd)] cString]);
  fflush(stdout);
#endif

}

/*

  WM_QUERYOPEN Notification

  The WM_QUERYOPEN message is sent to an icon when the user requests
  that the window be restored to its previous size and position.  A
  window receives this message through its WindowProc function.

  Syntax

  WM_QUERYOPEN

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
    This parameter is not used.
  lParam
    This parameter is not used.

  Return Value

  If the icon can be opened, an application that processes this
  message should return TRUE; otherwise, it should return FALSE to
  prevent the icon from being opened.

  Remarks

  By default, the DefWindowProc function returns TRUE.

  While processing this message, the application should not perform
  any action that would cause an activation or focus change (for
  example, creating a dialog box).

*/

- (void) decodeWM_QUERYOPENParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
#ifdef __TESTEVENT__
  printf("WM_QUERYOPEN\n");
#endif
}

/*

  WM_SYSCOMMAND Notification

  A window receives this message when the user chooses a command from
  the Window menu (formerly known as the system or control menu) or
  when the user chooses the maximize button, minimize button, restore
  button, or close button.  
  
  Syntax

  WM_SYSCOMMAND

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
    Specifies the type of system command requested. This parameter can
  be one of the following values. SC_CLOSE Closes the window.

  SC_CONTEXTHELP
    Changes the cursor to a question mark with a pointer. If the user
  then clicks a control in the dialog box, the control receives a
  WM_HELP message. SC_DEFAULT Selects the default item; the user
  double-clicked the window menu.

  SC_HOTKEY
    Activates the window associated with the application-specified hot
  key. The lParam parameter identifies the window to
  activate. SC_HSCROLL Scrolls horizontally.

  SC_KEYMENU
    Retrieves the window menu as a result of a keystroke. For more
  information, see the Remarks section. SC_MAXIMIZE Maximizes the
  window.

  SC_MINIMIZE
    Minimizes the window.

  SC_MONITORPOWER
    Sets the state of the display. This command supports devices that
  have power- saving features, such as a battery-powered personal
  computer. The lParam parameter can have the following values:

  1 - the display is going to low power

  2 - the display is being shut off

  SC_MOUSEMENU
    Retrieves the window menu as a result of a mouse click.
  SC_MOVE
    Moves the window.
  SC_NEXTWINDOW
    Moves to the next window.
  SC_PREVWINDOW
    Moves to the previous window.
  SC_RESTORE
    Restores the window to its normal position and size.
  SC_SCREENSAVE
    Executes the screen saver application specified in the [boot]
  section of the System.ini file. SC_SIZE Sizes the window.
  SC_TASKLIST
    Activates the Start menu.
  SC_VSCROLL
    Scrolls vertically.
  lParam
    The low-order word specifies the horizontal position of the cursor,
  in screen coordinates, if a window menu command is chosen with the
  mouse. Otherwise, this parameter is not used. The high-order word
  specifies the vertical position of the cursor, in screen
  coordinates, if a window menu command is chosen with the mouse. This
  parameter is –1 if the command is chosen using a system accelerator,
  or zero if using a mnemonic.

  Return Value

  An application should return zero if it processes this message.

  Remarks

  To obtain the position coordinates in screen coordinates, use the following 
  code:
  xPos = GET_X_LPARAM(lParam); // horizontal position
  yPos = GET_Y_LPARAM(lParam); // vertical position


  The DefWindowProc function carries out the window menu request for
  the predefined actions specified in the previous table.  In
  WM_SYSCOMMAND messages, the four low-order bits of the wParam
  parameter are used internally by the system. To obtain the correct
  result when testing the value of wParam, an application must combine
  the value 0xFFF0 with the wParam value by using the bitwise AND
  operator.  The menu items in a window menu can be modified by using
  the GetSystemMenu, AppendMenu, InsertMenu, ModifyMenu,
  InsertMenuItem, and SetMenuItemInfo functions. Applications that
  modify the window menu must process WM_SYSCOMMAND messages.  An
  application can carry out any system command at any time by passing
  a WM_SYSCOMMAND message to DefWindowProc. Any WM_SYSCOMMAND messages
  not handled by the application must be passed to DefWindowProc. Any
  command values added by an application must be processed by the
  application and cannot be passed to DefWindowProc.  Accelerator keys
  that are defined to choose items from the window menu are translated
  into WM_SYSCOMMAND messages; all other accelerator keystrokes are
  translated into WM_COMMAND messages.  If the wParam is SC_KEYMENU,
  lParam contains the character code of the key that is used with the
  ALT key to display the popup menu. For example, pressing ALT+F to
  display the File popup will cause a WM_SYSCOMMAND with wParam equal
  to SC_KEYMENU and lParam equal to 'f'.

*/

- (void) decodeWM_SYSCOMMANDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stubbed for future development
#ifdef __TESTEVENT__
  printf("WM_SYSCOMMAND\n");
#endif
}

// should be moved to the debug catagory
- (void) handleNotification:(NSNotification*)aNotification
{
#ifdef __APPNOTIFICATIONS__
  printf("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
  printf("+++                NEW EVENT                                 +++\n");
  printf("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
  printf("WM_APPNOTIFICATION -1\n %s\nPosted by current application\n",
	 [[aNotification name] cString]);
  NSWindow *theWindow=[aNotification object];
  printf("%s",[[self gswindowstate:theWindow] cString]);
#endif
} 

- (void) resetForGSWindowStyle:(HWND)hwnd gsStryle:(int)aStyle
{
  // to be completed for styles
  LONG result;

  ShowWindow(hwnd,SW_HIDE);
  SetLastError(0);
  result=SetWindowLong(hwnd,GWL_EXSTYLE,(LONG)WS_EX_RIGHT);
  // should check error here...
  ShowWindow(hwnd,SW_SHOWNORMAL);
}
      
@end 
