// ChipmunkConstraints.hpp
#ifndef CHIPMUNK_CONSTRAINTS_HPP
#define CHIPMUNK_CONSTRAINTS_HPP

#include "third_party/chipmunk/include/chipmunk/chipmunk.h"

#include "third_party/chipmunk/include/chipmunk/cpConstraint.h"
#include "ChipmunkBody.hpp"
#include "ChipmunkSpace.hpp"
#include <cassert>

// Base class for all constraints
class Constraint {
public:
    // Takes ownership of the cpConstraint pointer; will destroy it in destructor
    explicit Constraint(cpConstraint* constraint)
    : constraint_(constraint) {
        assert(constraint_ && "Constraint pointer must not be null");
        constraint_->userData = this;
        setupCallbacks();
    }
    virtual ~Constraint() {
        // Destroy the underlying constraint
        cpConstraintDestroy(constraint_);
    }

    // Underlying cpConstraint pointer
    cpConstraint* get() const { return constraint_; }

    // Bodies
    ChipmunkBody* bodyA() const {
        cpBody* b = cpConstraintGetBodyA(constraint_);
        return b ? static_cast<ChipmunkBody*>(cpBodyGetUserData(b)) : nullptr;
    }
    ChipmunkBody* bodyB() const {
        cpBody* b = cpConstraintGetBodyB(constraint_);
        return b ? static_cast<ChipmunkBody*>(cpBodyGetUserData(b)) : nullptr;
    }

    // Space
    ChipmunkSpace* space() const {
        cpSpace* s = cpConstraintGetSpace(constraint_);
        return s ? static_cast<ChipmunkSpace*>(cpSpaceGetUserData(s)) : nullptr;
    }

    // Common properties
    cpFloat maxForce() const { return cpConstraintGetMaxForce(constraint_); }
    void setMaxForce(cpFloat v) { cpConstraintSetMaxForce(constraint_, v); }

    cpFloat errorBias() const { return cpConstraintGetErrorBias(constraint_); }
    void setErrorBias(cpFloat v) { cpConstraintSetErrorBias(constraint_, v); }

    cpFloat maxBias() const { return cpConstraintGetMaxBias(constraint_); }
    void setMaxBias(cpFloat v) { cpConstraintSetMaxBias(constraint_, v); }

    bool collideBodies() const { return cpConstraintGetCollideBodies(constraint_); }
    void setCollideBodies(bool v) { cpConstraintSetCollideBodies(constraint_, v); }

    cpFloat impulse() const { return cpConstraintGetImpulse(constraint_); }

    // Add/Remove to Space wrapper
    void addToSpace(ChipmunkSpace* space);
    void removeFromSpace(ChipmunkSpace* space);

    // Override these for custom behavior
    virtual void preSolve(ChipmunkSpace* space) {}
    virtual void postSolve(ChipmunkSpace* space) {}

protected:
    cpConstraint* constraint_;

private:
    void setupCallbacks() {
        cpConstraintSetPreSolveFunc(constraint_, preSolveFunc);
        cpConstraintSetPostSolveFunc(constraint_, postSolveFunc);
    }
    static void preSolveFunc(cpConstraint* c, cpSpace* s) {
        static_cast<Constraint*>(c->userData)->preSolve(static_cast<ChipmunkSpace*>(s->userData));
    }
    static void postSolveFunc(cpConstraint* c, cpSpace* s) {
        static_cast<Constraint*>(c->userData)->postSolve(static_cast<ChipmunkSpace*>(s->userData));
    }
};

// Pin joint (rod) between two anchor points
class PinJoint : public Constraint {
public:
    static PinJoint* create(ChipmunkBody* a, ChipmunkBody* b, const cpVect& anchorA, const cpVect& anchorB) {
        return new PinJoint(a, b, anchorA, anchorB);
    }
    PinJoint(ChipmunkBody* a, ChipmunkBody* b, const cpVect& anchorA, const cpVect& anchorB)
    : Constraint(cpPinJointNew(a->body(), b->body(), anchorA, anchorB)) {}

    cpVect anchorA() const { return cpPinJointGetAnchorA(constraint_); }
    void setAnchorA(const cpVect& v) { cpPinJointSetAnchorA(constraint_, v); }

    cpVect anchorB() const { return cpPinJointGetAnchorB(constraint_); }
    void setAnchorB(const cpVect& v) { cpPinJointSetAnchorB(constraint_, v); }

    cpFloat dist() const { return cpPinJointGetDist(constraint_); }
    void setDist(cpFloat v) { cpPinJointSetDist(constraint_, v); }
};

// Slide joint (telescoping rod)
class SlideJoint : public Constraint {
public:
    static SlideJoint* create(ChipmunkBody* a, ChipmunkBody* b, const cpVect& anchorA, const cpVect& anchorB, cpFloat min, cpFloat max) {
        return new SlideJoint(a, b, anchorA, anchorB, min, max);
    }
    SlideJoint(ChipmunkBody* a, ChipmunkBody* b, const cpVect& anchorA, const cpVect& anchorB, cpFloat min_v, cpFloat max_v)
    : Constraint(cpSlideJointNew(a->body(), b->body(), anchorA, anchorB, min_v, max_v)) {}

