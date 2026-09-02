ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WebHider

WebHider_FILES = Tweak.xm \
    Sources/PHThreeFingerGesture.m \
    Sources/PHOverlayManager.m \
    Sources/PHV17ButtonOrderFix.m \
    Sources/PHV21FilterFormatFix.m \
    Sources/PHV21HiddenNamesFix.m \
    Sources/PHV26JSONFlowFinal.m \
    Sources/PHVisualStyle23.m \
    Sources/PHV23SaveFix.m \
    Sources/PHV233FinalUI.m \
    Sources/PHV234ElementFlow.m \
    Sources/PHV30ElementPromptFix.m

WebHider_CFLAGS = -fobjc-arc -Wno-unused-function
WebHider_FRAMEWORKS = UIKit Foundation WebKit

include $(THEOS_MAKE_PATH)/tweak.mk

INSTALL_TARGET_PROCESSES =
