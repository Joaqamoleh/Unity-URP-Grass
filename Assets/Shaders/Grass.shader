Shader "Custom/Grass"
{
    // Properties contains parameters that can be set in the editor with materials that use this shader
    // Syntax is var_name("in editor name", Object) = (default value in editor)
    properties
    {
        _Base_Color("Base Color", Color) = (0, 0, 0 , 1)
        _Tip_Color("Tip Color", Color) = (1, 1, 1, 1)
        
        _Bend_Delta("Grass Bend Randomness", Range(0, 1)) = 0.2
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
            // initialize our parameters for the shader but for the shader and not the editor
            CBUFFER_START(UnityPerMaterial)
                float4 _Base_Color;
                float4 _Tip_Color;
                float _Bend_Delta;
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
            
            // Psuedo random number generator. Takes a vec3 as a seed for more consistent results
            // derrived from this guide 
            // https://answers.unity.com/questions/399751/randomity-in-cg-shaders-beginner.html?childToView=624136#answer-624136
             float rand(float3 co) {
                return frac(sin( dot(co.xyz ,float3(12.9898,78.233,45.5432) )) * 43758.5453);
            }


            // Rotation with angle (in radians) and axis
            // sourced from https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
            float3x3 AngleAxis3x3(float angle, float3 axis) {
                float c, s;
                sincos(angle, s, c);

                float t = 1 - c;
                float x = axis.x;
                float y = axis.y;
                float z = axis.z;

                return float3x3(
                    t * x * x + c,      t * x * y - s * z,  t * x * z + s * y,
                    t * x * y + s * z,  t * y * y + c,      t * y * z - s * x,
                    t * x * z - s * y,  t * y * z + s * x,  t * z * z + c
                );
            }


            // Geometry Shader
            [maxvertexcount(3)] // specifies the maximum amount of vertices the geo shader can make
            void geoShader(point VertexOutput input[1], inout TriangleStream<GeoData> stream) {
                // grab data from our input
                float3 vPos = input[0].vertex.xyz;
                float3 vNorm = input[0].normal;
                float4 vTangent = input[0].tangent;
                // second tangent vector needed for calculations
                // we multiply by W here because Unity stores binormal direction in w
                float3 vBitangent = cross(vNorm, vTangent.xyz) * vTangent.w;


                // This matrix transforms the grass blade from tangent space to local space
                // This is kind common knowledge but I implemented it from this article:
                // https://roystan.net/articles/grass-shader/
                float3x3 tangentToLocal = float3x3
                (
                    vTangent.x, vBitangent.x, vNorm.x,
                    vTangent.y, vBitangent.y, vNorm.y,
                    vTangent.z, vBitangent.z, vNorm.z
                );

                // rotates around the y axis for grass blade orientation
                float3x3 rotMatrix = AngleAxis3x3(rand(vPos) * TWO_PI, float3(0.0f, 0.0f, 1.0f));
                // rotates around the X axis for grass blade bending. Affected by a variable in editor
                float3x3 bendMatrix = AngleAxis3x3(rand(vPos.zzx) * _Bend_Delta * PI, float3(1.0f, 0.0f, 0.0f));

                // Tip tf matrix applied by rotating and then bending
                float3x3 tipTfMatrix = mul(mul(tangentToLocal, rotMatrix), bendMatrix);
                // base tf matrix is just rotation since its "on" the ground
                float3x3 baseTfMatrix = mul(tangentToLocal, rotMatrix);

                // append a triangle to the stream
                stream.Append(transformToClip(vPos, float3(0.5f, 0.0f, 0.0f), baseTfMatrix, float2(0.0, 0.0f)));
                stream.Append(transformToClip(vPos, float3(-0.5f, 0.0f, 0.0f), baseTfMatrix, float2(1.0, 0.0f)));
                // vertical offset is on the z-axis instead of y-axis because of the tangent to local transformation
                stream.Append(transformToClip(vPos, float3(0.0f, 0.0f, 1.0f), tipTfMatrix, float2(0.5, 1.0f)));
                
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

                float4 fragShader(GeoData g) : SV_Target {
                    // lerp is used to interpolate between base and tip colors for the gradient
                    return lerp(_Base_Color, _Tip_Color, g.uv.y);
                }
            ENDHLSL
        }
    }
}