
all: ToastNotifications-0.dll

clean:
	rm -rf obj
	(cd ToastNotifications/Debug && (find . -type f | grep -v '.dll' | xargs rm -rf))
	(cd ToastNotifications/Release && (find . -type f | grep -v '.dll' | xargs rm -rf))
	(rm -rf ToastNotifications/ToastNotifications/Debug)
	(rm -rf ToastNotifications/ToastNotifications/Release)
	(rm -rf ToastNotifications/ipch ToastNotifications/*.sdf)
  
distclean: clean

obj:
	mkdir -p obj

install: ToastNotifications-0.dll

ifeq ($(debug),yes)
ToastNotifications-0.dll: obj ToastNotifications/Debug/ToastNotifications.dll
	cp -p ToastNotifications/Debug/ToastNotifications.dll obj/ToastNotifications-0.dll
else
ToastNotifications-0.dll: obj ToastNotifications/Release/ToastNotifications.dll
	cp -p ToastNotifications/Release/ToastNotifications.dll obj/ToastNotifications-0.dll
endif

include $(GNUSTEP_MAKEFILES)/common.make
