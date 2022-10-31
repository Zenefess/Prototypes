/************************************************************
 * File: gs.instanced.sprites.hlsl      Created: 2022/10/28 *
 *                                    Last mod.: 2022/10/31 *
 *                                                          *
 * Desc: Geometry shader. Generates billboarded sprites     *
 *       from point lists.                                  *
 *                                                          *
 *  Copyright (c) David William Bull. All rights reserved.  *
 ************************************************************/

cbuffer CB_PROJ {
	matrix camera;
};

/* Reduced packet size -- 256x256 max atlas segments
	-------------------------------------------------
FLOAT3	Sprite location									// 12 bytes
FLOAT		Rotation												// 20 bytes
FLOAT2	Scale													// 24 bytes
UINT																// 28 bytes
	Fixed8p00	Texture X segment
	Fixed8p00	Texture X total segments
	Fixed8p00	Texture Y segment
	Fixed8p00	Texture Y total segments
UINT																// 32 bytes
	Fixed3p00	Squadron generation method
	Fixed7p00	Sprite stride
	Fixed8p14	X/Y distance between sprites
*/

struct VOut {
	float3 position : POSITION;
	float3 r_s : NORMAL;
	uint   bits : BLENDINDICES;
};

struct GOut {
	float4 pos : SV_Position;
	float3 position : POSITION;
	float3 n : NORMAL;
	float2 tex : TEXCOORD;
	uint   pID : SV_PrimitiveID;
};

inline float2 RotateVector(float2 v, float2 dir) {
	float2 fResult;

	fResult.x = dot(v, float2(dir.x, -dir.y));
	fResult.y = dot(v, dir.yx);

	return fResult;
}

[maxvertexcount(4)]
void main(point VOut gin[1], uint pID : SV_PrimitiveID, inout TriangleStream<GOut> triStream) {
	const uint4  uiTV = (gin[0].bits >> uint4(0, 8, 16, 24)) & 0x0FF;
	const float4 fTV  = float4(int4(uiTV));
			float4 fTC  = float4(fTV.x, 1.0f - fTV.y, 1.0, 1.0) / fTV.ywyw;
			float4 fRot = gin[0].r_s.yzyz;
			float2 fDir; sincos(gin[0].r_s.x, fDir.y, fDir.x);
			GOut   output;

	fTC.zw += fTC.xy;
	fRot.w = -fRot.w;
	fRot.xy = RotateVector(fRot.xy, fDir);
	fRot.zw = RotateVector(fRot.zw, fDir);
	
	output.pID = pID;
	output.n = float3( 0.0f, 0.0f, -1.0f );

	output.position = gin[0].position;	// Translate
	output.position.xy -= fRot.xy;	// Rotate & scale
	output.pos = mul(float4(output.position, 1.0f), camera);	// Transform
	output.tex = fTC.xy;
	triStream.Append(output);
	
	output.position = gin[0].position;
	output.position.xy -= fRot.zw;
	output.pos = mul(float4(output.position, 1.0f), camera);
	output.tex = fTC.xw;
	triStream.Append(output);
	
	output.position = gin[0].position;
	output.position.xy += fRot.zw;
	output.pos = mul(float4(output.position, 1.0f), camera);
	output.tex = fTC.zy;
	triStream.Append(output);
	
	output.position = gin[0].position;
	output.position.xy += fRot.xy;
	output.pos = mul(float4(output.position, 1.0f), camera);
	output.tex = fTC.zw;
	triStream.Append(output);
}
Footer
