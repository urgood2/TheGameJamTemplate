// ChipmunkSpace.hpp
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

#define CHIPMUNK_SPACE_USE_HASTY_SPACE 1


#include "third_party/chipmunk/include/chipmunk/chipmunk.h"
extern "C" {
#include "third_party/chipmunk/include/chipmunk/cpHastySpace.h"
}
#include <vector>
#include <set>
#include <functional>
#include "ChipmunkBaseObject.hpp"
#include "ChipmunkBody.hpp"
#include "ChipmunkShape.hpp"
#include "ChipmunkConstraints.hpp"

// Arbiter helper macros
#define CHIPMUNK_ARBITER_GET_SHAPES(__arb__, __a__, __b__) \
    ChipmunkShape* __a__; ChipmunkShape* __b__; { \
        cpShape* _A; cpShape* _B; \
        cpArbiterGetShapes(__arb__, &_A, &_B); \
        __a__ = static_cast<ChipmunkShape*>(cpShapeGetUserData(_A)); \
        __b__ = static_cast<ChipmunkShape*>(cpShapeGetUserData(_B)); \
    }
#define CHIPMUNK_ARBITER_GET_BODIES(__arb__, __a__, __b__) \
    ChipmunkBody* __a__; ChipmunkBody* __b__; { \
        cpBody* _A; cpBody* _B; \
        cpArbiterGetBodies(__arb__, &_A, &_B); \
        __a__ = static_cast<ChipmunkBody*>(cpBodyGetUserData(_A)); \
        __b__ = static_cast<ChipmunkBody*>(cpBodyGetUserData(_B)); \
    }

class ChipmunkSpace {
public:
    ChipmunkSpace();
    virtual ~ChipmunkSpace();

    // Properties
    int Iterations() const;
    void setIterations(int v);
    cpVect Gravity() const;
    void setGravity(cpVect v);
    cpFloat Damping() const;
    void setDamping(cpFloat v);
    cpFloat IdleSpeedThreshold() const;
    void setIdleSpeedThreshold(cpFloat v);
    cpFloat SleepTimeThreshold() const;
    void setSleepTimeThreshold(cpFloat v);
    cpFloat CollisionSlop() const;
    void setCollisionSlop(cpFloat v);
    cpFloat CollisionBias() const;
    void setCollisionBias(cpFloat v);
    cpTimestamp CollisionPersistence() const;
    void setCollisionPersistence(cpTimestamp v);

    cpSpace* space() const;
    ChipmunkBody* staticBody() const;
    cpFloat currentTimeStep() const;
    bool isLocked() const;

    void* UserData() const;
    void setUserData(void* data);

    static ChipmunkSpace* SpaceFromCPSpace(cpSpace* s);

    // Collision handlers
    void setDefaultCollisionHandler(
        void* delegate,
        cpCollisionBeginFunc begin,
        cpCollisionPreSolveFunc preSolve,
        cpCollisionPostSolveFunc postSolve,
        cpCollisionSeparateFunc separate
    );
    void addCollisionHandler(
        void* delegate,
        cpCollisionType a, cpCollisionType b,
        cpCollisionBeginFunc begin,
        cpCollisionPreSolveFunc preSolve,
        cpCollisionPostSolveFunc postSolve,
        cpCollisionSeparateFunc separate
    );

    // Object management
    void add(ChipmunkObject* obj);
    void remove(ChipmunkObject* obj);
    bool contains(ChipmunkObject* obj) const;
    void smartAdd(ChipmunkObject* obj);
    void smartRemove(ChipmunkObject* obj);

    // Utility
    std::vector<ChipmunkObject*> addBounds(
        cpBB bounds,
        cpFloat radius,
        cpFloat elasticity,
        cpFloat friction,
        cpShapeFilter filter,
        cpCollisionType collisionType
    );

    // Post-step callbacks
    bool addPostStepCallback(void* target, cpPostStepFunc func, void* key, void* context);
    bool addPostStepBlock(const std::function<void()>& block, void* key);
    void addPostStepAddition(ChipmunkObject* obj);
    void addPostStepRemoval(ChipmunkObject* obj);

    // Queries
    std::vector<ChipmunkPointQueryInfo> pointQueryAll(cpVect point, cpFloat maxDistance, cpShapeFilter filter);
    ChipmunkPointQueryInfo pointQueryNearest(cpVect point, cpFloat maxDistance, cpShapeFilter filter);
    std::vector<ChipmunkSegmentQueryInfo> segmentQueryAll(cpVect start, cpVect end, cpFloat radius, cpShapeFilter filter);
    ChipmunkSegmentQueryInfo segmentQueryFirst(cpVect start, cpVect end, cpFloat radius, cpShapeFilter filter);
    std::vector<ChipmunkShape*> bbQueryAll(cpBB bb, cpShapeFilter filter);
    std::vector<ChipmunkShapeQueryInfo> shapeQueryAll(ChipmunkShape* shape);
    bool shapeTest(ChipmunkShape* shape) const;
    std::vector<ChipmunkBody*> bodies() const;
    std::vector<ChipmunkShape*> shapes() const;
    std::vector<Constraint*> constraints() const;

    // Reindexing
    void reindexStatic();
    void reindexShape(ChipmunkShape* shape);
    void reindexShapesForBody(ChipmunkBody* body);

    // Stepping
    virtual void step(cpFloat dt);
    
    struct HandlerContext {
        void* delegate;
        cpCollisionType a, b;
        cpCollisionBeginFunc begin;
        cpCollisionPreSolveFunc preSolve;
        cpCollisionPostSolveFunc postSolve;
        cpCollisionSeparateFunc separate;
    };

protected:
    cpSpace* _space;
    ChipmunkBody* _staticBody;
    std::set<ChipmunkObject*> _children;
    
    std::vector<HandlerContext> _handlers;
};

class ChipmunkHastySpace : public ChipmunkSpace {
public:
    ChipmunkHastySpace();
    ~ChipmunkHastySpace() override;

    size_t threads() const;
    void setThreads(size_t n);
    void step(cpFloat dt) override;
};

