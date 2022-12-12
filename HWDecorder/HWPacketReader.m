//
//  HWPacketReader.m
//  HWDecorder
//
//  Created by xiaobing yao on 2022/12/15.
//

#import "HWPacketReader.h"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>

static AVFormatContext *fmt_ctx = NULL;
static AVCodecContext *video_dec_ctx = NULL;
static AVStream *video_stream = NULL;
static int video_stream_idx = -1;
static const char *src_filename = NULL;
static AVPacket *pkt = NULL;





@interface HWPacketReader ()
@end

@implementation HWPacketReader

- (instancetype)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (void)startRunning {
    NSString *fileName = [[NSBundle mainBundle] pathForResource:@"xx" ofType:@"h264"];
    
    openFile([fileName cStringUsingEncoding:NSUTF8StringEncoding], (__bridge void *)(self));
}

void openFile(const char *src_filename, void *context){
    /* open input file, and allocate format context */
    if (avformat_open_input(&fmt_ctx, src_filename, NULL, NULL) < 0) {
        fprintf(stderr, "Could not open source file %s\n", src_filename);
        exit(1);
    }
    
    /* retrieve stream information */
    if (avformat_find_stream_info(fmt_ctx, NULL) < 0) {
        fprintf(stderr, "Could not find stream information\n");
        exit(1);
    }

    
    int ret;
    enum AVMediaType type = AVMEDIA_TYPE_VIDEO;
    ret = av_find_best_stream(fmt_ctx, type, -1, -1, NULL, 0);
    if (ret < 0) {
        fprintf(stderr, "Could not find %s stream in input file %s \n",
                av_get_media_type_string(type), src_filename);
        exit(1);
    }
    video_stream_idx = ret;
    video_stream = fmt_ctx->streams[video_stream_idx];
    /* dump input information to stderr */
    av_dump_format(fmt_ctx, 0, src_filename, 0);
    
    if (!video_stream) {
        fprintf(stderr, "Could not find video stream in the input, aborting\n");
        exit(1);
    }
    
    pkt = av_packet_alloc();
    if (!pkt) {
        fprintf(stderr, "Could not allocate packet\n");
        exit(1);
    }
    
    /* read frames from the file */
    while (av_read_frame(fmt_ctx, pkt) >= 0) {
        // check if the packet belongs to a stream we are interested in, otherwise
        // skip it
        if (pkt->stream_index == video_stream_idx)
            decode_packet(pkt, context);
        av_packet_unref(pkt);
        if (ret < 0)
            break;
    }
    
}


static int find_start_code(const uint8_t *start, const uint8_t *end, uint32_t *startCodeLength) {
    
    
    int i = 0;
    bool found = false;
    while (start + i + 3 <= end) {
        if (start[i] == 0 && start[i+1] == 0 && start[i+2] == 1) {
            if (i > 0 && start[i-1] == 0) {
                *startCodeLength = 4;
                i--;
            } else {
                *startCodeLength = 3;
            }
            found = true;
            break;
        }
        i++;
    }
    if (found) {
        return i;
    } else {
        return -1;
    }
}


void freeH264NAL(H264NAL *nal) {
    
    if (!nal || !nal->data) return;
    
    free(nal->data);
    nal->data = nil;
}

void freeH264Packet(H264Packet *pkt) {
    if (!pkt->nb_nals) return;
    for (int i = 0; i< pkt->nb_nals; i++) {
        freeH264NAL(&pkt->nals[i]);
    }
    free(pkt->nals);
    pkt->nals = nil;
}


void decode_packet(AVPacket *pkt, void *context) {
    NSLog(@"read pkt size = %d", pkt->size);
    H264Packet h264Packet;
    h264Packet.nals = malloc(sizeof(H264NAL) * 4);
    h264Packet.capacity = 4;
    h264Packet.nb_nals = 0;
    split_packet(pkt, &h264Packet);
    
    HWPacketReader *self = (__bridge HWPacketReader *)(context);
    [self.delegate packetReader:self didReadPacket:&h264Packet];

    freeH264Packet(&h264Packet);
}





void split_packet(AVPacket *pkt, H264Packet *h264Packet) {
    /*
     1. 读取startcode，根据start code 将 pkt 中的 h264 数据切分，
        每一 nal 保存为 H264NAL
     2. 读取nal header， 拿到 type， 主要为了拿到 sps， pps
     */
    
    
    uint8_t *start = pkt->data;
    uint8_t *end = pkt->data + pkt->size - 1;
    
    /*
     start code 可能是 三个字节 00 00 01
            也可能是   四个字节 00 00 00 01
     */
    
    
    NSLog(@"=========== %s", __FUNCTION__);
    
    int offset = 0;
    while (end - start >= 3) {
        uint32_t currentCodeLength = 0;
        int currentStartIndex = find_start_code(start + offset, end, &currentCodeLength);
        uint8_t type = *(start + offset + currentCodeLength) & 0x1F;
        printf("type = %d\n ", type);
        if (currentStartIndex == -1)
        {
            NSLog(@"not found start code index");
            break;
        }
        
        
        if (h264Packet->capacity < h264Packet->nb_nals +1) {
            h264Packet->nals =  realloc(h264Packet->nals, sizeof(H264NAL) * h264Packet->nb_nals + 1);
            h264Packet->capacity = h264Packet->nb_nals + 1;
        }
        
        NSLog(@"start index = %d, code length = %d", currentStartIndex, currentCodeLength);
        uint8_t * nextStart = start + offset + currentCodeLength;
        uint32_t nextCodeLength = 0;
        int nextStartIndex = find_start_code(nextStart, end, &nextCodeLength);
        if (nextStartIndex == -1) {
            uint32_t nal_length = (uint32_t)(end - nextStart + 1);
            memset(h264Packet->nals + h264Packet->nb_nals, 0, sizeof(H264NAL));
            H264NAL *nal = &(h264Packet->nals[h264Packet->nb_nals]);
            nal->data = malloc(nal_length);
            memcpy(nal->data, nextStart, nal_length);
            nal->size = nal_length;
            nal->type = type;
            h264Packet->nb_nals++;
            
            NSLog(@"got nal, length = %d", nal_length);
            
            NSLog(@"reach end, not more nals");
            break;
        }
        
        int32_t nal_length = nextStartIndex;
        NSLog(@"got nal, length = %d", nal_length);
        
        memset(h264Packet->nals + h264Packet->nb_nals, 0, sizeof(H264NAL));
        H264NAL *nal = &(h264Packet->nals[h264Packet->nb_nals]);
        nal->data = malloc(nal_length);
        memcpy(nal->data, nextStart, nal_length);
        nal->size = nal_length;
        nal->type = type;
        h264Packet->nb_nals++;


        offset += currentCodeLength + nal_length;
    }
}

@end
