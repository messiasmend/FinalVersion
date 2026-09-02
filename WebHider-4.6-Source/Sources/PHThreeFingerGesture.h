#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PHThreeFingerGesture : NSObject

- (void)processEvent:(UIEvent *)event;
- (void)reset;

@end

NS_ASSUME_NONNULL_END
