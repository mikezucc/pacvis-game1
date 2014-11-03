//
//  ObtainCalibFramesViewController.h
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/8/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//


//#import "VideoFeed.h"
#import <UIKit/UIKit.h>
#import "VideoFeedCalibrate.h"

@interface ObtainCalibFramesViewController : UIViewController

@property (nonatomic, strong) VideoFeedCalibrate *videoSource;
@property (nonatomic, strong) IBOutlet UIImageView *backgroundImageView;

@property (nonatomic, strong) IBOutlet UIButton *closeThisView;

-(IBAction)closeMe;

@end
