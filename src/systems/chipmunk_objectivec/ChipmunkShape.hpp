// ChipmunkShape.hpp
#pragma once

/*
 * Copyright (c) 2013 Scott Lembcke and Howling Moon Software
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifdef CP_ALLOW_PRIVATE_ACCESS

#include "third_party/chipmunk/include/chipmunk/chipmunk_private.h"
#else

#include "third_party/chipmunk/include/chipmunk/chipmunk.h"
#include "third_party/chipmunk/include/chipmunk/chipmunk_structs.h"
#endif

#include "ChipmunkBaseObject.hpp"
#include "ChipmunkBody.hpp"
#include "ChipmunkShape.hpp"
#include "ChipmunkSpace.hpp"
#include <vector>



// ChipmunkPointQueryInfo.hpp
class ChipmunkPointQueryInfo {
public:
    ChipmunkPointQueryInfo() { std::memset(&_info, 0, sizeof(_info)); }
    ChipmunkPointQueryInfo(cpShape* s, const cpPointQueryInfo& info) : _info(info) { _shape = static_cast<ChipmunkShape*>(s->userData); }
    ChipmunkShape* shape() const { return _shape; }
    cpVect point() const { return _info.point; }
    cpFloat distance() const { return _info.distance; }
    cpVect gradient() const { return _info.gradient; }
private:
    ChipmunkShape* _shape = nullptr;
    cpPointQueryInfo _info;
};

class ChipmunkSegmentQueryInfo {
public:
    ChipmunkSegmentQueryInfo() { std::memset(&_info, 0, sizeof(_info)); }
    ChipmunkSegmentQueryInfo(cpShape* s, const cpSegmentQueryInfo& info) : _info(info) { _shape = static_cast<ChipmunkShape*>(s->userData); }
    ChipmunkShape* shape() const { return _shape; }
    cpFloat t() const { return _info.alpha; }
    cpVect normal() const { return _info.normal; }
    cpVect point() const { return _info.point; }
    cpFloat dist() const { return cpvdist(_start, _end)*_info.alpha; }
private:
    ChipmunkShape* _shape = nullptr;
    cpSegmentQueryInfo _info;
    cpVect _start, _end;
};

class ChipmunkShapeQueryInfo {
public:
    ChipmunkShapeQueryInfo() = default;
    ChipmunkShapeQueryInfo(ChipmunkShape* s, const cpContactPointSet& pts) : _shape(s), _points(pts) {}
    ChipmunkShape* shape() const { return _shape; }
    const cpContactPointSet& contactPoints() const { return _points; }
private:
    ChipmunkShape* _shape = nullptr;
    cpContactPointSet _points;
};


class ChipmunkShape : public ChipmunkBaseObject {
private:
    cpShape* _shape;
public:
    static ChipmunkShape* ShapeFromCPShape(cpShape* shape) {
        auto* obj = static_cast<ChipmunkShape*>(shape->userData);
        return obj;
    }

    // virtual cpShape* shape() const = 0;
    virtual cpShape* shape() const { return _shape; }

    virtual ~ChipmunkShape() = default;

    ChipmunkBody* body() const {
        auto* b = cpShapeGetBody(shape());
        return b ? static_cast<ChipmunkBody*>(b->userData) : nullptr;
    }
    void setBody(ChipmunkBody* b) {
        cpShapeSetBody(shape(), b ? b->body() : nullptr);
    }

    cpFloat mass() const { return cpShapeGetMass(shape()); }
    void setMass(cpFloat v) { cpShapeSetMass(shape(), v); }

    cpFloat density() const { return cpShapeGetDensity(shape()); }
    void setDensity(cpFloat v) { cpShapeSetDensity(shape(), v); }

    cpFloat moment() const { return cpShapeGetMoment(shape()); }
    cpFloat area() const { return cpShapeGetArea(shape()); }
    cpVect centerOfGravity() const { return cpShapeGetCenterOfGravity(shape()); }

    cpBB bb() const { return cpShapeGetBB(shape()); }
    bool sensor() const { return cpShapeGetSensor(shape()); }
    void setSensor(bool v) { cpShapeSetSensor(shape(), v); }

    cpFloat elasticity() const { return cpShapeGetElasticity(shape()); }
    void setElasticity(cpFloat v) { cpShapeSetElasticity(shape(), v); }

    cpFloat friction() const { return cpShapeGetFriction(shape()); }
    void setFriction(cpFloat v) { cpShapeSetFriction(shape(), v); }

    cpVect surfaceVelocity() const { return cpShapeGetSurfaceVelocity(shape()); }
    void setSurfaceVelocity(cpVect v) { cpShapeSetSurfaceVelocity(shape(), v); }

    cpCollisionType collisionType() const { return cpShapeGetCollisionType(shape()); }
    void setCollisionType(cpCollisionType v) { cpShapeSetCollisionType(shape(), v); }

    cpShapeFilter filter() const { return cpShapeGetFilter(shape()); }
    void setFilter(cpShapeFilter f) { cpShapeSetFilter(shape(), f); }

    ChipmunkSpace* space() const {
        auto* s = cpShapeGetSpace(shape());
        return s ? static_cast<ChipmunkSpace*>(cpSpaceGetUserData(s)) : nullptr;
    }

    cpBB cacheBB() const { return cpShapeCacheBB(shape()); }

    ChipmunkPointQueryInfo pointQuery(cpVect v) const {
        cpPointQueryInfo info;
        cpShapePointQuery(shape(), v, &info);
        return ChipmunkPointQueryInfo(shape(), info);
    }

    ChipmunkSegmentQueryInfo segmentQuery(cpVect a, cpVect b, cpFloat r) const {
        cpSegmentQueryInfo info;
        cpShapeSegmentQuery(shape(), a, b, r, &info);
        return ChipmunkSegmentQueryInfo(shape(), info);
    }

    std::vector<ChipmunkBaseObject*> chipmunkObjects() const override {
        return { const_cast<ChipmunkShape*>(this) };
    }

    void addToSpace(ChipmunkSpace* sp) override {
        sp->add(this);
    }
    void removeFromSpace(ChipmunkSpace* sp) override {
        sp->remove(this);
    }
};



// ChipmunkCircleShape
class ChipmunkCircleShape : public ChipmunkShape {

public:
    static ChipmunkCircleShape* CircleWithBody(ChipmunkBody* body, cpFloat radius, cpVect offset) {
        return new ChipmunkCircleShape(body, radius, offset);
    }
    ChipmunkCircleShape(ChipmunkBody* body, cpFloat radius, cpVect offset) {
        cpCircleShapeInit(&_shape, body->body(), radius, offset);
        _shape.shape.userData = this;
    }
    cpShape* shape() const override { return reinterpret_cast<cpShape*>(const_cast<cpCircleShape*>(&_shape)); }
    cpFloat radius() const { return cpCircleShapeGetRadius(shape()); }
    cpVect offset() const { return cpCircleShapeGetOffset(shape()); }
private:
    cpCircleShape _shape;
};

// ChipmunkSegmentShape
class ChipmunkSegmentShape : public ChipmunkShape {
public:
    static ChipmunkSegmentShape* SegmentWithBody(ChipmunkBody* body, cpVect a, cpVect b, cpFloat r) {
        return new ChipmunkSegmentShape(body, a, b, r);
    }
    ChipmunkSegmentShape(ChipmunkBody* body, cpVect a, cpVect b, cpFloat r) {
        cpSegmentShapeInit(&_shape, body->body(), a, b, r);
        _shape.shape.userData = this;
    }
    cpShape* shape() const override { return reinterpret_cast<cpShape*>(const_cast<cpSegmentShape*>(&_shape)); }
    void setPrevNeighbor(cpVect prev, cpVect next) { cpSegmentShapeSetNeighbors(&(_shape.shape), prev, next); }
    cpVect a() const { return cpSegmentShapeGetA(shape()); }
    cpVect b() const { return cpSegmentShapeGetB(shape()); }
    cpVect normal() const { return cpSegmentShapeGetNormal(shape()); }
    cpFloat radius() const { return cpSegmentShapeGetRadius(shape()); }
private:
    cpSegmentShape _shape;
};

// ChipmunkPolyShape
class ChipmunkPolyShape : public ChipmunkShape {
public:
    static ChipmunkPolyShape* PolyWithBody(ChipmunkBody* body, int count, const cpVect* verts, cpTransform transform, cpFloat radius) {
        return new ChipmunkPolyShape(body, count, verts, transform, radius);
    }
    static ChipmunkPolyShape* BoxWithBody(ChipmunkBody* body, cpFloat w, cpFloat h, cpFloat r) {
        return new ChipmunkPolyShape(body, 4, nullptr, cpTransformIdentity, r); // placeholder
    }
    ChipmunkPolyShape(ChipmunkBody* body, int count, const cpVect* verts, cpTransform transform, cpFloat radius) {
        cpPolyShapeInit(&_shape, body->body(), count, verts, transform, radius);
        _shape.shape.userData = this;
    }
    cpShape* shape() const override { return reinterpret_cast<cpShape*>(const_cast<cpPolyShape*>(&_shape)); }
    int count() const { return cpPolyShapeGetCount(shape()); }
    cpFloat radius() const { return cpPolyShapeGetRadius(shape()); }
    cpVect getVertex(int i) const { return cpPolyShapeGetVert(shape(), i); }
private:
    cpPolyShape _shape;
};
