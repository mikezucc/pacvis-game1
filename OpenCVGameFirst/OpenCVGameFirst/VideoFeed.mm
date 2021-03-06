//
//  VideoFeed.m
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/7/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import "VideoFeed.h"
using namespace cv;
using namespace std;

cv::Mat testfaceMat;

struct CvPoint2D32f {
    double x;
    double y;
};

//TermCriteria crit = TermCriteria(cv::TermCriteria::EPS + cv::TermCriteria::MAX_ITER, 30, 0.1);

@interface VideoFeed () <AVCaptureVideoDataOutputSampleBufferDelegate>

@end


@implementation VideoFeed

@synthesize doge;

#pragma mark -
#pragma mark Object Lifecycle
- (id)init {
    self = [super init];
    if ( self ) {
        //gray_image = new cv::Mat(480, 640, CV_8UC1);
        AVCaptureSession * captureSession = [[AVCaptureSession alloc] init];
        if ( [captureSession canSetSessionPreset:AVCaptureSessionPreset640x480] ) {
            [captureSession setSessionPreset:AVCaptureSessionPreset640x480];
            NSLog(@"Capturing video at 640x480");
        } else {
            NSLog(@"Could not configure AVCaptureSession video input");
        }
        _captureSession = captureSession;
        doge = [UIImage imageNamed:@"testface.jpg"];
        //NSLog(@"testface is %@",doge);
        //testfaceMat = [self toCVMatFromRGB:doge];
        NSLog(@"post mat conversion");
    }
    return self;
}

- (AVCaptureDevice*)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray * devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice * device in devices ) {
        if ( [device position] == position ) {
            return device;
        }
    }
    return nil;
}

- (BOOL)startWithDevicePosition:(AVCaptureDevicePosition)devicePosition {
    // (1) Find camera device at the specific position
    AVCaptureDevice * videoDevice = [self cameraWithPosition:devicePosition];
    [videoDevice lockForConfiguration:nil];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSURL *selectedPath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:@"focusData.plist"]];
    NSMutableDictionary *focusDict = [[NSMutableDictionary alloc] initWithContentsOfURL:selectedPath];
    float val = [(NSNumber *)[focusDict valueForKey:@"focusLock"] floatValue];
    [videoDevice setFocusModeLockedWithLensPosition:val completionHandler:nil];
    [videoDevice setExposureMode:AVCaptureExposureModeLocked];
    videoDevice.activeVideoMinFrameDuration = CMTimeMake(1, 20);
    if ( !videoDevice ) {
        NSLog(@"Could not initialize camera at position %d", devicePosition);
        return FALSE;
    }
    
    // (2) Obtain input port for camera device
    NSError * error;
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if ( !error ) {
        [self setDeviceInput:videoInput];
    } else {
        NSLog(@"Could not open input port for device %@ (%@)", videoDevice, [error localizedDescription]);
        return FALSE;
    }
    
    // (3) Configure input port for captureSession
    if ( [self.captureSession canAddInput:videoInput] ) {
        [self.captureSession addInput:videoInput];
    } else {
        NSLog(@"Could not add input port to capture session %@", self.captureSession);
        return FALSE;
    }
    
    // (4) Configure output port for captureSession
    [self addVideoDataOutput];
    
    AVCaptureConnection *videoConnection = nil;
    for ( AVCaptureOutput *output in [[self captureSession] outputs])
    {
        for ( AVCaptureConnection *connection in [output connections] )
        {
            [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        }
    }
    
    // (5) Start captureSession running
    [self.captureSession startRunning];
    
    return TRUE;
}

- (void) addVideoDataOutput {
    // (1) Instantiate a new video data output object
    AVCaptureVideoDataOutput * captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    AVCaptureConnection *capConnect = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
    [capConnect setVideoOrientation: AVCaptureVideoOrientationPortrait];
    
    // (2) The sample buffer delegate requires a serial dispatch queue
    dispatch_queue_t queue;
    queue = dispatch_queue_create("com.videofeed", DISPATCH_QUEUE_SERIAL);
    [captureOutput setSampleBufferDelegate:self queue:queue];
    //dispatch_release(queue); deprecated ios6+
    
    // (3) Define the pixel format for the video data output
    NSString * key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber * value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary * settings = @{key:value};
    [captureOutput setVideoSettings:settings];
    
    // (4) Configure the output port on the captureSession property
    [self.captureSession addOutput:captureOutput];
}

