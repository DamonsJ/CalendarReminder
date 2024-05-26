//
//  MacCalendar.h
//  CalendarReminder
//
//  Created by HongLei Sun on 2024/2/2.
//


#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>
#import <Cocoa/Cocoa.h>

@interface MacCalendar : NSObject


+ (instancetype)sharedManager;

- (BOOL)isSignIn;

-(void)queryTodaysEvents:(NSMutableDictionary* )todayEvents;
-(void)requestCalendarAccess:(void (^)(NSError *error))completion;



@end
