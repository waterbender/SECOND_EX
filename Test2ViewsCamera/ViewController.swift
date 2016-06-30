//
//  ViewController.swift
//  Test2ViewsCamera
//
//  Created by Yevgenii Pasko on 30.06.16.
//  Copyright © 2016 Yevgenii Pasko. All rights reserved.
//

import UIKit
import AVFoundation
import GLKit


class GLKViewWithBounds: GLKView {
    var viewBounds : CGRect?
}


class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate {

    var ciContext: CIContext = CIContext()
    var eaglContext: EAGLContext?
    var captureSession: AVCaptureSession?
    var captureSessionQueue : dispatch_queue_t?
    var currentVideoDimensions: CMVideoDimensions?
    var feedViews: [GLKViewWithBounds]?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        self.edgesForExtendedLayout = .None
        self.view.backgroundColor = UIColor.blackColor()
        feedViews = []
        
        if (AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count > 0) {
            // create the dispatch queue for handling capture session delegate method calls
            self.captureSessionQueue = dispatch_queue_create("capture_session_queue", nil);
            
            
            self.setupContexts()
            self.setupSession()
            self.setupFeedViews()
        }
    
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func setupFeedViews() {
        
        let feedViewHeight: CGFloat = self.view.bounds.height

        let feedView : GLKViewWithBounds = self.setupFeedViewWithFrame(CGRectMake(0.0, feedViewHeight*CGFloat(0), 1000, 1000))
        
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight] // for supporting device rotation

        let feedAboveView = self.setupFeedViewWithFrame(CGRectMake(self.view.bounds.size.width/2-100, 100, 200, 200))
        
        view.addSubview(feedView)
        view.addSubview(blurEffectView)
        view.addSubview(feedAboveView)
        
        self.feedViews?.append(feedView)
        self.feedViews?.append(feedAboveView)

        
    }

    
    func setupFeedViewWithFrame(frame: CGRect) -> GLKViewWithBounds {
        
        let feedView = GLKViewWithBounds(frame: frame, context: self.eaglContext!)
        feedView.enableSetNeedsDisplay = false
        
        
        feedView.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2));
        feedView.frame = frame;
        
        feedView.bindDrawable()
        
        feedView.viewBounds = CGRectMake(0.0, 0.0, CGFloat(feedView.drawableWidth), CGFloat(feedView.drawableHeight));
        
        
        dispatch_async(dispatch_get_main_queue()) {
            let transform : CGAffineTransform  = CGAffineTransformMakeRotation(CGFloat(M_PI_2));
            
            feedView.transform = transform;
            feedView.frame = frame;
    
        }
 
        return feedView
    }
    
    func setupContexts() {
        
        // setup the GLKView for video/image preview
        self.eaglContext =  EAGLContext.init(API: .OpenGLES2)

        // create the CIContext instance, note that this must be done after _videoPreviewView is properly set up
        self.ciContext = CIContext.init(EAGLContext: self.eaglContext!, options: [kCIContextWorkingColorSpace:CGColorSpaceCreateDeviceRGB()! ])

    }

    func setupSession() {
        if (self.captureSession != nil) {
            return; }
        
        dispatch_async(self.captureSessionQueue!) {

            let videoDevices :Array = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
  
            var _videoDevice: AVCaptureDevice?
            
            if (_videoDevice == nil) {
                _videoDevice = videoDevices[0] as? AVCaptureDevice
            }
            
            
            var videoDeviceInput: AVCaptureDeviceInput? = nil
            do {
                videoDeviceInput = try AVCaptureDeviceInput.init(device: _videoDevice)
              
                if (videoDeviceInput == nil)
                {
                    self._showAlertViewWithMessage("Unable to obtain video device input, error: %@", title: "Some error 1")

                    return;
                }
                
            } catch {
                
            }

            // obtain the preset and validate the preset
            let preset : String = AVCaptureSessionPresetMedium;
            
            if (_videoDevice?.supportsAVCaptureSessionPreset(preset) == nil)
            {
                let string = "Capture session preset not supported by video device:  /(preset)"
                self._showAlertViewWithMessage(string)

                return;
            }
            
            // CoreImage wants BGRA pixel format
            
            let outputSettings =  NSDictionary(object: Int(kCVPixelFormatType_32BGRA), forKey: kCVPixelBufferPixelFormatTypeKey as String) as [NSObject : AnyObject]

            // create the capture session
            self.captureSession = AVCaptureSession()
            self.captureSession!.sessionPreset = preset;
            

            // create and configure video data output
            
            let videoDataOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.videoSettings = outputSettings;
            videoDataOutput.setSampleBufferDelegate(self, queue: self.captureSessionQueue)
            
            // begin configure capture session
            self.captureSession?.beginConfiguration()

            if ((self.captureSession?.canAddOutput(videoDataOutput)) == nil)
            {
                let string = "Cannot add video data output"
                self._showAlertViewWithMessage(string)
                self.captureSession = nil

                return;
            }
            
            // connect the video device input and video data and still image outputs
            self.captureSession?.addInput(videoDeviceInput)
            self.captureSession?.addOutput(videoDataOutput)

            self.captureSession?.commitConfiguration()
            self.captureSession?.startRunning()
   
        }
        
    }

    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        let formatDesc :CMFormatDescriptionRef  = CMSampleBufferGetFormatDescription(sampleBuffer)!;
        self.currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
        
        let imageBuffer: CVImageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer)!;
        let sourceImage: CIImage = CIImage.init(CVImageBuffer:imageBuffer, options: nil)
    
        let sourceExtent : CGRect = sourceImage.extent
        
        let sourceAspect : CGFloat  = sourceExtent.size.width / sourceExtent.size.height;
        
        
        for  somveView in self.feedViews! {
            
            let feedView : GLKViewWithBounds = somveView 
            
            let previewAspect: CGFloat  = feedView.viewBounds!.size.width  / feedView.viewBounds!.size.height;
            
            // we want to maintain the aspect radio of the screen size, so we clip the video image
            var drawRect :CGRect  = sourceExtent;
            if (sourceAspect > previewAspect) {
                // use full height of the video image, and center crop the width
                drawRect.origin.x += (drawRect.size.width - drawRect.size.height * previewAspect) / 2.0;
                drawRect.size.width = drawRect.size.height * previewAspect;
            } else {
                // use full width of the video image, and center crop the height
                drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspect) / 2.0;
                drawRect.size.height = drawRect.size.width / previewAspect;
            }
            
            feedView.bindDrawable()
            
            if (self.eaglContext != EAGLContext.currentContext()) {
                EAGLContext.setCurrentContext(self.eaglContext)
            }
            
            // clear eagl view to grey
            glClearColor(0.5, 0.5, 0.5, 1.0);
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT));
            
            // set the blend mode to "source over" so that CI will use that
            glEnable(GLenum(GL_BLEND));
            glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA));
            
            if (sourceImage != 0) {
                self.ciContext.drawImage(sourceImage, inRect: feedView.viewBounds!, fromRect: drawRect)
            }
            
            feedView.display();
        }

    }
    
    
    //pragma mark - Misc
    
    func _showAlertViewWithMessage(message: String) {
        _showAlertViewWithMessage(message, title: "Error")
    }
    
    func _showAlertViewWithMessage(message: String, title: String) {
        dispatch_async(dispatch_get_main_queue()) {
            let alert: UIAlertView = UIAlertView.init(title: title, message: message, delegate: nil, cancelButtonTitle: "Dismiss")
            alert.show()
        }
        
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
}



