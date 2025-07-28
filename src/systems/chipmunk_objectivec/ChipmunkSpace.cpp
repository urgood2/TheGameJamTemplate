
// ChipmunkSpace.cpp
#include "ChipmunkSpace.hpp"
#include "ChipmunkConstraints.hpp"
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"
extern "C" {
#include "third_party/chipmunk/include/chipmunk/chipmunk_private.h"
}
#include <cstring>

// C-style callbacks for handlers
static bool DefaultBeginFunc(cpArbiter* arb, cpSpace* space, void* context) {
    auto* ctx = static_cast<ChipmunkSpace::HandlerContext*>(context);
    auto* wrapper = static_cast<ChipmunkSpace*>(cpSpaceGetUserData(space));
    using Fn = bool(*)(void*, cpArbiter*, ChipmunkSpace*);
    return reinterpret_cast<Fn>(ctx->begin)(ctx->delegate, arb, wrapper);
}

static bool DefaultPreSolveFunc(cpArbiter* arb, cpSpace* space, void* context) {
    auto ctx = static_cast<ChipmunkSpace::HandlerContext*>(context);
    auto* wrapper = static_cast<ChipmunkSpace*>(cpSpaceGetUserData(space));
    using Fn = bool(*)(void*, cpArbiter*, ChipmunkSpace*);
    return reinterpret_cast<Fn>(ctx->preSolve)(ctx->delegate, arb, wrapper);
}
static void DefaultPostSolveFunc(cpArbiter* arb, cpSpace* space, void* context) {
    auto ctx = static_cast<ChipmunkSpace::HandlerContext*>(context);
    auto* wrapper = static_cast<ChipmunkSpace*>(cpSpaceGetUserData(space));
    using Fn = void(*)(void*, cpArbiter*, ChipmunkSpace*);
    reinterpret_cast<Fn>(ctx->postSolve)(ctx->delegate, arb, wrapper);
}
static void DefaultSeparateFunc(cpArbiter* arb, cpSpace* space, void* context) {
    auto ctx = static_cast<ChipmunkSpace::HandlerContext*>(context);
    auto* wrapper = static_cast<ChipmunkSpace*>(cpSpaceGetUserData(space));
    using Fn = void(*)(void*, cpArbiter*, ChipmunkSpace*);
    reinterpret_cast<Fn>(ctx->separate)(ctx->delegate, arb, wrapper);
}

ChipmunkSpace::ChipmunkSpace() {
    _space = cpSpaceNew();
    cpSpaceSetUserData(_space, this);
    _staticBody = new ChipmunkBody(0.0f, 0.0f);
    _staticBody->setType(CP_BODY_TYPE_STATIC);
    cpSpaceSetStaticBody(_space, _staticBody->body());
}

ChipmunkSpace::~ChipmunkSpace() {
    delete _staticBody;
    cpSpaceFree(_space);
}

#define ACCESSOR(name, ctype, getter, setter) \
ctype ChipmunkSpace::name() const { return getter(_space); } \
void ChipmunkSpace::set##name(ctype v) { setter(_space, v); }
ACCESSOR(Iterations, int, cpSpaceGetIterations, cpSpaceSetIterations)
ACCESSOR(Gravity, cpVect, cpSpaceGetGravity, cpSpaceSetGravity)
ACCESSOR(Damping, cpFloat, cpSpaceGetDamping, cpSpaceSetDamping)
ACCESSOR(IdleSpeedThreshold, cpFloat, cpSpaceGetIdleSpeedThreshold, cpSpaceSetIdleSpeedThreshold)
ACCESSOR(SleepTimeThreshold, cpFloat, cpSpaceGetSleepTimeThreshold, cpSpaceSetSleepTimeThreshold)
ACCESSOR(CollisionSlop, cpFloat, cpSpaceGetCollisionSlop, cpSpaceSetCollisionSlop)
ACCESSOR(CollisionBias, cpFloat, cpSpaceGetCollisionBias, cpSpaceSetCollisionBias)
ACCESSOR(CollisionPersistence, cpTimestamp, cpSpaceGetCollisionPersistence, cpSpaceSetCollisionPersistence)

cpSpace* ChipmunkSpace::space() const { return _space; }
ChipmunkBody* ChipmunkSpace::staticBody() const { return _staticBody; }
cpFloat ChipmunkSpace::currentTimeStep() const { return cpSpaceGetCurrentTimeStep(_space); }
bool ChipmunkSpace::isLocked() const { return cpSpaceIsLocked(_space); }
void* ChipmunkSpace::UserData() const { return cpSpaceGetUserData(_space); }
void ChipmunkSpace::setUserData(void* data) { cpSpaceSetUserData(_space, data); }

