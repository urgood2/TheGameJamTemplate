#include "spine_raylib.hpp"
#include <vector>
#include "raylib.h"
#include "../../util/common_headers.hpp"

spine::SpineExtension *spine::getDefaultExtension() {
   return new spine::DefaultSpineExtension();
}


Texture2D spine_textures[MAX_TEXTURES]; // Fixed-size array for textures
size_t texture_count = 0;             // Current number of textures loaded

Texture2D* raylib_loadTexture(const char* path) {
    if (texture_count >= MAX_TEXTURES) {
        TraceLog(LOG_ERROR, "raylib_loadTexture: Maximum texture limit reached (%zu)", MAX_TEXTURES);
        return nullptr;
    }

    Texture2D texture = LoadTexture(path);

    // Check if texture was loaded successfully
    if (texture.id == 0) {
        TraceLog(LOG_ERROR, "raylib_loadTexture: Failed to load texture from path: %s", path);
        return nullptr;
    }

    // Add the texture to the array
    spine_textures[texture_count] = texture;
    return &spine_textures[texture_count++];
}

void raylib_unloadAllTextures() {
    for (size_t i = 0; i < texture_count; ++i) {
        UnloadTexture(spine_textures[i]);
    }
    texture_count = 0; // Reset the texture count
}



void MyTextureLoader::load(spine::AtlasPage &page, const spine::String &path) {
    Texture2D* texture = raylib_loadTexture(path.buffer());

    TraceLog(LOG_INFO, "MyTextureLoader::load: Loading texture from path: %s", path.buffer());

    if (!texture){
        return;
        TraceLog(LOG_ERROR, "MyTextureLoader::load: Failed to load texture from path: %s", path.buffer());
    }

    page.texture = texture;
    page.width = texture->width;
    page.height = texture->height;
}

void MyTextureLoader::unload(void *texture) {
    raylib_unloadAllTextures();
}

MyTextureLoader::MyTextureLoader() {}

MyTextureLoader::~MyTextureLoader() {}


// Container to temporarily store vertices
spine::Vector<Vertex> vertices;
// A single SkeletonRenderer instance (assuming rendering is performed single-threaded)
spine::SkeletonRenderer skeletonRenderer;

void drawSkeleton(spine::Skeleton &skeleton) {
    static bool hasWritten = false; // Tracks if the data has been written to a file

    spine::RenderCommand *command = skeletonRenderer.render(skeleton);
    rlDrawRenderBatchActive();
    rlDisableBackfaceCulling();

    // json outputJson; // To store vertex data in JSON format
    size_t commandIndex = 0;

    while (command) {
        Vertex vertex;
        float *positions = command->positions;
        float *uvs = command->uvs;
        uint32_t *colors = command->colors;
        uint16_t *indices = command->indices;
        Texture2D *texture = (Texture2D *)command->texture;

        // json commandJson; // JSON object for the current command
        // commandJson["texture_id"] = texture->id; // Store texture ID
        // json verticesJson = json::array(); // Array for vertex data
        // json indicesJson = json::array();  // Array for indices

        for (int i = 0, j = 0, n = command->numVertices * 2; i < n; ++i, j += 2) {
            vertex.x = positions[j];
            vertex.y = positions[j + 1];
            vertex.u = uvs[j];
            vertex.v = uvs[j + 1];
            vertex.color = colors[i];

            // Add vertex data to JSON
            // verticesJson.push_back({
            //     {"x", vertex.x},
            //     {"y", vertex.y},
            //     {"u", vertex.u},
            //     {"v", vertex.v},
            //     {"color", {
            //         {"r", (vertex.color >> 16) & 0xFF},
            //         {"g", (vertex.color >> 8) & 0xFF},
            //         {"b", vertex.color & 0xFF},
            //         {"a", (vertex.color >> 24) & 0xFF}
            //     }}
            // });

            vertices.add(vertex);
        }

        // // Add index data to JSON
        // for (int i = 0; i < command->numIndices; ++i) {
        //     indicesJson.push_back(indices[i]);
        // }

        // Populate the command JSON
        // commandJson["vertices"] = verticesJson;
        // commandJson["indices"] = indicesJson;
        // outputJson["commands"].push_back(commandJson);

        spine::BlendMode blendMode = command->blendMode; // Spine blend mode equals engine blend mode

        bool isXScaleNegative = skeleton.getScaleX() < 0;
        bool isYScaleNegative = skeleton.getScaleY() < 0;

        engine_drawMesh(vertices.buffer(), indices, command->numIndices, *texture, blendMode, isXScaleNegative, isYScaleNegative);
        vertices.clear();
        command = command->next;
        ++commandIndex;
    }

    rlEnableBackfaceCulling();

        // // Write to file if this is the first call
        // if (!hasWritten) {
        //     std::ofstream file("skeleton_data.json");
        //     if (file.is_open()) {
        //         file << outputJson.dump(4); // Write JSON with 4 spaces for indentation
        //         file.close();
        //         TraceLog(LOG_INFO, "Skeleton data written to skeleton_data.json");
        //     } else {
        //         TraceLog(LOG_ERROR, "Failed to open skeleton_data.json for writing");
        //     }
        //     hasWritten = true; // Ensure we only write the file once
        // }
}

