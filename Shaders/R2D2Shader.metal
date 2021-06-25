//
//  R2D2Shader.metal
//  R2D2
//
//  Created by Charlie Barber on 6/2/21.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewProjectionMatrix;
    float3x3 normalMatrix;
    
};

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldNormal;
    float3 worldPosition;
    float2 texCoord;
};

struct Light {
    float3 postition = float3(10, 2, 10);
    float3 color = float3(1, 1, 1);
};

struct Camera {
    float3 position = float3(0, 0, 25);
};

struct LightingModel {
    float ambientIntensity = 0.3;
    float specularPow = 200;
};

vertex VertexOut vertexShader(VertexIn vertexIn [[stage_in]], constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut vertexOut;
    
    float4 worldPosition = uniforms.modelMatrix * float4(vertexIn.position, 1);
    vertexOut.position = uniforms.viewProjectionMatrix * worldPosition; // Clip Space
    vertexOut.worldNormal = uniforms.normalMatrix * vertexIn.normal; // World space
    vertexOut.worldPosition = worldPosition.xyz; // World space
    vertexOut.texCoord = vertexIn.texCoord;
    return vertexOut;
    
};

fragment float4 fragmentShader(VertexOut fragmentIn [[stage_in]], texture2d<float> textureColor [[texture(0)]]) {
    
    constexpr sampler texSampler(filter::linear);
    float3 objectColor = textureColor.sample(texSampler, fragmentIn.texCoord).rgb;
    Light light;
    LightingModel lightModel;
    Camera camera;
    float ambient = lightModel.ambientIntensity;
//    float3 objectColor = float3(1, 0, 0);
    // Diffuse
    float3 normal = normalize(fragmentIn.worldNormal);
    float3 lightDir = normalize(light.postition - fragmentIn.worldPosition);
    float3 diffuseColor = saturate(dot(normal, lightDir));
    // Specular
    float3 viewDir = normalize(camera.position - fragmentIn.worldPosition);
    float3 halfWay = normalize(lightDir + viewDir);
    float specBase = saturate(dot(normal, halfWay));
    float specularIntensity = powr(specBase, lightModel.specularPow);

    float3 result = saturate(ambient + diffuseColor) * objectColor * light.color + specularIntensity * light.color;
    return float4(result, 1);
}