ChipmunkSpace* ChipmunkSpace::SpaceFromCPSpace(cpSpace* s) {
    return static_cast<ChipmunkSpace*>(cpSpaceGetUserData(s));
}

// Collision Handlers
void ChipmunkSpace::setDefaultCollisionHandler(
    void* delegate,
    cpCollisionBeginFunc begin,
    cpCollisionPreSolveFunc preSolve,
    cpCollisionPostSolveFunc postSolve,
    cpCollisionSeparateFunc separate
) {
    HandlerContext ctx{delegate, (cpCollisionType)-1, (cpCollisionType)-1, begin, preSolve, postSolve, separate};
    _handlers.push_back(ctx);
    auto handler = cpSpaceAddDefaultCollisionHandler(_space);
    handler->beginFunc = begin ? reinterpret_cast<cpCollisionBeginFunc>(DefaultBeginFunc) : nullptr;
    handler->preSolveFunc = preSolve ? reinterpret_cast<cpCollisionPreSolveFunc>(DefaultPreSolveFunc) : nullptr;
    handler->postSolveFunc = postSolve ? reinterpret_cast<cpCollisionPostSolveFunc>(DefaultPostSolveFunc) : nullptr;
    handler->separateFunc = separate ? reinterpret_cast<cpCollisionSeparateFunc>(DefaultSeparateFunc) : nullptr;
    handler->userData = &_handlers.back();
}

void ChipmunkSpace::addCollisionHandler(
    void* delegate,
    cpCollisionType a, cpCollisionType b,
    cpCollisionBeginFunc begin,
    cpCollisionPreSolveFunc preSolve,
    cpCollisionPostSolveFunc postSolve,
    cpCollisionSeparateFunc separate
) {
    HandlerContext ctx{delegate, a, b, begin, preSolve, postSolve, separate};
    _handlers.push_back(ctx);
    auto handler = cpSpaceAddCollisionHandler(_space, a, b);
    handler->beginFunc = begin ? reinterpret_cast<cpCollisionBeginFunc>(DefaultBeginFunc) : nullptr;
    handler->preSolveFunc = preSolve ? reinterpret_cast<cpCollisionPreSolveFunc>(DefaultPreSolveFunc) : nullptr;
    handler->postSolveFunc = postSolve ? reinterpret_cast<cpCollisionPostSolveFunc>(DefaultPostSolveFunc) : nullptr;
    handler->separateFunc = separate ? reinterpret_cast<cpCollisionSeparateFunc>(DefaultSeparateFunc) : nullptr;
    handler->userData = &_handlers.back();
}

// Object management
void ChipmunkSpace::add(ChipmunkObject* obj) {
  for(auto *child : obj->chipmunkObjects()) {
    child->addToSpace(this);
  }
  _children.insert(obj);
}

void ChipmunkSpace::add(ChipmunkShape* shape) {
    cpSpaceAddBody( _space, shape->body()->body());  // add the body first
    cpSpaceAddShape(_space, shape->shape());   // raw C API
    _children.insert(shape);
}
void ChipmunkSpace::add(ChipmunkBody* body) {
    cpSpaceAddBody(_space, body->body());
    _children.insert(body);
}

void ChipmunkSpace::remove(ChipmunkObject* obj) {
    if (auto* base = dynamic_cast<ChipmunkBaseObject*>(obj)) {
        base->removeFromSpace(this);
    } else {
        for (auto* child : obj->chipmunkObjects()) child->removeFromSpace(this);
    }
    _children.erase(obj);
}

bool ChipmunkSpace::contains(ChipmunkObject* obj) const {
    return _children.find(obj) != _children.end();
}

void ChipmunkSpace::smartAdd(ChipmunkObject* obj) {
    if (cpSpaceIsLocked(_space)) addPostStepAddition(obj);
    else add(obj);
}

void ChipmunkSpace::smartRemove(ChipmunkObject* obj) {
    if (cpSpaceIsLocked(_space)) addPostStepRemoval(obj);
    else remove(obj);
}

