#pragma once
#include "afx.h"

class ToastEventHandler;

class CToastNotification : public CObject
{
public:
  CToastNotification(ABI::Windows::UI::Notifications::IToastNotification * toastNotification, HWND _hwnd);
  ~CToastNotification();

protected:

private:
  ABI::Windows::UI::Notifications::IToastNotification *toastNotification;
  ToastEventHandler                                   *toastEventHandler;
  EventRegistrationToken activatedToken;
  EventRegistrationToken dismissedToken;
  EventRegistrationToken failedToken;
};