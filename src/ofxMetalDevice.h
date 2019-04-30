#pragma once

#include "ofMain.h"
#include <Metal/Metal.h>


namespace ofx {
namespace Metal {

class Device
{
    id<MTLDevice> device;
    
public:
    void setup();
    
    id<MTLDevice> getDevice();
};

} // Metal
} // ofx

