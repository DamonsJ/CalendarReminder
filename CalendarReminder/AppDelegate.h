//
//  AppDelegate.h
//  Reminder
//
//  Created by HongLei Sun on 2024/1/28.
//

#import <Cocoa/Cocoa.h>
#import "CSettings.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, SettingsWindowControllerDelegate>

@property (weak) NSWindow* window;

@end

