#define PI 3.14159265359

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

float2 rotate2d(float2 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float2(
        p.x * c - p.y * s,
        p.x * s + p.y * c
    );
}

float smoothMin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5*(b - a)/k, 0.0, 1.0);
    return lerp(b, a, h) - k*h*(1.0 - h);
}

float sdfSphere(float3 p, float r)
{
    return length(p) - r;
}

float sdfBox(float3 p, float3 b)
{
    float3 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

static float g_morphRate = 0;

float sdfMorphSphereBox(float3 p, float r, float3 b, float rate)
{
    float dSphere = sdfSphere(p, r);
    float dBox = sdfBox(p, b);
    return lerp(dSphere, dBox, rate);
}

SdfAndMat scanSdf(float3 pos)
{
    SdfAndMat result = emptySdfAndMat();

    float dMorph1;
    {
        float3 tmp = pos + float3(1, 1, 1) * 0.1;
        tmp.xy = rotate2d(tmp.xy, g_time * PI);
        dMorph1 = sdfMorphSphereBox(tmp, 0.2, float3(0.1, 0.1, 0.1), g_morphRate);
    }

    float dMorph2;
    {
        float3 tmp = pos - float3(1, 1, 1) * 0.1;
        tmp.xy = rotate2d(tmp.xy, -g_time * PI * 0.5);
        dMorph2 = sdfMorphSphereBox(tmp, 0.2, float3(0.1, 0.1, 0.1), 1.0 - g_morphRate);
    }

    float dMorph = smoothMin(dMorph1, dMorph2, 0.1);

    if (dMorph < result.sdf)
    {
        result.sdf = dMorph;
        result.mat = 1.0;
    }

    return result;
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

#define MAX_RAYMARCH 64

RaycastResult scanRaycast(float3 pos, float3 dir)
{
    RaycastResult result;
    result.pos = float3(0, 0, 0);
    result.d = emptySdfAndMat();

    float t = 0;
    for (int i = 0; i < MAX_RAYMARCH; ++i)
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

float3x3 rotateY(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float3x3(
        c, 0, s,
        0, 1, 0,
       -s, 0, c
    );
}

// -----------------------------------------------

float4 PS(s3d::PSInput input) : SV_TARGET
{
    g_morphRate = (sin(g_time * 5.0f) + 1.0) * 0.5;

    // -----------------------------------------------
    float3x3 cameraMat = rotateY(g_time * 0.5);

    float2 screenPos2 = input.position.xy;
    screenPos2 = (screenPos2 - g_resolution * 0.5) / g_resolution.y;

    float3 screenPos3 = float3(screenPos2.x, screenPos2.y, 0.0);
    float3 eyePos = float3(0, 0, -5);

    screenPos3 = mul(cameraMat, screenPos3);
    eyePos = mul(cameraMat, eyePos);

    float3 rayDir = normalize(screenPos3 - eyePos);

    RaycastResult r = scanRaycast(eyePos, rayDir);

    float3 color = float3(0, 0, 0);
    if (r.d.mat > 0)
    {
        float3 normal = scanNormal(r.pos);
        color = normal * 0.5 + 0.5;
    }

    return float4(color, 1.0);
}
