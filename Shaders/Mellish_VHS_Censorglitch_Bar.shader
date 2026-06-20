/*
    Mellish VHS Censorglitch Bar v1.1
    Created by Mellish

    Perfectly horizontal screen-space static bar.
    Uses a stencil mask so the bar only appears inside the masked/cube area.

    Support:
    https://www.patreon.com/Mellish_penthouse
*/

Shader "Mellish/VHS Censorglitch/Mellish_VHS_Censorglitch_Bar"
{
    Properties
    {
        _StencilRef ("Stencil Reference ID", Float) = 47
        _UseStencilDebugNote ("Stencil Required - Use Debug Shader To Bypass", Float) = 1
        _Tint ("Static Tint", Color) = (0.88, 0.95, 1.0, 1.0)
        _Opacity ("Bar Opacity", Range(0,1)) = 0.95
        _CullMode ("Cull Mode 0 Off 1 Front 2 Back", Float) = 0

        _BarHeight ("Screen Bar Height", Range(0.002,0.25)) = 0.055
        _VerticalOffset ("Vertical Offset", Range(-0.5,0.5)) = 0
        _ScreenPadding ("Screen Edge Padding", Range(0,0.5)) = 0.02
        _EdgeFade ("Soft Top Bottom Edge", Range(0.001,0.25)) = 0.025

        _ScreenHorizontalTiling ("Screen Horizontal Tiling", Range(1,160)) = 48
        _LocalVerticalTiling ("Vertical Static Tiling", Range(1,80)) = 10
        _SidewaysSpeed ("Left Right Static Drift", Range(-30,30)) = 5
        _StaticSpeed ("Static Crawl Speed", Range(0,60)) = 24

        _Brightness ("Static Brightness", Range(0,3)) = 1.5
        _DarkCrush ("Dark Crush", Range(0,1)) = 0.32

        _ScanlineCount ("Scanline Count", Range(8,720)) = 570
        _ScanlineStrength ("Scanline Strength", Range(0,1)) = 0.72
        _RGBSplit ("Chromatic Aberration", Range(0,0.1)) = 0.022
        _HorizontalTear ("Horizontal Tear", Range(0,0.35)) = 0.075
        _JitterStrength ("Left Right Jitter", Range(0,0.25)) = 0.045
        _VHSWobble ("VHS Wobble", Range(0,0.15)) = 0.025

        _TrackingBreakAmount ("Tracking Break Amount", Range(0,1)) = 0.45
        _TrackingBreakSpeed ("Tracking Break Scan Speed", Range(-10,10)) = 1.8
        _TrackingBreakThickness ("Tracking Break Thickness", Range(0.001,0.08)) = 0.012
        _TrackingBreakFrequency ("Tracking Break Frequency", Range(2,80)) = 24

        _PixelMaskToggle ("Enable CRT Pixel Mask", Float) = 1
        _PixelMaskTex ("CRT Pixel Mask Texture", 2D) = "white" {}
        _PixelMaskStrength ("CRT Pixel Mask Strength", Range(0,1)) = 0.55
        _PixelMaskTiling ("CRT Pixel Mask Tiling XY", Vector) = (640, 570, 0, 0)

        _BackgroundBlend ("Background Blend", Range(0,1)) = 0.08
        _BackgroundDistort ("Background Distortion", Range(0,0.1)) = 0.018
    }

    SubShader
    {
        Tags
        {
            "Queue"="Overlay-20"
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
        }

        GrabPass { "_MellishHorizontalScreenCensorGrab" }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest Always
            Cull [_CullMode]

            Stencil
            {
                Ref [_StencilRef]
                Comp Equal
                Pass Keep
            }

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MellishHorizontalScreenCensorGrab;
            sampler2D _PixelMaskTex;

            float4 _Tint;
            float _Opacity;
            float _BarHeight;
            float _VerticalOffset;
            float _ScreenPadding;
            float _EdgeFade;

            float _ScreenHorizontalTiling;
            float _LocalVerticalTiling;
            float _SidewaysSpeed;
            float _StaticSpeed;

            float _Brightness;
            float _DarkCrush;

            float _ScanlineCount;
            float _ScanlineStrength;
            float _RGBSplit;
            float _HorizontalTear;
            float _JitterStrength;
            float _VHSWobble;

            float _TrackingBreakAmount;
            float _TrackingBreakSpeed;
            float _TrackingBreakThickness;
            float _TrackingBreakFrequency;

            float _PixelMaskToggle;
            float _PixelMaskStrength;
            float4 _PixelMaskTiling;

            float _BackgroundBlend;
            float _BackgroundDistort;

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
                float2 uv : TEXCOORD2;
                float2 barUV : TEXCOORD3;
            };

            float hash21(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }

            float signedHash(float2 p)
            {
                return hash21(p) * 2.0 - 1.0;
            }

            float staticNoise(float2 p)
            {
                float a = hash21(floor(p + 0.123));
                float b = hash21(floor(p * 0.47 + 19.7));
                float c = hash21(floor(p * 2.3 - 8.1));
                return saturate(a * 0.52 + b * 0.36 + c * 0.38);
            }

            float trackingBreaks(float2 screenUV, float localY, float t)
            {
                float movingY = localY + t * _TrackingBreakSpeed * 0.08;
                float linePattern = frac(movingY * _TrackingBreakFrequency);
                float distToLine = abs(linePattern - 0.5);

                float thinLine = 1.0 - smoothstep(
                    _TrackingBreakThickness,
                    _TrackingBreakThickness + 0.025,
                    distToLine
                );

                float lineIndex = floor(movingY * _TrackingBreakFrequency);
                float randomGate = step(0.38, hash21(float2(lineIndex, floor(t * 4.0))));
                float segment = step(0.2, hash21(float2(floor(screenUV.x * 42.0), lineIndex + floor(t * 6.0))));

                return thinLine * randomGate * segment * _TrackingBreakAmount;
            }

            v2f vert(appdata v)
            {
                v2f o;

                // Project the object's origin. This is the anchor.
                float4 centreClip = UnityObjectToClipPos(float4(0, 0, 0, 1));

                // Convert mesh UV into full-screen strip coordinates.
                // uv.x 0..1 goes left to right across screen.
                // uv.y 0..1 controls strip height around the anchor.
                float pad = _ScreenPadding;
                float xNDC = lerp(-1.0 - pad, 1.0 + pad, saturate(v.uv.x));

                float centreNDCY = centreClip.y / centreClip.w;
                float yNDC = centreNDCY + _VerticalOffset + ((v.uv.y - 0.5) * _BarHeight * 2.0);

                // Rebuild clip position with original depth/w.
                float4 clip;
                clip.w = centreClip.w;
                clip.z = centreClip.z;
                clip.x = xNDC * clip.w;
                clip.y = yNDC * clip.w;

                o.pos = clip;
                o.grabPos = ComputeGrabScreenPos(o.pos);
                o.screenPos = ComputeScreenPos(o.pos);
                o.uv = v.uv;
                o.barUV = v.uv;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float t = fmod(_Time.y, 60.0);

                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float2 grabUV = i.grabPos.xy / i.grabPos.w;
                float2 barUV = i.barUV;

                float bottomFade = smoothstep(0.0, _EdgeFade, barUV.y);
                float topFade = smoothstep(0.0, _EdgeFade, 1.0 - barUV.y);
                float edgeFade = bottomFade * topFade;

                float wobble =
                    sin((screenUV.y * 42.0) + (t * 7.0)) *
                    sin((screenUV.y * 7.0) - (t * 2.0)) *
                    _VHSWobble;

                screenUV.x += wobble;
                grabUV.x += wobble;

                float2 sliceUV;
                sliceUV.x = screenUV.x * _ScreenHorizontalTiling + t * _SidewaysSpeed;
                sliceUV.y = barUV.y * _LocalVerticalTiling;

                float row = floor(barUV.y * _ScanlineCount);
                float rowJitter = signedHash(float2(row, floor(t * _StaticSpeed * 0.45)));
                float fastJitter = signedHash(float2(floor(t * _StaticSpeed), row * 3.17));

                sliceUV.x += rowJitter * _HorizontalTear * _ScreenHorizontalTiling;
                sliceUV.x += fastJitter * _JitterStrength * _ScreenHorizontalTiling;
                sliceUV.x += floor(t * _StaticSpeed);

                float noise = staticNoise(sliceUV * 12.0);

                float scan = frac(barUV.y * _ScanlineCount + t * 0.8);
                float scanline = step(0.48, scan);
                noise = lerp(noise, noise * scanline, _ScanlineStrength);

                float breaks = trackingBreaks(screenUV, barUV.y, t);

                float crushed = saturate((noise - _DarkCrush) * _Brightness);

                float rgb = _RGBSplit * (0.35 + crushed + abs(rowJitter));
                float2 distortedGrab = grabUV;
                distortedGrab.x += rowJitter * _BackgroundDistort;
                distortedGrab.x += fastJitter * _BackgroundDistort * 0.5;

                fixed3 grabbed;
                grabbed.r = tex2D(_MellishHorizontalScreenCensorGrab, distortedGrab + float2(rgb, 0)).r;
                grabbed.g = tex2D(_MellishHorizontalScreenCensorGrab, distortedGrab).g;
                grabbed.b = tex2D(_MellishHorizontalScreenCensorGrab, distortedGrab - float2(rgb, 0)).b;

                float noiseR = staticNoise((sliceUV + float2(3.1, 0.0)) * 12.0);
                float noiseG = staticNoise((sliceUV + float2(0.0, 6.2)) * 12.0);
                float noiseB = staticNoise((sliceUV + float2(-4.7, 1.9)) * 12.0);

                fixed3 staticRGB = fixed3(noiseR, noiseG, noiseB);
                staticRGB = saturate((staticRGB - _DarkCrush) * _Brightness);

                fixed3 col = lerp(staticRGB * _Tint.rgb * 1.45, grabbed, _BackgroundBlend);
                col += crushed * 0.22;
                col += breaks * 0.15;

                if (_PixelMaskToggle > 0.5)
                {
                    float2 maskUV = screenUV * _PixelMaskTiling.xy + _PixelMaskTiling.zw;
                    float3 mask = tex2D(_PixelMaskTex, maskUV).rgb;
                    col *= lerp(float3(1,1,1), mask, _PixelMaskStrength);
                }

                float alpha = _Opacity * edgeFade;
                alpha *= lerp(0.72, 1.0, crushed);
                alpha *= (1.0 - breaks);

                return fixed4(saturate(col), saturate(alpha));
            }
            ENDCG
        }
    }

    FallBack Off
}
