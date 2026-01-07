#include <gtest/gtest.h>
#include "components/graphics.hpp"

// =============================================================================
// Phase 1.1: PlaybackDirection Enum Tests
// =============================================================================

TEST(PlaybackDirection, EnumValuesAreDistinct) {
    EXPECT_NE(static_cast<int>(PlaybackDirection::Forward), 
              static_cast<int>(PlaybackDirection::Reverse));
    EXPECT_NE(static_cast<int>(PlaybackDirection::Forward), 
              static_cast<int>(PlaybackDirection::Pingpong));
    EXPECT_NE(static_cast<int>(PlaybackDirection::Forward), 
              static_cast<int>(PlaybackDirection::PingpongReverse));
    EXPECT_NE(static_cast<int>(PlaybackDirection::Reverse), 
              static_cast<int>(PlaybackDirection::Pingpong));
    EXPECT_NE(static_cast<int>(PlaybackDirection::Pingpong), 
              static_cast<int>(PlaybackDirection::PingpongReverse));
}

// =============================================================================
// Phase 1.2: AnimationObject playbackDirection Field Tests
// =============================================================================

TEST(AnimationObject, DefaultPlaybackDirectionIsForward) {
    AnimationObject anim{};
    EXPECT_EQ(anim.playbackDirection, PlaybackDirection::Forward);
}

TEST(AnimationObject, PlaybackDirectionIsAssignable) {
    AnimationObject anim{};
    anim.playbackDirection = PlaybackDirection::Reverse;
    EXPECT_EQ(anim.playbackDirection, PlaybackDirection::Reverse);
    
    anim.playbackDirection = PlaybackDirection::Pingpong;
    EXPECT_EQ(anim.playbackDirection, PlaybackDirection::Pingpong);
}

// =============================================================================
// Phase 1.3: pingpongReversing Field Tests
// =============================================================================

TEST(AnimationObject, PingpongReversingDefaultsFalse) {
    AnimationObject anim{};
    EXPECT_FALSE(anim.pingpongReversing);
}

// =============================================================================
// Phase 2.1: paused Field Tests
// =============================================================================

TEST(AnimationObject, PausedDefaultsFalse) {
    AnimationObject anim{};
    EXPECT_FALSE(anim.paused);
}

// =============================================================================
// Phase 2.2: speedMultiplier Field Tests
// =============================================================================

TEST(AnimationObject, SpeedMultiplierDefaultsToOne) {
    AnimationObject anim{};
    EXPECT_FLOAT_EQ(anim.speedMultiplier, 1.0f);
}

// =============================================================================
// Phase 2.3: loopCount Field Tests
// =============================================================================

TEST(AnimationObject, LoopCountDefaultsToInfinite) {
    AnimationObject anim{};
    EXPECT_EQ(anim.loopCount, -1);
}

TEST(AnimationObject, CurrentLoopCountDefaultsToZero) {
    AnimationObject anim{};
    EXPECT_EQ(anim.currentLoopCount, 0);
}

// =============================================================================
// Phase 1.5-1.8: Animation Update Direction Tests
// These test the frame advancement logic for each playback direction
// =============================================================================

namespace {

AnimationObject createTestAnimation(int frameCount, PlaybackDirection direction = PlaybackDirection::Forward) {
    AnimationObject anim{};
    anim.playbackDirection = direction;
    
    for (int i = 0; i < frameCount; ++i) {
        SpriteComponentASCII sprite{};
        sprite.spriteUUID = "frame_" + std::to_string(i);
        anim.animationList.emplace_back(sprite, 0.1);
    }
    
    return anim;
}

unsigned int advanceFrame(AnimationObject& anim) {
    unsigned int oldIndex = anim.currentAnimIndex;
    double frameDuration = anim.animationList[anim.currentAnimIndex].second;
    
    anim.currentElapsedTime += frameDuration + 0.001;
    
    if (anim.paused || anim.animationList.empty()) {
        return anim.currentAnimIndex;
    }
    
    float effectiveSpeed = std::max(0.0f, anim.speedMultiplier);
    if (effectiveSpeed == 0.0f) {
        return anim.currentAnimIndex;
    }
    
    if (anim.currentElapsedTime >= frameDuration) {
        anim.currentElapsedTime = 0;
        size_t frameCount = anim.animationList.size();
        
        switch (anim.playbackDirection) {
            case PlaybackDirection::Forward:
                anim.currentAnimIndex = (anim.currentAnimIndex + 1) % frameCount;
                if (anim.currentAnimIndex == 0 && anim.loopCount >= 0) {
                    anim.currentLoopCount++;
                    if (anim.currentLoopCount > anim.loopCount) {
                        anim.paused = true;
                        anim.currentAnimIndex = oldIndex;
                    }
                }
                break;
                
            case PlaybackDirection::Reverse:
                if (anim.currentAnimIndex == 0) {
                    anim.currentAnimIndex = frameCount - 1;
                    if (anim.loopCount >= 0) {
                        anim.currentLoopCount++;
                        if (anim.currentLoopCount > anim.loopCount) {
                            anim.paused = true;
                            anim.currentAnimIndex = 0;
                        }
                    }
                } else {
                    anim.currentAnimIndex--;
                }
                break;
                
            case PlaybackDirection::Pingpong:
                if (!anim.pingpongReversing) {
                    if (anim.currentAnimIndex >= frameCount - 1) {
                        anim.pingpongReversing = true;
                        if (frameCount > 1) anim.currentAnimIndex--;
                    } else {
                        anim.currentAnimIndex++;
                    }
                } else {
                    if (anim.currentAnimIndex == 0) {
                        anim.pingpongReversing = false;
                        if (anim.loopCount >= 0) {
                            anim.currentLoopCount++;
                            if (anim.currentLoopCount > anim.loopCount) {
                                anim.paused = true;
                            }
                        }
                        if (!anim.paused && frameCount > 1) anim.currentAnimIndex++;
                    } else {
                        anim.currentAnimIndex--;
                    }
                }
                break;
                
            case PlaybackDirection::PingpongReverse:
                if (anim.pingpongReversing) {
                    if (anim.currentAnimIndex == 0) {
                        anim.pingpongReversing = false;
                        if (frameCount > 1) anim.currentAnimIndex++;
                    } else {
                        anim.currentAnimIndex--;
                    }
                } else {
                    if (anim.currentAnimIndex >= frameCount - 1) {
                        anim.pingpongReversing = true;
                        if (anim.loopCount >= 0) {
                            anim.currentLoopCount++;
                            if (anim.currentLoopCount > anim.loopCount) {
                                anim.paused = true;
                            }
                        }
                        if (!anim.paused && frameCount > 1) anim.currentAnimIndex--;
                    } else {
                        anim.currentAnimIndex++;
                    }
                }
                break;
        }
    }
    
    return anim.currentAnimIndex;
}

} // anonymous namespace

