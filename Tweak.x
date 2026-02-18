// Animal Company VR - Mod Menu
// Built for PhotonPUN2 + PhotonVR architecture
// Tweak.x

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ── Globals ──
static UIWindow  *gModWindow    = nil;
static UIView    *gMenuView     = nil;
static UIButton  *gFloatBtn     = nil;
static BOOL       gMenuVisible  = NO;
static int        gSpawnAmount  = 1;
static UILabel   *gAmountLabel  = nil;
static UIView    *gColorPreview = nil;
static UIColor   *gPickedColor  = nil;

// ─────────────────────────────────────────────
// PHOTON HELPERS
// These mirror how PhotonVR/PUN2 games work:
// - Items spawned via PhotonNetwork.Instantiate
// - Player color stored in CustomProperties["Colour"]
// - Synced via photonView RPC RPCRefreshPlayerValues
// ─────────────────────────────────────────────

// Spawn item via PhotonNetwork.Instantiate (the way all gtag fan games do it)
static void photonSpawnItem(NSString *prefabName, int amount) {
    // PhotonNetwork class (Photon PUN2 compiled into Unity IL2CPP)
    Class photonNet = NSClassFromString(@"Photon.Pun.PhotonNetwork")
                   ?: NSClassFromString(@"PhotonNetwork");

    for (int i = 0; i < amount; i++) {
        if (photonNet) {
            // PhotonNetwork.Instantiate(prefabName, Vector3.zero, Quaternion.identity)
            SEL instantiateSel = NSSelectorFromString(@"Instantiate:position:rotation:");
            if ([photonNet respondsToSelector:instantiateSel]) {
                // Vector3(0,0,0) and Quaternion.identity packed as structs
                // Since IL2CPP mangles these, we use NSInvocation
                NSMethodSignature *sig = [photonNet methodSignatureForSelector:instantiateSel];
                if (sig) {
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    inv.target = photonNet;
                    inv.selector = instantiateSel;

                    // position: float[3] = {0,0,0}
                    float pos[3] = {0.0f, 0.0f, 0.0f};
                    // rotation: float[4] = {0,0,0,1} (identity quaternion)
                    float rot[4] = {0.0f, 0.0f, 0.0f, 1.0f};

                    [inv setArgument:&prefabName atIndex:2];
                    [inv setArgument:&pos        atIndex:3];
                    [inv setArgument:&rot        atIndex:4];
                    [inv invoke];

                    NSLog(@"[ModMenu] PhotonNetwork.Instantiate: %@", prefabName);
                    continue;
                }
            }
        }

        // Fallback: try PhotonVRManager or RoomManager spawn methods
        Class roomMgr = NSClassFromString(@"RoomManager")
                     ?: NSClassFromString(@"PhotonVRManager")
                     ?: NSClassFromString(@"GameManager");
        if (roomMgr) {
            id inst = [roomMgr performSelector:@selector(instance)]
                   ?: [roomMgr performSelector:@selector(sharedInstance)];
            SEL s = NSSelectorFromString(@"SpawnItem:");
            if (inst && [inst respondsToSelector:s]) {
                [inst performSelector:s withObject:prefabName];
                NSLog(@"[ModMenu] SpawnItem via RoomManager: %@", prefabName);
                continue;
            }
        }

        // Last resort: notification for the game to handle
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"ACModSpawn"
            object:nil
            userInfo:@{@"prefab": prefabName}];
        NSLog(@"[ModMenu] Fallback notification spawn: %@", prefabName);
    }
}

