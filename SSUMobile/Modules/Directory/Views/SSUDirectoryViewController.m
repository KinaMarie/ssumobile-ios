//
//  SSUDirectoryViewController.m
//  SSUMobile
//
//  Created by Andrew Huss on 2/9/13.
//  Copyright (c) 2013 Sonoma State University Department of Computer Science. All rights reserved.
//

#import "SSUDirectoryViewController.h"
#import "SSULogging.h"
#import "SSUDirectoryModule.h"
#import "SSUMapModule.h"
#import "SSUPersonViewController.h"
#import "SSUBuildingViewController.h"
#import "SSUSchoolViewController.h"
#import "SSUDepartmentViewController.h"
#import "RBStoryboardLink.h"
#import "SSUOutdoorMapViewController.h"

#import "SSUDirectoryConstants.h"
#import "SSUSettingsConstants.h"

#import "SSUDirectoryTableViewCell.h"
#import "SSUTableHeaderView.h"
#import "SSUSegmentedTableHeaderView.h"

#import <Masonry/Masonry.h>

static const CGFloat CELL_HEIGHT = 44;
static const CGFloat SEGMENT_FONT_SIZE = 11.0;

static NSString * const LOCATION_SEGUE = @"Location";
static NSString * const SEGMENTED_HEADER_IDENTIFIER = @"SegmentedHeader";
static NSString * const HEADER_IDENTIFIER = @"Header";

@interface SSUDirectoryViewController () <UISearchDisplayDelegate, UISearchBarDelegate>

@property (nonatomic) NSManagedObjectContext * context;
@property (nonatomic, readwrite) NSString * entityName;

@property (nonatomic) BOOL isSearching;

@property (nonatomic) NSPredicate* predicate;
@property (nonatomic) NSArray* sortDescriptors;

@property (nonatomic) id selectedObject;

@property (nonatomic) UISegmentedControl * segmentedControl;
@property (nonatomic) NSArray * defaultEntities;
@property (nonatomic) NSArray * displayEntities;
@property (nonatomic) NSDictionary * displayNames;

@end

@implementation SSUDirectoryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.context = [[SSUDirectoryModule sharedInstance] context];
    
    if (!self.refreshControl) {
        self.refreshControl = [[UIRefreshControl alloc] init];
    }
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
    [self setupEntities];
    [self setupSegmentedControl];
    [self setupFetchedResultsControllers];
    
    _showsSectionTitles = NO;
    _showsSectionIndexTitles = NO;
    self.tableView.sectionIndexBackgroundColor = [UIColor clearColor];
    self.tableView.sectionIndexColor = SSU_BLUE_COLOR;
    self.searchDisplayController.searchResultsTableView.sectionIndexBackgroundColor = [UIColor clearColor];
    self.searchDisplayController.searchResultsTableView.sectionIndexColor = SSU_BLUE_COLOR;
    
    [self.tableView registerClass:[SSUTableHeaderView class] forHeaderFooterViewReuseIdentifier:HEADER_IDENTIFIER];
    [self.tableView registerClass:[SSUSegmentedTableHeaderView class] forHeaderFooterViewReuseIdentifier:SEGMENTED_HEADER_IDENTIFIER];
    
    [self loadEntityName:_entityName usingPredicate:_predicate];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Setting this in viewDidLoad will have no effect
    self.navigationController.navigationBar.translucent = NO;
    
    // Check if we need to display anything - if we were pushed from another module
    if (self.objectToDisplay) {
        [self displayObject:self.objectToDisplay];
        self.objectToDisplay = nil;
    }
}

#pragma mark - Setup
#pragma mark -

- (void) setupEntities {
    self.defaultEntities = @[SSUDirectoryEntityPerson,
                             SSUDirectoryEntityDepartment,
                             SSUDirectoryEntityBuilding,
                             SSUDirectoryEntitySchool];
    self.displayNames = @{
                          SSUDirectoryEntityPerson      : @"Faculty/Staff",
                          SSUDirectoryEntityDepartment  : @"Departments",
                          SSUDirectoryEntityBuilding    : @"Buildings",
                          SSUDirectoryEntitySchool      : @"Schools"
                          };
    
    if (!self.entities) {
        self.entities = [self.defaultEntities copy];
    }
    
    
    NSMutableArray * display = [NSMutableArray new];
    for (NSString * entity in self.entities) {
        [display addObject:self.displayNames[entity]];
    }
    self.displayEntities = [display copy];
    
    if (self.entityName == nil) {
        self.entityName = [self.entities firstObject];
    }
}

