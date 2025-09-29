#include "physics_world.hpp"

#include "../../third_party/chipmunk/include/chipmunk/chipmunk.h"
#include "../../third_party/chipmunk/include/chipmunk/cpMarch.h"
#include "../../third_party/chipmunk/include/chipmunk/cpPolyline.h"
#include "spdlog/spdlog.h"
#include "systems/physics/physics_components.hpp"
#include "third_party/chipmunk/include/chipmunk/chipmunk_unsafe.h"
#include "util/common_headers.hpp"
#include <algorithm>
#include <memory>
#include <raylib.h>
#include <unordered_map>
#include <vector>

namespace physics {
  
  // lua arbiter struct
  std::pair<entt::entity, entt::entity> LuaArbiter::entities() const {
      cpShape *sa, *sb;
      cpArbiterGetShapes(arb, &sa, &sb);

      auto getE = [](cpShape* s) -> entt::entity {
          if (void* ud = cpShapeGetUserData(s)) {
              return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(ud));
          }
          // Return a valid entt::entity that represents null:
          return entt::entity{entt::null}; // or: static_cast<entt::entity>(entt::null)
      };

      return { getE(sa), getE(sb) };
  }

  std::pair<std::string, std::string> LuaArbiter::tags(PhysicsWorld& W) const {
      cpShape *sa, *sb;
      cpArbiterGetShapes(arb, &sa, &sb);
      auto fA = cpShapeGetFilter(sa);
      auto fB = cpShapeGetFilter(sb);
      return { W.GetTagFromCategory(int(fA.categories)),
              W.GetTagFromCategory(int(fB.categories)) };
  }

  cpVect LuaArbiter::normal() const { return cpArbiterGetNormal(arb); }

  float LuaArbiter::total_impulse_length() const {
      cpVect J = cpArbiterTotalImpulse(arb);
      return cpvlength(J);
  }
  cpVect LuaArbiter::total_impulse() const { return cpArbiterTotalImpulse(arb); }

  
  // --- Flags (read) ---
  bool LuaArbiter::is_first_contact() const { return cpArbiterIsFirstContact(arb) == cpTrue; }
  bool LuaArbiter::is_removal()       const { return cpArbiterIsRemoval(arb)       == cpTrue; }

  // --- Mutate (only meaningful in preSolve) ---
  void LuaArbiter::set_friction(float f) const    { cpArbiterSetFriction(arb, f); }
  void LuaArbiter::set_elasticity(float e) const  { cpArbiterSetRestitution(arb, e); }
  void LuaArbiter::set_surface_velocity(float vx, float vy) const { cpArbiterSetSurfaceVelocity(arb, cpv(vx, vy)); }
  void LuaArbiter::ignore() const                 { cpArbiterIgnore(arb); }



// --- Debug helpers (place near the top, after includes) ---
static inline uintptr_t EID(entt::entity e) {
  return static_cast<uintptr_t>(e);
}
static inline uintptr_t EID(void *p) { return reinterpret_cast<uintptr_t>(p); }
static inline uintptr_t BID(const cpBody *b) {
  return reinterpret_cast<uintptr_t>(b);
}
static inline uintptr_t SID(const cpShape *s) {
  return reinterpret_cast<uintptr_t>(s);
}
static inline std::string TagOf(const PhysicsWorld *W, const cpShape *s) {
  const auto f = cpShapeGetFilter(const_cast<cpShape *>(s));
  return W->GetTagFromCategory((int)f.categories);
}

template <class Fn> static void ForEachShape(ColliderComponent &c, Fn &&fn) {
  if (c.shape)
    fn(c.shape.get());
  for (auto &p : c.extraShapes)
    if (p.shape)
      fn(p.shape.get());
}

template <class Fn>
static void ForEachShapeConst(const ColliderComponent &c, Fn &&fn) {
  if (c.shape)
    fn(c.shape.get());
  for (auto &p : c.extraShapes)
    if (p.shape)
      fn(p.shape.get());
}

size_t PhysicsWorld::GetShapeCount(entt::entity e) const {
  const auto &c = registry->get<ColliderComponent>(e);
  return (c.shape ? 1 : 0) + c.extraShapes.size();
}

cpBB PhysicsWorld::GetShapeBB(entt::entity e, size_t index) const {
  const auto &c = registry->get<ColliderComponent>(e);
  if (index == 0 && c.shape)
    return cpShapeGetBB(c.shape.get());
  size_t i = index - (c.shape ? 1 : 0);
  if (i < c.extraShapes.size())
    return cpShapeGetBB(c.extraShapes[i].shape.get());
  return cpBBNew(0, 0, 0, 0);
}

std::shared_ptr<cpSpace> MakeSharedSpace() {
  return std::shared_ptr<cpSpace>(cpSpaceNew(),
                                  [](cpSpace *space) { cpSpaceFree(space); });
}

std::shared_ptr<cpBody> MakeSharedBody(cpFloat mass, cpFloat moment) {
  return std::shared_ptr<cpBody>(cpBodyNew(mass, moment),
                                 [](cpBody *body) { cpBodyFree(body); });
}

std::shared_ptr<cpShape> MakeSharedShape(cpBody *body, cpFloat width,
                                         cpFloat height) {
  assert(body && "MakeSharedShape: body must be non-null");

  return std::shared_ptr<cpShape>(cpBoxShapeNew(body, width, height, 0.0),
                                  [](cpShape *shape) { cpShapeFree(shape); });
}

PhysicsWorld::PhysicsWorld(entt::registry *registry, float meter,
                           float gravityX, float gravityY) {
  space = cpSpaceNew();
  cpSpaceSetUserData(space, this);

  cpSpaceSetGravity(space, cpv(gravityX, gravityY));
  cpSpaceSetIterations(space, 10);
  this->registry = registry;
  SPDLOG_INFO("PhysicsWorld init: gravity=({}, {}), iters={}",
            gravityX, gravityY, 10);
}

PhysicsWorld::~PhysicsWorld() {
  if (space) {
    registry->view<ColliderComponent>().each([&](auto, auto &c) {
      if (c.shape)
        cpSpaceRemoveShape(space, c.shape.get());
      for (auto &s : c.extraShapes) {
        if (s.shape)
          cpSpaceRemoveShape(space, s.shape.get());
      }
      if (c.body)
        cpSpaceRemoveBody(space, c.body.get());
    });

    if (mouseJoint) {
      cpSpaceRemoveConstraint(space, mouseJoint);
      cpConstraintFree(mouseJoint);
      mouseJoint = nullptr;
    }
    if (controlBody) {
      cpSpaceRemoveBody(space, controlBody);
      cpBodyFree(controlBody);
      controlBody = nullptr;
    }

    cpSpaceFree(space);
    space = nullptr;
  }
  SPDLOG_INFO("PhysicsWorld shutdown: removed all dynamic bodies/shapes; mouseJoint? {} controlBody? {}",
            mouseJoint ? "yes":"no", controlBody ? "yes":"no");

}

void PhysicsWorld::Update(float deltaTime) {
  cpSpaceStep(space, deltaTime);
#ifndef NDEBUG
  // Sanity check: ensure no shapes have null bodies (which indicates a
  // detach/free mismatch)
  cpSpaceEachShape(
      space,
      +[](cpShape *s, void *) {
        assert(cpShapeGetBody(s) &&
               "Shape has null body (detached/free mismatch)");
      },
      nullptr);
#endif
}

void PhysicsWorld::PostUpdate() {
  collisionEnter.clear();
  collisionExit.clear();
  triggerEnter.clear();
  triggerExit.clear();

  registry->view<ColliderComponent>().each([](auto &collider) {
    collider.collisionEnter.clear();
    collider.collisionActive.clear();
    collider.collisionExit.clear();
    collider.triggerEnter.clear();
    collider.triggerActive.clear();
    collider.triggerExit.clear();
  });
}

void PhysicsWorld::SetGravity(float gravityX, float gravityY) {
  cpSpaceSetGravity(space, cpv(gravityX, gravityY));
}

void PhysicsWorld::SetMeter(float meter) { this->meter = meter; }

void PhysicsWorld::OnCollisionBegin(cpArbiter *arb) {
  cpShape *shapeA, *shapeB;
  cpArbiterGetShapes(arb, &shapeA, &shapeB);

  SPDLOG_DEBUG("[Begin] A sensor? {}  B sensor? {}  A tag={}  B tag={}",
               (int)cpShapeGetSensor(shapeA), (int)cpShapeGetSensor(shapeB),
               GetTagFromCategory(cpShapeGetFilter(shapeA).categories),
               GetTagFromCategory(cpShapeGetFilter(shapeB).categories));

  bool isTriggerA = cpShapeGetSensor(shapeA);
  bool isTriggerB = cpShapeGetSensor(shapeB);

  void *dataA = cpShapeGetUserData(shapeA);
  void *dataB = cpShapeGetUserData(shapeB);

  if (!dataA || !dataB)
    return;

  entt::entity entityA =
      static_cast<entt::entity>(reinterpret_cast<uintptr_t>(dataA));
  entt::entity entityB =
      static_cast<entt::entity>(reinterpret_cast<uintptr_t>(dataB));

  const auto filterA = cpShapeGetFilter(shapeA);
  const auto filterB = cpShapeGetFilter(shapeB);

  std::string tagA = GetTagFromCategory(filterA.categories);
  std::string tagB = GetTagFromCategory(filterB.categories);

  // Get per-shape tags BEFORE any swapping
  const std::string aTag = GetTagFromCategory(filterA.categories);
  const std::string bTag = GetTagFromCategory(filterB.categories);

  // Use a sorted key ONLY for map storage
  std::string k1 = aTag, k2 = bTag;
  if (k2 < k1)
    std::swap(k1, k2);
  const std::string key = MakeKey(k1, k2);

  auto allows = [&](const std::string &tSensor, const std::string &tOther) {
    const auto &v = triggerTags[tSensor].triggers;
    const int catOther = triggerTags[tOther].category;
    return std::find(v.begin(), v.end(), catOther) != v.end();
  };
  
  SPDLOG_TRACE("Trigger check: A('{}')->B('{}') allowed={}", tagA, tagB, allows(tagA, tagB));


  if (isTriggerA || isTriggerB) {
    // determine tagA/tagB earlier as you do
    if (isTriggerA && allows(tagA, tagB)) {
      registry->get<ColliderComponent>(entityA).triggerEnter.push_back(dataB);
      triggerEnter[key].push_back(dataB);
      triggerActive[key].push_back(dataB);
    }
    if (isTriggerB && allows(tagB, tagA)) {
      registry->get<ColliderComponent>(entityB).triggerEnter.push_back(dataA);
      triggerEnter[key].push_back(dataA);
      triggerActive[key].push_back(dataA);
    }
    return;
  }

  if ((filterA.categories & filterB.mask) == 0 ||
      (filterB.categories & filterA.mask) == 0)
    return;

  CollisionEvent event = {dataA, dataB};
  cpContactPointSet contactPoints = cpArbiterGetContactPointSet(arb);
  cpVect normal = cpArbiterGetNormal(arb);

  if (contactPoints.count > 0) {
    event.x1 = contactPoints.points[0].pointA.x;
    event.y1 = contactPoints.points[0].pointA.y;
    event.x2 = contactPoints.points[0].pointB.x;
    event.y2 = contactPoints.points[0].pointB.y;
    event.nx = normal.x;
    event.ny = normal.y;
    
    SPDLOG_TRACE("Contacts: count={} n=({:.2f},{:.2f}) A({:.1f},{:.1f}) B({:.1f},{:.1f})",
             contactPoints.count, event.nx, event.ny, event.x1, event.y1, event.x2, event.y2);

  }

  collisionEnter[key].push_back(event);
  collisionActive[key].push_back(event);

  if (registry->all_of<ColliderComponent>(entityA))
    registry->get<ColliderComponent>(entityA).collisionEnter.push_back(event);
  event.objectA = dataB;
  event.objectB = dataA;
  if (registry->all_of<ColliderComponent>(entityB))
    registry->get<ColliderComponent>(entityB).collisionEnter.push_back(event);
}

void PhysicsWorld::OnCollisionEnd(cpArbiter *arb) {
  cpShape *shapeA, *shapeB;
  cpArbiterGetShapes(arb, &shapeA, &shapeB);

  bool isTriggerA = cpShapeGetSensor(shapeA);
  bool isTriggerB = cpShapeGetSensor(shapeB);

  void *dataA = cpShapeGetUserData(shapeA);
  void *dataB = cpShapeGetUserData(shapeB);

  if (!dataA || !dataB)
    return;

  entt::entity entityA =
      static_cast<entt::entity>(reinterpret_cast<uintptr_t>(dataA));
  entt::entity entityB =
      static_cast<entt::entity>(reinterpret_cast<uintptr_t>(dataB));

  const auto filterA = cpShapeGetFilter(shapeA);
  const auto filterB = cpShapeGetFilter(shapeB);

  std::string tagA = GetTagFromCategory(filterA.categories);
  std::string tagB = GetTagFromCategory(filterB.categories);

  std::string k1 = tagA, k2 = tagB;
  if (k2 < k1) std::swap(k1, k2);
  std::string key = MakeKey(k1, k2);

  if (isTriggerA || isTriggerB) {
    if (registry->all_of<ColliderComponent>(entityA)) {
      auto &colliderA = registry->get<ColliderComponent>(entityA);
      colliderA.triggerExit.push_back(dataB);

      colliderA.triggerActive.erase(std::remove(colliderA.triggerActive.begin(),
                                                colliderA.triggerActive.end(),
                                                dataB),
                                    colliderA.triggerActive.end());
    }

    if (registry->all_of<ColliderComponent>(entityB)) {
      auto &colliderB = registry->get<ColliderComponent>(entityB);
      colliderB.triggerExit.push_back(dataA);

      colliderB.triggerActive.erase(std::remove(colliderB.triggerActive.begin(),
                                                colliderB.triggerActive.end(),
                                                dataA),
                                    colliderB.triggerActive.end());
    }

    triggerExit[key].push_back(dataA);

    auto &activeTriggers = triggerActive[key];
    activeTriggers.erase(
        std::remove(activeTriggers.begin(), activeTriggers.end(), dataA),
        activeTriggers.end());
    return;
  }

  if ((filterA.categories & filterB.mask) == 0 ||
      (filterB.categories & filterA.mask) == 0)
    return;

  CollisionEvent event = {dataA, dataB};
  collisionExit[key].push_back(event);

  auto &activeCollisions = collisionActive[key];
  activeCollisions.erase(
      std::remove_if(activeCollisions.begin(), activeCollisions.end(),
                     [dataA, dataB](const CollisionEvent &e) {
                       return (e.objectA == dataA && e.objectB == dataB) ||
                              (e.objectA == dataB && e.objectB == dataA);
                     }),
      activeCollisions.end());
      
  SPDLOG_TRACE("Active prune: key='{}' collisions now={}", key, (int)activeCollisions.size());

  if (registry->all_of<ColliderComponent>(entityA)) {
    auto &colliderA = registry->get<ColliderComponent>(entityA);

    colliderA.collisionExit.push_back(event);
    colliderA.collisionActive.erase(
        std::remove_if(
            colliderA.collisionActive.begin(), colliderA.collisionActive.end(),
            [dataB](const CollisionEvent &e) { return e.objectB == dataB; }),
        colliderA.collisionActive.end());
  }

  if (registry->all_of<ColliderComponent>(entityB)) {
    auto &colliderB = registry->get<ColliderComponent>(entityB);

    event.objectA = dataB;
    event.objectB = dataA;

    colliderB.collisionExit.push_back(event);
    colliderB.collisionActive.erase(
        std::remove_if(
            colliderB.collisionActive.begin(), colliderB.collisionActive.end(),
            [dataA](const CollisionEvent &e) { return e.objectB == dataA; }),
        colliderB.collisionActive.end());
  }

  // Drop any glue constraints we created for this body pair
  StickySeparate(arb);
}

void PhysicsWorld::EnableCollisionBetween(
    const std::string &tag1, const std::vector<std::string> &tags) {
  auto &masks = collisionTags[tag1].masks;
  for (const auto &tag : tags) {
    masks.push_back(collisionTags[tag].category);
  }
  SPDLOG_DEBUG("Collision {} '{}' <-> {}", "enable", tag1, fmt::join(tags, ", "));

}