// Bounds helper
std::vector<ChipmunkObject*> ChipmunkSpace::addBounds(
    cpBB bounds, cpFloat radius, cpFloat elasticity, cpFloat friction,
    cpShapeFilter filter, cpCollisionType collisionType
) {
    auto l = bounds.l - radius; auto b = bounds.b - radius;
    auto r = bounds.r + radius; auto t = bounds.t + radius;
    std::vector<ChipmunkObject*> segs;

    auto makeSeg = [&](cpVect a, cpVect bb){
        // Instantiate the concrete segment‐shape wrapper, not the abstract base:
        auto* seg = new ChipmunkSegmentShape(
            _staticBody,   // body to attach it to
            a,             // start point
            bb,            // end point
            radius         // thickness
        );
        seg->setElasticity(elasticity);
        seg->setFriction(friction);
        seg->setFilter(filter);
        seg->setCollisionType(collisionType);
        return seg;     // returns a ChipmunkSegmentShape*, which is-a ChipmunkShape*
    };

    segs.push_back(makeSeg(cpv(l,b), cpv(l,t)));
    segs.push_back(makeSeg(cpv(l,t), cpv(r,t)));
    segs.push_back(makeSeg(cpv(r,t), cpv(r,b)));
    segs.push_back(makeSeg(cpv(r,b), cpv(l,b)));

    for(auto* o : segs){
        add(o);
    }
    return segs;
}


// Post-step callbacks
bool ChipmunkSpace::addPostStepCallback(void* target, cpPostStepFunc func, void* key, void* context) {
    if (!cpSpaceGetPostStepCallback(_space, key)) {
        cpSpaceAddPostStepCallback(_space, func, key, context);
        return true;
    }
    return false;
}
bool ChipmunkSpace::addPostStepBlock(const std::function<void()>& block, void* key) {
    struct BlockContext { std::function<void()> blk; };
    if (!cpSpaceGetPostStepCallback(_space, key)) {
        auto* ctx = new BlockContext{block};
        cpSpaceAddPostStepCallback(_space,
            [](cpSpace*, void* k, void* c){ reinterpret_cast<BlockContext*>(c)->blk(); delete reinterpret_cast<BlockContext*>(c); },
            key, ctx);
        return true;
    }
    return false;
}
void ChipmunkSpace::addPostStepAddition(ChipmunkObject* obj) { addPostStepCallback(this,
    [](cpSpace*, void* k, void* c){ reinterpret_cast<ChipmunkSpace*>(k)->add(reinterpret_cast<ChipmunkObject*>(c)); },
    this, obj);
}
void ChipmunkSpace::addPostStepRemoval(ChipmunkObject* obj) { addPostStepCallback(this,
    [](cpSpace*, void* k, void* c){ reinterpret_cast<ChipmunkSpace*>(k)->remove(reinterpret_cast<ChipmunkObject*>(c)); },
    this, obj);
}

// Queries
std::vector<ChipmunkPointQueryInfo> ChipmunkSpace::pointQueryAll(cpVect point, cpFloat dist, cpShapeFilter filter) {
    std::vector<ChipmunkPointQueryInfo> out;
    cpSpacePointQuery(_space, point, dist, filter,
    [](cpShape* s, cpVect p, cpFloat d, cpVect g, void* ctx){
        auto &vec = *reinterpret_cast<std::vector<ChipmunkPointQueryInfo>*>(ctx);
        cpPointQueryInfo info{ .point = p, .distance = d, .gradient = g };            // build the C struct
        vec.emplace_back(s, info);                    // use the ctor you already have
    },
    &out
);

    return out;
}
ChipmunkPointQueryInfo ChipmunkSpace::pointQueryNearest(cpVect point, cpFloat dist, cpShapeFilter filter) {
    cpPointQueryInfo info;
    auto* s = cpSpacePointQueryNearest(_space, point, dist, filter, &info);
    return s ? ChipmunkPointQueryInfo(s, info) : ChipmunkPointQueryInfo();
}
std::vector<ChipmunkSegmentQueryInfo> ChipmunkSpace::segmentQueryAll(
    cpVect a, cpVect b, cpFloat r, cpShapeFilter filter
) {
    std::vector<ChipmunkSegmentQueryInfo> out;
    cpSpaceSegmentQuery(_space, a, b, r, filter,
        [](cpShape* s, cpVect p, cpVect n, cpFloat t, void* ctx){
            auto &vec = *reinterpret_cast<std::vector<ChipmunkSegmentQueryInfo>*>(ctx);
            // Build the C struct first:
            cpSegmentQueryInfo info;
            info.point  = p;
            info.normal = n;
            info.alpha  = t;
            // Then wrap it:
            vec.emplace_back(s, info);
        },
        &out
    );
    return out;
}
ChipmunkSegmentQueryInfo ChipmunkSpace::segmentQueryFirst(cpVect a, cpVect b, cpFloat r, cpShapeFilter filter) {
    cpSegmentQueryInfo info;
    auto hit = cpSpaceSegmentQueryFirst(_space, a, b, r, filter, &info);
    return hit ? ChipmunkSegmentQueryInfo(hit, info) : ChipmunkSegmentQueryInfo();
}
std::vector<ChipmunkShape*> ChipmunkSpace::bbQueryAll(cpBB bb, cpShapeFilter filter) {
    std::vector<ChipmunkShape*> out;
    cpSpaceBBQuery(_space, bb, filter,
        [](cpShape* s, void* ctx){ reinterpret_cast<std::vector<ChipmunkShape*>*>(ctx)->push_back(static_cast<ChipmunkShape*>(cpShapeGetUserData(s))); }, &out);
    return out;
}
std::vector<ChipmunkShapeQueryInfo>
ChipmunkSpace::shapeQueryAll(ChipmunkShape* chipmunkShape/*unused*/) {
    std::vector<ChipmunkShapeQueryInfo> out;
    cpSpaceShapeQuery(_space, chipmunkShape->shape() /* only need the raw cpShape* */,
        [](cpShape* s, cpContactPointSet* pts, void* ctx){
            auto &vec = *reinterpret_cast<std::vector<ChipmunkShapeQueryInfo>*>(ctx);
            // Rebuild the C struct
            cpContactPointSet info = *pts;
            // Recover the C++ wrapper from userData:
            auto* wrapper = static_cast<ChipmunkShape*>(cpShapeGetUserData(s));
            // Push the wrapped info
            vec.push_back(ChipmunkShapeQueryInfo(wrapper, info));
        },
        &out
    );
    return out;
}

