#pragma once
#include "../../third_party/chipmunk/include/chipmunk/chipmunk.h"
#include "../../third_party/chipmunk/include/chipmunk/chipmunk_structs.h"
#include "../../third_party/chipmunk/include/chipmunk/chipmunk_private.h"
#include <memory>
#include <vector>
#include <unordered_map>
#include "entt/entt.hpp"
#include "raylib.h"
#include "systems/layer/layer.hpp"

namespace physics
{
    // ----------------------------------------------------------------------------
    // debug drawing functions: these are called by cpSpaceDebugDraw() to render the physics objects when debugging
    // ----------------------------------------------------------------------------
    static cpSpaceDebugColor Colors[] = {
        {0xb5/255.0f, 0x89/255.0f, 0x00/255.0f, 1.0f},
        {0xcb/255.0f, 0x4b/255.0f, 0x16/255.0f, 1.0f},
        {0xdc/255.0f, 0x32/255.0f, 0x2f/255.0f, 1.0f},
        {0xd3/255.0f, 0x36/255.0f, 0x82/255.0f, 1.0f},
        {0x6c/255.0f, 0x71/255.0f, 0xc4/255.0f, 1.0f},
        {0x26/255.0f, 0x8b/255.0f, 0xd2/255.0f, 1.0f},
        {0x2a/255.0f, 0xa1/255.0f, 0x98/255.0f, 1.0f},
        {0x85/255.0f, 0x99/255.0f, 0x00/255.0f, 1.0f},
    };
    
    
    // Draw a circle
    inline static void DrawCircle(cpVect p, cpFloat a, cpFloat r, cpSpaceDebugColor outline, cpSpaceDebugColor fill, cpDataPointer data) {
        Color outlineColor = (Color){ (unsigned char)(outline.r * 255), (unsigned char)(outline.g * 255), (unsigned char)(outline.b * 255), (unsigned char)(outline.a * 255) };
        Color fillColor = (Color){ (unsigned char)(fill.r * 255), (unsigned char)(fill.g * 255), (unsigned char)(fill.b * 255), (unsigned char)(fill.a * 255) };
        
        DrawCircle((int)p.x, (int)p.y, (float)r, fillColor);
        DrawCircleLines((int)p.x, (int)p.y, (float)r, outlineColor);
    }

    // Draw a line segment
    inline static void DrawSegment(cpVect a, cpVect b, cpSpaceDebugColor color, cpDataPointer data) {
        Color lineColor = (Color){ (unsigned char)(color.r * 255), (unsigned char)(color.g * 255), (unsigned char)(color.b * 255), (unsigned char)(color.a * 255) };
        DrawLine((int)a.x, (int)a.y, (int)b.x, (int)b.y, lineColor);
    }

    // Draw a thick line segment (fat segment)
    inline static void DrawFatSegment(cpVect a, cpVect b, cpFloat r, cpSpaceDebugColor outline, cpSpaceDebugColor fill, cpDataPointer data) {
        Color outlineColor = (Color){ (unsigned char)(outline.r * 255), (unsigned char)(outline.g * 255), (unsigned char)(outline.b * 255), (unsigned char)(outline.a * 255) };
        Color fillColor = (Color){ (unsigned char)(fill.r * 255), (unsigned char)(fill.g * 255), (unsigned char)(fill.b * 255), (unsigned char)(fill.a * 255) };

        DrawLineEx((Vector2){(float)a.x, (float)a.y}, (Vector2){(float)b.x, (float)b.y}, (float)(2 * r), fillColor);
        DrawLine((int)a.x, (int)a.y, (int)b.x, (int)b.y, outlineColor);
    }

    // Draw a polygon
    inline static void DrawPolygon(int count, const cpVect *verts, cpFloat r, cpSpaceDebugColor outline, cpSpaceDebugColor fill, cpDataPointer data) {
        Color outlineColor = (Color){ (unsigned char)(outline.r * 255), (unsigned char)(outline.g * 255), (unsigned char)(outline.b * 255), (unsigned char)(outline.a * 255) };
        Color fillColor = (Color){ (unsigned char)(fill.r * 255), (unsigned char)(fill.g * 255), (unsigned char)(fill.b * 255), (unsigned char)(fill.a * 255) };

        for (int i = 0; i < count; i++) {
            Vector2 start = { (float)verts[i].x, (float)verts[i].y };
            Vector2 end = { (float)verts[(i + 1) % count].x, (float)verts[(i + 1) % count].y };
            DrawLineEx(start, end, 2.0f, outlineColor);  // Draw outline
        }

        for (int i = 0; i < count; i++) {
            Vector2 vertex = { (float)verts[i].x, (float)verts[i].y };
            DrawCircleV(vertex, (float)r, fillColor);  // Draw vertex circles for effect
        }
    }

    // Draw a dot
    inline static void DrawDot(cpFloat size, cpVect pos, cpSpaceDebugColor color, cpDataPointer data) {
        Color dotColor = (Color){ (unsigned char)(color.r * 255), (unsigned char)(color.g * 255), (unsigned char)(color.b * 255), (unsigned char)(color.a * 255) };
        DrawCircle((int)pos.x, (int)pos.y, (float)size, dotColor);
    }
    
    static inline cpSpaceDebugColor LAColor(float l, float a){
        cpSpaceDebugColor color = {l, l, l, a};
        return color;
    }
    
    static inline cpSpaceDebugColor RGBAColor(float r, float g, float b, float a){
        cpSpaceDebugColor color = {r, g, b, a};
        return color;
    }
    
    inline static cpSpaceDebugColor
    ColorForShape(cpShape *shape, cpDataPointer data)
    {
        if(cpShapeGetSensor(shape)){
            return LAColor(1.0f, 0.1f);
        } else {
            cpBody *body = cpShapeGetBody(shape);
            
            if(cpBodyIsSleeping(body)){
                return RGBAColor(0x58/255.0f, 0x6e/255.0f, 0x75/255.0f, 1.0f);
            } else if(body->sleeping.idleTime > shape->space->sleepTimeThreshold) {
                return RGBAColor(0x93/255.0f, 0xa1/255.0f, 0xa1/255.0f, 1.0f);
            } else {
                uint32_t val = (uint32_t)shape->hashid;
                
                // scramble the bits up using Robert Jenkins' 32 bit integer hash function
                val = (val+0x7ed55d16) + (val<<12);
                val = (val^0xc761c23c) ^ (val>>19);
                val = (val+0x165667b1) + (val<<5);
                val = (val+0xd3a2646c) ^ (val<<9);
                val = (val+0xfd7046c5) + (val<<3);
                val = (val^0xb55a4f09) ^ (val>>16);
                return Colors[val & 0x7];
            }
        }
    }
    
