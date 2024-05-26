//
//  GoogleCalendar.m
//  CalendarReminder
//
//  Created by HongLei Sun on 2024/2/2.
//

#import <Foundation/Foundation.h>
#import "GoogleCalendar.h"

@interface GoogleCalendar ()

@property(nonatomic, strong) NSString *clientIDField;
@property(nonatomic, strong) NSString *clientSecretField;
@property(nonatomic,strong) OIDRedirectHTTPHandler *redirectHTTPHandler;
@property(nonatomic,strong) GTMKeychainStore *keychainStore;
@property(nonatomic,strong) GTMAuthSession *authSession;
@property(nonatomic,strong) GTLRCalendar_CalendarList *calendarList;
@property(nonatomic,strong) GTLRServiceTicket *calendarListTicket;
@property(nonatomic,strong) NSError *calendarListFetchError;
@property(nonatomic, strong) NSMutableArray<GTLRCalendar_Event *> *calendarEvents;
@property (strong,nonatomic) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_semaphore_t gSemaphore;

@end


static NSString *const kSuccessURLString = @"http://openid.github.io/AppAuth-iOS/redirect/";
NSString *const kGTMAppAuthKeychainItemName = @"CalendarSample: Google Calendar. GTMAppAuth";
static NSInteger kWaitSeconds = 15;

@implementation GoogleCalendar

#pragma mark init

+ (instancetype)sharedManager {
    static GoogleCalendar *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GoogleCalendar alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _calendarService = [[GTLRCalendarService alloc] init];
        _calendarService.shouldFetchNextPages = YES;
        _calendarService.retryEnabled = YES;
        // Set other configuration for the calendar service
        _clientIDField = @"yourid";
        _clientSecretField = @"yourscrete";
        _serialQueue = dispatch_queue_create("com.calendar.reminder", NULL);
        _gSemaphore = dispatch_semaphore_create(0);
    }
    return self;
}

#pragma mark signin

- (BOOL)isSignIn
{
    NSString *name = [self signedInUsername];
    return (name != nil);
}

- (NSString *)signedInUsername {
    // Get the email address of the signed-in user
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
    id<GTMFetcherAuthorizationProtocol> auth = self.calendarService.authorizer;
#pragma clang diagnostic pop
    BOOL isSignedIn = auth.canAuthorize;
    if (isSignedIn) {
        return auth.userEmail;
    } else {
        return nil;
    }
}

- (void)runSigninThenInvokeSelector:(NSWindow *) window
                  completionHandler:(void (^)(NSError *error))completionHandler {
    // Applications should have client ID hardcoded into the source
    // but the sample application asks the developer for the strings.
    // Client secret is now left blank.

    NSString *clientID = self.clientIDField;
    NSString *clientSecret = self.clientSecretField;
    NSURL *successURL = [NSURL URLWithString:kSuccessURLString];

    // Starts a loopback HTTP listener to receive the code, gets the redirect URI to be used.
    _redirectHTTPHandler = [[OIDRedirectHTTPHandler alloc] initWithSuccessURL:successURL];
    NSError *error;
    NSURL *localRedirectURI = [_redirectHTTPHandler startHTTPListener:&error];
    if (!localRedirectURI) {
        NSLog(@"Unexpected error starting redirect handler %@", error);
        return;
    }

    // Builds authentication request.
    OIDServiceConfiguration *configuration = [GTMAuthSession configurationForGoogle];
    NSArray<NSString *> *scopes = @[ kGTLRAuthScopeCalendar, OIDScopeEmail ];
    OIDAuthorizationRequest *request =
    [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                  clientId:clientID
                                              clientSecret:clientSecret
                                                    scopes:scopes
                                               redirectURL:localRedirectURI
                                              responseType:OIDResponseTypeCode
                                      additionalParameters:nil];

    // performs authentication request
    // Using the weakSelf pattern to avoid retaining self as block execution is indeterminate.
    __weak __typeof(self) weakSelf = self;
    _redirectHTTPHandler.currentAuthorizationFlow =
    [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                           presentingWindow:window
                                                   callback:^(OIDAuthState *_Nullable authState,
                                                              NSError *_Nullable error) {
        // Using weakSelf/strongSelf pattern to avoid retaining self as block execution is indeterminate
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        // Brings this app to the foreground.
        [[NSRunningApplication currentApplication]
         activateWithOptions:(NSApplicationActivateAllWindows |
                              NSApplicationActivateIgnoringOtherApps)];

        if (authState) {
            // Creates a GTMAuthSession object for authorizing requests.
            GTMAuthSession *gtmAuthorization = [[GTMAuthSession alloc] initWithAuthState:authState];
            strongSelf->_authSession = gtmAuthorization;

            // Sets the authorizer on the GTLRYouTubeService object so API calls will be authenticated.
            strongSelf.calendarService.authorizer = gtmAuthorization;

            // Serializes authorization to keychain in GTMAppAuth format.
            NSError *err;
            [strongSelf.keychainStore saveAuthSession:gtmAuthorization error:&error];
            if (err) {
                NSLog(@"Failed to say AuthSession: %@", err);
            }

            // Callback
            if (completionHandler) {
                completionHandler(error);
            }
        } else {
            strongSelf.calendarListFetchError = error;
            NSLog(@" error happen when login : %@", error );
        }
    }];
}

