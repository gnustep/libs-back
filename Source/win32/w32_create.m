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


@implementation WIN32Server (w32_create)

/*
  WM_NCCREATE Notification

  The WM_NCCREATE message is sent prior to the WM_CREATE message when a window 
  is first created.

  A window receives this message through its WindowProc function. 

  Syntax

  WM_NCCREATE

    WPARAM wParam
    LPARAM lParam;
    
  Parameters

  wParam
    This parameter is not used. 
  lParam
    Pointer to the CREATESTRUCT structure that contains information about the 
    window being created. The members of CREATESTRUCT are identical to the 
    parameters of the CreateWindowEx function. 

  Return Value

  If an application processes this message, it should return TRUE to
  continue creation of the window. If the application returns FALSE,
  the CreateWindow or CreateWindowEx function will return a NULL
  handle.

*/


- (LRESULT) decodeWM_NCCREATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
    // stubbed for future development
  #ifdef __WM_NCCREATE__
        printf("WM_NCCREATE\n");
  #ifdef __W32_debug__
  printf("%s",[[self w32_createDetails:(LPCREATESTRUCT)lParam] cString]);
  #endif
  printf("\nRequested GS Window Style is %u\n",flags.currentGS_Style);
  fflush(stdout);
 #endif

  return TRUE;
}
/*

  WM_CREATE Notification

  The WM_CREATE message is sent when an application requests that a
  window be created by calling the CreateWindowEx or CreateWindow
  function. (The message is sent before the function returns.)  The
  window procedure of the new window receives this message after the
  window is created, but before the window becomes visible.

  Syntax

  WM_CREATE

    WPARAM wParam
    LPARAM lParam;
  Parameters

  wParam
    This parameter is not used.
  lParam
    Pointer to a CREATESTRUCT structure that contains information
    about the window being created.
    
    typedef struct tagCREATESTRUCT {
    LPVOID lpCreateParams;
    HINSTANCE hInstance;
    HMENU hMenu;
    HWND hwndParent;
    int cy;
    int cx;
    int y;
    int x;
    LONG style;
    LPCTSTR lpszName;
    LPCTSTR lpszClass;
    DWORD dwExStyle;
} CREATESTRUCT, *LPCREATESTRUCT;

  Return Value

  If an application processes this message, it should return zero to
  continue creation of the window. If the application returns –1, the
  window is destroyed and the CreateWindowEx or CreateWindow function
  returns a NULL handle.

  dwExStyle [in] Specifies the extended window style of the window
  being created.  This parameter can be one or more of the following
  values.

  WS_EX_ACCEPTFILES
    Specifies that a window created with this style accepts drag-drop files. 

  WS_EX_APPWINDOW
    Forces a top-level window onto the taskbar when the window is visible. 

  WS_EX_CLIENTEDGE
    Specifies that a window has a border with a sunken edge.

  WS_EX_COMPOSITED
    Windows XP: Paints all descendants of a window in bottom-to-top
  painting order using double-buffering. For more information, see
  Remarks. This cannot be used if the window has a class style of
  either CS_OWNDC or CS_CLASSDC.

WS_EX_CONTEXTHELP
  Includes a question mark in the title bar of the window. When the
  user clicks the question mark, the cursor changes to a question mark
  with a pointer. If the user then clicks a child window, the child
  receives a WM_HELP message. The child window should pass the message
  to the parent window procedure, which should call the WinHelp
  function using the HELP_WM_HELP command. The Help application
  displays a pop-up window that typically contains help for the child
  window.  WS_EX_CONTEXTHELP cannot be used with the WS_MAXIMIZEBOX or
  WS_MINIMIZEBOX styles.

WS_EX_CONTROLPARENT
  The window itself contains child windows that should take part in
  dialog box navigation. If this style is specified, the dialog
  manager recurses into children of this window when performing
  navigation operations such as handling the TAB key, an arrow key, or
  a keyboard mnemonic. WS_EX_DLGMODALFRAME Creates a window that has a
  double border; the window can, optionally, be created with a title
  bar by specifying the WS_CAPTION style in the dwStyle
  parameter. WS_EX_LAYERED Windows 2000/XP: Creates a layered
  window. Note that this cannot be used for child windows. Also, this
  cannot be used if the window has a class style of either CS_OWNDC or
  CS_CLASSDC. WS_EX_LAYOUTRTL Arabic and Hebrew versions of Windows
  98/Me, Windows 2000/XP: Creates a window whose horizontal origin is
  on the right edge. Increasing horizontal values advance to the
  left. WS_EX_LEFT Creates a window that has generic left-aligned
  properties. This is the default.

WS_EX_LEFTSCROLLBAR
  If the shell language is Hebrew, Arabic, or another language that
  supports reading order alignment, the vertical scroll bar (if
  present) is to the left of the client area. For other languages, the
  style is ignored. WS_EX_LTRREADING The window text is displayed
  using left-to-right reading-order properties. This is the
  default. WS_EX_MDICHILD Creates a multiple-document interface (MDI)
  child window.

WS_EX_NOACTIVATE
  Windows 2000/XP: A top-level window created with this style does not
  become the foreground window when the user clicks it. The system
  does not bring this window to the foreground when the user minimizes
  or closes the foreground window. To activate the window, use the
  SetActiveWindow or SetForegroundWindow function.  The window does
  not appear on the taskbar by default. To force the window to appear
  on the taskbar, use the WS_EX_APPWINDOW style.

WS_EX_NOINHERITLAYOUT
  Windows 2000/XP: A window created with this style does not pass its window 
  layout to its child windows. 
WS_EX_NOPARENTNOTIFY
  Specifies that a child window created with this style does not send
  the WM_PARENTNOTIFY message to its parent window when it is created
  or destroyed.

WS_EX_OVERLAPPEDWINDOW
  Combines the WS_EX_CLIENTEDGE and WS_EX_WINDOWEDGE styles.
WS_EX_PALETTEWINDOW
  Combines the WS_EX_WINDOWEDGE, WS_EX_TOOLWINDOW, and WS_EX_TOPMOST styles. 

WS_EX_RIGHT
  The window has generic "right-aligned" properties. This depends on
  the window class. This style has an effect only if the shell
  language is Hebrew, Arabic, or another language that supports
  reading-order alignment; otherwise, the style is ignored. Using the
  WS_EX_RIGHT style for static or edit controls has the same effect as
  using the SS_RIGHT or ES_RIGHT style, respectively. Using this style
  with button controls has the same effect as using BS_RIGHT and
  BS_RIGHTBUTTON styles.

WS_EX_RIGHTSCROLLBAR
  Vertical scroll bar (if present) is to the right of the client area. This is 
  the default. WS_EX_RTLREADING
  If the shell language is Hebrew, Arabic, or another language that supports 
  reading-order alignment, the window text is displayed using right-to-left 
  reading-order properties. For other languages, the style is ignored. 

WS_EX_STATICEDGE
  Creates a window with a three-dimensional border style intended to
  be used for items that do not accept user input. WS_EX_TOOLWINDOW
  Creates a tool window; that is, a window intended to be used as a
  floating toolbar. A tool window has a title bar that is shorter than
  a normal title bar, and the window title is drawn using a smaller
  font. A tool window does not appear in the taskbar or in the dialog
  that appears when the user presses ALT+TAB. If a tool window has a
  system menu, its icon is not displayed on the title bar. However,
  you can display the system menu by right-clicking or by typing
  ALT+SPACE. WS_EX_TOPMOST Specifies that a window created with this
  style should be placed above all non- topmost windows and should
  stay above them, even when the window is deactivated. To add or
  remove this style, use the SetWindowPos function.

WS_EX_TRANSPARENT
  Specifies that a window created with this style should not be
  painted until siblings beneath the window (that were created by the
  same thread) have been painted. The window appears transparent
  because the bits of underlying sibling windows have already been
  painted.  To achieve transparency without these restrictions, use
  the SetWindowRgn function.

WS_EX_WINDOWEDGE
  Specifies that a window has a border with a raised edge.

*/
- (LRESULT) decodeWM_CREATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  //Created by original author
  WIN_INTERN *win;
  NSBackingStoreType type = (NSBackingStoreType)((LPCREATESTRUCT)lParam)->lpCreateParams;

  // Initialize the window. 
  NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "CREATE", hwnd);
  /* For windows with backingstore we create a compatible DC, that 
	   is stored in the extra fields for this window. Drawing operations 
	   work on this buffer. */
  win = objc_malloc(sizeof(WIN_INTERN));
  SetWindowLong(hwnd, GWL_USERDATA, (int)win);
	
  if (type != NSBackingStoreNonretained)
    {
      HDC hdc, hdc2;
      HBITMAP hbitmap;
      RECT r;

      GetClientRect((HWND)hwnd, &r);
      hdc = GetDC(hwnd);
      hdc2 = CreateCompatibleDC(hdc);
      hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, 
				       r.bottom - r.top);
      win->old = SelectObject(hdc2, hbitmap);

      win->hdc = hdc2;
      win->useHDC = YES;
	    
      ReleaseDC(hwnd, hdc);
    }
  else
    {
      win->useHDC = NO;
    }

