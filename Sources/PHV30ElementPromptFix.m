#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
- (void)showSelectedWebElement:(NSString *)details;
- (void)render:(BOOL)hierarchyMode;
@end

static void (*PH30OriginalShowSelectedWebElement)(id, SEL, NSString *);
static BOOL PH30Installed = NO;

static void PH30ShowSelectedWebElement(id self, SEL _cmd, NSString *details) {
    PHInspectorViewController *vc = (PHInspectorViewController *)self;
    NSString *payload = details ?: @"";

    // Preserve the exact selected-element payload before any asynchronous
    // renderer can rebuild the Element page.
    vc.currentDetails = payload;
    vc.currentSubtitle = @"Elemento Web selecionado";

    if (PH30OriginalShowSelectedWebElement) {
        PH30OriginalShowSelectedWebElement(self, _cmd, payload);
    }

    // The base UI renders asynchronously. Re-assert the payload after that
    // render so the Element prompt cannot be left empty by a stale render.
    dispatch_async(dispatch_get_main_queue(), ^{
        vc.currentDetails = payload;
        vc.currentSubtitle = @"Elemento Web selecionado";

        dispatch_async(dispatch_get_main_queue(), ^{
            vc.currentDetails = payload;
            vc.currentSubtitle = @"Elemento Web selecionado";
            [vc render:NO];
        });
    });
}

__attribute__((constructor)) static void PH30Install(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (PH30Installed) return;

        Class c = NSClassFromString(@"PHInspectorViewController");
        if (!c) return;

        Method m = class_getInstanceMethod(c, @selector(showSelectedWebElement:));
        if (!m) return;

        IMP current = method_getImplementation(m);
        if (!current || current == (IMP)PH30ShowSelectedWebElement) return;

        PH30OriginalShowSelectedWebElement = (void *)current;
        method_setImplementation(m, (IMP)PH30ShowSelectedWebElement);
        PH30Installed = YES;
    });
}
