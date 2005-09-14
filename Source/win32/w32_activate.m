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


#include <AppKit/NSImage.h>
#include <AppKit/NSBitmapImageRep.h>
#include <Foundation/NSData.h>
#include "w32_Events.h"

static NSString *NSMenuWillTearOff = @"MenuWillTearOff";
static NSString *NSMenuwillPopUP =@"MenuwillPopUP";
@interface NSMenu (w32Menu)
 
- (void) _rightMouseDisplay: (NSEvent*)theEvent;
- (void) setTornOff: (BOOL)flag;
@end

@implementation NSMenu (w32Menu)

// fixme to handle context menues better on win32
// although it works better then it used to, it still
// needs more work. 

- (void) _rightMouseDisplay: (NSEvent*)theEvent
{

  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSNotification * popped;
  //printf("my menu tarnsient method\n");
    
  // need to get hwnd for the window
  [self displayTransient];
  // post notification here
  popped = [NSNotification
		 notificationWithName: NSMenuwillPopUP
			       object: _bWindow
			     userInfo: nil];
		 
  [nc postNotification: popped];

  [_view mouseDown: theEvent];
  [self closeTransient];
  [_bWindow orderOut:self];

}

- (void) setTornOff: (BOOL)flag
{

  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSNotification * torn;
  NSMenu	*supermenu;

  _is_tornoff = flag; 

  if (flag)
    {
      supermenu = [self supermenu];
      if (supermenu != nil)
        {
          [[supermenu menuRepresentation] setHighlightedItemIndex: -1];
          supermenu->_attachedMenu = nil;
        }
        
      torn = [NSNotification
		 notificationWithName: NSMenuWillTearOff
			       object: self
			     userInfo: nil];
		 
      [nc postNotification: torn];
    }
  [_view update];
}

@end




@implementation WIN32Server (w32_activate)

/*	
* wParam
*	The low-order word specifies whether the window is being activated 
*       or deactivated. 
*	This parameter can be one of the following values. 
*	The high-order word specifies the minimized state of 
*	the window being activated or deactivated. 
*	A nonzero value indicates the window is minimized. 
* WA_ACTIVE
*	Activated by some method other than a mouse click 
*	(for example, by a call to the SetActiveWindow 
*	function or by use of the keyboard interface to select the window).
* WA_CLICKACTIVE
*	Activated by a mouse click.
* WA_INACTIVE
*	Deactivated.
* lParam
*	Handle to the window being activated or deactivated, depending on 
*	the value of the wParam parameter. If the low-order word of wParam 
*	is WA_INACTIVE, lParam is the handle to the window being activated. 
*	If the low-order word of wParam is WA_ACTIVE or WA_CLICKACTIVE, 
*	lParam is the handle to the window being deactivated. This handle 
*        can be NULL. 
*
* Return Value
* If an application processes this message, it should return zero. 
*/

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
#ifdef __WM_ACTIVE__
  BOOL target=NO;

  if((int)lParam == flags.menuRef)
    target=YES;

  printf("RECEIVER [hwnd]%s\n",[[EVENT_WINDOW(hwnd) className] cString]);
  printf("ON [lParam]%s\n",[[EVENT_WINDOW(lParam) className] cString]);

  printf("[lParam] %s",[[self gswindowstate:EVENT_WINDOW(lParam)] cString]);
  printf("ACTIVATE_FLAG STATE %d \n",_last_WM_ACTIVATE);

  printf("[hwnd] %s",[[self gswindowstate:EVENT_WINDOW(hwnd)] cString]);
  fflush(stdout);
#endif

  return 0;
}

/*
 * 
 * The WM_ACTIVATEAPP message is sent when a window belonging to a
 * different application than the active window is about to be
 * activated. The message is sent to the application whose window is
 * being activated and to the application whose window is being
 * deactivated.
 *
 * A window receives this message through its WindowProc function. 
 *
 * Syntax
 *
 * WM_ACTIVATEAPP
 * 
 *    WPARAM wParam
 *    LPARAM lParam;
 * Parameters
 * 
 * wParam
 *    Specifies whether the window is being activated or deactivated. 
 *    This parameter is TRUE if the window is being activated; it is FALSE if 
 *    the window is being deactivated.
 * lParam
 *    Specifies a thread identifier (a DWORD). If the wParam parameter
 *    is TRUE, lParam is the identifier of the thread that owns the
 *    window being deactivated.  If wParam is FALSE, lParam is the
 *    identifier of the thread that owns the window being activated.
 * 
 * Return Value 
 * If an application processes this message, it should return zero.  */


