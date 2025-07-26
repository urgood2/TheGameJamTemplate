
// CppChipmunkAutoGeometry.cpp
#include "ChipmunkAutogeometry.hpp"
#include <cassert>

// Polyline

Polyline::Polyline(cpPolyline* line, bool owner)
    : _line(line), _area(0.0f), _owner(owner) {}

Polyline::~Polyline() {
    if(_owner && _line) {
        cpPolylineFree(_line);
    }
}

Polyline Polyline::fromPolyline(cpPolyline* line) {
    return Polyline(line, true);
}

bool Polyline::isClosed() const {
    return cpPolylineIsClosed(_line);
}

cpFloat Polyline::area() const {
    if(_area == 0.0f && isClosed()) {
        _area = cpAreaForPoly(_line->count - 1, _line->verts, 0.0f);
    }
    return _area;
}

cpVect Polyline::centroid() const {
    assert(isClosed());
    return cpCentroidForPoly(_line->count - 1, _line->verts);
}

cpFloat Polyline::momentForMass(cpFloat mass, cpVect offset) const {
    assert(isClosed());
    return cpMomentForPoly(mass, _line->count - 1, _line->verts, offset, 0.0f);
}

size_t Polyline::count() const {
    return static_cast<size_t>(_line->count);
}

const cpVect* Polyline::verts() const {
    return _line->verts;
}

Polyline Polyline::simplifyCurves(cpFloat tolerance) const {
    return fromPolyline(cpPolylineSimplifyCurves(_line, tolerance));
}

Polyline Polyline::simplifyVertexes(cpFloat tolerance) const {
    return fromPolyline(cpPolylineSimplifyVertexes(_line, tolerance));
}

Polyline Polyline::toConvexHull(cpFloat tolerance) const {
    return fromPolyline(cpPolylineToConvexHull(_line, tolerance));
}

Polyline Polyline::toConvexHull() const {
    return toConvexHull(0.0f);
}

std::vector<Polyline> Polyline::toConvexHullsBeta(cpFloat tolerance) const {
    cpPolylineSet* set = cpPolylineConvexDecomposition_BETA(_line, tolerance);
    std::vector<Polyline> result;
    result.reserve(set->count);
    for(int i = 0; i < set->count; ++i) {
        result.emplace_back(set->lines[i]);
    }
    cpPolylineSetFree(set, false);
    return result;
}

std::vector<cpShape*> Polyline::asSegments(cpBody* body, cpFloat radius, cpVect offset) const {
    std::vector<cpShape*> arr;
    arr.reserve(static_cast<size_t>(_line->count));
    cpVect a = cpvadd(_line->verts[0], offset);
    for(int i = 1; i < _line->count; ++i) {
        cpVect b = cpvadd(_line->verts[i], offset);
        arr.push_back(cpSegmentShapeNew(body, a, b, radius));
        a = b;
    }
    return arr;
}

cpShape* Polyline::asPolyShape(cpBody* body, cpTransform transform, cpFloat radius) const {
    assert(isClosed());
    return cpPolyShapeNew(body, _line->count - 1, _line->verts, transform, radius);
}

// PolylineSet

PolylineSet::PolylineSet(const cpPolylineSet& set) {
    lines.reserve(static_cast<size_t>(set.count));
    for(int i = 0; i < set.count; ++i) {
        lines.emplace_back(set.lines[i], false);
    }
}

size_t PolylineSet::count() const {
    return lines.size();
}

const Polyline& PolylineSet::lineAtIndex(size_t index) const {
    return lines[index];
}

std::vector<Polyline>::const_iterator PolylineSet::begin() const {
    return lines.begin();
}

std::vector<Polyline>::const_iterator PolylineSet::end() const {
    return lines.end();
}

// AbstractSampler

AbstractSampler::AbstractSampler(cpMarchSampleFunc sampleFunc)
    : sampleFunc(sampleFunc), marchThreshold(0.5f) {}

cpFloat AbstractSampler::getMarchThreshold() const {
    return marchThreshold;
}

void AbstractSampler::setMarchThreshold(cpFloat threshold) {
    marchThreshold = threshold;
}

cpMarchSampleFunc AbstractSampler::getSampleFunc() const {
    return sampleFunc;
}

cpFloat AbstractSampler::sample(cpVect pos) const {
    return sampleFunc(pos, const_cast<AbstractSampler*>(this));
}

PolylineSet AbstractSampler::march(cpBB bb, size_t xSamples, size_t ySamples, bool hard) const {
    cpPolylineSet set;
    cpPolylineSetInit(&set);
    if(hard) {
        cpMarchHard(bb, xSamples, ySamples, marchThreshold,
                    (cpMarchSegmentFunc)cpPolylineSetCollectSegment,
                    &set, sampleFunc, const_cast<AbstractSampler*>(this));
    } else {
        cpMarchSoft(bb, xSamples, ySamples, marchThreshold,
                    (cpMarchSegmentFunc)cpPolylineSetCollectSegment,
                    &set, sampleFunc, const_cast<AbstractSampler*>(this));
    }
    PolylineSet result(set);
    cpPolylineSetDestroy(&set, false);
    return result;
}

// BlockSampler

BlockSampler::BlockSampler(std::function<cpFloat(cpVect)> block)
    : AbstractSampler(&sampleFromBlock), blockFunc(block) {}

BlockSampler BlockSampler::create(std::function<cpFloat(cpVect)> block) {
    return BlockSampler(block);
}

cpFloat BlockSampler::sampleFromBlock(cpVect point, void* userData) {
    auto* self = static_cast<BlockSampler*>(userData);
    return self->blockFunc(point);
}
