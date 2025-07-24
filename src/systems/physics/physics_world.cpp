#include "physics_world.hpp"

#include <raylib.h>
#include "util/common_headers.hpp"
#include "../../third_party/chipmunk/include/chipmunk/chipmunk.h"
#include <memory>
#include <vector>
#include <unordered_map>
#include <algorithm>

namespace physics
{

    // Helper function to create shared_ptr for cpSpace
    std::shared_ptr<cpSpace> MakeSharedSpace()
    {
        return std::shared_ptr<cpSpace>(
            cpSpaceNew(),
            [](cpSpace *space)
            { cpSpaceFree(space); });
    }

    // Helper function to create shared_ptr for cpBody
    std::shared_ptr<cpBody> MakeSharedBody(cpFloat mass, cpFloat moment)
    {
        return std::shared_ptr<cpBody>(
            cpBodyNew(mass, moment),
            [](cpBody *body)
            { cpBodyFree(body); });
    }

    // Helper function to create shared_ptr for cpShape
    std::shared_ptr<cpShape> MakeSharedShape(cpBody *body, cpFloat width, cpFloat height)
    {
        return std::shared_ptr<cpShape>(
            cpBoxShapeNew(body, width, height, 0.0),
            [](cpShape *shape)
            { cpShapeFree(shape); });
    }

    /**
     * @brief Constructs a PhysicsWorld object and initializes the Chipmunk2D physics space.
     *
     * This constructor initializes a new Chipmunk2D physics space, sets the gravity and iterations,
     * and associates the PhysicsWorld with an `entt::registry` for managing entities and components.
     *
     * @param registry Pointer to the `entt::registry` used to manage entities and components in the game or simulation.
     * @param meter (Unused in this implementation) A scaling factor representing the number of pixels per meter.
     *        Typically used for scaling physics calculations.
     * @param gravityX The X component of the gravitational force applied in the physics simulation.
     * @param gravityY The Y component of the gravitational force applied in the physics simulation.
     *
     * @details
     * - The physics space is initialized using `cpSpaceNew`.
     * - Gravity is set using `cpSpaceSetGravity`, with the vector `(gravityX, gravityY)` specifying the direction and strength.
     * - The default number of solver iterations is set to 10 using `cpSpaceSetIterations`.
     * - The `registry` pointer allows the physics system to interact with entities and their associated components.
     *
     * @note
     * The `meter` parameter is not currently used in this implementation but can be incorporated
     * if physics-world-to-screen scaling is required in the future.
     *
     * @example
     * // Example usage to create a PhysicsWorld object with gravity pointing downward
     * entt::registry registry;
     * PhysicsWorld physicsWorld(&registry, 1.0f, 0.0f, -9.8f);
     */
    PhysicsWorld::PhysicsWorld(entt::registry *registry, float meter, float gravityX, float gravityY)
    {
        // Initialize Chipmunk space
        space = cpSpaceNew();
        cpSpaceSetGravity(space, cpv(gravityX, gravityY));
        cpSpaceSetIterations(space, 10); // Default iteration count
        this->registry = registry;
    }

    PhysicsWorld::~PhysicsWorld()
    {
        cpSpaceFree(space); // Free the Chipmunk space
    }

    /**
     * @brief Advances the physics simulation by a given time step.
     *
     * @param deltaTime The time step in seconds to progress the physics simulation.
     *                  This value is typically the elapsed time between frames.
     *
     * @details
     * - Uses `cpSpaceStep` to advance the Chipmunk2D physics simulation by `deltaTime`.
     * - Updates the positions, velocities, and interactions of all objects in the physics space.
     * - This method should be called once per frame to ensure consistent simulation results.
     *
     * @note
     * - A smaller `deltaTime` increases simulation precision but may require more computational resources.
     * - Ensure `deltaTime` is consistent across frames for predictable physics behavior.
     *
     * @example
     * // Example usage in a game loop
     * float deltaTime = GetFrameTime(); // Get time since last frame
     * physicsWorld.Update(deltaTime);  // Update the physics world
     */
    void PhysicsWorld::Update(float deltaTime)
    {
        cpSpaceStep(space, deltaTime);
    }

    /**
     * @brief Clears the temporary collision and trigger event buffers.
     *
     * @details
     * - Resets the event tracking lists (`collisionEnter`, `collisionExit`, `triggerEnter`, and `triggerExit`) to prepare for the next simulation step.
     * - This method should be called after processing all collision and trigger events in the current frame.
     * - Helps maintain a clean state for event handling between updates.
     *
     * @note
     * - The persistent state of collisions and triggers should be handled elsewhere if needed, as this method clears the current frame's data.
     * - Typically called after the `Update` method in the game loop.
     *
     * @example
     * // Example usage in the game loop:
     * physicsWorld.Update(deltaTime);  // Update the physics simulation
     * HandleCollisionEvents();        // Process collision events
     * physicsWorld.PostUpdate();       // Clear event buffers
     */
    void PhysicsWorld::PostUpdate()
    {
        collisionEnter.clear();
        collisionExit.clear();
        triggerEnter.clear();
        triggerExit.clear();
        
        // Clear individual collider events
        registry->view<ColliderComponent>().each([](auto &collider) {
            collider.collisionEnter.clear();
            collider.collisionActive.clear();
            collider.collisionExit.clear();
            collider.triggerEnter.clear();
            collider.triggerActive.clear();
            collider.triggerExit.clear();
        });
    }

    /**
     * @brief Sets the gravity vector for the physics simulation.
     *
     * @param gravityX The X component of the gravity vector.
     * @param gravityY The Y component of the gravity vector.
     *
     * @details
     * - Updates the gravity applied to all objects in the physics simulation space.
     * - The gravity vector affects all dynamic bodies unless they have their gravity scale set to 0.
     * - This method can be used to simulate different gravitational environments or adjust gravity during gameplay.
     *
     * @note
     * - Default gravity is typically set during the construction of the `PhysicsWorld` object.
     * - Changes take effect immediately in the next physics update step.
     *
     * @example
     * // Set Earth's gravity
     * physicsWorld.SetGravity(0.0f, -9.8f);
     *
     * // Simulate zero-gravity environment
     * physicsWorld.SetGravity(0.0f, 0.0f);
     */
    void PhysicsWorld::SetGravity(float gravityX, float gravityY)
    {
        cpSpaceSetGravity(space, cpv(gravityX, gravityY));
    }

    // Chipmunk2D doesn't use a "meter" system like Box2D or Love2D, but we can simulate it by scaling forces or coordinates.
    // You could create a method to manage this scaling for consistency.
    void PhysicsWorld::SetMeter(float meter)
    {
        this->meter = meter; // Store it for use in scaling logic, if needed
    }

    /**
     * @brief Configures custom collision callbacks for the physics world.
     *
     * @details
     * - Sets up a collision handler for processing collisions of objects with collision type `1`.
     * - Registers callback functions to handle collision start (`beginFunc`) and collision end (`separateFunc`).
     * - Each callback function delegates processing to the appropriate member functions of the `PhysicsWorld` class: `OnCollisionBegin` and `OnCollisionEnd`.
     *
     * @note
     * - This method assumes a collision type of `1`. If multiple collision types are used, additional handlers may need to be added.
     * - The callbacks provide custom logic for detecting and responding to collisions between objects.
     * - The `userData` field in the handler is used to associate the `PhysicsWorld` instance with the callbacks.
     *
     * @example
     * // Initialize collision callbacks during the setup of the PhysicsWorld
     * physicsWorld.SetCollisionCallbacks();
     */
    void PhysicsWorld::SetCollisionCallbacks()
    {
        // Create a custom collision handler
        cpCollisionHandler *handler = cpSpaceAddCollisionHandler(space, 1, 1); // Collision type 1 with itself
        handler->beginFunc = [](cpArbiter *arb, cpSpace *space, void *data) -> cpBool
        {
            auto world = static_cast<PhysicsWorld *>(data);
            world->OnCollisionBegin(arb);
            return cpTrue; // Continue collision handling
        };
        handler->separateFunc = [](cpArbiter *arb, cpSpace *space, void *data)
        {
            auto world = static_cast<PhysicsWorld *>(data);
            world->OnCollisionEnd(arb);
        };
        handler->userData = this;
    }

