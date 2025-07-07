When using tracy, 
just un-comment lines with "ZoneScopedN"
and also the lines that import tracy: 
#include "third_party/tracy-master/public/tracy/Tracy.hpp"

Do not use tracy with web builds/release builds, it causes memory issues.