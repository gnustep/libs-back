/* WIN32Server - Implements window handling for MSWindows

   Copyright (C) 2002, 2005 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Date: March 2002
   Part of this code have been re-written by: 
   Tom MacSween <macsweent@sympatico.ca>
   Date August 2005

   This file is part of the GNU Objective C User Interface Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#include "config.h"
#include <Foundation/NSDebug.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSConnection.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSException.h>
#include <AppKit/AppKitExceptions.h>
#include <AppKit/NSApplication.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSMenu.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSText.h>
#include <AppKit/NSTextField.h>
#include <AppKit/DPSOperators.h>

#include "win32/WIN32Server.h"
#include "win32/WIN32Geometry.h"
#ifdef HAVE_WGL
#include "win32/WIN32OpenGL.h"
#endif 

#ifdef __CYGWIN__
#include <sys/file.h>
#endif

static NSEvent *process_key_event(WIN32Server *svr, 
                                  HWND hwnd, WPARAM wParam, 
                                  LPARAM lParam, NSEventType eventType);
static NSEvent *process_mouse_event(WIN32Server *svr, 
                                    HWND hwnd, WPARAM wParam, 
                                    LPARAM lParam, NSEventType eventType);

LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg, 
                             WPARAM wParam, LPARAM lParam);

@implementation WIN32Server

- (BOOL) handlesWindowDecorations
{
  return handlesWindowDecorations;
}

- (void) setHandlesWindowDecorations: (BOOL) b
{
  handlesWindowDecorations = b;
}

- (BOOL) usesNativeTaskbar
{
  return usesNativeTaskbar;
}

- (void) setUsesNativeTaskbar: (BOOL) b
{
  usesNativeTaskbar = b;
}

- (void) callback: (id)sender
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
          // Don't translate messages, as this would give
          // extra character messages.
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
#ifdef    __CYGWIN__
  if (type == ET_RDESC)
#else 
  if (type == ET_WINMSG)
#endif
    {
      MSG	*m = (MSG*)extra;

      if (m->message == WM_QUIT)
        {
          [NSApp terminate: nil];
          // Exit the program
          return;
        }
      else
        {
          DispatchMessage(m); 
        } 
    } 
  if (mode != nil)
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


// server 

/* Initialize AppKit backend */
+ (void) initializeBackend
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
  wc.hIcon = NULL;//currentAppIcon;
  wc.hCursor = LoadCursor(NULL, IDC_ARROW);
  wc.hbrBackground = GetStockObject(WHITE_BRUSH); 
  wc.lpszMenuName =  NULL; 
  wc.lpszClassName = "GNUstepWindowClass"; 
  wc.hIconSm = NULL;//currentAppIcon;

  if (!RegisterClassEx(&wc)) 
       return; 

  // FIXME We should use GetSysColor to get standard colours from MS Window and 
  // use them in NSColor

  // Should we create a message only window here, so we can get events, even when
  // no windows are created?
}

- (void) setupRunLoopInputSourcesForMode: (NSString*)mode
{
  NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];

#ifdef    __CYGWIN__
  int fdMessageQueue;
#define WIN_MSG_QUEUE_FNAME    "/dev/windows"

  // Open a file descriptor for the windows message queue
  fdMessageQueue = open (WIN_MSG_QUEUE_FNAME, O_RDONLY);
  if (fdMessageQueue == -1)
    {
      NSLog(@"Failed opening %s\n", WIN_MSG_QUEUE_FNAME);
      exit(1);
    }
  [currentRunLoop addEvent: (void*)fdMessageQueue
                  type: ET_RDESC
                  watcher: (id<RunLoopEvents>)self
                  forMode: mode];
#else 
  [currentRunLoop addEvent: (void*)0
                  type: ET_WINMSG
                  watcher: (id<RunLoopEvents>)self
                  forMode: mode];
#endif
}

/**

*/
- (id) initWithAttributes: (NSDictionary *)info
{
//  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

  self = [super initWithAttributes: info];

  if(self)
  {
    [self _initWin32Context];
    [super initWithAttributes: info];

    [self setupRunLoopInputSourcesForMode: NSDefaultRunLoopMode]; 
    [self setupRunLoopInputSourcesForMode: NSConnectionReplyMode]; 
    [self setupRunLoopInputSourcesForMode: NSModalPanelRunLoopMode]; 
    [self setupRunLoopInputSourcesForMode: NSEventTrackingRunLoopMode]; 

    [self setHandlesWindowDecorations: NO];
    [self setUsesNativeTaskbar: YES];

    { // Check user defaults
      NSUserDefaults	*defs;
      defs = [NSUserDefaults standardUserDefaults];
 
      if ([defs objectForKey: @"GSUseWMStyles"])
        {
          NSWarnLog(@"Usage of 'GSUseWMStyles' as user default option is deprecated. "
                    @"This option will be ignored in future versions. "
                    @"You should use 'GSBackHandlesWindowDecorations' option.");
          [self setHandlesWindowDecorations: ![defs boolForKey: @"GSUseWMStyles"]];
        }
      if ([defs objectForKey: @"GSUsesWMTaskbar"])
        {
          NSWarnLog(@"Usage of 'GSUseWMTaskbar' as user default option is deprecated. "
                    @"This option will be ignored in future versions. "
                    @"You should use 'GSBackUsesNativeTaskbar' option.");
          [self setUsesNativeTaskbar: [defs boolForKey: @"GSUseWMTaskbar"]];
        }

      if ([defs objectForKey: @"GSBackHandlesWindowDecorations"])
        {
          [self setHandlesWindowDecorations: [defs boolForKey: @"GSBackHandlesWindowDecorations"]];
        } 
      if ([defs objectForKey: @"GSBackUsesNativeTaskbar"])
        {
          [self setUsesNativeTaskbar: [defs boolForKey: @"GSUseNativeTaskbar"]];
        }
    }
  }
  return self;
}

