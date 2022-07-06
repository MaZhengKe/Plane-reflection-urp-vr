Shader "KM/Cloud"
{
    Properties
    {

        SEA_BASE("基础颜色", Color) = (0.0,0.09,0.18,1)
        SEA_WATER_COLOR("水颜色", Color) = (0.48,0.54,0.36,1)

        StepVector("采样数组 X:步数 Y：几何 Z:片元",vector) = (8,3,5,0)
        SEAData01("X:基础高度 Y：浪高 Z:陡峭程度 W：速度",vector) = (0,0.6,4.0,0.8)
        SEAData02("X:海浪频率 Y：反射 Z:折射 W：折射最大深度",vector) = (0.236,1,0.26,1.85)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" "RenderPeipeline" = "UniversalPepeline" "Queue"="Transparent"
        }
        LOD 100

        Pass
        {
            name "ShaderToy"
            blend one zero
            ZWrite off
            ZTest Lequal
            Cull off
            HLSLPROGRAM
            #pragma  vertex vert
            #pragma  fragment frag

            #define iGlobalTime   _Time.y
            #define iTime   _Time.y

            #define EPSILON_NRM (0.1 / _ScreenParams.x)
            #define SEA_TIME (1.0 + iTime * SEA_SPEED)

            #define NUM_STEPS           StepVector.x
            #define ITER_GEOMETRY       StepVector.y
            #define ITER_FRAGMENT       StepVector.z

            #define SEA_BaseHeight      SEAData01.x
            #define SEA_HEIGHT          SEAData01.y
            #define SEA_CHOPPY          SEAData01.z
            #define SEA_SPEED           SEAData01.w

            #define SEA_FREQ            SEAData02.x
            #define reflectedIndex      SEAData02.y
            #define refractedIndex      SEAData02.z
            #define refractedMaxDepth   SEAData02.w

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            TEXTURE2D_X(_MirrorTex);
            SAMPLER(sampler_MirrorTex);

            CBUFFER_START(UnityPerMaterial)
            float4 StepVector;
            float4 SEAData01;
            float4 SEAData02;
            float3 SEA_BASE;
            float3 SEA_WATER_COLOR;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewPos : TEXCOORD1;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                output.positionHCS = float4(input.positionOS.xy*1000, 0.5, 0.5*1000);
                output.viewPos = mul(UNITY_MATRIX_I_P, output.positionHCS).xyz;
                output.uv = input.uv;
                return output;
            }

            float3 getPixel(in float2 screen_pos)
            {
                
                float2 screen01Pos = screen_pos/_ScreenParams;
                float2 screen11pos = (screen01Pos-0.5)*2;
                screen11pos.y*=-1;
                float4 Hs = float4(screen11pos,0.5,1);
                float3 viewDir = mul(UNITY_MATRIX_I_P, Hs).xyz;

                
                float3 ori = _WorldSpaceCameraPos;
                float3 dirWS = mul(UNITY_MATRIX_I_V, float4(normalize(viewDir),0)).xyz;
                clip(dirWS.y);


                float x = dirWS.x/dirWS.y * SEA_HEIGHT;
                float z = dirWS.z/dirWS.y * SEA_HEIGHT;

                float3 ws = float3(x,SEA_HEIGHT,z);
                float3 color = float3(0,0,0);

                if(fmod(abs(ws.x) , SEA_BaseHeight)>SEA_BaseHeight*0.9)
                {
                    color = 1;
                }
                
                if(fmod(abs(ws.z) , SEA_BaseHeight)>SEA_BaseHeight*0.9)
                {
                    color = 1;
                }
                return color;
            }

            // VR下不要启用抗锯齿，GPU寄存器不够
             #define AA

            half4 frag(Varyings input):SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                const float2 screen_pos = input.positionHCS.xy;

                #ifdef AA
                float3 color = float3(0.0, 0.0, 0.0);
                for (int i = -1; i <= 1; i++)
                {
                    for (int j = -1; j <= 1; j++)
                    {
                        float2 uv = screen_pos + float2(i, j)/3;
                        
                        color += getPixel(uv );
                    }
                }
                color /= 9.0;
                #else

                
                float3 color = getPixel(screen_pos);
                #endif
                

                
                return float4(pow(clamp(color, 0, 1), 0.65), 1.0);
            }
            ENDHLSL
        }
    }
}