void PhysicsWorld::DisableCollisionBetween(
    const std::string &tag1, const std::vector<std::string> &tags) {
  auto &masks = collisionTags[tag1].masks;
  for (const auto &tag : tags) {
    masks.erase(
        std::remove(masks.begin(), masks.end(), collisionTags[tag].category),
        masks.end());
  }
  SPDLOG_DEBUG("Collision {} '{}' x {}", "disable", tag1, fmt::join(tags, ", "));
}

void PhysicsWorld::EnableTriggerBetween(const std::string &a,
                                        const std::vector<std::string> &bs) {
  for (const auto &b : bs) {
    triggerTags[a].triggers.push_back(triggerTags[b].category);
    triggerTags[b].triggers.push_back(triggerTags[a].category); // add reverse

    // NEW: also allow them at the filter level so an arbiter can be created.
    if (collisionTags.contains(a) && collisionTags.contains(b)) {
      auto &ma = collisionTags[a].masks;
      auto &mb = collisionTags[b].masks;
      const int ca = collisionTags[a].category;
      const int cb = collisionTags[b].category;

      if (std::find(ma.begin(), ma.end(), cb) == ma.end())
        ma.push_back(cb);
      if (std::find(mb.begin(), mb.end(), ca) == mb.end())
        mb.push_back(ca);
    }
    SPDLOG_DEBUG("Trigger enable '{}' <-> '{}': categories {} <-> {}",
             a, b, triggerTags[a].category, triggerTags[b].category);

  }
  // Push updated filters to already-added shapes
  // (same logic as in UpdateCollisionMasks, but for 'a' and each 'b')
  auto pushFiltersFor = [&](const std::string &tag) {
    if (!collisionTags.contains(tag))
      return;
    const int targetCategory = collisionTags[tag].category;
    registry->view<ColliderComponent>().each([&](auto, auto &c) {
      ForEachShape(c, [&](cpShape *s) {
        const auto f = cpShapeGetFilter(s);
        if ((int)f.categories == targetCategory) {
          ApplyCollisionFilter(s, tag);
          cpShapeSetCollisionType(s, _tagToCollisionType[tag]);
        }
      });
    });
  };
  pushFiltersFor(a);
  for (const auto &b : bs)
    pushFiltersFor(b);
}

void PhysicsWorld::DisableTriggerBetween(const std::string &tag1,
                                         const std::vector<std::string> &tags) {
  for (const auto &tag : tags) {
    auto &triggers = triggerTags[tag1].triggers;
    triggers.erase(std::remove(triggers.begin(), triggers.end(),
                               triggerTags[tag].category),
                   triggers.end());
  }
}

const std::vector<CollisionEvent> &
PhysicsWorld::GetCollisionEnter(const std::string &type1,
                                const std::string &type2) {
  return collisionEnter[MakeKey(type1, type2)];
}

const std::vector<void *> &
PhysicsWorld::GetTriggerEnter(const std::string &type1,
                              const std::string &type2) {
  return triggerEnter[MakeKey(type1, type2)];
}

void PhysicsWorld::SetCollisionTags(const std::vector<std::string> &tags) {
  collisionTags.clear();
  triggerTags.clear();
  categoryToTag.clear();
  _tagToCollisionType.clear();

  _nextCollisionType = 1; // reset once here

  int category = 1;
  for (const auto &tag : tags) {
    collisionTags[tag] = {category, {}, {}};
    triggerTags[tag] = {category, {}, {}};
    categoryToTag[category] = tag;

    _tagToCollisionType[tag] = _nextCollisionType++;

    category <<= 1;
    EnsureWildcardInstalled(_tagToCollisionType[tag]); // add this
    SPDLOG_DEBUG("Tag '{}' => category={} collisionType={}", tag, category, _tagToCollisionType[tag]);
  }
}

std::string PhysicsWorld::GetTagFromCategory(int category) const{
  for (const auto &[tag, collisionTag] : collisionTags) {
    if (collisionTag.category == category) {
      return tag;
    }
  }

  for (const auto &[tag, triggerTag] : triggerTags) {
    if (triggerTag.category == category) {
      return tag;
    }
  }

  return "unknown";
}

auto PhysicsWorld::RegisterFluidVolume(const std::string &tag, float density,
                                       float drag) -> void {
  const cpCollisionType t = TypeForTag(tag);
  _fluidByType[t] = FluidConfig{density, drag};
  EnsureWildcardInstalled(t);
}

auto PhysicsWorld::AddFluidSensorAABB(float left, float bottom, float right,
                                      float top, const std::string &tag)
    -> void {
  cpBody *staticBody = cpSpaceGetStaticBody(space);
  const cpCollisionType type = TypeForTag(tag);
  const cpBB bb = cpBBNew(left, bottom, right, top);
  cpShape *sensor = cpBoxShapeNew2(staticBody, bb, 0.0);
  cpShapeSetSensor(sensor, cpTrue);
  cpShapeSetCollisionType(sensor, type);
  cpSpaceAddShape(space, sensor);
  
  SPDLOG_DEBUG("FluidSensor AABB: ({:.1f},{:.1f})–({:.1f},{:.1f}) tag='{}'",
             left, bottom, right, top, tag);

}

auto PhysicsWorld::WaterPreSolveNative(cpArbiter *arb,
                                       cpCollisionType waterType) -> void {
  cpShape *sA;
  cpShape *sB;
  cpArbiterGetShapes(arb, &sA, &sB);
  cpShape *water = (cpShapeGetCollisionType(sA) == waterType) ? sA : sB;
  cpShape *other = (water == sA) ? sB : sA;

  if (cpPolyShapeGetCount(other) <= 0)
    return;

  cpBody *body = cpShapeGetBody(other);
  const float level = cpShapeGetBB(water).t;

  const int count = cpPolyShapeGetCount(other);
  std::vector<cpVect> clipped;
  clipped.reserve(count + 1);

  for (int i = 0, j = count - 1; i < count; j = i, ++i) {
    const cpVect a = cpBodyLocalToWorld(body, cpPolyShapeGetVert(other, j));
    const cpVect b = cpBodyLocalToWorld(body, cpPolyShapeGetVert(other, i));
    if (a.y < level)
      clipped.push_back(a);

    const float a_level = a.y - level;
    const float b_level = b.y - level;
    if (a_level * b_level < 0.0f) {
      const float t =
          std::fabs(a_level) / (std::fabs(a_level) + std::fabs(b_level));
      clipped.push_back(cpvlerp(a, b, t));
    }
  }

  const int clippedCount = static_cast<int>(clipped.size());
  if (clippedCount < 3)
    return;

  // SPDLOG_TRACE("Fluid: area={:.2f} displacedMass={:.3f} centroid=({:.1f},{:.1f}) GM=({:.1f},{:.1f})",
  //            area, displacedMass, centroid.x, centroid.y, g.x, g.y);

  FluidConfig cfg{0.00014f, 2.0f};
  if (auto it = _fluidByType.find(waterType); it != _fluidByType.end())
    cfg = it->second;

  const float dt = cpSpaceGetCurrentTimeStep(cpBodyGetSpace(body));
  const cpVect g = cpSpaceGetGravity(cpBodyGetSpace(body));

  const float area = cpAreaForPoly(clippedCount, clipped.data(), 0.0f);
  const float displacedMass = area * cfg.density;
  const cpVect centroid = cpCentroidForPoly(clippedCount, clipped.data());

  cpBodyApplyImpulseAtWorldPoint(body, cpvmult(g, -displacedMass * dt),
                                 centroid);

  const cpVect v_centroid = cpBodyGetVelocityAtWorldPoint(body, centroid);
  const float v_len =
      cpvlengthsq(v_centroid) > 0.f ? cpvlength(v_centroid) : 0.f;
  if (v_len > 0.f) {
    const cpVect n = cpvnormalize(v_centroid);
    const float k = k_scalar_body(body, centroid, n);
    const float damping = area * cfg.drag * cfg.density;
    const float v_coef = cpfexp(-damping * dt * k);
    const cpVect impulse =
        cpvmult(cpvsub(cpvmult(v_centroid, v_coef), v_centroid), 1.0f / k);
    cpBodyApplyImpulseAtWorldPoint(body, impulse, centroid);
  }

  const cpVect cog = cpBodyLocalToWorld(body, cpBodyGetCenterOfGravity(body));
  const float w_damping =
      cpMomentForPoly(cfg.drag * cfg.density * area, clippedCount,
                      clipped.data(), cpvneg(cog), 0.0f);
  const float new_w = cpBodyGetAngularVelocity(body) *
                      cpfexp(-w_damping * dt / cpBodyGetMoment(body));
  cpBodySetAngularVelocity(body, new_w);
  
  
}

cpConstraint *PhysicsWorld::MakeBreakableSlideJoint(
    cpBody *a, cpBody *b, cpVect anchorA, cpVect anchorB, cpFloat minDist,
    cpFloat maxDist, cpFloat breakingForce, cpFloat triggerRatio,
    bool collideBodies, bool useFatigue, cpFloat fatigueRate) {
  cpConstraint *j = cpSlideJointNew(a, b, anchorA, anchorB, minDist, maxDist);
  cpConstraintSetCollideBodies(j, collideBodies ? cpTrue : cpFalse);
  cpSpaceAddConstraint(space, j);

  physics::BJ_Attach(j, breakingForce, triggerRatio,
                     useFatigue ? cpTrue : cpFalse, fatigueRate);
  return j;
}

void PhysicsWorld::MakeConstraintBreakable(cpConstraint *c,
                                           cpFloat breakingForce,
                                           cpFloat triggerRatio,
                                           bool useFatigue,
                                           cpFloat fatigueRate) {
  physics::BJ_Attach(c, breakingForce, triggerRatio,
                     useFatigue ? cpTrue : cpFalse, fatigueRate);
}

// instance: look up pair first, then wildcard
cpBool PhysicsWorld::OnPreSolve(cpArbiter *arb) {
  cpShape *sa, *sb;
  cpArbiterGetShapes(arb, &sa, &sb);
  cpCollisionType ta = cpShapeGetCollisionType(sa);
  cpCollisionType tb = cpShapeGetCollisionType(sb);

  // --- Built-in fluid step (native), executes BEFORE Lua handlers.
  if (auto it = _fluidByType.find(ta); it != _fluidByType.end()) {
    WaterPreSolveNative(arb, ta);
  } else if (auto it2 = _fluidByType.find(tb); it2 != _fluidByType.end()) {
    WaterPreSolveNative(arb, tb);
  }

  // --- One-way platform native step ---
  auto allowPass = [&](cpShape *platformShape, cpShape *otherShape,
                       const OneWayPlatformData &cfg) -> bool {
    // Arbiter normal points from A -> B. We need the normal pointing out of the
    // platform.
    cpVect n = cpArbiterGetNormal(arb);
    if (platformShape == sb)
      n = cpvneg(n); // flip if platform is B

    // If motion is from the "back" side (dot < 0), ignore this contact.
    // That lets the other object pass through.
    if (cpvdot(n, cfg.n) < 0)
      return cpArbiterIgnore(arb);
    return cpTrue;
  };

  if (auto it = _oneWayByType.find(ta); it != _oneWayByType.end()) {
    SPDLOG_TRACE("OneWay: platformTag='{}' pass={} dot={:.3f}",
             TagOf(this, platformShape), /*true if kept*/ cpvdot(n, cfg.n) >= 0, cpvdot(n, cfg.n));

    if (!allowPass(sa, sb, it->second))
      return cpFalse;
  } else if (auto it = _oneWayByType.find(tb); it != _oneWayByType.end()) {
    if (!allowPass(sb, sa, it->second))
      return cpFalse;
  }

  // canonicalize pair key (min,max) so A-B == B-A
  auto key = PairKey(std::min(ta, tb), std::max(ta, tb));

  // pair pre-solve?
  LuaArbiter luaArb{arb};
  if (auto it = _luaPairHandlers.find(key); it != _luaPairHandlers.end()) {
    if (it->second.pre_solve.valid()) {
      sol::protected_function_result r = it->second.pre_solve(luaArb);
      if (!r.valid()) {
        sol::error err = r;
        SPDLOG_ERROR("pair pre_solve: {}", err.what());
        throw;
        return cpTrue;
      }
      // allow Lua to return boolean to accept/reject contact
      if (r.return_count() > 0 && r.get_type(0) == sol::type::boolean)
        return r.get<bool>();
      return cpTrue;
    }
  }
  // wildcard pre-solve? (any side)
  if (auto wi = _luaWildcardHandlers.find(ta);
      wi != _luaWildcardHandlers.end()) {
    if (wi->second.pre_solve.valid()) {
      auto r = wi->second.pre_solve(luaArb);
      // SPDLOG_TRACE("PreSolve Lua: pairKey={} -> returned={}", (unsigned long long)key,
      //        (r.return_count()>0 && r.get_type(0)==sol::type::boolean) ? (r.get<bool>()?"true":"false") : "none");

      if (!r.valid()) {
        sol::error err = r;
        SPDLOG_ERROR("wildcard({}) pre_solve: {}", (int)ta, err.what());
        throw;
        return cpTrue;
      }
      if (r.return_count() > 0 && r.get_type(0) == sol::type::boolean)
        return r.get<bool>();
      return cpTrue;
    }
  }
  if (auto wi = _luaWildcardHandlers.find(tb);
      wi != _luaWildcardHandlers.end()) {
    if (wi->second.pre_solve.valid()) {
      SPDLOG_TRACE("PreSolve Lua: pairKey={} -> returned={}", (unsigned long long)key,
             (r.return_count()>0 && r.get_type(0)==sol::type::boolean) ? (r.get<bool>()?"true":"false") : "none");

      auto r = wi->second.pre_solve(luaArb);
      if (!r.valid()) {
        sol::error err = r;
        SPDLOG_ERROR("wildcard({}) pre_solve: {}", (int)tb, err.what());
        throw;
        return cpTrue;
      }
      if (r.return_count() > 0 && r.get_type(0) == sol::type::boolean)
        return r.get<bool>();
      return cpTrue;
    }
  }
  return cpTrue;
}

void PhysicsWorld::OnPostSolve(cpArbiter *arb) {
  // Sticky glue creation (no-op if the pair isn't configured)
  StickyPostSolve(arb);

  cpShape *sa, *sb;
  cpArbiterGetShapes(arb, &sa, &sb);
  cpCollisionType ta = cpShapeGetCollisionType(sa);
  cpCollisionType tb = cpShapeGetCollisionType(sb);
  auto key = PairKey(std::min(ta, tb), std::max(ta, tb));
  
  SPDLOG_TRACE("PostSolve: pairKey={} ta={} tb={}", (unsigned long long)key, (int)ta, (int)tb);

  LuaArbiter luaArb{arb};

  auto call = [&](sol::protected_function &fn) {
    if (fn.valid()) {
      auto r = fn(luaArb);
      if (!r.valid()) {
        sol::error err = r;
        SPDLOG_ERROR("post_solve: {}", err.what());
        throw;
      }
    }
  };

  if (auto it = _luaPairHandlers.find(key); it != _luaPairHandlers.end())
    call(it->second.post_solve);
  if (auto wi = _luaWildcardHandlers.find(ta); wi != _luaWildcardHandlers.end())
    call(wi->second.post_solve);
  if (auto wi = _luaWildcardHandlers.find(tb); wi != _luaWildcardHandlers.end())
    call(wi->second.post_solve);
}

void PhysicsWorld::UpdateColliderTag(entt::entity entity,
                                     const std::string &newTag) {
  if (!collisionTags.contains(newTag)) {
    SPDLOG_DEBUG("Invalid tag: {}", newTag);
    return;
  }
  auto &c = registry->get<ColliderComponent>(entity);
  ForEachShape(c, [&](cpShape *s) {
    ApplyCollisionFilter(s, newTag);
    cpShapeSetCollisionType(s, _tagToCollisionType[newTag]);
    SPDLOG_DEBUG("UpdateColliderTag: entity={} -> '{}', shape={}", EID(entity), newTag, SID(s));

  });
  
}

