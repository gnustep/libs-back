#include "stdafx.h"
#include "ToastNotification.h"
#include "ToastEventHandler.h"

using namespace ABI::Windows::UI::Notifications;
using namespace Microsoft::WRL;

#ifdef _DEBUG
#define new DEBUG_NEW
#endif

CToastNotification::CToastNotification(IToastNotification *toastNotification, HWND _hwnd)
{
  dll_dlog("this: %p, toast: %p", this, toastNotification);

  this->toastNotification = toastNotification;

  // Register the event handlers
  ComPtr<ToastEventHandler> eventHandler(new ToastEventHandler(_hwnd, _hwnd));
  toastEventHandler = eventHandler.Get();

  HRESULT hr = toastNotification->add_Activated(eventHandler.Get(), &activatedToken);
  if (FAILED(hr))
  {
    dll_log("toast->add_Activated failed - status: %d", GetLastError());
  }
  else
  {
    dll_dlog("activatedToken: %d", activatedToken.value);
    hr = toastNotification->add_Dismissed(eventHandler.Get(), &dismissedToken);
    if (FAILED(hr))
    {
      dll_log("toast->add_Dismissed failed - status: %d", GetLastError());
    }
    else
    {
      dll_dlog("dismissedToken: %d", dismissedToken.value);
      hr = toastNotification->add_Failed(eventHandler.Get(), &failedToken);
      if (FAILED(hr))
      {
        dll_log("toast->add_Failed failed - status: %d", GetLastError());
      }
      else
      {
        dll_dlog("failedToken: %d - DONE", failedToken.value);
      }
    }
  }
}

CToastNotification::~CToastNotification()
{
  dll_dlog("this: %p toast: %p", this, toastNotification);
#if 0
  toastNotification->remove_Activated(activatedToken);
  toastNotification->remove_Dismissed(dismissedToken);
  toastNotification->remove_Failed(failedToken);
#endif
  delete toastEventHandler;
}

