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
static BOOL       gMenuBuilt    = NO;

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
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
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

// ── Spawn item_landmine at 0,0,0 ──
static void spawnLandmine(int amount) {
    NSString *prefab = @"item_landmine";
    for (int i = 0; i < amount; i++) {
        // Try PhotonNetwork.Instantiate first
        Class photonNet = NSClassFromString(@"PhotonNetwork");
        if (photonNet) {
            SEL s = NSSelectorFromString(@"Instantiate:position:rotation:");
            NSMethodSignature *sig = [photonNet methodSignatureForSelector:s];
            if (sig) {
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                inv.target   = photonNet;
                inv.selector = s;
                float pos[3] = {0.0f, 0.0f, 0.0f};
                float rot[4] = {0.0f, 0.0f, 0.0f, 1.0f};
                [inv setArgument:&prefab atIndex:2];
                [inv setArgument:&pos    atIndex:3];
                [inv setArgument:&rot    atIndex:4];
                [inv invoke];
                NSLog(@"[ModMenu] Spawned %@ at 0,0,0 via PhotonNetwork", prefab);
                continue;
            }
        }
        // Fallback notification
        [[NSNotificationCenter defaultCenter]
            postNotificationName:@"ACModSpawn"
            object:nil
            userInfo:@{@"prefab": prefab, @"x": @0, @"y": @0, @"z": @0}];
        NSLog(@"[ModMenu] Spawn fallback notification sent");
    }
}

static void toggleMenu() {
    gMenuVisible = !gMenuVisible;
    gMenuView.hidden = !gMenuVisible;
    [gFloatBtn setTitle:gMenuVisible ? @"✕" : @"☰" forState:UIControlStateNormal];
}

@interface ACModHandler : NSObject
+ (instancetype)shared;
- (void)floatTapped;
- (void)spawnTapped;
- (void)minusTapped;
- (void)plusTapped;
@end

