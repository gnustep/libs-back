/* WIN32Server - Implements window handling for MSWindows

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
#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSText.h>
#include <AppKit/DPSOperators.h>

#include "win32/WIN32Server.h"
#include "win32/WIN32Geometry.h"

static void 
validateWindow(HWND hwnd, RECT rect);
LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg,
			     WPARAM wParam, LPARAM lParam);

@implementation WIN32Server

/* Initialize AppKit backend */
+ (void)initializeBackend
{
  NSDebugLog(@"Initializing GNUstep win32 backend.\n");
  [GSDisplayServer setDefaultServerClass: [WIN32Server class]];
}

- (void) _initWin32Context
{
  WNDCLASSEX wc; 
  
  hinstance = (HINSTANCE)GetModuleHandle(NULL);

  // Register the main window class. 
  wc.cbSize = sizeof(wc);          
  //wc.style = CS_OWNDC; // | CS_HREDRAW | CS_VREDRAW; 
  wc.style = CS_HREDRAW | CS_VREDRAW; 
  wc.lpfnWndProc = (WNDPROC) MainWndProc; 
  wc.cbClsExtra = 0; 
  // Keep extra space for each window, for GS data
  wc.cbWndExtra = sizeof(WIN_INTERN); 
  wc.hInstance = hinstance; 
  wc.hIcon = NULL;
  wc.hCursor = NULL;
  wc.hbrBackground = GetStockObject(WHITE_BRUSH); 
  wc.lpszMenuName =  NULL; 
  wc.lpszClassName = "GNUstepWindowClass"; 
  wc.hIconSm = NULL;

  if (!RegisterClassEx(&wc)) 
       return; 

  // FIXME We should use GetSysColor to get standard colours from MS Window and 
  // use them in NSColor

  // Should we create a message only window here, so we can get events, even when
  // no windows are created?
}

- (void) setupRunLoopInputSourcesForMode: (NSString*)mode
{
  // FIXME
  NSTimer *timer;

  timer = [NSTimer timerWithTimeInterval: 0.1
		   target: self
		   selector: @selector(callback:)
		   userInfo: nil
		   repeats: YES];
  [[NSRunLoop currentRunLoop] addTimer: timer forMode: mode];
}

/**

*/
- (id) initWithAttributes: (NSDictionary *)info
{
  [self _initWin32Context];
  [super initWithAttributes: info];

  [self setupRunLoopInputSourcesForMode: NSDefaultRunLoopMode]; 
  [self setupRunLoopInputSourcesForMode: NSConnectionReplyMode]; 
  [self setupRunLoopInputSourcesForMode: NSModalPanelRunLoopMode]; 
  [self setupRunLoopInputSourcesForMode: NSEventTrackingRunLoopMode]; 
  return self;
}


- (void) _destroyWin32Context
{
  UnregisterClass("GNUstepWindowClass", hinstance);
}

/**

*/
- (void) dealloc
{
  [self _destroyWin32Context];
  [super dealloc];
}

/** Returns an instance of a class which implements the NSDraggingInfo
    protocol. */
- (id <NSDraggingInfo>) dragInfo
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) slideImage: (NSImage*)image from: (NSPoint)from to: (NSPoint)to
{
  [self subclassResponsibility: _cmd];
  return NO;
}

/* Screen information */
- (NSSize) resolutionForScreen: (int)screen
{
  int xres, yres;
  HDC hdc;

  hdc = GetDC(NULL);
  xres = GetDeviceCaps(hdc, LOGPIXELSX);
  yres = GetDeviceCaps(hdc, LOGPIXELSY);
  ReleaseDC(NULL, hdc);
  
  return NSMakeSize(xres, yres);
}

- (NSRect) boundsForScreen: (int)screen
{
  return NSMakeRect(0, 0, GetSystemMetrics(SM_CXSCREEN), 
		    GetSystemMetrics(SM_CYSCREEN));
}

