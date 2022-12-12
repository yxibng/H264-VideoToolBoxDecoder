//
//  HWPacketReader.h
//  HWDecorder
//
//  Created by xiaobing yao on 2022/12/15.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

enum {
    H264_NAL_UNSPECIFIED     = 0,
    H264_NAL_SLICE           = 1,
    H264_NAL_DPA             = 2,
    H264_NAL_DPB             = 3,
    H264_NAL_DPC             = 4,
    H264_NAL_IDR_SLICE       = 5,
    H264_NAL_SEI             = 6,
    H264_NAL_SPS             = 7,
    H264_NAL_PPS             = 8,
    H264_NAL_AUD             = 9,
    H264_NAL_END_SEQUENCE    = 10,
    H264_NAL_END_STREAM      = 11,
    H264_NAL_FILLER_DATA     = 12,
    H264_NAL_SPS_EXT         = 13,
    H264_NAL_PREFIX          = 14,
    H264_NAL_SUB_SPS         = 15,
    H264_NAL_DPS             = 16,
    H264_NAL_RESERVED17      = 17,
    H264_NAL_RESERVED18      = 18,
    H264_NAL_AUXILIARY_SLICE = 19,
    H264_NAL_EXTEN_SLICE     = 20,
    H264_NAL_DEPTH_EXTEN_SLICE = 21,
    H264_NAL_RESERVED22      = 22,
    H264_NAL_RESERVED23      = 23,
    H264_NAL_UNSPECIFIED24   = 24,
    H264_NAL_UNSPECIFIED25   = 25,
    H264_NAL_UNSPECIFIED26   = 26,
    H264_NAL_UNSPECIFIED27   = 27,
    H264_NAL_UNSPECIFIED28   = 28,
    H264_NAL_UNSPECIFIED29   = 29,
    H264_NAL_UNSPECIFIED30   = 30,
    H264_NAL_UNSPECIFIED31   = 31,
};



typedef struct {
    uint8_t *data; //without start code, include escaped code
    int size; //data length in byte
    /*
     NAL unit type
     */
    int type;
} H264NAL;


typedef struct {
    H264NAL *nals;
    int nb_nals;
    int capacity;
} H264Packet;

@class HWPacketReader;
@protocol HWPacketReaderDelegate <NSObject>




- (void)packetReader:(HWPacketReader *)packetReader  didReadPacket:(H264Packet *)packet;

@end


@interface HWPacketReader : NSObject

@property (nonatomic, weak) id<HWPacketReaderDelegate>delegate;

- (void)startRunning;

@end

NS_ASSUME_NONNULL_END
