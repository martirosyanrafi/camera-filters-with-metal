//
//  MainViewController.swift
//  MetalCamera
//
//  Created by Rafi Martirosyan on 14/06/2021.
//  Copyright © 2019 GS. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMedia

final class MainViewController: UIViewController {
    
    @IBOutlet weak var metalView: MetalView!
    
    private var videoCapture: VideoCapture!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        accessCamera()
    }
    
    private func accessCamera() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] success in
            if success {
                self?.setUpCamera()
            } else {
                let alert = UIAlertController(title: "Need Camera Access", message: "Camera access is required to make full use of this app.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (alert) -> Void in
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }))
                DispatchQueue.main.async { [weak self] in
                    self?.present(alert, animated: true)
                }
            }
        }
    }
    
    private func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.setUp(sessionPreset: .hd1280x720, frameRate: 60) { [weak self] success in
            if success {
                self?.videoCapture.start()
            }
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @IBAction func buttonAction(_ sender: Any) {
        metalView.changeKernel()
    }
}

extension MainViewController: VideoCaptureDelegate {
    
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        
        DispatchQueue.main.async { [weak self] in
            self?.metalView.pixelBuffer = pixelBuffer
        }
    }
}

