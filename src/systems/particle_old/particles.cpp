#include "raylib.h"
#include <stdlib.h> // Required for: malloc(), free()
#include <math.h>   // Required for: sinf(), cosf()
#include "particles.hpp"
// #include "entities/components.hpp"

#include "../../util/utilities.hpp"

#if defined(_WIN32)
#define NOGDI  // All GDI defines and routines
#define NOUSER // All USER defines and routines
#endif

#include "spdlog/spdlog.h"

#if defined(_WIN32) // raylib uses these names as function parameters
#undef near
#undef far
#endif

#include "raygui.h"
#include "fmt/core.h"
// #include "GL/gl.h"          // OpenGL library

#if defined(PLATFORM_DESKTOP) || defined(PLATFORM_DESKTOP_SDL)
#if defined(GRAPHICS_API_OPENGL_ES2)
#include "glad_gles2.h" // Required for: OpenGL functionality
#define glGenVertexArrays glGenVertexArraysOES
#define glBindVertexArray glBindVertexArrayOES
#define glDeleteVertexArrays glDeleteVertexArraysOES
#define GLSL_VERSION 100
#else
#if defined(__APPLE__)
#define GL_SILENCE_DEPRECATION // Silence Opengl API deprecation warnings
#include <OpenGL/gl3.h>        // OpenGL 3 library for OSX
#include <OpenGL/gl3ext.h>     // OpenGL 3 extensions library for OSX
#else
#include "external/glad.h" // Required for: OpenGL functionality
#endif
#define GLSL_VERSION 330
#endif
#else                  // PLATFORM_ANDROID, PLATFORM_WEB
#include <GLES2/gl2.h> // OpenGL ES 2.0 library
#include <GLES2/gl2ext.h>
#define GLSL_VERSION 100
#endif

#include "rlgl.h"    // Required for: rlDrawRenderBatchActive(), rlGetMatrixModelview(), rlGetMatrixProjection()
#include "raymath.h" // Required for: MatrixMultiply(), MatrixToFloat()
#include <stdlib.h>

#define MAX_PARTICLES 10000
#define MAX_EMITTERS 200
#define MAX_TEXTURES 3

namespace particle_system
{

// opengl 3.3
#ifndef __EMSCRIPTEN__
    const char *vertexShaderSource = R"(
    #version 330

    uniform mat4 mvp;
    in vec3 vertexPosition;
    in vec4 vertexColor;
    in int vertexTexIndex;
    in float vertexScale;
    in float vertexRotation; // in degrees

    out vec4 fragColor;
    flat out float rotationAngle;
    flat out int fragTexIndex;

    void main()
    {
        // Convert rotation from degrees to radians
        float rotationRadians = radians(vertexRotation);
        
        rotationAngle = rotationRadians;

        // Scale the vertex position
        vec3 scaledPosition = vertexPosition;
        
        // Apply the model-view-projection matrix
        vec4 pos = mvp * vec4(scaledPosition, 1.0);
        gl_Position = pos;
        gl_PointSize = 10.0 * vertexScale; // Adjust point size based on scale

        // Output the vertex color and texture index to the fragment shader
        fragColor = vertexColor;
        fragTexIndex = int(vertexTexIndex);

        // Debugging outputs (optional, remove if not needed)
        // These will be optimized out by the compiler if not used in the fragment shader
        // vec4 debugPosition = vec4(finalPosition, 1.0);
        // vec4 debugScaledPosition = vec4(scaledPosition, 1.0);
    }
)";