void PhysicsWorld::PrintCollisionTags() {
  for (const auto &[tag, collisionTag] : collisionTags) {
    SPDLOG_DEBUG("Tag: {} | Category: {} | Masks: ", tag,
                 collisionTag.category);
    for (int mask : collisionTag.masks)
      SPDLOG_DEBUG("{}", mask);
  }
}

void PhysicsWorld::AddCollisionTag(const std::string &tag) {
  if (collisionTags.find(tag) != collisionTags.end())
    return;

  int category = 1;
  while (categoryToTag.contains(category))
    category <<= 1;

  collisionTags[tag] = {category, {}, {}};
  triggerTags[tag] = {category, {}, {}};
  categoryToTag[category] = tag;
  _tagToCollisionType[tag] = _nextCollisionType++;

  EnsureWildcardInstalled(_tagToCollisionType[tag]);
}

void PhysicsWorld::RemoveCollisionTag(const std::string &tag) {
  if (!collisionTags.contains(tag))
    return;

  int category = collisionTags[tag].category;
  collisionTags.erase(tag);
  triggerTags.erase(tag);
  categoryToTag.erase(category);

  registry->view<ColliderComponent>().each([&](auto, auto &c) {
    ForEachShape(c, [&](cpShape *s) {
      const auto f = cpShapeGetFilter(s);
      if ((int)f.categories == category) {
        ApplyCollisionFilter(s, "default");
        cpShapeSetCollisionType(s, _tagToCollisionType["default"]);
      }
    });
  });
}

void PhysicsWorld::UpdateCollisionMasks(
    const std::string &tag, const std::vector<std::string> &collidableTags) {
  if (!collisionTags.contains(tag))
    return;

  // rewrite masks for the tag
  collisionTags[tag].masks.clear();
  for (const auto &t : collidableTags) {
    if (collisionTags.contains(t))
      collisionTags[tag].masks.push_back(collisionTags[t].category);
  }

  const int targetCategory = collisionTags[tag].category;

  registry->view<ColliderComponent>().each([&](auto, auto &c) {
    ForEachShape(c, [&](cpShape *s) {
      const auto f = cpShapeGetFilter(s);
      if ((int)f.categories == targetCategory) {
        ApplyCollisionFilter(s, tag);
        cpShapeSetCollisionType(s, _tagToCollisionType[tag]);
      }
    });
  });
  
  SPDLOG_DEBUG("Masks for '{}': [{}]", tag, fmt::join(collisionTags[tag].masks, ", "));

}

void PhysicsWorld::ApplyCollisionFilter(cpShape *shape, const std::string &tag) {
  auto it = collisionTags.find(tag);
  if (it == collisionTags.end()) {
    assert(false && "ApplyCollisionFilter: invalid tag");
    return;
  }
  const auto &ct = it->second;

  cpBitmask maskBits = 0;
  for (int cat : ct.masks) {
    maskBits |= static_cast<cpBitmask>(cat);
  }

  // IMPORTANT: do NOT expand empty masks. Empty mask = collides with nothing.
  cpShapeFilter filter = {
      /*group*/ 0,
      /*categories*/ static_cast<cpBitmask>(ct.category),
      /*mask*/ maskBits // may be 0 on purpose
  };
  cpShapeSetFilter(shape, filter);

  SPDLOG_TRACE("ApplyFilter shape={} tag='{}' cat={:#x} mask={:#x}",
               SID(shape), tag,
               (unsigned)filter.categories, (unsigned)filter.mask);
}

std::vector<RaycastHit> PhysicsWorld::Raycast(float x1, float y1, float x2,
                                              float y2) {
  std::vector<RaycastHit> hits;
  
  SPDLOG_TRACE("Raycast: ({:.1f},{:.1f})->({:.1f},{:.1f}) hits={}", x1,y1,x2,y2,(int)hits.size());


  cpSpaceSegmentQuery(
      space, cpv(x1, y1), cpv(x2, y2), 0, CP_SHAPE_FILTER_ALL,
      [](cpShape *shape, cpVect point, cpVect normal, cpFloat alpha,
         void *data) {
        auto *hits = static_cast<std::vector<RaycastHit> *>(data);
        RaycastHit hit;
        hit.shape = shape;
        hit.point = point;
        hit.normal = normal;
        hit.fraction = alpha;
        hits->push_back(hit);
      },
      &hits);

  return hits;
}

std::vector<void *> PhysicsWorld::GetObjectsInArea(float x1, float y1, float x2,
                                                   float y2) {
  std::vector<void *> objects;

  cpBB bb = cpBBNew(std::min(x1, x2), std::min(y1, y2), std::max(x1, x2),
                    std::max(y1, y2));
  cpSpaceBBQuery(
      space, bb, CP_SHAPE_FILTER_ALL,
      [](cpShape *shape, void *data) {
        auto *objects = static_cast<std::vector<void *> *>(data);
        void *userData = cpShapeGetUserData(shape);
        if (userData)
          objects->push_back(userData);
      },
      &objects);
      
  SPDLOG_TRACE("AABB query: ({:.1f},{:.1f})–({:.1f},{:.1f}) objects={}",
             x1,y1,x2,y2,(int)objects.size());


  return objects;
}

std::shared_ptr<cpShape> PhysicsWorld::AddShape(cpBody *body, float width,
                                                float height,
                                                const std::string &tag) {
  auto shape = MakeSharedShape(body, width, height);

  ApplyCollisionFilter(shape.get(), tag);
  cpShapeSetCollisionType(shape.get(), _tagToCollisionType[tag]);

  cpSpaceAddShape(space, shape.get());

  return shape;
}

auto MakeShapeFor(const std::string &shapeType, cpBody *body, float a, float b,
                  float c, float d, const std::vector<cpVect> &points)
    -> std::shared_ptr<cpShape> {
  if (shapeType == "rectangle") {
    return std::shared_ptr<cpShape>(cpBoxShapeNew(body, a, b, 0.0f),
                                    cpShapeFree);
  } else if (shapeType == "circle") {
    return std::shared_ptr<cpShape>(cpCircleShapeNew(body, a, cpvzero),
                                    cpShapeFree);
  } else if (shapeType == "polygon") {
    if (!points.empty()) {
      return std::shared_ptr<cpShape>(cpPolyShapeNew(body, (int)points.size(),
                                                     points.data(),
                                                     cpTransformIdentity, 0.0f),
                                      cpShapeFree);
    } else {
      std::vector<cpVect> verts = {{0, 0}, {a, 0}, {a / 2, b}};
      return std::shared_ptr<cpShape>(cpPolyShapeNew(body, (int)verts.size(),
                                                     verts.data(),
                                                     cpTransformIdentity, 0.0f),
                                      cpShapeFree);
    }
  } else if (shapeType == "chain") {
    const auto &verts =
        points.empty() ? std::vector<cpVect>{{0, 0}, {a, b}, {c, d}} : points;
    return std::shared_ptr<cpShape>(cpPolyShapeNew(body, (int)verts.size(),
                                                   verts.data(),
                                                   cpTransformIdentity, 1.0f),
                                    cpShapeFree);
  }
  throw std::invalid_argument("Unsupported shapeType: " + shapeType);
}

void PhysicsWorld::AddShapeToEntity(entt::entity e, const std::string &tag,
                                    const std::string &shapeType, float a,
                                    float b, float c, float d, bool isSensor,
                                    const std::vector<cpVect> &points) {
  if (!collisionTags.contains(tag))
    AddCollisionTag(tag); // ensure tag exists
  auto &col = registry->get<ColliderComponent>(e);
  if (!col.body) {
    // make a default dynamic body if none exists yet
    col.body = MakeSharedBody(
        isSensor ? 0.0f : 1.0f,
        cpMomentForBox(1.0f, std::max(1.f, a), std::max(1.f, b)));
    cpBodySetUserData(col.body.get(),
                      reinterpret_cast<void *>(static_cast<uintptr_t>(e)));
    cpSpaceAddBody(space, col.body.get());
  }

  auto shape = MakeShapeFor(shapeType, col.body.get(), a, b, c, d, points);

  ApplyCollisionFilter(shape.get(), tag);
  cpShapeSetCollisionType(shape.get(), _tagToCollisionType[tag]);
  cpShapeSetSensor(shape.get(), isSensor);
  cpShapeSetUserData(shape.get(),
                     reinterpret_cast<void *>(static_cast<uintptr_t>(e)));

  cpSpaceAddShape(space, shape.get());
  
  SPDLOG_DEBUG("AddShapeToEntity: e={} '{}' type={} sensor={} shape={} body={}",
             EID(e), tag, shapeType, isSensor, SID(shape.get()), BID(col.body.get()));


  // if there is no primary yet, use this as primary for back-compat
  if (!col.shape) {
    col.shape = shape;
    col.shapeType = (shapeType == "circle")      ? ColliderShapeType::Circle
                    : (shapeType == "polygon")   ? ColliderShapeType::Polygon
                    : (shapeType == "chain")     ? ColliderShapeType::Chain
                    : (shapeType == "rectangle") ? ColliderShapeType::Rectangle
                                                 : col.shapeType;
    col.tag = tag;
    col.isSensor = isSensor;
  } else {
    col.extraShapes.push_back(
        {shape,
         (shapeType == "circle")    ? ColliderShapeType::Circle
         : (shapeType == "polygon") ? ColliderShapeType::Polygon
         : (shapeType == "chain")   ? ColliderShapeType::Chain
                                    : ColliderShapeType::Rectangle,
         tag, isSensor});
  }
}

bool PhysicsWorld::RemoveShapeAt(entt::entity e, size_t index) {
  auto &c = registry->get<ColliderComponent>(e);
  // index 0 == primary; >=1 index into extraShapes (index-1)
  if (index == 0) {
    if (!c.shape)
      return false;
    cpSpaceRemoveShape(space, c.shape.get());
    c.shape.reset();
    SPDLOG_DEBUG("RemoveShapeAt: e={} index={} ok", EID(e), index);

    return true;
  }
  size_t i = index - 1;
  if (i >= c.extraShapes.size())
    return false;
  cpSpaceRemoveShape(space, c.extraShapes[i].shape.get());
  c.extraShapes.erase(c.extraShapes.begin() + i);
  SPDLOG_DEBUG("RemoveShapeAt: e={} index={} ok", EID(e), index);

  return true;
}

void PhysicsWorld::ClearAllShapes(entt::entity e) {
  auto &c = registry->get<ColliderComponent>(e);
  if (c.shape) {
    cpSpaceRemoveShape(space, c.shape.get());
    c.shape.reset();
  }
  for (auto &s : c.extraShapes) {
    if (s.shape)
      cpSpaceRemoveShape(space, s.shape.get());
  }
  c.extraShapes.clear();
  SPDLOG_DEBUG("ClearAllShapes: e={} cleared", EID(e));

}

entt::entity GetEntityFromBody(cpBody *body) {
  void *data = cpBodyGetUserData(body);
  if (data) {
    return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(data));
  }
  return entt::null;
}

void SetEntityToShape(cpShape *shape, entt::entity entity) {
  cpShapeSetUserData(shape,
                     reinterpret_cast<void *>(static_cast<uintptr_t>(entity)));
}

void SetEntityToBody(cpBody *body, entt::entity entity) {
  cpBodySetUserData(body,
                    reinterpret_cast<void *>(static_cast<uintptr_t>(entity)));
}

void PhysicsWorld::AddCollider(entt::entity entity, const std::string &tag,
                               const std::string &shapeType, float a, float b,
                               float c, float d, bool isSensor,
                               const std::vector<cpVect> &points) {
  if (registry->all_of<ColliderComponent>(entity)) {
    AddShapeToEntity(entity, tag, shapeType, a, b, c, d, isSensor, points);
    return;
  }

  // original single-shape path, but now ends identical to the helper:
  auto body =
      MakeSharedBody(isSensor ? 0.0f : 1.0f, cpMomentForBox(1.0f, a, b));
  auto shape = MakeShapeFor(shapeType, body.get(), a, b, c, d, points);

  ApplyCollisionFilter(shape.get(), tag);
  cpShapeSetCollisionType(shape.get(), _tagToCollisionType[tag]);
  cpShapeSetSensor(shape.get(), isSensor);
  registry->emplace<ColliderComponent>(
      entity, ColliderComponent{
                  body, shape, tag, isSensor,
                  (shapeType == "circle")    ? ColliderShapeType::Circle
                  : (shapeType == "polygon") ? ColliderShapeType::Polygon
                  : (shapeType == "chain")   ? ColliderShapeType::Chain
                                             : ColliderShapeType::Rectangle});
  SPDLOG_DEBUG("AddCollider: e={} '{}' type={} sensor={} body={} shape={}",
             EID(entity), tag, shapeType, isSensor, BID(body.get()), SID(shape.get()));

  cpShapeSetUserData(shape.get(),
                     reinterpret_cast<void *>(static_cast<uintptr_t>(entity)));
  cpBodySetUserData(body.get(),
                    reinterpret_cast<void *>(static_cast<uintptr_t>(entity)));

  cpSpaceAddBody(space, body.get());
  cpSpaceAddShape(space, shape.get());
}

void PhysicsWorld::Seek(entt::entity entity, float targetX, float targetY,
                        float maxSpeed) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect desiredVelocity =
      cpvnormalize(cpv(targetX - currentPos.x, targetY - currentPos.y));
  desiredVelocity = cpvmult(desiredVelocity, maxSpeed);

  cpVect currentVelocity = cpBodyGetVelocity(collider.body.get());
  cpVect steeringForce = cpvsub(desiredVelocity, currentVelocity);

  cpBodyApplyForceAtWorldPoint(collider.body.get(), steeringForce, currentPos);
}

void PhysicsWorld::Arrive(entt::entity entity, float targetX, float targetY,
                          float maxSpeed, float slowingRadius) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect toTarget = cpv(targetX - currentPos.x, targetY - currentPos.y);
  float distance = cpvlength(toTarget);

  float speed = maxSpeed;
  if (distance < slowingRadius) {
    speed = maxSpeed * (distance / slowingRadius);
  }

  cpVect desiredVelocity = cpvmult(cpvnormalize(toTarget), speed);
  cpVect currentVelocity = cpBodyGetVelocity(collider.body.get());
  cpVect steeringForce = cpvsub(desiredVelocity, currentVelocity);

  cpBodyApplyForceAtWorldPoint(collider.body.get(), steeringForce, currentPos);
}

void PhysicsWorld::Wander(entt::entity entity, float wanderRadius,
                          float wanderDistance, float jitter, float maxSpeed) {
  auto &collider = registry->get<ColliderComponent>(entity);

  static float wanderAngle = 0.0f;
  wanderAngle += jitter * ((rand() % 200 - 100) / 100.0f);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect circleCenter = cpvadd(
      currentPos, cpvmult(cpvnormalize(cpBodyGetVelocity(collider.body.get())),
                          wanderDistance));
  cpVect displacement =
      cpv(wanderRadius * cos(wanderAngle), wanderRadius * sin(wanderAngle));
  cpVect target = cpvadd(circleCenter, displacement);

  Seek(entity, target.x, target.y, maxSpeed);
}

void PhysicsWorld::Separate(entt::entity entity,
                            const std::vector<entt::entity> &others,
                            float separationRadius, float maxForce) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect steering = cpvzero;

  for (auto other : others) {
    if (other == entity)
      continue;

    auto &otherCollider = registry->get<ColliderComponent>(other);
    cpVect otherPos = cpBodyGetPosition(otherCollider.body.get());

    float distance = cpvlength(cpvsub(otherPos, currentPos));
    if (distance < separationRadius) {
      cpVect diff = cpvnormalize(cpvsub(currentPos, otherPos));
      steering = cpvadd(steering, cpvmult(diff, maxForce / distance));
    }
  }

  cpBodyApplyForceAtWorldPoint(collider.body.get(), steering, currentPos);
}

void PhysicsWorld::ApplyForce(entt::entity entity, float forceX, float forceY) {
  auto &collider = registry->get<ColliderComponent>(entity);
  cpBodyApplyForceAtWorldPoint(collider.body.get(), cpv(forceX, forceY),
                               cpBodyGetPosition(collider.body.get()));
}

