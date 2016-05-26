// ToastNotifications.cpp : Defines the initialization routines for the DLL.
//


#include "stdafx.h"
#include <iostream>
#include <Windows.Foundation.h>
#include <wrl\implements.h>
#include <wrl\client.h>
#include <wrl\wrappers\corewrappers.h>
#include <Windows.ui.notifications.h>
#include <strsafe.h>
#include "ToastNotifications.h"
#include "ToastEventHandler.h"
#include "../../../MSUserNotificationAPI.h"

#include <locale>
#include <codecvt>
#include <string>

using namespace Microsoft::WRL;
using namespace ABI::Windows::UI::Notifications;
using namespace ABI::Windows::Data::Xml::Dom;
using namespace Windows::Foundation;

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

//
//TODO: If this DLL is dynamically linked against the MFC DLLs,
//		any functions exported from this DLL which call into
//		MFC must have the AFX_MANAGE_STATE macro added at the
//		very beginning of the function.
//
//		For example:
//
//		extern "C" BOOL PASCAL EXPORT ExportedFunction()
//		{
//			AFX_MANAGE_STATE(AfxGetStaticModuleState());
//			// normal function body here
//		}
//
//		It is very important that this macro appear in each
//		function, prior to any calls into MFC.  This means that
//		it must appear as the first statement within the 
//		function, even before any object variable declarations
//		as their constructors may generate calls into the MFC
//		DLL.
//
//		Please see MFC Technical Notes 33 and 58 for additional
//		details.
//

// CToastNotificationsApp

BEGIN_MESSAGE_MAP(CToastNotificationsApp, CWinApp)
END_MESSAGE_MAP()

// CToastNotificationsApp construction
CToastNotificationsApp::CToastNotificationsApp()
{
  // TODO: add construction code here,
  // Place all significant initialization in InitInstance
  dll_dlog("");
}

CToastNotificationsApp::~CToastNotificationsApp()
{
  dll_dlog("");
}

// The one and only CToastNotificationsApp object

CToastNotificationsApp theApp;


// CToastNotificationsApp initialization

BOOL CToastNotificationsApp::InitInstance()
{
  CWinApp::InitInstance();

  return TRUE;
}
// In order to display toasts, a desktop application must have a shortcut on the Start menu.
// Also, an AppUserModelID must be set on that shortcut.
// The shortcut should be created as part of the installer. The following code shows how to create
// a shortcut and assign an AppUserModelID using Windows APIs. You must download and include the 
// Windows API Code Pack for Microsoft .NET Framework for this code to function
//
// Included in this project is a wxs file that be used with the WiX toolkit
// to make an installer that creates the necessary shortcut. One or the other should be used.

HRESULT CToastNotificationsApp::TryCreateShortcut()
{
  wchar_t shortcutPath[MAX_PATH];
  DWORD charWritten = GetEnvironmentVariable(L"APPDATA", shortcutPath, MAX_PATH);
  HRESULT hr = charWritten > 0 ? S_OK : E_INVALIDARG;
  dll_logw(shortcutPath);

  if (SUCCEEDED(hr))
  {
    errno_t concatError = wcscat_s(shortcutPath, ARRAYSIZE(shortcutPath), L"\\Microsoft\\Windows\\Start Menu\\Programs\\ToastNotifications.lnk");
    hr = concatError == 0 ? S_OK : E_INVALIDARG;
    if (SUCCEEDED(hr))
    {
      DWORD attributes = GetFileAttributes(shortcutPath);
      bool fileExists = attributes < 0xFFFFFFF;

      if (!fileExists)
      {
        hr = InstallShortcut(shortcutPath);
      }
      else
      {
        hr = S_FALSE;
      }
    }
  }
  return hr;
}

