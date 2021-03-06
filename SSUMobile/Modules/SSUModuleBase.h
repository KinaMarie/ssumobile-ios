//
//  SSUModuleBase.h
//  SSUMobile
//
//  Created by Eric Amorde on 9/8/15.
//  Copyright (c) 2015 Sonoma State University Department of Computer Science. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SSUModule <NSObject>

/** A user-facing title for this module. Should be localized */
- (NSString *) title;

/** Called immediately after application launch to provide modules with a time to set themselves up properly */
- (void) setup;
/** Called when the application is updating all modules at once */
- (void) updateData:(void (^)())completion;
/** Called when the user requests the deletion of all cached data */
- (void) clearCachedData;

@end

@protocol SSUModuleUI <SSUModule>

/** The image that will be used as the button for this module */
- (UIImage *) imageForHomeScreen;
/** The module's initial view controller */
- (UIViewController *) initialViewController;

/** If YES, this module's `viewForHomeScreen` view will be set as the navigation item's rightBarButtonItem */
- (BOOL) showModuleInNavigationBar;
/** The view that shows up on the homescreen and navigates to this module */
- (UIView *) viewForHomeScreen;

@end

@interface SSUModuleBase : NSObject <SSUModule>

@property (nonatomic, strong, readonly) NSDateFormatter * dateFormatter;

+ (instancetype) sharedInstance;

- (NSURL *) applicationDocumentsDirectory;
- (BOOL) setExcludeFromBackupAttributeOnResourceAtURL:(NSURL *)url toValue:(BOOL)excluded;

@end
