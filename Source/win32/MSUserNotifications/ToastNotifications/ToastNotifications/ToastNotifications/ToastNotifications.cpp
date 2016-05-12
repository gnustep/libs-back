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
}

CToastNotificationsApp::~CToastNotificationsApp()
{

#if defined(DEBUG) 
  static char str[512];
  sprintf_s(str, "%s:%d: DONE", __FUNCTION__, __LINE__);
  OutputDebugStringA(str);
#endif
}

// The one and only CToastNotificationsApp object

CToastNotificationsApp theApp;


// CToastNotificationsApp initialization

BOOL CToastNotificationsApp::InitInstance()
{
	CWinApp::InitInstance();

	return TRUE;
}

// Create the toast XML from a template
HRESULT CToastNotificationsApp::CreateToastXml(_In_ IToastNotificationManagerStatics *toastManager, _Outptr_ IXmlDocument** inputXml, wchar_t* notificationTitle, wchar_t* notificationDescription, wchar_t* imagePath)
{
#if defined(DEBUG) 
	int number = 600;
	char str[256];
	sprintf_s(str, "inside create toast xml and calling GetTemplateContent %d\n", number);
	OutputDebugStringA(str);
#endif

	HRESULT hr = toastManager->GetTemplateContent(ToastTemplateType_ToastImageAndText04, inputXml);

#if defined(DEBUG)
	sprintf_s(str, "done with  GetTemplateContent %d\n", number);
	OutputDebugStringA(str);
#endif

	if (SUCCEEDED(hr))
	{

#if defined(DEBUG)
		sprintf_s(str, "OK inside\n");
		OutputDebugStringA(str);
#endif
		
		//wchar_t *imagePath = _wfullpath(nullptr, L"toastImageAndText.png", MAX_PATH);

#if defined(DEBUG)
    static wchar_t wstr[512];
    swprintf_s(wstr, TEXT("%s:%d:imagePath: %s"), TEXT(__FUNCTION__), __LINE__, imagePath);
    OutputDebugStringW(wstr);
#endif
    
    hr = imagePath != nullptr ? S_OK : HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
		
		if (SUCCEEDED(hr))
		{
		
#if defined(DEBUG)
			sprintf_s(str, "got hte image path and now setting its source");
			OutputDebugStringA(str);
#endif

			hr = SetImageSrc(imagePath, *inputXml);

			if (SUCCEEDED(hr))
			{

#if defined(DEBUG)
				sprintf_s(str, "done setting the source");
				OutputDebugStringA(str);
#endif
		
				wchar_t* textValues[] = {
					notificationTitle,
					notificationDescription,
					L"      "
				};

				UINT32 textLengths[] = { wcslen(notificationTitle), wcslen(notificationDescription), 6 };
				hr = SetTextValues(textValues, 3, textLengths, *inputXml);

			}
		}
		else {

#if defined(DEBUG)
			sprintf_s(str, "AHh!with imagepath %ld\n", GetLastError());
			OutputDebugStringA(str);
#endif

		}
	}
	else {

#if defined(DEBUG)
		sprintf_s(str, "AHh! Shoot, done with  GetTemplateContent %ld\n", GetLastError());
		OutputDebugStringA(str);
#endif

	}
	return hr;
}

HRESULT CToastNotificationsApp::SetTextValues(_In_reads_(textValuesCount) wchar_t **textValues, _In_ UINT32 textValuesCount, _In_reads_(textValuesCount) UINT32 *textValuesLengths, _In_ IXmlDocument *toastXml)
{

#if defined(DEBUG)
	int number = 600;
	char str[256];
	sprintf_s(str, "inside set text values %d\n", number);
	OutputDebugStringA(str);
#endif

	HRESULT hr = textValues != nullptr && textValuesCount > 0 ? S_OK : E_INVALIDARG;
	if (SUCCEEDED(hr))
	{
		ComPtr<IXmlNodeList> nodeList;

#if defined(DEBUG)
		sprintf_s(str, "before calling get tag names %d\n", number);
		OutputDebugStringA(str);
#endif

		hr = toastXml->GetElementsByTagName(StringReferenceWrapper(L"text").Get(), &nodeList);
		if (SUCCEEDED(hr))
		{

#if defined(DEBUG)
			sprintf_s(str, "inside succeeded %d\n", number);
			OutputDebugStringA(str);
#endif

			UINT32 nodeListLength;
			hr = nodeList->get_Length(&nodeListLength);

			if (SUCCEEDED(hr))
			{

#if defined(DEBUG)
				sprintf_s(str, "inside got length %d\n", number);
				OutputDebugStringA(str);
#endif

				hr = textValuesCount <= nodeListLength ? S_OK : E_INVALIDARG;

				if (SUCCEEDED(hr))
				{

#if defined(DEBUG)
					sprintf_s(str, "insidenode list length %d\n", number);
					OutputDebugStringA(str);
#endif

					for (UINT32 i = 0; i < textValuesCount; i++)
					{
						ComPtr<IXmlNode> textNode;
						hr = nodeList->Item(i, &textNode);

						if (SUCCEEDED(hr))
						{

#if defined(DEBUG)
							sprintf_s(str, "before calling node value string %d\n", number);
							OutputDebugStringA(str);
#endif

							hr = SetNodeValueString(StringReferenceWrapper(textValues[i], textValuesLengths[i]).Get(), textNode.Get(), toastXml);
						}
					}
				}
			}
		}
	}

	//int number = 600;
	//char str[256];

#if defined(DEBUG)
	sprintf_s(str, "returning from set text values %d\n", number);
	OutputDebugStringA(str);
#endif

	return hr;
}

