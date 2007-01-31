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

#include "w32_Events.h"

static NSString * spacer =@"<BLANK_LINE>\n";

@implementation WIN32Server (w32_debug)

- (void) test_Geomemetry:(HWND)hwnd 
{
  NSRect gsrect;
  RECT r;
  RECT msrect;
	
  NSWindow *window = GSWindowWithNumber((int)hwnd);
	
  GetWindowRect(hwnd, &r);
	
  printf("*******************testing Conversion \n\n\n");
  printf("MSScreenRectToGS GSScreenRectToMS\n");
  gsrect = MSScreenRectToGS(r, [window styleMask], self);
  msrect= GSScreenRectToMS(gsrect, [window styleMask],self);
  printf("*************************test complete\n\n\n");
  
  [self print_result:msrect and:gsrect and:r];
  //TestsDone=YES;
}

- (void) print_result:(RECT) msrect and:(NSRect) gsrect and:(RECT) control
{

  printf("MS - Control\n");
  printf("MSrect = left %ld ",control.left);
  printf(" top %ld",control.top);
  printf(" right %ld",control.right);
  printf(" Bottom %ld\n",control.bottom);
  
  printf("GS - Calculated\n"); 
  printf("NSRect = height %f width %f ",gsrect.size.height,gsrect.size.width);
  printf(" X %f Y %f\n",gsrect.origin.x,gsrect.origin.y);
  
  printf("MS - Calculated\n");
  printf("MSrect = left %ld ",msrect.left);
  printf(" top %ld",msrect.top);
  printf(" right %ld",msrect.right);
  printf(" Bottom %ld\n",msrect.bottom);
}

- (BOOL) displayEvent:(unsigned int)uMsg
{

#ifdef __W32_debug__ //_logging
  //NSDebugLLog(@"NSEvent", @"Got Message %u for %d", uMsg, hwnd);
#endif

  switch (uMsg)
    {
    case WM_KEYDOWN:          return NO; break;  //Keyboard events
    case WM_KEYUP:            return NO; break;
    case WM_MOUSEMOVE:        return NO; break;// mouse moved events
    case WM_NCHITTEST:        return NO; break;
    case WM_SETCURSOR:        return NO; break;
    case WM_MOUSEWHEEL:       return NO; break;
    case WM_LBUTTONDOWN:      return YES; break;
    case WM_MOUSEACTIVATE:    return NO; break;
    case WM_CAPTURECHANGED:   return NO; break; //related to window -- redraw if needed
    case WM_NCMOUSEMOVE:      return NO; break;
    case WM_RBUTTONDOWN:      return YES; break;
    case WM_RBUTTONUP:        return YES; break;
    case WM_NCLBUTTONDOWN:    return NO; break;
    case WM_NCLBUTTONDBLCLK:  return NO; break;
      // window events Stubed or Functioning
    case WM_SETTEXT:            return __STATE; break;
    case WM_NCCREATE:           return __CREATE_FLAG;           break;
    case WM_NCCALCSIZE:         return __STATE; break;
    case WM_NCACTIVATE:         return __ACTIVE_FLAG;           break;
    case WM_NCPAINT:            return __STATE; break;
    case WM_SHOWWINDOW:         return __SHOWWINDOW_FLAG;       break;
    case WM_NCDESTROY:          return __STATE; break;
    case WM_GETTEXT:            return __STATE; break;
    case WM_STYLECHANGING:      return __STATE; break;
    case WM_STYLECHANGED:       return __STATE; break;
    case WM_GETMINMAXINFO:      return __GETMINMAXINFO_FLAG;    break;
    case WM_CREATE:             return __CREATE_FLAG;           break;
    case WM_WINDOWPOSCHANGING:  return __STATE; break;
    case WM_WINDOWPOSCHANGED:   return __STATE; break;
    case WM_MOVE:               return __MOVE_FLAG;             break;
      case WM_MOVING:             return __MOVING_FLAG;           break;
    case WM_SIZE:               return __SIZE_FLAG;             break;
    case WM_SIZING:             return __SIZING_FLAG;           break;
      case WM_ENTERSIZEMOVE:      return __ENTERSIZEMOVE_FLAG;    break;
    case WM_EXITSIZEMOVE:       return __EXITSIZEMOVE_FLAG;     break;
    case WM_ACTIVATE:           return __ACTIVE_FLAG;           break;
    case WM_ACTIVATEAPP:        return __ACTIVE_FLAG;           break;
    case WM_SETFOCUS:           return __SETFOCUS_FLAG;         break;
    case WM_KILLFOCUS:          return __KILLFOCUS_FLAG;        break;
      //case WM_SETCURSOR:          return __STATE; break;
    case WM_QUERYOPEN:          return __STATE; break;
      //case WM_CAPTURECHANGED:     return __STATE; break;
    case WM_ERASEBKGND:         return __ERASEBKGND_FLAG;       break;
    case WM_PAINT:              return __PAINT_FLAG;            break;
    case WM_SYNCPAINT:          return __STATE; break;
    case WM_CLOSE:              return __CLOSE_FLAG;            break;
    case WM_DESTROY:            return __DESTROY_FLAG;          break;
    case WM_QUIT:               return __STATE; break;
    case WM_USER:               return __STATE; break;
    case WM_APP:                return __STATE; break;
    case WM_ENTERMENULOOP:      return __STATE; break;
    case WM_EXITMENULOOP:       return __STATE; break;
    case WM_INITMENU:           return __STATE; break;
    case WM_MENUSELECT:         return __STATE; break;
    case WM_ENTERIDLE:          return __STATE; break;
      case WM_COMMAND:            return __COMMAND_FLAG;          break;
    case WM_SYSKEYDOWN:         return __STATE; break;
    case WM_SYSKEYUP:           return __STATE; break;
      case WM_SYSCOMMAND:         return __SYSCOMMAND_FLAG;       break;
    case WM_HELP:               return __STATE; break;
    case WM_GETICON:            return __STATE; break;
    case WM_CANCELMODE:         return __STATE; break;
    case WM_ENABLE:             return __STATE; break;
    case WM_CHILDACTIVATE:      return __ACTIVE_FLAG;           break;
    case WM_NULL:               return __STATE; break;
    case WM_LBUTTONUP:          return YES; break;
    case WM_PARENTNOTIFY:       return __STATE; break;  
    
    default:
      return YES;
      break;
    }
}

