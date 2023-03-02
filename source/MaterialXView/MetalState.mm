//
// Copyright (c) 2023 Apple Inc.
// Licensed under the Apache License v2.0
//

#include "MetalState.h"
#import <Metal/Metal.h>

#include <MaterialXRenderMsl/MetalFramebuffer.h>

std::unique_ptr<MetalState> MetalState::singleton = nullptr;

void MetalState::initLinearToSRGBKernel()
{
    if(supportsTiledPipeline)
    {
        NSString* linearToSRGB_kernel =
        @"#include <metal_stdlib>                                                         \n"
         "#include <simd/simd.h>                                                          \n"
         "                                                                                \n"
         "using namespace metal;                                                          \n"
         "                                                                                \n"
         "struct RenderTarget {                                                           \n"
         "    half4 colorTarget [[color(0)]];                                             \n"
         "};                                                                              \n"
         "                                                                                \n"
         "                                                                                \n"
         "                                                                                \n"
         "half4 linearToSRGB(half4 color_linear)                                          \n"
         "{                                                                               \n"
         "    half4 color_srgb;                                                           \n"
         "    for(int i = 0; i < 3; ++i)                                                  \n"
         "        color_srgb[i] = (color_linear[i] < 0.0031308) ? (12.92 * color_linear[i]): (1.055 * pow(color_linear[i], 1.0h / 2.2h) - 0.055);\n"
         "    color_srgb[3] = color_linear[3];                                            \n"
         "    return color_srgb;                                                          \n"
         "}                                                                               \n"
         "                                                                                \n"
         "kernel void LinearToSRGB_kernel(                                                \n"
         "    imageblock<RenderTarget,imageblock_layout_implicit> imageBlock,             \n"
         "    ushort2 tid                 [[ thread_position_in_threadgroup ]])           \n"
         "{                                                                               \n"
         "    RenderTarget linearValue = imageBlock.read(tid);                            \n"
         "    RenderTarget srgbValue;                                                     \n"
         "    srgbValue.colorTarget = linearToSRGB(linearValue.colorTarget);              \n"
         "    imageBlock.write(srgbValue, tid);                                           \n"
         "}                                                                               \n";

        
        NSError* error = nil;
        
        MTLCompileOptions* options = [MTLCompileOptions new];
        options.languageVersion = MTLLanguageVersion2_3;
        options.fastMathEnabled = true;
        id<MTLLibrary> library = [device newLibraryWithSource:linearToSRGB_kernel options:options error:&error];
        
        MTLFunctionDescriptor* functionDesc = [MTLFunctionDescriptor new];
        [functionDesc setName:@"LinearToSRGB_kernel"];
        
        id<MTLFunction> function = [library newFunctionWithDescriptor:functionDesc error:&error];
        
        MTLTileRenderPipelineDescriptor* renderPipelineDescriptor = [MTLTileRenderPipelineDescriptor new];
        [renderPipelineDescriptor setRasterSampleCount:1];
        [[renderPipelineDescriptor colorAttachments][0] setPixelFormat:MTLPixelFormatBGRA8Unorm];
        [renderPipelineDescriptor setTileFunction:function];
        linearToSRGB_pso = [device newRenderPipelineStateWithTileDescriptor:renderPipelineDescriptor options:0 reflection:nil error:&error];
    }
    else
    {
        NSString* linearToSRGB_kernel =
        @"#include <metal_stdlib>                                       \n"
         "#include <simd/simd.h>                                        \n"
         "                                                              \n"
         "using namespace metal;                                        \n"
         "                                                              \n"
         "struct VSOutput                                               \n"
         "{                                                             \n"
         "    float4 position [[position]];                             \n"
         "};                                                            \n"
         "                                                              \n"
         "vertex VSOutput VertexMain(uint vertexId [[ vertex_id ]])     \n"
         "{                                                             \n"
         "    VSOutput vsOut;                                           \n"
         "                                                              \n"
         "    switch(vertexId)                                          \n"
         "    {                                                         \n"
         "    case 0: vsOut.position = float4(-1, -1, 0.5, 1); break;   \n"
         "    case 1: vsOut.position = float4(-1,  3, 0.5, 1); break;   \n"
         "    case 2: vsOut.position = float4( 3, -1, 0.5, 1); break;   \n"
         "    };                                                        \n"
         "                                                              \n"
         "    return vsOut;                                             \n"
         "}                                                             \n"
         "                                                              \n"
         "half4 linearToSRGB(half4 color_linear)                        \n"
         "{                                                             \n"
         "    half4 color_srgb;                                         \n"
         "    for(int i = 0; i < 3; ++i)                                \n"
         "        color_srgb[i] = (color_linear[i] < 0.0031308) ? (12.92 * color_linear[i]): (1.055 * pow(color_linear[i], 1.0h / 2.2h) - 0.055);\n"
         "    color_srgb[3] = color_linear[3];                          \n"
         "    return color_srgb;                                        \n"
         "}                                                             \n"
         "                                                              \n"
         "fragment half4 FragmentMain(                                  \n"
         "    texture2d<half>  inputTex  [[ texture(0) ]],              \n"
         "    float4           fragCoord [[ position ]]                 \n"
         ")                                                             \n"
         "{                                                             \n"
         "    constexpr sampler ss(                                     \n"
         "        coord::pixel,                                         \n"
         "        address::clamp_to_border,                             \n"
         "        filter::linear);                                      \n"
         "    return linearToSRGB(inputTex.sample(ss, fragCoord.xy));   \n"
         "}                                                             \n";
        
        NSError* error = nil;
        
        MTLCompileOptions* options = [MTLCompileOptions new];
        options.languageVersion = MTLLanguageVersion2_3;
        options.fastMathEnabled = true;
        id<MTLLibrary> library = [device newLibraryWithSource:linearToSRGB_kernel options:options error:&error];
        
        MTLFunctionDescriptor* functionDesc = [MTLFunctionDescriptor new];
        [functionDesc setName:@"VertexMain"];
        
        id<MTLFunction> vertexfunction = [library newFunctionWithDescriptor:functionDesc error:&error];
        
        [functionDesc setName:@"FragmentMain"];
        
        id<MTLFunction> Fragmentfunction = [library newFunctionWithDescriptor:functionDesc error:&error];
        
        MTLRenderPipelineDescriptor* renderPipelineDesc = [MTLRenderPipelineDescriptor new];
        [renderPipelineDesc setVertexFunction:vertexfunction];
        [renderPipelineDesc setFragmentFunction:Fragmentfunction];
        [[renderPipelineDesc colorAttachments][0] setPixelFormat:MTLPixelFormatRGBA16Float];
        [renderPipelineDesc setDepthAttachmentPixelFormat:MTLPixelFormatDepth32Float];
        linearToSRGB_pso = [device newRenderPipelineStateWithDescriptor:renderPipelineDesc error:&error];
    }
}

