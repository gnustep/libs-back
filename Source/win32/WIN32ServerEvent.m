/* WIN32ServerEvent - Implements event handling for MSWindows

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#include <Foundation/NSDebug.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSTimer.h>
#include <AppKit/AppKitExceptions.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSText.h>
#include <AppKit/DPSOperators.h>

#include "win32/WIN32Server.h"
#include "win32/WIN32Geometry.h"

/*
 This standard windows macros are missing in MinGW.  The definition
 here is almost correct, but will fail for multi monitor systems
*/
#ifndef GET_X_LPARAM
#define GET_X_LPARAM(p) ((int)(short)LOWORD(p))
#endif
#ifndef GET_Y_LPARAM
#define GET_Y_LPARAM(p) ((int)(short)HIWORD(p))
#endif

static NSEvent *process_key_event(HWND hwnd, WPARAM wParam, LPARAM lParam, 
				  NSEventType eventType);
static NSEvent *process_mouse_event(HWND hwnd, WPARAM wParam, LPARAM lParam, 
				    NSEventType eventType);
static void invalidateWindow(HWND hwnd, RECT rect);

@interface WIN32Server (Internal)
- (NSEvent *) handleGotFocus: (HWND)hwnd;
- (NSEvent *) handleMoveSize: (HWND)hwnd
                            : (GSAppKitSubtype) subtype;
- (void) resizeBackingStoreFor: (HWND)hwnd;
- (LRESULT) windowEventProc: (HWND)hwnd : (UINT)uMsg 
		       : (WPARAM)wParam : (LPARAM)lParam;
@end

@implementation WIN32Server (EventOps)

- (void) callback: (id) sender
{
  MSG msg;
  WINBOOL bRet; 

  while ((bRet = PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) != 0)
    { 

      if (msg.message == WM_QUIT)
	{
	  // Exit the program
	  return;
	}
      if (bRet == -1)
	{
	  // handle the error and possibly exit
	}
      else
	{
	  // Don't translate messages, as this would give extra character messages.
	  DispatchMessage(&msg); 
	} 
    } 
}

- (BOOL) hasEvent
{
  return (GetQueueStatus(QS_ALLEVENTS) != 0);
}

- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
  [self callback: mode];
}


- (NSEvent*) getEventMatchingMask: (unsigned)mask
		       beforeDate: (NSDate*)limit
			   inMode: (NSString*)mode
			  dequeue: (BOOL)flag
{
  [self callback: nil];
  return [super getEventMatchingMask: mask
		beforeDate: limit
		inMode: mode
		dequeue: flag];
}

- (void) discardEventsMatchingMask: (unsigned)mask
		       beforeEvent: (NSEvent*)limit
{
  [self callback: nil];
  [super discardEventsMatchingMask: mask
			  beforeEvent: limit];
}

@end

@implementation WIN32Server (Internal)

/* This message comes when the window already got focus, so we send a focus
   in event to the front end, but also mark the window as having current focus
   so that the front end doesn't try to focus the window again. */
