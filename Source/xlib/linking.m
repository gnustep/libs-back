
#include "xlib/XGContext.h"

//extern void __objc_xgps_gsbackend_linking (void);

extern void __objc_xgcontextwindow_linking (void);
extern void __objc_xgcontextevent_linking (void);


void __objc_xgps_linking(void)
{
  //__objc_xgps_gsbackend_linking();
  __objc_xgcontextwindow_linking();
  __objc_xgcontextevent_linking();
}