bool ChipmunkSpace::shapeTest(ChipmunkShape* shape) const { return cpSpaceShapeQuery(_space, shape->shape(), nullptr, nullptr); }
std::vector<ChipmunkBody*> ChipmunkSpace::bodies() const {
    std::vector<ChipmunkBody*> out;
    cpSpaceEachBody(_space, [](cpBody* b, void* ctx){ reinterpret_cast<std::vector<ChipmunkBody*>*>(ctx)->push_back(static_cast<ChipmunkBody*>(cpBodyGetUserData(b))); }, &out);
    return out;
}
std::vector<ChipmunkShape*> ChipmunkSpace::shapes() const {
    std::vector<ChipmunkShape*> out;
    cpSpaceEachShape(_space, [](cpShape* s, void* ctx){ reinterpret_cast<std::vector<ChipmunkShape*>*>(ctx)->push_back(static_cast<ChipmunkShape*>(cpShapeGetUserData(s))); }, &out);
    return out;
}
std::vector<ChipmunkConstraint*> ChipmunkSpace::constraints() const {
    std::vector<ChipmunkConstraint*> out;
    cpSpaceEachConstraint(_space, [](cpConstraint* c, void* ctx){ reinterpret_cast<std::vector<ChipmunkConstraint*>*>(ctx)->push_back(static_cast<ChipmunkConstraint*>(cpConstraintGetUserData(c))); }, &out);
    return out;
}

// Reindexing
void ChipmunkSpace::reindexStatic() { cpSpaceReindexStatic(_space); }
void ChipmunkSpace::reindexShape(ChipmunkShape* shape) { cpSpaceReindexShape(_space, shape->shape()); }
void ChipmunkSpace::reindexShapesForBody(ChipmunkBody* body) { cpSpaceReindexShapesForBody(_space, body->body()); }

// Stepping
void ChipmunkSpace::step(cpFloat dt) { cpSpaceStep(_space, dt); }

// HastySpace
ChipmunkHastySpace::ChipmunkHastySpace() { _space = cpHastySpaceNew(); cpSpaceSetUserData(_space, this); _staticBody = new ChipmunkBody(0.0f,0.0f); cpSpaceSetStaticBody(_space,_staticBody->body()); }
ChipmunkHastySpace::~ChipmunkHastySpace() { delete _staticBody; cpHastySpaceFree(_space); }
size_t ChipmunkHastySpace::threads() const { return cpHastySpaceGetThreads(_space); } void ChipmunkHastySpace::setThreads(size_t n) { cpHastySpaceSetThreads(_space,n); }
void ChipmunkHastySpace::step(cpFloat dt) { cpHastySpaceStep(_space, dt); }
