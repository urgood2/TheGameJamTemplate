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

#define CP_DATA_POINTER_TYPE void*
#define CP_GROUP_TYPE void*
#define CP_COLLISION_TYPE_TYPE void*

// Forward declarations
class ChipmunkSpace;
class ChipmunkBaseObject;

/**
 * Allows you to add composite objects to a space in a single method call.
 * The easiest way to implement the ChipmunkObject interface is to add a
 * std::vector<ChipmunkBaseObject*> member to your class, initialize it with
 * ChipmunkObjectFlatten(), and return it in chipmunkObjects().
 */
class ChipmunkObject {
protected:
    std::vector<ChipmunkBaseObject*> _objects;

public:
    // Default: just return whatever you've pushed into _objects.
    virtual std::vector<ChipmunkBaseObject*> chipmunkObjects() const {
        return _objects;
    }

    virtual ~ChipmunkObject() = default;
};

/**
 * This protocol is implemented by objects that know how to add themselves to a space.
 * It's used internally as part of the ChipmunkObject protocol. You should never need to
 * implement it yourself.
 */
class ChipmunkBaseObject : public ChipmunkObject {
public:
    virtual void addToSpace(ChipmunkSpace* space) = 0;
    virtual void removeFromSpace(ChipmunkSpace* space) = 0;
};

// #include "ChipmunkBody.hpp"
// #include "ChipmunkShape.hpp"
// #include "ChipmunkConstraints.hpp"
// #include "ChipmunkSpace.hpp"
// #include "ChipmunkMultiGrab.hpp"


