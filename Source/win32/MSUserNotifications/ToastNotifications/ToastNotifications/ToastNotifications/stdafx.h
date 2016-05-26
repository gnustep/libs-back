// stdafx.h : include file for standard system include files,
// or project specific include files that are used frequently, but
// are changed infrequently

#pragma once
#ifdef BUILD_DLL
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __declspec(dllimport)
#endif

#ifndef VC_EXTRALEAN
#define VC_EXTRALEAN            // Exclude rarely-used stuff from Windows headers
#endif

#include "targetver.h"

#define _ATL_CSTRING_EXPLICIT_CONSTRUCTORS      // some CString constructors will be explicit

#include <afxwin.h>         // MFC core and standard components
#include <afxext.h>         // MFC extensions

#ifndef _AFX_NO_OLE_SUPPORT
#include <afxole.h>         // MFC OLE classes
#include <afxodlgs.h>       // MFC OLE dialog classes
#include <afxdisp.h>        // MFC Automation classes
#endif // _AFX_NO_OLE_SUPPORT

#ifndef _AFX_NO_DB_SUPPORT
#include <afxdb.h>                      // MFC ODBC database classes
#endif // _AFX_NO_DB_SUPPORT

#ifndef _AFX_NO_DAO_SUPPORT
#include <afxdao.h>                     // MFC DAO database classes
#endif // _AFX_NO_DAO_SUPPORT

#ifndef _AFX_NO_OLE_SUPPORT
#include <afxdtctl.h>           // MFC support for Internet Explorer 4 Common Controls
#endif
#ifndef _AFX_NO_AFXCMN_SUPPORT
#include <afxcmn.h>                     // MFC support for Windows Common Controls
#endif // _AFX_NO_AFXCMN_SUPPORT

#pragma once
#pragma comment(linker,"\"/manifestdependency:type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")


#include <SDKDDKVer.h>

// Windows Header Files:
#include <Windows.h>
#include <sal.h>
#include <Psapi.h>
#include <strsafe.h>
#include <ObjBase.h>
#include <ShObjIdl.h>
#include <propvarutil.h>
#include <functiondiscoverykeys.h>
#include <intsafe.h>
#include <guiddef.h>

#include <roapi.h>
#include <wrl\client.h>
#include <wrl\implements.h>
#include <windows.ui.notifications.h>
#include "StringReferenceWrapper.h"

// Log function prototypes...
void dll_log_s(const char *function, int line, const char *format, ...);
void dll_logw_s(const wchar_t *function, int line, const wchar_t *format, ...);
#define dll_log(f,...)  dll_log_s(__FUNCTION__,__LINE__,f,##__VA_ARGS__);
#define dll_logw(f,...) dll_logw_s(TEXT(__FUNCTION__), __LINE__,f,##__VA_ARGS__);
#if defined(DEBUG)
#define dll_dlog(f,...)  dll_log_s(__FUNCTION__,__LINE__,f,##__VA_ARGS__);
#define dll_dlogw(f,...) dll_logw_s(TEXT(__FUNCTION__), __LINE__,f,##__VA_ARGS__);
#else
#define dll_dlog(f,...)  {}
#define dll_dlogw(f,...) {}
#endif
