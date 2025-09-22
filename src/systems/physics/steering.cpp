#include "steering.hpp"

#include "physics_world.hpp"



namespace Steering {

    #define M_PI 3.14159265358979323846

    //--------------------------------------------
    // Utilities
    //--------------------------------------------
    cpVect truncate(const cpVect& v, float maxLen) {
        float len = cpvlength(v);
        if (len > maxLen && len > 0.f) return cpvmult(v, maxLen / len);
        return v;
    }

    cpVect pointToWorld(const cpVect& local,
                            const cpVect& heading,
                            const cpVect& side,
                            const cpVect& position) {
        // world = heading * x + side * y + position
        return cpvadd(cpvadd(cpvmult(heading, local.x), cpvmult(side, local.y)), position);
    }
    
    cpVect pointToLocal(const cpVect& p, const cpVect& heading, const cpVect& side, const cpVect& pos){
        // inverse of world = H*x + S*y + pos
        // local.x = dot(p-pos, heading), local.y = dot(p-pos, side)
        cpVect d = cpvsub(p, pos);
        return cpv(cpvdot(d, heading), cpvdot(d, side));
    }

    cpVect vectorToWorld(const cpVect& v, const cpVect& heading, const cpVect& side){
        return cpvadd(cpvmult(heading, v.x), cpvmult(side, v.y));
    }
    
    cpVect rotateAroundOrigin(const cpVect& v, float r){
        float s = sinf(r), c = cosf(r);
        return cpv(c*v.x - s*v.y, s*v.x + c*v.y);
    }

    // Small adapter: get cpBody* from either BodyComponent or physics::ColliderComponent
    cpBody* get_cpBody(entt::registry& r, entt::entity e) {
        if (auto bc = r.try_get<BodyComponent>(e)) {
            if (bc->body) return bc->body;
        }
        if (auto cc = r.try_get<physics::ColliderComponent>(e)) {
            // ColliderComponent defined in your physics header. We only need body.get().
            // We don't include the header here to keep compile units light.
            // NOTE: This relies on the field name "body". If you renamed it, adjust here.
            struct CCView { std::shared_ptr<cpBody> body; }; // layout view
            auto* raw = reinterpret_cast<CCView*>(cc);
            if (raw->body) return raw->body.get();
        }
        return nullptr;
    }

    //--------------------------------------------
    // Lifecycle
    //--------------------------------------------
    void MakeSteerable(entt::registry& r,
                            entt::entity e,
                            float maxSpeed,
                            float maxForce,
                            float maxTurnRate,
                            float turnMul) {
        auto& s = r.emplace<SteerableComponent>(e);
        s.enabled        = true;
        s.maxSpeed       = maxSpeed;
        s.maxForce       = maxForce;
        s.maxTurnRate    = maxTurnRate;
        s.turnMultiplier = turnMul;

        if (auto* body = get_cpBody(r, e)) {
            s.mass = cpBodyGetMass(body);
            cpVect v = cpBodyGetVelocity(body);
            if (cpvlengthsq(v) > 1e-6f) {
                s.heading = cpvnormalize(v);
                s.side    = cpvperp(s.heading);
            }
        } else {
            s.mass = 1.0f; // fallback
        }

        // seed wander target randomly on circle
        float rads = float(rand()) / float(RAND_MAX) * 2.0f * float(M_PI);
        s.wanderTarget = cpv(cosf(rads), sinf(rads));
    }

