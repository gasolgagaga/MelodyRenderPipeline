﻿Shader "Hidden/Melody RP/StochasticSSR"
{
    SubShader
    {
        Cull Off
        ZTest Always
        Zwrite Off

        HLSLINCLUDE
        #include "../ShaderLibrary/Common.hlsl"
        #include "../ShaderLibrary/Surface.hlsl"
        #include "../ShaderLibrary/Shadows.hlsl"
        #include "../ShaderLibrary/Light.hlsl"
        #include "../ShaderLibrary/BRDF.hlsl"
        #include "StochasticSSRPass.hlsl"
        ENDHLSL

        Pass 
        {
            Name "Linear Trace 1 SPP"

            //note: DO NOT use HLSLINCLUDE
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DefaultPassVertex
            #pragma fragment LinearTraceSingleSPP
            ENDHLSL
        }

        Pass 
        {
            Name "Linear Trace Multi SPP"

            //note: DO NOT use HLSLINCLUDE
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DefaultPassVertex
            #pragma fragment LinearTraceMultiSPP
            ENDHLSL
        }

        Pass 
        {
            Name "Spatio Filter 1 SPP"

            //note: DO NOT use HLSLINCLUDE
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DefaultPassVertex
            #pragma fragment SpatioFilterSingleSPP
            ENDHLSL
        }

        Pass 
        {
            Name "Spatio Filter Multi SPP"

            //note: DO NOT use HLSLINCLUDE
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DefaultPassVertex
            #pragma fragment SpatioFilterMultiSPP
            ENDHLSL
        }

        Pass
        {
            Name "Temporal Filter 1 SPP"

            //note: DO NOT use HLSLINCLUDE
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DefaultPassVertex
            #pragma fragment TemporalFilterSingelSSP
            ENDHLSL
        }

        Pass
        {
            Name "Temporal Filter Multi SPP"

            //note: DO NOT use HLSLINCLUDE
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DefaultPassVertex
            #pragma fragment TemporalFilterSingelSSP
            ENDHLSL
        }
    }
}
