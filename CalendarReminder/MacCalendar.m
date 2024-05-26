//
//  MacCalendar.m
//  CalendarReminder
//
//  Created by HongLei Sun on 2024/2/2.
//

#import "MacCalendar.h"


@interface MacCalendar ()

@property (nonatomic, strong) EKEventStore *eventStore;
@property (nonatomic, strong) NSMutableArray<EKEvent *> *calendarEvents;
@end


static NSInteger kWaitSeconds = 15;

static NSTimeInterval kReminderBeforeS1 = 60;// remind before 60 seconds
static NSTimeInterval kReminderBeforeS2 = 5 * 60;// remind before 5 minutes
static NSTimeInterval kReminderBeforeS3 = 24 * 60 * 60;// remind before 5 minutes

@implementation MacCalendar

#pragma mark init

+ (instancetype)sharedManager {
    static MacCalendar *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[MacCalendar alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _eventStore = [[EKEventStore alloc] init];
    }
    return self;
}

- (BOOL)isSignIn
{
    EKAuthorizationStatus s = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (s == EKAuthorizationStatusFullAccess) {
        return TRUE;
    }
    return FALSE;
}
- (void)requestCalendarAccess:(void (^)(NSError *error))completion
{
    
    [_eventStore requestFullAccessToEventsWithCompletion:^(BOOL granted, NSError *error) {
        if (granted) {
            // Access granted, you can now fetch calendar data
            if (completion) {
                completion(error);
            }
        } else {
            // Access denied or error occurred
            NSLog(@"Error accessing calendar: %@", error.localizedDescription);
        }
    }];
}

-(void)queryTodaysEvents:(NSMutableDictionary* )todayEvents
{
    // Request access to the user's calendar
    [_eventStore requestFullAccessToEventsWithCompletion:^(BOOL granted, NSError *error) {
        if (granted) {
            [self.calendarEvents removeAllObjects];
            // Access granted, fetch calendar events
            // Get the current date and time
            NSDate *currentDate = [NSDate date];
            // Create a calendar object
            NSCalendar *calendar = [NSCalendar currentCalendar];
            // Get the date components (year, month, day, hour, minute, second)
            NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay)
                                                       fromDate:currentDate];
            // Set the time components to the beginning of the day
            components.hour = 0;
            components.minute = 0;
            components.second = 0;

            // Create a new date using the modified components
            NSDate *startDate = [calendar dateFromComponents:components];
            NSDate *endDate = [startDate dateByAddingTimeInterval:1 * 24 * 60 * 60]; // 30 days from now

            NSPredicate *predicate = [self.eventStore predicateForEventsWithStartDate:startDate
                                                                         endDate:endDate
                                                                       calendars:nil];

            NSArray<EKEvent *> *events = [self.eventStore eventsMatchingPredicate:predicate];
            
            [self.calendarEvents addObjectsFromArray:events];
            [self.calendarEvents sortUsingComparator:^NSComparisonResult(EKEvent *event1, EKEvent *event2) {
                // Customize the comparison logic based on the type of elements in your array
                return [event1.startDate compare:event2.startDate];
            }];
            
            NSMutableArray<NSMutableDictionary *> *allevents = [[NSMutableArray alloc] init];
            for (EKEvent *event in events) {
//                NSDictionary *e = [NSDictionary dictionaryWithObjectsAndKeys:@"title",event.title, @"start",event.startDate,@"end",event.endDate,nil] ;
                
                NSMutableDictionary *e = [[NSMutableDictionary alloc] init];
                [e setObject:event.title forKey:@"title"];
                [e setObject:event.startDate forKey:@"start"];
                [e setObject:event.endDate forKey:@"end"];
                [allevents addObject:e];
            }
            [todayEvents setObject:allevents forKey:@"events"];
            // Process the retrieved events
//            for (EKEvent *event in events) {
//                NSLog(@"Event Title: %@", event.title);
//                NSLog(@"Start Date: %@", event.startDate);
//                NSLog(@"End Date: %@", event.endDate);
//                // Add more details as needed
//            }
        } else {
            // Access denied or error occurred
            NSLog(@"Error accessing calendar: %@", error.localizedDescription);
        }
    }];
}

@end