void PhysicsWorld::RegisterPairPreSolve(const std::string &a,
                                        const std::string &b,
                                        sol::protected_function fn) {
  cpCollisionType ta = TypeForTag(a), tb = TypeForTag(b);
  _luaPairHandlers[PairKey(ta, tb)].pre_solve = std::move(fn);
  EnsurePairInstalled(ta, tb);
}

void PhysicsWorld::RegisterPairPostSolve(const std::string &a,
                                         const std::string &b,
                                         sol::protected_function fn) {
  cpCollisionType ta = TypeForTag(a), tb = TypeForTag(b);
  _luaPairHandlers[PairKey(ta, tb)].post_solve = std::move(fn);
  EnsurePairInstalled(ta, tb);
}

void PhysicsWorld::RegisterWildcardPreSolve(const std::string &tag,
                                            sol::protected_function fn) {
  cpCollisionType t = TypeForTag(tag);
  _luaWildcardHandlers[t].pre_solve = std::move(fn);
  EnsureWildcardInstalled(t);
}

void PhysicsWorld::RegisterWildcardPostSolve(const std::string &tag,
                                             sol::protected_function fn) {
  cpCollisionType t = TypeForTag(tag);
  _luaWildcardHandlers[t].post_solve = std::move(fn);
  EnsureWildcardInstalled(t);
}

void PhysicsWorld::ClearPairHandlers(const std::string &a,
                                     const std::string &b) {
  cpCollisionType ta = TypeForTag(a), tb = TypeForTag(b);
  _luaPairHandlers.erase(PairKey(ta, tb));
}

void PhysicsWorld::ClearWildcardHandlers(const std::string &tag) {
  cpCollisionType t = TypeForTag(tag);
  _luaWildcardHandlers.erase(t);
}

void PhysicsWorld::EnsureWildcardInstalled(cpCollisionType t) {
  if (_installedWildcards.count(t))
    return;
  cpCollisionHandler *h = cpSpaceAddWildcardHandler(space, t);
  h->userData = this;
  h->beginFunc = &PhysicsWorld::C_Begin;         // CHANGED
  h->preSolveFunc = &PhysicsWorld::C_PreSolve;   // existing
  h->postSolveFunc = &PhysicsWorld::C_PostSolve; // existing
  h->separateFunc = &PhysicsWorld::C_Separate;   // CHANGED
  _installedWildcards.insert(t);
}

void PhysicsWorld::EnsurePairInstalled(cpCollisionType ta, cpCollisionType tb) {
  const uint64_t key = PairKey(ta, tb);
  if (_installedPairs.count(key))
    return;
  cpCollisionHandler *h = cpSpaceAddCollisionHandler(space, ta, tb);
  h->userData = this;
  h->beginFunc = &PhysicsWorld::C_Begin;         // CHANGED
  h->preSolveFunc = &PhysicsWorld::C_PreSolve;   // existing
  h->postSolveFunc = &PhysicsWorld::C_PostSolve; // existing
  h->separateFunc = &PhysicsWorld::C_Separate;   // CHANGED
  _installedPairs.insert(key);
}

cpBool PhysicsWorld::C_Begin(cpArbiter *a, cpSpace *, void *d) {
  return static_cast<PhysicsWorld *>(d)->OnBegin(a);
}
void PhysicsWorld::C_Separate(cpArbiter *a, cpSpace *, void *d) {
  static_cast<PhysicsWorld *>(d)->OnSeparate(a);
}

cpBool PhysicsWorld::OnBegin(cpArbiter *arb) {

  cpShape *shapeA, *shapeB;
  cpArbiterGetShapes(arb, &shapeA, &shapeB);

  // --- Keep your current bookkeeping (triggers, collisionEnter/Active, etc.)
  // Move your existing OnCollisionBegin(arb) body here (or call it).
  // NOTE: you can keep the function and call it if you prefer.
  OnCollisionBegin(arb); // if you keep the old function

  // --- Now run Lua begin handlers (pair first, then wildcards on each side)
  cpShape *sa, *sb;
  cpArbiterGetShapes(arb, &sa, &sb);
  cpCollisionType ta = cpShapeGetCollisionType(sa);
  cpCollisionType tb = cpShapeGetCollisionType(sb);
  const uint64_t key = PairKey(std::min(ta, tb), std::max(ta, tb));
  
  LuaArbiter luaArb{arb};

  auto call = [&](sol::protected_function &fn) -> std::optional<bool> {
    if (!fn.valid())
      return std::nullopt;
    sol::protected_function_result r = fn(luaArb);
    if (!r.valid()) {
      sol::error err = r;
      SPDLOG_ERROR("begin: {}", err.what());
      throw;
      return std::nullopt;
    }
    if (r.return_count() > 0 && r.get_type(0) == sol::type::boolean) {
      return r.get<bool>();
    }
    return std::nullopt;
  };

  bool accept = true;

  if (auto it = _luaPairHandlers.find(key); it != _luaPairHandlers.end()) {
    if (auto v = call(it->second.begin); v.has_value() && v.value() == false)
      accept = false;
  }
  if (auto wi = _luaWildcardHandlers.find(ta);
      wi != _luaWildcardHandlers.end()) {
    if (auto v = call(wi->second.begin); v.has_value() && v.value() == false)
      accept = false;
  }
  if (auto wi = _luaWildcardHandlers.find(tb);
      wi != _luaWildcardHandlers.end()) {
    if (auto v = call(wi->second.begin); v.has_value() && v.value() == false)
      accept = false;
  }
  
  SPDLOG_DEBUG("Begin: sa={} sb={} ta={} tb={} tags=({}, {}) sensors=({}, {}) accept={}",
             SID(sa), SID(sb), (int)ta, (int)tb,
             TagOf(this, sa), TagOf(this, sb),
             (int)cpShapeGetSensor(sa), (int)cpShapeGetSensor(sb),
             accept);

  return accept ? cpTrue : cpFalse;
}

void PhysicsWorld::OnSeparate(cpArbiter *arb) {
  // --- Keep your current bookkeeping for exits
  OnCollisionEnd(arb); // reuse your existing function body

  // --- Lua separate
  cpShape *sa, *sb;
  cpArbiterGetShapes(arb, &sa, &sb);
  cpCollisionType ta = cpShapeGetCollisionType(sa);
  cpCollisionType tb = cpShapeGetCollisionType(sb);
  const uint64_t key = PairKey(std::min(ta, tb), std::max(ta, tb));
  
  SPDLOG_DEBUG("Separate: sa={} sb={} ta={} tb={} tags=({}, {})",
             SID(sa), SID(sb), (int)ta, (int)tb, TagOf(this, sa), TagOf(this, sb));

  LuaArbiter luaArb{arb};

  auto call = [&](sol::protected_function &fn) {
    if (!fn.valid())
      return;
    auto r = fn(luaArb);
    if (!r.valid()) {
      sol::error err = r;
      SPDLOG_ERROR("separate: {}", err.what());
      throw;
    }
  };

  if (auto it = _luaPairHandlers.find(key); it != _luaPairHandlers.end())
    call(it->second.separate);
  if (auto wi = _luaWildcardHandlers.find(ta); wi != _luaWildcardHandlers.end())
    call(wi->second.separate);
  if (auto wi = _luaWildcardHandlers.find(tb); wi != _luaWildcardHandlers.end())
    call(wi->second.separate);
}

void PhysicsWorld::InstallDefaultBeginHandlersForAllTags() {
  for (auto &[tag, ct] : collisionTags) {
    EnsureWildcardInstalled(
        _tagToCollisionType[tag]); // installs C_Begin → OnBegin
  }
}

void PhysicsWorld::ApplyImpulse(entt::entity entity, float impulseX,
                                float impulseY) {
  auto &collider = registry->get<ColliderComponent>(entity);
  cpBodyApplyImpulseAtWorldPoint(collider.body.get(), cpv(impulseX, impulseY),
                                 cpBodyGetPosition(collider.body.get()));
}

void PhysicsWorld::SetDamping(entt::entity entity, float damping) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect velocity = cpBodyGetVelocity(collider.body.get());
  cpVect dampedVelocity = cpvmult(velocity, 1.0f - damping);
  cpBodySetVelocity(collider.body.get(), dampedVelocity);
}

void PhysicsWorld::SetGlobalDamping(float damping) {
  cpSpaceSetDamping(space, damping);
}

void PhysicsWorld::SetVelocity(entt::entity entity, float velocityX,
                               float velocityY) {
  auto &collider = registry->get<ColliderComponent>(entity);
  cpBodySetVelocity(collider.body.get(), cpv(velocityX, velocityY));
}

void PhysicsWorld::Align(entt::entity entity,
                         const std::vector<entt::entity> &others,
                         float alignRadius, float maxSpeed, float maxForce) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect averageVelocity = cpvzero;
  int neighborCount = 0;

  for (auto other : others) {
    if (other == entity)
      continue;

    auto &otherCollider = registry->get<ColliderComponent>(other);
    cpVect otherPos = cpBodyGetPosition(otherCollider.body.get());

    float distance = cpvlength(cpvsub(otherPos, currentPos));
    if (distance < alignRadius) {
      averageVelocity =
          cpvadd(averageVelocity, cpBodyGetVelocity(otherCollider.body.get()));
      neighborCount++;
    }
  }

  if (neighborCount > 0) {
    averageVelocity = cpvmult(averageVelocity, 1.0f / neighborCount);
    cpVect currentVelocity = cpBodyGetVelocity(collider.body.get());
    cpVect steeringForce = cpvsub(averageVelocity, currentVelocity);

    steeringForce = cpvclamp(steeringForce, maxForce);
    cpBodyApplyForceAtWorldPoint(collider.body.get(), steeringForce,
                                 currentPos);
  }
}

void PhysicsWorld::Cohesion(entt::entity entity,
                            const std::vector<entt::entity> &others,
                            float cohesionRadius, float maxSpeed,
                            float maxForce) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect averagePosition = cpvzero;
  int neighborCount = 0;

  for (auto other : others) {
    if (other == entity)
      continue;

    auto &otherCollider = registry->get<ColliderComponent>(other);
    cpVect otherPos = cpBodyGetPosition(otherCollider.body.get());

    float distance = cpvlength(cpvsub(otherPos, currentPos));
    if (distance < cohesionRadius) {
      averagePosition = cpvadd(averagePosition, otherPos);
      neighborCount++;
    }
  }

  if (neighborCount > 0) {
    averagePosition = cpvmult(averagePosition, 1.0f / neighborCount);
    Seek(entity, averagePosition.x, averagePosition.y, maxSpeed);
  }
}

void PhysicsWorld::EnforceBoundary(entt::entity entity, float minY) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect position = cpBodyGetPosition(collider.body.get());
  if (position.y > minY) {
    cpVect force = cpv(0, -1000 * (position.y - minY));
    cpBodyApplyForceAtWorldPoint(collider.body.get(), force, position);
  }
}

void PhysicsWorld::AccelerateTowardMouse(entt::entity entity,
                                         float acceleration, float maxSpeed) {
  auto &collider = registry->get<ColliderComponent>(entity);

  Vector2 mousePos = GetMousePosition();
  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect toMouse = cpv(mousePos.x - currentPos.x, mousePos.y - currentPos.y);
  float angle = atan2(toMouse.y, toMouse.x);

  AccelerateTowardAngle(entity, angle, acceleration, maxSpeed);
}

void PhysicsWorld::AccelerateTowardObject(entt::entity entity,
                                          entt::entity target,
                                          float acceleration, float maxSpeed) {
  auto &collider = registry->get<ColliderComponent>(entity);
  auto &targetCollider = registry->get<ColliderComponent>(target);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect targetPos = cpBodyGetPosition(targetCollider.body.get());
  cpVect toTarget = cpv(targetPos.x - currentPos.x, targetPos.y - currentPos.y);
  float angle = atan2(toTarget.y, toTarget.x);

  AccelerateTowardAngle(entity, angle, acceleration, maxSpeed);
}

void PhysicsWorld::MoveTowardAngle(entt::entity entity, float angle,
                                   float speed) {
  auto &collider = registry->get<ColliderComponent>(entity);

  float velocityX = speed * cos(angle);
  float velocityY = speed * sin(angle);
  cpBodySetVelocity(collider.body.get(), cpv(velocityX, velocityY));
}

void PhysicsWorld::RotateTowardObject(entt::entity entity, entt::entity target,
                                      float lerpValue) {
  auto &collider = registry->get<ColliderComponent>(entity);
  auto &targetCollider = registry->get<ColliderComponent>(target);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect targetPos = cpBodyGetPosition(targetCollider.body.get());
  float targetAngle =
      atan2(targetPos.y - currentPos.y, targetPos.x - currentPos.x);

  float currentAngle = cpBodyGetAngle(collider.body.get());
  float newAngle = currentAngle + lerpValue * (targetAngle - currentAngle);
  cpBodySetAngle(collider.body.get(), newAngle);
}

void PhysicsWorld::RotateTowardPoint(entt::entity entity, float targetX,
                                     float targetY, float lerpValue) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  float targetAngle = atan2(targetY - currentPos.y, targetX - currentPos.x);

  float currentAngle = cpBodyGetAngle(collider.body.get());
  float newAngle = currentAngle + lerpValue * (targetAngle - currentAngle);
  cpBodySetAngle(collider.body.get(), newAngle);
}

void PhysicsWorld::RotateTowardMouse(entt::entity entity, float lerpValue) {
  auto &collider = registry->get<ColliderComponent>(entity);

  Vector2 mousePos = GetMousePosition();
  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  float targetAngle =
      atan2(mousePos.y - currentPos.y, mousePos.x - currentPos.x);

  float currentAngle = cpBodyGetAngle(collider.body.get());
  float newAngle = currentAngle + lerpValue * (targetAngle - currentAngle);
  cpBodySetAngle(collider.body.get(), newAngle);
}

void PhysicsWorld::RotateTowardVelocity(entt::entity entity, float lerpValue) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect velocity = cpBodyGetVelocity(collider.body.get());
  if (cpvlength(velocity) > 0) {
    float targetAngle = atan2(velocity.y, velocity.x);

    float currentAngle = cpBodyGetAngle(collider.body.get());
    float newAngle = currentAngle + lerpValue * (targetAngle - currentAngle);
    cpBodySetAngle(collider.body.get(), newAngle);
  }
}

void PhysicsWorld::AccelerateTowardAngle(entt::entity entity, float angle,
                                         float acceleration, float maxSpeed) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect force = cpv(acceleration * cos(angle), acceleration * sin(angle));
  cpBodyApplyForceAtWorldPoint(collider.body.get(), force,
                               cpBodyGetPosition(collider.body.get()));

  cpVect velocity = cpBodyGetVelocity(collider.body.get());
  float speed = cpvlength(velocity);
  if (speed > maxSpeed) {
    cpVect clampedVelocity = cpvmult(cpvnormalize(velocity), maxSpeed);
    cpBodySetVelocity(collider.body.get(), clampedVelocity);
  }
}

void PhysicsWorld::AccelerateTowardPoint(entt::entity entity, float targetX,
                                         float targetY, float acceleration,
                                         float maxSpeed) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  cpVect toTarget = cpv(targetX - currentPos.x, targetY - currentPos.y);
  float angle = atan2(toTarget.y, toTarget.x);

  AccelerateTowardAngle(entity, angle, acceleration, maxSpeed);
}

void PhysicsWorld::MoveTowardPoint(entt::entity entity, float targetX,
                                   float targetY, float speed, float maxTime) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect currentPos = cpBodyGetPosition(collider.body.get());
  float distance = cpvlength(cpvsub(cpv(targetX, targetY), currentPos));

  if (maxTime > 0) {
    speed = distance / maxTime;
  }

  cpVect direction =
      cpvnormalize(cpv(targetX - currentPos.x, targetY - currentPos.y));
  cpVect velocity = cpvmult(direction, speed);
  cpBodySetVelocity(collider.body.get(), velocity);
}

void PhysicsWorld::MoveTowardMouse(entt::entity entity, float speed,
                                   float maxTime) {
  Vector2 mousePos = GetMousePosition();
  MoveTowardPoint(entity, mousePos.x, mousePos.y, speed, maxTime);
}

