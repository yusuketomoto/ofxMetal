#include "ofMain.h"
#include "ofxiOS.h"
#include "ofxMetal.h"

class ofApp : public ofxiOSApp {
    
    ofxMetal::Device device;
    ofxMetal::Texture texture;
    ofxMetal::TestRenderer renderer;
    ofEasyCam ecam;
    ofMesh mesh;
    ofLight light;
    
public:
    void setup()
    {
        ofBackground(0);
        ofSetFrameRate(60);
        ofSetVerticalSync(true);
        
        float w = ofGetWidth();
        float h = ofGetHeight();
        MTLPixelFormat pixelFormat = MTLPixelFormatBGRA8Unorm;
        device.setup();
        texture.allocate(&device, w, h, pixelFormat);
        renderer.setup(&device, pixelFormat);
        
        mesh = ofBoxPrimitive(w * 0.1, h * 0.1, std::min(w, h) * 0.1).getMesh();
    }
    void update() {
        renderer.drawToTexture(texture);
    }
    void draw() {
        ofEnableDepthTest();
 
        ecam.begin();
        ofPushMatrix();
        ofScale(3, 3, 3);
        texture.bind();
        mesh.draw();
        texture.unbind();
        ofPopMatrix();
        ecam.end();
 
        ofDrawBitmapString(ofGetFrameRate(), 20, 20);
    }
};

//========================================================================

int main() {
    
    //  here are the most commonly used iOS window settings.
    //------------------------------------------------------
    ofiOSWindowSettings settings;
    settings.enableRetina = true; // enables retina resolution if the device supports it.
    settings.enableDepth = true; // enables depth buffer for 3d drawing.
    settings.enableAntiAliasing = false; // enables anti-aliasing which smooths out graphics on the screen.
    settings.numOfAntiAliasingSamples = 0; // number of samples used for anti-aliasing.
    settings.enableHardwareOrientation = false; // enables native view orientation.
    settings.enableHardwareOrientationAnimation = false; // enables native orientation changes to be animated.
    settings.glesVersion = OFXIOS_RENDERER_ES2; // type of renderer to use, ES1, ES2, ES3
    settings.windowMode = OF_FULLSCREEN;
    ofCreateWindow(settings);
    
	return ofRunApp(new ofApp);
}
