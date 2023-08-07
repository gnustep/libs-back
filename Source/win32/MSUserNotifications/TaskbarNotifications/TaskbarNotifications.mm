// Windows documentation - see: https://msdn.microsoft.com/en-us/library/windows/desktop/bb773352(v=vs.85).aspx
// Several members of this structure are only supported for Windows 2000 and later. To enable these members, 
//  include one of the following lines in your header:
// // Windows Vista and later:
// #define NTDDI_VERSION NTDDI_WIN2K
// #define NTDDI_VERSION NTDDI_WINXP
// #define NTDDI_VERSION NTDDI_VISTA
//
// // Windows XP and earlier:
// #define _WIN32_IE 0x0500
//
// We've defined these in the GNUmakefile!!!!

// MUST BE FIRST!!!
#include <../MSUserNotification.h>
#include <AppKit/NSGraphics.h>
#include <AppKit/NSImage.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSUserNotification.h>
#include <Foundation/NSUUID.h>
#include <Foundation/NSValue.h>

#include <ShellAPI.h>
#define CINTERFACE
#define interface struct
#include <shlwapi.h>
#undef interface
//#include <Winuser.h>
#include <rpcdce.h>

#if !defined(NIIF_USER)
#define NIIF_USER    0x00000004
#endif

#if !defined(NIN_SELECT)
#define NIN_SELECT          (WM_USER + 0)
#endif
#if !defined(NIN_BALLOONSHOW)
#define NIN_BALLOONSHOW         (WM_USER + 2)
#endif
#if !defined(NIN_BALLOONHIDE)
#define NIN_BALLOONHIDE         (WM_USER + 3)
#endif
#if !defined(NIN_BALLOONTIMEOUT)
#define NIN_BALLOONTIMEOUT      (WM_USER + 4)
#endif
#if !defined(NIN_BALLOONUSERCLICK)
#define NIN_BALLOONUSERCLICK    (WM_USER + 5)
#endif
#if !defined(NIN_POPUPOPEN)
#define NIN_POPUPOPEN        (WM_USER + 6)
#endif
#if !defined(NIN_POPUPCLOSE)
#define NIN_POPUPCLOSE        (WM_USER + 7)
#endif

#ifdef BUILD_DLL
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __declspec(dllimport)
#endif

#define WIN_EXTRABYTES      0
#define WINDOW_CLASS_NAME   TEXT("NSUserNotificationTaskbar")
#define WINDOW_TITLE_NAME   TEXT("TaskBarNotifierWin")
#define NOTIFY_MESSAGE_NAME TEXT("NSUserNotificationWindowsMessage")

