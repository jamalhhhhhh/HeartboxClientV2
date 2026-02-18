// Animal Company VR Companion - Mod Menu
// Uses PrefabGenerator.SpawnItem / SpawnItemAsync
// Tweak.x

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static UIWindow    *gModWindow   = nil;
static UIView      *gMenuView    = nil;
static UIButton    *gFloatBtn    = nil;
static BOOL         gMenuVisible = NO;
static BOOL         gMenuBuilt   = NO;
static int          gSpawnAmount = 1;
static UILabel     *gAmountLabel = nil;
static UITextField *gPrefabField = nil;

// ── Passthrough window ──
@interface ACPassthroughWindow : UIWindow
@end
@implementation ACPassthroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self.rootViewController.view || hit == nil) return nil;
    return hit;
}
@end

// ── Draggable button ──
@interface ACDragButton : UIButton
@property (nonatomic, assign) CGPoint dragStart;
@property (nonatomic, assign) CGPoint centerStart;
@property (nonatomic, assign) BOOL didDrag;
@end
@implementation ACDragButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        _dragStart   = [pan locationInView:self.superview];
        _centerStart = self.center;
        _didDrag     = NO;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint cur = [pan locationInView:self.superview];
        CGFloat dx = cur.x - _dragStart.x;
        CGFloat dy = cur.y - _dragStart.y;
        if (fabs(dx) > 4 || fabs(dy) > 4) _didDrag = YES;
        self.center = CGPointMake(_centerStart.x + dx, _centerStart.y + dy);
    }
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!_didDrag) [super touchesEnded:touches withEvent:event];
    _didDrag = NO;
}
@end

// ── Core spawn using PrefabGenerator ──
static void doSpawn(NSString *prefabName, int amount, float x, float y, float z) {
    for (int i = 0; i < amount; i++) {
        BOOL spawned = NO;

        // Try PrefabGenerator class (from IL2CPP dump)
        Class prefabGen = NSClassFromString(@"PrefabGenerator");
        if (!prefabGen) prefabGen = NSClassFromString(@"ACCompanion.PrefabGenerator");

        if (prefabGen) {
            id instance = [prefabGen performSelector:@selector(instance)]
                       ?: [prefabGen performSelector:@selector(sharedInstance)]
                       ?: [prefabGen performSelector:@selector(Instance)];

            if (instance) {
                // Try SpawnItemAsync first (networked)
                SEL asyncSel = NSSelectorFromString(@"SpawnItemAsync:x:y:z:");
                if ([instance respondsToSelector:asyncSel]) {
                    NSMethodSignature *sig = [instance methodSignatureForSelector:asyncSel];
                    if (sig) {
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        inv.target = instance;
                        inv.selector = asyncSel;
                        [inv setArgument:&prefabName atIndex:2];
                        [inv setArgument:&x atIndex:3];
                        [inv setArgument:&y atIndex:4];
                        [inv setArgument:&z atIndex:5];
                        [inv invoke];
                        spawned = YES;
                        NSLog(@"[ModMenu] SpawnItemAsync: %@ at %.1f,%.1f,%.1f", prefabName, x, y, z);
                    }
                }

                // Try SpawnItem with 3 args (name, x, y, z)
                if (!spawned) {
                    SEL spawnSel = NSSelectorFromString(@"SpawnItem:x:y:z:");
                    if ([instance respondsToSelector:spawnSel]) {
                        NSMethodSignature *sig = [instance methodSignatureForSelector:spawnSel];
                        if (sig) {
                            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                            inv.target = instance;
                            inv.selector = spawnSel;
                            [inv setArgument:&prefabName atIndex:2];
                            [inv setArgument:&x atIndex:3];
                            [inv setArgument:&y atIndex:4];
                            [inv setArgument:&z atIndex:5];
                            [inv invoke];
                            spawned = YES;
                            NSLog(@"[ModMenu] SpawnItem: %@ at %.1f,%.1f,%.1f", prefabName, x, y, z);
                        }
                    }
                }

                // Try SpawnItem with just name
                if (!spawned) {
                    SEL simpleSel = NSSelectorFromString(@"SpawnItem:");
                    if ([instance respondsToSelector:simpleSel]) {
                        [instance performSelector:simpleSel withObject:prefabName];
                        spawned = YES;
                        NSLog(@"[ModMenu] SpawnItem simple: %@", prefabName);
                    }
                }
            }
        }

        // Fallback: PhotonNetwork.Instantiate
        if (!spawned) {
            Class photonNet = NSClassFromString(@"PhotonNetwork");
            if (photonNet) {
                SEL s = NSSelectorFromString(@"Instantiate:position:rotation:");
                NSMethodSignature *sig = [photonNet methodSignatureForSelector:s];
                if (sig) {
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    inv.target = photonNet;
                    inv.selector = s;
                    float pos[3] = {x, y, z};
                    float rot[4] = {0.0f, 0.0f, 0.0f, 1.0f};
                    [inv setArgument:&prefabName atIndex:2];
                    [inv setArgument:&pos atIndex:3];
                    [inv setArgument:&rot atIndex:4];
                    [inv invoke];
                    spawned = YES;
                    NSLog(@"[ModMenu] PhotonNetwork.Instantiate: %@", prefabName);
                }
            }
        }

        // Last resort notification
        if (!spawned) {
            [[NSNotificationCenter defaultCenter]
                postNotificationName:@"ACModSpawn"
                object:nil
                userInfo:@{
                    @"prefab": prefabName,
                    @"source": @"YOUR MENU",
                    @"x": @(x), @"y": @(y), @"z": @(z)
                }];
            NSLog(@"[ModMenu] Fallback notification: %@", prefabName);
        }
    }
}

