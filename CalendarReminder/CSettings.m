//
//  CSettings.m
//  CalendarReminder
//
//  Created by HongLei Sun on 2024/2/4.
//

#import "CSettings.h"

@interface CSettings ()

@property(nonatomic, strong) NSFont* phaseFont;
@property(nonatomic, assign) NSInteger curPhase;

@end

@implementation CSettings


- (IBAction)googleClicked:(id)sender
{
    NSInteger state = [googleEnabled state];
    // Notify the delegate (AppDelegate) about the changes
    if ([self.delegate respondsToSelector:@selector(googleCalendarEnabled:)]) {
        [self.delegate googleCalendarEnabled:state];
    }
}

- (IBAction)macClicked:(id)sender
{
    NSInteger state = [macEnabled state];
    // Notify the delegate (AppDelegate) about the changes
    if ([self.delegate respondsToSelector:@selector(macCalendarEnabled:)]) {
        [self.delegate macCalendarEnabled:state];
    }
}


- (void)showFontPanelForPhase:(NSInteger)phase {
    NSFontPanel *fontPanel = [NSFontPanel sharedFontPanel];
    [fontPanel setDelegate:self];
    if (1 == phase) {
        CGFloat defaultFontSize = 18.0;
        _phaseFont = [NSFont fontWithName:@"Helvetica" size:defaultFontSize];
        [fontPanel setPanelFont:_phaseFont isMultiple:NO];
        NSColor *selectedColor = [NSColorPanel sharedColorPanel].color;
    }
    
    if (2 == phase) {
        CGFloat defaultFontSize = 17.0;
        _phaseFont = [NSFont fontWithName:@"Helvetica" size:defaultFontSize];
        [fontPanel setPanelFont:_phaseFont isMultiple:NO];
       
    }
    
    if (3 == phase) {
        CGFloat defaultFontSize = 16.0;
        _phaseFont = [NSFont fontWithName:@"Helvetica" size:defaultFontSize];
        [fontPanel setPanelFont:_phaseFont isMultiple:NO];
    }
    
    [fontPanel makeKeyAndOrderFront:nil];
}

-(void)changeFont:(id)sender {
    NSLog(@"Sender class: %@", NSStringFromClass([sender class]));
    if (sender == nil) {
        NSLog(@"Warning: sender is nil");
        return;
    }
    CGFloat defaultFontSize = 16.0;
    if (3 == _curPhase) {
        defaultFontSize = 16.0;
    }
    if (2 == _curPhase) {
        defaultFontSize = 17.0;
    }
    if (1 == _curPhase) {
        defaultFontSize = 18.0;
    }
    NSFont *newFont = [sender convertFont:[NSFont systemFontOfSize:defaultFontSize]];
    
    if (3 == _curPhase) {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:phase3Font.title attributes:@{NSFontAttributeName: newFont}];
        [phase3Font setAttributedTitle:attributedTitle];

        
    }
    if (2 == _curPhase) {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:phase2Font.title attributes:@{NSFontAttributeName: newFont}];
        [phase2Font setAttributedTitle:attributedTitle];
        
    }
    if (1 == _curPhase) {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:phase1Font.title attributes:@{NSFontAttributeName: newFont}];
        [phase1Font setAttributedTitle:attributedTitle];
    }
    
    NSLog(@"Selected Font: %@", [newFont fontName]);
    NSLog(@"Selected Font size: %f", [newFont pointSize]);
    [self.delegate fontChanged:_curPhase font:newFont];
}

- (IBAction)phase1Clicked:(id)sender
{
    _curPhase = 1;
    [self showFontPanelForPhase:1];
}

- (IBAction)phase2Clicked:(id)sender
{
    _curPhase = 2;
    [self showFontPanelForPhase:2];
}
- (IBAction)phase3Clicked:(id)sender
{
    _curPhase = 3;
    [self showFontPanelForPhase:3];
}
- (IBAction)confirmClicked:(id)sender
{
    [self.window setIsVisible:FALSE];
}
- (IBAction)phase3ColorClicked:(id)sender {
    _curPhase = 3;
    [self showColorPanelForPhase:3];
}

- (IBAction)phase2ColorClicked:(id)sender {
    _curPhase = 2;
    [self showColorPanelForPhase:2];
}

- (IBAction)phase1ColorClicked:(id)sender {
    _curPhase = 1;
    [self showColorPanelForPhase:1];
}

- (void)showColorPanelForPhase:(NSInteger)phase
{
    NSColor *defaultColor = [NSColor blackColor];
    if (phase == 1)
        defaultColor = [NSColor redColor];
    if (phase == 2)
        defaultColor = [NSColor blueColor];
    
    NSColorPanel *colorpanel = [NSColorPanel sharedColorPanel];
    colorpanel.mode = NSColorPanelModeRGB; //调出时，默认色盘
    [colorpanel setColor:defaultColor];
    [colorpanel setAction:@selector(changeColor:)];
    [colorpanel setTarget:self];
    [colorpanel orderFront:nil];
}

//颜色选择action事件
- (void)changeColor:(id)sender {
    NSColorPanel *colorPanel = sender ;
    NSColor *color = colorPanel.color;
    NSLog(@" ==> _curPhase %d, color %@", _curPhase, color);
    
     
    if (_curPhase == 1) {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:phase1Color.title attributes:@{NSForegroundColorAttributeName: color}];
       
        [phase1Color setAttributedTitle:attributedTitle];
    }
    if (_curPhase == 2) {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:phase2Color.title attributes:@{NSForegroundColorAttributeName: color}];
       
        [phase2Color setAttributedTitle:attributedTitle];
    }
    if (_curPhase == 3) {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:phase3Color.title attributes:@{NSForegroundColorAttributeName: color}];
        [phase3Color setAttributedTitle:attributedTitle];
    }
    [self.delegate colorChanged:_curPhase color:color];
}

- (IBAction)cancelClicked:(id)sender
{
    [self.window setIsVisible:FALSE];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    _phaseFont = [NSFont fontWithName:@"Helvetica" size:14.0]; // Replace with your desired font name and size
    _curPhase = 0;
    {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:phase1Color.title attributes:@{NSForegroundColorAttributeName: [NSColor redColor]}];
        
        [phase1Color setAttributedTitle:attributedTitle];
    }
    {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:phase2Color.title attributes:@{NSForegroundColorAttributeName: [NSColor blueColor]}];
        
        [phase2Color setAttributedTitle:attributedTitle];
    }
    {
        NSAttributedString *attributedTitle = [[NSAttributedString alloc] initWithString:phase3Color.title attributes:@{NSForegroundColorAttributeName: [NSColor blackColor]}];
        [phase3Color setAttributedTitle:attributedTitle];
    }
    const int desiredHeight = 32;
    {
        NSRect buttonFrame = phase1Font.frame;
        buttonFrame.size.height = desiredHeight;
        [phase1Font setFrame:buttonFrame];
    }
    {
        NSRect buttonFrame = phase2Font.frame;
        buttonFrame.size.height = desiredHeight;
        [phase2Font setFrame:buttonFrame];
    }
    {
        NSRect buttonFrame = phase3Font.frame;
        buttonFrame.size.height = desiredHeight;
        [phase3Font setFrame:buttonFrame];
    }
}

@end
