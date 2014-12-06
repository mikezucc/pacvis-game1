pacvis-game1
============

under development

This is an attempt to make an actually fun implementation of AR for mobile gaming. You can view the "mz-cubeDemo" branch to get a working snapshot of a cube displayed referencing the board's coord space.

#NOTE
This app uses Apple's iOS 8 new API for accessing the focus parameter of the AVCaptureDevice to try to minimize error during calibration and runtime of the Demo. It will only work on iOS 8, and probably with iphone 5s and above.

# To calibrate your phone
>> Use a a 6x9 checkerboard
>> Open the "Record Calibration images controller"
>> Get a focus distance of a little more than arms length from the checkerboard and then tap the "lock focus" button. once it turns green, you are ready to start capturing images. DO NOT reset the focus lock once you begin capturing a sequence of images for calibration.
>> collect at least 30 images using the "Record calibration images controller" (54 according to the OpenCV docs is a standard minimum, but who has time for that)
>> Return to the first view and run "Obtain Calibration Data" to get the parameters. Do NOT return the image recorder, as you will reset the focus lock mechanism, as represented by the "fL" field. Once the "POSE ESTIM8" button turns green, you can tap it to the run the Demo.
>> enjoy the novelty. if you go into my code you can see I am trying to work on a thresholding code to make an image appear as if it is sticking out of the chessboard. I have it working in my Python implementation but not here yet. Im going to sleep. peace.
