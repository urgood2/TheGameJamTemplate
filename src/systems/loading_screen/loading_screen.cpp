#include "loading_screen.hpp"
#include "loading_progress.hpp"

namespace loading_screen {

static LoadingProgress s_progress;

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

}
