//
//  AppDelegate.m
//  Reminder
//
//  Created by HongLei Sun on 2024/1/28.
//

#import "AppDelegate.h"
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>
#import "GoogleCalendar.h"
#import "MacCalendar.h"

@interface AppDelegate ()
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSStatusItem *statusItemScroll;
@property (nonatomic, strong) NSMenu *statusMenu;
@property (nonatomic, strong) CATextLayer *textLayer;
@property (nonatomic, strong) NSTimer *scrollTimer;
@property (nonatomic, strong) NSTimer *calendarTimer;
@property (nonatomic, strong) NSTimer *textLayerTimer;
@property (nonatomic, strong) CSettings *settingWindow;
@property (nonatomic, strong) NSMutableDictionary *menuTags;

@property (nonatomic, strong) GoogleCalendar *googleCalendarService;
@property (nonatomic, assign) BOOL googleEnabled;

@property (nonatomic, strong) MacCalendar *macCalendarService;
@property (nonatomic, assign) BOOL macEnabled;

@property (nonatomic, strong) NSMutableDictionary* selectedCalendarIndices;
@property (nonatomic, strong) NSMutableDictionary* nextEvents;

@property (nonatomic, strong) NSColor* S1Color;
@property (nonatomic, strong) NSColor* S2Color;
@property (nonatomic, strong) NSColor* S3Color;

@property (nonatomic, strong) NSFont* S1Font;
@property (nonatomic, strong) NSFont* S2Font;
@property (nonatomic, strong) NSFont* S3Font;

@end

static NSTimeInterval kQueryTextLayerInterval = 30;
static NSTimeInterval kQueryCalendarInterval = 5 * 60;
static NSTimeInterval kReminderBeforeS1 = 5 * 60;// remind before 60 seconds
static NSTimeInterval kReminderBeforeS2 = 15 * 60;// remind before 5 minutes
static NSTimeInterval kReminderBeforeS3 = 24 * 60 * 60;// remind before 5 minutes

@implementation AppDelegate



- (void)scrollText {
    CGRect frame = self.textLayer.bounds;
    
    // Calculate the new x position for scrolling from right to left
    frame.origin.x -= 1;
    
    // Check if the text has completely scrolled out of the view
    if ((frame.origin.x + frame.size.width) < 0) {
        // Reset the x position to the right edge of the status item
        frame.origin.x = self.statusItemScroll.view.frame.size.width;
    }
    
    // Update the bounds of the CATextLayer
    self.textLayer.bounds = frame;
}

- (void)createTextLayer
{
    // Create a CATextLayer for displaying the scrolling text
    self.textLayer = [CATextLayer layer];
    self.textLayer.string = @"";
    CGColorRef textColor = [NSColor blackColor].CGColor; // Adjust text color
    self.textLayer.foregroundColor = textColor;
    self.textLayer.fontSize = 16.0; // Adjust font size
    
    NSView *customView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 32)]; // Adjust width as needed
    [customView setWantsLayer:YES];
    [customView setLayer:self.textLayer];
    
    [self.statusItemScroll setView:customView];
}

