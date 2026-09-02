#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@class PHOverlayManager;

@interface PHOverlayManager : NSObject
+ (instancetype)sharedManager;
- (void)savePendingFilters;
@end

/*
 * WebHider 2.3.2 — Save-button fix only.
 *
 * The existing save implementation remains the source of truth. This layer
 * makes the GUI action explicit and gives the user immediate feedback instead
 * of silently doing nothing when there is nothing pending.
 */

static NSString *PH23FindFilterPath(void) {
    NSString *home = NSHomeDirectory();
    NSDirectoryEnumerator *enumerator = [NSFileManager.defaultManager enumeratorAtPath:home];
    NSString *relative = nil;
    while ((relative = [enumerator nextObject])) {
        if ([relative.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
            return [home stringByAppendingPathComponent:relative];
        }
    }
    return [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
}

static NSDate *PH23FilterModificationDate(void) {
    NSString *path = PH23FindFilterPath();
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    return attributes[NSFileModificationDate];
}

static void PH23SaveTapped(id self, SEL _cmd) {
    NSDate *before = PH23FilterModificationDate();

    PHOverlayManager *manager = [PHOverlayManager sharedManager];
    [manager savePendingFilters];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDate *after = PH23FilterModificationDate();
        BOOL changed = (after != nil && (before == nil || [after compare:before] == NSOrderedDescending));

        NSString *title = changed ? @"Salvo" : @"Salvar";
        NSString *message = changed
            ? @"O filtro foi salvo com sucesso."
            : @"Não há filtros pendentes para salvar.";

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                         message:message
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [(UIViewController *)self presentViewController:alert animated:YES completion:nil];
    });
}

__attribute__((constructor))
static void PH23InstallSaveFix(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"PHInspectorViewController");
        if (!cls) return;

        SEL originalSEL = @selector(saveTapped);
        SEL replacementSEL = @selector(ph23_saveTapped);
        Method original = class_getInstanceMethod(cls, originalSEL);
        Method replacement = class_getInstanceMethod(cls, replacementSEL);

        if (!replacement) {
            class_addMethod(cls, replacementSEL, (IMP)PH23SaveTapped, "v@:");
            replacement = class_getInstanceMethod(cls, replacementSEL);
        }
        if (original && replacement) {
            method_setImplementation(original, method_getImplementation(replacement));
        }
    });
}