//TODO: can't figure out
// static void drawTriangleVert(ImDrawVert& idx_vert)
// {
//     Color* c;
//     c = (Color*)&idx_vert.col;
//     rlColor4ub(c->r, c->g, c->b, c->a);
//     rlTexCoord2f(idx_vert.uv.x, idx_vert.uv.y);
//     rlVertex2f(idx_vert.pos.x, idx_vert.pos.y);
// }



void engine_drawMesh(Vertex* vertices, unsigned short* indices, size_t numIndices, Texture2D texture, spine::BlendMode blendMode, bool isXScaleNegative = false, bool isYScaleNegative = false) {
    if (numIndices % 3 != 0) {
        TraceLog(LOG_ERROR, "engine_drawMesh: numIndices must be divisible by 3");
        return;
    }

    if (texture.id == 0) {
        TraceLog(LOG_ERROR, "engine_drawMesh: Texture is not ready");
        return;
    }

    rlDrawRenderBatchActive(); // Ensure the batch is sent to the GPU

    rlBegin(RL_TRIANGLES);
    rlDisableBackfaceCulling(); // Disable culling for debugging
    rlSetTexture(texture.id);
    rlEnableColorBlend();
    rlSetBlendMode(BLEND_ALPHA);

    for (size_t i = 0; i < numIndices; i += 3) {
        // Fetch indices of the triangle
        unsigned short idx0 = indices[i];
        unsigned short idx1 = indices[i + 1];
        unsigned short idx2 = indices[i + 2];

        // Get vertices from the indices
        Vertex v0 = vertices[idx0];
        Vertex v1 = vertices[idx1];
        Vertex v2 = vertices[idx2];

        // Swap v0 and v1 if isXScaleNegative is true
        if (isXScaleNegative == false) {
            std::swap(v0, v1);
        }
        if (isYScaleNegative == false) {
            std::swap(v0, v1);
        }

        // Draw the triangle
        rlColor4ub((v0.color >> 16) & 0xFF, (v0.color >> 8) & 0xFF, v0.color & 0xFF, (v0.color >> 24) & 0xFF);
        rlTexCoord2f(v0.u, v0.v);
        rlVertex2f(v0.x, v0.y);

        rlColor4ub((v1.color >> 16) & 0xFF, (v1.color >> 8) & 0xFF, v1.color & 0xFF, (v1.color >> 24) & 0xFF);
        rlTexCoord2f(v1.u, v1.v);
        rlVertex2f(v1.x, v1.y);

        rlColor4ub((v2.color >> 16) & 0xFF, (v2.color >> 8) & 0xFF, v2.color & 0xFF, (v2.color >> 24) & 0xFF);
        rlTexCoord2f(v2.u, v2.v);
        rlVertex2f(v2.x, v2.y);
    }

    rlEnd();
    rlSetTexture(0); // Unbind the texture
    // rlEnableBackfaceCulling(); // Re-enable culling
}

