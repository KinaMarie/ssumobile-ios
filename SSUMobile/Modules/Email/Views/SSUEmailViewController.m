//
//  SSUEmailViewController.m
//  SSUMobile
//
//  Created by Eric Amorde on 2/7/15.
//  Copyright (c) 2015 Sonoma State University Department of Computer Science. All rights reserved.
//

#import "SSUEmailViewController.h"
#import "SSULogging.h"
#import "SSUEmailConstants.h"
#import "SSUMoonlightCommunicator.h"
#import "SSUEmailLoginViewController.h"
#import "SSULDAPCredentials.h"

#import <MBProgressHUD/MBProgressHUD.h>

static NSString * kLoginSegue = @"login";
static NSString * SharedSessionID = nil;
static NSString * SharedLoginToken = nil;

@interface SSUEmailViewController() <UIWebViewDelegate,UIAlertViewDelegate,SSUEmailLoginDelegate>

@property (nonatomic) MBProgressHUD * progressHUD;
@property (nonatomic) NSString * loadingText;
@property (nonatomic) BOOL loggingIn;
@property (nonatomic) BOOL loggedIn;
@property (nonatomic) BOOL canceled;
@property (nonatomic) NSString * loginToken;
@property (nonatomic) NSString * sessionId;
@property (nonatomic) NSInteger requestCount;
@property (nonatomic) NSInteger requestsCompleted;

// The url for the main email webpage
@property (nonatomic) NSURL * emailURL;
@property (nonatomic) NSString * emailDomain;

@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *inboxButton;
- (IBAction)inboxButtonPressed:(UIBarButtonItem *)sender;
- (IBAction)logoutButtonPressed:(UIBarButtonItem *)sender;


@end

@implementation SSUEmailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.loggedIn = NO;
    self.loggingIn = NO;
    
    self.requestCount = 0;
    self.requestsCompleted = 0;
    
    self.sessionId = nil;
    self.loginToken = nil;
    
//    NSArray * cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
//    SSULogDebug(@"%@",cookies);
//    [self checkForExistingSession];
    
    [self checkForStoredCredentials];

    if (!self.loggedIn) {
        [self showLoadingView];
        [self getSessionTokens];
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!self.loggedIn && !self.loggingIn && !self.canceled) {
        [self showLoginController];
    }
}

- (void) setMode:(SSUEmailViewControllerMode)mode {
    _mode = mode;
    if (mode == SSUEmailViewControllerModeExchange) {
        self.emailURL = [NSURL URLWithString:SSUEmailExchangeURL];
        self.inboxButton.title = @"Inbox";
    }
    else if (mode == SSUEmailViewControllerModeGmail) {
        self.emailURL = [NSURL URLWithString:SSUEmailGmailURL];
        self.inboxButton.title = @"Inbox";
    }
    else if (mode == SSUEmailViewControllerModeGoogleDocs)  {
        self.emailURL = [NSURL URLWithString:SSUEmailGoogleDocsURL];
        self.inboxButton.title = @"Home";
    }
}

#pragma mark - Loading View

- (MBProgressHUD *) progressHUD {
    if (_progressHUD != nil) {
        return _progressHUD;
    }
    _progressHUD = [[MBProgressHUD alloc] initWithView:self.webView];
    [self.webView addSubview:_progressHUD];
    _progressHUD.labelText = @"Loading";
    
    return _progressHUD;
}

- (void) setLoadingText:(NSString *)loadingText {
    self.progressHUD.labelText = loadingText;
}

- (NSString *) loadingText {
    return self.progressHUD.labelText;
}

- (void) showLoadingView {
    if (!self.progressHUD.superview) {
        [self.webView addSubview:self.progressHUD];
    }
    [self.progressHUD show:YES];
}

- (void) hideLoadingView {
    self.progressHUD.progress = 0.9f;
    [self.progressHUD hide:YES afterDelay:0.5];
}

#pragma mark - UIAlertViewDelegate

- (void) alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex)
        return;
    [self logout];
}

#pragma mark - LDAP Auth

//- (void) checkForExistingSession {
//    NSArray * cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
//    for (NSHTTPCookie * cookie in cookies) {
//        if ([cookie.name isEqualToString:SSUEmailCookieNameSessionID]) {
//            self.sessionId = cookie.value;
//        }
//    }
//}