void MetalState::triggerProgrammaticCapture()
{
    MTLCaptureManager*    captureManager    = [MTLCaptureManager sharedCaptureManager];
    MTLCaptureDescriptor* captureDescriptor = [MTLCaptureDescriptor new];
   
    [captureDescriptor setCaptureObject:device];
    
    NSError* error = nil;
    if(![captureManager startCaptureWithDescriptor:captureDescriptor error:&error])
    {
        NSLog(@"Failed to start capture, error %@", error);
    }
}

void MetalState::stopProgrammaticCapture()
{
    MTLCaptureManager* captureManager = [MTLCaptureManager sharedCaptureManager];
    [captureManager stopCapture];
}

void MetalState::beginCommandBuffer()
{
    cmdBuffer = [cmdQueue commandBuffer];
    inFlightCommandBuffers++;
}

void MetalState::beginEncoder(MTLRenderPassDescriptor* renderpassDesc)
{
    renderCmdEncoder = [cmdBuffer
                        renderCommandEncoderWithDescriptor:renderpassDesc];
}

void MetalState::endEncoder()
{
    [renderCmdEncoder endEncoding];
}

void MetalState::endCommandBuffer()
{
    endEncoder();
    [cmdBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull) {
        inFlightCommandBuffers--;
        inFlightCV.notify_one();
    }];
    [cmdBuffer commit];
    [cmdBuffer waitUntilCompleted];
}

void MetalState::waitForComplition()
{
    std::unique_lock lock(inFlightMutex);
    while (inFlightCommandBuffers != 0){
        inFlightCV.wait(lock, [this]{ return inFlightCommandBuffers.load() == 0; });
    }
}

MaterialX::MetalFramebufferPtr MetalState::currentFramebuffer()
{
    return framebufferStack.top();
}
