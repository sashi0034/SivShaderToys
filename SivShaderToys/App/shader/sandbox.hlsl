//-----------------------------------------------
//
//	This file is part of the Siv3D Engine.
//
//	Copyright (c) 2008-2025 Ryo Suzuki
//	Copyright (c) 2016-2025 OpenSiv3D Project
//
//	Licensed under the MIT License.
//
//-----------------------------------------------

//
//	Textures
//
Texture2D g_texture0 : register(t0);

SamplerState g_sampler0 : register(s0);

namespace s3d
{
    struct PSInput
    {
        float4 position : SV_POSITION;
        float4 color : COLOR0;
        float2 uv : TEXCOORD0;
    };
}

cbuffer PSConstants2D : register(b0)
{
    float4 g_colorAdd;
    float4 g_sdfParam;
    float4 g_sdfOutlineColor;
    float4 g_sdfShadowColor;
    float4 g_internal;
}

cbuffer SandboxData : register(b1) {
	float2 g_resolution;
	float g_time;
};

// -----------------------------------------------

struct SdfAndMat {
    float sdf;
    float mat; // TODO
};

SdfAndMat emptySdfAndMat()
{
    SdfAndMat result;
    result.sdf = 1e10;
    result.mat = 0.0;
    return result;
}

SdfAndMat sdfSphere(float3 p, float r)
{
    SdfAndMat result;
    result.sdf = length(p) - r;
    result.mat = 1.0;
    return result;
}

SdfAndMat scanSdf(float3 pos)
{
    return sdfSphere(pos, 1.0);
}

float3 scanNormal(float3 pos)
{
    float h = 1e-4;
    float3 n;
    n.x = scanSdf(pos + float3(h, 0, 0)).sdf - scanSdf(pos - float3(h, 0, 0)).sdf;
    n.y = scanSdf(pos + float3(0, h, 0)).sdf - scanSdf(pos - float3(0, h, 0)).sdf;
    n.z = scanSdf(pos + float3(0, 0, h)).sdf - scanSdf(pos - float3(0, 0, h)).sdf;
    return normalize(n);
}

struct RaycastResult {
    float3 pos;
    SdfAndMat d;
};

#define EPS 1e-4

#define MAX_DIST 1000.0

RaycastResult scanRaycast(float3 pos, float3 dir)
{
    RaycastResult result;
    result.pos = float3(0, 0, 0);
    result.d = emptySdfAndMat();

    float t = 0;
    for (int i = 0; i < 64; ++i)
    {
        float3 p = pos + dir * t;
        SdfAndMat d = scanSdf(p);
        if (d.sdf < EPS)
        {
            result.pos = p;
            result.d = d;
            break;
        }

        t += d.sdf;
    }

    return result;
}

// -----------------------------------------------

float4 PS(s3d::PSInput input) : SV_TARGET
{
    float3 color = float3(0, 0, 0);

    // -----------------------------------------------

    float2 screenPos2 = input.position.xy;
    screenPos2 = (screenPos2 - g_resolution * 0.5) / g_resolution.y;

    float3 screenPos3 = float3(screenPos2.x, screenPos2.y, 0.0);

    float3 eyePos = float3(0, 0, -5);

    float3 rayDir = normalize(float3(screenPos2.x, screenPos2.y, 1.0));

    RaycastResult r = scanRaycast(eyePos, rayDir);

    if (r.d.mat > 0)
    {
        float3 normal = scanNormal(r.pos);
        color = normal * 0.5 + 0.5;
    }

    return float4(color, 1.0);
}
