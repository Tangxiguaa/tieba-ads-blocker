export TARGET = iphone:clang:17.0:14.0
export ARCHS = arm64 arm64e
export PACKAGE_VERSION = 1.0.0

INSTALL_TARGET_PROCESSES = com.baidu.tieba

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TiebaAdsBlocker

TiebaAdsBlocker_FILES = Tweak.xm
TiebaAdsBlocker_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 com.baidu.tieba" || true
