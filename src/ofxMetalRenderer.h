#pragma once

#include "ofxMetalTexture.h"

namespace ofx {
namespace Metal {

class RendererBase
{
public:
    virtual void setup(MTLPixelFormat mtlPixelFormat);
    void drawToTexture(Texture& texture);
    
protected:
    virtual id<MTLCommandBuffer> drawToMetalTexture(id<MTLTexture> texture) = 0;
    
protected:
    CGSize size;
};

} // Metal
} // ofx
