//
//  ViewController.m
//  AudioLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

#import "ViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "SMUGraphHelper.h"
#import "FFTHelper.h"
#import "AudioFileReader.h"

#define BUFFER_SIZE 2048

@interface ViewController ()
@property (strong, nonatomic) Novocaine *audioManager;
@property (strong, nonatomic) CircularBuffer *buffer;
@property (strong, nonatomic) SMUGraphHelper *graphHelper;
@property (strong, nonatomic) FFTHelper *fftHelper;
@property (strong, nonatomic) AudioFileReader *fileReader;
@end



@implementation ViewController

#pragma mark Lazy Instantiation
-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}

-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:BUFFER_SIZE];
    }
    return _buffer;
}

-(SMUGraphHelper*)graphHelper{
    if(!_graphHelper){
        _graphHelper = [[SMUGraphHelper alloc]initWithController:self
                                        preferredFramesPerSecond:15
                                                       numGraphs:3
                                                       plotStyle:PlotStyleSeparated
                                               maxPointsPerGraph:BUFFER_SIZE];
    }
    return _graphHelper;
}

-(FFTHelper*)fftHelper{
    if(!_fftHelper){
        _fftHelper = [[FFTHelper alloc]initWithFFTSize:BUFFER_SIZE];
    }
    
    return _fftHelper;
}

-(AudioFileReader*) fileReader {
    if(!_fileReader) {
        NSURL *inputFileURL = [[NSBundle mainBundle] URLForResource:@"satisfaction" withExtension:@"mp3"];
        _fileReader = [[AudioFileReader alloc]
                       initWithAudioFileURL: inputFileURL
                       samplingRate:self.audioManager.samplingRate
                       numChannels:self.audioManager.numOutputChannels];
        
    }
    
    return _fileReader;
}


#pragma mark VC Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    
    [self.graphHelper setScreenBoundsBottomHalf];
    
    __block ViewController * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        //[weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    
    [self.audioManager play];
    
    //////////////////////////////////////////////////
    
    
    [self.fileReader play];
    self.fileReader.currentTime = 0.0;
    
    
    //__block ViewController * __weak weakSelf = self; // don't increment ARC'
    [self.audioManager setOutputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels)
     {
         [weakSelf.fileReader retrieveFreshAudio:data numFrames:numFrames numChannels:numChannels];
        
//         float zero = 0.0;
         
//         vDSP_vsadd(data, numChannels, &zero, leftSampleData, 1, numFrames);
         
         [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
         
     }];
    
}

#pragma mark GLK Inherited Functions
//  override the GLKViewController update function, from OpenGLES
- (void)update{
    // just plot the audio stream
    
    // get audio stream data
    float* leftSampleData = malloc(sizeof(float)*BUFFER_SIZE/2);
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    float* fftMagnitude = malloc(sizeof(float)*BUFFER_SIZE/2);
    float* fftTwenty = malloc(sizeof(float)*20);
    
    
    
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    
    //send off for graphing
    [self.graphHelper setGraphData:arrayData
                    withDataLength:BUFFER_SIZE
                     forGraphIndex:0];
    
    // take forward FFT
    [self.fftHelper performForwardFFTWithData:arrayData
                   andCopydBMagnitudeToBuffer:fftMagnitude];
    
    // graph the FFT Data
    [self.graphHelper setGraphData:fftMagnitude
                    withDataLength:BUFFER_SIZE/2
                     forGraphIndex:1
                 withNormalization:64.0
                     withZeroValue:-60];
    
    float maxVal = 0.0;
    int batchLength = BUFFER_SIZE/2/20;
    
    for(int i=0; i<20; ++i) {
        vDSP_maxv(&fftMagnitude[i*batchLength], 1, &maxVal, batchLength);
        fftTwenty[i] = maxVal;
    }
    
    // NEW GRAPH FOR ICA 2 PART 2
    [self.graphHelper setGraphData:fftTwenty
                    withDataLength:20
                     forGraphIndex:2
                 withNormalization:64.0
                     withZeroValue:-60];
    
    [self.graphHelper update]; // update the graph
    free(arrayData);
    free(fftMagnitude);
    free(fftTwenty);
    free(leftSampleData);
}

//  override the GLKView draw function, from OpenGLES
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    [self.graphHelper draw]; // draw the graph
}

- (IBAction)goBack:(id)sender {
    
        [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.audioManager pause];
}


@end