    /**
     * @brief Handles the beginning of a collision between two shapes in the physics world.
     *
     * @param arb A pointer to the Chipmunk arbiter object that describes the collision.
     *
     * @details
     * - This function is called whenever two shapes in the physics simulation start colliding.
     * - It distinguishes between physical collisions and trigger events (sensor interactions).
     * - For physical collisions:
     *   - Verifies collision category and mask compatibility using the filters.
     *   - Adds a `CollisionEvent` to the `collisionEnter` and `collisionActive` lists for tracking.
     * - For trigger interactions:
     *   - Tracks trigger events in `triggerEnter` and `triggerActive`.
     *
     * @note
     * - Assumes the collision categories and masks are preconfigured for the shapes.
     * - Trigger and physical collision logic are handled separately to allow for different game mechanics.
     * - User data associated with the shapes is used to identify objects during collision handling.
     *
     * @example
     * // Triggered automatically by the collision callback system:
     * void PhysicsWorld::SetCollisionCallbacks() {
     *     cpCollisionHandler *handler = cpSpaceAddCollisionHandler(space, 1, 1);
     *     handler->beginFunc = [](cpArbiter *arb, cpSpace *space, void *data) -> cpBool {
     *         auto world = static_cast<PhysicsWorld *>(data);
     *         world->OnCollisionBegin(arb);
     *         return cpTrue;
     *     };
     * }
     */
    void PhysicsWorld::OnCollisionBegin(cpArbiter *arb)
    {
        cpShape *shapeA, *shapeB;
        cpArbiterGetShapes(arb, &shapeA, &shapeB);

        // Check if either shape is a sensor (trigger)
        bool isTriggerA = cpShapeGetSensor(shapeA);
        bool isTriggerB = cpShapeGetSensor(shapeB);

        void *dataA = cpShapeGetUserData(shapeA);
        void *dataB = cpShapeGetUserData(shapeB);

        if (!dataA || !dataB) return;

        entt::entity entityA = static_cast<entt::entity>(reinterpret_cast<uintptr_t>(dataA));
        entt::entity entityB = static_cast<entt::entity>(reinterpret_cast<uintptr_t>(dataB));

        // Fetch the mask categories
        const auto filterA = cpShapeGetFilter(shapeA);
        const auto filterB = cpShapeGetFilter(shapeB);

        // Fetch tags using categories
        std::string tagA = GetTagFromCategory(filterA.categories);
        std::string tagB = GetTagFromCategory(filterB.categories);

        // Generate a meaningful key
        std::string key = tagA + ":" + tagB;

        if (isTriggerA || isTriggerB)
        {
            // Handle trigger interaction
            if (isTriggerA)
                registry->get<ColliderComponent>(entityA).triggerEnter.push_back(dataB);
            if (isTriggerB)
                registry->get<ColliderComponent>(entityB).triggerEnter.push_back(dataA);

            triggerEnter[key].push_back(dataA);
            triggerActive[key].push_back(dataA);
            return;
        }

        // Handle physical collisions
        if ((filterA.categories & filterB.mask) == 0 || (filterB.categories & filterA.mask) == 0)
            return;

        // Populate collision data
        CollisionEvent event = { dataA, dataB };
        cpContactPointSet contactPoints = cpArbiterGetContactPointSet(arb);
        cpVect normal = cpArbiterGetNormal(arb);

        if (contactPoints.count > 0)
        {
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
        // swap
        event.objectA = dataB;
        event.objectB = dataA;
        if (registry->all_of<ColliderComponent>(entityB))
            registry->get<ColliderComponent>(entityB).collisionEnter.push_back(event);
    }

    /**
     * @brief Handles the end of a collision between two shapes in the physics world.
     *
     * @param arb A pointer to the Chipmunk arbiter object that describes the collision.
     *
     * @details
     * - This function is called whenever two shapes in the physics simulation stop colliding.
     * - It distinguishes between physical collisions and trigger events (sensor interactions).
     * - For physical collisions:
     *   - Verifies collision category and mask compatibility using the filters.
     *   - Adds a `CollisionEvent` to the `collisionExit` list to track the exit.
     *   - Removes the exited collision from the `collisionActive` list.
     * - For trigger interactions:
     *   - Tracks trigger exit events in `triggerExit`.
     *   - Removes the corresponding object from `triggerActive`.
     *
     * @note
     * - Assumes the collision categories and masks are preconfigured for the shapes.
     * - Trigger and physical collision logic are handled separately to allow for different game mechanics.
     * - User data associated with the shapes is used to identify objects during collision handling.
     *
     * @example
     * // Triggered automatically by the collision callback system:
     * void PhysicsWorld::SetCollisionCallbacks() {
     *     cpCollisionHandler *handler = cpSpaceAddCollisionHandler(space, 1, 1);
     *     handler->separateFunc = [](cpArbiter *arb, cpSpace *space, void *data) {
     *         auto world = static_cast<PhysicsWorld *>(data);
     *         world->OnCollisionEnd(arb);
     *     };
     * }
     */
    void PhysicsWorld::OnCollisionEnd(cpArbiter *arb)
    {
        cpShape *shapeA, *shapeB;
        cpArbiterGetShapes(arb, &shapeA, &shapeB);

        // Check if either shape is a sensor (trigger)
        bool isTriggerA = cpShapeGetSensor(shapeA);
        bool isTriggerB = cpShapeGetSensor(shapeB);

        void *dataA = cpShapeGetUserData(shapeA);
        void *dataB = cpShapeGetUserData(shapeB);

        if (!dataA || !dataB) return;

        entt::entity entityA = static_cast<entt::entity>(reinterpret_cast<uintptr_t>(dataA));
        entt::entity entityB = static_cast<entt::entity>(reinterpret_cast<uintptr_t>(dataB));

        // Fetch the mask categories
        const auto filterA = cpShapeGetFilter(shapeA);
        const auto filterB = cpShapeGetFilter(shapeB);

        // Fetch tags using categories
        std::string tagA = GetTagFromCategory(filterA.categories);
        std::string tagB = GetTagFromCategory(filterB.categories);

        // Generate a meaningful key
        std::string key = tagA + ":" + tagB;

        if (isTriggerA || isTriggerB)
        {
            // Handle trigger exit
            if (registry->all_of<ColliderComponent>(entityA)) {
                auto &colliderA = registry->get<ColliderComponent>(entityA);
                colliderA.triggerExit.push_back(dataB);

                // Remove from active triggers
                colliderA.triggerActive.erase(
                    std::remove(colliderA.triggerActive.begin(), colliderA.triggerActive.end(), dataB),
                    colliderA.triggerActive.end());
            }

            if (registry->all_of<ColliderComponent>(entityB)) {
                auto &colliderB = registry->get<ColliderComponent>(entityB);
                colliderB.triggerExit.push_back(dataA);

                // Remove from active triggers
                colliderB.triggerActive.erase(
                    std::remove(colliderB.triggerActive.begin(), colliderB.triggerActive.end(), dataA),
                    colliderB.triggerActive.end());
            }

            triggerExit[key].push_back(dataA);

            auto &activeTriggers = triggerActive[key];
            activeTriggers.erase(
                std::remove(activeTriggers.begin(), activeTriggers.end(), dataA),
                activeTriggers.end());
            return;
        }

        // Handle physical collisions
        if ((filterA.categories & filterB.mask) == 0 || (filterB.categories & filterA.mask) == 0)
            return;

        CollisionEvent event = { dataA, dataB };
        collisionExit[key].push_back(event);

        auto &activeCollisions = collisionActive[key];
        activeCollisions.erase(
            std::remove_if(activeCollisions.begin(), activeCollisions.end(),
                        [dataA, dataB](const CollisionEvent &e)
                        {
                            return (e.objectA == dataA && e.objectB == dataB) ||
                                    (e.objectA == dataB && e.objectB == dataA);
                        }),
            activeCollisions.end());

        if (registry->all_of<ColliderComponent>(entityA)) {
            auto &colliderA = registry->get<ColliderComponent>(entityA);

            // Clear collision events related to entityB for colliderA
            colliderA.collisionExit.push_back(event);
            colliderA.collisionActive.erase(
                std::remove_if(colliderA.collisionActive.begin(), colliderA.collisionActive.end(),
                            [dataB](const CollisionEvent &e) { return e.objectB == dataB; }),
                colliderA.collisionActive.end());
        }

        if (registry->all_of<ColliderComponent>(entityB)) {
            auto &colliderB = registry->get<ColliderComponent>(entityB);

            // Clear collision events related to entityA for colliderB
            event.objectA = dataB; // Swap objects for entityB's perspective
            event.objectB = dataA;

            colliderB.collisionExit.push_back(event);
            colliderB.collisionActive.erase(
                std::remove_if(colliderB.collisionActive.begin(), colliderB.collisionActive.end(),
                            [dataA](const CollisionEvent &e) { return e.objectB == dataA; }),
                colliderB.collisionActive.end());
        }
    }



    /**
     * @brief Enables collisions between two sets of tags in the physics world.
     *
     * @param tag1 The first tag that will participate in the collision.
     * @param tags A vector of tags that will be allowed to collide with `tag1`.
     *
     * @details
     * - This function modifies the collision filter masks of the specified tags to enable interactions between them.
     * - It updates the `collisionTags` map, which stores the collision categories and masks for each tag.
     * - The tags specified in the `tags` vector will be added to the collision mask of `tag1`.
     * - Once the collision mask is updated, objects with these tags will be able to collide with each other during the physics simulation.
     *
     * @note
     * - The collision filter allows fine-grained control over which objects can collide with each other.
     * - The `collisionTags` map must be populated with tags and their corresponding categories prior to calling this function.
     *
     * @example
     * // To enable collisions between 'player' and 'enemy':
     * std::vector<std::string> enemyTags = {"enemy"};
     * world.EnableCollisionBetween("player", enemyTags);
     */
    void PhysicsWorld::EnableCollisionBetween(const std::string &tag1, const std::vector<std::string> &tags)
    {
        auto &masks = collisionTags[tag1].masks;
        for (const auto &tag : tags)
        {
            masks.push_back(collisionTags[tag].category);
        }
    }

    /**
     * @brief Disables collisions between two sets of tags in the physics world.
     *
     * @param tag1 The first tag that will have its collisions with `tags` disabled.
     * @param tags A vector of tags that will be removed from the collision mask of `tag1`.
     *
     * @details
     * - This function modifies the collision filter masks of the specified tags to disable interactions between them.
     * - It updates the `collisionTags` map, which stores the collision categories and masks for each tag.
     * - The tags specified in the `tags` vector will be removed from the collision mask of `tag1`, preventing collisions between these tags.
     * - Once the mask is updated, objects with these tags will no longer be able to collide with objects having the `tag1` tag during the physics simulation.
     *
     * @note
     * - The collision filter allows fine-grained control over which objects can collide with each other.
     * - The `collisionTags` map must be populated with tags and their corresponding categories prior to calling this function.
     *
     * @example
     * // To disable collisions between 'player' and 'enemy':
     * std::vector<std::string> enemyTags = {"enemy"};
     * world.DisableCollisionBetween("player", enemyTags);
     */
    void PhysicsWorld::DisableCollisionBetween(const std::string &tag1, const std::vector<std::string> &tags)
    {
        auto &masks = collisionTags[tag1].masks;
        for (const auto &tag : tags)
        {
            masks.erase(std::remove(masks.begin(), masks.end(), collisionTags[tag].category), masks.end());
        }
    }

    /**
     * @brief Enables triggers between two sets of tags in the physics world.
     *
     * @param tag1 The first tag that will have its triggers enabled with the tags specified in the `tags` vector.
     * @param tags A vector of tags that will be added to the trigger list for `tag1`.
     *
     * @details
     * - This function modifies the trigger configuration of the specified tags to enable interactions between them.
     * - It updates the `triggerTags` map, which stores the trigger categories and their respective trigger lists for each tag.
     * - The tags specified in the `tags` vector will be added to the trigger list of `tag1`, allowing trigger interactions between the two sets of tags.
     * - Once this function is called, objects with `tag1` will be able to trigger events with objects having the specified tags in the `tags` vector.
     *
     * @note
     * - The trigger system allows objects to detect when they enter or exit specific regions or interact in a non-colliding manner.
     * - The `triggerTags` map must be populated with tags and their corresponding categories and triggers before calling this function.
     *
     * @example
     * // To enable triggers between 'player' and 'collectible':
     * std::vector<std::string> collectibleTags = {"collectible"};
     * world.EnableTriggerBetween("player", collectibleTags);
     */
    void PhysicsWorld::EnableTriggerBetween(const std::string &tag1, const std::vector<std::string> &tags)
    {
        for (const auto &tag : tags)
        {
            triggerTags[tag1].triggers.push_back(triggerTags[tag].category);
        }
    }

    /**
     * @brief Disables triggers between two sets of tags in the physics world.
     *
     * @param tag1 The first tag whose trigger interactions with the tags in the `tags` vector will be disabled.
     * @param tags A vector of tags whose triggers with `tag1` will be removed.
     *
     * @details
     * - This function modifies the trigger configuration of the specified tags to disable interactions between them.
     * - It updates the `triggerTags` map, which stores the trigger categories and their respective trigger lists for each tag.
     * - The tags specified in the `tags` vector will be removed from the trigger list of `tag1`, effectively disabling the trigger interactions between `tag1` and the specified tags.
     * - Once this function is called, objects with `tag1` will no longer trigger events with objects having the specified tags in the `tags` vector.
     *
     * @note
     * - The trigger system allows objects to detect when they enter or exit specific regions or interact in a non-colliding manner.
     * - The `triggerTags` map must be populated with tags and their corresponding categories and triggers before calling this function.
     *
     * @example
     * // To disable triggers between 'player' and 'collectible':
     * std::vector<std::string> collectibleTags = {"collectible"};
     * world.DisableTriggerBetween("player", collectibleTags);
     */
    void PhysicsWorld::DisableTriggerBetween(const std::string &tag1, const std::vector<std::string> &tags)
    {
        for (const auto &tag : tags)
        {
            auto &triggers = triggerTags[tag1].triggers;
            triggers.erase(std::remove(triggers.begin(), triggers.end(), triggerTags[tag].category), triggers.end());
        }
    }

    /**
     * @brief Retrieves the list of collision events for two specified types.
     *
     * @param type1 The first object type involved in the collision.
     * @param type2 The second object type involved in the collision.
     * @return A constant reference to a vector of `CollisionEvent` objects representing the collision events between the two types.
     *
     * @details
     * - This function provides access to the list of collision events between two specified types. It returns the events stored in the `collisionEnter` map, which is indexed by the concatenated `type1:type2` key.
     * - Collision events are populated when a collision between objects of the specified types occurs.
     * - The returned vector will contain details about each collision event, such as the objects involved and any other relevant data.
     *
     * @note
     * - The `collisionEnter` map is populated when a collision begins, and the events are stored for later access.
     * - If no collision between the specified types has occurred, the function will return an empty vector.
     *
     * @example
     * // To get the collision events between 'player' and 'enemy':
     * const auto& events = world.GetCollisionEnter("player", "enemy");
     * for (const auto& event : events) {
     *     // Handle each collision event
     * }
     */
    const std::vector<CollisionEvent> &PhysicsWorld::GetCollisionEnter(const std::string &type1, const std::string &type2)
    {
        return collisionEnter[type1 + ":" + type2];
    }

    /**
     * @brief Retrieves the list of objects that triggered an event between two specified types.
     *
     * @param type1 The first object type involved in the trigger event.
     * @param type2 The second object type involved in the trigger event.
     * @return A constant reference to a vector of pointers to objects that triggered the event between the specified types.
     *
     * @details
     * - This function provides access to the list of objects that triggered a sensor event between two specified types. It returns the objects stored in the `triggerEnter` map, which is indexed by the concatenated `type1:type2` key.
     * - Trigger events are populated when one object enters the trigger area of another object of the specified type.
     * - The returned vector will contain pointers to the objects involved in the trigger event.
     *
     * @note
     * - The `triggerEnter` map is populated when a trigger event begins, and the objects that triggered the event are stored for later access.
     * - If no trigger event between the specified types has occurred, the function will return an empty vector.
     *
     * @example
     * // To get the objects that triggered an event between 'player' and 'enemy':
     * const auto& triggeredObjects = world.GetTriggerEnter("player", "enemy");
     * for (auto* object : triggeredObjects) {
     *     // Handle each triggered object
     * }
     */
    const std::vector<void *> &PhysicsWorld::GetTriggerEnter(const std::string &type1, const std::string &type2)
    {
        return triggerEnter[type1 + ":" + type2];
    }

    /**
     * @brief Sets the collision and trigger tags for the objects in the physics world.
     *
     * @param tags A vector of tags that will be assigned to the collision and trigger categories.
     *
     * @details
     * - This function initializes and clears the `collisionTags` and `triggerTags` maps, which are responsible for storing the collision and trigger categories for various tags.
     * - The `tags` vector contains the list of tags that will be assigned to each category.
     * - Each tag is assigned a unique category, which is used to determine collision interactions and trigger events.
     * - The categories are assigned incrementally as powers of 2, starting from 1.
     * - The `collisionTags` map stores information related to collision categories, while the `triggerTags` map stores trigger categories.
     *
     * @note
     * - This function clears any previously set tags and categories, so calling it will overwrite existing settings.
     * - The categories are assigned using bitwise shifting, ensuring that each tag has a unique category.
     *
     * @example
     * // Example usage to set collision and trigger tags for "player" and "enemy":
     * world.SetCollisionTags({"player", "enemy"});
     * // "player" will be assigned category 1, "enemy" will be assigned category 2, etc.
     */
    void PhysicsWorld::SetCollisionTags(const std::vector<std::string> &tags)
    {
        collisionTags.clear();
        triggerTags.clear();

        int category = 1; // Start with category 1 (Chipmunk categories are powers of 2)
        for (const auto &tag : tags)
        {
            collisionTags[tag] = {category, {}, {}};
            triggerTags[tag] = {category, {}, {}};
            categoryToTag[category] = tag; // Populate reverse map
            category <<= 1; // Move to the next bit
        }
    }
    
    std::string PhysicsWorld::GetTagFromCategory(int category)
    {
        // Search in collisionTags
        for (const auto &[tag, collisionTag] : collisionTags)
        {
            if (collisionTag.category == category)
            {
                return tag;
            }
        }

        // Search in triggerTags (if needed)
        for (const auto &[tag, triggerTag] : triggerTags)
        {
            if (triggerTag.category == category)
            {
                return tag;
            }
        }

        return "unknown"; // Return a default tag if not found
    }
    
    void PhysicsWorld::UpdateColliderTag(entt::entity entity, const std::string &newTag)
    {
        if (collisionTags.find(newTag) == collisionTags.end()){
            
            SPDLOG_DEBUG("Invalid tag: {}", newTag);
            return; // Invalid tag
        }

        auto &collider = registry->get<ColliderComponent>(entity);
        ApplyCollisionFilter(collider.shape.get(), newTag);
    }
    
    void PhysicsWorld::PrintCollisionTags()
    {
        for (const auto &[tag, collisionTag] : collisionTags)
        {
            SPDLOG_DEBUG("Tag: {} | Category: {} | Masks: ", tag, collisionTag.category);
            for (int mask : collisionTag.masks)
                SPDLOG_DEBUG("{}", mask);
        }
    }
    
    void PhysicsWorld::AddCollisionTag(const std::string &tag)
    {
        if (collisionTags.find(tag) != collisionTags.end())
            return; // Tag already exists

        int category = 1;
        while (collisionTags.count(categoryToTag[category])) // Find the next available category
            category <<= 1;

        collisionTags[tag] = {category, {}, {}};
        triggerTags[tag] = {category, {}, {}};
        categoryToTag[category] = tag;
    }
    
    void PhysicsWorld::RemoveCollisionTag(const std::string &tag)
    {
        if (collisionTags.find(tag) == collisionTags.end())
            return; // Tag doesn't exist

        int category = collisionTags[tag].category;

        // Remove from data structures
        collisionTags.erase(tag);
        triggerTags.erase(tag);
        categoryToTag.erase(category);

        // Reset all colliders using this tag
        registry->view<ColliderComponent>().each([this, category](auto entity, auto &collider) {
            // Fetch the category of the collider's shape
            const auto filter = cpShapeGetFilter(collider.shape.get());

            if (filter.categories == category)
            {
                ApplyCollisionFilter(collider.shape.get(), "default"); // Reset to a default tag
            }
        });
    }

    
    void PhysicsWorld::UpdateCollisionMasks(const std::string &tag, const std::vector<std::string> &collidableTags)
    {
        if (collisionTags.find(tag) == collisionTags.end())
            return; // Invalid tag

        // Update the masks for the given tag
        collisionTags[tag].masks.clear();
        for (const auto &collidableTag : collidableTags)
        {
            if (collisionTags.find(collidableTag) != collisionTags.end())
            {
                collisionTags[tag].masks.push_back(collisionTags[collidableTag].category);
            }
        }

        // Reapply the filter for all shapes with the specified category
        int targetCategory = collisionTags[tag].category;
        registry->view<ColliderComponent>().each([this, targetCategory, &tag](auto entity, auto &collider) {
            // Fetch the category of the collider's shape
            const auto filter = cpShapeGetFilter(collider.shape.get());

            if (filter.categories == targetCategory)
            {
                ApplyCollisionFilter(collider.shape.get(), tag);
            }
        });
    }

    /**
     * @brief Sets the collision and trigger tags for the objects in the physics world.
     *
     * @param tags A vector of tags that will be assigned to the collision and trigger categories.
     *
     * @details
     * - This function initializes and clears the `collisionTags` and `triggerTags` maps, which are responsible for storing the collision and trigger categories for various tags.
     * - The `tags` vector contains the list of tags that will be assigned to each category.
     * - Each tag is assigned a unique category, which is used to determine collision interactions and trigger events.
     * - The categories are assigned incrementally as powers of 2, starting from 1.
     * - The `collisionTags` map stores information related to collision categories, while the `triggerTags` map stores trigger categories.
     *
     * @note
     * - This function clears any previously set tags and categories, so calling it will overwrite existing settings.
     * - The categories are assigned using bitwise shifting, ensuring that each tag has a unique category.
     *
     * @example
     * // Example usage to set collision and trigger tags for "player" and "enemy":
     * world.SetCollisionTags({"player", "enemy"});
     * // "player" will be assigned category 1, "enemy" will be assigned category 2, etc.
     */
    void PhysicsWorld::ApplyCollisionFilter(cpShape *shape, const std::string &tag)
    {
        if (collisionTags.find(tag) == collisionTags.end()) {
            SPDLOG_DEBUG("Invalid tag: {}. Tag not applied", tag);
            return; // Invalid tag
        }
        
        const auto &collisionTag = collisionTags[tag];
        int mask = 0;

        // Combine masks into a single bitfield
        for (int category : collisionTag.masks)
        {
            mask |= category;
        }

        cpShapeFilter filter = {static_cast<cpGroup>(collisionTag.category), static_cast<cpBitmask>(mask), static_cast<cpBitmask>(CP_ALL_CATEGORIES)}; // CP_ALL_CATEGORIES is the default wildcard
        cpShapeSetFilter(shape, filter);
    }

    /**
     * @brief Performs a raycast in the physics world and returns the hit information.
     *
     * @param x1 The starting x-coordinate of the ray.
     * @param y1 The starting y-coordinate of the ray.
     * @param x2 The ending x-coordinate of the ray.
     * @param y2 The ending y-coordinate of the ray.
     *
     * @return A vector of `RaycastHit` objects that contain information about the shapes hit by the ray.
     *
     * @details
     * - This function performs a raycast between the points `(x1, y1)` and `(x2, y2)` using Chipmunk's `cpSpaceSegmentQuery` function.
     * - It queries the physics space for any shapes that the ray intersects and returns a list of the hit shapes along with additional details such as the collision point, the normal vector at the point of contact, and the fraction of the ray's length at the hit location.
     * - The query checks all shapes in the space using the `CP_SHAPE_FILTER_ALL` filter, meaning that it will consider all shape types.
     * - A callback function processes each hit shape and stores the results in the provided vector of `RaycastHit` objects.
     *
     * @note
     * - Raycasting is commonly used for line-of-sight checks, bullet simulations, or any scenario where you need to determine which objects a ray intersects.
     * - This method is highly efficient for checking multiple shapes in a single query, making it ideal for scenarios like determining line-of-sight or interactions in physics-based simulations.
     * - The fraction (`alpha`) value represents how far along the ray the collision occurred. A fraction of `0.0` means the collision happened at the start of the ray, and `1.0` means the collision occurred at the end of the ray.
     *
     * @example
     * // Example usage of raycasting:
     * std::vector<RaycastHit> hits = world.Raycast(0.0f, 0.0f, 100.0f, 100.0f);
     * for (const auto &hit : hits) {
     *     // Process each hit, e.g., log the hit details
     *     printf("Hit shape: %p at point (%f, %f)\n", hit.shape, hit.point.x, hit.point.y);
     * }
     */
    std::vector<RaycastHit> PhysicsWorld::Raycast(float x1, float y1, float x2, float y2)
    {
        std::vector<RaycastHit> hits;

        cpSpaceSegmentQuery(
            space, cpv(x1, y1), cpv(x2, y2), 0, CP_SHAPE_FILTER_ALL,
            [](cpShape *shape, cpVect point, cpVect normal, cpFloat alpha, void *data)
            {
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

    /**
     * @brief Retrieves all objects within a specified rectangular area in the physics world.
     *
     * @param x1 The x-coordinate of the first corner of the area.
     * @param y1 The y-coordinate of the first corner of the area.
     * @param x2 The x-coordinate of the opposite corner of the area.
     * @param y2 The y-coordinate of the opposite corner of the area.
     *
     * @return A vector of void* pointers, each representing the user data of the shapes within the specified area.
     *
     * @details
     * - This method performs a bounding box query to find all shapes within a rectangular region defined by the coordinates `(x1, y1)` and `(x2, y2)`.
     * - It uses Chipmunk's `cpSpaceBBQuery` to query the physics space for all shapes that intersect the given bounding box.
     * - The query will return all shapes in the area regardless of shape type or category, as the filter `CP_SHAPE_FILTER_ALL` is used.
     * - The `userData` of each shape (if set) is collected and returned in the resulting vector. The `userData` can be any type of data associated with the shape, often representing game objects or other components.
     *
     * @note
     * - The returned vector contains raw pointers (`void*`) to the `userData` of the shapes. You need to cast these to the appropriate types based on the specific game object or component stored in the `userData`.
     * - This method is useful for operations like detecting all objects within a certain area, applying effects, or checking for collisions or interactions with multiple objects.
     *
     * @example
     * // Example usage of getting all objects within an area:
     * std::vector<void *> objectsInArea = world.GetObjectsInArea(0.0f, 0.0f, 100.0f, 100.0f);
     * for (void *object : objectsInArea) {
     *     // Cast the object to the appropriate type and process it
     *     GameObject *gameObject = static_cast<GameObject*>(object);
     *     gameObject->applyEffect();
     * }
     */
    std::vector<void *> PhysicsWorld::GetObjectsInArea(float x1, float y1, float x2, float y2)
    {
        std::vector<void *> objects;

        cpBB bb = cpBBNew(std::min(x1, x2), std::min(y1, y2), std::max(x1, x2), std::max(y1, y2));
        cpSpaceBBQuery(
            space, bb, CP_SHAPE_FILTER_ALL,
            [](cpShape *shape, void *data)
            {
                auto *objects = static_cast<std::vector<void *> *>(data);
                void *userData = cpShapeGetUserData(shape);
                if (userData)
                    objects->push_back(userData);
            },
            &objects);

        return objects;
    }

    /**
     * @brief Adds a rectangular shape to the physics world and applies a collision filter.
     *
     * @param body A pointer to the `cpBody` to which the shape will be attached.
     * @param width The width of the shape.
     * @param height The height of the shape.
     * @param tag A string representing the tag used for collision filtering.
     *
     * @return A shared pointer to the created shape (`cpShape`).
     *
     * @details
     * This method creates a rectangular shape with the specified dimensions (`width` and `height`) and attaches it to the provided `cpBody`.
     * - It applies the collision filter based on the `tag` provided, which determines how this shape interacts with other shapes in the physics world.
     * - It assigns the `userData` of the shape (optional), which can be used to store references to game objects or other related data.
     * - The shape is added to the physics world (`space`) for simulation.
     *
     * @note
     * - The `tag` provided will be used to apply the collision filter, which is critical in determining which shapes will interact with one another based on their categories and masks.
     * - `userData` is set to the `PhysicsWorld` object (`this`) for convenience, but it can be modified to store any type of data, depending on the game's design (such as a pointer to a specific game object).
     *
     * @example
     * // Example usage of adding a shape to the world:
     * cpBody *body = world.CreateBody();
     * std::shared_ptr<cpShape> shape = world.AddShape(body, 10.0f, 5.0f, "player");
     * // This adds a rectangular shape of size 10x5 to the `body` with the tag "player"
     */
    std::shared_ptr<cpShape> PhysicsWorld::AddShape(cpBody *body, float width, float height, const std::string &tag)
    {
        auto shape = MakeSharedShape(body, width, height);

        // Apply the collision filter based on the tag
        ApplyCollisionFilter(shape.get(), tag);

        // Set user data (optional, e.g., a reference to the game object)
        cpShapeSetUserData(shape.get(), static_cast<void *>(this));

        // Add the shape to the space
        cpSpaceAddShape(space, shape.get());

        return shape;
    }
    
    entt::entity GetEntityFromBody(cpBody *body)
    {
        void *data = cpBodyGetUserData(body);
        if (data)
        {
            return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(data));
        }
        return entt::null; // Return a null entity if no data is set
    }

    
    void SetEntityToShape(cpShape *shape, entt::entity entity)
    {
        cpShapeSetUserData(shape, reinterpret_cast<void*>(static_cast<uintptr_t>(entity)));
    }
    
    void SetEntityToBody(cpBody *body, entt::entity entity)
    {
        cpBodySetUserData(body, reinterpret_cast<void*>(static_cast<uintptr_t>(entity)));
    }


    /**
     * @brief Adds a collider to an entity in the physics world.
     *
     * This function creates a physics body and shape based on the specified parameters, applies collision filtering,
     * and registers the collider as a component for the specified entity using the EnTT registry.
     *
     * @param entity The EnTT entity to which the collider is associated.
     * @param tag A string tag identifying the collision category for the collider.
     *            The tag should correspond to a category defined in the collision filtering setup.
     * @param shapeType The type of shape for the collider. Supported values are:
     *                  - "rectangle": Creates a rectangular shape.
     *                  - "circle": Creates a circular shape.
     *                  - "polygon": Creates a polygonal shape.
     *                  - "chain": Creates a chain of vertices.
     * @param a The primary dimension (e.g., width for rectangles, radius for circles). Ignored if `points` is provided.
     * @param b The secondary dimension (e.g., height for rectangles). Ignored if `points` is provided.
     * @param c Used for chain shapes as the x-coordinate of the third vertex. Ignored for other shape types or if `points` is provided.
     * @param d Used for chain shapes as the y-coordinate of the third vertex. Ignored for other shape types or if `points` is provided.
     * @param isSensor A boolean flag indicating whether the collider is a sensor.
     *                 Sensors detect overlaps but do not produce physical responses.
     * @param points (Optional) A vector of points defining the vertices of the shape.
     *               Used for "polygon" or "chain" shape types. Overrides the `a`, `b`, `c`, and `d` parameters for these types.
     *
     * @throws std::invalid_argument If an unsupported `shapeType` is provided.
     *
     * This function performs the following steps:
     * 1. Creates a physics body using `MakeSharedBody`, with a mass of 0 if it's a sensor (static body).
     * 2. Creates a shape based on the specified `shapeType`:
     *    - Rectangle: Uses `MakeSharedShape`.
     *    - Circle: Uses `cpCircleShapeNew`.
     *    - Polygon: Uses `cpPolyShapeNew` with provided or default vertices.
     *    - Chain: Uses `cpPolyShapeNew` with provided or default vertices.
     * 3. Applies collision filtering to the shape using the specified `tag` via `ApplyCollisionFilter`.
     * 4. Sets the shape as a sensor if `isSensor` is true.
     * 5. Registers the collider with the EnTT registry as a `ColliderComponent`.
     * 6. Adds the body and shape to the physics simulation space.
     */
    void PhysicsWorld::AddCollider(entt::entity entity, const std::string &tag, const std::string &shapeType, float a, float b, float c, float d, bool isSensor, const std::vector<cpVect> &points)
    {
        auto body = MakeSharedBody(isSensor ? 0.0f : 1.0f, cpMomentForBox(1.0f, a, b));
        std::shared_ptr<cpShape> shape;

        if (shapeType == "rectangle")
        {
            shape = MakeSharedShape(body.get(), a, b);
        }
        else if (shapeType == "circle")
        {
            shape = std::shared_ptr<cpShape>(cpCircleShapeNew(body.get(), a, cpvzero), [](cpShape *s)
                                             { cpShapeFree(s); });
        }
        else if (shapeType == "polygon")
        {
            if (!points.empty())
            {
                shape = std::shared_ptr<cpShape>(cpPolyShapeNew(body.get(), points.size(), points.data(), cpTransformIdentity, 0.0),
                                                 [](cpShape *s)
                                                 { cpShapeFree(s); });
            }
            else
            {
                // Default to a triangle if no points are provided
                std::vector<cpVect> verts = {{0, 0}, {a, 0}, {a / 2, b}};
                shape = std::shared_ptr<cpShape>(cpPolyShapeNew(body.get(), verts.size(), verts.data(), cpTransformIdentity, 0.0),
                                                 [](cpShape *s)
                                                 { cpShapeFree(s); });
            }
        }
        else if (shapeType == "chain")
        {
            if (!points.empty())
            {
                shape = std::shared_ptr<cpShape>(cpPolyShapeNew(body.get(), points.size(), points.data(), cpTransformIdentity, 1.0),
                                                 [](cpShape *s)
                                                 { cpShapeFree(s); });
            }
            else
            {
                // Default to a simple chain if no points are provided
                std::vector<cpVect> verts = {{0, 0}, {a, b}, {c, d}};
                shape = std::shared_ptr<cpShape>(cpPolyShapeNew(body.get(), verts.size(), verts.data(), cpTransformIdentity, 1.0),
                                                 [](cpShape *s)
                                                 { cpShapeFree(s); });
            }
        }
        else
        {
            throw std::invalid_argument("Unsupported shapeType: " + shapeType);
        }

        // Apply collision filtering
        ApplyCollisionFilter(shape.get(), tag);
        cpShapeSetSensor(shape.get(), isSensor);

        // Register component with EnTT
        registry->emplace<ColliderComponent>(entity, body, shape, tag, isSensor);
        
        // save the entity in the shape & body's user data
        cpShapeSetUserData(shape.get(), reinterpret_cast<void*>(static_cast<uintptr_t>(entity)));
        cpBodySetUserData(body.get(), reinterpret_cast<void*>(static_cast<uintptr_t>(entity)));

        // Add to physics space
        cpSpaceAddBody(space, body.get());
        cpSpaceAddShape(space, shape.get());
    }

    /**
     * @brief Renders the colliders in the physics world for debugging purposes.
     *
     * This function iterates through all entities with a `ColliderComponent`
     * and renders their shapes, velocities, and angular velocities based on their
     * `shapeType` and other properties. It is primarily intended for debugging
     * and visualization of the physics simulation.
     *
     * **Supported Collider Shape Types:**
     * - **Circle:** Renders as a filled circle using the radius and offset from the shape.
     * - **Rectangle:** Renders as a filled rectangle using the bounding box dimensions.
     * - **Polygon:** Renders as a series of connected lines forming the polygon shape.
     * - **Segment:** Renders as a single line between two points.
     * - **Chain:** Renders as a series of connected line segments forming a loop.
     *
     * **Additional Debug Information:**
     * - **Velocity:** Renders as a yellow line originating from the collider's position.
     * - **Angular Velocity:** Renders as a rotating orange line around the collider's position.
     *
     * @details
     * - The function uses `collider.debugDraw` to determine whether to render a specific collider.
     * - It retrieves the `ColliderShapeType` from the `ColliderComponent` to decide the rendering logic.
     * - Positions and velocities are transformed from physics space to rendering space.
     * - All rendering operations use Raylib functions for visualization.
     *
     * @note
     * Ensure that `ColliderComponent` includes a `shapeType` variable of type `ColliderShapeType`
     * to classify the shape of the collider. Also, ensure that Raylib's rendering functions are
     * properly integrated into the project.
     *
     * @example
     * // Enable debug drawing for a collider
     * registry.emplace_or_replace<ColliderComponent>(entity, colliderBody, colliderShape, true);
     *
     * // Call RenderColliders during your game loop
     * physicsWorld.RenderColliders();
     */
    void PhysicsWorld::RenderColliders()
    {
        auto view = registry->view<ColliderComponent>();
        for (auto entity : view)
        {
            const auto &collider = view.get<ColliderComponent>(entity);

            if (!collider.debugDraw)
                continue;

            cpVect position = cpBodyGetPosition(collider.body.get());

            switch (collider.shapeType)
            {
            case ColliderShapeType::Circle:
            {
                // Render circle
                float radius = cpCircleShapeGetRadius(collider.shape.get());
                cpVect offset = cpCircleShapeGetOffset(collider.shape.get());
                DrawCircle(position.x + offset.x, position.y + offset.y, radius, RED);
                break;
            }
            case ColliderShapeType::Rectangle:
            {
                // Render rectangle (box)
                cpBB bb = cpShapeGetBB(collider.shape.get());
                DrawRectangle(bb.l, bb.b, bb.r - bb.l, bb.t - bb.b, BLUE);
                break;
            }
            case ColliderShapeType::Polygon:
            {
                // Render polygon
                const int count = cpPolyShapeGetCount(collider.shape.get());
                std::vector<Vector2> points(count);
                for (int i = 0; i < count; ++i)
                {
                    cpVect vert = cpPolyShapeGetVert(collider.shape.get(), i);
                    points[i] = {(float)vert.x + (float)position.x, (float)vert.y + (float)position.y};
                }
                for (int i = 0; i < count; ++i)
                {
                    const Vector2 &p1 = points[i];
                    const Vector2 &p2 = points[(i + 1) % count];
                    DrawLine(p1.x, p1.y, p2.x, p2.y, GREEN);
                }
                break;
            }
            case ColliderShapeType::Segment:
            {
                // Render segment
                cpVect a = cpSegmentShapeGetA(collider.shape.get());
                cpVect b = cpSegmentShapeGetB(collider.shape.get());
                DrawLine(a.x, a.y, b.x, b.y, ORANGE);
                break;
            }
            case ColliderShapeType::Chain:
            {
                // Render chain (loop of segments)
                const int count = cpPolyShapeGetCount(collider.shape.get());
                std::vector<Vector2> points(count);
                for (int i = 0; i < count; ++i)
                {
                    cpVect vert = cpPolyShapeGetVert(collider.shape.get(), i);
                    points[i] = {(float)vert.x + (float)position.x, (float)vert.y + (float)position.y};
                }
                for (int i = 0; i < count - 1; ++i)
                {
                    const Vector2 &p1 = points[i];
                    const Vector2 &p2 = points[i + 1];
                    DrawLine(p1.x, p1.y, p2.x, p2.y, PURPLE);
                }
                if (!points.empty())
                {
                    // Close the loop for chains
                    DrawLine(points.back().x, points.back().y, points[0].x, points[0].y, PURPLE);
                }
                break;
            }
            }

            // Render velocity as a line
            cpVect velocity = cpBodyGetVelocity(collider.body.get());
            DrawLine(position.x, position.y, position.x + velocity.x, position.y + velocity.y, YELLOW);

            // Render angular velocity as a rotating line
            float angle = cpBodyGetAngle(collider.body.get());
            DrawLineEx(
                {(float)position.x, (float)position.y},
                {(float)position.x + 20 * cos(angle), (float)position.y + 20 * sin(angle)},
                2.0f,
                ORANGE);
        }
    }

    /**
     * @brief Guides an entity towards a target point by applying a steering force.
     *
     * This method calculates a desired velocity towards the target position and adjusts
     * the current velocity of the entity by applying a steering force. The resulting
     * movement is smooth and mimics seeking behavior, commonly used in AI and game physics.
     *
     * @param entity The entity whose movement is to be adjusted.
     * @param targetX The X-coordinate of the target position.
     * @param targetY The Y-coordinate of the target position.
     * @param maxSpeed The maximum speed the entity should achieve while seeking.
     *
     * @details
     * - The function computes the desired velocity vector by normalizing the direction
     *   towards the target point and scaling it by `maxSpeed`.
     * - The steering force is calculated as the difference between the desired velocity
     *   and the entity's current velocity.
     * - This steering force is applied to the entity's physics body at its current position.
     * - The behavior creates smooth and realistic seeking motion, often used in steering behaviors
     *   for AI entities.
     *
     * **Key Steps:**
     * 1. Compute the desired velocity towards the target.
     * 2. Calculate the steering force by subtracting the current velocity from the desired velocity.
     * 3. Apply the steering force to the entity's physics body.
     *
     * **Requirements:**
     * - The entity must have a `ColliderComponent` with a valid `cpBody` reference.
     * - Ensure the `ColliderComponent` is registered with the physics `registry`.
     *
     * **Use Cases:**
     * - Guiding AI-controlled entities toward a specific location in the game world.
     * - Implementing behaviors such as flocking, pathfinding, or basic autonomous movement.
     *
     * **Example Usage:**
     * ```cpp
     * // Seek behavior for an entity to move towards the target position (300, 400) with max speed 200
     * physicsWorld.Seek(playerEntity, 300.0f, 400.0f, 200.0f);
     * ```
     *
     * **Related Methods:**
     * - `Arrive`: Gradually slows the entity as it approaches the target.
     * - `Wander`: Randomized movement with steering behaviors.
     *
     * @note
     * This method assumes that the physics body is dynamic and can respond to applied forces.
     * The `maxSpeed` parameter determines the upper limit of the velocity magnitude.
     */
    void PhysicsWorld::Seek(entt::entity entity, float targetX, float targetY, float maxSpeed)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect desiredVelocity = cpvnormalize(cpv(targetX - currentPos.x, targetY - currentPos.y));
        desiredVelocity = cpvmult(desiredVelocity, maxSpeed);

        cpVect currentVelocity = cpBodyGetVelocity(collider.body.get());
        cpVect steeringForce = cpvsub(desiredVelocity, currentVelocity);

        cpBodyApplyForceAtWorldPoint(collider.body.get(), steeringForce, currentPos);
    }

    /**
     * @brief Guides an entity toward a target point while slowing down as it approaches the target.
     *
     * This method implements the "arrive" steering behavior, where an entity accelerates towards
     * a target point and gradually slows down within a specified radius to avoid overshooting
     * or abrupt stops.
     *
     * @param entity The entity whose movement is to be adjusted.
     * @param targetX The X-coordinate of the target position.
     * @param targetY The Y-coordinate of the target position.
     * @param maxSpeed The maximum speed the entity can achieve while moving towards the target.
     * @param slowingRadius The radius around the target where the entity will begin to slow down.
     *
     * @details
     * - The method calculates the distance to the target and adjusts the speed proportionally
     *   if the entity is within the `slowingRadius`.
     * - Outside the `slowingRadius`, the entity moves at `maxSpeed`.
     * - The desired velocity is calculated based on the target position and adjusted speed.
     * - A steering force is then applied to align the entity's velocity with the desired velocity.
     *
     * **Key Steps:**
     * 1. Calculate the vector from the entity's current position to the target (`toTarget`).
     * 2. Determine the speed based on the distance:
     *    - If the distance is greater than the `slowingRadius`, use `maxSpeed`.
     *    - Otherwise, scale the speed proportionally based on the distance.
     * 3. Compute the desired velocity using the adjusted speed and direction to the target.
     * 4. Calculate the steering force as the difference between the desired velocity and the current velocity.
     * 5. Apply the steering force to the entity's physics body at its current position.
     *
     * **Requirements:**
     * - The entity must have a `ColliderComponent` with a valid `cpBody` reference.
     * - Ensure the `ColliderComponent` is registered with the physics `registry`.
     *
     * **Use Cases:**
     * - Smoothly guiding AI entities to a specific location in the game world.
     * - Implementing natural stopping behaviors for vehicles, characters, or projectiles.
     *
     * **Example Usage:**
     * ```cpp
     * // Move the entity towards the point (500, 500) with a max speed of 200 and a slowing radius of 100.
     * physicsWorld.Arrive(playerEntity, 500.0f, 500.0f, 200.0f, 100.0f);
     * ```
     *
     * **Related Methods:**
     * - `Seek`: Guides the entity toward a target point without slowing down.
     * - `Wander`: Adds randomized movement with steering behaviors.
     * - `Separate`: Prevents the entity from clustering with others.
     *
     * @note
     * This method ensures smooth deceleration near the target but does not directly stop the entity
     * unless the desired velocity becomes zero. A separate method may be required for precise stopping.
     */
    void PhysicsWorld::Arrive(entt::entity entity, float targetX, float targetY, float maxSpeed, float slowingRadius)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect toTarget = cpv(targetX - currentPos.x, targetY - currentPos.y);
        float distance = cpvlength(toTarget);

        float speed = maxSpeed;
        if (distance < slowingRadius)
        {
            speed = maxSpeed * (distance / slowingRadius);
        }

        cpVect desiredVelocity = cpvmult(cpvnormalize(toTarget), speed);
        cpVect currentVelocity = cpBodyGetVelocity(collider.body.get());
        cpVect steeringForce = cpvsub(desiredVelocity, currentVelocity);

        cpBodyApplyForceAtWorldPoint(collider.body.get(), steeringForce, currentPos);
    }

    /**
     * @brief Causes an entity to move in a wandering pattern by introducing randomness to its movement direction.
     *
     * This method implements the "wander" steering behavior, where an entity moves in an unpredictable
     * yet smooth trajectory by randomly adjusting its steering direction within a defined range.
     *
     * @param entity The entity to apply the wandering behavior.
     * @param wanderRadius The radius of the imaginary circle around which the entity wanders.
     * @param wanderDistance The forward distance from the entity's current position to the center of the wandering circle.
     * @param jitter The random jitter added to the wander angle in radians.
     * @param maxSpeed The maximum speed the entity can achieve during wandering.
     *
     * @details
     * - The wander behavior is achieved by creating an imaginary circle in front of the entity.
     * - A displacement point on the circle is adjusted by a random jitter each frame, causing the entity
     *   to steer slightly differently each time.
     * - The target point for the entity is the sum of the circle's center and the adjusted displacement point.
     * - The method uses the existing `Seek` function to guide the entity toward the target point on the circle.
     *
     * **Key Steps:**
     * 1. Determine the current position of the entity.
     * 2. Calculate the center of the wandering circle:
     *    - Use the entity's velocity direction and scale it by `wanderDistance`.
     * 3. Calculate a displacement point on the circle:
     *    - Adjust the `wanderAngle` by applying a random jitter.
     *    - Use trigonometric functions to compute the displacement based on the updated angle.
     * 4. Compute the target point by summing the circle center and the displacement.
     * 5. Call the `Seek` method to steer the entity toward the target point with the specified `maxSpeed`.
     *
     * **Requirements:**
     * - The entity must have a `ColliderComponent` with a valid `cpBody` reference.
     * - The entity's velocity must be non-zero for meaningful wandering behavior.
     *
     * **Use Cases:**
     * - Giving AI entities lifelike, exploratory movement patterns.
     * - Simulating animals, vehicles, or characters that roam the game world without specific destinations.
     *
     * **Example Usage:**
     * ```cpp
     * // Apply wandering behavior with a radius of 50, distance of 100, jitter of 0.2, and max speed of 150.
     * physicsWorld.Wander(enemyEntity, 50.0f, 100.0f, 0.2f, 150.0f);
     * ```
     *
     * **Related Methods:**
     * - `Seek`: Guides the entity toward a specific target point.
     * - `Arrive`: Moves the entity to a point with smooth deceleration near the target.
     * - `Separate`: Prevents clustering by steering the entity away from nearby objects.
     *
     * @note
     * The `wanderAngle` is static to ensure continuity in the wandering direction between frames.
     * This method should be called frequently (e.g., every frame) for the effect to appear smooth.
     */
    void PhysicsWorld::Wander(entt::entity entity, float wanderRadius, float wanderDistance, float jitter, float maxSpeed)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        static float wanderAngle = 0.0f;
        wanderAngle += jitter * ((rand() % 200 - 100) / 100.0f); // Random jitter in radians

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect circleCenter = cpvadd(currentPos, cpvmult(cpvnormalize(cpBodyGetVelocity(collider.body.get())), wanderDistance));
        cpVect displacement = cpv(wanderRadius * cos(wanderAngle), wanderRadius * sin(wanderAngle));
        cpVect target = cpvadd(circleCenter, displacement);

        Seek(entity, target.x, target.y, maxSpeed);
    }