- (void) checkForStoredCredentials {
    if ([[SSULDAPCredentials sharedInstance] rememberLogin]) {
        self.loggedIn = YES;
        [self getSessionTokensWithCompletion:^{
            NSString * username = [[SSULDAPCredentials sharedInstance] username];
            NSString * passsword = [[SSULDAPCredentials sharedInstance] password];
            [self authenticateToLDAPWithUsername:username password:passsword];
        }];
    }
}

- (void) getSessionTokens {
    [self getSessionTokensWithCompletion:NULL];
}

//getSessionTokens starts a request with LDAP to scrape a session ID and login token for this request
-(void) getSessionTokensWithCompletion:(void (^)())completion {
    NSURL *url = [NSURL URLWithString:SSUEmailLDAPURL];

    [SSUMoonlightCommunicator fetchURL:url completionHandler:^(NSData *data, NSError *error) {
        if (error) {
            SSULogError(@"Request failed: %@", [error localizedDescription]);
            if (completion) {
                completion();
            }
        }
        else {
            NSString * responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSRange sessionIdRange = [responseString rangeOfString:SSUEmailSessionIDRange];
            
            //If sessionId is found
            if (sessionIdRange.location != NSNotFound) {
                sessionIdRange.location += sessionIdRange.length; //Consume/displace past the 'sessionid=' to the token
                sessionIdRange.length = SSUEmailSessionIDLength;
                
                self.sessionId = [responseString substringWithRange:sessionIdRange];
                SSULogInfo(@"Successfully retrieved session");
                SSULogDebug(@"SessionID: %@", _sessionId);
            }
            
            NSRange loginTokenRange = [responseString rangeOfString:SSUEmailLoginTokenRange];
            
            //If loginToken found in response
            if (loginTokenRange.location != NSNotFound) {
                loginTokenRange.location += loginTokenRange.length;
                loginTokenRange.length = SSUEmailLoginTokenLength;
                
                self.loginToken = [responseString substringWithRange:loginTokenRange];
                SSULogInfo(@"Successfully retrieved login token");
                SSULogDebug(@"Login Token: %@", _loginToken);
            }
            
            if (completion) {
                completion();
            }
        }
    }];
}


- (void) authenticateToLDAPWithUsername:(NSString *)username password:(NSString *)password {
    if (username == nil || password == nil) {
        return;
    }
    self.loggedIn = NO;
    self.loggingIn = YES;
    self.loadingText = @"Logging in";
    [self showLoadingView];
    NSURL *url = [NSURL URLWithString:SSUEmailLDAPURL];
    NSMutableDictionary * params = [@{
                                      @"username" : username,
                                      @"password" : password,
                                      @"_eventId" : @"submit",
                                      } mutableCopy];
    if (self.loginToken) {
        params[@"lt"] = self.loginToken;
    }

    [SSUMoonlightCommunicator postURL:url parameters:params completionHandler:^(NSData *data, NSError *error) {
        [self hideLoadingView];
        if (error) {
            self.loggedIn = NO;
            SSULogDebug(@"Error while logging in: %@", error);
            [self showLoginController];
        }
        else {
            //Check to see if login failed/ was not brought to proper logged in LDAP page
            NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSRange notFound;
            notFound.location = NSNotFound;
            notFound.length = 0;
            
            if ([response rangeOfString:SSUEmailMySSULinkRange].location == NSNotFound) {
                SSULogInfo(@"LDAP auth failed!");
                self.loggedIn = NO;		//Did not authenticate properly
                self.loggingIn = NO;
                
                [self showLoginController];
            }
            else {
                SSULogInfo(@"LDAP auth succeeded!");
                self.loggedIn = YES;	//Auth successful
                self.loggingIn = NO;
                [self loadEmail];
            }
        }
    }];
}

// Starts loading of email web page request in a webview
- (void)loadEmail {
    self.loadingText = @"Loading";
    [self showLoadingView];
    NSURLRequest *req = [NSURLRequest requestWithURL:self.emailURL];
    [self loadRequest:req];
}

