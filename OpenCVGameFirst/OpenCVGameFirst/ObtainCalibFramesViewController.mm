//
//  ObtainCalibFramesViewController.m
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/8/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import "ObtainCalibFramesViewController.h"
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

using namespace cv;

@interface ObtainCalibFramesViewController ()

@end

@implementation ObtainCalibFramesViewController

@synthesize selectedImageView, closeMeButton, useMeButton, capturedImage;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(IBAction)closeMe:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(IBAction)useThisPicture:(id)sender
{
    NSString *picName = [NSString stringWithFormat:@"%@.jpeg",[self generateCode]];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSURL *selectedPath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:picName]];
    
    NSData *capturedData = UIImageJPEGRepresentation(capturedImage, 1.0);
    [capturedData writeToFile:selectedPath.path atomically:YES];
    
    NSURL *picStoragePath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:@"calibrationImages.plist"]];
    NSFileManager *fMan = [NSFileManager defaultManager];
    NSMutableArray *listOfCalibrationImages = [[NSMutableArray alloc] init];
    if ([fMan fileExistsAtPath:picStoragePath.path])
    {
        listOfCalibrationImages = [[NSMutableArray alloc] initWithContentsOfFile:picStoragePath.path];
        NSLog(@"list of calib images contains %@",listOfCalibrationImages);
    }
    else
    {
        // do nothing
    }
    [listOfCalibrationImages addObject:picName];
    [listOfCalibrationImages writeToFile:picStoragePath.path atomically:YES];
    
}

- (NSString *)generateCode
{
    static NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY";
    static NSString *digits = @"0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:8];
    //returns 19 random chars into array (mutable string)
    for (NSUInteger i = 0; i < 3; i++) {
        uint32_t r;
        
        // Append 2 random letters:
        r = arc4random_uniform((uint32_t)[letters length]);
        [s appendFormat:@"%C", [letters characterAtIndex:r]];
        r = arc4random_uniform((uint32_t)[letters length]);
        [s appendFormat:@"%C", [letters characterAtIndex:r]];
        
        // Append 2 random digits:
        r = arc4random_uniform((uint32_t)[digits length]);
        [s appendFormat:@"%C", [digits characterAtIndex:r]];
        r = arc4random_uniform((uint32_t)[digits length]);
        [s appendFormat:@"%C", [digits characterAtIndex:r]];
        
    }
    NSLog(@"s-->%@",s);
    return s;
}

-(void)viewDidAppear:(BOOL)animated
{
    [selectedImageView setImage:capturedImage];
    selectedImageView.contentMode = UIViewContentModeScaleToFill;
    selectedImageView.clipsToBounds = YES;
}

#ifdef __cplusplus
- (cv::Mat)toCVMatFromRGB:(UIImage*)image
{
    // (1) Get image dimensions
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    NSLog(@"imageDims are %f x %f",cols, rows);
    
    // (2) Create OpenCV image container, 8 bits per component, 4 channels
    cv::Mat cvMat(rows, cols, CV_8UC3);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    // (3) Create CG context and draw the image
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,
                                                    cols,
                                                    rows,
                                                    CGImageGetBitsPerComponent(image.CGImage),
                                                    764,
                                                    rgbColorSpace,
                                                    CGImageGetBitmapInfo(image.CGImage));
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(contextRef);
    
    // (4) Return OpenCV image container reference
    return cvMat;
}
#endif

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