HRESULT CToastNotificationsApp::SetImageSrc(_In_z_ wchar_t *imagePath, _In_ IXmlDocument *toastXml)
{
	wchar_t imageSrc[MAX_PATH] = L"file:///";
	HRESULT hr = StringCchCat(imageSrc, ARRAYSIZE(imageSrc), imagePath);
	if (SUCCEEDED(hr))
	{
		ComPtr<IXmlNodeList> nodeList;
		hr = toastXml->GetElementsByTagName(StringReferenceWrapper(L"image").Get(), &nodeList);
		if (SUCCEEDED(hr))
		{
			ComPtr<IXmlNode> imageNode;
			hr = nodeList->Item(0, &imageNode);
			if (SUCCEEDED(hr))
			{
				ComPtr<IXmlNamedNodeMap> attributes;

				hr = imageNode->get_Attributes(&attributes);
				if (SUCCEEDED(hr))
				{
					ComPtr<IXmlNode> srcAttribute;

					hr = attributes->GetNamedItem(StringReferenceWrapper(L"src").Get(), &srcAttribute);
					if (SUCCEEDED(hr))
					{
#if defined(DEBUG)
            static char str[256];
            sprintf_s(str, "setting image source %d", hr);
            OutputDebugStringA(str);
#endif
            hr = SetNodeValueString(StringReferenceWrapper(imageSrc).Get(), srcAttribute.Get(), toastXml);
					}
				}
			}
		}
	}

#if defined(DEBUG)
	int number = 600;
	char str[256];
	sprintf_s(str, "returning from set image source %d\n", number);
	OutputDebugStringA(str);
#endif

	return hr;
}

HRESULT CToastNotificationsApp::SetNodeValueString(_In_ HSTRING inputString, _In_ IXmlNode *node, _In_ IXmlDocument *xml)
{

#if defined(DEBUG)
	int number = 600;
	char str[256];
	sprintf_s(str, "inside node value string %d\n", number);
	OutputDebugStringA(str);
#endif

	ComPtr<IXmlText> inputText;

	HRESULT hr = xml->CreateTextNode(inputString, &inputText);

	if (SUCCEEDED(hr))
	{

#if defined(DEBUG)
		sprintf_s(str, "done create node text %d\n", number);
		OutputDebugStringA(str);
#endif

		ComPtr<IXmlNode> inputTextNode;

		hr = inputText.As(&inputTextNode);
		if (SUCCEEDED(hr))
		{
			ComPtr<IXmlNode> pAppendedChild;
			hr = node->AppendChild(inputTextNode.Get(), &pAppendedChild);
		}
	}

#if defined(DEBUG)
	number = 600;
	sprintf_s(str, "returning from set node value string %d\n", number);
	OutputDebugStringA(str);
#endif

	return hr;
}

HRESULT CToastNotificationsApp::CreateToast(_In_ IToastNotificationManagerStatics *toastManager, _In_ IXmlDocument *xml, HWND hWnd)
{
	_hwnd = hWnd;
	ComPtr<IToastNotifier> notifier;
	HRESULT hr = toastManager->CreateToastNotifierWithId(StringReferenceWrapper(AppId).Get(), &notifier);
	if (SUCCEEDED(hr))
	{
		ComPtr<IToastNotificationFactory> factory;
		hr = GetActivationFactory(StringReferenceWrapper(RuntimeClass_Windows_UI_Notifications_ToastNotification).Get(), &factory);
		if (SUCCEEDED(hr))
		{
			ComPtr<IToastNotification> toast;
			hr = factory->CreateToastNotification(xml, &toast);
			if (SUCCEEDED(hr))
			{
				// Register the event handlers
				EventRegistrationToken activatedToken, dismissedToken, failedToken;
				ComPtr<ToastEventHandler> eventHandler(new ToastEventHandler(_hwnd, _hwnd));

				toast->add_Activated(eventHandler.Get(), &activatedToken);
				if (SUCCEEDED(hr))
				{
					hr = toast->add_Dismissed(eventHandler.Get(), &dismissedToken);
					if (SUCCEEDED(hr))
					{
						hr = toast->add_Failed(eventHandler.Get(), &failedToken);
						if (SUCCEEDED(hr))
						{
							hr = notifier->Show(toast.Get());
						}
					}
				}
			}

		}
	}

#if defined(DEBUG)
	static wchar_t str[256];
  swprintf_s(str, TEXT("returning from create toast"));
	OutputDebugString(str);
#endif

	return hr;
}

