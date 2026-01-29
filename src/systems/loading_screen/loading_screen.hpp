#pragma once

#include <string>
#include <functional>

namespace loading_screen {

struct LoadingProgress;

void init();
void shutdown();
LoadingProgress& getProgress();
void setStage(int index, int total, const std::string& name);
void setComplete();
void setError(const std::string& message);

#ifndef __EMSCRIPTEN__
void render(float dt);
void initExecutor(int configuredThreads);
void runAsync(std::function<void()> task, const std::string& stageName);
void waitForCompletion();
void shutdownExecutor();
#endif

}
