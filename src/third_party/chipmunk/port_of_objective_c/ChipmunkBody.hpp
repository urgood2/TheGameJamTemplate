// ChipmunkBody.hpp
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

#include <vector>
#include <chipmunk/chipmunk.h>
#include "ObjectiveChipmunk.hpp"

class ChipmunkShape;
class ChipmunkSpace;

class ChipmunkBody : public ChipmunkBaseObject {
public:
    // Factory methods
    static ChipmunkBody* BodyFromCPBody(cpBody* body);
    static ChipmunkBody* BodyWithMassAndMoment(cpFloat mass, cpFloat moment);
    static ChipmunkBody* StaticBody();
    static ChipmunkBody* KinematicBody();

    // Constructor / Destructor
    explicit ChipmunkBody(cpFloat mass, cpFloat moment);
    ~ChipmunkBody();

    // Access underlying cpBody and transform
    cpBody* body() const { return const_cast<cpBody*>(&_body); }
    cpTransform transform() const { return _body.transform; }

    // Properties: getters and setters
    cpBodyType type() const;
    void setType(cpBodyType value);

    cpFloat mass() const;
    void setMass(cpFloat value);

    cpFloat moment() const;
    void setMoment(cpFloat value);

    cpVect centerOfGravity() const;
    void setCenterOfGravity(cpVect value);

    cpVect position() const;
    void setPosition(cpVect value);

    cpVect velocity() const;
    void setVelocity(cpVect value);

    cpVect force() const;
    void setForce(cpVect value);

    cpFloat angle() const;
    void setAngle(cpFloat value);

    cpFloat angularVelocity() const;
    void setAngularVelocity(cpFloat value);

    cpFloat torque() const;
    void setTorque(cpFloat value);

    void* userData() const;
    void setUserData(void* data);

    bool isSleeping() const;
    cpFloat kineticEnergy() const;
    ChipmunkSpace* space() const;

    // Coordinate transforms
    cpVect localToWorld(cpVect v) const;
    cpVect worldToLocal(cpVect v) const;

    // Velocity at points
    cpVect velocityAtLocalPoint(cpVect p) const;
    cpVect velocityAtWorldPoint(cpVect p) const;

    // Force / Impulse
    void applyForce(cpVect force, cpVect point);
    void applyForceAtWorldPoint(cpVect force, cpVect point);
    void applyImpulse(cpVect impulse, cpVect point);
    void applyImpulseAtWorldPoint(cpVect impulse, cpVect point);

    // Activation / Sleep
    void activate();
    void activateStatic(ChipmunkShape* filter);
    void sleepWithGroup(ChipmunkBody* group);
    void sleep();

    // ChipmunkObject protocol
    std::vector<ChipmunkBaseObject*> chipmunkObjects() const override;

    // ChipmunkBaseObject protocol
    void addToSpace(ChipmunkSpace* space) override;
    void removeFromSpace(ChipmunkSpace* space) override;

    // Overrideable integration methods
    virtual void updateVelocity(cpFloat dt, cpVect gravity, cpFloat damping);
    virtual void updatePosition(cpFloat dt);

private:
    cpBody _body;
    void* _userData = nullptr;

    // Integration callbacks
    static void VelocityFunc(cpBody* body, cpVect gravity, cpFloat damping, cpFloat dt);
    static void PositionFunc(cpBody* body, cpFloat dt);
    bool methodIsOverridden(void* methodPtr) const;
};

// Double-dispatch helpers for ChipmunkSpace
class ChipmunkSpaceDispatch {
public:
    ChipmunkBody* addBody(ChipmunkBody* obj);
    ChipmunkBody* removeBody(ChipmunkBody* obj);
};