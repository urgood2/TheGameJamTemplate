


```cpp

// init physics (pass an EventBus so collision events publish to your context)
    physicsWorld = physics::InitPhysicsWorld(&globals::getRegistry(), 64.0f, 0.0f, 0.f, &globals::getEventBus());
    
    entt::entity testEntity = globals::getRegistry().create();
    
    physicsWorld->AddCollider(testEntity, "player", "rectangle", 50, 50, -1, -1, false);
    
    physicsWorld->SetBodyPosition(testEntity, 600.f, 300.f);

    physicsWorld->AddScreenBounds(0, 0, GetScreenWidth(), GetScreenHeight());

    physicsWorld->SetDamping(testEntity, 3.5f);
    physicsWorld->SetAngularDamping(testEntity, 3.0f);
    physicsWorld->AddUprightSpring(testEntity, 4500.0f, 1500.0f);
    physicsWorld->SetFriction(testEntity, 0.2f);
    physicsWorld->CreateTopDownController(testEntity);
    
    static PointCloudSampler                      _pointCloud(32.0f);
    static std::unique_ptr<BlockSampler>         _sampler;
    
    static cpVect                                 _randomOffset;
    
    static std::shared_ptr<ChipmunkSpace> physicsSpace = std::make_shared<ChipmunkSpace>(physicsWorld->space);
    static auto sampler = std::make_unique<BlockSampler>([](cpVect pos){
    // 2 octaves of worley + pointCloud sampling
    cpFloat noise = CellularNoiseOctaves(cpvadd(pos, _randomOffset) * (1.0f/300.0f), 2);
    return cpfmin(2.8f * noise, 1.0f) * _pointCloud.sample(pos);
    });
    // BasicTileCache(_sampler.get(), ChipmunkSpace::SpaceFromCPSpace(physicsWorld->space), 128.0f, 8, 64);
    _tileCache = std::make_shared<BasicTileCache>(
        sampler.get(),
        physicsSpace.get(),
        128.0f, // tile size
        8,      // tile margin
        500      // max tiles
    );
    
    
    // pick a random offset once
    _randomOffset = cpvmult(
    cpv((cpFloat)rand()/RAND_MAX, (cpFloat)rand()/RAND_MAX),
    10000.0f
    );
    
    // configure terrain segments
    _tileCache->segmentRadius     = 2.0f;
    _tileCache->segmentFriction   = 0.7f;
    _tileCache->segmentElasticity = 0.3f;

    
    //TODO: test CreateTilemapColliders
    // original row‑major map (6 rows, 8 cols)
    /// 0 = empty, 1 = solid
    // std::vector<std::vector<bool>> rowMajor = {
    //     {0,0,0,0,0,0,0,0},
    //     {0,1,1,1,1,1,1,0},
    //     {0,1,0,0,0,0,1,0},
    //     {0,1,0,1,1,0,1,0},
    //     {0,1,0,0,0,0,1,0},
    //     {0,1,1,1,1,1,1,0},
    // };

    // transpose → colMajor[x][y]
    // std::vector<std::vector<bool>> sampleMap(8, std::vector<bool>(6));
    // for(int y = 0; y < 6; y++){
    //     for(int x = 0; x < 8; x++){
    //         sampleMap[x][y] = rowMajor[y][x];
    //     }
    // }

    // now width = 8, height = 6 as expected
    // physicsWorld->CreateTilemapColliders(sampleMap, 100.0f, 5.0f);
    
    // Assuming 'camera' is your Camera2D…
    Vector2 topLeft     = GetScreenToWorld2D({ 0, 0 },            camera_manager::Get("world_camera")->cam);
    Vector2 bottomRight = GetScreenToWorld2D({ (float)GetScreenWidth(),
    (float)GetScreenHeight() }, camera_manager::Get("world_camera")->cam);

    
    // Now topLeft.y < bottomRight.y
    // cpBB viewBB = cpBBNew(
    //     topLeft.x,      // minX
    //     topLeft.y,      // minY  ← the smaller Y
    //     bottomRight.x,  // maxX
    //     bottomRight.y   // maxY  ← the larger Y
    // );


    // _tileCache->ensureRect(viewBB);
    
    cpVect physTL = cpv((cpFloat)topLeft.x, (cpFloat)topLeft.y);
    cpVect physBR = cpv((cpFloat)bottomRight.x, (cpFloat)bottomRight.y);

    // 2) Ensure we supply min / max in each axis
    cpFloat minX = fmin(physTL.x, physBR.x);
    cpFloat maxX = fmax(physTL.x, physBR.x);
    cpFloat minY = fmin(physTL.y, physBR.y);
    cpFloat maxY = fmax(physTL.y, physBR.y);

    // 3) Build the BB in physics‐space
    cpBB viewBB = cpBBNew(minX, minY, maxX, maxY);

    // 4) Query your tile-cache in physics units
    _tileCache->ensureRect(viewBB);
    
    // generate a texture for the block sampler
    blockSamplerTexture = GenerateDensityTexture(sampler.get(), camera_manager::Get("world_camera")->cam);
    pointCloudSamplerTexture = GeneratePointCloudDensityTexture(&_pointCloud, camera_manager::Get("world_camera")->cam);
    
    // After your ensureRect call, do:
    // for(CachedTile* t = _tileCache->_cacheTail; t; t = t->next) {
    //     spdlog::info("CachedTile: l={} b={} r={} t={}",
    //                 t->bb.l, t->bb.b,
    //                 t->bb.r, t->bb.t);
    // }
    cpSpatialIndexEach(
        _tileCache->_tileIndex,        // your cpSpatialIndex*
        +[](void *obj, void *){
            auto *tile = static_cast<CachedTile*>(obj);
            spdlog::info("CACHED TILE: l={:.2f}, b={:.2f}, r={:.2f}, t={:.2f}",
                        tile->bb.l, tile->bb.b,
                        tile->bb.r, tile->bb.t);
        },
        nullptr                         // no extra userData needed
    );


    
    auto debugTile = _tileCache->GetTileAt(0, 0);
    
    for (auto &shape : debugTile->shapes) {
        auto boundingBox = shape->bb();
        SPDLOG_DEBUG("Tile at (0, 0) has shape with bounding box: ({}, {}) to ({}, {})",
            boundingBox.l, boundingBox.b, boundingBox.r, boundingBox.t);
    }
    // _tileCache->ensureRect(cpBBNew(0, 0, GetScreenWidth(), GetScreenHeight()));

```
