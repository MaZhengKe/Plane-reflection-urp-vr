Shader "KM/Cloud"
{
    Properties
    {
        cloudHeight ("cloudHeight ",float) = 1.1

        cloudscale ("cloudscale ",float) = 1.1
        speed ("speed      ",float) = 0.03
        clouddark ("clouddark  ",float) = 0.5
        cloudlight ("cloudlight ",float) = 0.3
        cloudcover ("cloudcover ",float) = 0.2
        cloudalpha ("cloudalpha ",float) = 8.0
        skytint ("skytint    ",float) = 0.5


        skycolour1("skycolour1",Color) = (0.2, 0.4, 0.6)
        skycolour2("skycolour2",Color) = (0.4, 0.7, 1.0)

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
            blend one one
            ZWrite on
            ZTest Lequal
            Cull off
            HLSLPROGRAM
            #pragma  vertex vert
            #pragma  fragment frag

            #define iGlobalTime   _Time.y
            #define iTime   _Time.y

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            TEXTURE2D_X(_MirrorTex);
            SAMPLER(sampler_MirrorTex);

            CBUFFER_START(UnityPerMaterial)

            float cloudHeight = 1.1;
            float cloudscale = 1.1;
            float speed = 0.03;
            float clouddark = 0.5;
            float cloudlight = 0.3;
            float cloudcover = 0.2;
            float cloudalpha = 8.0;
            float skytint = 0.5;
            float3 skycolour1 = float3(0.2, 0.4, 0.6);
            float3 skycolour2 = float3(0.4, 0.7, 1.0);

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
                output.positionHCS = float4(input.positionOS.xy * 1000, 0.5, 0.5 * 1000);
                output.viewPos = mul(UNITY_MATRIX_I_P, output.positionHCS).xyz;
                output.uv = input.uv;
                return output;
            }

            const static float2x2 m = float2x2(1.6, 1.2, -1.2, 1.6);

            float2 hash(float2 p)
            {
                p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
                return -1.0 + 2.0 * frac(sin(p) * 43758.5453123);
            }

            float noise(in float2 p)
            {
                const float K1 = 0.366025404; // (sqrt(3)-1)/2;
                const float K2 = 0.211324865; // (3-sqrt(3))/6;
                float2 i = floor(p + (p.x + p.y) * K1);
                float2 a = p - i + (i.x + i.y) * K2;
                float2 o = (a.x > a.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
                //float2 of = 0.5 + 0.5*float2(sign(a.x-a.y), sign(a.y-a.x));
                float2 b = a - o + K2;
                float2 c = a - 1.0 + 2.0 * K2;
                float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
                float3 n = h * h * h * h * float3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
                return dot(n, float3(70.0, 70.0, 70.0));
            }

            float fbm(float2 n)
            {
                float total = 0.0, amplitude = 0.1;
                for (int i = 0; i < 7; i++)
                {
                    total += noise(n) * amplitude;
                    n = mul(m, n);
                    amplitude *= 0.4;
                }
                return total;
            }

            // -----------------------------------------------

            float3 mainImage(in float2 fragCoord,float3 dir)
            {
                float2 mianUV = fragCoord.xy / _ScreenParams.xy;
                float2 uv = mianUV;
                float time = iTime * speed;
                float q = fbm(uv * cloudscale * 0.5);

                //ridged noise shape
                float r = 0.0;
                uv *= cloudscale;
                uv -= q - time;
                float weight = 0.8;
                for (int i = 0; i < 8; i++)
                {
                    r += abs(weight * noise(uv));
                    uv = mul(m, uv) + time;
                    weight *= 0.7;
                }

                //noise shape
                float f = 0.0;
                uv = mianUV;
                uv *= cloudscale;
                uv -= q - time;
                weight = 0.7;
                for (int i = 0; i < 8; i++)
                {
                    f += weight * noise(uv);
                    uv = mul(m, uv) + time;
                    weight *= 0.6;
                }

                f *= r + f;

                //noise colour
                float c = 0.0;
                time = iTime * speed * 2.0;
                uv = mianUV;
                uv *= cloudscale * 2.0;
                uv -= q - time;
                weight = 0.4;
                for (int i = 0; i < 7; i++)
                {
                    c += weight * noise(uv);
                    uv = mul(m, uv) + time;
                    weight *= 0.6;
                }

                //noise ridge colour
                float c1 = 0.0;
                time = iTime * speed * 3.0;
                uv = mianUV;
                uv *= cloudscale * 3.0;
                uv -= q - time;
                weight = 0.4;
                for (int i = 0; i < 7; i++)
                {
                    c1 += abs(weight * noise(uv));
                    uv = mul(m, uv) + time;
                    weight *= 0.6;
                }

                c += c1;

                float3 skycolour = lerp(skycolour2, skycolour1, dir.y);
                skycolour = 0;
                float3 cloudcolour = float3(1.1, 1.1, 0.9) * clamp((clouddark + cloudlight * c), 0.0, 1.0);

                f = cloudcover + cloudalpha * f * r;

                float3 result = lerp(skycolour, clamp(skytint * skycolour + cloudcolour, 0.0, 1.0),
                                     clamp(f + c, 0.0, 1.0) * clamp(dir.y*1.5 - 0.7,0,1));

                return clamp(result,0,1);
            }

            float3 getPixel(in float2 screen_pos)
            {
                float2 screen01Pos = screen_pos / _ScreenParams;
                float2 screen11pos = (screen01Pos - 0.5) * 2;
                
                #ifdef  UNITY_UV_STARTS_AT_TOP
                screen11pos.y*=-1;
                #endif
                float4 Hs = float4(screen11pos, 0.5, 1);
                float3 viewDir = mul(UNITY_MATRIX_I_P, Hs).xyz;

                float3 dirWS = mul(UNITY_MATRIX_I_V, float4(normalize(viewDir), 0)).xyz;
                clip(dirWS.y);


                float x = dirWS.x / dirWS.y * cloudHeight;
                float z = dirWS.z / dirWS.y * cloudHeight;

                float3 ws = float3(x, cloudHeight, z);


                return mainImage(ws.xz,dirWS);
                
            }

            // VR下不要启用抗锯齿，GPU寄存器不够
            //#define AA

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
                        float2 uv = screen_pos + float2(i, j) / 3;

                        color += getPixel(uv);
                    }
                }
                color /= 9.0;
                #else

                
                float3 color = getPixel(screen_pos);
                #endif


                return float4(clamp(color,0,1), 1.0);
            }
            ENDHLSL
        }
    }
}