- (NSEvent *) handleGotFocus: (HWND)hwnd
{
  int key_num, win_num;
  NSEvent *e = nil;
  NSPoint eventLocation;

  key_num = [[NSApp keyWindow] windowNumber];
  win_num = (int)hwnd;
  NSDebugLLog(@"Focus", @"Got focus:%d (current = %d, key = %d)", 
	      win_num, currentFocus, key_num);
  currentFocus = hwnd;
  eventLocation = NSMakePoint(0,0);
  if (currentFocus == desiredFocus)
    {
      /* This was from a request from the front end. Mark as done. */
      desiredFocus = 0;
      NSDebugLLog(@"Focus", @"  result of focus request");
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
  return e;
}

/**
*/
- (NSEvent *) handleMoveSize: (HWND)hwnd
                            : (GSAppKitSubtype) subtype
{
  NSPoint eventLocation;
  NSRect rect;
  RECT r;
  NSEvent *ev = nil;
  NSWindow *window = GSWindowWithNumber((int)hwnd);

  GetWindowRect(hwnd, &r);
  rect = MSScreenRectToGS(r, [window styleMask], self);
  eventLocation = rect.origin;

  if (window)
    {
      if( subtype == GSAppKitWindowMoved )
	{
	  ev = [NSEvent otherEventWithType: NSAppKitDefined
			          location: eventLocation
			     modifierFlags: 0
			         timestamp: 0
			      windowNumber: (int)hwnd
			           context: GSCurrentContext()
			           subtype: GSAppKitWindowMoved
			             data1: rect.origin.x
                                     data2: rect.origin.y];
	}
      else if( subtype == GSAppKitWindowResized )
	{
	  ev = [NSEvent otherEventWithType: NSAppKitDefined
                                  location: eventLocation
                             modifierFlags: 0
                                 timestamp: 0
                              windowNumber: (int) hwnd
                                   context: GSCurrentContext()
                                   subtype: GSAppKitWindowResized
                                     data1: rect.size.width
                                     data2: rect.size.height];
	}
      else
	{
	  return nil;
	}
    }
  return ev;
}

- (void) resizeBackingStoreFor: (HWND)hwnd
{
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
      NSDebugLLog(@"NSEvent", @"Change backing store to %d %d", r.right - r.left, r.bottom - r.top);
      hdc = GetDC((HWND)hwnd);
      hdc2 = CreateCompatibleDC(hdc);
      hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, r.bottom - r.top);
      win->old = SelectObject(hdc2, hbitmap);
      win->hdc = hdc2;
      
      ReleaseDC((HWND)hwnd, hdc);
    }
}