- (LRESULT) decodeWM_ACTIVEAPPParams: (HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam
{
          
  BOOL active=[NSApp isActive];
          
  switch ((int)wParam)
    {
    case TRUE:
      {
	if(active==YES)
	  {
	    if (flags._is_menu==YES) // have menu and app active
	      {
		// future implimentation if needed
	      }
	    else  // Not a menu and app is active
	      {
		// window is Visable
		if([EVENT_WINDOW(hwnd) isVisible]==YES) 
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
            
#ifdef __WM_ACTIVATEAPP__

  printf("NSApp is:[%s]\n",active ? "active" : "inactive");
  printf("lParam is [%s]\n thread = [%u]\n  w32_Class[%s] \n",
	 (int)wParam ? "TRUE": "FALSE",
	 (unsigned int)lParam,
	 [[self getNativeClassName:hwnd] cString]);
  // debug GS_state details       
  printf("%s",[[self gswindowstate:EVENT_WINDOW(hwnd)] cString]);
  printf("%s",[[self gswindowstate:EVENT_WINDOW(wParam)] cString]);
  printf("eventHandled=[%s]\n",_eventHandled ? "YES" : "NO");
            
  printf("REQUESTED STATE %d\n",flags._last_WM_ACTIVATE);
  fflush(stdout);
#endif 

  return 0;
}

/*
  WM_NCACTIVATE Notification

  The WM_NCACTIVATE message is sent to a window when its nonclient
  area needs to be changed to indicate an active or inactive state.  A
  window receives this message through its WindowProc function.

  Syntax

  WM_NCACTIVATE

  WPARAM wParam
  LPARAM lParam;

  Parameters

  wParam
    Specifies when a title bar or icon needs to be changed to indicate
    an active or inactive state. If an active title bar or icon is to
    be drawn, the wParam parameter is TRUE. It is FALSE for an
    inactive title bar or icon.
  lParam        
    This parameter is not used.

  Return Value

  When the wParam parameter is FALSE, an application should return
  TRUE to indicate that the system should proceed with the default
  processing, or it should return FALSE to prevent the title bar or
  icon from being deactivated.  When wParam is TRUE, the return value
  is ignored.

  Remarks

  The DefWindowProc function draws the title bar or icon title in its
  active colors when the wParam parameter is TRUE and in its inactive
  colors when wParam is FALSE.  
*/

- (void) decodeWM_NCACTIVATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd
{
#ifdef __TESTEVENT__
  printf("WM_NCACTIVATE\n");
#endif
}
/*
   Notification hook from application
   The default notification are:
 
        NSApplicationDidFinishLaunchingNotification
        NSApplicationWillFinishLaunchingNotification
        NSApplicationWillHideNotification
        NSWindowWillMiniaturizeNotification
        
        Custom Notifications:
        NSMenuWillTearOff
        NSMenuwillPopUP
        
   when these are received the Win32 server can now finalize its setup.
   other hook can also be set at this point
   syncronize the GS Env with The native Backend so we can use native
   calls to manage certain things directly.
 */
- (void) ApplicationWillFinishLaunching: (NSNotification*)aNotification;
{
}
 
 
- (void) ApplicationDidFinishLaunching: (NSNotification*)aNotification  
{
  LONG result;  
  // Get our MainMenu  window refference:

  flags.menuRef=[[[NSApp mainMenu] window] windowNumber];
  flags.HAVE_MAIN_MENU=YES;
    
  /*
    reset the style on the main menu panel so when it hides it will go
    the the task bar I will use WS_EX_RIGHT for this. Note that this
    is native code mixed with GNUStep */
  ShowWindow((HWND)flags.menuRef,SW_HIDE);
  SetLastError(0);
  result=SetWindowLong((HWND)flags.menuRef,GWL_EXSTYLE,(LONG)WS_EX_RIGHT);
  // should check error here...
    
  ShowWindow((HWND)flags.menuRef,SW_SHOWNORMAL);
    
  // set app icon image for win32
    
  // future implimentation 
        
#ifdef __WM_ACTIVE__

  printf("reseting menu style\n");
  if (result==0)
    {
      printf("setting mainMenu Style: Error %ld\n",GetLastError());

    }
  fflush(stdout);
#endif
}

- (void) ApplicationWillHideNotification: (NSNotification*)aNotification
{        
  flags.HOLD_MENU_FOR_MOVE=TRUE;
  flags.HOLD_MENU_FOR_SIZE=TRUE;
        
  ReleaseCapture(); // if the mouse is 'stuck' release it
    
#ifdef __WM_ACTIVE__
  printf("UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU\n");
  printf("got Notification: %s\n",
         [[aNotification name] cString]);
  fflush(stdout);
#endif

}

-(void) WindowWillMiniaturizeNotification:(NSNotification*)aNotification
{
  flags.HOLD_MINI_FOR_SIZE=TRUE;
  flags.HOLD_MINI_FOR_MOVE=TRUE;
}

-(void) MenuWillTearOff:(NSNotification*)aNotification
{
  LONG result;
  NSMutableString * iconTitle =[NSMutableString stringWithString:@"MENU "];
  NSMenu * theMenu=[aNotification object];
  int windowNum =[[theMenu window] windowNumber];
    
  ShowWindow((HWND)windowNum,SW_HIDE);
  SetLastError(0);
  result=SetWindowLong((HWND)windowNum,GWL_EXSTYLE,(LONG)WS_EX_RIGHT);
  // should check error here...
    
  // set the icon title
  [iconTitle appendString: [theMenu title]];
  result=SetWindowText((HWND)windowNum,[iconTitle cString]); 
  ShowWindow((HWND)windowNum,SW_SHOWNORMAL);


#ifdef __APPNOTIFICATIONS__
  printf("got menu tear off Notification\n");
  printf("menu title is: %s\n",[[theMenu title] cString]);
#endif
}

-(void) MenuwillPopUP:(NSNotification*)aNotification
{
  LONG result;
  int windowNum=[[aNotification object] windowNumber]; 

  ShowWindow((HWND)windowNum,SW_HIDE);
  SetLastError(0);
  result=SetWindowLong((HWND)windowNum,GWL_EXSTYLE,(LONG)WS_EX_RIGHT);
  // should check error here...
    
  // set the icon title
  result=SetWindowText((HWND)windowNum,"Context menu"); 
  ShowWindow((HWND)windowNum,SW_SHOWNORMAL);

  flags.HOLD_TRANSIENT_FOR_SIZE=TRUE;
  flags.HOLD_TRANSIENT_FOR_MOVE=TRUE;
    
#ifdef __APPNOTIFICATIONS__
  printf("got menu Popup Notification\n");
  printf("window title is: %s\n",[[[aNotification object] title] cString]);
#endif

}

@end
