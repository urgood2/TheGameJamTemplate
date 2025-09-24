#include "physics_world.hpp"

#include "../../third_party/chipmunk/include/chipmunk/chipmunk.h"
#include "../../third_party/chipmunk/include/chipmunk/cpMarch.h"
#include "../../third_party/chipmunk/include/chipmunk/cpPolyline.h"
#include "util/common_headers.hpp"
#include <algorithm>
#include <memory>
#include <raylib.h>
#include <unordered_map>
#include <vector>

namespace physics {
  
template <class Fn>
static void ForEachShape(ColliderComponent& c, Fn&& fn) {
  if (c.shape) fn(c.shape.get());
  for (auto& p : c.extraShapes) if (p.shape) fn(p.shape.get());
}

template <class Fn>
static void ForEachShapeConst(const ColliderComponent& c, Fn&& fn) {
  if (c.shape) fn(c.shape.get());
  for (auto& p : c.extraShapes) if (p.shape) fn(p.shape.get());
}

size_t PhysicsWorld::GetShapeCount(entt::entity e) const {
    const auto& c = registry->get<ColliderComponent>(e);
    return (c.shape ? 1 : 0) + c.extraShapes.size();
}

cpBB PhysicsWorld::GetShapeBB(entt::entity e, size_t index) const {
    const auto& c = registry->get<ColliderComponent>(e);
    if (index == 0 && c.shape) return cpShapeGetBB(c.shape.get());
    size_t i = index - (c.shape ? 1 : 0);
    if (i < c.extraShapes.size()) return cpShapeGetBB(c.extraShapes[i].shape.get());
    return cpBBNew(0,0,0,0);
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
  return std::shared_ptr<cpShape>(cpBoxShapeNew(body, width, height, 0.0),
                                  [](cpShape *shape) { cpShapeFree(shape); });
}

PhysicsWorld::PhysicsWorld(entt::registry *registry, float meter,
                           float gravityX, float gravityY) {
  space = cpSpaceNew();
  cpSpaceSetGravity(space, cpv(gravityX, gravityY));
  cpSpaceSetIterations(space, 10);
  this->registry = registry;
}

PhysicsWorld::~PhysicsWorld() {
  if (space) {
    registry->view<ColliderComponent>().each([&](auto, auto& c){
      if (c.shape) cpSpaceRemoveShape(space, c.shape.get());
      for (auto& s : c.extraShapes) {
        if (s.shape) cpSpaceRemoveShape(space, s.shape.get());
      }
      if (c.body)  cpSpaceRemoveBody(space,  c.body.get());
    });

    if (mouseJoint) { cpSpaceRemoveConstraint(space, mouseJoint); cpConstraintFree(mouseJoint); mouseJoint = nullptr; }
    if (controlBody){ cpSpaceRemoveBody(space, controlBody); cpBodyFree(controlBody); controlBody = nullptr; }

    cpSpaceFree(space);
    space = nullptr;
  }
}


void PhysicsWorld::Update(float deltaTime) { cpSpaceStep(space, deltaTime); }

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

void PhysicsWorld::SetMeter(float meter) {
  this->meter = meter;
}

void PhysicsWorld::OnCollisionBegin(cpArbiter *arb) {
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

  std::string key = tagA + ":" + tagB;

  if (isTriggerA || isTriggerB) {
    if (isTriggerA)
      registry->get<ColliderComponent>(entityA).triggerEnter.push_back(dataB);
    if (isTriggerB)
      registry->get<ColliderComponent>(entityB).triggerEnter.push_back(dataA);

    triggerEnter[key].push_back(dataA);
    triggerActive[key].push_back(dataA);
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

  std::string key = tagA + ":" + tagB;

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
}

void PhysicsWorld::EnableCollisionBetween(
    const std::string &tag1, const std::vector<std::string> &tags) {
  auto &masks = collisionTags[tag1].masks;
  for (const auto &tag : tags) {
    masks.push_back(collisionTags[tag].category);
  }
}

void PhysicsWorld::DisableCollisionBetween(
    const std::string &tag1, const std::vector<std::string> &tags) {
  auto &masks = collisionTags[tag1].masks;
  for (const auto &tag : tags) {
    masks.erase(
        std::remove(masks.begin(), masks.end(), collisionTags[tag].category),
        masks.end());
  }
}

void PhysicsWorld::EnableTriggerBetween(const std::string &tag1,
                                        const std::vector<std::string> &tags) {
  for (const auto &tag : tags) {
    triggerTags[tag1].triggers.push_back(triggerTags[tag].category);
  }
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
  return collisionEnter[type1 + ":" + type2];
}

const std::vector<void *> &
PhysicsWorld::GetTriggerEnter(const std::string &type1,
                              const std::string &type2) {
  return triggerEnter[type1 + ":" + type2];
}

void PhysicsWorld::SetCollisionTags(const std::vector<std::string>& tags) {
  collisionTags.clear();
  triggerTags.clear();
  categoryToTag.clear();
  _tagToCollisionType.clear();

  _nextCollisionType = 1; // reset once here

  int category = 1;
  for (const auto& tag : tags) {
    collisionTags[tag] = {category, {}, {}};
    triggerTags[tag]   = {category, {}, {}};
    categoryToTag[category] = tag;

    _tagToCollisionType[tag] = _nextCollisionType++;

    category <<= 1;
  }
}

std::string PhysicsWorld::GetTagFromCategory(int category) {
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


// instance: look up pair first, then wildcard
cpBool PhysicsWorld::OnPreSolve(cpArbiter* arb) {
  cpShape *sa, *sb; cpArbiterGetShapes(arb, &sa, &sb);
  cpCollisionType ta = cpShapeGetCollisionType(sa);
  cpCollisionType tb = cpShapeGetCollisionType(sb);

  // canonicalize pair key (min,max) so A-B == B-A
  auto key = PairKey(std::min(ta,tb), std::max(ta,tb));

  // pair pre-solve?
  if (auto it = _luaPairHandlers.find(key); it != _luaPairHandlers.end()) {
    if (it->second.pre_solve.valid()) {
      sol::protected_function_result r = it->second.pre_solve(arb);
      if (!r.valid()) { sol::error err = r; SPDLOG_ERROR("pair pre_solve: {}", err.what()); return cpTrue; }
      // allow Lua to return boolean to accept/reject contact
      if (r.return_count() > 0 && r.get_type(0) == sol::type::boolean) return r.get<bool>();
      return cpTrue;
    }
  }
  // wildcard pre-solve? (any side)
  if (auto wi = _luaWildcardHandlers.find(ta); wi != _luaWildcardHandlers.end()) {
    if (wi->second.pre_solve.valid()) {
      auto r = wi->second.pre_solve(arb);
      if (!r.valid()) { sol::error err = r; SPDLOG_ERROR("wildcard({}) pre_solve: {}", (int)ta, err.what()); return cpTrue; }
      if (r.return_count() > 0 && r.get_type(0) == sol::type::boolean) return r.get<bool>();
      return cpTrue;
    }
  }
  if (auto wi = _luaWildcardHandlers.find(tb); wi != _luaWildcardHandlers.end()) {
    if (wi->second.pre_solve.valid()) {
      auto r = wi->second.pre_solve(arb);
      if (!r.valid()) { sol::error err = r; SPDLOG_ERROR("wildcard({}) pre_solve: {}", (int)tb, err.what()); return cpTrue; }
      if (r.return_count() > 0 && r.get_type(0) == sol::type::boolean) return r.get<bool>();
      return cpTrue;
    }
  }
  return cpTrue;
}

void PhysicsWorld::OnPostSolve(cpArbiter* arb) {
  cpShape *sa, *sb; cpArbiterGetShapes(arb, &sa, &sb);
  cpCollisionType ta = cpShapeGetCollisionType(sa);
  cpCollisionType tb = cpShapeGetCollisionType(sb);
  auto key = PairKey(std::min(ta,tb), std::max(ta,tb));

  auto call = [&](sol::protected_function& fn){
    if (fn.valid()) {
      auto r = fn(arb);
      if (!r.valid()) { sol::error err = r; SPDLOG_ERROR("post_solve: {}", err.what()); }
    }
  };

  if (auto it = _luaPairHandlers.find(key); it != _luaPairHandlers.end()) call(it->second.post_solve);
  if (auto wi = _luaWildcardHandlers.find(ta); wi != _luaWildcardHandlers.end()) call(wi->second.post_solve);
  if (auto wi = _luaWildcardHandlers.find(tb); wi != _luaWildcardHandlers.end()) call(wi->second.post_solve);
}


void PhysicsWorld::UpdateColliderTag(entt::entity entity, const std::string &newTag) {
  if (!collisionTags.contains(newTag)) { SPDLOG_DEBUG("Invalid tag: {}", newTag); return; }
  auto &c = registry->get<ColliderComponent>(entity);
  ForEachShape(c, [&](cpShape* s){
    ApplyCollisionFilter(s, newTag);
    cpShapeSetCollisionType(s, _tagToCollisionType[newTag]);
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
while (categoryToTag.contains(category)) category <<= 1;


  collisionTags[tag] = {category, {}, {}};
  triggerTags[tag] = {category, {}, {}};
  categoryToTag[category] = tag;
  _tagToCollisionType[tag] = _nextCollisionType++;
}

void PhysicsWorld::RemoveCollisionTag(const std::string &tag) {
  if (!collisionTags.contains(tag)) return;

  int category = collisionTags[tag].category;
  collisionTags.erase(tag);
  triggerTags.erase(tag);
  categoryToTag.erase(category);

  registry->view<ColliderComponent>().each([&](auto, auto &c) {
    ForEachShape(c, [&](cpShape* s){
      const auto f = cpShapeGetFilter(s);
      if ((int)f.categories == category) {
        ApplyCollisionFilter(s, "default");
        cpShapeSetCollisionType(s, _tagToCollisionType["default"]);
      }
    });
  });
}


void PhysicsWorld::UpdateCollisionMasks(const std::string &tag,
                                        const std::vector<std::string> &collidableTags) {
  if (!collisionTags.contains(tag)) return;

  // rewrite masks for the tag
  collisionTags[tag].masks.clear();
  for (const auto &t : collidableTags) {
    if (collisionTags.contains(t)) collisionTags[tag].masks.push_back(collisionTags[t].category);
  }

  const int targetCategory = collisionTags[tag].category;

  registry->view<ColliderComponent>().each([&](auto, auto &c) {
    ForEachShape(c, [&](cpShape* s){
      const auto f = cpShapeGetFilter(s);
      if ((int)f.categories == targetCategory) {
        ApplyCollisionFilter(s, tag);
        cpShapeSetCollisionType(s, _tagToCollisionType[tag]);
      }
    });
  });
}


void PhysicsWorld::ApplyCollisionFilter(cpShape* shape, const std::string& tag) {
  auto it = collisionTags.find(tag);
  if (it == collisionTags.end()) {
    SPDLOG_DEBUG("Invalid tag: {}. Tag not applied", tag);
    return;
  }

  const auto& collisionTag = it->second;

  cpBitmask maskBits = 0;
  for (int cat : collisionTag.masks) {
    maskBits |= static_cast<cpBitmask>(cat);
  }

  if (maskBits == 0) {
    maskBits = CP_ALL_CATEGORIES;
    SPDLOG_DEBUG("Tag '{}' has empty masks; defaulting mask to CP_ALL_CATEGORIES", tag);
  }

  cpShapeFilter filter = {
    0,
    static_cast<cpBitmask>(collisionTag.category),
    maskBits
  };

  cpShapeSetFilter(shape, filter);
}

std::vector<RaycastHit> PhysicsWorld::Raycast(float x1, float y1, float x2,
                                              float y2) {
  std::vector<RaycastHit> hits;

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

auto MakeShapeFor(const std::string& shapeType,
                  cpBody* body,
                  float a, float b, float c, float d,
                  const std::vector<cpVect>& points) -> std::shared_ptr<cpShape>
{
    if (shapeType == "rectangle") {
        return std::shared_ptr<cpShape>(cpBoxShapeNew(body, a, b, 0.0f), cpShapeFree);
    } else if (shapeType == "circle") {
        return std::shared_ptr<cpShape>(cpCircleShapeNew(body, a, cpvzero), cpShapeFree);
    } else if (shapeType == "polygon") {
        if (!points.empty()) {
            return std::shared_ptr<cpShape>(cpPolyShapeNew(body, (int)points.size(), points.data(), cpTransformIdentity, 0.0f), cpShapeFree);
        } else {
            std::vector<cpVect> verts = {{0,0},{a,0},{a/2,b}};
            return std::shared_ptr<cpShape>(cpPolyShapeNew(body, (int)verts.size(), verts.data(), cpTransformIdentity, 0.0f), cpShapeFree);
        }
    } else if (shapeType == "chain") {
        const auto& verts = points.empty() ? std::vector<cpVect>{{0,0},{a,b},{c,d}} : points;
        return std::shared_ptr<cpShape>(cpPolyShapeNew(body, (int)verts.size(), verts.data(), cpTransformIdentity, 1.0f), cpShapeFree);
    }
    throw std::invalid_argument("Unsupported shapeType: " + shapeType);
}

void PhysicsWorld::AddShapeToEntity(entt::entity e,
                                    const std::string& tag,
                                    const std::string& shapeType,
                                    float a, float b, float c, float d,
                                    bool isSensor,
                                    const std::vector<cpVect>& points)
{
    auto& col = registry->get<ColliderComponent>(e);
    if (!col.body) {
        // make a default dynamic body if none exists yet
        col.body = MakeSharedBody(isSensor ? 0.0f : 1.0f, cpMomentForBox(1.0f, std::max(1.f,a), std::max(1.f,b)));
        cpBodySetUserData(col.body.get(), reinterpret_cast<void*>(static_cast<uintptr_t>(e)));
        cpSpaceAddBody(space, col.body.get());
    }

    auto shape = MakeShapeFor(shapeType, col.body.get(), a,b,c,d, points);

    ApplyCollisionFilter(shape.get(), tag);
    cpShapeSetCollisionType(shape.get(), _tagToCollisionType[tag]);
    cpShapeSetSensor(shape.get(), isSensor);
    cpShapeSetUserData(shape.get(), reinterpret_cast<void*>(static_cast<uintptr_t>(e)));

    cpSpaceAddShape(space, shape.get());

    // if there is no primary yet, use this as primary for back-compat
    if (!col.shape) {
        col.shape     = shape;
        col.shapeType = (shapeType == "circle")    ? ColliderShapeType::Circle
                     : (shapeType == "polygon")   ? ColliderShapeType::Polygon
                     : (shapeType == "chain")     ? ColliderShapeType::Chain
                     : (shapeType == "rectangle") ? ColliderShapeType::Rectangle
                                                  : col.shapeType;
        col.tag       = tag;
        col.isSensor  = isSensor;
    } else {
        col.extraShapes.push_back({shape,
            (shapeType == "circle")    ? ColliderShapeType::Circle
          : (shapeType == "polygon")   ? ColliderShapeType::Polygon
          : (shapeType == "chain")     ? ColliderShapeType::Chain
                                       : ColliderShapeType::Rectangle,
          tag, isSensor});
    }
}

bool PhysicsWorld::RemoveShapeAt(entt::entity e, size_t index) {
    auto& c = registry->get<ColliderComponent>(e);
    // index 0 == primary; >=1 index into extraShapes (index-1)
    if (index == 0) {
        if (!c.shape) return false;
        cpSpaceRemoveShape(space, c.shape.get());
        c.shape.reset();
        return true;
    }
    size_t i = index - 1;
    if (i >= c.extraShapes.size()) return false;
    cpSpaceRemoveShape(space, c.extraShapes[i].shape.get());
    c.extraShapes.erase(c.extraShapes.begin() + i);
    return true;
}

void PhysicsWorld::ClearAllShapes(entt::entity e) {
    auto& c = registry->get<ColliderComponent>(e);
    if (c.shape) {
        cpSpaceRemoveShape(space, c.shape.get());
        c.shape.reset();
    }
    for (auto& s : c.extraShapes) {
        if (s.shape) cpSpaceRemoveShape(space, s.shape.get());
    }
    c.extraShapes.clear();
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
                               const std::vector<cpVect> &points)
{
  if (registry->all_of<ColliderComponent>(entity)) {
    AddShapeToEntity(entity, tag, shapeType, a,b,c,d, isSensor, points);
    return;
  }

  // original single-shape path, but now ends identical to the helper:
  auto body = MakeSharedBody(isSensor ? 0.0f : 1.0f, cpMomentForBox(1.0f, a, b));
  auto shape = MakeShapeFor(shapeType, body.get(), a,b,c,d, points);

  ApplyCollisionFilter(shape.get(), tag);
  cpShapeSetCollisionType(shape.get(), _tagToCollisionType[tag]);
  cpShapeSetSensor(shape.get(), isSensor);
  registry->emplace<ColliderComponent>(entity, ColliderComponent{
      body, shape, tag, isSensor,
      (shapeType == "circle")    ? ColliderShapeType::Circle
    : (shapeType == "polygon")   ? ColliderShapeType::Polygon
    : (shapeType == "chain")     ? ColliderShapeType::Chain
                                 : ColliderShapeType::Rectangle
  });

  cpShapeSetUserData(shape.get(), reinterpret_cast<void *>(static_cast<uintptr_t>(entity)));
  cpBodySetUserData(body.get(),  reinterpret_cast<void *>(static_cast<uintptr_t>(entity)));

  cpSpaceAddBody(space,  body.get());
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
  wanderAngle +=
      jitter * ((rand() % 200 - 100) / 100.0f);

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

void PhysicsWorld::RegisterPairPreSolve(const std::string& a, const std::string& b, sol::protected_function fn) {
    cpCollisionType ta = TypeForTag(a), tb = TypeForTag(b);
    _luaPairHandlers[PairKey(ta,tb)].pre_solve = std::move(fn);
    EnsurePairInstalled(ta, tb);
}

void PhysicsWorld::RegisterPairPostSolve(const std::string& a, const std::string& b, sol::protected_function fn) {
    cpCollisionType ta = TypeForTag(a), tb = TypeForTag(b);
    _luaPairHandlers[PairKey(ta,tb)].post_solve = std::move(fn);
    EnsurePairInstalled(ta, tb);
}

void PhysicsWorld::RegisterWildcardPreSolve(const std::string& tag, sol::protected_function fn) {
    cpCollisionType t = TypeForTag(tag);
    _luaWildcardHandlers[t].pre_solve = std::move(fn);
    EnsureWildcardInstalled(t);
}

void PhysicsWorld::RegisterWildcardPostSolve(const std::string& tag, sol::protected_function fn) {
    cpCollisionType t = TypeForTag(tag);
    _luaWildcardHandlers[t].post_solve = std::move(fn);
    EnsureWildcardInstalled(t);
}

void PhysicsWorld::ClearPairHandlers(const std::string& a, const std::string& b) {
    cpCollisionType ta = TypeForTag(a), tb = TypeForTag(b);
    _luaPairHandlers.erase(PairKey(ta,tb));
}

void PhysicsWorld::ClearWildcardHandlers(const std::string& tag) {
    cpCollisionType t = TypeForTag(tag);
    _luaWildcardHandlers.erase(t);
}

void PhysicsWorld::EnsureWildcardInstalled(cpCollisionType t) {
    if (_installedWildcards.count(t)) return;
    cpCollisionHandler* h = cpSpaceAddWildcardHandler(space, t);
    h->userData      = this;
    h->preSolveFunc  = &PhysicsWorld::C_PreSolve;
    h->postSolveFunc = &PhysicsWorld::C_PostSolve;
    h->beginFunc     = [](cpArbiter* a, cpSpace* s, void* d)->cpBool {
        static_cast<PhysicsWorld*>(d)->OnCollisionBegin(a);
        return cpTrue;
    };
    h->separateFunc  = [](cpArbiter* a, cpSpace* s, void* d) {
        static_cast<PhysicsWorld*>(d)->OnCollisionEnd(a);
    };
    _installedWildcards.insert(t);
}

void PhysicsWorld::EnsurePairInstalled(cpCollisionType ta, cpCollisionType tb) {
    uint64_t key = PairKey(ta, tb);
    if (_installedPairs.count(key)) return;

    cpCollisionHandler* h = cpSpaceAddCollisionHandler(space, ta, tb);
    h->userData      = this;
    h->preSolveFunc  = &PhysicsWorld::C_PreSolve;
    h->postSolveFunc = &PhysicsWorld::C_PostSolve;
    h->beginFunc     = [](cpArbiter* a, cpSpace* s, void* d)->cpBool {
        static_cast<PhysicsWorld*>(d)->OnCollisionBegin(a);
        return cpTrue;
    };
    h->separateFunc  = [](cpArbiter* a, cpSpace* s, void* d) {
        static_cast<PhysicsWorld*>(d)->OnCollisionEnd(a);
    };

    _installedPairs.insert(key);
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
    Seek(entity, averagePosition.x, averagePosition.y,
         maxSpeed);
  }
}

void PhysicsWorld::EnforceBoundary(entt::entity entity, float minY) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect position = cpBodyGetPosition(collider.body.get());
  if (position.y > minY) {
    cpVect force = cpv(
        0, -1000 * (position.y -
                    minY));
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

  AccelerateTowardAngle(entity, angle, acceleration,
                        maxSpeed);
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
  cpBodySetVelocity(collider.body.get(),
                    cpv(velocity.x, 0));
}

void PhysicsWorld::LockVertically(entt::entity entity) {
  auto &collider = registry->get<ColliderComponent>(entity);

  cpVect velocity = cpBodyGetVelocity(collider.body.get());
  cpBodySetVelocity(collider.body.get(),
                    cpv(0, velocity.y));
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
  ForEachShape(c, [&](cpShape* s){ cpShapeSetElasticity(s, restitution); });
}

void PhysicsWorld::SetFriction(entt::entity entity, float friction) {
  auto &c = registry->get<ColliderComponent>(entity);
  ForEachShape(c, [&](cpShape* s){ cpShapeSetFriction(s, friction); });
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
    float distance =
        fabs(mousePosition.x - position.x);
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
    float distance =
        fabs(mousePosition.y - position.y);
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
  cpVect counterClockwiseForce =
      cpvmult(offset, torque);

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
    cpSpaceSetIterations(space,
                         20);

    cpBodySetVelocityUpdateFunc(
        collider.body.get(),
        [](cpBody *body, cpVect gravity, cpFloat damping, cpFloat dt) {
          cpBodyUpdateVelocity(body, gravity, 1.0f,
                               dt);
        });

    cpSpaceSetCollisionSlop(
        space, 0.1);
  } else {
    cpSpaceSetIterations(space, 10);
    cpBodySetVelocityUpdateFunc(
        collider.body.get(),
        cpBodyUpdateVelocity);
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
    float moment =
        cpMomentForBox(mass, width, height);
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
    cpBodyActivate(
        collider.body
            .get());
  } else {
    throw std::invalid_argument("Invalid body type: " + bodyType);
  }
}

entt::entity PhysicsWorld::PointQuery(float x, float y) {
  cpPointQueryInfo info;
  cpShape *hit = cpSpacePointQueryNearest(space, cpv(x, y), 3.0f,
                                          CP_SHAPE_FILTER_ALL, &info);
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
      cpSpaceGetStaticBody(space),
      c.body.get(),
      0.0f,
      stiffness,
      damping
  );
  cpSpaceAddConstraint(space, spring);
}

void PhysicsWorld::RegisterExclusivePairCollisionHandler(const std::string& tagA, const std::string& tagB) {
  cpCollisionType ta = TypeForTag(tagA);
  cpCollisionType tb = TypeForTag(tagB);

  cpCollisionHandler* h = cpSpaceAddCollisionHandler(space, ta, tb);
  h->userData = this;

  h->beginFunc    = [](cpArbiter* a, cpSpace* s, void* d) -> cpBool {
    static_cast<PhysicsWorld*>(d)->OnCollisionBegin(a);
    return cpTrue;
  };
  h->separateFunc = [](cpArbiter* a, cpSpace* s, void* d) {
    static_cast<PhysicsWorld*>(d)->OnCollisionEnd(a);
    free_store(a);
  };

}

void PhysicsWorld::AddScreenBounds(float xMin, float yMin, float xMax, float yMax, float thickness,
                                   const std::string& collisionTag)
{
  cpBody* staticBody = cpSpaceGetStaticBody(space);
  cpShapeFilter filter = CP_SHAPE_FILTER_ALL;
  cpCollisionType type = TypeForTag(collisionTag);

  auto makeWall = [&](float ax, float ay, float bx, float by) {
    cpShape* seg = cpSegmentShapeNew(staticBody, cpv(ax, ay), cpv(bx, by), thickness);
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
}

void PhysicsWorld::StartMouseDrag(float x, float y) {
  if (mouseJoint)
    return;
  EndMouseDrag();

  if (!mouseBody) {
    mouseBody = cpBodyNewStatic();
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
  cpSpaceAddConstraint(space, mouseJoint);
}

void PhysicsWorld::UpdateMouseDrag(float x, float y) {
  if (mouseBody) {
    cpBodySetPosition(mouseBody, cpv(x, y));
  }
}

void PhysicsWorld::EndMouseDrag() {
  if (mouseJoint) {
    cpSpaceRemoveConstraint(space, mouseJoint);
    cpConstraintFree(mouseJoint);
    mouseJoint = nullptr;
  }
  draggedEntity = entt::null;
}

void PhysicsWorld::CreateTilemapColliders(
    const std::vector<std::vector<bool>> &collidable, float tileSize,
    float segmentRadius
) {
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
}



void PhysicsWorld::EnableCollisionGrouping(cpCollisionType minType,
                                           cpCollisionType maxType,
                                           int threshold,
                                           std::function<void(cpBody*)> onGroupRemoved)
{
    _groupThreshold  = threshold;
    _onGroupRemoved  = std::move(onGroupRemoved);

    for(cpCollisionType t = minType; t <= maxType; ++t) {
        auto handler = cpSpaceAddCollisionHandler(
            space, t, t
        );
        handler->postSolveFunc = &PhysicsWorld::GroupPostSolveCallback;
        handler->userData = this;
    }
}

void PhysicsWorld::GroupPostSolveCallback(cpArbiter* arb,
                                            cpSpace*,
                                            void*      userData)
{
    static_cast<PhysicsWorld*>(userData)->OnGroupPostSolve(arb);
}

void PhysicsWorld::OnGroupPostSolve(cpArbiter* arb) {
    cpShape *shapeA, *shapeB;
    cpArbiterGetShapes(arb, &shapeA, &shapeB);
    cpBody  *bodyA = cpShapeGetBody(shapeA);
    cpBody  *bodyB = cpShapeGetBody(shapeB);

    MakeNode(bodyA);
    MakeNode(bodyB);
    UnionBodies(bodyA, bodyB);

}


UFNode& PhysicsWorld::MakeNode(cpBody* body) {
    auto it = _groupNodes.find(body);
    if(it == _groupNodes.end()) {
        UFNode node;
        node.parent = &node;
        node.count  = 1;
        auto pair  = _groupNodes.emplace(body, node);
        return pair.first->second;
    }
    return it->second;
}

UFNode& PhysicsWorld::FindNode(cpBody* body) {
    UFNode& node = MakeNode(body);

    if(node.parent != &node) {
        cpBody* parentBody = nullptr;
        for(auto& kv : _groupNodes) {
            if(&kv.second == node.parent) {
                parentBody = kv.first;
                break;
            }
        }
        node.parent = &FindNode(parentBody);
    }
    return *node.parent;
}

void PhysicsWorld::UnionBodies(cpBody* a, cpBody* b) {
    UFNode& na = FindNode(a);
    UFNode& nb = FindNode(b);
    if(&na != &nb) {
        nb.parent = &na;
        na.count += nb.count;
    }
}

void PhysicsWorld::ProcessGroups() {
    for(auto& [body, node] : _groupNodes) {
        if(node.parent == &node && node.count >= _groupThreshold) {
            _onGroupRemoved(body);
        }
    }
}
}
