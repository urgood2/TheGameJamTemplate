// TileCacheWrappers.cpp
// Port of ObjectiveChipmunk's ChipmunkAbstractTileCache and ChipmunkBasicTileCache to C++

#include "ChipmunkAutogeometry.hpp"
#include "ChipmunkSpace.hpp"
#include "ChipmunkPointCloudSampler.hpp"
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"
#include <vector>
#include <cassert>
#include <cmath>

// Forward declaration for segment creation wrapper
class ChipmunkChipmunkSegmentShape;

// Cached tile node for LRU cache and spatial index
struct CachedTile {
    cpBB bb;
    bool dirty;
    CachedTile* next;
    CachedTile* prev;
    std::vector<ChipmunkSegmentShape*> shapes;

    explicit CachedTile(const cpBB& bounds)
    : bb(bounds), dirty(true), next(nullptr), prev(nullptr) {}
};

// Abstract tile cache: manages grid of tiles for deformable terrain
class AbstractTileCache {
public:
    // ctor: sampler, space to add segments, tileSize in world units, samples per tile, cacheSize = max tile count
    AbstractTileCache(AbstractSampler* sampler,
                      ChipmunkSpace* space,
                      cpFloat tileSize,
                      unsigned samplesPerTile,
                      unsigned cacheSize)
    : _sampler(sampler), _space(space),
      _tileSize(tileSize), _samplesPerTile(samplesPerTile),
      _tileOffset(cpvzero), _cacheSize(cacheSize),
      _tileIndex(nullptr), _cacheHead(nullptr), _cacheTail(nullptr),
      _tileCount(0), _ensuredDirty(true), _marchHard(false)
    {
        resetCache();
    }

    virtual ~AbstractTileCache() {
        // cleanup tiles and shapes
        for(CachedTile* t = _cacheTail; t; t = t->next) {
            removeShapesForTile(t);
            delete t;
        }
        if(_tileIndex) cpSpatialIndexFree(_tileIndex);
    }
    
    // Extract the bb from a CachedTile*, wrapped for the C API:
    static cpBB CachedTileBB(void *obj) {
        auto *tile = static_cast<CachedTile*>(obj);
        return tile->bb;  // or tile->_bb if your member is private
    }


    // Reset all tiles, clear space and index
    void resetCache() {
        _ensuredDirty = true;
        if(_tileIndex) cpSpatialIndexFree(_tileIndex);
        _tileIndex = cpSpaceHashNew(
            _tileSize,
            static_cast<int>(_cacheSize),
            CachedTileBB,   // your cpSpatialIndexBBFunc = cpBB(*)(void*)
            nullptr
        );

        // remove shapes and delete tiles
        for(CachedTile* t = _cacheTail; t; ) {
            CachedTile* next = t->next;
            removeShapesForTile(t);
            delete t;
            t = next;
        }
        _cacheHead = _cacheTail = nullptr;
        _tileCount = 0;
    }

    // Mark bounds dirty; will regenerate when ensureRect is called
    void markDirtyRect(const cpBB& bounds) {
        Rect rect = TileRectForBB(bounds);
        if(!_ensuredDirty && cpBBContainsBB(_ensuredBB, BBForRect(rect))) {
            _ensuredDirty = true;
        }
        for(int i = rect.l; i < rect.r; ++i) {
            for(int j = rect.b; j < rect.t; ++j) {
                CachedTile* tile = GetTileAt(i, j);
                if(tile) tile->dirty = true;
            }
        }
    }

    // Ensure all tiles covering bounds are up-to-date
    void ensureRect(const cpBB& bounds) {
        Rect rect = TileRectForBB(bounds);
        cpBB ensure = BBForRect(rect);
        if(!_ensuredDirty && cpBBContainsBB(_ensuredBB, ensure)) return;
        //NOTE: starts at -1, -1 for padding
        // Iterate over tile coords
        for(int i = rect.l; i < rect.r; ++i) {
            for(int j = rect.b; j < rect.t; ++j) {
                CachedTile* tile = GetTileAt(i, j);
                if(!tile) {
                    // create new tile
                    cpBB bb = BBForRect({i,j,i+1,j+1});
                    tile = new CachedTile(bb);
                    cpSpatialIndexInsert(_tileIndex, tile, reinterpret_cast<cpHashValue>(tile));
                    ++_tileCount;
                }
                if(tile->dirty) marchTile(tile);
                // move to head of LRU list
                moveToHead(tile);
            }
        }
        _ensuredBB = ensure;
        _ensuredDirty = false;

        // prune oldest tiles beyond cacheSize
        int toRemove = static_cast<int>(_tileCount) - static_cast<int>(_cacheSize);
        while(toRemove-- > 0 && _cacheTail) {
            CachedTile* old = _cacheTail;
            cpSpatialIndexRemove(_tileIndex, old, reinterpret_cast<cpHashValue>(old));
            removeShapesForTile(old);
            removeFromList(old);
            delete old;
            --_tileCount;
        }
    }

    // Simplify polyline; override in subclass
    virtual cpPolyline* simplify(cpPolyline* polyline) {
        // default stub: no simplification
        return polyline;
    }

    // Create a segment shape in space from a->b; override in subclass
    virtual ChipmunkSegmentShape* makeSegmentFor(ChipmunkBody* staticBody,
                                         const cpVect& a,
                                         const cpVect& b) {
        // stub: user must override
        assert(false && "makeSegmentFor must be overridden");
        return nullptr;
    }

    // Whether to use hard marching (cpMarchHard) or soft (cpMarchSoft)
    bool marchHard() const { return _marchHard; }
    void setMarchHard(bool v) { _marchHard = v; }

    cpVect tileOffset() const { return _tileOffset; }
    void setTileOffset(const cpVect& v) { _tileOffset = v; }

    AbstractSampler* _sampler;
    ChipmunkSpace* _space;
    cpFloat _tileSize;
    unsigned _samplesPerTile;
    cpVect _tileOffset;
    unsigned _cacheSize;
    cpSpatialIndex* _tileIndex;
    CachedTile* _cacheHead;
    CachedTile* _cacheTail;
    unsigned _tileCount;
    cpBB _ensuredBB;
    bool _ensuredDirty;
    bool _marchHard;

    // Internal tile rectangle type
    struct Rect { int l, b, r, t; };

    // Convert world BB to tile rectangle coords
    Rect TileRectForBB(const cpBB& bb) const {
        float inv = 1.0f / _samplesPerTile;
        float ox = _tileOffset.x, oy = _tileOffset.y;
        return {
            int(std::floor((bb.l - ox)/_tileSize - inv)),
            int(std::floor((bb.b - oy)/_tileSize - inv)),
            int(std::ceil ( (bb.r - ox)/_tileSize + inv)),
            int(std::ceil ( (bb.t - oy)/_tileSize + inv))
        };
    }
    // Convert tile rect to world BB
    cpBB BBForRect(const Rect& r) const {
        float ox = _tileOffset.x, oy = _tileOffset.y;
        return cpBBNew(
            r.l*_tileSize + ox,
            r.b*_tileSize + oy,
            r.r*_tileSize + ox,
            r.t*_tileSize + oy
        );
    }
    // Spatial query for tile at grid coords i,j
    CachedTile* GetTileAt(int i, int j) const {
        cpVect pt = cpv((i + 0.5f)*_tileSize + _tileOffset.x,
                        (j + 0.5f)*_tileSize + _tileOffset.y);
        CachedTile* out = nullptr;

        cpSpatialIndexQuery(
            _tileIndex,
            &pt,                                 // queryObj
            cpBBNewForCircle(pt, 0.0f),          // bounding box for the query
            +[](void *obj, void *queryObj, cpCollisionID, void *userData)
                -> unsigned int 
            {
                auto *tile  = static_cast<CachedTile*>(obj);     // now correct
                auto *point = static_cast<cpVect*>(queryObj);    // now correct
                if(cpBBContainsVect(tile->bb, *point)) {
                    *static_cast<CachedTile**>(userData) = tile;
                    return 1;
                }
                return 0;
            },
            &out
        );

        return out;
    }