void PhysicsWorld::LockHorizontally(entt::entity entity) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect velocity = cpBodyGetVelocity(collider.body.get());
  cpBodySetVelocity(collider.body.get(), cpv(velocity.x, 0));
}

void PhysicsWorld::LockVertically(entt::entity entity) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect velocity = cpBodyGetVelocity(collider.body.get());
  cpBodySetVelocity(collider.body.get(), cpv(0, velocity.y));
}

void PhysicsWorld::SetAngularVelocity(entt::entity entity,
                                      float angularVelocity) {
  auto &collider = registry->get<ColliderComponent>(entity);
  cpBodySetAngularVelocity(collider.body.get(), angularVelocity);
}

void PhysicsWorld::SetAngularDamping(entt::entity entity,
                                     float angularDamping) {
  auto &collider = registry->get<ColliderComponent>(entity);

  float angularVelocity = cpBodyGetAngularVelocity(collider.body.get());

  float dampedAngularVelocity = angularVelocity * (1.0f - angularDamping);

  cpBodySetAngularVelocity(collider.body.get(), dampedAngularVelocity);
}

float PhysicsWorld::GetAngle(entt::entity entity) {
  auto &collider = registry->get<ColliderComponent>(entity);
  return cpBodyGetAngle(collider.body.get());
}

void PhysicsWorld::SetAngle(entt::entity entity, float angle) {
  auto &collider = registry->get<ColliderComponent>(entity);
  cpBodySetAngle(collider.body.get(), angle);
}

void PhysicsWorld::SetRestitution(entt::entity entity, float restitution) {
  auto &c = registry->get<ColliderComponent>(entity);
  ForEachShape(c, [&](cpShape *s) { cpShapeSetElasticity(s, restitution); });
}

void PhysicsWorld::SetFriction(entt::entity entity, float friction) {
  auto &c = registry->get<ColliderComponent>(entity);
  ForEachShape(c, [&](cpShape *s) { cpShapeSetFriction(s, friction); });
}

void PhysicsWorld::ApplyAngularImpulse(entt::entity entity,
                                       float angularImpulse) {
  auto &collider = registry->get<ColliderComponent>(entity);

  float momentOfInertia = cpBodyGetMoment(collider.body.get());

  if (momentOfInertia != 0) {
    float deltaAngularVelocity = angularImpulse / momentOfInertia;

    float currentAngularVelocity =
        cpBodyGetAngularVelocity(collider.body.get());
    cpBodySetAngularVelocity(collider.body.get(),
                             currentAngularVelocity + deltaAngularVelocity);
  }
}

void PhysicsWorld::SetAwake(entt::entity entity, bool awake) {
  auto &collider = registry->get<ColliderComponent>(entity);
  if (awake) {
    cpBodyActivate(collider.body.get());
  } else {
    cpBodySleep(collider.body.get());
  }
}

cpVect PhysicsWorld::GetPosition(entt::entity entity) {
  auto &collider = registry->get<ColliderComponent>(entity);
  return cpBodyGetPosition(collider.body.get());
}

void PhysicsWorld::SetPosition(entt::entity entity, float x, float y) {
  auto &collider = registry->get<ColliderComponent>(entity);
  cpBodySetPosition(collider.body.get(), cpv(x, y));
}

void PhysicsWorld::MoveTowardsMouseHorizontally(entt::entity entity,
                                                float speed, float maxTime) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect position = cpBodyGetPosition(collider.body.get());
  cpVect mousePosition = {static_cast<cpFloat>(GetMouseX()),
                          static_cast<cpFloat>(GetMouseY())};

  if (maxTime > 0.0f) {
    float distance = fabs(mousePosition.x - position.x);
    speed = distance / maxTime;
  }

  float angle =
      atan2(mousePosition.y - position.y, mousePosition.x - position.x);
  cpVect velocity = cpBodyGetVelocity(collider.body.get());
  cpVect newVelocity = {speed * cos(angle), velocity.y};

  cpBodySetVelocity(collider.body.get(), newVelocity);
}

void PhysicsWorld::MoveTowardsMouseVertically(entt::entity entity, float speed,
                                              float maxTime) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect position = cpBodyGetPosition(collider.body.get());
  cpVect mousePosition = {static_cast<cpFloat>(GetMouseX()),
                          static_cast<cpFloat>(GetMouseY())};

  if (maxTime > 0.0f) {
    float distance = fabs(mousePosition.y - position.y);
    speed = distance / maxTime;
  }

  float angle =
      atan2(mousePosition.y - position.y, mousePosition.x - position.x);
  cpVect velocity = cpBodyGetVelocity(collider.body.get());
  cpVect newVelocity = {velocity.x, speed * sin(angle)};

  cpBodySetVelocity(collider.body.get(), newVelocity);
}

void PhysicsWorld::ApplyTorque(entt::entity entity, float torque) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect position = cpBodyGetPosition(collider.body.get());
  cpVect offset = cpv(1.0, 0.0);
  cpVect clockwiseForce = cpvmult(offset, -torque);
  cpVect counterClockwiseForce = cpvmult(offset, torque);

  cpVect clockwisePoint = cpvadd(position, offset);
  cpVect counterClockwisePoint = cpvsub(position, offset);

  cpBodyApplyForceAtWorldPoint(collider.body.get(), clockwiseForce,
                               clockwisePoint);
  cpBodyApplyForceAtWorldPoint(collider.body.get(), counterClockwiseForce,
                               counterClockwisePoint);
}

float PhysicsWorld::GetMass(entt::entity entity) {
  auto &collider = registry->get<ColliderComponent>(entity);
  return cpBodyGetMass(collider.body.get());
}

void PhysicsWorld::SetMass(entt::entity entity, float mass) {
  auto &collider = registry->get<ColliderComponent>(entity);
  cpBodySetMass(collider.body.get(), mass);
}

void PhysicsWorld::SetBullet(entt::entity entity, bool isBullet) {
  auto &collider = registry->get<ColliderComponent>(entity);

  if (isBullet) {
    cpSpaceSetIterations(space, 20);

    cpBodySetVelocityUpdateFunc(
        collider.body.get(),
        [](cpBody *body, cpVect gravity, cpFloat damping, cpFloat dt) {
          cpBodyUpdateVelocity(body, gravity, 1.0f, dt);
        });

    cpSpaceSetCollisionSlop(space, 0.1);
  } else {
    cpSpaceSetIterations(space, 10);
    cpBodySetVelocityUpdateFunc(collider.body.get(), cpBodyUpdateVelocity);
    cpSpaceSetCollisionSlop(space, 0.5);
  }
}

void PhysicsWorld::SetFixedRotation(entt::entity entity, bool fixedRotation) {
  auto &collider = registry->get<ColliderComponent>(entity);
  if (fixedRotation) {
    cpBodySetMoment(collider.body.get(), INFINITY);
  } else {
    float mass = cpBodyGetMass(collider.body.get());
    float width = 1.0f;
    float height = 1.0f;
    float moment = cpMomentForBox(mass, width, height);
    cpBodySetMoment(collider.body.get(), moment);
  }
}

std::vector<cpVect> PhysicsWorld::GetVertices(entt::entity entity) {
  auto &collider = registry->get<ColliderComponent>(entity);
  std::vector<cpVect> vertices;

  if (collider.shapeType == ColliderShapeType::Polygon ||
      collider.shapeType == ColliderShapeType::Chain) {
    int count = cpPolyShapeGetCount(collider.shape.get());
    for (int i = 0; i < count; ++i) {
      vertices.push_back(cpPolyShapeGetVert(collider.shape.get(), i));
    }
    if (collider.shapeType == ColliderShapeType::Chain && !vertices.empty()) {
      vertices.push_back(vertices.front());
    }
  }

  return vertices;
}

void PhysicsWorld::SetBodyType(entt::entity entity,
                               const std::string &bodyType) {
  auto &collider = registry->get<ColliderComponent>(entity);

  if (bodyType == "static") {
    cpBodySetType(collider.body.get(), CP_BODY_TYPE_STATIC);
  } else if (bodyType == "kinematic") {
    cpBodySetType(collider.body.get(), CP_BODY_TYPE_KINEMATIC);
  } else if (bodyType == "dynamic") {
    cpBodySetType(collider.body.get(), CP_BODY_TYPE_DYNAMIC);
    cpBodyActivate(collider.body.get());
  } else {
    throw std::invalid_argument("Invalid body type: " + bodyType);
  }
}

entt::entity PhysicsWorld::PointQuery(float x, float y) {
  cpPointQueryInfo info;
  cpShape *hit = cpSpacePointQueryNearest(space, cpv(x, y), 3.0f,
                                          CP_SHAPE_FILTER_ALL, &info);
                                          
  // SPDLOG_TRACE("PointQuery: ({:.1f},{:.1f}) -> {}", x, y, (int)e);
  if (!hit)
    return entt::null;
  return static_cast<entt::entity>(
      reinterpret_cast<uintptr_t>(cpShapeGetUserData(hit)));
}

void PhysicsWorld::SetBodyPosition(entt::entity e, float x, float y) {
  auto &c = registry->get<ColliderComponent>(e);
  cpBodySetPosition(c.body.get(), cpv(x, y));
}

void PhysicsWorld::SetBodyVelocity(entt::entity e, float vx, float vy) {
  auto &c = registry->get<ColliderComponent>(e);
  cpBodySetVelocity(c.body.get(), cpv(vx, vy));
}

void PhysicsWorld::AddUprightSpring(entt::entity e, float stiffness,
                                    float damping) {
  auto &c = registry->get<ColliderComponent>(e);
  cpConstraint *spring = cpDampedRotarySpringNew(
      cpSpaceGetStaticBody(space), c.body.get(), 0.0f, stiffness, damping);
  cpSpaceAddConstraint(space, spring);
}

void PhysicsWorld::RegisterExclusivePairCollisionHandler(
    const std::string &tagA, const std::string &tagB) {
  cpCollisionType ta = TypeForTag(tagA);
  cpCollisionType tb = TypeForTag(tagB);

  cpCollisionHandler *h = cpSpaceAddCollisionHandler(space, ta, tb);
  h->userData = this;

  h->beginFunc = [](cpArbiter *a, cpSpace *s, void *d) -> cpBool {
    static_cast<PhysicsWorld *>(d)->OnCollisionBegin(a);
    return cpTrue;
  };
  h->separateFunc = [](cpArbiter *a, cpSpace *s, void *d) {
    static_cast<PhysicsWorld *>(d)->OnCollisionEnd(a);
    free_store(a);
  };
}

void PhysicsWorld::AddScreenBounds(float xMin, float yMin, float xMax,
                                   float yMax, float thickness,
                                   const std::string &collisionTag) {
  cpBody *staticBody = cpSpaceGetStaticBody(space);
  cpShapeFilter filter = CP_SHAPE_FILTER_ALL;
  cpCollisionType type = TypeForTag(collisionTag);

  auto makeWall = [&](float ax, float ay, float bx, float by) {
    cpShape *seg =
        cpSegmentShapeNew(staticBody, cpv(ax, ay), cpv(bx, by), thickness);
    cpShapeSetFriction(seg, 1.0f);
    cpShapeSetElasticity(seg, 0.0f);
    cpShapeSetFilter(seg, filter);
    cpShapeSetCollisionType(seg, type);
    cpSpaceAddShape(space, seg);
  };

  makeWall(xMin, yMin, xMax, yMin);
  makeWall(xMin, yMin, xMin, yMax);
  makeWall(xMin, yMax, xMax, yMax);
  makeWall(xMax, yMin, xMax, yMax);
  
  SPDLOG_INFO("AddScreenBounds: rect=({}, {})–({}, {}), thick={}, tag='{}'", xMin, yMin, xMax, yMax, thickness, collisionTag);

}

void PhysicsWorld::StartMouseDrag(float x, float y) {
  if (mouseJoint)
    return;
  EndMouseDrag();

  if (!mouseBody) {
    mouseBody = cpBodyNewStatic();
    SpaceAddBodySafe(space, mouseBody);
  }
  cpBodySetPosition(mouseBody, cpv(x, y));

  draggedEntity = PointQuery(x, y);
  if (draggedEntity == entt::null)
    return;

  auto &c = registry->get<ColliderComponent>(draggedEntity);

  cpVect worldPt = cpv(x, y);
  cpVect anchorA = cpBodyWorldToLocal(mouseBody, worldPt);
  cpVect anchorB = cpBodyWorldToLocal(c.body.get(), worldPt);

  mouseJoint = cpPivotJointNew2(mouseBody, c.body.get(), anchorA, anchorB);
  SpaceAddConstraintSafe(space, mouseJoint);
}

void PhysicsWorld::UpdateMouseDrag(float x, float y) {
  if (mouseBody) {
    cpBodySetPosition(mouseBody, cpv(x, y));
  }
}

void PhysicsWorld::EndMouseDrag() {
  if (mouseJoint) {
    SpaceRemoveConstraintSafe(space, mouseJoint, /*freeAfter=*/true);
    mouseJoint = nullptr;
  }
  draggedEntity = entt::null;
}

void PhysicsWorld::CreateTilemapColliders(
    const std::vector<std::vector<bool>> &collidable, float tileSize,
    float segmentRadius) {
  int w = (int)collidable.size();
  int h = w ? (int)collidable[0].size() : 0;
  if (w == 0 || h == 0)
    return;

  cpBB sampleRect = cpBBNew(-0.5f, -0.5f, w + 0.5f, h + 0.5f);

  cpBB clampBB = cpBBNew(0.5f, 0.5f, w - 0.5f, h - 0.5f);

  struct Sampler {
    const std::vector<std::vector<bool>> *grid;
    int w, h;
    cpBB clamp;
  } sampler{&collidable, w, h, clampBB};

  auto sampleFunc = +[](cpVect pt, void *data) -> cpFloat {
    auto *s = static_cast<Sampler *>(data);
    pt = cpBBClampVect(s->clamp, pt);
    int tx = (int)pt.x;
    int ty = (int)pt.y;
    ty = s->h - 1 - ty;
    return (*s->grid)[tx][ty] ? 1.0f : 0.0f;
  };

  cpPolylineSet *polys = cpPolylineSetNew();
  cpMarchHard(sampleRect, (unsigned)w + 2, (unsigned)h + 2, 0.5f,
              (cpMarchSegmentFunc)cpPolylineSetCollectSegment, polys,
              sampleFunc, &sampler);

  for (int i = 0; i < polys->count; ++i) {
    cpPolyline *line = polys->lines[i];
    cpPolyline *simp = cpPolylineSimplifyCurves(line, 0.0f);

    for (int j = 0; j < simp->count - 1; ++j) {
      cpVect a = cpvmult(simp->verts[j], tileSize);
      cpVect b = cpvmult(simp->verts[j + 1], tileSize);
      cpShape *seg =
          cpSegmentShapeNew(cpSpaceGetStaticBody(space), a, b, segmentRadius);
      cpShapeSetFriction(seg, 1.0f);
      // Give them a tag/filter/collision type if you want them queryable by tag:
      ApplyCollisionFilter(seg, "WORLD");
      cpShapeSetCollisionType(seg, _tagToCollisionType["WORLD"]);
      cpSpaceAddShape(space, seg);
    }

    if (simp != line)
      cpPolylineFree(simp);
  }

  cpPolylineSetFree(polys, cpTrue);
}

void PhysicsWorld::CreateTopDownController(entt::entity entity, float maxBias,
                                           float maxForce) {
  if (!controlBody) {
    controlBody = cpBodyNewStatic();
    cpSpaceAddBody(space, controlBody);
  }

  auto &col = registry->get<ColliderComponent>(entity);
  cpConstraint *joint =
      cpPivotJointNew2(controlBody, col.body.get(), cpvzero, cpvzero);
  cpConstraintSetMaxBias(joint, maxBias);
  cpConstraintSetMaxForce(joint, maxForce);
  cpSpaceAddConstraint(space, joint);
  // add collision tag
  ApplyCollisionFilter(col.shape.get(), "WORLD");
}

