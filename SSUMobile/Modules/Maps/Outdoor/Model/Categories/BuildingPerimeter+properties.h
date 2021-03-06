//
//  BuildingPerimeter+properties.h
//  SSUMobile
//
//  Created by Andrew Huss on 3/5/13.
//  Copyright (c) 2013 Sonoma State University Department of Computer Science. All rights reserved.
//

#import "SSUMapBuildingPerimeter.h"
#import "Polygon+properties.h"
#import <MapKit/MapKit.h>

@interface SSUMapBuildingPerimeter (properties) <MKAnnotation>

- (MKMapRect) boundingMapRect;

@end
