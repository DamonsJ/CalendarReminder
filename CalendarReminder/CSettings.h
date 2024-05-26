//
//  CSettings.h
//  CalendarReminder
//
//  Created by HongLei Sun on 2024/2/4.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SettingsWindowControllerDelegate <NSObject>

- (void)googleCalendarEnabled:(NSInteger)state;
- (void)macCalendarEnabled:(NSInteger)state;

- (void)fontChanged:(NSInteger)phase
              font :(NSFont*)font;

- (void)colorChanged:(NSInteger)phase
              color :(NSColor*)color;

@end

@interface CSettings : NSWindowController <NSFontChanging> {
@private
    IBOutlet NSButton *googleEnabled;
    IBOutlet NSButton *macEnabled;
    IBOutlet NSButton *phase1Font;
    IBOutlet NSButton *phase2Font;
    IBOutlet NSButton *phase3Font;
    IBOutlet NSButton *confirm;
    IBOutlet NSButton *cancel;
    IBOutlet NSButton *phase1Color;
    IBOutlet NSButton *phase2Color;
    IBOutlet NSButton *phase3Color;
}

@property (nonatomic, weak) id<SettingsWindowControllerDelegate> delegate;

- (IBAction)googleClicked:(id)sender;
- (IBAction)macClicked:(id)sender;
- (IBAction)phase1Clicked:(id)sender;
- (IBAction)phase2Clicked:(id)sender;
- (IBAction)phase3Clicked:(id)sender;
- (IBAction)confirmClicked:(id)sender;
- (IBAction)cancelClicked:(id)sender;
- (IBAction)phase1ColorClicked:(id)sender;
- (IBAction)phase2ColorClicked:(id)sender;
- (IBAction)phase3ColorClicked:(id)sender;
@end

NS_ASSUME_NONNULL_END