/*
typedef struct tagCREATESTRUCT {
    LPVOID lpCreateParams;
    HINSTANCE hInstance;
    HMENU hMenu;
    HWND hwndParent;
    int cy;
    int cx;
    int y;
    int x;
    LONG style;
    LPCTSTR lpszName;
    LPCTSTR lpszClass;
    DWORD dwExStyle;
} CREATESTRUCT, *LPCREATESTRUCT;
*/

- (NSMutableString *) w32_createDetails:(LPCREATESTRUCT)details
{

  NSMutableString * output= [NSMutableString stringWithString:spacer];
  [output appendString:@"\n\nLPCREATESTRUCT details\n"];
    
  [output appendFormat:@"HINSTANCE %p   ",details->hInstance];
    
  [output appendFormat:@"HMENU %p\n",details->hMenu];
    
    
  [output appendFormat:@"Creating window: Parent is  %s:\n",
	  [self getNativeClassName:details->hwndParent]];
    
  [output appendFormat:@"Co-ordanates:height[%d] width[%d] Pos[%d] Pox[%d]\n",
	  details->cy,details->cx,details->y,details->x];
                                            
  [output appendFormat:@"Style %lu Name: %s Win32Class: %s Extended Style %ld\n\n\n",
	  details->style,details->lpszName,
	  details->lpszClass,details->dwExStyle];
  [output appendString:spacer];
                                 
  return output;
}

- (NSMutableString *) createWindowDetail:(NSArray *)anArray
{
  int i =0;
  int c=[anArray count];
    
    
  NSMutableString * output= [NSMutableString stringWithString:spacer];
    
  [output appendFormat:@"Application window count is: %d\n",c];

  for (i=0;i<c;i++)
    {
      NSWindow * theWindow=[anArray objectAtIndex:i];
        
      [output appendString:[self WindowDetail:theWindow]];
    }
  [output appendString:spacer];
    
  return output;
}

- (NSMutableString *) WindowDetail:(NSWindow *) theWindow
{   
  return [self gswindowstate:theWindow];
    
}

- (NSMutableString *) MSRectDetails:(RECT)aRect
{
  NSMutableString * output= [NSMutableString stringWithCString:"MSRect Details\n"];

  [output appendFormat:@"left %ld ",aRect.left];
  [output appendFormat:@"top %ld ",aRect.top];
  [output appendFormat:@"right %ld ",aRect.right];
  [output appendFormat:@"Bottom %ld\n",aRect.bottom];

  return output;
}

- (NSMutableString *) NSRectDetails:(NSRect)aRect
{

  NSMutableString * output= [NSMutableString stringWithString:@" "];

  [output appendFormat:@"height %ld width %ld ",(int)aRect.size.height
	  ,(int)aRect.size.width];
  [output appendFormat:@" XPos %ld YPos %ld\n",(int)aRect.origin.x
	  ,(int)aRect.origin.y];

  return output;
}

