//
//  VideoCapture.swift
//  MetalCamera
//
//  Created by Rafi Martirosyan on 14/06/2021.
//  Copyright © 2019 GS. All rights reserved.
//

import UIKit
import AVFoundation
import CoreVideo

protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer?, timestamp: CMTime)
}

class VideoCapture: NSObject {
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    weak var delegate: VideoCaptureDelegate?
    
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    let queue = DispatchQueue(label: "camera-queue")
    
    func setUp(sessionPreset: AVCaptureSession.Preset, frameRate: Int, completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let success = self.setUpCamera(sessionPreset: sessionPreset, frameRate: frameRate)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    func setUpCamera(sessionPreset: AVCaptureSession.Preset, frameRate: Int) -> Bool {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        let desiredFrameRate = frameRate
        
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            fatalError("Error: no video devices available")
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            fatalError("Error: could not create AVCaptureDeviceInput")
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
        ]
        
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        
        let activeDimensions = CMVideoFormatDescriptionGetDimensions(captureDevice.activeFormat.formatDescription)
        for vFormat in captureDevice.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(vFormat.formatDescription)
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            if let frameRate = ranges.first,
               frameRate.maxFrameRate >= Float64(desiredFrameRate) &&
                frameRate.minFrameRate <= Float64(desiredFrameRate) &&
                activeDimensions.width == dimensions.width &&
                activeDimensions.height == dimensions.height &&
                CMFormatDescriptionGetMediaSubType(vFormat.formatDescription) == 875704422 {
                do {
                    try captureDevice.lockForConfiguration()
                    captureDevice.activeFormat = vFormat as AVCaptureDevice.Format
                    captureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
                    captureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(desiredFrameRate))
                    captureDevice.unlockForConfiguration()
                    break
                } catch {
                    continue
                }
            }
        }
        
        captureSession.commitConfiguration()
        return true
    }
    
    func start() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    func stop() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
    }
}
