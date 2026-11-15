//
//  DOPSListController.m
//  Dopamine
//

#import "DOPSListController.h"
#import "DOGlobalAppearance.h"
#import <Preferences/PSTableCell.h>
#import <Preferences/PSSwitchTableCell.h>

static void DOStylePreferenceControls(UIView *view)
{
    if ([view isKindOfClass:UISwitch.class]) {
        UISwitch *toggle = (UISwitch *)view;
        toggle.onTintColor = [DOGlobalAppearance accentColor];
        toggle.thumbTintColor = [DOGlobalAppearance buttonTextColor];
    } else if ([view isKindOfClass:UITextField.class]) {
        UITextField *textField = (UITextField *)view;
        textField.textColor = [DOGlobalAppearance primaryTextColor];
        textField.tintColor = [DOGlobalAppearance accentColor];
        textField.keyboardAppearance = [DOGlobalAppearance interfaceStyle] == UIUserInterfaceStyleDark ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
        if (textField.attributedPlaceholder.length > 0) {
            NSMutableAttributedString *placeholder = textField.attributedPlaceholder.mutableCopy;
            [placeholder addAttribute:NSForegroundColorAttributeName value:[DOGlobalAppearance secondaryTextColor] range:NSMakeRange(0, placeholder.length)];
            textField.attributedPlaceholder = placeholder;
        }
    }
    for (UIView *subview in view.subviews) DOStylePreferenceControls(subview);
}

static void DOStylePreferenceSectionView(UIView *view)
{
    if ([view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView *sectionView = (UITableViewHeaderFooterView *)view;
        sectionView.textLabel.textColor = [DOGlobalAppearance secondaryTextColor];
        sectionView.detailTextLabel.textColor = [DOGlobalAppearance secondaryTextColor];
        sectionView.tintColor = [DOGlobalAppearance accentColor];
    }
}

@implementation DOPSListController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [_table setSeparatorColor:UIColor.clearColor];
    [_table setBackgroundColor:UIColor.clearColor];
    [DOPSListController setupViewControllerStyle:self];
}

+ (void)setupViewControllerStyle:(UIViewController *)vc
{
    if (!vc.isViewLoaded) return;
    vc.overrideUserInterfaceStyle = [DOGlobalAppearance interfaceStyle];
    [DOGlobalAppearance styleViewController:vc];
    if ([vc isKindOfClass:DOPSListController.class]) {
        UITableView *table = [(DOPSListController *)vc valueForKey:@"table"];
        table.separatorColor = UIColor.clearColor;
        table.backgroundColor = UIColor.clearColor;
    }
    [UISwitch appearanceWhenContainedInInstancesOfClasses:@[[vc class]]].onTintColor = [DOGlobalAppearance accentColor];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [DOGlobalAppearance styleTableCell:cell];
    if ([cell isKindOfClass:PSTableCell.class]) {
        PSTableCell *preferenceCell = (PSTableCell *)cell;
        BOOL enabled = [preferenceCell respondsToSelector:@selector(cellEnabled)] ? preferenceCell.cellEnabled : cell.userInteractionEnabled;
        if ([preferenceCell respondsToSelector:@selector(titleLabel)]) {
            id titleLabel = preferenceCell.titleLabel;
            if ([titleLabel isKindOfClass:UILabel.class]) ((UILabel *)titleLabel).textColor = enabled ? [DOGlobalAppearance primaryTextColor] : [DOGlobalAppearance secondaryTextColor];
        }
        if ([preferenceCell respondsToSelector:@selector(valueLabel)]) {
            id valueLabel = preferenceCell.valueLabel;
            if ([valueLabel isKindOfClass:UILabel.class]) ((UILabel *)valueLabel).textColor = [DOGlobalAppearance secondaryTextColor];
        }
    }
    if ([cell isKindOfClass:PSSwitchTableCell.class] && [cell respondsToSelector:@selector(control)]) {
        UIControl *control = [(PSSwitchTableCell *)cell control];
        if (control) DOStylePreferenceControls(control);
    }
    DOStylePreferenceControls(cell.contentView);
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    DOStylePreferenceSectionView(view);
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section
{
    DOStylePreferenceSectionView(view);
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    _table.frame = CGRectMake(12, 5, self.view.bounds.size.width - 24, self.view.bounds.size.height - 10);
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return [DOGlobalAppearance interfaceStyle] == UIUserInterfaceStyleDark ? UIStatusBarStyleLightContent : UIStatusBarStyleDarkContent;
}

@end
