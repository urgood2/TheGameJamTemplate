#include "loading_screen.hpp"
#include "loading_progress.hpp"

#ifndef __EMSCRIPTEN__
#include <taskflow.hpp>
#include <raylib.h>
#include <thread>
#include <spdlog/spdlog.h>
#endif

namespace loading_screen {

static LoadingProgress s_progress;

#ifndef __EMSCRIPTEN__
static std::unique_ptr<tf::Executor> s_executor;
static std::unique_ptr<tf::Taskflow> s_taskflow;
static bool s_useSynchronousMode = false;
static int s_pendingTasks = 0;
static std::mutex s_taskCountMutex;
#endif

void init() {
    s_progress.percentage = 0.0f;
    s_progress.currentStage = 0;
    s_progress.totalStages = 0;
    s_progress.isComplete = false;
    s_progress.hasError = false;
    {
        std::lock_guard<std::mutex> lock(s_progress.stageMutex);
        s_progress.currentStageName.clear();
        s_progress.errorMessage.clear();
    }
}

void shutdown() {
#ifndef __EMSCRIPTEN__
    s_executor.reset();
    s_taskflow.reset();
#endif
}

LoadingProgress& getProgress() {
    return s_progress;
}

void setStage(int index, int total, const std::string& name) {
    s_progress.currentStage = index;
    s_progress.totalStages = total;
    if (total > 0) {
        s_progress.percentage = static_cast<float>(index) / static_cast<float>(total);
    }
    {
        std::lock_guard<std::mutex> lock(s_progress.stageMutex);
        s_progress.currentStageName = name;
    }
}

void setComplete() {
    s_progress.percentage = 1.0f;
    s_progress.isComplete = true;
}

void setError(const std::string& message) {
    s_progress.hasError = true;
    {
        std::lock_guard<std::mutex> lock(s_progress.stageMutex);
        s_progress.errorMessage = message;
    }
}

#ifndef __EMSCRIPTEN__

void render(float dt) {
    int screenWidth = GetScreenWidth();
    int screenHeight = GetScreenHeight();
    
    ClearBackground(Color{30, 30, 30, 255});
    
    constexpr int barWidth = 400;
    constexpr int barHeight = 20;
    int barX = (screenWidth - barWidth) / 2;
    int barY = screenHeight / 2;
    
    DrawRectangle(barX, barY, barWidth, barHeight, DARKGRAY);
    
    float progress = s_progress.percentage.load();
    int fillWidth = static_cast<int>(barWidth * progress);
    DrawRectangle(barX, barY, fillWidth, barHeight, Color{100, 200, 100, 255});
    
    DrawRectangleLines(barX, barY, barWidth, barHeight, LIGHTGRAY);
    
    int percent = static_cast<int>(progress * 100.0f);
    const char* percentText = TextFormat("%d%%", percent);
    int textWidth = MeasureText(percentText, 20);
    DrawText(percentText, (screenWidth - textWidth) / 2, barY + barHeight + 10, 20, WHITE);
    
    std::string stageName;
    {
        std::lock_guard<std::mutex> lock(s_progress.stageMutex);
        stageName = s_progress.currentStageName;
    }
    if (!stageName.empty()) {
        int stageTextWidth = MeasureText(stageName.c_str(), 16);
        DrawText(stageName.c_str(), (screenWidth - stageTextWidth) / 2, barY - 30, 16, LIGHTGRAY);
    }
}

void initExecutor(int configuredThreads) {
    unsigned int hwConcurrency = std::thread::hardware_concurrency();
    if (hwConcurrency == 0) hwConcurrency = 4;
    
    int numThreads;
    if (configuredThreads < 0) {
        s_useSynchronousMode = true;
        spdlog::info("[LoadingScreen] Using synchronous loading mode");
        return;
    } else if (configuredThreads == 0) {
        numThreads = static_cast<int>(hwConcurrency) - 1;
        if (numThreads < 1) numThreads = 1;
    } else {
        numThreads = std::min(configuredThreads, static_cast<int>(hwConcurrency) - 1);
        if (numThreads < 1) numThreads = 1;
    }
    
    s_useSynchronousMode = false;
    s_pendingTasks = 0;
    
    try {
        s_executor = std::make_unique<tf::Executor>(static_cast<size_t>(numThreads));
        s_taskflow = std::make_unique<tf::Taskflow>();
        spdlog::info("[LoadingScreen] Initialized executor with {} threads", numThreads);
    } catch (const std::exception& e) {
        spdlog::error("[LoadingScreen] Failed to create executor: {}. Falling back to synchronous mode.", e.what());
        s_useSynchronousMode = true;
        s_executor.reset();
        s_taskflow.reset();
    }
}

void runAsync(std::function<void()> task, const std::string& stageName) {
    if (s_useSynchronousMode || !s_executor) {
        {
            std::lock_guard<std::mutex> lock(s_progress.stageMutex);
            s_progress.currentStageName = stageName;
        }
        try {
            task();
        } catch (const std::exception& e) {
            setError(std::string("Error in ") + stageName + ": " + e.what());
        }
        return;
    }
    
    {
        std::lock_guard<std::mutex> lock(s_taskCountMutex);
        s_pendingTasks++;
    }
    
    s_executor->silent_async([task, stageName]() {
        try {
            task();
        } catch (const std::exception& e) {
            setError(std::string("Error in ") + stageName + ": " + e.what());
        }
        {
            std::lock_guard<std::mutex> lock(s_taskCountMutex);
            s_pendingTasks--;
        }
    });
}

void waitForCompletion() {
    if (s_useSynchronousMode || !s_executor) {
        return;
    }
    s_executor->wait_for_all();
}

void shutdownExecutor() {
    if (s_executor) {
        s_executor->wait_for_all();
    }
    s_executor.reset();
    s_taskflow.reset();
}

#endif

}