- (void) _destroyWin32Context
{
  UnregisterClass("GNUstepWindowClass", hinstance);
}

- (void) dealloc
{
  [self _destroyWin32Context];
  [super dealloc];
}

- (void) restrictWindow: (int)win toImage: (NSImage*)image
{
  //TODO [self subclassResponsibility: _cmd];
}

- (int) findWindowAt: (NSPoint)screenLocation 
           windowRef: (int*)windowRef 
           excluding: (int)win
{
  HWND hwnd;
  POINT p;

  p = GSScreenPointToMS(screenLocation);
  hwnd = WindowFromPoint(p);
  if ((int)hwnd == win)
    {
      /*
       * If the window at the point we want is excluded, 
       * we must look through ALL windows at a lower level
       * until we find one which contains the same point.
       */
      while (hwnd != 0)
        {
          RECT	r;

          hwnd = GetWindow(hwnd, GW_HWNDNEXT);
          GetWindowRect(hwnd, &r);
          if (PtInRect(&r, p) && IsWindowVisible(hwnd))
            {
              break;
            }
        }
    }

  *windowRef = (int)hwnd;	// Any windows

  return (int)hwnd;
}

// FIXME: The following methods wont work for multiple screens
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

- (void) beep
{
  Beep(400, 500);
}  

- (void) resizeBackingStoreFor: (HWND)hwnd
{
  [self subclassResponsibility: _cmd];
}

- (BOOL) displayEvent: (unsigned int)uMsg;   // diagnotic filter
{
  [self subclassResponsibility: _cmd];
  return YES;
}

// main event loop

/*
 * Reset all of our flags before the next run through the event switch
 *
 */
- (void) setFlagsforEventLoop: (HWND)hwnd
{
  flags._eventHandled = NO;

  flags._is_menu = NO;
  if ((HWND)flags.menuRef == hwnd && flags.HAVE_MAIN_MENU == YES)
    flags._is_menu = YES;
  // note some cache windows are needed..... just get the zeros 
  flags._is_cache = [[EVENT_WINDOW(hwnd) className] isEqual: @"GSCacheW"];
  
  flags._hasGSClassName = NO;
  if ([EVENT_WINDOW(hwnd) className] != nil)
    flags._hasGSClassName = YES;
    
  // future house keeping can go here

}