- (void) setupSegmentedControl {
    self.segmentedControl = [[UISegmentedControl alloc] initWithItems:self.displayEntities];
    self.segmentedControl.selectedSegmentIndex = 0;
    self.segmentedControl.tintColor = [UIColor whiteColor];
    [self.segmentedControl addTarget:self action:@selector(segmentChanged) forControlEvents:UIControlEventValueChanged];
    id textAttributes = @{
                          NSFontAttributeName : [UIFont systemFontOfSize:SEGMENT_FONT_SIZE]
                          };
    [self.segmentedControl setTitleTextAttributes:textAttributes
                                         forState:UIControlStateNormal];
}

- (void) setupFetchedResultsControllers {
    self.sortDescriptors = @[
                             [NSSortDescriptor sortDescriptorWithKey:@"sectionName" ascending:YES],
                             [NSSortDescriptor sortDescriptorWithKey:@"term" ascending:YES]
                             ];
    self.fetchedResultsController = [self makeFetchedResultsController];
    self.searchFetchedResultsController = [self makeSearchFetchedResultsController];
}

- (NSManagedObjectContext *) context {
    if (_context) return _context;
    
    _context = [[SSUDirectoryModule sharedInstance] context];
    return _context;
}

#pragma mark Entities

- (NSString *) displayNameForEntity:(NSString *)entity {
    NSString * display = self.displayNames[entity];
    return (display != nil) ? display : entity;
}

- (void) setEntities:(NSArray *)entities {
    _entities = entities;
    [self resetSegments];
}

#pragma mark Segmented Control

- (void) resetSegments {
    [self.segmentedControl removeAllSegments];
    
    NSMutableArray * display = [NSMutableArray new];
    [self.entities enumerateObjectsUsingBlock:^(NSString * entity, NSUInteger idx, BOOL *stop) {
        [display addObject:[self displayNameForEntity:entity]];
        [self.segmentedControl insertSegmentWithTitle:display.lastObject atIndex:idx animated:NO];
    }];
    
    self.displayEntities = [display copy];
}

- (void) setShowsSectionTitles:(BOOL)showsSectionTitles {
    if (_showsSectionTitles != showsSectionTitles) {
        _showsSectionTitles = showsSectionTitles;
        // Reload the section headers
        [self.tableView reloadData];
    }
}

/**
 Callback for UISegmentedControl value changed
 */
- (void) segmentChanged {
    NSUInteger index = [self.segmentedControl selectedSegmentIndex];
    NSString * entity = [self.entities objectAtIndex:index];
    [self loadEntityName:entity usingPredicate:nil];
}

#pragma mark - Loading

- (void) refresh {
    SSULogDebug(@"Refreshing...");
    if (!self.refreshControl.refreshing)
        [self.refreshControl beginRefreshing];
    [[SSUDirectoryModule sharedInstance] updateData:^{
        [self.refreshControl endRefreshing];
    }];
}

- (void) reloadData {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performFetch];
        [self.tableView reloadData];
    });
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSString* identifier = segue.identifier;
    if ([identifier isEqualToString:LOCATION_SEGUE]) {
        SSUOutdoorMapViewController* controller = (SSUOutdoorMapViewController *)segue.destinationViewController;
        [controller loadObject:self.selectedObject inContext:[SSUMapModule sharedInstance].context];
    }
    else if ([segue.destinationViewController isKindOfClass:[SSUDirectoryDetailController class]]){
        SSUDirectoryDetailController* controller = segue.destinationViewController;
        if (self.selectedObject != nil) {
            [controller loadObject:self.selectedObject inContext:self.context];
        }
    }
}