#if defined(__cplusplus)
extern "C" {
#endif

void _registerWindowsClass();
void _unregisterWindowsClass();
void _initWin32Context();
void _destroyWin32Context();
LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

HICON _iconForBundle();
void _setupNotifyDataIcon(NOTIFYICONDATA&, HICON);
void _setupNotifyDataUUID(NOTIFYICONDATA &, const char *);
void _setupNotifyData(NOTIFYICONDATA&);
UINT _addApplicationIcon(DWORD, const char *, HICON);
void _removeApplicationIcon(DWORD, HICON);
void _removeProcessInfo();
void _removeApplicationIconForID(UINT appIconID);

static HANDLE         gHandleDLL         = NULL;
static HWND           gHandleWin         = NULL;
static UINT           gNotifyMsg         = 0;
static UINT           gNotifyCnt         = 0;
static DLLVERSIONINFO gShell32DllVersion = { 0 };

// Objective-C/GNUstep references...
static NSString            *gUuidString  = nil;
static NSMutableDictionary *gProcessInfo = nil;

// Need to capture the DLL instance handle....
BOOL WINAPI DllMain(HANDLE hinstDLL, DWORD dwReason, LPVOID lpvReserved)
{
  DWORD processID = GetCurrentProcessId();

#if defined(DEBUG)
  NSLog(@"%s:hinstDLL: %p dwReason: %d lpvReserved: %p procID: %p", __PRETTY_FUNCTION__, hinstDLL, dwReason, lpvReserved, processID);
#endif
  
	switch (dwReason)
  {
    case DLL_PROCESS_ATTACH: // Do process attach specific stuff here...
      // TODO: DO we need to worry about OTHER PROCESSES ATTACHING???
      // Save the DLL instance handle...
      // FIXME: Need process specific code here to setup for capturing the generated icons
      gHandleDLL = hinstDLL;
      
#if 0 // DOES NOT WORK - error code 126 - "The specified module could not be found"
      // even though the instance handle is the same as the modile handle...
      // Disable thread attache/detach invocations...
      if (DisableThreadLibraryCalls((HMODULE)hinstDLL) == 0)
      {
        NSLog(@"%s:PROCESS_ATTACH:disable thread library calls error: %d", __PRETTY_FUNCTION__, GetLastError());
        return FALSE;
      }
#endif
      
      // General intialization...
      _initWin32Context();
      
      // If no window...
      if  (gHandleWin == NULL)
        return FALSE; // This is bad...

      // Log our info...
#if 0 //defined(DEBUG)
      NSLog(@"%s:PROCESS_ATTACH:gHandleDLL: %p gHandleWin: %p", __PRETTY_FUNCTION__, gHandleDLL, gHandleWin);
#endif
      break;
      
    case DLL_PROCESS_DETACH: // Do process attach specific stuff here...
      // FIXME: Need process specific code here to remove any generated icons
#if 0 //defined(DEBUG)
      NSLog(@"%s:PROCESS_DETACH:gHandleDLL: %p gHandleWin: %p", __PRETTY_FUNCTION__, gHandleDLL, gHandleWin);
#endif

      // Cleanup window stuff...
      _destroyWin32Context();
      
      break;
      
    case DLL_THREAD_ATTACH: // Do thread attach specific stuff here...
      // FIXME: Do we need thread specific code here...
#if 0 //defined(DEBUG)
      NSLog(@"%s:THREAD_ATTACH:gHandleDLL: %p gHandleWin: %p", __PRETTY_FUNCTION__, gHandleDLL, gHandleWin);
#endif
      break;

    case DLL_THREAD_DETACH: // Do thread detach specific stuff here...
      // FIXME: Do we need thread specific code here...
#if 0 //defined(DEBUG)
      NSLog(@"%s:THREAD_DETACH:gHandleDLL: %p gHandleWin: %p", __PRETTY_FUNCTION__, gHandleDLL, gHandleWin);
#endif
      break;
	}
	return TRUE;
}

void _initWin32Context()
{
  NSString *gHandleString = nil;
  NSNumber *value = [NSNumber numberWithInteger:GetCurrentProcessId()];

  // Register our message window type......
  _registerWindowsClass();
  
#if defined(DEBUG)
  // Get Shell32 DLL version information...
  HMODULE hShell32Dll = LoadLibrary(TEXT("Shell32.dll"));
  if (hShell32Dll == NULL)
  {
    NSLog(@"%s:unable to load library Shell32.dll - error: %d", __PRETTY_FUNCTION__, GetLastError());
  }
  else
  {
    DLLGETVERSIONPROC procaddr = (DLLGETVERSIONPROC)GetProcAddress(hShell32Dll, TEXT("DllGetVersion"));
    
    if (procaddr == NULL)
    {
      NSLog(@"%s:Shell32.dll version info function 'DllGetVersion' missing", __PRETTY_FUNCTION__);
    }
    else
    {
      // Setup the size parameter for the structure...
      gShell32DllVersion.cbSize = sizeof(gShell32DllVersion);
      
      // Get the version information...
      procaddr(&gShell32DllVersion);
      NSLog(@"%s:Shell32.dll version info - major: %d minor: %d build: %d platform %d", __PRETTY_FUNCTION__,
            gShell32DllVersion.dwMajorVersion,
            gShell32DllVersion.dwMinorVersion,
            gShell32DllVersion.dwBuildNumber,
            gShell32DllVersion.dwPlatformID);
    }

    // cleanup...
    FreeLibrary(hShell32Dll);
  }
#endif

  // Register the windows notify message we want...
  gNotifyMsg = RegisterWindowMessage(NOTIFY_MESSAGE_NAME);
  if (gNotifyMsg == 0)
  {
    NSLog(@"%s:error registering windos message - error: %d", __PRETTY_FUNCTION__, GetLastError());
    return;
  }
      
  // Create a message only window...if it hasn't been created yet...
  gHandleWin = CreateWindowEx( 0, WINDOW_CLASS_NAME, WINDOW_TITLE_NAME, 0, 0, 0, 0, 0, HWND_MESSAGE, NULL, NULL, NULL );
  if (gHandleWin == NULL)
  {
    NSLog(@"%s:PROCESS_ATTACH:create window error: %d", __PRETTY_FUNCTION__, GetLastError());
    return;
  }

  // Initialize necessary data structures...
  gProcessInfo = [NSMutableDictionary new];
  [gProcessInfo setObject:[NSMutableDictionary dictionary] forKey:@"AppIcons"];
  [gProcessInfo setObject:[NSMutableDictionary dictionary] forKey:@"AppNotes"];
  [gProcessInfo setObject:value forKey:@"ProcessID"];
}

void _destroyWin32Context()
{
  // Remove the process' info dictionary entried...
  _removeProcessInfo();
  
  // Free process info dictionary...
  DESTROY(gProcessInfo);

  // Destroy the message window...
  if (gHandleWin != NULL)
    DestroyWindow(gHandleWin);
    
  // Unregister the window class...
  _unregisterWindowsClass();
}

NSImage *_imageForBundleInfo(NSDictionary*infoDict)
{
  NSImage  *image       = nil;
  NSString *appIconFile = [infoDict objectForKey: @"NSIcon"];
  
  if (appIconFile && ![appIconFile isEqual: @""])
  {
    image = [NSImage imageNamed: appIconFile];
  }

  // Try to look up the icns file.
  appIconFile = [infoDict objectForKey: @"CFBundleIconFile"];
  if (appIconFile && ![appIconFile isEqual: @""])
  {
    image = [NSImage imageNamed: appIconFile];
  }

  if (image == nil)
  {
    image = [NSImage imageNamed: @"GNUstep"];
  }
  else
  {
    /* Set the new image to be named 'NSApplicationIcon' ... to do that we
     * must first check that any existing image of the same name has its
     * name removed.
     */
    [(NSImage*)[NSImage imageNamed: @"NSApplicationIcon"] setName: nil];
    // We need to copy the image as we may have a proxy here
    image = AUTORELEASE([image copy]);
    [image setName: @"NSApplicationIcon"];
  }
  return image;
}

HICON _iconFromRep(NSBitmapImageRep* rep)
{
  HICON result = NULL;
  
  if (rep)
  {
    int w = [rep pixelsWide];
    int h = [rep pixelsHigh];
    
    // Create a windows bitmap from the image representation's bitmap...
    if ((w > 0) && (h > 0))
    {
      BITMAP    bm;
      HDC       hDC             = GetDC(NULL);
      HDC       hMainDC         = CreateCompatibleDC(hDC);
      HDC       hAndMaskDC      = CreateCompatibleDC(hDC);
      HDC       hXorMaskDC      = CreateCompatibleDC(hDC);      
      HBITMAP   hAndMaskBitmap  = NULL;
      HBITMAP   hXorMaskBitmap  = NULL;
      
      // Create the source bitmap...
      HBITMAP hSourceBitmap = CreateBitmap(w, h, [rep numberOfPlanes], [rep bitsPerPixel], [rep bitmapData]);
      
      // Get the dimensions of the source bitmap
      GetObject(hSourceBitmap, sizeof(BITMAP), &bm);
      
      // Create compatible bitmaps for the device context...
      hAndMaskBitmap = CreateCompatibleBitmap(hDC, bm.bmWidth, bm.bmHeight);
      hXorMaskBitmap = CreateCompatibleBitmap(hDC, bm.bmWidth, bm.bmHeight);
      
      // Select the bitmaps to DC
      HBITMAP hOldMainBitmap    = (HBITMAP)SelectObject(hMainDC, hSourceBitmap);
      HBITMAP hOldAndMaskBitmap = (HBITMAP)SelectObject(hAndMaskDC, hAndMaskBitmap);
      HBITMAP hOldXorMaskBitmap = (HBITMAP)SelectObject(hXorMaskDC, hXorMaskBitmap);
      
      /* On windows, to calculate the color for a pixel, first an AND is done
       * with the background and the "and" bitmap, then an XOR with the "xor"
       * bitmap. This means that when the data in the "and" bitmap is 0, the
       * pixel will get the color as specified in the "xor" bitmap.
       * However, if the data in the "and" bitmap is 1, the result will be the
       * background XOR'ed with the value in the "xor" bitmap. In case the "xor"
       * data is completely black (0x000000) the pixel will become transparent,
       * in case it's white (0xffffff) the pixel will become the inverse of the
       * background color.
       */

      // Scan each pixel of the souce bitmap and create the masks
      int y;
      int *pixel = (int*)[rep bitmapData];
      for(y = 0; y < bm.bmHeight; ++y)
      {
        int x;
        for (x = 0; x < bm.bmWidth; ++x)
          {
            if (*pixel++ == 0x00000000)
              {
                SetPixel(hAndMaskDC, x, y, RGB(255, 255, 255));
                SetPixel(hXorMaskDC, x, y, RGB(0, 0, 0));
              }
            else
              {
                SetPixel(hAndMaskDC, x, y, RGB(0, 0, 0));
                SetPixel(hXorMaskDC, x, y, GetPixel(hMainDC, x, y));
              }
          }
      }
    
      // Reselect the old bitmap objects...
      SelectObject(hMainDC, hOldMainBitmap);
      SelectObject(hAndMaskDC, hOldAndMaskBitmap);
      SelectObject(hXorMaskDC, hOldXorMaskBitmap);
      
      // Create the cursor from the generated and/xor data...
      ICONINFO iconinfo = { 0 };
      iconinfo.fIcon    = FALSE;
      iconinfo.xHotspot = 0;
      iconinfo.yHotspot = 0;
      iconinfo.hbmMask  = hAndMaskBitmap;
      iconinfo.hbmColor = hXorMaskBitmap;
      
      // Finally, try to create the cursor...
      result = CreateIconIndirect(&iconinfo);

      // Cleanup the DC's...
      DeleteDC(hXorMaskDC);
      DeleteDC(hAndMaskDC);
      DeleteDC(hMainDC);
      
      // Cleanup the bitmaps...
      DeleteObject(hXorMaskBitmap);
      DeleteObject(hAndMaskBitmap);
      DeleteObject(hSourceBitmap);
      
      // Release the screen HDC...
      ReleaseDC(NULL,hDC);
    }
  }
  
  return(result);
}

NSBitmapImageRep *_getStandardBitmap(NSImage *image)
{
  NSBitmapImageRep *rep;
  
  if (image == nil)
  {
    return nil;
  }
  
  rep = (NSBitmapImageRep *)[image bestRepresentationForDevice: nil];
  if (!rep || ![rep respondsToSelector: @selector(samplesPerPixel)])
  {
    /* FIXME: We might create a blank cursor here? */
#if defined(DEBUG)
    NSLog(@"%s:could not convert cursor bitmap data for image: %@", __PRETTY_FUNCTION__, image);
#endif
    return nil;
  }
  else
  {
    // Convert into something usable by the backend
    return [rep _convertToFormatBitsPerSample: 8
                              samplesPerPixel: [rep hasAlpha] ? 4 : 3
                                     hasAlpha: [rep hasAlpha]
                                     isPlanar: NO
                               colorSpaceName: NSCalibratedRGBColorSpace
                                 bitmapFormat: 0
                                  bytesPerRow: 0
                                 bitsPerPixel: 0];
  }
}

HICON _iconFromImage(NSImage *image)
{
  // Default the return cursur ID to NULL...
  HICON             result = NULL;
  NSBitmapImageRep *rep    = _getStandardBitmap(image);
  
  if (rep == NULL)
  {
    NSLog(@"%s:error creating standard bitmap for image: %@", __PRETTY_FUNCTION__, image);
  }
  else
  {
    // Try to create the icon from the image...
    result = _iconFromRep(rep);
  }
  
  // Return whatever we were able to generate...
  return(result);
}

HICON _iconForBundle()
{
  NSBundle     *mainBundle  = [NSBundle mainBundle];
  NSDictionary *infoDict    = [mainBundle infoDictionary];
  NSLog(@"%s:infoDict: %@", __PRETTY_FUNCTION__, infoDict);
  NSString     *imageName   = [[infoDict objectForKey:@"CFBundleIconFiles"] objectAtIndex:0];
  NSString     *imageType   = @"";
  NSString     *path        = [mainBundle  pathForResource:imageName ofType:imageType];
  NSImage      *image       = _imageForBundleInfo(infoDict);
  return _iconFromImage(image);
}

void _registerWindowsClass()
{
  WNDCLASSEX wc = { 0 };

  // Register the main window class. 
  wc.cbSize        = sizeof(wc);          
  wc.style         = 0;
  wc.lpfnWndProc   = (WNDPROC)MainWndProc;
  wc.cbClsExtra    = 0; 
  // Keep extra space for each window, for OFF_LEVEL and OFF_ORDERED
  wc.cbWndExtra    = WIN_EXTRABYTES; 
  wc.hInstance     = (HINSTANCE)gHandleDLL; 
  wc.hIcon         = NULL;
  wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
  wc.hbrBackground = (HBRUSH)GetStockObject(WHITE_BRUSH); 
  wc.lpszMenuName  =  NULL; 
  wc.lpszClassName = WINDOW_CLASS_NAME;
  wc.hIconSm       = NULL;

  if (!RegisterClassEx(&wc))
  {
    NSLog(@"%s:error registering windows class - error: %d", __PRETTY_FUNCTION__, GetLastError());
    return;
  }
  // FIXME We should use GetSysColor to get standard colours from MS Window and 
  // use them in NSColor

  // Should we create a message only window here, so we can get events, even when
  // no windows are created?
}

void _unregisterWindowsClass()
{
  UnregisterClass(WINDOW_CLASS_NAME, (HINSTANCE)gHandleDLL);
}

/* Windows documentation.....

See: https://msdn.microsoft.com/en-us/library/windows/desktop/bb773352(v=vs.85).aspx

An application-defined message identifier. The system uses this identifier to send
notification messages to the window identified in hWnd. These notification messages 
are sent when a mouse event or hover occurs in the bounding rectangle of the icon, 
when the icon is selected or activated with the keyboard, or when those actions occur 
in the balloon notification.

When the uVersion member is either 0 or NOTIFYICON_VERSION, the wParam parameter of the 
message contains the identifier of the taskbar icon in which the event occurred. This 
identifier can be 32 bits in length. The lParam parameter holds the mouse or keyboard 
message associated with the event. For example, when the pointer moves over a taskbar 
icon, lParam is set to WM_MOUSEMOVE.

When the uVersion member is NOTIFYICON_VERSION_4, applications continue to receive 
notification events in the form of application-defined messages through the uCallbackMessage 
member, but the interpretation of the lParam and wParam parameters of that message is changed 
as follows:
o LOWORD(lParam) contains notification events, such as NIN_BALLOONSHOW, NIN_POPUPOPEN, or 
  WM_CONTEXTMENU.
o HIWORD(lParam) contains the icon ID. Icon IDs are restricted to a length of 16 bits.
o GET_X_LPARAM(wParam) returns the X anchor coordinate for notification events NIN_POPUPOPEN, 
  NIN_SELECT, NIN_KEYSELECT, and all mouse messages between WM_MOUSEFIRST and WM_MOUSELAST. 
  If any of those messages are generated by the keyboard, wParam is set to the upper-left corner 
  of the target icon. For all other messages, wParam is undefined.
o GET_Y_LPARAM(wParam) returns the Y anchor coordinate for notification events and messages 
  as defined for the X anchor.

*/
LRESULT CALLBACK MainWndProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  LRESULT status = 0;
  
#if defined(DEBUG)
  NSLog(@"%s:hwnd: %p uMsg %d wParam: %p lParam: %p", __PRETTY_FUNCTION__, hwnd, uMsg, wParam, lParam);
#endif
  
  // If it's not our notify event message ID then...
  if (uMsg != gNotifyMsg)
  {
    // invoke default windows procedure to handle the message...
    status = DefWindowProc(hwnd, uMsg, wParam, lParam);
  }
  else  // Otherwise we'll process it...
  {
    UINT loword = LOWORD(lParam);
    
    switch (loword)
    {
      case NIN_SELECT:
#if defined(DEBUG)
        NSLog(@"%s:NIN_SELECT:", __PRETTY_FUNCTION__);
#endif
        break;

      case NIN_BALLOONSHOW:
#if defined(DEBUG)
        NSLog(@"%s:NIN_BALLOONSHOW:", __PRETTY_FUNCTION__);
#endif
        break;

      case NIN_BALLOONHIDE:
#if defined(DEBUG)
        NSLog(@"%s:NIN_BALLOONHIDE:", __PRETTY_FUNCTION__);
#endif
        break;

      case NIN_BALLOONTIMEOUT:
#if defined(DEBUG)
        NSLog(@"%s:NIN_BALLOONTIMEOUT:", __PRETTY_FUNCTION__);
#endif
        break;

      case NIN_BALLOONUSERCLICK:
#if defined(DEBUG)
        NSLog(@"%s:NIN_BALLOONUSERCLICK:", __PRETTY_FUNCTION__);
#endif
        break;

      case NIN_POPUPOPEN:
#if defined(DEBUG)
        NSLog(@"%s:NIN_POPUPOPEN:", __PRETTY_FUNCTION__);
#endif
        break;
        
      case NIN_POPUPCLOSE:
#if defined(DEBUG)
        NSLog(@"%s:NIN_POPUPCLOSE:", __PRETTY_FUNCTION__);
#endif
        break;
        
      case WM_MOUSEMOVE:
#if defined(DEBUG)
        NSLog(@"%s:WM_MOUSEMOVE:", __PRETTY_FUNCTION__);
#endif
        break;
        
      case WM_LBUTTONUP:
#if defined(DEBUG)
        NSLog(@"%s:WM_LBUTTONUP:", __PRETTY_FUNCTION__);
#endif
        break;
        
      case WM_LBUTTONDOWN:
#if defined(DEBUG)
        NSLog(@"%s:WM_LBUTTONDOWN:", __PRETTY_FUNCTION__);
#endif
        break;
        
      case WM_LBUTTONDBLCLK:
#if defined(DEBUG)
        NSLog(@"%s:WM_LBUTTONDBLCLK:", __PRETTY_FUNCTION__);
#endif
        break;
                
      case WM_RBUTTONUP:
#if defined(DEBUG)
        NSLog(@"%s:WM_RBUTTONUP:", __PRETTY_FUNCTION__);
#endif
        break;
        
      case WM_RBUTTONDOWN:
#if defined(DEBUG)
        NSLog(@"%s:WM_RBUTTONDOWN:", __PRETTY_FUNCTION__);
#endif
        break;
                
      case WM_RBUTTONDBLCLK:
#if defined(DEBUG)
        NSLog(@"%s:WM_RBUTTONDBLCLK:", __PRETTY_FUNCTION__);
#endif
        break;

      case WM_CONTEXTMENU:
#if defined(DEBUG)
        NSLog(@"%s:WM_CONTEXTMENU:", __PRETTY_FUNCTION__);
#endif
        break;

      default:
        NSLog(@"%s:default - unhandled notification event: %d", __PRETTY_FUNCTION__, loword);
        status = 1;
        break;
    }
  }

  // Cleanup...
  [pool drain];
  
  return status;
}

