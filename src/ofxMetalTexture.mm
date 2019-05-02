#include "ofxMetalTexture.h"

#if TARGET_OS_IOS
#include "ofxiOS.h"
#define GL_UNSIGNED_INT_8_8_8_8_REV 0x8367
#endif

namespace ofx {
namespace Metal {


// Table of equivalent formats across CoreVideo, Metal, and OpenGL
static const AAPLTextureFormatInfo AAPLInteropFormatTable[] =
{
    // Core Video Pixel Format,               Metal Pixel Format,            GL internalformat, GL format,   GL type
    { kCVPixelFormatType_32BGRA,              MTLPixelFormatBGRA8Unorm,      GL_RGBA,           GL_BGRA_EXT, GL_UNSIGNED_INT_8_8_8_8_REV },
#if TARGET_OS_IOS
    { kCVPixelFormatType_32BGRA,              MTLPixelFormatBGRA8Unorm_sRGB, GL_RGBA,           GL_BGRA_EXT, GL_UNSIGNED_INT_8_8_8_8_REV },
#else
    { kCVPixelFormatType_ARGB2101010LEPacked, MTLPixelFormatBGR10A2Unorm,    GL_RGB10_A2,       GL_BGRA,     GL_UNSIGNED_INT_2_10_10_10_REV },
    { kCVPixelFormatType_32BGRA,              MTLPixelFormatBGRA8Unorm_sRGB, GL_SRGB8_ALPHA8,   GL_BGRA,     GL_UNSIGNED_INT_8_8_8_8_REV },
    { kCVPixelFormatType_64RGBAHalf,          MTLPixelFormatRGBA16Float,     GL_RGBA,           GL_RGBA,     GL_HALF_FLOAT },
#endif
};

static const NSUInteger AAPLNumInteropFormats = sizeof(AAPLInteropFormatTable) / sizeof(AAPLTextureFormatInfo);

const AAPLTextureFormatInfo *const textureFormatInfoFromMetalPixelFormat(MTLPixelFormat pixelFormat)
{
    for(int i = 0; i < AAPLNumInteropFormats; i++) {
        if(pixelFormat == AAPLInteropFormatTable[i].mtlFormat) {
            return &AAPLInteropFormatTable[i];
        }
    }
    return NULL;
}


void Texture::allocate(int width, int height, MTLPixelFormat mtlPixelFormat)
{
    device = Device::defaultDevice();

    size = CGSizeMake(width, height);
    formatInfo = textureFormatInfoFromMetalPixelFormat(mtlPixelFormat);
    
#ifdef TARGET_OSX
    openGLContext = (NSOpenGLContext*)ofGetWindowPtr()->getNSGLContext();
    cglPixelFormat = openGLContext.pixelFormat.CGLPixelFormatObj;
#else
    auto window = (ofAppiOSWindow*)ofGetWindowPtr();
    auto settings = window->getSettings();
    if (settings.windowControllerType == METAL_KIT || settings.windowControllerType == GL_KIT) {
        openGLContext = [[ofxiOSGLKView getInstance] context];
    }
    else {
        openGLContext = [[ofxiOSEAGLView getInstance] context];
    }
#endif
    
    NSDictionary* cvBufferProperties = @{
        (__bridge NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
        (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
    };
    CVReturn cvret = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width, height,
                                         formatInfo->cvPixelFormat,
                                         (__bridge CFDictionaryRef)cvBufferProperties,
                                         &cvPixelBuffer);
    if (cvret != kCVReturnSuccess)
    {
        assert(!"Failed to create CVPixelBuffer");
    }
    
    createGLTexture();
    createMetalTexture();
    
    texture.allocate(width, height, GL_RGBA);
    texture.setUseExternalTextureID(openGLTexture);
    
    texture.setTextureMinMagFilter(GL_LINEAR, GL_LINEAR);
    texture.setTextureWrap(GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE);
}

void Texture::draw(float x, float y, float width, float height)
{
    texture.draw(x, y, width, height);
}

id<MTLTexture> Texture::getMetalTexture()
{
    return metalTexture;
}

ofTexture Texture::getTexture()
{
    return texture;
}

void Texture::bind()
{
    texture.bind();
}

void Texture::unbind()
{
    texture.unbind();
}

float Texture::getWidth() const
{
    return texture.getWidth();
}

float Texture::getHeight() const
{
    return texture.getHeight();
}

#ifdef TARGET_OSX
void Texture::createGLTexture()
{
    CVReturn cvret;
    // 1. Create an OpenGL CoreVideo texture cache from the pixel buffer.
    cvret  = CVOpenGLTextureCacheCreate(kCFAllocatorDefault,
                                        nil,
                                        openGLContext.CGLContextObj,
                                        cglPixelFormat,
                                        nil,
                                        &cvGLTextureCache);
    if(cvret != kCVReturnSuccess)
    {
        assert(!"Failed to create OpenGL Texture Cache");
        return NO;
    }
    // 2. Create a CVPixelBuffer-backed OpenGL texture image from the texture cache.
    cvret = CVOpenGLTextureCacheCreateTextureFromImage(
                                                       kCFAllocatorDefault,
                                                       cvGLTextureCache,
                                                       cvPixelBuffer,
                                                       nil,
                                                       &cvGLTexture);
    if(cvret != kCVReturnSuccess)
    {
        assert(!"Failed to create OpenGL Texture From Image");
        return NO;
    }
    // 3. Get an OpenGL texture name from the CVPixelBuffer-backed OpenGL texture image.
    openGLTexture = CVOpenGLTextureGetName(cvGLTexture);
}
#else
void Texture::createGLTexture()
{
    CVReturn cvret;
    // 1. Create an OpenGL ES CoreVideo texture cache from the pixel buffer.
    cvret = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                         nil,
                                         openGLContext,
                                         nil,
                                         &cvGLTextureCache);
    if(cvret != kCVReturnSuccess)
    {
        assert(!"Failed to create OpenGL ES Texture Cache");
    }
    // 2. Create a CVPixelBuffer-backed OpenGL ES texture image from the texture cache.
    cvret = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         cvGLTextureCache,
                                                         cvPixelBuffer,
                                                         nil,
                                                         GL_TEXTURE_2D,
                                                         formatInfo->glInternalFormat,
                                                         size.width, size.height,
                                                         formatInfo->glFormat,
                                                         formatInfo->glType,
                                                         0,
                                                         &cvGLTexture);
    if(cvret != kCVReturnSuccess)
    {
        assert(!"Failed to create OpenGL ES Texture From Image");
    }
    // 3. Get an OpenGL ES texture name from the CVPixelBuffer-backed OpenGL ES texture image.
    openGLTexture = CVOpenGLESTextureGetName(cvGLTexture);
}
#endif
 
void Texture::createMetalTexture()
{
    CVReturn cvret;
    // 1. Create a Metal Core Video texture cache from the pixel buffer.
    cvret = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                      nil,
                                      device,
                                      nil,
                                      &cvMtlTextureCache);
    if(cvret != kCVReturnSuccess)
    {
        ofLog() << "fail CVMetalTextureCacheCreate";
    }
    // 2. Create a CoreVideo pixel buffer backed Metal texture image from the texture cache.
    cvret = CVMetalTextureCacheCreateTextureFromImage(
                                                      kCFAllocatorDefault,
                                                      cvMtlTextureCache,
                                                      cvPixelBuffer, nil,
                                                      formatInfo->mtlFormat,
                                                      size.width, size.height,
                                                      0,
                                                      &cvMtlTexture);
    if(cvret != kCVReturnSuccess)
    {
        assert(!"Failed to create Metal texture cache");
    }
    // 3. Get a Metal texture using the CoreVideo Metal texture reference.
    metalTexture = CVMetalTextureGetTexture(cvMtlTexture);
    // Get a Metal texture object from the Core Video pixel buffer backed Metal texture image
    if(!metalTexture)
    {
        assert(!"Failed to get metal texture from CVMetalTextureRef");
    }
}

} // Metal
} // ofx
