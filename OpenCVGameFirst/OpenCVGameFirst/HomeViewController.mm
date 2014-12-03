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

@interface HomeViewController ()

@end

@implementation HomeViewController

@synthesize numberOfImagesField, recordCalibImages, rmsField, runCalibrationScheme, poseEstim8;

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

}

-(IBAction)obtainCalibration:(id)sender
{
    
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
    
    for (i = 0; i < (int)objectPoints.size(); ++i)
    {
        projectPoints(Mat(objectPoints[i]), rvecs[i], tvecs[i], cameraMatrix,
                      distCoeffs, imagePoints2);
        err = norm(Mat(imagePoints[i]), Mat(imagePoints2), CV_L2);
        
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
}

void runCalib(String picListLocation)
{
    double widthInp = 4, heightInp = 5;
    
    namedWindow("Display window", WINDOW_AUTOSIZE); // Create a window for display.
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
    
    while (1) {
        if (photoNum == (widthInp * heightInp)) break;
        cout << "start while" << endl;
        string imageName = "./images/" + to_string(photoNum) + ".jpg";
        imgMat = imread(imageName, 1);
        if (!imgMat.data) break;
        cout << "image properly read with " << imgMat.cols << " cols" << endl;
        if (findChessboardCorners(imgMat, cv::Size(5, 4), corners, CALIB_CB_ADAPTIVE_THRESH + CALIB_CB_NORMALIZE_IMAGE))
        {
            cout << "found chessboard corners" << endl;
            imgPoints.push_back(corners);
            cout << "imgPoints dims are " << imgPoints.size() << endl;
            drawChessboardCorners(imgMat, boardSize, Mat(corners), true);
            //calibrateCamera()
        }
        cout << "done through frame " << photoNum << endl;
        imshow("Example2", imgMat);
        photoNum++;
    }
    vector<vector<Point3f>> objPoints(1);
    for (int i = 0; i < boardSize.height; ++i)
        for (int j = 0; j < boardSize.width; ++j)
            objPoints[0].push_back(Point3f(float(j * 1), float(i * 1), 0));
    
    objPoints.resize(imgPoints.size(), objPoints[0]);
    
    cout << "objPoints dims are " << objPoints.size() << endl;
    rms = calibrateCamera(objPoints, imgPoints, cv::Size(640, 480), cameraMatrix, distCoeffs, rvecs, tvecs, 0, TermCriteria(TermCriteria::COUNT + TermCriteria::EPS, 30, DBL_EPSILON));
    //Mat copyctn;
    rmsArr.push_back(rms);
    cout << "error for " << photoNum << " is: " << rms << endl;
    
    double totalAvgErr = computeReprojectionErrors(objPoints, imgPoints, rvecs, tvecs, cameraMatrix, distCoeffs, reprojErrs);
    
    cout << "total average error: " << totalAvgErr << endl;
    cout << "Saving parameters..." << endl;
    saveCameraParams(cameraMatrix, distCoeffs);
    cout << "Done saving to \"cameraParams.xml\"" << endl;
    
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
