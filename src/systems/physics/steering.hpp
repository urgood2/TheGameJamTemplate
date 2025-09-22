#pragma once
#include <cmath>
#include <entt/entt.hpp>
#include <memory>
#include <raylib.h>
#include <third_party/chipmunk/include/chipmunk/chipmunk.h>
#include <vector>

#define M_PI 3.14159265358979323846

// Forward decl to avoid heavy includes
namespace physics {
struct ColliderComponent; // has std::shared_ptr<cpBody> body;
cpVect raylibToChipmunkCoords(const Vector2 &); // from your physics utils
} // namespace physics

struct BodyComponent { // OPTIONAL legacy support
  cpBody *body = nullptr;
};

//============================================
// Steerable Agent System for EnTT + Chipmunk2D
//============================================
struct SteerableComponent {
  bool enabled = false;
  float mass = 1.0f;
  float maxSpeed = 100.0f;
  float maxForce = 2000.0f;
  float maxTurnRate = 2.0f * float(M_PI);
  float turnMultiplier = 2.0f;

  cpVect heading{1, 0}, side{0, 1};

  // composed
  cpVect steeringForce{0, 0};

  // per-behavior forces
  cpVect seekForce{0, 0}, fleeForce{0, 0}, pursuitForce{0, 0}, evadeForce{0, 0};
  cpVect wanderForce{0, 0}, pathFollowForce{0, 0};
  cpVect separationForce{0, 0}, alignmentForce{0, 0}, cohesionForce{0, 0};

  // timed external inputs (applied in Steering::Update)
  cpVect timedForce{0, 0};
  float timedForceTimeLeft = 0.f, timedForceDuration = 0.f;
  cpVect timedImpulsePerSec{0, 0}; // distribute an impulse over 's' seconds
  float timedImpulseTimeLeft = 0.f, timedImpulseDuration = 0.f;

  // behavior flags
  bool isSeeking = false, isFleeing = false, isPursuing = false,
       isEvading = false;
  bool isWandering = false, isPathFollowing = false;
  bool isSeparating = false, isAligning = false, isCohesing = false;

  // wander state
  cpVect wanderTarget{0, 0};
  float wanderRadius = 40.f, wanderDistance = 40.f, wanderJitter = 20.f;

  // path follow (simple waypoint list)
  std::vector<cpVect> path;
  int pathIndex = 0;
  float pathArriveRadius = 16.f;
};

namespace Steering {

//--------------------------------------------
// Utilities
//--------------------------------------------
extern cpVect truncate(const cpVect &v, float maxLen);

extern cpVect pointToWorld(const cpVect &local, const cpVect &heading,
                           const cpVect &side, const cpVect &position);

extern cpVect pointToLocal(const cpVect &p, const cpVect &heading,
                           const cpVect &side, const cpVect &pos);

extern cpVect vectorToWorld(const cpVect &v, const cpVect &heading,
                            const cpVect &side);

extern cpVect rotateAroundOrigin(const cpVect &v, float r);

// Small adapter: get cpBody* from either BodyComponent or
// physics::ColliderComponent
extern cpBody *get_cpBody(entt::registry &r, entt::entity e);

//--------------------------------------------
// Lifecycle
//--------------------------------------------
extern void MakeSteerable(entt::registry &r, entt::entity e, float maxSpeed,
                          float maxForce,
                          float maxTurnRate = 2.0f * float(M_PI),
                          float turnMul = 2.0f);

//--------------------------------------------
// Frame update
//--------------------------------------------
extern void Update(entt::registry &r, entt::entity e, float dt);

//--------------------------------------------
// Behaviors
//--------------------------------------------

// Seek (Chipmunk coords)
extern void SeekPoint(entt::registry &r, entt::entity e, const cpVect &target,
                      float deceleration = 1.0f, float weight = 1.0f);

// Separation (Chipmunk coords)
extern void Separate(entt::registry &r, entt::entity e, float separationRadius,
                     const std::vector<entt::entity> &neighbors,
                     float weight = 1.0f);

// Wander (Chipmunk coords)
extern void Wander(entt::registry &r, entt::entity e, float jitter,
                   float radius, float distance, float weight = 1.0f);

// FLee
extern void FleePoint(entt::registry &r, entt::entity e, const cpVect &threat,
                      float panicDist, float weight = 1.f);

extern void Pursuit(entt::registry &r, entt::entity e, entt::entity target,
                    float weight = 1.f);

extern void Evade(entt::registry &r, entt::entity e, entt::entity pursuer,
                  float weight = 1.f);

extern void Align(entt::registry &r, entt::entity e,
                  const std::vector<entt::entity> &neighbors, float alignRadius,
                  float weight = 1.f);

extern void Cohesion(entt::registry &r, entt::entity e,
                     const std::vector<entt::entity> &neighbors,
                     float cohesionRadius, float weight = 1.f);

extern void SetPath(entt::registry &r, entt::entity e,
                    std::vector<cpVect> waypoints, float arriveRadius = 16.f);

extern void PathFollow(entt::registry &r, entt::entity e, float decel = 1.0f,
                       float weight = 1.0f);

extern void ApplySteeringForce(entt::registry &r, entt::entity e, float f,
                               float radians, float seconds);

extern void ApplySteeringImpulse(entt::registry &r, entt::entity e, float f,
                                 float radians, float seconds);

//--------------------------------------------
// Raylib helpers (prevent Y-flip mistakes)
//--------------------------------------------
extern void SeekObject(entt::registry &r, entt::entity e, entt::entity target,
                       float decel = 1.f, float weight = 1.f);

} // namespace Steering