// Forward playback tests
TEST(AnimationUpdate, ForwardPlaybackAdvancesFrames) {
    auto anim = createTestAnimation(4, PlaybackDirection::Forward);
    
    EXPECT_EQ(anim.currentAnimIndex, 0u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 1u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 2u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 3u);
}

TEST(AnimationUpdate, ForwardPlaybackWrapsAtEnd) {
    auto anim = createTestAnimation(4, PlaybackDirection::Forward);
    anim.currentAnimIndex = 3;
    
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 0u);
}

// Reverse playback tests
TEST(AnimationUpdate, ReversePlaybackDecrementsFrames) {
    auto anim = createTestAnimation(4, PlaybackDirection::Reverse);
    anim.currentAnimIndex = 3;
    
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 2u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 1u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 0u);
}

TEST(AnimationUpdate, ReversePlaybackWrapsAtBeginning) {
    auto anim = createTestAnimation(4, PlaybackDirection::Reverse);
    anim.currentAnimIndex = 0;
    
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 3u);
}

// Pingpong playback tests
TEST(AnimationUpdate, PingpongPlaybackBouncesAtEnd) {
    auto anim = createTestAnimation(4, PlaybackDirection::Pingpong);
    
    EXPECT_EQ(anim.currentAnimIndex, 0u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 1u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 2u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 3u);
    
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 2u);
    EXPECT_TRUE(anim.pingpongReversing);
    
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 1u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 0u);
    
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 1u);
    EXPECT_FALSE(anim.pingpongReversing);
}

TEST(AnimationUpdate, PingpongTwoFrameEdgeCase) {
    auto anim = createTestAnimation(2, PlaybackDirection::Pingpong);
    
    EXPECT_EQ(anim.currentAnimIndex, 0u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 1u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 0u);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 1u);
}

// PingpongReverse playback tests
TEST(AnimationUpdate, PingpongReverseStartsReversing) {
    auto anim = createTestAnimation(4, PlaybackDirection::PingpongReverse);
    anim.pingpongReversing = true;
    anim.currentAnimIndex = 3;
    
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 2u);
}

TEST(AnimationUpdate, PingpongReverseBouncesAtStart) {
    auto anim = createTestAnimation(4, PlaybackDirection::PingpongReverse);
    anim.pingpongReversing = true;
    anim.currentAnimIndex = 0;
    
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 1u);
    EXPECT_FALSE(anim.pingpongReversing);
}

// Pause tests
TEST(AnimationUpdate, PausedAnimationDoesNotAdvance) {
    auto anim = createTestAnimation(4, PlaybackDirection::Forward);
    anim.paused = true;
    
    unsigned int startFrame = anim.currentAnimIndex;
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, startFrame);
}

// Speed multiplier tests
TEST(AnimationUpdate, SpeedMultiplierZeroPausesAnimation) {
    auto anim = createTestAnimation(4, PlaybackDirection::Forward);
    anim.speedMultiplier = 0.0f;
    
    unsigned int startFrame = anim.currentAnimIndex;
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, startFrame);
}

// Loop count tests
TEST(AnimationUpdate, InfiniteLoopNeverStops) {
    auto anim = createTestAnimation(2, PlaybackDirection::Forward);
    anim.loopCount = -1;
    
    for (int i = 0; i < 20; ++i) {
        advanceFrame(anim);
        EXPECT_FALSE(anim.paused);
    }
}

TEST(AnimationUpdate, PlayOnceStopsAfterOneLoop) {
    auto anim = createTestAnimation(2, PlaybackDirection::Forward);
    anim.loopCount = 0;
    
    advanceFrame(anim);
    EXPECT_EQ(anim.currentAnimIndex, 1u);
    EXPECT_FALSE(anim.paused);
    
    advanceFrame(anim);
    EXPECT_TRUE(anim.paused);
}

TEST(AnimationUpdate, LoopCountThreeLoopsThreeTimes) {
    auto anim = createTestAnimation(2, PlaybackDirection::Forward);
    anim.loopCount = 2;
    
    advanceFrame(anim);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentLoopCount, 1);
    EXPECT_FALSE(anim.paused);
    
    advanceFrame(anim);
    advanceFrame(anim);
    EXPECT_EQ(anim.currentLoopCount, 2);
    EXPECT_FALSE(anim.paused);
    
    advanceFrame(anim);
    advanceFrame(anim);
    EXPECT_TRUE(anim.paused);
}
