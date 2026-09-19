TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES :=

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := ReturnToLiveContainer

ReturnToLiveContainer_FILES := Tweak.xm
ReturnToLiveContainer_CFLAGS := -fobjc-arc
ReturnToLiveContainer_FRAMEWORKS := UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