    /**
     * @brief Applies a separation force to an entity to prevent it from clustering too closely with other entities.
     *
     * This method implements the "separation" steering behavior, which ensures that an entity maintains a minimum distance
     * from other entities by applying a repulsive force based on proximity.
     *
     * @param entity The entity to apply the separation behavior to.
     * @param others A vector of other entities to check for proximity.
     * @param separationRadius The radius within which the separation force is applied.
     * @param maxForce The maximum force applied to the entity to maintain separation.
     *
     * @details
     * - The separation behavior helps entities avoid overlapping or clustering too closely with others.
     * - The repulsive force is proportional to the inverse of the distance between the entity and others, ensuring stronger
     *   repulsion for closer entities.
     * - The resulting force is a sum of all individual separation forces and is applied as a single steering force to the entity.
     *
     * **Key Steps:**
     * 1. Retrieve the current position of the entity.
     * 2. Initialize the steering vector to zero.
     * 3. Iterate through the `others` list:
     *    - Skip the entity itself.
     *    - Calculate the distance to each other entity.
     *    - If the other entity is within the `separationRadius`, compute a normalized repulsive force.
     *    - Scale the force by the maximum force divided by the distance and add it to the steering vector.
     * 4. Apply the accumulated steering force to the entity's body.
     *
     * **Requirements:**
     * - The `entity` and all entities in `others` must have a `ColliderComponent` with a valid `cpBody` reference.
     * - The method should be called frequently (e.g., every frame) to maintain continuous separation.
     *
     * **Use Cases:**
     * - Preventing AI entities from clustering or overlapping in crowded environments.
     * - Simulating flocking behaviors, where separation is a key component alongside alignment and cohesion.
     * - Ensuring characters, vehicles, or objects maintain a comfortable distance in dynamic scenes.
     *
     * **Example Usage:**
     * ```cpp
     * // Apply separation behavior with a radius of 50 and a maximum force of 200.
     * std::vector<entt::entity> nearbyEntities = {enemy1, enemy2, enemy3};
     * physicsWorld.Separate(playerEntity, nearbyEntities, 50.0f, 200.0f);
     * ```
     *
     * **Related Methods:**
     * - `Align`: Aligns the entity's movement with nearby entities.
     * - `Cohesion`: Moves the entity toward the average position of nearby entities.
     * - `Wander`: Introduces random, lifelike movement to entities.
     *
     * @note
     * The force magnitude is clamped by `maxForce / distance` to ensure that closer entities exert a stronger repulsion.
     * Entities farther than `separationRadius` are ignored in the calculation.
     */