// Install the shortcut
HRESULT CToastNotificationsApp::InstallShortcut(_In_z_ wchar_t *shortcutPath)
{
  dll_logw(shortcutPath);
  wchar_t exePath[MAX_PATH];

  DWORD charWritten = GetModuleFileNameEx(GetCurrentProcess(), nullptr, exePath, ARRAYSIZE(exePath));
  dll_logw(exePath);

  HRESULT hr = charWritten > 0 ? S_OK : E_FAIL;

  if (SUCCEEDED(hr))
  {
    ComPtr<IShellLink> shellLink;
    hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&shellLink));

    if (SUCCEEDED(hr))
    {
      hr = shellLink->SetPath(exePath);
      if (SUCCEEDED(hr))
      {
        hr = shellLink->SetArguments(L"");
        if (SUCCEEDED(hr))
        {
          ComPtr<IPropertyStore> propertyStore;

          hr = shellLink.As(&propertyStore);
          if (SUCCEEDED(hr))
          {
            PROPVARIANT appIdPropVar;
            hr = InitPropVariantFromString(AppId, &appIdPropVar);
            if (SUCCEEDED(hr))
            {
              hr = propertyStore->SetValue(PKEY_AppUserModel_ID, appIdPropVar);
              dll_log("propertyStore result: %d", hr);
              if (SUCCEEDED(hr))
              {
                hr = propertyStore->Commit();
                if (SUCCEEDED(hr))
                {
                  ComPtr<IPersistFile> persistFile;
                  hr = shellLink.As(&persistFile);
                  if (SUCCEEDED(hr))
                  {
                    hr = persistFile->Save(shortcutPath, TRUE);
                  }
                }
              }
              PropVariantClear(&appIdPropVar);
            }
          }
        }
      }
    }
  }
  return hr;
}

// Create the toast XML from a template
HRESULT CToastNotificationsApp::CreateToastXml(_In_ IToastNotificationManagerStatics *toastManager, _Outptr_ IXmlDocument** inputXml, wchar_t* notificationTitle, wchar_t* notificationDescription, wchar_t* imagePath)
{
  dll_dlogw(L"note title: %s info %s imagePath: %s", notificationTitle, notificationDescription, imagePath);

  HRESULT hr = toastManager->GetTemplateContent(ToastTemplateType_ToastImageAndText04, inputXml);

  if (FAILED(hr))
  {
    dll_log("GetTemplateContent failed - status: %d", GetLastError());
  }
  else
  {
    // ONLY supporting .png files right now...
    std::wstring filePath = imagePath;
    if ((filePath.find_last_of(L".") == std::wstring::npos) ||
        (filePath.substr(filePath.find_last_of(L".") + 1) != L"png"))
    {
      // Replace with proxy image...
      imagePath = L"toastImageAndText.png";
    }

    // Get full path to image...
    imagePath = _wfullpath(nullptr, imagePath, MAX_PATH);

    dll_logw(TEXT("loading application image file: %s"), imagePath);
    hr = imagePath != nullptr ? S_OK : HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);

    if (FAILED(hr))
    {
      dll_log("imagePath failed - status: %d", GetLastError());
    }
    else
    {
      hr = SetImageSrc(imagePath, *inputXml);

      if (FAILED(hr))
      {
        dll_log("SetImageSrc failed - status: %d", GetLastError());
      }
      else
      {
        wchar_t* textValues[] =
        {
          notificationTitle,
          notificationDescription,
          L"      "
        };

        UINT32 textLengths[] = { wcslen(notificationTitle), wcslen(notificationDescription), 6 };
        hr = SetTextValues(textValues, 3, textLengths, *inputXml);
      }
    }
  }
  return hr;
}

HRESULT CToastNotificationsApp::SetTextValues(_In_reads_(textValuesCount) wchar_t **textValues, _In_ UINT32 textValuesCount, _In_reads_(textValuesCount) UINT32 *textValuesLengths, _In_ IXmlDocument *toastXml)
{
  HRESULT hr = textValues != nullptr && textValuesCount > 0 ? S_OK : E_INVALIDARG;
  if (FAILED(hr))
  {
    dll_log("text values/count mismatched - textValues: %p count: %d", textValues, textValuesCount);
  }
  else
  {
    ComPtr<IXmlNodeList> nodeList;

    hr = toastXml->GetElementsByTagName(StringReferenceWrapper(L"text").Get(), &nodeList);
    if (FAILED(hr))
    {
      dll_log("GetElementsByTagName failed - status: %d", GetLastError());
    }
    else
    {
      UINT32 nodeListLength;
      hr = nodeList->get_Length(&nodeListLength);

      if (FAILED(hr))
      {
        dll_log("nodeList->get_Length failed - status: %d", GetLastError());
      }
      else
      {
        hr = textValuesCount <= nodeListLength ? S_OK : E_INVALIDARG;

        if (FAILED(hr))
        {
          dll_log("textValuesCount > nodeListLength failed");
        }
        else
        {
          for (UINT32 i = 0; i < textValuesCount; i++)
          {
            ComPtr<IXmlNode> textNode;
            hr = nodeList->Item(i, &textNode);

            if (FAILED(hr))
            {
              dll_log("textValuesCount > nodeListLength failed");
            }
            else
            {
              hr = SetNodeValueString(StringReferenceWrapper(textValues[i], textValuesLengths[i]).Get(), textNode.Get(), toastXml);
              if (FAILED(hr))
              {
                dll_log("SetNodeValueString failed - value: %s length: %d", textValues[i], textValuesLengths[i]);
                break;
              }
            }
          }
        }
      }
    }
  }

  return hr;
}