#pragma mark -
#pragma mark Sample Buffer Delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // (1) Convert CMSampleBufferRef to CVImageBufferRef
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // (2) Lock pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    // (3) Construct VideoFrame struct
    uint8_t *baseAddress = (uint8_t*)CVPixelBufferGetBaseAddress(imageBuffer);
    //size_t width = CVPixelBufferGetWidth(imageBuffer);
    //size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t stride = CVPixelBufferGetBytesPerRow(imageBuffer);
    cout << "stride is: " << stride << endl;
    //struct VideoFrame frame = {width, height, stride, baseAddress};
    //cv::Mat image = cv::Mat((int)height,(int)width,CV_8UC4,baseAddress);
    
    // (4) Dispatch VideoFrame to VideoSource delegate
    
    //[self processImage:image];
    NSLog(@"frame ready");
    [self.delegate frameReady:baseAddress];
    
    // (5) Unlock pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

#ifdef __cplusplus
-(void)processImage:(cv::Mat &)image
{
    std::vector<cv::Point2f> corners;
    cv::Size _imageSize(image.size().width, image.size().height);
    cv::Size boardSize(3,3);
    bool found = cv::findChessboardCorners(image, boardSize, corners);
    
    cv::Size ffaceSize(testfaceMat.size().width, testfaceMat.size().height);
    
    //unnecessary calculation, since image is already converted to gray scale
    cv::Mat warp_matrix(3,3,CV_32FC3);
    //cv::cvtColor(image, *gray_image, COLOR_BGRA2GRAY);
    if (found) {
        // improves accuracy to attempted subpixel (increases memory 10x)
        //cv::cornerSubPix(*gray_image, corners, cv::Size(11, 11), cv::Size(-1, -1), cv::TermCriteria(cv::TermCriteria::EPS + cv::TermCriteria::MAX_ITER, 30, 0.1));
        
        cv::drawChessboardCorners(image, boardSize, corners, found);
        cv::Point2f p[4];
        cv::Point2f q[4];
        cv::Point2f e[4];
        
        float m = 100;//pixel offset
        float k = 1; //size multiplier
        
        e[0] = Point2f((0*k)+m,(0*k)+m);
        e[1] = Point2f((100*k)+m,(0*k)+m);
        e[2] = Point2f((100*k)+m,(100*k)+m);
        e[3] = Point2f((0*k)+m,(100*k)+m);
        
        p[0] = Point2f(corners[0].x,corners[0].y);
        p[1] = Point2f(corners[2].x,corners[2].y);
        p[2] = Point2f(corners[8].x,corners[8].y);
        p[3] = Point2f(corners[6].x,corners[6].y);
        
        //cv::Point2f simOrigin;
        //simOrigin = Point2f(corners[4].x,corners[4].y);
        
        
        //find cross product
        //first use get v1 and v2
        cv::Point2f v1 = Point2f(p[1].x-p[0].x,p[1].y-p[0].y);
        cv::Point2f v2 = Point2f(p[2].x-p[0].x,p[2].y-p[0].y);
        
        cv::Point2f orthZ;
        orthZ = Point2f(v1.x * v2.y, v1.y * v2.x);
        //NSLog(@"\nv1: %f\nv1: %f",v1.x,v1.y);
        //Mat lambda( 2, 4, CV_32FC4 );
        //lambda = Mat::zeros( image.rows, image.cols, CV_32FC4);
        warp_matrix = cv::getPerspectiveTransform(p,e);
        //NSLog(@"orthZ points are %f, %f",e[1].x,e[1].y);
        int thickness = 2;
        int lineType = 8;
        
        //cv::Mat ffaceCopy;
        //testfaceMat.copyTo(ffaceCopy);
        //cv::warpPerspective(image, image, warp_matrix, ffaceSize);
        //cv::perspectiveTransform(image, image, warp_matrix);
       // cv::getaf
        
        line( image, p[0], p[1], Scalar( 255, 255, 0 ), thickness );
        line( image, p[0], p[3], Scalar( 255, 0, 0 ), thickness );
        line( image, p[1], p[2], Scalar( 0, 255, 0 ), thickness );
        line( image, p[2], p[3], Scalar( 0, 255, 255 ), thickness );
        //line( image, e[0], e[0], Scalar( 0, 0, 255), thickness );
        
        //place the dog over
        //cv::Size ffaceSize(ffaceCopy.size().width, ffaceCopy.size().height);
        NSLog(@"ffacesizeb4 run are %d, %d", testfaceMat.size().height, testfaceMat.size().width);
        cv::Rect roi( p[0], ffaceSize);
        cv::Mat destinationROI = image( roi );
        testfaceMat.copyTo( destinationROI );
        
        UIImage *img = [self fromCVMatRGB:testfaceMat];
        NSLog(@"waithere");
    }
    
    //NSLog(@"imagepoints is 1:%f 2:%f",corners(1),corners(2));//_imagePoints->push_back(corners);
}
#endif

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
@end