// GLSL 3.3 fragment shader
const char *fragmentShaderSource = R"(
    #version 330

    uniform sampler2D textures[3];

    in vec4 fragColor;
    
    flat in float rotationAngle;
    flat in int fragTexIndex;

    out vec4 finalColor;

    void main()
    {
        // Calculate the center of the point
        vec2 center = vec2(0.5, 0.5);
        
        // Translate coordinates to the center
        vec2 coord = gl_PointCoord - center;

        // Calculate the rotation matrix
        float cosAngle = cos(rotationAngle);
        float sinAngle = sin(rotationAngle);
        mat2 rotationMatrix = mat2(
            cosAngle, -sinAngle,
            sinAngle, cosAngle
        );

        // Apply the rotation matrix
        coord = rotationMatrix * coord;

        // Translate coordinates back
        coord += center;

        // Sample the texture with the rotated coordinates
        finalColor = texture(textures[fragTexIndex], coord) * fragColor;
    }

)";

#else
    // GLSL ES 2.0 fragment shader
    const char *vertexShaderSource = R"(

    precision mediump float;

    uniform mat4 mvp;
    attribute vec3 vertexPosition;
    attribute vec4 vertexColor;
    attribute float vertexTexIndex;
    attribute float vertexScale;
    attribute float vertexRotation;

    varying vec4 fragColor;
    varying float fragTexIndex;

    void main()
    {
        // Scale the vertex position
        vec3 scaledPosition = vertexPosition * vertexScale;

        // Apply rotation around the Z-axis
        float cosAngle = cos(vertexRotation);
        float sinAngle = sin(vertexRotation);
        vec3 rotatedPosition = vec3(
            cosAngle * scaledPosition.x - sinAngle * scaledPosition.y,
            sinAngle * scaledPosition.x + cosAngle * scaledPosition.y,
            scaledPosition.z
        );

        vec4 pos = mvp * vec4(rotatedPosition, 1.0);
        gl_Position = pos;
        gl_PointSize = 10.0 * vertexScale; // Adjust point size based on scale

        fragColor = vertexColor;
        fragTexIndex = vertexTexIndex;
    }
    )";

    // GLSL ES 2.0 fragment shader
    const char *fragmentShaderSource = R"(
    precision mediump float;

    uniform sampler2D textures[3];

    varying vec4 fragColor;
    varying float fragTexIndex;
    varying vec2 pointCoord;

    void main()
    {
        int texIndex = int(fragTexIndex);
        // vec2 coord = pointCoord * 0.5 + 0.5; // Map pointCoord from [-1, 1] to [0, 1]
        vec2 coord = gl_PointCoord; // Automatically provided texture coordinates
        vec4 texColor;

        if (texIndex == 0)
            texColor = texture2D(textures[0], coord);
            // texColor = vec4(coord.x, coord.y, .0, 1.0); // debugging
        else if (texIndex == 1)
            texColor = texture2D(textures[1], coord);
            // texColor = vec4(coord.x, coord.y, .0, 1.0); // debugging
        else
            texColor = texture2D(textures[2], coord);
            // texColor = vec4(coord.x, coord.y, .0, 1.0); // debugging

        gl_FragColor = texColor * fragColor;
    }
)";

