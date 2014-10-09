//
//  DOJOPreviewView.h
//  dojo
//
//  Created by Michael Zuccarino on 7/27/14.
//  Copyright (c) 2014 Michael Zuccarino. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AVCaptureSession;

@interface DOJOPreviewView : UIView

@property (nonatomic) AVCaptureSession *session;

@end