#pragma mark fetch

- (void)fetchCalendarListSync:(void (^)(NSError *error))completion
{

    dispatch_async(_serialQueue, ^{
        self.calendarList = nil;
        self.calendarListFetchError = nil;

        GTLRCalendarQuery_CalendarListList *query = [GTLRCalendarQuery_CalendarListList query];

        BOOL shouldFetchedOwned = FALSE;
        if (shouldFetchedOwned) {
            query.minAccessRole = kGTLRCalendarMinAccessRoleOwner;
        }

        self.calendarListTicket = [_calendarService executeQuery:query
                                               completionHandler:^(GTLRServiceTicket *callbackTicket,
                                                                   id calendarList,
                                                                   NSError *callbackError) {
            // Callback
            self.calendarList = calendarList;
            self.calendarListFetchError = callbackError;
            self.calendarListTicket = nil;

            if (completion)
            {
                completion(callbackError);
            }

            NSLog(@" ===> fetch end ");
            dispatch_semaphore_signal(_gSemaphore);
        }];
        dispatch_semaphore_wait(_gSemaphore, dispatch_time(DISPATCH_TIME_NOW, kWaitSeconds*NSEC_PER_SEC));
    });

    // Wait for the semaphore with a timeout of 40 seconds on the main thread
    NSLog(@" ===> fetch wait end ");
}


- (NSArray*)getCalendarListNames
{
    NSMutableArray * calendar_names = [NSMutableArray new];
    if (self.calendarList != nil && self.calendarList.items.count > 0)
    {
        for (GTLRCalendar_CalendarListEntry * item in self.calendarList.items)
        {
            [calendar_names addObject:item.summary];
        }
    }
    return calendar_names;
}

#pragma mark query


// Utility routine to make a GTLRDateTime object for sometime today
- (GTLRDateTime *)dateTimeForTodayAtHour:(int)hour
                                  minute:(int)minute
                                  second:(int)second {

    NSUInteger const kComponentBits = (NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                       | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond);

    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];

    NSDateComponents *dateComponents = [cal components:kComponentBits
                                              fromDate:[NSDate date]];
    dateComponents.hour = hour;
    dateComponents.minute = minute;
    dateComponents.second = second;
    dateComponents.timeZone = [NSTimeZone localTimeZone];

    GTLRDateTime *dateTime = [GTLRDateTime dateTimeWithDateComponents:dateComponents];
    return dateTime;
}

-(void)getEvents:(NSMutableArray<NSMutableDictionary *> *)allEvents
{
    if (self.calendarEvents != nil && self.calendarEvents.count > 0) {
        for (GTLRCalendar_Event *event in self.calendarEvents) {
            NSMutableDictionary *e = [[NSMutableDictionary alloc] init];
            if (event.summary)
                [e setObject:event.summary forKey:@"title"];
            else
                [e setObject:@"No Title" forKey:@"title"];
            [e setObject:event.start.dateTime.date forKey:@"start"];
            [e setObject:event.end.dateTime.date forKey:@"end"];
            [allEvents addObject:e];
        }
    }
}

