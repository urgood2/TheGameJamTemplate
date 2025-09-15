```cpp
{
    // ZoneScopedN("testing various draws");
    
    
    // --testing stencil 
    // layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = visualX + visualW * 0.5 - shadowDisplacementX, y = visualY + visualH * 0.5 + shadowDisplacementY](auto *cmd) {
    //         cmd->x = x;
    //         cmd->y = y;
    //     }, 0, drawCommandSpace);
    // clearStencilBuffer(); // clear the stencil buffer
    layer::QueueCommand<layer::CmdClearStencilBuffer>(sprites, [](auto* cmd) {
    }, 0, layer::DrawCommandSpace::World); // clear the stencil buffer
    // beginStencil();
    layer::QueueCommand<layer::CmdBeginStencilMode>(sprites, [](auto* cmd) {
    }, 0, layer::DrawCommandSpace::World); // begin stencil mode
    // beginStencilMask();
    layer::QueueCommand<layer::CmdBeginStencilMask>(sprites, [](auto* cmd) {
    }, 0, layer::DrawCommandSpace::World); // begin stencil mask

    
    // endStencilMask();
    layer::QueueCommand<layer::CmdEndStencilMask>(sprites, [](auto* cmd) {
    }, 0, layer::DrawCommandSpace::World); // end stencil mask
    
    
    // endStencil();
    layer::QueueCommand<layer::CmdEndStencilMode>(sprites, [](auto* cmd) {
    }, 0, layer::DrawCommandSpace::World); // end stencil mode
    
    
    
    
    static float phase = 0;
    phase += dt * 10.0f; // advance phase for dashes
    // -- testing --
    // DrawDashedCircle({ 100, 100 }, 50, 10, 5, phase, 32, 2, GREEN);
    layer::QueueCommand<layer::CmdDrawDashedCircle>(sprites, [](auto* cmd) {
        cmd->center = { 100, 100 };
        cmd->radius = 50;
        cmd->dashLength = 10;
        cmd->gapLength = 5;
        cmd->phase = phase;
        cmd->segments = 32;
        cmd->thickness = 2;
        cmd->color = GREEN;
    }, 0, layer::DrawCommandSpace::World);
    // DrawDashedLine({ 200, 200 }, { 300, 300 }, 10, 5, phase, 2, GREEN);
    layer::QueueCommand<layer::CmdDrawDashedLine>(sprites, [](auto* cmd) {
        cmd->start = { 200, 200 };
        cmd->end = { 300, 300 };
        cmd->dashLength = 10;
        cmd->gapLength = 5;
        cmd->phase = phase;
        cmd->thickness = 2;
        cmd->color = GREEN;
    }, 0, layer::DrawCommandSpace::World);
    // DrawDashedRoundedRect(
    //     { 400, 400, 200, 100 }, // rectangle
    //     10,                   // dash length
    //     5,                    // gap length
    //     phase,                // phase
    //     20,                   // radius
    //     16,                   // arc steps
    //     2,                    // thickness
    //     BLUE                 // color
    // );
    layer::QueueCommand<layer::CmdDrawDashedRoundedRect>(sprites, [](auto* cmd) {
        cmd->rec = { 400, 400, 200, 100 };
        cmd->dashLen = 10;
        cmd->gapLen = 5;
        cmd->phase = phase;
        cmd->radius = 20;
        cmd->arcSteps = 16;
        cmd->thickness = 2;
        cmd->color = BLUE;
    }, 0, layer::DrawCommandSpace::World);
    // ellipse(
    //     600, 600, 100, 50, // center x, y, radius x, radius y
    //     std::nullopt,      // no color (default to WHITE)
    //     std::nullopt       // no line width (default to 1px)
    // );
    layer::QueueCommand<layer::CmdDrawCenteredEllipse>(sprites, [](auto* cmd) {
        cmd->x = 600;
        cmd->y = 600;
        cmd->rx = 100;
        cmd->ry = 50;
        cmd->color = WHITE;
        cmd->lineWidth = 1;
    }, 0, layer::DrawCommandSpace::World);
    // rounded_line(
    //     700, 700, 800, 800, // start x, y, end x, y
    //     std::nullopt,       // no color (default to WHITE)
    //     30        // no line width (default to 1px)
    // );
    layer::QueueCommand<layer::CmdDrawRoundedLine>(sprites, [](auto* cmd) {
        cmd->x1 = 700;
        cmd->y1 = 700;
        cmd->x2 = 800;
        cmd->y2 = 800;
        cmd->color = WHITE;
        cmd->lineWidth = 30;
    }, 0, layer::DrawCommandSpace::World);
    // polyline(
    //     { { 900, 900 }, { 950, 850 }, { 1000, 700 }, { 950, 300 } }, // points
    //     YELLOW, // no color (default to WHITE)
    //     20  // no line width (default to 1px)
    // );
    layer::QueueCommand<layer::CmdDrawPolyline>(sprites, [](auto* cmd) {
        cmd->points = { { 900, 900 }, { 950, 850 }, { 1000, 700 }, { 950, 300 } };
        cmd->color = YELLOW;
        cmd->lineWidth = 20;
    }, 0, layer::DrawCommandSpace::World);
    // polygon(
    //     { { 1100, 850 }, { 1150, 400 }, { 1200, 500 }, { 1150, 800 } }, // vertices
    //     GREEN, // no color (default to WHITE)
    //     5  // no line width (default to 1px)
    // );
    layer::QueueCommand<layer::CmdDrawPolygon>(sprites, [](auto* cmd) {
        cmd->vertices = { { 1100, 850 }, { 1150, 400 }, { 1200, 500 }, { 1150, 800 } };
        cmd->color = GREEN;
        cmd->lineWidth = 5;
    }, 0, layer::DrawCommandSpace::World);
    // arc(
    //     ArcType::Pie, // type
    //     600, 200, 100, // center x, y, radius
    //     0, PI / 2, // start angle, end angle
    //     std::nullopt, // no color (default to WHITE)
    //     std::nullopt, // no line width (default to 1px)
    //     32 // segments
    // );
    
    layer::QueueCommand<layer::CmdDrawArc>(sprites, [](auto* cmd) {
        cmd->type = "Pie";
        cmd->x = 600;
        cmd->y = 200;
        cmd->r = 100;
        cmd->r1 = 0;
        cmd->r2 = PI / 2;
        cmd->color = WHITE;
        cmd->lineWidth = 1;
        cmd->segments = 32;
    }, 0, layer::DrawCommandSpace::World);
    // triangle_equilateral(
    //     1400, 700, 100, // center x, y, width
    //     std::nullopt, // no color (default to WHITE)
    //     std::nullopt  // no line width (default to 1px)
    // );
    layer::QueueCommand<layer::CmdDrawTriangleEquilateral>(sprites, [](auto* cmd) {
        cmd->x = 1400;
        cmd->y = 700;
        
        cmd->w = 100;
        cmd->color = WHITE;
        cmd->lineWidth = std::nullopt;
    }, 0, layer::DrawCommandSpace::World);
    // rectangle(
    //     1500, 300, 200, 100, // center x, y, width, height
    //     10, 
    //     10, 
    //     std::nullopt, // no color (default to WHITE)
    //     std::nullopt  // no line width (default to 1px)
    // );
    layer::QueueCommand<layer::CmdDrawCenteredFilledRoundedRect>(sprites, [](auto* cmd) {
        cmd->x = 0;
        cmd->y = 0;
        cmd->w = 200;
        cmd->h = 200;
        cmd->rx = 10;
        cmd->ry = 10;
        cmd->color = WHITE;
        cmd->lineWidth = 1;
    }, 0, layer::DrawCommandSpace::World);
    
    // DrawSpriteCentered("star_09.png", 500, 500, 
    //                    std::nullopt, std::nullopt, GREEN); // draw centered sprite
    
    layer::QueueCommand<layer::CmdDrawSpriteCentered>(sprites, [](auto* cmd) {
        cmd->spriteName = "star_09.png";
        cmd->x = 500;
        cmd->y = 500;
        cmd->dstW = std::nullopt;
        cmd->dstH = std::nullopt;
        cmd->tint = GREEN;
    }, 0, layer::DrawCommandSpace::World);
    // DrawCircle(500, 500, 10, YELLOW); // draw circle
    
    // DrawSpriteTopLeft("keyboard_w_outline.png", 500, 500, 
    //                   std::nullopt, std::nullopt, WHITE); // draw top-left sprite

    layer::QueueCommand<layer::CmdDrawSpriteTopLeft>(sprites, [](auto* cmd) {
        cmd->spriteName = "keyboard_w_outline.png";
        cmd->x = 500;
        cmd->y = 500;
        cmd->dstW = std::nullopt;
        cmd->dstH = std::nullopt;
        cmd->tint = WHITE;
    }, 0, layer::DrawCommandSpace::World);
                        
    // fill screen with white
    // DrawRectangleRec({0, 0, (float)GetScreenWidth() / 2, (float)GetScreenHeight() / 2}, {255, 255, 255, 255});
    
}
```