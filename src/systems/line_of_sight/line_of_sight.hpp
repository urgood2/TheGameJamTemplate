#pragma once
#include <functional>
#include <entt/entt.hpp>

extern auto initLineOfSight(entt::registry& registry) -> void;
extern auto initLineOfSight() -> void;

namespace los
{
    class LevelPoint
    {
    public:
        int X, Y;
        LevelPoint(int x, int y) : X(x), Y(y) {}
    };

    /// <param name="blocksLight">A function that accepts the X and Y coordinates of a tile and determines whether the
    /// given tile blocks the passage of light. The function must be able to accept coordinates that are out of bounds.
    /// </param>
    /// <param name="setVisible">A function that sets a tile to be visible, given its X and Y coordinates. The function
    /// must ignore coordinates that are out of bounds.
    /// </param>
    /// <param name="getDistance">A function that takes the X and Y coordinate of a point where X >= 0,
    /// Y >= 0, and X >= Y, and returns the distance from the point to the origin (0,0).
    /// </param>
    class MyVisibility
    {
    public:
        using FuncBlocksLight = std::function<bool(int, int)>;
        using ActionSetVisible = std::function<void(int, int)>;
        using FuncGetDistance = std::function<int(int, int)>;

    private:
        FuncBlocksLight _blocksLight;
        ActionSetVisible _setVisible;
        FuncGetDistance GetDistance;

        // REVIEW: done
        // REVIEW: done
        struct Slope
        { // represents the slope Y/X as a rational number
            unsigned X, Y;
            Slope(unsigned y, unsigned x) : X(x), Y(y) {}

            bool Greater(unsigned y, unsigned x) const { return Y * x > X * y; }         // this > y/x
            bool GreaterOrEqual(unsigned y, unsigned x) const { return Y * x >= X * y; } // this >= y/x
            bool Less(unsigned y, unsigned x) const { return Y * x < X * y; }            // this < y/x
            // bool LessOrEqual(uint32_t y, uint32_t x) const { return Y * x <= X * y; } // this <= y/x
        };

    public:
        MyVisibility(FuncBlocksLight blocksLight, ActionSetVisible setVisible, FuncGetDistance getDistance);

        // REVIEW: done
        void Compute(const LevelPoint &origin, int rangeLimit);

    private:
        void
        Compute(unsigned octant, LevelPoint origin, int rangeLimit, unsigned x, Slope top, Slope bottom);

        bool BlocksLight(unsigned x, unsigned y, unsigned octant, const LevelPoint &origin);

        void SetVisible(unsigned x, unsigned y, unsigned octant, const LevelPoint &origin);
    };

}