- (void)queryTodaysEvents: (NSMutableDictionary* )selectedList
               completion:(void (^)(NSError *error))completion;
{
    if (![selectedList objectForKey:@"google"]) return;
    if ([[selectedList objectForKey:@"google"] count] < 1 ) return ;
    if (!self.calendarList) return;

    if (!self.calendarEvents) {
        self.calendarEvents = [[NSMutableArray alloc] init];
    }
    NSMutableSet *selectedCalendarIndex = [selectedList objectForKey:@"google"];
    [self.calendarEvents removeAllObjects];
//    NSMutableArray<NSMutableDictionary *> *allevents = [[NSMutableArray alloc] init];
//    [todayEvents setObject:allevents forKey:@"events"];

    for (id item in selectedCalendarIndex)
    {
        NSInteger index = [item intValue];
        if (index >= self.calendarList.items.count) continue;

        GTLRCalendar_CalendarListEntry *selectedCalendar = self.calendarList.items[index];
        if (selectedCalendar) {
            NSString *calendarID = selectedCalendar.identifier;

            GTLRDateTime *startOfDay = [self dateTimeForTodayAtHour:0 minute:0 second:0];
            GTLRDateTime *endOfDay = [self dateTimeForTodayAtHour:23 minute:59 second:59];

            GTLRCalendarQuery_EventsList *query =
            [GTLRCalendarQuery_EventsList queryWithCalendarId:calendarID];
            query.maxResults = 24;
            query.timeMin = startOfDay;
            query.timeMax = endOfDay;

            // The service is set to fetch all pages, but for querying today's events,
            // we only want the first 10 results
            query.executionParameters.shouldFetchNextPages = @NO;

            GTLRCalendarService *service = self.calendarService;
            [service executeQuery:query
                completionHandler:^(GTLRServiceTicket *callbackTicket, GTLRCalendar_Acl *events,
                                    NSError *callbackError) {
                // Callback
                if (callbackError == nil) {
                    NSArray<GTLRCalendar_Event *> *items = events.items;
                    if (items.count > 0) {
                        // Sort the array by the 'start' date property of GTLRCalendar_Event
                        [self.calendarEvents addObjectsFromArray:items];
                        [self.calendarEvents sortUsingComparator:^NSComparisonResult(GTLRCalendar_Event *event1, GTLRCalendar_Event *event2) {
                            // Customize the comparison logic based on the type of elements in your array
                            return [event1.start.dateTime.date compare:event2.start.dateTime.date];
                        }];
                        NSLog(@" calendarEvents %ld ", [self.calendarEvents count]);
                        NSLog(@" items %ld ", items.count);
                    } else {
                        NSLog(@"No upcoming events found.");
                    }
                } else {
                    NSLog(@"Query failed: %@ ", callbackError);
                }
                completion(callbackError);
                NSLog(@" ===> state changed to 1");
                //dispatch_semaphore_signal(_gSemaphore);
            }];
        }
    }

//
//    for (GTLRCalendar_Event *event in self.calendarEvents) {
//        //            NSDictionary *e = [NSDictionary dictionaryWithObjectsAndKeys:@"title",event.summary, @"start",event.start.dateTime.date,@"end",event.end.dateTime.date,nil] ;
//
//        NSMutableDictionary *e = [[NSMutableDictionary alloc] init];
//        [e setObject:event.summary forKey:@"title"];
//        [e setObject:event.start.dateTime.date forKey:@"start"];
//        [e setObject:event.end.dateTime.date forKey:@"end"];
//
//        [allevents addObject:e];
//    }



}


#pragma mark restore

-(void)restore
{
    self.keychainStore = [[GTMKeychainStore alloc] initWithItemName:kGTMAppAuthKeychainItemName];
    NSError *err;
    _authSession = [_keychainStore retrieveAuthSessionWithError:&err];
    if (err) {
        NSLog(@"Failed to load AuthSession: %@", err);
    }
    _calendarService.authorizer = _authSession;
}

#pragma mark signout

- (void)signOut {
    // Move your sign-out logic here
    NSError *err;
    if (![self.keychainStore removeAuthSessionWithError:&err]) {
        NSLog(@"Fail to remove authSession: %@", err);
    }
    _authSession = nil;
    _calendarService.authorizer = nil;
    _calendarList = nil;
    _calendarEvents = nil;
}

@end
