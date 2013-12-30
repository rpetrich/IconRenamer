TWEAK_NAME = IconRenamer
IconRenamer_FILES = IconRenamer.m
IconRenamer_FRAMEWORKS = Foundation UIKit

IPHONE_ARCHS = armv6 arm64

TARGET_IPHONEOS_DEPLOYMENT_VERSION = 4.0
THEOS_PLATFORM_SDK_ROOT_armv6 = /Applications/Xcode_Legacy.app/Contents/Developer

ADDITIONAL_CFLAGS = -std=c99

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk
