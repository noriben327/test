// 2024/09/04 LaserLightShader V012

Shader "Noriben/noribenLaserLight_AudioLinkDelay"
{
    Properties
    {
        [Header(Color)]
        _Color1 ("Color 1" , Color) = (1.0, 1.0, 1.0, 1.0)
        _Color2 ("Color 2" , Color) = (1.0, 1.0, 1.0, 1.0)
        [PowerSlider(2.0)]_Brightness ("Brightness", Range(0, 30)) = 1
        _ColorSpeed ("Gradation Speed", Range(-10, 10)) = 1
        _HueRotation ("Hue Rotation", Range(-10, 10)) = 1
        [NoScaleOffset]_RenderTex ("Blend Render Texture Color(Multiply)", 2D) = "white" {}

        [Header(Main Parameter)]
        _Width ("Width", Range(0.0001, 1)) = 0.3
        [PowerSlider(2.)]_Scroll ("Scroll", Range(-1, 1)) = 1
        _Thickness ("Thickness", Range(0.0001, 2.)) = 0.02
        [IntRange] _Beams ("Beams", Range(0, 64)) = 1

        [Header(Sub Parameter)]
        _Flash ("Flash", Range(0, 1)) = 1
        _RandomFlash ("Random Flash", Range(0, 1)) = 1
        _Contrast ("Contrast", Range(0.01, 5)) = 1
        [PowerSlider(3.)] _Soft ("Soft", Range(0.0, 100.0)) = 100
        _rootIntensity ("Root Intensity", Range(0.0, 1.)) = 1
        _Transparency ("Transparency", Range(0,1)) = 0

        [Header(3D Noise)]
        [PowerSlider(.3)]_Noise ("Noise", Range(0, 1)) = 1
        _NoiseScroll ("Noise Scroll", Vector) = (0.1, 0.1,0,0)
        _NoiseSize ("Noise1 Size", Range(0, 3)) = 1
        _NoiseSize2 ("Noise2 Size", Range(0, 3)) = 1
        _NoisePower ("Noise1 Power", Range(0, 1)) = 1
        _NoisePower2 ("Noise2 Power", Range(0, 1)) = 1
        [NoScaleOffset]_Volume ("3D Noise Tex", 3D) = ""{}
        
        [Header(Swing)]
        _SwingSpeed ("Swing Speed", Range(0,1)) = 0
        _SwingWidth ("Swing Width", Range(0.001,.5)) = 0

        [Header(Chase)]
        [Toggle] _ChaseToggle ("Chase ON", int) = 0
        [PowerSlider(2.)]_ChaseSpeed ("Chase Speed", Range(-10,10)) = 0
        _ChaseWidth ("Chase Width", Range(0.5,1)) = 0

        [Header(Parameters used only in cone mesh)]
        _Triangle ("Triangle", Range(0, 1)) = 1
        _ConeWidth ("Cone Width", Range(-0.07, 1)) = 1
        _ConeLength ("Cone Length", Range(0, 3)) = 1
        _ConeWidthAnim ("Cone Width Animation", Range(0, 1)) = 1
        _ConeWidthSpeed ("Cone Width Speed", Range(0, 20)) = 1

        [Header(Brightness clamp)]
        _BrightnessClamp ("Brightness clamp", Range(0, 10)) = 1


        [Space(40)]
		[Header(AudioLink for VRChat)]
		[Toggle(AudioLinkOn)] _AudioLinkOn ("AudioLink On", Float) = 0
		
		_AudioLinkIntensity ("AudioLink Intensity", Range(0,1)) = 1
		[Enum(Bass,0,Low mid,1,High mid,2,Treble,3)]
		_AudioLinkType ("AudioLink BandType", int) = 0
		[HideInInspector]_AudioLinkFiltering ("AudioLink Smooth Filtering", Range(0, 1)) = 0
        _AudioLinkDelay ("AudioLink Delay", Range(0, 1)) = 0
    }
    SubShader
    {
		Tags { "RenderType"="Transparent" "Queue" = "Transparent" }
		Cull Off
		Blend One One
		Zwrite Off
		LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #pragma shader_feature_local _ AudioLinkOn

            #include "UnityCG.cginc"

            // AudioLink
			#ifdef AudioLinkOn
			#define ALPASS_AUDIOLINK uint2(0,0)
            #define ALPASS_FILTEREDAUDIOLINK uint2(0,28)
			float4 _AudioTexture_TexelSize;
            Texture2D<float4> _AudioTexture;
            #define AudioLinkData(xycoord) _AudioTexture[uint2(xycoord)]
            float4 AudioLinkLerp(float2 xy) { return lerp( AudioLinkData(xy), AudioLinkData(xy+int2(1,0)), frac( xy.x ) ); }
			#endif

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 uv2 : TEXCOORD1;
                float4 vertex : SV_POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler3D _Volume;
            float _Brightness;
            float _Scroll;
            float _Thickness;
            float _Beams;
            float _Triangle;
            float _Width;
            float _Noise;
            float _Flash;
            float _Contrast;
            float _rootIntensity;
            float _Transparency;
            float _ChaseSpeed;
            float _ChaseWidth;
            float4 _Color1;
            float4 _Color2;
            float _ColorSpeed;
            float _HueRotation;
            float _Soft;
            int _ChaseToggle;
            float _SwingSpeed;
            float _SwingWidth;
            float _ConeLength;
            float _ConeWidth;
            float _ConeWidthAnim;
            float4 _NoiseScroll;
            float _NoiseSize;
            float _NoiseSize2;
            float _NoisePower;
            float _NoisePower2;
            float _RandomFlash;
            float _ConeWidthSpeed;
            float _BrightnessClamp;
            float _AudioLinkIntensity;
			int _AudioLinkType;
			float _AudioLinkFiltering;
            float _AudioLinkDelay;
            sampler2D _RenderTex;
            

            v2f vert (appdata v)
            {
                
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);

                //コーンの直径を大きくする
				//0から1にグラデーション状に大きくする
                float coneWidthSpeed = _ConeWidthSpeed * _Time.y;
				float vertexHeight = (1 - v.uv.y) * _ConeWidth * 100 * (1.1- (((sin(coneWidthSpeed) + 1.) *.5) * _ConeWidthAnim)); 
				//normal方向に拡大
				v.vertex.xz = v.vertex.xz + v.normal.xz * 1 * vertexHeight;
				v.vertex.y *= _ConeLength;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                
                //ワールド座標の3Dノイズ用
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv2 = worldPos.xyz;

                return o;
            }

            //1D random
            float rand1d(float t)
            {
                return frac(sin(t) * 100000.);
            }
            
            //2D random
            float rand2d (float2 p) 
            { 
                return frac(sin(dot(p, fixed2(12.9898,78.233))) * 43758.5453);
            }

            //1D perlin noise
            float noise1d(float t)
            {
                float i = floor(t);
                float f = frac(t);
                return lerp(rand1d(i),rand1d(i + 1.), smoothstep(0., 1. , f));
            }

            // remap
            float remap(float In, float2 InMinMax, float2 OutMinMax)
            {
                return OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
            }
            
            // linearstep
            float linearstep(float edge0, float edge1, float x)
            {
                return min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0);
            }
            
            //イージング
            float ease_in_cubic(float x) {
                float t = x; float b = 0; float c = 1; float d = 1;
                return c*(t/=d)*t*t + b;
            }

            //HSV変換
            float3 hsv2rgb(float3 c)
            {
                float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }
            float3 rgb2hsv(float3 c)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
            
                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 uv = i.uv;
                const float pi = 3.1415926535;

                //3Dノイズ
                float3 tex3dUV = i.uv2 * _NoiseSize;
                float3 tex3dUV2 = i.uv2 * _NoiseSize2;
                tex3dUV = tex3dUV + _Time.y * _NoiseScroll.xyz;
                tex3dUV2 = tex3dUV2 + _Time.y * _NoiseScroll.xyz;
                float4 tex3d = tex3D(_Volume, tex3dUV);
                float4 tex3d2 = tex3D(_Volume, tex3dUV2);

                tex3d.xyz = tex3d.xyz * pow(tex3d.xyz, float3(4, 5, 5));
                tex3d2.xyz = tex3d2.xyz * pow(tex3d2.xyz, float3(4, 5, 5));

                tex3d = clamp(tex3d, 0, 1) * _NoisePower;
                tex3d2 = clamp(tex3d2, 0, 1) * _NoisePower2;

                tex3d = (tex3d + tex3d2);
                tex3d = clamp(tex3d, 0,1);
                
                tex3d = lerp(1, tex3d, _Noise);


                //下半円形クロップ
                float boxclop = smoothstep(.4, .9, uv.y);
                float circle = 1.- smoothstep(.2, .5, distance(uv, float2(.5,.5)));
                circle += boxclop;
                circle = lerp(circle, 1., _Triangle); //Triangle ONのときは円形クロップを使わない

                //UVで0がセンターにくるように
                uv.x += -.5;
                uv.x *= 2.0;

                //UVを三角形にする
                float grad = 1. -uv.y;
                grad += .000001; //0除算を防ぐ
                uv.x = lerp(uv.x / grad, uv.x, _Triangle);

                //UVスイング Triangle ONのときはスイングさせない
                uv.x += lerp(sin(_Time.y * _SwingSpeed / _SwingWidth) * _SwingWidth, 0, _Triangle);

                //両端ぼかしとクロップ
                float clop = smoothstep(_Width,_Width + 0.05, uv.x) + smoothstep(-_Width, -(_Width +.05),uv.x);
                clop = 1.-clop;
                //レンズ部分がクロップされないよう補正(_Triangleが1のときのみ)
                float nocloplens = smoothstep(0.9995,0.99995,uv.y);
                clop += lerp(0,nocloplens, floor(_Triangle));
                

                //追いかけていくように消えるやつ
                float chaseuv = uv.x / _Width;
                float chase = (sin(_Time.y *_ChaseSpeed + chaseuv) + 1.) * .5;
                chase = saturate(chase);
                float chase2 = (sin(_Time.y * _ChaseSpeed + chaseuv + pi) + 1.) * .5;
                chase2 = saturate(chase2);
                                                            //ChaseWidthが0.75を中心に1や0.5になるほどぼかす
                chase = smoothstep(_ChaseWidth, _ChaseWidth + abs(abs(((1.-_ChaseWidth)) -.25) -.25) + .02, chase);
                chase2 = smoothstep(_ChaseWidth, _ChaseWidth + abs(abs(((1.-_ChaseWidth)) -.25) -.25) + .02, chase2);
                chase += chase2;
                clop = lerp(clop, clop * saturate(chase), _ChaseToggle);
                
                

                //カラーグラデーション
                float gradSpeed = _Time.y * _ColorSpeed;
                                                    //Triangle OnのときUVの端と端で色がちゃんとつながるように
                float colorwave1 = (sin(gradSpeed + (uv.x * lerp(1,pi,_Triangle))) + 1.) * .5;
                float colorwave2 = (sin(gradSpeed + (uv.x * lerp(1,pi,_Triangle)) + pi) + 1.) * .5;
                float3 color1 = _Color1.xyz * colorwave1;
                float3 color2 = _Color2.xyz * colorwave2;
                float3 colorGrad = color1 + color2;
                //色相の回転
                colorGrad = rgb2hsv(colorGrad);
                colorGrad.x += _Time * _HueRotation;
                colorGrad = saturate(hsv2rgb(colorGrad));

                //uvスクロール
                uv.x += _Time.y * _Scroll;      
                //Triangleオフ用UVスイング
                uv.x += lerp(0, sin(_Time.y * _SwingSpeed / _SwingWidth) * _SwingWidth, _Triangle);

                //flash用のUV
                float2 flashUV = floor((float2(uv.x * 12 + _Time.y * 100,uv.y)) * 1) / 1;
    
                //タイリング(ビームの数)
                uv.x = frac(uv.x * _Beams);

                //タイルの中心を0にする
                uv.x = uv.x - 0.5;

                //レーザーの描画
                float wave = sin(uv.y - _Time.y) ;
                                //レーザーの数が減っても太くならないようにする
                float colwave = (_Thickness * _Beams * 0.1) / abs(uv.x);
                
                //点滅
                //2D random flash
                flashUV.x += _Time * 12.;
                float randomNoise = rand2d(flashUV * .01); // * .01はRTX20x0でのノイズの偏りのFixのため
                randomNoise = lerp(1, randomNoise, _RandomFlash);
                //1D random flash
                float flash = noise1d(_Time.y * 32.);
                flash = lerp(1, flash, _Flash);
                colwave = colwave * (flash * randomNoise);


                //透明度（グラデーション付き）
                float transv = pow(uv.y, 2.2);
                transv = lerp(transv, 0., _Transparency);

                //ビームのグラデーションと根本を明るくする
                colwave += pow(uv.y,12.1) * 3 *_rootIntensity;

                //ビームの太さを根本に行くほど太くする
                float beamGradCorrect = .2 / (1.-uv.y);
                colwave *= beamGradCorrect;
                //ここでクランプすると描写がソフトになる
                colwave = clamp(0, _Soft, colwave);
                
                
                //根本部分の補正（Cone Meshに適用したときにレンズ部分がいい感じに見えるよう）
                float lensColor = .01 / (1.-uv.y);
                lensColor = clamp(lensColor, 0, 10000);
                lensColor = pow(lensColor, 2.2);


                //_AudioLink
				#ifdef AudioLinkOn
                    /*
					float AudioLink = AudioLinkData(ALPASS_AUDIOLINK + int2(0, _AudioLinkType));
					float AudioLinkLowFiltered = AudioLinkData(ALPASS_FILTEREDAUDIOLINK + int2(0, _AudioLinkType));

					AudioLink = lerp(AudioLink, AudioLinkLowFiltered, _AudioLinkFiltering);
					AudioLink = lerp(1, AudioLink, _AudioLinkIntensity);
                    */

                    float AudioLink = AudioLinkLerp(uint2(0,0) + float2((0.5, _AudioLinkDelay) * 128 * 1, _AudioLinkType));
                    AudioLink = lerp(1, AudioLink, _AudioLinkIntensity);
				#endif
                
                // RenderTex Color
                float4 renderTexCol = tex2D(_RenderTex, float2(.5, .5));

                //カラー適用、コントラスト調整
                float3 col = float3(colwave,colwave,colwave) * colorGrad * clop * renderTexCol.xyz;


                col += lensColor;
                col *= tex3d.xyz;
                col = pow(col, _Contrast);
                

                //最終mix
                col = col  * transv * circle;
                col *= lerp(clop, 1, floor(_Triangle)); //根元部分が横に広がって光るアーティファクトの修正
                col *= _Brightness;

                #ifdef AudioLinkOn
                    col *= AudioLink;
                #endif

                col = clamp(col, 0, _BrightnessClamp);

                float4 finalcol = float4(col.xyz, 1.);
                

                return finalcol;
            }
            ENDCG
        }
    }
}
