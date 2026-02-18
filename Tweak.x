// Animal Company VR Companion - Mod Menu
// Tweak.x

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static UIWindow  *gModWindow    = nil;
static UIView    *gMenuView     = nil;
static UIButton  *gFloatBtn     = nil;
static BOOL       gMenuVisible  = NO;
static int        gSpawnAmount  = 1;
static UILabel   *gAmountLabel  = nil;
static UIView    *gColorPreview = nil;
static UIColor   *gPickedColor  = nil;
static BOOL       gMenuBuilt    = NO;

static void photonSpawnItem(NSString *prefabName, int amount) {
    for (int i = 0; i < amount; i++) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        Class photonNet = NSClassFromString(@"PhotonNetwork");
        if (photonNet) {
            SEL s = NSSelectorFromString(@"Instantiate:position:rotation:");
            if ([photonNet respondsToSelector:s]) {
                float pos[3] = {0.0f, 0.0f, 0.0f};
                float rot[4] = {0.0f, 0.0f, 0.0f, 1.0f};
                NSMethodSignature *sig = [photonNet methodSignatureForSelector:s];
                if (sig) {
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    inv.target = photonNet;
                    inv.selector = s;
                    [inv setArgument:&prefabName atIndex:2];
                    [inv setArgument:&pos atIndex:3];
                    [inv setArgument:&rot atIndex:4];
                    [inv invoke];
                    #pragma clang diagnostic pop
                    continue;
                }
            }
        }
        #pragma clang diagnostic pop
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"ACModSpawn"
            object:nil
            userInfo:@{@"prefab": prefabName}];
    }
    NSLog(@"[ModMenu] Spawned %dx %@", amount, prefabName);
}

static void setControllerColor(UIColor *color) {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    NSString *colorJson = [NSString stringWithFormat:
        @"{\"r\":%.4f,\"g\":%.4f,\"b\":%.4f,\"a\":%.4f}", r, g, b, a];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    Class mgrCls = NSClassFromString(@"PhotonVRManager");
    if (mgrCls) {
        id mgr = [mgrCls performSelector:@selector(Manager)];
        if (mgr) {
            id localPlayer = [mgr performSelector:@selector(LocalPlayer)];
            if (localPlayer) {
                SEL s = NSSelectorFromString(@"SetCustomProperty:value:");
                if ([localPlayer respondsToSelector:s])
                    [localPlayer performSelector:s withObject:@"Colour" withObject:colorJson];
                SEL r2 = NSSelectorFromString(@"RefreshPlayerValues");
                if ([localPlayer respondsToSelector:r2])
                    [localPlayer performSelector:r2];
            }
        }
    }
    #pragma clang diagnostic pop
    NSLog(@"[ModMenu] Controller color: %@", colorJson);
}

static void toggleMenu() {
    gMenuVisible = !gMenuVisible;
    gMenuView.hidden = !gMenuVisible;
    [gFloatBtn setTitle:gMenuVisible ? @"✕" : @"☰" forState:UIControlStateNormal];
}

@interface ACModHandler : NSObject
+ (instancetype)shared;
- (void)floatTapped;
- (void)spawnLandmine;
- (void)minusTapped;
- (void)plusTapped;
- (void)colorRed;
- (void)colorGreen;
- (void)colorBlue;
- (void)colorYellow;
- (void)colorPurple;
- (void)redController;
- (void)greenController;
- (void)resetController;
@end

@implementation ACModHandler
+ (instancetype)shared {
    static ACModHandler *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [ACModHandler new]; });
    return s;
}
- (void)floatTapped     { toggleMenu(); }
- (void)spawnLandmine   { photonSpawnItem(@"item_landmine", gSpawnAmount); }
- (void)minusTapped     { if (gSpawnAmount > 1) gSpawnAmount--; gAmountLabel.text = [NSString stringWithFormat:@"%d", gSpawnAmount]; }
- (void)plusTapped      { if (gSpawnAmount < 50) gSpawnAmount++; gAmountLabel.text = [NSString stringWithFormat:@"%d", gSpawnAmount]; }
- (void)colorRed        { gPickedColor = [UIColor redColor];    gColorPreview.backgroundColor = gPickedColor; }
- (void)colorGreen      { gPickedColor = [UIColor greenColor];  gColorPreview.backgroundColor = gPickedColor; }
- (void)colorBlue       { gPickedColor = [UIColor blueColor];   gColorPreview.backgroundColor = gPickedColor; }
- (void)colorYellow     { gPickedColor = [UIColor yellowColor]; gColorPreview.backgroundColor = gPickedColor; }
- (void)colorPurple     { gPickedColor = [UIColor purpleColor]; gColorPreview.backgroundColor = gPickedColor; }
- (void)redController   { setControllerColor([UIColor redColor]); }
- (void)greenController { setControllerColor([UIColor greenColor]); }
- (void)resetController { setControllerColor([UIColor whiteColor]); }
@end

