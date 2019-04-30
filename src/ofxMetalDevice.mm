#include "ofxMetalDevice.h"

namespace ofx {
namespace Metal {

void Device::setup()
{
    device = MTLCreateSystemDefaultDevice();
}

id<MTLDevice> Device::getDevice()
{
    return device;
}

} // Metal
} // ofx
