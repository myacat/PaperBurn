/*******************************************************
*   2020-03-18 16:38:42
*   @Mya
*   模拟纸张燃烧的shader
********************************************************/
Shader "Mya/Effect/BurningPaper"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _AshTex ("Ash Texture", 2D) = "white" {}
        _NoiseMap("Noise" , 2D) = "black"{}
        
        
        _Blend("Blend" , Range(0,1)) = 0
         [hdr]_RangeColor("Range Color" , Color) = (1,0,0,1)
        _Range("Range" , Range(0.01,0.5)) = 0.1
        _FireRange("Fire Range" , Range(0,0.5)) = 0.2
        _FireOffset("Fire Offset" , Range(0,1)) = 0
        [hdr]_SparkColor("Spark Color" , Color) = (1,0,0,1)
        _AshRange("Ash Range" , Range(0,1)) = 0.1
        _FlowVector("Flow Vector" , vector) = (0,0,0,0)

        _NoiseMap2("Noise2" , 2D) = "black"{}
        _VertOffset("Vert Offset" , Range(0,1))    = 0.1
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex   : POSITION;
                float2 uv       : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv       : TEXCOORD0;
                float4 uv2      : TEXCOORD1;
                float4 vertex   : SV_POSITION;
            };

            sampler2D   _MainTex;
            float4      _MainTex_ST;
            sampler2D   _AshTex;
            
            sampler2D   _NoiseMap; 
            float4      _NoiseMap_ST ;
            sampler2D   _NoiseMap2;
            float4      _NoiseMap2_ST ;

            half        _Blend;
            half        _Range;
            fixed4      _RangeColor;
            fixed4      _SparkColor;
            half        _AshRange;

            half        _FireRange;
            half        _FireOffset;

            half4       _FlowVector;
            half        _VertOffset;
            v2f vert (appdata v)
            {
                v2f o;
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                //通过采样两次噪音图进行叠加来让噪音更随机一些，让其中一次稍微放大一些防止完全重叠的情况
                o.uv2 = TRANSFORM_TEX(v.uv, _NoiseMap).xyxy * half4(1,1,1.3,1.3) + _FlowVector * _Time.x;

                //顶点里采样贴图需要使用tex2Dlod
                float4 noiseuv = float4(v.uv * _NoiseMap2_ST.xy + _NoiseMap2_ST.zw * _Time.x, 0,0) ;
                fixed noise = tex2Dlod(_NoiseMap2 , noiseuv) ;

                _Blend = _Blend * 4 - 1;
                //对燃烧区域的顶点做一点偏移，模拟飘动的效果
                half vertOffset =  noise *  _VertOffset * saturate (1 - (o.uv.x*4  -_Blend));

                o.vertex = UnityObjectToClipPos(v.vertex + half4(0,0,vertOffset ,0));

                return o;
            }


            fixed4 frag (v2f i) : SV_Target
            {
                fixed noise = (tex2D(_NoiseMap , i.uv2.xy) + tex2D(_NoiseMap2, i.uv2.zw))*0.5;
                
                //基于uv的x方向计算混合的权重，边缘使用噪音进行扰动
                //要保证四个状态（原始，燃烧，灰烬，消散）都能完整显示，需要把混合因子映射到-1~3
                _Blend = _Blend * 4 - 1;
                half blendValue = smoothstep(_Blend-_Range, _Blend+_Range, i.uv.x + noise * _Range) ;
                
                //原始的颜色
                fixed4 col = tex2D(_MainTex, i.uv.xy);
                //燃烧后的颜色
                fixed4 colAsh = tex2D(_AshTex, i.uv.xy);
   
                //余烬
                fixed3 spark =(smoothstep(0.8,1, noise)) * _SparkColor;

                //火焰
                float3 burnRange = max(0 , 1 - abs(blendValue - (_FireOffset *(1-_FireRange*2)+ _FireRange)) /_FireRange) * _RangeColor;

                //消散
                clip(col.a * (i.uv.x+ noise * _Range)  -  (_Blend  -  _Range -_AshRange)) ;

                //混合
                col.rgb = lerp(colAsh + spark, col ,  blendValue) + burnRange;

                return col;
            }
            ENDCG
        }
    }
}
