
# 使用 VideoToolBox 进行 h264 编解码

参考： [H264 Encode And Decode Using VideoToolBox](https://mobisoftinfotech.com/resources/mguide/h264-encode-decode-using-videotoolbox/)


# 什么是 AVCC， Annex-B

1. Annex B
Annex B is widely used in Live streaming because of its simple format. In this format, it’s common to repeat SPS and PPS periodically preceding every IDR. Thus, it creates random access points for decoder. It gives the ability to join stream which is already in progress.

2. AVCC
AVCC is the common method to store H264 stream. In this format, each NALU is preceded with its length (**In big endian**).

Introductory image for SPS,PPS, IDR and Non IDR frames.

# 编码

AVCC -> Annex-B

1. 输入 CVPixelBuffer , 获得 CMSampleBuffer
2. 判断是否是 I 帧， 如果是 I 帧， 读取 sps， pps， 写入sps， pps， I 帧
3. 不是 I 帧，写入 P 帧
4. 每个 NALU 之前需要添加 start code

# 解码

1. 构建 VTDecompressionSessionRef 需要先获取 sps， pps
2. 给编码器送入 NALU， 用 CMSampleBuffer 来表示
3. 需要将 NALU 之前需要添加的 start code 替换为该 NALU 的长度，长度需要用**大端**来表示


