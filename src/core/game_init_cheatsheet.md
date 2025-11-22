This cheatsheet summarizes the core architectural patterns and programming techniques used in your `game::init()` function.

---
## 1. Entity-Component-System (ECS) with `EnTT`

The foundation of your game architecture. Instead of complex object hierarchies, game objects are simple `entt::entity` IDs, and their data and behavior are defined by attaching modular `components`.

* **Global Registry**: A single, global `entt::registry` instance (`globals::getRegistry()`) acts as the central database for all entities and components.
* **Entity Creation**: New game objects are created as simple, empty handles.
    ```cpp
    // Creates a new entity ID.
    player = globals::getRegistry().create();
    ```
* **Component Attachment**: Data is attached to entities using `emplace`. The component is default-constructed, and its properties are set immediately after. This is a common and flexible pattern.
    ```cpp
    // Add a component to an entity.
    auto& node = globals::getRegistry().emplace<transform::GameObject>(transformEntity);
    // Set properties on the new component.
    node.debug.debugText = "Parent";
    node.state.dragEnabled = true;
    ```

---
## 2. Layer-Based Rendering

Your rendering is not monolithic. It's organized into distinct, independent layers that are composited together at the end of the frame. This is excellent for managing complex scenes and UI.

* **Layer Creation**: Each layer is a separate rendering target, created to a specific size (usually the screen size).
    ```cpp
    // Create distinct rendering layers.
    background = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
    ui_layer   = layer::CreateLayerWithSize(GetScreenWidth(), GetScreenHeight());
    ```
* **Command Buffer Pattern**: Instead of drawing immediately, rendering commands (`CmdDrawRectangle`, `CmdDrawTransformEntityAnimation`, etc.) are queued into a layer's command buffer during the `draw()` phase.
    ```cpp
    // Queue a command to draw an animated entity into the 'sprites' layer.
    layer::QueueCommand<layer::CmdDrawTransformEntityAnimation>(sprites, ...);
    ```
* **Composition**: At the end of the draw call, the layers are rendered in order (e.g., background first, then sprites, then UI) to produce the final image, often with post-processing shaders applied.
    ```cpp
    // Render one layer's contents onto another, applying a shader.
    layer::DrawCanvasOntoOtherLayerWithShader(background, "main", finalOutput, "main", ...);
    ```

---
## 3. Hierarchical UI System (Builder Pattern)

Your UI is built using a highly structured, hierarchical, and data-driven approach. This is a very powerful pattern for creating complex and reusable UIs.

* **Template Nodes**: UI elements are defined as `UIElementTemplateNode` objects. This separates the *definition* of a UI element from its *instance* in the game world.
* **Builder Pattern**: You use a fluent "builder" syntax to construct these templates. This makes the code readable and prevents errors by guiding the construction process.
    ```cpp
    ui::UIElementTemplateNode uiTestRootDef = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::ROOT)
        .addConfig(ui::UIConfig::Builder::create()
            .addColor(BLUE)
            .addAlign(...)
            .build()
        )
        .addChild(...)
        .build();
    ```
* **Initialization from Template**: A complete UI hierarchy is instantiated in the world from a root template node. This creates all the necessary entities and components.
    ```cpp
    // Create a live UI box in the world from a template definition.
    uiBox = ui::box::Initialize(globals::getRegistry(), {.w=200, .h=200}, uiTestRootDef, ...);
    ```

---
## 4. Scene Graph & Transform Hierarchy

Game objects are positioned in a parent-child hierarchy (a scene graph) to allow for complex relative movements, attachments, and layouts.

* **Role-Based Hierarchy**: Relationships are defined by assigning a "role" to an entity via the `InheritedProperties` component. This is more flexible than a direct pointer-based parent-child system.
* **Assigning Roles**: The `transform::AssignRole` function establishes a link between a child and a master entity, defining how properties like location and rotation are synchronized.
    ```cpp
    // Make 'childEntity' a permanent attachment to 'transformEntity'.
    transform::AssignRole(&globals::getRegistry(), childEntity, transform::InheritedProperties::Type::PermanentAttachment, transformEntity, ...);
    ```
