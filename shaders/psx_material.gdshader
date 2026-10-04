shader_type spatial;
render_mode vertex_lighting, specular_disabled, cull_back;
// Material estilo PS1 (opcional): vertex snapping (tremor de vértices) e textura afim.
// Funciona em Compatibility/WebGL2. Use `Efeitos.material_psx(cor, textura)` para criar um
// e deixar o `snap` seguir GameState.corruption, ou crie um ShaderMaterial na mão.
//
//  snap  resolução da grade de vértices (menor = mais tremor). 1024 ≈ quase nada, 120 = bem PS1.
//  afim  0 = textura com perspectiva correta, 1 = textura ondulando (afim) como no PS1.

uniform vec4 cor : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_nearest, repeat_enable;
uniform bool usa_tex = false;
uniform vec2 escala_uv = vec2(1.0);
uniform float snap = 512.0;
uniform float afim : hint_range(0.0, 1.0) = 1.0;

varying vec3 uv_w;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 ndc = clip.xyz / clip.w;
	ndc.xy = floor(ndc.xy * snap + 0.5) / snap;
	POSITION = vec4(ndc * clip.w, clip.w);
	uv_w = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, uv_w.xy / uv_w.z, afim) * escala_uv;
	vec4 t = usa_tex ? texture(tex, uv) : vec4(1.0);
	ALBEDO = cor.rgb * t.rgb;
	ALPHA = cor.a * t.a;
	ROUGHNESS = 1.0;
}
