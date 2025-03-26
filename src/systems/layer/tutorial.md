This system allows for localized rendering (render commands are added outside the draw loop) and modular application of shaders.

```cpp
{
    // Create layers
    auto bg = layer::CreateLayer();         // Background layer
    auto fg = layer::CreateLayer();         // Foreground layer
    auto shadow = layer::CreateLayer();     // Shadow layer for drop shadows
    auto effects = layer::CreateLayer();    // Effects layer
    auto output = layer::CreateLayer();     // Final output layer

    Camera2D camera = {0};                  // Dummy camera

    Shader dropShadow = {0};                // Drop shadow shader
    Shader outline = {0};                   // Outline shader

    // Add additional canvases to layers
    layer::AddCanvasToLayer(fg, "outline"); // Add outline canvas to foreground layer
    layer::AddCanvasToLayer(effects, "outline"); // Add outline canvas to effects layer

    // Render commands to respective canvases
    layer::DrawLayerCommandsToSpecificCanvas(bg, "main", &camera);
    layer::DrawLayerCommandsToSpecificCanvas(fg, "main", &camera);
    layer::DrawLayerCommandsToSpecificCanvas(effects, "main", &camera);

    // Render shadows using the drop shadow shader
    layer::DrawCustomLamdaToSpecificCanvas(shadow, "main", [&]() {
        layer::SendUniformFloat(dropShadow, "u_offset", 5.0f);
        layer::DrawCanvasToCurrentRenderTarget(fg, "main", 0, 0, 0, 1, 1, WHITE, dropShadow, true);
        layer::DrawCanvasToCurrentRenderTarget(effects, "main", 0, 0, 0, 1, 1, WHITE, dropShadow, true);
    });

    // Render outlines using the outline shader
    layer::DrawCustomLamdaToSpecificCanvas(fg, "outline", [&]() {
        layer::SendUniformFloat(outline, "u_thickness", 2.0f);
        layer::DrawCanvasToCurrentRenderTarget(fg, "main", 0, 0, 0, 1, 1, WHITE, outline, true);
    });
    layer::DrawCustomLamdaToSpecificCanvas(effects, "outline", [&]() {
        layer::SendUniformFloat(outline, "u_thickness", 2.0f);
        layer::DrawCanvasToCurrentRenderTarget(effects, "main", 0, 0, 0, 1, 1, WHITE, outline, true);
    });

    // Render everything to the output layer in the correct order
    layer::DrawCustomLamdaToSpecificCanvas(output, "main", [&]() {
        layer::DrawCanvasToCurrentRenderTarget(bg, "main", 0, 0, 0, 1, 1, WHITE);
        layer::DrawCanvasToCurrentRenderTarget(shadow, "main", 0, 0, 0, 1, 1, WHITE);
        layer::DrawCanvasToCurrentRenderTarget(fg, "outline", 0, 0, 0, 1, 1, WHITE);
        layer::DrawCanvasToCurrentRenderTarget(fg, "main", 0, 0, 0, 1, 1, WHITE);
        layer::DrawCanvasToCurrentRenderTarget(effects, "outline", 0, 0, 0, 1, 1, WHITE);
        layer::DrawCanvasToCurrentRenderTarget(effects, "main", 0, 0, 0, 1, 1, WHITE);
    });

    // Render the output layer to the screen
    layer::DrawCanvasToCurrentRenderTarget(output, "main", 0, 0, 0, 1, 1, WHITE);
}
```