static void buildModMenu() {
    if (gMenuBuilt) return;
    gMenuBuilt = YES;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] &&
                s.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s;
                break;
            }
        }

        if (scene) {
            gModWindow = [[UIWindow alloc] initWithWindowScene:scene];
        } else {
            gModWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }

        gModWindow.windowLevel = UIWindowLevelAlert + 999;
        gModWindow.backgroundColor = [UIColor clearColor];
        gModWindow.userInteractionEnabled = YES;
        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = [UIColor clearColor];
        gModWindow.rootViewController = vc;
        gModWindow.hidden = NO;
        [gModWindow makeKeyAndVisible];

        UIView *root = vc.view;
        CGFloat mw = 255, pad = 14, bw = mw - pad * 2;

        // Floating button
        gFloatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        gFloatBtn.frame = CGRectMake(16, 160, 50, 50);
        gFloatBtn.layer.cornerRadius = 25;
        gFloatBtn.layer.masksToBounds = YES;
        gFloatBtn.backgroundColor = [UIColor colorWithRed:0.05 green:0.6 blue:0.05 alpha:0.95];
        gFloatBtn.layer.borderColor = [UIColor colorWithRed:0.1 green:1 blue:0.1 alpha:0.8].CGColor;
        gFloatBtn.layer.borderWidth = 2;
        [gFloatBtn setTitle:@"☰" forState:UIControlStateNormal];
        [gFloatBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        gFloatBtn.titleLabel.font = [UIFont systemFontOfSize:20];
        [gFloatBtn addTarget:[ACModHandler shared] action:@selector(floatTapped) forControlEvents:UIControlEventTouchUpInside];
        [root addSubview:gFloatBtn];

        // Menu panel
        CGFloat mh = 430;
        gMenuView = [[UIView alloc] initWithFrame:CGRectMake(74, 100, mw, mh)];
        gMenuView.backgroundColor = [UIColor colorWithRed:0.04 green:0.1 blue:0.04 alpha:0.97];
        gMenuView.layer.cornerRadius = 14;
        gMenuView.layer.borderColor = [UIColor colorWithRed:0.1 green:0.8 blue:0.1 alpha:0.4].CGColor;
        gMenuView.layer.borderWidth = 1.5;
        gMenuView.hidden = YES;
        [root addSubview:gMenuView];

        CGFloat y = 12;

        // Title
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, y, mw, 26)];
        title.text = @"🐾 AC Mod Menu";
        title.textColor = [UIColor colorWithRed:0.2 green:1 blue:0.2 alpha:1];
        title.font = [UIFont boldSystemFontOfSize:15];
        title.textAlignment = NSTextAlignmentCenter;
        [gMenuView addSubview:title];
        y += 28;

        UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(0, y, mw, 14)];
        sub.text = @"Photon PUN2";
        sub.textColor = [UIColor colorWithWhite:0.4 alpha:1];
        sub.font = [UIFont systemFontOfSize:10];
        sub.textAlignment = NSTextAlignmentCenter;
        [gMenuView addSubview:sub];
        y += 22;

        UIView *d1 = [[UIView alloc] initWithFrame:CGRectMake(pad, y, bw, 1)];
        d1.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.1 alpha:0.5];
        [gMenuView addSubview:d1];
        y += 10;

        // SPAWN header
        UILabel *spawnHdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, bw, 16)];
        spawnHdr.text = @"SPAWN";
        spawnHdr.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:1 alpha:1];
        spawnHdr.font = [UIFont boldSystemFontOfSize:10];
        [gMenuView addSubview:spawnHdr];
        y += 20;

        // Landmine button
        UIButton *lmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        lmBtn.frame = CGRectMake(pad, y, bw, 40);
        lmBtn.backgroundColor = [UIColor colorWithRed:0.7 green:0.15 blue:0.15 alpha:1];
        lmBtn.layer.cornerRadius = 8;
        [lmBtn setTitle:@"💣  item_landmine" forState:UIControlStateNormal];
        [lmBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        lmBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        [lmBtn addTarget:[ACModHandler shared] action:@selector(spawnLandmine) forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:lmBtn];
        y += 50;

        // Amount stepper
        UILabel *amtLbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, y+2, 68, 22)];
        amtLbl.text = @"Amount:";
        amtLbl.textColor = [UIColor lightGrayColor];
        amtLbl.font = [UIFont systemFontOfSize:12];
        [gMenuView addSubview:amtLbl];

        UIButton *minus = [UIButton buttonWithType:UIButtonTypeSystem];
        minus.frame = CGRectMake(88, y, 32, 26);
        minus.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
        minus.layer.cornerRadius = 6;
        [minus setTitle:@"−" forState:UIControlStateNormal];
        [minus setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        minus.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [minus addTarget:[ACModHandler shared] action:@selector(minusTapped) forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:minus];

        gAmountLabel = [[UILabel alloc] initWithFrame:CGRectMake(126, y, 28, 26)];
        gAmountLabel.text = @"1";
        gAmountLabel.textColor = [UIColor whiteColor];
        gAmountLabel.font = [UIFont boldSystemFontOfSize:15];
        gAmountLabel.textAlignment = NSTextAlignmentCenter;
        [gMenuView addSubview:gAmountLabel];

        UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        plusBtn.frame = CGRectMake(160, y, 32, 26);
        plusBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
        plusBtn.layer.cornerRadius = 6;
        [plusBtn setTitle:@"+" forState:UIControlStateNormal];
        [plusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        plusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        [plusBtn addTarget:[ACModHandler shared] action:@selector(plusTapped) forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:plusBtn];
        y += 38;

        // Color row
        UILabel *colLbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, y+2, 50, 22)];
        colLbl.text = @"Color:";
        colLbl.textColor = [UIColor lightGrayColor];
        colLbl.font = [UIFont systemFontOfSize:12];
        [gMenuView addSubview:colLbl];

        NSArray *colorDefs = @[
            @[[UIColor redColor],    NSStringFromSelector(@selector(colorRed))],
            @[[UIColor greenColor],  NSStringFromSelector(@selector(colorGreen))],
            @[[UIColor blueColor],   NSStringFromSelector(@selector(colorBlue))],
            @[[UIColor yellowColor], NSStringFromSelector(@selector(colorYellow))],
            @[[UIColor purpleColor], NSStringFromSelector(@selector(colorPurple))],
        ];
        CGFloat cx = 70;
        for (NSArray *def in colorDefs) {
            UIButton *cb = [UIButton buttonWithType:UIButtonTypeCustom];
            cb.frame = CGRectMake(cx, y+1, 24, 24);
            cb.backgroundColor = def[0];
            cb.layer.cornerRadius = 12;
            cb.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.4].CGColor;
            cb.layer.borderWidth = 1.2;
            [cb addTarget:[ACModHandler shared] action:NSSelectorFromString(def[1]) forControlEvents:UIControlEventTouchUpInside];
            [gMenuView addSubview:cb];
            cx += 30;
        }
        gColorPreview = [[UIView alloc] initWithFrame:CGRectMake(cx+4, y+1, 24, 24)];
        gColorPreview.backgroundColor = [UIColor redColor];
        gColorPreview.layer.cornerRadius = 12;
        gColorPreview.layer.borderColor = [UIColor whiteColor].CGColor;
        gColorPreview.layer.borderWidth = 1.5;
        [gMenuView addSubview:gColorPreview];
        y += 40;

        UIView *d2 = [[UIView alloc] initWithFrame:CGRectMake(pad, y, bw, 1)];
        d2.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.1 alpha:0.5];
        [gMenuView addSubview:d2];
        y += 10;

        // Controller header
        UILabel *ctrlHdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, bw, 16)];
        ctrlHdr.text = @"CONTROLLER COLOR";
        ctrlHdr.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:1 alpha:1];
        ctrlHdr.font = [UIFont boldSystemFontOfSize:10];
        [gMenuView addSubview:ctrlHdr];
        y += 20;

        CGFloat halfW = (bw - 8) / 2.0;

        UIButton *redBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        redBtn.frame = CGRectMake(pad, y, halfW, 36);
        redBtn.backgroundColor = [UIColor colorWithRed:0.65 green:0.1 blue:0.1 alpha:1];
        redBtn.layer.cornerRadius = 8;
        [redBtn setTitle:@"🔴 Red" forState:UIControlStateNormal];
        [redBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        redBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        [redBtn addTarget:[ACModHandler shared] action:@selector(redController) forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:redBtn];

        UIButton *greenBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        greenBtn.frame = CGRectMake(pad + halfW + 8, y, halfW, 36);
        greenBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.1 alpha:1];
        greenBtn.layer.cornerRadius = 8;
        [greenBtn setTitle:@"🟢 Green" forState:UIControlStateNormal];
        [greenBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        greenBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        [greenBtn addTarget:[ACModHandler shared] action:@selector(greenController) forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:greenBtn];
        y += 46;

        UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        resetBtn.frame = CGRectMake(pad, y, bw, 30);
        resetBtn.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1];
        resetBtn.layer.cornerRadius = 8;
        [resetBtn setTitle:@"⬜ Reset Controller" forState:UIControlStateNormal];
        [resetBtn setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        resetBtn.titleLabel.font = [UIFont systemFontOfSize:12];
        [resetBtn addTarget:[ACModHandler shared] action:@selector(resetController) forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:resetBtn];

        NSLog(@"[ModMenu] Overlay built successfully");
    });
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gMenuBuilt) {
        NSLog(@"[ModMenu] viewDidAppear - building menu");
        buildModMenu();
    }
}
%end

%ctor {
    NSLog(@"[ModMenu] Animal Company Mod Menu loaded");
    gSpawnAmount = 1;
    gPickedColor = [UIColor redColor];
}
