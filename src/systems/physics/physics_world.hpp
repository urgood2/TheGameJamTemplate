#pragma once
#include "../../third_party/chipmunk/include/chipmunk/chipmunk.h"
#include "../../third_party/chipmunk/include/chipmunk/chipmunk_private.h"
#include "../../third_party/chipmunk/include/chipmunk/chipmunk_structs.h"
#include "entt/entt.hpp"
#include "physics_components.hpp"
#include "raylib.h"
#include "systems/layer/layer.hpp"
#include "third_party/chipmunk/include/chipmunk/chipmunk_types.h"
#include <memory>
#include <unordered_map>
#include <vector>

namespace physics {
    
/* ---------------------------- from sticky demo ---------------------------- */

struct StickyConfig {
  cpFloat impulseThreshold;   // create glue if total impulse >= this
  cpFloat maxForce;           // joint MaxForce (how strong the glue is)
};

    
/* ----------------------------- from slice demo ---------------------------- */
    // Signed distance of point p to the infinite line through A->B (left side positive).
    static inline cpFloat signedDistToLine(cpVect p, cpVect A, cpVect B) {
        // Normal pointing to the left of AB
        cpVect n = cpvperp(cpvsub(B, A));
        // Normalize is not required for sign consistency; scale cancels in clipping.
        return cpvdot(n, cpvsub(p, A));
    }

    // Clip a world-space convex polygon against half-space (keep side where sdist >= 0).
    // inPoly: convex poly in world coordinates.
    // outPoly: result polygon (world coordinates).
    static void clipHalfSpace(const std::vector<cpVect>& inPoly, std::vector<cpVect>& outPoly, cpVect A, cpVect B) {
        outPoly.clear();
        if (inPoly.empty()) return;

        auto sdist = [&](const cpVect& P) { return signedDistToLine(P, A, B); };

        cpVect prev = inPoly.back();
        cpFloat prevD = sdist(prev);

        for (size_t i = 0; i < inPoly.size(); ++i) {
            cpVect curr = inPoly[i];
            cpFloat currD = sdist(curr);

            bool currInside = (currD >= 0.0f);
            bool prevInside = (prevD >= 0.0f);

            // Edge crosses boundary?
            if (prevInside != currInside) {
                // Interpolate intersection between prev and curr where sdist = 0
                cpFloat t = prevD / (prevD - currD); // safe if prevD != currD due to branch
                cpVect I = cpvlerp(prev, curr, t);
                outPoly.push_back(I);
            }
            if (currInside) outPoly.push_back(curr);

            prev = curr;
            prevD = currD;
        }
    }

    // Transform body-local polygon vertices to world.
    static void polyBodyLocalToWorld(const cpBody* body, const cpShape* poly, std::vector<cpVect>& outWorldVerts) {
        int count = cpPolyShapeGetCount(poly);
        outWorldVerts.resize(count);
        for (int i = 0; i < count; ++i) {
            cpVect lv = cpPolyShapeGetVert(poly, i);
            outWorldVerts[i] = cpBodyLocalToWorld(body, lv);
        }
    }

    // Build a new dynamic rigid piece from world-space polygon verts.
    // Copies material/filter/collision type from src shape.
    static cpBody* makePieceFromWorldPoly(cpSpace* space,
                                        const std::vector<cpVect>& worldVerts,
                                        const cpShape* src,
                                        float density /*area * density -> mass*/) {
        if (worldVerts.size() < 3) return nullptr;

        // Compute area & centroid in world-space, then shift verts to local (centroid) space.
        cpFloat area = cpAreaForPoly((int)worldVerts.size(), worldVerts.data(), 0.0f);
        if (area <= 0) return nullptr;

        cpVect centroid = cpCentroidForPoly((int)worldVerts.size(), worldVerts.data());
        std::vector<cpVect> localVerts(worldVerts.size());
        for (size_t i = 0; i < worldVerts.size(); ++i) {
            localVerts[i] = cpvsub(worldVerts[i], centroid);
        }

        cpFloat mass = area * density;
        if (mass <= 0) mass = 1.0f;

        cpFloat moment = cpMomentForPoly(mass, (int)localVerts.size(), localVerts.data(), cpvzero, 0.0f);

        cpBody* body = cpSpaceAddBody(space, cpBodyNew(mass, moment));
        cpBodySetPosition(body, centroid);

        cpShape* piece = cpSpaceAddShape(space, cpPolyShapeNew(body, (int)localVerts.size(), localVerts.data(), cpTransformIdentity, 0.0f));

        // Copy material/filter/collision type from src
        cpShapeSetElasticity(piece, cpShapeGetElasticity(src));
        cpShapeSetFriction(piece,    cpShapeGetFriction(src));
        cpShapeSetFilter(piece,      cpShapeGetFilter(src));
        cpShapeSetCollisionType(piece, cpShapeGetCollisionType(src));

        // OPTIONAL: set user data so ECS can track this new shape -> entity
        // cpShapeSetUserData(piece, (void*)(uintptr_t)newEntity);

        return body;
    }

    // Slice a convex poly shape by line (A->B). Returns true if replaced by 2+ pieces.
    static bool slicePolyShape(cpSpace* space, cpShape* shape, cpVect A, cpVect B, float density = 1.0f/10000.0f, float minArea = 1.0f) {
        if (!shape || shape->type != CP_POLY_SHAPE) return false;

        cpBody* srcBody = cpShapeGetBody(shape);

        // Build world-space polygon of the original.
        std::vector<cpVect> worldPoly;
        polyBodyLocalToWorld(srcBody, shape, worldPoly);

        // Clip against the two half-spaces (keep-left and keep-right).
        std::vector<cpVect> left, tmp, right;
        clipHalfSpace(worldPoly, left, A, B);      // keep left
        clipHalfSpace(worldPoly, tmp,  B, A);      // keep right: flip line
        right.swap(tmp);

        auto valid = [&](const std::vector<cpVect>& poly) {
            if (poly.size() < 3) return false;
            cpFloat area = cpAreaForPoly((int)poly.size(), poly.data(), 0.0f);
            return area > minArea;
        };

        bool madeAny = false;
        if (valid(left))  { makePieceFromWorldPoly(space, left,  shape, density);  madeAny = true; }
        if (valid(right)) { makePieceFromWorldPoly(space, right, shape, density);  madeAny = true; }

        if (madeAny) {
            // Remove and free original
            cpSpaceRemoveShape(space, shape);
            cpBody* body = cpShapeGetBody(shape);
            cpSpaceRemoveBody(space, body);
            cpShapeFree(shape);
            cpBodyFree(body);
        }

        return madeAny;
    }

    
/* ---------------------------- from shatter demo --------------------------- */


    // tune as you like
    constexpr int  kMaxVoronoiVerts = 16;
    constexpr float kDensity = 1.0f/10000.0f;

    static inline cpVect HashVect(uint32_t x, uint32_t y, uint32_t seed) {
        const float border = 0.05f;
        uint32_t h = (x*1640531513u ^ y*2654435789u) + seed;
        float hx = static_cast<float>( h        & 0xFFFF) / 65535.0f;
        float hy = static_cast<float>((h >> 16) & 0xFFFF) / 65535.0f;
        return cpv(
            cpflerp(border, 1.0f - border, hx),
            cpflerp(border, 1.0f - border, hy)
        );
    }

    struct WorleyCtx {
        uint32_t seed;
        float cellSize;
        int w, h;
        cpBB bb;
    };

    static inline cpVect WorleyPoint(int i, int j, const WorleyCtx& ctx) {
        cpVect fv = HashVect(i, j, ctx.seed);
        float cx = 0.5f*(ctx.bb.l + ctx.bb.r);
        float cy = 0.5f*(ctx.bb.b + ctx.bb.t);
        return cpv(
            cx + ctx.cellSize*(i + fv.x - ctx.w*0.5f),
            cy + ctx.cellSize*(j + fv.y - ctx.h*0.5f)
        );
    }

    // Clip polygon verts by perpendicular bisector between 'center' and Worley cell (i,j).
    static int ClipCell(const cpShape* srcShape,
                        cpVect center, int i, int j,
                        const WorleyCtx& ctx,
                        const cpVect* verts, int count,
                        cpVect* out)
    {
        cpVect other = WorleyPoint(i, j, ctx);

        // If the other site falls *outside* the source shape, this half-space can’t cut anything;
        // just pass-through.
        if (cpShapePointQuery(srcShape, other, nullptr) > 0.0f) {
            std::memcpy(out, verts, count*sizeof(cpVect));
            return count;
        }

        cpVect n = cpvsub(other, center);                   // normal of bisector half-space
        float dist = cpvdot(n, cpvlerp(center, other, 0.5f)); // point-plane offset

        int outCount = 0;
        for (int j2 = 0, i2 = count-1; j2 < count; i2 = j2, ++j2) {
            cpVect a = verts[i2];
            cpVect b = verts[j2];
            float ad = cpvdot(a, n) - dist;
            float bd = cpvdot(b, n) - dist;

            if (ad <= 0.0f) out[outCount++] = a;
            if (ad * bd < 0.0f) {
                float t = std::fabs(ad) / (std::fabs(ad) + std::fabs(bd));
                out[outCount++] = cpvlerp(a, b, t);
            }
        }
        return outCount;
    }
    
/* ---------------------------- query hit result ---------------------------- */
    struct SegmentQueryHit {
        bool        hit = false;
        const cpShape*    shape = nullptr;
        cpVect      point = cpvzero;   // impact point
        cpVect      normal = cpvzero;  // surface normal at impact
        float       alpha = 1.0f;      // fraction along the ray [0..1]
        };

        struct NearestPointHit {
        bool        hit = false;
        const cpShape*    shape = nullptr;
        cpVect      point = cpvzero;   // closest point on shape
        float       distance = INFINITY; // signed: <0 means the query point is inside
        };
/* -------------------------------- tank demo ------------------------------- */

struct TankController {
  cpBody* body{nullptr};          // the dynamic tank body you drive
  cpBody* control{nullptr};       // kinematic control body
  cpConstraint* pivot{nullptr};   // control ↔ body pivot
  cpConstraint* gear{nullptr};    // control ↔ body gear
  float driveSpeed = 30.0f;       // world units/sec along facing
  float stopRadius = 30.0f;       // stop when within this of target
  float gearMaxBias = 1.2f;       // limit angular correction rate
  float gearMaxForce = 50000.0f;  // angular “friction” strength
  float pivotMaxForce = 10000.0f; // linear “friction” strength
  cpVect target{cpvzero};         // steering target in world space
  bool  hasTarget = false;
};

    
/* ---------------------------- one way platform ---------------------------- */
    
    struct OneWayPlatformData {
        cpVect n;   // direction objects are allowed to pass through (platform’s “top”)
    };

    
/* ------------------------------ crane physics ----------------------------- */
    struct CraneState {
    cpBody* dollyBody{nullptr};
    cpBody* hookBody{nullptr};
    cpConstraint* dollyServo{nullptr};   // cpPivotJoint
    cpConstraint* winchServo{nullptr};   // cpSlideJoint
    cpConstraint* hookJoint{nullptr};    // cpPivotJoint (temporary attach)
    cpCollisionType HOOK_SENSOR{0}, CRATE{0};
    };

    
/* ---------------------------- breakable joints ---------------------------- */
    
    struct CrushMetrics { float crush; int touchingCount; };
    
    struct BreakableJointData {
        cpFloat  maxForce;      // also set on the constraint
        cpFloat  triggerRatio;  // break when force > triggerRatio * maxForce (e.g. 0.9)
        cpBool   useFatigue;    // accumulate stress over time
        cpFloat  fatigue;       // 0..1
        cpFloat  fatigueRate;   // how fast fatigue accumulates per normalized stress per second
    };
    
    
    struct FluidConfig {
        float density;
        float drag;
    };
    
    // ---- utilities ----
    static inline void BJ_Detach(cpConstraint* c) {
        if (!c) return;
        if (auto* d = static_cast<BreakableJointData*>(cpConstraintGetUserData(c))) {
            cpfree(d);
            cpConstraintSetUserData(c, nullptr);
        }
    }

    static void BJ_PostStepRemove(cpSpace* space, cpConstraint* joint, void*) {
        BJ_Detach(joint);
        cpSpaceRemoveConstraint(space, joint);
        cpConstraintFree(joint);
    }

    // The actual breaking logic – hook this with cpConstraintSetPostSolveFunc(...)
    static void BJ_PostSolve(cpConstraint* joint, cpSpace* space) {
        auto* d = static_cast<BreakableJointData*>(cpConstraintGetUserData(joint));
        if (!d) return;

        const cpFloat dt    = cpSpaceGetCurrentTimeStep(space);
        const cpFloat J     = cpConstraintGetImpulse(joint);  // N*s
        const cpFloat force = (dt > 0.0f) ? (J / dt) : 0.0f;  // N

        cpBool shouldBreak = (force > d->triggerRatio * d->maxForce);

        if (d->useFatigue && dt > 0.0f && d->maxForce > 0.0f) {
            // accumulate normalized stress
            d->fatigue += d->fatigueRate * (force / d->maxForce) * dt;
            if (d->fatigue >= 1.0f) shouldBreak = cpTrue;
        }

        if (shouldBreak) {
            cpSpaceAddPostStepCallback(space, (cpPostStepFunc)BJ_PostStepRemove, joint, nullptr);
        }
    }

