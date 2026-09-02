#import <Foundation/Foundation.h>
@class WKWebView;

NS_ASSUME_NONNULL_BEGIN

@interface PHMetadataStore : NSObject

+ (void)captureSelectedElementFromWebView:(WKWebView *)webView;
+ (void)captureSelectedElementFromWebView:(WKWebView *)webView completion:(void (^)(BOOL captured))completion;
+ (void)synchronizeWithFilters;
+ (BOOL)hasPendingMetadata;
+ (nullable NSString *)nameForSelector:(NSString *)selector;

@end

NS_ASSUME_NONNULL_END
