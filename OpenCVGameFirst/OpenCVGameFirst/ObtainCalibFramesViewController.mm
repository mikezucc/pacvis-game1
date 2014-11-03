//
//  ObtainCalibFramesViewController.m
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/8/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import "ObtainCalibFramesViewController.h"

@interface ObtainCalibFramesViewController () <VideoSourceDelegate>

@end

@implementation ObtainCalibFramesViewController

@synthesize closeThisView;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.videoSource = [[VideoFeedCalibrate alloc] init];
    self.videoSource.delegate = self;
    [self.videoSource startWithDevicePosition:AVCaptureDevicePositionBack];
    
    self.backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y, 480, 640)];
    [self.view addSubview:self.backgroundImageView];
    
    closeThisView = [[UIButton alloc] initWithFrame:CGRectMake(20, 20, 40, 40)];
    [closeThisView setTitle:@"close me" forState:UIControlStateNormal];
    [closeThisView addTarget:self action:@selector(closeMe)forControlEvents:UIControlStateNormal];
    [self.view addSubview:closeThisView];

}

-(IBAction)closeMe
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark VideoSource Delegate
- (void)frameReady:(const cv::Mat&)frame {
    __weak typeof(self) _weakSelf = self;
    dispatch_sync( dispatch_get_main_queue(), ^{
        // Construct CGContextRef from VideoFrame
        //NSLog(@"did capture a frame %s, with stride %zu",frame.data, frame.stride);
        /*
         CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
         CGContextRef newContext = CGBitmapContextCreate(frame.data,
         frame.width,
         frame.height,
         8,
         frame.stride,
         colorSpace,
         kCGBitmapByteOrder32Little |
         kCGImageAlphaPremultipliedFirst);
         
         // Construct CGImageRef from CGContextRef
         CGImageRef newImage = CGBitmapContextCreateImage(newContext);
         
         // Construct UIImage from CGImageRef
         UIImage * image = [UIImage imageWithCGImage:newImage];
         CGImageRelease(newImage);
         CGContextRelease(newContext);
         CGColorSpaceRelease(colorSpace);
         */
        UIImage *convImg = [self fromCVMat:frame];
        [[_weakSelf backgroundImageView] setImage:convImg];
        [[_weakSelf backgroundImageView] setNeedsDisplay];
    });
}

- (UIImage*)fromCVMat:(const cv::Mat&)cvMat
{
    // (1) Construct the correct color space
    CGColorSpaceRef colorSpace;
    if ( cvMat.channels() == 1 ) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    // (2) Create image data reference
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, cvMat.data, (cvMat.elemSize() * cvMat.total()));
    
    // (3) Create CGImage from cv::Mat container
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGImageRef imageRef = CGImageCreate(cvMat.cols,
                                        cvMat.rows,
                                        8,
                                        8 * cvMat.elemSize(),
                                        cvMat.step[0],
                                        colorSpace,
                                        kCGImageAlphaNone | kCGBitmapByteOrderDefault,
                                        provider,
                                        NULL,
                                        false,
                                        kCGRenderingIntentDefault);
    
    // (4) Create UIImage from CGImage
    UIImage * finalImage = [UIImage imageWithCGImage:imageRef];
    
    // (5) Release the references
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CFRelease(data);
    CGColorSpaceRelease(colorSpace);
    
    // (6) Return the UIImage instance
    return finalImage;
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