NSMutableDictionary *appIconsForProcess()
{
  return [gProcessInfo objectForKey:@"AppIcons"];
}

NSMutableDictionary *appIconInfoForID(UINT appIconID)
{
  NSNumber     *appIDValue = [NSNumber numberWithInteger:appIconID];
  NSDictionary *appIcons   = appIconsForProcess();
  NSDictionary *appIcon    = [appIcons objectForKey:appIDValue];
  NSLog(@"Appicon for ID: %d value: %@", __PRETTY_FUNCTION__, appIconID, appIcon);
  return appIcon;
}

void removeAppIconInfoForID(UINT appIconID)
{
  NSNumber            *appIDValue = [NSNumber numberWithInteger:appIconID];
  NSMutableDictionary *appIcons   = appIconsForProcess();
  [appIcons removeObjectForKey:appIDValue];
}

void removeAppIconsForProcess()
{
  // Clean up applications icons on task bar...
  NSDictionary *appicons  = appIconsForProcess();
  NSEnumerator *iconsIter = [appicons objectEnumerator];
  NSDictionary *iconInfo  = nil;
  
  while ((iconInfo = [iconsIter nextObject]))
  {
    UINT  appIconID = [[iconInfo objectForKey:@"AppIconID"] integerValue];

#if defined(DEBUG)
    NSLog(@"%s:removing proc ID: %d iconID: %d", __PRETTY_FUNCTION__, GetCurrentProcessId(), appIconID);
#endif

    // Remove from task bar...
    _removeApplicationIconForID(appIconID);
    
    // And destroy the icon memory...
    DestroyIcon((HICON)[[iconInfo objectForKey:@"AppIcon"] pointerValue]);
  }
}

