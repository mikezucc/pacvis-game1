//
//  FirstViewController.m
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/7/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import "FirstViewController.h"
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
using namespace std;

cv::Mat cameraMatrixFirstVC;
cv::Mat distortionCoeffFirstVC;

Mat testImage;
cv::Size boardSize(5, 4);
vector<Point2f> corners;
vector<vector<Point2f>> imgPoints;
Mat outputImage;
vector<Point2f> imageFrame;
vector<Point3f> initialFrame;
vector<Point2f> transformedFrame;
vector<Point3f> objPoints;
Mat transfMat;
Mat rvec, tvec;
 

@interface FirstViewController () <VideoSourceDelegate>

@property (nonatomic) dispatch_queue_t displaySerializer;

@end

@implementation FirstViewController

@synthesize closeThisView, displaySerializer, backgroundImageView, videoSource;

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    displaySerializer = dispatch_queue_create("com.ocvGame.displayThread", DISPATCH_QUEUE_SERIAL);
}

-(void)viewDidAppear:(BOOL)animated
{
    cameraMatrixFirstVC = self.cameraMatrixProperty;
    distortionCoeffFirstVC = self.distortionCoeffProperty;
    cout << "camera matrix global: " << cameraMatrixFirstVC << endl;
    
    UIImage *testface = [UIImage imageNamed:@"face.png"];
    testImage = [self toCVMatFromRGBWithAlpha:testface];
    cout << "testImage: " << testImage.rows << endl;
    
    self.videoSource = [[VideoFeed alloc] init];
    self.videoSource.delegate = self;
    [self.videoSource startWithDevicePosition:AVCaptureDevicePositionBack];
    
    self.backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y, 480, 640)];
    self.backgroundImageView.backgroundColor = [UIColor greenColor];
    [self.view addSubview:self.backgroundImageView];
    
    self.closeThisView = [[UIButton alloc] initWithFrame:CGRectMake(20, 20, 40, 40)];
    [self.closeThisView setTitle:@"close me" forState:UIControlStateNormal];
    [self.closeThisView addTarget:self action:@selector(closeMe)forControlEvents:UIControlStateNormal];
    [self.view addSubview:self.closeThisView];

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
- (void)frameReady:(uint8_t *)frameAddress {
    NSLog(@"delegate called on FIRST VIEW");
    cv::Mat holder = cv::Mat((int)640,(int)480,CV_8UC4,frameAddress);
    cv::Mat image;
    holder.copyTo(image);
    holder.release();
    cout << "frame dims is: " << image.rows << " by " << image.cols << endl;
    cv::Mat imageCopyLocal;// = Mat(frame.rows, frame.cols,CV_8UC4);
    image.copyTo(imageCopyLocal);
    imageCopyLocal = performPoseAndPosition(imageCopyLocal);
    cout << "row size: " << imageCopyLocal.rows << endl;
    UIImage *convImg = [self fromCVMatRGB:imageCopyLocal];
    imageCopyLocal.release();
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"updating with image %ld",(long)convImg.size.width);
        [[self backgroundImageView] setImage:convImg];
    });
    /*
    dispatch_async( displaySerializer, ^{
        cout << "frame dims is: " << holder.rows << " by " << holder.cols << endl;
        cv::Mat imageCopyLocal;// = Mat(frame.rows, frame.cols,CV_8UC4);
        image.copyTo(imageCopyLocal);
        imageCopyLocal = performPoseAndPosition(imageCopyLocal);
        cout << "row size: " << imageCopyLocal.rows << endl;
        UIImage *convImg = [self fromCVMatRGB:imageCopyLocal];
        imageCopyLocal.release();
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"updating with image %ld",(long)convImg.size.width);
            [[self backgroundImageView] setImage:convImg];
        });
        //[[_weakSelf backgroundImageView] setNeedsDisplay];
    });
     */
    //holder.release();
}


#ifdef __cplusplus
Mat performPoseAndPosition(const cv::Mat& inputFrame)
{
    cout << "open capture" << endl;
    //outputImage = Mat(testImage.size(), CV_8UC3);
    
    if (imageFrame.size() != 4)
    {
        imageFrame.push_back(Point2f(400, 0));
        imageFrame.push_back(Point2f(400, 400));
        imageFrame.push_back(Point2f(0, 0));
        imageFrame.push_back(Point2f(0, 400));
        initialFrame.push_back(Point3f(400, 0, 0));
        initialFrame.push_back(Point3f(400, 0, 400));
        initialFrame.push_back(Point3f(0, 0, 0));
        initialFrame.push_back(Point3f(0, 0, 400));
        initialFrame.resize(4, initialFrame[0]);
    }
    
    if (objPoints.size() != 20)
    {
        for (int i = 0; i < boardSize.height; ++i)
        {
            for (int j = 0; j < boardSize.width; ++j)
            {
                objPoints.push_back(Point3f(float(j * 1), float(i * 1), 0));
            }
        }
    }
    
    rvec.release();
    tvec.release();
    corners.clear();
    //objPoints.resize(imgPoints.size(), objPoints[0]);
    
    cout << "start while" << endl;
    //cv::Mat imgmat = inputFrame.clone();
    if (findChessboardCorners(inputFrame, cv::Size(5, 4), corners, CALIB_CB_ADAPTIVE_THRESH + CALIB_CB_NORMALIZE_IMAGE))
    {
        drawChessboardCorners(inputFrame, boardSize, Mat(corners), true);
        //calibrateCamera()
        cout << "obj points is " << objPoints << endl;
        cout << "distortion firstVC" << distortionCoeffFirstVC << endl;
        bool solved = solvePnP(objPoints, corners, cameraMatrixFirstVC, distortionCoeffFirstVC, rvec, tvec, false, ITERATIVE);
        if (solved)
        {
            NSLog(@"solved");
        }
        else
        {
            NSLog(@"not solved");
        }
        
        projectPoints(initialFrame, rvec, tvec, cameraMatrixFirstVC, distortionCoeffFirstVC, transformedFrame, noArray(), 0);
        transfMat = getPerspectiveTransform(imageFrame, transformedFrame);
        warpPerspective(testImage, outputImage, transfMat, testImage.size(), INTER_LINEAR, BORDER_CONSTANT, 0);
        circle(inputFrame, transformedFrame[3],10,Scalar(0,0,255),5,-1);
    }
    cout << "query frame" << endl;
    return inputFrame;
}
#endif

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

- (UIImage*)fromCVMatRGB:(const cv::Mat&)cvMat
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

- (cv::Mat)toCVMatFromRGBWithAlpha:(UIImage*)image
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
                                                    kCGImageAlphaLast);
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(contextRef);
    
    // (4) Return OpenCV image container reference
    return cvMat;
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
