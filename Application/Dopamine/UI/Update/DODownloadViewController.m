//
//  DODownloadViewController.m
//  Dopamine
//
//  Created by tomt000 on 07/02/2024.
//

#import "DODownloadViewController.h"
#import "DOUpdateCircleView.h"
#import "DOUIManager.h"
#import "DOGlobalAppearance.h"
#import "DOPSListController.h"

@interface DODownloadViewController ()

@property (strong, nonatomic) DOUpdateCircleView *circleView;
@property (strong, nonatomic) NSString *urlString;
@property (copy, nonatomic) void (^downloadCallback)(NSURL *file);
@property (strong, nonatomic) NSURLSessionDownloadTask *downloadTask;
@property (strong, nonatomic) NSTimer *progressTimer;

@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *descriptionLabel;

@end

@implementation DODownloadViewController

- (id)initWithUrl:(NSString *)urlString callback:(void (^)(NSURL *file))callback {
    self = [super init];
    if (self) {
        self.urlString = urlString;
        self.downloadCallback = callback;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [DOPSListController setupViewControllerStyle:self];
    UIView *pageContent = [DOGlobalAppearance contentViewForController:self];

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.alignment = UIStackViewAlignmentCenter;
    stackView.distribution = UIStackViewDistributionEqualSpacing;
    stackView.spacing = 10;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.text = DOLocalizedString(@"Update_Status_Downloading");
    self.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightMedium];
    self.titleLabel.textColor = [DOGlobalAppearance primaryTextColor];

    self.descriptionLabel = [[UILabel alloc] init];
    self.descriptionLabel.text = DOLocalizedString(@"Update_Status_Subtitle_Please_Wait");
    self.descriptionLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightRegular];
    self.descriptionLabel.textColor = [DOGlobalAppearance secondaryTextColor];
    self.descriptionLabel.textAlignment = NSTextAlignmentCenter;
    self.descriptionLabel.numberOfLines = 0;

    self.circleView = [[DOUpdateCircleView alloc] initWithFrame:CGRectNull];
    self.circleView.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *spacer = [[UIView alloc] init];
    spacer.translatesAutoresizingMaskIntoConstraints = NO;

    [stackView addArrangedSubview:self.titleLabel];
    [stackView addArrangedSubview:self.descriptionLabel];
    [stackView addArrangedSubview:spacer];
    [stackView addArrangedSubview:self.circleView];

    [NSLayoutConstraint activateConstraints:@[
        [self.circleView.widthAnchor constraintEqualToConstant:150],
        [self.circleView.heightAnchor constraintEqualToConstant:150],
        [spacer.heightAnchor constraintEqualToConstant:20]
    ]];   

    [pageContent addSubview:stackView];

    [NSLayoutConstraint activateConstraints:@[
        [stackView.centerXAnchor constraintEqualToAnchor:pageContent.centerXAnchor],
        [stackView.centerYAnchor constraintEqualToAnchor:pageContent.centerYAnchor],
        [stackView.widthAnchor constraintEqualToAnchor:pageContent.widthAnchor multiplier:0.8]
    ]];

    [self startDownload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.downloadTask && self.downloadTask.state == NSURLSessionTaskStateRunning) {
        [self trackDownloadProgress:self.downloadTask];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopTrackingDownloadProgress];
    [self.circleView.layer removeAllAnimations];
}

- (void)dealloc {
    [_progressTimer invalidate];
}

- (void)stopTrackingDownloadProgress {
    [self.progressTimer invalidate];
    self.progressTimer = nil;
}

- (void)startDownload {
    [self stopTrackingDownloadProgress];
    NSURL *url = [NSURL URLWithString:self.urlString];
    if (!url) {
        NSLog(@"Invalid URL");
        return;
    }

    __weak typeof(self) weakSelf = self;
    // Keep delivery independent of the page lifetime, as before.
    void (^downloadCallback)(NSURL *) = [self.downloadCallback copy];
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            DODownloadViewController *strongSelf = weakSelf;
            [strongSelf stopTrackingDownloadProgress];
            strongSelf.downloadTask = nil;
        });
        if (error) {
            NSLog(@"Download error: %@", error.localizedDescription);
            return;
        }

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *destinationPath = [documentsDirectory stringByAppendingPathComponent:[location lastPathComponent]];
        NSURL *destinationURL = [NSURL fileURLWithPath:destinationPath];

        NSError *fileError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destinationURL error:&fileError];
        if (fileError) {
            NSLog(@"File moving error: %@", fileError.localizedDescription);
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            DODownloadViewController *strongSelf = weakSelf;
            strongSelf.circleView.progress = 1.0;
            if (downloadCallback) {
                downloadCallback(destinationURL);
                [strongSelf startBlinking];
            }
        });
    }];

    self.downloadTask = downloadTask;
    [self trackDownloadProgress:downloadTask];
    [downloadTask resume];
}

- (void)trackDownloadProgress:(NSURLSessionDownloadTask *)downloadTask {
    [self stopTrackingDownloadProgress];
    __weak typeof(self) weakSelf = self;
    __weak NSURLSessionDownloadTask *weakDownloadTask = downloadTask;
    self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:(1.0/60.0) repeats:YES block:^(NSTimer * _Nonnull timer) {
        DODownloadViewController *strongSelf = weakSelf;
        NSURLSessionDownloadTask *task = weakDownloadTask;
        if (!strongSelf) {
            [timer invalidate];
            return;
        }
        if (!task || task.state == NSURLSessionTaskStateCompleted || task.state == NSURLSessionTaskStateCanceling) {
            [strongSelf stopTrackingDownloadProgress];
            return;
        }

        if (task.countOfBytesExpectedToReceive > 0) {
            float progress = (float) task.countOfBytesReceived / (float) task.countOfBytesExpectedToReceive;
            if (strongSelf.circleView.progress < progress) {
                strongSelf.circleView.progress += (progress - strongSelf.circleView.progress) * 0.25;
            }
        }
    }];
}

- (void)startBlinking {
    self.titleLabel.text = DOLocalizedString(@"Update_Status_Installing");
    self.descriptionLabel.text = DOLocalizedString(@"Update_Status_Subtitle_Restart_Soon");
    if (!self.view.window) return;
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionAllowUserInteraction animations:^{
        self.circleView.alpha = 0.7;
    } completion:nil];
}

#pragma mark - Status Bar

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return [DOGlobalAppearance interfaceStyle] == UIUserInterfaceStyleDark ? UIStatusBarStyleLightContent : UIStatusBarStyleDarkContent;
}


@end
