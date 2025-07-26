// CppChipmunkAutoGeometry.hpp
#ifndef CPP_CHIPMUNK_AUTOGEOMETRY_HPP
#define CPP_CHIPMUNK_AUTOGEOMETRY_HPP

#include <vector>
#include <functional>
#include "chipmunk/chipmunk.h"
#include "chipmunk/cpMarch.h"
#include "chipmunk/cpPolyline.h"

// Wrapper for cpPolyline
class Polyline {
public:
    explicit Polyline(cpPolyline* line, bool owner = true);
    ~Polyline();
    static Polyline fromPolyline(cpPolyline* line);

    bool isClosed() const;
    cpFloat area() const;
    cpVect centroid() const;
    cpFloat momentForMass(cpFloat mass, cpVect offset) const;

    size_t count() const;
    const cpVect* verts() const;

    Polyline simplifyCurves(cpFloat tolerance) const;
    Polyline simplifyVertexes(cpFloat tolerance) const;
    Polyline toConvexHull(cpFloat tolerance) const;
    Polyline toConvexHull() const;

    std::vector<Polyline> toConvexHullsBeta(cpFloat tolerance) const;

    std::vector<cpShape*> asSegments(cpBody* body, cpFloat radius, cpVect offset) const;
    cpShape* asPolyShape(cpBody* body, cpTransform transform, cpFloat radius) const;

private:
    cpPolyline* _line;
    mutable cpFloat _area;
    bool _owner;
};

class PolylineSet {
public:
    explicit PolylineSet(const cpPolylineSet& set);
    ~PolylineSet() = default;

    size_t count() const;
    const Polyline& lineAtIndex(size_t index) const;

    std::vector<Polyline>::const_iterator begin() const;
    std::vector<Polyline>::const_iterator end() const;

private:
    std::vector<Polyline> lines;
};

class AbstractSampler {
public:
    explicit AbstractSampler(cpMarchSampleFunc sampleFunc);
    virtual ~AbstractSampler() = default;

    cpFloat getMarchThreshold() const;
    void setMarchThreshold(cpFloat threshold);

    cpMarchSampleFunc getSampleFunc() const;

    cpFloat sample(cpVect pos) const;

    PolylineSet march(cpBB bb, size_t xSamples, size_t ySamples, bool hard) const;

private:
    cpMarchSampleFunc sampleFunc;
    cpFloat marchThreshold;
};

class BlockSampler : public AbstractSampler {
public:
    explicit BlockSampler(std::function<cpFloat(cpVect)> block);
    static BlockSampler create(std::function<cpFloat(cpVect)> block);

private:
    std::function<cpFloat(cpVect)> blockFunc;
    static cpFloat sampleFromBlock(cpVect point, void* userData);
};

#endif // CPP_CHIPMUNK_AUTOGEOMETRY_HPP