- (LRESULT) windowEventProc: (HWND)hwnd : (UINT)uMsg 
		       : (WPARAM)wParam : (LPARAM)lParam
{ 
  NSEvent *ev = nil;

  [self setFlagsforEventLoop: hwnd];
 
  switch (uMsg) 
    { 
      case WM_SIZING: 
        [self decodeWM_SIZINGParams: hwnd : wParam : lParam];
      case WM_NCCREATE: 
        return [self decodeWM_NCCREATEParams: wParam : lParam : hwnd];
        break;
      case WM_NCCALCSIZE: 
        [self decodeWM_NCCALCSIZEParams: wParam : lParam : hwnd]; 
        break;
      case WM_NCACTIVATE: 
        [self decodeWM_NCACTIVATEParams: wParam : lParam : hwnd]; 
        break;
      case WM_NCPAINT: 
        if ([self handlesWindowDecorations])
          [self decodeWM_NCPAINTParams: wParam : lParam : hwnd]; 
        break;
     //case WM_SHOWWINDOW: 
      //[self decodeWM_SHOWWINDOWParams: wParam : lParam : hwnd]; 
      //break;
      case WM_NCDESTROY: 
        [self decodeWM_NCDESTROYParams: wParam : lParam : hwnd]; 
        break;
      case WM_GETTEXT: 
        [self decodeWM_GETTEXTParams: wParam : lParam : hwnd]; 
        break;
      case WM_STYLECHANGING: 
        break;
      case WM_STYLECHANGED: 
        break;
      case WM_GETMINMAXINFO: 
        return [self decodeWM_GETMINMAXINFOParams: wParam : lParam : hwnd];
        break;
      case WM_CREATE: 
        return [self decodeWM_CREATEParams: wParam : lParam : hwnd];
        break;
      case WM_WINDOWPOSCHANGING: 
        [self decodeWM_WINDOWPOSCHANGINGParams: wParam : lParam : hwnd]; 
        break;
      case WM_WINDOWPOSCHANGED: 
        [self decodeWM_WINDOWPOSCHANGEDParams: wParam : lParam : hwnd]; 
        break;
      case WM_MOVE: 
        return [self decodeWM_MOVEParams: hwnd : wParam : lParam];
        break;
      case WM_MOVING: 
        return [self decodeWM_MOVINGParams: hwnd : wParam : lParam];
        break;
      case WM_SIZE: 
        return [self decodeWM_SIZEParams: hwnd : wParam : lParam];
        break;
      case WM_ENTERSIZEMOVE: 
        break;
      case WM_EXITSIZEMOVE: 
        //return [self decodeWM_EXITSIZEMOVEParams: wParam : lParam : hwnd];
        return DefWindowProc(hwnd, uMsg, wParam, lParam); 
        break; 
      case WM_ACTIVATE: 
        if ((int)lParam !=0)
          [self decodeWM_ACTIVEParams: wParam : lParam : hwnd]; 
        break;
      case WM_ACTIVATEAPP: 
        return [self decodeWM_ACTIVEAPPParams: hwnd : wParam : lParam];
        break;
      case WM_SETFOCUS: 
        return [self decodeWM_SETFOCUSParams: wParam : lParam : hwnd]; 
        break;
      case WM_KILLFOCUS: 
        if (wParam == (int)hwnd)
          return 0;
        else
          [self decodeWM_KILLFOCUSParams: wParam : lParam : hwnd]; 
        break;
      case WM_SETCURSOR: 
        break;
      case WM_QUERYOPEN: 
        [self decodeWM_QUERYOPENParams: wParam : lParam : hwnd]; 
        break;
      case WM_CAPTURECHANGED: 
        [self decodeWM_CAPTURECHANGEDParams: wParam : lParam : hwnd]; 
        break;
      case WM_ERASEBKGND: 
        return [self decodeWM_ERASEBKGNDParams: wParam : lParam : hwnd];
        break;
      case WM_PAINT: 
        [self decodeWM_PAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd]; 
        break;
      case WM_SYNCPAINT: 
        if ([self handlesWindowDecorations])
          [self decodeWM_SYNCPAINTParams: wParam : lParam : hwnd]; 
        break;
      case WM_CLOSE: 
        [self decodeWM_CLOSEParams: wParam : lParam : hwnd]; 
        break;
      case WM_DESTROY: 
        [self decodeWM_DESTROYParams: wParam : lParam : hwnd];
        break;
      case WM_QUIT: 
        break;
      case WM_USER: 
        break;
      case WM_APP: 
        break;  
      case WM_ENTERMENULOOP: 
        break;
      case WM_EXITMENULOOP: 
        break;
      case WM_INITMENU: 
        break;
      case WM_MENUSELECT: 
        break;
      case WM_ENTERIDLE: 
        break;
      case WM_COMMAND: 
        [self decodeWM_COMMANDParams: wParam : lParam : hwnd];
        break;
      case WM_SYSKEYDOWN: 
        break;
      case WM_SYSKEYUP: 
        break;
      case WM_SYSCOMMAND: 
        [self decodeWM_SYSCOMMANDParams: wParam : lParam : hwnd];
        break;
      case WM_HELP: 
        break;
      //case WM_GETICON: 
        //return [self decodeWM_GETICONParams: wParam : lParam : hwnd];
        //break;
      //case WM_SETICON: 
        //return [self decodeWM_SETICONParams: wParam : lParam : hwnd];
        //break;
      case WM_CANCELMODE:
        break;
      case WM_ENABLE: 
      case WM_CHILDACTIVATE: 
        break;
      case WM_NULL: 
        break; 
	
      case WM_NCHITTEST: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCHITTEST", hwnd);
        break;
      case WM_NCMOUSEMOVE: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCMOUSEMOVE", hwnd);
        break;
      case WM_NCLBUTTONDOWN:  //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCLBUTTONDOWN", hwnd);
        break;
      case WM_NCLBUTTONUP: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "NCLBUTTONUP", hwnd);
        break;
      case WM_MOUSEACTIVATE: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOUSEACTIVATE", hwnd);
        break;
      case WM_MOUSEMOVE: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOUSEMOVE", hwnd);
        ev = process_mouse_event(self, hwnd, wParam, lParam, NSMouseMoved);
        break;
      case WM_LBUTTONDOWN: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "LBUTTONDOWN", hwnd);
        //[self decodeWM_LBUTTONDOWNParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd];
        ev = process_mouse_event(self, hwnd, wParam, lParam, NSLeftMouseDown);
        break;
      case WM_LBUTTONUP: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "LBUTTONUP", hwnd);
        ev = process_mouse_event(self, hwnd, wParam, lParam, NSLeftMouseUp);
        break;
      case WM_LBUTTONDBLCLK: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "LBUTTONDBLCLK", hwnd);
        break;
      case WM_MBUTTONDOWN: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MBUTTONDOWN", hwnd);
        ev = process_mouse_event(self, hwnd, wParam, lParam, NSOtherMouseDown);
        break;
      case WM_MBUTTONUP: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MBUTTONUP", hwnd);
        ev = process_mouse_event(self, hwnd, wParam, lParam, NSOtherMouseUp);
        break;
      case WM_MBUTTONDBLCLK: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MBUTTONDBLCLK", hwnd);
        break;
      case WM_RBUTTONDOWN: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "RBUTTONDOWN", hwnd);
        ev = process_mouse_event(self, hwnd, wParam, lParam, NSRightMouseDown);
        break;
      case WM_RBUTTONUP: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "RBUTTONUP", hwnd);
        ev = process_mouse_event(self, hwnd, wParam, lParam, NSRightMouseUp);
        break;
      case WM_RBUTTONDBLCLK: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "RBUTTONDBLCLK", hwnd);
        break;
      case WM_MOUSEWHEEL: //MOUSE
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "MOUSEWHEEL", hwnd);
        ev = process_mouse_event(self, hwnd, wParam, lParam, NSScrollWheel);
        break;
	
      case WM_KEYDOWN:  //KEYBOARD
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "KEYDOWN", hwnd);
        ev = process_key_event(self, hwnd, wParam, lParam, NSKeyDown);
        break;
      case WM_KEYUP:  //KEYBOARD
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "KEYUP", hwnd);
        ev = process_key_event(self, hwnd, wParam, lParam, NSKeyUp);
        break;

      case WM_POWERBROADCAST: //SYSTEM
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "POWERBROADCAST", hwnd);
        break;
      case WM_TIMECHANGE:  //SYSTEM
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "TIMECHANGE", hwnd);
        break;
      case WM_DEVICECHANGE: //SYSTEM
        NSDebugLLog(@"NSEvent", @"Got Message %s for %d", "DEVICECHANGE", hwnd);
        break;
	
      default: 
        // Process all other messages.
          NSDebugLLog(@"NSEvent", @"Got unhandled Message %d for %d", uMsg, hwnd);
          break;
    } 
    
    /*
     * see if the event was handled in the the main loop or in the
     * menu loop.  if eventHandled = YES then we are done and need to
     * tell the windows event handler we are finished 
     */
  if (flags._eventHandled == YES)
    return 0;
  
  if (ev != nil)
    {		
      [GSCurrentServer() postEvent: ev atStart: NO];
      return 0;
    }

  /*
   * We did not care about the event, return it back to the windows
   * event handler 
   */
  return DefWindowProc(hwnd, uMsg, wParam, lParam); 
}