HRESULT CToastNotificationsApp::SetImageSrc(_In_z_ wchar_t *imagePath, _In_ IXmlDocument *toastXml)
{
  wchar_t imageSrc[MAX_PATH] = L"file:///";
  HRESULT hr = StringCchCat(imageSrc, ARRAYSIZE(imageSrc), imagePath);
  if (FAILED(hr))
  {
    dll_logw(TEXT("StringCchCat failed - imagePath: %s"), imagePath);
  }
  else
  {
    ComPtr<IXmlNodeList> nodeList;
    hr = toastXml->GetElementsByTagName(StringReferenceWrapper(L"image").Get(), &nodeList);
    if (FAILED(hr))
    {
      dll_logw(TEXT("GetElementsByTagName failed for: 'image'"));
    }
    else
    {
      ComPtr<IXmlNode> imageNode;
      hr = nodeList->Item(0, &imageNode);
      if (FAILED(hr))
      {
        dll_logw(TEXT("nodeList->Item failed for: 'image'"));
      }
      else
      {
        ComPtr<IXmlNamedNodeMap> attributes;

        hr = imageNode->get_Attributes(&attributes);
        if (FAILED(hr))
        {
          dll_logw(TEXT("imageNode->get_Attributes failed for: 'image'"));
        }
        else
        {
          ComPtr<IXmlNode> srcAttribute;

          hr = attributes->GetNamedItem(StringReferenceWrapper(L"src").Get(), &srcAttribute);
          if (FAILED(hr))
          {
            dll_logw(TEXT("attributes->GetNamedItem failed for: 'src'"));
          }
          else
          {
            hr = SetNodeValueString(StringReferenceWrapper(imageSrc).Get(), srcAttribute.Get(), toastXml);
          }
        }
      }
    }
  }

  return hr;
}

HRESULT CToastNotificationsApp::SetNodeValueString(_In_ HSTRING inputString, _In_ IXmlNode *node, _In_ IXmlDocument *xml)
{
  ComPtr<IXmlText> inputText;

  HRESULT hr = xml->CreateTextNode(inputString, &inputText);

  if (FAILED(hr))
  {
    dll_log("CreateTextNode failed")
  }
  else
  {
    ComPtr<IXmlNode> inputTextNode;

    hr = inputText.As(&inputTextNode);
    if (FAILED(hr))
    {
      dll_log("inputText failed")
    }
    else
    {
      ComPtr<IXmlNode> pAppendedChild;
      hr = node->AppendChild(inputTextNode.Get(), &pAppendedChild);
      if (FAILED(hr))
      {
        dll_log("AppendChild failed");
      }
    }
  }

  return hr;
}

