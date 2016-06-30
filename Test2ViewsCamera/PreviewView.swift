//
//  PreviewView.swift
//  Test2ViewsCamera
//
//  Created by Yevgenii Pasko on 30.06.16.
//  Copyright © 2016 Yevgenii Pasko. All rights reserved.
//

import UIKit
import AVFoundation

@objc(PreviewView)
class PreviewView: UIView {
    
    private var _session: AVCaptureSession?
    
    override class func layerClass() -> AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var session: AVCaptureSession! {
        get {
            let previewLayer = self.layer as! AVCaptureVideoPreviewLayer
            return previewLayer.session
        }
        
        set(session) {
            let previewLayer = self.layer as! AVCaptureVideoPreviewLayer
            previewLayer.session = session
        }
    }
    
}