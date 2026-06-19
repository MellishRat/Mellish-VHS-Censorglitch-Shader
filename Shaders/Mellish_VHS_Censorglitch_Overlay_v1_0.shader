/*
    Mellish VHS Censorglitch Overlay v1.1
    Created by Mellish

    CRT/VHS overlay with optional distance fade.
    The effect grows stronger as the camera/player gets closer to the overlay object.

    Support:
    https://www.patreon.com/Mellish_penthouse
*/

Shader "Mellish/VHS Censorglitch/Overlay v1.0"
{
    Properties
    {
        [Header(Main)]
        [Space(6)]
        _Opacity ("Overlay Opacity", Range(0,1)) = 0.28
        _Tint ("Screen Tint", Color) = (0.95, 0.98, 1.0, 1.0)
        [Enum(Off,0,Front,1,Back,2)] _CullMode ("Cull Mode", Float) = 1

        [Header(Distance Fade)]
        [Space(6)]
        _DistanceFadeEnabled ("Enable Distance Fade 0 Off 1 On", Float) = 1
        _FadeNearDistance ("Fade Near Distance Full Effect", Range(0,20)) = 1
        _FadeFarDistance ("Fade Far Distance No Effect", Range(0,30)) = 5
        _FadeCurve ("Fade Curve", Range(0.1,8)) = 2
        _InvertDistanceFade ("Invert Distance Fade", Float) = 0

        [Header(CRT Pixel Mask)]
        [Space(6)]
        [Toggle] _PixelMaskToggle ("Enable CRT Pixel Mask", Float) = 1
        _PixelMaskTex ("CRT Pixel Mask Texture", 2D) = "white" {}
        _PixelMaskStrength ("CRT Pixel Mask Strength", Range(0,1)) = 0.35
        _PixelMaskTiling ("CRT Pixel Mask Tiling XY", Vector) = (640, 570, 0, 0)

        [Header(Screen Resolution)]
        [Space(6)]
        [Toggle] _PixelateScreen ("Pixelate Screen", Float) = 1
        _PixelResolution ("Pixel Resolution XY", Vector) = (640, 570, 0, 0)

        [Header(VHS Feel)]
        [Space(6)]
        _ScanlineStrength ("Scanline Strength", Range(0,1)) = 0.18
        _ScanlineCount ("Scanline Count", Range(8,720)) = 570
        _RGBSplit ("RGB Split", Range(0,0.02)) = 0.0015
        _WobbleStrength ("VHS Wobble", Range(0,0.02)) = 0.0025
        _NoiseAmount ("Fine Noise", Range(0,0.1)) = 0.012
        _VignetteStrength ("Vignette", Range(0,1)) = 0.08

        [Header(Final Colour)]
        [Space(6)]
        _Saturation ("Saturation", Range(0,2)) = 1.05
        _Contrast ("Contrast", Range(0.75,1.5)) = 1.0
        _Brightness ("Brightness", Range(0.5,1.5)) = 1.0
    }

    SubShader
    {
        Tags
        {
            "Queue"="Overlay-20"
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
        }

        GrabPass { "_MellishCRTVHSOverlayLiteGrab" }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest Always
            Cull [_CullMode]

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MellishCRTVHSOverlayLiteGrab;
            sampler2D _PixelMaskTex;

            float _Opacity;
            float4 _Tint;

            float _PixelMaskToggle;
            float _PixelMaskStrength;
            float4 _PixelMaskTiling;

            float _PixelateScreen;
            float4 _PixelResolution;

            float _ScanlineStrength;
            float _ScanlineCount;
            float _RGBSplit;
            float _WobbleStrength;
            float _NoiseAmount;
            float _VignetteStrength;

            float _Saturation;
            float _Contrast;
            float _Brightness;

            float _DistanceFadeEnabled;
            float _FadeNearDistance;
            float _FadeFarDistance;
            float _FadeCurve;
            float _InvertDistanceFade;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float4 grabPos : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float distanceFade : TEXCOORD2;
            };

            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float luma(float3 c)
            {
                return dot(c, float3(0.2126, 0.7152, 0.0722));
            }

            float3 applySaturation(float3 color, float sat)
            {
                float l = luma(color);
                return lerp(float3(l, l, l), color, sat);
            }

            float2 snapUV(float2 uv, float2 res)
            {
                res = max(res, float2(1.0, 1.0));
                return floor(uv * res) / res;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.grabPos = ComputeGrabScreenPos(o.pos);
                o.screenPos = ComputeScreenPos(o.pos);

                float3 objectWorld = mul(unity_ObjectToWorld, float4(0, 0, 0, 1)).xyz;
                float cameraDistance = distance(_WorldSpaceCameraPos.xyz, objectWorld);

                float fadeRange = max(0.001, _FadeFarDistance - _FadeNearDistance);
                float fade = 1.0 - saturate((cameraDistance - _FadeNearDistance) / fadeRange);
                fade = pow(fade, max(_FadeCurve, 0.001));

                if (_InvertDistanceFade > 0.5)
                {
                    fade = 1.0 - fade;
                }

                if (_DistanceFadeEnabled < 0.5)
                {
                    fade = 1.0;
                }

                o.distanceFade = saturate(fade);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float t = fmod(_Time.y, 60.0);
                float distanceFade = saturate(i.distanceFade);

                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float2 grabUV = i.grabPos.xy / i.grabPos.w;

                // Very subtle VHS horizontal wobble.
                float wobble =
                    sin(screenUV.y * 38.0 + t * 8.0) *
                    sin(screenUV.y * 7.0 - t * 1.5) *
                    (_WobbleStrength * distanceFade);

                grabUV.x += wobble;

                float2 res = max(_PixelResolution.xy, float2(1.0, 1.0));
                float2 sampleUV = (_PixelateScreen > 0.5) ? snapUV(grabUV, res) : grabUV;

                // Mild RGB offset.
                float rgb = _RGBSplit * distanceFade;
                float3 col;
                col.r = tex2D(_MellishCRTVHSOverlayLiteGrab, sampleUV + float2(rgb, 0)).r;
                col.g = tex2D(_MellishCRTVHSOverlayLiteGrab, sampleUV).g;
                col.b = tex2D(_MellishCRTVHSOverlayLiteGrab, sampleUV - float2(rgb, 0)).b;

                // Scanlines.
                float scan = frac(screenUV.y * _ScanlineCount);
                float scanline = lerp(1.0, lerp(0.82, 1.0, step(0.5, scan)), _ScanlineStrength * distanceFade);
                col *= scanline;

                // Tiny grain only, no harsh white static.
                float grain = hash21(floor(screenUV * res) + floor(t * 24.0)) - 0.5;
                col += grain * (_NoiseAmount * distanceFade);

                // CRT mask.
                if (_PixelMaskToggle > 0.5)
                {
                    float2 maskUV = screenUV * _PixelMaskTiling.xy + _PixelMaskTiling.zw;
                    float3 mask = tex2D(_PixelMaskTex, maskUV).rgb;
                    col *= lerp(float3(1,1,1), mask, _PixelMaskStrength * distanceFade);
                }

                // Light final grade.
                col = ((col - 0.5) * _Contrast) + 0.5;
                col = applySaturation(col, _Saturation);
                col *= _Tint.rgb * _Brightness;

                float2 centred = screenUV * 2.0 - 1.0;
                float vignette = saturate(1.0 - dot(centred, centred) * (_VignetteStrength * distanceFade));
                col *= vignette;

                return fixed4(saturate(col), _Opacity * distanceFade);
            }
            ENDCG
        }
    }

    FallBack Off
}
