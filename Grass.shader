// Code was made while referencing the following sources: 
// Roystan's Grass Shader guide: https://roystan.net/articles/grass-shader/
// Daniel Illet's BoTW Grass Shader guide: https://youtu.be/MeyW_aYE82s
// CatLikeCoding's tesselation for UnityURP guide: 
//    https://catlikecoding.com/unity/tutorials/advanced-rendering/tessellation/
// Citations are in code as well for other sources for secondary things like math explanations
// heightmap generated from https://heightmap.skydark.pl/

Shader "Custom/Grass"
{
    // Properties contains parameters that can be set in the editor with materials that use this shader
    // Syntax is var_name("in editor name", Object) = (default value in editor)
    properties
    {
        _Base_Color("Base Color", Color) = (0, 0, 0 , 1)
        _Tip_Color("Tip Color", Color) = (1, 1, 1, 1)

        _Grass_Width_Min("Min Grass Width", Range(0, 1.0)) = 0.02
		_Grass_Width_Max("Max Grass Width", Range(0, 1.0)) = 0.05
		_Grass_Height_Min("Min Grass Height", Range(0, 3)) = 0.1
		_Grass_Height_Max("Max Grass Height", Range(0, 3)) = 0.3

        _Grass_Curvature("Blade Curvature", Range(1, 5)) = 2
        _Grass_Bend_Max("Grass Bendiness", Float) = 0.3
        _Slant_Delta("Grass Bend Variance", Range(0, 0.3)) = 0.2

        _GrassTessellationDistance("Grass Distance", Range(0.1, 1)) = 0.1
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
            // constant for number of segments for each blade
            #define GRASS_SEGMENTS 4
            // initialize our parameters for the shader but for the shader and not the editor
            CBUFFER_START(UnityPerMaterial)
                // grass color parameters
                float4 _Base_Color;
                float4 _Tip_Color;

                // grass shape parameters
                float _Grass_Width_Min;
                float _Grass_Width_Max;
                float _Grass_Height_Min;
                float _Grass_Height_Max;

                // grass bend/curve parameters
                // bend refers to how far forward the grass looks
                // curve refers to how curly the grass is
                int _Grass_Curvature;
                float _Grass_Bend_Max;
                float _Slant_Delta;

                float _GrassTessellationDistance;
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

            struct TessellationFactors
			{
				float edge[3] : SV_TessFactor;
				float inside  : SV_InsideTessFactor;
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

            // The following Domain and Hull shaders and helper functions were derrived from:
            // https://catlikecoding.com/unity/tutorials/advanced-rendering/tessellation/
            float tessellationEdgeFactor(VertexInput vert0, VertexInput vert1)
			{
				float3 v0 = vert0.vertex.xyz;
				float3 v1 = vert1.vertex.xyz;
                // get the distance between each vertex
				float edgeLength = distance(v0, v1);
                // divide by the length we want from each blade of grass
                // TODO: this can be editable by a random number to ensure grass is not completely uniform
				return edgeLength / _GrassTessellationDistance;
			}

            // patch constant function, decides where the new vertices will be
            TessellationFactors patchConstantFunction(InputPatch<VertexInput, 3> patch) {
                // create our tesselation factors struct
				TessellationFactors f;
                // get the tessellation
				f.edge[0] = tessellationEdgeFactor(patch[1], patch[2]);
				f.edge[1] = tessellationEdgeFactor(patch[2], patch[0]);
				f.edge[2] = tessellationEdgeFactor(patch[0], patch[1]);
				f.inside = (f.edge[0] + f.edge[1] + f.edge[2]) / 3.0f;

				return f;
			}

            // gets the data from the tessellated vertex and passes it to a vertexOutput object
            // different from the vertex shader bc we dont project the data or anything
            VertexOutput tessVertex(VertexInput v) {
                VertexOutput o;

				o.vertex = v.vertex;
				o.normal = v.normal;
				o.tangent = v.tangent;
				o.uv = v.uv;

				return o;
            }

            // Hull Shader
            [domain("tri")]
			[outputcontrolpoints(3)]
			[outputtopology("triangle_cw")]
			[partitioning("integer")]
			[patchconstantfunc("patchConstantFunction")]
			VertexInput hullShader(InputPatch<VertexInput, 3> patch, uint id : SV_OutputControlPointID)
			{
				return patch[id];
			}
            // Domain Shader
            [domain("tri")]
			VertexOutput domainShader(TessellationFactors factors, OutputPatch<VertexInput, 3> patch,
            float3 barycentricCoordinates : SV_DomainLocation) {
                VertexInput vertData;
                // it was recommended I make a macro for bary coord interpolation
                // for each fieldname in VertexInput.
                #define INTERPOLATE_BARY(fieldname) vertData.fieldname = \
					patch[0].fieldname * barycentricCoordinates.x + \
					patch[1].fieldname * barycentricCoordinates.y + \
					patch[2].fieldname * barycentricCoordinates.z;
                // interpolate all of the properties
                INTERPOLATE_BARY(vertex)
                INTERPOLATE_BARY(normal)
                INTERPOLATE_BARY(tangent)
                INTERPOLATE_BARY(uv)
                // return the vertex data as a VertexOutput for the geo shader
                return tessVertex(vertData);
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


            // Constructs a rotation matrix from angle (in radians) and an axis
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
            [maxvertexcount(GRASS_SEGMENTS * 2 + 1)] // specifies the maximum amount of vertices the geo shader can make
            void geoShader(point VertexOutput input[1], inout TriangleStream<GeoData> stream) {
                // grab data from our input
                float3 vPos = input[0].vertex.xyz;
                float3 vNorm = input[0].normal;
                float4 vTangent = input[0].tangent;
                // second tangent vector needed for calculations
                // we multiply by W here because Unity stores binormal direction in w
                float3 vBitangent = cross(vNorm, vTangent.xyz) * vTangent.w;


                // This matrix transforms the grass blade from tangent space to local space
                // This is kind of common knowledge but I implemented it from this article:
                // https://roystan.net/articles/grass-shader/
                float3x3 tangentToLocal = float3x3
                (
                    vTangent.x, vBitangent.x, vNorm.x,
                    vTangent.y, vBitangent.y, vNorm.y,
                    vTangent.z, vBitangent.z, vNorm.z
                );

                // wind
                float Wavelength = 15;
                float Speed = 50;
                float wind = PI / Wavelength  * (vPos.x - Speed * _SinTime.x);
                wind = clamp(wind % 1, .5, 1.57);
                

                // for wind effect
                float3x3 windMatrix = AngleAxis3x3(wind, float3(0.0f, 0.0f, 0.0f));


                // rotates around the y axis for grass blade orientation
                float3x3 rotMatrix = AngleAxis3x3(rand(vPos) * TWO_PI, float3(0.0f, 0.0f, 1.0f));

                // rotates around the X axis for grass blade slant. Affected by a variable in editor
                float3x3 bendMatrix = AngleAxis3x3(rand(vPos.zzx) * _Slant_Delta * PI, float3(1.0f, 0.0f, 0.0f));


                // Tip tf matrix applied by rotating and then bending
                float3x3 tipTfMatrix = mul(mul(mul(tangentToLocal, windMatrix), rotMatrix), bendMatrix);

                // base tf matrix is just rotation since its "on" the ground
                float3x3 baseTfMatrix = mul(tangentToLocal, rotMatrix);

                // grass width and height and forward should be calculated here
                float width = lerp(_Grass_Width_Min, _Grass_Width_Max, rand(vPos.xzy));
                float height = lerp(_Grass_Height_Min, _Grass_Height_Max, rand(vPos.zyx));
                float forward = rand(vPos.zzy) * _Grass_Bend_Max;

                // make whole segment at once, set tip vertex at the end
                for(int i = 0; i < GRASS_SEGMENTS; i++) {
                    // first, determine how far along the grass blade we are
                    // and determine what transformation matrix we need to use.
                    // t is always between 0 and 1 and corresponds to the y
                    // component of the uv
                    float t = i / (float)GRASS_SEGMENTS;
                    float3x3 tfMatrix = (i == 0) ? baseTfMatrix : tipTfMatrix;
                    // I spent an hour debugging bc I forgot we are in tangent space
                    // Since this is in tangent space, the Z axis is "up"
                    // The math for calculating the offsets was derrived from https://roystan.net/articles/grass-shader/
                    // but Im adding my own spice to it by messing with the paramaters a bit
                    float3 vOffset = float3(width * (1 - t), pow(t, _Grass_Curvature) * forward, height * t);
                    // append our 2 segment vertices to the Triangle Stream
                    stream.Append(transformToClip(vPos, float3(vOffset.x, vOffset.y, vOffset.z), tfMatrix, float2(0.0f, t)));
                    stream.Append(transformToClip(vPos, float3(-vOffset.x, vOffset.y, vOffset.z), tfMatrix, float2(1.0f, t)));

                }
                // append the tip vertex to the stream
                // vertical offset is on the z-axis instead of y-axis because of the tangent to local transformation
                stream.Append(transformToClip(vPos, float3(0.0f, forward, height), tipTfMatrix, float2(0.5, 1.0f)));
                
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
                #pragma require tessellation tessHW

                #pragma vertex vertShader
                #pragma hull hullShader
                #pragma domain domainShader
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