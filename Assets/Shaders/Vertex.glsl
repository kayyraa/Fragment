#ifdef VERTEX
uniform mat4 projectionMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;
uniform mat3 normalMatrix;
uniform bool isCanvasEnabled;
uniform bool edgePass;
uniform vec2 viewport;
uniform float lineWidth;
uniform float depthBias;

attribute vec3 VertexAux; // surface: normal, edge: other endpoint

varying vec3 vNormal;
varying vec3 vWorld;
varying float vDepth;
varying vec2 vTexCoord;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    vNormal = vec3(0.0, 1.0, 0.0);
    vWorld = vec3(0.0);
    vDepth = 0.0;
    vTexCoord = VertexTexCoord.xy;

    mat4 VP = projectionMatrix * viewMatrix;

    if (!edgePass) {
        vec4 world = modelMatrix * vertex_position;
        vNormal = normalMatrix * VertexAux;
        vWorld = world.xyz;
        vec4 screenPos = VP * world;
        vDepth = screenPos.w;
        if (isCanvasEnabled) screenPos.y *= -1.0;
        return screenPos;
    }

    // Edge pass: expand each edge into a screen-space quad of constant pixel width
    vec4 Own   = VP * modelMatrix * vec4(vertex_position.xyz, 1.0);
    vec4 Other = VP * modelMatrix * vec4(VertexAux, 1.0);
    float End  = VertexTexCoord.x; // 0 = start, 1 = end
    float Side = VertexTexCoord.y; // -1 / +1

    const float Eps = 0.01;
    if (Own.w < Eps && Other.w < Eps) return vec4(2.0, 2.0, 2.0, 1.0);
    if (Own.w < Eps)   Own   = mix(Own,   Other, (Eps - Own.w)   / (Other.w - Own.w));
    if (Other.w < Eps) Other = mix(Other, Own,   (Eps - Other.w) / (Own.w - Other.w));

    vec2 HalfView = viewport * 0.5;
    vec2 So = Own.xy / Own.w * HalfView;
    vec2 Sq = Other.xy / Other.w * HalfView;

    vec2 Dir = (End < 0.5) ? (Sq - So) : (So - Sq);
    float Len = length(Dir);
    Dir = (Len > 1e-5) ? Dir / Len : vec2(1.0, 0.0);
    vec2 Nrm = vec2(-Dir.y, Dir.x);

    float Hw = lineWidth * 0.5;
    vec2 Offset = Nrm * Side * Hw + Dir * ((End < 0.5) ? -Hw : Hw);

    Own.xy += Offset / HalfView * Own.w;
    Own.z -= depthBias * Own.w;
    if (isCanvasEnabled) Own.y *= -1.0;
    return Own;
}
#endif

#ifdef PIXEL
uniform bool edgePass;
uniform vec4 edgeColor;

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 ambientColor;
uniform float lightIntensity;

uniform vec3 viewPos;
uniform int renderStyle;
uniform float transparency;
uniform float depthRange;
uniform vec3 fillColor;

varying vec3 vNormal;
varying vec3 vWorld;
varying float vDepth;
varying vec2 vTexCoord;

vec4 effect(vec4 color, Image tex, vec2 texcoord, vec2 pixcoord) {
    if (edgePass) return edgeColor;

    vec4 base = Texel(tex, vTexCoord) * color;
    float Alpha = base.a * (1.0 - transparency);
    if (Alpha < 0.003) discard;

    vec3 N = normalize(vNormal);

    if (renderStyle == STYLE_NORMALS) {
        return vec4(N * 0.5 + 0.5, Alpha);
    }
    if (renderStyle == STYLE_DEPTH) {
        return vec4(vec3(1.0 - clamp(vDepth / depthRange, 0.0, 1.0)), Alpha);
    }
    if (renderStyle == STYLE_OUTLINE) {
        return vec4(fillColor, Alpha);
    }

    // Shaded: two-sided, so flip the normal toward the viewer
    vec3 V = normalize(viewPos - vWorld);
    if (dot(N, V) < 0.0) N = -N;

    float NdotL = max(dot(N, normalize(lightDir)), 0.0);
    vec3 Lit = base.rgb * (ambientColor + lightColor * NdotL * lightIntensity);
    return vec4(Lit, Alpha);
}
#endif