static void toggleMenu() {
    gMenuVisible = !gMenuVisible;
    gMenuView.hidden = !gMenuVisible;
    [gFloatBtn setTitle:gMenuVisible ? @"✕" : @"☰" forState:UIControlStateNormal];
    if (gMenuVisible) [gPrefabField becomeFirstResponder];
    else [gPrefabField resignFirstResponder];
}

@interface ACModHandler : NSObject
+ (instancetype)shared;
- (void)floatTapped;
- (void)spawnTapped;
- (void)minusTapped;
- (void)plusTapped;
- (void)quickLandmine;
- (void)quickApple;
@end

@implementation ACModHandler
+ (instancetype)shared {
    static ACModHandler *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [ACModHandler new]; });
    return s;
}
- (void)floatTapped  { toggleMenu(); }
- (void)spawnTapped  {
    NSString *name = gPrefabField.text;
    if (name.length == 0) name = @"item_apple";
    [gPrefabField resignFirstResponder];
    doSpawn(name, gSpawnAmount, 0, 0, 0);
}
- (void)minusTapped  {
    if (gSpawnAmount > 1) gSpawnAmount--;
    gAmountLabel.text = [NSString stringWithFormat:@"%d", gSpawnAmount];
}
- (void)plusTapped   {
    if (gSpawnAmount < 50) gSpawnAmount++;
    gAmountLabel.text = [NSString stringWithFormat:@"%d", gSpawnAmount];
}
- (void)quickLandmine { doSpawn(@"item_landmine", gSpawnAmount, 0, 0, 0); }
- (void)quickApple    { doSpawn(@"item_apple",    gSpawnAmount, 0, 0, 0); }
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

        gModWindow = scene
            ? [[ACPassthroughWindow alloc] initWithWindowScene:scene]
            : [[ACPassthroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

        gModWindow.windowLevel = UIWindowLevelAlert + 999;
        gModWindow.backgroundColor = [UIColor clearColor];
        gModWindow.userInteractionEnabled = YES;
        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = [UIColor clearColor];
        gModWindow.rootViewController = vc;
        gModWindow.hidden = NO;
        [gModWindow makeKeyAndVisible];

        UIView *root = vc.view;
        CGFloat pad = 14, mw = 240, bw = mw - pad * 2;

        // ── Float button ──
        gFloatBtn = [[ACDragButton alloc] initWithFrame:CGRectMake(16, 160, 50, 50)];
        gFloatBtn.layer.cornerRadius  = 25;
        gFloatBtn.layer.masksToBounds = YES;
        gFloatBtn.backgroundColor     = [UIColor colorWithRed:0.05 green:0.55 blue:0.05 alpha:0.95];
        gFloatBtn.layer.borderColor   = [UIColor colorWithRed:0.1 green:1 blue:0.1 alpha:0.7].CGColor;
        gFloatBtn.layer.borderWidth   = 2;
        [gFloatBtn setTitle:@"☰" forState:UIControlStateNormal];
        [gFloatBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        gFloatBtn.titleLabel.font = [UIFont systemFontOfSize:20];
        [gFloatBtn addTarget:[ACModHandler shared] action:@selector(floatTapped)
            forControlEvents:UIControlEventTouchUpInside];
        [root addSubview:gFloatBtn];

        // ── Menu panel ──
        gMenuView = [[UIView alloc] initWithFrame:CGRectMake(74, 120, mw, 320)];
        gMenuView.backgroundColor    = [UIColor colorWithRed:0.04 green:0.09 blue:0.04 alpha:0.97];
        gMenuView.layer.cornerRadius = 14;
        gMenuView.layer.borderColor  = [UIColor colorWithRed:0.1 green:0.75 blue:0.1 alpha:0.45].CGColor;
        gMenuView.layer.borderWidth  = 1.5;
        gMenuView.hidden             = YES;
        [root addSubview:gMenuView];

        CGFloat y = 12;

        // Title
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, y, mw, 24)];
        title.text          = @"🐾 AC Mod Menu";
        title.textColor     = [UIColor colorWithRed:0.2 green:1 blue:0.2 alpha:1];
        title.font          = [UIFont boldSystemFontOfSize:14];
        title.textAlignment = NSTextAlignmentCenter;
        [gMenuView addSubview:title];
        y += 30;

        // Section header
        UILabel *spawnHdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, bw, 14)];
        spawnHdr.text      = @"SPAWN ITEM  (pos: 0, 0, 0)";
        spawnHdr.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:1 alpha:1];
        spawnHdr.font      = [UIFont boldSystemFontOfSize:9];
        [gMenuView addSubview:spawnHdr];
        y += 18;

        // Prefab text field
        gPrefabField = [[UITextField alloc] initWithFrame:CGRectMake(pad, y, bw, 34)];
        gPrefabField.backgroundColor   = [UIColor colorWithWhite:0.15 alpha:1];
        gPrefabField.textColor         = [UIColor whiteColor];
        gPrefabField.font              = [UIFont systemFontOfSize:13];
        gPrefabField.layer.cornerRadius = 7;
        gPrefabField.layer.masksToBounds = YES;
        gPrefabField.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.15].CGColor;
        gPrefabField.layer.borderWidth = 1;
        gPrefabField.returnKeyType     = UIReturnKeyDone;
        gPrefabField.autocorrectionType = UITextAutocorrectionTypeNo;
        gPrefabField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0,0,8,34)];
        gPrefabField.leftView = paddingView;
        gPrefabField.leftViewMode = UITextFieldViewModeAlways;
        NSAttributedString *placeholder = [[NSAttributedString alloc]
            initWithString:@"type prefab name..."
            attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.45 alpha:1]}];
        gPrefabField.attributedPlaceholder = placeholder;
        [gMenuView addSubview:gPrefabField];
        y += 42;

        // Spawn button
        UIButton *spawnBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        spawnBtn.frame = CGRectMake(pad, y, bw, 38);
        spawnBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.5 blue:0.15 alpha:1];
        spawnBtn.layer.cornerRadius = 8;
        [spawnBtn setTitle:@"▶  Spawn Item" forState:UIControlStateNormal];
        [spawnBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        spawnBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        [spawnBtn addTarget:[ACModHandler shared] action:@selector(spawnTapped)
            forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:spawnBtn];
        y += 48;

        // Quick buttons
        UILabel *quickHdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, bw, 14)];
        quickHdr.text      = @"QUICK SPAWN";
        quickHdr.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:1 alpha:1];
        quickHdr.font      = [UIFont boldSystemFontOfSize:9];
        [gMenuView addSubview:quickHdr];
        y += 18;

        CGFloat halfW = (bw - 8) / 2.0;

        UIButton *lmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        lmBtn.frame = CGRectMake(pad, y, halfW, 36);
        lmBtn.backgroundColor = [UIColor colorWithRed:0.65 green:0.12 blue:0.12 alpha:1];
        lmBtn.layer.cornerRadius = 8;
        [lmBtn setTitle:@"💣 Landmine" forState:UIControlStateNormal];
        [lmBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        lmBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [lmBtn addTarget:[ACModHandler shared] action:@selector(quickLandmine)
            forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:lmBtn];

        UIButton *appleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        appleBtn.frame = CGRectMake(pad + halfW + 8, y, halfW, 36);
        appleBtn.backgroundColor = [UIColor colorWithRed:0.6 green:0.1 blue:0.4 alpha:1];
        appleBtn.layer.cornerRadius = 8;
        [appleBtn setTitle:@"🍎 Apple" forState:UIControlStateNormal];
        [appleBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        appleBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        [appleBtn addTarget:[ACModHandler shared] action:@selector(quickApple)
            forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:appleBtn];
        y += 46;

        // Amount stepper
        UILabel *amtLbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, y+2, 60, 22)];
        amtLbl.text      = @"Amount:";
        amtLbl.textColor = [UIColor lightGrayColor];
        amtLbl.font      = [UIFont systemFontOfSize:12];
        [gMenuView addSubview:amtLbl];

        UIButton *minus = [UIButton buttonWithType:UIButtonTypeSystem];
        minus.frame = CGRectMake(80, y, 30, 26);
        minus.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
        minus.layer.cornerRadius = 6;
        [minus setTitle:@"−" forState:UIControlStateNormal];
        [minus setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        minus.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        [minus addTarget:[ACModHandler shared] action:@selector(minusTapped)
            forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:minus];

        gAmountLabel = [[UILabel alloc] initWithFrame:CGRectMake(116, y, 26, 26)];
        gAmountLabel.text          = @"1";
        gAmountLabel.textColor     = [UIColor whiteColor];
        gAmountLabel.font          = [UIFont boldSystemFontOfSize:15];
        gAmountLabel.textAlignment = NSTextAlignmentCenter;
        [gMenuView addSubview:gAmountLabel];

        UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        plusBtn.frame = CGRectMake(148, y, 30, 26);
        plusBtn.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
        plusBtn.layer.cornerRadius = 6;
        [plusBtn setTitle:@"+" forState:UIControlStateNormal];
        [plusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        plusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        [plusBtn addTarget:[ACModHandler shared] action:@selector(plusTapped)
            forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:plusBtn];

        NSLog(@"[ModMenu] Built with PrefabGenerator hooks");
    });
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gMenuBuilt) buildModMenu();
}
%end

%ctor {
    NSLog(@"[ModMenu] AC Mod Menu loaded - PrefabGenerator edition");
    gSpawnAmount = 1;
}
