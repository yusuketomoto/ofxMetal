#pragma once

#include "ofxMetalDevice.h"
#include "ofxMetalTexture.h"

namespace ofx {
namespace Metal {

class TestRenderer
{
public:
    void setup(Device* device, MTLPixelFormat mtlPixelFormat);
    void drawToTexture(Texture& texture);
    
protected:
    virtual id<MTLCommandBuffer> drawToMetalTexture(id<MTLTexture> texture);
    void updateState();
    
protected:
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _commandQueue;

    static const NSUInteger AAPLMaxBuffersInFlight = 3;
    dispatch_semaphore_t _inFlightSemaphore;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLTexture> _baseMap;
    id<MTLTexture> _labelMap;
    id<MTLBuffer> _quadVertexBuffer;
    id<MTLBuffer> _dynamicUniformBuffers[AAPLMaxBuffersInFlight];
    uint8_t _currentBufferIndex;
    matrix_float4x4 _projectionMatrix;
    float _rotation;
    float _rotationIncrement;
    MTLRenderPassDescriptor *_renderPassDescriptor;
    
    CGSize _size;
};

} // Metal
} // ofx