#ifdef __WM_CREATE__
  printf("WM_CREATE: *********************\n");
#ifdef __W32_debug__
  printf("%s",[[self w32_createDetails:(LPCREATESTRUCT)lParam] cString]);
  fflush(stdout);
#endif
  

  printf("Parent isa %s\n",[[self getNativeClassName:GetParent(hwnd)] cString]);
  printf("[hwnd]Native WindowType %s\n",[[self getNativeClassName:(HWND)hwnd] cString]);
  printf("[hwnd]GS WindowType %s:\n",[[EVENT_WINDOW(hwnd) className] cString]);
  printf("HAVE_MAIN_MENU = %s\n",flags.HAVE_MAIN_MENU ? "YES": "NO");
  printf("Main Menu Window Num: %d    Currrent window Num:  %d\n",
	 [[[NSApp mainMenu] window] windowNumber],(int)hwnd);
  printf("Window Task bar flag %s\n",flags.useWMTaskBar ? "YES" : "NO");
#endif

  return 0;
}

- (void) trackWindow:(NSNotification*)aNotification
{
  // stubbed for future development
 
  // later when I have a Clss/ stye system in place, I can get the
  // window server
  //to Post a notification when a window is fully inited.... or I could use a catagorey extention
  //to NSwindow, to make it post my notification.
}

@end

