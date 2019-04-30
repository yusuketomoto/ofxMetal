#include "ofxMetalRenderer.h"


namespace ofx {
namespace Metal {

void RendererBase::setup(Device *device, MTLPixelFormat mtlPixelFormat)
{
    
}

void RendererBase::drawToTexture(Texture &texture)
{
    _size = CGSizeMake(texture.getWidth(), texture.getHeight());
    id<MTLCommandBuffer> commandBuffer = drawToMetalTexture(texture.getMetalTexture());
    [commandBuffer commit];
}

} //Metal
} // ofx
