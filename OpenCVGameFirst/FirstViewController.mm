//
//  FirstViewController.m
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/7/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import "FirstViewController.h"
#import "MyScene.h"
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
cv::Size boardSize(6, 9);
vector<Point2f> corners;
vector<vector<Point2f>> imgPoints;
Mat outputImage;
vector<Point2f> imageFrame;
vector<Point3f> initialFrame;
vector<Point2f> transformedFrame;
vector<Point3f> objPoints;
Mat transfMat;
Mat rvec, tvec;
bool didFindChess;
 

@interface FirstViewController () <VideoSourceDelegate>

@property (nonatomic) dispatch_queue_t displaySerializer;
@property (nonatomic, weak) IBOutlet SKView *frontView;
@property (nonatomic, assign) CGFloat rotAngle;

@property (strong, nonatomic) dispatch_queue_t cvQueue;

@end

@implementation FirstViewController

@synthesize closeThisView, displaySerializer, backgroundImageView, videoSource, cvQueue;

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    displaySerializer = dispatch_queue_create("com.ocvGame.displayThread", DISPATCH_QUEUE_SERIAL);
    
    self.cvQueue = dispatch_queue_create("com.cvthread", DISPATCH_QUEUE_SERIAL);
    
    self.rotAngle = 10;
    
    // Configure the front view.
    SKView * skViewFront = self.frontView;
    skViewFront.showsFPS = YES;
    skViewFront.showsNodeCount = YES;
    
    // Create and configure the front scene.
    SKScene * sceneFront = [MyScene sceneWithSize:skViewFront.bounds.size];
    sceneFront.scaleMode = SKSceneScaleModeAspectFill;
    
    // Present the front scene.
    [skViewFront presentScene:sceneFront];
    
    didFindChess = false;
}

