#pragma once

#include "ofMain.h"
#include <Metal/Metal.h>


namespace ofx {
namespace Metal {

class Device
{
    id<MTLDevice> device;
    
public:
    static id<MTLDevice> defaultDevice();
    
private:
    Device();
    static Device& singleton();
};

} // Metal
} // ofx

