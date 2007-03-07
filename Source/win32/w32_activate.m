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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, 
   Boston, MA 02111 USA.
   */


#include <AppKit/NSImage.h>
#include <AppKit/NSBitmapImageRep.h>
#include <Foundation/NSData.h>
#include "w32_Events.h"

@implementation WIN32Server (w32_activate)

- (LRESULT) decodeWM_ACTIVEParams:(WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // decode our params
      
  flags._last_WM_ACTIVATE = LOWORD(wParam);
  //int minimized = HIWORD(wParam);

  switch (flags._last_WM_ACTIVATE)
    {
    case WA_ACTIVE:  //deactivate
      {
	// future implimentation if needed
      }
      break;
    case WA_CLICKACTIVE:  //order back the window
      {
	// future implimentation if needed
      }
      break;
    case WA_INACTIVE: // set currentactive and display
      {
	currentActive=hwnd;
	[EVENT_WINDOW(lParam) display];
      }
      break;
	
    default:
      break;
    }

  return 0;
}

- (LRESULT) decodeWM_ACTIVEAPPParams: (HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
  BOOL active=[NSApp isActive];
          
  switch ((int)wParam)
    {
    case TRUE:
      {
	if (active==YES)
	  {
	    if (flags._is_menu==YES) // have menu and app active
	      {
		// future implimentation if needed
	      }
	    else  // Not a menu and app is active
	      {
		// window is Visable
		if ([EVENT_WINDOW(hwnd) isVisible]==YES) 
		  {
		    // future implimentation if needed
		  }    
		else
		  {
		    // future implimentation if needed
		  }
	      }
	  }
	else  // app is not active
	  {
	    [NSApp activateIgnoringOtherApps:YES];
	    flags._eventHandled=YES;
	  }    
      }
      break;
    case FALSE:
      {
	if (flags._is_menu==YES)
	  {
	    // future implimentation if needed
	  }
	else
	  {
	    // future implimentation if needed
	  }             
      }            
      break;
              
    default:
      break;            
    }
            
  return 0;
}

- (void) decodeWM_NCACTIVATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{

}

@end
