//
//  HWDecoder.m
//  HWDecorder
//
//  Created by xiaobing yao on 2022/12/19.
//

#import "HWDecoder.h"
#import "HWPacketReader.h"
#import <VideoToolbox/VideoToolbox.h>


@interface HWDecoder ()<HWPacketReaderDelegate>
{
    VTDecompressionSessionRef _decoder;
    BOOL _setupSuccess;
    CMVideoFormatDescriptionRef _fmt_desc;
}

@property (nonatomic, strong) HWPacketReader *packetReader;
@property (nonatomic) dispatch_queue_t queue;

@end


@implementation HWDecoder

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _packetReader = [[HWPacketReader alloc] init];
        _queue = dispatch_queue_create("com.xx.decode.queu", DISPATCH_QUEUE_SERIAL);
        _packetReader.delegate = self;
        [_packetReader startRunning];
    }
    return self;
}


void decompressionOutputCallback(
                                 void * CM_NULLABLE decompressionOutputRefCon,
                                 void * CM_NULLABLE sourceFrameRefCon,
                                 OSStatus status,
                                 VTDecodeInfoFlags infoFlags,
                                 CM_NULLABLE CVImageBufferRef imageBuffer,
                                 CMTime presentationTimeStamp,
                                 CMTime presentationDuration ) {
    
    
    
    NSLog(@"%@, status = %d", imageBuffer, status);
}


- (void)setupDecoderWithFmtDesc:(CMVideoFormatDescriptionRef)fmt_desc {
        
    
    _fmt_desc = CFRetain(fmt_desc);
    
    VTDecompressionOutputCallbackRecord callback;
    callback.decompressionOutputCallback = decompressionOutputCallback;
    callback.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
    OSStatus ret = VTDecompressionSessionCreate(NULL,
                                       fmt_desc,
                                       NULL,
                                       NULL,
                                       &callback,
                                       &_decoder);
    if (ret) {
        NSLog(@"create decoder failed, code = %d",ret);
        return;
    }
    
    _setupSuccess = YES;
}

- (void)packetReader:(nonnull HWPacketReader *)packetReader didReadPacket:(nonnull H264Packet *)packet {
    
    
    uint8_t *sps = NULL;
    uint8_t *pps = NULL;
    size_t spsSize = 0;
    size_t ppsSize = 0;
    
    
    uint32_t blockBufferSize = 0; // (4 bytes length + nalu)  * n
    
    for (int i = 0; i < packet->nb_nals; i++) {
        H264NAL *nal = &packet->nals[i];
        if (nal->type == H264_NAL_SPS) {
            sps = nal->data;
            spsSize = nal->size;
            continue;
        }

        if (nal->type == H264_NAL_PPS) {
            pps = nal->data;
            ppsSize = nal->size;
            continue;
        }
        blockBufferSize += 4 + nal->size;
    }
    
    uint8_t *blockBuffer = malloc(blockBufferSize);
    
    int offset = 0;
    for (int i = 0; i < packet->nb_nals; i++) {
        H264NAL *nal = &packet->nals[i];
        if (nal->type == H264_NAL_SPS
            || nal->type == H264_NAL_PPS)
        {
            continue;;
        }
        uint32_t size = htonl(nal->size);
        memcpy(blockBuffer + offset, &size, sizeof(uint32_t));
        offset += sizeof(uint32_t);
        memcpy(blockBuffer + offset, nal->data, nal->size);
        offset += nal->size;
    }

    
    CMVideoFormatDescriptionRef fmt_desc = NULL;
    if (sps && pps) {
        const uint8_t *parameterSetPointers[] = {sps, pps};
        size_t parameterSetSizes[] = {spsSize, ppsSize};
        OSStatus ret = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL,
                                                            2,
                                                            parameterSetPointers,
                                                            parameterSetSizes,
                                                            4,
                                                            &fmt_desc);
        assert(ret == 0);
    }
    
    dispatch_async(_queue, ^{
        if (!self->_setupSuccess) {
            [self setupDecoderWithFmtDesc:fmt_desc];
        }
        [self decode:blockBuffer blockLength:blockBufferSize fmt_desc:fmt_desc];
        if (fmt_desc) {
            CFRelease(fmt_desc);
        }
    });
}

- (void)decode:(void *)memoryBlock blockLength:(size_t)blockLength fmt_desc:(CMVideoFormatDescriptionRef)fmt_desc {
    
    CMBlockBufferRef blockBuffer;
    OSStatus ret = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                      memoryBlock,
                                                      blockLength,
                                                      NULL,
                                                      NULL,
                                                      0,
                                                      blockLength,
                                                      0,
                                                      &blockBuffer);
    
    if (ret) {
        NSLog(@"create block buffer failed, ret = %d", ret);
        return;
    }
    
    CMSampleBufferRef sampleBuffer;
    ret = CMSampleBufferCreate(kCFAllocatorDefault,  // allocator
                               blockBuffer,            // dataBuffer
                               TRUE,                 // dataReady
                               0,                    // makeDataReadyCallback
                               0,                    // makeDataReadyRefcon
                               self->_fmt_desc,             // formatDescription
                               1,                    // numSamples
                               0,                    // numSampleTimingEntries
                               NULL,                 // sampleTimingArray
                               0,                    // numSampleSizeEntries
                               NULL,                 // sampleSizeArray
                               &sampleBuffer);
    
    CFRelease(blockBuffer);
    if (ret) {
        NSLog(@"create sampleBuffer failed, ret =%d", ret);
        return;
    }
    
    ret =  VTDecompressionSessionDecodeFrame(_decoder, sampleBuffer, 0, NULL, NULL);
    switch (ret) {
        case noErr:
            NSLog(@"Decoding one frame succeeded.");
            break;
        case kVTInvalidSessionErr:
            NSLog(@"Error: Invalid session, reset decoder session");
            break;
        case kVTVideoDecoderBadDataErr:
            NSLog(@"Error: decode failed status=%d(Bad data)", ret);
            break;
        default:
            NSLog(@"Error: decode failed status=%d", ret);
            break;
    }
    CFRelease(sampleBuffer);
}





@end