-(void)rotateFrontViewOnXAxis
{
    if (rvec.size().height != 0)
    {
        NSLog(@"rotating now");
        self.rotAngle -= 10;
        
        float angle = (M_PI / 180.0f) * self.rotAngle;
        
        float XTheta = rvec.at<double>(0);
        float YTheta = rvec.at<double>(1);
        float ZTheta = rvec.at<double>(2);
        
        cout << "rvec before rotate is " << rvec << endl;
        cout<< "must rotate" << (M_PI -(float)XTheta) << "radians" << endl;
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            /*
            CATransform3D transform3DRotation = CATransform3DMakeRotation( (float)YTheta, 0.0, 1.0, 0.0);
            //CATransform3DRotate(transform3DRotation, (float)YTheta, 0.0, 1.0, 0.0);
            //CATransform3DRotate(transform3DRotation, ZTheta, 0.0, 0.0, 1.0);
            */
                /*
                 CATransform3D transform3DRotation = CATransform3DMakeRotation( (float)YTheta, 0.0, 1.0, 0.0);
                 //CATransform3DRotate(transform3DRotation, (float)YTheta, 0.0, 1.0, 0.0);
                 //CATransform3DRotate(transform3DRotation, ZTheta, 0.0, 0.0, 1.0);
                 */
            
            CATransform3D rotationAndPerspectiveTransform = CATransform3DIdentity;
            
            rotationAndPerspectiveTransform.m34 = 1.0f / -200.0f;
            rotationAndPerspectiveTransform = CATransform3DRotate(rotationAndPerspectiveTransform, XTheta, 0.1f, 0.0f, 0.0f);
            
            
            /*
            rotationAndPerspectiveTransform = CATransform3DRotate(rotationAndPerspectiveTransform, -YTheta, 0.0f, 1.0f, 0.0f);
            
            rotationAndPerspectiveTransform = CATransform3DRotate(rotationAndPerspectiveTransform, ZTheta, 0.0f, 0.0f, 1.0f);
            */
            //transfMat
            /*
            rotationAndPerspectiveTransform.m11 = transfMat.at<float>(0,0);
            rotationAndPerspectiveTransform.m12 = transfMat.at<float>(0,1);
            rotationAndPerspectiveTransform.m13 = transfMat.at<float>(0,2);
            rotationAndPerspectiveTransform.m14 = transfMat.at<float>(0,3);
            rotationAndPerspectiveTransform.m21 = transfMat.at<float>(1,0);
            rotationAndPerspectiveTransform.m22 = transfMat.at<float>(1,1);
            rotationAndPerspectiveTransform.m23 = transfMat.at<float>(1,2);
            rotationAndPerspectiveTransform.m24 = transfMat.at<float>(1,3);
            rotationAndPerspectiveTransform.m31 = transfMat.at<float>(2,0);
            rotationAndPerspectiveTransform.m32 = transfMat.at<float>(2,1);
            rotationAndPerspectiveTransform.m33 = transfMat.at<float>(2,2);
            rotationAndPerspectiveTransform.m34 = transfMat.at<float>(2,3);
            rotationAndPerspectiveTransform.m41 = transfMat.at<float>(3,0);
            rotationAndPerspectiveTransform.m42 = transfMat.at<float>(3,1);
            rotationAndPerspectiveTransform.m43 = transfMat.at<float>(3,2);
            rotationAndPerspectiveTransform.m44 = transfMat.at<float>(3,3);
            */
            
            self.frontView.layer.transform = rotationAndPerspectiveTransform;
            self.frontView.layer.zPosition = 200;
            [self.frontView setNeedsDisplay];
        });
    }
}
/*
+ (CATransform3D)transformQuadrilateral:(Quadrilateral)origin toQuadrilateral:(Quadrilateral)destination {
    
    CvPoint2D32f *cvsrc = [self openCVMatrixWithQuadrilateral:origin];
    CvMat *src_mat = cvCreateMat( 4, 2, CV_32FC1 );
    cvSetData(src_mat, cvsrc, sizeof(CvPoint2D32f));
    
    CvPoint2D32f *cvdst = [self openCVMatrixWithQuadrilateral:destination];
    CvMat *dst_mat = cvCreateMat( 4, 2, CV_32FC1 );
    cvSetData(dst_mat, cvdst, sizeof(CvPoint2D32f));
    
    CvMat *H = cvCreateMat(3,3,CV_32FC1);
    cvFindHomography(src_mat, dst_mat, H);
    cvReleaseMat(&src_mat);
    cvReleaseMat(&dst_mat);
    
    CATransform3D transform = [self transform3DWithCMatrix:H->data.fl];
    cvReleaseMat(&H);
    
    return transform;
}

+ (CvPoint2D32f *)openCVMatrixWithQuadrilateral:(Quadrilateral)origin {
    
    CvPoint2D32f *cvsrc = (CvPoint2D32f *)malloc(4*sizeof(CvPoint2D32f));
    cvsrc[0].x = origin.upperLeft.x;
    cvsrc[0].y = origin.upperLeft.y;
    cvsrc[1].x = origin.upperRight.x;
    cvsrc[1].y = origin.upperRight.y;
    cvsrc[2].x = origin.lowerRight.x;
    cvsrc[2].y = origin.lowerRight.y;
    cvsrc[3].x = origin.lowerLeft.x;
    cvsrc[3].y = origin.lowerLeft.y;
    return cvsrc;
}

+ (CATransform3D)transform3DWithCMatrix:(float *)matrix {
    CATransform3D transform = CATransform3DIdentity;
    
    transform.m11 = matrix[0];
    transform.m21 = matrix[1];
    transform.m41 = matrix[2];
    
    transform.m12 = matrix[3];
    transform.m22 = matrix[4];
    transform.m42 = matrix[5];
    
    transform.m14 = matrix[6];
    transform.m24 = matrix[7];
    transform.m44 = matrix[8];
    
    return transform; 
}
 */

