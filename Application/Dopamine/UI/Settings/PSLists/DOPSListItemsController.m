//
//  DOPSListItemsController.m
//  Dopamine
//
//  Created by tomt000 on 26/01/2024.
//

#import "DOPSListItemsController.h"
#import "DOPSListController.h"
#import "DOGlobalAppearance.h"

@interface DOPSListItemsController ()

@end

@implementation DOPSListItemsController

- (void)loadView
{
    [super loadView];
    if ([self.view isKindOfClass:UITableView.class]) {
        UITableView *table = _table ?: (UITableView *)self.view;
        UIView *root = [[UIView alloc] initWithFrame:self.view.bounds];
        [root addSubview:table];
        self.view = root;
        _table = table;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [_table setSeparatorColor:[UIColor clearColor]];
    [_table setBackgroundColor:[UIColor clearColor]];
    [DOPSListController setupViewControllerStyle:self];
    [DOPSListController layoutTable:_table inController:self];
    
    _table.tableHeaderView = [DOPSListItemsController makeHeader: ((PSSpecifier*)self.specifier).name withTarget:self];
}

+ (UIView *)makeHeader:(NSString *)title withTarget:(id)target
{
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 70)];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 60)];
    label.text = title;
    label.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
    label.textColor = [DOGlobalAppearance primaryTextColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:label];

    UIView *border = [[UIView alloc] init];
    border.translatesAutoresizingMaskIntoConstraints = NO;
    border.backgroundColor = [DOGlobalAppearance separatorColor];
    [header addSubview:border];

    UIImage *backImage = [UIImage systemImageNamed:@"chevron.left" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium]];
    backImage = [backImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIButton *backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [backButton setImage:backImage forState:UIControlStateNormal];
    [backButton setTintColor:[DOGlobalAppearance secondaryTextColor]];
    [backButton addTarget:target action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    backButton.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:backButton];

    [NSLayoutConstraint activateConstraints:@[
        [label.centerYAnchor constraintEqualToAnchor:header.centerYAnchor constant:-8],
        [label.centerXAnchor constraintEqualToAnchor:header.centerXAnchor]
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [border.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [border.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [border.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-12],
        [border.heightAnchor constraintEqualToConstant:1]
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [backButton.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:10],
        [backButton.centerYAnchor constraintEqualToAnchor:header.centerYAnchor constant:-7],
        [backButton.widthAnchor constraintEqualToConstant:30],
        [backButton.heightAnchor constraintEqualToConstant:30]
    ]];

    return header;
}

- (void)dismiss {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [DOGlobalAppearance styleTableCell:cell];
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    if ([DOGlobalAppearance isRoseStyle] && [view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
        footer.textLabel.textColor = [DOGlobalAppearance secondaryTextColor];
        footer.detailTextLabel.textColor = [DOGlobalAppearance secondaryTextColor];
    }
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [DOPSListController layoutTable:_table inController:self];
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return [DOGlobalAppearance interfaceStyle] == UIUserInterfaceStyleDark ? UIStatusBarStyleLightContent : UIStatusBarStyleDarkContent;
}


@end
