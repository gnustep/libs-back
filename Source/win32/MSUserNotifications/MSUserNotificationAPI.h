#pragma once

#include <string>

#if defined(__cplusplus)
extern "C" { // Only if you are using C++ rather than C
#endif

typedef struct _SEND_NOTE_INFO
{
  const char *uuidString;
  const char *title;
  const char *informativeText;
  HICON       contentIcon;
  const char *appIconPath;
} SEND_NOTE_INFO_T, *SEND_NOTE_INFO_PTR;

typedef struct _REMOVE_NOTE_INFO
{
  UINT uniqueID;
} REMOVE_NOTE_INFO_T, *REMOVE_NOTE_INFO_PTR;

#if defined(__cplusplus)
}
#endif
