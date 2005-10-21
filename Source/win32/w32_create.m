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
@end
