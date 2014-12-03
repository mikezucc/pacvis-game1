//
//  DOJOCameraViewController.m
//  dojo
//
//  Created by Kian Anderson on 7/13/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import "DOJOCameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "DOJOPreviewView.h"
#import "ObtainCalibFramesViewController.h"

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * RecordingContext = &RecordingContext;
static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface DOJOCameraViewController () <AVCaptureFileOutputRecordingDelegate>

// For use in the storyboards.
@property (nonatomic, weak) IBOutlet DOJOPreviewView *previewView;
@property (nonatomic, weak) IBOutlet UIButton *recordButton;
@property (nonatomic, weak) IBOutlet UIButton *cameraButton;
@property (nonatomic, weak) IBOutlet UIButton *stillButton;

- (IBAction)toggleMovieRecording:(id)sender;
- (IBAction)changeCamera:(id)sender;
- (IBAction)snapStillImage:(id)sender;
- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

// Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;

@property (nonatomic) ObtainCalibFramesViewController *obtainController;
@property (nonatomic) NSData *imageData;
@property (nonatomic) NSString *mediaType;
@property (nonatomic) UIImage *originalImage;
@property (nonatomic) NSData *videoData;

@property (nonatomic) NSString *viewDidLoadAlready;
@property BOOL didRun;

@end

@implementation DOJOCameraViewController

@synthesize cameraButton,recordButton,stillButton, obtainController, imageData, mediaType, originalImage, videoData, didRun, viewDidLoadAlready;


//@synthesize session;

/*
 - (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
 {
 self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
 if (self) {
 // Custom initialization
 }
 return self;
 }
 */

- (BOOL)isSessionRunningAndDeviceAuthorized
{
    return [[self session] isRunning] && [self isDeviceAuthorized];
}

