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



#ifndef _W32_EVENTS_h_INCLUDE
#define _W32_EVENTS_h_INCLUDE

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
#include <AppKit/NSMenuView.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSView.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSCursor.h>
#include <AppKit/NSText.h>
#include <AppKit/DPSOperators.h>

#include "win32/WIN32Server.h"
#include "win32/WIN32Geometry.h"
#include "w32_config.h"

  
@interface WIN32Server (w32_activate)
- (LRESULT) decodeWM_ACTIVEParams: (WPARAM)wParam :(LPARAM)lParam : (HWND)hwnd;
- (LRESULT) decodeWM_ACTIVEAPPParams: (HWND)hwnd :(WPARAM)wParam : (LPARAM)lParam;
- (void) decodeWM_NCACTIVATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) ApplicationDidFinishLaunching: (NSNotification*)aNotification;
- (void) ApplicationWillFinishLaunching: (NSNotification*)aNotification;
- (void) ApplicationWillHideNotification: (NSNotification*)aNotification;
- (void) WindowWillMiniaturizeNotification:(NSNotification*)aNotification;
- (void) MenuWillTearOff: (NSNotification*)aNotification;
- (void) MenuwillPopUP: (NSNotification*)aNotification;

@end




@interface WIN32Server (w32_movesize)

- (LRESULT) decodeWM_SIZEParams: (HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam;
- (LRESULT) decodeWM_MOVEParams: (HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam;
- (void) decodeWM_NCCALCSIZEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_WINDOWPOSCHANGINGParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_WINDOWPOSCHANGEDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (LRESULT) decodeWM_GETMINMAXINFOParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (LRESULT) decodeWM_EXITSIZEMOVEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (LRESULT) decodeWM_SIZINGParams:(HWND)hwnd : (WPARAM)wParam : (LPARAM)lParam;
@end

@interface WIN32Server (w32_create)

- (LRESULT) decodeWM_NCCREATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (LRESULT) decodeWM_CREATEParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) trackWindow:(NSNotification*)aNotification;
@end 

@interface WIN32Server (w32_windowdisplay)

- (void) decodeWM_SHOWWINDOWParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_NCPAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (LRESULT) decodeWM_ERASEBKGNDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_PAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_SYNCPAINTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_CAPTURECHANGEDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_GETICONParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) resizeBackingStoreFor: (HWND)hwnd;
@end

@interface WIN32Server (w32_text_focus)

//- (LRESULT) decodeWM_SETTEXTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (LRESULT) decodeWM_SETFOCUSParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_KILLFOCUSParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_GETTEXTParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;

@end

//small but useful events

@interface WIN32Server (w32_General)

- (void) decodeWM_CLOSEParams: (WPARAM)wParam :(LPARAM)lParam :(HWND)hwnd;
- (void) decodeWM_DESTROYParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_NCDESTROYParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_QUERYOPENParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) decodeWM_SYSCOMMANDParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;
- (void) resetForGSWindowStyle: (HWND)hwnd gsStryle:(int)aStyle;
//- (LRESULT) decodeWM_LBUTTONDOWNParams: (WPARAM)wParam : (LPARAM)lParam : (HWND)hwnd;

@end 


@interface WIN32Server (w32_debug)

- (BOOL) displayEvent: (unsigned int)uMsg;   // diagnotic filter
- (void) test_Geomemetry: (HWND)hwnd;
- (void) print_result: (RECT)msrect and: (NSRect)gsrect and: (RECT)control;
- (NSMutableString *) w32_createDetails: (LPCREATESTRUCT)details;
- (NSMutableString *) createWindowDetail: (NSArray *)anArray;
- (NSMutableString *) WindowDetail: (NSWindow *) theWindow;
- (NSMutableString *) MSRectDetails: (RECT)aRect;
- (NSMutableString *) NSRectDetails: (NSRect)aRect;
- (NSMutableString *) gswindowstate: (NSWindow *)theWindow;
- (NSMutableString *) MINMAXDetails: (MINMAXINFO *) mm;
- (NSMutableString *) subViewDetails: (NSWindow *)theWindow;

@end

// debug hooks into the GSDisplayServer class
@interface GSDisplayServer (GSDisplayServer_details)
- (int) eventQueCount;
- (NSMutableString *) dumpQue:(int)acount;
- (void) clearEventQue;

@end

#endif //_W32_EVENTS_h_INCLUDE