void PhysicsWorld::EnableCollisionGrouping(
    cpCollisionType minType, cpCollisionType maxType, int threshold,
    std::function<void(cpBody *)> onGroupRemoved) {
  _groupThreshold = threshold;
  _onGroupRemoved = std::move(onGroupRemoved);

  for (cpCollisionType t = minType; t <= maxType; ++t) {
    auto handler = cpSpaceAddCollisionHandler(space, t, t);
    handler->postSolveFunc = &PhysicsWorld::GroupPostSolveCallback;
    handler->userData = this;
  }
}

void PhysicsWorld::GroupPostSolveCallback(cpArbiter *arb, cpSpace *,
                                          void *userData) {
  static_cast<PhysicsWorld *>(userData)->OnGroupPostSolve(arb);
}

void PhysicsWorld::OnGroupPostSolve(cpArbiter *arb) {
  cpShape *shapeA, *shapeB;
  cpArbiterGetShapes(arb, &shapeA, &shapeB);
  cpBody *bodyA = cpShapeGetBody(shapeA);
  cpBody *bodyB = cpShapeGetBody(shapeB);

  MakeNode(bodyA);
  MakeNode(bodyB);
  UnionBodies(bodyA, bodyB);
}

UFNode &PhysicsWorld::MakeNode(cpBody *body) {
  auto it = _groupNodes.find(body);
  if (it == _groupNodes.end()) {
    UFNode node;
    node.parent = &node;
    node.count = 1;
    auto pair = _groupNodes.emplace(body, node);
    return pair.first->second;
  }
  return it->second;
}

UFNode &PhysicsWorld::FindNode(cpBody *body) {
  UFNode &node = MakeNode(body);

  if (node.parent != &node) {
    cpBody *parentBody = nullptr;
    for (auto &kv : _groupNodes) {
      if (&kv.second == node.parent) {
        parentBody = kv.first;
        break;
      }
    }
    node.parent = &FindNode(parentBody);
  }
  return *node.parent;
}

void PhysicsWorld::UnionBodies(cpBody *a, cpBody *b) {
  UFNode &na = FindNode(a);
  UFNode &nb = FindNode(b);
  if (&na != &nb) {
    nb.parent = &na;
    na.count += nb.count;
  }
}

void PhysicsWorld::ProcessGroups() {
  for (auto &[body, node] : _groupNodes) {
    if (node.parent == &node && node.count >= _groupThreshold) {
      _onGroupRemoved(body);
    }
  }
}

std::vector<entt::entity> PhysicsWorld::TouchingEntities(entt::entity e) {
  auto &c = registry->get<ColliderComponent>(e);
  std::vector<entt::entity> out;
  cpBodyEachArbiter(
      c.body.get(),
      +[](cpBody *body, cpArbiter *arb, void *ctx) {
        auto *v = static_cast<std::vector<entt::entity> *>(ctx);
        CP_ARBITER_GET_SHAPES(arb, sa, sb);
        cpShape *other = (cpShapeGetBody(sa) == body) ? sb : sa;
        if (void *u = cpShapeGetUserData(other)) {
          v->push_back(
              static_cast<entt::entity>(reinterpret_cast<uintptr_t>(u)));
        }
      },
      &out);
  return out;
}

// After a step in the same frame (impulses are valid only then)
cpVect PhysicsWorld::SumImpulsesForBody(cpBody *body) {
  cpVect sum = cpvzero;
  cpBodyEachArbiter(
      body,
      +[](cpBody *, cpArbiter *arb, void *s) {
        auto *acc = static_cast<cpVect *>(s);
        *acc = cpvadd(*acc, cpArbiterTotalImpulse(arb));
      },
      &sum);
  return sum;
}

float PhysicsWorld::TotalForceOn(entt::entity e, float dt) {
  auto &c = registry->get<ColliderComponent>(e);
  cpVect J = SumImpulsesForBody(c.body.get());
  return (dt > 0.f) ? cpvlength(J) / dt : 0.f;
}

float PhysicsWorld::WeightOn(entt::entity e, float dt) {
  auto &c = registry->get<ColliderComponent>(e);
  cpVect J = SumImpulsesForBody(c.body.get());
  cpVect g = cpSpaceGetGravity(space);
  float gl2 = cpvlengthsq(g);
  return (dt > 0.f && gl2 > 0.f) ? cpvdot(g, J) / (gl2 * dt) : 0.f;
}

CrushMetrics PhysicsWorld::CrushOn(entt::entity e, float dt) {
  auto &c = registry->get<ColliderComponent>(e);

  // Keep the accumulator as a real variable on the stack
  std::pair<std::pair<float, cpVect>, int> accum{{0.f, cpvzero}, 0};

  cpBodyEachArbiter(
      c.body.get(),
      +[](cpBody *body, cpArbiter *arb, void *ctx) {
        auto *P = static_cast<std::pair<std::pair<float, cpVect>, int> *>(ctx);
        cpVect J = cpArbiterTotalImpulse(arb);
        P->first.first += cpvlength(J);               // magnitudeSum
        P->first.second = cpvadd(P->first.second, J); // vectorSum
        P->second++;                                  // touchingCount
      },
      &accum);

  CrushMetrics out;
  out.touchingCount = accum.second;
  out.crush = (accum.first.first - cpvlength(accum.first.second)) * dt;
  return out;
}

bool PhysicsWorld::ConvexAddPoint(entt::entity e, cpVect worldPoint,
                                  float tolerance /*=2.0f*/) {
  auto &col = registry->get<ColliderComponent>(e);
  if (!col.body || !col.shape)
    return false;

  cpShape *s = col.shape.get();
  if (cpPolyShapeGetCount(s) <= 0)
    return false; // not a poly/box

  // Optional: only add if cursor is outside by > tolerance (like the demo).
  // If you want the same behavior, uncomment:
  // if (cpShapePointQuery(s, worldPoint, nullptr) <= tolerance) return false;

  cpBody *body = col.body.get();
  const int count = cpPolyShapeGetCount(s);

  // Collect existing verts (LOCAL space), append new point (LOCAL).
  std::vector<cpVect> verts;
  verts.reserve(count + 1);
  for (int i = 0; i < count; ++i)
    verts.push_back(cpPolyShapeGetVert(s, i));

  verts.push_back(cpBodyWorldToLocal(body, worldPoint));

  // Convexify in place. (cpConvexHull can write the result back into the same
  // array.)
  int hullCount = cpConvexHull((int)verts.size(), verts.data(), verts.data(),
                               nullptr, tolerance);
  verts.resize(hullCount);

  // Compute centroid/area in LOCAL space of the new polygon.
  cpVect centroid = cpCentroidForPoly(hullCount, verts.data());
  cpFloat area = cpAreaForPoly(hullCount, verts.data(), 0.0f);
  if (area <= 0)
    return false; // degenerate

  // Recompute mass/moment (tune your density here if you want).
  constexpr cpFloat DENSITY = (1.0 / 10000.0);
  cpFloat mass = area * DENSITY;
  cpFloat moment =
      cpMomentForPoly(mass, hullCount, verts.data(), cpvneg(centroid), 0.0f);

  // Shift the body so its world position = old world centroid of the new verts.
  // (Same trick as the demo.)
  cpBodySetMass(body, mass);
  cpBodySetMoment(body, moment);
  cpBodySetPosition(body, cpBodyLocalToWorld(body, centroid));
  cpBodyActivate(body);

  // Finally, replace the polygon verts (LOCAL) with a transform that centers
  // it. This keeps the world shape where the mouse added the point.
  cpPolyShapeSetVerts(s, hullCount, verts.data(),
                      cpTransformTranslate(cpvneg(centroid)));

  return true;
}

// Resolve (entity,shapeIndex) -> cpBody*
cpBody *PhysicsWorld::BodyOf(entt::entity e) {
  return registry->get<ColliderComponent>(e).body.get();
}

// Pin joint
cpConstraint *PhysicsWorld::AddPinJoint(entt::entity ea, cpVect aLocal,
                                        entt::entity eb, cpVect bLocal) {
  auto *ja = cpSpaceAddConstraint(
      space, cpPinJointNew(BodyOf(ea), BodyOf(eb), aLocal, bLocal));
  return ja;
}

// Slide joint
cpConstraint *PhysicsWorld::AddSlideJoint(entt::entity ea, cpVect aLocal,
                                          entt::entity eb, cpVect bLocal,
                                          cpFloat minD, cpFloat maxD) {
  return cpSpaceAddConstraint(
      space,
      cpSlideJointNew(BodyOf(ea), BodyOf(eb), aLocal, bLocal, minD, maxD));
}

// Pivot joint (world anchor)
cpConstraint *PhysicsWorld::AddPivotJointWorld(entt::entity ea, entt::entity eb,
                                               cpVect worldAnchor) {
  return cpSpaceAddConstraint(
      space, cpPivotJointNew(BodyOf(ea), BodyOf(eb), worldAnchor));
}

// Groove joint (A provides groove, in A's local space)
cpConstraint *PhysicsWorld::AddGrooveJoint(entt::entity a, cpVect a1Local,
                                           cpVect a2Local, entt::entity b,
                                           cpVect bLocal) {
  return cpSpaceAddConstraint(
      space, cpGrooveJointNew(BodyOf(a), BodyOf(b), a1Local, a2Local, bLocal));
}

// Springs
cpConstraint *PhysicsWorld::AddDampedSpring(entt::entity ea, cpVect aLocal,
                                            entt::entity eb, cpVect bLocal,
                                            cpFloat rest, cpFloat k,
                                            cpFloat damp) {
  return cpSpaceAddConstraint(
      space,
      cpDampedSpringNew(BodyOf(ea), BodyOf(eb), aLocal, bLocal, rest, k, damp));
}
cpConstraint *PhysicsWorld::AddDampedRotarySpring(entt::entity ea,
                                                  entt::entity eb,
                                                  cpFloat restAngle, cpFloat k,
                                                  cpFloat damp) {
  return cpSpaceAddConstraint(
      space,
      cpDampedRotarySpringNew(BodyOf(ea), BodyOf(eb), restAngle, k, damp));
}

// Angular joints
cpConstraint *PhysicsWorld::AddRotaryLimit(entt::entity ea, entt::entity eb,
                                           cpFloat minAngle, cpFloat maxAngle) {
  return cpSpaceAddConstraint(
      space, cpRotaryLimitJointNew(BodyOf(ea), BodyOf(eb), minAngle, maxAngle));
}
cpConstraint *PhysicsWorld::AddRatchet(entt::entity ea, entt::entity eb,
                                       cpFloat phase, cpFloat ratchet) {
  return cpSpaceAddConstraint(
      space, cpRatchetJointNew(BodyOf(ea), BodyOf(eb), phase, ratchet));
}
cpConstraint *PhysicsWorld::AddGear(entt::entity ea, entt::entity eb,
                                    cpFloat phase, cpFloat ratio) {
  return cpSpaceAddConstraint(
      space, cpGearJointNew(BodyOf(ea), BodyOf(eb), phase, ratio));
}
cpConstraint *PhysicsWorld::AddSimpleMotor(entt::entity ea, entt::entity eb,
                                           cpFloat rateRadPerSec) {
  return cpSpaceAddConstraint(
      space, cpSimpleMotorNew(BodyOf(ea), BodyOf(eb), rateRadPerSec));
}

// Convenience tuning
void PhysicsWorld::SetConstraintLimits(cpConstraint *c, cpFloat maxForce,
                                       cpFloat maxBias) {
  if (maxForce >= 0)
    cpConstraintSetMaxForce(c, maxForce);
  if (maxBias >= 0)
    cpConstraintSetMaxBias(c, maxBias);
}

entt::entity PhysicsWorld::SpawnPixelBall(float x, float y, float r) {
  auto e = registry->create();
  // tag it however you like; "pixel" here assumes you’ve added it via
  // SetCollisionTags()
  AddCollider(e, /*tag*/ "pixel", /*shape*/ "circle",
              /*a=radius*/ r, /*b*/ 0, /*c*/ 0, /*d*/ 0,
              /*sensor*/ false, /*points*/ {});
  SetPosition(e, x, y);
  SetFriction(e, 0.0f);
  SetRestitution(e, 0.0f);
  // optional: very light mass for fast sim
  SetMass(e, 1.0f);
  return e;
}

void PhysicsWorld::BuildLogoFromBitmap(const unsigned char *bits, int w, int h,
                                       int rowLenBytes,
                                       float pixelWorldScale /*=2.0f*/,
                                       float jitter /*=0.05f*/) {
  for (int y = 0; y < h; ++y) {
    for (int x = 0; x < w; ++x) {
      if (!get_pixel(x, y, bits, rowLenBytes))
        continue;

      float jx = jitter * ((rand() % 200 - 100) / 100.0f);
      float jy = jitter * ((rand() % 200 - 100) / 100.0f);

      float wx = pixelWorldScale * (x - w * 0.5f + jx);
      float wy = pixelWorldScale * (h * 0.5f - y + jy);
      SpawnPixelBall(wx, wy);
    }
  }
}
entt::entity PhysicsWorld::AddOneWayPlatform(
    float x1, float y1, float x2, float y2, float thickness,
    const std::string &tag /*= "one_way"*/, cpVect n /*= cpv(0, 1)*/) {
  // Ensure collision tag exists (category + collision type)
  if (!collisionTags.contains(tag)) {
    AddCollisionTag(tag);
  }

  // Register one-way behavior for this tag (stores in _oneWayByType and
  // installs wildcard handler)
  RegisterOneWayPlatform(tag, n);

  // Build the static segment
  cpBody *staticBody = cpSpaceGetStaticBody(space);
  cpShape *seg =
      cpSegmentShapeNew(staticBody, cpv(x1, y1), cpv(x2, y2), thickness);
  cpShapeSetElasticity(seg, 1.0f);
  cpShapeSetFriction(seg, 1.0f);

  // Apply your filter + collision type
  ApplyCollisionFilter(seg, tag);
  cpCollisionType type = _tagToCollisionType[tag];
  cpShapeSetCollisionType(seg, type);

  // Create an entity to track this platform (so your collision code sees a
  // userData)
  entt::entity e = registry->create();

  // IMPORTANT: keep userData = entity (matches the rest of your engine)
  cpShapeSetUserData(seg, reinterpret_cast<void *>(static_cast<uintptr_t>(e)));

  // Add to space
  cpSpaceAddShape(space, seg);
  
  SPDLOG_INFO("OneWay platform: e={} line=({:.1f},{:.1f})–({:.1f},{:.1f}) n=({:.2f},{:.2f}) tag='{}'",
            EID(e), x1,y1,x2,y2, n.x,n.y, tag);


  return e;
}

void PhysicsWorld::OnVelocityUpdate(cpBody *body, cpVect gravity,
                                    cpFloat damping, cpFloat dt) {
  auto it = _gravityByBody.find(body);
  if (it == _gravityByBody.end() ||
      it->second.mode == GravityField::Mode::None) {
    // default integration
    cpBodyUpdateVelocity(body, gravity, damping, dt);
    return;
  }

  const auto &f = it->second;
  cpVect p = cpBodyGetPosition(body);
  cpVect c = (f.mode == GravityField::Mode::InverseSquareToBody && f.centerBody)
                 ? cpBodyGetPosition(f.centerBody)
                 : f.point;
  cpVect r = cpvsub(p, c);
  cpFloat r2 = cpvlengthsq(r);
  // avoid singularity; fall back to no extra gravity if too close
  if (r2 < 1e-6f) {
    cpBodyUpdateVelocity(body, gravity, damping, dt);
    return;
  }
  cpFloat inv_r3 = 1.0f / (r2 * cpfsqrt(r2));
  cpVect gvec = cpvmult(r, -f.GM * inv_r3); // -GM * r̂ / r^2

  cpBodyUpdateVelocity(body, gvec, damping, dt);
}

void PhysicsWorld::C_VelocityUpdate(cpBody *body, cpVect gravity,
                                    cpFloat damping, cpFloat dt) {
  cpSpace *sp = cpBodyGetSpace(body);
  auto *world = static_cast<PhysicsWorld *>(cpSpaceGetUserData(sp));
  if (!world) {
    cpBodyUpdateVelocity(body, gravity, damping, dt);
    return;
  }
  world->OnVelocityUpdate(body, gravity, damping, dt);
}

