//
//  SSUHomeViewController.m
//  SSUMobile
//
//  Created by Eric Amorde on 7/30/14.
//  Copyright (c) 2014 Sonoma State University Department of Computer Science. All rights reserved.
//

#import "SSUHomeViewController.h"
#import "SSUAppPickerModuleCell.h"
#import "SSUAppDelegate.h"
#import <Masonry/Masonry.h>

static NSInteger COLS = 3;
static CGFloat MARGIN = 5.0;
static NSInteger BLANK_CELL_INDEX = 7;

@interface SSUHomeViewController () <UICollectionViewDelegate,UICollectionViewDataSource, SSUModuleCellDelegate>

@property (nonatomic, strong) NSArray * modules;
@property (nonatomic, strong) id<SSUModuleUI> navBarModule;
@property (nonatomic, strong) NSIndexPath * blankCellIndexPath;
@property (nonatomic) CGSize cellSize;

@end

@implementation SSUHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self resetCellSize];
    
    self.blankCellIndexPath = [NSIndexPath indexPathForItem:7 inSection:0];
    
    [self loadModules];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // Change the nav bar styling to be 100% transparent
    UINavigationBar * navBar = self.navigationController.navigationBar;
    [navBar setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
    navBar.shadowImage = [UIImage new];
    navBar.barTintColor = [UIColor clearColor];
    navBar.translucent = YES;

}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // Undo all the styling changes we made to the nav bar
    UINavigationBar * navBar = self.navigationController.navigationBar;
    UINavigationBar * appearance = [UINavigationBar appearance];
    [navBar setBackgroundImage:[appearance backgroundImageForBarMetrics:UIBarMetricsDefault]
                 forBarMetrics:UIBarMetricsDefault];
    navBar.shadowImage = [appearance shadowImage];
    navBar.barTintColor = [appearance barTintColor];
    navBar.translucent = NO;
    
}

- (UIStatusBarStyle) preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void) loadModules {
    NSMutableArray * modules = [[AppDelegate modulesUI] mutableCopy];
    id<SSUModuleUI> navBarModule = nil;
    for (id<SSUModuleUI> module in modules) {
        if ([module respondsToSelector:@selector(showModuleInNavigationBar)] &&
            [module showModuleInNavigationBar]) {
            navBarModule = module;
            break;
        }
    }
    
    if (navBarModule) {
        UIButton * navView = (UIButton *)[navBarModule viewForHomeScreen];
        UIBarButtonItem * barItem = [[UIBarButtonItem alloc] initWithCustomView:navView];
        [navView addTarget:self action:@selector(navBarButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        self.navigationItem.rightBarButtonItem = barItem;
        self.navBarModule = navBarModule;
        [modules removeObject:navBarModule];
    }
    
    self.modules = modules;
}

- (void) resetCellSize {
    // Create a CGSize that will fit the cells to the number of columns we want
    CGFloat margin = MARGIN * (COLS+1);
    CGRect screen = [[UIScreen mainScreen] applicationFrame];
    CGFloat width = roundf((screen.size.width - margin)/COLS);
    if (screen.size.height <= 480) {
        width = 82; // iPhone 4/4Ss are tiny, make the cells a bit smaller
    }
    self.cellSize = CGSizeMake(width, width);;
    UICollectionViewFlowLayout * layout = (id)self.collectionView.collectionViewLayout;
    layout.itemSize = self.cellSize;
}

#pragma mark - Collection View

- (NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.modules.count + 1; // + 1 for blank cell
}

- (UICollectionViewCell *) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == BLANK_CELL_INDEX) {
        UICollectionViewCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"BlankCell" forIndexPath:indexPath];
        return cell;
    }
    NSString * cellName = @"ModuleCell";
    UICollectionViewCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellName forIndexPath:indexPath];
    // In iOS 7, the contentView property is broken and shrinks for some reason. Force it to be the size
    // that we want
    CGRect newFrame = cell.contentView.frame;
    newFrame.size = self.cellSize;
    cell.contentView.frame = newFrame;
    
    id<SSUModuleUI> module = [self moduleAtIndexPath:indexPath];
    SSUAppPickerModuleCell * moduleCell = (SSUAppPickerModuleCell *)cell;
    moduleCell.module = module;
    moduleCell.delegate = self;
    
    return cell;
}

- (void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView selectItemAtIndexPath:indexPath animated:YES scrollPosition:UICollectionViewScrollPositionNone];
    id<SSUModuleUI> module = self.modules[indexPath.item];
    UIViewController * viewController = [module initialViewController];
    [self.navigationController pushViewController:viewController animated:YES];
}

- (CGSize) collectionView:(UICollectionView *)collectionView
                   layout:(UICollectionViewLayout *)layout
   sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return self.cellSize;
}

- (void) moduleCellWasSelected:(SSUAppPickerModuleCell *)cell {
    id<SSUModuleUI> module = cell.module;
    UIViewController * viewController = [module initialViewController];
    [self.navigationController pushViewController:viewController animated:YES];
}

#pragma mark - Button Actions

- (void) navBarButtonPressed:(id)sender {
    UIViewController * viewController = [self.navBarModule initialViewController];
    [self.navigationController pushViewController:viewController animated:YES];
}

#pragma mark - Helper

- (NSIndexPath *) translateIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= BLANK_CELL_INDEX && indexPath.section == 0) {
        return [NSIndexPath indexPathForItem:indexPath.item-1 inSection:indexPath.section];
    }
    return indexPath;
}

- (id<SSUModuleUI>) moduleAtIndexPath:(NSIndexPath *) indexPath {
    indexPath = [self translateIndexPath:indexPath];
    return self.modules[indexPath.item];
}

/** 
 Attempts to trigger a selection animation, whether by calling setSelected:animated:
 or by calling setHighlighted:animated:
 */
- (void) selectView:(UIView *)view {
    id generic = view;
    if ([generic respondsToSelector:@selector(sendActionsForControlEvents:)]) {
        // UIButton
        [generic setHighlighted:YES];
        [generic sendActionsForControlEvents:UIControlEventTouchUpInside];
        [generic setHighlighted:NO];
    }
    else if ([generic respondsToSelector:@selector(setSelected:animated:)]) {
        [generic setSelected:YES animated:YES];
    }
    else if ([generic respondsToSelector:@selector(setHighlighted:animated:)]) {
        [generic setHighlighted:YES animated:YES];
    }
}

@end