- (LRESULT) windowEventProc: (HWND)hwnd : (UINT)uMsg 
		       : (WPARAM)wParam : (LPARAM)lParam
{ 
  NSEvent *ev = nil;

  switch (uMsg) 
    { 
    case WM_SETTEXT: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "SETTEXT", hwnd);
      break;
    case WM_NCCREATE: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCCREATE", hwnd);
      break;
    case WM_NCCALCSIZE: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCCALCSIZE", hwnd);
      break;
    case WM_NCACTIVATE: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d: %s", "NCACTIVATE", 
		  hwnd, (wParam) ? "active" : "deactive");
      break;
    case WM_NCPAINT: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCPAINT", hwnd);
      break;
    case WM_NCHITTEST: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCHITTEST", hwnd);
      break;
    case WM_SHOWWINDOW: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d: %s %d", "SHOWWINDOW", 
		  hwnd, (wParam) ? "show" : "hide", lParam);
      break;
    case WM_NCMOUSEMOVE: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCMOUSEMOVE", hwnd);
      break;
    case WM_NCLBUTTONDOWN: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCLBUTTONDOWN", hwnd);
      break;
    case WM_NCLBUTTONUP: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCLBUTTONUP", hwnd);
      break;
    case WM_NCDESTROY: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCDESTROY", hwnd);
      break;
    case WM_GETTEXT: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "GETTEXT", hwnd);
      break;
    case WM_STYLECHANGING: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "STYLECHANGING", hwnd);
      break;
    case WM_STYLECHANGED: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "STYLECHANGED", hwnd);
      break;

    case WM_GETMINMAXINFO:
      {
	WIN_INTERN *win = (WIN_INTERN *)GetWindowLong(hwnd, GWL_USERDATA);
	MINMAXINFO *mm;

	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "GETMINMAXINFO", hwnd);
	if (win != NULL)
	  {
	    mm = (MINMAXINFO*)lParam;
	    mm->ptMinTrackSize = win->minmax.ptMinTrackSize;
	    mm->ptMaxTrackSize = win->minmax.ptMaxTrackSize;
	    return 0;
	  }
      }
    case WM_CREATE: 
      {
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
	
	break;
      }
    case WM_WINDOWPOSCHANGING: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "WINDOWPOSCHANGING", hwnd);
      break;
    case WM_WINDOWPOSCHANGED: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "WINDOWPOSCHANGED", hwnd);
      break;
    case WM_MOVE:
      {
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOVE", hwnd);
	ev = [self handleMoveSize: hwnd : GSAppKitWindowMoved];
	break;
      }
    case WM_MOVING: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOVING", hwnd);
      break;
    case WM_SIZE: 
      {
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "SIZE", hwnd);
	ev = [self handleMoveSize: hwnd : GSAppKitWindowResized];
	break;
      }
    case WM_SIZING: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "SIZING", hwnd);
      break;
    case WM_ENTERSIZEMOVE: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "ENTERSIZEMOVE", hwnd);
      break;
    case WM_EXITSIZEMOVE: 
      {
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "EXITSIZEMOVE", hwnd);
	[self resizeBackingStoreFor: hwnd];
	ev = [self handleMoveSize: hwnd : GSAppKitWindowMoved];
	if (ev != nil)
	  {
	    [GSCurrentServer() postEvent: ev atStart: NO];
	  }
	ev = [self handleMoveSize: hwnd : GSAppKitWindowResized];
	if (ev != nil)
	  {
	    [GSCurrentServer() postEvent: ev atStart: NO];
	  }
	// Make sure DefWindowProc gets called
	ev = nil;
	break;
      }
    case WM_ACTIVATE: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d: %s %d", "ACTIVATE", 
		  hwnd, (LOWORD(wParam)) ? "activate" : "deactivate",
		  HIWORD(wParam));
      if (LOWORD(wParam))
	currentActive = hwnd;
      break;
    case WM_ACTIVATEAPP:
      {
	int special;
	BOOL active = [NSApp isActive];
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d: %s (app is %s)", 
		    "ACTIVATEAPP", hwnd, (wParam) ? "activate" : "deactivate",
		    (active) ? "active" : "deactivated");
	special = [[[NSApp mainMenu] window] windowNumber];
	if (active == NO && wParam)
          {

	  [NSApp activateIgnoringOtherApps: YES];
         }
	else if (special == (int)hwnd && active == YES && wParam == 0)
	  [NSApp deactivate];
      }
      break;
    case WM_MOUSEACTIVATE: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOUSEACTIVATE", hwnd);
      break;
    case WM_SETFOCUS: 
      {
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "SETFOCUS", hwnd);
	ev = [self handleGotFocus: hwnd];
	break;
      }
    case WM_KILLFOCUS: 
      {
	NSPoint eventLocation = NSMakePoint(0,0);

	if (wParam == (int)hwnd)
  	  return 0;
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "KILLFOCUS", hwnd);
	NSDebugLLog(@"Focus", @"Got KILLFOCUS (focus out) for %d", hwnd);
	ev = [NSEvent otherEventWithType:NSAppKitDefined
		      location: eventLocation
		      modifierFlags: 0
		      timestamp: 0
		      windowNumber: (int)hwnd
		      context: GSCurrentContext()
		      subtype: GSAppKitWindowFocusOut
		      data1: 0
		      data2: 0];
	break;
      }
    case WM_SETCURSOR: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "SETCURSOR", hwnd);
      break;
    case WM_QUERYOPEN: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "QUERYOPEN", hwnd);
      break;
    case WM_CAPTURECHANGED: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "CAPTURECHANGED", hwnd);
      break;
      
    case WM_ERASEBKGND: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "ERASEBKGND", hwnd);
      // Handle background painting ourselves.
      return (LRESULT)1;
      break;
    case WM_PAINT: 
      {
	RECT rect;

	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "PAINT", hwnd);
	if (GetUpdateRect(hwnd, &rect, NO))
	  {
	    invalidateWindow(hwnd, rect);
	    // validate the whole window, for in some cases an infinite series
            // of WM_PAINT is triggered
            ValidateRect(hwnd, NULL);
	  }

	return 0;
      }
    case WM_SYNCPAINT: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "SYNCPAINT", hwnd);
      break;
      
    case WM_CLOSE: 
      {
	NSPoint eventLocation = NSMakePoint(0,0);

	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "CLOSE", hwnd);
	ev = [NSEvent otherEventWithType: NSAppKitDefined
		      location: eventLocation
		      modifierFlags: 0
		      timestamp: 0
		      windowNumber: (int)hwnd
		      context: GSCurrentContext()
		      subtype: GSAppKitWindowClose
		      data1: 0
		      data2: 0];
	break;
      }
    case WM_DESTROY:
      { 
	WIN_INTERN *win = (WIN_INTERN *)GetWindowLong(hwnd, GWL_USERDATA);

	// Clean up window-specific data objects. 
	NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "DESTROY", hwnd);
	
	if (win->useHDC)
	  {
	    HGDIOBJ old;
	    
	    old = SelectObject(win->hdc, win->old);
	    DeleteObject(old);
	    DeleteDC(win->hdc);
	  }
	objc_free(win);
	break;
      }
    case WM_KEYDOWN:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "KEYDOWN", hwnd);
      ev = process_key_event(hwnd, wParam, lParam, NSKeyDown);
      break;
    case WM_KEYUP:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "KEYUP", hwnd);
      ev = process_key_event(hwnd, wParam, lParam, NSKeyUp);
      break;

    case WM_MOUSEMOVE: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOUSEMOVE", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSMouseMoved);
      break;
    case WM_LBUTTONDOWN: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "LBUTTONDOWN", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSLeftMouseDown);
      break;
    case WM_LBUTTONUP: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "LBUTTONUP", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSLeftMouseUp);
      break;
    case WM_LBUTTONDBLCLK: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "LBUTTONDBLCLK", hwnd);
      break;
    case WM_MBUTTONDOWN: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MBUTTONDOWN", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSOtherMouseDown);
      break;
    case WM_MBUTTONUP: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MBUTTONUP", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSOtherMouseUp);
      break;
    case WM_MBUTTONDBLCLK: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MBUTTONDBLCLK", hwnd);
      break;
    case WM_RBUTTONDOWN: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "RBUTTONDOWN", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSRightMouseDown);
      break;
    case WM_RBUTTONUP: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "RBUTTONUP", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSRightMouseUp);
      break;
    case WM_RBUTTONDBLCLK: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "RBUTTONDBLCLK", hwnd);
      break;
    case WM_MOUSEWHEEL: 
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOUSEWHEEL", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSScrollWheel);
      break;

    case WM_QUIT:
      NSLog(@"Got Message %s for %d", "QUIT", hwnd);
      break;
    case WM_USER:
      NSLog(@"Got Message %s for %d", "USER", hwnd);
      break;
    case WM_APP:
      NSLog(@"Got Message %s for %d", "APP", hwnd);
      break;

    case WM_ENTERMENULOOP:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "ENTERMENULOOP", hwnd);
      break;
    case WM_EXITMENULOOP:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "EXITMENULOOP", hwnd);
      break;
    case WM_INITMENU:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "INITMENU", hwnd);
      break;
    case WM_MENUSELECT:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MENUSELECT", hwnd);
      break;
    case WM_ENTERIDLE:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "ENTERIDLE", hwnd);
      break;
 
    case WM_COMMAND:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "COMMAND", hwnd);
      break;
    case WM_SYSKEYDOWN:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "SYSKEYDOWN", hwnd);
      break;
    case WM_SYSKEYUP:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "SYSKEYUP", hwnd);
      break;
    case WM_SYSCOMMAND:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "SYSCOMMAND", hwnd);
      break;
    case WM_HELP:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "HELP", hwnd);
      break;
    case WM_POWERBROADCAST:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "POWERBROADCAST", hwnd);
      break;
    case WM_TIMECHANGE:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "TIMECHANGE", hwnd);
      break;
    case WM_DEVICECHANGE:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "DEVICECHANGE", hwnd);
      break;
    case WM_GETICON:
      NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "GETICON", hwnd);
      break;

    default: 
      // Process all other messages. 
      NSDebugLLog(@"NSEvent", @"Got unhandled Message %d for %d", uMsg, hwnd);
      break;
    } 

  if (ev != nil)
    {
      [GSCurrentServer() postEvent: ev atStart: NO];
      return 0;
    }

  return DefWindowProc(hwnd, uMsg, wParam, lParam); 
}

