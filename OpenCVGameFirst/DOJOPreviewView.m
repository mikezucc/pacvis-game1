//
//  DOJOPreviewView.m
//  dojo
//
//  Created by Michael Zuccarino on 7/27/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import "DOJOPreviewView.h"
#import <AVFoundation/AVFoundation.h>

@implementation DOJOPreviewView

+ (Class)layerClass
{
	return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session
{
	return [(AVCaptureVideoPreviewLayer *)[self layer] session];
}

- (void)setSession:(AVCaptureSession *)session
{
	[(AVCaptureVideoPreviewLayer *)[self layer] setSession:session];
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