- (void)createMenus
{
    self.statusMenu = [[NSMenu alloc] init];
    self.menuTags = [[ NSMutableDictionary alloc] initWithCapacity:10];
    [self.menuTags setObject:[NSNumber numberWithInt:1] forKey:@"google"];
    [self.menuTags setObject:[NSNumber numberWithInt:2] forKey:@"mac"];
    [self.menuTags setObject:[NSNumber numberWithInt:3] forKey:@"settings"];
    [self.menuTags setObject:[NSNumber numberWithInt:11] forKey:@"about"];
    [self.menuTags setObject:[NSNumber numberWithInt:10] forKey:@"quit"];
    
    // create google menu
    NSString *calendar = @"google calendar";
    [self.statusMenu addItemWithTitle:calendar action:@selector(googleCalendar:) keyEquivalent:@"g"];
    [[self.statusMenu itemWithTitle:calendar] setTag:[[self.menuTags objectForKey:@"google"] intValue]];
    // create mac menu
    NSString *mac_calendar = @"mac calendar";
    [self.statusMenu addItemWithTitle:mac_calendar action:@selector(macCalendar:) keyEquivalent:@"m"];
    [[self.statusMenu itemWithTitle:mac_calendar] setTag:[[self.menuTags objectForKey:@"mac"] intValue]];
    
    // create setting menu
    NSString *settingTitle = @"settings";
    [self.statusMenu addItemWithTitle:settingTitle action:@selector(settingCalendar:) keyEquivalent:@"s"];
    [[self.statusMenu itemWithTitle:settingTitle] setTag:[[self.menuTags objectForKey:@"settings"] intValue]];
    
    NSString *aboutTitle = @"about";
    [self.statusMenu addItemWithTitle:aboutTitle action:@selector(aboutMenu:) keyEquivalent:@"a"];
    [[self.statusMenu itemWithTitle:aboutTitle] setTag:[[self.menuTags objectForKey:@"about"] intValue]];
    
    // create exit menu
    NSString *exitTitle = @"quit";
    [self.statusMenu addItemWithTitle:exitTitle action:@selector(exitMenu:) keyEquivalent:@"q"];
    [[self.statusMenu itemWithTitle:exitTitle] setTag:[[self.menuTags objectForKey:@"quit"] intValue]];
    // add to status item
    [self.statusItem setMenu:self.statusMenu];
}

-(void) createStatusItems
{
    // create main status bar
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    self.statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon = [NSImage imageNamed:@"reminder"];
    [self.statusItem.button setImage:icon];
    // create scroll text status bar
    self.statusItemScroll = [statusBar statusItemWithLength:NSVariableStatusItemLength];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.selectedCalendarIndices = [[NSMutableDictionary alloc] init];
    self.nextEvents = [[NSMutableDictionary alloc] init];
    self.googleEnabled = TRUE;
    self.macEnabled = TRUE;
    
    self.S1Color = [NSColor redColor];
    self.S2Color = [NSColor blueColor];
    self.S3Color = [NSColor blackColor];
   
    self.S1Font = [NSFont systemFontOfSize:18.0];
    self.S2Font = [NSFont systemFontOfSize:17.0];
    self.S3Font = [NSFont systemFontOfSize:16.0];
    
    
    
//    _window = [[[NSApplication sharedApplication] windows] firstObject];
//    [[[[NSApplication sharedApplication] windows] lastObject] close];
//    [_window setIsVisible:FALSE];
    NSRect frame = NSMakeRect(0, 0, 800, 600); // Set the initial frame as needed
    _window = [[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSWindowStyleMaskTitled)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO];
    NSRect mainScreenFrame = NSScreen.mainScreen.frame;
    NSRect settingsWindowFrame = self.settingWindow.window.frame;
    CGFloat centerX = NSMidX(mainScreenFrame) - NSWidth(settingsWindowFrame) / 2;
    CGFloat centerY = NSMidY(mainScreenFrame) - NSHeight(settingsWindowFrame) / 2;
    NSPoint centerPoint = NSMakePoint(centerX, centerY);
    _settingWindow = [[CSettings alloc] initWithWindowNibName:@"CSettings"];
    [_settingWindow.window setFrameOrigin:centerPoint];
    [_settingWindow.window setIsVisible:FALSE];
    _settingWindow.delegate = self;
    
    // create status
    [self createStatusItems];
    // create a menu
    [self createMenus];
    // create text lauer
    [self createTextLayer];
    
    // Add a timer to scroll the text
    self.scrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.03
                                                        target:self
                                                      selector:@selector(scrollText)
                                                      userInfo:nil
                                                       repeats:YES];
    
    self.calendarTimer = [NSTimer scheduledTimerWithTimeInterval:kQueryCalendarInterval
                                                                   target:self
                                                        selector:@selector(updateEvents)
                                                                 userInfo:nil
                                                                  repeats:YES];
    
    self.textLayerTimer = [NSTimer scheduledTimerWithTimeInterval:kQueryTextLayerInterval
                                                                   target:self
                                                        selector:@selector(updateTextLayers)
                                                                 userInfo:nil
                                                                  repeats:YES];
    
    // Initialize google service
    self.googleCalendarService = [GoogleCalendar sharedManager];
    self.macCalendarService = [MacCalendar sharedManager];
    
    // check account and change item state
    [self checkAccountsAndChangeItemState];
    // update
    [self updateAfterLogin];
    // Run the timer on the main run loop
    [[NSRunLoop mainRunLoop] addTimer:self.scrollTimer forMode:NSRunLoopCommonModes];
}