@end

static unichar 
process_char(WPARAM wParam, unsigned *eventModifierFlags)
{
  switch (wParam)
    {
    case VK_RETURN: return NSCarriageReturnCharacter;
    case VK_TAB:    return NSTabCharacter;
    case VK_ESCAPE:  return 0x1b;
    case VK_BACK:   return NSBackspaceCharacter;

      /* The following keys need to be reported as function keys */
#define WIN_FUNCTIONKEY \
*eventModifierFlags = *eventModifierFlags | NSFunctionKeyMask;
    case VK_F1: WIN_FUNCTIONKEY return NSF1FunctionKey;
    case VK_F2: WIN_FUNCTIONKEY return NSF2FunctionKey;
    case VK_F3: WIN_FUNCTIONKEY return NSF3FunctionKey;
    case VK_F4: WIN_FUNCTIONKEY return NSF4FunctionKey;
    case VK_F5: WIN_FUNCTIONKEY return NSF5FunctionKey;
    case VK_F6: WIN_FUNCTIONKEY return NSF6FunctionKey;
    case VK_F7: WIN_FUNCTIONKEY return NSF7FunctionKey;
    case VK_F8: WIN_FUNCTIONKEY return NSF8FunctionKey;
    case VK_F9: WIN_FUNCTIONKEY return NSF9FunctionKey;
    case VK_F10: WIN_FUNCTIONKEY return NSF10FunctionKey;
    case VK_F11: WIN_FUNCTIONKEY return NSF12FunctionKey;
    case VK_F12: WIN_FUNCTIONKEY return NSF12FunctionKey;
    case VK_F13: WIN_FUNCTIONKEY return NSF13FunctionKey;
    case VK_F14: WIN_FUNCTIONKEY return NSF14FunctionKey;
    case VK_F15: WIN_FUNCTIONKEY return NSF15FunctionKey;
    case VK_F16: WIN_FUNCTIONKEY return NSF16FunctionKey;
    case VK_F17: WIN_FUNCTIONKEY return NSF17FunctionKey;
    case VK_F18: WIN_FUNCTIONKEY return NSF18FunctionKey;
    case VK_F19: WIN_FUNCTIONKEY return NSF19FunctionKey;
    case VK_F20: WIN_FUNCTIONKEY return NSF20FunctionKey;
    case VK_F21: WIN_FUNCTIONKEY return NSF21FunctionKey;
    case VK_F22: WIN_FUNCTIONKEY return NSF22FunctionKey;
    case VK_F23: WIN_FUNCTIONKEY return NSF23FunctionKey;
    case VK_F24: WIN_FUNCTIONKEY return NSF24FunctionKey;

    case VK_DELETE:      WIN_FUNCTIONKEY return NSDeleteFunctionKey;
    case VK_HOME:        WIN_FUNCTIONKEY return NSHomeFunctionKey;
    case VK_LEFT:        WIN_FUNCTIONKEY return NSLeftArrowFunctionKey;
    case VK_RIGHT:       WIN_FUNCTIONKEY return NSRightArrowFunctionKey;
    case VK_UP:          WIN_FUNCTIONKEY return NSUpArrowFunctionKey;
    case VK_DOWN:        WIN_FUNCTIONKEY return NSDownArrowFunctionKey;
    case VK_PRIOR:       WIN_FUNCTIONKEY return NSPrevFunctionKey;
    case VK_NEXT:        WIN_FUNCTIONKEY return NSNextFunctionKey;
    case VK_END:         WIN_FUNCTIONKEY return NSEndFunctionKey;
    //case VK_BEGIN:       WIN_FUNCTIONKEY return NSBeginFunctionKey;
    case VK_SELECT:      WIN_FUNCTIONKEY return NSSelectFunctionKey;
    case VK_PRINT:       WIN_FUNCTIONKEY return NSPrintFunctionKey;
    case VK_EXECUTE:     WIN_FUNCTIONKEY return NSExecuteFunctionKey;
    case VK_INSERT:      WIN_FUNCTIONKEY return NSInsertFunctionKey;
    case VK_HELP:        WIN_FUNCTIONKEY return NSHelpFunctionKey;
    case VK_CANCEL:      WIN_FUNCTIONKEY return NSBreakFunctionKey;
    //case VK_MODECHANGE:  WIN_FUNCTIONKEY return NSModeSwitchFunctionKey;
    case VK_SCROLL:      WIN_FUNCTIONKEY return NSScrollLockFunctionKey;
    case VK_PAUSE:       WIN_FUNCTIONKEY return NSPauseFunctionKey;
    case VK_OEM_CLEAR:   WIN_FUNCTIONKEY return NSClearDisplayFunctionKey;
#undef WIN_FUNCTIONKEY
    default:
      return 0;
    }
}

