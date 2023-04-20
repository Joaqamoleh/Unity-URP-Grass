Shader "Custom/Grass"
{
    // Properties contains parameters that can be set in the editor with materials that use this shader
    // Syntax is var_name("in editor name", Object) = (default value in editor)
    properties
    {
        _Color("Main Color", Color) = (1, 1, 1, 1)
    }

    // contains all of the "sub-shaders", basically all the different types of shaders that make up our
    // grass shader such as the vertex, fragment, and other sub shaders
    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
			"Queue" = "Geometry"
			
        }
        LOD 100 // idk what this does yet lmao
		Cull Off // Apparently we want both sides of our grass to render? experiment with this later

        HLSLINCLUDE // keyword to tell Unity this is in HLSL
        	// Unity imports
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            // constants for mathematical calculations
            #define PI 3.14159265359f
			#define TWO_PI 6.28318530718f
            // initialize our parameters for the shader but for the shader and not the editor
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
            CBUFFER_END

            // structs for neatly packing vertex data, derived from this article
            // these are apparently very commonly used when writing shaders and
            // has to do with how unity passes data to the shader.
            // also derived from this guide on HLSL unity shaders:
            // https://cyangamedev.wordpress.com/2020/06/05/urp-shader-code/4/

            // vertex shader input
            struct VertexInput
			{
				float4 vertex  : POSITION;
				float3 normal  : NORMAL;
				float4 tangent : TANGENT;
				float2 uv      : TEXCOORD0;
			};
            
            // vertex shader output
			struct VertexOutput
			{
				float4 vertex  : SV_POSITION;
				float3 normal  : NORMAL;
				float4 tangent : TANGENT;
				float2 uv      : TEXCOORD0;
			};

            // geometry shader takes some different data, so we need a new struct for it
            struct GeoData
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            // Vertex Shader
            VertexOutput vertShader(VertexInput vIn) {
                // create our output object
                VertexOutput vOut;
                // transform our input vertex into worldspace
                vOut.vertex = float4(TransformObjectToWorld(vIn.vertex), 1.0f);
                vOut.normal = TransformObjectToWorldNormal(vIn.normal);
                vOut.tangent = vIn.tangent;
                return vOut;
            }

            // Geometry related functions derrived/inspired from this article https://roystan.net/articles/grass-shader/

            // helper function to create geoData instance and transform to clip space and 
            // apply an offset and transformation matrix
            // borrowed from https://youtu.be/MeyW_aYE82s because it saves so much space
            GeoData transformToClip(float3 pos, float3 offset, float3x3 tfMatrix, float2 uv) {
                GeoData g;
                g.pos = TransformObjectToHClip(pos + mul(tfMatrix, offset));
                g.uv = uv;
                g.worldPos = TransformObjectToHClip(pos + mul(tfMatrix, offset));

                return g;
            }


            // Geometry Shader
            [maxvertexcount(3)] // specifies the maximum amount of vertices the geo shader can make
            void geoShader(point VertexOutput input[1], inout TriangleStream<GeoData> stream) {
                // grab data from our input
                float3 pos = input[0].vertex.xyz;
                float3 norm = input[0].normal;


                // gonna do this manually bc life is unfair
                float3x3 tfMatrix = float3x3
                (
                    1, 0, 0,
                    0, 1, 0,
                    0, 0, 1
                );

                // append a triangle to the stream
                stream.Append(transformToClip(pos, float3(-0.1f, 0.0f, 0.0f), tfMatrix, float2(0.0, 0.0f)));
                stream.Append(transformToClip(pos, float3(0.1f, 0.0f, 0.0f), tfMatrix, float2(1.0, 0.0f)));
                stream.Append(transformToClip(pos, float3(0.0f, 0.5f, 0.0f), tfMatrix, float2(0.5, 1.0f)));
                
                // apparently this is good practice
                stream.RestartStrip();
            }
        ENDHLSL // end of HLSL code

        // Render pass for our grass shader
        Pass
        {
            Name "GrsPass"
            Tags {"LightMode" = "UniversalForward"} // to specify Universal Rendering

            HLSLPROGRAM
                #pragma require geometry

                #pragma vertex vertShader
                #pragma geometry geoShader
                #pragma fragment fragShader

                float4 fragShader(VertexOutput v) : SV_Target {
                    return float4(1.0f, 1.0f, 1.0f, 1.0f);
                }
            ENDHLSL
        }
    }
}