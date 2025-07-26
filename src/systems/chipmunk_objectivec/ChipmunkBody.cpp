// ChipmunkBody.cpp
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"

#include "third_party/chipmunk/include/chipmunk/cpBody.h"
#include "ChipmunkBody.hpp"
#include "ChipmunkSpace.hpp"
#include "ChipmunkShape.hpp"

// Check if a virtual method is overridden in subclass
bool ChipmunkBody::methodIsOverridden(void* methodPtr) const {
    constexpr std::size_t vtableOffset = /* your vtable offset */;
    // Don’t drop const here:
    const char* base = reinterpret_cast<const char*>(this);
    // Read a pointer‐sized value out of the vtable slot:
    void* current =
      *reinterpret_cast<void* const*>(base + vtableOffset);
    return methodPtr != current;
}

// Factory methods
ChipmunkBody* ChipmunkBody::BodyFromCPBody(cpBody* body) {
    return static_cast<ChipmunkBody*>(body->userData);
}

ChipmunkBody* ChipmunkBody::BodyWithMassAndMoment(cpFloat mass, cpFloat moment) {
    return new ChipmunkBody(mass, moment);
}

ChipmunkBody* ChipmunkBody::StaticBody() {
    auto* b = new ChipmunkBody(0.0f, 0.0f);
    b->setType(CP_BODY_TYPE_STATIC);
    return b;
}

ChipmunkBody* ChipmunkBody::KinematicBody() {
    auto* b = new ChipmunkBody(0.0f, 0.0f);
    b->setType(CP_BODY_TYPE_KINEMATIC);
    return b;
}

// Constructor / Destructor

ChipmunkBody::ChipmunkBody(cpFloat mass, cpFloat moment) {
    cpBodyInit(&_body, mass, moment);
    _body.userData = this;

    // Always install these trampolines:
    _body.velocity_func = VelocityFunc;
    _body.position_func = PositionFunc;
}


ChipmunkBody::~ChipmunkBody() {
    cpBodyDestroy(&_body);
}

// Getters and setters
#define GETTER(NAME, TYPE, FN) TYPE ChipmunkBody::NAME() const { return FN(&_body); }
#define SETTER(NAME, TYPE, FN) void ChipmunkBody::set##NAME(TYPE value) { FN(&_body, value); }

GETTER(type, cpBodyType, cpBodyGetType)
SETTER(Type, cpBodyType, cpBodySetType)
GETTER(mass, cpFloat, cpBodyGetMass)
SETTER(Mass, cpFloat, cpBodySetMass)
GETTER(moment, cpFloat, cpBodyGetMoment)
SETTER(Moment, cpFloat, cpBodySetMoment)
GETTER(centerOfGravity, cpVect, cpBodyGetCenterOfGravity)
SETTER(CenterOfGravity, cpVect, cpBodySetCenterOfGravity)
GETTER(position, cpVect, cpBodyGetPosition)
SETTER(Position, cpVect, cpBodySetPosition)
GETTER(velocity, cpVect, cpBodyGetVelocity)
SETTER(Velocity, cpVect, cpBodySetVelocity)
GETTER(force, cpVect, cpBodyGetForce)
SETTER(Force, cpVect, cpBodySetForce)
GETTER(angle, cpFloat, cpBodyGetAngle)
SETTER(Angle, cpFloat, cpBodySetAngle)
GETTER(angularVelocity, cpFloat, cpBodyGetAngularVelocity)
SETTER(AngularVelocity, cpFloat, cpBodySetAngularVelocity)
GETTER(torque, cpFloat, cpBodyGetTorque)
SETTER(Torque, cpFloat, cpBodySetTorque)

void* ChipmunkBody::userData() const { return _body.userData; }
void ChipmunkBody::setUserData(void* data) { _body.userData = data; }

bool ChipmunkBody::isSleeping() const { return cpBodyIsSleeping(&_body); }
cpFloat ChipmunkBody::kineticEnergy() const { return cpBodyKineticEnergy(&_body); }
ChipmunkSpace* ChipmunkBody::space() const {
    cpSpace* sp = cpBodyGetSpace(&_body);
    return sp ? static_cast<ChipmunkSpace*>(cpSpaceGetUserData(sp)) : nullptr;
}

// Transforms and velocities
cpVect ChipmunkBody::localToWorld(cpVect v) const { return cpBodyLocalToWorld(&_body, v); }
cpVect ChipmunkBody::worldToLocal(cpVect v) const { return cpBodyWorldToLocal(&_body, v); }
cpVect ChipmunkBody::velocityAtLocalPoint(cpVect p) const { return cpBodyGetVelocityAtLocalPoint(&_body, p); }
cpVect ChipmunkBody::velocityAtWorldPoint(cpVect p) const { return cpBodyGetVelocityAtWorldPoint(&_body, p); }

// Forces and impulses
void ChipmunkBody::applyForce(cpVect force, cpVect point) { cpBodyApplyForceAtLocalPoint(&_body, force, point); }
void ChipmunkBody::applyForceAtWorldPoint(cpVect force, cpVect point) { cpBodyApplyForceAtWorldPoint(&_body, force, point); }
void ChipmunkBody::applyImpulse(cpVect impulse, cpVect point) { cpBodyApplyImpulseAtLocalPoint(&_body, impulse, point); }
void ChipmunkBody::applyImpulseAtWorldPoint(cpVect impulse, cpVect point) { cpBodyApplyImpulseAtWorldPoint(&_body, impulse, point); }

// Activation and sleep
void ChipmunkBody::activate() { cpBodyActivate(&_body); }
void ChipmunkBody::activateStatic(ChipmunkShape* filter) { cpBodyActivateStatic(&_body, filter ? filter->shape() : nullptr); }
void ChipmunkBody::sleepWithGroup(ChipmunkBody* group) { cpBodySleepWithGroup(&_body, group ? group->body() : nullptr); }
void ChipmunkBody::sleep() { cpBodySleep(&_body); }

// Protocol implementations
std::vector<ChipmunkBaseObject*> ChipmunkBody::chipmunkObjects() const { return { const_cast<ChipmunkBody*>(this) }; }
void ChipmunkBody::addToSpace(ChipmunkSpace* space) { space->add(this); }
void ChipmunkBody::removeFromSpace(ChipmunkSpace* space) { space->remove(this); }

// Integration callback wrappers
void ChipmunkBody::VelocityFunc(cpBody* body, cpVect gravity, cpFloat damping, cpFloat dt) {
    static_cast<ChipmunkBody*>(body->userData)->updateVelocity(dt, gravity, damping);
}
void ChipmunkBody::PositionFunc(cpBody* body, cpFloat dt) {
    static_cast<ChipmunkBody*>(body->userData)->updatePosition(dt);
}

void ChipmunkBody::updateVelocity(cpFloat dt, cpVect gravity, cpFloat damping) {
    cpBodyUpdateVelocity(&_body, gravity, damping, dt);
}
void ChipmunkBody::updatePosition(cpFloat dt) {
    cpBodyUpdatePosition(&_body, dt);
}

ChipmunkBody* ChipmunkSpaceDispatch::addBody(ChipmunkBody* obj) {
    cpSpace* space = /* obtain underlying cpSpace pointer */ nullptr;
    cpSpaceAddBody(space, obj->body());
    return obj;
}
ChipmunkBody* ChipmunkSpaceDispatch::removeBody(ChipmunkBody* obj) {
    cpSpace* space = /* obtain underlying cpSpace pointer */ nullptr;
    cpSpaceRemoveBody(space, obj->body());
    return obj;
}