    cpVect anchorA() const { return cpSlideJointGetAnchorA(constraint_); }
    void setAnchorA(const cpVect& v) { cpSlideJointSetAnchorA(constraint_, v); }

    cpVect anchorB() const { return cpSlideJointGetAnchorB(constraint_); }
    void setAnchorB(const cpVect& v) { cpSlideJointSetAnchorB(constraint_, v); }

    cpFloat min() const { return cpSlideJointGetMin(constraint_); }
    void setMin(cpFloat v) { cpSlideJointSetMin(constraint_, v); }

    cpFloat max() const { return cpSlideJointGetMax(constraint_); }
    void setMax(cpFloat v) { cpSlideJointSetMax(constraint_, v); }
};

// Pivot joint (free rotation around a point)
class PivotJoint : public Constraint {
public:
    static PivotJoint* create(ChipmunkBody* a, ChipmunkBody* b, const cpVect& anchorA, const cpVect& anchorB) {
        return new PivotJoint(a, b, anchorA, anchorB);
    }
    static PivotJoint* create(ChipmunkBody* a, ChipmunkBody* b, const cpVect& pivot) {
        return new PivotJoint(a, b, pivot, true);
    }
    PivotJoint(ChipmunkBody* a, ChipmunkBody* b, const cpVect& anchorA, const cpVect& anchorB)
    : Constraint(cpPivotJointNew2(a->body(), b->body(), anchorA, anchorB)) {}
    // usePivot == true selects world-to-local variant
    PivotJoint(ChipmunkBody* a, ChipmunkBody* b, const cpVect& pivot, bool usePivot)
    : Constraint(cpPivotJointNew2(
            a->body(), b->body(),
            cpBodyWorldToLocal(a->body(), pivot), cpBodyWorldToLocal(b->body(), pivot)
        )) {}

    cpVect anchorA() const { return cpPivotJointGetAnchorA(constraint_); }
    void setAnchorA(const cpVect& v) { cpPivotJointSetAnchorA(constraint_, v); }

    cpVect anchorB() const { return cpPivotJointGetAnchorB(constraint_); }
    void setAnchorB(const cpVect& v) { cpPivotJointSetAnchorB(constraint_, v); }
};

// Groove joint (pin slides along groove)
class GrooveJoint : public Constraint {
public:
    static GrooveJoint* create(ChipmunkBody* a, ChipmunkBody* b, const cpVect& grooveA, const cpVect& grooveB, const cpVect& anchorB) {
        return new GrooveJoint(a, b, grooveA, grooveB, anchorB);
    }
    GrooveJoint(ChipmunkBody* a, ChipmunkBody* b, const cpVect& grooveA, const cpVect& grooveB, const cpVect& anchorB)
    : Constraint(cpGrooveJointNew(a->body(), b->body(), grooveA, grooveB, anchorB)) {}

    cpVect grooveA() const { return cpGrooveJointGetGrooveA(constraint_); }
    void setGrooveA(const cpVect& v) { cpGrooveJointSetGrooveA(constraint_, v); }

    cpVect grooveB() const { return cpGrooveJointGetGrooveB(constraint_); }
    void setGrooveB(const cpVect& v) { cpGrooveJointSetGrooveB(constraint_, v); }

    cpVect anchorB() const { return cpGrooveJointGetAnchorB(constraint_); }
    void setAnchorB(const cpVect& v) { cpGrooveJointSetAnchorB(constraint_, v); }
};

// Damped spring (spring + damper)
class DampedSpring : public Constraint {
public:
    static DampedSpring* create(ChipmunkBody* a, ChipmunkBody* b, const cpVect& anchorA, const cpVect& anchorB,
                                 cpFloat restLength, cpFloat stiffness, cpFloat damping) {
        return new DampedSpring(a, b, anchorA, anchorB, restLength, stiffness, damping);
    }
    DampedSpring(ChipmunkBody* a, ChipmunkBody* b, const cpVect& anchorA, const cpVect& anchorB,
                 cpFloat restLength, cpFloat stiffness, cpFloat damping)
    : Constraint(cpDampedSpringNew(a->body(), b->body(), anchorA, anchorB, restLength, stiffness, damping)) {}

    cpVect anchorA() const { return cpDampedSpringGetAnchorA(constraint_); }
    void setAnchorA(const cpVect& v) { cpDampedSpringSetAnchorA(constraint_, v); }

    cpVect anchorB() const { return cpDampedSpringGetAnchorB(constraint_); }
    void setAnchorB(const cpVect& v) { cpDampedSpringSetAnchorB(constraint_, v); }

    cpFloat restLength() const { return cpDampedSpringGetRestLength(constraint_); }
    void setRestLength(cpFloat v) { cpDampedSpringSetRestLength(constraint_, v); }

