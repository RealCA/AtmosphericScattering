// This shader fills the mesh shape with a color predefined in the code.
Shader "Hidden/URPUnlitShaderBasic"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    { }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        
		LOD 100


        Pass
        {
            ZTest Off
			Cull Off
			ZWrite Off
			Blend Off
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            
#define UNITY_HDR_ON
#pragma shader_feature ATMOSPHERE_REFERENCE
#pragma shader_feature LIGHT_SHAFTS
            // This line defines the name of the vertex shader. 
            #pragma vertex vertDir
            // This line defines the name of the fragment shader. 
            #pragma fragment fragDir

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"   
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"   
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"       
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"              
            #include "AtmosphericScattering.cginc"
            
			sampler2D _Background;		
            
		    float _DistanceScale;
		    float3 _LightDir;
            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				uint vertexId : SV_VertexID;        
            };

            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 wpos : TEXCOORD1;
            };            
            
		    sampler2D _LightShaft1;

            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings vertDir(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Varyings OUT;
                // The TransformObjectToHClip function transforms vertex positions
                // from object space to homogenous clip space.
                OUT.pos = TransformObjectToHClip(IN.vertex.xyz);
                
                OUT.uv = IN.uv.xy;
				OUT.wpos = _FrustumCorners[IN.vertexId];
                // Returning the output.
                return OUT;
            }

            // The fragment shader definition.            
            float4 fragDir(Varyings i) : SV_Target
            {
                float2 uv = i.uv.xy;
				float depth = LoadSceneDepth(uv);
				float linearDepth = Linear01Depth(depth,_ZBufferParams);

				float3 wpos = i.wpos;
				float3 rayStart = _WorldSpaceCameraPos;
				float3 rayDir = wpos - _WorldSpaceCameraPos;
				rayDir *= linearDepth;

				float rayLength = length(rayDir);
				rayDir /= rayLength;
					
				float3 planetCenter = _WorldSpaceCameraPos;
				planetCenter = float3(0, -_PlanetRadius, 0);
				float2 intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius + _AtmosphereHeight);
				if (linearDepth > 0.99999)
				{
					rayLength = 1e20;
				}
				rayLength = min(intersection.y, rayLength);

				intersection = RaySphereIntersection(rayStart, rayDir, planetCenter, _PlanetRadius);
				if (intersection.x > 0)
					rayLength = min(rayLength, intersection.x);

				float4 extinction;
				_SunIntensity = 0;
				float4 inscattering = IntegrateInscattering(rayStart, rayDir, rayLength, planetCenter, _DistanceScale, _LightDir, 16, extinction);
					
#ifndef ATMOSPHERE_REFERENCE
				inscattering.xyz = tex3D(_InscatteringLUT, float3(uv.x, uv.y, linearDepth));
				extinction.xyz = tex3D(_ExtinctionLUT, float3(uv.x, uv.y, linearDepth));
#endif					
#ifdef LIGHT_SHAFTS
				float shadow = tex2D(_LightShaft1, uv.xy).x;
				shadow = (pow(shadow, 4) + shadow) / 2;
				shadow = max(0.1, shadow);

				inscattering *= shadow;

#endif
				float4 background = tex2D(_Background, uv);

				if (linearDepth > 0.99999)
				{
#ifdef LIGHT_SHAFTS
					background *= shadow;
#endif
					inscattering = 0;
					extinction = 1;
				}
					
				float4 c = background * extinction + inscattering;
				return c;
            }
            ENDHLSL
        }
    }
}