#endif

    // #else
    //     // GLSL ES 2.0 vertex shader
    //     // GLSL ES 2.0 vertex shader
    //     const char *vertexShaderSource = R"(
    //     #version 330

    //     uniform mat4 mvp;
    //     in vec3 vertexPosition;
    //     in vec4 vertexColor;
    //     in float vertexTexIndex;

    //     out vec4 fragColor;
    //     flat out int fragTexIndex;

    //     void main()
    //     {
    //         vec4 pos = mvp * vec4(vertexPosition, 1.0);
    //         gl_Position = pos;
    //         gl_PointSize = 10.0;

    //         fragColor = vertexColor;
    //         fragTexIndex = int(vertexTexIndex);
    //     }

    // )";

    //     // GLSL ES 2.0 fragment shader
    //     const char *fragmentShaderSource = R"(
    //     #version 330

    //     uniform sampler2D textures[3];

    //     in vec4 fragColor;
    //     flat in int fragTexIndex;

    //     out vec4 finalColor;

    //     void main()
    //     {
    //         finalColor = texture(textures[fragTexIndex], gl_PointCoord) * fragColor;
    //     }

    // )";
    // #endif
    GLuint vao = 0;
    GLuint vbo = 0;
    GLuint ebo = 0; // Element buffer object

    Shader shader;
    Camera particleCamera;

    int currentTimeLoc, mvpLoc;

    Texture2D textures[MAX_TEXTURES]; // Array to hold multiple textures
    int texLoc[MAX_TEXTURES];         // Locations of the texture samplers in the shader
    Emitter emitters[MAX_EMITTERS];
    Particle particles[MAX_PARTICLES];
    unsigned int indices[MAX_PARTICLES];
    int livingParticleCount = 0;

    int vertexPosLocation = 0;
    int vertexColorLocation = 3;
    int vertexTexIndexLocation = 1;
    int vertexScaleLocation = -1;
    int vertexRotationLocation = -1;

    // convenience function to check for OpenGL errors
    GLenum glCheckError_(const char *file, int line)
    {
        GLenum errorCode;
        while ((errorCode = glGetError()) != GL_NO_ERROR)
        {
            std::string error;
            switch (errorCode)
            {
            case GL_INVALID_ENUM:
                error = "INVALID_ENUM";
                break;
            case GL_INVALID_VALUE:
                error = "INVALID_VALUE";
                break;
            case GL_INVALID_OPERATION:
                error = "INVALID_OPERATION";
                break;
// not for apple or web
#if !defined(__APPLE__) && !defined(__EMSCRIPTEN__)
            case GL_STACK_OVERFLOW:
                error = "STACK_OVERFLOW";
                break;
            case GL_STACK_UNDERFLOW:
                error = "STACK_UNDERFLOW";
                break;
#endif
            case GL_OUT_OF_MEMORY:
                error = "OUT_OF_MEMORY";
                break;
            case GL_INVALID_FRAMEBUFFER_OPERATION:
                error = "INVALID_FRAMEBUFFER_OPERATION";
                break;
            }
            spdlog::error("OpenGL error {}: {} | {} ({})", errorCode, error, file, line);
        }
        return errorCode;
    }