HRESULT CToastNotificationsApp::DisplayToast(HWND hWnd, wchar_t* notificationTitle, wchar_t* notificationDescription, wchar_t* imagePath)
{

#if defined(DEBUG)
	static wchar_t str[512];
	swprintf_s(str, L"%s:%d: note title: %su infoText: %su", TEXT(__FUNCTION__), __LINE__, notificationTitle, notificationTitle, imagePath);
  OutputDebugString(str);
#endif

	ComPtr<IToastNotificationManagerStatics> toastStatics;

	HRESULT hr = GetActivationFactory(StringReferenceWrapper(RuntimeClass_Windows_UI_Notifications_ToastNotificationManager).Get(), &toastStatics);

	if (SUCCEEDED(hr))
	{
		ComPtr<IXmlDocument> toastXml;
		hr = CreateToastXml(toastStatics.Get(), &toastXml, notificationTitle, notificationDescription, imagePath);

		if (SUCCEEDED(hr))
		{

#if defined(DEBUG)
			char str[256];
			sprintf_s(str, "done with toast xml and calling the toast method %d\n");
			OutputDebugStringA(str);
#endif

			hr = CreateToast(toastStatics.Get(), toastXml.Get(), hWnd);
		}
		return hr;
	}
	else
		
		return 1;
}

extern "C" EXPORT BOOL __cdecl sendNotification(HWND hWnd, HICON icon, SEND_NOTE_INFO_T *noteInfo)
{
		//NSLog(@"%s:hWnd: %p icon: %p GUID: %p note: %p", __PRETTY_FUNCTION__, hWnd, icon, note);

#if defined(DEBUG)
	  static char str[512];
	  sprintf_s(str, "%s:%d: note %p", __FUNCTION__, __LINE__, noteInfo);
	  OutputDebugStringA(str);
    sprintf_s(str, "%s:%d: noteInfo ptrs: title: %p infoText: %p imagePath: %p", __FUNCTION__, __LINE__, noteInfo->title, noteInfo->informativeText, noteInfo->appIconPath);
	  OutputDebugStringA(str);
#endif

#if defined(DEBUG)
	  sprintf_s(str, "%s:%d: note title: %s", __FUNCTION__, __LINE__, noteInfo->title);
	  OutputDebugStringA(str);
    sprintf_s(str, "%s:%d: note infoText: %s", __FUNCTION__, __LINE__, noteInfo->informativeText);
    OutputDebugStringA(str);
    sprintf_s(str, "%s:%d: note contentPath: %s", __FUNCTION__, __LINE__, noteInfo->appIconPath);
    OutputDebugStringA(str);
    sprintf_s(str, "%s:%d: note UUID: %s", __FUNCTION__, __LINE__, noteInfo->uuidString);
	  OutputDebugStringA(str);
#endif

		std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
		std::wstring title = converter.from_bytes(noteInfo->title);
		std::wstring description = converter.from_bytes(noteInfo->informativeText);
    std::wstring imagePath = TEXT("");
    
    // Convert content image path if available...
    if (noteInfo->appIconPath != NULL)
      imagePath = converter.from_bytes(noteInfo->appIconPath);

#if defined(DEBUG)
		static wchar_t wstr[512];
    swprintf_s(wstr, TEXT("%s:%d: note title: %s infoText: %s imagePath: %s"), TEXT(__FUNCTION__), __LINE__, title.c_str(), description.c_str(), imagePath.c_str());
		OutputDebugString(wstr);
#endif

#if 0
		CToastNotificationsApp *app = new CToastNotificationsApp();
		HRESULT hr = app->DisplayToast(hWnd, const_cast<wchar_t*>(title.c_str()), const_cast<wchar_t*>(description.c_str()));
#else
    HRESULT hr = theApp.DisplayToast(hWnd, const_cast<wchar_t*>(title.c_str()), const_cast<wchar_t*>(description.c_str()), const_cast<wchar_t*>(imagePath.c_str()));
#endif

#if defined(DEBUG)
		sprintf_s(str, "%s:%d: HR %d", __FUNCTION__, __LINE__, hr);
		OutputDebugStringA(str);
#endif

	if (SUCCEEDED(hr))
	{
		return TRUE;
	}

	return FALSE;
}

extern "C" EXPORT BOOL __cdecl removeNotification(HICON icon, REMOVE_NOTE_INFO_T *noteinfo)
{
#if 1 //defined(DEBUG)
  static char str[512];
  sprintf_s(str, "%s:%d: note %p uniqueID: %d", __FUNCTION__, __LINE__, noteinfo, noteinfo->uniqueID);
  OutputDebugStringA(str);
#endif
  return FALSE;
}
