#include "ofMain.h"
#include "ofxMetal.h"

class ofApp : public ofBaseApp {

    ofxMetal::Device device;
    ofxMetal::Texture texture;
    ofxMetal::TestRenderer renderer;
    ofEasyCam ecam;
    ofMesh mesh;

public:
    void setup() {
        ofBackground(0);
        ofSetFrameRate(60);
        ofSetVerticalSync(true);
        
        MTLPixelFormat pixelFormat = MTLPixelFormatBGRA8Unorm;
        device.setup();
        texture.allocate(&device, ofGetWidth(), ofGetHeight(), pixelFormat);
        renderer.setup(&device, pixelFormat);
        
        mesh = ofBoxPrimitive(128, 72, 128).getMesh();
        for (auto& tc: mesh.getTexCoords()) {
            tc.x *= texture.getWidth();
            tc.y *= texture.getHeight();
        }
    }
    void update() {
        renderer.drawToTexture(texture);
    }
    void draw() {
        ofEnableDepthTest();
        
        ecam.begin();
        texture.bind();
        mesh.draw();
        texture.unbind();
        ecam.end();
        
        ofDrawBitmapString(ofGetFrameRate(), 20, 20);
    }
};

//========================================================================
int main( ){
    ofGLFWWindowSettings s;
    s.setSize(1280, 720);
    auto window = ofCreateWindow(s);
    auto app = make_shared<ofApp>();
    ofRunApp(window, app);
    ofRunMainLoop();
}
