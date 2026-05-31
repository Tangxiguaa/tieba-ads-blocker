export TARGET := iphone:clang:14.0:14.0
export ARCHS = arm64 arm64e

INSTALL_TARGET_PROCESSES = *

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SplashSkipper

SplashSkipper_FILES = Tweak.xm
SplashSkipper_CFLAGS = -fobjc-arc
SplashSkipper_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
