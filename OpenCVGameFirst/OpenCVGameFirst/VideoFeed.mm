//
//  VideoFeed.m
//  OpenCVGameFirst
//
//  Created by Michael Zuccarino on 10/7/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import "VideoFeed.h"
using namespace cv;

cv::Mat *gray_image;

@interface VideoFeed () <AVCaptureVideoDataOutputSampleBufferDelegate>

@end


@implementation VideoFeed

#pragma mark -
#pragma mark Object Lifecycle
- (id)init {
    self = [super init];
    if ( self ) {
        gray_image = new cv::Mat(480, 640, CV_8UC1);
        AVCaptureSession * captureSession = [[AVCaptureSession alloc] init];
        if ( [captureSession canSetSessionPreset:AVCaptureSessionPreset640x480] ) {
            [captureSession setSessionPreset:AVCaptureSessionPreset640x480];
            NSLog(@"Capturing video at 640x480");
        } else {
            NSLog(@"Could not configure AVCaptureSession video input");
        }
        _captureSession = captureSession;
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
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t stride = CVPixelBufferGetBytesPerRow(imageBuffer);
    //struct VideoFrame frame = {width, height, stride, baseAddress};
    cv::Mat image = cv::Mat((int)height,(int)width,CV_8UC4,baseAddress);
    
    // (4) Dispatch VideoFrame to VideoSource delegate
    
    [self processImage:image];
    
    [self.delegate frameReady:image];
    
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
    
    //unnecessary calculation, since image is already converted to gray scale
    cv::cvtColor(image, *gray_image, COLOR_BGRA2GRAY);
    if (found) {
        // improves accuracy to attempted subpixel (increases memory 10x)
        //cv::cornerSubPix(*gray_image, corners, cv::Size(11, 11), cv::Size(-1, -1), cv::TermCriteria(cv::TermCriteria::EPS + cv::TermCriteria::MAX_ITER, 30, 0.1));
        
        cv::drawChessboardCorners(image, boardSize, corners, found);
    }
    
    //NSLog(@"imagepoints is 1:%f 2:%f",corners(1),corners(2));//_imagePoints->push_back(corners);
}
#endif

@end
