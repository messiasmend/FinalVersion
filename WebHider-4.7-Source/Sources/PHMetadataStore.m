#import "PHMetadataStore.h"
#import <WebKit/WebKit.h>

static NSMutableDictionary<NSString *, NSDictionary *> *PH47PendingMetadata(void) {
    static NSMutableDictionary *pending;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ pending = [NSMutableDictionary dictionary]; });
    return pending;
}

static NSString *PH47CustomFiltersPath(void) {
    static NSString *cachedPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *enumerator = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *relative = nil;
        while ((relative = [enumerator nextObject])) {
            if ([relative.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
                cachedPath = [home stringByAppendingPathComponent:relative];
                break;
            }
        }
        if (!cachedPath.length) {
            cachedPath = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
        }
    });
    return cachedPath;
}

static NSString *PH47AppName(void) {
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
    if (![name isKindOfClass:NSString.class] || !name.length) name = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
    if (![name isKindOfClass:NSString.class] || !name.length) name = NSProcessInfo.processInfo.processName;
    if (![name isKindOfClass:NSString.class] || !name.length) name = @"App";
    NSCharacterSet *unsafe = [NSCharacterSet characterSetWithCharactersInString:@"/:\\\n\r\t"];
    name = [[name componentsSeparatedByCharactersInSet:unsafe] componentsJoinedByString:@"_"];
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return name.length ? name : @"App";
}

static NSString *PH47MetadataPath(void) {
    NSString *directory = PH47CustomFiltersPath().stringByDeletingLastPathComponent;
    return [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-metadata.json", PH47AppName()]];
}

static NSDictionary *PH47LoadMetadata(void) {
    NSData *data = [NSData dataWithContentsOfFile:PH47MetadataPath()];
    if (!data) return @{};
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if (![json isKindOfClass:NSDictionary.class]) return @{};
    id elements = json[@"elements"];
    return [elements isKindOfClass:NSDictionary.class] ? elements : @{};
}

static NSArray<NSDictionary *> *PH47LoadFilters(void) {
    NSData *data = [NSData dataWithContentsOfFile:PH47CustomFiltersPath()];
    if (!data) return @[];
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if ([json isKindOfClass:NSDictionary.class]) json = json[@"filters"];
    return [json isKindOfClass:NSArray.class] ? json : @[];
}

static NSString *PH47String(id value, NSUInteger limit) {
    if (![value isKindOfClass:NSString.class]) return @"";
    NSString *s = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length > limit) s = [[s substringToIndex:limit] stringByAppendingString:@"…"];
    return s;
}

static NSString *PH47NameForElement(NSDictionary *element) {
    NSString *tag = [PH47String(element[@"tag"], 80) lowercaseString];
    if ([tag isEqualToString:@"lottie-player"]) return @"Lottie Player";
    NSArray<NSString *> *keys = @[@"ariaLabel", @"text", @"title", @"id", @"className", @"tag"];
    for (NSString *key in keys) {
        NSString *value = PH47String(element[key], [key isEqualToString:@"text"] ? 120 : 100);
        if (value.length) {
            if ([key isEqualToString:@"className"] && [value rangeOfString:@" "].location != NSNotFound) {
                NSArray *classes = [value componentsSeparatedByString:@" "];
                for (NSString *cls in classes) if (cls.length) return [NSString stringWithFormat:@".%@", cls];
            }
            return value;
        }
    }
    return @"Elemento";
}