// Toward a fixed point
void PhysicsWorld::EnableInverseSquareGravityToPoint(entt::entity e,
                                                     cpVect point, cpFloat GM) {
  auto &c = registry->get<ColliderComponent>(e);
  _gravityByBody[c.body.get()] = {GravityField::Mode::InverseSquareToPoint, GM,
                                  point, nullptr};
  cpBodySetVelocityUpdateFunc(c.body.get(), &PhysicsWorld::C_VelocityUpdate);
}

void PhysicsWorld::EnableInverseSquareGravityToBody(entt::entity e,
                                                    entt::entity center,
                                                    cpFloat GM) {
  auto &c = registry->get<ColliderComponent>(e);
  auto &cc = registry->get<ColliderComponent>(center);
  _gravityByBody[c.body.get()] = {GravityField::Mode::InverseSquareToBody, GM,
                                  cpvzero, cc.body.get()};
  cpBodySetVelocityUpdateFunc(c.body.get(), &PhysicsWorld::C_VelocityUpdate);
}

void PhysicsWorld::DisableCustomGravity(entt::entity e) {
  auto &c = registry->get<ColliderComponent>(e);
  _gravityByBody.erase(c.body.get());
  cpBodySetVelocityUpdateFunc(c.body.get(),
                              cpBodyUpdateVelocity); // restore default
}

entt::entity PhysicsWorld::CreatePlanet(cpFloat radius,
                                        cpFloat spinRadiansPerSec,
                                        const std::string &tag /*= "planet"*/,
                                        cpVect pos /*= {0,0}*/) {
  entt::entity e = registry->create();

  // make a kinematic body
  auto body = MakeSharedBody(0.0f, INFINITY);
  cpBodySetType(body.get(), CP_BODY_TYPE_KINEMATIC);
  cpBodySetPosition(body.get(), pos);
  cpBodySetAngularVelocity(body.get(), spinRadiansPerSec);
  SetEntityToBody(body.get(), e);
  cpSpaceAddBody(space, body.get());

  // a circle shape for visuals/collisions
  cpShape *ring = cpCircleShapeNew(body.get(), radius, cpvzero);
  ApplyCollisionFilter(ring, tag);
  cpShapeSetElasticity(ring, 1.0f);
  cpShapeSetFriction(ring, 1.0f);
  SetEntityToShape(ring, e);
  cpSpaceAddShape(space, ring);

  registry->emplace<ColliderComponent>(
      e, ColliderComponent{body, std::shared_ptr<cpShape>(ring, cpShapeFree),
                           tag, false, ColliderShapeType::Circle});
  return e;
}

entt::entity PhysicsWorld::SpawnOrbitingBox(
    cpVect startPos, cpFloat halfSize, cpFloat mass, cpFloat GM,
    cpVect gravityCenter /*usually {0,0} or planet pos*/) {
  entt::entity e = registry->create();

  // body + box shape
  auto body =
      MakeSharedBody(mass, cpMomentForBox(mass, 2 * halfSize, 2 * halfSize));
  cpBodySetPosition(body.get(), startPos);

  auto shape = std::shared_ptr<cpShape>(
      cpBoxShapeNew(body.get(), 2 * halfSize, 2 * halfSize, 0.0), cpShapeFree);
  ApplyCollisionFilter(shape.get(), "dynamic"); // or your tag
  cpShapeSetElasticity(shape.get(), 0.0f);
  cpShapeSetFriction(shape.get(), 0.7f);

  SetEntityToBody(body.get(), e);
  SetEntityToShape(shape.get(), e);
  cpSpaceAddBody(space, body.get());
  cpSpaceAddShape(space, shape.get());

  registry->emplace<ColliderComponent>(
      e, ColliderComponent{body, shape, "dynamic", false,
                           ColliderShapeType::Rectangle});

  // Initial circular orbit velocity
  cpVect rvec = cpvsub(startPos, gravityCenter);
  cpFloat r = cpvlength(rvec);
  if (r > 1e-4f) {
    cpFloat v = cpfsqrt(GM / r) / r; // matches the demo
    cpBodySetVelocity(body.get(), cpvmult(cpvperp(rvec), v));
    cpBodySetAngularVelocity(body.get(), v);
    cpBodySetAngle(body.get(), cpfatan2(rvec.y, rvec.x));
  }

  // Hook in inverse-square gravity to that point
  EnableInverseSquareGravityToPoint(e, gravityCenter, GM);

  return e;
}

// Create a box "player" with infinite moment (no rotation) and a fat box shape
// for nice footing.
entt::entity PhysicsWorld::CreatePlatformerPlayer(cpVect pos, float w, float h,
                                                  const std::string &tag) {
  entt::entity e = registry->create();

  auto body = MakeSharedBody(/*mass*/ 1.0f, INFINITY);
  cpBodySetType(body.get(), CP_BODY_TYPE_DYNAMIC);
  cpBodySetPosition(body.get(), pos);
  cpBodySetVelocityUpdateFunc(body.get(), &PhysicsWorld::C_PlayerVelUpdate);
  SetEntityToBody(body.get(), e);
  cpSpaceAddBody(space, body.get());

  // Slightly rounded box for “feet”
  cpBB bb = cpBBNew(-w * 0.5f, -h * 0.5f, w * 0.5f, h * 0.5f);
  auto shape = std::shared_ptr<cpShape>(
      cpBoxShapeNew2(body.get(), bb, /*radius*/ 10.0), cpShapeFree);
  ApplyCollisionFilter(shape.get(), tag);
  cpShapeSetElasticity(shape.get(), 0.0f);
  cpShapeSetFriction(shape.get(),
                     0.0f); // friction is injected via surface velocity trick
  SetEntityToShape(shape.get(), e);
  cpSpaceAddShape(space, shape.get());

  registry->emplace<ColliderComponent>(
      e, ColliderComponent{body, shape, tag, /*isSensor*/ false,
                           ColliderShapeType::Rectangle});

  PlatformerCtrl ctrl;
  ctrl.body = body.get();
  ctrl.feet = shape.get();
  ctrl.gravityY = 2000.f; // keep in sync with space gravity if you change it
  _platformers.emplace(e, ctrl);
  _platformerByBody.emplace(body.get(), e);

  return e;
}

// Feed input each frame: moveX in [-1,1], jumpHeld = is jump currently held.
void PhysicsWorld::SetPlatformerInput(entt::entity e, float moveX,
                                      bool jumpHeld) {
  auto it = _platformers.find(e);
  if (it == _platformers.end())
    return;
  it->second.moveX = std::clamp(moveX, -1.0f, 1.0f);
  it->second.jumpHeld = jumpHeld;
}

void PhysicsWorld::C_PlayerVelUpdate(cpBody *body, cpVect gravity,
                                     cpFloat damping, cpFloat dt) {
  cpSpace *sp = cpBodyGetSpace(body);
  auto *world = static_cast<PhysicsWorld *>(cpSpaceGetUserData(sp));
  if (!world) {
    cpBodyUpdateVelocity(body, gravity, damping, dt);
    return;
  }
  world->PlayerVelUpdate(body, gravity, damping, dt);
}

void PhysicsWorld::SelectGroundNormal(cpBody *, cpArbiter *arb, cpVect *maxUp) {
  // Up = negative collision normal in body’s frame (as in the demo).
  cpVect n = cpvneg(cpArbiterGetNormal(arb));
  if (n.y > maxUp->y)
    *maxUp = n;
}

static inline float lerpconst(float a, float b, float d) {
  return (a < b) ? std::min(b, a + d) : std::max(b, a - d);
}

void PhysicsWorld::PlayerVelUpdate(cpBody *body, cpVect gravity,
                                   cpFloat damping, cpFloat dt) {
  auto eit = _platformerByBody.find(body);
  if (eit == _platformerByBody.end()) {
    cpBodyUpdateVelocity(body, gravity, damping, dt);
    return;
  }
  PlatformerCtrl &pc = _platformers[eit->second];

  // 1) Ground check from previous step’s contacts
  cpVect groundUp = cpvzero;
  cpBodyEachArbiter(
      body, (cpBodyArbiterIteratorFunc)&PhysicsWorld::SelectGroundNormal,
      &groundUp);
  pc.grounded = (groundUp.y > 0.f);
  if (groundUp.y < 0.f)
    pc.remainingBoost = 0.f; // sliding under ceilings cancels boost

  // 2) Jump impulse: on rising edge of jump while grounded
  if (pc.jumpHeld && !pc.lastJumpHeld && pc.grounded) {
    float jump_v = std::sqrt(2.0f * pc.jumpHeight * pc.gravityY);
    cpVect v = cpBodyGetVelocity(body);
    v = cpv(v.x, v.y + jump_v);
    cpBodySetVelocity(body, v);
    pc.remainingBoost = pc.jumpBoostH / jump_v;
  }

  // 3) Gravity override for boost
  const bool boosting = (pc.jumpHeld && pc.remainingBoost > 0.f);
  cpVect g = boosting ? cpvzero : gravity; // zero gravity while boosting
  cpBodyUpdateVelocity(body, g, damping, dt);

  // 4) Ground control via surface velocity + friction “as accel”
  const float targetVX = pc.maxVel * pc.moveX;

  // feet move opposite to player desired motion (like a treadmill)
  cpVect surfaceV = cpv(-targetVX, 0.0f);
  cpShapeSetSurfaceVelocity(pc.feet, surfaceV);

  // While grounded: µ ~ accel / g (unit-consistent approximation from demo)
  cpShapeSetFriction(pc.feet,
                     pc.grounded ? (pc.groundAccel / pc.gravityY) : 0.0f);

  // 5) Air control: clamp vx toward target with a fixed accel
  if (!pc.grounded) {
    cpVect v = cpBodyGetVelocity(body);
    v = cpv(lerpconst(v.x, targetVX, pc.airAccel * dt), v.y);
    cpBodySetVelocity(body, v);
  }

  // 6) Clamp terminal fall speed
  cpVect v = cpBodyGetVelocity(body);
  if (v.y < -pc.fallVel) {
    v.y = -pc.fallVel;
    cpBodySetVelocity(body, v);
  }

  // 7) boost timer
  pc.remainingBoost = std::max(0.f, pc.remainingBoost - (float)dt);
  pc.lastJumpHeld = pc.jumpHeld;
}

SegmentQueryHit PhysicsWorld::SegmentQueryFirst(cpVect start, cpVect end,
                                                float radius,
                                                cpShapeFilter filter) const {
  cpSegmentQueryInfo info{};
  SegmentQueryHit out;

  if (cpSpaceSegmentQueryFirst(space, start, end, radius, filter, &info)) {
    out.hit = true;
    out.shape = info.shape;
    out.point = info.point;
    out.normal = info.normal;
    out.alpha = info.alpha;
  } else {
    out.alpha = 1.0f;
  }
  return out;
}

NearestPointHit PhysicsWorld::PointQueryNearest(cpVect p, float maxDistance,
                                                cpShapeFilter filter) const {
  cpPointQueryInfo info{};
  NearestPointHit out;

  cpSpacePointQueryNearest(space, p, maxDistance, filter, &info);
  if (info.shape) {
    out.hit = true;
    out.shape = info.shape;
    out.point = info.point;
    out.distance = info.distance; // < 0 ⇒ inside the shape
  }
  SPDLOG_TRACE("PointNearest: p=({:.1f},{:.1f}) hit={} dist={:.2f}",
             p.x, p.y, out.hit, out.distance);

  return out;
}

// Shatter a polygon cpShape* into fragments. DOES NOT free the original;
// use your own removal path so ECS/smart pointers stay consistent.
void PhysicsWorld::ShatterShape(cpShape *shape, float cellSize, cpVect focus) {
  if (!shape)
    return;

  // Only sensible for polys.
  if (shape->type != CP_POLY_SHAPE)
    return;

  cpBody *srcBody = cpShapeGetBody(shape);

  // Collect world-space original polygon (cap to kMaxVoronoiVerts)
  const int origCount = std::min(cpPolyShapeGetCount(shape), kMaxVoronoiVerts);
  SPDLOG_DEBUG("Shatter: srcShape={} verts={} cellSize={:.1f}", SID(shape), origCount, cellSize);

  std::vector<cpVect> ping(origCount), pong(origCount);
  for (int i = 0; i < origCount; ++i) {
    ping[i] = cpBodyLocalToWorld(srcBody, cpPolyShapeGetVert(shape, i));
  }

  // Build Worley grid over the shape's AABB
  const cpBB bb = cpShapeGetBB(shape);
  int w = static_cast<int>((bb.r - bb.l) / cellSize) + 1;
  int h = static_cast<int>((bb.t - bb.b) / cellSize) + 1;
  WorleyCtx ctx{static_cast<uint32_t>(rand()), cellSize, w, h, bb};

  // Copy material/filter/collision info for new fragments
  const cpShapeFilter filter = cpShapeGetFilter(shape);
  const cpCollisionType ctype = cpShapeGetCollisionType(shape);
  const cpFloat fric = cpShapeGetFriction(shape);
  const cpFloat elast = cpShapeGetElasticity(shape);
  const cpBool sensor = cpShapeGetSensor(shape);

  // For each Worley site inside the polygon, clip and spawn a fragment.
  for (int i = 0; i < ctx.w; ++i) {
    for (int j = 0; j < ctx.h; ++j) {
      cpVect site = WorleyPoint(i, j, ctx);
      if (cpShapePointQuery(shape, site, nullptr) >= 0.0f)
        continue;

      // Start from original polygon each time (ping holds current polygon)
      int count = origCount;
      // Make working copies because we’ll be overwriting ping/pong
      std::vector<cpVect> workPing = ping;
      std::vector<cpVect> workPong(origCount + 8); // some slack for splits

      for (int ii = 0; ii < ctx.w; ++ii) {
        for (int jj = 0; jj < ctx.h; ++jj) {
          if (ii == i && jj == j)
            continue;

          const int newCount =
              ClipCell(shape, site, ii, jj, ctx, workPing.data(), count,
                       workPong.data());
          workPing.assign(workPong.begin(), workPong.begin() + newCount);
          count = newCount;
          if (count < 3)
            break;
        }
        if (count < 3)
          break;
      }
      if (count < 3)
        continue;

      // Compute mass/centroid/moment
      const cpVect centroid = cpCentroidForPoly(count, workPing.data());
      const cpFloat area = cpAreaForPoly(count, workPing.data(), 0.0f);
      const cpFloat mass = area * kDensity;
      const cpFloat moment =
          cpMomentForPoly(mass, count, workPing.data(), cpvneg(centroid), 0.0f);

      // Spawn body + shape
      cpBody *b = cpSpaceAddBody(space, cpBodyNew(mass, moment));
      cpBodySetPosition(b, centroid);
      // inherit linear/angular velocity at the fragment centroid
      cpBodySetVelocity(b, cpBodyGetVelocityAtWorldPoint(srcBody, centroid));
      cpBodySetAngularVelocity(b, cpBodyGetAngularVelocity(srcBody));
      
      SPDLOG_TRACE("Shatter fragment: count={} centroid=({:.1f},{:.1f}) mass={:.3f} body={}",
             count, centroid.x, centroid.y, mass, BID(b));


      // Rebase verts to body-local
      std::vector<cpVect> local(count);
      for (int k = 0; k < count; ++k)
        local[k] = cpvsub(workPing[k], centroid);

      cpShape *s =
          cpSpaceAddShape(space, cpPolyShapeNew(b, count, local.data(),
                                                cpTransformIdentity, 0.0f));
                                          

      cpShapeSetFilter(s, filter);
      cpShapeSetCollisionType(s, ctype);
      cpShapeSetFriction(s, fric);
      cpShapeSetElasticity(s, elast);
      cpShapeSetSensor(s, sensor);

      // optional: tag/collision masks via your helpers
      // ApplyCollisionFilter(s, categoryToTag[(int)filter.categories]);
    }
  }

  // Now disable/remove the source collider SAFELY.
  // If this shape belongs to an entity, use your ECS helpers:
  if (void *ud = cpShapeGetUserData(shape)) {
    entt::entity e = static_cast<entt::entity>(reinterpret_cast<uintptr_t>(ud));
    if (registry->valid(e) && registry->all_of<ColliderComponent>(e)) {
      // Drop *just* the primary shape or remove item that matches 'shape'
      // (choose whichever semantics you want)
      // Example: remove primary if it matches, else search extras:
      auto &c = registry->get<ColliderComponent>(e);
      bool removed = false;
      if (c.shape && c.shape.get() == shape) {
        cpSpaceRemoveShape(space, shape);
        c.shape.reset();
        removed = true;
      } else {
        for (auto it = c.extraShapes.begin(); it != c.extraShapes.end(); ++it) {
          if (it->shape && it->shape.get() == shape) {
            cpSpaceRemoveShape(space, shape);
            it->shape.reset();
            c.extraShapes.erase(it);
            removed = true;
            break;
          }
        }
      }
      // If body has no shapes left, you can also remove/sleep it
      // (up to your engine’s policy).
      (void)removed;
    } else {
      // Fallback: shape not tracked by ECS (rare). Just remove from space.
      cpSpaceRemoveShape(space, shape);
    }
  } else {
    // No ECS userdata set — remove from space.
    cpSpaceRemoveShape(space, shape);
  }
  // DO NOT cpShapeFree / cpBodyFree here; your engine owns them (smart
  // pointers)!
}