- (void)awakeFromNib {
  // Attempts to deserialize authorization from keychain in GTMAppAuth format.
    if(!self.googleCalendarService) {
        self.googleCalendarService = [GoogleCalendar sharedManager];
    }
    [self.googleCalendarService restore];
}

-(void)checkAccountsAndChangeItemState
{
    // check google
    NSMenuItem* item = [self.statusMenu itemWithTag: [[self.menuTags objectForKey:@"google"] intValue]];
    BOOL isGoogleSigned = [self.googleCalendarService isSignIn];
    if (isGoogleSigned) {
        [item setState:NSControlStateValueOn];
        NSString *email = [self.googleCalendarService signedInUsername];
        [item setTitle:email];
    }else {
        [item setState:NSControlStateValueOff];
    }
    
    // check mac
    NSMenuItem* mitem = [self.statusMenu itemWithTag: [[self.menuTags objectForKey:@"mac"] intValue]];
    [mitem setState:NSControlStateValueOn];
}

- (void)updateAfterLogin
{
    [self fetchCalendarList];
    //[self updateEvents];
}


- (void)updateUI
{
    // update google item
    
    {
        if (![self.selectedCalendarIndices objectForKey:@"google"] ) {
            NSMutableSet *cset = [NSMutableSet set];
            [self.selectedCalendarIndices setObject: cset forKey:@"google"];
        }
        
        NSArray* names =  [self.googleCalendarService getCalendarListNames];
        if (names && names.count > 0) {
            NSUInteger tag = [[self.menuTags objectForKey:@"google"] intValue];
            NSMenuItem* item = [self.statusMenu itemWithTag: tag];
            [item setSubmenu:nil];
            
            NSMenu *submenu = [[NSMenu alloc] init];
            NSInteger index = 0;
            for (NSString * name in names) {
                NSMenuItem* smenu = [[NSMenuItem alloc] initWithTitle:name action:@selector(chooseCalendar:) keyEquivalent:@""];
                [smenu setTag:index];
                if (0 == index) {
                    [self.selectedCalendarIndices[@"google"] addObject:@(index)];
                    [smenu setState:NSControlStateValueOn];
                } else {
                    [smenu setState:NSControlStateValueOff];
                }
                index += 1;
                [submenu addItem:smenu];
            }
            if (index > 0)
                [item setSubmenu:submenu];
        }
    }
}

- (void)chooseCalendar:(id)sender {
    NSMenuItem* item  = (NSMenuItem*)sender;
    NSInteger tag = [item tag];
   
    if ([item state] == NSControlStateValueOn) {
        [self.selectedCalendarIndices[@"google"] removeObject:@(tag)];
        [item setState:NSControlStateValueOff];
    } else {
        [self.selectedCalendarIndices[@"google"] addObject:@(tag)];
        [item setState:NSControlStateValueOn];
    }
    
    [self updateEvents];
}


- (void)updateEvents
{
   // update google
    if ([self.googleCalendarService isSignIn]) {
        [self.googleCalendarService queryTodaysEvents:self.selectedCalendarIndices completion:^(NSError *error) {
            [self updateTextLayers];
        }];
    }
    // update mac
    if ([self.macCalendarService isSignIn]) {
        if (![self.nextEvents objectForKey:@"mac"])
        {
            NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
            [self.nextEvents setObject:d forKey:@"mac"];
        }
        [self.macCalendarService queryTodaysEvents:[self.nextEvents objectForKey:@"mac"]];
    }
    
}

- (BOOL)areDatesCloseInTime:(NSDate *)date1 andDate:(NSDate *)date2 withThreshold:(NSTimeInterval)threshold {
    NSTimeInterval timeDifference = [date1 timeIntervalSinceDate:date2];

    return timeDifference > 0 && timeDifference <= threshold;
}