#define glCheckError() glCheckError_(__FILE__, __LINE__)

    Vector3 GetWorldCoordinates(Vector2 screenPos, Camera camera)
    {
        Ray ray = GetMouseRay(screenPos, camera);

        // Assuming a plane at y = 0
        float groundY = 0.0f;
        float distance = (groundY - ray.position.y) / ray.direction.y;

        Vector3 worldPos = Vector3Add(ray.position, Vector3Scale(ray.direction, distance));

        return worldPos;
    }

    /**
     * Sets the lifetime of the emitter at the specified index.
     *
     * @param index The index of the emitter.
     * @param newLifetime The new lifetime value to set.
     */
    void setEmitterLifetime(int index, float newLifetime)
    {
        if (index >= 0 && index < MAX_EMITTERS)
        {
            emitters[index].lifetime = newLifetime;
        }
    }
    /**
     * Adds a new emitter to the list of emitters.
     *
     * @param newEmitter The emitter to be added.
     * @return The index of the newly added emitter, or -1 if no available slot is found.
     */
    int addEmitter(Emitter newEmitter)
    {

        for (int i = 0; i < MAX_EMITTERS; i++)
        {
            if (emitters[i].valid == false) // Assuming an emission rate of 0 means the emitter is inactive
            {
                spdlog::debug("Adding new emitter at index {}", i);
                emitters[i] = newEmitter;
                emitters[i].timer = 0.0f; // Reset the timer
                emitters[i].valid = true; // Mark the emitter as valid
                return i;                 // Return the index of the newly added emitter
            }
        }
        return -1; // No available slot for a new emitter
    }

    void setEmitterData(int index, Emitter newEmitter)
    {
        if (index >= 0 && index < MAX_EMITTERS)
        {
            emitters[index] = newEmitter;
            emitters[index].timer = 0.0f; // Reset the timer
        }
    }

    void clearAllEmitters()
    {
        for (int i = 0; i < MAX_EMITTERS; i++)
        {
            emitters[i].valid = false;
        }
    }

    void clearAllParticles()
    {
        for (int i = 0; i < MAX_PARTICLES; i++)
        {
            particles[i].life = 0.0f;
        }
    }

    void setEmitterLocation(int index, Vector3 newPosition)
    {
        if (index >= 0 && index < MAX_EMITTERS)
        {
            emitters[index].position = newPosition;
        }
    }

    /**
     * @brief Removes an emitter at the specified index.
     *
     * @param index The index of the emitter to remove.
     *
     * @details This function disables the emitter at the specified index by setting its emission rate to 0 and its lifetime to 0.0f.
     *          This ensures that the emitter is fully deactivated and no longer emits particles.
     *          The index should be a valid index within the range of emitters.
     */
    void removeEmitter(int index)
    {
        if (index >= 0 && index < MAX_EMITTERS)
        {
            emitters[index].emissionRate = 0; // Disable the emitter
            emitters[index].lifetime = 0.0f;  // Ensure the emitter is fully deactivated
            emitters[index].valid = false;    // Mark the emitter as invalid
        }
    }

    Emitter getEmitterData(int index)
    {
        if (index >= 0 && index < MAX_EMITTERS)
        {
            return emitters[index];
        }
        else
        {
            spdlog::error("Invalid emitter index: {}", index);
            return Emitter{};
        }
    }

    auto setEmitterEmissionRate(int index, float newRate) -> void
    {
        if (index >= 0 && index < MAX_EMITTERS)
        {
            emitters[index].emissionRate = newRate;
        }
    }

    void init()
    {

        shader = LoadShaderFromMemory(vertexShaderSource, fragmentShaderSource);

        currentTimeLoc = GetShaderLocation(shader, "currentTime");
        mvpLoc = GetShaderLocation(shader, "mvp");

        // Load multiple textures
        textures[0] = LoadTexture(util::getRawAssetPathNoUUID("graphics/particles/particle.png").c_str());
        textures[1] = LoadTexture(util::getRawAssetPathNoUUID("graphics/particles/particle_circle.png").c_str());
        textures[2] = LoadTexture(util::getRawAssetPathNoUUID("graphics/particles/particle_square.png").c_str());
        

        for (int i = 0; i < MAX_TEXTURES; i++)
        {
            SetTextureFilter(textures[i], TEXTURE_FILTER_POINT);
        }

        // Retrieve and store uniform locations for texture samplers
        for (int i = 0; i < MAX_TEXTURES; i++) {
            std::string uniformName = "textures[" + std::to_string(i) + "]";
            texLoc[i] = glGetUniformLocation(shader.id, uniformName.c_str());
            if (texLoc[i] == -1) {
                spdlog::error("Uniform location not found for: {}", uniformName);
            } else {
                spdlog::debug("Uniform location for {}: {}", uniformName, texLoc[i]);
            }

            

        }

        // Verify attribute locations

        GLint maxVertexAttribs;
        glGetIntegerv(GL_MAX_VERTEX_ATTRIBS, &maxVertexAttribs);

        int posAttrib = glGetAttribLocation(shader.id, "vertexPosition");
        int colorAttrib = glGetAttribLocation(shader.id, "vertexColor");
        int texIndexAttrib = glGetAttribLocation(shader.id, "vertexTexIndex");
        int vertexScaleAttrib = glGetAttribLocation(shader.id, "vertexScale");
        int vertexRotationAttrib = glGetAttribLocation(shader.id, "vertexRotation");

        vertexPosLocation = posAttrib;
        vertexColorLocation = colorAttrib;
        vertexTexIndexLocation = texIndexAttrib;
        vertexScaleLocation = vertexScaleAttrib;
        vertexRotationLocation = vertexRotationAttrib;

        if (vertexPosLocation >= maxVertexAttribs || vertexColorLocation >= maxVertexAttribs || vertexTexIndexLocation >= maxVertexAttribs || vertexScaleLocation >= maxVertexAttribs || vertexRotationLocation >= maxVertexAttribs)
        {
            spdlog::error("Attribute locations exceed the maximum number of vertex attributes: {}", maxVertexAttribs);
        }

        if (vertexPosLocation == -1 || vertexColorLocation == -1 || vertexTexIndexLocation == -1 || vertexScaleLocation == -1 || vertexRotationLocation == -1)
        {
            spdlog::error("Failed to get attribute locations: pos: {}, color: {}, texIndex: {}", vertexPosLocation, vertexColorLocation, vertexTexIndexLocation);
        }

        spdlog::debug("Attribute locations: pos: {}, color: {}, texIndex: {}, scale: {}, rotation: {}", vertexPosLocation, vertexColorLocation, vertexTexIndexLocation, vertexScaleLocation, vertexRotationLocation);

        for (int i = 0; i < MAX_EMITTERS; i++)
        {
            emitters[i] = Emitter{};
            emitters[i].valid = false; // Initialize all emitters as invalid
        }

        // Initialize particles
        for (int i = 0; i < MAX_PARTICLES; i++)
        {
            particles[i].life = 0.0f; // Particles start inactive
        }

        // OpenGL initialization
        glGenBuffers(1, &vbo);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, MAX_PARTICLES * sizeof(Particle), particles, GL_DYNAMIC_DRAW);

        glGenBuffers(1, &ebo);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, MAX_PARTICLES * sizeof(unsigned int), indices, GL_DYNAMIC_DRAW);
        // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);


        // vao (not supported by web)
