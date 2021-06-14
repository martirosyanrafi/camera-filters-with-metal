//
//  MetalView.swift
//  MetalCamera
//
//  Created by Rafi Martirosyan on 14/06/2021.
//  Copyright © 2019 GS. All rights reserved.
//

import MetalKit
import CoreVideo

final class MetalView: MTKView {
    
    private var kernelIndex = 0
    private let kernels = [
        "passthroughKernel",
        "brightnessKernel",
        "inversionKernel",
        "contrastKernel",
        "rgba2bgraKernel",
        "exposureKernel",
        "gammaKernel",
        "grayscaleKernel",
        "pixellateKernel",
        "boxBlurKernel"
    ]
    
    var pixelBuffer: CVPixelBuffer? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    private var textureCache: CVMetalTextureCache?
    private var commandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState!
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        device = MTLCreateSystemDefaultDevice()!
        
        commandQueue = device!.makeCommandQueue()
        updatePipelineState()
        
        var textCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &textCache) != kCVReturnSuccess {
            fatalError("Unable to allocate texture cache.")
        }
        else {
            textureCache = textCache
        }
        
        drawableSize.width = 720
        drawableSize.height = 1280
        framebufferOnly = false
    }
    
    override func draw(_ rect: CGRect) {
        autoreleasepool {
            if !rect.isEmpty {
                self.render()
            }
        }
    }
    
    private func render() {
        guard let pixelBuffer = self.pixelBuffer else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache!, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTextureOut)
        
        guard let cvTexture = cvTextureOut, let inputTexture = CVMetalTextureGetTexture(cvTexture) else {
            fatalError("Failed to create metal textures")
        }
        
        guard let drawable: CAMetalDrawable = self.currentDrawable else { fatalError("Failed to create drawable") }
        
        if let commandQueue = commandQueue, let commandBuffer = commandQueue.makeCommandBuffer(), let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() {
            computeCommandEncoder.setComputePipelineState(computePipelineState)
            computeCommandEncoder.setTexture(inputTexture, index: 0)
            computeCommandEncoder.setTexture(drawable.texture, index: 1)
            computeCommandEncoder.dispatchThreadgroups(inputTexture.threadGroups(), threadsPerThreadgroup: inputTexture.threadGroupCount())
            computeCommandEncoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
    
    private func updatePipelineState() {
        let library = device!.makeDefaultLibrary()!
        let function = library.makeFunction(name: kernels[kernelIndex])!
        computePipelineState = try! device!.makeComputePipelineState(function: function)
    }
    
    func changeKernel() {
        kernelIndex = (kernelIndex + 1) % kernels.count
        updatePipelineState()
    }
}

extension MTLTexture {
    
    func threadGroupCount() -> MTLSize {
        return MTLSizeMake(8, 8, 1)
    }
    
    func threadGroups() -> MTLSize {
        let groupCount = threadGroupCount()
        return MTLSize(width: (Int(width) + groupCount.width - 1) / groupCount.width, height: (Int(height) + groupCount.height - 1) / groupCount.height, depth: 1)
    }
}
