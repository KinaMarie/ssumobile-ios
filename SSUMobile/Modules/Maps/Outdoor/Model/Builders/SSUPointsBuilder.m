//
//  SSUPointsBuilder.m
//  SSUMobile
//
//  Created by Andrew Huss on 4/14/13.
//  Copyright (c) 2013 Sonoma State University Department of Computer Science. All rights reserved.
//

#import "SSUPointsBuilder.h"
#import "SSULogging.h"

@implementation SSUPointsBuilder

- (void) build:(NSArray*)points {
    SSULogDebug(@"Building Points: %lu", (unsigned long)points.count);
    for (NSDictionary* pointData in points) {
        SSUMoonlightDataMode mode = [self modeFromJSONData:pointData];
        SSUMapPoint* point = [SSUPointsBuilder mapPointWithID:pointData[SSUMoonlightManagerKeyID] inContext:self.context];
        if (mode == SSUMoonlightDataModeDeleted) {
            [self.context deleteObject:point];
            continue;
        }

        point.latitude = pointData[SSUPointKeyLatitude];
        point.longitude = pointData[SSUPointKeyLongitude];
    }
    [self saveContext];
}

@end