bool PhysicsWorld::ShatterNearest(float x, float y, float gridDiv /*=5.0f*/) {
  cpPointQueryInfo info{};
  const cpShape *hit = cpSpacePointQueryNearest(space, cpv(x, y), 0.0f,
                                                CP_SHAPE_FILTER_ALL, &info);
                                                
  SPDLOG_DEBUG("ShatterNearest at ({:.1f},{:.1f}) gridDiv={:.1f} hit={}", x,y,gridDiv, (bool)hit);
  if (!hit)
    return false;

  if (hit->type != CP_POLY_SHAPE)
    return false;

  cpBB bb = cpShapeGetBB(hit);
  float maxSpan = std::max(bb.r - bb.l, bb.t - bb.b);
  float cellSize = std::max(maxSpan / gridDiv, 5.0f);

  ShatterShape(const_cast<cpShape *>(hit), cellSize, cpv(x, y));


  return true;
}

bool PhysicsWorld::SliceFirstHit(cpVect A, cpVect B, float density,
                                 float minArea) {
  cpSegmentQueryInfo hit{};
  const cpShape *h =
      cpSpaceSegmentQueryFirst(space, A, B, 0.0f, CP_SHAPE_FILTER_ALL, &hit);
      
  SPDLOG_DEBUG("Slice: A=({:.1f},{:.1f}) B=({:.1f},{:.1f}) hit={} poly={} density={:.3f}",
             A.x,A.y,B.x,B.y, (bool)h, h && h->type==CP_POLY_SHAPE, density);

  if (!h)
    return false;

  if (h->type != CP_POLY_SHAPE)
    return false;

  // We are going to replace this shape, so we need a non-const handle:
  cpShape *toCut = const_cast<cpShape *>(h);
  return slicePolyShape(space, toCut, A, B, density, minArea);
}

entt::entity PhysicsWorld::AddSmoothSegmentChain(const std::vector<cpVect> &pts,
                                                 float radius,
                                                 const std::string &tag) {
  if (pts.size() < 2)
    return entt::null;
  if (!collisionTags.contains(tag))
    AddCollisionTag(tag);
  const cpCollisionType type = _tagToCollisionType[tag];

  entt::entity chainEntity = registry->create(); // optional handle

  cpBody *sbody = cpSpaceGetStaticBody(space);

  // Build segments [p[i-1], p[i]] and set neighbors to smooth junctions.
  for (size_t i = 1; i < pts.size(); ++i) {
    const cpVect v0 = pts[(i >= 2) ? (i - 2) : 0];
    const cpVect v1 = pts[i - 1];
    const cpVect v2 = pts[i];
    const cpVect v3 = pts[(i + 1 < pts.size()) ? (i + 1) : (pts.size() - 1)];

    cpShape *seg = cpSegmentShapeNew(sbody, v1, v2, radius);
    ApplyCollisionFilter(seg, tag);
    cpShapeSetCollisionType(seg, type);
    cpShapeSetFriction(seg, 1.0f);
    cpShapeSetElasticity(seg, 0.0f);

    // Key bit: tell Chipmunk about adjacent vertices so normals are smooth.
    cpSegmentShapeSetNeighbors(seg, v0, v3);

    // Optional: store the owning entity in userData if you want to relate back
    cpShapeSetUserData(
        seg, reinterpret_cast<void *>(static_cast<uintptr_t>(chainEntity)));

    cpSpaceAddShape(space, seg);
  }

  return chainEntity;
}

entt::entity PhysicsWorld::AddBarSegment(cpVect a, cpVect b, float thickness,
                                         const std::string &tag,
                                         int32_t group) {
  if (!collisionTags.contains(tag))
    AddCollisionTag(tag);

  // Mass/moment for a uniform slender rod about its center (I = m L^2 / 12)
  const cpVect center = cpvmult(cpvadd(a, b), 0.5f);
  const cpFloat length = cpvlength(cpvsub(b, a));
  const cpFloat mass = std::max<cpFloat>(length / 160.0f, 1e-4f);
  const cpFloat moment = mass * length * length / 12.0f;

  entt::entity e = registry->create();

  auto body = MakeSharedBody(mass, moment);
  cpBodySetPosition(body.get(), center);
  SetEntityToBody(body.get(), e);
  cpSpaceAddBody(space, body.get());

  // Segment endpoints in *body-local* frame
  const cpVect la = cpvsub(a, center);
  const cpVect lb = cpvsub(b, center);

  std::shared_ptr<cpShape> shape(
      cpSegmentShapeNew(body.get(), la, lb, thickness), cpShapeFree);
  ApplyCollisionFilter(shape.get(), tag);
  cpShapeSetCollisionType(shape.get(), _tagToCollisionType[tag]);
  cpShapeSetFriction(shape.get(), 1.0f);
  cpShapeSetElasticity(shape.get(), 0.0f);
  if (group != 0) {
    cpShapeFilter f = cpShapeGetFilter(shape.get());
    f.group = group; // same non-zero group = never collide
    cpShapeSetFilter(shape.get(), f);
  }
  SetEntityToShape(shape.get(), e);
  cpSpaceAddShape(space, shape.get());

  registry->emplace<ColliderComponent>(
      e, ColliderComponent{body, shape, tag, /*isSensor*/ false,
                           ColliderShapeType::Rectangle});

  return e;
}

namespace {
struct SpringClampData {
  cpFloat clampAbs;
};

static cpFloat SpringForceFunc(cpConstraint *spring, cpFloat dist) {
  auto *data = static_cast<SpringClampData *>(cpConstraintGetUserData(spring));
  const cpFloat clampAbs = data ? data->clampAbs : INFINITY;

  // Same math as the demo, but with a configurable clamp
  const cpFloat dx =
      cpfclamp(cpDampedSpringGetRestLength(spring) - dist, -clampAbs, clampAbs);
  return dx * cpDampedSpringGetStiffness(spring);
}
} // namespace

cpConstraint *PhysicsWorld::AddClampedDampedSpring(
    cpBody *a, cpBody *b, cpVect anchorA, cpVect anchorB, cpFloat restLength,
    cpFloat stiffness, cpFloat damping, cpFloat clampAbs) {
  cpConstraint *s =
      cpDampedSpringNew(a, b, anchorA, anchorB, restLength, stiffness, damping);

  auto *data = new SpringClampData{clampAbs};
  cpConstraintSetUserData(s, data);
  cpDampedSpringSetSpringForceFunc(s, &SpringForceFunc);

  cpSpaceAddConstraint(space, s);
  return s;
}

void PhysicsWorld::FreeSpringUserData(cpConstraint *c) {
  if (!c)
    return;
  if (auto *data = static_cast<SpringClampData *>(cpConstraintGetUserData(c))) {
    delete data;
    cpConstraintSetUserData(c, nullptr);
  }
}

void PhysicsWorld::EnableStickyBetween(const std::string &A,
                                       const std::string &B,
                                       cpFloat impulseThreshold,
                                       cpFloat maxForce) {
  if (!collisionTags.contains(A))
    AddCollisionTag(A);
  if (!collisionTags.contains(B))
    AddCollisionTag(B);

  cpCollisionType ta = _tagToCollisionType[A];
  cpCollisionType tb = _tagToCollisionType[B];

  _stickyByPair[PairKey(ta, tb)] = StickyConfig{impulseThreshold, maxForce};
  InstallStickyPairHandler(ta, tb); // idempotent
}

void PhysicsWorld::DisableStickyBetween(const std::string &A,
                                        const std::string &B) {
  if (!collisionTags.contains(A) || !collisionTags.contains(B))
    return;
  _stickyByPair.erase(PairKey(_tagToCollisionType[A], _tagToCollisionType[B]));
  // (Leaving the handler installed is fine; it will no-op w/o config.)
}

void PhysicsWorld::InstallStickyPairHandler(cpCollisionType ta,
                                            cpCollisionType tb) {
  // If you already add a custom handler for this pair elsewhere, merge these
  // function pointers.
  cpCollisionHandler *h = cpSpaceAddCollisionHandler(space, ta, tb);
  h->userData = this;
  h->beginFunc = &PhysicsWorld::C_StickyBegin;
  h->postSolveFunc = &PhysicsWorld::C_StickyPostSolve;
  h->separateFunc = &PhysicsWorld::C_StickySeparate;
  // Keep your existing begin/separate logging in OnCollisionBegin/End via
  // wildcard if you like; Sticky’s pair handler runs in addition to wildcard
  // handlers.
}

cpBool PhysicsWorld::C_StickyBegin(cpArbiter *a, cpSpace *s, void *d) {
  return static_cast<PhysicsWorld *>(d)->StickyBegin(a);
}
void PhysicsWorld::C_StickyPostSolve(cpArbiter *a, cpSpace *s, void *d) {
  static_cast<PhysicsWorld *>(d)->StickyPostSolve(a);
}
void PhysicsWorld::C_StickySeparate(cpArbiter *a, cpSpace *s, void *d) {
  static_cast<PhysicsWorld *>(d)->StickySeparate(a);
}

// Always allow contacts to start; glue creation happens in PostSolve (we need
// the impulse).
cpBool PhysicsWorld::StickyBegin(cpArbiter *arb) { return cpTrue; }

void PhysicsWorld::StickyPostSolve(cpArbiter *arb) {
  cpShape *sa, *sb;
  cpArbiterGetShapes(arb, &sa, &sb);
  cpCollisionType ta = cpShapeGetCollisionType(sa);
  cpCollisionType tb = cpShapeGetCollisionType(sb);

  auto it = _stickyByPair.find(PairKey(ta, tb));
  if (it == _stickyByPair.end())
    return;

  const StickyConfig cfg = it->second;

  const cpVect J = cpArbiterTotalImpulse(arb);
  if (cpvlength(J) < cfg.impulseThreshold)
    return;

  cpBody *ba = cpShapeGetBody(sa);
  cpBody *bb = cpShapeGetBody(sb);
  auto key = MakeBodyPair(ba, bb);

  // avoid piling up glue each frame
  auto &bucket = _stickyJoints[key];
  if (!bucket.empty())
    return;

  cpContactPointSet set = cpArbiterGetContactPointSet(arb);
  for (int i = 0; i < set.count; ++i) {
    const cpVect worldP =
        set.points[i].pointA; // <- use pointA (world space on A)
    cpConstraint *j = cpPivotJointNew(ba, bb, worldP);
    cpConstraintSetMaxBias(j, 0.0f);          // no creep
    cpConstraintSetMaxForce(j, cfg.maxForce); // glue strength
    cpSpaceAddConstraint(space, j);
    bucket.push_back(j);
  }
}

void PhysicsWorld::StickySeparate(cpArbiter *arb) {
  cpShape *sa, *sb;
  cpArbiterGetShapes(arb, &sa, &sb);
  cpBody *ba = cpShapeGetBody(sa);
  cpBody *bb = cpShapeGetBody(sb);
  auto key = MakeBodyPair(ba, bb);

  auto it = _stickyJoints.find(key);
  if (it == _stickyJoints.end())
    return;

  for (cpConstraint *c : it->second) {
    if (!c)
      continue;
    cpSpaceRemoveConstraint(space, c);
    cpConstraintFree(c);
  }
  _stickyJoints.erase(it);
}

void PhysicsWorld::EnableTankController(entt::entity e,
                                        float driveSpeed /*=30.f*/,
                                        float stopRadius /*=30.f*/,
                                        float pivotMaxForce /*=10000.f*/,
                                        float gearMaxForce /*=50000.f*/,
                                        float gearMaxBias /*=1.2f*/) {
  auto &col = registry->get<ColliderComponent>(e);

  // kinematic control body (one per tank)
  cpBody *control = cpBodyNewKinematic();
  cpSpaceAddBody(space, control);

  // pivot & gear from control → tank body
  cpConstraint *pivot = cpSpaceAddConstraint(
      space, cpPivotJointNew2(control, col.body.get(), cpvzero, cpvzero));
  cpConstraintSetMaxBias(pivot, 0.0f); // no linear correction creep
  cpConstraintSetMaxForce(pivot, std::max(0.f, pivotMaxForce));

  cpConstraint *gear = cpSpaceAddConstraint(
      space, cpGearJointNew(control, col.body.get(), 0.0f, 1.0f));
  cpConstraintSetErrorBias(gear, 0.0f); // fully correct each step
  cpConstraintSetMaxBias(gear, std::max(0.f, gearMaxBias));
  cpConstraintSetMaxForce(gear, std::max(0.f, gearMaxForce));

  TankController tc;
  tc.body = col.body.get();
  tc.control = control;
  tc.pivot = pivot;
  tc.gear = gear;
  tc.driveSpeed = driveSpeed;
  tc.stopRadius = stopRadius;
  tc.gearMaxBias = gearMaxBias;
  tc.gearMaxForce = gearMaxForce;
  tc.pivotMaxForce = pivotMaxForce;

  _tanks[e] = tc;
}

void PhysicsWorld::CommandTankTo(entt::entity e, cpVect targetWorld) {
  auto it = _tanks.find(e);
  if (it == _tanks.end())
    return;
  it->second.target = targetWorld;
  it->second.hasTarget = true;
}

void PhysicsWorld::UpdateTanks(double dt) {
  for (auto &[e, tc] : _tanks) {
    if (!tc.body || !tc.control)
      continue;
    if (!tc.hasTarget)
      continue;

    const cpVect pos = cpBodyGetPosition(tc.body);
    const cpVect forward = cpBodyGetRotation(tc.body);
    const cpVect toTarget = cpvsub(tc.target, pos);

    // Angle from tank forward to target, measured in tank-local space
    const cpVect localDelta = cpvunrotate(forward, toTarget);
    const cpFloat turn = cpvtoangle(localDelta);

    // Align control body’s angle so gear joint steers us toward the target
    cpBodySetAngle(tc.control, cpBodyGetAngle(tc.body) - turn);

    // Drive forward or reverse based on whether target is in front/behind
    if (cpvnear(tc.target, pos, tc.stopRadius)) {
      cpBodySetVelocity(tc.control, cpvzero);
    } else {
      const cpFloat dir = (cpvdot(toTarget, forward) > 0.f) ? 1.f : -1.f;
      cpBodySetVelocity(tc.control,
                        cpvrotate(forward, cpv(tc.driveSpeed * dir, 0.f)));
    }
  }
}

void PhysicsWorld::AttachFrictionJoints(cpBody *body, cpFloat linearMax,
                                        cpFloat angularMax) {
  cpBody *staticBody = cpSpaceGetStaticBody(space);

  cpConstraint *pivot = cpSpaceAddConstraint(
      space, cpPivotJointNew2(staticBody, body, cpvzero, cpvzero));
  cpConstraintSetMaxBias(pivot, 0.0f);
  cpConstraintSetMaxForce(pivot, std::max(0.f, (float)linearMax));

  cpConstraint *gear =
      cpSpaceAddConstraint(space, cpGearJointNew(staticBody, body, 0.0f, 1.0f));
  cpConstraintSetMaxBias(gear, 0.0f);
  cpConstraintSetMaxForce(gear, std::max(0.f, (float)angularMax));
}

} // namespace physics