    // Remove shapes of a tile from space
    void removeShapesForTile(CachedTile* tile) {
        for(auto* s : tile->shapes) {
            _space->remove(s);
            delete s;
        }
        tile->shapes.clear();
    }
    // March a single tile (regenerate geometry)
    void marchTile(CachedTile* tile) {
        removeShapesForTile(tile);
        cpPolylineSet* set = cpPolylineSetNew();
        if(_marchHard)
            cpMarchHard(tile->bb, _samplesPerTile, _samplesPerTile,
                        _sampler->marchThreshold,
                        reinterpret_cast<cpMarchSegmentFunc>(cpPolylineSetCollectSegment), set,
                        _sampler->sampleFunc, _sampler);
        else
            cpMarchSoft(tile->bb, _samplesPerTile, _samplesPerTile,
                        _sampler->marchThreshold,
                        reinterpret_cast<cpMarchSegmentFunc>(cpPolylineSetCollectSegment), set,
                        _sampler->sampleFunc, _sampler);

        if(set->count > 0) {
            ChipmunkBody* staticBody = ChipmunkBody::StaticBody();
            for(int i = 0; i < set->count; ++i) {
                cpPolyline* pl = simplify(set->lines[i]);
                for(int v = 0; v < pl->count - 1; ++v) {
                    ChipmunkSegmentShape* seg = makeSegmentFor(staticBody,
                                                       pl->verts[v], pl->verts[v+1]);
                    tile->shapes.push_back(seg);
                    _space->add(seg);
                }
                cpPolylineFree(pl);
            }
        }
        cpPolylineSetFree(set, true);
        tile->dirty = false;
    }

    // LRU list management
    void moveToHead(CachedTile* tile) {
        if(tile == _cacheHead) return;
        removeFromList(tile);
        // insert at head
        tile->prev = _cacheHead;
        tile->next = nullptr;
        if(_cacheHead) _cacheHead->next = tile;
        _cacheHead = tile;
        if(!_cacheTail) _cacheTail = tile;
    }
    void removeFromList(CachedTile* tile) {
        if(tile->prev) tile->prev->next = tile->next;
        if(tile->next) tile->next->prev = tile->prev;
        if(_cacheHead == tile) _cacheHead = tile->prev;
        if(_cacheTail == tile) _cacheTail = tile->next;
        tile->prev = tile->next = nullptr;
    }
};

// Basic tile cache: configurable generation parameters
class BasicTileCache : public AbstractTileCache {
public:
    BasicTileCache(AbstractSampler* sampler,
                   ChipmunkSpace* space,
                   cpFloat tileSize,
                   unsigned samplesPerTile,
                   unsigned cacheSize)
    : AbstractTileCache(sampler, space, tileSize, samplesPerTile, cacheSize),
      simplifyThreshold(2.0f), segmentRadius(0.0f),
      segmentFriction(1.0f), segmentElasticity(1.0f),
      segmentFilter(CP_SHAPE_FILTER_ALL),
      segmentCollisionType(0)
    {}

    // override simplification
    cpPolyline* simplify(cpPolyline* polyline) override {
        return cpPolylineSimplifyCurves(polyline, simplifyThreshold);
    }
    // override segment creation
    ChipmunkSegmentShape* makeSegmentFor(ChipmunkBody* staticBody,
                                 const cpVect& a,
                                 const cpVect& b) override {
        ChipmunkSegmentShape* seg = ChipmunkSegmentShape::SegmentWithBody(staticBody, a, b, segmentRadius);
        seg->setFriction(segmentFriction);
        seg->setElasticity(segmentElasticity);
        seg->setFilter(segmentFilter);
        seg->setCollisionType(segmentCollisionType);
        return seg;
    }

    // Public parameters
    cpFloat simplifyThreshold;
    cpFloat segmentRadius;
    cpFloat segmentFriction;
    cpFloat segmentElasticity;
    cpShapeFilter segmentFilter;
    cpCollisionType segmentCollisionType;
};
