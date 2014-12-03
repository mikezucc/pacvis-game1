//
//  HomeViewController.m
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 12/2/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import "HomeViewController.h"
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

double rmsForField;

@interface HomeViewController ()

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue;

@end

@implementation HomeViewController

@synthesize numberOfImagesField, recordCalibImages, rmsField, runCalibrationScheme, poseEstim8, chessboardDisplay, sessionQueue;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewDidAppear:(BOOL)animated
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSURL *picStoragePath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:@"calibrationImages.plist"]];
    NSFileManager *fMan = [NSFileManager defaultManager];
    NSMutableArray *listOfCalibrationImages = [[NSMutableArray alloc] init];
    if ([fMan fileExistsAtPath:picStoragePath.path])
    {
        listOfCalibrationImages = [[NSMutableArray alloc] initWithContentsOfFile:picStoragePath.path];
        NSLog(@"list of calib images contains %@",listOfCalibrationImages);
        numberOfImagesField.text = [NSString stringWithFormat:@"%ld",(long) listOfCalibrationImages.count];
    }
    else
    {
        // do nothing
        numberOfImagesField.text = @"0";
    }
    chessboardDisplay = [[UIImageView alloc] initWithFrame:CGRectMake(40, 260, 240, 240)];
    chessboardDisplay.contentMode = UIViewContentModeScaleToFill;
    [self.view addSubview:chessboardDisplay];

}

-(IBAction)obtainCalibration:(id)sender
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSURL *picStoragePath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:@"calibrationImages.plist"]];
    NSFileManager *fMan = [NSFileManager defaultManager];
    NSMutableArray *listOfCalibrationImages = [[NSMutableArray alloc] init];
    if ([fMan fileExistsAtPath:picStoragePath.path])
    {
        listOfCalibrationImages = [[NSMutableArray alloc] initWithContentsOfFile:picStoragePath.path];
        NSLog(@"list of calib images contains %@",listOfCalibrationImages);
        numberOfImagesField.text = [NSString stringWithFormat:@"%ld",(long) listOfCalibrationImages.count];
        vector<String> tempList;
        for (int i=0; i<listOfCalibrationImages.count;i++)
        {
            String convString = [(NSString *)[listOfCalibrationImages objectAtIndex:i] UTF8String];
            tempList.push_back(convString);
        }
        NSLog(@"beginning calibration");
        dispatch_queue_t queue;
        queue = dispatch_queue_create("com.example.calibThread", DISPATCH_QUEUE_SERIAL);
        sessionQueue = dispatch_queue_create("com.example.chessDisplayThread", DISPATCH_QUEUE_SERIAL);
        __weak typeof(self) _weakSelf = self;
        dispatch_async(queue, ^{
            HomeViewController *strongSelf = _weakSelf;
            [strongSelf runCalib:tempList];
        });
        NSLog(@"returned to calling thread");
        rmsField.text = [NSString stringWithFormat:@"%f",(float)rmsForField];
    }
    else
    {
        // do nothing
        rmsField.text = @"nothing calibrated yet";
    }
}

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

#ifdef __cplusplus
static double computeReprojectionErrors(const vector<vector<Point3f> >& objectPoints,
                                        const vector<vector<Point2f> >& imagePoints,
                                        const vector<Mat>& rvecs, const vector<Mat>& tvecs,
                                        const Mat& cameraMatrix, const Mat& distCoeffs,
                                        vector<float>& perViewErrors)
{
    vector<Point2f> imagePoints2;
    int i, totalPoints = 0;
    double totalErr = 0, err;
    perViewErrors.resize(objectPoints.size());
    
    NSLog(@"preparing error calculation");
    
    for (i = 0; i < (int)objectPoints.size(); ++i)
    {
        projectPoints(Mat(objectPoints[i]), rvecs[i], tvecs[i], cameraMatrix,
                      distCoeffs, imagePoints2);
        err = norm(Mat(imagePoints[i]), Mat(imagePoints2), 4);
        NSLog(@"error for objpt: %ld is: %f",(long)i,(float)err);
        int n = (int)objectPoints[i].size();
        perViewErrors[i] = (float)std::sqrt(err*err / n);
        totalErr += err*err;
        totalPoints += n;
    }
    
    return std::sqrt(totalErr / totalPoints);
}

