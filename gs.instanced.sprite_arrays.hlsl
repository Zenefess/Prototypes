/************************************************************
 * File: gs.instanced.sprites.hlsl      Created: 2022/11/21 *
 *                                    Last mod.: 2022/12/04 *
 *                                                          *
 * Desc: Geometry shader. Generates 3-space sprites from    *
 *       point lists. Animation support, optional billboard *
 *       orienting, and choice between tri and quad.        *
 *                                                          *
 *  Copyright (c) David William Bull. All rights reserved.  *
 ************************************************************/

cbuffer CB_PROJ {
	matrix camera;
	matrix projection;
	float  totalSecs;
//	uint   totalTics[2];
//	float  elapsedSecs;
};

struct OBJECT_IMM {	// 4 bytes
	uint bits;	// 0-4==Quad count, 16-31==PART_IMM starting index
};

struct PART_IMM {	// 68 bytes
	float3	pos;		// Position (relative to origin)
	float3	rot;		// Rotation	(relative to origin)
	float2	size;		//	Relative to parent
	float3	t_pos;	// Slide & rotation vectors (maximum transformation)
	float3	t_rot;	// Slide & rotation vectors (maximum transformation)
	uint		bits;		// 0==Shape (quad/tri), 1==Billboard
	uint		tc[2];	// tc[1].r == Paint map | ts[1].g == Emission map (+0.5f)
};							// tc[1].b == Highlight map | ts[1].a == Occlusion map

struct BONE_DYN {	// 56 bytes
	float3	pos;
	float3	rot;
	float3	size;		// Scale (.x==0 ? Not drawn)
	float		lerp;		// pos->mt.s & rot->mt.r (current recoil state)
	uint		tc[2];
	uint		afc_ft;	// 0-7==Animation frame offset, 8-31==Animation frame time : 16p8
	uint		afo_sai;	// 0-7==Animation frame offset, 8-11==???, 12-31==SPRITE array index (~1,024K unique)
};

StructuredBuffer<uint> object;
StructuredBuffer<PART_IMM> part;
StructuredBuffer<BONE_DYN> bone;

struct GOut {	// 13 scalars
	float4 pos : SV_Position;
	float3 position : POSITION;
	float2 tex : TEXCOORD;
	uint   i : BLENDINDICES0;		// Sprite index
	uint   rotX : BLENDINCICES1;	// sin & cos of X rotation
	uint   rotY : BLENDINCICES2;	// sin & cos of Y rotation
	uint   rotZ : BLENDINCICES3;	// sin & cos of Z rotation
};

inline float2 RotateVector(float2 v, float2 dir) { return float2(dot(v, float2(dir.x, -dir.y)), dot(v, dir.yx)); }

