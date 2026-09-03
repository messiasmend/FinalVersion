#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface PHMetadataStore : NSObject
+ (void)recordMetadata:(NSDictionary *)metadata forSelector:(NSString *)selector;
+ (void)synchronizeWithFilters;
+ (void)migrateMetadataFromSelector:(NSString *)oldSelector toSelector:(NSString *)newSelector;
+ (nullable NSString *)nameForSelector:(NSString *)selector;
@end
NS_ASSUME_NONNULL_END
