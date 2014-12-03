//
//  ObtainCalibFramesViewController.h
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/8/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ObtainCalibFramesViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIButton *closeMeButton;
@property (strong, nonatomic) IBOutlet UIButton *useMeButton;
@property (strong, nonatomic) IBOutlet UIImageView *selectedImageView;

@property (strong, nonatomic) UIImage *capturedImage;

@end