    // Attach to any constraint you already created/added.
    static inline void BJ_Attach(cpConstraint* joint,
                                cpFloat maxForce,
                                cpFloat triggerRatio = 0.9f,
                                cpBool  useFatigue   = cpFalse,
                                cpFloat fatigueRate  = 0.25f)
    {
        auto* d = (BreakableJointData*)cpcalloc(1, sizeof(BreakableJointData));
        d->maxForce     = maxForce;
        d->triggerRatio = triggerRatio;
        d->useFatigue   = useFatigue;
        d->fatigue      = 0.0f;
        d->fatigueRate  = (fatigueRate > 0.0f) ? fatigueRate : 0.0f;

        cpConstraintSetUserData(joint, d);
        cpConstraintSetMaxForce(joint, maxForce);
        cpConstraintSetPostSolveFunc(joint, BJ_PostSolve);
    }
/* -------------------------- end breakable joints -------------------------- */


/**
* @brief Scale factor: number of pixels that correspond to one Chipmunk unit.
*
* @details
* - If you want 100 pixels to equal 1 physics‐unit, set this to 100.0f.
/// - Default is 1.0f (1px == 1 unit).
*/
constexpr float PIXELS_PER_PIXEL_UNIT = 1.0f;

constexpr std::string DEFAULT_COLLISION_TAG = "WORLD";

/**
 * @brief Convert a Raylib world‐space point (pixels, Y‐down) to Chipmunk
 * physics‐space (units, Y‐up).
 *
 * @param world
 *   A position in Raylib world‐space (in pixels), *after* applying your
 * camera’s screen→world transform: Vector2 world =
 * GetScreenToWorld2D(screenPos, camera);
 *
 * @return
 *   The corresponding cpVect in Chipmunk physics‐space (in units), with Y
 * flipped.
 */
inline cpVect raylibToChipmunkCoords(const Vector2 &world) {
  return cpv(world.x / PIXELS_PER_PIXEL_UNIT,
             -world.y / PIXELS_PER_PIXEL_UNIT // flip Y‐axis
  );
}

/**
 * @brief Convert a Chipmunk physics‐space point (units, Y‐down) back to Raylib
 * world‐space (pixels, Y‐down).
 *
 * @param p
 *   A position in Chipmunk physics‐space (in units).
 *
 * @return
 *   The corresponding Vector2 in Raylib world‐space (in pixels), ready for
 * Camera2D world→screen: Vector2 screenPos = GetWorldToScreen2D(worldPos,
 * camera);
 */
inline Vector2 chipmunkToRaylibCoords(const cpVect &p) {
  return {
      (float)p.x * PIXELS_PER_PIXEL_UNIT,
      (float)p.y * PIXELS_PER_PIXEL_UNIT // flip Y back
  };
}

// ----------------------------------------------------------------------------
// debug drawing functions: these are called by cpSpaceDebugDraw() to render the
// physics objects when debugging
// ----------------------------------------------------------------------------
static cpSpaceDebugColor Colors[] = {
    {0xb5 / 255.0f, 0x89 / 255.0f, 0x00 / 255.0f, 1.0f},
    {0xcb / 255.0f, 0x4b / 255.0f, 0x16 / 255.0f, 1.0f},
    {0xdc / 255.0f, 0x32 / 255.0f, 0x2f / 255.0f, 1.0f},
    {0xd3 / 255.0f, 0x36 / 255.0f, 0x82 / 255.0f, 1.0f},
    {0x6c / 255.0f, 0x71 / 255.0f, 0xc4 / 255.0f, 1.0f},
    {0x26 / 255.0f, 0x8b / 255.0f, 0xd2 / 255.0f, 1.0f},
    {0x2a / 255.0f, 0xa1 / 255.0f, 0x98 / 255.0f, 1.0f},
    {0x85 / 255.0f, 0x99 / 255.0f, 0x00 / 255.0f, 1.0f},
};

// Draw a circle
inline static void DrawCircle(cpVect p, cpFloat a, cpFloat r,
                              cpSpaceDebugColor outline, cpSpaceDebugColor fill,
                              cpDataPointer data) {
  Color outlineColor = (Color){
      (unsigned char)(outline.r * 255), (unsigned char)(outline.g * 255),
      (unsigned char)(outline.b * 255), (unsigned char)(outline.a * 255)};
  Color fillColor =
      (Color){(unsigned char)(fill.r * 255), (unsigned char)(fill.g * 255),
              (unsigned char)(fill.b * 255), (unsigned char)(fill.a * 255)};

  DrawCircle((int)p.x, (int)p.y, (float)r, fillColor);
  DrawCircleLines((int)p.x, (int)p.y, (float)r, outlineColor);
}

// Draw a line segment
inline static void DrawSegment(cpVect a, cpVect b, cpSpaceDebugColor color,
                               cpDataPointer data) {
  Color lineColor =
      (Color){(unsigned char)(color.r * 255), (unsigned char)(color.g * 255),
              (unsigned char)(color.b * 255), (unsigned char)(color.a * 255)};
  DrawLine((int)a.x, (int)a.y, (int)b.x, (int)b.y, lineColor);
}

// Draw a thick line segment (fat segment)
inline static void DrawFatSegment(cpVect a, cpVect b, cpFloat r,
                                  cpSpaceDebugColor outline,
                                  cpSpaceDebugColor fill, cpDataPointer data) {
  Color outlineColor = (Color){
      (unsigned char)(outline.r * 255), (unsigned char)(outline.g * 255),
      (unsigned char)(outline.b * 255), (unsigned char)(outline.a * 255)};
  Color fillColor =
      (Color){(unsigned char)(fill.r * 255), (unsigned char)(fill.g * 255),
              (unsigned char)(fill.b * 255), (unsigned char)(fill.a * 255)};

  DrawLineEx((Vector2){(float)a.x, (float)a.y},
             (Vector2){(float)b.x, (float)b.y}, (float)(2 * r), fillColor);
  DrawLine((int)a.x, (int)a.y, (int)b.x, (int)b.y, outlineColor);
}

// Draw a polygon
inline static void DrawPolygon(int count, const cpVect *verts, cpFloat r,
                               cpSpaceDebugColor outline,
                               cpSpaceDebugColor fill, cpDataPointer data) {
  Color outlineColor = (Color){
      (unsigned char)(outline.r * 255), (unsigned char)(outline.g * 255),
      (unsigned char)(outline.b * 255), (unsigned char)(outline.a * 255)};
  Color fillColor =
      (Color){(unsigned char)(fill.r * 255), (unsigned char)(fill.g * 255),
              (unsigned char)(fill.b * 255), (unsigned char)(fill.a * 255)};

  for (int i = 0; i < count; i++) {
    Vector2 start = {(float)verts[i].x, (float)verts[i].y};
    Vector2 end = {(float)verts[(i + 1) % count].x,
                   (float)verts[(i + 1) % count].y};
    DrawLineEx(start, end, 2.0f, outlineColor); // Draw outline
  }

  for (int i = 0; i < count; i++) {
    Vector2 vertex = {(float)verts[i].x, (float)verts[i].y};
    DrawCircleV(vertex, (float)r, fillColor); // Draw vertex circles for effect
  }
}

// Draw a dot
inline static void DrawDot(cpFloat size, cpVect pos, cpSpaceDebugColor color,
                           cpDataPointer data) {
  Color dotColor =
      (Color){(unsigned char)(color.r * 255), (unsigned char)(color.g * 255),
              (unsigned char)(color.b * 255), (unsigned char)(color.a * 255)};
  DrawCircle((int)pos.x, (int)pos.y, (float)size, dotColor);
}

static inline cpSpaceDebugColor LAColor(float l, float a) {
  cpSpaceDebugColor color = {l, l, l, a};
  return color;
}

static inline cpSpaceDebugColor RGBAColor(float r, float g, float b, float a) {
  cpSpaceDebugColor color = {r, g, b, a};
  return color;
}

inline static cpSpaceDebugColor ColorForShape(cpShape *shape,
                                              cpDataPointer data) {
  if (!shape) {
    return LAColor(0.9f, 1.0f);
  } 
  
  if (cpShapeGetSensor(shape)) {
    return LAColor(1.0f, 0.1f);
  } else {
    cpBody *body = cpShapeGetBody(shape);
    
    if (!body) {
      return LAColor(0.7f, 1.0f);
    } 

    if (cpBodyIsSleeping(body)) {
      return RGBAColor(0x58 / 255.0f, 0x6e / 255.0f, 0x75 / 255.0f, 1.0f);
    } else if (body->sleeping.idleTime > shape->space->sleepTimeThreshold) {
      return RGBAColor(0x93 / 255.0f, 0xa1 / 255.0f, 0xa1 / 255.0f, 1.0f);
    } else {
      uint32_t val = (uint32_t)shape->hashid;

      // scramble the bits up using Robert Jenkins' 32 bit integer hash function
      val = (val + 0x7ed55d16) + (val << 12);
      val = (val ^ 0xc761c23c) ^ (val >> 19);
      val = (val + 0x165667b1) + (val << 5);
      val = (val + 0xd3a2646c) ^ (val << 9);
      val = (val + 0xfd7046c5) + (val << 3);
      val = (val ^ 0xb55a4f09) ^ (val >> 16);
      return Colors[val & 0x7];
    }
  }
}

// Call this function to draw the physics objects for a cpSpace when debugging.
// NOTE: if using a camera, call this function after beginMode2D(camera)
inline static void ChipmunkDemoDefaultDrawImpl(cpSpace *space) {

  cpSpaceDebugDrawOptions drawOptions = {
      DrawCircle,
      DrawSegment,
      DrawFatSegment,
      DrawPolygon,
      DrawDot,
      (cpSpaceDebugDrawFlags)(CP_SPACE_DEBUG_DRAW_SHAPES |
                              CP_SPACE_DEBUG_DRAW_CONSTRAINTS |
                              CP_SPACE_DEBUG_DRAW_COLLISION_POINTS),
      {0xEE / 255.0f, 0xE8 / 255.0f, 0xD5 / 255.0f, 1.0f}, // Outline color
      ColorForShape,
      {0.0f, 0.75f, 0.0f, 1.0f}, // Constraint color
      {1.0f, 0.0f, 0.0f, 1.0f},  // Collision point color
      NULL,
  };

  cpSpaceDebugDraw(space, &drawOptions);
  
  
}

// ----------------------------------------------------------------------------
// Utility functions
// ----------------------------------------------------------------------------

// Helper function to create shared_ptr for cpSpace
extern std::shared_ptr<cpSpace> MakeSharedSpace();

// Helper function to create shared_ptr for cpBody
extern std::shared_ptr<cpBody> MakeSharedBody(cpFloat mass, cpFloat moment);

// Helper function to create shared_ptr for cpShape
extern std::shared_ptr<cpShape> MakeSharedShape(cpBody *body, cpFloat width,
                                                cpFloat height);

extern entt::entity GetEntityFromBody(cpBody *body);

extern void SetEntityToShape(cpShape *shape, entt::entity entity);

extern void SetEntityToBody(cpBody *body, entt::entity entity);
// ----------------------------------------------------------------------------
// Data structures
// ----------------------------------------------------------------------------

enum class ColliderShapeType { Rectangle, Segment, Circle, Polygon, Chain };

// A structure to represent collision events.
struct CollisionEvent {
  void *objectA;
  void *objectB;
  float x1, y1, x2, y2, nx, ny;
};

struct ColliderComponent {
  std::shared_ptr<cpBody> body;   // Pointer to the Chipmunk body
  std::shared_ptr<cpShape> shape; // Pointer to the Chipmunk shape
  bool isSensor = false;          // True if the collider is a sensor
  bool isDynamic = true;          // Indicates whether the body is dynamic
  bool debugDraw = true;          // Flag to enable/disable rendering
  ColliderShapeType shapeType;    // Type of collider shape
  std::vector<CollisionEvent> collisionEnter;  // Physical collision start
  std::vector<CollisionEvent> collisionActive; // Physical collision active
  std::vector<CollisionEvent> collisionExit;   // Physical collision end
  std::vector<void *> triggerEnter;  // Trigger (collision with sensor) start
  std::vector<void *> triggerActive; // Trigger (collision with sensor) active
  std::vector<void *> triggerExit;   // Trigger end
  std::string tag = "default";       // Collision tag for filtering

  ColliderComponent(std::shared_ptr<cpBody> body,
                    std::shared_ptr<cpShape> shape, const std::string &tag,
                    bool sensor = false,
                    ColliderShapeType shapeType = ColliderShapeType::Rectangle)
      : body(std::move(body)), shape(std::move(shape)), isSensor(sensor),
        shapeType(shapeType) {}

  // NEW: extra shapes in the same body
  struct SubShape {
    std::shared_ptr<cpShape> shape;
    ColliderShapeType type;
    std::string tag;
    bool isSensor = false;
  };
  std::vector<SubShape> extraShapes;
};

struct CollisionTag {
  int category;              // Collision category ID
  std::vector<int> masks;    // Categories this tag can collide with
  std::vector<int> triggers; // Categories this tag can trigger with
};

struct RaycastHit {
  cpShape *shape;
  float fraction; // Intersection fraction (0.0 to 1.0)
  cpVect normal;  // Surface normal at the intersection point
  cpVect point;   // Intersection point
};

// ----------------------------------------------------------------------------
// PhysicsWorld Class
// ----------------------------------------------------------------------------

// A small node for our union-find structure.
struct UFNode {
  UFNode *parent; // If this points to itself, it’s a root.
  int count;      // Only accurate on root nodes.
};

class PhysicsWorld {
public:
  // General Members
  entt::registry *registry;
  cpSpace *space;
  float meter; // REVIEW: unused
  // Internal state for mouse dragging
  cpBody *mouseBody = nullptr;        // a static body to attach the mouse joint
  cpConstraint *mouseJoint = nullptr; // the active pivot joint
  entt::entity draggedEntity = entt::null; // which entity is being dragged
  cpBody *controlBody = nullptr;           // for your player/controller joint
  // TODO: isolate the above into the collision component later

  /**
   * ===== Example Usage for union find feature (think detection for touching
   * balls of same color for X balls, etc.) =====
   *
   *  1) Create your PhysicsWorld as usual:
   * PhysicsWorld world;
   *
   *  2) Enable grouping on collision types 1 through 6,
   *     so that whenever 4 or more like-typed bodies connect via collisions,
   *     your callback is invoked once (with the “root” body of that set).
   * world.EnableCollisionGrouping(
   *     minType     1,
   *      maxType     6,
   *     threshold   4,
   *     onRemoved   [](cpBody* groupRoot){
   *          Called once per set of ≥4 bodies.
   *          E.g. remove them, play effects, etc.
   *         RemoveBodyAndChildren(groupRoot);
   *     }
   * );
   *
   *  3) In your main loop:
   * float  dt = GetDeltaTime();
   * world.Step(dt);  // steps physics and then processes grouping
   */

  // Collision Event Maps
  std::unordered_map<std::string, std::vector<CollisionEvent>> collisionEnter;
  std::unordered_map<std::string, std::vector<CollisionEvent>> collisionActive;
  std::unordered_map<std::string, std::vector<CollisionEvent>> collisionExit;

  // Trigger Event Maps
  std::unordered_map<std::string, std::vector<void *>> triggerEnter;
  std::unordered_map<std::string, std::vector<void *>> triggerActive;
  std::unordered_map<std::string, std::vector<void *>> triggerExit;

  // Collision and Tag Management
  std::unordered_map<std::string, CollisionTag> collisionTags;
  std::unordered_map<std::string, CollisionTag> triggerTags;
  std::unordered_map<int, std::string> categoryToTag;

  // Constructors and Destructors
  PhysicsWorld(entt::registry *registry, float meter = 64.0f,
               float gravityX = 0.0f, float gravityY = 0.0f);
  ~PhysicsWorld();

  // Update and Post-Update
  void Update(float deltaTime);
  void PostUpdate();
  
  
/* -------------------------- weights and crushing -------------------------- */


    // After a step in the same frame (impulses are valid only then)
    cpVect SumImpulsesForBody(cpBody* body);
    float TotalForceOn(entt::entity e, float dt) ;
    float WeightOn(entt::entity e, float dt) ;
    CrushMetrics CrushOn(entt::entity e, float dt) ;
    std::vector<entt::entity> TouchingEntities(entt::entity e);


/* -------------------------------- tank demo ------------------------------- */