#ifndef __EMSCRIPTEN__
        glGenVertexArrays(1, &vao);
        glBindVertexArray(vao);

        glEnableVertexAttribArray(vertexPosLocation);
        glCheckError();
        glVertexAttribPointer(vertexPosLocation, 3, GL_FLOAT, GL_FALSE, sizeof(Particle), (void *)offsetof(Particle, position));
        glCheckError();

        glEnableVertexAttribArray(vertexColorLocation);
        glCheckError();
        glVertexAttribPointer(vertexColorLocation, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(Particle), (void *)offsetof(Particle, color));
        glCheckError();

        glEnableVertexAttribArray(vertexTexIndexLocation);
        glCheckError();
        glVertexAttribPointer(vertexTexIndexLocation, 1, GL_INT, GL_FALSE, sizeof(Particle), (void *)offsetof(Particle, textureIndex));
        glCheckError();

        glEnableVertexAttribArray(vertexScaleLocation);
        glCheckError();
        glVertexAttribPointer(vertexScaleLocation, 1, GL_FLOAT, GL_FALSE, sizeof(Particle), (void *)offsetof(Particle, scale));
        glCheckError();

        glEnableVertexAttribArray(vertexRotationLocation);
        glCheckError();
        glVertexAttribPointer(vertexRotationLocation, 1, GL_FLOAT, GL_FALSE, sizeof(Particle), (void *)offsetof(Particle, rotation));
        glCheckError();

#endif
        // glEnable(GL_POINT_SPRITE);
        // glEnable(GL_PROGRAM_POINT_SIZE);
#ifndef __EMSCRIPTEN__
        glEnable(GL_PROGRAM_POINT_SIZE);
