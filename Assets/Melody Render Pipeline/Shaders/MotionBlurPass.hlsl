﻿#ifndef MELODY_MOTION_BLUR_PASS_INCLUDED
#define MELODY_MOTION_BLUR_PASS_INCLUDED

TEXTURE2D(_MotionBlurSource);
float4 _MotionBlurSource_TexelSize;
TEXTURE2D(_NeighborMaxTex);
float4 _NeighborMaxTex_TexelSize;
TEXTURE2D(_VelocityTex);
float4 _VelocityTex_TexelSize;

float _VelocityScale;
//tileMax filter parameters
int _TileMaxLoop;
float2 _TileMaxOffs;
//max blur radius(in pixels)
float _MaxBlurRadius;
float _RcpMaxBlurRadius;
//filter parameters/coefficients
half _LoopCount;

//history buffer for frame blending
TEXTURE2D(_History1LumaTex);
TEXTURE2D(_History2LumaTex);
TEXTURE2D(_History3LumaTex);
TEXTURE2D(_History4LumaTex);
TEXTURE2D(_History1ChromaTex);
TEXTURE2D(_History2ChromaTex);
TEXTURE2D(_History3ChromaTex);
TEXTURE2D(_History4ChromaTex);

float _History1Weight;
float _History2Weight;
float _History3Weight;
float _History4Weight;

struct Imag {
    float4 positionCS : SV_POSITION;
    float2 screenUV : VAR_SCREEN_UV;
};

struct Multitex {
    float4 positionCS : SV_POSITION;
    float2 screenUV0 : VAR_SCREEN_UV0;
    float2 screenUV1 : VAR_SCREEN_UV1;
};

//vertexID is the clockwise index of a triangle : 0,1,2
Imag DefaultPassVertex(uint vertexID : SV_VertexID) {
    Imag output;
    //make the [-1, 1] NDC, visible UV coordinates cover the 0-1 range
    output.positionCS = float4(vertexID <= 1 ? -1.0 : 3.0,
        vertexID == 1 ? 3.0 : -1.0,
        0.0, 1.0);
    output.screenUV = float2(vertexID <= 1 ? 0.0 : 2.0,
        vertexID == 1 ? 2.0 : 0.0);
    //some graphics APIs have the texture V coordinate start at the top while others have it start at the bottom
    if (_ProjectionParams.x < 0.0) {
        output.screenUV.y = 1.0 - output.screenUV.y;
    }
    return output;
}

Multitex MultiTexPassVertex(uint vertexID : SV_VertexID) {
    Multitex output;
    output.positionCS = float4(vertexID <= 1 ? -1.0 : 3.0,
        vertexID == 1 ? 3.0 : -1.0,
        0.0, 1.0);
    output.screenUV0 = float2(vertexID <= 1 ? 0.0 : 2.0,
        vertexID == 1 ? 2.0 : 0.0);
    if (_ProjectionParams.x < 0.0) {
        output.screenUV0.y = 1.0 - output.screenUV0.y;
    }
    output.screenUV1 = output.screenUV0;
    return output;
}

//linearize depth value sampled from the camera depth texture.
float LinearizeDepth(float z) {
    float isOrtho = unity_OrthoParams.w;
    float isPers = 1 - unity_OrthoParams.w;
    z *= _ZBufferParams.x;
    return (1 - isOrtho * z) / (isPers * z + _ZBufferParams.y);
}

//returns the largest vector of v1 and v2.
float2 VMax(float2 v1, float2 v2) {
    return dot(v1, v1) < dot(v2, v2) ? v2 : v1;
}

