//
//  DOPSListController.m
//  Dopamine
//
//  Created by tomt000 on 26/01/2024.
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
    }
    else if ([view isKindOfClass:UITextField.class]) {
        UITextField *textField = (UITextField *)view;
        textField.textColor = [DOGlobalAppearance primaryTextColor];
        textField.tintColor = [DOGlobalAppearance accentColor];
        textField.keyboardAppearance = UIKeyboardAppearanceLight;
        if (textField.attributedPlaceholder.length > 0) {
            NSMutableAttributedString *placeholder = textField.attributedPlaceholder.mutableCopy;
            [placeholder addAttribute:NSForegroundColorAttributeName value:[DOGlobalAppearance secondaryTextColor] range:NSMakeRange(0, placeholder.length)];
            textField.attributedPlaceholder = placeholder;
        }
    }
    for (UIView *subview in view.subviews) {
        DOStylePreferenceControls(subview);
    }
}

static void DOStylePreferenceSectionView(UIView *view)
{
    if ([DOGlobalAppearance isRoseStyle] && [view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView *sectionView = (UITableViewHeaderFooterView *)view;
        sectionView.textLabel.textColor = [DOGlobalAppearance secondaryTextColor];
        sectionView.detailTextLabel.textColor = [DOGlobalAppearance secondaryTextColor];
        sectionView.tintColor = [DOGlobalAppearance accentColor];
    }
}

@interface DOPSListController ()

@end

@implementation DOPSListController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [_table setSeparatorColor:[UIColor clearColor]];
    [_table setBackgroundColor:[UIColor clearColor]];
    [DOPSListController setupViewControllerStyle:self];
}

+ (void)setupViewControllerStyle:(UIViewController*)vc
{
    BOOL roseStyle = [DOGlobalAppearance isRoseStyle];
    vc.overrideUserInterfaceStyle = [DOGlobalAppearance interfaceStyle];
    vc.view.backgroundColor = [DOGlobalAppearance panelColor];
    vc.view.tintColor = [DOGlobalAppearance accentColor];
    vc.view.layer.cornerRadius = 16;
    vc.view.layer.masksToBounds = YES;
    vc.view.layer.cornerCurve = kCACornerCurveContinuous;
    vc.view.layer.borderWidth = roseStyle ? 1 : 0;
    vc.view.layer.borderColor = roseStyle ? [DOGlobalAppearance separatorColor].CGColor : nil;

    if (roseStyle) {
        [UISwitch appearanceWhenContainedInInstancesOfClasses:@[[vc class]]].onTintColor = [DOGlobalAppearance accentColor];
    }
    else if (@available(iOS 19.0, *)) {
        // Preferences may recreate SwiftUI-backed controls with the system tint.
    }
    else {
        [UISwitch appearanceWhenContainedInInstancesOfClasses:@[[vc class]]].onTintColor = [UIColor colorWithRed:71.0/255.0 green:169.0/255.0 blue:135.0/255.0 alpha:1.0];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [DOGlobalAppearance styleTableCell:cell];
    if (![DOGlobalAppearance isRoseStyle]) return;

    if ([cell isKindOfClass:PSTableCell.class]) {
        PSTableCell *preferenceCell = (PSTableCell *)cell;
        BOOL enabled = [preferenceCell respondsToSelector:@selector(cellEnabled)] ? preferenceCell.cellEnabled : cell.userInteractionEnabled;
        if ([preferenceCell respondsToSelector:@selector(titleLabel)]) {
            id titleLabel = [preferenceCell titleLabel];
            if ([titleLabel isKindOfClass:UILabel.class]) {
                [titleLabel setTextColor:enabled ? [DOGlobalAppearance primaryTextColor] : [DOGlobalAppearance secondaryTextColor]];
            }
        }
        if ([preferenceCell respondsToSelector:@selector(valueLabel)]) {
            id valueLabel = [preferenceCell valueLabel];
            if ([valueLabel isKindOfClass:UILabel.class]) {
                [valueLabel setTextColor:[DOGlobalAppearance secondaryTextColor]];
            }
        }
    }
    if ([cell isKindOfClass:PSSwitchTableCell.class] && [cell respondsToSelector:@selector(control)]) {
        UIControl *control = [(PSSwitchTableCell *)cell control];
        if (control) DOStylePreferenceControls(control);
    }
    DOStylePreferenceControls(cell.contentView);
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    DOStylePreferenceSectionView(view);
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    DOStylePreferenceSectionView(view);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _table.frame = CGRectMake(12, 5, self.view.bounds.size.width - 24, self.view.bounds.size.height - 10);
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return [DOGlobalAppearance isRoseStyle] ? UIStatusBarStyleDarkContent : UIStatusBarStyleLightContent;
}


@end