#endif

        // Enable blending for transparency
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        // Disable depth writing for particles
        glDepthMask(GL_FALSE);

        glCheckError();
    }

    void updateAndDraw(float dt)
    {
        livingParticleCount = 0; // Reset living particle count

        // for (int j = 0; j < MAX_PARTICLES; j++) {
        //     if (particles[j].life > 0.0f) {
        //         spdlog::debug("Particle {}: Texture Index = {}", j, particles[j].textureIndex);
        //     }
        // }

        // Update all emitters and emit particles
        for (int i = 0; i < MAX_EMITTERS; i++)
        {
            emitters[i].timer += dt;

            if (emitters[i].valid && (emitters[i].emissionRate <= 0 || emitters[i].lifetime <= 0.0f))
            {
                continue;
            }

            // Skip if emitter not valid or emission rate is 0 or dead
            if (!emitters[i].valid || emitters[i].emissionRate <= 0 || emitters[i].lifetime <= 0.0f)
            {
                continue;
            }

            if (emitters[i].timer >= 1.0f / emitters[i].emissionRate)
            {
                emitters[i].timer = 0.0f;

                // Find an inactive particle
                for (int j = 0; j < MAX_PARTICLES; j++)
                {
                    if (particles[j].life <= 0.0f)
                    {
                        particles[j].position = emitters[i].position;

                        // Emission angle calculation
                        float emissionAngle = emitters[i].emissionAngleMin + (emitters[i].emissionAngleMax - emitters[i].emissionAngleMin) * ((float)GetRandomValue(0, 100) / 100.0f);
                        float radians = DEG2RAD * emissionAngle;
                        float speedFactor = 0.5f + ((float)GetRandomValue(0, 50) / 100.0f) * 100.0f; // Scale factor between 0.5 and 1.0 x 100
                        float speed = emitters[i].startSpeed * speedFactor;
                        particles[j].velocity = Vector3{
                            cosf(radians) * speed,
                            sinf(radians) * speed,
                            // GetRandomValue(-100, 100) * speed,
                            // GetRandomValue(-100, 100) * speed,
                            0};
                        // float speed = emitters[i].startSpeed * ((float)GetRandomValue(0, 100) / 100.0f);
                        // particles[j].velocity = Vector3{
                        //     GetRandomValue(-100, 100) * speed,
                        //     GetRandomValue(-100, 100) * speed,
                        //     0};
                            
                        float rotationSpeed = emitters[i].rotationSpeedMin + (emitters[i].rotationSpeedMax - emitters[i].rotationSpeedMin) * ((float)GetRandomValue(0, 100) / 100.0f);
                        particles[j].rotationSpeed = rotationSpeed;

                        // Using gravity?
                        if (emitters[i].useGravity)
                        {
                            // Combine gravity with the provided acceleration
                            particles[j].acceleration = Vector3{
                                emitters[i].startAcceleration,
                                emitters[i].startAcceleration + 98.0f,
                                0};
                        }
                        else
                        {
                            particles[j].acceleration = Vector3{
                                emitters[i].startAcceleration,
                                emitters[i].startAcceleration,
                                0};
                        }

                        particles[j].color = emitters[i].startColor;
                        particles[j].life = emitters[i].particleLifetime; // Set particle lifetime
                        particles[j].age = 0.0f;
                        particles[j].textureIndex = emitters[i].textureIndex; // Assign particle the emitter's texture index
                        particles[j].startAlpha = emitters[i].startAlpha;
                        particles[j].endAlpha = emitters[i].endAlpha;
                        
                        particles[j].startColor = emitters[i].startColor;
                        particles[j].endColor = emitters[i].endColor;

                        // Initialize scale and rotation
                        particles[j].scale = emitters[i].startScale;
                        particles[j].rotation = 0.0f;
                        particles[j].rotationSpeed = ((float)GetRandomValue(-100, 100) / 100.0f) * 180.0f; // Random rotation speed between -360 and 360 degrees per second

                        break;
                    }
                }
            }

            // Reduce the lifetime of emitters and deactivate if necessary
            emitters[i].lifetime -= dt;
            if (emitters[i].lifetime <= 0.0f)
            {
                emitters[i].emissionRate = 0; // Stop emission
                // emitters[i].valid = false;    // Mark the emitter as invalid
            }
        }

        // Update particles
        for (int i = 0; i < MAX_PARTICLES; i++)
        {
            if (particles[i].life > 0.0f)
            {
                particles[i].age += dt;
                particles[i].life -= dt;

                // Update velocity based on acceleration
                particles[i].velocity = Vector3Add(particles[i].velocity, Vector3Scale(particles[i].acceleration, dt));

                // Update position based on velocity
                particles[i].position = Vector3Add(particles[i].position, Vector3Scale(particles[i].velocity, dt));

                // Update rotation
                particles[i].rotation += particles[i].rotationSpeed * dt;

                // Update scale
                float lifeRatio = particles[i].age / particles[i].life;
                particles[i].scale = particles[i].startScale * (1.0f - lifeRatio) + particles[i].endScale * lifeRatio;

                // Update color and alpha based on age
                particles[i].color.r = (unsigned char)fmin(fmax(particles[i].endColor.r * lifeRatio + particles[i].startColor.r * (1.0f - lifeRatio), 0), 255);
                particles[i].color.g = (unsigned char)fmin(fmax(particles[i].endColor.g * lifeRatio + particles[i].startColor.g * (1.0f - lifeRatio), 0), 255);
                particles[i].color.b = (unsigned char)fmin(fmax(particles[i].endColor.b * lifeRatio + particles[i].startColor.b * (1.0f - lifeRatio), 0), 255);
                particles[i].color.a = (unsigned char)fmin(fmax((particles[i].endAlpha * 255.0f) * lifeRatio + (particles[i].startAlpha * 255.0f) * (1.0f - lifeRatio), 0), 255);

                if (particles[i].life <= 0.0f)
                {
                    particles[i].life = 0.0f; // Deactivate particle
                }
                else
                {
                    indices[livingParticleCount++] = i; // Add index of living particle
                }
            }
        }

        // Update OpenGL buffer with the new positions and colors
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glCheckError();
        glBufferSubData(GL_ARRAY_BUFFER, 0, MAX_PARTICLES * sizeof(Particle), particles);   
#ifndef __EMSCRIPTEN__
        // glBindBuffer(GL_ARRAY_BUFFER, 0); // adding for consistency, not sure why this is needed
#endif

        // Update index buffer with living particle indices
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
        glCheckError();
        glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, 0, livingParticleCount * sizeof(unsigned int), indices);