void _removeProcessInfo()
{
  removeAppIconsForProcess();
}

UINT _addApplicationIcon(DWORD processID, const char *uuidString, HICON icon)
{
  NSValue             *iconValue   = [NSValue valueWithPointer:icon];
  NSMutableDictionary *appIcons    = appIconsForProcess();
  UINT                 appID       = -1;

#if defined(DEBUG)
  NSLog(@"%s:icon: %p iconValue: %@ appIcons: %@", __PRETTY_FUNCTION__, icon, iconValue, appIcons);
#endif

  if ([appIcons objectForKey:iconValue] != nil)
  {
    NSDictionary *appIcon = [appIcons objectForKey:iconValue];
    appID = [[appIcon objectForKey:@"AppIconID"] integerValue];

#if defined(DEBUG)
    NSLog(@"%s:re-using icon: %p with uID: %d", __PRETTY_FUNCTION__, icon, appID);
#endif
  }
  else
  {
#if defined(DEBUG)
    NSLog(@"%s:adding app icon for UUID: %p icon: %p", __PRETTY_FUNCTION__, uuidString, icon);
#endif
    
    NOTIFYICONDATA notifyData = { 0 };
    
    // Initialize basic structure...
    _setupNotifyData(notifyData);
    _setupNotifyDataIcon(notifyData, icon);
    notifyData.uID = gNotifyCnt++;

    // Adding...
    if (Shell_NotifyIcon(NIM_ADD, &notifyData) == 0)
    {
      NSLog(@"%s:adding windows notification icon failed - error: %ld", __PRETTY_FUNCTION__, GetLastError());
      return FALSE;
    }
    
    // Set version......
    if (Shell_NotifyIcon(NIM_SETVERSION, &notifyData) == 0)
    {
      NSLog(@"%s:setting windows notification version failed - error: %ld", __PRETTY_FUNCTION__, GetLastError());
      return FALSE;
    }
    
    // Add the application ID for this icon...
    appID = notifyData.uID;
    
    // Remember this information...
#if defined(DEBUG)
    NSLog(@"%s:setting up icon: %p with uID: %d", __PRETTY_FUNCTION__, icon, appID);
#endif
    NSMutableDictionary *appIcon = [NSMutableDictionary dictionary];
    NSNumber            *appIDValue = [NSNumber numberWithInteger:appID];
    [appIcon setObject:appIDValue forKey:@"AppIconID"];
    [appIcon setObject:iconValue forKey:@"AppIcon"];
    [appIcons setObject:appIcon forKey:iconValue];
  }
  
  return appID;
}

