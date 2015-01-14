//
//  ViewController.m
//  SpriteKit2.5D_Example
//
//  Created by Sam  keene on 31/12/13.
//  Copyright (c) 2013 Sam  keene. All rights reserved.
//

#import "SwaggyViewController.h"
#import "MyScene.h"

@interface SwaggyViewController ()
@property (nonatomic, weak) IBOutlet SKView *frontView;
@property (nonatomic, weak) IBOutlet SKView *backView;
@property (nonatomic, assign) CGFloat rotAngle;
@end

@implementation SwaggyViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.rotAngle = 10;
    
    // Configure the back view.
    SKView * skViewBack = self.backView;
    skViewBack.showsFPS = YES;
    skViewBack.showsNodeCount = YES;
    
    // Create and configure the back scene.
    SKScene * sceneBack = [MyScene sceneWithSize:skViewBack.bounds.size];
    sceneBack.scaleMode = SKSceneScaleModeAspectFill;
    
    // Present the back scene.
    [skViewBack presentScene:sceneBack];
    
    
    // Configure the front view.
    SKView * skViewFront = self.frontView;
    skViewFront.showsFPS = YES;
    skViewFront.showsNodeCount = YES;
    
    // Create and configure the front scene.
    SKScene * sceneFront = [MyScene sceneWithSize:skViewFront.bounds.size];
    sceneFront.scaleMode = SKSceneScaleModeAspectFill;
   
    // Present the front scene.
    [skViewFront presentScene:sceneFront];
    
    //schedule a rotation method to animate the movement
    [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(rotateFrontViewOnXAxis) userInfo:nil repeats:YES];
}


- (void)rotateFrontViewOnXAxis
{
    self.rotAngle -= 10;
    
    float angle = (M_PI / 180.0f) * self.rotAngle/10;
    
    CATransform3D transform3DRotation = CATransform3DMakeRotation(angle, 1.0, 0.0, 0.0);
    
    self.frontView.layer.transform = transform3DRotation;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

@end
