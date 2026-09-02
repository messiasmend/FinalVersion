#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// ProjetoH V9: inspector overlay API.
@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
- (void)presentTestOverlayIfNeeded;
- (void)presentInspectorIfNeeded;
- (void)startSelectionMode;
- (void)processInspectionEvent:(UIEvent *)event;
- (void)selectView:(UIView *)view;
- (void)dismissOverlay;
@end

NS_ASSUME_NONNULL_END