    //--------------------------------------------
    // Frame update
    //--------------------------------------------
    void Update(entt::registry& r, entt::entity e, float dt){
        auto &s = r.get<SteerableComponent>(e);
        if(!s.enabled) return;

        // Compose
        s.steeringForce = cpvzero;
        if(s.isSeeking)      s.steeringForce = cpvadd(s.steeringForce, s.seekForce);
        if(s.isFleeing)      s.steeringForce = cpvadd(s.steeringForce, s.fleeForce);
        if(s.isPursuing)     s.steeringForce = cpvadd(s.steeringForce, s.pursuitForce);
        if(s.isEvading)      s.steeringForce = cpvadd(s.steeringForce, s.evadeForce);
        if(s.isWandering)    s.steeringForce = cpvadd(s.steeringForce, s.wanderForce);
        if(s.isPathFollowing)s.steeringForce = cpvadd(s.steeringForce, s.pathFollowForce);
        if(s.isSeparating)   s.steeringForce = cpvadd(s.steeringForce, s.separationForce);
        if(s.isAligning)     s.steeringForce = cpvadd(s.steeringForce, s.alignmentForce);
        if(s.isCohesing)     s.steeringForce = cpvadd(s.steeringForce, s.cohesionForce);

        // Timed steering force (linear decay to 0 over duration)
        if(s.timedForceTimeLeft > 0.f){
            float k = s.timedForceTimeLeft / s.timedForceDuration; // 1..0
            s.steeringForce = cpvadd(s.steeringForce, cpvmult(s.timedForce, k));
            s.timedForceTimeLeft = std::max(0.f, s.timedForceTimeLeft - dt);
        }

        s.steeringForce = truncate(s.steeringForce, s.maxForce);

        // Reset flags
        s.isSeeking=s.isFleeing=s.isPursuing=s.isEvading=false;
        s.isWandering=s.isPathFollowing=false;
        s.isSeparating=s.isAligning=s.isCohesing=false;

        auto* body = get_cpBody(r, e);
        if(!body) return;

        // Apply force at CoM
        cpBodyApplyForceAtLocalPoint(body, s.steeringForce, cpvzero);

        // Timed impulse: apply per-frame impulse chunk
        if(s.timedImpulseTimeLeft > 0.f){
            float slice = std::min(dt, s.timedImpulseTimeLeft);
            cpVect impulse = cpvmult(s.timedImpulsePerSec, slice);
            cpBodyApplyImpulseAtLocalPoint(body, impulse, cpvzero);
            s.timedImpulseTimeLeft = std::max(0.f, s.timedImpulseTimeLeft - dt);
        }

        // Optional pre-step clamp
        cpVect vel = cpBodyGetVelocity(body);
        float v2 = cpvlengthsq(vel);
        if(v2 > s.maxSpeed*s.maxSpeed){
            cpBodySetVelocity(body, cpvmult(cpvnormalize(vel), s.maxSpeed));
        }
        if(v2 > 1e-6f){
            s.heading = cpvnormalize(vel);
            s.side    = cpvperp(s.heading);
        }
    }

    //--------------------------------------------
    // Behaviors
    //--------------------------------------------

    // Seek (Chipmunk coords)
    void SeekPoint(entt::registry& r, entt::entity e,
                        const cpVect& target,
                        float deceleration,
                        float weight) {
        auto *body = get_cpBody(r, e);
        if (!body) return;

        auto &s = r.get<SteerableComponent>(e);

        cpVect pos = cpBodyGetPosition(body);
        cpVect toTarget = cpvsub(target, pos);
        float  dist     = cpvlength(toTarget);

        if (dist > 1e-5f) {
            float speed   = std::min(dist / (deceleration * 0.08f), s.maxSpeed);
            cpVect desired= cpvmult(toTarget, speed / dist);
            cpVect vel    = cpBodyGetVelocity(body);

            s.seekForce = cpvmult(cpvsub(desired, vel), s.turnMultiplier * weight);
            s.isSeeking = true;
        } else {
            s.seekForce = cpvzero;
            s.isSeeking = false;
        }
    }

    // Separation (Chipmunk coords)
    void Separate(entt::registry& r, entt::entity e,
                        float separationRadius,
                        const std::vector<entt::entity>& neighbors,
                        float weight) {
        auto *body = get_cpBody(r, e);
        if (!body) return;

        auto &s = r.get<SteerableComponent>(e);

        const cpVect pos = cpBodyGetPosition(body);
        cpVect force = cpvzero;

        const float twice = 2.0f * separationRadius;

        for (auto ne : neighbors) {
            if (ne == e) continue;
            if (auto* nbody = get_cpBody(r, ne)) {
                const cpVect op = cpBodyGetPosition(nbody);
                const cpVect diff = cpvsub(pos, op);
                const float  d    = cpvlength(diff);

                if (d > 0.f && d < twice) {
                    cpVect away = cpvmult(cpvnormalize(diff), (twice - d)); // stronger when closer
                    force = cpvadd(force, away);
                }
            }
        }

        s.separationForce = cpvmult(force, weight);
        s.isSeparating    = true;
    }