- glContextClass
{
#ifdef HAVE_WGL
  return [Win32GLContext class];
#else
  return nil;
#endif
}

- glPixelFormatClass
{
#ifdef HAVE_WGL
  return [Win32GLPixelFormat class];
#else
  return nil;
#endif
}

@end



@implementation WIN32Server (WindowOps)

/*
  styles are mapped between the two systems 

    NSUtilityWindowMask         16
    NSDocModalWindowMask        32
    NSBorderlessWindowMask      0
    NSTitledWindowMask          1
    NSClosableWindowMask        2
    NSMiniaturizableWindowMask  4
    NSResizableWindowMask       8
    NSIconWindowMask            64
    NSMiniWindowMask            128

  NSMenu(style) =  NSTitledWindowMask | NSClosableWindowMask =3;
*/
- (DWORD) windowStyleForGSStyle: (unsigned int) style
{
  DWORD wstyle = 0;
        
  if ([self handlesWindowDecorations] == NO)
    return WS_POPUP;
        
  switch (style)
    {
      case 0:
         wstyle = WS_POPUP;
         break;
      case NSTitledWindowMask: // 1
         wstyle = WS_CAPTION;
         break;
      case NSClosableWindowMask: // 2
         wstyle = WS_CAPTION+WS_SYSMENU;
         break;
      case NSMiniaturizableWindowMask: //4
         wstyle = WS_MINIMIZEBOX+WS_SYSMENU;
         break;
      case NSResizableWindowMask: // 8
         wstyle = WS_SIZEBOX;
      case NSMiniWindowMask: //128
      case NSIconWindowMask: // 64
         wstyle = WS_ICONIC; 
         break;
      //case NSUtilityWindowMask: //16
      //case NSDocModalWindowMask: //32
         break;
      // combinations
      case NSTitledWindowMask+NSClosableWindowMask: //3
         wstyle = WS_CAPTION+WS_SYSMENU;
         break;
      case NSTitledWindowMask+NSClosableWindowMask+NSMiniaturizableWindowMask: //7
         wstyle = WS_CAPTION+WS_MINIMIZEBOX+WS_SYSMENU;
         break;
      case NSTitledWindowMask+NSResizableWindowMask: // 9
         wstyle = WS_CAPTION+WS_SIZEBOX;
         break;
      case NSTitledWindowMask+NSClosableWindowMask+NSResizableWindowMask: // 11
         wstyle = WS_CAPTION+WS_SIZEBOX+WS_SYSMENU;
         break;
      case NSTitledWindowMask+NSResizableWindowMask+NSMiniaturizableWindowMask: //13
         wstyle = WS_SIZEBOX+WS_MINIMIZEBOX+WS_SYSMENU+WS_CAPTION;
         break;   
      case NSTitledWindowMask+NSClosableWindowMask+NSResizableWindowMask+
                                                NSMiniaturizableWindowMask: //15
         wstyle = WS_CAPTION+WS_SIZEBOX+WS_MINIMIZEBOX+WS_SYSMENU;
         break;
        
      default:
         wstyle = WS_POPUP; //WS_CAPTION+WS_SYSMENU;
         break;
   }

   //NSLog(@"Window wstyle %d for style %d", wstyle, style);
   return wstyle;
}