- (void) loadEntityName:(NSString*)entityName
         usingPredicate:(NSPredicate*)predicate {
    NSParameterAssert(entityName);
    
    _entityName = entityName;
    self.predicate = predicate;
    
    NSMutableArray* sortDescriptors = [NSMutableArray array];
    [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"sectionName" ascending:YES]];
    [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"term" ascending:YES]];
    if ([self.entityName isEqualToString:SSUDirectoryEntityPerson]) {
        _showsSectionTitles = YES;
        _showsSectionIndexTitles = YES;
        
    }
    else if ([self.entityName isEqualToString:SSUDirectoryEntityBuilding]) {
        _showsSectionTitles = NO;
        _showsSectionIndexTitles = NO;
    }
    else if ([self.entityName isEqualToString:SSUDirectoryEntityDepartment]) {
        NSPredicate * pred = [NSPredicate predicateWithFormat:@"name != 'Unknown' AND ANY people.id != nil"];
        if (self.predicate) {
            id predicates = @[self.predicate, pred];
            self.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
        }
        else {
            self.predicate = pred;
        }
        _showsSectionTitles = YES;
        _showsSectionIndexTitles = YES;
    }
    else if ([self.entityName isEqualToString:SSUDirectoryEntityDirectoryObject]) {
        _showsSectionTitles = YES;
        _showsSectionIndexTitles = YES;
    }
    else if ([self.entityName isEqualToString:SSUDirectoryEntitySchool]) {
        _showsSectionTitles = NO;
        _showsSectionIndexTitles = NO;
    }
    else {
        SSULogDebug(@"Unknown Entity Name: %@", self.entityName);
    }
    
    NSInteger selectedSegment = (NSInteger)[self.displayEntities indexOfObject:[self displayNameForEntity:self.entityName]];
    self.segmentedControl.selectedSegmentIndex = selectedSegment;
    self.sortDescriptors = [NSArray arrayWithArray:sortDescriptors];
    
    if (self.defaultPredicate != nil) {
        if (self.predicate) {
            self.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[self.defaultPredicate, self.predicate]];
        }
        else {
            self.predicate = self.defaultPredicate;
        }
    }
    
    NSFetchRequest* fetchRequest = self.fetchedResultsController.fetchRequest;
    fetchRequest.entity = [NSEntityDescription entityForName:self.entityName inManagedObjectContext:self.context];
    fetchRequest.sortDescriptors = self.sortDescriptors;
    fetchRequest.predicate = self.predicate;

    [self reloadData];
}

#pragma mark - Table View

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString * identifier = (section == 0) ? SEGMENTED_HEADER_IDENTIFIER : HEADER_IDENTIFIER;
    SSUTableHeaderView * header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:identifier];
    if ([header isKindOfClass:[SSUSegmentedTableHeaderView class]]) {
        SSUSegmentedTableHeaderView * segmentedHeader = (SSUSegmentedTableHeaderView *)header;
        segmentedHeader.segmentedControl = self.segmentedControl;
    }
    header.headerTextLabel.text = [self tableView:tableView titleForHeaderInSection:section];
    return header;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0 && [self tableView:tableView titleForHeaderInSection:section].length > 0) {
        return self.segmentedControl.frame.size.height * 2;
    }
    return self.segmentedControl.frame.size.height + 1;
}

- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (self.isSearching)
        return [[self.searchFetchedResultsController.sections objectAtIndex:section] name];
    if (!self.showsSectionTitles)
        return @"";
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self fetchedResultsController] sections][section];
    return [sectionInfo name];
}

- (NSArray *) sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (!self.showsSectionIndexTitles)
        return nil;
    if (self.isSearching)
        return [self.searchFetchedResultsController sectionIndexTitles];

    return [self.fetchedResultsController sectionIndexTitles];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return CELL_HEIGHT;
}

- (SSUDirectoryObject *) objectAtIndex:(NSIndexPath *)indexPath {
    if(self.isSearching) {
        return [self.searchFetchedResultsController objectAtIndexPath:indexPath];
    } else {
        return [self.fetchedResultsController objectAtIndexPath:indexPath];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == self.searchDisplayController.searchResultsTableView)
        return [self tableView:tableView searchCellForRowAtIndexPath:indexPath];
    SSUDirectoryObject* object = [self objectAtIndex:indexPath];
    NSString *cellIdentifier = object.entity.name;
    SSUDirectoryTableViewCell *cell = (id)[tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    [self configureCell:cell forObject:object];
    return cell;
}

- (UITableViewCell *) tableView:(UITableView *)tableView searchCellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SSUDirectoryObject * obj = [self.searchFetchedResultsController objectAtIndexPath:indexPath];
    NSString * identifier = obj.entity.name;
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.text = obj.displayName;
    
    return cell;
}