static NSEvent*
process_key_event(HWND hwnd, WPARAM wParam, LPARAM lParam, 
		  NSEventType eventType)
{
  NSEvent *event;
  BOOL repeat;
  DWORD pos;
  NSPoint eventLocation;
  unsigned int eventFlags;
  NSTimeInterval time;
  LONG ltime;
  unichar unicode[5];
  unsigned int scan;
  int result;
  BYTE keyState[256];
  NSString *keys, *ukeys;
  NSGraphicsContext *gcontext;
  unichar uChar;

  /* FIXME: How do you guarentee a context is associated with an event? */
  gcontext = GSCurrentContext();

  repeat = (lParam & 0xFFFF) != 0;

  pos = GetMessagePos();
  eventLocation = MSWindowPointToGS(hwnd,  GET_X_LPARAM(pos), GET_Y_LPARAM(pos));

  ltime = GetMessageTime();
  time = ltime / 1000;

  GetKeyboardState(keyState);
  eventFlags = 0;
  if (keyState[VK_CONTROL] & 128)
    eventFlags |= NSControlKeyMask;
  if (keyState[VK_SHIFT] & 128)
    eventFlags |= NSShiftKeyMask;
  if (keyState[VK_CAPITAL] & 128)
    eventFlags |= NSShiftKeyMask;
  if (keyState[VK_MENU] & 128)
    eventFlags |= NSAlternateKeyMask;
  if ((keyState[VK_LWIN] & 128) || (keyState[VK_RWIN] & 128))
    eventFlags |= NSCommandKeyMask;


  switch(wParam)
    {
    case VK_SHIFT:
    case VK_CAPITAL:
    case VK_CONTROL:
    case VK_MENU:
    case VK_NUMLOCK:
      eventType = NSFlagsChanged;
      break;
    case VK_NUMPAD0: 
    case VK_NUMPAD1: 
    case VK_NUMPAD2: 
    case VK_NUMPAD3: 
    case VK_NUMPAD4: 
    case VK_NUMPAD5: 
    case VK_NUMPAD6: 
    case VK_NUMPAD7: 
    case VK_NUMPAD8: 
    case VK_NUMPAD9:
      eventFlags |= NSNumericPadKeyMask;
      break;
    default:
      break;
    }


  uChar = process_char(wParam, &eventFlags);
  if (uChar)
    {
      keys = [NSString  stringWithCharacters: &uChar  length: 1];
      ukeys = [NSString  stringWithCharacters: &uChar  length: 1];
    }
  else
    {
      scan = ((lParam >> 16) & 0xFF);
      //NSLog(@"Got key code %d %d", scan, wParam);
      result = ToUnicode(wParam, scan, keyState, unicode, 5, 0);
      //NSLog(@"To Unicode resulted in %d with %d", result, unicode[0]);
      if (result == -1)
	{
	  // A non spacing accent key was found, we still try to use the result 
	  result = 1;
	}
      keys = [NSString  stringWithCharacters: unicode  length: result];
      // Now switch modifiers off
      keyState[VK_LCONTROL] = 0;
      keyState[VK_RCONTROL] = 0;
      keyState[VK_LMENU] = 0;
      keyState[VK_RMENU] = 0;
      result = ToUnicode(wParam, scan, keyState, unicode, 5, 0);
      //NSLog(@"To Unicode resulted in %d with %d", result, unicode[0]);
      if (result == -1)
	{
	  // A non spacing accent key was found, we still try to use the result 
	  result = 1;
	}
      ukeys = [NSString  stringWithCharacters: unicode  length: result];
    }

  event = [NSEvent keyEventWithType: eventType
		   location: eventLocation
		   modifierFlags: eventFlags
		   timestamp: time
		   windowNumber: (int)hwnd
		   context: gcontext
		   characters: keys
		   charactersIgnoringModifiers: ukeys
		   isARepeat: repeat
		   keyCode: wParam];

  return event;
}

