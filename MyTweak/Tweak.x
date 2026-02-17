// MyTweak - Dylib Tweak
// Tweak.x - Add your hooks below

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ─────────────────────────────────────────────
// Example: Hook UIApplication didFinishLaunching
// ─────────────────────────────────────────────
%hook UIApplication

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[MyTweak] App launched!");
    // Call the original implementation
    return %orig;
}

%end

// ─────────────────────────────────────────────
// Constructor: runs when the dylib is loaded
// ─────────────────────────────────────────────
%ctor {
    NSLog(@"[MyTweak] Dylib injected successfully!");
}

%dtor {
    NSLog(@"[MyTweak] Dylib unloaded.");
}