// index[0]: 0-11==Object index (~4K unique), 12-31==Parent bone index (~1,024K unique)
[instance(32)] [maxvertexcount(4)]
void main(point uint index[1] : BLENDINDICES, uint pID : SV_PrimitiveID, uint iID : SV_GSInstanceID, inout TriangleStream<GOut> triStream) {
	GOut   output;
	float2 fRot;
	// Abandon quad if infinitely small
	if(bone[index[0] >> 12].size.x == 0.0f) return;
	// Unpack object array index from input data
	const uint uiOAI = index[0] & 0x0FFF;
	// Unpack quad count from object header bits
	const uint uiQuadC = object[uiOAI] >> 27;
	// Abandon quad if part is non-existant
	if(uiQuadC < iID) return;
	// Unpack array indices
	const uint uiBPI = index[0] >> 12;
	const uint uiBAI = uiBPI + uiQuadC - iID;
	const uint uiSAI = (bone[uiBAI].afo_sai & 0x0FFFFF);
	const uint uiPPI = object[uiOAI] & 0x0FFFF;
	const uint uiPAI = uiPPI + uiQuadC - iID;
	// Unpack bone bits
	const float fAFO = float((bone[uiBAI].afo_sai >> 24) & 0x0FF);
	const float fAFC = float(((bone[uiBAI].afc_ft >> 24) & 0x0FF) + 1);
	const float fFT  = float(bone[uiBAI].afc_ft & 0x0FF) * 0.00390625f + float((bone[uiBAI].afc_ft >> 8) & 0x0FFFF);
	// Unpack part bits
	const bool   bShape     = part[uiPAI].bits & 0x01;
	const bool   bBillboard = (part[uiPAI].bits >> 1) & 0x01;
	// Calculate adjusted position and rotation
	float3 fPosition = lerp(part[uiPAI].pos, part[uiPAI].t_pos, bone[uiBAI].lerp);
	float3 fRotation = lerp(part[uiPPI].rot + bone[uiBPI].rot, part[uiPPI].t_rot + bone[uiBPI].rot, bone[uiBPI].lerp);
	// Transrotate if child
	if(uiQuadC - iID) {
		fPosition *= float3(part[uiPPI].size, 1.0f) * bone[uiBPI].size * 0.25f;
		sincos(fRotation.z * 0.5f, fRot.y, fRot.x);
		fPosition.xy = RotateVector(fPosition.xy, fRot);
		fPosition.xy = RotateVector(fPosition.xy, fRot);
		sincos(fRotation.y * 0.5f, fRot.y, fRot.x);
		fPosition.xz = RotateVector(fPosition.xz, fRot);
		fPosition.xz = RotateVector(fPosition.xz, fRot);
		sincos(fRotation.x * 0.5f, fRot.y, fRot.x);
		fPosition.yz = RotateVector(fPosition.yz, fRot);
		fPosition.yz = RotateVector(fPosition.yz, fRot);

		fRotation += lerp(part[uiPAI].rot + bone[uiBAI].rot, part[uiPAI].t_rot, bone[uiBAI].lerp);
	}
	fPosition += lerp(part[uiPPI].pos + bone[uiBPI].pos, part[uiPPI].t_pos + bone[uiBPI].pos, bone[uiBPI].lerp);
	// Calculate size
	float3 fVert1 = bone[uiBAI].size * float3(part[uiPAI].size, 0.0f); if(iID) fVert1 *= bone[uiBPI].size;
	float3 fVert2 = float3(-fVert1.x, fVert1.yz);
	// Unpack texture coordinates
	const float4 fTC = float4((bone[uiBAI].tc[0] >> uint2(0, 16)) & 0x0FFFF, (bone[uiPAI].tc[1] >> uint2(0, 16)) & 0x0FFFF) * 0.000030517578125f;

	// Rotate
	sincos(fRotation.z, fRot.y, fRot.x);
	fVert1.xy = RotateVector(fVert1.xy, fRot);
	fVert2.xy = RotateVector(fVert2.xy, fRot);
	// Rotate around X and Y if not a billboard
	if(!bBillboard) {
		sincos(fRotation.y, fRot.y, fRot.x);
		fVert1.xz = RotateVector(fVert1.xz, fRot);
		fVert2.xz = RotateVector(fVert2.xz, fRot);
		sincos(fRotation.x, fRot.y, fRot.x);
		fVert1.yz = RotateVector(fVert1.yz, fRot);
		fVert2.yz = RotateVector(fVert2.yz, fRot);
	}
	
	output.i = uiSAI;
	sincos(fRotation.x + 1.5f, fRot.y, fRot.x);
	output.rotX = f32tof16(fRot.y) | (f32tof16(-fRot.x) << 16);
	sincos(fRotation.y + 1.5f, fRot.y, fRot.x);
	output.rotY = f32tof16(fRot.y) | (f32tof16(-fRot.x) << 16);
	sincos(fRotation.z + 1.5f, fRot.y, fRot.x);
	output.rotZ = f32tof16(fRot.y) | (f32tof16(-fRot.x) << 16);

	// Calculate animation frame offset
	const float fFrameOS = (fTC.z - fTC.x) * trunc(((totalSecs / fFT) + fAFO) % fAFC);

	// Bottom-left vertex
	output.position = fPosition; if(!bBillboard) output.position -= fVert1;
	float4 prePos = mul(float4(output.position, 1.0f), camera);
	if(bBillboard) prePos -= float4(fVert1, 0.0f);
	output.pos = mul(prePos, projection);
	output.tex = float2(fTC.x + fFrameOS, fTC.w);
	triStream.Append(output);

	// Top(-left) vertex
	output.position = fPosition; if(!bBillboard && !bShape) output.position += fVert2;	// Shift to top-left if quadrilateral
	prePos = mul(float4(output.position, 1.0f), camera);
	if(bBillboard && !bShape) prePos += float4(fVert2, 0.0f);
	output.pos = mul(prePos, projection);
	output.tex = float2(fTC.x + fFrameOS, fTC.y);
	triStream.Append(output);

	// Bottom-right vertex
	output.position = fPosition; if(!bBillboard) output.position -= fVert2;
	prePos = mul(float4(output.position, 1.0f), camera);
	if(bBillboard) prePos -= float4(fVert2, 0.0f);
	output.pos = mul(prePos, projection);
	output.tex = float2(fTC.z + fFrameOS, fTC.w);
	triStream.Append(output);

	// Top-right vertex
	if(bShape) return;	// Exit if triangle
	output.position = fPosition; if(!bBillboard) output.position += fVert1;
	prePos = mul(float4(output.position, 1.0f), camera);
	if(bBillboard) prePos += float4(fVert1, 0.0f);
	output.pos = mul(prePos, projection);
	output.tex = float2(fTC.z + fFrameOS, fTC.y);
	triStream.Append(output);
}