static NSEvent*
process_mouse_event(HWND hwnd, WPARAM wParam, LPARAM lParam, 
		    NSEventType eventType)
{
  NSEvent *event;
  NSPoint eventLocation;
  unsigned int eventFlags;
  NSTimeInterval time;
  LONG ltime;
  DWORD tick;
  NSGraphicsContext *gcontext;
  short deltaY = 0;
  static int clickCount = 1;
  static LONG lastTime = 0;

  gcontext = GSCurrentContext();
  eventLocation = MSWindowPointToGS(hwnd,  GET_X_LPARAM(lParam), 
				    GET_Y_LPARAM(lParam));
  ltime = GetMessageTime();
  time = ltime / 1000;
  tick = GetTickCount();
  eventFlags = 0;
  if (wParam & MK_CONTROL)
    {
      eventFlags |= NSControlKeyMask;
    }
  if (wParam & MK_SHIFT)
    {
      eventFlags |= NSShiftKeyMask;
    }
  if (GetKeyState(VK_MENU) < 0) 
    {
      eventFlags |= NSAlternateKeyMask;
    }
  // What about other modifiers?

  if (eventType == NSScrollWheel)
    {
      deltaY = GET_WHEEL_DELTA_WPARAM(wParam) / 120;
      //NSLog(@"Scroll event with delat %d", deltaY);
    }
  else if (eventType == NSMouseMoved)
    {
      if (wParam & MK_LBUTTON)
	{
	  eventType = NSLeftMouseDragged;
	}
      else if (wParam & MK_RBUTTON)
	{
	  eventType = NSRightMouseDragged;
	}
      else if (wParam & MK_MBUTTON)
	{
	  eventType = NSOtherMouseDragged;
	}
    }
  else if ((eventType == NSLeftMouseDown) || 
	   (eventType == NSRightMouseDown) || 
	   (eventType == NSOtherMouseDown))
    {
      if (lastTime + GetDoubleClickTime() > ltime)
	{
	  clickCount += 1;
	}
      else 
	{
	  clickCount = 1;
	  lastTime = ltime;
	}
    }

  event = [NSEvent mouseEventWithType: eventType
		   location: eventLocation
		   modifierFlags: eventFlags
		   timestamp: time
		   windowNumber: (int)hwnd
		   context: gcontext
		   eventNumber: tick
		   clickCount: clickCount
		   pressure: 1.0
		   buttonNumber: 0 /* FIXME */
		   deltaX: 0.
		   deltaY: deltaY
		   deltaZ: 0.];

  return event;
}

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

LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg,
			     WPARAM wParam, LPARAM lParam)
{
  WIN32Server	*ctxt = (WIN32Server *)GSCurrentServer();

  return [ctxt windowEventProc: hwnd : uMsg : wParam : lParam];
}
