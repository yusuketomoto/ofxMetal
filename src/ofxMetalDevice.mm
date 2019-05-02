#include "ofxMetalDevice.h"

namespace ofx {
namespace Metal {

Device::Device()
{
    device = MTLCreateSystemDefaultDevice();
}

id<MTLDevice> Device::defaultDevice()
{
    return singleton().device;
}

Device& Device::singleton()
{
    static Device o;
    return o;
}

} // Metal
} // ofx
