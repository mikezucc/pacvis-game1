//
//  FirstViewController.h
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/7/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VideoFeed.h"
#import <SpriteKit/SpriteKit.h>

@interface FirstViewController : UIViewController
{
    cv::Mat cameraMatrixProperty;
    cv::Mat distortionCoeffProperty;
}
@property cv::Mat cameraMatrixProperty;
@property cv::Mat distortionCoeffProperty;

@property (nonatomic, strong) VideoFeed *videoSource;
@property (nonatomic, strong) UIImageView *backgroundImageView;

@property (nonatomic, strong) IBOutlet UIButton *closeThisView;

-(IBAction)closeMe;

@end
