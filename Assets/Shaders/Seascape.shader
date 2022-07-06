Shader "KM/Seascape"
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
            ZTest always
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

            float hash(float2 p)
            {
                float h = dot(p, float2(127.1, 311.7));
                return frac(sin(h) * 43758.5453123);
            }

            float noise(in float2 p)
            {
                float2 i = floor(p);
                float2 f = frac(p);
                float2 u = f * f * (3.0 - 2.0 * f);
                return -1.0 + 2.0 * lerp(lerp(hash(i + float2(0.0, 0.0)),
                                              hash(i + float2(1.0, 0.0)), u.x),
                                         lerp(hash(i + float2(0.0, 1.0)),
                                              hash(i + float2(1.0, 1.0)), u.x), u.y);
            }

            // lighting
            float diffuse(float3 n, float3 l, float p)
            {
                return pow(abs(dot(n, l) * 0.4 + 0.6), p);
            }

            float specular(float3 n, float3 l, float3 e, float s)
            {
                float nrm = (s + 8.0) / (PI * 8.0);
                return pow(max(dot(reflect(e, n), l), 0.0), s) * nrm;
            }

            // sky
            float3 getSkyColor(float3 e)
            {
                e.y = (max(e.y, 0.0) * 0.8 + 0.2) * 0.8;
                return float3(pow(1.0 - e.y, 2.0), 1.0 - e.y, 0.6 + (1.0 - e.y) * 0.4) * 1.1;
            }

            // sea 
            float sea_octave(float2 uv, float choppy)
            {
                //return 0;
                uv += noise(uv);
                float2 wv = 1.0 - abs(sin(uv));
                float2 swv = abs(cos(uv));
                wv = lerp(wv, swv, wv);
                return pow(abs(1.0 - pow(abs(wv.x * wv.y), 0.65)), choppy);
            }

            const static float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);
            
            // p:point return 高度差
            float map(float3 p)
            {
                float freq = SEA_FREQ;
                float amp = 1;
                float choppy = SEA_CHOPPY;

                float2 uv = p.xz;
                float h = SEA_BaseHeight;
                
                float allH = (1-pow(0.22,ITER_GEOMETRY)/(1-0.22));
                
                for (int i = 0; i < ITER_GEOMETRY; i++)
                {
                    float d = sea_octave((uv + SEA_TIME) * freq, choppy);
                    d += sea_octave((uv - SEA_TIME) * freq, choppy);
                    h += d * amp/allH * SEA_HEIGHT;
                    // 只是扰动变换了UV
                    uv = mul(uv, octave_m);
                    // 频率加快
                    freq *= 1.9;
                    // 高度降低
                    amp *= 0.22;
                    // 更加平缓
                    choppy = lerp(choppy, 1.0, 0.2);
                }
                return p.y - h;
            }

            float map_detailed(float3 p)
            {
                float freq = SEA_FREQ;
                float amp = 1;
                float choppy = SEA_CHOPPY;
                float2 uv = p.xz;
                float h = SEA_BaseHeight;
                float allH = (1-pow(0.22,ITER_FRAGMENT)/(1-0.22));
                for (int i = 0; i < ITER_FRAGMENT; i++)
                {
                    float d = sea_octave((uv + SEA_TIME) * freq, choppy);
                    d += sea_octave((uv - SEA_TIME) * freq, choppy);
                    h += d * amp/allH * SEA_HEIGHT;
                    uv = mul(uv, octave_m);
                    freq *= 1.9;
                    amp *= 0.22;
                    choppy = lerp(choppy, 1.0, 0.2);
                }
                return p.y - h;
            }

            float3 getSeaColor(float height, float3 n, float3 l, float3 eye, float dist, float3 reflectedColor,
                               float3 refractedColor, float waterDepth)
            {
                float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
                fresnel = pow(fresnel, 3.0) * 0.5;

                float3 reflected = reflectedColor * reflectedIndex;
                float3 refracted = SEA_BASE + diffuse(n, l, 80.0) * SEA_WATER_COLOR * 0.12;
                refracted += refractedColor * refractedIndex * clamp((refractedMaxDepth - waterDepth) / refractedMaxDepth, 0,1);

                float3 color = lerp(refracted, reflected, fresnel);

                // 距离衰减
                float atten = max(1.0 - dist * dist * 0.001, 0.0);

                color += SEA_WATER_COLOR * (height - SEA_HEIGHT - SEA_BaseHeight) * 0.18 * atten;
                color += (specular(n, l, eye, 60.0));
                
                return lerp(color,1,clamp((0.05 - waterDepth)/0.05,0,1));
            }

            // tracing
            float3 getNormal(float3 p, float eps)
            {
                float3 n;
                n.y = map_detailed(p);
                n.x = map_detailed(float3(p.x + eps, p.y, p.z)) - n.y;
                n.z = map_detailed(float3(p.x, p.y, p.z + eps)) - n.y;
                n.y = eps;
                return normalize(n);
            }

            // 高度图步进
            float4 heightMapTracing(float3 ori, float3 dir)
            {
                float3 p;
                float tm = 0.0;
                float tx = 1000.0;
                p = ori;
                if (map(p) < 0)
                {
                    //起始点就在下面
                    return -1;
                }
                p = ori + dir * tx;
                float hx = map(p);
                if (hx > 0.0)
                {
                    // 最大距离还在上面
                    return tx;
                }

                p = ori + dir * tm;
                float hm = map(p);
                float tmid = 0.0;
                for (int i = 0; i < NUM_STEPS; i++)
                {
                    tmid = lerp(tm, tx, hm / (hm - hx));
                    p = ori + dir * tmid;
                    float hmid = map(p);
                    if (hmid < 0.0)
                    {
                        tx = tmid;
                        hx = hmid;
                    }
                    else
                    {
                        tm = tmid;
                        hm = hmid;
                    }
                }
                return float4(p,tmid);
            }

            float3 getPixel(in float2 screen_pos)
            {
                
                float2 uv = screen_pos/_ScreenParams;
                float2 screen11pos = (uv-0.5)*2;
                screen11pos.y*=-1;
                float4 Hs = float4(screen11pos,0.5,1);
                float3 viewPos = mul(UNITY_MATRIX_I_P, Hs).xyz;

                
                float3 ori = _WorldSpaceCameraPos;
                float3 dir = mul(UNITY_MATRIX_I_V, float4(normalize(viewPos),0)).xyz;
                clip(-dir.y);

                // tracing point
                const float4 data = heightMapTracing(ori, dir);
                clip(data.w);

                float depth = SampleSceneDepth(uv);
                float3 worldPos = ComputeWorldSpacePosition(uv, depth, UNITY_MATRIX_I_VP);
                // ray

                const float3 objDis = worldPos - ori;
                const float waterDepth = length(objDis) - data.w ;
                clip(waterDepth);

                float3 n = getNormal(data.xyz, data.w  * data.w  * EPSILON_NRM);

                float2 screenUV = uv;
                screenUV.x = 1 - screenUV.x;
                screenUV += n.xz * 0.1;

                const float3 reflectedColor = SAMPLE_TEXTURE2D_X(_MirrorTex, sampler_MirrorTex, screenUV).xyz;
                const float3 refractedColor = SampleSceneColor(uv + n.xz * 0.05);
                const float3 light_dir = GetMainLight().direction;

                // color 以地平线来分割
                return lerp(
                    getSkyColor(dir),
                    getSeaColor(data.y, n, light_dir, dir, data.w , reflectedColor, refractedColor, waterDepth),
                    pow(smoothstep(0.0, -0.02, dir.y), 0.2));
            }


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
                output.positionHCS = float4(input.positionOS.xy, 0.5, 0.5);
                output.viewPos = mul(UNITY_MATRIX_I_P, output.positionHCS).xyz;
                output.uv = input.uv;
                return output;
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
                        float2 uv = screen_pos + float2(i, j) / 3.0;
                        color += getPixel(uv);
                    }
                }
                color /= 9.0;
                #else
                float3 color = getPixel(screen_pos);
                #endif
                // post
                return float4(pow(clamp(color, 0, 1), 0.65), 1.0);
            }
            ENDHLSL
        }
    }
}