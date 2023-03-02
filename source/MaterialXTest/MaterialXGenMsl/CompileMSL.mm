//
// Copyright (c) 2023 Apple Inc.
// Licensed under the Apache License v2.0
//

#include "CompileMSL.h"

#include <string>
#include <streambuf>

#include <MaterialXGenShader/ShaderGenerator.h>

#import <Metal/Metal.h>

#define SHOW_COMPILE_DEBUG MESSAGES
#ifdef SHOW_COMPILE_DEBUG
#define PRINTF(fmt, ...) printf(fmt"\n", ##__VA_ARGS__)
#else
#define PRINTF(...)
#endif

id<MTLDevice> device = nil;

void CompileMSLShader(const char* pShaderFilePath, const char* pEntryFuncName)
{
    NSError* _Nullable error = nil;
    if(device == nil)
        device = MTLCreateSystemDefaultDevice();
    
    NSString* filepath = [NSString stringWithUTF8String:pShaderFilePath];
    NSString* shadersource = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:&error];
    if(error != nil)
    {
       throw MaterialX::ExceptionShaderGenError("Cannot load file '" + std::string(pShaderFilePath) + "'.");
        return;
    }
    
    MTLCompileOptions* options = [MTLCompileOptions new];
    options.languageVersion = MTLLanguageVersion3_0;
    options.fastMathEnabled = true;
    [device newLibraryWithSource:shadersource options:options error:&error];
    if(error != nil)
    {
        throw MaterialX::ExceptionShaderGenError("Failed to create library out of '" + std::string(pShaderFilePath) + "'.");
        return;
    }
}
