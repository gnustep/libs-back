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


//- (LRESULT) decodeWM_SETTEXTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
//{
//printf("WM_SETTEXT\n");
//printf("Window text is: %s\n",(LPSTR)lParam);

//BOOL result=SetWindowText(hwnd,(LPSTR)lParam);    
    
  //      if (result==0)
            //printf("error on setWindow text %ld\n",GetLastError());
        
//return 0;
//}


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

- (void) decodeWM_GETTEXTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
#ifdef __TESTEVENT__
  printf("WM_GETTEXT\n");
#endif
}

@end
