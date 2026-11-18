//
//  DOButtonCell.m
//  Dopamine
//
//  Created by tomt000 on 26/01/2024.
//

#import "DOButtonCell.h"
#import "DOActionMenuButton.h"
#import "DOGlobalAppearance.h"
#import "DOUIManager.h"

@implementation DOButtonCell

- (id)initWithStyle:(int)style reuseIdentifier:(id)reuseIdentifier specifier:(PSSpecifier *)specifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self)
    {
        [self setShouldHideTitle:YES];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.contentView.backgroundColor = UIColor.clearColor;

        UIAction *action = [UIAction actionWithTitle:DOLocalizedString([specifier propertyForKey:@"title"]) image:[UIImage systemImageNamed:[specifier propertyForKey:@"image"] withConfiguration:[DOGlobalAppearance smallIconImageConfiguration]] identifier:[specifier propertyForKey:@"key"] handler:^(__kindof UIAction * _Nonnull action) {
            SEL selector = NSSelectorFromString([specifier propertyForKey:@"action"]);
            if ([[specifier target] respondsToSelector:selector]) {
                [[specifier target] performSelector:selector withObject:specifier];
            }
        }];

        DOActionMenuButton *button = [DOActionMenuButton buttonWithAction:action chevron:NO];

        button.translatesAutoresizingMaskIntoConstraints = NO;
        [button setContentHorizontalAlignment:UIControlContentHorizontalAlignmentCenter];
        button.tintColor = [DOGlobalAppearance accentColor];
        button.backgroundColor = UIColor.clearColor;

        // The table cell supplies the single row surface, including accessories.
        UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
        configuration.background = [UIBackgroundConfiguration clearConfiguration];
        configuration.baseForegroundColor = [DOGlobalAppearance accentColor];
        configuration.image = action.image;
        configuration.imagePadding = 10;
        // Destructive actions keep their action color; ordinary row titles
        // share the global text role without recoloring their symbols.
        if (![[specifier propertyForKey:@"action"] isEqualToString:@"removeJailbreakPressed"]) {
            configuration.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
                NSMutableDictionary *result = attributes.mutableCopy;
                result[NSForegroundColorAttributeName] = [DOGlobalAppearance primaryTextColor];
                return result;
            };
        } else {
            configuration.baseForegroundColor = UIColor.systemRedColor;
            [DOGlobalAppearance preserveSemanticTextInView:button];
        }
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(0, 20, 0, 20);
        configuration.attributedTitle = [[NSAttributedString alloc] initWithString:action.title attributes:@{
            NSFontAttributeName: [UIFont systemFontOfSize:15 weight:UIFontWeightMedium]
        }];
        button.configuration = configuration;

        [self.contentView addSubview:button];

        [NSLayoutConstraint activateConstraints:@[
            [button.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [button.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [button.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [button.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor],
        ]];
    }
    return self;
}

@end
