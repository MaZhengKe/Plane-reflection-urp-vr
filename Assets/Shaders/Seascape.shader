Shader "KM/Seascape"
{
    Properties
    {

        SEA_BASE("基础颜色", Color) = (0.0,0.09,0.18,1)
        SEA_WATER_COLOR("水颜色", Color) = (0.48,0.54,0.36,1)

        NUM_STEPS("采样步数",int) = 8
        ITER_GEOMETRY("ITER_GEOMETRY",int) = 3
        ITER_FRAGMENT ("ITER_FRAGMENT",int) = 5

        SEA_HEIGHT("海高度",range(0,1)) = 0.6
        SEA_CHOPPY("海浪",range(0,10)) = 4.0
        SEA_SPEED("海浪速度",range(0,1)) = 0.8
        SEA_FREQ("海浪频率",range(0,0.5)) = 0.16

        AA("AA",Integer) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque" "RenderPeipeline" = "UniversalPepeline"
        }
        LOD 100

        Pass
        {
            name "ShaderToy"
            blend one zero
            ZWrite on
            ZTest always
            Cull off
            HLSLPROGRAM
            #pragma  vertex vert
            #pragma  fragment frag

            #define iGlobalTime   _Time.y
            #define iTime   _Time.y
            
            #define EPSILON_NRM (0.1 / _ScreenParams.x)
            #define SEA_TIME (1.0 + iTime * SEA_SPEED)


            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)

            int NUM_STEPS = 8;
            int ITER_GEOMETRY = 3;
            int ITER_FRAGMENT = 5;
            float SEA_HEIGHT = 0.6;
            float SEA_CHOPPY = 4.0;
            float SEA_SPEED = 0.8;
            float SEA_FREQ = 0.16;
            float3 SEA_BASE = float3(0.0, 0.09, 0.18);
            float3 SEA_WATER_COLOR = float3(0.8, 0.9, 0.6) * 0.6;

            int AA;

            CBUFFER_END


            //#define AA

            // math
            float3x3 fromEuler(float3 ang)
            {
                float2 xx = float2(sin(ang.x), cos(ang.x));
                float2 yy = float2(sin(ang.y), cos(ang.y));
                float2 zz = float2(sin(ang.z), cos(ang.z));
                float3x3 m;
                m[0] = float3(xx.y * zz.y + xx.x * yy.x * zz.x, xx.y * yy.x * zz.x + zz.y * xx.x, -yy.y * zz.x);
                m[1] = float3(-yy.y * xx.x, xx.y * yy.y, yy.x);
                m[2] = float3(zz.y * xx.x * yy.x + xx.y * zz.x, xx.x * zz.x - xx.y * zz.y * yy.x, yy.y * zz.y);
                return m;
            }

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
                uv += noise(uv);
                float2 wv = 1.0 - abs(sin(uv));
                float2 swv = abs(cos(uv));
                wv = lerp(wv, swv, wv);
                return pow(abs(1.0 - pow(wv.x * wv.y, 0.65)), choppy);
            }

            // p:point return 高度差
            float map(float3 p)
            {
                float freq = SEA_FREQ;
                float amp = SEA_HEIGHT;
                float choppy = SEA_CHOPPY;

                float2 uv = p.xz;
                

            float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);
                // why
                uv.x *= 0.75;
                float d, h = 0.0;
                for (int i = 0; i < ITER_GEOMETRY; i++)
                {
                    d = sea_octave((uv + SEA_TIME) * freq, choppy);
                    d += sea_octave((uv - SEA_TIME) * freq, choppy);
                    h += d * amp;
                    //uv *= octave_m;
                    //uv = mul(octave_m, uv);
                    // 只是扰动变换了UV
                    uv = mul(uv, octave_m);
                    //频率加快
                    freq *= 1.9;
                    //高度降低
                    amp *= 0.22;
                    choppy = lerp(choppy, 1.0, 0.2);
                }
                return p.y - h;
            }

            float map_detailed(float3 p)
            {

            float2x2 octave_m = float2x2(1.6, 1.2, -1.2, 1.6);
                float freq = SEA_FREQ;
                float amp = SEA_HEIGHT;
                float choppy = SEA_CHOPPY;
                float2 uv = p.xz;
                uv.x *= 0.75;
                float d, h = 0.0;
                for (int i = 0; i < ITER_FRAGMENT; i++)
                {
                    d = sea_octave((uv + SEA_TIME) * freq, choppy);
                    d += sea_octave((uv - SEA_TIME) * freq, choppy);
                    h += d * amp;
                    //uv *= octave_m;
                    uv = mul(octave_m, uv);
                    // uv = mul(uv, octave_m);
                    freq *= 1.9;
                    amp *= 0.22;
                    choppy = lerp(choppy, 1.0, 0.2);
                }
                return p.y - h;
            }

            float3 getSeaColor(float3 p, float3 n, float3 l, float3 eye, float3 dist)
            {
                float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
                fresnel = pow(fresnel, 3.0) * 0.5;
                float3 reflected = getSkyColor(reflect(eye, n));
                float3 refraced = SEA_BASE + diffuse(n, l, 80.0) * SEA_WATER_COLOR * 0.12;

                float3 color = lerp(refraced, reflected, fresnel);

                // 距离衰减
                float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);

                color += SEA_WATER_COLOR * (p.y - SEA_HEIGHT) * 0.18 * atten;
                color += (specular(n, l, eye, 60.0));
                return color;
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
            float heightMapTracing(float3 ori, float3 dir, out float3 p)
            {
                float tm = 0.0;
                float tx = 1000.0;
                float hx = map(ori + dir * tx);
                if (hx > 0.0)
                {
                    p = ori + dir * tx;
                    return tx;
                }

                float hm = map(ori + dir * tm);
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
                return tmid;
            }

            float3 getPixel(in float2 coord)
            {
                float2 uv = coord / _ScreenParams.xy;
                uv = uv * 2.0 - 1.0;
                uv.x *= _ScreenParams.x / _ScreenParams.y;
                // ray

                float3 ori = _WorldSpaceCameraPos;
                float3 dir = normalize(float3(uv.xy, -2.0));

                dir = mul(UNITY_MATRIX_I_V, normalize(dir));

                // tracing point
                float3 p;
                heightMapTracing(ori, dir, p);

                float3 dist = p - ori;
                float3 n = getNormal(p, dot(dist, dist) * EPSILON_NRM);

                const float3 light_dir = GetMainLight().direction;

                // color 以地平线来分割
                return lerp(
                    getSkyColor(dir),
                    getSeaColor(p, n, light_dir, dir, dist),
                    pow(smoothstep(0.0, -0.02, dir.y), 0.2));
            }

            // main
            float4 mainImage(float2 fragCoord)
            {
                float3 color = float3(0.0, 0.0, 0.0);
                if (AA == 1)
                {
                    for (int i = -1; i <= 1; i++)
                    {
                        for (int j = -1; j <= 1; j++)
                        {
                            float2 uv = fragCoord + float2(i, j) / 3.0;
                            color += getPixel(uv);
                        }
                    }
                    color /= 9.0;
                }
                else
                {
                    color = getPixel(fragCoord);
                }

                // post
                color = clamp(color,0,1);
                color = pow((color), 0.65);
                return float4(color, 1.0);
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
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                //output.positionHCS = TransformObjectToHClip(input.positionOS);

                output.positionHCS = float4(input.positionOS.xy, 0.5, 0.5);
                    
                output.uv = input.uv;

                return output;
            }

            half4 frag(Varyings input):SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 screenUV = input.positionHCS;

                return mainImage(screenUV);
            }
            ENDHLSL
        }
    }
}