void _removeApplicationIcon(DWORD processID, HICON icon)
{
}

void _removeApplicationIconForID(UINT appIconID)
{
  NOTIFYICONDATA notifyData = { 0 };
  
  _setupNotifyData(notifyData);
  notifyData.uID = appIconID;

  // Deleting...
  if (Shell_NotifyIcon(NIM_DELETE, &notifyData) == 0)
  {
    NSLog(@"%s:deleting windows notification icon failed - error: %ld", __PRETTY_FUNCTION__, GetLastError());
  }
}

GUID guidFromUUIDString(NSString *uuidString)
{
  GUID       theGUID;
  NSArray   *components = [uuidString componentsSeparatedByString: @"-"];
  NSScanner *scanner1 = [NSScanner scannerWithString: [components objectAtIndex: 0]];
  NSScanner *scanner2 = [NSScanner scannerWithString: [components objectAtIndex: 1]];
  NSScanner *scanner3 = [NSScanner scannerWithString: [components objectAtIndex: 2]];
  NSString  *data4 = [[components objectAtIndex: 3] stringByAppendingString: [components objectAtIndex: 4]];
  NSScanner *scanner4 = [NSScanner scannerWithString: data4];

  unsigned int value;
  [scanner1 scanHexInt: (unsigned int*)&theGUID.Data1];
  [scanner2 scanHexInt: &value];
  theGUID.Data2 = (WORD) value;
  [scanner3 scanHexInt: &value];
  theGUID.Data3 = (WORD) value;

  return theGUID;
}