- (void) resetForGSWindowStyle:(HWND)hwnd w32Style:(DWORD)aStyle
{
  // to be completed for styles
  LONG result;

  ShowWindow(hwnd, SW_HIDE);
  SetLastError(0);
  result = SetWindowLong(hwnd, GWL_EXSTYLE, WS_EX_APPWINDOW);
  result = SetWindowLong(hwnd, GWL_STYLE, (LONG)aStyle);
  // should check error here...
  ShowWindow(hwnd, SW_SHOWNORMAL);
}

/*
  styleMask specifies the receiver's style. It can either be
  NSBorderlessWindowMask, or it can contain any of the following
  options, combined using the C bitwise OR operator: Option Meaning

    NSTitledWindowMask          The NSWindow displays a title bar.
    NSClosableWindowMask        The NSWindow displays a close button.
    NSMiniaturizableWindowMask  The NSWindow displays a miniaturize button. 
    NSResizableWindowMask       The NSWindow displays a resize bar or border.
    NSBorderlessWindowMask
    
    NSUtilityWindowMask         16
    NSDocModalWindowMask        32
    NSBorderlessWindowMask      0
    NSTitledWindowMask          1
    NSClosableWindowMask        2
    NSMiniaturizableWindowMask  4
    NSResizableWindowMask       8
    NSIconWindowMask            64
    NSMiniWindowMask            128

  Borderless windows display none of the usual peripheral elements and
  are generally useful only for display or caching purposes; you
  should normally not need to create them. Also, note that an
  NSWindow's style mask should include NSTitledWindowMask if it
  includes any of the others.

  backingType specifies how the drawing done in the receiver is
  buffered by the object's window device: NSBackingStoreBuffered
  NSBackingStoreRetained NSBackingStoreNonretained


  flag determines whether the Window Server creates a window device
  for the new object immediately. If flag is YES, it defers creating
  the window until the receiver is moved on screen. All display
  messages sent to the NSWindow or its NSViews are postponed until the
  window is created, just before it's moved on screen.  Deferring the
  creation of the window improves launch time and minimizes the
  virtual memory load on the Window Server.  The new NSWindow creates
  an instance of NSView to be its default content view.  You can
  replace it with your own object by using the setContentView: method.

*/

- (int) window: (NSRect)frame : (NSBackingStoreType)type : (unsigned int)style
              : (int) screen
{
  HWND hwnd; 
  RECT r;
  DWORD wstyle;
  DWORD estyle;

  flags.currentGS_Style = style;
    
  wstyle = [self windowStyleForGSStyle: style] | WS_CLIPCHILDREN;

  if ((style & NSMiniaturizableWindowMask) == NSMiniaturizableWindowMask)
    {
      if ([self usesNativeTaskbar])
        estyle = WS_EX_APPWINDOW;
      else
          estyle = WS_EX_TOOLWINDOW;
    }
  else
    {
      estyle = WS_EX_TOOLWINDOW;
    } 

  r = GSScreenRectToMS(frame, style, self);

  /* 
   * from here down is reused and unmodified from WIN32EventServer.m 
   * which has been removed form the subproject 
   */
  NSDebugLLog(@"WTrace", @"window: %@ : %d : %d : %d", NSStringFromRect(frame), 
              type, style, screen);
  NSDebugLLog(@"WTrace", @"         device frame: %d, %d, %d, %d", 
              r.left, r.top, r.right - r.left, r.bottom - r.top);
  hwnd = CreateWindowEx(estyle, 
                        "GNUstepWindowClass", 
                        "GNUstepWindow", 
                        wstyle, 
                        r.left, 
                        r.top, 
                        r.right - r.left, 
                        r.bottom - r.top, 
                        (HWND)NULL, 
                        (HMENU)NULL, 
                        hinstance, 
                        (void*)type);
  NSDebugLLog(@"WTrace", @"         num/handle: %d", hwnd);

  [self _setWindowOwnedByServer: (int)hwnd];
  return (int)hwnd;
}

