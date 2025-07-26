#include "ChipmunkShape.hpp"
#include "ChipmunkSpace.hpp"


void ChipmunkShape::addToSpace(ChipmunkSpace* sp) {
    sp->add(this);
}

void ChipmunkShape::removeFromSpace(ChipmunkSpace* sp) {
    sp->remove(this);
}