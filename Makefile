export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64 arm64e
export PACKAGE_VERSION = 1.0.0

INSTALL_TARGET_PROCESSES = com.baidu.tieba

include /makefiles/common.mk

TWEAK_NAME = TiebaAdsBlocker

TiebaAdsBlocker_FILES = Tweak.xm
TiebaAdsBlocker_CFLAGS = -fobjc-arc

include /tweak.mk

after-install::
	install.exec "killall -9 com.baidu.tieba" || true