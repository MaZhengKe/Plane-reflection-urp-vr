Shader "KuanMi/Mirror"
{

    Properties {}
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" "RenderPeipeline" = "UniversalPepeline" "Queue"="Transparent"
        }
        LOD 100

        Pass
        {
            name "MirrorPass"
            blend one zero
            ZWrite off
            ZTest Lequal
            Cull off
            HLSLPROGRAM
            #pragma  vertex vert
            #pragma  fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"


            TEXTURE2D_X(_MirrorTex);
            SAMPLER(sampler_MirrorTex);


            struct Attributes
            {
                float4 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);

                return output;
            }


            half4 frag(Varyings input):SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 screenUV = input.positionHCS / _ScreenParams;
                //screenUV.y = 1 - screenUV.y;
                screenUV.x = 1 - screenUV.x;
                
                //screenUV.y += 0.002;
                #if defined USING_STEREO_MATRICES

                // if (unity_StereoEyeIndex == 1)
                // {
                //     screenUV.x -= 0.058;
                // }
                // else
                // {
                //     screenUV.x += 0.06;
                // }

                #else
                
                #endif
                
                return SAMPLE_TEXTURE2D_X(_MirrorTex, sampler_MirrorTex, screenUV) * 0.8;

                return 1;
            }
            ENDHLSL
        }
    }
}