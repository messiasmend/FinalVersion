#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface PHInspectorViewController : UIViewController
@property(nonatomic,copy) NSString *currentDetails;
@property(nonatomic,copy) NSString *currentSubtitle;
@property(nonatomic,copy) NSString *detailsBeforeHierarchy;
@property(nonatomic,copy) NSString *subtitleBeforeHierarchy;
@property(nonatomic,assign) BOOL showingHierarchy;
- (void)hierarchyTapped;
- (void)backTapped;
- (void)copyTapped;
- (void)closeTapped;
- (void)hideTapped;
- (void)hiddenTapped;
- (void)saveTapped;
@end

static UIColor *P233C(NSString *hex) {
    unsigned v=0; [[NSScanner scannerWithString:[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]] scanHexInt:&v];
    return [UIColor colorWithRed:((v>>16)&255)/255.0 green:((v>>8)&255)/255.0 blue:(v&255)/255.0 alpha:1];
}
static UILabel *P233Label(NSString *text, UIFont *font, UIColor *color) {
    UILabel *l=[UILabel new]; l.translatesAutoresizingMaskIntoConstraints=NO; l.text=text?:@""; l.font=font; l.textColor=color; l.numberOfLines=0; return l;
}
static UIView *P233Card(void) {
    UIView *v=[UIView new]; v.translatesAutoresizingMaskIntoConstraints=NO; v.backgroundColor=P233C(@"#17191D"); v.layer.cornerRadius=17; v.layer.borderWidth=1; v.layer.borderColor=P233C(@"#34373D").CGColor; v.layer.masksToBounds=YES; return v;
}
static UIButton *P233Button(PHInspectorViewController *vc, NSString *title, NSString *symbol, SEL action, UIColor *tint, UIColor *fill, BOOL border) {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; b.translatesAutoresizingMaskIntoConstraints=NO; b.titleLabel.font=[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [b setTitle:title forState:UIControlStateNormal]; [b setTitleColor:tint forState:UIControlStateNormal]; b.tintColor=tint; b.backgroundColor=fill; b.layer.cornerRadius=16; b.layer.masksToBounds=YES;
    if(border){b.layer.borderWidth=1;b.layer.borderColor=P233C(@"#30343A").CGColor;}
    if(symbol.length){UIImage *im=[UIImage systemImageNamed:symbol]; if(im){[b setImage:im forState:UIControlStateNormal]; b.titleEdgeInsets=UIEdgeInsetsMake(0,9,0,0); b.imageEdgeInsets=UIEdgeInsetsMake(0,-4,0,0);}}
    [b addTarget:vc action:action forControlEvents:UIControlEventTouchUpInside]; return b;
}
static NSDictionary *P233Parse(NSString *details) {
    NSMutableDictionary *r=[NSMutableDictionary dictionary]; NSArray *lines=[details componentsSeparatedByString:@"\n"];
    NSSet *known=[NSSet setWithObjects:@"HTML",@"ID",@"Classe",@"Classes",@"Tipo",@"Texto",@"Link",nil];
    for(NSString *line in lines){NSString *s=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];NSRange c=[s rangeOfString:@":"];if(c.location==NSNotFound)continue;NSString*k=[[s substringToIndex:c.location] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];NSString*v=[[s substringFromIndex:c.location+1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if([known containsObject:k]&&v.length)r[k]=v;}
    NSMutableArray *rect=[NSMutableArray array]; NSSet *rk=[NSSet setWithObjects:@"x",@"y",@"largura",@"altura",nil];
    for(NSString *line in lines){NSString*s=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];NSRange c=[s rangeOfString:@":"];if(c.location==NSNotFound)continue;NSString*k=[[s substringToIndex:c.location] lowercaseString];NSString*v=[[s substringFromIndex:c.location+1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];if([rk containsObject:k]&&v.length)[rect addObject:[NSString stringWithFormat:@"%@: %@",k.capitalizedString,v]];}
    if(rect.count)r[@"Retângulo (Rect)"]=[rect componentsJoinedByString:@"  "];
    return r;
}
static void P233AddRow(UIView *card, NSString *key, NSString *value, CGFloat y) {
    UILabel*k=P233Label(key,[UIFont systemFontOfSize:14.5],P233C(@"#8F949D")); UILabel*v=P233Label(value,[UIFont systemFontOfSize:15],UIColor.whiteColor); v.textAlignment=NSTextAlignmentRight; v.lineBreakMode=NSLineBreakByTruncatingMiddle;
    [card addSubview:k];[card addSubview:v];
    [NSLayoutConstraint activateConstraints:@[[k.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],[k.topAnchor constraintEqualToAnchor:card.topAnchor constant:y],[v.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],[v.centerYAnchor constraintEqualToAnchor:k.centerYAnchor],[v.leadingAnchor constraintGreaterThanOrEqualToAnchor:k.trailingAnchor constant:8]]];
}
static void P233Render(id self, SEL _cmd, BOOL hierarchyMode) {
    PHInspectorViewController *vc=(PHInspectorViewController*)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        for(UIView*v in vc.view.subviews.copy)[v removeFromSuperview]; vc.view.backgroundColor=UIColor.clearColor;
        UIView *panel=[UIView new];panel.translatesAutoresizingMaskIntoConstraints=NO;panel.backgroundColor=P233C(@"#0E1013");panel.layer.cornerRadius=26;panel.layer.borderWidth=1;panel.layer.borderColor=P233C(@"#35383E").CGColor;panel.layer.masksToBounds=YES;[vc.view addSubview:panel];
        UIView*h=[UIView new];h.translatesAutoresizingMaskIntoConstraints=NO;h.backgroundColor=P233C(@"#4B4F57");h.layer.cornerRadius=4;[panel addSubview:h];
        UILabel*t=P233Label(@"WebHider Inspector",[UIFont systemFontOfSize:25 weight:UIFontWeightBold],UIColor.whiteColor);t.textAlignment=NSTextAlignmentCenter;[panel addSubview:t];
        NSString *sub=vc.currentSubtitle.length?vc.currentSubtitle:@"Elemento Web selecionado"; if(hierarchyMode)sub=@"Hierarquia DOM";
        UILabel*s=P233Label(sub,[UIFont systemFontOfSize:16],P233C(@"#8F949D"));s.textAlignment=NSTextAlignmentCenter;[panel addSubview:s];
        UIView *info=P233Card();[panel addSubview:info];
        UIImageView*icon=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"doc.text"]];icon.translatesAutoresizingMaskIntoConstraints=NO;icon.tintColor=P233C(@"#0A84FF");[info addSubview:icon];
        UILabel*it=P233Label(@"Informações do elemento",[UIFont systemFontOfSize:19 weight:UIFontWeightMedium],UIColor.whiteColor);[info addSubview:it];
        UIImageView*chev=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"chevron.right"]];chev.translatesAutoresizingMaskIntoConstraints=NO;chev.tintColor=P233C(@"#8F949D");[info addSubview:chev];
        [NSLayoutConstraint activateConstraints:@[[icon.leadingAnchor constraintEqualToAnchor:info.leadingAnchor constant:20],[icon.topAnchor constraintEqualToAnchor:info.topAnchor constant:16],[icon.widthAnchor constraintEqualToConstant:23],[icon.heightAnchor constraintEqualToConstant:23],[it.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:15],[it.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],[chev.trailingAnchor constraintEqualToAnchor:info.trailingAnchor constant:-18],[chev.centerYAnchor constraintEqualToAnchor:icon.centerYAnchor],[chev.widthAnchor constraintEqualToConstant:16],[chev.heightAnchor constraintEqualToConstant:16]]];
        BOOL elementMode=(!hierarchyMode && [sub isEqualToString:@"Elemento Web selecionado"]);
        BOOL rawMode=hierarchyMode || elementMode || [sub isEqualToString:@"Filtro JSON"];
        if(rawMode){
            UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.alwaysBounceVertical=YES;scroll.showsVerticalScrollIndicator=YES;scroll.indicatorStyle=UIScrollViewIndicatorStyleWhite;scroll.backgroundColor=P233C(@"#15171B");scroll.layer.cornerRadius=10;scroll.layer.masksToBounds=YES;[info addSubview:scroll];
            UILabel *content=P233Label(vc.currentDetails,[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular],UIColor.whiteColor);[scroll addSubview:content];
            [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:info.leadingAnchor constant:12],[scroll.trailingAnchor constraintEqualToAnchor:info.trailingAnchor constant:-12],[scroll.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:12],[scroll.bottomAnchor constraintEqualToAnchor:info.bottomAnchor constant:-12],[content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:10],[content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:10],[content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-10],[content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-10],[content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-20]]];
        } else {
            NSMutableDictionary *rows=[P233Parse(vc.currentDetails?:@"") mutableCopy];
            if(!rows)rows=[NSMutableDictionary dictionary];
            if(rows[@"HTML"]&&!rows[@"Tipo"])rows[@"Tipo"]=rows[@"HTML"];
            NSMutableArray *preferred=[NSMutableArray array];for(NSString*k in @[@"Tipo",@"ID",@"Classes",@"Classe",@"Texto",@"Retângulo (Rect)"])if(rows[k]&&![preferred containsObject:k]){if([k isEqualToString:@"Classe"]&&rows[@"Classes"])continue;[preferred addObject:k];}
            CGFloat y=53;for(NSString*k in preferred){P233AddRow(info,k,rows[k],y);y+=30;if(y>168)break;}
        }
        BOOL back=elementMode || [sub isEqualToString:@"Filtro JSON"];
        UIView *seg=[UIView new];seg.translatesAutoresizingMaskIntoConstraints=NO;seg.backgroundColor=P233C(@"#15171B");seg.layer.cornerRadius=17;seg.layer.borderWidth=1;seg.layer.borderColor=P233C(@"#2B2E35").CGColor;seg.layer.masksToBounds=YES;[panel addSubview:seg];
        UIButton *left=P233Button(vc,back?@"Elemento":@"Voltar",back?@"list.bullet.indent":@"chevron.left",back?@selector(backTapped):@selector(hierarchyTapped),P233C(@"#0A84FF"),P233C(@"#191D24"),YES);
        UIButton *json=P233Button(vc,@"JSON",@"curlybraces",NSSelectorFromString(@"ph_jsonTapped26"),P233C(@"#C7CBD1"),P233C(@"#15171B"),YES);[seg addSubview:left];[seg addSubview:json];
        UIView *copyC=P233Card();copyC.backgroundColor=P233C(@"#15171B");[panel addSubview:copyC];
        UIImageView *copyIcon=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"doc.on.doc"]];copyIcon.translatesAutoresizingMaskIntoConstraints=NO;copyIcon.tintColor=P233C(@"#0A84FF");[copyC addSubview:copyIcon];
        UILabel *copyTitle=P233Label(@"COPIAR",[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold],UIColor.whiteColor);copyTitle.textAlignment=NSTextAlignmentCenter;[copyC addSubview:copyTitle];
        UIButton*copy=[UIButton buttonWithType:UIButtonTypeSystem];copy.translatesAutoresizingMaskIntoConstraints=NO;copy.backgroundColor=UIColor.clearColor;[copy addTarget:vc action:@selector(copyTapped) forControlEvents:UIControlEventTouchUpInside];[copyC addSubview:copy];
        UIView *hiddenC=P233Card();hiddenC.backgroundColor=P233C(@"#15171B");[panel addSubview:hiddenC];
        UIImageView *hiddenIcon=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"eye.slash"]];hiddenIcon.translatesAutoresizingMaskIntoConstraints=NO;hiddenIcon.tintColor=P233C(@"#A970FF");[hiddenC addSubview:hiddenIcon];
        UILabel *hiddenTitle=P233Label(@"OCULTOS",[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold],UIColor.whiteColor);hiddenTitle.textAlignment=NSTextAlignmentCenter;[hiddenC addSubview:hiddenTitle];
        UIButton*hidden=[UIButton buttonWithType:UIButtonTypeSystem];hidden.translatesAutoresizingMaskIntoConstraints=NO;hidden.backgroundColor=UIColor.clearColor;[hidden addTarget:vc action:@selector(hiddenTapped) forControlEvents:UIControlEventTouchUpInside];[hiddenC addSubview:hidden];
        UIView *hideC=P233Card();hideC.backgroundColor=P233C(@"#281417");hideC.layer.borderColor=P233C(@"#6A2B31").CGColor;[panel addSubview:hideC];
        UIImageView *hideIcon=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:@"eye.slash"]];hideIcon.translatesAutoresizingMaskIntoConstraints=NO;hideIcon.tintColor=P233C(@"#FF5E67");[hideC addSubview:hideIcon];
        UILabel *hideTitle=P233Label(@"OCULTAR",[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold],UIColor.whiteColor);hideTitle.textAlignment=NSTextAlignmentCenter;[hideC addSubview:hideTitle];
        UIButton*hide=[UIButton buttonWithType:UIButtonTypeSystem];hide.translatesAutoresizingMaskIntoConstraints=NO;hide.backgroundColor=UIColor.clearColor;[hide addTarget:vc action:@selector(hideTapped) forControlEvents:UIControlEventTouchUpInside];[hideC addSubview:hide];
        UIButton*close=P233Button(vc,@"Fechar",@"xmark",@selector(closeTapped),UIColor.whiteColor,P233C(@"#17191D"),YES);[panel addSubview:close];
        UIButton*save=P233Button(vc,@"Salvar",@"square.and.arrow.down",@selector(saveTapped),UIColor.whiteColor,P233C(@"#0A84FF"),NO);[panel addSubview:save];
        [NSLayoutConstraint activateConstraints:@[
            [panel.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],[panel.centerYAnchor constraintEqualToAnchor:vc.view.centerYAnchor],[panel.widthAnchor constraintEqualToConstant:350],[panel.heightAnchor constraintEqualToConstant:530],
            [h.topAnchor constraintEqualToAnchor:panel.topAnchor constant:15],[h.centerXAnchor constraintEqualToAnchor:panel.centerXAnchor],[h.widthAnchor constraintEqualToConstant:60],[h.heightAnchor constraintEqualToConstant:6],
            [t.topAnchor constraintEqualToAnchor:h.bottomAnchor constant:18],[t.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:15],[t.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-15],
            [s.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:4],[s.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:15],[s.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-15],
            [info.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14],[info.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14],[info.topAnchor constraintEqualToAnchor:s.bottomAnchor constant:16],[info.heightAnchor constraintEqualToConstant:180],
            [seg.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14],[seg.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14],[seg.topAnchor constraintEqualToAnchor:info.bottomAnchor constant:12],[seg.heightAnchor constraintEqualToConstant:43],
            [left.leadingAnchor constraintEqualToAnchor:seg.leadingAnchor constant:5],[left.topAnchor constraintEqualToAnchor:seg.topAnchor constant:5],[left.bottomAnchor constraintEqualToAnchor:seg.bottomAnchor constant:-5],[left.widthAnchor constraintEqualToAnchor:seg.widthAnchor multiplier:.5 constant:-7.5],
            [json.trailingAnchor constraintEqualToAnchor:seg.trailingAnchor constant:-5],[json.topAnchor constraintEqualToAnchor:seg.topAnchor constant:5],[json.bottomAnchor constraintEqualToAnchor:seg.bottomAnchor constant:-5],[json.widthAnchor constraintEqualToAnchor:left.widthAnchor],
            [copyC.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14],[copyC.topAnchor constraintEqualToAnchor:seg.bottomAnchor constant:10],[copyC.heightAnchor constraintEqualToConstant:108],[copyC.widthAnchor constraintEqualToConstant:102],
            [hiddenC.leadingAnchor constraintEqualToAnchor:copyC.trailingAnchor constant:8],[hiddenC.topAnchor constraintEqualToAnchor:copyC.topAnchor],[hiddenC.heightAnchor constraintEqualToAnchor:copyC.heightAnchor],[hiddenC.widthAnchor constraintEqualToAnchor:copyC.widthAnchor],
            [hideC.leadingAnchor constraintEqualToAnchor:hiddenC.trailingAnchor constant:8],[hideC.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14],[hideC.topAnchor constraintEqualToAnchor:copyC.topAnchor],[hideC.heightAnchor constraintEqualToAnchor:copyC.heightAnchor],
            [copyIcon.centerXAnchor constraintEqualToAnchor:copyC.centerXAnchor],[copyIcon.centerYAnchor constraintEqualToAnchor:copyC.centerYAnchor constant:-18],[copyIcon.widthAnchor constraintEqualToConstant:30],[copyIcon.heightAnchor constraintEqualToConstant:30],
            [copyTitle.centerXAnchor constraintEqualToAnchor:copyC.centerXAnchor],[copyTitle.centerYAnchor constraintEqualToAnchor:copyC.centerYAnchor constant:25],[copyTitle.heightAnchor constraintEqualToConstant:20],
            [copy.leadingAnchor constraintEqualToAnchor:copyC.leadingAnchor],[copy.trailingAnchor constraintEqualToAnchor:copyC.trailingAnchor],[copy.topAnchor constraintEqualToAnchor:copyC.topAnchor],[copy.bottomAnchor constraintEqualToAnchor:copyC.bottomAnchor],
            [hiddenIcon.centerXAnchor constraintEqualToAnchor:hiddenC.centerXAnchor],[hiddenIcon.centerYAnchor constraintEqualToAnchor:hiddenC.centerYAnchor constant:-18],[hiddenIcon.widthAnchor constraintEqualToConstant:30],[hiddenIcon.heightAnchor constraintEqualToConstant:30],
            [hiddenTitle.centerXAnchor constraintEqualToAnchor:hiddenC.centerXAnchor],[hiddenTitle.centerYAnchor constraintEqualToAnchor:hiddenC.centerYAnchor constant:25],[hiddenTitle.heightAnchor constraintEqualToConstant:20],
            [hidden.leadingAnchor constraintEqualToAnchor:hiddenC.leadingAnchor],[hidden.trailingAnchor constraintEqualToAnchor:hiddenC.trailingAnchor],[hidden.topAnchor constraintEqualToAnchor:hiddenC.topAnchor],[hidden.bottomAnchor constraintEqualToAnchor:hiddenC.bottomAnchor],
            [hideIcon.centerXAnchor constraintEqualToAnchor:hideC.centerXAnchor],[hideIcon.centerYAnchor constraintEqualToAnchor:hideC.centerYAnchor constant:-18],[hideIcon.widthAnchor constraintEqualToConstant:30],[hideIcon.heightAnchor constraintEqualToConstant:30],
            [hideTitle.centerXAnchor constraintEqualToAnchor:hideC.centerXAnchor],[hideTitle.centerYAnchor constraintEqualToAnchor:hideC.centerYAnchor constant:25],[hideTitle.heightAnchor constraintEqualToConstant:20],
            [hide.leadingAnchor constraintEqualToAnchor:hideC.leadingAnchor],[hide.trailingAnchor constraintEqualToAnchor:hideC.trailingAnchor],[hide.topAnchor constraintEqualToAnchor:hideC.topAnchor],[hide.bottomAnchor constraintEqualToAnchor:hideC.bottomAnchor],
            [close.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:14],[close.topAnchor constraintEqualToAnchor:copyC.bottomAnchor constant:18],[close.heightAnchor constraintEqualToConstant:46],[close.trailingAnchor constraintEqualToAnchor:panel.centerXAnchor constant:-5],
            [save.leadingAnchor constraintEqualToAnchor:panel.centerXAnchor constant:5],[save.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-14],[save.topAnchor constraintEqualToAnchor:close.topAnchor],[save.heightAnchor constraintEqualToAnchor:close.heightAnchor]
        ]];
    });
}
__attribute__((constructor)) static void P233Install(void){dispatch_async(dispatch_get_main_queue(),^{Class c=NSClassFromString(@"PHInspectorViewController");Method m=class_getInstanceMethod(c,@selector(render:));if(c&&m)method_setImplementation(m,(IMP)P233Render);});}
