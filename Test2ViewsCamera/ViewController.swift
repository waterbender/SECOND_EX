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

        
        let session = AVCaptureSession()
        let inputDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        let deviceInput: AVCaptureDeviceInput?
        do {
            deviceInput = try AVCaptureDeviceInput.init(device: inputDevice)
            if session.canAddInput(deviceInput) {
                session.addInput(deviceInput)
            }
            
        } catch {
            
        }
        
        
        let previewLayer : AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer.init(session: session)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.frame = self.view.bounds
        
        let replicatorInstances : Int = 2
        let replicatorViewHeight : Float = (Float(self.view.bounds.size.height) - 300) / Float(replicatorInstances)
        
        //Create the replicator layer
        let replicatorLayer: CAReplicatorLayer = CAReplicatorLayer()
        replicatorLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width/5, CGFloat(replicatorViewHeight)/5)
        
        var transform:CATransform3D  = CATransform3DIdentity;

        let k = (self.view.frame.width/2) / self.view.frame.height
        let xInset = CGFloat(150.0)
        transform = CATransform3DScale(transform, 0.5, k, 1)
        transform = CATransform3DTranslate(transform, xInset, 300, 1)
    
        
        replicatorLayer.instanceCount = replicatorInstances;
        replicatorLayer.instanceTransform = transform

        replicatorLayer.addSublayer(previewLayer)
        self.view.layer.addSublayer(replicatorLayer)
        session.startRunning()
    }

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
}



