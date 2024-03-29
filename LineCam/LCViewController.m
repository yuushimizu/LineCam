#import "LCViewController.h"

@interface LCViewController () {
    UIImageView *_imageView;
    CGImageRef _currentImage;
    AVCaptureSession  *_captureSession;
    CGContextRef _drawnContext;
}

@end

@implementation LCViewController

- (void)buttonClicked {
    _imageView.backgroundColor = [UIColor redColor];
}

- (void)setupViews {
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    self.view = view;
    _imageView = [[UIImageView alloc] initWithFrame:view.bounds];
    [view addSubview:_imageView];
}

- (AVCaptureDeviceFormat *)captureDeviceFormat:(AVCaptureDevice *)captureDevice fps:(int)fps {
    for (AVCaptureDeviceFormat *captureDeviceFormat in captureDevice.formats) {
        if (captureDeviceFormat.mediaType == AVMediaTypeVideo) {
            for (AVFrameRateRange *frameRateRange in captureDeviceFormat.videoSupportedFrameRateRanges) {
                if (frameRateRange.maxFrameRate >= fps) return captureDeviceFormat;
            }
        }
    }
    return nil;
}

- (void)setupCaptureSession {
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [captureDevice lockForConfiguration:nil];
    int fps = 120;
    AVCaptureDeviceFormat *captureDeviceFormat = [self captureDeviceFormat:captureDevice fps:fps];
    captureDevice.activeFormat = captureDeviceFormat;
    captureDevice.activeVideoMaxFrameDuration = CMTimeMake(1, fps);
    captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, fps);
    [captureDevice unlockForConfiguration];
    AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
    [captureDevice lockForConfiguration:nil];
    captureDevice.focusMode = AVCaptureFocusModeLocked;
    [captureDevice unlockForConfiguration];
    [_captureSession addInput:captureDeviceInput];
    AVCaptureVideoDataOutput *captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t dispatchQueue = dispatch_queue_create("jp.yuushimizu.LineCam", nil);
    [captureVideoDataOutput setSampleBufferDelegate:self queue:dispatchQueue];
    captureVideoDataOutput.videoSettings = @{(id) kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithInt:kCVPixelFormatType_32BGRA]};
    AVCaptureConnection *captureConnection = [captureVideoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    captureConnection.enabled = YES;
    [_captureSession addOutput:captureVideoDataOutput];
    [_captureSession startRunning];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self setupViews];
    [self setupCaptureSession];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setImage {
    _imageView.image = [UIImage imageWithCGImage:_currentImage scale:1.0f orientation:UIImageOrientationRight];
}

- (void)updateImage:(CMSampleBufferRef)sampleBuffer {
    int lineWidth = 1;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    size_t capturedWidth = CVPixelBufferGetWidth(imageBuffer);
    size_t capturedHeight = CVPixelBufferGetHeight(imageBuffer);
    CGContextRef capturedContext = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(imageBuffer), capturedWidth, capturedHeight, 8, CVPixelBufferGetBytesPerRow(imageBuffer), colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef capturedImage = CGBitmapContextCreateImage(capturedContext);
    CGContextRelease(capturedContext);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    CGSize screenSize = [UIScreen mainScreen].applicationFrame.size;
    if (!_drawnContext) {
        _drawnContext = CGBitmapContextCreate(NULL, screenSize.width, screenSize.height, 8, screenSize.width * 4, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    }
    if (_currentImage) {
        CGContextDrawImage(_drawnContext, CGRectMake(0, -lineWidth, screenSize.width, screenSize.height), _currentImage);
    }
    CGImageRef lineImage = CGImageCreateWithImageInRect(capturedImage, CGRectMake(0, capturedHeight / 2, capturedWidth, lineWidth));
    CGImageRelease(capturedImage);
    CGContextDrawImage(_drawnContext, CGRectMake(0, screenSize.height - lineWidth, screenSize.width, lineWidth), lineImage);
    CGImageRelease(lineImage);
    CGImageRef previousImage = _currentImage;
    _currentImage = CGBitmapContextCreateImage(_drawnContext);
    if (previousImage) CGImageRelease(previousImage);
    [self performSelectorOnMainThread:@selector(setImage) withObject:nil waitUntilDone:YES];
    CGColorSpaceRelease(colorSpace);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    [self updateImage:sampleBuffer];
}

- (void)dealloc {
    if (_currentImage) CGImageRelease(_currentImage);
    if (_drawnContext) CGContextRelease(_drawnContext);
}

@end