    // entity -> controller
    std::unordered_map<entt::entity, TankController> _tanks;
    
    
void EnableTankController(entt::entity e,
                                        float driveSpeed /*=30.f*/,
                                        float stopRadius /*=30.f*/,
                                        float pivotMaxForce /*=10000.f*/,
                                        float gearMaxForce  /*=50000.f*/,
                                        float gearMaxBias   /*=1.2f*/);
void CommandTankTo(entt::entity e, cpVect targetWorld);

void UpdateTanks(double dt);

void AttachFrictionJoints(cpBody* body,
                                        cpFloat linearMax = 1000.f,
                                        cpFloat angularMax = 5000.f);

    
/* -------------------------- constraints & joints -------------------------- */

// Resolve (entity,shapeIndex) -> cpBody*
cpBody* BodyOf(entt::entity e) ;

// Pin joint
cpConstraint* AddPinJoint(entt::entity ea, cpVect aLocal, entt::entity eb, cpVect bLocal);

// Slide joint
cpConstraint* AddSlideJoint(entt::entity ea, cpVect aLocal, entt::entity eb, cpVect bLocal, cpFloat minD, cpFloat maxD);

// Pivot joint (world anchor)
cpConstraint* AddPivotJointWorld(entt::entity ea, entt::entity eb, cpVect worldAnchor);
// Groove joint (A provides groove, in A's local space)
cpConstraint* AddGrooveJoint(entt::entity a, cpVect a1Local, cpVect a2Local, entt::entity b, cpVect bLocal);

// Springs
cpConstraint* AddDampedSpring(entt::entity ea, cpVect aLocal, entt::entity eb, cpVect bLocal, cpFloat rest, cpFloat k, cpFloat damp);
cpConstraint* AddDampedRotarySpring(entt::entity ea, entt::entity eb, cpFloat restAngle, cpFloat k, cpFloat damp);
// Angular joints
cpConstraint* AddRotaryLimit(entt::entity ea, entt::entity eb, cpFloat minAngle, cpFloat maxAngle) ;
cpConstraint* AddRatchet(entt::entity ea, entt::entity eb, cpFloat phase, cpFloat ratchet);
cpConstraint* AddGear(entt::entity ea, entt::entity eb, cpFloat phase, cpFloat ratio);
cpConstraint* AddSimpleMotor(entt::entity ea, entt::entity eb, cpFloat rateRadPerSec) ;
// Convenience tuning
void SetConstraintLimits(cpConstraint* c, cpFloat maxForce, cpFloat maxBias);

/* ---------------------------- from sticky demo ---------------------------- */


// enable sticky glue between two tags (pair-specific)
void EnableStickyBetween(const std::string& tagA,
                         const std::string& tagB,
                         cpFloat impulseThreshold,
                         cpFloat maxForce);

// (optional) disable again
void DisableStickyBetween(const std::string& tagA,
                          const std::string& tagB);

  // pair key (collision type A,B) → config
  std::unordered_map<uint64_t, StickyConfig> _stickyByPair;

  // body-pair key → list of joints created by sticky
  struct BodyPairKey {
    cpBody* a; cpBody* b;
    bool operator==(const BodyPairKey& o) const { return a==o.a && b==o.b; }
  };
  struct BodyPairKeyHash {
    size_t operator()(const BodyPairKey& k) const {
      auto lo = std::min(k.a,k.b), hi = std::max(k.a,k.b);
      // order-insensitive hash
      return std::hash<uintptr_t>()(reinterpret_cast<uintptr_t>(lo)) ^
             (std::hash<uintptr_t>()(reinterpret_cast<uintptr_t>(hi))<<1);
    }
  };
  std::unordered_map<BodyPairKey, std::vector<cpConstraint*>, BodyPairKeyHash> _stickyJoints;

  // helpers
  static BodyPairKey MakeBodyPair(cpBody* a, cpBody* b) {
    if (a>b) std::swap(a,b);
    return BodyPairKey{a,b};
  }

  // Chipmunk callbacks for sticky pair
  static cpBool C_StickyBegin(cpArbiter*, cpSpace*, void*);
  static void   C_StickySeparate(cpArbiter*, cpSpace*, void*);
  static void   C_StickyPostSolve(cpArbiter*, cpSpace*, void*);

  // instance methods called by the C_… thunks
  cpBool StickyBegin(cpArbiter* arb);
  void   StickyPostSolve(cpArbiter* arb);
  void   StickySeparate(cpArbiter* arb);

  void   InstallStickyPairHandler(cpCollisionType ta, cpCollisionType tb);


/* ------------------------ convex hull modification ------------------------ */
bool ConvexAddPoint(entt::entity e, cpVect worldPoint, float tolerance /*=2.0f*/);

  // Collision Management
  void OnCollisionBegin(cpArbiter *arb);
  void OnCollisionEnd(cpArbiter *arb);
  void EnableCollisionBetween(const std::string &tag1,
                              const std::vector<std::string> &tags);
  void DisableCollisionBetween(const std::string &tag1,
                               const std::vector<std::string> &tags);
  void EnableTriggerBetween(const std::string &tag1,
                            const std::vector<std::string> &tags);
  void DisableTriggerBetween(const std::string &tag1,
                             const std::vector<std::string> &tags);
  void EnsureWildcardInstalled(cpCollisionType t);
  void EnsurePairInstalled(cpCollisionType ta, cpCollisionType tb);
  // Pair registration
  void RegisterPairPreSolve(const std::string &a, const std::string &b,
                            sol::protected_function fn);
  void RegisterPairPostSolve(const std::string &a, const std::string &b,
                             sol::protected_function fn);
  // Wildcard registration (per-tag)
  void RegisterWildcardPreSolve(const std::string &tag,
                                sol::protected_function fn);
  void RegisterWildcardPostSolve(const std::string &tag,
                                 sol::protected_function fn);
  // Optional unregistration helpers if you want:
  void ClearPairHandlers(const std::string &a, const std::string &b);
  void ClearWildcardHandlers(const std::string &tag);

  // Collision Tag Management
  std::string GetTagFromCategory(int category);
  void AddCollisionTag(const std::string &tag);
  void RemoveCollisionTag(const std::string &tag);
  void UpdateCollisionMasks(const std::string &tag,
                            const std::vector<std::string> &collidableTags);
  void SetCollisionTags(const std::vector<std::string> &tags);
  void ApplyCollisionFilter(cpShape *shape, const std::string &tag);
  void UpdateColliderTag(entt::entity entity, const std::string &newTag);
  void InstallWildcardCollisionHandlers();
  void RegisterExclusivePairCollisionHandler(const std::string &tagA,
                                             const std::string &tagB);

  // -------- Local fallback (no world available) --------
  static void DetachPhysicsComponentFallback(entt::registry &R,
                                             entt::entity e) {
    using namespace physics;
    auto *cc = R.try_get<ColliderComponent>(e);
    if (!cc)
      return;

    if (auto *s = cc->shape.get()) {
      if (auto *sp = cpShapeGetSpace(s))
        cpSpaceRemoveShape(sp, s);
      cpShapeSetUserData(s, nullptr);
    }
    if (auto *b = cc->body.get()) {
      if (auto *sp = cpBodyGetSpace(b))
        cpSpaceRemoveBody(sp, b);
      cpBodySetUserData(b, nullptr);
    }

    R.remove<ColliderComponent>(e);
  }

  void DetachPhysicsComponent(entt::entity e) {
    auto &cc = registry->get<physics::ColliderComponent>(e);
    if (auto *s = cc.shape.get())
      if (auto *sp = cpShapeGetSpace(s))
        cpSpaceRemoveShape(sp, s);
    if (auto *b = cc.body.get())
      if (auto *sp = cpBodyGetSpace(b))
        cpSpaceRemoveBody(sp, b);
    cpShapeSetUserData(cc.shape.get(), nullptr);
    cpBodySetUserData(cc.body.get(), nullptr);
    registry->remove<physics::ColliderComponent>(e);
  }

  // Utility Functions
  
  
  
  cpConstraint* MakeBreakableSlideJoint(cpBody* a, cpBody* b,
        cpVect anchorA, cpVect anchorB, cpFloat minDist, cpFloat maxDist,
        cpFloat breakingForce, cpFloat triggerRatio = 0.9f,
        bool collideBodies = false, bool useFatigue = false, cpFloat fatigueRate = 0.25f);

void MakeConstraintBreakable(cpConstraint* c,
    cpFloat breakingForce, cpFloat triggerRatio = 0.9f,
    bool useFatigue = false, cpFloat fatigueRate = 0.25f);
  
