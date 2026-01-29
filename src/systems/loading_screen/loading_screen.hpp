#pragma once

#include <string>

namespace loading_screen {

struct LoadingProgress;

void init();
void shutdown();
LoadingProgress& getProgress();
void setStage(int index, int total, const std::string& name);
void setComplete();
void setError(const std::string& message);

}