HRESULT CToastNotificationsApp::CreateToast(_In_ IToastNotificationManagerStatics *toastManager, _In_ IXmlDocument *xml, HWND hWnd)
{
  _hwnd = hWnd;
  ComPtr<IToastNotifier> notifier;
  HRESULT hr = toastManager->CreateToastNotifierWithId(StringReferenceWrapper(AppId).Get(), &notifier);
  if (FAILED(hr))
  {
    dll_log("error creating toast - status: %d", GetLastError());
  }
  else
  {
    ComPtr<IToastNotificationFactory> factory;
    hr = GetActivationFactory(StringReferenceWrapper(RuntimeClass_Windows_UI_Notifications_ToastNotification).Get(), &factory);
    if (FAILED(hr))
    {
      dll_log("GetActivationFactory failed - status: %d", GetLastError());
    }
    else
    {
      ComPtr<IToastNotification> toast;
      hr = factory->CreateToastNotification(xml, &toast);
      if (FAILED(hr))
      {
        dll_log("factory->CreateToastNotification failed - status: %d", GetLastError());
      }
      else
      {
        // Register the event handlers
        EventRegistrationToken activatedToken, dismissedToken, failedToken;
        ComPtr<ToastEventHandler> eventHandler(new ToastEventHandler(_hwnd, _hwnd));

        toast->add_Activated(eventHandler.Get(), &activatedToken);
        if (FAILED(hr))
        {
          dll_log("toast->add_Activated failed - status: %d", GetLastError());
        }
        else
        {
          hr = toast->add_Dismissed(eventHandler.Get(), &dismissedToken);
          if (FAILED(hr))
          {
            dll_log("toast->add_Dismissed failed - status: %d", GetLastError());
          }
          else
          {
            hr = toast->add_Failed(eventHandler.Get(), &failedToken);
            if (FAILED(hr))
            {
              dll_log("toast->add_Failed failed - status: %d", GetLastError());
            }
            else
            {
              hr = notifier->Show(toast.Get());
            }
          }
        }
      }
    }
  }

  return hr;
}

HRESULT CToastNotificationsApp::DisplayToast(HWND hWnd, wchar_t* notificationTitle, wchar_t* notificationDescription, wchar_t* imagePath)
{
  dll_dlogw(L"note title: %s infoText: %s imagePath: %s", notificationTitle, notificationTitle, imagePath);

  ComPtr<IToastNotificationManagerStatics> toastStatics;

  HRESULT hr = GetActivationFactory(StringReferenceWrapper(RuntimeClass_Windows_UI_Notifications_ToastNotificationManager).Get(), &toastStatics);

  if (FAILED(hr))
  {
    dll_log("GetActivationFactory failed for %s", StringReferenceWrapper(RuntimeClass_Windows_UI_Notifications_ToastNotificationManager).Get());
  }
  else
  {
    ComPtr<IXmlDocument> toastXml;
    hr = CreateToastXml(toastStatics.Get(), &toastXml, notificationTitle, notificationDescription, imagePath);

    if (FAILED(hr))
    {
      dll_log("CreateToastXml failed");
    }
    else
    {
      hr = CreateToast(toastStatics.Get(), toastXml.Get(), hWnd);
      if (FAILED(hr))
      {
        dll_log("CreateToast failed");
      }
    }
    return hr;
  }

  return 1;
}

extern "C" EXPORT BOOL __cdecl sendNotification(HWND hWnd, HICON icon, SEND_NOTE_INFO_T *noteInfo)
{
  AFX_MANAGE_STATE(AfxGetStaticModuleState());
  dll_dlog("note %p", noteInfo);

  dll_dlog("note title: %s", noteInfo->title);
  dll_dlog("note infoText: %s", noteInfo->informativeText);
  dll_dlog("note contentPath: %s", noteInfo->appIconPath);
  dll_dlog("note UUID: %s", noteInfo->uuidString);

  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
  std::wstring title       = converter.from_bytes(noteInfo->title);
  std::wstring description = converter.from_bytes(noteInfo->informativeText);
  std::wstring imagePath   = TEXT("");

  // Convert content image path if available...
  if (noteInfo->appIconPath != NULL)
    imagePath = converter.from_bytes(noteInfo->appIconPath);

  dll_dlogw(TEXT("note title: %s infoText: %s imagePath: %s"), title.c_str(), description.c_str(), imagePath.c_str());

  HRESULT hr = theApp.DisplayToast(hWnd, const_cast<wchar_t*>(title.c_str()), const_cast<wchar_t*>(description.c_str()), const_cast<wchar_t*>(imagePath.c_str()));

  dll_dlog("HR %d", hr);

  if (SUCCEEDED(hr))
  {
    return TRUE;
  }

  return FALSE;
}

extern "C" EXPORT BOOL __cdecl removeNotification(HICON icon, REMOVE_NOTE_INFO_T *noteinfo)
{
  AFX_MANAGE_STATE(AfxGetStaticModuleState());
  dll_log("note %p uniqueID: %d", noteinfo, noteinfo->uniqueID);
  return FALSE;
}
