//
//  School.h
//  SSUMobile
//
//  Created by Eric Amorde on 3/26/14.
//  Copyright (c) 2014 Computer Science. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "SSUDirectoryObject.h"

@class SSUBuilding, SSUDepartment, SSUPerson;

@interface SSUSchool : SSUDirectoryObject

@property (nonatomic, retain) NSNumber * id;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) SSUPerson *admin;
@property (nonatomic, retain) SSUPerson *assistant;
@property (nonatomic, retain) SSUPerson *dean;
@property (nonatomic, retain) NSSet *departments;
@property (nonatomic, retain) SSUBuilding *building;
@end

@interface SSUSchool (CoreDataGeneratedAccessors)

- (void)addDepartmentsObject:(SSUDepartment *)value;
- (void)removeDepartmentsObject:(SSUDepartment *)value;
- (void)addDepartments:(NSSet *)values;
- (void)removeDepartments:(NSSet *)values;

@end