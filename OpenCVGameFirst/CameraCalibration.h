//
//  CameraCalibration.h
//  OpenCVTutorial
//
//  Created by Paul Sholtz on 12/18/13.
//  Copyright (c) 2013 Razeware LLC. All rights reserved.
//

#ifndef OpenCVTutorial_CameraCalibration_h
#define OpenCVTutorial_CameraCalibration_h

struct CameraCalibration
{
    float xDistortion;
    float yDistortion;
    float xCorrection;
    float yCorrection;
};

#endif