static void PH47WriteMetadata(NSDictionary *elements) {
    NSString *path = PH47MetadataPath();
    if (!elements.count) {
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
        return;
    }
    NSString *directory = path.stringByDeletingLastPathComponent;
    [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSDictionary *payload = @{ @"elements": elements, @"version": @1 };
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
    if (data) [data writeToFile:path atomically:YES];
}

static NSString *PH47FilterSelector(NSDictionary *filter) {
    if (![filter isKindOfClass:NSDictionary.class]) return nil;
    NSString *selector = filter[@"selector"];
    if ([selector isKindOfClass:NSString.class] && selector.length) return selector;
    NSDictionary *action = filter[@"action"];
    selector = [action isKindOfClass:NSDictionary.class] ? action[@"selector"] : nil;
    return ([selector isKindOfClass:NSString.class] && selector.length) ? selector : nil;
}

@implementation PHMetadataStore

+ (void)captureSelectedElementFromWebView:(WKWebView *)webView {
    if (!webView) return;
    NSString *script = @"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return null;function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var same=[...q.children].filter(function(c){return c.tagName===n.tagName;});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(same.indexOf(n)+1)+')');n=q;}return a.join(' > ');}return JSON.stringify({selector:p(e),tag:e.tagName.toLowerCase(),id:e.id||'',className:typeof e.className==='string'?e.className:'',text:(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,500),ariaLabel:e.getAttribute('aria-label')||'',title:e.getAttribute('title')||''});})()";
    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:NSString.class]) return;
        NSData *data = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *element = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![element isKindOfClass:NSDictionary.class]) return;
        NSString *selector = PH47String(element[@"selector"], 1000);
        if (!selector.length) return;
        NSMutableDictionary *record = [NSMutableDictionary dictionary];
        record[@"name"] = PH47NameForElement(element);
        record[@"selector"] = selector;
        record[@"tag"] = PH47String(element[@"tag"], 80);
        record[@"id"] = PH47String(element[@"id"], 160);
        record[@"className"] = PH47String(element[@"className"], 300);
        record[@"text"] = PH47String(element[@"text"], 500);
        record[@"ariaLabel"] = PH47String(element[@"ariaLabel"], 200);
        record[@"title"] = PH47String(element[@"title"], 200);
        PH47PendingMetadata()[selector] = [record copy];
    }];
}

+ (void)synchronizeWithFilters {
    NSArray<NSDictionary *> *filters = PH47LoadFilters();
    NSMutableSet<NSString *> *activeSelectors = [NSMutableSet set];
    for (NSDictionary *filter in filters) {
        NSString *selector = PH47FilterSelector(filter);
        if (selector.length) [activeSelectors addObject:selector];
    }
    NSMutableDictionary *elements = [PH47LoadMetadata() mutableCopy];
    [PH47PendingMetadata() enumerateKeysAndObjectsUsingBlock:^(NSString *selector, NSDictionary *record, BOOL *stop) {
        if ([activeSelectors containsObject:selector]) {
            elements[selector] = record;
        } else {
            NSString *recordClassName = PH47String(record[@"className"], 300);
            NSString *recordID = PH47String(record[@"id"], 160);
            NSString *recordSelector = PH47String(record[@"selector"], 1000);
            for (NSString *active in activeSelectors) {
                BOOL classMatch = [active hasPrefix:@"."] && [[recordClassName componentsSeparatedByString:@" "] containsObject:[active substringFromIndex:1]];
                BOOL idMatch = [active hasPrefix:@"#"] && [recordID isEqualToString:[active substringFromIndex:1]];
                if (classMatch || idMatch || [active isEqualToString:recordSelector]) {
                    elements[active] = record;
                    break;
                }
            }
        }
    }];
    NSArray *staleKeys = [elements.allKeys filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *key, NSDictionary *bindings) {
        return ![activeSelectors containsObject:key];
    }]];
    [elements removeObjectsForKeys:staleKeys];
    PH47WriteMetadata(elements);
    [PH47PendingMetadata() removeAllObjects];
}

+ (NSString *)nameForSelector:(NSString *)selector {
    if (!selector.length) return nil;
    NSDictionary *pending = PH47PendingMetadata()[selector];
    NSString *name = PH47String(pending[@"name"], 100);
    if (name.length) return name;
    NSDictionary *saved = PH47LoadMetadata()[selector];
    name = PH47String(saved[@"name"], 100);
    if (name.length) return name;
    if ([selector hasPrefix:@"."] || [selector hasPrefix:@"#"]) {
        NSString *needle = [selector substringFromIndex:1];
        NSDictionary *all = PH47LoadMetadata();
        for (NSString *key in all) {
            NSDictionary *record = all[key];
            if ([selector hasPrefix:@"."]) {
                NSString *classes = PH47String(record[@"className"], 300);
                if ([[classes componentsSeparatedByString:@" "] containsObject:needle]) return PH47String(record[@"name"], 100);
            } else if ([selector hasPrefix:@"#"] && [PH47String(record[@"id"], 160) isEqualToString:needle]) {
                return PH47String(record[@"name"], 100);
            }
        }
    }
    return nil;
}

@end
