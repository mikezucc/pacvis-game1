//
//  HomeViewController.h
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 12/2/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HomeViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIButton *recordCalibImages;
@property (strong, nonatomic) IBOutlet UIButton *runCalibrationScheme;
@property (strong, nonatomic) IBOutlet UIButton *poseEstim8;

@property (strong, nonatomic) UIImageView *chessboardDisplay;

@property (strong, nonatomic) IBOutlet UITextField *numberOfImagesField;
@property (strong, nonatomic) IBOutlet UITextField *rmsField;
//@property (strong, nonatomic) IBOutlet UITextField *numberOfImagesField;

@end