- (NSWindowDepth) windowDepthForScreen: (int)screen
{
  HDC hdc;
  int bits;
  //int planes;
      
  hdc = GetDC(NULL);
  bits = GetDeviceCaps(hdc, BITSPIXEL) / 3;
  //planes = GetDeviceCaps(hdc, PLANES);
  //NSLog(@"bits %d planes %d", bits, planes);
  ReleaseDC(NULL, hdc);
  
  return (_GSRGBBitValue | bits);
}

- (const NSWindowDepth *) availableDepthsForScreen: (int)screen
{
  int		 ndepths = 1;
  NSZone	*defaultZone = NSDefaultMallocZone();
  NSWindowDepth	*depths = 0;

  depths = NSZoneMalloc(defaultZone, sizeof(NSWindowDepth)*(ndepths + 1));
  // FIXME
  depths[0] = [self windowDepthForScreen: screen];
  depths[1] = 0;

  return depths;
}

- (NSArray *) screenList
{
  return [NSArray arrayWithObject: [NSNumber numberWithInt: 0]];
}

/**
   Returns the handle of the module instance.  */
- (void *) serverDevice
{
  return hinstance;
}

/**
   As the number of the window is actually is handle we return this.  */
- (void *) windowDevice: (int)win
{
  return (void *)win;
}

@end

static inline
DWORD windowStyleForGSStyle(int style)
{
  DWORD wstyle = 0;

  if (style & NSTitledWindowMask)
    {
      wstyle |= WS_CAPTION;
    }
  if (style & NSClosableWindowMask)
    {
      wstyle |= WS_SYSMENU;
    }
  if (style & NSMiniaturizableWindowMask)
    {
      wstyle |= WS_MINIMIZEBOX;
    }
  if (style & NSResizableWindowMask)
    {
      wstyle |= WS_SIZEBOX;
    }

  if (wstyle)
    {
      wstyle |= WS_OVERLAPPED;
    }
  else
    {
      wstyle |= WS_POPUP;
    }
    
/*
  This does not work as NSBorderlessWindowMask is 0
  if (!(style & NSBorderlessWindowMask))
    {
      wstyle |= WS_BORDER;
    }
*/
  if (style & NSIconWindowMask)
    {
      wstyle = WS_ICONIC;
    }
  if (style & NSMiniWindowMask)
    {
      wstyle = WS_ICONIC;
    }

  //NSLog(@"Window wstyle %d for style %d", wstyle, style);
  return wstyle;
}

@implementation WIN32Server (WindowOps)

- (int) window: (NSRect)frame : (NSBackingStoreType)type : (unsigned int)style
	      : (int) screen
{
  HWND hwnd; 
  RECT r;
  DWORD wstyle = windowStyleForGSStyle(style);

  r = GSScreenRectToMS(frame);

  //NSLog(@"Creating at %d, %d, %d, %d", r.left, r.top, r.right - r.left, r.bottom - r.top);
  hwnd = CreateWindowEx(0,
			"GNUstepWindowClass",
			"GNUstepWindow",
			wstyle, 
			r.left, 
			r.top, 
			r.right - r.left, 
			r.bottom - r.top,
			(HWND) NULL,
			(HMENU) NULL,
			hinstance,
			(void*)type);
  //NSLog(@"Create Window %d", hwnd);

  [self _setWindowOwnedByServer: (int)hwnd];
  return (int)hwnd;
}

- (void) termwindow: (int) winNum
{
  DestroyWindow((HWND)winNum); 
}

- (void) stylewindow: (int)style : (int) winNum
{
  DWORD wstyle = windowStyleForGSStyle(style);

  //NSLog(@"Style Window %d style %d using %d", winNum, style, wstyle);
  SetWindowLong((HWND)winNum, GWL_STYLE, wstyle);
  //NSLog(@"Resulted in %d ", GetWindowLong((HWND)winNum, GWL_STYLE));
}

