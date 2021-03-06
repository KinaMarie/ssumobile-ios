//
//  Person+properties.m
//  SSUMobile
//
//  Created by Andrew Huss on 3/1/13.
//  Copyright (c) 2013 Sonoma State University Department of Computer Science. All rights reserved.
//

#import "SSUPerson+properties.h"
#import "SSUSettingsConstants.h"

@implementation SSUPerson (properties)

- (void) updateNameOrder {
    [self updateDisplayName];
    [self updateTerm];
    [self updateSectionName];
}

- (void) updateDisplayName {
    NSString* displayName = nil;
    switch ([[NSUserDefaults standardUserDefaults] boolForKey:SSUDirectoryDisplayOrderKey]) {
        case kSSUFirstLast:
            displayName = [NSString stringWithFormat:@"%@ %@", self.firstName, self.lastName];
            break;
        case kSSULastFirst:
            displayName = [NSString stringWithFormat:@"%@, %@", self.lastName, self.firstName];
            break;
    }
    [self setDisplayName:SSUTrimString(displayName)];
}

- (void) updateTerm {
    NSString* term = nil;
    switch ([[NSUserDefaults standardUserDefaults] boolForKey:SSUDirectorySortOrderKey]) {
        case kSSUFirstLast:
            term = [NSString stringWithFormat:@"%@ %@", self.firstName, self.lastName];
            break;
        case kSSULastFirst:
            term = [NSString stringWithFormat:@"%@, %@", self.lastName, self.firstName];
            break;
    }
    [self setTerm:SSUTrimString(term)];
}

- (void) updateSectionName {
    NSString * displayName = [[self displayName] stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
    self.sectionName = [displayName substringToIndex:1];
}

@end
