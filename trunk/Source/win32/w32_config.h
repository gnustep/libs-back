/* WIN32Server - Implements window handling for MSWindows

   Copyright (C) 2005 Free Software Foundation, Inc.

   Written By: Tom MacSween <macsweent@sympatico.ca>
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


#ifndef _W32_CONFIG_h_INCLUDE
#define  _W32_CONFIG_h_INCLUDE

#define EVENT_WINDOW(lp) (GSWindowWithNumber((int)lp))

//#define _logging  //use to log messages from our debug code

//#define __W32_debug_Event_loop //special flag for event loops and counts

//#define __W32_debug__ // activate the debug code in the main event server
#define __STATE NO

#ifdef __W32_debug__  // turn on tests for this
#define __SETFOCUS__
#define __KILLFOCUS__
#define __SHOWWINDOW__
#define __WM_ACTIVE__
#define __WM_ACTIVATEAPP__ 
#define __WM_NCACTIVATE__
#define __WM_NCCREATE__
#define __WM_CREATE__
#define __WM_MOVE__
#define __WM_SIZE__
#define __PAINT__
#define __BACKING__
#define __CLOSE__
#define __DESTROY__
#define __ERASEBKGND__
#define __GETMINMAXINFO__
#define __EXITSIZEMOVE__
 //#define __APPNOTIFICATIONS__
#define __SIZING__
 #define __SYSCOMMAND__
 #define __COMMAND__
 #define __MOVING__
 #define __ENTERSIZEMOVE__

#define __SETFOCUS_FLAG 1
#define __ACTIVE_FLAG 1
#define __CREATE_FLAG 1
#define __MOVE_FLAG 1
#define __SIZE_FLAG 1
#define __SHOWWINDOW_FLAG 1
#define __KILLFOCUS_FLAG 1
#define __PAINT_FLAG 1
#define __CLOSE_FLAG 1
#define __DESTROY_FLAG 1
#define __ERASEBKGND_FLAG 1
#define __GETMINMAXINFO_FLAG 1
#define __EXITSIZEMOVE_FLAG 1
#define __SIZING_FLAG 1
 #define __SYSCOMMAND_FLAG 1
 #define __COMMAND_FLAG 1
 #define __MOVING_FLAG 1
 #define __ENTERSIZEMOVE_FLAG 1
#else
#define __ACTIVE_FLAG 0
#define __CREATE_FLAG 0
#define __MOVE_FLAG 0
#define __SIZE_FLAG 0
#define __SHOWWINDOW_FLAG 0
#define __KILLFOCUS_FLAG 0
#define __SETFOCUS_FLAG 0
#define __PAINT_FLAG 0
#define __CLOSE_FLAG 0
#define __DESTROY_FLAG 0
#define __ERASEBKGND_FLAG 0
#define __GETMINMAXINFO_FLAG 0
#define __EXITSIZEMOVE_FLAG 0
#define __SIZING_FLAG 0
 #define __SYSCOMMAND_FLAG 0
 #define __COMMAND_FLAG 0
 #define __MOVING_FLAG 0
 #define __ENTERSIZEMOVE_FLAG 0
#endif

#endif //_W32_CONFIG_h_INCLUDE
