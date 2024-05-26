//
//  GoogleCalendar.h
//  CalendarReminder
//
//  Created by HongLei Sun on 2024/2/2.
//

#import <Foundation/Foundation.h>
#import <GTMSessionFetcher/GTMSessionFetcherLogging.h>
#import <GoogleAPIClientForREST/GTLRUtilities.h>
#import <GoogleAPIClientForREST/GTLRCalendar.h>

@import AppAuth;
@import GTMAppAuth;

@interface GoogleCalendar : NSObject

@property(readonly) GTLRCalendarService *calendarService;

+ (instancetype)sharedManager;

- (BOOL)isSignIn;
- (NSString *)signedInUsername;
- (void)runSigninThenInvokeSelector:(NSWindow *) window
                  completionHandler:(void (^)(NSError *error))completionHandler;

- (void)fetchCalendarListSync:(void (^)(NSError *error))completion;
- (NSArray*)getCalendarListNames;
- (void)queryTodaysEvents:(NSMutableDictionary* )selectedList
               completion:(void (^)(NSError *error))completion;
-(void)getEvents:(NSMutableArray<NSMutableDictionary *> *)allEvents;
- (void)restore;
- (void)signOut;


@end