-(void)updateTextLayers
{
    // get events first
    // google
    {
        if (![self.nextEvents objectForKey:@"google"])
        {
            NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
            NSMutableArray<NSMutableDictionary *> *events  = [[NSMutableArray alloc] init];
            [d setObject:events forKey:@"events"];
            [self.nextEvents setObject:d forKey:@"google"];
        }
        [self.googleCalendarService getEvents:[[self.nextEvents objectForKey:@"google"] objectForKey:@"events"]];
    }
    
    NSInteger allEvents = 0;
    NSString *summary = @"";
    NSString *type = @"";
    
    NSFont* font = [NSFont systemFontOfSize:14.0];
    NSColor *textColor = [NSColor blackColor];
    NSDate *currentDate = [NSDate date];
    NSTimeInterval min_interval = [currentDate timeIntervalSince1970];
    
    for (NSString *key in self.nextEvents) {
        NSMutableDictionary* value = [self.nextEvents objectForKey:key];
        if (!value) continue;
        if (!_googleEnabled && [key isEqual:@"google"]) {
            continue;
        }
        if (!_macEnabled && [key isEqual:@"mac"]) {
            continue;
        }
        NSMutableArray<NSMutableDictionary *> *events = [value objectForKey:@"events"];
        for (NSMutableDictionary * e in events) {
            NSDate *ed = e[@"start"];
            NSTimeInterval timeDifference = [ed timeIntervalSinceDate:currentDate];
    
            if (timeDifference > 0 && timeDifference <= kReminderBeforeS3) {
                allEvents += 1;
            }
            
            if (timeDifference > 0 && timeDifference <= kReminderBeforeS1) {
                if (min_interval > timeDifference) {
                    min_interval = timeDifference;
                    type = @"S1";
                    summary = e[@"title"];
                    font = self.S1Font;
                    textColor = self.S1Color;
                } else if ( fabs(min_interval - timeDifference) < 0.001) {
                    summary = [summary stringByAppendingString:@" && "];
                    summary = [summary stringByAppendingString:e[@"title"]];
                }
                break;
            }
            if (timeDifference > 0 && timeDifference <= kReminderBeforeS2) {
                if (min_interval > timeDifference) {
                    min_interval = timeDifference;
                    type = @"S2";
                    summary = e[@"title"];
                    font = self.S2Font;
                    textColor = self.S2Color;
                } else if ( fabs(min_interval - timeDifference) < 0.001) {
                    summary = [summary stringByAppendingString:@" && "];
                    summary = [summary stringByAppendingString:e[@"title"]];
                }
                break;
            }
            
            if (timeDifference > 0 && timeDifference <= kReminderBeforeS3) {
                if (min_interval > timeDifference) {
                    min_interval = timeDifference;
                    type = @"S3";
                    summary = e[@"title"];
                    font = self.S3Font;
                    textColor = self.S3Color;
                } else if ( fabs(min_interval - timeDifference) < 0.001) {
                    summary = [summary stringByAppendingString:@" && "];
                    summary = [summary stringByAppendingString:e[@"title"]];
                }
                break;
            }
        }
        
    }
        
    self.textLayer.string = summary;
    self.textLayer.foregroundColor = textColor.CGColor; // Adjust text color
    CFTypeRef fontRef = (__bridge CFTypeRef)font;
    self.textLayer.font = fontRef;
    
    NSFont *fontTitile = [NSFont systemFontOfSize:14.0];
    NSDictionary *titleAttributes = @{NSFontAttributeName: fontTitile, NSForegroundColorAttributeName: [NSColor blackColor]};
    [self.statusItem.button setAttributedTitle:[[NSAttributedString alloc] initWithString:[@(allEvents) stringValue] attributes:titleAttributes]];
}

#pragma mark fetchCalendars

- (void)fetchCalendarList {
    // fetch google
    if ([self.googleCalendarService isSignIn]) {
        [self.googleCalendarService fetchCalendarListSync:^(NSError *error) {
            if (!error) {
                // Update UI or perform other tasks on successful fetch
                [self updateUI];
                [self updateEvents];
                
            } else {
                // Handle the error
                NSLog(@"Error fetching calendar list: %@", error);
            }
        }];
    }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}


