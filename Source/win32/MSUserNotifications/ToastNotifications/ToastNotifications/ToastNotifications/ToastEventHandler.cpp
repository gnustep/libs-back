#include "stdafx.h"
#include "ToastEventHandler.h"

using namespace ABI::Windows::UI::Notifications;

ToastEventHandler::ToastEventHandler(_In_ HWND hToActivate, _In_ HWND hEdit) : _ref(1), _hToActivate(hToActivate), _hEdit(hEdit)
{
  dll_dlog("this: %p", this);
}

ToastEventHandler::~ToastEventHandler()
{
  dll_dlog("this: %p", this);
}

// DesktopToastActivatedEventHandler
IFACEMETHODIMP ToastEventHandler::Invoke(_In_ IToastNotification* sender, _In_ IInspectable* /* args */)
{
  dll_dlog("IToastNotePtr: %p msg: The user clicked on the toast", sender);

  BOOL succeeded = SetForegroundWindow(_hToActivate);
  if (succeeded)
  {
    LRESULT result = SendMessage(_hEdit, WM_SETTEXT, reinterpret_cast<WPARAM>(nullptr), reinterpret_cast<LPARAM>(L"The user clicked on the toast."));
    succeeded = result ? TRUE : FALSE;
  }
  return succeeded ? S_OK : E_FAIL;
}

// DesktopToastDismissedEventHandler
IFACEMETHODIMP ToastEventHandler::Invoke(_In_ IToastNotification* sender, _In_ IToastDismissedEventArgs* e)
{
    ToastDismissalReason tdr;
    HRESULT hr = e->get_Reason(&tdr);
    if (SUCCEEDED(hr))
    {
        wchar_t *outputText;
        switch (tdr)
        {
        case ToastDismissalReason_ApplicationHidden:
            outputText = L"The application hid the toast using ToastNotifier.hide()";
            break;
        case ToastDismissalReason_UserCanceled:
            outputText = L"The user dismissed this toast";
            break;
        case ToastDismissalReason_TimedOut:
            outputText = L"The toast has timed out";
            break;
        default:
            outputText = L"Toast not activated";
            break;
        }

        dll_dlogw(L"IToastNotePtr: %p msg: %s", sender, outputText);
        //notifier->RemoveFromSchedule

        LRESULT succeeded = SendMessage(_hEdit, WM_SETTEXT, reinterpret_cast<WPARAM>(nullptr), reinterpret_cast<LPARAM>(outputText));
        hr = succeeded ? S_OK : E_FAIL;
    }

    // Cleanup...
    return hr;
}

// DesktopToastFailedEventHandler
IFACEMETHODIMP ToastEventHandler::Invoke(_In_ IToastNotification* /* sender */, _In_ IToastFailedEventArgs* /* e */)
{
    LRESULT succeeded = SendMessage(_hEdit, WM_SETTEXT, reinterpret_cast<WPARAM>(nullptr), reinterpret_cast<LPARAM>(L"The toast encountered an error."));
    return succeeded ? S_OK : E_FAIL;
}

IFACEMETHODIMP_(ULONG) ToastEventHandler::AddRef()
{
  LONG value = InterlockedIncrement(&_ref);
  dll_dlog("ref: %d value: %d", _ref, value);
  return value;
}

IFACEMETHODIMP_(ULONG) ToastEventHandler::Release()
{
  ULONG l = InterlockedDecrement(&_ref);
  dll_dlog("ref: %d value: %d", _ref, l);
  if (l == 0)
  {
    dll_dlog("deleting this: %p", this);
    delete this;
  }
  return l;
}
