// CraneSystem.cpp (snippet)
#include "crane_system.hpp"
#include "physics_world.hpp" // your class
#include <raylib.h>          // for mouse input if desired

static void AttachHook_PostStep(cpSpace* space, cpBody* hook, void* crateBodyVoid) {
  auto* crateBody = static_cast<cpBody*>(crateBodyVoid);
  // Attach at hook’s current position:
  cpConstraint* joint = cpPivotJointNew(hook, crateBody, cpBodyGetPosition(hook));
  cpSpaceAddConstraint(space, joint);
  // stash on hook userData if you prefer, or store via a CraneState*
  // (we’ll set it from the begin callback where we have state access)
}

static cpBool HookCrate_Begin(cpArbiter* arb, cpSpace* space, void* userData) {
  auto* crane = static_cast<CraneState*>(userData);
  if (crane->hookJoint) return cpTrue; // already attached

  CP_ARBITER_GET_BODIES(arb, hook, crate);
  // Queue the attach in post-step (safe point to mutate the space)
  cpSpaceAddPostStepCallback(space, (cpPostStepFunc)AttachHook_PostStep, hook, crate);
  return cpTrue; // sensors ignore return anyway
}

void InitCrane(physics::PhysicsWorld& pw, CraneState& s) {
  cpSpace* space = pw.space; // you expose it publicly in your impl

  // --- Tags / collision types
  pw.AddCollisionTag("hook_sensor");
  pw.AddCollisionTag("crate");
  s.HOOK_SENSOR = pw.TypeForTag("hook_sensor");
  s.CRATE       = pw.TypeForTag("crate");

  // ground
  {
    cpShape* floor = cpSegmentShapeNew(cpSpaceGetStaticBody(space), cpv(-320,-240), cpv(320,-240), 0.0f);
    cpShapeSetElasticity(floor, 1.0f);
    cpShapeSetFriction(floor, 1.0f);
    cpShapeSetFilter(floor, cpShapeFilterNew(CP_NO_GROUP, CP_ALL_CATEGORIES, CP_ALL_CATEGORIES));
    cpSpaceAddShape(space, floor);
  }

  // Dolly (dynamic translational, no rotation)
  {
    s.dollyBody = cpSpaceAddBody(space, cpBodyNew(10.0, INFINITY)); // INF moment locks rotation
    cpBodySetPosition(s.dollyBody, cpv(0, 100));
    cpSpaceAddShape(space, cpBoxShapeNew(s.dollyBody, 30, 30, 0.0));
    // Groove rail to slide along Y=100
    cpSpaceAddConstraint(space,
      cpGrooveJointNew(cpSpaceGetStaticBody(space), s.dollyBody, cpv(-250,100), cpv(250,100), cpvzero));

    // Pivot as servo to pull dolly toward target X
    s.dollyServo = cpSpaceAddConstraint(space,
      cpPivotJointNew(cpSpaceGetStaticBody(space), s.dollyBody, cpBodyGetPosition(s.dollyBody)));
    cpConstraintSetMaxForce(s.dollyServo, 10000);
    cpConstraintSetMaxBias(s.dollyServo, 100); // speed clamp
  }

  // Hook (sensor)
  {
    s.hookBody = cpSpaceAddBody(space, cpBodyNew(1.0, INFINITY));
    cpBodySetPosition(s.hookBody, cpv(0, 50));

    cpShape* hookSensor = cpSpaceAddShape(space, cpCircleShapeNew(s.hookBody, 10, cpvzero));
    cpShapeSetSensor(hookSensor, cpTrue);
    cpShapeSetCollisionType(hookSensor, s.HOOK_SENSOR);

    // Slide joint as winch line from dolly to hook
    s.winchServo = cpSpaceAddConstraint(space,
      cpSlideJointNew(s.dollyBody, s.hookBody, cpvzero, cpvzero, 0.0, INFINITY));
    cpConstraintSetMaxForce(s.winchServo, 30000);
    cpConstraintSetMaxBias(s.winchServo, 60);   // winch speed
  }

  // Crate
  {
    cpBody* box = cpSpaceAddBody(space, cpBodyNew(30.0, cpMomentForBox(30.0, 50, 50)));
    cpBodySetPosition(box, cpv(200, -200));
    cpShape* sh = cpSpaceAddShape(space, cpBoxShapeNew(box, 50, 50, 0.0));
    cpShapeSetFriction(sh, 0.7);
    cpShapeSetCollisionType(sh, s.CRATE);
  }

  // Collision handler: hook sensor vs crate -> schedule attach
  {
    cpCollisionHandler* h = cpSpaceAddCollisionHandler(space, s.HOOK_SENSOR, s.CRATE);
    h->userData = &s;
    h->beginFunc = [](cpArbiter* a, cpSpace* sp, void* ud)->cpBool {
      return HookCrate_Begin(a, sp, ud);
    };
  }

  // Gravity & damping similar to demo
  cpSpaceSetIterations(space, 30);
  cpSpaceSetGravity(space, cpv(0, -100));
  cpSpaceSetDamping(space, 0.8);
}

void UpdateCrane(physics::PhysicsWorld& pw, CraneState& s, double dt) {
  cpSpace* space = pw.space;

  // Mouse drives target:
  Vector2 m = GetMousePosition();
  // 1) “Servo” the dolly by moving pivot’s AnchorA along rail:
  cpPivotJointSetAnchorA(s.dollyServo, cpv(m.x, 100));

  // 2) “Winch” by shortening/lengthening max cable
  cpFloat maxLen = cpfmax(100.0f - (cpFloat)m.y, 50.0f);
  cpSlideJointSetMax(s.winchServo, maxLen);

  // 3) Drop with right click
  if (IsMouseButtonPressed(MOUSE_BUTTON_RIGHT) && s.hookJoint) {
    cpSpaceRemoveConstraint(space, s.hookJoint);
    cpConstraintFree(s.hookJoint);
    s.hookJoint = nullptr;
  }

  // If we just attached in a post-step, pick up pointer:
  // (Optional) You can capture the created joint inside AttachHook_PostStep by
  // storing to a global or by using a wrapper that has access to `s`.

  cpSpaceStep(space, dt);
}