export THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang:latest:16.0
ARCHS := arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HomePodBridgeHomedProbe
HomePodBridgeHomedProbe_FILES = HomedProbe.xm
HomePodBridgeHomedProbe_CFLAGS = -fobjc-arc -Wall -Wextra
HomePodBridgeHomedProbe_FRAMEWORKS = Foundation
HomePodBridgeHomedProbe_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
