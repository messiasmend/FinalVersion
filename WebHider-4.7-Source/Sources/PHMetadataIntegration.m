#import "PHMetadataStore.h"
#import "PHOverlayManager.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface PHOverlayManager (PHMetadataIntegration)
- (void)ph47_hideSelectedElement;
- (void)ph47_savePendingFilters;
@end

@implementation PHOverlayManager (PHMetadataIntegration)

- (void)ph47_hideSelectedElement {
    WKWebView *webView = nil;
    @try { webView = [self valueForKey:@"highlightedWebView"]; } @catch (__unused NSException *exception) {}
    [PHMetadataStore captureSelectedElementFromWebView:webView];
    [self ph47_hideSelectedElement];
}

- (void)ph47_savePendingFilters {
    [self ph47_savePendingFilters];

    // The element metadata is captured through WKWebView asynchronously.
    // The original save operation remains untouched; synchronization is
    // retried briefly so the metadata callback has time to populate pending.
    NSArray<NSNumber *> *delays = @[@0.25, @0.75, @1.50];
    for (NSNumber *delay in delays) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([PHMetadataStore hasPendingMetadata]) {
                [PHMetadataStore synchronizeWithFilters];
            }
        });
    }
}

@end

__attribute__((constructor)) static void PH47MetadataIntegrationInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Method hideOriginal = class_getInstanceMethod(PHOverlayManager.class, @selector(hideSelectedElement));
            Method hideReplacement = class_getInstanceMethod(PHOverlayManager.class, @selector(ph47_hideSelectedElement));
            if (hideOriginal && hideReplacement) method_exchangeImplementations(hideOriginal, hideReplacement);

            Method saveOriginal = class_getInstanceMethod(PHOverlayManager.class, @selector(savePendingFilters));
            Method saveReplacement = class_getInstanceMethod(PHOverlayManager.class, @selector(ph47_savePendingFilters));
            if (saveOriginal && saveReplacement) method_exchangeImplementations(saveOriginal, saveReplacement);
        });
    });
}
