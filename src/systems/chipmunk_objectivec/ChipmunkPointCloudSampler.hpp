// PointCloudSamplerWrappers.cpp
// Port of ChipmunkPointCloudSampler (Objective-C) to C++

#include <chipmunk/chipmunk.h>
#include <cstdlib>

// Internal struct matching DeformPoint in ObjC
struct DeformPoint {
    cpVect pos;
    cpFloat radius;
    cpFloat fuzz;
};

// Compute the bounding box for a point (used by spatial index)
static cpBB PointBB(DeformPoint* p) {
    return cpBBNew(
        p->pos.x - p->radius,
        p->pos.y - p->radius,
        p->pos.x + p->radius,
        p->pos.y + p->radius
    );
}

// Softness-based fuzz function
static inline cpFloat FuzzSample(const cpVect& v, const DeformPoint& p) {
    cpFloat d2 = cpvdistsq(v, p.pos);
    cpFloat r = p.radius;
    if(d2 < r*r) {
        cpFloat d = cpfsqrt(d2);
        cpFloat soft = p.fuzz;
        cpFloat frac = (r - d) / (soft * r);
        return 1.0f - cpfclamp01(frac);
    }
    return 1.0f;
}

// Spatial index query callback multiplies density
static void PointQuery(cpVect* v, DeformPoint* p, cpCollisionID, cpFloat* density) {
    *density *= FuzzSample(*v, *p);
}

// Sampling function for marching (could be passed to cpMarch)
static cpFloat PointCloudSample(void* userData, cpVect pos) {
    // userData is a PointCloudSampler*
    PointCloudSampler* sampler = static_cast<PointCloudSampler*>(userData);
    cpFloat density = 1.0f;
    cpBB bb = cpBBNewForCircle(pos, 0.0f);
    cpSpatialIndexQuery(sampler->_index, &pos, bb,
                        reinterpret_cast<cpSpatialIndexQueryFunc>(PointQuery),
                        &density);
    return density;
}

// C++ wrapper for ChipmunkPointCloudSampler
class PointCloudSampler {
public:
    // Initializes with given cell size (grid resolution for spatial hash)
    explicit PointCloudSampler(cpFloat cellSize)
    : _cellSize(cellSize)
    {
        // Create a spatial hash: cellSize, initial count=1000, bbox func PointBB
        _index = cpSpaceHashNew(cellSize, 1000,
                                reinterpret_cast<cpSpatialIndexBBFunc>(PointBB),
                                nullptr);
        // If using marching, you can call:
        // cpMarchSetSampleFunc(reinterpret_cast<cpMarchSampleFunc>(PointCloudSample), this);
    }

    // Clean up all stored points and the index
    ~PointCloudSampler() {
        // Free each stored DeformPoint
        cpSpatialIndexEach(_index,
            [](void* ptr, void*) { std::free(ptr); },
            nullptr);
        cpSpatialIndexFree(_index);
    }

    // Adds a point with radius and fuzz; returns dirty bounding box
    cpBB addPoint(const cpVect& pos, cpFloat radius, cpFloat fuzz) {
        auto* p = static_cast<DeformPoint*>(std::calloc(1, sizeof(DeformPoint)));
        p->pos = pos;
        p->radius = radius;
        p->fuzz = fuzz;
        cpSpatialIndexInsert(_index, p, reinterpret_cast<cpHashValue>(p));
        return PointBB(p);
    }

    // Expose the spatial index for marching or manual queries
    cpSpatialIndex* index() const { return _index; }

private:
    cpFloat _cellSize;
    cpSpatialIndex* _index;
};