- (NSMutableString *) gswindowstate:(NSWindow *)theWindow
{
  // NSRect cvRect=[[theWindow contentView] frame];
  NSMutableString * output= [NSMutableString stringWithString:spacer];
  [output appendFormat:@"MenuRef = %d\n",flags.menuRef];
  [output appendFormat:@"Main Menu %s\n",flags._is_menu ? "YES" : "NO"];
  [output appendFormat:@"WINDOW title %@\n", [theWindow title]];
  [output appendFormat:@"WINDOW className %@\n", [theWindow className]];
  [output appendFormat:@"WINDOW isVisible: %s\n",[theWindow isVisible] ? "YES" : "NO"];
  [output appendFormat:@"WINDOW isAutodisplay: %s\n",[theWindow isAutodisplay] ? "YES" : "NO"];
  [output appendFormat:@"WINDOW isMiniaturized: %s\n",[theWindow isMiniaturized] ? "YES" : "NO"];
  [output appendFormat:@"WINDOW viewsNeedDisplay: %s\n",[theWindow viewsNeedDisplay] ? "YES" : "NO"];
  [output appendFormat:@"WINDOW isOpaque: %s\n",[theWindow isOpaque] ? "YES" : "NO"];
  [output appendFormat:@"WINDOW isReleasedWhenClosed: %s\n ",[theWindow isReleasedWhenClosed] ? "YES" : "NO"];
  [output appendFormat:@"WINDOW isOneShot: %s\n",[theWindow isOneShot] ? "YES" : "NO"];
  [output appendFormat:@"WINDOW isMainWindow: %s\n",[theWindow isMainWindow] ? "YES" : "NO"];
  [output appendFormat:@"WINDOW isKeyWindow: %s\n",[theWindow isKeyWindow] ? "YES" : "NO"];
  [output appendFormat:@"WINDOW styleMask: %d\n",[theWindow styleMask]];
  [output appendFormat:@"WINDOW frame:%@", [self NSRectDetails:[theWindow frame]]];
  //[output appendString:[self subViewDetails:theWindow]];
    
  [output appendFormat:@"Native Class Name %@\n",
	  [self getNativeClassName:(HWND)[theWindow windowNumber]]];
  [output appendFormat:@"Win32 GWL_EXStyle %ld\n",
	  GetWindowLong((HWND)[theWindow windowNumber],GWL_EXSTYLE)];
              
  [output appendFormat:@"Win32 GWL_STYLE %X\n",
	  GetWindowLong((HWND)[theWindow windowNumber],GWL_STYLE)];
              
  [output appendFormat:@"Win32 GWL_WNDPROC %ld\n",
	  GetWindowLong((HWND)[theWindow windowNumber],GWL_WNDPROC)];
              
  [output appendFormat:@"Win32 GWL_HINSTANCE %ld\n",
	  GetWindowLong((HWND)[theWindow windowNumber],GWL_HINSTANCE)];
              
  [output appendFormat:@"Win32 GWL_HWNDPARENT %ld\n",
	  GetWindowLong((HWND)[theWindow windowNumber],GWL_HWNDPARENT)];
              
  [output appendFormat:@"Win32 GWL_ID %ld\n",
	  GetWindowLong((HWND)[theWindow windowNumber],GWL_ID)];
  [output appendString:spacer];
    
  [output appendFormat:@"Win32 windowtext %@\n",
	  [self getWindowtext:(HWND)[theWindow windowNumber]]];
  return output;
}

- (NSMutableString *) MINMAXDetails:(MINMAXINFO *) mm
{
  NSMutableString * output =[NSMutableString stringWithString:spacer];
  [output appendString:@"MINMAXINFO"];
    
  [output appendFormat:@"ptMaxSize width[%ld] X height[%ld]\n",
	  mm->ptMaxSize.x,mm->ptMaxSize.y];
      
  [output appendFormat:@"ptMaxPosition width[%ld] X height[%ld]\n",
	  mm->ptMaxPosition.x,mm->ptMaxPosition.y];
      
  [output appendFormat:@"ptMinTrackSize width[%ld] X height[%ld]\n",
	  mm->ptMinTrackSize.x,mm->ptMinTrackSize.y];
      
  [output appendFormat:@"ptMaxTrackSize width[%ld] X height[%ld]\n",
	  mm->ptMaxTrackSize.x,mm->ptMaxTrackSize.y];
          
  return output;
}

- (NSMutableString *) subViewDetails:(NSWindow *)theWindow
{
  NSView * cView=[theWindow contentView];
  NSView * sView=[cView superview];
  NSArray * theViews=[cView subviews];
  unsigned int i=0;
  unsigned int c=[theViews count];
  NSView * temp=nil;
  NSRect cvRect = [cView frame];
  NSRect svRect = [sView frame];
  NSRect tRect;
  NSMutableString * output =[NSMutableString stringWithString:spacer];
  [output appendFormat:@"subView Details for %@\n", [theWindow title]];
  [output appendFormat:@"superRect %@", [self NSRectDetails:svRect]];
  [output appendFormat:@"contentRect %@", [self NSRectDetails:cvRect]];
    
  for (i=0;i<c;i++)
    {
      temp=[theViews objectAtIndex:i];
      tRect =[temp frame];
      [output appendFormat:@"subView %u rect %@",
	      i, [self NSRectDetails:tRect]];
    }
  return output;
}

- (void) handleNotification:(NSNotification*)aNotification
{
   #ifdef __APPNOTIFICATIONS__
   printf("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
   printf("+++                NEW EVENT                                 +++\n");
   printf("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n");
   printf("WM_APPNOTIFICATION -1\n %s\nPosted by current application\n",
                                [[aNotification name] cString]);
   NSWindow *theWindow=[aNotification object];
                               
   printf("%s",[[self gswindowstate:theWindow] cString]);
   #endif
} 
@end