+ (NSSet *)keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized
{
    return [NSSet setWithObjects:@"session.running", @"deviceAuthorized", nil];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"VIEW LOADED");
    didRun = NO;
    // Create the AVCaptureSession
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset640x480;
    [self setSession:session];
    
    // Setup the preview view
    [[self previewView] setSession:session];
    
    // Check for device authorization
    [self checkDeviceAuthorizationStatus];
    
    //set aspect ratio
    //[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [(AVCaptureVideoPreviewLayer *)[[self previewView] layer] setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    // In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
    // Why not do all of this on the main queue?
    // -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue so that the main queue isn't blocked (which keeps the UI responsive).
    
    dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    [self setSessionQueue:sessionQueue];
    
    dispatch_async(sessionQueue, ^{
        [self setBackgroundRecordingID:UIBackgroundTaskInvalid];
        
        NSError *error = nil;
        
        AVCaptureDevice *videoDevice = [DOJOCameraViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        
        if (error)
        {
            NSLog(@"%@", error);
        }
        
        if ([session canAddInput:videoDeviceInput])
        {
            [session addInput:videoDeviceInput];
            [self setVideoDeviceInput:videoDeviceInput];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                // Why are we dispatching this to the main queue?
                // Because AVCaptureVideoPreviewLayer is the backing layer for AVCamPreviewView and UIView can only be manipulated on main thread.
                // Note: As an exception to the above rule, it is not necessary to serialize video orientation changes on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
                
                [[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
            });
        }
        
        AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
        AVCaptureDeviceInput *audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
        
        if (error)
        {
            NSLog(@"%@", error);
        }
        
        if ([session canAddInput:audioDeviceInput])
        {
            [session addInput:audioDeviceInput];
        }
        
        AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        if ([session canAddOutput:movieFileOutput])
        {
            [session addOutput:movieFileOutput];
            AVCaptureConnection *connection = [movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            if ([connection isVideoStabilizationSupported])
                [connection setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeAuto];
            [self setMovieFileOutput:movieFileOutput];
        }
        
        AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ([session canAddOutput:stillImageOutput])
        {
            [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
            [session addOutput:stillImageOutput];
            [self setStillImageOutput:stillImageOutput];
        }
    });
    
}

- (void)viewWillAppear:(BOOL)animated
{
    /*
     @try {
     dispatch_async([self sessionQueue], ^{
     [[self session] stopRunning];
     
     [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
     [[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
     
     [self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
     [self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
     [self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
     });
     }
     @catch (NSException *exception) {
     NSLog(@"thread already killed");
     }
     @finally {
     NSLog(@"completed view will appear sanitize");
     }
     */
    NSLog(@"view will appear");
    if (!self.didRun)
    {
        NSLog(@"reinitializing the streams");
        dispatch_async([self sessionQueue], ^{
            [self addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
            [self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
            [self addObserver:self forKeyPath:@"movieFileOutput.recording" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:RecordingContext];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
            
            __weak DOJOCameraViewController *weakSelf = self;
            [self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:[self session] queue:nil usingBlock:^(NSNotification *note) {
                DOJOCameraViewController *strongSelf = weakSelf;
                dispatch_async([strongSelf sessionQueue], ^{
                    // Manually restarting the session since it must have been stopped due to an error.
                    [[strongSelf session] startRunning];
                    [[strongSelf recordButton] setTitle:NSLocalizedString(@"Record", @"Recording button record title") forState:UIControlStateNormal];
                });
            }]];
            [[self session] startRunning];
        });
        float adjustHeight;
        adjustHeight = 120;
        // [cameraButton setFrame:CGRectMake(cameraButton.frame.origin.x, self.view.frame.size.height-adjustHeight, cameraButton.frame.size.width, 57)];
        [stillButton setFrame:CGRectMake(stillButton.frame.origin.x, self.view.frame.size.height-adjustHeight, 105, 53)];
        [recordButton setFrame:CGRectMake(recordButton.frame.origin.x, self.view.frame.size.height-adjustHeight, 105, 53)];
    }
    else
    {
        self.didRun = YES;
    }
    
}

-(void)viewDidAppear:(BOOL)animated
{
    NSLog(@"view did load");
    if ([viewDidLoadAlready isEqualToString:@"loaded"])
    {
        //        [self removeFromParentViewController];
    }
    else
    {
        viewDidLoadAlready = @"loaded";
        
    }
}


- (void)viewDidDisappear:(BOOL)animated
{
    /*
     dispatch_async([self sessionQueue], ^{
     [[self session] stopRunning];
     
     [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
     [[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
     
     [self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
     [self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
     [self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
     });
     */
}

-(void)viewWillDisappear:(BOOL)animated
{
    /*
     @try {
     dispatch_async([self sessionQueue], ^{
     [[self session] stopRunning];
     
     // [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
     //  [[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
     
     [self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
     [self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
     [self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
     });
     }
     @catch (NSException *exception) {
     NSLog(@"thread already killed");
     }
     @finally {
     NSLog(@"completed view will appear sanitize");
     }
     dispatch_async([self sessionQueue], ^{
     [[self session] stopRunning];
     
     for(AVCaptureInput *input in [self session].inputs) {
     [[self session] removeInput:input];
     }
     
     for(AVCaptureOutput *output in [self session].outputs) {
     [[self session] removeOutput:output];
     }
     
     [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
     [[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
     
     [self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
     [self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
     [self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
     });
     */
}

-(IBAction)removeYoself:(id)sender
{
    //[self performSegueWithIdentifier:@"backToHome" sender:self];
    //[self dealloc];
    dispatch_async([self sessionQueue], ^{
        [[self session] stopRunning];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self name:
         AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
        [[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        
        [self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
        [self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
        [self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
    });
    
    [self dismissViewControllerAnimated:YES completion:^{NSLog(@"yar");}];
}


- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate
{
    // Disable autorotation of the interface when recording is in progress.
    return ![self lockInterfaceRotation];
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)toInterfaceOrientation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == CapturingStillImageContext)
    {
        BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
        
        if (isCapturingStillImage)
        {
            [self runStillImageCaptureAnimation];
        }
    }
    else if (context == RecordingContext)
    {
        BOOL isRecording = [change[NSKeyValueChangeNewKey] boolValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isRecording)
            {
                [[self cameraButton] setEnabled:NO];
                [[self stillButton] setEnabled:NO];
                //[[self recordButton] setTitle:NSLocalizedString(@"Stop", @"Recording button stop title") forState:UIControlStateNormal];
                [[self recordButton] setBackgroundImage:[UIImage imageNamed:@"vidbuttonpressed2x.png"] forState:UIControlStateNormal];
                [[self recordButton] setEnabled:YES];
            }
            else
            {
                [[self cameraButton] setEnabled:YES];
                [[self stillButton] setEnabled:YES];
                //	[[self recordButton] setTitle:NSLocalizedString(@"Record", @"Recording button record title") forState:UIControlStateNormal];
                [[self recordButton] setBackgroundImage:[UIImage imageNamed:@"vidbutton2x.png"] forState:UIControlStateNormal];
                [[self recordButton] setEnabled:YES];
            }
        });
    }
    else if (context == SessionRunningAndDeviceAuthorizedContext)
    {
        BOOL isRunning = [change[NSKeyValueChangeNewKey] boolValue];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (isRunning)
            {
                [[self cameraButton] setEnabled:YES];
                [[self recordButton] setEnabled:YES];
                [[self stillButton] setEnabled:YES];
            }
            else
            {
                [[self cameraButton] setEnabled:NO];
                [[self recordButton] setEnabled:NO];
                [[self stillButton] setEnabled:NO];
            }
        });
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark Actions

- (IBAction)toggleMovieRecording:(id)sender
{
    NSLog(@"recording toggled");
    [[self recordButton] setEnabled:NO];
    
    dispatch_async([self sessionQueue], ^{
        if (![[self movieFileOutput] isRecording])
        {
            [self setLockInterfaceRotation:YES];
            
            if ([[UIDevice currentDevice] isMultitaskingSupported])
            {
                // Setup background task. This is needed because the captureOutput:didFinishRecordingToOutputFileAtURL: callback is not received until AVCam returns to the foreground unless you request background execution time. This also ensures that there will be time to write the file to the assets library when AVCam is backgrounded. To conclude this background execution, -endBackgroundTask is called in -recorder:recordingDidFinishToOutputFileURL:error: after the recorded file has been saved.
                [self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil]];
            }
            
            // Update the orientation on the movie file output video connection before starting recording.
            [[[self movieFileOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
            
            // Turning OFF flash for video recording
            [DOJOCameraViewController setFlashMode:AVCaptureFlashModeOff forDevice:[[self videoDeviceInput] device]];
            
            // Start recording to a temporary file.
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"movie" stringByAppendingPathExtension:@"mov"]];
            [[self movieFileOutput] startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
        }
        else
        {
            [[self movieFileOutput] stopRecording];
        }
    });
}

- (IBAction)changeCamera:(id)sender
{
    [[self cameraButton] setEnabled:NO];
    [[self recordButton] setEnabled:NO];
    [[self stillButton] setEnabled:NO];
    
    dispatch_async([self sessionQueue], ^{
        AVCaptureDevice *currentVideoDevice = [[self videoDeviceInput] device];
        AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionUnspecified;
        AVCaptureDevicePosition currentPosition = [currentVideoDevice position];
        
        switch (currentPosition)
        {
            case AVCaptureDevicePositionUnspecified:
                preferredPosition = AVCaptureDevicePositionBack;
                break;
            case AVCaptureDevicePositionBack:
                preferredPosition = AVCaptureDevicePositionFront;
                break;
            case AVCaptureDevicePositionFront:
                preferredPosition = AVCaptureDevicePositionBack;
                break;
        }
        
        AVCaptureDevice *videoDevice = [DOJOCameraViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
        
        [[self session] beginConfiguration];
        
        [[self session] removeInput:[self videoDeviceInput]];
        if ([[self session] canAddInput:videoDeviceInput])
        {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];
            
            [DOJOCameraViewController setFlashMode:AVCaptureFlashModeAuto forDevice:videoDevice];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:videoDevice];
            
            [[self session] addInput:videoDeviceInput];
            [self setVideoDeviceInput:videoDeviceInput];
        }
        else
        {
            [[self session] addInput:[self videoDeviceInput]];
        }
        
        [[self session] commitConfiguration];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self cameraButton] setEnabled:YES];
            [[self recordButton] setEnabled:YES];
            [[self stillButton] setEnabled:YES];
        });
    });
}

