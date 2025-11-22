#pragma once

#include <memory>
#include "../../third_party/chipmunk/include/chipmunk/chipmunk.h"

namespace physics
{
    struct CpBodyDeleter
    {
        void operator()(cpBody *b) const noexcept
        {
            if (b)
            {
                cpBodyFree(b);
            }
        }
    };

    struct CpConstraintDeleter
    {
        void operator()(cpConstraint *c) const noexcept
        {
            if (c)
            {
                cpConstraintFree(c);
            }
        }
    };

    struct CpShapeDeleter
    {
        void operator()(cpShape *s) const noexcept
        {
            if (s)
            {
                cpShapeFree(s);
            }
        }
    };

    struct CpSpaceDeleter
    {
        void operator()(cpSpace *s) const noexcept
        {
            if (s)
            {
                cpSpaceFree(s);
            }
        }
    };

    using BodyPtr = std::unique_ptr<cpBody, CpBodyDeleter>;
    using ConstraintPtr = std::unique_ptr<cpConstraint, CpConstraintDeleter>;
    using ShapePtr = std::unique_ptr<cpShape, CpShapeDeleter>;
    using SpacePtr = std::unique_ptr<cpSpace, CpSpaceDeleter>;
}