// Set player controller color via Photon CustomProperties
// Mirrors: photonView.Owner.CustomProperties["Colour"] = JsonUtility.ToJson(color)
static void setControllerColor(UIColor *color) {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];

    // Build the JSON string Photon stores: {"r":1.0,"g":0.0,"b":0.0,"a":1.0}
    NSString *colorJson = [NSString stringWithFormat:
        @"{\"r\":%.4f,\"g\":%.4f,\"b\":%.4f,\"a\":%.4f}", r, g, b, a];

    // Try to set via PhotonVRPlayer
    Class playerCls = NSClassFromString(@"Photon.VR.Player.PhotonVRPlayer")
                   ?: NSClassFromString(@"PhotonVRPlayer")
                   ?: NSClassFromString(@"VRPlayer");

    if (playerCls) {
        // Get local player instance (PhotonVRManager.Manager.LocalPlayer)
        Class mgrCls = NSClassFromString(@"Photon.VR.PhotonVRManager")
                    ?: NSClassFromString(@"PhotonVRManager");
        if (mgrCls) {
            id mgr = [mgrCls performSelector:@selector(Manager)];
            if (mgr) {
                id localPlayer = [mgr performSelector:@selector(LocalPlayer)];
                if (localPlayer) {
                    // Set CustomProperties["Colour"] = colorJson
                    SEL setPropSel = NSSelectorFromString(@"SetCustomProperty:value:");
                    if ([localPlayer respondsToSelector:setPropSel]) {
                        [localPlayer performSelector:setPropSel
                                         withObject:@"Colour"
                                         withObject:colorJson];
                    }
                    // Call RPCRefreshPlayerValues to sync across network
                    SEL refreshSel = NSSelectorFromString(@"RefreshPlayerValues");
                    if ([localPlayer respondsToSelector:refreshSel]) {
                        [localPlayer performSelector:refreshSel];
                    }
                    NSLog(@"[ModMenu] Color set via PhotonVRPlayer: %@", colorJson);
                    return;
                }
            }
        }
    }

    // Fallback: set via PhotonNetwork.LocalPlayer.CustomProperties
    Class photonNet = NSClassFromString(@"Photon.Pun.PhotonNetwork")
                   ?: NSClassFromString(@"PhotonNetwork");
    if (photonNet) {
        id localPlayer = [photonNet performSelector:@selector(LocalPlayer)];
        if (localPlayer) {
            SEL setPropSel = NSSelectorFromString(@"SetCustomProperties:");
            NSDictionary *props = @{@"Colour": colorJson};
            if ([localPlayer respondsToSelector:setPropSel]) {
                [localPlayer performSelector:setPropSel withObject:props];
                NSLog(@"[ModMenu] Color set via PhotonNetwork.LocalPlayer: %@", colorJson);
            }
        }
    }
}

// ── Toggle menu ──
static void toggleMenu() {
    gMenuVisible = !gMenuVisible;
    gMenuView.hidden = !gMenuVisible;
    [gFloatBtn setTitle:gMenuVisible ? @"✕" : @"☰" forState:UIControlStateNormal];
}

// ─────────────────────────────────────────────
// Button handler
// ─────────────────────────────────────────────
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
- (void)floatTapped { toggleMenu(); }
- (void)spawnLandmine { photonSpawnItem(@"item_landmine", gSpawnAmount); }
- (void)minusTapped {
    if (gSpawnAmount > 1) gSpawnAmount--;
    gAmountLabel.text = [NSString stringWithFormat:@"%d", gSpawnAmount];
}
- (void)plusTapped {
    if (gSpawnAmount < 50) gSpawnAmount++;
    gAmountLabel.text = [NSString stringWithFormat:@"%d", gSpawnAmount];
}
- (void)colorRed    { gPickedColor = [UIColor redColor];    gColorPreview.backgroundColor = gPickedColor; }
- (void)colorGreen  { gPickedColor = [UIColor greenColor];  gColorPreview.backgroundColor = gPickedColor; }
- (void)colorBlue   { gPickedColor = [UIColor blueColor];   gColorPreview.backgroundColor = gPickedColor; }
- (void)colorYellow { gPickedColor = [UIColor yellowColor]; gColorPreview.backgroundColor = gPickedColor; }
- (void)colorPurple { gPickedColor = [UIColor purpleColor]; gColorPreview.backgroundColor = gPickedColor; }
- (void)redController   { setControllerColor([UIColor redColor]); }
- (void)greenController { setControllerColor([UIColor greenColor]); }
- (void)resetController { setControllerColor([UIColor whiteColor]); }
@end

