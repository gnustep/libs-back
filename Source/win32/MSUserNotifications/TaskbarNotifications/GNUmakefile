ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

LIBRARY_NAME = TaskbarNotifications

TaskbarNotifications_NEEDS_GUI = NO
TaskbarNotifications_CFLAGS += -DWINVER=0x0600 -D_WIN32_IE=0x0600 -DBUILD_DLL -fms-extensions
TaskbarNotifications_OBJCFLAGS += -DWINVER=0x0600 -D_WIN32_IE=0x0600 -DBUILD_DLL -fms-extensions
TaskbarNotifications_OBJCCFLAGS += -DWINVER=0x0600 -D_WIN32_IE=0x0600 -DBUILD_DLL -fms-extensions
TaskbarNotifications_OBJC_FILES = 
TaskbarNotifications_OBJCC_FILES = TaskbarNotifications.mm
TaskbarNotifications_LIBRARIES_DEPEND_UPON += -lgnustep-gui -lgdi32
TaskbarNotifications_RESOURCE_FILES += 
 
include $(GNUSTEP_MAKEFILES)/common.make
include $(GNUSTEP_MAKEFILES)/library.make
