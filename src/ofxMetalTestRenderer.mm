#include "ofxMetalTestRenderer.h"
#include "ofMain.h"
#include <MetalKit/MetalKit.h>

#if TARGET_IOS
#define GL_UNSIGNED_INT_8_8_8_8_REV 0x8367
#endif

#import "AAPLShaderTypes.h"
#import "AAPLMathUtilities.h"


namespace ofx {
namespace Metal {

void TestRenderer::setup(Device *device, MTLPixelFormat mtlPixelFormat)
{
    id<MTLDevice> _device = device->getDevice();
    
    _inFlightSemaphore = dispatch_semaphore_create(AAPLMaxBuffersInFlight);
    
    _library = [_device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [_library newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [_library newFunctionWithName:@"fragmentShader"];
    
    // Create a reusable pipeline state
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    pipelineStateDescriptor.vertexFunction = vertexFunction;
    pipelineStateDescriptor.fragmentFunction = fragmentFunction;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = mtlPixelFormat;
    
    NSError *error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
    if (!_pipelineState)
    {
        NSLog(@"Failed to create create render pipeline state, error %@", error);
    }
    
    // Create and allocate the dynamic uniform buffer objects.
    for(NSUInteger i = 0; i < AAPLMaxBuffersInFlight; i++)
    {
        // Indicate shared storage so that both the  CPU can access the buffers
        const MTLResourceOptions storageMode = MTLResourceStorageModeShared;
        
        _dynamicUniformBuffers[i] = [_device newBufferWithLength:sizeof(AAPLUniforms)
                                                         options:storageMode];
        
        _dynamicUniformBuffers[i].label = [NSString stringWithFormat:@"UniformBuffer%lu", i];
    }
    
    // Create the command queue
    _commandQueue = [_device newCommandQueue];
    static const AAPLVertex QuadVertices[] =
    {
        //  Positions                        TexCoords
        { { -0.75,  -0.75,  0.0,  1.0 }, { 0.0, 1.0 } },
        { { -0.75,   0.75,  0.0,  1.0 }, { 0.0, 0.0 } },
        { {  0.75,  -0.75,  0.0,  1.0 }, { 1.0, 1.0 } },
        
        { {  0.75,  -0.75,  0.0,  1.0 }, { 1.0, 1.0 } },
        { { -0.75,   0.75,  0.0,  1.0 }, { 0.0, 0.0 } },
        { {  0.75,   0.75,  0.0,  1.0 }, { 1.0, 0.0 } },
    };
    
    _quadVertexBuffer = [_device newBufferWithBytes:QuadVertices
                                             length:sizeof(QuadVertices)
                                            options:0];
    
    _renderPassDescriptor = [MTLRenderPassDescriptor new];
    _renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0.5, 0.5, 1);
    _renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    _renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    _rotationIncrement = 0.01;
    
    
    
    MTKTextureLoader *textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
    
    NSString *texPath = [NSString stringWithUTF8String:ofToDataPath("QuadWithMetalToPixelBuffer.png").c_str()];
    NSURL *labelMapURL = [NSURL fileURLWithPath:texPath];
    _labelMap = [textureLoader newTextureWithContentsOfURL:labelMapURL options:nil error:&error];
    
    if(!_labelMap || error)
    {
        NSLog(@"Error loading Metal texture from file: %@", error.localizedDescription);
    }
    
    texPath = [NSString stringWithUTF8String:ofToDataPath("Colors.png").c_str()];
    NSURL *baseMapURL = [NSURL fileURLWithPath:texPath];
    _baseMap = [textureLoader newTextureWithContentsOfURL:baseMapURL options:nil error:&error];
    
    if(!_baseMap || error)
    {
        NSLog(@"Error loading Metal texture from file: %@", error.localizedDescription);
    }
    ofLog() << "setup renderer okay";
}

id<MTLCommandBuffer> TestRenderer::drawToMetalTexture(id<MTLTexture> texture)
{
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
    
    updateState();
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
     {
         dispatch_semaphore_signal(block_sema);
     }];
    
    _renderPassDescriptor.colorAttachments[0].texture = texture;
    
    id<MTLRenderCommandEncoder> renderEncoder =
    [commandBuffer renderCommandEncoderWithDescriptor:_renderPassDescriptor];
    renderEncoder.label = @"MyRenderEncoder";
    
    // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
    [renderEncoder pushDebugGroup:@"DrawMesh"];
    
    // Set render command encoder state
    [renderEncoder setCullMode:MTLCullModeBack];
    [renderEncoder setRenderPipelineState:_pipelineState];
    
    // Set any buffers fed into the render pipeline
    [renderEncoder setVertexBuffer:_dynamicUniformBuffers[_currentBufferIndex]
                            offset:0
                           atIndex:AAPLBufferIndexUniforms];
    
    [renderEncoder setFragmentBuffer:_dynamicUniformBuffers[_currentBufferIndex]
                              offset:0
                             atIndex:AAPLBufferIndexUniforms];
    
    // Set buffer with vertices for the quad
    [renderEncoder setVertexBuffer:_quadVertexBuffer
                            offset:0
                           atIndex:AAPLBufferIndexVertices];
    
    // Set base texture (which is either loaded from file or the texture rendered to with OpenGL)
    [renderEncoder setFragmentTexture:_baseMap
                              atIndex:AAPLTextureIndexBaseMap];
    
    // Set label texture that set "This quad is rendered with Metal"
    [renderEncoder setFragmentTexture:_labelMap
                              atIndex:AAPLTextureIndexLabelMap];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                      vertexStart:0
                      vertexCount:6];
    
    [renderEncoder popDebugGroup];
    
    // Done encoding commands
    [renderEncoder endEncoding];
    
    return commandBuffer;
}

void TestRenderer::updateState()
{
    float aspect = (float)_size.width / _size.height;
    _projectionMatrix = matrix_perspective_right_hand(1, aspect, .1, 5.0);
    
    
    if(_rotation > 30*(M_PI/180.0f))
    {
        _rotationIncrement = -0.01;
    }
    else if(_rotation < -30*(M_PI/180.0f))
    {
        _rotationIncrement = 0.01;
    }
    _rotation += _rotationIncrement;
    
    matrix_float4x4 rotation = matrix4x4_rotation(_rotation, 0.0, 1.0, 0.0);
    matrix_float4x4 translation = matrix4x4_translation(0.0, 0.0, -2.0);
    matrix_float4x4 modelView = matrix_multiply(translation, rotation);
    
    matrix_float4x4 mvp = matrix_multiply(_projectionMatrix, modelView);
    
    AAPLUniforms *uniforms = (AAPLUniforms *)_dynamicUniformBuffers[_currentBufferIndex].contents;
    uniforms->mvp = mvp;
}

} // Metal
} // ofx
