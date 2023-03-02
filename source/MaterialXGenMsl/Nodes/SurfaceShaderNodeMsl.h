//
// Copyright (c) 2023 Apple Inc.
// Licensed under the Apache License v2.0
//

#ifndef MATERIALX_SURFACESHADERNODEMSL_H
#define MATERIALX_SURFACESHADERNODEMSL_H

#include <MaterialXGenMsl/Export.h>
#include <MaterialXGenShader/Nodes/SourceCodeNode.h>

MATERIALX_NAMESPACE_BEGIN

/// SurfaceShader node implementation for MSL
/// Used for all surface shaders implemented in source code.
class MX_GENMSL_API SurfaceShaderNodeMsl : public SourceCodeNode
{
  public:
    static ShaderNodeImplPtr create();

    const string& getTarget() const override;

    void createVariables(const ShaderNode& node, GenContext& context, Shader& shader) const override;

    void emitFunctionCall(const ShaderNode& node, GenContext& context, ShaderStage& stage) const override;
};

MATERIALX_NAMESPACE_END

#endif
