#import "PHOverlayManager.h"
#import <WebKit/WebKit.h>
#import "PHMetadataStore.h"

@class PHInspectorViewController;

@interface PHOverlayManager ()
@property (nonatomic, strong, nullable) PHInspectorViewController *inspectorViewController;
@property (nonatomic, strong, nullable) UIWindow *inspectorWindow;
@property (nonatomic, assign) BOOL selectionModeActive;
@property (nonatomic, weak, nullable) UIView *highlightedView;
@property (nonatomic, weak, nullable) WKWebView *highlightedWebView;
@property (nonatomic, assign) CGFloat previousBorderWidth;
@property (nonatomic, strong, nullable) UIColor *previousBorderColor;
- (void)showHierarchy;
- (void)restoreInspector;
@end

static NSString *PHFilterPath(void) {
    static NSString *cachedPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *relative = nil;
        while ((relative = [e nextObject])) {
            if ([relative.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) {
                cachedPath = [home stringByAppendingPathComponent:relative]; break;
            }
        }
        if (!cachedPath.length) cachedPath = [home stringByAppendingPathComponent:@"Documents/custom-filters.json"];
    });
    if (![[NSFileManager defaultManager] fileExistsAtPath:cachedPath]) {
        NSString *home = NSHomeDirectory();
        NSDirectoryEnumerator *e = [NSFileManager.defaultManager enumeratorAtPath:home];
        NSString *relative = nil;
        while ((relative = [e nextObject])) {
            if ([relative.lastPathComponent.lowercaseString isEqualToString:@"custom-filters.json"]) { cachedPath = [home stringByAppendingPathComponent:relative]; break; }
        }
    }
    return cachedPath;
}
static NSMutableArray *PHLoadFilters(void) {
    NSData *data = [NSData dataWithContentsOfFile:PHFilterPath()];
    if (!data) return [NSMutableArray array];
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    if ([json isKindOfClass:NSDictionary.class]) json = json[@"filters"];
    return [json isKindOfClass:NSArray.class] ? [json mutableCopy] : [NSMutableArray array];
}
static BOOL PHWriteFilters(NSArray *filters) {
    NSString *path = PHFilterPath();
    [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"version":@1,@"filters":filters?:@[]} options:0 error:nil];
    return data && [data writeToFile:path atomically:YES];
}
static NSString *PHSelectorsJSON(NSArray *selectors) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:selectors?:@[] options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
}
static void PHApplyFilters(WKWebView *webView) {
    if (!webView) return;
    NSMutableArray *selectors=[NSMutableArray array];
    for(NSDictionary *filter in PHLoadFilters()){NSString *selector=filter[@"selector"];if([selector isKindOfClass:NSString.class]&&selector.length)[selectors addObject:selector];}
    if(!selectors.count)return;
    NSString *json=PHSelectorsJSON(selectors);
    NSString *script=[NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){if(e.getAttribute('data-projetoh-hidden')!=='1'){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none';}})}catch(e){}});",json];
    [webView evaluateJavaScript:script completionHandler:nil];
}
static void PHHideSelector(WKWebView *webView,NSString *selector){if(!webView||!selector.length)return;NSString *json=PHSelectorsJSON(@[selector]);NSString *script=[NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.setAttribute('data-projetoh-hidden','1');e.setAttribute('data-projetoh-prev-display',e.style.display||'');e.style.display='none';})}catch(e){}});",json];[webView evaluateJavaScript:script completionHandler:nil];}
static void PHRestoreSelector(WKWebView *webView,NSString *selector){if(!webView||!selector.length)return;NSString *json=PHSelectorsJSON(@[selector]);NSString *script=[NSString stringWithFormat:@"(%@).forEach(function(s){try{document.querySelectorAll(s).forEach(function(e){e.style.display=e.getAttribute('data-projetoh-prev-display')||'';e.removeAttribute('data-projetoh-hidden');e.removeAttribute('data-projetoh-prev-display');})}catch(e){}});",json];[webView evaluateJavaScript:script completionHandler:nil];}

static NSMutableArray<NSString *> *PHPendingSelectors=nil;

