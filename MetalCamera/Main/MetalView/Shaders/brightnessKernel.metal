//
//  brightnessKernel.metal
//  MetalCamera
//
//  Created by Rafi Martirosyan on 14/06/2021.
//  Copyright © 2019 GS. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void brightnessKernel(texture2d<float, access::read> inTexture [[ texture(0) ]],
                              texture2d<float, access::write> outTexture [[ texture(1) ]],
                              uint2 gid [[ thread_position_in_grid ]]) {
    const float brightness = 0.5;
    float4 originalColor = inTexture.read(gid);
    float4 finalColor = float4(originalColor.rgb+brightness, originalColor.a);
    outTexture.write(finalColor, gid);
}
