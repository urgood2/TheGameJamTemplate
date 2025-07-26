/* Copyright (c) 2013 Scott Lembcke and Howling Moon Software
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

#include "ChipmunkConstraints.hpp"
#include <vector>
#include <algorithm>
#include <cmath>

// Forward declarations
class Grab;
class MultiGrab;

//=======================================================
// Grab: Handles a single pointer grab
//=======================================================
class Grab : public Constraint {
public:
    // Construct grab with owner, grab position, nearest contact, target body and shape, and all chipmunk objects to add.
    Grab(MultiGrab* owner, cpVect pos, cpVect nearest, Body* body, Shape* grabbedShape, const std::vector<Constraint*>& chipmunkObjects);
    ~Grab() override;

    // Override preSolve callback
    void preSolve(Space* space) override;

    // Accessors
    cpVect pos() const { return _pos; }
    void setPos(cpVect v) { _pos = v; }
    bool hasGrabbed() const { return _grabbedShape != nullptr; }

private:
    cpVect _pos;
    float _smoothing;
    Shape* _grabbedShape;
    std::vector<Constraint*> _objects;

    // PreSolve helper bound to cpConstraint
    static void PreSolveFunc(cpConstraint* constraint, cpSpace* space);
};

//=======================================================
// MultiGrab: Manages multiple concurrent grabs
//=======================================================
class MultiGrab {
public:
    MultiGrab(Space* space, float smoothing, float grabForce);
    ~MultiGrab();

    // Begin a grab at world position pos. Returns Grab if object pulled or pushed, else nullptr.
    Grab* beginLocation(cpVect pos);
    // Update existing grab closest to pos.
    Grab* updateLocation(cpVect pos);
    // End and remove grab closest to pos.
    Grab* endLocation(cpVect pos);

    // List of active grab objects that have a shape
    std::vector<Grab*> grabs() const;

    // Configuration properties
    float grabForce;
    float smoothing;
    cpShapeFilter filter;
    std::function<bool(Shape*)> grabFilter;
    std::function<float(Shape*, float)> grabSort;
    float grabFriction;
    float grabRotaryFriction;
    float grabRadius;
    bool pullMode;
    bool pushMode;
    float pushMass;
    float pushFriction;
    float pushElasticity;
    unsigned int pushCollisionType;

private:
    Space* _space;
    std::vector<Grab*> _grabs;

    // Helper to find best grab by proximity
    static Grab* BestGrab(const std::vector<Grab*>& grabs, cpVect pos);
};

//=======================================================
// Grab Implementation
//=======================================================

void Grab::PreSolveFunc(cpConstraint* constraint, cpSpace* space) {
    Body* grabBody = static_cast<Body*>(cpBodyGetUserData(cpConstraintGetBodyA(constraint)));
    Grab* grab = static_cast<Grab*>(constraint->userData);
    float dt = cpSpaceGetCurrentTimeStep(space);
    float coef = std::pow(grab->_smoothing, dt);
    cpVect targetPos = cpvlerp(grab->_pos, cpBodyGetPosition(grabBody->get()), coef);
    cpBodySetVelocity(grabBody->get(), cpvmult(cpvsub(targetPos, cpBodyGetPosition(grabBody->get())), 1.0f/dt));
}

Grab::Grab(MultiGrab* owner,
           cpVect pos,
           cpVect nearest,
           Body* body,
           Shape* grabbedShape,
           const std::vector<Constraint*>& chipmunkObjects)
: Constraint(nullptr)
, _pos(pos)
, _smoothing(owner->smoothing)
, _grabbedShape(grabbedShape)
, _objects(chipmunkObjects)
{
    // Create kinematic grab body
    Body* grabBody = Body::createKinematic();
    grabBody->setPosition(pos);

    // Build initial pivot joint
    PivotJoint* pivot = PivotJoint::create(grabBody, body, cpvzero, body->worldToLocal(nearest));
    pivot->setMaxForce(owner->grabForce);
    pivot->get()->userData = this;
    cpConstraintSetPreSolveFunc(pivot->get(), Grab::PreSolveFunc);
    _objects.push_back(pivot);

    // Friction pivot if shape exists
    if(grabbedShape) {
        if(owner->grabFriction > 0.0f && (1.0f/body->getMass() + 1.0f/grabBody->getMass() != 0.0f)) {
            PivotJoint* friction = PivotJoint::create(grabBody, body, cpvzero, body->worldToLocal(nearest));
            friction->setMaxForce(owner->grabFriction);
            friction->setMaxBias(0.0f);
            _objects.push_back(friction);
        }
        if(owner->grabRotaryFriction > 0.0f && (1.0f/body->getMoment() + 1.0f/grabBody->getMoment() != 0.0f)) {
            GearJoint* rotary = GearJoint::create(grabBody, body, 0.0f, 1.0f);
            rotary->setMaxForce(owner->grabRotaryFriction);
            rotary->setMaxBias(0.0f);
            _objects.push_back(rotary);
        }
    }

    // Store constraint handles for cleanup
    _objects.push_back(this); // include self if managing deletion
    // Add all to space
    for(auto c : _objects) {
        owner->_space->addConstraint(static_cast<Constraint*>(c));
    }
}

Grab::~Grab() {
    for(auto c : _objects) {
        delete c;
    }
}

void Grab::preSolve(Space* space) {
    // No-op: handled in static PreSolveFunc callback
}

//=======================================================
// MultiGrab Implementation
//=======================================================

MultiGrab::MultiGrab(Space* space, float smoothing, float grabForce)
: _space(space)
, grabForce(grabForce)
, smoothing(smoothing)
, filter(CP_SHAPE_FILTER_ALL)
, grabFilter([](Shape*) { return true; })
, grabSort([](Shape*, float depth) { return depth; })
, grabFriction(0.0f)
, grabRotaryFriction(0.0f)
, grabRadius(0.0f)
, pullMode(true)
, pushMode(false)
, pushMass(0.0f)
, pushFriction(0.0f)
, pushElasticity(0.0f)
, pushCollisionType(0)
{
    // nothing else
}

MultiGrab::~MultiGrab() {
    for(auto g : _grabs) delete g;
}

static void PushBodyVelocityFunc(cpBody* body, cpVect gravity, cpFloat damping, cpFloat dt) {}

Grab* MultiGrab::beginLocation(cpVect pos) {
    float minSort = INFINITY;
    cpVect nearest = pos;
    Shape* grabbedShape = nullptr;

    if(pullMode) {
        cpSpacePointQuery(_space->get(), pos, grabRadius, filter, [&](cpShape* c_shape, cpVect point, cpFloat dist, cpVect gradient){
            Shape* shape = Shape::from(c_shape);
            float sortVal = dist;
            if(dist <= 0.0f) {
                sortVal = -grabSort(shape, -dist);
            }
            if(sortVal < minSort && cpShapeGetBody(c_shape)->m > 0) {
                if(grabFilter(shape)) {
                    minSort = sortVal;
                    nearest = (dist > 0.0f ? point : pos);
                    grabbedShape = shape;
                }
            }
        });
    }

    Body* pushBody = nullptr;
    std::vector<Constraint*> chipmunkObjects;

    if(!grabbedShape && pushMode) {
        pushBody = Body::create(pushMass, INFINITY);
        pushBody->setPosition(pos);
        cpBodySetVelocityUpdateFunc(pushBody->get(), PushBodyVelocityFunc);

        Shape* pushShape = CircleShape::create(pushBody, grabRadius, cpvzero);
        pushShape->setFriction(pushFriction);
        pushShape->setElasticity(pushElasticity);
        pushShape->setFilter(filter);
        pushShape->setCollisionType(pushCollisionType);
        chipmunkObjects.push_back(pushShape);
    }

    Body* targetBody = grabbedShape ? grabbedShape->getBody() : pushBody;
    Grab* grab = new Grab(this, pos, nearest, targetBody, grabbedShape, chipmunkObjects);
    _grabs.push_back(grab);
    return grab->hasGrabbed() ? grab : nullptr;
}

Grab* MultiGrab::BestGrab(const std::vector<Grab*>& grabs, cpVect pos) {
    Grab* best = nullptr;
    float bestDist = INFINITY;
    for(auto g : grabs) {
        float d2 = cpvdistsq(pos, g->pos());
        if(d2 < bestDist) {
            best = g;
            bestDist = d2;
        }
    }
    return best;
}

Grab* MultiGrab::updateLocation(cpVect pos) {
    Grab* grab = BestGrab(_grabs, pos);
    if(grab) grab->setPos(pos);
    return grab && grab->hasGrabbed() ? grab : nullptr;
}

Grab* MultiGrab::endLocation(cpVect pos) {
    Grab* grab = BestGrab(_grabs, pos);
    auto it = std::find(_grabs.begin(), _grabs.end(), grab);
    if(it != _grabs.end()) {
        _grabs.erase(it);
    }
    return grab && grab->hasGrabbed() ? grab : nullptr;
}

std::vector<Grab*> MultiGrab::grabs() const {
    std::vector<Grab*> result;
    for(auto g : _grabs) {
        if(g->hasGrabbed()) result.push_back(g);
    }
    return result;
}