  /**
   * Enable union-find grouping on collisions.
   *
   * @param minType      The lowest collisionType to watch.
   * @param maxType      The highest collisionType to watch.
   * @param threshold    How many bodies in one set before firing
   * onGroupRemoved.
   * @param onGroupRemoved
   *        A function called once per root body when its set size ≥ threshold.
   */
  void EnableCollisionGrouping(cpCollisionType minType, cpCollisionType maxType,
                               int threshold,
                               std::function<void(cpBody *)> onGroupRemoved);
  void AddScreenBounds(float xMin, float yMin, float xMax, float yMax,
                       float thickness = 1.0f,
                       const std::string &collisionTag = DEFAULT_COLLISION_TAG);
  void CreateTilemapColliders(const std::vector<std::vector<bool>> &collidable,
                              float tileSize, float segmentRadius = 1.0f);
  void CreateTopDownController(entt::entity entity, float maxBias = 200.0f,
                               float maxForce = 3000.0f);
  void AddUprightSpring(entt::entity e, float stiffness = 100.0f,
                        float damping = 10.0f);
                        
/* --------------------------------- queries -------------------------------- */
                        
  entt::entity PointQuery(float x, float y);
  
    SegmentQueryHit SegmentQueryFirst(cpVect start, cpVect end, float radius = 10.0f,
                                                    cpShapeFilter filter = CP_SHAPE_FILTER_ALL) const;
    NearestPointHit PointQueryNearest(cpVect p, float maxDistance = 100.0f,
                                                    cpShapeFilter filter = CP_SHAPE_FILTER_ALL) const;
  /// Teleport an entity's body to (x,y).
  void SetBodyPosition(entt::entity e, float x,
                       float y); /// Directly set an entity's linear velocity.
  void SetBodyVelocity(entt::entity e, float vx, float vy);
  /// Begin dragging the body under (x,y) with a pivot joint.
  void StartMouseDrag(float x, float y);
  /// Update the drag target to follow (x,y).
  void UpdateMouseDrag(float x, float y);
  /// End the current mouse drag.
  void EndMouseDrag();
  const std::vector<CollisionEvent> &
  GetCollisionEnter(const std::string &type1, const std::string &type2);
  const std::vector<void *> &GetTriggerEnter(const std::string &type1,
                                             const std::string &type2);
  std::vector<RaycastHit> Raycast(float x1, float y1, float x2, float y2);
  std::vector<void *> GetObjectsInArea(float x1, float y1, float x2, float y2);
  void SetGravity(float gravityX, float gravityY);
  void SetMeter(float meter);
  size_t GetShapeCount(entt::entity e) const;
  cpBB GetShapeBB(entt::entity e, size_t index) const;
  
/* ---------------------------- from shatter demo --------------------------- */

void ShatterShape(cpShape* shape, float cellSize, cpVect focus);
bool ShatterNearest(float x, float y, float gridDiv /*=5.0f*/);

/* ----------------------------- from slice demo ---------------------------- */



  
/* ---------------------------- from planet demo ---------------------------- */

struct GravityField {
  enum class Mode { None, InverseSquareToPoint, InverseSquareToBody };
  Mode mode{Mode::None};
  cpFloat GM{0};          // ‘gravityStrength’ in the demo
  cpVect point{0,0};      // static center (if used)
  cpBody* centerBody{nullptr}; // dynamic center (optional)
};

std::unordered_map<cpBody*, GravityField> _gravityByBody;

static void C_VelocityUpdate(cpBody* body, cpVect gravity, cpFloat damping, cpFloat dt);
void OnVelocityUpdate(cpBody* body, cpVect gravity, cpFloat damping, cpFloat dt);
  
// Toward a fixed point
void EnableInverseSquareGravityToPoint(entt::entity e, cpVect point, cpFloat GM);
void EnableInverseSquareGravityToBody(entt::entity e, entt::entity center, cpFloat GM);
void DisableCustomGravity(entt::entity e);

entt::entity CreatePlanet(cpFloat radius, cpFloat spinRadiansPerSec,
                                        const std::string& tag /*= "planet"*/,
                                        cpVect pos /*= {0,0}*/);

entt::entity SpawnOrbitingBox(cpVect startPos, cpFloat halfSize,
                                            cpFloat mass, cpFloat GM,
                                            cpVect gravityCenter /*usually {0,0} or planet pos*/);
                                            
                                            
/* --------------------- from platformer controller demo -------------------- */

struct PlatformerCtrl {
  cpBody*  body{nullptr};
  cpShape* feet{nullptr};
  // Tunables (match the demo defaults)
  float maxVel      = 500.0f;
  float groundAccel = 500.0f / 0.1f;   // PLAYER_VELOCITY / PLAYER_GROUND_ACCEL_TIME
  float airAccel    = 500.0f / 0.25f;  // PLAYER_VELOCITY / PLAYER_AIR_ACCEL_TIME
  float jumpHeight  = 50.0f;
  float jumpBoostH  = 55.0f;
  float fallVel     = 900.0f;
  float gravityY    = 2000.0f;

  // Runtime state
  float remainingBoost = 0.f;
  bool  grounded       = false;
  bool  lastJumpHeld   = false;
  // Input (per-frame)
  float moveX          = 0.f;  // [-1..1]
  bool  jumpHeld       = false;
};

std::unordered_map<entt::entity, PlatformerCtrl> _platformers; // key by entity
std::unordered_map<cpBody*, entt::entity>        _platformerByBody;

static void C_PlayerVelUpdate(cpBody* body, cpVect gravity, cpFloat damping, cpFloat dt);
static void SelectGroundNormal(cpBody* body, cpArbiter* arb, cpVect* outMaxUp);
void PlayerVelUpdate(cpBody* body, cpVect gravity, cpFloat damping, cpFloat dt);
// Create a box "player" with infinite moment (no rotation) and a fat box shape for nice footing.
entt::entity CreatePlatformerPlayer(cpVect pos, float w=30.f, float h=55.f,
                                                  const std::string& tag="player");
// Feed input each frame: moveX in [-1,1], jumpHeld = is jump currently held.
void SetPlatformerInput(entt::entity e, float moveX, bool jumpHeld);


/* ------------------------ from custom springs demo ------------------------ */

// Create a dynamic “bar” made from a fat segment between world points a–b.
// `thickness` is the segment radius; `group` (optional) prevents self-collisions among bars with same non-zero group.
// Returns the new entity.
entt::entity AddBarSegment(cpVect a, cpVect b,
                           float thickness,
                           const std::string& tag,
                           int32_t group = 0);
// Create a damped spring with a custom force function that clamps displacement.
// Force = clamp(restLength - dist, -clamp, +clamp) * stiffness
cpConstraint* AddClampedDampedSpring(cpBody* a, cpBody* b,
                                     cpVect anchorA, cpVect anchorB,
                                     cpFloat restLength,
                                     cpFloat stiffness,
                                     cpFloat damping,
                                     cpFloat clampAbs);

// If you manage constraints’ lifetimes yourself, call this before destroying/removing the constraint to clean userData.
static void FreeSpringUserData(cpConstraint* c);

/* --------------------------- smooth terrain demo -------------------------- */


entt::entity AddSmoothSegmentChain(const std::vector<cpVect>& pts,
                                   float radius,
                                   const std::string& tag);
                            

/* ----------------------------- from slice dmeo ---------------------------- */

bool SliceFirstHit(cpVect A, cpVect B, float density, float minArea);


/* ----------------------- from one way platform demo ----------------------- */
entt::entity AddOneWayPlatform(float x1, float y1,
                                             float x2, float y2,
                                             float thickness,
                                             const std::string& tag /*= "one_way"*/,
                                             cpVect n /*= cpv(0, 1)*/);
                                             
  std::unordered_map<cpCollisionType, OneWayPlatformData> _oneWayByType;
  