// ─────────────────────────────────────────────
// Build UI
// ─────────────────────────────────────────────
static UIButton* makeBtn(NSString *title, CGRect frame, UIColor *bg, SEL action) {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = frame;
    btn.backgroundColor = bg;
    btn.layer.cornerRadius = 8;
    btn.layer.masksToBounds = YES;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [btn addTarget:[ACModHandler shared] action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

static UILabel* makeLabel(NSString *text, CGRect frame, UIFont *font, UIColor *color, NSTextAlignment align) {
    UILabel *lbl = [[UILabel alloc] initWithFrame:frame];
    lbl.text = text;
    lbl.font = font;
    lbl.textColor = color;
    lbl.textAlignment = align;
    return lbl;
}

static void buildModMenu() {
    if (gModWindow) return;

    gModWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    gModWindow.windowLevel = UIWindowLevelAlert + 100;
    gModWindow.backgroundColor = [UIColor clearColor];
    gModWindow.hidden = NO;
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = [UIColor clearColor];
    gModWindow.rootViewController = vc;
    [gModWindow makeKeyAndVisible];
    UIView *root = vc.view;

    // ── Floating button ──
    gFloatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    gFloatBtn.frame = CGRectMake(16, 120, 50, 50);
    gFloatBtn.layer.cornerRadius = 25;
    gFloatBtn.layer.masksToBounds = YES;
    gFloatBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.15 alpha:0.9];
    gFloatBtn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.25].CGColor;
    gFloatBtn.layer.borderWidth = 1.5;
    [gFloatBtn setTitle:@"☰" forState:UIControlStateNormal];
    gFloatBtn.titleLabel.font = [UIFont systemFontOfSize:20];
    [gFloatBtn addTarget:[ACModHandler shared] action:@selector(floatTapped) forControlEvents:UIControlEventTouchUpInside];
    [root addSubview:gFloatBtn];

    // ── Menu panel ──
    CGFloat mw = 255, mh = 420;
    gMenuView = [[UIView alloc] initWithFrame:CGRectMake(74, 100, mw, mh)];
    gMenuView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.1 alpha:0.96];
    gMenuView.layer.cornerRadius = 14;
    gMenuView.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    gMenuView.layer.borderWidth = 1;
    gMenuView.hidden = YES;
    [root addSubview:gMenuView];

    CGFloat y = 12, pad = 14;
    CGFloat bw = mw - pad*2;

    // Title
    [gMenuView addSubview:makeLabel(@"🐾 AC Mod Menu", CGRectMake(0, y, mw, 26),
        [UIFont boldSystemFontOfSize:15], [UIColor whiteColor], NSTextAlignmentCenter)];
    y += 30;

    // Sub-title (Photon)
    [gMenuView addSubview:makeLabel(@"Photon PUN2 Network", CGRectMake(0, y, mw, 16),
        [UIFont systemFontOfSize:10], [UIColor colorWithWhite:0.5 alpha:1], NSTextAlignmentCenter)];
    y += 22;

    // Divider
    UIView *d1 = [[UIView alloc] initWithFrame:CGRectMake(pad, y, bw, 1)];
    d1.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [gMenuView addSubview:d1];
    y += 10;

    // SPAWN section header
    [gMenuView addSubview:makeLabel(@"SPAWN", CGRectMake(pad, y, bw, 16),
        [UIFont boldSystemFontOfSize:10], [UIColor colorWithRed:0.4 green:0.8 blue:1 alpha:1], NSTextAlignmentLeft)];
    y += 20;

    // Landmine button
    [gMenuView addSubview:makeBtn(@"💣  Spawn item_landmine",
        CGRectMake(pad, y, bw, 40),
        [UIColor colorWithRed:0.72 green:0.16 blue:0.16 alpha:1],
        @selector(spawnLandmine))];
    y += 50;

    // Amount stepper
    [gMenuView addSubview:makeLabel(@"Amount:", CGRectMake(pad, y+2, 68, 22),
        [UIFont systemFontOfSize:12], [UIColor lightGrayColor], NSTextAlignmentLeft)];

    UIButton *minus = [UIButton buttonWithType:UIButtonTypeSystem];
    minus.frame = CGRectMake(88, y, 32, 26);
    minus.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
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

    UIButton *plus = [UIButton buttonWithType:UIButtonTypeSystem];
    plus.frame = CGRectMake(160, y, 32, 26);
    plus.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1];
    plus.layer.cornerRadius = 6;
    [plus setTitle:@"+" forState:UIControlStateNormal];
    [plus setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    plus.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [plus addTarget:[ACModHandler shared] action:@selector(plusTapped) forControlEvents:UIControlEventTouchUpInside];
    [gMenuView addSubview:plus];
    y += 38;

    // Color picker row
    [gMenuView addSubview:makeLabel(@"Color:", CGRectMake(pad, y+2, 50, 22),
        [UIFont systemFontOfSize:12], [UIColor lightGrayColor], NSTextAlignmentLeft)];

    NSArray *colorDefs = @[
        @[@"R", [UIColor redColor],    NSStringFromSelector(@selector(colorRed))],
        @[@"G", [UIColor greenColor],  NSStringFromSelector(@selector(colorGreen))],
        @[@"B", [UIColor blueColor],   NSStringFromSelector(@selector(colorBlue))],
        @[@"Y", [UIColor yellowColor], NSStringFromSelector(@selector(colorYellow))],
        @[@"P", [UIColor purpleColor], NSStringFromSelector(@selector(colorPurple))],
    ];
    CGFloat cx = 70;
    for (NSArray *def in colorDefs) {
        UIButton *cb = [UIButton buttonWithType:UIButtonTypeCustom];
        cb.frame = CGRectMake(cx, y+1, 24, 24);
        cb.backgroundColor = def[1];
        cb.layer.cornerRadius = 12;
        cb.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.4].CGColor;
        cb.layer.borderWidth = 1.2;
        [cb addTarget:[ACModHandler shared] action:NSSelectorFromString(def[2]) forControlEvents:UIControlEventTouchUpInside];
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

    // Divider
    UIView *d2 = [[UIView alloc] initWithFrame:CGRectMake(pad, y, bw, 1)];
    d2.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [gMenuView addSubview:d2];
    y += 10;

    // CONTROLLER section
    [gMenuView addSubview:makeLabel(@"CONTROLLER COLOR (Photon RPC)", CGRectMake(pad, y, bw, 16),
        [UIFont boldSystemFontOfSize:10], [UIColor colorWithRed:0.4 green:0.8 blue:1 alpha:1], NSTextAlignmentLeft)];
    y += 20;

    CGFloat halfW = (bw - 8) / 2.0;
    [gMenuView addSubview:makeBtn(@"🔴 Red",
        CGRectMake(pad, y, halfW, 36),
        [UIColor colorWithRed:0.65 green:0.1 blue:0.1 alpha:1],
        @selector(redController))];
    [gMenuView addSubview:makeBtn(@"🟢 Green",
        CGRectMake(pad + halfW + 8, y, halfW, 36),
        [UIColor colorWithRed:0.1 green:0.5 blue:0.1 alpha:1],
        @selector(greenController))];
    y += 46;

    [gMenuView addSubview:makeBtn(@"⬜ Reset Controller Color",
        CGRectMake(pad, y, bw, 30),
        [UIColor colorWithWhite:0.2 alpha:1],
        @selector(resetController))];

    NSLog(@"[ModMenu] Built successfully - Photon PUN2 hooks ready");
}

// ─────────────────────────────────────────────
// Hook UIApplication bootstrap
// ─────────────────────────────────────────────
%hook UIApplication
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    BOOL r = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        buildModMenu();
    });
    return r;
}
%end

%ctor {
    NSLog(@"[ModMenu] Animal Company Mod Menu - Photon PUN2 Edition loaded");
    gSpawnAmount = 1;
    gPickedColor = [UIColor redColor];
}
