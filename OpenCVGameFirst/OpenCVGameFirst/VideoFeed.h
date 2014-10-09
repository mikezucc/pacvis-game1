//
//  VideoFeed.h
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/7/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "VideoFrame.h"

#import <opencv2/videoio/cap_ios.h>
#import <opencv2/opencv.hpp>
#import "opencv2/core.hpp"
#import "opencv2/imgproc.hpp"
#import "opencv2/photo.hpp"
#import "opencv2/video.hpp"
#import "opencv2/features2d.hpp"
#import "opencv2/objdetect.hpp"
#import "opencv2/calib3d.hpp"
#import "opencv2/imgcodecs.hpp"
#import "opencv2/videoio.hpp"
#import "opencv2/highgui.hpp"
#import "opencv2/ml.hpp"

#pragma mark -
#pragma mark VideoSource Delegate
@protocol VideoSourceDelegate <NSObject>

@required
- (void)frameReady:(const cv::Mat &)frame;

@end

#pragma mark -
#pragma mark VideoSource Interface


@interface VideoFeed : NSObject

@property (nonatomic, strong) AVCaptureSession * captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput * deviceInput;
@property (nonatomic, weak) id<VideoSourceDelegate> delegate;

- (BOOL)startWithDevicePosition:(AVCaptureDevicePosition)devicePosition;

@property (nonatomic, strong) UIImage *doge;

@end