#ifndef __EMSCRIPTEN__
        // glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0); // adding for consistency, not sure why this is needed
#endif



        // Render
        rlMatrixMode(RL_PROJECTION);
        rlLoadIdentity();
        rlOrtho(0, (double)GetScreenWidth(), (double)GetScreenHeight(), 0, -1.0, 1.0); // Set the orthographic projection
        rlMatrixMode(RL_MODELVIEW);
        rlLoadIdentity();

        // Apply camera transformations
        rlTranslatef(globals::camera.offset.x, globals::camera.offset.y, 0.0f);
        rlScalef(globals::camera.zoom, globals::camera.zoom, 1.0f);
        rlTranslatef(-globals::camera.target.x, -globals::camera.target.y, 0.0f);

        rlDrawRenderBatchActive();
        glUseProgram(shader.id);
        glUniform1f(currentTimeLoc, GetTime());
        glCheckError();

        // Bind textures to texture units
        for (int i = 0; i < MAX_TEXTURES; i++)
        {
            glActiveTexture(GL_TEXTURE0 + i);
            glBindTexture(GL_TEXTURE_2D, textures[i].id);
            glUniform1i(texLoc[i], i);

            // spdlog::debug("Bound texture id {} to texture unit {} at uniform location {}", textures[i].id, i, texLoc[i]);
            glCheckError();
        }

        // the following not required for opengl 3.3