  void RegisterOneWayPlatform(const std::string& tag, cpVect allowedDir) {
    cpCollisionType t = TypeForTag(tag);
    _oneWayByType[t] = OneWayPlatformData{ allowedDir };
    EnsureWildcardInstalled(t); // you already have this; installs our pre/post solve shims
}

  
/* -------------------------- from smash logo demo -------------------------- */

    entt::entity SpawnPixelBall(float x, float y, float r = 0.95f);
    
    static inline int get_pixel(int x, int y,
                            const unsigned char* bits,
                            int rowLen /*bytes per row*/) {
        return (bits[(x >> 3) + y * rowLen] >> (~x & 0x7)) & 1;
    }

    void BuildLogoFromBitmap(const unsigned char* bits,
                                        int w, int h, int rowLenBytes,
                                        float pixelWorldScale /*=2.0f*/,
                                        float jitter /*=0.05f*/);





  /* ---------------------------- fluid simulation ----------------------------
   */
  // --- Fluid (sensor-based buoyancy/drag) ---
  auto AddFluidSensorAABB(float left, float bottom, float right, float top,
                          const std::string &tag) -> void;

  auto RegisterFluidVolume(const std::string &tag, float density, float drag)
      -> void;

  auto WaterPreSolveNative(cpArbiter *arb, cpCollisionType waterType) -> void;
  
  static inline float k_scalar_body(cpBody *body, cpVect point, cpVect n) {
    const float rcn = cpvcross(cpvsub(point, cpBodyGetPosition(body)), n);
    return 1.0f / cpBodyGetMass(body) + (rcn * rcn) / cpBodyGetMoment(body);
  }

  // Collider Management
  std::shared_ptr<cpShape> AddShape(cpBody *body, float width, float height,
                                    const std::string &tag);
  void AddShapeToEntity(entt::entity e, const std::string &tag,
                        const std::string &shapeType, float a, float b, float c,
                        float d, bool isSensor,
                        const std::vector<cpVect> &points);
  void AddCollider(entt::entity entity, const std::string &tag,
                   const std::string &shapeType, float a, float b, float c,
                   float d, bool isSensor,
                   const std::vector<cpVect> &points = {});
  bool RemoveShapeAt(entt::entity e, size_t index);
  void ClearAllShapes(entt::entity e);

  cpBool OnPreSolve(cpArbiter *arb);
  void OnPostSolve(cpArbiter *arb);
  void InstallWildcardHandlersForAllTags();

  // Rendering and Debugging
  void DebugDrawContacts() {
    // Walk all bodies and their arbiters; or keep a list of arbiters from your callbacks.
        cpSpaceEachBody(space, +[](cpBody* b, void*){
            cpBodyEachArbiter(b, +[](cpBody* body, cpArbiter* arb, void*){
                cpContactPointSet set = cpArbiterGetContactPointSet(arb);
                for (int i=0; i<set.count; ++i) {
                    const auto& p = set.points[i];
                    // send p.pointA / p.pointB and p.normal to your debug renderer
                    DrawCircleV(
                        {(float)p.pointA.x, (float)p.pointA.y}, 3.0f, BLUE); 
                    // (your renderer likely wants world points)
                }
            }, nullptr);
        }, nullptr);
    }

  void RenderColliders(); // TODO: remove
  void PrintCollisionTags();

  // Movement and Steering Behaviors
  void Seek(entt::entity entity, float targetX, float targetY, float maxSpeed);
  void Arrive(entt::entity entity, float targetX, float targetY, float maxSpeed,
              float slowingRadius);
  void Wander(entt::entity entity, float wanderRadius, float wanderDistance,
              float jitter, float maxSpeed);
  void Separate(entt::entity entity, const std::vector<entt::entity> &others,
                float separationRadius, float maxForce);
  void Align(entt::entity entity, const std::vector<entt::entity> &others,
             float alignRadius, float maxSpeed, float maxForce);
  void Cohesion(entt::entity entity, const std::vector<entt::entity> &others,
                float cohesionRadius, float maxSpeed, float maxForce);
  void RotateTowardObject(entt::entity entity, entt::entity target,
                          float lerpValue);
  void RotateTowardPoint(entt::entity entity, float targetX, float targetY,
                         float lerpValue);
  void RotateTowardMouse(entt::entity entity, float lerpValue);
  void RotateTowardVelocity(entt::entity entity, float lerpValue);

  // Physics Operations
  void ApplyForce(entt::entity entity, float forceX, float forceY);
  void ApplyImpulse(entt::entity entity, float impulseX, float impulseY);
  void SetDamping(entt::entity entity, float damping);
  void SetGlobalDamping(float damping);
  void SetVelocity(entt::entity entity, float velocityX, float velocityY);
  void SetAngularVelocity(entt::entity entity, float angularVelocity);
  void SetAngularDamping(entt::entity entity, float angularDamping);
  void SetRestitution(entt::entity entity, float restitution);
  void SetFriction(entt::entity entity, float friction);
  void ApplyAngularImpulse(entt::entity entity, float angularImpulse);
  void ApplyTorque(entt::entity entity, float torque);
  void SetBullet(entt::entity entity, bool isBullet);
  void SetFixedRotation(entt::entity entity, bool fixedRotation);
  void SetAwake(entt::entity entity, bool awake);
  float GetMass(entt::entity entity);
  void SetMass(entt::entity entity, float mass);

  // Entity Transformations
  cpVect GetPosition(entt::entity entity);
  void SetPosition(entt::entity entity, float x, float y);
  float GetAngle(entt::entity entity);
  void SetAngle(entt::entity entity, float angle);

  // Steering and Movement Controls
  void AccelerateTowardMouse(entt::entity entity, float acceleration,
                             float maxSpeed);
  void AccelerateTowardObject(entt::entity entity, entt::entity target,
                              float acceleration, float maxSpeed);
  void AccelerateTowardAngle(entt::entity entity, float angle,
                             float acceleration, float maxSpeed);
  void AccelerateTowardPoint(entt::entity entity, float targetX, float targetY,
                             float acceleration, float maxSpeed);
  void MoveTowardAngle(entt::entity entity, float angle, float speed);
  void MoveTowardPoint(entt::entity entity, float targetX, float targetY,
                       float speed, float maxTime);
  void MoveTowardMouse(entt::entity entity, float speed, float maxTime);
  void MoveTowardsMouseHorizontally(entt::entity entity, float speed,
                                    float maxTime);
  void MoveTowardsMouseVertically(entt::entity entity, float speed,
                                  float maxTime);
  void LockHorizontally(entt::entity entity);
  void LockVertically(entt::entity entity);

  // Boundary Enforcement
  void EnforceBoundary(entt::entity entity, float minY);

  // Geometry and Body Management
  std::vector<cpVect> GetVertices(entt::entity entity);
  void SetBodyType(entt::entity entity, const std::string &bodyType);

  // helper for mapping string tags to collisionType integers
  cpCollisionType TypeForTag(const std::string &tag) const {
    if (auto it = _tagToCollisionType.find(tag);
        it != _tagToCollisionType.end())
      return it->second;
    // ensure default exists
    if (auto it2 = _tagToCollisionType.find("default");
        it2 != _tagToCollisionType.end())
      return it2->second;
    return 0; // or assert
  }

  /* -------------------- free body / shape usage from lua: -------------------
   */

  // In PhysicsWorld (private):
  uint64_t _nextBodyId = 1;
  std::unordered_map<uint64_t, std::shared_ptr<cpBody>> _bodyHandles;

  // internal helpers
  uint64_t registerBody(std::shared_ptr<cpBody> b) {
    const auto id = _nextBodyId++;
    _bodyHandles.emplace(id, std::move(b));
    return id;
  }
  std::shared_ptr<cpBody> bodyFrom(uint64_t id) {
    auto it = _bodyHandles.find(id);
    return (it == _bodyHandles.end()) ? nullptr : it->second;
  }
  void unregisterBody(uint64_t id) { _bodyHandles.erase(id); }

