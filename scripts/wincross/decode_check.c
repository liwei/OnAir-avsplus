// Decodes the video of an MPEG-TS file with the libavcodec it is linked against and reports the cavs decoder's
// profile list, the stream's codec, and how many frames came out. Used to check the static FFmpeg of a package.
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <stdio.h>

int main(int argc, char** argv) {
    if (argc < 2) { fprintf(stderr, "usage: decode_check <file.ts>\n"); return 2; }
    const AVCodec* cavs = avcodec_find_decoder(AV_CODEC_ID_CAVS);
    printf("cavs decoder: %s; profiles:", cavs ? cavs->long_name : "none");
    for (const AVProfile* p = cavs ? cavs->profiles : NULL; p && p->profile != AV_PROFILE_UNKNOWN; p++) printf(" 0x%02x=%s", p->profile, p->name);
    printf("%s\n", cavs && cavs->profiles ? "" : " (none)");

    AVFormatContext* fmt = NULL;
    if (avformat_open_input(&fmt, argv[1], NULL, NULL) < 0 || avformat_find_stream_info(fmt, NULL) < 0) { fprintf(stderr, "cannot open %s\n", argv[1]); return 1; }
    int vi = av_find_best_stream(fmt, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (vi < 0) { fprintf(stderr, "no video stream\n"); return 1; }
    AVCodecParameters* par = fmt->streams[vi]->codecpar;
    const AVCodec* dec = avcodec_find_decoder(par->codec_id);
    printf("video: %s %dx%d, decoder %s\n", avcodec_get_name(par->codec_id), par->width, par->height, dec ? dec->name : "none");
    if (!dec) return 1;
    AVCodecContext* ctx = avcodec_alloc_context3(dec);
    avcodec_parameters_to_context(ctx, par);
    if (avcodec_open2(ctx, dec, NULL) < 0) { fprintf(stderr, "cannot open decoder\n"); return 1; }
    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();
    long frames = 0, errors = 0;
    while (av_read_frame(fmt, pkt) >= 0) {
        if (pkt->stream_index == vi) {
            if (avcodec_send_packet(ctx, pkt) < 0) errors++;
            else while (avcodec_receive_frame(ctx, frame) >= 0) { frames++; av_frame_unref(frame); }
        }
        av_packet_unref(pkt);
    }
    avcodec_send_packet(ctx, NULL);
    while (avcodec_receive_frame(ctx, frame) >= 0) { frames++; av_frame_unref(frame); }
    printf("frames decoded: %ld, packets rejected: %ld\n", frames, errors);
    return frames > 0 ? 0 : 1;
}
