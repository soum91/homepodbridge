export THEOS_PACKAGE_SCHEME = rootless

TARGET := iphone:clang:latest:16.0
ARCHS := arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HomePodBridge
HomePodBridge_FILES = Tweak.xm
HomePodBridge_CFLAGS = -fobjc-arc -Wall -Wextra
HomePodBridge_FRAMEWORKS = Foundation
HomePodBridge_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