/** Changes window's the backing store to type */
- (void) windowbacking: (NSBackingStoreType)type : (int) winNum
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)winNum, GWL_USERDATA);

  if (win->useHDC)
    {
      DeleteDC(win->hdc);
      win->hdc = NULL;
    }

  if (type == NSBackingStoreBuffered)
    {
      HDC hdc, hdc2;
      HBITMAP hbitmap;
      HGDIOBJ old;
      RECT r;

      GetClientRect((HWND)winNum, &r);
      hdc = GetDC((HWND)winNum);
      hdc2 = CreateCompatibleDC(hdc);
      hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, r.bottom - r.top);
      old = SelectObject(hdc2, hbitmap);
      DeleteObject(old);

      win->hdc = hdc2;

      ReleaseDC((HWND)winNum, hdc);
    }
}

- (void) titlewindow: (NSString*)window_title : (int) winNum
{
  //NSLog(@"Settitle %@ for %d", window_title, winNum);
  SetWindowText((HWND)winNum, [window_title cString]);
}

- (void) miniwindow: (int) winNum
{
  ShowWindow((HWND)winNum, SW_MINIMIZE); 
}

/** Returns NO as we don't provide mini windows on MS Windows */ 
- (BOOL) appOwnsMiniwindow
{
  return NO;
}

- (void) windowdevice: (int) winNum
{
  NSGraphicsContext *ctxt;

  ctxt = GSCurrentContext();
  GSSetDevice(ctxt, (void*)winNum, 0, 0);
  DPSinitmatrix(ctxt);
  DPSinitclip(ctxt);
}

- (void) orderwindow: (int) op : (int) otherWin : (int) winNum
{
  if (op != NSWindowOut)
    {
      ShowWindow((HWND)winNum, SW_SHOW); 
    }

  switch (op)
    {
    case NSWindowOut:
      SetWindowPos((HWND)winNum, NULL, 0, 0, 0, 0, 
		   SWP_HIDEWINDOW | SWP_NOSIZE | SWP_NOMOVE | SWP_NOZORDER);
      break;
    case NSWindowBelow:
      if (otherWin == 0)
	otherWin = (int)HWND_BOTTOM;
      SetWindowPos((HWND)winNum, (HWND)otherWin, 0, 0, 0, 0, 
		   SWP_NOSIZE | SWP_NOMOVE);
      break;
    case NSWindowAbove:
      if (otherWin == 0)
	{
	  otherWin = winNum;
	  winNum = (int)HWND_TOP;
	}
      SetWindowPos((HWND) otherWin, (HWND)winNum, 0, 0, 0, 0, 
		   SWP_NOSIZE | SWP_NOMOVE);
      break;
    }
}

- (void) movewindow: (NSPoint)loc : (int)winNum
{
  POINT p;

  p = GSWindowOriginToMS((HWND)winNum, loc);

  SetWindowPos((HWND)winNum, NULL, p.x, p.y, 0, 0, 
	       SWP_NOZORDER | SWP_NOSIZE | SWP_NOREDRAW);
}

- (void) placewindow: (NSRect)frame : (int) winNum
{
  RECT r;

  r = GSScreenRectToMS(frame);

  //NSLog(@"Placing at %d, %d, %d, %d", r.left, r.top, r.right - r.left, r.bottom - r.top);
  SetWindowPos((HWND)winNum, NULL, r.left, r.top, r.right - r.left, r.bottom - r.top, 
	       SWP_NOZORDER | SWP_NOREDRAW);


}

- (BOOL) findwindow: (NSPoint)loc : (int) op : (int) otherWin 
		   : (NSPoint *)floc : (int*) winFound
{
  return NO;
}

- (NSRect) windowbounds: (int) winNum
{
  RECT r;

  GetWindowRect((HWND)winNum, &r);
  return MSScreenRectToGS(r);
}

- (void) setwindowlevel: (int) level : (int) winNum
{
}

- (int) windowlevel: (int) winNum
{
  return 0;
}

- (NSArray *) windowlist
{
  return nil;
}

- (int) windowdepth: (int) winNum
{
  return 0;
}

/** Set the maximum size of the window */
- (void) setmaxsize: (NSSize)size : (int) winNum
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)winNum, GWL_USERDATA);
  POINT p;

  p.x = size.width;
  p.y = size.height;
  win->minmax.ptMaxTrackSize = p;
}