    cpFloat stiffness() const { return cpDampedSpringGetStiffness(constraint_); }
    void setStiffness(cpFloat v) { cpDampedSpringSetStiffness(constraint_, v); }

    cpFloat damping() const { return cpDampedSpringGetDamping(constraint_); }
    void setDamping(cpFloat v) { cpDampedSpringSetDamping(constraint_, v); }
};

// Damped rotary spring
class DampedRotarySpring : public Constraint {
public:
    static DampedRotarySpring* create(ChipmunkBody* a, ChipmunkBody* b, cpFloat restAngle, cpFloat stiffness, cpFloat damping) {
        return new DampedRotarySpring(a, b, restAngle, stiffness, damping);
    }
    DampedRotarySpring(ChipmunkBody* a, ChipmunkBody* b, cpFloat restAngle, cpFloat stiffness, cpFloat damping)
    : Constraint(cpDampedRotarySpringNew(a->body(), b->body(), restAngle, stiffness, damping)) {}

    cpFloat restAngle() const { return cpDampedRotarySpringGetRestAngle(constraint_); }
    void setRestAngle(cpFloat v) { cpDampedRotarySpringSetRestAngle(constraint_, v); }

    cpFloat stiffness() const { return cpDampedRotarySpringGetStiffness(constraint_); }
    void setStiffness(cpFloat v) { cpDampedRotarySpringSetStiffness(constraint_, v); }

    cpFloat damping() const { return cpDampedRotarySpringGetDamping(constraint_); }
    void setDamping(cpFloat v) { cpDampedRotarySpringSetDamping(constraint_, v); }
};

// Rotary limit joint
class RotaryLimitJoint : public Constraint {
public:
    static RotaryLimitJoint* create(ChipmunkBody* a, ChipmunkBody* b, cpFloat min, cpFloat max) {
        return new RotaryLimitJoint(a, b, min, max);
    }
    RotaryLimitJoint(ChipmunkBody* a, ChipmunkBody* b, cpFloat min_v, cpFloat max_v)
    : Constraint(cpRotaryLimitJointNew(a->body(), b->body(), min_v, max_v)) {}

    cpFloat min() const { return cpRotaryLimitJointGetMin(constraint_); }
    void setMin(cpFloat v) { cpRotaryLimitJointSetMin(constraint_, v); }

    cpFloat max() const { return cpRotaryLimitJointGetMax(constraint_); }
    void setMax(cpFloat v) { cpRotaryLimitJointSetMax(constraint_, v); }
};

// Simple motor
class SimpleMotor : public Constraint {
public:
    static SimpleMotor* create(ChipmunkBody* a, ChipmunkBody* b, cpFloat rate) {
        return new SimpleMotor(a, b, rate);
    }
    SimpleMotor(ChipmunkBody* a, ChipmunkBody* b, cpFloat rate_v)
    : Constraint(cpSimpleMotorNew(a->body(), b->body(), rate_v)) {}

    cpFloat rate() const { return cpSimpleMotorGetRate(constraint_); }
    void setRate(cpFloat v) { cpSimpleMotorSetRate(constraint_, v); }
};

// Gear joint
class GearJoint : public Constraint {
public:
    static GearJoint* create(ChipmunkBody* a, ChipmunkBody* b, cpFloat phase, cpFloat ratio) {
        return new GearJoint(a, b, phase, ratio);
    }
    GearJoint(ChipmunkBody* a, ChipmunkBody* b, cpFloat phase_v, cpFloat ratio_v)
    : Constraint(cpGearJointNew(a->body(), b->body(), phase_v, ratio_v)) {}

    cpFloat phase() const { return cpGearJointGetPhase(constraint_); }
    void setPhase(cpFloat v) { cpGearJointSetPhase(constraint_, v); }

    cpFloat ratio() const { return cpGearJointGetRatio(constraint_); }
    void setRatio(cpFloat v) { cpGearJointSetRatio(constraint_, v); }
};

// Ratchet joint
class RatchetJoint : public Constraint {
public:
    static RatchetJoint* create(ChipmunkBody* a, ChipmunkBody* b, cpFloat phase, cpFloat ratchet) {
        return new RatchetJoint(a, b, phase, ratchet);
    }
    RatchetJoint(ChipmunkBody* a, ChipmunkBody* b, cpFloat phase_v, cpFloat ratchet_v)
    : Constraint(cpRatchetJointNew(a->body(), b->body(), phase_v, ratchet_v)) {}

    cpFloat angle() const { return cpRatchetJointGetAngle(constraint_); }
    void setAngle(cpFloat v) { cpRatchetJointSetAngle(constraint_, v); }

    cpFloat phase() const { return cpRatchetJointGetPhase(constraint_); }
    void setPhase(cpFloat v) { cpRatchetJointSetPhase(constraint_, v); }

    cpFloat ratchet() const { return cpRatchetJointGetRatchet(constraint_); }
    void setRatchet(cpFloat v) { cpRatchetJointSetRatchet(constraint_, v); }
};

#endif // CHIPMUNK_CONSTRAINTS_HPP