-(void)viewDidAppear:(BOOL)animated
{
    cameraMatrixFirstVC = self.cameraMatrixProperty;
    distortionCoeffFirstVC = self.distortionCoeffProperty;
    cout << "camera matrix global: " << cameraMatrixFirstVC << endl;
    
    //UIImage *testface = [UIImage imageNamed:@"smallface.png"];
    //testImage = [self toCVMatFromRGBWithAlpha:testface];
    //cout << "testImage: " << testImage.rows << endl;
    //UIImage *newThang = [self fromCVMatRGB:testImage];
    
    self.videoSource = [[VideoFeed alloc] init];
    self.videoSource.delegate = self;
    [self.videoSource startWithDevicePosition:AVCaptureDevicePositionBack];
    
    self.backgroundImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.view.frame.origin.x, self.view.frame.origin.y, 480, 640)];
    self.backgroundImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.backgroundImageView.backgroundColor = [UIColor greenColor];
    [self.view addSubview:self.backgroundImageView];
    [self.view sendSubviewToBack:self.backgroundImageView];
    //[self.backgroundImageView setImage:newThang];
    
    /*self.closeThisView = [[UIButton alloc] initWithFrame:CGRectMake(20, 20, 40, 40)];
    [self.closeThisView setTitle:@"close me" forState:UIControlStateNormal];
    [self.closeThisView addTarget:self action:@selector(closeMe)forControlEvents:UIControlStateNormal];
    [self.view addSubview:self.closeThisView];*/
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
    //cv::Mat imageCopyLocal;// = Mat(frame.rows, frame.cols,CV_8UC4);
    //image.copyTo(imageCopyLocal);
    holder  = performPoseAndPosition(holder);
    if (didFindChess)
    {
        [self rotateFrontViewOnXAxis];
    }
    //cout << "row size: " << imageCopyLocal.rows << endl;
    UIImage *convImg = [self fromCVMatRGB:holder];
    holder.release();
    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"updating with image %ld",(long)convImg.size.width);
        [[self backgroundImageView] setImage:convImg];
    });
    convImg = nil;
    //cv::Mat image;
    //holder.copyTo(image);
    //holder.release();
    //cout << "frame dims is: " << image.rows << " by " << image.cols << endl;
    
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
        imageFrame.push_back(Point2f(0, 0));
        imageFrame.push_back(Point2f(0, 10));
        imageFrame.push_back(Point2f(10, 10));
        imageFrame.push_back(Point2f(10, 0));
        
        initialFrame.push_back(Point3f(0, 0, 0));
        initialFrame.push_back(Point3f(0, 0, -10));
        initialFrame.push_back(Point3f(10, 0, -10));
        initialFrame.push_back(Point3f(10, 0, 0));
        
         // THIS IS FOR A CUBE, this messes up other code
