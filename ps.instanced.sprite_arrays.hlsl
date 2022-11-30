/************************************************************
 * File: ps.16lights.hlsl               Created: 2022/11/21 *
 *                                Last modified: 2022/11/28 *
 *                                                          *
 * Desc: Pixel shader. Co-shader for instanced sprite       *
 *       arrays.                                            *
 *                                                          *
 *  Copyright (c) David William Bull. All rights reserved.  *
 ************************************************************/

struct LIGHT {
	float4 lightPos; // .w == range
	float4 lightCol; // .a == flags
};

cbuffer cbLight {	// 512 bytes
	LIGHT l[16] : register(b0);
}

struct SPRITE_DPS {	// 16 bytes
	float  gev;	// Global emission value
	uint   pmc;	// Paint map colour
	uint   dmc;	// Damage map colour
	uint   das;	// 0-15==Damage map emission additive (8p8), 16=31==Damage map scalar (1p15)
};

StructuredBuffer<SPRITE_DPS> sprite : register(t0);

// [0] == Diffuse map | [1] == Normal map | [2] == Mask channels
Texture2D Texture[3] : register(t1);

SamplerState Sampler : register(s0);

struct GOut {	// 13 scalars
	float4 pos : SV_Position;
	float3 position : POSITION;
	float3 n : NORMAL;
	float2 tex : TEXCOORD;
	uint   i : BLENDINDICES;		// Sprite index
};

float4 main(in GOut g) : SV_Target {
	const float4 fTexSamp = Texture[0].Sample(Sampler, g.tex);

	// Discard texel if completely transparent
//	clip(fTexSamp.a - 0.01f);
	clip(fTexSamp.a - 0.70710678118654752440084436210485f);

	const float4 fTexel   = float4(pow(fTexSamp.rgb, 2.2f), fTexSamp.a);
	const float3 fTexMods = Texture[2].Sample(Sampler, g.tex);

	// Unpack paint & damage map colours
	const float4 fPMC = float4(((sprite[g.i].pmc >> uint4(0, 8, 16, 24)) & 0x0FF) + 1) * 0.00390625f;
	const float4 fDMC = float4(((sprite[g.i].dmc >> uint4(0, 8, 16, 24)) & 0x0FF) + 1) * 0.00390625f;
	// Unpack damage additive and scalar
	const float  fDMA = float(sprite[g.i].das & 0x0FFFF) * 0.00390625f;
	const float  fDMS = float((sprite[g.i].das >> 16) & 0x0FFFF) * 0.000030517578125f;

	const float  fTexDam   = (1.0f - fTexMods.b) * fDMS;
	const float  fEmission = (fTexMods.g * 4.0f - 3.0f) + sprite[g.i].gev;
	const float4 fPaint    = lerp(fTexel, fTexel * fPMC, fTexMods.r);
	const float4 fDamage   = lerp(fPaint, fTexel * fDMC, fTexDam);
	const float  fDamEmiss = fDMA * fTexDam;

	float3 fLight = { 0.0f, 0.0f, 0.0f };
	[unroll]
	for(uint i = 0; i < 3; i++) {
		float3 lCol = l[i].lightCol.rgb;
		float range = l[i].lightPos.w;
		float3 vToL = l[i].lightPos.xyz - g.position;
		float distToL = length(vToL);
		float att = min(1.0f, (distToL / range + distToL / (range * range)) * 0.5f);
		float3 lum = saturate(dot(vToL / distToL, g.n)) * lCol;
		fLight += lum * (1.0f - att);
	}
//	const float3 fHighlight = max(0.0f, fLight * fTexMods.b - 0.5f);

//	return fDamage * float4(fLight + fEmission + fDamEmiss, 1.0f) + float4(fHighlight, 0.0f);
	return fDamage * float4(fLight + fEmission + fDamEmiss, 1.0f);
}