#pragma mark selectors

- (void)googleCalendar:(id)sender {
    if (![self.googleCalendarService isSignIn]) {
        // signed in first
        [self.googleCalendarService runSigninThenInvokeSelector:_window completionHandler:^(NSError *error) {
            if (!error) {
                // Update UI or perform other tasks on successful fetch
                [self updateAfterLogin];
                [self checkAccountsAndChangeItemState];
            } else {
                // Handle the error
                NSLog(@"runSigninThenInvokeSelector: %@", error);
            }
        }];
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"Confirmation"];
        [alert setInformativeText:@"Are you sure you want to log out?"];
        [alert addButtonWithTitle:@"Log Out"];
        [alert addButtonWithTitle:@"Cancel"];
        [alert setAlertStyle:NSAlertStyleWarning];
        
        // Get the selected button
        NSModalResponse response = [alert runModal];
        
        if (response == NSAlertFirstButtonReturn) {
            [self.googleCalendarService signOut];
            NSMenuItem* item = [self.statusMenu itemWithTag: [[self.menuTags objectForKey:@"google"] intValue]];
            
            [item setState:NSControlStateValueOff];
            NSString *calendar = @"google calendar";
            [item setTitle:calendar];
            
            if ([self.selectedCalendarIndices objectForKey:@"google"]) {
                for (NSMenuItem *sitem in [[item submenu] itemArray]) {
                    NSInteger tag = [sitem tag];
                    [self.selectedCalendarIndices[@"google"] removeObject:@(tag)];
                }
            }
            
            [item setSubmenu:nil];
            [self updateAfterLogin];
        }
    }
    
}

-(void)macCalendar:(id)sender
{
    if (![self.macCalendarService isSignIn]) {
        // signed in first
        [self.macCalendarService requestCalendarAccess:^(NSError *error) {
            if (!error) {
                // Update UI or perform other tasks on successful fetch
                [self checkAccountsAndChangeItemState];
            } else {
                // Handle the error
                NSLog(@"macCalendarService login error : %@", error);
            }
        }];
    } else {
        NSLog(@" ==> mac signed in");
    }
}

- (void)exitMenu:(id)sender {
    // Exit the application
    [NSApp terminate:self];
}

- (void)aboutMenu:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"About"];
    NSString *informativeText = @"CalendarReminder \n";
    informativeText = [informativeText stringByAppendingString:@"- Version: 0.1\n"];
    informativeText = [informativeText stringByAppendingString:@"- Author: 295313461@qq.com\n"];
    
    [alert setInformativeText:informativeText];
    
    [alert setAlertStyle:NSAlertStyleInformational];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}


- (void)settingCalendar:(id)sender {
    [_settingWindow.window setIsVisible:TRUE];
    [self.window beginSheet:self.settingWindow.window completionHandler:nil];
}


#pragma mark delegate

- (void)googleCalendarEnabled:(NSInteger)state
{
    NSLog(@" googleCalendarEnabled : %ld ", state);
    if (state == 0)
        self->_googleEnabled = FALSE;
    else
        self->_googleEnabled = TRUE;
}

- (void)macCalendarEnabled:(NSInteger)state
{
    NSLog(@" macCalendarEnabled : %ld ", state);
    if (state == 0)
        self->_macEnabled = FALSE;
    else
        self->_macEnabled = TRUE;
}

- (void)fontChanged:(NSInteger)phase
              font :(NSFont*)font
{
    NSLog(@" fontChanged : %d ", phase);
    if (1 == phase) {
        self->_S1Font = font;
    }
    if (2 == phase) {
        self->_S2Font = font;
    }
    if (3 == phase) {
        self->_S3Font = font;
    }
}

- (void)colorChanged:(NSInteger)phase
              color :(NSColor*)color
{
    NSLog(@" colorChanged : %d ", phase);
    if (1 == phase) {
        self->_S1Color = color;
    }
    if (2 == phase) {
        self->_S2Color = color;
    }
    if (3 == phase) {
        self->_S3Color = color;
    }
}

@end
