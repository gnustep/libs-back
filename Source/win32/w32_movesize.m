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

#include "w32_Events.h"

@implementation WIN32Server (w32_movesize)

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
         

  if (hwnd==(HWND)flags.menuRef)
    {
      //need native code here?
      if (flags.HOLD_MENU_FOR_MOVE==FALSE)
	{
	  [EVENT_WINDOW(hwnd) sendEvent:ev];
	}
      
    }
  else
    {
      if (flags.HOLD_TRANSIENT_FOR_MOVE==FALSE)
	[EVENT_WINDOW(hwnd) sendEvent:ev];
    }   
		  
  ev=nil;
  flags.HOLD_MENU_FOR_MOVE=FALSE;
  flags.HOLD_MINI_FOR_MOVE=FALSE;
  flags.HOLD_TRANSIENT_FOR_MOVE=FALSE;
  
  return 0;
}

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
      }
      break;
    case SIZE_MAXIMIZED:
      {
	// stubbed for future development
      }
      break;
    case SIZE_MAXSHOW:
      {
	// stubbed for future development
      }
      break;
    case SIZE_MINIMIZED:
      {
      
	if  (flags.HOLD_MINI_FOR_SIZE==TRUE) //// this is fix for [5, 25 bug]
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
               
	if (hwnd==(HWND)flags.menuRef)
	  {
	    if (flags.HOLD_MENU_FOR_SIZE==FALSE)
	      {
                  [[NSApp mainMenu] setMenuChangedMessagesEnabled:YES];
		[EVENT_WINDOW(hwnd) sendEvent:ev];
		[self resizeBackingStoreFor:hwnd];
		            [EVENT_WINDOW(hwnd) miniaturize:self];
		            [[NSApp mainMenu] setMenuChangedMessagesEnabled:NO];
	      }
	  }
	else 
	  {   
	    if (flags.HOLD_TRANSIENT_FOR_SIZE==FALSE)
	      {
		[EVENT_WINDOW(hwnd) sendEvent:ev];
		[self resizeBackingStoreFor:hwnd];
		if ([self usesNativeTaskbar])
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
               
	if (hwnd==(HWND)flags.menuRef)
	  {
	    if (flags.HOLD_MENU_FOR_SIZE==FALSE)
	      {
               [EVENT_WINDOW(hwnd) _setVisible:YES];
		[EVENT_WINDOW(hwnd) sendEvent:ev];
		[self resizeBackingStoreFor:hwnd];
		         //[EVENT_WINDOW(hwnd) deminiaturize:self];
		         
	      }
	  }
	else
	  { 
	    if (flags.HOLD_TRANSIENT_FOR_SIZE==FALSE)
	      {
		[EVENT_WINDOW(hwnd) sendEvent:ev];
		[self resizeBackingStoreFor:hwnd];
		// fixes part one of bug [5, 25] see notes
		if ([self usesNativeTaskbar])
		  [EVENT_WINDOW(hwnd) deminiaturize:self];
	      } 
	  } 
      }
      break;
      
    default:
      break;
    }
                      
  ev=nil;
  flags.HOLD_MENU_FOR_SIZE=FALSE;
  flags.HOLD_MINI_FOR_SIZE=FALSE;
  flags.HOLD_TRANSIENT_FOR_SIZE=FALSE;

  return 0;
}

- (void) decodeWM_NCCALCSIZEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd 
{
  // stub for future dev

    /*NCCALCSIZE_PARAMS * newRects;

   NSPoint eventLocation;
   NSRect rect;
   RECT drect;
   NSEvent *ev =nil;

   if (wParam==TRUE)
   {
      // get first rect from NCCALCSIZE_PARAMS Structure
      newRects=(NCCALCSIZE_PARAMS *)lParam;
      // get rect 1 from array
      drect=newRects->rgrc[1];

        //create a size event and send it to the window
        rect = MSScreenRectToGS(drect, [EVENT_WINDOW(hwnd) styleMask], self);
        eventLocation = rect.origin;

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

                   [EVENT_WINDOW(hwnd) sendEvent:ev];*/
                   //[[EVENT_WINDOW(hwnd)  contentView] display];
		            //[self resizeBackingStoreFor:hwnd];


		           /* ev = [NSEvent otherEventWithType: NSAppKitDefined
			          location: eventLocation
			     modifierFlags: 0
			         timestamp: 0
			      windowNumber: (int)hwnd
			           context: GSCurrentContext()
			           subtype: GSAppKitWindowMoved
			             data1: rect.origin.x
                   data2: rect.origin.y]; 

		            [EVENT_WINDOW(hwnd) sendEvent:ev];

        //printf(" Rect 1 =\n%s", [[self MSRectDetails:drect] cString]);

   }

   //printf("wParam is %s\n", wParam ? "TRUE" : "FALSE");*/
}

- (void) decodeWM_WINDOWPOSCHANGEDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
}

- (void) decodeWM_WINDOWPOSCHANGINGParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
  // stub for future dev
}

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
	  
  return 0; 
}

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
  return 0;
}

- (void) decodeWM_SIZINGParams:(HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
   // stub for future dev

   flags.HOLD_PAINT_FOR_SIZING=TRUE;

   //[EVENT_WINDOW(hwnd) displayIfNeeded];
   //[self decodeWM_SIZEParams:(HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam];
   //printf("SIZING called\n");

   //return TRUE;
}

- (LRESULT) decodeWM_MOVINGParams:(HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
  // stub for future dev
   [self decodeWM_MOVEParams:(HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam];

   return TRUE;
}
@end




