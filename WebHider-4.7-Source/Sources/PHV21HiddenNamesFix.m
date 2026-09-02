#import "PHOverlayManager.h"
#import "PHMetadataStore.h"
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static NSString *PHV21FilterPath(void){
    static NSString*cachedPath;
    static dispatch_once_t once;
    dispatch_once(&once,^{
        NSString*home=NSHomeDirectory();
        NSDirectoryEnumerator*e=[NSFileManager.defaultManager enumeratorAtPath:home];
        NSString*r=nil;
        while((r=[e nextObject])){
            if([r.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]){cachedPath=[home stringByAppendingPathComponent:r];break;}
        }
        if(!cachedPath.length)cachedPath=[home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    });
    return cachedPath;
}

static NSMutableArray*PHV21LoadFilters(void){
    NSData*data=[NSData dataWithContentsOfFile:PHV21FilterPath()];
    if(!data)return[NSMutableArray array];
    id json=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if([json isKindOfClass:NSDictionary.class])json=json[@"filters"];
    return[json isKindOfClass:NSArray.class]?[json mutableCopy]:[NSMutableArray array];
}

static BOOL PHV21WriteFilters(NSArray*filters){
    NSString*path=PHV21FilterPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData*data=[NSJSONSerialization dataWithJSONObject:@{@"version":@1,@"filters":filters?:@[]} options:0 error:nil];
    return data&&[data writeToFile:path atomically:YES];
}

static NSString*PHV21SelectorFromFilter(NSDictionary*f){
    if(![f isKindOfClass:NSDictionary.class])return nil;
    NSString*s=f[@"selector"];
    if([s isKindOfClass:NSString.class]&&s.length)return s;
    NSDictionary*a=f[@"action"];
    s=[a isKindOfClass:NSDictionary.class]?a[@"selector"]:nil;
    return([s isKindOfClass:NSString.class]&&s.length)?s:nil;
}

static void PHV21RestoreSelector(WKWebView*w,NSString*s){
    if(!w||!s.length)return;
    NSData*d=[NSJSONSerialization dataWithJSONObject:@[s] options:0 error:nil];
    NSString*j=[[NSString alloc]initWithData:d encoding:NSUTF8StringEncoding]?:@"[]";
    NSString*script=[NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.style.display=e.getAttribute('data-projetoh-prev-display')||'';e.removeAttribute('data-projetoh-hidden');e.removeAttribute('data-projetoh-prev-display');})}catch(e){}});",j];
    [w evaluateJavaScript:script completionHandler:nil];
}

@interface PHOverlayManager(PHV21HiddenNamesFix)
- (void)phv21_fix_showHiddenElements;
@end

@implementation PHOverlayManager(PHV21HiddenNamesFix)

- (void)phv21_fix_showHiddenElements{
    NSArray*filters=PHV21LoadFilters();
    UIViewController*vc=[self valueForKey:@"inspectorViewController"];
    if(!vc)return;

    UIAlertController*a=[UIAlertController alertControllerWithTitle:@"Elementos ocultos" message:[NSString stringWithFormat:@"%lu item(ns) em custom-filters.json",(unsigned long)filters.count] preferredStyle:UIAlertControllerStyleAlert];
    __weak PHOverlayManager*weakSelf=self;

    for(NSDictionary*f in filters){
        NSString*s=PHV21SelectorFromFilter(f);
        if(!s.length)continue;
        NSString*name=[PHMetadataStore nameForSelector:s];
        NSString*display=name.length?name:(s.length>90?[[s substringToIndex:90]stringByAppendingString:@"…"]:s);
        [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@",display] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction*action){
            PHOverlayManager*strongSelf=weakSelf;
            NSMutableArray*cur=PHV21LoadFilters();
            NSIndexSet*idx=[cur indexesOfObjectsPassingTest:^BOOL(NSDictionary*item,NSUInteger i,BOOL*stop){return[PHV21SelectorFromFilter(item)isEqualToString:s];}];
            [cur removeObjectsAtIndexes:idx];
            PHV21WriteFilters(cur);
            PHV21RestoreSelector([strongSelf valueForKey:@"highlightedWebView"],s);
            [PHMetadataStore synchronizeWithFilters];
        }]];
    }

    if(filters.count)[a addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction*action){
        PHOverlayManager*strongSelf=weakSelf;
        WKWebView*w=[strongSelf valueForKey:@"highlightedWebView"];
        for(NSDictionary*f in PHV21LoadFilters())PHV21RestoreSelector(w,PHV21SelectorFromFilter(f));
        PHV21WriteFilters(@[]);
        [PHMetadataStore synchronizeWithFilters];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

@end

__attribute__((constructor))static void PHV21HiddenNamesFixInit(void){
    dispatch_async(dispatch_get_main_queue(),^{
        static dispatch_once_t once;
        dispatch_once(&once,^{
            Method original=class_getInstanceMethod(PHOverlayManager.class,@selector(showHiddenElements));
            Method replacement=class_getInstanceMethod(PHOverlayManager.class,@selector(phv21_fix_showHiddenElements));
            if(original&&replacement)method_exchangeImplementations(original,replacement);
        });
    });
}