#ifdef __EMSCRIPTEN__

        glEnableVertexAttribArray(vertexPosLocation);
        glCheckError();
        // spdlog::info("vertexPosLocation: {}", vertexPosLocation);

        glVertexAttribPointer(vertexPosLocation, 3, GL_FLOAT, GL_FALSE, sizeof(Particle), (void *)offsetof(Particle, position));
        glCheckError();

        glEnableVertexAttribArray(vertexColorLocation);
        glCheckError();
        glVertexAttribPointer(vertexColorLocation, 4, GL_UNSIGNED_BYTE, GL_TRUE, sizeof(Particle), (void *)offsetof(Particle, color));
        glCheckError();

        glEnableVertexAttribArray(vertexTexIndexLocation);
        glCheckError();
        glVertexAttribPointer(vertexTexIndexLocation, 1, GL_INT, GL_FALSE, sizeof(Particle), (void *)offsetof(Particle, textureIndex));
        glCheckError();

        glEnableVertexAttribArray(vertexScaleLocation);
        glCheckError();
        glVertexAttribPointer(vertexScaleLocation, 1, GL_FLOAT, GL_FALSE, sizeof(Particle), (void *)offsetof(Particle, scale));
        glCheckError();

        glEnableVertexAttribArray(vertexRotationLocation);
        glCheckError();
        glVertexAttribPointer(vertexRotationLocation, 1, GL_FLOAT, GL_FALSE, sizeof(Particle), (void *)offsetof(Particle, rotation));
        glCheckError();

#endif

        // Render particles
        Matrix modelViewProjection = MatrixMultiply(rlGetMatrixModelview(), rlGetMatrixProjection());
        glUniformMatrix4fv(mvpLoc, 1, GL_FALSE, MatrixToFloat(modelViewProjection));
#ifndef __EMSCRIPTEN__
        // Bind vertex array object
        glBindVertexArray(vao);
#endif
        glCheckError();

        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
        glCheckError();

        // check buffer binding
        GLint currentElementArrayBuffer;
        glGetIntegerv(GL_ELEMENT_ARRAY_BUFFER_BINDING, &currentElementArrayBuffer);
        if (currentElementArrayBuffer == 0)
        {
            spdlog::error("No element array buffer is bound!");
            // Bind your element array buffer here
        }
        glDrawElements(GL_POINTS, livingParticleCount, GL_UNSIGNED_INT, 0);
#ifndef __EMSCRIPTEN__
        glBindVertexArray(0);
#endif
        glCheckError();

#ifdef __EMSCRIPTEN__
        // Disable vertex attributes after drawing (only for web, since it doesn't use vao)
        glDisableVertexAttribArray(vertexPosLocation);
        glDisableVertexAttribArray(vertexColorLocation);
        glDisableVertexAttribArray(vertexTexIndexLocation);
        glDisableVertexAttribArray(vertexScaleLocation);
        glDisableVertexAttribArray(vertexRotationLocation);

#endif

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        glUseProgram(0);


#ifndef __EMSCRIPTEN__
        // Unbind VAO (optional, good practice)
        // glBindVertexArray(0);
#endif

        glCheckError();

        // Undo camera transformations
        rlTranslatef(globals::camera.target.x, globals::camera.target.y, 0.0f);
        rlScalef(1.0f / globals::camera.zoom, 1.0f / globals::camera.zoom, 1.0f);
        rlTranslatef(-globals::camera.offset.x, -globals::camera.offset.y, 0.0f);
    }

    void unload()
    {
        // De-Initialization
        glDeleteBuffers(1, &ebo);
        glDeleteBuffers(1, &vbo);
#ifndef __EMSCRIPTEN__
        glDeleteVertexArrays(1, &vao);
#endif

        UnloadShader(shader); // Unload shader

        // Unload textures
        for (int i = 0; i < MAX_TEXTURES; i++)
        {
            UnloadTexture(textures[i]);
        }

        glCheckError();
    }

}