/** Set the minimum size of the window */
- (void) setminsize: (NSSize)size : (int) winNum
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)winNum, GWL_USERDATA);
  POINT p;

  p.x = size.width;
  p.y = size.height;
  win->minmax.ptMinTrackSize = p;
}

/** Set the resize incremenet of the window */
- (void) setresizeincrements: (NSSize)size : (int) winNum
{
}

/** Causes buffered graphics to be flushed to the screen */
- (void) flushwindowrect: (NSRect)rect : (int) winNum
{
  RECT r = GSWindowRectToMS((HWND)winNum, rect);
  
  /*
  NSLog(@"Will validated window %d %@ (%d, %d, %d, %d)", winNum, 
	    NSStringFromRect(rect), r.left, r.top, r.right, r.bottom);
  */
  validateWindow((HWND)winNum, r);
}

- (void) styleoffsets: (float *) l : (float *) r : (float *) t : (float *) b
		     : (int) style 
{
  DWORD wstyle = windowStyleForGSStyle(style);
  RECT rect = {100, 100, 200, 200};
  
  AdjustWindowRectEx(&rect, wstyle, NO, 0);

  *l = 100 - rect.left;
  *r = rect.right - 200;
  *t = 100 - rect.top;
  *b = rect.bottom - 200;

  //NSLog(@"Sytle %d offset %f %f %f %f", wstyle, *l, *r, *t, *b);
}

- (void) docedited: (int) edited : (int) winNum
{
}

- (void) setinputstate: (int)state : (int)winNum
{
  if (state == GSTitleBarKey)
    {
      SetActiveWindow((HWND)winNum);
    }
}

/** Forces focus to the window so that all key events are sent to this
    window */
- (void) setinputfocus: (int) winNum
{
  if (winNum)
    SetFocus((HWND)winNum);
}

- (NSPoint) mouselocation
{
  POINT p;

  if (!GetCursorPos(&p))
    {  
      NSLog(@"GetCursorPos failed with %d", GetLastError());
      return NSZeroPoint;
    }

  return MSScreenPointToGS(p.x, p.y);
}

- (NSPoint) mouseLocationOnScreen: (int)screen window: (void *)win
{
  return [self mouselocation];
}

- (BOOL) capturemouse: (int) winNum
{
  SetCapture((HWND)winNum);
  return YES;
}

- (void) releasemouse
{
  ReleaseCapture();
}

- (void) hidecursor
{
  ShowCursor(NO);
}

- (void) showcursor
{
  ShowCursor(YES);
}

- (void) standardcursor: (int)style : (void **)cid
{
  HCURSOR hCursor;

  switch (style)
    {
    case GSArrowCursor:
      hCursor = LoadCursor(NULL, IDC_ARROW);
      break;
    case GSIBeamCursor:
      hCursor = LoadCursor(NULL, IDC_IBEAM);
      break;
    default:
      hCursor = LoadCursor(NULL, IDC_ARROW);
      break;
    }
  *cid = (void*)hCursor;
}

- (void) imagecursor: (NSPoint)hotp : (int) w :  (int) h 
		    : (int)colors : (const char *)image : (void **)cid
{
  /*
  HCURSOR cur;
  BYTE *and;
  BYTE *xor;

  xor = image;
  cur = CreateCursor(hinstance, (int)hotp.x, (int)hotp.y,  (int)w, (int)h, and, xor);
  *cid = (void*)hCursor;
  */
}

- (void) setcursorcolor: (NSColor *)fg : (NSColor *)bg : (void*) cid
{
  /* FIXME The colour is currently ignored
  if (fg != nil)
    {
      ICONINFO iconinfo;

      if (GetIconInfo((HCURSOR)cid, &iconinfo))
	{
	  iconinfo.hbmColor = ; 
	}
    }
  */

  SetCursor((HCURSOR)cid);
}

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

