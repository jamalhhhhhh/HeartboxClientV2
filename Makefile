THEOS_PACKAGE_SCHEME = rootless
TARGET := iphone:clang::14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MyTweak

MyTweak_FILES = Tweak.x
MyTweak_CFLAGS = -fobjc-arc
MyTweak_FRAMEWORKS = UIKit Foundation

include $(THEOS)/makefiles/tweak.mk