- (void)configureCell:(SSUDirectoryTableViewCell *)cell forObject:(NSManagedObject *)object {
    SSUDirectoryObject * entity = (SSUDirectoryObject *)object;
    cell.directoryEntry = entity;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SSUDirectoryObject* object = [self objectAtIndex:indexPath];
    self.selectedObject = object;
    
    [self performSegueWithIdentifier:object.entity.name sender:self];
    
    self.searchDisplayController.active = NO;
    
    SSULogDebug(@"Object: %@", object);
}

#pragma mark - Core Data

- (NSFetchedResultsController *) makeFetchedResultsController {
    
    NSFetchRequest* fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    fetchRequest.predicate = self.predicate;
    fetchRequest.sortDescriptors = self.sortDescriptors;
    
    fetchRequest.includesPendingChanges = YES;
    
    NSFetchedResultsController * c = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                         managedObjectContext:self.context
                                                                           sectionNameKeyPath:@"sectionName"
                                                                                    cacheName:nil];
    return c;
}

- (NSFetchedResultsController *) makeSearchFetchedResultsController {
    
    NSFetchRequest * request = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    NSArray * sortDescriptors = @[
                                  [NSSortDescriptor sortDescriptorWithKey:@"sectionName" ascending:YES],
                                  [NSSortDescriptor sortDescriptorWithKey:@"term" ascending:YES],
                                  ];
    request.sortDescriptors = sortDescriptors;
    request.includesPendingChanges = YES;
    
    NSFetchedResultsController * c = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                         managedObjectContext:self.context
                                                                           sectionNameKeyPath:@"sectionName"
                                                                                    cacheName:nil];
    
    return c;
}

#pragma mark - Search

- (void) setShowsSearchBar:(BOOL)showsSearchBar {
    _showsSearchBar = showsSearchBar;
    if (!_showsSearchBar) {
        self.tableView.tableHeaderView = nil;
    }
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    self.isSearching = YES;
    [self performSearchFetch];
    return YES;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString {
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text]];
    return YES;
}

- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
    // See: http://stackoverflow.com/a/24253630/2012042
    // if (self.tableView != self.searchDisplayController.searchBar.superview) {
    if (self.searchDisplayController.searchBar.window == nil) {
        [self.tableView insertSubview:self.searchDisplayController.searchBar aboveSubview:self.tableView];
    }
    self.isSearching = NO;
    [self loadEntityName:self.entityName usingPredicate:nil];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    self.isSearching = NO;
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    self.isSearching = NO;
    return YES;
}

#pragma mark - SSUDetailTableViewDelegate

/**
 Displays the respective detail view for the entity and segues to it
 
 @warning object must be a subclass of DirectoryObject such as Person or Building, as there is no detail view for the abstract DirectoryObject entity
 */
- (void) displayObject:(SSUDirectoryObject *)object {
    NSString * identifier = NSStringFromClass([object class]);
    self.selectedObject = object;
    
    [self performSegueWithIdentifier:identifier sender:self];
}

// After pushing a detail table view onto the navigation stack, delete
// any existing ones
- (void) detailTableViewDidAppear:(SSUDetailTableViewController *)controller {
    /*
    NSMutableArray * controllers = [self.navigationController.viewControllers mutableCopy];
    NSUInteger size = controllers.count;
    while (size >= 2 &&
           [controllers[size-2] isKindOfClass:[SSUDetailTableViewController class]])
    {
        [controllers removeObjectAtIndex:size-2];
        size = controllers.count;
    }
    [self.navigationController setViewControllers:controllers animated:NO];
     */
}

- (void) detailTableView:(SSUDetailTableViewController *)controller didSelectObject:(id)object {
    [self displayObject:object];
}

- (void) detailTableView:(SSUDetailTableViewController *)controller requestedMapDisplayForObject:(id)object {
    if ([object isKindOfClass:[SSUBuilding class]]) {
        self.selectedObject = object;
        [self performSegueWithIdentifier:LOCATION_SEGUE sender:self];
    }
}

@end
