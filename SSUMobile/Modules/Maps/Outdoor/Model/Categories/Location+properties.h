//
//  Coordinate+properties.h
//  SSUMobile
//
//  Created by Andrew Huss on 3/5/13.
//  Copyright (c) 2013 Sonoma State University Department of Computer Science. All rights reserved.
//

#import "SSUMapLocation.h"
#import <CoreLocation/CoreLocation.h>

@interface SSUMapLocation (properties)

- (CLLocationCoordinate2D) coordinate;
- (void) setCoordinate:(CLLocationCoordinate2D) newCoordinate;
- (CLLocation*) location;


@end
