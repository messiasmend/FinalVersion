#import <Foundation/Foundation.h>
@class WKWebView;

NS_ASSUME_NONNULL_BEGIN
@interface PHMetadataStore : NSObject
+ (void)storeMetadataRecord:(NSDictionary *)record forSelector:(NSString *)selector;
+ (void)storeMetadataRecords:(NSArray<NSDictionary *> *)records;
+ (void)synchronizeWithFilters;
+ (void)replaceMetadataSelector:(NSString *)oldSelector withSelector:(NSString *)newSelector;
+ (nullable NSString *)nameForSelector:(NSString *)selector;
@end
NS_ASSUME_NONNULL_END