- (void) termwindow: (int) winNum
{
  NSDebugLLog(@"WTrace", @"termwindow: %d", winNum);
  DestroyWindow((HWND)winNum); 
}

- (void) stylewindow: (unsigned int)style : (int) winNum
{
  DWORD wstyle = [self windowStyleForGSStyle: style];

  NSAssert([self handlesWindowDecorations], 
	   @"-stylewindow: : called when [self handlesWindowDecorations] == NO");

  NSDebugLLog(@"WTrace", @"stylewindow: %d : %d", style, winNum);
  SetWindowLong((HWND)winNum, GWL_STYLE, wstyle);
}

- (void) setbackgroundcolor: (NSColor *)color : (int)win
{
}

/** Changes window's the backing store to type */
- (void) windowbacking: (NSBackingStoreType)type : (int) winNum
{
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)winNum, GWL_USERDATA);

  NSDebugLLog(@"WTrace", @"windowbacking: %d : %d", type, winNum);
  if (win->useHDC)
    {
      HGDIOBJ old;

      old = SelectObject(win->hdc, win->old);
      DeleteObject(old);
      DeleteDC(win->hdc);
      win->hdc = NULL;
      win->old = NULL;
      win->useHDC = NO;
    }

  if (type != NSBackingStoreNonretained)
    {
      HDC hdc, hdc2;
      HBITMAP hbitmap;
      RECT r;

      GetClientRect((HWND)winNum, &r);
      hdc = GetDC((HWND)winNum);
      hdc2 = CreateCompatibleDC(hdc);
      hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, r.bottom - r.top);
      win->old = SelectObject(hdc2, hbitmap);
      win->hdc = hdc2;
      win->useHDC = YES;
      win->backingStoreEmpty = YES;

      ReleaseDC((HWND)winNum, hdc);
    }
  else
    {
      win->useHDC = NO;
      win->hdc = NULL;
    }
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
      hdc = GetDC((HWND)hwnd);
      hdc2 = CreateCompatibleDC(hdc);
      hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, r.bottom - r.top);
      win->old = SelectObject(hdc2, hbitmap);
      win->hdc = hdc2;
      
      ReleaseDC((HWND)hwnd, hdc);

      // After resizing the backing store, we need to redraw the window
      win->backingStoreEmpty = YES;
    }
}

- (void) titlewindow: (NSString*)window_title : (int) winNum
{
  NSDebugLLog(@"WTrace", @"titlewindow: %@ : %d", window_title, winNum);
  SetWindowTextW((HWND)winNum, (const unichar*)
    [window_title cStringUsingEncoding: NSUnicodeStringEncoding]);
}

- (void) miniwindow: (int) winNum
{
  NSDebugLLog(@"WTrace", @"miniwindow: %d", winNum);
  ShowWindow((HWND)winNum, SW_MINIMIZE); 
}

/** Returns NO as we don't provide mini windows on MS Windows */ 
- (BOOL) appOwnsMiniwindow
{
  return NO;
}

- (void) setWindowdevice: (int)winNum forContext: (NSGraphicsContext *)ctxt
{
  RECT rect;
  float h, l, r, t, b;
  NSWindow *window;

  NSDebugLLog(@"WTrace", @"windowdevice: %d", winNum);
  window = GSWindowWithNumber(winNum);
  GetClientRect((HWND)winNum, &rect);
  h = rect.bottom - rect.top;
  [self styleoffsets: &l : &r : &t : &b : [window styleMask]];
  GSSetDevice(ctxt, (void*)winNum, l, h + b);
  DPSinitmatrix(ctxt);
  DPSinitclip(ctxt);
}

- (void) orderwindow: (int) op : (int) otherWin : (int) winNum
{
  NSDebugLLog(@"WTrace", @"orderwindow: %d : %d : %d", op, otherWin, winNum);

  if ([self usesNativeTaskbar])
    {
      /* When using this policy, we make these changes: 
         - don't show the application icon window
         - Never order out the main menu, just minimize it, so that
         when the user clicks on it in the taskbar it will activate the
         application.
      */
      int special;
      special = [[NSApp iconWindow] windowNumber];
      if (winNum == special)
        {
          return;
        }
      special = [[[NSApp mainMenu] window] windowNumber];
      if (winNum == special && op == NSWindowOut)
        {
          ShowWindow((HWND)winNum, SW_MINIMIZE); 
          return;
        }
    }

  if (op != NSWindowOut)
    {
      int flag = SW_SHOW;

      if (IsIconic((HWND)winNum))
        flag = SW_RESTORE;
      ShowWindow((HWND)winNum, flag); 
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
                     SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
        break;
      case NSWindowAbove: 
        if (otherWin <= 0)
          {
            /* FIXME: Need to find the current key window (otherWin == 0
               means keep the window below the current key.)  */
            otherWin = winNum;
            winNum = (int)HWND_TOP;
          }
        SetWindowPos((HWND) otherWin, (HWND)winNum, 0, 0, 0, 0, 
                     SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE);
        break;
    }
}