- (IBAction)snapStillImage:(id)sender
{
    dispatch_async([self sessionQueue], ^{
        // Update the orientation on the still image output video connection before capturing.
        [[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] videoOrientation]];
        
        // Flash set to Auto for Still Capture
        [DOJOCameraViewController setFlashMode:AVCaptureFlashModeAuto forDevice:[[self videoDeviceInput] device]];
        
        // Capture a still image.
        [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            
            if (imageDataSampleBuffer)
            {
                imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                int imageSize = (unsigned)imageData.length;
                NSLog(@"SIZE OF IMAGE: %i ", imageSize);
                originalImage = [[UIImage alloc] initWithData:imageData];
                //imageData = UIImageJPEGRepresentation(originalImage, 0.6);
                mediaType = @"image";
                
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
                NSString *documentsDirectory = [paths objectAtIndex:0];
                NSURL *selectedPath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:@"captured.jpeg"]];
                [imageData writeToURL:selectedPath atomically:YES];
                selectedPath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:@"mediaType.plist"]];
                NSDictionary *mediaTypeDict = [[NSDictionary alloc] initWithObjects:@[mediaType] forKeys:@[@"mediaType"]];
                [mediaTypeDict writeToURL:selectedPath atomically:YES];
                
                
                //[[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
                [self.storyboard instantiateViewControllerWithIdentifier:@"obtainController"];
                [self performSegueWithIdentifier:@"toVerifyController" sender:self];
            }
        }];
    });
}