static void saveCameraParams(Mat& cameraMatrix, Mat& distCoeffs)
{
    FileStorage fs("cameraParams.xml", FileStorage::WRITE);
    fs << "Camera_Matrix" << cameraMatrix;
    fs << "Distortion_Coefficients" << distCoeffs;
    NSLog(@"wrote camera params");
    fs.release();
}

Mat loadACalibrationImage(String filepath)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePathNS = [NSString stringWithUTF8String:filepath.c_str()];
    NSURL *picStoragePath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:filePathNS]];
    NSLog(@"pic storage path is %@",picStoragePath);
    UIImage *nsImage = [[UIImage alloc] initWithContentsOfFile:picStoragePath.path];
    // (1) Get image dimensions
    CGFloat cols = nsImage.size.width;
    CGFloat rows = nsImage.size.height;
    NSLog(@"imageDims are %f x %f",cols, rows);
    
    // (2) Create OpenCV image container, 8 bits per component, 4 channels
    cv::Mat cvMat(rows, cols, CV_8UC4);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    // (3) Create CG context and draw the image
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,
                                                    cols,
                                                    rows,
                                                    CGImageGetBitsPerComponent(nsImage.CGImage),
                                                    1920,
                                                    rgbColorSpace,
                                                    CGImageGetBitmapInfo(nsImage.CGImage));
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), nsImage.CGImage);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(contextRef);

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

-(void)displayThisChessBoard:(const cv::Mat&)cvMat
{
    NSLog(@"portraying drawn chessboard");
    UIImage *converted = [self fromCVMatRGB:cvMat];
    dispatch_async(sessionQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"display chessboard in nested queue");
            [[self chessboardDisplay] setImage:converted];
        });
    });
}

-(void)runCalib:(vector<String>)listOfPicLocations
{
    double widthInp = 4, heightInp = 5;
    
    //IplImage *img;
    Mat imgMat;
    Mat rvecsMat;
    Mat tvecsMat;
    cv::Size boardSize(widthInp, heightInp);
    vector<Point2f> corners;
    int photoNum = 0;
    vector<Mat> rvecs, tvecs;
    vector<float> reprojErrs;
    vector<vector<Point2f>> imgPoints;
    Mat cameraMatrix = Mat::eye(3, 3, CV_64F);
    //Mat distCoeffs;
    Mat distCoeffs = Mat::zeros(8, 1, CV_64F);
    vector<Mat> rvecArr;
    vector<Mat> tvecArr;
    double rms;
    vector<double>rmsArr;
    
    while (photoNum < listOfPicLocations.size()) {
        if (photoNum == (widthInp * heightInp)) break;
        NSLog(@"processing image %ld",(long)photoNum);
        string filepath = listOfPicLocations[photoNum];
        imgMat = loadACalibrationImage(filepath);
        if (!imgMat.data)
        {
            break;
        }
        else
        {
            NSLog(@"image loaded correctly");
        }
        if (findChessboardCorners(imgMat, cv::Size(5, 4), corners, CALIB_CB_ADAPTIVE_THRESH + CALIB_CB_NORMALIZE_IMAGE))
        {
            imgPoints.push_back(corners);
            drawChessboardCorners(imgMat, boardSize, Mat(corners), true);
            //dispatch_async( dispatch_get_main_queue(), ^{
                [self displayThisChessBoard:imgMat];
            //});
            //calibrateCamera()
        }
        photoNum++;
    }
    vector<vector<Point3f>> objPoints(1);
    for (int i = 0; i < boardSize.height; ++i)
        for (int j = 0; j < boardSize.width; ++j)
            objPoints[0].push_back(Point3f(float(j * 1), float(i * 1), 0));
    
    objPoints.resize(imgPoints.size(), objPoints[0]);
    
    rms = calibrateCamera(objPoints, imgPoints, cv::Size(640, 480), cameraMatrix, distCoeffs, rvecs, tvecs, 0, TermCriteria(TermCriteria::COUNT + TermCriteria::EPS, 30, DBL_EPSILON));
    NSLog(@"rms is %f",(float)rms);
    rmsArr.push_back(rms);
    
    double totalAvgErr = computeReprojectionErrors(objPoints, imgPoints, rvecs, tvecs, cameraMatrix, distCoeffs, reprojErrs);
    
    rmsForField = totalAvgErr;
    [self.rmsField setText:[NSString stringWithFormat:@"%f",(float)rmsForField]];
    NSLog(@"total Average Error: %f",(float)totalAvgErr);
    
    saveCameraParams(cameraMatrix, distCoeffs);
    
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
