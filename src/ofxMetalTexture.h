#pragma once

#include "ofxMetalConstants.h"
#include "ofxMetalDevice.h"

namespace ofx {
namespace Metal {

class Texture
{
public:
    void allocate(Device* devicePtr, int width, int height, MTLPixelFormat mtlPixelFormat);
    
    void draw(float x, float y, float width = ofGetWidth(), float height = ofGetHeight());

    id<MTLTexture> getMetalTexture();
    ofTexture getTexture();
    void bind();
    void unbind();
    float getWidth() const;
    float getHeight() const;
    
protected:
    void createGLTexture();
    void createMetalTexture();
    
protected:
    id<MTLDevice> device;
    id<MTLTexture> metalTexture;
    GLuint openGLTexture;
    ofTexture texture;
    
    const AAPLTextureFormatInfo *formatInfo;
    
    PlatformGLContext *openGLContext;
    
    CVPixelBufferRef cvPixelBuffer;
    CVMetalTextureRef cvMtlTexture; // requires deployment target >= 10.13
#ifdef TARGET_OSX
    CVOpenGLTextureCacheRef cvGLTextureCache;
    CVOpenGLTextureRef cvGLTexture;
    CGLPixelFormatObj cglPixelFormat;
    //#else // if!(TARGET_IOS || TARGET_TVOS)
#else if(TARGET_IOS || TARGET_TVOS)
    CVOpenGLESTextureRef cvGLTexture;
    CVOpenGLESTextureCacheRef cvGLTextureCache;
#endif // !(TARGET_IOS || TARGET_TVOS)
    
    CVMetalTextureCacheRef cvMtlTextureCache;
    CGSize size;
};

} // Metal
} // ofx
