#pragma once
// PointCloudSamplerWrappers.cpp
// Port of ChipmunkPointCloudSampler (Objective-C) to C++

#include "systems/chipmunk_objectivec/ChipmunkAutogeometry.hpp"
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"
#include <cstdlib>

// Internal struct matching ObjC’s DeformPoint
struct DeformPoint {
    cpVect  pos;
    cpFloat radius;
    cpFloat fuzz;
};

// ----------------------------------------------------------------------------
// 1) Bounding‐box extractor for the spatial hash
// ----------------------------------------------------------------------------
static cpBB PointBBRaw(void *obj) {
    auto *p = static_cast<DeformPoint*>(obj);
    return cpBBNew(
        p->pos.x - p->radius,
        p->pos.y - p->radius,
        p->pos.x + p->radius,
        p->pos.y + p->radius
    );
}

// ----------------------------------------------------------------------------
// 2) Fuzz‐based falloff function (same as ObjC’s `fuzz` inline)
// ----------------------------------------------------------------------------
static inline cpFloat FuzzSample(const cpVect &v, const DeformPoint &p) {
    cpFloat d2 = cpvdistsq(v, p.pos);
    cpFloat r  = p.radius;
    if(d2 < r*r) {
        cpFloat d     = cpfsqrt(d2);
        cpFloat soft  = p.fuzz;
        cpFloat frac  = (r - d) / (soft * r);
        return 1.0f - cpfclamp01(frac);
    }
    return 1.0f;
}

// ----------------------------------------------------------------------------
// 3) Spatial‐index iterator callback: multiply density
//    Signature MUST match cpSpatialIndexQueryFunc:
//      typedef unsigned int (*)(void *obj, void *data, cpCollisionID id, void *userData);
// ----------------------------------------------------------------------------
static unsigned int PointQueryRaw(void *obj, void *data, cpCollisionID, void *userData) {
    auto    *v       = static_cast<cpVect*>(obj);
    auto    *p       = static_cast<DeformPoint*>(data);
    auto    *density = static_cast<cpFloat*>(userData);

    *density *= FuzzSample(*v, *p);
    return 0; // return nonzero to stop early; we want to sample all points
}

// ----------------------------------------------------------------------------
// 4) Free each DeformPoint in the hash on destruction
//    Matches cpSpatialIndexIteratorFunc:
//      typedef void (*)(void *obj, void *data);
// ----------------------------------------------------------------------------
static void FreeDeformPoint(void *obj, void *) {
    std::free(obj);
}

static cpFloat MarchSampleRaw(cpVect pos, void *userData);

// Marching callback wrapper: cpMarchSegmentFunc wants (cpVect, cpVect, void*)
static void MarchSegmentWrapper(cpVect a, cpVect b, void *data) {
    auto *set = static_cast<cpPolylineSet*>(data);
    cpPolylineSetCollectSegment(a, b, set);
}

// ----------------------------------------------------------------------------
// 6) C++ wrapper class
// ----------------------------------------------------------------------------
class PointCloudSampler {
public:
    // Construct with desired cell size and optional initial hash capacity
    explicit PointCloudSampler(cpFloat cellSize, int initialCount = 1000)
      : _cellSize(cellSize)
    {
        _index = cpSpaceHashNew(
          _cellSize,
          initialCount,
          PointBBRaw,    // cpSpatialIndexBBFunc = cpBB(*)(void*)
          nullptr        // userData for BB func (not used)
        );
    }

    // RAII cleanup: free all points, then free the index
    ~PointCloudSampler() {
        cpSpatialIndexEach(_index, FreeDeformPoint, nullptr);
        cpSpatialIndexFree(_index);
    }

    // Add a point; returns its “dirty” bounding box for re‐marching
    cpBB addPoint(const cpVect &pos, cpFloat radius, cpFloat fuzz) {
        auto *p = static_cast<DeformPoint*>(std::calloc(1, sizeof(DeformPoint)));
        p->pos    = pos;
        p->radius = radius;
        p->fuzz   = fuzz;

        cpSpatialIndexInsert(_index, p, reinterpret_cast<cpHashValue>(p));
        return PointBBRaw(p);
    }

    // Sample the density at an arbitrary position
    cpFloat sample(const cpVect &pos) const {
        cpFloat density = 1.0f;
        cpBB    bb      = cpBBNewForCircle(pos, 0.0f);

        cpSpatialIndexQuery(
          _index,
          const_cast<cpVect*>(&pos),
          bb,
          PointQueryRaw,
          &density
        );

        return density;
    }

    // Expose the raw index if you need it for more advanced queries
    cpSpatialIndex* index() const { return _index; }

    // Helper to run marching‐squares over a tile:
    //   - call cpMarchHard or cpMarchSoft directly
    //   - passes MarchSampleRaw + this as your sample callback
    void marchTile(cpPolylineSet *set,
               cpBB bounds,
               int nx, int ny,
               cpFloat threshold,
               bool hard = true)
    {
        auto marchFn = hard ? cpMarchHard : cpMarchSoft;
        marchFn(
        bounds,
        nx, ny,
        threshold,

        // use the wrapper so the 3rd parameter is void* → cpPolylineSet*
        MarchSegmentWrapper, set,

        // your existing sample callback
        MarchSampleRaw, this
        );
    }


private:
    cpFloat          _cellSize;
    cpSpatialIndex*  _index;
};


// ----------------------------------------------------------------------------
// 5) March‐sampling callback for cpMarchHard / cpMarchSoft:
//      typedef cpFloat (*cpMarchSampleFunc)(void *userData, cpVect pos);
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// March‐sampling callback: MUST match cpMarchSampleFunc = cpFloat (*)(cpVect,void*)
// ----------------------------------------------------------------------------
static cpFloat MarchSampleRaw(cpVect pos, void *userData) {
    auto *sampler = static_cast<PointCloudSampler*>(userData);
    return sampler->sample(pos);
}
