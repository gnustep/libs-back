
ifeq ($(debug),yes)
ToastNotifications-0.dll: obj ToastNotifications/Debug/ToastNotifications.dll
	cp -p ToastNotifications/Debug/ToastNotifications.dll obj/ToastNotifications-0.dll
else
ToastNotifications-0.dll: obj ToastNotifications/Release/ToastNotifications.dll
	cp -p ToastNotifications/Release/ToastNotifications.dll obj/ToastNotifications-0.dll
endif

include $(GNUSTEP_MAKEFILES)/common.make
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
