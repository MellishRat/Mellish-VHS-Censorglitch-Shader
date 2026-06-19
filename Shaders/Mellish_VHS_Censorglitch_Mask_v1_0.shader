/*
    Mellish VHS Censorglitch Mask v1.0
    Created by Mellish

    Invisible stencil mask for containing the VHS Censorglitch bar effect.

    Support:
    https://www.patreon.com/Mellish_penthouse
*/

Shader "Mellish/VHS Censorglitch/Mask v1.0"
{
    Properties
    {
        [Header(Censor Mask)]
        [Space(6)]
        _StencilRef ("Stencil Reference ID", Float) = 47
    }

    SubShader
    {
        Tags
        {
            "Queue"="Overlay-30"
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
        }

        Pass
        {
            ZWrite Off
            ZTest Always
            Cull Off
            ColorMask 0

            Stencil
            {
                Ref [_StencilRef]
                Comp Always
                Pass Replace
            }
        }
    }

    FallBack Off
}
