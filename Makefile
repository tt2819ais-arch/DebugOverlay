TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DebugOverlay
DebugOverlay_FILES = Tweak.xm
DebugOverlay_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_FILES)/tweak.mk