//fragment shader: Velocity texture setup
float4 VelocitySetup(Imag input) : SV_Target{
    //sample the motion vector.
    float2 v = SAMPLE_TEXTURE2D(_CameraMotionVectorTexture, sampler_point_clamp, input.screenUV).rg;
    //apply the exposure time and convert to the pixel space.
    v *= (_VelocityScale * 0.5) * _CameraMotionVectorTexture_TexelSize.zw;
    //clamp the vector with the maximum blur radius.
    v /= max(1, length(v) * _RcpMaxBlurRadius);
    //sample the depth of the pixel.
    float d = LinearizeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_point_clamp, input.screenUV));
    //pack into 10/10/10/2 format.
    return float4((v * _RcpMaxBlurRadius + 1) / 2, d, 0);
}

//fragment shader: TileMax filter (2 pixel width with normalization)
float4 TileMax1(Imag input) : SV_Target {
    float4 d = _MotionBlurSource_TexelSize.xyxy * float4(-0.5, -0.5, 0.5, 0.5);
    float2 v1 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.xy).rg;
    float2 v2 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.zy).rg;
    float2 v3 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.xw).rg;
    float2 v4 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.zw).rg;
    v1 = (v1 * 2 - 1) * _MaxBlurRadius;
    v2 = (v2 * 2 - 1) * _MaxBlurRadius;
    v3 = (v3 * 2 - 1) * _MaxBlurRadius;
    v4 = (v4 * 2 - 1) * _MaxBlurRadius;
    return float4(VMax(VMax(VMax(v1, v2), v3), v4), 0, 0);
}

//fragment shader: TileMax filter (2 pixel width)
float4 TileMax2(Imag input) : SV_Target{
    float4 d = _MotionBlurSource_TexelSize.xyxy * float4(-0.5, -0.5, 0.5, 0.5);
    float2 v1 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.xy).rg;
    float2 v2 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.zy).rg;
    float2 v3 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.xw).rg;
    float2 v4 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.zw).rg;
    return float4(VMax(VMax(VMax(v1, v2), v3), v4), 0, 0);
}

//fragment shader: TileMax filter (variable width)
float4 TileMaxV(Imag input) : SV_Target{
    float2 uv0 = input.screenUV + _MotionBlurSource_TexelSize.xy * _TileMaxOffs.xy;
    float2 du = float2(_MotionBlurSource_TexelSize.x, 0);
    float2 dv = float2(0, _MotionBlurSource_TexelSize.y);
    float2 vo = 0;
    [loop]
    for (int ix = 0; ix < _TileMaxLoop; ix++) {
        [loop]
        for (int iy = 0; iy < _TileMaxLoop; iy++) {
            float2 uv = uv0 + du * ix + dv * iy;
            vo = VMax(vo, SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, uv).rg);
        }
    }
    return float4(vo, 0, 0);
}

//fragment shader: NeighborMax filter
float4 NeighborMax(Imag input) : SV_Target{
    //center weight tweak
    const float cw = 1.01f;
    float4 d = _MotionBlurSource_TexelSize.xyxy * float4(1, 1, -1, 0);
    float2 v1 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV - d.xy).rg;
    float2 v2 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV - d.wy).rg;
    float2 v3 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV - d.zy).rg;
    float2 v4 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV - d.xw).rg;
    float2 v5 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV).rg * cw;
    float2 v6 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.xw).rg;
    float2 v7 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.zy).rg;
    float2 v8 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.wy).rg;
    float2 v9 = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_point_clamp, input.screenUV + d.xy).rg;
    float2 va = VMax(v1, VMax(v2, v3));
    float2 vb = VMax(v4, VMax(v5, v6));
    float2 vc = VMax(v7, VMax(v8, v9));
    return float4(VMax(va, VMax(vb, vc)) / cw, 0, 0);
}

//returns true or false with a given interval.
bool Interval(half phase, half interval) {
    return frac(phase / interval) > 0.499;
}

//interleaved gradient function from Jimenez 2014 http://goo.gl/eomGso
float GradientNoise(float2 uv) {
    uv = floor((uv + _Time.y) * _ScreenParams.xy);
    float f = dot(float2(0.06711056f, 0.00583715f), uv);
    return frac(52.9829189f * frac(f));
}