    // Call this function to draw the physics objects for a cpSpace when debugging. NOTE: if using a camera, call this function after beginMode2D(camera)
    inline static void ChipmunkDemoDefaultDrawImpl(cpSpace *space) {
        
        cpSpaceDebugDrawOptions drawOptions = {
            DrawCircle,
            DrawSegment,
            DrawFatSegment,
            DrawPolygon,
            DrawDot,
            (cpSpaceDebugDrawFlags)(CP_SPACE_DEBUG_DRAW_SHAPES | CP_SPACE_DEBUG_DRAW_CONSTRAINTS | CP_SPACE_DEBUG_DRAW_COLLISION_POINTS),
            {0xEE / 255.0f, 0xE8 / 255.0f, 0xD5 / 255.0f, 1.0f},  // Outline color
            ColorForShape,
            {0.0f, 0.75f, 0.0f, 1.0f},  // Constraint color
            {1.0f, 0.0f, 0.0f, 1.0f},   // Collision point color
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
    extern std::shared_ptr<cpShape> MakeSharedShape(cpBody *body, cpFloat width, cpFloat height);

    extern entt::entity GetEntityFromBody(cpBody *body);
    
    extern void SetEntityToShape(cpShape *shape, entt::entity entity);
    
    extern void SetEntityToBody(cpBody *body, entt::entity entity);
    // ----------------------------------------------------------------------------
    // Data structures
    // ----------------------------------------------------------------------------
 
    
    enum class ColliderShapeType {
        Rectangle,
        Segment,
        Circle,
        Polygon,
        Chain
    };

    // A structure to represent collision events.
    struct CollisionEvent
    {
        void *objectA;
        void *objectB;
        float x1, y1, x2, y2, nx, ny;
    };

    struct ColliderComponent {
        std::shared_ptr<cpBody> body;     // Pointer to the Chipmunk body
        std::shared_ptr<cpShape> shape;  // Pointer to the Chipmunk shape
        bool isSensor = false;           // True if the collider is a sensor
        bool isDynamic = true;           // Indicates whether the body is dynamic
        bool debugDraw = true;           // Flag to enable/disable rendering
        ColliderShapeType shapeType;     // Type of collider shape
         std::vector<CollisionEvent> collisionEnter; // Physical collision start
        std::vector<CollisionEvent> collisionActive; // Physical collision active
        std::vector<CollisionEvent> collisionExit;  // Physical collision end
        std::vector<void *> triggerEnter;   // Trigger (collision with sensor) start
        std::vector<void *> triggerActive;  // Trigger (collision with sensor) active
        std::vector<void *> triggerExit;    // Trigger end


        ColliderComponent(std::shared_ptr<cpBody> body, std::shared_ptr<cpShape> shape, const std::string &tag, bool sensor = false, ColliderShapeType shapeType = ColliderShapeType::Rectangle)
            : body(std::move(body)), shape(std::move(shape)), isSensor(sensor), shapeType(shapeType) {}
    };
    
    struct CollisionTag {
        int category;                 // Collision category ID
        std::vector<int> masks;       // Categories this tag can collide with
        std::vector<int> triggers;    // Categories this tag can trigger with
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

    class PhysicsWorld
    {
    public:
        // General Members
        entt::registry *registry;
        cpSpace *space;
        float meter; // REVIEW: unused
        // Internal state for mouse dragging
        cpBody* mouseBody = nullptr;           // a static body to attach the mouse joint
        cpConstraint* mouseJoint = nullptr;    // the active pivot joint
        entt::entity draggedEntity = entt::null; // which entity is being dragged
        cpBody* controlBody = nullptr;    // for your player/controller joint
        //TODO: isolate the above into the collision component later
            
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
        PhysicsWorld(entt::registry *registry, float meter = 64.0f, float gravityX = 0.0f, float gravityY = 0.0f);
        ~PhysicsWorld();

        // Update and Post-Update
        void Update(float deltaTime);
        void PostUpdate();

        // Collision Management
        void SetCollisionCallbacks();
        void OnCollisionBegin(cpArbiter *arb);
        void OnCollisionEnd(cpArbiter *arb);
        void EnableCollisionBetween(const std::string &tag1, const std::vector<std::string> &tags);
        void DisableCollisionBetween(const std::string &tag1, const std::vector<std::string> &tags);
        void EnableTriggerBetween(const std::string &tag1, const std::vector<std::string> &tags);
        void DisableTriggerBetween(const std::string &tag1, const std::vector<std::string> &tags);

        // Collision Tag Management
        std::string GetTagFromCategory(int category);
        void AddCollisionTag(const std::string &tag);
        void RemoveCollisionTag(const std::string &tag);
        void UpdateCollisionMasks(const std::string &tag, const std::vector<std::string> &collidableTags);
        void SetCollisionTags(const std::vector<std::string> &tags);
        void ApplyCollisionFilter(cpShape *shape, const std::string &tag);
        void UpdateColliderTag(entt::entity entity, const std::string &newTag);

        // Utility Functions
        /// Query the first entity at world point (x,y). Returns entt::null if none found.
        void CreateTilemapColliders(
            const std::vector<std::vector<bool>>& collidable,
            float tileSize,
            float segmentRadius = 1.0f
        );
        void CreateTopDownController(
            entt::entity entity,
            float maxBias  = 200.0f,
            float maxForce = 3000.0f);
        void AddUprightSpring(entt::entity e, float stiffness = 100.0f, float damping = 10.0f);
        void AddScreenBounds(float xMin, float yMin,
                                    float xMax, float yMax,
                                    float thickness = 1.0f);
        entt::entity PointQuery(float x, float y);
        /// Teleport an entity's body to (x,y).
        void SetBodyPosition(entt::entity e, float x, float y);\
        /// Directly set an entity's linear velocity.
        void SetBodyVelocity(entt::entity e, float vx, float vy);
        /// Begin dragging the body under (x,y) with a pivot joint.
        void StartMouseDrag(float x, float y);
        /// Update the drag target to follow (x,y).
        void UpdateMouseDrag(float x, float y);
        /// End the current mouse drag.
        void EndMouseDrag();
        const std::vector<CollisionEvent> &GetCollisionEnter(const std::string &type1, const std::string &type2);
        const std::vector<void *> &GetTriggerEnter(const std::string &type1, const std::string &type2);
        std::vector<RaycastHit> Raycast(float x1, float y1, float x2, float y2);
        std::vector<void *> GetObjectsInArea(float x1, float y1, float x2, float y2);
        void SetGravity(float gravityX, float gravityY);
        void SetMeter(float meter);

        // Collider Management
        std::shared_ptr<cpShape> AddShape(cpBody *body, float width, float height, const std::string &tag);
        void AddCollider(entt::entity entity, const std::string &tag, const std::string &shapeType, float a, float b, float c, float d, bool isSensor, const std::vector<cpVect> &points = {});

        // Rendering and Debugging
        void RenderColliders(); // TODO: remove
        void PrintCollisionTags();

        // Movement and Steering Behaviors
        void Seek(entt::entity entity, float targetX, float targetY, float maxSpeed);
        void Arrive(entt::entity entity, float targetX, float targetY, float maxSpeed, float slowingRadius);
        void Wander(entt::entity entity, float wanderRadius, float wanderDistance, float jitter, float maxSpeed);
        void Separate(entt::entity entity, const std::vector<entt::entity> &others, float separationRadius, float maxForce);
        void Align(entt::entity entity, const std::vector<entt::entity> &others, float alignRadius, float maxSpeed, float maxForce);
        void Cohesion(entt::entity entity, const std::vector<entt::entity> &others, float cohesionRadius, float maxSpeed, float maxForce);
        void RotateTowardObject(entt::entity entity, entt::entity target, float lerpValue);        
        void RotateTowardPoint(entt::entity entity, float targetX, float targetY, float lerpValue);
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
        void AccelerateTowardMouse(entt::entity entity, float acceleration, float maxSpeed);
        void AccelerateTowardObject(entt::entity entity, entt::entity target, float acceleration, float maxSpeed);
        void AccelerateTowardAngle(entt::entity entity, float angle, float acceleration, float maxSpeed);
        void AccelerateTowardPoint(entt::entity entity, float targetX, float targetY, float acceleration, float maxSpeed);
        void MoveTowardAngle(entt::entity entity, float angle, float speed);
        void MoveTowardPoint(entt::entity entity, float targetX, float targetY, float speed, float maxTime);
        void MoveTowardMouse(entt::entity entity, float speed, float maxTime);
        void MoveTowardsMouseHorizontally(entt::entity entity, float speed, float maxTime);
        void MoveTowardsMouseVertically(entt::entity entity, float speed, float maxTime);
        void LockHorizontally(entt::entity entity);
        void LockVertically(entt::entity entity);

        // Boundary Enforcement
        void EnforceBoundary(entt::entity entity, float minY);

        // Geometry and Body Management
        std::vector<cpVect> GetVertices(entt::entity entity);
        void SetBodyType(entt::entity entity, const std::string &bodyType);
    };
    
    
    inline static std::shared_ptr<PhysicsWorld> InitPhysicsWorld(entt::registry *registry, float meter = 64.0f, float gravityX = 0.0f, float gravityY = 0.0f) {
        return std::make_shared<PhysicsWorld>(registry, meter, gravityX, gravityY);
    }
}
