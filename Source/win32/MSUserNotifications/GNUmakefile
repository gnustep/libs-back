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

BUNDLE_NAME = NSUserNotification

# Get common definitions - needed for base version information
-include $(GNUSTEP_MAKEFILES)/common.make

NSUserNotification_NEEDS_GUI = NO
NSUserNotification_CFLAGS += -DWINVER=0x0600 -D_WIN32_IE=0x0600 -DBUILD_DLL -fms-extensions
NSUserNotification_OBJCFLAGS += -DWINVER=0x0600 -D_WIN32_IE=0x0600 -DBUILD_DLL -fms-extensions
NSUserNotification_OBJCCFLAGS += -DWINVER=0x0600 -D_WIN32_IE=0x0600 -DBUILD_DLL -fms-extensions
NSUserNotification_PRINCIPAL_CLASS = MSUserNotificationCenter
NSUserNotification_OBJC_FILES =
NSUserNotification_OBJCC_FILES = MSUserNotification.mm
NSUserNotification_BUNDLE_LIBS = -lgnustep-gui -lgdi32 -lgdiplus
#NSUserNotification_LIBS = stdc++
#NSUserNotification_INCLUDE_DIRS += \
#  -I/mingw/lib/gcc/mingw32/4.8.1/include/c++/mingw32 \
#  -I/mingw/lib/gcc/mingw32/4.8.1/include/c++
NSUserNotification_RESOURCE_FILES = \
  Images/GNUstep.png \
  ToastNotifications/obj/ToastNotifications-0.dll \
  TaskbarNotifications/obj/TaskbarNotifications-0.dll
#NSUserNotification_SUBPROJECTS = ToastNotifications TaskbarNotifications
SUBPROJECTS = ToastNotifications TaskbarNotifications

# Set this to the ROOT DIRECTORY of your GNUstep build that contains the 'core' directory...
ifdef GNUSTEP_BASE_MAJOR_VERSION
  ifdef GNUSTEP_BASE_MINOR_VERSION
    BASE_VERSION_DEFINED=1
  endif
endif
ifndef BASE_VERSION_DEFINED
  ifeq ($(GNUSTEP_BUILD_ROOT),)
    $(error You need to checkout core/base and/or set GNUSTEP_BUILD_ROOT to your gnustep root containing 'core/base' before compiling!)
  endif
  include ${GNUSTEP_BUILD_ROOT}/core/base/Version
  GNUSTEP_BASE_MAJOR_VERSION=$(MAJOR_VERSION)
  GNUSTEP_BASE_MAJOR_VERSION=$(MINOR_VERSION)
  BASE_VERSION_DEFINED=1
endif
libgnustep-base_INTERFACE_VERSION=$(GNUSTEP_BASE_MAJOR_VERSION).$(GNUSTEP_BASE_MINOR_VERSION)
NSUserNotification_INSTALL_DIR = $(GNUSTEP_LIBRARY)/Libraries/gnustep-base/Versions/$(libgnustep-base_INTERFACE_VERSION)/Resources/

#include GNUmakefile.postamble

include $(GNUSTEP_MAKEFILES)/common.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/bundle.make
