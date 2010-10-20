TWEAK_NAME = IconRenamer
IconRenamer_OBJC_FILES = IconRenamer.m
IconRenamer_FRAMEWORKS = Foundation UIKit

ADDITIONAL_CFLAGS = -std=c99

include framework/makefiles/common.mk
include framework/makefiles/tweak.mk
