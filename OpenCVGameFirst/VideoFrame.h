//
//  VideoFrame.h
//  OpenCVTutorial
//
//  Created by Paul Sholtz on 12/14/13.
//  Copyright (c) 2013 Razeware LLC. All rights reserved.
//

#ifndef OpenCVTutorial_VideoFrame_h
#define OpenCVTutorial_VideoFrame_h

//#include <cstddef>

struct VideoFrame
{
    size_t width;
    size_t height;
    size_t stride;
    
    unsigned char * data;
};

#endif
