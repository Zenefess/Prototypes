// Header elements of immutable structured buffer for predefined objects
al4 struct OBJECT_IGS {	// 4 bytes
	union {
		struct {
			ui16 ppi;	// Parent PART_IGS index
			ui16 qc;		// 0-4==Quad count - 1, 5-15==??
		};
		ui32 bits;	// 0-4==Quad count - 1, 5-7==???, 16-31==Parent PART_IGS index
	};
};

// Elements of immutable structured buffer for predefined objects
al4 struct PART_IGS {	// 68 bytes
	VEC3Df	pos;		// Position (relative)
	VEC3Df	rot;		// Rotation	(relative)
	VEC2Df	size;		//	Relative to parent
	VEC6Df	trans;	// Slide & rotation vectors (maximum transformation)
	ui32		bits;		// 0==Shape (quad/tri), 1==Billboard
	VEC4Du16	tc;		// tc[1].r == Paint map | tc[1].g == Emission map (+0.5f)
};							// tc[1].b == Phong map | tc[1].a == Damage map

// Elements of dynamic structured buffer for entity states
al8 struct BONE_DGS {	// 56 bytes
	VEC3Df	pos;
	VEC3Df	rot;
	VEC3Df	size;		// Scale (.x==0 ? Not drawn)
	float		lerp;		// pos->mt.s & rot->mt.r (current recoil state)
	VEC4Du16	tc;
	union {
		struct {
			ui8	ft[3];	//	Animation frame time : 16p8
			ui8	afc;		// Animation frame count : value - 1
		};
		ui32		afc_ft;	// 0-7==Animation frame offset, 8-31==Animation frame time : 16p8
	};
	union {
		struct {
			ui8	sai[3];	// 0-3==???, 4-23==SPRITE_DPS array index (~1,024K unique)
			ui8	afo;		// Animation frame offset
		};
		ui32		afo_sai;	// 0-7==Animation frame offset, 8-11==???,
	};							// 12-31==SPRITE array index (~1,024K unique)
};

// Elements of dynamic structured buffer for sprite modifiers
al16 struct SPRITE_DPS {	// 16 bytes
	float		gev;	// Global emission value
	VEC4Du8	pmc;	// Paint map colour : values - 1
	VEC4Du8	dmc;	// Damage map colour : values - 1
	ui16		dma;	// 0-15==Damage map emission additive : 8p8
	ui16		dms;	// 16=31==Damage map scalar : 1p15
};
