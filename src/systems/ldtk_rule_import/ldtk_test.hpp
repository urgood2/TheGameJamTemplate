#pragma once

#include "raylib.h"
#include "ldtkimport/include/ldtkimport/LdtkDefFile.hpp"
#include "ldtkimport/include/ldtkimport/Level.h"

namespace ldtk_test {
    extern Color bgColor;
    extern ldtkimport::Level level;

    struct TileSetImage;

    struct LdtkAssets;

    extern auto updateAndDrawLDTKTest(float deltaTime) -> void;

    extern bool initLDTKTest();

}