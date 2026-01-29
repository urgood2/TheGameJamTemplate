#pragma once

#include <atomic>
#include <mutex>
#include <string>

namespace loading_screen {

struct LoadingProgress {
    std::atomic<float> percentage{0.0f};
    std::atomic<int> currentStage{0};
    std::atomic<int> totalStages{0};
    std::mutex stageMutex;
    std::string currentStageName;
    std::atomic<bool> isComplete{false};
    std::atomic<bool> hasError{false};
    std::string errorMessage;
};

}
