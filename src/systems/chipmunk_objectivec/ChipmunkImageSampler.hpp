#include "third_party/chipmunk/include/chipmunk/cpBB.h"
#include "third_party/chipmunk/include/chipmunk/chipmunk.h"
#include "third_party/chipmunk/include/chipmunk/cpPolyline.h"

// Helper for fast floor
static inline int floorInt(float f) {
    int i = static_cast<int>(f);
    return (f < 0.0f && f != i) ? i - 1 : i;
}

// Static sampling functions
static cpFloat sampleClampFunc(cpVect point, BitmapSampler* self) {
    cpBB bb = self->_outputRect;
    cpVect clamped = cpBBClampVect(bb, point);
    return self->sampleAt(clamped);
}
static cpFloat sampleBorderFunc(cpVect point, BitmapSampler* self) {
    cpBB bb = self->_outputRect;
    if (cpBBContainsVect(bb, point)) {
        return self->sampleAt(point);
    }
    return self->_borderValue;
}

// BitmapSampler implementation
cpFloat BitmapSampler::sampleAt(cpVect p) const {
    float fx = (_width - 1) * (p.x - _outputRect.l) / (_outputRect.r - _outputRect.l);
    float fy = (_height - 1) * (p.y - _outputRect.b) / (_outputRect.t - _outputRect.b);
    int x = floorInt(fx + 0.5f);
    int y = floorInt(fy + 0.5f);
    if (_flip) y = int(_height - 1) - y;
    size_t idx = size_t(y) * _stride + size_t(x) * _bytesPerPixel + _component;
    return static_cast<cpFloat>(_pixels[idx]) / 255.0f;
}

std::vector<Polyline> BitmapSampler::marchAll(bool bordered, bool hard) {
    cpBB bb = _outputRect;
    unsigned xs = bordered ? _width + 2 : _width;
    unsigned ys = bordered ? _height + 2 : _height;
    if (bordered) bb = borderedBB(bb);
    return cpMarch(reinterpret_cast<cpMarchSampleFunc>(_sampleFunc), this, bb, xs, ys, hard);
}

cpBB BitmapSampler::borderedBB(const cpBB& bb) {
    float xBorder = (bb.r - bb.l) / float(_width - 1);
    float yBorder = (bb.t - bb.b) / float(_height - 1);
    return cpBBNew(bb.l - xBorder, bb.b - yBorder,
                   bb.r + xBorder, bb.t + yBorder);
}

// CGContextSampler implementation
CGContextSampler::CGContextSampler(unsigned width, unsigned height,
                                   CGColorSpaceRef cs,
                                   CGBitmapInfo bi,
                                   unsigned component)
: BitmapSampler(0, 0, 0, 0, 0, false, nullptr)
{
    // Create temp to query bits
    CGContextRef temp = CGBitmapContextCreate(nullptr, width, height, 8, 0, cs, bi);
    assert(temp && "Failed to create temporary CGBitmapContext");
    size_t bpc = CGBitmapContextGetBitsPerComponent(temp);
    size_t bpp = CGBitmapContextGetBitsPerPixel(temp) / 8;
    assert(bpc == 8 && "Only 8-bit supported");
    CGContextRelease(temp);

    size_t stride = width * bpp;
    _data.resize(stride * height);
    _context = CGBitmapContextCreate(_data.data(), width, height,
                                     bpc, stride, cs, bi);

    // Initialize base sampler state
    _width = width;
    _height = height;
    _stride = stride;
    _bytesPerPixel = bpp;
    _component = component;
    _flip = true;
    _pixels = _data.data();
    _outputRect = cpBBNew(0.5f, 0.5f, width - 0.5f, height - 0.5f);
    _sampleFunc = sampleClampFunc;
}

CGContextSampler::~CGContextSampler() {
    if (_context) CGContextRelease(_context);
}

// ImageSampler implementation
CGImageRef ImageSampler::loadImage(const std::string& path) {
    CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                    CFStringCreateWithCString(kCFAllocatorDefault,
                                              path.c_str(), kCFStringEncodingUTF8),
                    kCFURLPOSIXPathStyle, false);
    CGImageSourceRef src = CGImageSourceCreateWithURL(url, nullptr);
    CGImageRef img = CGImageSourceCreateImageAtIndex(src, 0, nullptr);
    CFRelease(src);
    CFRelease(url);
    assert(img && "Image load failed");
    return img;
}

ImageSampler::ImageSampler(CGImageRef image, bool isMask,
                           unsigned contextWidth,
                           unsigned contextHeight)
: CGContextSampler(
    isMask ? CGImageGetWidth(image) : contextWidth,
    isMask ? CGImageGetHeight(image) : contextHeight,
    isMask ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB(),
    isMask ? kCGImageAlphaNone : kCGImageAlphaOnly,
    0)
{
    CGRect rect = CGRectMake(0, 0,
        contextWidth ? contextWidth : CGImageGetWidth(image),
        contextHeight ? contextHeight : CGImageGetHeight(image));
    CGContextDrawImage(_context, rect, image);
}

ImageSampler::ImageSampler(const std::string& filePath, bool isMask)
: ImageSampler(loadImage(filePath), isMask, 0, 0) {}