@implementation ACModHandler
+ (instancetype)shared {
    static ACModHandler *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [ACModHandler new]; });
    return s;
}
- (void)floatTapped { toggleMenu(); }
- (void)spawnTapped { spawnLandmine(gSpawnAmount); }
- (void)minusTapped {
    if (gSpawnAmount > 1) gSpawnAmount--;
    gAmountLabel.text = [NSString stringWithFormat:@"%d", gSpawnAmount];
}
- (void)plusTapped {
    if (gSpawnAmount < 50) gSpawnAmount++;
    gAmountLabel.text = [NSString stringWithFormat:@"%d", gSpawnAmount];
}
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
        CGFloat pad = 14;
        CGFloat mw  = 220;
        CGFloat bw  = mw - pad * 2;

        // ── Floating circle button ──
        gFloatBtn = [[ACDragButton alloc] initWithFrame:CGRectMake(16, 160, 50, 50)];
        gFloatBtn.layer.cornerRadius  = 25;
        gFloatBtn.layer.masksToBounds = YES;
        gFloatBtn.backgroundColor     = [UIColor colorWithRed:0.05 green:0.55 blue:0.05 alpha:0.95];
        gFloatBtn.layer.borderColor   = [UIColor colorWithRed:0.1 green:1 blue:0.1 alpha:0.7].CGColor;
        gFloatBtn.layer.borderWidth   = 2;
        [gFloatBtn setTitle:@"☰" forState:UIControlStateNormal];
        [gFloatBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        gFloatBtn.titleLabel.font = [UIFont systemFontOfSize:20];
        [gFloatBtn addTarget:[ACModHandler shared] action:@selector(floatTapped) forControlEvents:UIControlEventTouchUpInside];
        [root addSubview:gFloatBtn];

        // ── Menu panel ──
        CGFloat mh = 200;
        gMenuView = [[UIView alloc] initWithFrame:CGRectMake(74, 140, mw, mh)];
        gMenuView.backgroundColor     = [UIColor colorWithRed:0.04 green:0.09 blue:0.04 alpha:0.97];
        gMenuView.layer.cornerRadius  = 14;
        gMenuView.layer.borderColor   = [UIColor colorWithRed:0.1 green:0.75 blue:0.1 alpha:0.45].CGColor;
        gMenuView.layer.borderWidth   = 1.5;
        gMenuView.hidden              = YES;
        [root addSubview:gMenuView];

        CGFloat y = 12;

        // Title
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, y, mw, 24)];
        title.text          = @"🐾 AC Mod Menu";
        title.textColor     = [UIColor colorWithRed:0.2 green:1 blue:0.2 alpha:1];
        title.font          = [UIFont boldSystemFontOfSize:14];
        title.textAlignment = NSTextAlignmentCenter;
        [gMenuView addSubview:title];
        y += 28;

        // Divider
        UIView *div = [[UIView alloc] initWithFrame:CGRectMake(pad, y, bw, 1)];
        div.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        [gMenuView addSubview:div];
        y += 10;

        // SPAWN label
        UILabel *spawnHdr = [[UILabel alloc] initWithFrame:CGRectMake(pad, y, bw, 14)];
        spawnHdr.text      = @"SPAWN  (pos: 0, 0, 0)";
        spawnHdr.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:1 alpha:1];
        spawnHdr.font      = [UIFont boldSystemFontOfSize:9];
        [gMenuView addSubview:spawnHdr];
        y += 18;

        // Spawn button
        UIButton *spawnBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        spawnBtn.frame           = CGRectMake(pad, y, bw, 40);
        spawnBtn.backgroundColor = [UIColor colorWithRed:0.65 green:0.12 blue:0.12 alpha:1];
        spawnBtn.layer.cornerRadius = 8;
        [spawnBtn setTitle:@"💣  item_landmine" forState:UIControlStateNormal];
        [spawnBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        spawnBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
        [spawnBtn addTarget:[ACModHandler shared] action:@selector(spawnTapped) forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:spawnBtn];
        y += 50;

        // Amount stepper
        UILabel *amtLbl = [[UILabel alloc] initWithFrame:CGRectMake(pad, y+2, 60, 22)];
        amtLbl.text      = @"Amount:";
        amtLbl.textColor = [UIColor lightGrayColor];
        amtLbl.font      = [UIFont systemFontOfSize:12];
        [gMenuView addSubview:amtLbl];

        UIButton *minus = [UIButton buttonWithType:UIButtonTypeSystem];
        minus.frame           = CGRectMake(80, y, 30, 26);
        minus.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
        minus.layer.cornerRadius = 6;
        [minus setTitle:@"−" forState:UIControlStateNormal];
        [minus setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        minus.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        [minus addTarget:[ACModHandler shared] action:@selector(minusTapped) forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:minus];

        gAmountLabel = [[UILabel alloc] initWithFrame:CGRectMake(116, y, 26, 26)];
        gAmountLabel.text          = @"1";
        gAmountLabel.textColor     = [UIColor whiteColor];
        gAmountLabel.font          = [UIFont boldSystemFontOfSize:15];
        gAmountLabel.textAlignment = NSTextAlignmentCenter;
        [gMenuView addSubview:gAmountLabel];

        UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        plusBtn.frame           = CGRectMake(148, y, 30, 26);
        plusBtn.backgroundColor = [UIColor colorWithWhite:0.22 alpha:1];
        plusBtn.layer.cornerRadius = 6;
        [plusBtn setTitle:@"+" forState:UIControlStateNormal];
        [plusBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        plusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:17];
        [plusBtn addTarget:[ACModHandler shared] action:@selector(plusTapped) forControlEvents:UIControlEventTouchUpInside];
        [gMenuView addSubview:plusBtn];

        NSLog(@"[ModMenu] Built");
    });
}

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!gMenuBuilt) buildModMenu();
}
%end

%ctor {
    NSLog(@"[ModMenu] Loaded");
    gSpawnAmount = 1;
}
