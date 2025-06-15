
local function voucherSheenPrepass()
    -- called *after* uniforms have already been applied
    shaders.TryApplyUniforms(
      shaders.getShader("voucher_sheen"),
      globals.globalShaderUniforms,
      "voucher_sheen"
    )
end

local function flashPrepass()
    shaders.TryApplyUniforms(
      shaders.getShader("flash"),
      globals.globalShaderUniforms,
      "flash"
    )
end

local function shaderPassConfigFunction(e)
    -- 1) emplace the pipeline component
    
    local pipeline = registry:emplace(e, shader_pipeline.ShaderPipelineComponent)

    -- 2) create & configure first pass
    
    local pass1 = shader_pipeline.createShaderPass("voucher_sheen", {}) -- uniforms are empty for now
    pass1.customPrePassFunction = voucherSheenPrepass
    table.insert(pipeline.passes, pass1)

    -- 3) create & configure second pass
    local pass2 = shader_pipeline.createShaderPass("flash", {})
    pass2.customPrePassFunction = flashPrepass
    table.insert(pipeline.passes, pass2)
end

return shaderPassConfigFunction