    // Wander (Chipmunk coords)
    void Wander(entt::registry& r, entt::entity e,
                    float jitter,
                    float radius,
                    float distance,
                    float weight) {
        auto *body = get_cpBody(r, e);
        if (!body) return;

        auto &s = r.get<SteerableComponent>(e);

        // keep local wander state updated
        s.wanderJitter   = jitter;
        s.wanderRadius   = radius;
        s.wanderDistance = distance;

        // jitter the wander target on the unit disk
        auto rnd = []() -> float { return float(rand()) / float(RAND_MAX); };
        s.wanderTarget = cpvadd(s.wanderTarget,
                                cpvmult(cpv(2.0f*rnd()-1.0f, 2.0f*rnd()-1.0f),
                                        s.wanderJitter));
        s.wanderTarget = cpvnormalize(s.wanderTarget);
        s.wanderTarget = cpvmult(s.wanderTarget, s.wanderRadius);

        // project ahead in local space and convert to world
        const cpVect localTarget = cpvadd(s.wanderTarget, cpv(s.wanderDistance, 0));
        const cpVect pos         = cpBodyGetPosition(body);
        const cpVect worldTarget = pointToWorld(localTarget, s.heading, s.side, pos);

        s.wanderForce = cpvmult(cpvsub(worldTarget, pos), weight);
        s.isWandering = true;
    }
    
    
// FLee
    void FleePoint(entt::registry& r, entt::entity e, const cpVect& threat, float panicDist, float weight){
        auto* body = get_cpBody(r, e); if(!body) return;
        auto& s = r.get<SteerableComponent>(e);
        cpVect pos = cpBodyGetPosition(body);
        cpVect away = cpvsub(pos, threat);
        float d = cpvlength(away);
        if(d > 1e-5f && d < panicDist){
            cpVect desired = cpvmult(cpvnormalize(away), s.maxSpeed);
            cpVect vel = cpBodyGetVelocity(body);
            s.fleeForce = cpvmult(cpvsub(desired, vel), s.turnMultiplier * weight);
            s.isFleeing = true;
        }
    }

    void Pursuit(entt::registry& r, entt::entity e, entt::entity target, float weight){
        auto* bodyA = get_cpBody(r, e); if(!bodyA) return;
        auto* bodyB = get_cpBody(r, target); if(!bodyB) return;
        auto& s = r.get<SteerableComponent>(e);

        cpVect posA = cpBodyGetPosition(bodyA);
        cpVect posB = cpBodyGetPosition(bodyB);
        cpVect velA = cpBodyGetVelocity(bodyA);
        cpVect velB = cpBodyGetVelocity(bodyB);

        cpVect toTarget = cpvsub(posB, posA);
        float relativeHeading = cpvdot(s.heading, cpvnormalize(velB));
        // if mostly facing each other, just seek current pos
        bool directSeek = (cpvdot(toTarget, s.heading) > 0.f) && (relativeHeading < -0.95f);

        cpVect predicted = posB;
        if(!directSeek){
            float T = cpvlength(toTarget) / (s.maxSpeed + cpvlength(velB) + 1e-4f);
            predicted = cpvadd(posB, cpvmult(velB, T));
        }
        SeekPoint(r, e, predicted, 1.0f, weight);
        s.pursuitForce = s.seekForce; // for debugging/inspection
        s.isPursuing = true;
    }

    void Evade(entt::registry& r, entt::entity e, entt::entity pursuer, float weight){
        auto* bodyA = get_cpBody(r, e); if(!bodyA) return;
        auto* bodyB = get_cpBody(r, pursuer); if(!bodyB) return;
        auto& s = r.get<SteerableComponent>(e);

        cpVect posA = cpBodyGetPosition(bodyA);
        cpVect posB = cpBodyGetPosition(bodyB);
        cpVect velB = cpBodyGetVelocity(bodyB);

        cpVect toThreat = cpvsub(posB, posA);
        float T = cpvlength(toThreat) / (s.maxSpeed + cpvlength(velB) + 1e-4f);
        cpVect future = cpvadd(posB, cpvmult(velB, T));

        // Flee from predicted future position
        FleePoint(r, e, future, std::numeric_limits<float>::infinity(), weight);
        s.evadeForce = s.fleeForce;
        s.isEvading = true;
    }