@interface PHInspectorViewController:UIViewController
@property(nonatomic,assign)BOOL selectionMode;
@property(nonatomic,copy)NSString *currentDetails;
@property(nonatomic,copy)NSString *currentSubtitle;
@property(nonatomic,copy)NSString *detailsBeforeHierarchy;
@property(nonatomic,copy)NSString *subtitleBeforeHierarchy;
@property(nonatomic,assign)BOOL showingHierarchy;
- (void)showSelectionPrompt;
- (void)showSelectedWebElement:(NSString *)details;
- (void)showSelectedView:(UIView *)view;
@end

@implementation PHInspectorViewController
- (void)viewDidLoad{[super viewDidLoad];self.view.backgroundColor=UIColor.clearColor;[self showSelectionPrompt];}
- (UILabel *)label:(NSString *)text font:(UIFont *)font color:(UIColor *)color{UILabel*l=[UILabel new];l.translatesAutoresizingMaskIntoConstraints=NO;l.text=text?:@"";l.font=font;l.textColor=color;l.numberOfLines=0;return l;}
- (UIButton *)button:(NSString *)title action:(SEL)action{UIButton*b=[UIButton buttonWithType:UIButtonTypeSystem];b.translatesAutoresizingMaskIntoConstraints=NO;[b setTitle:title forState:UIControlStateNormal];b.titleLabel.font=[UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];[b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;}
- (void)clear{for(UIView*v in self.view.subviews.copy)[v removeFromSuperview];}
- (UIView *)panel{UIView*p=[UIView new];p.translatesAutoresizingMaskIntoConstraints=NO;p.backgroundColor=[UIColor colorWithWhite:.08 alpha:.97];p.layer.cornerRadius=18;p.layer.masksToBounds=YES;return p;}
- (void)showSelectionPrompt{dispatch_async(dispatch_get_main_queue(),^{[self clear];self.selectionMode=YES;self.showingHierarchy=NO;UILabel*b=[self label:@"Toque no elemento que deseja inspecionar" font:[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold] color:UIColor.whiteColor];b.backgroundColor=[UIColor colorWithWhite:.08 alpha:.96];b.layer.cornerRadius=22;b.layer.masksToBounds=YES;b.textAlignment=NSTextAlignmentCenter;[self.view addSubview:b];[NSLayoutConstraint activateConstraints:@[[b.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[b.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:18],[b.widthAnchor constraintEqualToConstant:320],[b.heightAnchor constraintEqualToConstant:44]]];});}
- (void)showInspectorDetails:(NSString*)details subtitle:(NSString*)subtitle{dispatch_async(dispatch_get_main_queue(),^{self.selectionMode=NO;self.showingHierarchy=NO;self.currentDetails=details?:@"";self.currentSubtitle=subtitle?:@"Elemento Web selecionado";[self render:NO];});}
- (void)showSelectedWebElement:(NSString*)details{[self showInspectorDetails:details subtitle:@"Elemento Web selecionado"];}
- (void)showSelectedView:(UIView*)view{CGRect r=view.frame;NSString*d=[NSString stringWithFormat:@"Classe: %@\n\nRect:\n  x: %.1f\n  y: %.1f\n  largura: %.1f\n  altura: %.1f\n\nTag: %ld\nHidden: %@\nAlpha: %.2f",NSStringFromClass(view.class),r.origin.x,r.origin.y,r.size.width,r.size.height,(long)view.tag,view.hidden?@"SIM":@"NÃO",view.alpha];[self showInspectorDetails:d subtitle:@"Elemento nativo selecionado"];}
- (void)render:(BOOL)hierarchyMode{[self clear];UIView*p=[self panel];[self.view addSubview:p];UILabel*title=[self label:@"ProjetoH Inspector" font:[UIFont boldSystemFontOfSize:21] color:UIColor.whiteColor];UILabel*subtitle=[self label:(hierarchyMode?@"Hierarquia DOM":self.currentSubtitle) font:[UIFont systemFontOfSize:14] color:[UIColor colorWithWhite:.72 alpha:1]];UIScrollView*scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.backgroundColor=[UIColor colorWithWhite:.055 alpha:1];scroll.layer.cornerRadius=12;scroll.alwaysBounceVertical=YES;UILabel*content=[self label:self.currentDetails font:[UIFont monospacedSystemFontOfSize:12.5 weight:UIFontWeightRegular] color:[UIColor colorWithWhite:.88 alpha:1]];[scroll addSubview:content];UIButton*left=[self button:(hierarchyMode?@"Voltar":@"Hierarquia") action:(hierarchyMode?@selector(backTapped):@selector(hierarchyTapped))];UIButton*copy=[self button:@"Copiar" action:@selector(copyTapped)];UIButton*close=[self button:@"Fechar" action:@selector(closeTapped)];UIButton*hide=[self button:@"Ocultar" action:@selector(hideTapped)];UIButton*hidden=[self button:@"Ocultos" action:@selector(hiddenTapped)];UIButton*save=[self button:@"Salvar" action:@selector(saveTapped)];save.hidden=PHPendingSelectors.count==0;for(UIView*v in @[title,subtitle,scroll,left,copy,close,hide,hidden,save])[p addSubview:v];[NSLayoutConstraint activateConstraints:@[[p.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],[p.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],[p.widthAnchor constraintEqualToConstant:360],[p.heightAnchor constraintEqualToConstant:500],[title.topAnchor constraintEqualToAnchor:p.topAnchor constant:22],[title.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:22],[subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],[subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],[scroll.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:18],[scroll.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],[scroll.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],[scroll.heightAnchor constraintEqualToConstant:326],[content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],[content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],[content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],[content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],[content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],[left.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],[left.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-62],[left.widthAnchor constraintEqualToConstant:100],[copy.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],[copy.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-62],[copy.widthAnchor constraintEqualToConstant:100],[close.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],[close.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-62],[close.widthAnchor constraintEqualToConstant:100],[hide.leadingAnchor constraintEqualToAnchor:p.leadingAnchor constant:18],[hide.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-14],[hide.widthAnchor constraintEqualToConstant:100],[hidden.centerXAnchor constraintEqualToAnchor:p.centerXAnchor],[hidden.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-14],[hidden.widthAnchor constraintEqualToConstant:100],[save.trailingAnchor constraintEqualToAnchor:p.trailingAnchor constant:-18],[save.bottomAnchor constraintEqualToAnchor:p.bottomAnchor constant:-14],[save.widthAnchor constraintEqualToConstant:100]]];}
- (void)hierarchyTapped{self.detailsBeforeHierarchy=self.currentDetails;self.subtitleBeforeHierarchy=self.currentSubtitle;[[PHOverlayManager sharedManager] performSelector:@selector(showHierarchy)];}
- (void)backTapped{[[PHOverlayManager sharedManager] performSelector:@selector(restoreInspector)];}
- (void)copyTapped{UIPasteboard.generalPasteboard.string=self.currentDetails?:@"";}
- (void)closeTapped{[[PHOverlayManager sharedManager] dismissOverlay];}
- (void)hideTapped{[[PHOverlayManager sharedManager] performSelector:@selector(hideSelectedElement)];}
- (void)hiddenTapped{[[PHOverlayManager sharedManager] performSelector:@selector(showHiddenElements)];}
- (void)saveTapped{[[PHOverlayManager sharedManager] performSelector:@selector(savePendingFilters)];}
@end

@implementation PHOverlayManager
+ (instancetype)sharedManager{static PHOverlayManager*m;static dispatch_once_t once;dispatch_once(&once,^{m=[PHOverlayManager new];});return m;}
- (void)presentTestOverlayIfNeeded{[self startSelectionMode];}
- (void)presentInspectorIfNeeded{[self startSelectionMode];}
- (UIWindow*)activeKeyWindow{for(UIScene*scene in UIApplication.sharedApplication.connectedScenes){if(![scene isKindOfClass:UIWindowScene.class]||scene.activationState!=UISceneActivationStateForegroundActive)continue;UIWindowScene*ws=(UIWindowScene*)scene;for(UIWindow*w in ws.windows.reverseObjectEnumerator)if(w.isKeyWindow&&!w.hidden&&w.alpha>0)return w;for(UIWindow*w in ws.windows.reverseObjectEnumerator)if(!w.hidden&&w.alpha>0&&w.rootViewController)return w;}return nil;}
- (void)installInspectorWindowIfNeeded{if(self.inspectorWindow)return;UIWindow*app=[self activeKeyWindow];if(!app||!app.windowScene)return;PHInspectorViewController*vc=[PHInspectorViewController new];UIWindow*w=[[UIWindow alloc]initWithWindowScene:app.windowScene];w.frame=app.bounds;w.windowLevel=UIWindowLevelAlert+1;w.backgroundColor=UIColor.clearColor;w.rootViewController=vc;w.hidden=NO;w.userInteractionEnabled=NO;self.inspectorViewController=vc;self.inspectorWindow=w;}
- (void)startSelectionMode{dispatch_async(dispatch_get_main_queue(),^{[self installInspectorWindowIfNeeded];if(!self.inspectorWindow)return;self.selectionModeActive=YES;self.inspectorWindow.userInteractionEnabled=NO;[self.inspectorViewController showSelectionPrompt];});}
- (UIView*)deepestViewFrom:(UIView*)view point:(CGPoint)point{if(!view||view.hidden||view.alpha<=.01||![view pointInside:point withEvent:nil])return nil;for(UIView*sub in view.subviews.reverseObjectEnumerator){CGPoint q=[sub convertPoint:point fromView:view];UIView*d=[self deepestViewFrom:sub point:q];if(d)return d;}return view;}
- (UIView*)deepestViewAtPoint:(CGPoint)point inWindow:(UIWindow*)window{return[self deepestViewFrom:window point:point];}
- (UIView*)selectView:(UIView*)view{self.highlightedView=view;self.highlightedWebView=nil;self.previousBorderWidth=view.layer.borderWidth;self.previousBorderColor=view.layer.borderColor?[UIColor colorWithCGColor:view.layer.borderColor]:nil;view.layer.borderWidth=2.0;view.layer.borderColor=[UIColor systemBlueColor].CGColor;[self.inspectorViewController showSelectedView:view];return view;}
- (WKWebView*)webViewContainingView:(UIView*)view{for(UIView*v=view;v;v=v.superview)if([v isKindOfClass:WKWebView.class])return(WKWebView*)v;return nil;}
- (void)highlightWebElementInWebView:(WKWebView*)webView x:(CGFloat)x y:(CGFloat)y{self.highlightedWebView=webView;NSString*script=[NSString stringWithFormat:@"(function(){var e=document.elementFromPoint(%0.3f,%0.3f);if(!e)return null;var old=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(old){old.style.outline=old.getAttribute('data-projetoh-prev-outline')||'';old.removeAttribute('data-projetoh-selected');old.removeAttribute('data-projetoh-prev-outline');}e.setAttribute('data-projetoh-selected','1');e.setAttribute('data-projetoh-prev-outline',e.style.outline||'');e.style.outline='3px solid #007AFF';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var same=[...q.children].filter(function(c){return c.tagName===n.tagName;});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(same.indexOf(n)+1)+')');n=q;}return a.join(' > ');}var r=e.getBoundingClientRect();return JSON.stringify({tag:e.tagName.toLowerCase(),id:e.id||'',className:typeof e.className==='string'?e.className:'',text:(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,180),href:e.href||'',type:e.getAttribute('type')||'',selector:p(e),rect:{x:r.x,y:r.y,width:r.width,height:r.height}});})()",x,y];[webView evaluateJavaScript:script completionHandler:^(id result,NSError*error){dispatch_async(dispatch_get_main_queue(),^{self.selectionModeActive=NO;self.inspectorWindow.userInteractionEnabled=YES;if(error||![result isKindOfClass:NSString.class]){[self selectView:[self deepestViewAtPoint:CGPointMake(x,y) inWindow:webView.window]];return;}NSData*data=[(NSString*)result dataUsingEncoding:NSUTF8StringEncoding];NSDictionary*info=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;if(![info isKindOfClass:NSDictionary.class]){[self selectView:[self deepestViewAtPoint:CGPointMake(x,y) inWindow:webView.window]];return;}NSMutableString*d=[NSMutableString stringWithFormat:@"HTML: <%@>",info[@"tag"]?:@"?"];if([info[@"id"] length])[d appendFormat:@"\nID: %@",info[@"id"]];if([info[@"className"] length])[d appendFormat:@"\nClasse: %@",info[@"className"]];if([info[@"type"] length])[d appendFormat:@"\nTipo: %@",info[@"type"]];if([info[@"text"] length])[d appendFormat:@"\nTexto: %@",info[@"text"]];if([info[@"href"] length])[d appendFormat:@"\nLink: %@",info[@"href"]];NSDictionary*r=info[@"rect"];if([r isKindOfClass:NSDictionary.class])[d appendFormat:@"\n\nRect:\n  x: %.1f\n  y: %.1f\n  largura: %.1f\n  altura: %.1f",[r[@"x"] doubleValue],[r[@"y"] doubleValue],[r[@"width"] doubleValue],[r[@"height"] doubleValue]];[self.inspectorViewController showSelectedWebElement:d];});}];}
- (void)hideSelectedElement{WKWebView*web=self.highlightedWebView;if(!web)return;[web evaluateJavaScript:@"(function(){var e=document.querySelector('[data-projetoh-selected=\\\"1\\\"]');if(!e)return '{}';function p(n){if(n.id)return '#'+CSS.escape(n.id);var a=[];while(n&&n.nodeType===1&&n!==document.body){var q=n.parentElement;if(!q)break;var same=[...q.children].filter(function(c){return c.tagName===n.tagName;});a.unshift(n.tagName.toLowerCase()+':nth-of-type('+(same.indexOf(n)+1)+')');n=q;}return a.join(' > ');}return JSON.stringify({selector:p(e),tag:e.tagName.toLowerCase(),id:e.id||'',className:typeof e.className==='string'?e.className:'',text:(e.innerText||e.textContent||'').trim().replace(/\\s+/g,' ').slice(0,500),ariaLabel:e.getAttribute('aria-label')||'',title:e.getAttribute('title')||''});})()" completionHandler:^(id result,NSError*error){if(error||![result isKindOfClass:NSString.class])return;NSData*data=[result dataUsingEncoding:NSUTF8StringEncoding];NSDictionary*info=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;NSString*selector=info[@"selector"];if(!selector.length)return;[PHMetadataStore recordMetadata:info forSelector:selector];if(!PHPendingSelectors)PHPendingSelectors=[NSMutableArray array];if(![PHPendingSelectors containsObject:selector])[PHPendingSelectors addObject:selector];PHHideSelector(web,selector);dispatch_async(dispatch_get_main_queue(),^{[self.inspectorViewController render:self.inspectorViewController.showingHierarchy];});}];}
- (void)savePendingFilters{if(!PHPendingSelectors.count)return;NSMutableArray*filters=PHLoadFilters();for(NSString*selector in PHPendingSelectors){BOOL exists=NO;for(NSDictionary*f in filters)if([f[@"selector"] isEqualToString:selector]){exists=YES;break;}if(!exists)[filters addObject:@{@"selector":selector}];}if(PHWriteFilters(filters)){[PHPendingSelectors removeAllObjects];[self.inspectorViewController render:self.inspectorViewController.showingHierarchy];PHApplyFilters(self.highlightedWebView);[PHMetadataStore synchronizeWithFilters];}}
- (void)showHiddenElements{NSArray*filters=PHLoadFilters();UIViewController*vc=self.inspectorViewController;if(!vc)return;UIAlertController*a=[UIAlertController alertControllerWithTitle:@"Elementos ocultos" message:[NSString stringWithFormat:@"%lu item(ns) em custom-filters.json",(unsigned long)filters.count] preferredStyle:UIAlertControllerStyleAlert];NSMutableDictionary*counts=[NSMutableDictionary dictionary];for(NSDictionary*f in filters){NSString*selector=f[@"selector"]?:@"";if(!selector.length)continue;NSString*name=[PHMetadataStore nameForSelector:selector];if(!name.length)name=selector;NSInteger count=[counts[name] integerValue];counts[name]=@(count+1);if(count>0)name=[NSString stringWithFormat:@"%@ #%ld",name,(long)count+1];[a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Reativar: %@",name] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction*action){NSMutableArray*cur=PHLoadFilters();NSIndexSet*idx=[cur indexesOfObjectsPassingTest:^BOOL(NSDictionary*item,NSUInteger i,BOOL*stop){return[item[@"selector"]isEqualToString:selector];}];[cur removeObjectsAtIndexes:idx];PHWriteFilters(cur);PHRestoreSelector(self.highlightedWebView,selector);[PHMetadataStore synchronizeWithFilters];}]];}if(filters.count)[a addAction:[UIAlertAction actionWithTitle:@"Reativar todos" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction*action){WKWebView*w=self.highlightedWebView;for(NSDictionary*f in PHLoadFilters())PHRestoreSelector(w,f[@"selector"]);PHWriteFilters(@[]);[PHMetadataStore synchronizeWithFilters];}]];[a addAction:[UIAlertAction actionWithTitle:@"Fechar" style:UIAlertActionStyleCancel handler:nil]];[vc presentViewController:a animated:YES completion:nil];}
- (void)dismissOverlay{self.inspectorWindow.hidden=YES;self.inspectorWindow=nil;self.inspectorViewController=nil;}
@end
