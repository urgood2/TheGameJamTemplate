#pragma once

#include "../../third_party/chipmunk/include/chipmunk/chipmunk.h"

// CraneSystem.hpp (snippet)
struct CraneState {
  cpBody* dollyBody{nullptr};
  cpBody* hookBody{nullptr};
  cpConstraint* dollyServo{nullptr};   // cpPivotJoint
  cpConstraint* winchServo{nullptr};   // cpSlideJoint
  cpConstraint* hookJoint{nullptr};    // cpPivotJoint (temporary attach)
  cpCollisionType HOOK_SENSOR{0}, CRATE{0};
};