* **Alignment Flags**: The layout of children relative to their parent is controlled with bitmask flags, allowing for precise and complex arrangements (e.g., align to the parent's right edge and vertical center).
    ```cpp
    childRole.flags->alignment = transform::InheritedProperties::Alignment::HORIZONTAL_RIGHT | transform::InheritedProperties::Alignment::VERTICAL_CENTER;
    ```

---
## 5. C++/Lua Scripting Bridge

Your C++ engine is driven by a master Lua state, allowing for game logic to be defined and modified without recompiling the C++ code.

* **Master Lua State**: A single `sol::state` (`ai_system::masterStateLua`) holds all loaded game logic scripts.
* **Function Caching**: At initialization, key Lua functions (`init`, `update`, `draw`) are fetched from the Lua state and stored in C++ `sol::function` handles for fast, repeated calling.
    ```cpp
    luaMainInitFunc = ai_system::masterStateLua["main"]["init"];
    luaMainUpdateFunc = ai_system::masterStateLua["main"]["update"];
    ```
* **Bootstrapping**: The C++ `init()` function calls the main Lua `init()` function, effectively handing off control to the Lua script to begin the game setup.
    ```cpp
    // Kick off the game from the Lua side.
    sol::protected_function_result result = luaMainInitFunc();
    ```

---
## 6. Collision Detection with Quadtree

For efficient collision detection, you use a quadtree to spatially partition the game world.

* **Initialization**: The quadtree is initialized once with bounds slightly larger than the game world to handle objects near the edges.
* **Per-Frame Rebuild**: The quadtree is cleared and re-populated with all collidable entities every single frame. While this seems expensive, it's often faster and simpler than trying to update the positions of dynamic objects within the tree.
    ```cpp
    // In your main update loop...
    globals::quadtree.clear();
    globals::getRegistry().view<transform::Transform>().each([&](entt::entity e, ...) {
        globals::quadtree.add(e);
    });
    ```
* **Querying**: Other systems can then efficiently query the quadtree to find potential collisions within a specific area, avoiding a slow check against every object in the game.

---
## 7. Rich Text System with In-line Tagging

Your engine supports a rich text system that parses special tags within strings to apply real-time effects, embed images, and handle complex character sets.

* **Tag-Based Formatting**: Strings can contain BBCode-style tags to apply effects, colors, or embed other objects. This supports UTF-8, allowing for languages like Korean.
    ```cpp
    // This string mixes effects, colors, images, and non-ASCII characters.
    auto text = "[안녕](color=red)[img](uuid=gear.png)[Hello](rainbow;bump)";
    ```
* **Event-Driven Callbacks**: The system uses callbacks to react to events. For example, `OnUIScaleChanged` can trigger a function to re-calculate UI layouts when the global UI scale changes.
    ```cpp
    // Assign a lambda to be called when the UI scale factor changes.
    OnUIScaleChanged = []() {
        // ... get UI root component ...
        SPDLOG_DEBUG("UI Scale changed to: {}", globals::globalUIScaleFactor);
        ui::box::RenewAlignment(globals::getRegistry(), uiBox);
    };
    ```

---
## 8. Detailed Entity Initialization

Entities are more than just a single component. A typical game object is composed of multiple components that define its state, appearance, and behavior.

* **Composition over Inheritance**: Instead of a deep class hierarchy, a "player" is defined by the components it *has*.
* **Step-by-Step Configuration**: An entity is first created, then components are emplaced one by one, and their properties are configured. This is a very clear and explicit way to define an object.
    ```cpp
    // 1. Create the entity from an animation resource.
    player2 = animation_system::createAnimatedObjectWithTransform("...");

    // 2. Get the GameObject component to configure its state.
    auto &playerNode2 = globals::getRegistry().get<transform::GameObject>(player2);
    playerNode2.debug.debugText = "Player (untethered)";
    playerNode2.state.dragEnabled = true;
    playerNode2.state.hoverEnabled = true;
    playerNode2.state.collisionEnabled = true;
    
    // 3. Call a system function to modify the entity.
    animation_system::resizeAnimationObjectsInEntityToFit(player2, 40.f, 40.f);
    ```

---
## 9. Procedural Particle System

Your engine can generate complex visual effects through a procedural particle system, often driven by timers for continuous or burst emissions.

* **Timer-Driven Spawning**: A timer can be set up to periodically run a function that creates new particles. This is great for effects like smoke, fire, or explosions.
* **Randomized Properties**: Each particle can be created with unique, randomized properties (velocity, rotation, lifespan, color) to create a more natural and less uniform appearance.
    ```cpp
    timer::TimerSystem::timer_every(4.0f, [](auto f) {
        // Define a new particle with randomized values.
        particle::Particle particle{
            .velocity = Vector2{Random::get<float>(-200, 200), ...},
            .lifespan = Random::get<float>(1, 3),
            .color    = random_utils::random_element<Color>({RED, GREEN, BLUE})
        };
        // Create the particle instance in the world.
        particle::CreateParticle(globals::getRegistry(), GetMousePosition(), ...);
    });
    ```

---
## 10. Shader Pipelines & Post-Processing

Complex visual effects are achieved by attaching a `ShaderPipelineComponent` to an entity, allowing for multiple shader passes to be applied sequentially.

* **Shader Pass Definition**: Each step in the pipeline is a `ShaderPass`, which specifies a shader name and a set of unique uniforms.
    ```cpp
    // Create a shader pass object using a factory function.
    auto pass = shader_pipeline::createShaderPass("voucher_sheen", {});
    ```
* **Pre-Pass Callbacks**: Each pass can have a `customPrePassFunction`. This lambda is executed right before the shader is applied, allowing for dynamic, frame-by-frame uniform updates.
    ```cpp
    pass.customPrePassFunction = []() {
        // This code runs every frame for this specific pass.
        shaders::TryApplyUniforms(shaders::getShader("voucher_sheen"), ...);
    };
    ```
* **Attaching the Pipeline**: The configured passes are added to the entity's `ShaderPipelineComponent`. The rendering system then automatically executes this pipeline.
    ```cpp
    // Create the pipeline component on the entity.
    auto &shaderPipeline = globals::getRegistry().emplace<shader_pipeline::ShaderPipelineComponent>(e);
    // Add the configured passes.
    shaderPipeline.passes.push_back(pass);
    shaderPipeline.passes.push_back(pass2);
    
    
This cheatsheet explains how to create, style, and manage dynamic text entities using your game's `TextSystem`.

---
## 1. Defining a Text Object

The foundation of the system is the `TextSystem::Text` C++ struct. You create an instance of this struct to define the appearance and content of your text before turning it into a game entity.

```cpp
text = {
    // The core string, with special formatting tags.
    .rawText = "[HEY!](rainbow;bump)[img](uuid=gear.png)",

    // --- Basic Properties ---
    .fontData = globals::fontData, // Font data loaded globally
    .fontSize = 50.0f,

    // --- Layout Properties ---
    .wrapEnabled = false,
    .alignment = TextSystem::Text::Alignment::LEFT,
    .wrapMode = TextSystem::Text::WrapMode::WORD
};
```

* **`rawText`**: The most important property. It contains the string to be displayed, along with special tags for styling and effects.
* **UTF-8 Support**: The system handles UTF-8 characters, allowing for languages like Korean (`"[안녕하세요]"`) to be used seamlessly with effects.

---
## 2. Rich Text Tagging

The system's power comes from its BBCode-style tagging within the `rawText` string. This allows you to apply effects, embed images, or change colors on a per-character or per-word basis.

**Syntax:** `[Text To Display](tag1=value;tag2;...)`

| Tag Syntax Example | Description |
| :--- | :--- |
| `[Hello](color=red)` | Applies a static color. |
| `[World](rainbow)` | Applies a dynamic, cycling rainbow color effect. |
| `[Shake!](shake=2,2)` | Applies a shake animation with a given x/y intensity. |
| `[Bump](bump)` | Applies a "bump" or "pop" animation. |
| `[img](uuid=gear.png;scale=0.8)` | **Embeds an Image:** Renders an image from the sprite atlas directly inside the text flow. |
| `[안녕하세요](rotate=2.0,5;float)` | **Chaining:** Multiple effects can be chained together by separating them with a semicolon. |

---
## 3. Creating and Managing the Text Entity

Once your `Text` object is configured, you create a live entity in the world that the text system will manage and render.

* **Entity Creation**:
    ```cpp
    // Creates the entity and its character children.
    textEntity = TextSystem::Functions::createTextEntity(text, x_pos, y_pos);
    ```
* **Applying Effects Programmatically**: You can add or change effects on a live text entity after it has been created.
    ```cpp
    // Removes all existing effects.
    TextSystem::Functions::clearAllEffects(textEntity);
    // Adds new effects to all characters in the string.
    TextSystem::Functions::applyGlobalEffects(textEntity, "pop=0.4,0.1,out;");
    ```

---
## 4. Advanced: Dynamic Content with Callbacks

Your text system uses a powerful callback-driven design to handle dynamic content and reactive layouts automatically.

### Dynamic Text Content

The `get_value_callback` allows the displayed text to be driven by an external C++ variable, decoupling the UI from the game state.

* **How it works**:
    1.  You assign a lambda to `text.get_value_callback`.
    2.  This lambda should return the string you want to display.
    3.  The text system will automatically call this function to get the most up-to-date string, re-parsing and re-rendering the text entity whenever the underlying value changes.
* **Example**:
    ```cpp
    // In C++, randomStringText is a global variable.
    text.get_value_callback = []() {
        return randomStringText; // The text entity will always display the current value of this variable.
    };

    // Elsewhere, a timer changes the variable, and the text updates automatically.
    timer::TimerSystem::timer_every(5.f, [](...) {
        randomStringText = random_utils::random_element(randomStringTextList);
    });
    ```

### Reacting to Changes

The `onStringContentUpdatedViaCallback` is a hook that fires whenever the text content changes, allowing you to run logic like resizing the text's container.

* **How it works**:
    1.  Assign a lambda to `text.onStringContentUpdatedViaCallback`.
    2.  This lambda receives the `textEntity` as an argument.
    3.  It's the perfect place to run layout-related code.
* **Example**:
    ```cpp
    // This function will run automatically whenever the text content changes.
    text.onStringContentUpdatedViaCallback = [](entt::entity textEntity) {
        // Get the text's parent/master entity.
        auto& role = globals::getRegistry().get<transform::InheritedProperties>(textEntity);
        auto& masterTransform = globals::getRegistry().get<transform::Transform>(role.master);

        // Automatically resize the text to fit its container.
        TextSystem::Functions::resizeTextToFit(textEntity, masterTransform.getActualW(), masterTransform.getActualH());
    };
    