- (void) movewindow: (NSPoint)loc : (int)winNum
{
  POINT p;

  NSDebugLLog(@"WTrace", @"movewindow: %@ : %d", NSStringFromPoint(loc), 
	      winNum);
  p = GSWindowOriginToMS((HWND)winNum, loc);

  SetWindowPos((HWND)winNum, NULL, p.x, p.y, 0, 0, 
               SWP_NOZORDER | SWP_NOSIZE);
}

- (void) placewindow: (NSRect)frame : (int) winNum
{
  RECT r;
  RECT r2;
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong((HWND)winNum, GWL_USERDATA);
  NSWindow *window = GSWindowWithNumber(winNum);

  NSDebugLLog(@"WTrace", @"placewindow: %@ : %d", NSStringFromRect(frame), 
              winNum);
  r = GSScreenRectToMS(frame, [window styleMask], self);
  GetWindowRect((HWND)winNum, &r2);

  SetWindowPos((HWND)winNum, NULL, 
    r.left, r.top, r.right - r.left, r.bottom - r.top, SWP_NOZORDER); 

  if ((win->useHDC)
      && (r.right - r.left != r2.right - r2.left)
      && (r.bottom - r.top != r2.bottom - r2.top))
    {
      HDC hdc, hdc2;
      HBITMAP hbitmap;
      HGDIOBJ old;
      
      old = SelectObject(win->hdc, win->old);
      DeleteObject(old);
      DeleteDC(win->hdc);
      win->hdc = NULL;
      win->old = NULL;
      
      GetClientRect((HWND)winNum, &r);
      hdc = GetDC((HWND)winNum);
      hdc2 = CreateCompatibleDC(hdc);
      hbitmap = CreateCompatibleBitmap(hdc, r.right - r.left, r.bottom - r.top);
      win->old = SelectObject(hdc2, hbitmap);
      win->hdc = hdc2;
      
      ReleaseDC((HWND)winNum, hdc);
    }
}

- (BOOL) findwindow: (NSPoint)loc : (int) op : (int) otherWin 
		   : (NSPoint *)floc : (int*) winFound
{
  return NO;
}

- (NSRect) windowbounds: (int) winNum
{
  RECT r;
  NSWindow *window = GSWindowWithNumber(winNum);

  GetWindowRect((HWND)winNum, &r);
  return MSScreenRectToGS(r, [window styleMask], self);
}

- (void) setwindowlevel: (int) level : (int) winNum
{
  NSDebugLLog(@"WTrace", @"setwindowlevel: %d : %d", level, winNum);
}

- (int) windowlevel: (int) winNum
{
  return 0;
}