    void PhysicsWorld::Separate(entt::entity entity, const std::vector<entt::entity> &others, float separationRadius, float maxForce)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect steering = cpvzero;

        for (auto other : others)
        {
            if (other == entity)
                continue;

            auto &otherCollider = registry->get<ColliderComponent>(other);
            cpVect otherPos = cpBodyGetPosition(otherCollider.body.get());

            float distance = cpvlength(cpvsub(otherPos, currentPos));
            if (distance < separationRadius)
            {
                cpVect diff = cpvnormalize(cpvsub(currentPos, otherPos));
                steering = cpvadd(steering, cpvmult(diff, maxForce / distance));
            }
        }

        cpBodyApplyForceAtWorldPoint(collider.body.get(), steering, currentPos);
    }

    /**
     * @brief Applies a continuous force to an entity at its current position.
     *
     * This method directly applies a force vector to an entity's physics body, affecting its velocity
     * and enabling dynamic movement. The force is applied at the body's center of mass by default.
     *
     * @param entity The entity to which the force is applied.
     * @param forceX The X-component of the force vector.
     * @param forceY The Y-component of the force vector.
     *
     * @details
     * - Forces are cumulative and directly modify the body's acceleration over time, resulting in
     *   smooth, continuous motion.
     * - The entity must have a `ColliderComponent` that includes a valid `cpBody` reference for the method
     *   to function properly.
     *
     * **Key Steps:**
     * 1. Retrieve the entity's `ColliderComponent` from the registry.
     * 2. Use `cpBodyApplyForceAtWorldPoint` to apply the specified force to the body at its current position.
     *
     * **Use Cases:**
     * - Simulating wind, gravity, or other environmental forces on entities.
     * - Adding dynamic propulsion to characters, vehicles, or projectiles.
     * - Implementing external effects such as explosions or magnetic pulls.
     *
     * **Example Usage:**
     * ```cpp
     * // Apply a force of 100 units in the X direction and 50 units in the Y direction to an entity.
     * physicsWorld.ApplyForce(playerEntity, 100.0f, 50.0f);
     * ```
     *
     * **Related Methods:**
     * - `ApplyImpulse`: Instantly applies an impulse to an entity, altering its velocity immediately.
     * - `SetVelocity`: Directly sets the velocity of an entity's body.
     * - `ApplyTorque`: Applies a rotational force to the entity.
     *
     * @note
     * Unlike an impulse, a force is applied continuously over time. For one-time instantaneous effects, consider using `ApplyImpulse` instead.
     */

    void PhysicsWorld::ApplyForce(entt::entity entity, float forceX, float forceY)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        cpBodyApplyForceAtWorldPoint(collider.body.get(), cpv(forceX, forceY), cpBodyGetPosition(collider.body.get()));
    }

    /**
     * @brief Instantly applies an impulse to an entity at its current position.
     *
     * This method applies a one-time impulse to an entity's physics body, causing an immediate change in its velocity.
     * Unlike forces, which act over time, impulses provide an instantaneous effect on the entity's motion.
     *
     * @param entity The entity to which the impulse is applied.
     * @param impulseX The X-component of the impulse vector.
     * @param impulseY The Y-component of the impulse vector.
     *
     * @details
     * - Impulses are applied at the body's center of mass by default.
     * - The magnitude and direction of the impulse determine how the entity's velocity is modified.
     * - The entity must have a `ColliderComponent` with a valid `cpBody` for the method to execute properly.
     *
     * **Key Steps:**
     * 1. Retrieve the entity's `ColliderComponent` from the registry.
     * 2. Use `cpBodyApplyImpulseAtWorldPoint` to apply the specified impulse to the body at its current position.
     *
     * **Use Cases:**
     * - Simulating instant impacts, such as explosions or collisions.
     * - Adding jump or thrust mechanics to characters or objects.
     * - Implementing projectile launches or quick bursts of movement.
     *
     * **Example Usage:**
     * ```cpp
     * // Apply an impulse of 200 units in the X direction and 100 units in the Y direction to an entity.
     * physicsWorld.ApplyImpulse(playerEntity, 200.0f, 100.0f);
     * ```
     *
     * **Related Methods:**
     * - `ApplyForce`: Applies a continuous force to an entity over time, creating smooth acceleration.
     * - `SetVelocity`: Directly sets the velocity of an entity's body.
     * - `ApplyTorque`: Applies a rotational impulse to the entity.
     *
     * @note
     * Impulses are ideal for scenarios requiring immediate changes in velocity, such as simulating explosions or collisions.
     */
    void PhysicsWorld::ApplyImpulse(entt::entity entity, float impulseX, float impulseY)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        cpBodyApplyImpulseAtWorldPoint(collider.body.get(), cpv(impulseX, impulseY), cpBodyGetPosition(collider.body.get()));
    }

    /**
     * @brief Sets damping on the velocity of a physics body associated with the given entity.
     *
     * This function simulates damping by manually reducing the velocity of the physics body.
     * Damping slows down the motion of the body over time, simulating the effect of air resistance
     * or friction. This method modifies the velocity of the body directly.
     *
     * @param entity The EnTT entity representing the object whose velocity should be damped.
     * @param damping The damping factor to apply. A value between 0.0 (no damping) and 1.0 (full stop).
     *
     * @note Damping is applied as a factor to the velocity. The resulting velocity is calculated as:
     *       dampedVelocity = velocity * (1.0 - damping)
     *       For high damping values (close to 1.0), the velocity will quickly reduce to near zero.
     *
     * @warning This function assumes the damping value is clamped between 0.0 and 1.0.
     * Providing values outside this range may lead to undefined behavior.
     *
     * @example
     * PhysicsWorld physicsWorld;
     * physicsWorld.SetDamping(entity, 0.1f); // Apply 10% damping to the entity's velocity.
     */
    void PhysicsWorld::SetDamping(entt::entity entity, float damping)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        // Apply damping to velocity manually
        cpVect velocity = cpBodyGetVelocity(collider.body.get());
        cpVect dampedVelocity = cpvmult(velocity, 1.0f - damping);
        cpBodySetVelocity(collider.body.get(), dampedVelocity);
    }

    /**
     * @brief Sets global damping for the physics simulation.
     *
     * Global damping affects all bodies in the physics simulation uniformly, reducing their velocities
     * over time. This simulates the effect of a medium, like air or water, that provides resistance
     * to movement. The damping is applied during each physics step.
     *
     * @param damping The damping factor to apply globally. A value between 0.0 (no damping)
     * and 1.0 (full stop).
     *
     * @note The global damping is applied uniformly to all bodies in the physics space.
     * Individual body-specific damping can be applied separately using `SetDamping`.
     *
     * @warning Ensure the damping value is within the range of 0.0 to 1.0. Values outside this range
     * may lead to undefined behavior.
     *
     * @example
     * PhysicsWorld physicsWorld;
     * physicsWorld.SetGlobalDamping(0.2f); // Apply 20% global damping to all physics bodies.
     */
    void PhysicsWorld::SetGlobalDamping(float damping)
    {
        cpSpaceSetDamping(space, damping);
    }

    /**
     * @brief Sets the linear velocity of a specific physics body.
     *
     * This method directly sets the velocity of the body associated with the given entity.
     * The velocity is applied as a vector, with separate components for the x-axis and y-axis.
     *
     * @param entity The EnTT entity whose velocity is being set.
     * @param velocityX The velocity along the x-axis.
     * @param velocityY The velocity along the y-axis.
     *
     * @note This method overrides any existing velocity for the body. Use with caution if
     * other forces or accelerations are being applied to the body, as this will replace them.
     *
     * @example
     * // Set a body to move to the right at 50 units per second.
     * physicsWorld.SetVelocity(myEntity, 50.0f, 0.0f);
     */
    void PhysicsWorld::SetVelocity(entt::entity entity, float velocityX, float velocityY)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        cpBodySetVelocity(collider.body.get(), cpv(velocityX, velocityY));
    }

    /**
     * @brief Aligns an entity's velocity with the average velocity of its neighbors within a given radius.
     *
     * This method calculates the average velocity of all neighboring entities within the specified
     * alignment radius and adjusts the velocity of the target entity to align with this average.
     * A maximum force is applied to limit the steering adjustment, and the adjusted velocity is
     * capped at the specified maximum speed.
     *
     * @param entity The EnTT entity whose velocity is to be aligned.
     * @param others A vector of other entities to consider as neighbors.
     * @param alignRadius The radius within which neighbors influence the alignment.
     * @param maxSpeed The maximum speed for the target entity.
     * @param maxForce The maximum steering force that can be applied to align the velocity.
     *
     * @note This method assumes that all entities in `others` have valid `ColliderComponent` instances
     * and are part of the same physics world. Ensure `alignRadius` is large enough to include relevant
     * neighbors, but not so large as to include distant entities that should not influence alignment.
     *
     * @example
     * // Align the velocity of `myEntity` with nearby entities within a radius of 100 units.
     * physicsWorld.Align(myEntity, nearbyEntities, 100.0f, 200.0f, 50.0f);
     */
    void PhysicsWorld::Align(entt::entity entity, const std::vector<entt::entity> &others, float alignRadius, float maxSpeed, float maxForce)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect averageVelocity = cpvzero;
        int neighborCount = 0;

        for (auto other : others)
        {
            if (other == entity)
                continue;

            auto &otherCollider = registry->get<ColliderComponent>(other);
            cpVect otherPos = cpBodyGetPosition(otherCollider.body.get());

            float distance = cpvlength(cpvsub(otherPos, currentPos));
            if (distance < alignRadius)
            {
                averageVelocity = cpvadd(averageVelocity, cpBodyGetVelocity(otherCollider.body.get()));
                neighborCount++;
            }
        }

        if (neighborCount > 0)
        {
            averageVelocity = cpvmult(averageVelocity, 1.0f / neighborCount);
            cpVect currentVelocity = cpBodyGetVelocity(collider.body.get());
            cpVect steeringForce = cpvsub(averageVelocity, currentVelocity);

            steeringForce = cpvclamp(steeringForce, maxForce);
            cpBodyApplyForceAtWorldPoint(collider.body.get(), steeringForce, currentPos);
        }
    }

    /**
     * @brief Adjusts an entity's position to move closer to the average position of its neighbors within a given radius.
     *
     * This method calculates the average position of all neighboring entities within the specified cohesion radius
     * and applies a steering force to move the target entity toward this average position. The steering behavior
     * ensures that the entity maintains cohesive movement with its neighbors, simulating flocking or group dynamics.
     *
     * @param entity The EnTT entity that needs to exhibit cohesive behavior.
     * @param others A vector of other entities to consider as neighbors.
     * @param cohesionRadius The radius within which neighbors influence cohesion.
     * @param maxSpeed The maximum speed for the entity when moving toward the average position.
     * @param maxForce The maximum steering force applied to adjust the entity's position.
     *
     * @note The cohesion behavior uses the `Seek` method to steer the entity toward the calculated average position.
     * Ensure that `cohesionRadius` is large enough to include relevant neighbors but not too large to incorporate
     * distant entities that should not influence cohesion.
     *
     * @example
     * // Move `myEntity` closer to nearby entities within a radius of 50 units.
     * physicsWorld.Cohesion(myEntity, nearbyEntities, 50.0f, 150.0f, 30.0f);
     */
    void PhysicsWorld::Cohesion(entt::entity entity, const std::vector<entt::entity> &others, float cohesionRadius, float maxSpeed, float maxForce)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect averagePosition = cpvzero;
        int neighborCount = 0;

        for (auto other : others)
        {
            if (other == entity)
                continue;

            auto &otherCollider = registry->get<ColliderComponent>(other);
            cpVect otherPos = cpBodyGetPosition(otherCollider.body.get());

            float distance = cpvlength(cpvsub(otherPos, currentPos));
            if (distance < cohesionRadius)
            {
                averagePosition = cpvadd(averagePosition, otherPos);
                neighborCount++;
            }
        }

        if (neighborCount > 0)
        {
            averagePosition = cpvmult(averagePosition, 1.0f / neighborCount);
            Seek(entity, averagePosition.x, averagePosition.y, maxSpeed); // Seek method already exists in your implementation
        }
    }

    /**
     * @brief Ensures an entity stays above a specified vertical boundary by applying a corrective force.
     *
     * This method checks if the entity's position is below the given vertical boundary (`minY`).
     * If it is, a proportional upward force is applied to push the entity back above the boundary.
     * This can be used to implement boundaries for gameplay areas or keep objects within a defined region.
     *
     * @param entity The EnTT entity to enforce the boundary on.
     * @param minY The minimum vertical position (y-coordinate) the entity is allowed to move below.
     *
     * @note The force applied is proportional to the distance the entity has moved below the boundary,
     * creating a smooth corrective behavior.
     *
     * @example
     * // Prevent `myEntity` from falling below y = 100.
     * physicsWorld.EnforceBoundary(myEntity, 100.0f);
     */
    void PhysicsWorld::EnforceBoundary(entt::entity entity, float minY)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect position = cpBodyGetPosition(collider.body.get());
        if (position.y > minY)
        {
            cpVect force = cpv(0, -1000 * (position.y - minY)); // Apply a force proportional to the displacement
            cpBodyApplyForceAtWorldPoint(collider.body.get(), force, position);
        }
    }

    /**
     * @brief Accelerates an entity toward the current position of the mouse pointer.
     *
     * This method calculates the direction from the entity to the mouse position and applies an acceleration force
     * toward that direction. The resulting velocity is clamped to a specified maximum speed.
     *
     * @param entity The EnTT entity to apply the acceleration to.
     * @param acceleration The magnitude of the acceleration force to be applied.
     * @param maxSpeed The maximum speed the entity can achieve while moving toward the mouse position.
     *
     * @note This method requires the use of the `AccelerateTowardAngle` function, which handles acceleration toward
     * a specific angle.
     *
     * @example
     * // Accelerate `myEntity` toward the mouse pointer with an acceleration of 500 units and a max speed of 250 units.
     * physicsWorld.AccelerateTowardMouse(myEntity, 500.0f, 250.0f);
     */
    void PhysicsWorld::AccelerateTowardMouse(entt::entity entity, float acceleration, float maxSpeed)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        Vector2 mousePos = GetMousePosition(); // Assuming Raylib is used
        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect toMouse = cpv(mousePos.x - currentPos.x, mousePos.y - currentPos.y);
        float angle = atan2(toMouse.y, toMouse.x);

        AccelerateTowardAngle(entity, angle, acceleration, maxSpeed); // Assuming AccelerateTowardAngle exists
    }

    /**
     * @brief Accelerates an entity toward the position of another target entity.
     *
     * This method calculates the direction from the given entity to the target entity and applies an acceleration force
     * in that direction. The resulting velocity is clamped to a specified maximum speed.
     *
     * @param entity The EnTT entity to apply the acceleration to.
     * @param target The target EnTT entity toward which the acceleration is applied.
     * @param acceleration The magnitude of the acceleration force to be applied.
     * @param maxSpeed The maximum speed the entity can achieve while moving toward the target.
     *
     * @note This method requires the use of the `AccelerateTowardAngle` function, which handles acceleration toward
     * a specific angle.
     *
     * @example
     * // Accelerate `myEntity` toward `targetEntity` with an acceleration of 500 units and a max speed of 300 units.
     * physicsWorld.AccelerateTowardObject(myEntity, targetEntity, 500.0f, 300.0f);
     */
    void PhysicsWorld::AccelerateTowardObject(entt::entity entity, entt::entity target, float acceleration, float maxSpeed)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        auto &targetCollider = registry->get<ColliderComponent>(target);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect targetPos = cpBodyGetPosition(targetCollider.body.get());
        cpVect toTarget = cpv(targetPos.x - currentPos.x, targetPos.y - currentPos.y);
        float angle = atan2(toTarget.y, toTarget.x);

        AccelerateTowardAngle(entity, angle, acceleration, maxSpeed);
    }

    /**
     * @brief Moves an entity at a specified speed in a given direction (angle).
     *
     * This method calculates the velocity vector based on the provided angle and speed,
     * then applies it directly to the entity's body. The entity will move along a straight line
     * in the specified direction at the given speed.
     *
     * @param entity The EnTT entity to move.
     * @param angle The direction in which the entity should move, specified in radians.
     * @param speed The magnitude of the speed at which the entity should move.
     *
     * @note This method overrides the entity's current velocity with the newly calculated velocity.
     * Use this method for scenarios like projectiles or constant motion in a given direction.
     *
     * @example
     * // Move `myEntity` at 200 units per second toward a 45-degree angle.
     * physicsWorld.MoveTowardAngle(myEntity, M_PI / 4, 200.0f);
     */
    void PhysicsWorld::MoveTowardAngle(entt::entity entity, float angle, float speed)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        float velocityX = speed * cos(angle);
        float velocityY = speed * sin(angle);
        cpBodySetVelocity(collider.body.get(), cpv(velocityX, velocityY));
    }

    /**
     * @brief Rotates an entity toward the position of a target entity using a linear interpolation value.
     *
     * This method computes the angle between the entity's current position and the target's position,
     * then adjusts the entity's current angle toward the target angle using the specified lerp value.
     *
     * @param entity The EnTT entity to rotate.
     * @param target The EnTT target entity toward which the rotation is performed.
     * @param lerpValue The interpolation value controlling the speed of rotation.
     *                  A value closer to 1 rotates the entity faster, while lower values create a slower, smoother rotation.
     *
     * @note This method is useful for implementing behaviors like homing projectiles, AI entities aiming at a target,
     * or orienting objects in a physics simulation toward a goal.
     *
     * @example
     * // Rotate `entity` toward `target` with a smooth interpolation of 0.1.
     * physicsWorld.RotateTowardObject(entity, target, 0.1f);
     */
    void PhysicsWorld::RotateTowardObject(entt::entity entity, entt::entity target, float lerpValue)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        auto &targetCollider = registry->get<ColliderComponent>(target);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect targetPos = cpBodyGetPosition(targetCollider.body.get());
        float targetAngle = atan2(targetPos.y - currentPos.y, targetPos.x - currentPos.x);

        float currentAngle = cpBodyGetAngle(collider.body.get());
        float newAngle = currentAngle + lerpValue * (targetAngle - currentAngle);
        cpBodySetAngle(collider.body.get(), newAngle);
    }

    /**
     * @brief Rotates an entity toward a specific point using a linear interpolation value.
     *
     * This method calculates the angle between the entity's current position and a target point,
     * then adjusts the entity's current angle toward the target angle using the specified lerp value.
     *
     * @param entity The EnTT entity to rotate.
     * @param targetX The X-coordinate of the target point.
     * @param targetY The Y-coordinate of the target point.
     * @param lerpValue The interpolation value controlling the speed of rotation.
     *                  A value closer to 1 rotates the entity faster, while lower values create a slower, smoother rotation.
     *
     * @note This method is useful for aligning entities toward a fixed point, such as in aiming mechanics
     * or orienting objects in a physics simulation toward a static target.
     *
     * @example
     * // Rotate `entity` toward point (100.0f, 200.0f) with a smooth interpolation of 0.05.
     * physicsWorld.RotateTowardPoint(entity, 100.0f, 200.0f, 0.05f);
     */
    void PhysicsWorld::RotateTowardPoint(entt::entity entity, float targetX, float targetY, float lerpValue)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        float targetAngle = atan2(targetY - currentPos.y, targetX - currentPos.x);

        float currentAngle = cpBodyGetAngle(collider.body.get());
        float newAngle = currentAngle + lerpValue * (targetAngle - currentAngle);
        cpBodySetAngle(collider.body.get(), newAngle);
    }

    /**
     * @brief Rotates an entity toward the current mouse position using a linear interpolation value.
     *
     * This method calculates the angle between the entity's current position and the mouse position,
     * then adjusts the entity's current angle toward the target angle using the specified lerp value.
     *
     * @param entity The EnTT entity to rotate.
     * @param lerpValue The interpolation value controlling the speed of rotation.
     *                  A value closer to 1 rotates the entity faster, while lower values create a slower, smoother rotation.
     *
     * @note This method assumes that the mouse position is retrieved using Raylib's `GetMousePosition` function
     * and is appropriate for 2D scenarios where the entity needs to follow or aim toward the mouse.
     *
     * @example
     * // Rotate `entity` smoothly toward the mouse position with a lerp value of 0.1.
     * physicsWorld.RotateTowardMouse(entity, 0.1f);
     */
    void PhysicsWorld::RotateTowardMouse(entt::entity entity, float lerpValue)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        Vector2 mousePos = GetMousePosition(); // Assuming Raylib is used
        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        float targetAngle = atan2(mousePos.y - currentPos.y, mousePos.x - currentPos.x);

        float currentAngle = cpBodyGetAngle(collider.body.get());
        float newAngle = currentAngle + lerpValue * (targetAngle - currentAngle);
        cpBodySetAngle(collider.body.get(), newAngle);
    }

    /**
     * @brief Rotates an entity toward the direction of its current velocity using linear interpolation.
     *
     * This method calculates the angle of the entity's velocity vector and adjusts the entity's current
     * angle toward this target angle using the specified lerp value.
     *
     * @param entity The EnTT entity to rotate.
     * @param lerpValue The interpolation value controlling the speed of rotation.
     *                  Higher values result in faster rotation, while lower values create smoother, slower rotation.
     *
     * @note This method assumes that the entity has a valid velocity. If the velocity vector length is zero,
     * the method does nothing.
     *
     * @example
     * // Rotate the entity smoothly toward its velocity direction with a lerp value of 0.1.
     * physicsWorld.RotateTowardVelocity(entity, 0.1f);
     */
    void PhysicsWorld::RotateTowardVelocity(entt::entity entity, float lerpValue)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect velocity = cpBodyGetVelocity(collider.body.get());
        if (cpvlength(velocity) > 0)
        {
            float targetAngle = atan2(velocity.y, velocity.x);

            float currentAngle = cpBodyGetAngle(collider.body.get());
            float newAngle = currentAngle + lerpValue * (targetAngle - currentAngle);
            cpBodySetAngle(collider.body.get(), newAngle);
        }
    }

    /**
     * @brief Accelerates an entity in a specified direction while clamping its velocity to a maximum speed.
     *
     * This method applies a force to the entity's body in the direction specified by the angle. It also ensures
     * that the resulting velocity does not exceed the maximum speed by clamping it.
     *
     * @param entity The EnTT entity to accelerate.
     * @param angle The direction of acceleration in radians. The angle is measured counterclockwise from the positive x-axis.
     * @param acceleration The magnitude of the force to be applied in the specified direction.
     * @param maxSpeed The maximum speed the entity is allowed to reach. If the resulting velocity exceeds this limit,
     *                 it is clamped to the maximum speed.
     *
     * @note The method assumes the entity has a valid `ColliderComponent` and that its body has already been added to the physics space.
     *
     * @example
     * // Accelerate the entity at a 45-degree angle with a force of 100 units and a max speed of 200 units.
     * physicsWorld.AccelerateTowardAngle(entity, M_PI / 4, 100.0f, 200.0f);
     */
    void PhysicsWorld::AccelerateTowardAngle(entt::entity entity, float angle, float acceleration, float maxSpeed)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect force = cpv(acceleration * cos(angle), acceleration * sin(angle));
        cpBodyApplyForceAtWorldPoint(collider.body.get(), force, cpBodyGetPosition(collider.body.get()));

        // Clamp velocity
        cpVect velocity = cpBodyGetVelocity(collider.body.get());
        float speed = cpvlength(velocity);
        if (speed > maxSpeed)
        {
            cpVect clampedVelocity = cpvmult(cpvnormalize(velocity), maxSpeed);
            cpBodySetVelocity(collider.body.get(), clampedVelocity);
        }
    }

    /**
     * @brief Accelerates an entity toward a specified target point, limiting its velocity to a maximum speed.
     *
     * This method calculates the direction from the entity's current position to the target point and applies
     * a force in that direction. The resulting velocity is clamped to the specified maximum speed.
     *
     * @param entity The EnTT entity to accelerate.
     * @param targetX The x-coordinate of the target point.
     * @param targetY The y-coordinate of the target point.
     * @param acceleration The magnitude of the force to apply toward the target.
     * @param maxSpeed The maximum speed the entity is allowed to reach. If the resulting velocity exceeds this limit,
     *                 it is clamped to the maximum speed.
     *
     * @note The method assumes the entity has a valid `ColliderComponent` and that its body has already been added to the physics space.
     * @note This method relies on the `AccelerateTowardAngle` method to handle the actual acceleration and velocity clamping.
     *
     * @example
     * // Accelerate the entity toward the point (100, 200) with a force of 150 units and a max speed of 300 units.
     * physicsWorld.AccelerateTowardPoint(entity, 100.0f, 200.0f, 150.0f, 300.0f);
     */
    void PhysicsWorld::AccelerateTowardPoint(entt::entity entity, float targetX, float targetY, float acceleration, float maxSpeed)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        cpVect toTarget = cpv(targetX - currentPos.x, targetY - currentPos.y);
        float angle = atan2(toTarget.y, toTarget.x);

        AccelerateTowardAngle(entity, angle, acceleration, maxSpeed);
    }

    /**
     * @brief Moves an entity toward a specified target point at a given speed or within a specified maximum time.
     *
     * This method calculates the direction from the entity's current position to the target point and sets
     * its velocity to move toward the point. If `maxTime` is specified, the speed is adjusted to ensure the
     * entity reaches the target within the given time.
     *
     * @param entity The EnTT entity to move.
     * @param targetX The x-coordinate of the target point.
     * @param targetY The y-coordinate of the target point.
     * @param speed The desired speed of the entity. If `maxTime` is provided, this value is recalculated based on the distance.
     * @param maxTime The maximum time (in seconds) for the entity to reach the target. If set to 0, the provided speed is used.
     *
     * @note This method directly sets the velocity of the entity's physics body and does not account for acceleration or deceleration.
     *
     * @example
     * // Move the entity toward the point (300, 400) at a speed of 100 units per second.
     * physicsWorld.MoveTowardPoint(entity, 300.0f, 400.0f, 100.0f, 0.0f);
     *
     * // Move the entity toward the point (300, 400) and ensure it reaches the target in 2 seconds.
     * physicsWorld.MoveTowardPoint(entity, 300.0f, 400.0f, 0.0f, 2.0f);
     */
    void PhysicsWorld::MoveTowardPoint(entt::entity entity, float targetX, float targetY, float speed, float maxTime)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect currentPos = cpBodyGetPosition(collider.body.get());
        float distance = cpvlength(cpvsub(cpv(targetX, targetY), currentPos));

        if (maxTime > 0)
        {
            speed = distance / maxTime; // Calculate speed to reach in maxTime
        }

        cpVect direction = cpvnormalize(cpv(targetX - currentPos.x, targetY - currentPos.y));
        cpVect velocity = cpvmult(direction, speed);
        cpBodySetVelocity(collider.body.get(), velocity);
    }

    /**
     * @brief Moves an entity toward the current mouse position at a specified speed or within a given maximum time.
     *
     * This method retrieves the current mouse position (using Raylib's `GetMousePosition`) and calculates
     * the direction from the entity's position to the mouse. It then calls `MoveTowardPoint` to set the velocity
     * for moving toward the mouse position.
     *
     * @param entity The EnTT entity to move.
     * @param speed The desired speed of the entity. If `maxTime` is provided, this value is recalculated based on the distance.
     * @param maxTime The maximum time (in seconds) for the entity to reach the mouse position. If set to 0, the provided speed is used.
     *
     * @note This method directly modifies the velocity of the entity's physics body and does not account for acceleration or deceleration.
     *
     * @example
     * // Move the entity toward the mouse position at a speed of 100 units per second.
     * physicsWorld.MoveTowardMouse(entity, 100.0f, 0.0f);
     *
     * // Move the entity toward the mouse position and ensure it reaches the target in 1.5 seconds.
     * physicsWorld.MoveTowardMouse(entity, 0.0f, 1.5f);
     */
    void PhysicsWorld::MoveTowardMouse(entt::entity entity, float speed, float maxTime)
    {
        Vector2 mousePos = GetMousePosition(); // Assuming Raylib is used
        MoveTowardPoint(entity, mousePos.x, mousePos.y, speed, maxTime);
    }

    /**
     * @brief Locks the vertical movement of an entity, allowing it to move only horizontally.
     *
     * This method retrieves the current velocity of the entity and sets the vertical velocity component to zero,
     * effectively locking the entity's movement along the vertical axis.
     *
     * @param entity The EnTT entity whose vertical movement is to be locked.
     *
     * @note This method modifies the velocity of the physics body directly. It does not affect acceleration or forces applied to the body,
     *       but any applied vertical force will result in no vertical movement.
     *
     * @example
     * // Lock the vertical movement of the entity.
     * physicsWorld.LockHorizontally(entity);
     *
     * @see LockVertically
     */
    void PhysicsWorld::LockHorizontally(entt::entity entity)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect velocity = cpBodyGetVelocity(collider.body.get());
        cpBodySetVelocity(collider.body.get(), cpv(velocity.x, 0)); // Maintain horizontal velocity only
    }

    /**
     * @brief Locks the horizontal movement of an entity, allowing it to move only vertically.
     *
     * This method retrieves the current velocity of the entity and sets the horizontal velocity component to zero,
     * effectively locking the entity's movement along the horizontal axis.
     *
     * @param entity The EnTT entity whose horizontal movement is to be locked.
     *
     * @note This method modifies the velocity of the physics body directly. It does not affect acceleration or forces applied to the body,
     *       but any applied horizontal force will result in no horizontal movement.
     *
     * @example
     * // Lock the horizontal movement of the entity.
     * physicsWorld.LockVertically(entity);
     *
     * @see LockHorizontally
     */
    void PhysicsWorld::LockVertically(entt::entity entity)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect velocity = cpBodyGetVelocity(collider.body.get());
        cpBodySetVelocity(collider.body.get(), cpv(0, velocity.y)); // Maintain vertical velocity only
    }

    /**
     * @brief Sets the angular velocity of an entity's physics body.
     *
     * This method directly updates the angular velocity of the specified entity, allowing it to rotate at a specified rate.
     * Angular velocity is measured in radians per second.
     *
     * @param entity The EnTT entity whose angular velocity is to be set.
     * @param angularVelocity The desired angular velocity in radians per second.
     *
     * @note This method overrides any current angular velocity and does not take into account any torque
     *       or angular damping applied to the entity's physics body.
     *
     * @example
     * // Set the entity to rotate at π/2 radians per second (90 degrees per second).
     * physicsWorld.SetAngularVelocity(entity, M_PI / 2.0f);
     *
     * @see ApplyAngularImpulse, SetAngularDamping
     */
    void PhysicsWorld::SetAngularVelocity(entt::entity entity, float angularVelocity)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        cpBodySetAngularVelocity(collider.body.get(), angularVelocity);
    }

    /**
     * @brief Applies angular damping to an entity's rotational movement.
     *
     * This function reduces the angular velocity of the specified entity's physics body by a specified damping factor.
     * Since Chipmunk 2D does not directly support angular damping, this implementation applies the effect manually
     * by scaling the angular velocity on each call.
     *
     * @param entity The entity whose angular damping will be applied.
     * @param angularDamping A factor between 0.0f and 1.0f that determines the damping effect.
     *                       A value of 0.0f results in no damping, while 1.0f applies full damping (stops rotation instantly).
     *
     * @note This method is typically called every frame or physics update to create a continuous damping effect.
     *       The damping factor should be small (e.g., 0.01f) to avoid abrupt changes in angular velocity.
     *
     * @example
     * // Apply light angular damping to an entity
     * SetAngularDamping(entity, 0.02f);
     *
     * // Apply heavy damping to quickly stop an entity's rotation
     * SetAngularDamping(entity, 0.5f);
     */
    void PhysicsWorld::SetAngularDamping(entt::entity entity, float angularDamping)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        // Retrieve the current angular velocity
        float angularVelocity = cpBodyGetAngularVelocity(collider.body.get());

        // Apply damping by reducing angular velocity proportionally
        float dampedAngularVelocity = angularVelocity * (1.0f - angularDamping);

        // Set the updated angular velocity
        cpBodySetAngularVelocity(collider.body.get(), dampedAngularVelocity);
    }

    /**
     * @brief Retrieves the current angle (rotation) of the specified entity in radians.
     *
     * This function accesses the physics body associated with the specified entity
     * and returns its current rotation angle in radians. The angle represents the orientation
     * of the body in the 2D space relative to the x-axis.
     *
     * @param entity The entity whose rotation angle is to be retrieved.
     * @return float The angle of the entity in radians.
     *
     * @note The angle is measured in radians. To convert it to degrees, use a conversion factor:
     *       degrees = radians * (180.0 / M_PI).
     *
     * @example
     * // Get the current angle of an entity
     * float angle = GetAngle(entity);
     *
     * // Convert the angle to degrees
     * float angleInDegrees = angle * (180.0f / M_PI);
     */
    float PhysicsWorld::GetAngle(entt::entity entity)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        return cpBodyGetAngle(collider.body.get());
    }

    /**
     * @brief Sets the rotation angle of the specified entity in radians.
     *
     * This function updates the angle (orientation) of the physics body associated with the specified entity.
     * The angle determines the body's rotation in 2D space relative to the x-axis.
     *
     * @param entity The entity whose rotation angle is to be set.
     * @param angle The new angle in radians.
     *
     * @note
     * - The angle is measured in radians. To convert from degrees to radians, use a conversion factor:
     *   radians = degrees * (M_PI / 180.0).
     * - Directly setting the angle may conflict with ongoing physics interactions. Use this carefully to avoid
     *   unexpected behavior during simulation.
     *
     * @example
     * // Set the angle of an entity to 45 degrees
     * float angleInRadians = 45.0f * (M_PI / 180.0f);
     * SetAngle(entity, angleInRadians);
     */
    void PhysicsWorld::SetAngle(entt::entity entity, float angle)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        cpBodySetAngle(collider.body.get(), angle);
    }

    /**
     * @brief Sets the restitution (bounciness) of the specified entity's collider.
     *
     * Restitution determines how much kinetic energy is conserved during a collision. A higher value means
     * the object will bounce more after a collision, while a lower value reduces the bounce effect.
     *
     * @param entity The entity whose collider's restitution is to be set.
     * @param restitution The restitution value. This should typically be between 0.0 (no bounce) and 1.0 (perfect bounce).
     *
     * @note
     * - Values greater than 1.0 can cause exaggerated bouncing effects but may lead to unstable physics behavior.
     * - Setting the restitution does not affect ongoing collisions; it only applies to future collisions.
     *
     * @example
     * // Set the restitution of an entity to a bouncy value
     * SetRestitution(entity, 0.8f);
     */
    void PhysicsWorld::SetRestitution(entt::entity entity, float restitution)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        cpShapeSetElasticity(collider.shape.get(), restitution);
    }

    /**
     * @brief Sets the friction of the specified entity's collider.
     *
     * Friction determines how much resistance the collider has when sliding against another surface.
     * A higher value increases resistance to motion, while a lower value reduces resistance.
     *
     * @param entity The entity whose collider's friction is to be set.
     * @param friction The friction coefficient. Typical values range from 0.0 (no friction) to 1.0 (high friction).
     * Values greater than 1.0 are possible for extra resistance.
     *
     * @note
     * - Friction is a multiplicative property between two colliders during contact. The combined friction is determined by both colliders' friction coefficients.
     * - Setting friction affects future physics interactions and does not retroactively modify ongoing collisions.
     *
     * @example
     * // Set the friction of an entity to simulate a slippery surface
     * SetFriction(entity, 0.2f);
     *
     * // Set the friction of an entity to simulate a rough surface
     * SetFriction(entity, 1.0f);
     */
    void PhysicsWorld::SetFriction(entt::entity entity, float friction)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        cpShapeSetFriction(collider.shape.get(), friction);
    }

    /**
     * @brief Applies an angular impulse to the specified entity's collider.
     *
     * This method directly modifies the angular velocity of the collider by calculating the
     * effect of the given angular impulse using the collider's moment of inertia.
     *
     * @param entity The entity whose collider receives the angular impulse.
     * @param angularImpulse The angular impulse to be applied, measured in units of angular momentum (e.g., N·m·s).
     *
     * @note
     * - The angular impulse results in an instantaneous change in the angular velocity of the body.
     * - The body's moment of inertia must be non-zero for this calculation to work as expected.
     *
     * @example
     * // Apply an angular impulse to spin the entity
     * ApplyAngularImpulse(entity, 10.0f);
     */
    void PhysicsWorld::ApplyAngularImpulse(entt::entity entity, float angularImpulse)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        // Retrieve the body's moment of inertia
        float momentOfInertia = cpBodyGetMoment(collider.body.get());

        if (momentOfInertia != 0)
        {
            // Calculate the change in angular velocity from the impulse
            float deltaAngularVelocity = angularImpulse / momentOfInertia;

            // Apply the change to the current angular velocity
            float currentAngularVelocity = cpBodyGetAngularVelocity(collider.body.get());
            cpBodySetAngularVelocity(collider.body.get(), currentAngularVelocity + deltaAngularVelocity);
        }
    }

    /**
     * @brief Sets the specified entity's collider to an awake or sleeping state.
     *
     * This method allows you to manually control the activation state of a body in the physics simulation.
     * If the body is set to awake, it will participate in the simulation. If set to sleep, it will be excluded
     * from the simulation until explicitly reactivated or affected by external forces.
     *
     * @param entity The entity whose collider's awake state is being set.
     * @param awake A boolean indicating the desired awake state:
     *              - `true`: Activate the body, making it part of the simulation.
     *              - `false`: Put the body to sleep, excluding it from simulation until reactivated.
     *
     * @note
     * - Awake bodies are actively simulated and may interact with other objects in the world.
     * - Sleeping bodies are idle and do not consume processing resources.
     * - A sleeping body will automatically wake up if touched by another active body or explicitly activated.
     *
     * @example
     * // Put an entity's body to sleep
     * SetAwake(entity, false);
     *
     * // Activate an entity's body for simulation
     * SetAwake(entity, true);
     */
    void PhysicsWorld::SetAwake(entt::entity entity, bool awake)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        if (awake)
        {
            cpBodyActivate(collider.body.get());
        }
        else
        {
            cpBodySleep(collider.body.get());
        }
    }

    /**
     * @brief Retrieves the current position of the specified entity's collider in the physics world.
     *
     * This method returns the position of the body associated with the specified entity as a `cpVect`,
     * representing the coordinates in the physics world. The position is typically in the simulation's
     * coordinate system.
     *
     * @param entity The entity whose collider's position is being retrieved.
     * @return cpVect The position of the entity's collider in the format `{x, y}`.
     *
     * @note
     * - The position is relative to the physics world and may differ from other game-world coordinate systems
     *   if a transformation or scaling factor is applied.
     * - Useful for determining the precise location of an entity during simulation.
     *
     * @example
     * // Get the position of an entity's collider
     * cpVect position = GetPosition(entity);
     * std::cout << "Position: (" << position.x << ", " << position.y << ")\n";
     */
    cpVect PhysicsWorld::GetPosition(entt::entity entity)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        return cpBodyGetPosition(collider.body.get());
    }

    /**
     * @brief Sets the position of the specified entity's collider in the physics world.
     *
     * This method updates the position of the body associated with the given entity to the specified coordinates.
     * It directly modifies the collider's position, effectively "teleporting" the entity in the physics simulation.
     *
     * @param entity The entity whose collider's position is being set.
     * @param x The new x-coordinate for the collider.
     * @param y The new y-coordinate for the collider.
     *
     * @note
     * - This operation does not affect the body's velocity or acceleration, and may cause unexpected behavior
     *   if the entity is part of an active simulation (e.g., collisions or forces).
     * - Avoid using this function frequently during simulation as it bypasses the physics engine's continuous
     *   motion calculations.
     *
     * @example
     * // Set the position of an entity's collider
     * SetPosition(entity, 100.0f, 200.0f);
     */
    void PhysicsWorld::SetPosition(entt::entity entity, float x, float y)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        cpBodySetPosition(collider.body.get(), cpv(x, y));
    }

    /**
     * @brief Moves the specified entity's collider horizontally toward the mouse position.
     *
     * This method adjusts the collider's horizontal velocity to move it toward the x-coordinate of the mouse
     * position. The vertical velocity remains unaffected.
     *
     * @param entity The entity whose collider is being moved.
     * @param speed The desired horizontal speed. If `maxTime` is provided, this value will be overridden.
     * @param maxTime The time (in seconds) within which the entity should reach the mouse's x-coordinate.
     *                If set to a value greater than 0, it calculates the speed required to reach the target
     *                within the specified time.
     *
     * @note
     * - If the mouse position's x-coordinate is already close to the entity's position, the calculated speed
     *   will be small, resulting in slower movement.
     * - The vertical velocity of the entity is preserved during this operation.
     *
     * @example
     * // Move an entity horizontally toward the mouse at a constant speed of 5.0f units per second
     * MoveTowardsMouseHorizontally(entity, 5.0f, 0.0f);
     *
     * @example
     * // Move an entity horizontally toward the mouse within 2 seconds, regardless of the distance
     * MoveTowardsMouseHorizontally(entity, 0.0f, 2.0f);
     */
    void PhysicsWorld::MoveTowardsMouseHorizontally(entt::entity entity, float speed, float maxTime)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect position = cpBodyGetPosition(collider.body.get());
        cpVect mousePosition = {static_cast<cpFloat>(GetMouseX()), static_cast<cpFloat>(GetMouseY())};

        if (maxTime > 0.0f)
        {
            float distance = fabs(mousePosition.x - position.x); // Only horizontal distance
            speed = distance / maxTime;
        }

        float angle = atan2(mousePosition.y - position.y, mousePosition.x - position.x);
        cpVect velocity = cpBodyGetVelocity(collider.body.get());
        cpVect newVelocity = {speed * cos(angle), velocity.y};

        cpBodySetVelocity(collider.body.get(), newVelocity);
    }

    /**
     * @brief Moves the specified entity's collider vertically toward the mouse position.
     *
     * This method adjusts the collider's vertical velocity to move it toward the y-coordinate of the mouse
     * position. The horizontal velocity remains unaffected.
     *
     * @param entity The entity whose collider is being moved.
     * @param speed The desired vertical speed. If `maxTime` is provided, this value will be overridden.
     * @param maxTime The time (in seconds) within which the entity should reach the mouse's y-coordinate.
     *                If set to a value greater than 0, it calculates the speed required to reach the target
     *                within the specified time.
     *
     * @note
     * - If the mouse position's y-coordinate is already close to the entity's position, the calculated speed
     *   will be small, resulting in slower movement.
     * - The horizontal velocity of the entity is preserved during this operation.
     *
     * @example
     * // Move an entity vertically toward the mouse at a constant speed of 5.0f units per second
     * MoveTowardsMouseVertically(entity, 5.0f, 0.0f);
     *
     * @example
     * // Move an entity vertically toward the mouse within 2 seconds, regardless of the distance
     * MoveTowardsMouseVertically(entity, 0.0f, 2.0f);
     */
    void PhysicsWorld::MoveTowardsMouseVertically(entt::entity entity, float speed, float maxTime)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        cpVect position = cpBodyGetPosition(collider.body.get());
        cpVect mousePosition = {static_cast<cpFloat>(GetMouseX()), static_cast<cpFloat>(GetMouseY())};

        if (maxTime > 0.0f)
        {
            float distance = fabs(mousePosition.y - position.y); // Only vertical distance
            speed = distance / maxTime;
        }

        float angle = atan2(mousePosition.y - position.y, mousePosition.x - position.x);
        cpVect velocity = cpBodyGetVelocity(collider.body.get());
        cpVect newVelocity = {velocity.x, speed * sin(angle)};

        cpBodySetVelocity(collider.body.get(), newVelocity);
    }

    /**
     * @brief Applies a torque to the specified entity's collider.
     *
     * This method simulates the effect of torque on a rigid body by applying balanced forces at offset points
     * relative to the body's center of mass.
     *
     * @param entity The entity whose collider the torque is applied to.
     * @param torque The amount of torque to apply. Positive values apply counterclockwise torque, and negative
     *               values apply clockwise torque.
     *
     * @note
     * - This implementation approximates torque using force vectors, as Chipmunk2D does not provide a
     *   direct function for applying torque.
     * - Ensure the body's mass and moment of inertia are set correctly for accurate torque effects.
     *
     * @example
     * // Apply a torque of 100.0f to an entity
     * ApplyTorque(entity, 100.0f);
     */
    void PhysicsWorld::ApplyTorque(entt::entity entity, float torque)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        // Calculate positions to apply force for simulating torque
        cpVect position = cpBodyGetPosition(collider.body.get());
        cpVect offset = cpv(1.0, 0.0);                          // Offset vector (arbitrary, must not be zero)
        cpVect clockwiseForce = cpvmult(offset, -torque);       // Force in one direction
        cpVect counterClockwiseForce = cpvmult(offset, torque); // Force in the opposite direction

        // Apply the forces at the appropriate points to create a torque effect
        cpVect clockwisePoint = cpvadd(position, offset);
        cpVect counterClockwisePoint = cpvsub(position, offset);

        cpBodyApplyForceAtWorldPoint(collider.body.get(), clockwiseForce, clockwisePoint);
        cpBodyApplyForceAtWorldPoint(collider.body.get(), counterClockwiseForce, counterClockwisePoint);
    }

    /**
     * @brief Retrieves the mass of the specified entity's collider.
     *
     * This function returns the mass of the body associated with the specified entity's collider.
     *
     * @param entity The entity whose collider's mass is to be retrieved.
     * @return float The mass of the collider in units defined by the physics world.
     *
     * @note
     * - The mass is defined when the collider is created. It is used in calculations for dynamics such
     *   as acceleration and force.
     * - Ensure that the collider has been initialized and properly set up in the physics world before
     *   calling this function.
     *
     * @example
     * // Retrieve and print the mass of an entity's collider
     * float mass = GetMass(entity);
     * std::cout << "Collider mass: " << mass << std::endl;
     */
    float PhysicsWorld::GetMass(entt::entity entity)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        return cpBodyGetMass(collider.body.get());
    }

    /**
     * @brief Sets the mass of the specified entity's collider.
     *
     * This function updates the mass of the body associated with the specified entity's collider.
     * Changing the mass affects the physics calculations, including acceleration and force interactions.
     *
     * @param entity The entity whose collider's mass is to be updated.
     * @param mass The new mass value to be assigned to the collider.
     *
     * @note
     * - A mass of `0` or a negative value may cause unexpected behavior, depending on the physics engine's
     *   implementation. Ensure the mass is a positive, non-zero value unless intentionally setting it for a specific effect.
     * - Changing the mass of a dynamic body at runtime can impact the stability of the physics simulation.
     *
     * @example
     * // Set a new mass for an entity's collider
     * SetMass(entity, 5.0f);
     */
    void PhysicsWorld::SetMass(entt::entity entity, float mass)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        cpBodySetMass(collider.body.get(), mass);
    }

    /**
     * @brief Enables or disables bullet behavior for a specific entity.
     *
     * Bullet mode emulates continuous collision detection (CCD) for high-speed objects,
     * reducing the chance of tunneling through other colliders. This function adjusts the simulation
     * parameters globally for improved accuracy.
     *
     * @param entity The entity whose collider's behavior is to be modified.
     * @param isBullet If true, enables bullet mode; otherwise, disables it.
     *
     * @note
     * - Bullet mode is emulated by increasing simulation iterations and modifying collision slop.
     * - Enabling bullet mode affects the global physics space and may increase computational cost.
     *
     * @example
     * // Enable bullet behavior for an entity
     * SetBullet(entity, true);
     *
     * // Disable bullet behavior
     * SetBullet(entity, false);
     */
    void PhysicsWorld::SetBullet(entt::entity entity, bool isBullet)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        if (isBullet)
        {
            // Increase the number of iterations for high accuracy
            cpSpaceSetIterations(space, 20); // Adjust the number as needed for your simulation

            // Enable continuous collision detection
            cpBodySetVelocityUpdateFunc(collider.body.get(), [](cpBody *body, cpVect gravity, cpFloat damping, cpFloat dt)
                                        {
                                            cpBodyUpdateVelocity(body, gravity, 1.0f, dt); // No damping for precise velocity updates
                                        });

            // Optional: Reduce the collision slop globally for better accuracy
            cpSpaceSetCollisionSlop(space, 0.1); // Default is usually 0.5, smaller values reduce tunneling
        }
        else
        {
            // Restore default behavior
            cpSpaceSetIterations(space, 10);                                        // Default iterations
            cpBodySetVelocityUpdateFunc(collider.body.get(), cpBodyUpdateVelocity); // Reset to default velocity updates
            cpSpaceSetCollisionSlop(space, 0.5);                                    // Restore default slop
        }
    }

    /**
     * @brief Fixes or unfixes the rotation of a body in the physics simulation.
     *
     * When fixed rotation is enabled, the body will not rotate regardless of applied forces or collisions.
     * Disabling fixed rotation restores the body's ability to rotate.
     *
     * @param entity The entity whose rotation behavior is to be modified.
     * @param fixedRotation If true, prevents the body from rotating; otherwise, allows it to rotate.
     *
     * @note
     * - Fixed rotation is achieved by setting the moment of inertia to infinity.
     * - Disabling fixed rotation restores the moment of inertia to a finite value, which is calculated
     *   based on the shape and mass of the body.
     * - Ensure the shape dimensions are correctly provided when calculating the moment of inertia.
     *
     * @example
     * // Prevent the body from rotating
     * SetFixedRotation(entity, true);
     *
     * // Allow the body to rotate
     * SetFixedRotation(entity, false);
     */
    void PhysicsWorld::SetFixedRotation(entt::entity entity, bool fixedRotation)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        if (fixedRotation)
        {
            // Lock rotation by setting the moment of inertia to infinity
            cpBodySetMoment(collider.body.get(), INFINITY);
        }
        else
        {
            // Reset the moment of inertia to a finite value for normal rotation
            // You can calculate the moment based on the shape or use a default value
            float mass = cpBodyGetMass(collider.body.get());
            float width = 1.0f;                                 // Placeholder for width (adjust based on shape)
            float height = 1.0f;                                // Placeholder for height (adjust based on shape)
            float moment = cpMomentForBox(mass, width, height); // Example for a box shape
            cpBodySetMoment(collider.body.get(), moment);
        }
    }

    /**
     * @brief Retrieves the vertices of a polygonal or chain shape associated with a specified entity.
     *
     * This function extracts the vertices of a shape if the `ColliderShapeType` indicates that it is
     * either a `Polygon` or `Chain`. For chain shapes, the vertices are closed into a loop by appending
     * the first vertex to the end of the vector.
     *
     * @param entity The entity whose shape vertices are to be retrieved.
     * @return std::vector<cpVect> A vector containing the vertices of the shape. If the shape is not
     *         of type `Polygon` or `Chain`, the vector will be empty.
     *
     * @details
     * - This function relies on the `ColliderShapeType` enum within the `ColliderComponent` to determine
     *   the type of the shape.
     * - For polygon shapes, the vertices are retrieved in order.
     * - For chain shapes, the vertices are retrieved in order, and the first vertex is repeated at the
     *   end of the vector to close the loop.
     * - If the shape is not a `Polygon` or `Chain`, the function returns an empty vector.
     * - The function assumes that the `collider.shape` pointer is valid and points to a compatible shape
     *   in the Chipmunk2D physics system.
     *
     * @note
     * Ensure that the `ColliderShapeType` is correctly set when creating the collider component. This
     * function does not validate or infer the shape type based on runtime data.
     *
     * @example
     * // Example usage
     * auto vertices = physicsWorld.GetVertices(entity);
     * for (const auto& vertex : vertices) {
     *     std::cout << "Vertex: (" << vertex.x << ", " << vertex.y << ")\n";
     * }
     */
    std::vector<cpVect> PhysicsWorld::GetVertices(entt::entity entity)
    {
        auto &collider = registry->get<ColliderComponent>(entity);
        std::vector<cpVect> vertices;

        if (collider.shapeType == ColliderShapeType::Polygon || collider.shapeType == ColliderShapeType::Chain)
        {
            // Extract vertices for polygon or chain shapes
            int count = cpPolyShapeGetCount(collider.shape.get());
            for (int i = 0; i < count; ++i)
            {
                vertices.push_back(cpPolyShapeGetVert(collider.shape.get(), i));
            }
            // For chains, optionally close the loop
            if (collider.shapeType == ColliderShapeType::Chain && !vertices.empty())
            {
                vertices.push_back(vertices.front());
            }
        }

        return vertices;
    }

    /**
     * @brief Sets the body type of a specified entity's physics body.
     *
     * The body type can be "static", "kinematic", or "dynamic". If the body type is set to "dynamic",
     * the body will be explicitly activated to ensure it participates in the physics simulation.
     *
     * @param entity The entity whose body type is being modified.
     * @param bodyType A string specifying the desired body type: "static", "kinematic", or "dynamic".
     *
     * @throws std::invalid_argument If the provided body type string is invalid.
     *
     * @details
     * - **Static**: Bodies that do not move and do not react to forces.
     * - **Kinematic**: Bodies that can move but are not affected by forces or collisions.
     * - **Dynamic**: Bodies that are fully simulated, reacting to forces, collisions, and impulses.
     * - When a body is set to dynamic, it is explicitly activated using `cpBodyActivate` to ensure it
     *   does not remain in a sleeping state.
     *
     * @note
     * Ensure that the body type string is valid; otherwise, an exception will be thrown.
     *
     * @example
     * // Set the body type of an entity to dynamic
     * physicsWorld.SetBodyType(entity, "dynamic");
     */
    void PhysicsWorld::SetBodyType(entt::entity entity, const std::string &bodyType)
    {
        auto &collider = registry->get<ColliderComponent>(entity);

        if (bodyType == "static")
        {
            cpBodySetType(collider.body.get(), CP_BODY_TYPE_STATIC);
        }
        else if (bodyType == "kinematic")
        {
            cpBodySetType(collider.body.get(), CP_BODY_TYPE_KINEMATIC);
        }
        else if (bodyType == "dynamic")
        {
            cpBodySetType(collider.body.get(), CP_BODY_TYPE_DYNAMIC);
            cpBodyActivate(collider.body.get()); // Ensure the body is activated when set to dynamic
        }
        else
        {
            throw std::invalid_argument("Invalid body type: " + bodyType);
        }
    }
    
    entt::entity PhysicsWorld::PointQuery(float x, float y) {
        // Use nearest-point query with zero radius to pick the shape containing the point.
        cpPointQueryInfo info;
        cpShape* hit = cpSpacePointQueryNearest(
            space,
            cpv(x, y),
            0.0f,
            CP_SHAPE_FILTER_ALL,
            &info
        );
        if (!hit) return entt::null;
        return static_cast<entt::entity>(reinterpret_cast<uintptr_t>(cpShapeGetUserData(hit)));
    }

    void PhysicsWorld::SetBodyPosition(entt::entity e, float x, float y) {
        auto &c = registry->get<ColliderComponent>(e);
        cpBodySetPosition(c.body.get(), cpv(x, y));
    }

    void PhysicsWorld::SetBodyVelocity(entt::entity e, float vx, float vy) {
        auto &c = registry->get<ColliderComponent>(e);
        cpBodySetVelocity(c.body.get(), cpv(vx, vy));
    }
    
    /// Create four static segment‐shapes around [xMin,yMin]→[xMax,yMax].
    /// 'thickness' is the segment radius.
    void PhysicsWorld::AddScreenBounds(float xMin, float yMin,
                                    float xMax, float yMax,
                                    float thickness)
    {
        // Grab the built‑in static body (infinite mass)
        cpBody* staticBody = cpSpaceGetStaticBody(space);

        auto makeWall = [&](float ax, float ay, float bx, float by) {
            // segment from A→B with given thickness
            cpShape* seg = cpSegmentShapeNew(staticBody, cpv(ax, ay), cpv(bx, by), thickness);
            // optional: tune friction/elasticity
            cpShapeSetFriction(seg,    1.0f);
            cpShapeSetElasticity(seg,  0.0f);
            cpSpaceAddShape(space, seg);
        };

        // bottom
        makeWall(xMin, yMin, xMax, yMin);
        // right
        makeWall(xMax, yMin, xMax, yMax);
        // top
        makeWall(xMax, yMax, xMin, yMax);
        // left
        makeWall(xMin, yMax, xMin, yMin);
    }

    void PhysicsWorld::StartMouseDrag(float x, float y) {
    if (mouseJoint) return;     // already dragging
    EndMouseDrag();             // tear down any stray joint

    // 1) Ensure we have a static mouseBody, and position it
    if (!mouseBody) {
        mouseBody = cpBodyNewStatic();
    }
    cpBodySetPosition(mouseBody, cpv(x, y));

    // 2) Pick the entity under the mouse
    draggedEntity = PointQuery(x, y);
    if (draggedEntity == entt::null) return;

    auto &c = registry->get<ColliderComponent>(draggedEntity);

    // 3) Compute each body's local anchor for that world point
    cpVect worldPt = cpv(x, y);
    cpVect anchorA = cpBodyWorldToLocal(mouseBody,    worldPt);
    cpVect anchorB = cpBodyWorldToLocal(c.body.get(), worldPt);

    // 4) Create a pivot joint using those local anchors
    mouseJoint = cpPivotJointNew2(
        mouseBody,
        c.body.get(),
        anchorA,
        anchorB
    );
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

}