void _setupNotifyDataIcon(NOTIFYICONDATA &notifyData, HICON icon)
{
  // If we were not able to load the icon image...
  if (icon == NULL)
  {
    notifyData.dwInfoFlags |= NIIF_INFO;
  }
  else
  {
    // otherwise use it in the notification...
    notifyData.uFlags       |= NIF_ICON; 
    notifyData.hIcon         = icon;
  }
}

void _setupNotifyDataBalloonIcon(NOTIFYICONDATA &notifyData, HICON contentIcon)
{
#if _WIN32_WINNT >= 0x600
  // If we were given a content icon image...
  if (contentIcon != NULL)
  {
    // otherwise use it in the notification...
    notifyData.dwInfoFlags  |= NIIF_USER;
    notifyData.hBalloonIcon  = contentIcon;
  }
#endif
}

void _setupNotifyDataUUID(NOTIFYICONDATA &notifyData, const char *uuidString)
{
#if USE_GUID
  if (uuidString != NULL)
  {
    // Setup the flags and GUID...
    notifyData.uFlags   |= NIF_GUID;
    notifyData.guidItem  = guidFromUUIDString([NSString stringWithFormat:@"%s",uuidString]);
  }
#else
  // Otherwise using uID field...
  notifyData.uID = 0;
#endif
}

