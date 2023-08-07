#include <Foundation/NSString.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSUserNotification.h>
#include <Foundation/NSUUID.h>
#include <Foundation/NSValue.h>
#include <../MSUserNotification.h>

#include <windows.h>

#ifdef BUILD_DLL
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" { // Only if you are using C++ rather than C
#endif
static HANDLE gHandleDLL = NULL;

// Need to capture the DLL instance handle....
BOOL WINAPI DllMain(HANDLE hinstDLL, DWORD dwReason, LPVOID lpvReserved)
{
  switch (dwReason)
  {
    case DLL_PROCESS_ATTACH: // Do process attach specific stuff here...
      // Save the DLL instance handle...
      gHandleDLL = hinstDLL;
      break;
      
    case DLL_PROCESS_DETACH: // Do process attach specific stuff here...
      break;
      
    case DLL_THREAD_ATTACH: // Do thread attach specific stuff here...
        break;

    case DLL_THREAD_DETACH: // Do thread detach specific stuff here...
        break;
  }
  return TRUE;
}

EXPORT NSString * __cdecl sendNotification(HWND hWnd, NSMutableString *theGUID, HICON icon, NSUserNotification *note)
{
  NSString *uuid = [[NSUUID UUID] UUIDString];
  NSLog(@"%s:UUID: %@", __PRETTY_FUNCTION__, uuid);
  NSArray *components = [uuid componentsSeparatedByString: @"-"];
  NSLog(@"%s:components: %@", __PRETTY_FUNCTION__, components);
  GUID myGUID;
  NSString *data4 = [[components objectAtIndex: 3] stringByAppendingString: [components objectAtIndex: 4]];
  myGUID.Data1 = [[components objectAtIndex: 0] longLongValue];
  myGUID.Data2 = [[components objectAtIndex: 1] integerValue];
  myGUID.Data3 = [[components objectAtIndex: 2] integerValue];
  int index;
  for (index = 0; index < 8; index++)
    myGUID.Data4[index] = [data4 characterAtIndex: index];
    
  // TODO: Add your Toast code here...
  
  // IF ERROR DO NOT RETURN UUID...
  if (true)
    return nil;
    
  // TOD: Return status...
  return uuid;
}

#if defined(__cplusplus)
}
#endif
