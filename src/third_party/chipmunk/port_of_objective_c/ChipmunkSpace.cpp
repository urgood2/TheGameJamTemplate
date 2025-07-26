
// ChipmunkSpace.cpp
#include "ChipmunkSpace.hpp"
#include <cstring>

// C-style callbacks for handlers
static bool DefaultBeginFunc(cpArbiter* arb, cpSpace* space, void* context) {
    auto ctx = static_cast<ChipmunkSpace::HandlerContext*>(context);
    using Fn = bool(*)(void*, cpArbiter*, ChipmunkSpace*);
    return reinterpret_cast<Fn>(ctx->begin)(ctx->delegate, arb, ctx->space());
}
static bool DefaultPreSolveFunc(cpArbiter* arb, cpSpace* space, void* context) {
    auto ctx = static_cast<ChipmunkSpace::HandlerContext*>(context);
    using Fn = bool(*)(void*, cpArbiter*, ChipmunkSpace*);
    return reinterpret_cast<Fn>(ctx->preSolve)(ctx->delegate, arb, ctx->space());
}
static void DefaultPostSolveFunc(cpArbiter* arb, cpSpace* space, void* context) {
    auto ctx = static_cast<ChipmunkSpace::HandlerContext*>(context);
    using Fn = void(*)(void*, cpArbiter*, ChipmunkSpace*);
    reinterpret_cast<Fn>(ctx->postSolve)(ctx->delegate, arb, ctx->space());
}
static void DefaultSeparateFunc(cpArbiter* arb, cpSpace* space, void* context) {
    auto ctx = static_cast<ChipmunkSpace::HandlerContext*>(context);
    using Fn = void(*)(void*, cpArbiter*, ChipmunkSpace*);
    reinterpret_cast<Fn>(ctx->separate)(ctx->delegate, arb, ctx->space());
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
ACCESSOR(iterations, int, cpSpaceGetIterations, cpSpaceSetIterations)
ACCESSOR(gravity, cpVect, cpSpaceGetGravity, cpSpaceSetGravity)
ACCESSOR(damping, cpFloat, cpSpaceGetDamping, cpSpaceSetDamping)
ACCESSOR(idleSpeedThreshold, cpFloat, cpSpaceGetIdleSpeedThreshold, cpSpaceSetIdleSpeedThreshold)
ACCESSOR(sleepTimeThreshold, cpFloat, cpSpaceGetSleepTimeThreshold, cpSpaceSetSleepTimeThreshold)
ACCESSOR(collisionSlop, cpFloat, cpSpaceGetCollisionSlop, cpSpaceSetCollisionSlop)
ACCESSOR(collisionBias, cpFloat, cpSpaceGetCollisionBias, cpSpaceSetCollisionBias)
ACCESSOR(collisionPersistence, cpTimestamp, cpSpaceGetCollisionPersistence, cpSpaceSetCollisionPersistence)

cpSpace* ChipmunkSpace::space() const { return _space; }
ChipmunkBody* ChipmunkSpace::staticBody() const { return _staticBody; }
cpFloat ChipmunkSpace::currentTimeStep() const { return cpSpaceGetCurrentTimeStep(_space); }
bool ChipmunkSpace::isLocked() const { return cpSpaceIsLocked(_space); }
void* ChipmunkSpace::userData() const { return cpSpaceGetUserData(_space); }
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
    if (auto* base = dynamic_cast<ChipmunkBaseObject*>(obj)) {
        base->addToSpace(this);
    } else {
        for (auto* child : obj->chipmunkObjects()) child->addToSpace(this);
    }
    _children.insert(obj);
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
    auto makeSeg = [&](cpVect a, cpVect bb) {
        auto seg = new ChipmunkShape(cpSegmentShapeNew(_staticBody->body(), a, bb, radius));
        seg->setElasticity(elasticity);
        seg->setFriction(friction);
        seg->setFilter(filter);
        seg->setCollisionType(collisionType);
        return seg;
    };
    segs.push_back(makeSeg(cpv(l,b), cpv(l,t)));
    segs.push_back(makeSeg(cpv(l,t), cpv(r,t)));
    segs.push_back(makeSeg(cpv(r,t), cpv(r,b)));
    segs.push_back(makeSeg(cpv(r,b), cpv(l,b)));
    for (auto* o : segs) add(o);
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
        [](cpShape* s, cpVect p, cpFloat d, cpVect g, void* cntx){ reinterpret_cast<std::vector<ChipmunkPointQueryInfo>*>(cntx)->emplace_back(s,p,d,g); }, &out);
    return out;
}
ChipmunkPointQueryInfo ChipmunkSpace::pointQueryNearest(cpVect point, cpFloat dist, cpShapeFilter filter) {
    cpPointQueryInfo info;
    auto* s = cpSpacePointQueryNearest(_space, point, dist, filter, &info);
    return s ? ChipmunkPointQueryInfo(s, info) : ChipmunkPointQueryInfo();
}
std::vector<ChipmunkSegmentQueryInfo> ChipmunkSpace::segmentQueryAll(cpVect a, cpVect b, cpFloat r, cpShapeFilter filter) {
    std::vector<ChipmunkSegmentQueryInfo> out;
    cpSpaceSegmentQuery(_space, a, b, r, filter,
        [](cpShape* s, cpVect p, cpVect n, cpFloat t, void* ctx){ reinterpret_cast<std::vector<ChipmunkSegmentQueryInfo>*>(ctx)->emplace_back(s,p,n,t); }, &out);
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
std::vector<ChipmunkShapeQueryInfo> ChipmunkSpace::shapeQueryAll(ChipmunkShape* shape) {
    std::vector<ChipmunkShapeQueryInfo> out;
    cpSpaceShapeQuery(_space, shape->shape(),
        [](cpShape* s, cpContactPointSet* pts, void* ctx){ reinterpret_cast<std::vector<ChipmunkShapeQueryInfo>*>(ctx)->emplace_back(s, *pts); }, &out);
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