  /* ------------------------ Arbiter user-data storage -----------------------
   */

  struct ArbiterStore {
    // string -> stored value; keep it simple & safe for Lua
    std::unordered_map<std::string, double> nums;
    std::unordered_map<std::string, bool> bools;
    std::unordered_map<std::string, uintptr_t>
        ptrs; // lightuserdata / entity ids
  };
  static ArbiterStore *ensure_store(cpArbiter *arb) {
    if (auto p = (ArbiterStore *)cpArbiterGetUserData(arb))
      return p;
    auto *store = new ArbiterStore();
    cpArbiterSetUserData(arb, store);
    return store;
  }
  static void free_store(cpArbiter *arb) {
    if (auto *p = (ArbiterStore *)cpArbiterGetUserData(arb)) {
      delete p;
      cpArbiterSetUserData(arb, nullptr);
    }
  }

private:
    std::unordered_map<cpCollisionType, FluidConfig> _fluidByType;

  /* --------------- collision handling post-solve and pre-solve --------------
   */
  struct LuaPairHandler {
    sol::protected_function pre_solve;  // optional
    sol::protected_function post_solve; // optional
  };

  struct LuaWildcardHandler {
    sol::protected_function pre_solve;  // optional
    sol::protected_function post_solve; // optional
  };

  std::unordered_map<uint64_t, LuaPairHandler> _luaPairHandlers;
  std::unordered_map<cpCollisionType, LuaWildcardHandler> _luaWildcardHandlers;

  // Optional: book-keeping to avoid double-install
  std::unordered_set<uint64_t>
      _installedPairs; // pair handler registered in cpSpace
  std::unordered_set<cpCollisionType>
      _installedWildcards; // wildcard handler registered in cpSpace

  cpCollisionType TypeFromShape(cpShape *s) const {
    return cpShapeGetCollisionType(s);
  }

  LuaPairHandler *FindPairHandler(cpArbiter *arb) {
    cpShape *sa, *sb;
    cpArbiterGetShapes(arb, &sa, &sb);
    cpCollisionType ta = TypeFromShape(sa), tb = TypeFromShape(sb);
    auto it = _luaPairHandlers.find(PairKey(ta, tb));
    if (it == _luaPairHandlers.end())
      return nullptr;
    return &it->second;
  }

  LuaWildcardHandler *FindWildcardHandler(cpArbiter *arb) {
    cpShape *sa, *sb;
    cpArbiterGetShapes(arb, &sa, &sb);
    // Either side can carry the wildcard; Chipmunk calls both wildcards if
    // installed.
    auto ita = _luaWildcardHandlers.find(TypeFromShape(sa));
    if (ita != _luaWildcardHandlers.end())
      return &ita->second;
    auto itb = _luaWildcardHandlers.find(TypeFromShape(sb));
    if (itb != _luaWildcardHandlers.end())
      return &itb->second;
    return nullptr;
  }

  // C callbacks that Chipmunk invokes
  static cpBool C_PreSolve(cpArbiter *a, cpSpace *, void *d) {
    auto *W = static_cast<PhysicsWorld *>(d);
    LuaArbiter lab{a};
    // Prefer pair handler over wildcard
    if (auto *ph = W->FindPairHandler(a)) {
      if (ph->pre_solve.valid()) {
        auto r = ph->pre_solve(lab);
        if (!r.valid())
          return cpTrue; // swallow lua errors, keep solving
        sol::optional<bool> keep = r;
        return keep.value_or(true) ? cpTrue : cpFalse;
      }
    }
    if (auto *wh = W->FindWildcardHandler(a)) {
      if (wh->pre_solve.valid()) {
        auto r = wh->pre_solve(lab);
        if (!r.valid())
          return cpTrue;
        sol::optional<bool> keep = r;
        return keep.value_or(true) ? cpTrue : cpFalse;
      }
    }
    return cpTrue;
  }

  static void C_PostSolve(cpArbiter *a, cpSpace *, void *d) {
    auto *W = static_cast<PhysicsWorld *>(d);
    LuaArbiter lab{a};

    if (auto *ph = W->FindPairHandler(a)) {
      if (ph->post_solve.valid()) {
        auto r = ph->post_solve(lab);
        (void)r; // ignore result
        return;
      }
    }
    if (auto *wh = W->FindWildcardHandler(a)) {
      if (wh->post_solve.valid()) {
        auto r = wh->post_solve(lab);
        (void)r;
      }
    }
  }

  /* -------------------------- other private members -------------------------
   */

  std::unordered_map<std::string, cpCollisionType> _tagToCollisionType;
  cpCollisionType _nextCollisionType =
      1; // Start from 1, as 0 is default in Chipmunk

  // —— Union-Find state ——
  std::unordered_map<cpBody *, UFNode> _groupNodes;
  int _groupThreshold = 0;
  std::function<void(cpBody *)> _onGroupRemoved;

  // —— Union-Find helpers ——
  UFNode &MakeNode(cpBody *body);
  UFNode &FindNode(cpBody *body);
  void UnionBodies(cpBody *a, cpBody *b);
  void ProcessGroups();

  std::unordered_set<cpCollisionType> _installedWildcardTypes;

  static inline uint64_t PairKey(cpCollisionType a, cpCollisionType b) {
    if (a > b)
      std::swap(a, b);
    return (uint64_t(a) << 32) | uint64_t(b);
  }

  // —— Collision callback trampoline ——
  static void GroupPostSolveCallback(cpArbiter *arb, cpSpace *space,
                                     void *userData);
  // Called by the static callback; unions the two colliding bodies.
  void OnGroupPostSolve(cpArbiter *arb);
};

inline static std::shared_ptr<PhysicsWorld>
InitPhysicsWorld(entt::registry *registry, float meter = 64.0f,
                 float gravityX = 0.0f, float gravityY = 0.0f) {
  auto toReturn =
      std::make_shared<PhysicsWorld>(registry, meter, gravityX, gravityY);

  return toReturn;
}

/* ---------------------------- Collision layers ---------------------------- */
// Set all entities in an object layer to use a given physics tag and re-apply
// cpShapeFilter.
inline void SetObjectLayerPhysicsTag(entt::registry &R,
                                     physics::PhysicsWorld &W,
                                     const std::string &objectLayerName,
                                     const std::string &physicsTag) {
  const auto targetHash = std::hash<std::string>{}(objectLayerName);

  auto view = R.view<ColliderComponent, ObjectLayerTag>();
  for (auto e : view) {
    const auto &ol = view.get<ObjectLayerTag>(e);
    if (ol.hash != targetHash)
      continue;

    // (1) record the layer tag on the entity
    R.emplace_or_replace<PhysicsLayer>(e, physicsTag);

    // (2) apply the filter on the shape now
    auto &cc = view.get<ColliderComponent>(e);
    W.ApplyCollisionFilter(cc.shape.get(), physicsTag);
  }
}

// Update the mask list for a tag, then re-apply it to all shapes that use that
// tag.
inline void
SetObjectLayerCollidesWith(entt::registry &R, physics::PhysicsWorld &W,
                           const std::string &physicsTag,
                           const std::vector<std::string> &collidesWith) {
  W.UpdateCollisionMasks(physicsTag, collidesWith);

  auto view = R.view<ColliderComponent, PhysicsLayer>();
  const auto tagHash = std::hash<std::string>{}(physicsTag);
  for (auto e : view) {
    const auto &L = view.get<PhysicsLayer>(e);
    if (L.tag_hash != tagHash)
      continue;

    auto &cc = view.get<ColliderComponent>(e);
    W.ApplyCollisionFilter(cc.shape.get(), physicsTag);
  }
}
} // namespace physics
