// stdafx.cpp : source file that includes just the standard includes
// ToastNotifications.pch will be the pre-compiled header
// stdafx.obj will contain the pre-compiled type information

#include "stdafx.h"
#include <string>
#include <sstream>

void dll_log_s(const char *function, int line, const char *format, ...)
{
  static const size_t STRBUFSIZE = 512;
  static char str[STRBUFSIZE];
  std::stringstream message;
  va_list argptr;
  va_start(argptr, format);
  sprintf_s(str, STRBUFSIZE, "%s:%d: ", function, line);
  vsprintf_s(&str[strlen(str)], STRBUFSIZE - strlen(str), format, argptr);
  OutputDebugStringA(str);
  va_end(argptr);
}

void dll_logw_s(const wchar_t *function, int line, const wchar_t *format, ...)
{
  static const size_t STRBUFSIZE = 512;
  static wchar_t wstr[STRBUFSIZE];
  va_list argptr;
  va_start(argptr, format);
  swprintf_s(wstr, STRBUFSIZE, TEXT("%s:%d: "), function, line);
  vswprintf_s(&wstr[_tcslen(wstr)], STRBUFSIZE - _tcslen(wstr), format, argptr);
  OutputDebugStringW(wstr);
  va_end(argptr);
}