    void Align(entt::registry& r, entt::entity e,
                    const std::vector<entt::entity>& neighbors,
                    float alignRadius, float weight){
        auto* body = get_cpBody(r, e); if(!body) return;
        auto& s = r.get<SteerableComponent>(e);

        cpVect pos = cpBodyGetPosition(body);
        cpVect avgHeading = cpvzero; int count=0;
        for(auto n : neighbors){
            if (n==e) continue;
            if(auto* nb = get_cpBody(r, n)){
                cpVect np = cpBodyGetPosition(nb);
                if(cpvlength(cpvsub(np,pos)) < alignRadius){
                    cpVect nv = cpBodyGetVelocity(nb);
                    if(cpvlengthsq(nv) > 1e-6f){
                        avgHeading = cpvadd(avgHeading, cpvnormalize(nv));
                        ++count;
                    }
                }
            }
        }
        if(count>0){
            avgHeading = cpvnormalize(avgHeading);
            cpVect desired = cpvmult(avgHeading, s.maxSpeed);
            cpVect vel = cpBodyGetVelocity(body);
            s.alignmentForce = cpvmult(cpvsub(desired, vel), s.turnMultiplier * weight);
            s.isAligning = true;
        }
    }

    void Cohesion(entt::registry& r, entt::entity e,
                        const std::vector<entt::entity>& neighbors,
                        float cohesionRadius, float weight){
        auto* body = get_cpBody(r, e); if(!body) return;
        auto& s = r.get<SteerableComponent>(e);

        cpVect pos = cpBodyGetPosition(body);
        cpVect center = cpvzero; int count=0;
        for(auto n : neighbors){
            if (n==e) continue;
            if(auto* nb = get_cpBody(r, n)){
                cpVect np = cpBodyGetPosition(nb);
                if(cpvlength(cpvsub(np,pos)) < cohesionRadius){
                    center = cpvadd(center, np); ++count;
                }
            }
        }
        if(count>0){
            center = cpvmult(center, 1.f/float(count));
            // steer towards center (seek)
            SeekPoint(r, e, center, 1.0f, weight);
            s.cohesionForce = s.seekForce;
            s.isCohesing = true;
        }
    }

    void SetPath(entt::registry& r, entt::entity e,
                        std::vector<cpVect> waypoints,
                        float arriveRadius){
        auto& s = r.get<SteerableComponent>(e);
        s.path = std::move(waypoints);
        s.pathIndex = 0;
        s.pathArriveRadius = arriveRadius;
    }

    void PathFollow(entt::registry& r, entt::entity e,
                        float decel, float weight){
        auto* body = get_cpBody(r, e); if(!body) return;
        auto& s = r.get<SteerableComponent>(e);
        if(s.path.empty()) return;

        cpVect pos = cpBodyGetPosition(body);
        while(s.pathIndex < (int)s.path.size() &&
            cpvlength(cpvsub(s.path[s.pathIndex], pos)) <= s.pathArriveRadius){
            ++s.pathIndex;
        }
        if(s.pathIndex >= (int)s.path.size()){
            // reached final point: stop contributing
            s.pathFollowForce = cpvzero;
            s.isPathFollowing = false;
            return;
        }
        SeekPoint(r, e, s.path[s.pathIndex], decel, weight);
        s.pathFollowForce = s.seekForce;
        s.isPathFollowing = true;
    }

    void ApplySteeringForce(entt::registry& r, entt::entity e, float f, float radians, float seconds){
        auto& s = r.get<SteerableComponent>(e);
        s.timedForce = cpv(f*cosf(radians), f*sinf(radians));
        s.timedForceDuration = s.timedForceTimeLeft = std::max(0.001f, seconds);
    }

    void ApplySteeringImpulse(entt::registry& r, entt::entity e, float f, float radians, float seconds){
        auto& s = r.get<SteerableComponent>(e);
        // Distribute this impulse over duration as per-frame impulses (closest to your tween)
        s.timedImpulsePerSec = cpv(f*cosf(radians), f*sinf(radians));
        s.timedImpulseDuration = s.timedImpulseTimeLeft = std::max(0.001f, seconds);
    }

    //--------------------------------------------
    // Raylib helpers
    //--------------------------------------------
    void SeekPoint(entt::registry& r, entt::entity e,
                        const Vector2& rlTarget,
                        float decel, float weight) {
        SeekPoint(r, e, rlTarget, decel, weight);
    }
    
    void SeekObject(entt::registry& r, entt::entity e, entt::entity target, float decel, float weight){
        if(auto* tb = get_cpBody(r, target))
            SeekPoint(r, e, cpBodyGetPosition(tb), decel, weight);
    }

} // namespace Steering