/*        initialFrame.push_back(Point3f(30, 30, 0));
        initialFrame.push_back(Point3f(0, 30, -10));
        initialFrame.push_back(Point3f(30, 30, -10));
        initialFrame.push_back(Point3f(0, 30, 0));
 */
        //initialFrame.resize(4, initialFrame[0]);
    }
    
    if (objPoints.size() != 54)
    {
        for (int i = 0; i < boardSize.height; ++i)
        {
            for (int j = 0; j < boardSize.width; ++j)
            {
                objPoints.push_back(Point3f(float(j * 5),  float(i * 5), 0));
            }
        }
    }
    
    rvec.release();
    tvec.release();
    corners.clear();
    //objPoints.resize(imgPoints.size(), objPoints[0]);
    
    cout << "start while ++++++++++++++++++++++++++++++++++++++++++++++++" << endl;
    //cv::Mat imgmat = inputFrame.clone();
    if (findChessboardCorners(inputFrame, cv::Size(6, 9), corners, CALIB_CB_ADAPTIVE_THRESH + CALIB_CB_NORMALIZE_IMAGE))
    {
        //drawChessboardCorners(inputFrame, boardSize, Mat(corners), true);
        //calibrateCamera()
        //cout << "obj points is " << objPoints << endl;
        //cout << "distortion firstVC" << distortionCoeffFirstVC << endl << "cam matrix: " << cameraMatrixFirstVC << endl;
        
        //cout << "objPoints 1: " << objPoints << endl << " corners: " << corners << endl;
        didFindChess = solvePnP(objPoints, corners, cameraMatrixFirstVC, distortionCoeffFirstVC, rvec, tvec, false, ITERATIVE);
        //cout << "rvec is " << rvec << endl;
        
        if (didFindChess)
        {
            NSLog(@"solved");
            projectPoints(initialFrame, rvec, tvec, cameraMatrixFirstVC, distortionCoeffFirstVC, transformedFrame, noArray(), 0);
            transfMat = getPerspectiveTransform(imageFrame, transformedFrame);
            cout << "transformed mat is " << transfMat << endl;
            //warpPerspective(testImage, outputImage, transfMat, testImage.size(), INTER_LINEAR, BORDER_CONSTANT, 0);
            /*
            int roiWidth = 0, roiHeight = 0;
            roiWidth = outputImage.size().width;
            roiHeight = outputImage.size().height;
            if ((outputImage.size().width + transformedFrame[2].x) >= inputFrame.size().width)
            {
                // too big width
                cout << "OUT OF FRAME RIGHT" << endl;
                roiWidth = transformedFrame[2].x - inputFrame.size().width;
            }
            if (transformedFrame[2].x <= 0)
            {
                cout << "OUT OF FRAME LEFT" << endl;
                roiWidth = transformedFrame[2].x + outputImage.size().width;
            }
            if ((outputImage.size().height + transformedFrame[2].y) >= inputFrame.size().height)
            {
                cout << "OUT OF FRAME BOTTOM" << endl;
                roiHeight = inputFrame.size().height - transformedFrame[2].y;
            }
            if (transformedFrame[2].y <= 0)
            {
                cout << "OUT OF FRAME TOP" << endl;
                roiHeight = transformedFrame[2].y + outputImage.size().height;
            }
            
            // This is a bit of hack, but adds in the warped game frame by threshing and masking black (see that rhymed)
            //cv::Rect roi( transformedFrame[2], cv::Size( roiWidth, roiHeight));
            int rows, cols, channels;
            rows = outputImage.rows;
            cols = outputImage.cols;
            channels = outputImage.channels();
            cv::Rect roi( cv::Point(0,0), cv::Size( roiWidth, roiHeight));
            cv::Mat destinationROI = inputFrame( roi );
            cv::Mat grayDog;
            cvtColor(outputImage, grayDog, COLOR_RGBA2GRAY);
            cvtColor(destinationROI, destinationROI, COLOR_RGBA2GRAY);
            cv::Mat mask, maskInv;
            threshold(grayDog, mask, 10, 255, THRESH_TOZERO);
            threshold(grayDog, maskInv, 10, 255, THRESH_TOZERO_INV);
            destinationROI.copyTo(destinationROI, mask);
            outputImage.copyTo(outputImage, maskInv);
            //cv::add(outputImage, destinationROI, destinationROI);
            inputFrame(roi) = destinationROI;
            
            //cout << "roi: " << roi << endl;
            //cv::Mat destinationROI = inputFrame( roi );
            //outputImage.copyTo( destinationROI );
     */
            
            
            circle(inputFrame, transformedFrame[0],10,Scalar(255,0,0),5,-1); // RED this one occasionally errors
            circle(inputFrame, transformedFrame[1],10,Scalar(255,255,0),5,-1); // YELLOW this one is flying everywhere
            circle(inputFrame, transformedFrame[2],10,Scalar(0,255,255),5,-1); // teal, this one is the origin point
            circle(inputFrame, transformedFrame[3],10,Scalar(0,255,0),5,-1); // this one flying everywhere
            circle(inputFrame, transformedFrame[4],10,Scalar(255,255,255),5,-1);
            circle(inputFrame, transformedFrame[5],10,Scalar(255,0,255),5,-1);
            circle(inputFrame, transformedFrame[6],10,Scalar(0,255,0),5,-1);
            circle(inputFrame, transformedFrame[7],10,Scalar(0,255,0),5,-1);

        }
        else
        {
            NSLog(@"not solved");
        }
        /*
        cv::Mat rotation, viewMatrix(4, 4, CV_64F);
        cv::Rodrigues(rvec, rotation);
        
        for(unsigned int row=0; row<3; ++row)
        {
            for(unsigned int col=0; col<3; ++col)
            {
                viewMatrix.at<double>(row, col) = rotation.at<double>(row, col);
            }
            viewMatrix.at<double>(row, 3) = tvec.at<double>(row, 0);
        }
        viewMatrix.at<double>(3, 3) = 1.0f;
        cv::Mat cvToGl = cv::Mat::zeros(4, 4, CV_64F);
        cvToGl.at<double>(0, 0) = 1.0f;
        cvToGl.at<double>(1, 1) = -1.0f; // Invert the y axis
        cvToGl.at<double>(2, 2) = -1.0f; // invert the z axis
        cvToGl.at<double>(3, 3) = 1.0f;
        viewMatrix = cvToGl * viewMatrix;
        cv::Mat glViewMatrix = cv::Mat::zeros(4, 4, CV_64F);
        cv::transpose(viewMatrix , glViewMatrix);
        //glMatrixMode(GL_MODELVIEW);
        //glLoadMatrixd(&glViewMatrix.at<double>(0, 0));
            */

        
    }
    //cout << "query frame RVEC: " << rvec << endl;
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
    NSLog(@"starting CVMAT RGB -> UIIMAGE");
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
    cv::Mat cvMat(rows, cols, CV_8UC4);
    CGImage *coreimage = image.CGImage;
    // (3) Create CG context and draw the image
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,
                                                    cols,
                                                    rows,
                                                    CGImageGetBitsPerComponent(coreimage),
                                                    CGImageGetBytesPerRow(coreimage),
                                                    CGImageGetColorSpace(coreimage),
                                                    CGImageGetBitmapInfo(coreimage));
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
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