- (NSArray *) windowlist
{
  NSMutableArray	*list = [NSMutableArray arrayWithCapacity: 100];
  HWND			w;
  HWND			next;

  w = GetForegroundWindow();	// Try to start with frontmost window
  if (w == NULL)
    {
      w = GetDesktopWindow();	// This should always succeed.
    }

  /* Step up to the frontmost window.
   */
  while ((next = GetNextWindow(w, GW_HWNDPREV)) != NULL)
    {
      w = next;
    }
  
  /* Now walk down the window list populating the array.
   */
  while (w != NULL)
    {
      /* Only add windows we own.
       * FIXME We should improve the API to support all windows on server.
       */
      if (GSWindowWithNumber((int)w) != nil)
	{
	  [list addObject: [NSNumber numberWithInt: (int)w]];
	}
      w = GetNextWindow(w, GW_HWNDNEXT);
    }

  return list;
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
- (void) flushwindowrect: (NSRect)rect : (int)winNum
{
  HWND hwnd = (HWND)winNum;
  RECT r = GSWindowRectToMS(self, hwnd, rect);
  WIN_INTERN *win = (WIN_INTERN *)GetWindowLong(hwnd, GWL_USERDATA);

  if (win->useHDC)
    {
      HDC hdc = GetDC(hwnd);
      WINBOOL result;

      result = BitBlt(hdc, rect.left, rect.top, 
                      (rect.right - rect.left), (rect.bottom - rect.top), 
                      win->hdc, rect.left, rect.top, SRCCOPY);
      if (!result)
        {
          NSLog(@"Flush window %d %@", hwnd, 
                NSStringFromRect(MSWindowRectToGS(self, hwnd, rect)));
          NSLog(@"Flush window failed with %d", GetLastError());
        }
      ReleaseDC(hwnd, hdc);
    }
}

- (void) styleoffsets: (float *) l : (float *) r : (float *) t : (float *) b
		     : (unsigned int) style 
{
  if ([self handlesWindowDecorations])
    {
      DWORD wstyle = [self windowStyleForGSStyle: style];
      RECT rect = {100, 100, 200, 200};
      
      AdjustWindowRectEx(&rect, wstyle, NO, 0);

      *l = 100 - rect.left;
      *r = rect.right - 200;
      *t = 100 - rect.top;
      *b = rect.bottom - 200;
      //NSLog(@"Style %d offset %f %f %f %f", wstyle, *l, *r, *t, *b);
    }
  else
    {
      /*
        If we don't handle decorations, all our windows are going to be
        border- and decorationless. In that case, -gui won't call this method, 
        but we still use it internally.
      */
      *l = *r = *t = *b = 0.0;
    }
}

- (void) docedited: (int) edited : (int) winNum
{
}

- (void) setinputstate: (int)state : (int)winNum
{
  if ([self handlesWindowDecorations] == NO)
    {
      return;
    }
  if (state == GSTitleBarKey)
    {
      SetActiveWindow((HWND)winNum);
    }
}

/** Forces focus to the window so that all key events are sent to this
    window */
- (void) setinputfocus: (int) winNum
{
  NSDebugLLog(@"WTrace", @"setinputfocus: %d", winNum);
  NSDebugLLog(@"Focus", @"Setting input focus to %d", winNum);
  if (winNum == 0)
    {
      NSDebugLLog(@"Focus", @" invalid focus window");
      return;
    }
  if (currentFocus == (HWND)winNum)
    {
      NSDebugLLog(@"Focus", @" window already has focus");
      return;
    }
  desiredFocus = (HWND)winNum;
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

- (NSPoint) mouseLocationOnScreen: (int)screen window: (int *)win
{
  return [self mouselocation];
}

- (BOOL) capturemouse: (int) winNum
{
  NSDebugLLog(@"WTrace", @"capturemouse: %d", winNum);
  SetCapture((HWND)winNum);
  return YES;
}

- (void) releasemouse
{
  NSDebugLLog(@"WTrace", @"releasemouse");
  ReleaseCapture();
}

- (void) hidecursor
{
  NSDebugLLog(@"WTrace", @"hidecursor");
  ShowCursor(NO);
}

- (void) showcursor
{
  ShowCursor(YES);
}

- (void) standardcursor: (int)style : (void **)cid
{
  HCURSOR hCursor = 0;

  NSDebugLLog(@"WTrace", @"standardcursor: %d", style);
  switch (style)
    {
      case GSArrowCursor: 
        hCursor = LoadCursor(NULL, IDC_ARROW);
        break;
      case GSIBeamCursor: 
        hCursor = LoadCursor(NULL, IDC_IBEAM);
        break;
      case GSCrosshairCursor: 
        hCursor = LoadCursor(NULL, IDC_CROSS);
        break;
      case GSPointingHandCursor: 
        hCursor = LoadCursor(NULL, IDC_HAND);
        break;
      case GSResizeLeftRightCursor: 
        hCursor = LoadCursor(NULL, IDC_SIZEWE);
        break;
      case GSResizeUpDownCursor: 
        hCursor = LoadCursor(NULL, IDC_SIZENS);
        break;
      default: 
        return;
    }
  *cid = (void*)hCursor;
}

- (void) imagecursor: (NSPoint)hotp : (int) w :  (int) h 
		    : (int)colors : (const unsigned char *)image : (void **)cid
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
process_key_event(WIN32Server *svr, HWND hwnd, WPARAM wParam, LPARAM lParam, 
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
  eventLocation
    = MSWindowPointToGS(svr, hwnd,  GET_X_LPARAM(pos), GET_Y_LPARAM(pos));

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
  if (keyState[VK_HELP] & 128)
    eventFlags |= NSHelpKeyMask;
  if ((keyState[VK_LWIN] & 128) || (keyState[VK_RWIN] & 128))
    eventFlags |= NSCommandKeyMask;


  switch(wParam)
    {
      case VK_SHIFT: 
      case VK_CAPITAL: 
      case VK_CONTROL: 
      case VK_MENU: 
      case VK_HELP: 
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
process_mouse_event(WIN32Server *svr, HWND hwnd, WPARAM wParam, LPARAM lParam, 
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
  eventLocation = MSWindowPointToGS(svr, hwnd,  GET_X_LPARAM(lParam), 
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
  if (GetKeyState(VK_HELP) < 0) 
    {
      eventFlags |= NSHelpKeyMask;
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
  else if ((eventType == NSLeftMouseDown)
    || (eventType == NSRightMouseDown)
    || (eventType == NSOtherMouseDown))
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


LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg, 
			     WPARAM wParam, LPARAM lParam)
{
  WIN32Server	*ctxt = (WIN32Server *)GSCurrentServer();

  return [ctxt windowEventProc: hwnd : uMsg : wParam : lParam];
}
