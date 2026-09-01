#import "PHThreeFingerGesture.h"
#import "PHOverlayManager.h"

// ProjetoH V6: the GUI is activated with exactly two fingers.
static const NSUInteger PHRequiredFingerCount = 2;
static NSTimeInterval const PHTwoFingerHoldInterval = 0.8;

@interface PHThreeFingerGesture ()
@property (nonatomic, strong, nullable) NSTimer *holdTimer;
@property (nonatomic, assign) BOOL triggered;
@end

@implementation PHThreeFingerGesture

- (void)processEvent:(UIEvent *)event {
    if (event == nil || ![event respondsToSelector:@selector(allTouches)]) return;
    NSSet<UITouch *> *touches = event.allTouches;
    NSUInteger activeTouches = 0;
    for (UITouch *touch in touches) {
        switch (touch.phase) {
            case UITouchPhaseBegan:
            case UITouchPhaseMoved:
            case UITouchPhaseStationary:
                activeTouches += 1;
                break;
            default:
                break;
        }
    }
    if (activeTouches == PHRequiredFingerCount) [self armIfNeeded];
    else [self cancelHoldAndResetTrigger];
}

- (void)armIfNeeded {
    if (self.triggered || self.holdTimer != nil) return;
    if (![NSThread isMainThread]) { dispatch_async(dispatch_get_main_queue(), ^{ [self armIfNeeded]; }); return; }
    __weak typeof(self) weakSelf = self;
    self.holdTimer = [NSTimer timerWithTimeInterval:PHTwoFingerHoldInterval repeats:NO block:^(__unused NSTimer *timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf handleHoldTimerFired];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.holdTimer forMode:NSRunLoopCommonModes];
}

- (void)handleHoldTimerFired {
    self.holdTimer = nil;
    if (self.triggered) return;
    self.triggered = YES;
    [[PHOverlayManager sharedManager] startSelectionMode];
}

- (void)cancelHoldAndResetTrigger {
    if (![NSThread isMainThread]) { dispatch_async(dispatch_get_main_queue(), ^{ [self cancelHoldAndResetTrigger]; }); return; }
    [self cancelTimer];
    self.triggered = NO;
}

- (void)cancelTimer { [self.holdTimer invalidate]; self.holdTimer = nil; }
- (void)reset { [self cancelHoldAndResetTrigger]; }
@end
