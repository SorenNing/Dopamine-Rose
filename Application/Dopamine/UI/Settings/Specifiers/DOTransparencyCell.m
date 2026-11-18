//
//  DOTransparencyCell.m
//  Dopamine
//

#import "DOTransparencyCell.h"
#import "DOGlobalAppearance.h"
#import "DOUIManager.h"
#import <math.h>


@implementation DOTransparencyCell {
    UISlider *_slider;
    UILabel *_valueLabel;
}

- (instancetype)initWithStyle:(int)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (!self) return nil;

    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = UIColor.clearColor;
    self.contentView.backgroundColor = UIColor.clearColor;

    [self setShouldHideTitle:YES];
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = DOLocalizedString(@"Interface_Transparency");
    [self.contentView addSubview:title];
    title.textColor = [DOGlobalAppearance primaryTextColor];
    title.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    title.numberOfLines = 0;
    [title setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

    UILabel *hint = [[UILabel alloc] init];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.text = DOLocalizedString(@"Interface_Transparency_Hint");
    hint.textColor = [DOGlobalAppearance secondaryTextColor];
    hint.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    hint.numberOfLines = 0;
    hint.accessibilityIdentifier = @"DOTransparencyHint";

    _valueLabel = [[UILabel alloc] init];
    _valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _valueLabel.textAlignment = NSTextAlignmentRight;
    _valueLabel.textColor = [DOGlobalAppearance primaryTextColor];
    _valueLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    _valueLabel.accessibilityIdentifier = @"DOTransparencyValue";

    _slider = [[UISlider alloc] init];
    _slider.translatesAutoresizingMaskIntoConstraints = NO;
    _slider.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    _slider.minimumValue = 0.0;
    _slider.maximumValue = 100.0;
    _slider.minimumTrackTintColor = [DOGlobalAppearance accentColor];
    _slider.maximumTrackTintColor = [DOGlobalAppearance separatorColor];
    _slider.accessibilityIdentifier = @"DOTransparencySlider";
    _slider.accessibilityLabel = DOLocalizedString(@"Interface_Transparency");
    _slider.accessibilityValue = @"50%";
    [_slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];

    [self.contentView addSubview:hint];
    [self.contentView addSubview:_valueLabel];
    [self.contentView addSubview:_slider];
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [title.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
        [_valueLabel.widthAnchor constraintGreaterThanOrEqualToConstant:42],
        [hint.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [hint.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [hint.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [_valueLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_valueLabel.centerYAnchor constraintEqualToAnchor:title.centerYAnchor],
        [_valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:title.trailingAnchor constant:8],
        [_slider.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_slider.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_slider.topAnchor constraintEqualToAnchor:hint.bottomAnchor constant:2],
        [_slider.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:78]
    ]];

    [self updateValueFromPreference];
    return self;
}

- (void)updateValueFromPreference
{
    float value = [DOGlobalAppearance interfaceTransparency];
    _slider.value = value;
    [self updateValueLabel:value];
}

- (void)updateValueLabel:(float)value
{
    NSString *text = [NSString stringWithFormat:@"%d%%", (int)lroundf(value)];
    _valueLabel.text = text;
    _slider.accessibilityValue = text;
}

- (void)sliderChanged:(UISlider *)sender
{
    float value = roundf(sender.value);
    sender.value = value;
    if ((NSInteger)value != (NSInteger)[DOGlobalAppearance interfaceTransparency])
        [DOGlobalAppearance setInterfaceTransparency:value];
    [self updateValueLabel:value];

}

- (CGFloat)preferredHeightForWidth:(CGFloat)width
{
    CGSize size = [self.contentView systemLayoutSizeFittingSize:CGSizeMake(MAX(1, width), 0)
                               withHorizontalFittingPriority:UILayoutPriorityRequired
                                     verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return MAX(96, ceil(size.height));
}

@end