//jitter function for tile lookup
float2 JitterTile(float2 uv) {
    float rx, ry;
    //output sin and cosine
    sincos(GradientNoise(uv + float2(2, 0)) * PI * 2, ry, rx);
    return float2(rx, ry) * _NeighborMaxTex_TexelSize.xy / 4;
}

float3 SampleVelocity(float2 uv) {
    float3 v = SAMPLE_TEXTURE2D_LOD(_VelocityTex, sampler_point_clamp, uv, 0).xyz;
    return  float3((v.xy * 2 - 1) * _MaxBlurRadius, v.z);
}

//fragment shader: Reconstruction
float4 Reconstruction(Multitex input) : SV_Target {
    //color sample at center point
    float4 c_p = SAMPLE_TEXTURE2D(_MotionBlurSource, sampler_linear_clamp, input.screenUV0);
    //velocity/depth sample at center point
    float3 vd_p = SampleVelocity(input.screenUV1);
    float l_v_p = max(length(vd_p.xy), 0.5);
    float rcp_d_p = 1 / vd_p.z;
    //neightborMax vector sample at center point
    float2 v_max = SAMPLE_TEXTURE2D(_NeighborMaxTex, sampler_point_clamp, input.screenUV1 + JitterTile(input.screenUV1));
    float l_v_max = length(v_max);
    float rcp_l_v_max = 1 / l_v_max;
    //earlt exit if neightborMax is too small
    float4 a = SAMPLE_TEXTURE2D(_CameraMotionVectorTexture, sampler_point_clamp, input.screenUV0) * 30;
    return a;
    if (l_v_max < 2) {
        return c_p;
    }
    //use v as a secondary sampling direction except when it's too small compared to V_max. This vector is rescaled to be the length of V_max.
    float2 v_alt = (l_v_p * 2 > l_v_max) ? vd_p.xy * (l_v_max / l_v_p) : v_max;
    //determine the sample count
    float sc = floor(min(_LoopCount, l_v_max / 2));
    //loop variables (starts from the outermost sample)
    float dt = 1 / sc;
    float t_offs = (GradientNoise(input.screenUV0) - 0.5) * dt;
    float t = 1 - dt / 2;
    float count = 0;
    //background velocity
    //this is used for tracking the maximum velocity in the background layer.
    float l_v_bg = max(l_v_p, 1);
    //color accumlation
    float4 acc = 0;
    while(t > dt / 4) {
        //sampling direction(switch per 2 samples)
        float2 v_s = Interval(count, 4) ? v_alt : v_max;
        //sampling position(inverted per every sample)
        float t_s = (Interval(count, 2) ? -t : t) + t_offs;
        //distance to sample position
        float l_t = l_v_max + abs(t_s);
        //uv for sample position
        float2 uv0 = input.screenUV0 + v_s * t_s * _MotionBlurSource_TexelSize.xy;
        float2 uv1 = input.screenUV1 + v_s * t_s * _VelocityTex_TexelSize.xy;
        //color sample
        float3 c = SAMPLE_TEXTURE2D_LOD(_MotionBlurSource, sampler_linear_clamp, uv0, 0);
        //velocity/depth sample
        float3 vd = SampleVelocity(uv1);
        //background/Foreground separation
        float fg = saturate((vd_p.z - vd.z) * 20 * rcp_d_p);
        //length of the velocity vector
        float l_v = lerp(l_v_bg, length(vd.xy), fg);
        //sample weight
        //(Distance test) * (Spreading out by motion) * (Triangular window)
        float w = saturate(l_v - l_t) / l_v * (1.2 - t);
        //color accumlate
        acc += float4(c, 1) * w;
        //update the background velocity.
        l_v_bg = max(l_v_bg, l_v);
        //advance to the next sample.
        t = Interval(count, 2) ? t - dt : t;
        count += 1;
    }
    //add the center sample.
    acc += float4(c_p.rgb, 1) * (1.2 / (l_v_bg * sc * 2));
    return float4(acc.rgb / acc.a, c_p.a);
}

#endif