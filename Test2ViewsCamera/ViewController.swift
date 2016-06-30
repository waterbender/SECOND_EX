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
import Photos

class GLKViewWithBounds: GLKView {
    var viewBounds : CGRect?
}


class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {
    
    @IBOutlet weak var captureChain: UIImageView!
    @IBOutlet weak var someView: PreviewView!
    @IBOutlet weak var changeCameraButton: UIButton!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var timerLabel: UILabel!
    
    private var movieFileOutput: AVCaptureMovieFileOutput!
    private var stillImageOutput: AVCaptureStillImageOutput!
    private var backgroundRecordingID: UIBackgroundTaskIdentifier = 0
    
    var ciContext: CIContext = CIContext()
    var eaglContext: EAGLContext?
    var captureSession: AVCaptureSession?
    var captureSessionQueue : dispatch_queue_t?
    var currentVideoDimensions: CMVideoDimensions?
    var feedViews: [GLKViewWithBounds]?
    var isFront = false
    var seconds: Double = 0
    var timer: NSTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        loadCamera()
        
    }
    
    func loadCamera() {
        
        if (AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count > 0) {
            // create the dispatch queue for handling capture session delegate method calls
            self.captureSessionQueue = dispatch_queue_create("capture_session_queue", nil);
            
            self.edgesForExtendedLayout = .None
            self.view.backgroundColor = UIColor.blackColor()
            feedViews = []
            
            self.setupContexts()
            self.setupSession()
            self.setupFeedViews()
            self.view.bringSubviewToFront(changeCameraButton)
            self.view.bringSubviewToFront(changeCameraButton)
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setupFeedViews() {
        
        let feedViewHeight: CGFloat = self.view.bounds.height
        
        let feedView : GLKViewWithBounds = self.setupFeedViewWithFrame(CGRectMake(0.0, feedViewHeight*CGFloat(0), self.view.bounds.size.width, self.view.bounds.size.height))
        
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.Dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight] // for supporting device rotation
        
        let feedAboveView = self.setupFeedViewWithFrame(CGRectMake(0.0, feedViewHeight*CGFloat(0), self.view.bounds.size.width, self.view.bounds.size.height))
        feedAboveView.viewBounds = CGRectMake(0.0, 0, feedAboveView.viewBounds!.width, feedAboveView.viewBounds!.height)
        
        view.addSubview(feedView)
        view.addSubview(blurEffectView)
        someView.addSubview(feedAboveView)
        
        self.feedViews?.append(feedView)
        self.feedViews?.append(feedAboveView)
        
        // Setup the preview view.
        self.someView.session = self.captureSession
        
        
        self.view.bringSubviewToFront(someView)
        self.view.bringSubviewToFront(recordButton)
        self.view.bringSubviewToFront(captureChain)
        self.view.bringSubviewToFront(timerLabel)
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
                
                let type = self.isFront ? AVCaptureDevicePosition.Front : AVCaptureDevicePosition.Back
                
                for device in videoDevices{
                    let device = device as! AVCaptureDevice
                    if device.position == type {
                        _videoDevice = device
                        break
                    }
                }
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
            
            let movieFileOutput = AVCaptureMovieFileOutput()
            if ((self.captureSession?.canAddOutput(videoDataOutput)) == nil)
            {
                let string = "Cannot add video data output"
                self._showAlertViewWithMessage(string)
                self.captureSession = nil
                
                return;
            } else {
                
                let connection = movieFileOutput.connectionWithMediaType(AVMediaTypeVideo)
                if connection?.supportsVideoStabilization ?? false {
                    connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationMode.Auto
                }
                
                self.movieFileOutput = movieFileOutput
                
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
            glClearColor(0.5, 0.5, 0.5, 0.0);
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
    
    @IBAction func changeCamera(sender: UIButton) {
        
        self.ciContext = CIContext()
        self.eaglContext = nil
        self.captureSession?.stopRunning()
        self.captureSession = nil
        self.feedViews = nil
   
        isFront = !isFront
        if !isFront {
            sender.setImage(UIImage(named: "ic_camera_rear_white"), forState: .Normal)
        } else {
            sender.setImage(UIImage(named: "ic_camera_front_white"), forState: .Normal)
        }

        loadCamera()
    }
    
    
    //MARK: File Output Recording Delegate
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        // Enable the Record button to let the user stop the recording.
        dispatch_async( dispatch_get_main_queue()) {
            self.recordButton.enabled = true
            self.recordButton.setImage(UIImage(named: "testStop"), forState: .Normal)
        }
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
    
        let cleanup: dispatch_block_t = {
            do {
                try NSFileManager.defaultManager().removeItemAtURL(outputFileURL)
            } catch _ {}
        }
        
        var success = true
        
        if error != nil {
            NSLog("Movie file finishing error: %@", error!)
            success = error!.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as! Bool? ?? false
        }
        if success {
            // Check authorization status.
            PHPhotoLibrary.requestAuthorization {status in
                guard status == PHAuthorizationStatus.Authorized else {
                    cleanup()
                    return
                }
                // Save the movie file to the photo library and cleanup.
                PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                    // In iOS 9 and later, it's possible to move the file into the photo library without duplicating the file data.
                    // This avoids using double the disk space during save, which can make a difference on devices with limited free disk space.
                    if #available(iOS 9.0, *) {
                        let options = PHAssetResourceCreationOptions()
                        options.shouldMoveFile = true
                        let changeRequest = PHAssetCreationRequest.creationRequestForAsset()
                        changeRequest.addResourceWithType(PHAssetResourceType.Video, fileURL: outputFileURL, options: options)
                    } else {
                        PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(outputFileURL)
                    }
                    }, completionHandler: {success, error in
                        if !success {
                            NSLog("Could not save movie to photo library: %@", error!)
                        }
                        cleanup()
                })
            }
        } else {
            cleanup()
        }
        
        // Enable the Camera and Record buttons to let the user switch camera and start another recording.
        dispatch_async( dispatch_get_main_queue()) {
            // Only enable the ability to change camera if the device has more than one camera.
            self.recordButton.enabled = true
            self.recordButton.setImage(UIImage(named: "testRed"), forState: .Normal)

            
        }

    }
    
    
    
    
    @IBAction func toggleMovieRecording(_: AnyObject) {
        // Disable the Camera button until recording finishes, and disable the Record button until recording starts or finishes. See the
        // AVCaptureFileOutputRecordingDelegate methods.
        

        self.timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "update", userInfo: nil, repeats: true)
        
        dispatch_async(self.captureSessionQueue!) {
            if !self.movieFileOutput.recording {
                
                // Start recording to a temporary file.
                let outputFileName = NSProcessInfo.processInfo().globallyUniqueString as NSString
                let outputFilePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent(outputFileName.stringByAppendingPathExtension("mov")!)
                
                let videoFileOutput = AVCaptureMovieFileOutput()
                self.captureSession!.addOutput(videoFileOutput)
                self.movieFileOutput = videoFileOutput
                self.movieFileOutput.startRecordingToOutputFileURL(NSURL(fileURLWithPath: outputFilePath), recordingDelegate: self)
            } else {
                self.timer?.invalidate()
                self.timerLabel.text = ""
                self.movieFileOutput.stopRecording()
            }
        }
        
    }
    
    func update() {
        self.seconds += 0.1
        
        dispatch_async(dispatch_get_main_queue()) {
            
            let hours = round((self.seconds/60)/60)
            let minutes = round((self.seconds - hours*60) / 60)
            let seconds = round(self.seconds - minutes*60-hours*60*60)
            
            self.timerLabel.text = "\(hours):\(minutes):\(seconds)"
        }
    }
}



