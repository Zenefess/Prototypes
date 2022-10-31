/************************************************************
 * File: vs.instanced.squads.hlsl       Created: 2020/10/27 *
 *                                Last modified: 2020/10/31 *
 *                                                          *
 * Desc:                                                    *
 *                                                          *
 *  Copyright (c) David William Bull. All rights reserved.  *
 ************************************************************/

struct IOut {
	float3	trans : POSITION;
	float3	r_s : NORMAL;
	uint		bits : BLENDINDICES0;
	uint		bits2 : BLENDINDICES1;
	uint		i : SV_VertexID;
};

struct VOut {
	float3	trans : POSITION;
	float3	r_s : NORMAL;
	uint		bits : BLENDINDICES0;
};

/*  Reduced packet size -- 256x256 max atlas segments
	 -------------------
FLOAT3	Sprite location							// 12 bytes
FLOAT		Rotation										// 16 bytes
FLOAT2	Scale											// 28 bytes
UINT														// 32 bytes
	Fixed08p00	Texture X segment
	Fixed08p00	Texture X total segments
	Fixed08p00	Texture Y segment
	Fixed08p00	Texture Y total segments
UINT														// 32 bytes
	Fixed03p00	Squadron generation method
	Fixed04p00	X Sprite stride
	Fixed04p00	Y Sprite stride
	Fixed08p13	X/Y distance between sprites
*/

inline float SquadLineX(uint bits, uint index) {
	const uint  uiSS  = uint(((bits >> 0x03 & 0x0F) + 1) >> 1);
	const uint  uiSD  = uint(bits >> 0x0b & 0x01FFFFF);
	const float fDist = float(uiSD) * (1.0f / 4096.0f);

	return (float(index) - float(uiSS)) * fDist;
}

inline float SquadLineY(uint bits, uint index) {
	const uint  uiSS  = uint(((bits >> 0x07 & 0x0F) + 1) >> 1);
	const uint  uiSD  = uint(bits >> 0x0b & 0x01FFFFF);
	const float fDist = float(uiSD) * (1.0f / 4096.0f);

	return (float(index) - float(uiSS)) * fDist;
}

inline float2 SquadQuad(uint bits, uint index) {
	const uint  uiSSx  = uint(bits >> 0x03 & 0x0F);
	const uint  uiSSy  = uint(bits >> 0x07 & 0x0F);
	const float fSSx1  = uint((uiSSx + 1) >> 1);
	const float fSSy1  = uint((uiSSy + 1) >> 1);
	const uint  uiSD   = uint(bits >> 0x0b & 0x01FFFFF);
	const float fDist  = float(uiSD) * (1.0f / 4096.0f);

	return float2((float(uint(index % uiSSx)) - fSSx1), (float(uint(index / uiSSx)) - fSSy1)) * fDist;
}

inline float2 SquadTriangle(uint bits, uint index) {
	return (0.0f, 0.0f);
}

inline float2 SquadVFormation(uint bits, uint index) {
	return float2(0.0f, 0.0f);
}

VOut main(in IOut ia) {
	VOut vo;

	vo.trans = ia.trans;
	vo.r_s = ia.r_s;
	vo.bits = ia.bits;
	 
	switch(ia.bits2 & 0x07)	{
		case 1:
			vo.trans.x += SquadLineX(ia.bits2, ia.i);
			return vo;
		case 2:
			vo.trans.y += SquadLineY(ia.bits2, ia.i);
			return vo;
		case 3:
			vo.trans.xy += SquadQuad(ia.bits2, ia.i);
			return vo;
		case 4:
			vo.trans.xy += SquadTriangle(ia.bits2, ia.i);
			return vo;
		case 5:
			vo.trans.xy += SquadVFormation(ia.bits, ia.i);
			return vo;
		case 6:
			return vo;
		case 7:
			return vo;
		default:
			return vo;
	}
}
