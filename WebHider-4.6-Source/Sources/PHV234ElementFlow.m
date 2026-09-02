#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@property(nonatomic,assign) BOOL showingHierarchy;
- (void)showInspectorDetails:(NSString *)details subtitle:(NSString *)subtitle;
- (void)showSelectedWebElement:(NSString *)details;
- (void)render:(BOOL)hierarchyMode;
- (void)backTapped;
- (void)hierarchyTapped;
@end

static const void *kPH234SelectedCode = &kPH234SelectedCode;
static const void *kPH234SelectedSubtitle = &kPH234SelectedSubtitle;
static const void *kPH234InTree = &kPH234InTree;

static NSString *PH234Get(id obj, const void *key) { return objc_getAssociatedObject(obj,key); }
static void PH234Set(id obj, const void *key, NSString *value) { objc_setAssociatedObject(obj,key,value,OBJC_ASSOCIATION_COPY_NONATOMIC); }
static BOOL PH234Tree(id obj) { return [objc_getAssociatedObject(obj,kPH234InTree) boolValue]; }
static void PH234SetTree(id obj, BOOL value) { objc_setAssociatedObject(obj,kPH234InTree,@(value),OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

static NSString *PH234Value(NSString *details, NSString *key) {
    for (NSString *line in [details componentsSeparatedByString:@"\n"]) {
        NSString *prefix = [key stringByAppendingString:@":"];
        if ([line hasPrefix:prefix]) return [[line substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    }
    return @"";
}

static BOOL PH234LooksLikeElementDetails(NSString *details) {
    NSString *d = details ?: @"";
    return [d rangeOfString:@"HTML:"].location != NSNotFound && [d rangeOfString:@"Rect:"].location != NSNotFound;
}

static NSString *PH234ElementCode(NSString *details) {
    NSString *html = PH234Value(details ?: @"", @"HTML");
    NSString *tag = @"div";
    NSRange open = [html rangeOfString:@"<"];
    NSRange close = (open.location != NSNotFound) ? [html rangeOfString:@">" options:0 range:NSMakeRange(open.location,html.length-open.location)] : NSMakeRange(NSNotFound,0);
    if (open.location != NSNotFound && close.location != NSNotFound && close.location > open.location) {
        NSString *inside = [html substringWithRange:NSMakeRange(open.location+1,close.location-open.location-1)];
        NSArray *parts = [inside componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (parts.count && [parts[0] length]) tag = parts[0];
    }
    NSMutableString *attrs=[NSMutableString string];
    NSString *identifier=PH234Value(details,@"ID");
    NSString *classes=PH234Value(details,@"Classe");
    NSString *type=PH234Value(details,@"Tipo");
    NSString *href=PH234Value(details,@"Link");
    if(identifier.length)[attrs appendFormat:@" id=\"%@\"",identifier];
    if(classes.length)[attrs appendFormat:@" class=\"%@\"",classes];
    if(type.length && ![type isEqualToString:tag])[attrs appendFormat:@" type=\"%@\"",type];
    if(href.length)[attrs appendFormat:@" href=\"%@\"",href];
    NSString *text=PH234Value(details,@"Texto");
    if(text.length) return [NSString stringWithFormat:@"<%@%@>\n    %@\n</%@>",tag,attrs,text,tag];
    return [NSString stringWithFormat:@"<%@%@></%@>",tag,attrs,tag];
}

static UIButton *PH234FindButton(UIView *root, NSString *title) {
    if (!root) return nil;
    if ([root isKindOfClass:UIButton.class]) {
        UIButton *button=(UIButton *)root;
        if ([[button titleForState:UIControlStateNormal] ?: @"" isEqualToString:title]) return button;
    }
    for (UIView *child in [root.subviews copy]) {
        UIButton *found=PH234FindButton(child,title);
        if (found) return found;
    }
    return nil;
}

static UIView *PH234Panel(UIViewController *vc) {
    for (UIView *view in [vc.view.subviews copy]) {
        if (![view isKindOfClass:UIButton.class]) return view;
    }
    return nil;
}

static void PH234AlignButtonLeft(UIButton *button) {
    if (!button) return;
    button.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    button.contentVerticalAlignment=UIControlContentVerticalAlignmentCenter;
    button.contentEdgeInsets=UIEdgeInsetsMake(0,18,0,18);
    button.titleEdgeInsets=UIEdgeInsetsMake(0,8,0,0);
    button.imageEdgeInsets=UIEdgeInsetsZero;
    button.titleLabel.textAlignment=NSTextAlignmentLeft;
    button.titleLabel.numberOfLines=1;
}

static void PH234MakeButtonLabelFit(UIButton *button) {
    if (!button) return;
    button.titleLabel.adjustsFontSizeToFitWidth=YES;
    button.titleLabel.minimumScaleFactor=0.78;
    button.titleLabel.numberOfLines=1;
}

static void PH234ShrinkHeightConstraint(UIView *panel, UIView *view) {
    if (!panel || !view) return;
    for (NSLayoutConstraint *constraint in [panel.constraints copy]) {
        BOOL isHeight=(constraint.firstAttribute==NSLayoutAttributeHeight || constraint.secondAttribute==NSLayoutAttributeHeight);
        BOOL ownsView=(constraint.firstItem==view || constraint.secondItem==view);
        if (isHeight && ownsView && constraint.constant > 55.0 && constraint.constant < 60.0) constraint.constant=constraint.constant*0.90;
    }
}

static void PH234CompactGUI(UIViewController *vc, BOOL elementMode) {
    UIView *panel=PH234Panel(vc);
    if (!panel) return;
    UIButton *copy=PH234FindButton(panel,@"Copiar");
    UIButton *hidden=PH234FindButton(panel,@"Ocultos");
    UIButton *hide=PH234FindButton(panel,@"Ocultar");
    UIButton *json=PH234FindButton(panel,@"JSON");
    UIButton *close=PH234FindButton(panel,@"Fechar");
    UIButton *save=PH234FindButton(panel,@"Salvar");
    PH234ShrinkHeightConstraint(panel,copy.superview);
    PH234ShrinkHeightConstraint(panel,hidden.superview);
    PH234ShrinkHeightConstraint(panel,hide.superview);
    PH234ShrinkHeightConstraint(panel,json.superview.superview);
    for (NSLayoutConstraint *constraint in [panel.constraints copy]) if (constraint.firstItem==panel && constraint.firstAttribute==NSLayoutAttributeBottom && constraint.constant > -20.0) constraint.constant=-35.0;
    if (copy) PH234AlignButtonLeft(copy);
    if (hidden) PH234AlignButtonLeft(hidden);
    if (hide) PH234AlignButtonLeft(hide);
    PH234MakeButtonLabelFit(copy); PH234MakeButtonLabelFit(hidden); PH234MakeButtonLabelFit(hide); PH234MakeButtonLabelFit(json); PH234MakeButtonLabelFit(close); PH234MakeButtonLabelFit(save);
}

static void PH234UpdateNavigationButton(PHInspectorViewController *vc) {
    BOOL tree=PH234Tree(vc);
    UIButton *left=PH234FindButton(vc.view,@"Hierarquia");
    if (!left) left=PH234FindButton(vc.view,@"Elemento");
    if (!left) left=PH234FindButton(vc.view,@"Voltar");
    if (!left) return;
    NSString *title=tree ? @"Voltar" : @"Elemento";
    NSString *symbol=tree ? @"chevron.left" : @"list.bullet.indent";
    UIImage *image=[UIImage systemImageNamed:symbol];
    UIColor *blue=[UIColor colorWithRed:0.039 green:0.518 blue:1.0 alpha:1.0];
    [left setTitle:title forState:UIControlStateNormal];
    if (image) [left setImage:image forState:UIControlStateNormal];
    left.tintColor=blue; [left setTitleColor:blue forState:UIControlStateNormal]; PH234MakeButtonLabelFit(left);
    [left removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [left addTarget:vc action:@selector(backTapped) forControlEvents:UIControlEventTouchUpInside];
}

static void PH234ApplyUI(PHInspectorViewController *vc) {
    dispatch_async(dispatch_get_main_queue(),^{ PH234UpdateNavigationButton(vc); PH234CompactGUI(vc,!PH234Tree(vc)); });
}

static void (*PH234OrigShowInspector)(id,SEL,NSString*,NSString*);
static void (*PH234OrigShowSelectedWeb)(id,SEL,NSString*);
static void (*PH234OrigRender)(id,SEL,BOOL);
static void (*PH234OrigBack)(id,SEL);
static void (*PH234OrigHierarchy)(id,SEL);

static void PH234ShowInspector(id self, SEL _cmd, NSString *details, NSString *subtitle) {
    NSString *payload = details ?: @"";
    PH234Set(self,kPH234SelectedCode,payload);
    PH234Set(self,kPH234SelectedSubtitle,subtitle ?: @"Elemento Web selecionado");

    if (PH234LooksLikeElementDetails(payload)) {
        PH234SetTree(self,NO);
        @try { [self setValue:payload forKey:@"currentDetails"]; } @catch (__unused NSException *e) {}
        @try { [self setValue:(subtitle ?: @"Elemento Web selecionado") forKey:@"currentSubtitle"]; } @catch (__unused NSException *e) {}
        if(PH234OrigShowInspector) PH234OrigShowInspector(self,_cmd,payload,subtitle);
        dispatch_async(dispatch_get_main_queue(),^{
            PH234SetTree(self,NO);
            @try { [self setValue:payload forKey:@"currentDetails"]; } @catch (__unused NSException *e) {}
            @try { [self setValue:(subtitle ?: @"Elemento Web selecionado") forKey:@"currentSubtitle"]; } @catch (__unused NSException *e) {}
            if(PH234OrigRender) PH234OrigRender(self,@selector(render:),NO);
            PH234ApplyUI((PHInspectorViewController *)self);
        });
        return;
    }

    PH234SetTree(self,YES);
    if(PH234OrigShowInspector) PH234OrigShowInspector(self,_cmd,payload,subtitle);
    dispatch_async(dispatch_get_main_queue(),^{
        id manager=[NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)];
        if([manager respondsToSelector:@selector(showHierarchy)]) [manager performSelector:@selector(showHierarchy)];
        PH234SetTree(self,YES); PH234ApplyUI((PHInspectorViewController *)self);
    });
}

static void PH234ShowSelectedWeb(id self, SEL _cmd, NSString *details) {
    NSString *payload = details ?: @"";
    @try { [self setValue:payload forKey:@"currentDetails"]; } @catch (__unused NSException *e) {}
    @try { [self setValue:@"Elemento Web selecionado" forKey:@"currentSubtitle"]; } @catch (__unused NSException *e) {}
    PH234Set(self,kPH234SelectedCode,payload);
    PH234Set(self,kPH234SelectedSubtitle,@"Elemento Web selecionado");
    PH234SetTree(self,NO);
    if(PH234OrigShowSelectedWeb) PH234OrigShowSelectedWeb(self,_cmd,payload);
    dispatch_async(dispatch_get_main_queue(),^{
        PH234SetTree(self,NO);
        @try { [self setValue:payload forKey:@"currentDetails"]; } @catch (__unused NSException *e) {}
        @try { [self setValue:@"Elemento Web selecionado" forKey:@"currentSubtitle"]; } @catch (__unused NSException *e) {}
        if(PH234OrigRender) PH234OrigRender(self,@selector(render:),NO);
        PH234ApplyUI((PHInspectorViewController *)self);
    });
}

static void PH234Render(id self, SEL _cmd, BOOL hierarchyMode) {
    if(PH234OrigRender) PH234OrigRender(self,_cmd,hierarchyMode);
    PH234ApplyUI((PHInspectorViewController *)self);
}

static void PH234Back(id self, SEL _cmd) {
    PHInspectorViewController *vc=(PHInspectorViewController *)self;
    if(PH234Tree(self)) {
        vc.currentDetails=PH234Get(self,kPH234SelectedCode) ?: @"";
        vc.currentSubtitle=PH234Get(self,kPH234SelectedSubtitle) ?: @"Elemento Web selecionado";
        vc.showingHierarchy=NO; PH234SetTree(self,NO);
        if(PH234OrigRender) PH234OrigRender(self,@selector(render:),NO);
        PH234ApplyUI(vc); return;
    }
    id manager=[NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)];
    if([manager respondsToSelector:@selector(showHierarchy)]) [manager performSelector:@selector(showHierarchy)];
    PH234SetTree(self,YES);
    if(PH234OrigRender) PH234OrigRender(self,@selector(render:),YES);
    PH234ApplyUI(vc);
}

static void PH234Hierarchy(id self, SEL _cmd) {
    id manager=[NSClassFromString(@"PHOverlayManager") performSelector:@selector(sharedManager)];
    if([manager respondsToSelector:@selector(showHierarchy)]) [manager performSelector:@selector(showHierarchy)];
    PH234SetTree(self,YES); PH234ApplyUI((PHInspectorViewController *)self);
}

__attribute__((constructor)) static void PH234Install(void) {
    dispatch_async(dispatch_get_main_queue(),^{
        Class c=NSClassFromString(@"PHInspectorViewController"); if(!c)return; Method m;
        m=class_getInstanceMethod(c,@selector(showInspectorDetails:subtitle:)); if(m){PH234OrigShowInspector=(void*)method_getImplementation(m);method_setImplementation(m,(IMP)PH234ShowInspector);}
        m=class_getInstanceMethod(c,@selector(showSelectedWebElement:)); if(m){PH234OrigShowSelectedWeb=(void*)method_getImplementation(m);method_setImplementation(m,(IMP)PH234ShowSelectedWeb);}
        m=class_getInstanceMethod(c,@selector(render:)); if(m){PH234OrigRender=(void*)method_getImplementation(m);method_setImplementation(m,(IMP)PH234Render);}
        m=class_getInstanceMethod(c,@selector(backTapped)); if(m){PH234OrigBack=(void*)method_getImplementation(m);method_setImplementation(m,(IMP)PH234Back);}
        m=class_getInstanceMethod(c,@selector(hierarchyTapped)); if(m){PH234OrigHierarchy=(void*)method_getImplementation(m);method_setImplementation(m,(IMP)PH234Hierarchy);}
    });
}