/*
 This standard windows marcors are missing in MinGW
 The definition here is almost correct, but will fail for multi monitor systems
*/
#ifndef GET_X_LPARAM
#define GET_X_LPARAM(p) LOWORD(p)
#endif
#ifndef GET_Y_LPARAM
#define GET_Y_LPARAM(p) HIWORD(p)
#endif

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
validateWindow(HWND hwnd, RECT rect)
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)hwnd, GWL_USERDATA);

  if (win->useHDC)
    {
      HDC hdc = GetDC((HWND)hwnd);
      WINBOOL result;

      /*
      NSLog(@"validated window %d %@", hwnd, 
	    NSStringFromRect(MSWindowRectToGS((HWND)hwnd, rect)));
      */
      result = BitBlt(hdc, rect.left, rect.top, 
		      (rect.right - rect.left), (rect.bottom - rect.top), 
		      win->hdc, rect.left, rect.top, SRCCOPY);
      if (!result)
	NSLog(@"validateWindow failed %d", GetLastError());
      ReleaseDC((HWND)hwnd, hdc);
    }
}

static void 
invalidateWindow(HWND hwnd, RECT rect)
{
  NSWindow *window = GSWindowWithNumber((int)hwnd);
  NSRect r = MSWindowRectToGS((HWND)hwnd, rect);

  /*
  NSLog(@"INvalidated window %d %@", hwnd, 
	NSStringFromRect(MSWindowRectToGS((HWND)hwnd, rect)));
  */
  // Repaint the window's client area. 
  [[window contentView] setNeedsDisplayInRect: r];
}

LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg,
			     WPARAM wParam, LPARAM lParam)
{ 
  NSEvent *ev = nil;
  
  /*
      {
	NSWindow *window = GSWindowWithNumber((int)hwnd);
	RECT r;
	NSRect rect;

	NSLog(@"%d Frame %@", hwnd, NSStringFromRect([window frame]));
	GetWindowRect(hwnd, &r);
	rect = MSScreenRectToGS(r);
	NSLog(@"%d Real frame %@", uMsg, NSStringFromRect(rect));
      }
  */
  switch (uMsg) 
    { 
    case WM_SETTEXT: 
      //NSLog(@"Got Message %s for %d", "SETTEXT", hwnd);
      break;
    case WM_NCCREATE: 
      //NSLog(@"Got Message %s for %d", "NCCREATE", hwnd);
      break;
    case WM_NCCALCSIZE: 
      //NSLog(@"Got Message %s for %d", "NCCALCSIZE", hwnd);
      break;
    case WM_NCACTIVATE: 
      //NSLog(@"Got Message %s for %d", "NCACTIVATE", hwnd);
      break;
    case WM_NCPAINT: 
      //NSLog(@"Got Message %s for %d", "NCPAINT", hwnd);
      break;
    case WM_NCHITTEST: 
      //NSLog(@"Got Message %s for %d", "NCHITTEST", hwnd);
      break;
    case WM_SHOWWINDOW: 
      //NSLog(@"Got Message %s for %d", "SHOWWINDOW", hwnd);
      break;
    case WM_NCMOUSEMOVE: 
      //NSLog(@"Got Message %s for %d", "NCMOUSEMOVE", hwnd);
      break;
    case WM_NCLBUTTONDOWN: 
      //NSLog(@"Got Message %s for %d", "NCLBUTTONDOWN", hwnd);
      break;
    case WM_NCLBUTTONUP: 
      //NSLog(@"Got Message %s for %d", "NCLBUTTONUP", hwnd);
      break;
    case WM_NCDESTROY: 
      //NSLog(@"Got Message %s for %d", "NCDESTROY", hwnd);
      break;
    case WM_GETTEXT: 
      //NSLog(@"Got Message %s for %d", "GETTEXT", hwnd);
      break;
    case WM_STYLECHANGING: 
      //NSLog(@"Got Message %s for %d", "STYLECHANGING", hwnd);
      break;
    case WM_STYLECHANGED: 
      //NSLog(@"Got Message %s for %d", "STYLECHANGED", hwnd);
      break;

    case WM_GETMINMAXINFO:
      {
	WIN_INTERN *win = (WIN_INTERN *)GetWindowLong(hwnd, GWL_USERDATA);
	MINMAXINFO *mm;

	//NSLog(@"Got Message %s for %d", "GETMINMAXINFO", hwnd);
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
	//NSLog(@"Got Message %s for %d", "CREATE", hwnd);
	/* For windows with backingstore we create a compatible DC, that 
	   is stored in the extra fields for this window. Drawing operations 
	   work on this buffer. */
	win = objc_malloc(sizeof(WIN_INTERN));
	SetWindowLong(hwnd, GWL_USERDATA, (int)win);
	
	if (type == NSBackingStoreBuffered)
	  {
	    HDC hdc, hdc2;
	    HBITMAP hbitmap;
	    RECT r;
	    HGDIOBJ old;

	    GetClientRect((HWND)hwnd, &r);
	    hdc = GetDC(hwnd);
	    hdc2 = CreateCompatibleDC(hdc);
	    hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, 
					     r.bottom - r.top);
	    old = SelectObject(hdc2, hbitmap);
	    DeleteObject(old);

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
      //NSLog(@"Got Message %s for %d", "WINDOWPOSCHANGING", hwnd);
      break;
    case WM_WINDOWPOSCHANGED: 
      //NSLog(@"Got Message %s for %d", "WINDOWPOSCHANGED", hwnd);
      break;
    case WM_MOVE: 
      {
	NSPoint eventLocation = NSMakePoint(0,0);
	int xPos = (int)(short) LOWORD(lParam);
	int yPos = (int)(short) HIWORD(lParam);
	NSPoint p;

	p = MSWindowOriginToGS(hwnd, xPos, yPos);
	//NSLog(@"Got Message %s for %d to %f, %f", "MOVE", hwnd, p.x, p.y);
	ev = [NSEvent otherEventWithType: NSAppKitDefined
		      location: eventLocation
		      modifierFlags: 0
		      timestamp: 0
		      windowNumber: (int)hwnd
		      context: GSCurrentContext()
		      subtype: GSAppKitWindowMoved
		      data1: p.x
		      data2: p.y];
	break;
      }
    case WM_MOVING: 
      //NSLog(@"Got Message %s for %d", "MOVING", hwnd);
      break;
    case WM_SIZE: 
      //NSLog(@"Got Message %s for %d", "SIZE", hwnd);
      break;
    case WM_SIZING: 
      //NSLog(@"Got Message %s for %d", "SIZING", hwnd);
      break;
    case WM_ENTERSIZEMOVE: 
      //NSLog(@"Got Message %s for %d", "ENTERSIZEMOVE", hwnd);
      break;
    case WM_EXITSIZEMOVE: 
      {
	NSPoint eventLocation;
	NSRect rect;
	RECT r;
	WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)hwnd, GWL_USERDATA);
	
	// FIXME: We should check if the size really did change. And this should 
	// be called on program size changes as well!
	if (win->useHDC)
	  {
	    HDC hdc, hdc2;
	    HBITMAP hbitmap;
	    HGDIOBJ old;

	    DeleteDC(win->hdc);
	    win->hdc = NULL;
	    
	    GetClientRect((HWND)hwnd, &r);
	    hdc = GetDC((HWND)hwnd);
	    hdc2 = CreateCompatibleDC(hdc);
	    hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, r.bottom - r.top);
	    old = SelectObject(hdc2, hbitmap);
	    DeleteObject(old);
	    //NSLog(@"Change backing store to %d %d", r.right - r.left, r.bottom - r.top);
	    win->hdc = hdc2;
	    
	    ReleaseDC((HWND)hwnd, hdc);
	  }

	GetWindowRect(hwnd, &r);
	rect = MSScreenRectToGS(r);
	eventLocation = rect.origin;
	//NSLog(@"Got Message %s for %d", "EXITSIZEMOVE", hwnd);
	ev = [NSEvent otherEventWithType: NSAppKitDefined
		      location: eventLocation
		      modifierFlags: 0
		      timestamp: 0
		      windowNumber: (int)hwnd
		      context: GSCurrentContext()
		      subtype: GSAppKitWindowResized
		      data1: rect.size.width
		      data2: rect.size.height];
	if (ev != nil)
	  {
	    [GSCurrentServer() postEvent: ev atStart: NO];
	  }
	ev = [NSEvent otherEventWithType: NSAppKitDefined
		      location: eventLocation
		      modifierFlags: 0
		      timestamp: 0
		      windowNumber: (int)hwnd
		      context: GSCurrentContext()
		      subtype: GSAppKitWindowMoved
		      data1: rect.origin.x
		      data2: rect.origin.y];
	if (ev != nil)
	  {
	    [GSCurrentServer() postEvent: ev atStart: NO];
	  }
	// Make sure DefWindowProc gets called
	ev = nil;
	break;
      }
    case WM_ACTIVATE: 
      //NSLog(@"Got Message %s for %d", "ACTIVATE", hwnd);
      break;
    case WM_ACTIVATEAPP: 
      //NSLog(@"Got Message %s for %d", "ACTIVATEAPP", hwnd);
      break;
    case WM_MOUSEACTIVATE: 
      //NSLog(@"Got Message %s for %d", "MOUSEACTIVATE", hwnd);
      break;
    case WM_SETFOCUS: 
      {
	NSPoint eventLocation = NSMakePoint(0,0);

	if (wParam == (int)hwnd)
	  return 0;
	//NSLog(@"Got Message %s for %d", "SETFOCUS", hwnd);
	ev = [NSEvent otherEventWithType:NSAppKitDefined
		      location: eventLocation
		      modifierFlags: 0
		      timestamp: 0
		      windowNumber: (int)hwnd
		      context: GSCurrentContext()
		      subtype: GSAppKitWindowFocusIn
		      data1: 0
		      data2: 0];
	break;
      }
    case WM_KILLFOCUS: 
      {
	NSPoint eventLocation = NSMakePoint(0,0);

	if (wParam == (int)hwnd)
	  return 0;
	//NSLog(@"Got Message %s for %d", "KILLFOCUS", hwnd);
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
      //NSLog(@"Got Message %s for %d", "SETCURSOR", hwnd);
      break;
    case WM_QUERYOPEN: 
      //NSLog(@"Got Message %s for %d", "QUERYOPEN", hwnd);
      break;
    case WM_CAPTURECHANGED: 
      //NSLog(@"Got Message %s for %d", "CAPTURECHANGED", hwnd);
      break;
      
    case WM_ERASEBKGND: 
      //NSLog(@"Got Message %s for %d", "ERASEBKGND", hwnd);
      //return 0;
      break;
    case WM_PAINT: 
      {
	RECT rect;

	if (GetUpdateRect(hwnd, &rect, NO))
	  {
	    invalidateWindow(hwnd, rect);
	    ValidateRect(hwnd, &rect);
	  }

	//NSLog(@"Got Message %s for %d", "PAINT", hwnd);
	return 0;
      }
    case WM_SYNCPAINT: 
      //NSLog(@"Got Message %s for %d", "SYNCPAINT", hwnd);
      break;
      
    case WM_CLOSE: 
      {
	NSPoint eventLocation = NSMakePoint(0,0);

	//NSLog(@"Got Message %s for %d", "CLOSE", hwnd);
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
	//NSLog(@"Got Message %s for %d", "DESTROY", hwnd);
	
	if (win->useHDC)
	  DeleteDC(win->hdc);
	objc_free(win);
	break;
      }
    case WM_KEYDOWN:
      //NSLog(@"Got Message %s for %d", "KEYDOWN", hwnd);
      ev = process_key_event(hwnd, wParam, lParam, NSKeyDown);
      break;
    case WM_KEYUP:
      //NSLog(@"Got Message %s for %d", "KEYUP", hwnd);
      ev = process_key_event(hwnd, wParam, lParam, NSKeyUp);
      break;

    case WM_MOUSEMOVE: 
      //NSLog(@"Got Message %s for %d", "MOUSEMOVE", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSMouseMoved);
      break;
    case WM_LBUTTONDOWN: 
      //NSLog(@"Got Message %s for %d", "LBUTTONDOWN", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSLeftMouseDown);
      break;
    case WM_LBUTTONUP: 
      //NSLog(@"Got Message %s for %d", "LBUTTONUP", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSLeftMouseUp);
      break;
    case WM_LBUTTONDBLCLK: 
      //NSLog(@"Got Message %s for %d", "LBUTTONDBLCLK", hwnd);
      break;
    case WM_MBUTTONDOWN: 
      //NSLog(@"Got Message %s for %d", "MBUTTONDOWN", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSOtherMouseDown);
      break;
    case WM_MBUTTONUP: 
      //NSLog(@"Got Message %s for %d", "MBUTTONUP", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSOtherMouseUp);
      break;
    case WM_MBUTTONDBLCLK: 
      //NSLog(@"Got Message %s for %d", "MBUTTONDBLCLK", hwnd);
      break;
    case WM_RBUTTONDOWN: 
      //NSLog(@"Got Message %s for %d", "RBUTTONDOWN", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSRightMouseDown);
      break;
    case WM_RBUTTONUP: 
      //NSLog(@"Got Message %s for %d", "RBUTTONUP", hwnd);
      ev = process_mouse_event(hwnd, wParam, lParam, NSRightMouseUp);
      break;
    case WM_RBUTTONDBLCLK: 
      //NSLog(@"Got Message %s for %d", "RBUTTONDBLCLK", hwnd);
      break;
    case WM_MOUSEWHEEL: 
      //NSLog(@"Got Message %s for %d", "MOUSEWHEEL", hwnd);
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
      //NSLog(@"Got Message %s for %d", "ENTERMENULOOP", hwnd);
      break;
    case WM_EXITMENULOOP:
      //NSLog(@"Got Message %s for %d", "EXITMENULOOP", hwnd);
      break;
    case WM_INITMENU:
      //NSLog(@"Got Message %s for %d", "INITMENU", hwnd);
      break;
    case WM_MENUSELECT:
      //NSLog(@"Got Message %s for %d", "MENUSELECT", hwnd);
      break;
    case WM_ENTERIDLE:
      //NSLog(@"Got Message %s for %d", "ENTERIDLE", hwnd);
      break;
 
    case WM_COMMAND:
      //NSLog(@"Got Message %s for %d", "COMMAND", hwnd);
      break;
    case WM_SYSKEYDOWN:
      //NSLog(@"Got Message %s for %d", "SYSKEYDOWN", hwnd);
      break;
    case WM_SYSKEYUP:
      //NSLog(@"Got Message %s for %d", "SYSKEYUP", hwnd);
      break;
    case WM_SYSCOMMAND:
      //NSLog(@"Got Message %s for %d", "SYSCOMMAND", hwnd);
      break;
    case WM_HELP:
      //NSLog(@"Got Message %s for %d", "HELP", hwnd);
      break;
    case WM_POWERBROADCAST:
      //NSLog(@"Got Message %s for %d", "POWERBROADCAST", hwnd);
      break;
    case WM_TIMECHANGE:
      //NSLog(@"Got Message %s for %d", "TIMECHANGE", hwnd);
      break;
    case WM_DEVICECHANGE:
      NSLog(@"Got Message %s for %d", "DEVICECHANGE", hwnd);
      break;
    case WM_GETICON:
      NSLog(@"Got Message %s for %d", "GETICON", hwnd);
      break;

    default: 
      // Process all other messages. 
      NSLog(@"Got Message %d for %d", uMsg, hwnd);
      break;
    } 

  if (ev != nil)
    {
      //NSLog(@"Send event %@", ev);
      [GSCurrentServer() postEvent: ev atStart: NO];
      return 0;
    }

  return DefWindowProc(hwnd, uMsg, wParam, lParam); 
}
