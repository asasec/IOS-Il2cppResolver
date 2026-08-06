target = iphone:clang:latest:14.0
architectures = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Il2CppDumpMenu

Il2CppDumpMenu_FILES = main.mm
Il2CppDumpMenu_CFLAGS = -fobjc-arc -std=c++17
Il2CppDumpMenu_CCFLAGS = -std=c++17 -stdlib=libc++
Il2CppDumpMenu_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk