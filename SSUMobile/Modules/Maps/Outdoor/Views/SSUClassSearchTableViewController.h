#import <UIKit/UIKit.h>

@protocol SSUClassSearchTableViewControllerDelegate <NSObject>

- (void)didDismissWithBuildingChoice:(NSInteger)buildingId;

@end

@interface SSUClassSearchTableViewController : UITableViewController
@property (nonatomic, weak) id<SSUClassSearchTableViewControllerDelegate> delegate;
@end