void _setupNotifyDataTextInfo(NOTIFYICONDATA &notifyData, const char *title, const char *informativeText)
{
  // Setup the flags...
  notifyData.uFlags = NIF_TIP | NIF_INFO | NIF_MESSAGE;

  // This text will be shown as the icon's tooltip.
  StrCpy(notifyData.szTip, informativeText);
  StrCpy(notifyData.szInfo, informativeText);
  StrCpy(notifyData.szInfoTitle, title);
}

void _setupNotifyData(NOTIFYICONDATA &notifyData)
{
  notifyData.cbSize            = sizeof(NOTIFYICONDATA);
  notifyData.uCallbackMessage  = gNotifyMsg;
  notifyData.hWnd              = gHandleWin;
  notifyData.dwState          |= NIS_SHAREDICON;

  // Load the /timeout/version???
  notifyData.uVersion = NOTIFYICON_VERSION;
}

EXPORT BOOL __cdecl sendNotification(HWND hWnd, HICON icon, SEND_NOTE_INFO_T *note)
{
#if 0 //defined(DEBUG)
  NSLog(@"%s:hWnd: %p icon: %p GUID: %p UUID: %s", __PRETTY_FUNCTION__, hWnd, icon, note->uuidString);
  NSLog(@"%s:note title: %s informativeText: %s", __PRETTY_FUNCTION__, note->title, note->informativeText);
#endif
  
  NOTIFYICONDATA notifyData = { 0 };
  _setupNotifyData(notifyData);
  _setupNotifyDataUUID(notifyData, note->uuidString);
  _setupNotifyDataIcon(notifyData, icon);
#if 0
  _setupNotifyDataBalloonIcon(notifyData, note->contentIcon);
#endif
  _setupNotifyDataTextInfo(notifyData, note->title, note->informativeText);
  
  // Need the uID for this icon...
  notifyData.uID = _addApplicationIcon(GetCurrentProcessId(), note->uuidString, icon);

  // Show the notification.
  // Modifying...
  if (Shell_NotifyIcon(NIM_MODIFY, &notifyData) == 0)
  {
    NSLog(@"%s:windows notification update failed for note title %s error: %ld", __PRETTY_FUNCTION__, note->title, GetLastError());
    return FALSE;
  }
  
  // TODO: Should we instead return a NSString HERE instead???
  return TRUE;
}

EXPORT BOOL __cdecl removeNotification(HICON icon, REMOVE_NOTE_INFO_T *noteinfo)
{
  NSAutoreleasePool *pool       = [NSAutoreleasePool new];
  NOTIFYICONDATA     notifyData = { 0 };
  BOOL               status     = TRUE;
  
#if defined(DEBUG)
  NSLog(@"%s:%d:ID %d", __PRETTY_FUNCTION__, __LINE__, noteinfo->uniqueID);
#endif
  
  _setupNotifyData(notifyData);
  //s_setupNotifyDataTextInfo(notifyData, "", "");
  notifyData.uID = _addApplicationIcon(GetCurrentProcessId(), NULL, icon);

  // Show the notification.
  // Modifying...
  if (Shell_NotifyIcon(NIM_MODIFY, &notifyData) == 0)
  {
    NSLog(@"%s:windows notification update failed for note ID %d error: %ld", __PRETTY_FUNCTION__, noteinfo->uniqueID, GetLastError());
    return FALSE;
  }

  [pool drain];
  return status;
}

#if defined(__cplusplus)
}
#endif