- (IBAction)focusAndExposeTap:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint devicePoint = [(AVCaptureVideoPreviewLayer *)[[self previewView] layer] captureDevicePointOfInterestForPoint:[gestureRecognizer locationInView:[gestureRecognizer view]]];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:devicePoint monitorSubjectAreaChange:YES];
}

- (void)subjectAreaDidChange:(NSNotification *)notification
{
    CGPoint devicePoint = CGPointMake(.5, .5);
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

#pragma mark File Output Delegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    NSLog(@"did finish check");
    if (error)
        NSLog(@"%@", error);
    
    [self setLockInterfaceRotation:NO];
    
    // Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
    UIBackgroundTaskIdentifier backgroundRecordingID = [self backgroundRecordingID];
    [self setBackgroundRecordingID:UIBackgroundTaskInvalid];
    
    [[[ALAssetsLibrary alloc] init] writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error)
            NSLog(@"%@", error);
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSURL *selectedPath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:@"recorded.mov"]];
        [[NSFileManager defaultManager] copyItemAtURL:outputFileURL toURL:selectedPath error:&error];
        videoData = [[NSData alloc] initWithContentsOfURL:outputFileURL];
        [videoData writeToURL:selectedPath atomically:YES];
        mediaType = @"movie";
        
        selectedPath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:@"mediaType.plist"]];
        NSDictionary *mediaTypeDict = [[NSDictionary alloc] initWithObjects:@[mediaType] forKeys:@[@"mediaType"]];
        [mediaTypeDict writeToURL:selectedPath atomically:YES];
        
        
        [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
        
        if (backgroundRecordingID != UIBackgroundTaskInvalid)
        {
            [[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
        }
        [self.storyboard instantiateViewControllerWithIdentifier:@"obtainController"];
        [self performSegueWithIdentifier:@"toVerifyController" sender:self];
    }];
    
}

#pragma mark Device Configuration

- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange
{
    dispatch_async([self sessionQueue], ^{
        AVCaptureDevice *device = [[self videoDeviceInput] device];
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
            {
                [device setFocusMode:focusMode];
                [device setFocusPointOfInterest:point];
            }
            if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
            {
                [device setExposureMode:exposureMode];
                [device setExposurePointOfInterest:point];
            }
            [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    });
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
    if ([device hasFlash] && [device isFlashModeSupported:flashMode])
    {
        NSError *error = nil;
        if ([device lockForConfiguration:&error])
        {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        }
        else
        {
            NSLog(@"%@", error);
        }
    }
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
    AVCaptureDevice *captureDevice = [devices firstObject];
    
    for (AVCaptureDevice *device in devices)
    {
        if ([device position] == position)
        {
            captureDevice = device;
            break;
        }
    }
    
    return captureDevice;
}

#pragma mark UI

- (void)runStillImageCaptureAnimation
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[[self previewView] layer] setOpacity:0.0];
        [UIView animateWithDuration:.25 animations:^{
            [[[self previewView] layer] setOpacity:1.0];
        }];
    });
}

- (void)checkDeviceAuthorizationStatus
{
    NSLog(@"authorization check");
    NSString *mediaType = AVMediaTypeVideo;
    
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if (granted)
        {
            //Granted access to mediaType
            [self setDeviceAuthorized:YES];
        }
        else
        {
            //Not granted access to mediaType
            dispatch_async(dispatch_get_main_queue(), ^{
                [[[UIAlertView alloc] initWithTitle:@"AVCam!"
                                            message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
                                           delegate:self
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil] show];
                [self setDeviceAuthorized:NO];
            });
        }
    }];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"toVerifyController"])
    {
        // Get reference to the destination view controller
        ObtainCalibFramesViewController *vc = [segue destinationViewController];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSURL *selectedPath = [[NSURL alloc] initFileURLWithPath:[documentsDirectory stringByAppendingPathComponent:@"captured.jpeg"]];
        
        vc.capturedImage = [UIImage imageWithContentsOfFile:selectedPath.path];
        
        NSLog(@"applying properties");
        
        dispatch_async([self sessionQueue], ^{
            [[self session] stopRunning];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self name:
             AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
            [[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            
            [self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
            [self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
            [self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
        });
    }
}




/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end