- (void) logout {
    self.loggedIn = NO;
    [self showLoadingView];
    [[SSULDAPCredentials sharedInstance] clearCredentials];
    [self deleteCookiesForURL:self.emailURL];
    [self showLoginController];
}

- (void) deleteCookiesForURL:(NSURL *)url {
    NSHTTPCookieStorage * storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie * cookie in [storage cookiesForURL:url]) {
        [storage deleteCookie:cookie];
    }
}

- (void) showLoginController {
    [self performSegueWithIdentifier:kLoginSegue sender:self];
}

#pragma mark - Button Actions

- (IBAction) inboxButtonPressed:(UIBarButtonItem *)sender {
    [self loadEmail];
}

- (IBAction) logoutButtonPressed:(UIBarButtonItem *)sender {
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Logout"
                                                     message:@"Are you sure you want to log out?"
                                                    delegate:self
                                           cancelButtonTitle:@"Cancel"
                                           otherButtonTitles:@"Logout", nil];
    [alert show];
}

#pragma mark - Login View Delegate

- (void) loginControllerDidCancel:(SSUEmailLoginViewController *)loginController {
    self.loggingIn = NO;
    self.canceled = YES;
    [self hideLoadingView];
    if (!self.loggedIn) {
        // Pop both the login and self
        [self.navigationController popViewControllerAnimated:NO];
        [self.navigationController popViewControllerAnimated:YES];
    }
    else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void) loginControllerDidLogin:(SSUEmailLoginViewController *)loginController {
    self.canceled = NO;
    NSString * username = loginController.username;
    NSString * password = loginController.password;
    if (loginController.rememberLogin) {
        [[SSULDAPCredentials sharedInstance] setUsername:username];
        [[SSULDAPCredentials sharedInstance] setPassword:password];
        [[SSULDAPCredentials sharedInstance] setRememberLogin:YES];
        [[SSULDAPCredentials sharedInstance] setHasCredentials:YES];
        [[SSULDAPCredentials sharedInstance] save];
    }
    self.loggingIn = YES;
    if (self.sessionId == nil) {
        id __weak weakSelf = self;
        [self getSessionTokensWithCompletion:^{
            [weakSelf authenticateToLDAPWithUsername:username password:password];
        }];
    }
    else {
        [self authenticateToLDAPWithUsername:username password:password];
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:kLoginSegue]) {
        //UINavigationController * nav = segue.destinationViewController;
        SSUEmailLoginViewController * controller = (SSUEmailLoginViewController *) segue.destinationViewController; //nav.topViewController;
        controller.delegate = self;
    }
}

#pragma mark - UIWebView Progress

- (void) updateProgress {
    self.progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
    [self.progressHUD show:YES];
    float progress = 0.0f;
    if (self.requestCount > 0 && self.requestsCompleted > 0) {
        progress = self.requestsCompleted / (float)self.requestCount;
    }
    else {
        progress = MAX(self.progressHUD.progress,0.1f);
    }
    progress = MIN(progress,0.9f);
    self.progressHUD.progress = progress;
    if (!self.webView.isLoading || self.requestCount == self.requestsCompleted) {
        [self.progressHUD hide:YES afterDelay:1.0];
    }
}

- (void) loadRequest:(NSURLRequest *)request {
    self.requestCount = 0;
    self.requestsCompleted = 0;
    [self.webView loadRequest:request];
}

- (void) setRequestCount:(NSInteger)requestCount {
    _requestCount = requestCount;
    [self updateProgress];
}

- (void) setRequestsCompleted:(NSInteger)requestsCompleted {
    _requestsCompleted = requestsCompleted;
    [self updateProgress];
}

#pragma mark -
#pragma mark UIWebViewDelegate Methods

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    self.requestsCompleted++;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    //Filter where the user can click links to
    NSURL *selectedURL = [request URL];
    NSString *urlString = [selectedURL absoluteString];
    
    if ([urlString containsString:@"logout"] || [urlString containsString:@"logoff"]) {
        // If the user logs out using gmail's interface, perform a logout on the client
        if (self.loggedIn) {
            [self logout];
        }
    }
    
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    self.requestsCompleted++;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    self.requestCount++;
}

@end
