#version 300 es

#define PI 3.14159265359
#define deg2rad PI / 180.0
#define saturate(x) clamp(x, 0.0, 1.0)
precision highp float;

uniform float u_Time;
uniform vec2 u_AspectRatio;
uniform vec4 u_Eye;

out vec4 out_Col;
in vec2 f_Pos;
in float aspectRatio;

// referenced this tutorial: http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/

const int MAX_MARCHING_STEPS = 255;
const float MIN_DIST = 0.0;
const float MAX_DIST = 100.0;
const float EPSILON = 0.0001;

float time;

vec3 ambientMaterial = vec3(0.0);
vec3 diffuse = vec3(0.0);
vec3 specularMaterial = vec3(0.0);
vec3 outlineColor = vec3(0.0);

//const vec4 cameraPos = vec4()
//const vec4 lightPos = vec4()

vec2 convertAspectRatio(vec2 st) {

	return ((st + 1.0) / 2.0) * u_AspectRatio.xy;
}


//http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/
float intersectSDF(float distA, float distB) {
    return max(distA, distB);
}

//http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/
float unionSDF(float distA, float distB) {
    return min(distA, distB);
}

//http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/
float differenceSDF(float distA, float distB) {
    return max(distA, -distB);
}

//http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/
float sphereSDF(vec3 p) {
    return length(p) - 1.0;
}

/**
 * Rotation matrix around the X axis. https://www.shadertoy.com/view/4tcGDr
 */
mat3 rotateX(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(1, 0, 0),
        vec3(0, c, -s),
        vec3(0, s, c)
    );
}

/**
 * Rotation matrix around the Y axis. https://www.shadertoy.com/view/4tcGDr
 */
mat3 rotateY(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(c, 0, s),
        vec3(0, 1, 0),
        vec3(-s, 0, c)
    );
}

/**
 * Rotation matrix around the Z axis. https://www.shadertoy.com/view/4tcGDr
 */
mat3 rotateZ(float theta) {
    float c = cos(theta);
    float s = sin(theta);
    return mat3(
        vec3(c, -s, 0),
        vec3(s, c, 0),
        vec3(0, 0, 1)
    );
}

/**
 * Signed distance function for a sphere centered at the origin with radius r.
 */
float sphereSDF(vec3 p, float r) {
    return length(p) - r;
}

// iq
float capsuleSDF( vec3 p, vec3 a, vec3 b, float r )
{
    vec3 pa = p - a;
	vec3 ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h ) - r;
}

/**https://www.shadertoy.com/view/Xtd3z7 jamie wong
 */
float cubeSDF(vec3 p, vec3 size) {
    vec3 d = abs(p) - (size / 2.0);
    
    // Assuming p is inside the cube, how far is it from the surface?
    // Result will be negative or zero.
    float insideDistance = min(max(d.x, max(d.y, d.z)), 0.0);
    
    // Assuming p is outside the cube, how far is it from the surface?
    // Result will be positive or zero.
    float outsideDistance = length(max(d, 0.0));
    
    return insideDistance + outsideDistance;
}


// modified from jamie wong
vec3 scaleOp(vec3 samplePoint, vec3 scale)
{
	return (samplePoint / scale) * min(scale.x, min(scale.y, scale.z));
}

// iq
float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

float skull(vec3 p)
{
	vec3 scale = vec3(2.0, 1.5, 1.0); // scale sphere to ellipsoid
	vec3 headPoint = scaleOp(p, scale);
	headPoint -= vec3(0.0, .03, 0.0); //translate up
	float circle = sphereSDF(headPoint, .10);

	headPoint -= vec3(0.0, -.06, 0.0); 
	//headPoint = scaleOp(headPoint, vec3(.3, .1, .4));
	float square = cubeSDF(headPoint, vec3(.1, .1, .1)) - .01; // subtract a small constant for rounded edges

	return smin(circle, square, .01);
}

float eyes(vec3 p)
{
	//eyeball
	vec3 scale = vec3(1.7, 2.5, 1.0); // scale
	vec3 eye = scaleOp(p, scale);
	vec3 eye1 = eye - vec3(0.03, .0, 0.09); //translate
	vec3 eye2 = eye - vec3(-0.03, .0, 0.09);
	float e1 = sphereSDF(eye1, .03);
	float e2 = sphereSDF(eye2, .03);
	float eyes = unionSDF(e1, e2);

	// pupils
	vec3 pupil1 = eye1;
	vec3 pupil2 = eye2;
	pupil1 -= vec3(0.0, -.01, 0.0);
	pupil2 -= vec3(0.0, -.01, 0.0);
	float p1 = cubeSDF(pupil1, vec3(.01, .02, 0.08));
	float p2 = cubeSDF(pupil2, vec3(.01, .02, .08));
	float pupils = unionSDF(p1, p2);

	
	float eyeballs = differenceSDF(eyes, pupils);

	if(eyeballs < 0.0 + EPSILON) {
		vec3 eyeWhiteColor = 1.0 / 255.0 * vec3(239.0, 229.0, 137.0);
		ambientMaterial = eyeWhiteColor;
		diffuse = vec3(1.0, 1.0, 0.0);
		specularMaterial = vec3(1.0, 1.0, 1.0);
		outlineColor = eyeWhiteColor - vec3(.5, .5, .5);
	}
		if(pupils < 0.0 + EPSILON)
	{
		vec3 pupilColor = 1.0 / 255.0 * vec3(107.0, 38.0, 14.0);
		ambientMaterial = pupilColor;
		diffuse = pupilColor;
		specularMaterial = pupilColor;
	}
	return eyeballs;
}

//modified from iq
vec3 opMouthBend( vec3 p )
{
	// smile and frown
    float c = cos(cos(u_Time/100.0) * 1.0 * p.y + PI * 0.5);
    float s = sin(cos(u_Time/100.0) * 1.0 * p.y + PI * 0.5);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3((m*p.xy),p.z);
	
    return q;
}


//modified from iq
vec3 opNoseBend( vec3 p )
{
	
    float c = cos(3.0 * p.z + PI * 0.5);
    float s = sin(-4.0 * p.z + PI * 0.5);
    mat2  m = mat2(c,-s,s,c);
    vec3  q = vec3((m*p.xz),p.y);
	
    return q;
}

float mouth(vec3 p)
{
	
	vec3 a = vec3(-.15, -0.16, 0.0);
	vec3 b = vec3(.15, -0.16, 0.0);;
	float r = .06;

	p = rotateZ(-90.0 * deg2rad) * p;
	vec3 bend = opMouthBend(p);

	
	float mouth = capsuleSDF(bend, a, b, r);

	float mouthLine = capsuleSDF(bend - vec3(0, 0, .06), a, b, .01);

	if(mouthLine < 0.0)
	{
		ambientMaterial = vec3(.1, .1, .1);
		diffuse = vec3(.1, .1, .1);
		specularMaterial = vec3(.1, .1, .1);
		outlineColor = vec3(.1, .1, .1);
	}

	return differenceSDF(mouth, mouthLine);
}

float head(vec3 p)
{
	
	float skull = skull(p);
	float eyes = eyes(p);
	float mouth = mouth(p);
	float skullAndEyes = unionSDF(skull, eyes);
	return smin(skullAndEyes, mouth, .02);
}

float nose(vec3 p)
{
	vec3 translate = vec3(0.0, -.15, 0.09);
	vec3 a = vec3(.1, 0, 0.0);
	vec3 b = vec3(-0.10, 0, 0.0);
	float r = .05;

	p -= translate;
	p = rotateZ(90.0 * deg2rad) * p;
	
	vec3 bend = opNoseBend(p);
	bend = rotateX(0.0 * deg2rad) * bend;
	bend = rotateZ(70.0 * deg2rad) * bend;
	

	
	float nose = capsuleSDF(bend, a, b, r);
	return nose;
}

float squidward(vec3 samplePoint)
{

	samplePoint = rotateY(time / 2.0) * samplePoint;
	float head = head(samplePoint);
	float nose = nose(samplePoint);
	
	return unionSDF(head, nose);
}

// iq
vec3 opRep( vec3 p, vec3 c )
{
    return mod(p,c)-0.5*c;
}

float sceneSDF(vec3 samplePoint)
{
	float ogSquid = squidward(samplePoint);
	vec3 c = vec3(5, 15, 5);
	samplePoint = opRep(samplePoint, c);
	float repSquid = squidward(samplePoint);
	return unionSDF(ogSquid, repSquid);
}


/**
https://www.shadertoy.com/view/llt3R4
 * Return the shortest distance from the eyepoint to the scene surface along
 * the marching direction. If no part of the surface is found between start and end,
 * return end.
 * 
 * eye: the eye point, acting as the origin of the ray
 * marchingDirection: the normalized direction to march in
 * start: the starting distance away from the eye
 * end: the max distance away from the ey to march before giving up
 */
float shortestDistanceToSurface(vec3 eye, vec3 marchingDirection, float start, float end) {
    float depth = start;
    for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
        float dist = sceneSDF(eye + depth * marchingDirection);
        if (dist < EPSILON) {
			return depth;
        }
        depth += dist;
        if (depth >= end) {
            return end;
        }
    }
    return end;
}
   

/**
https://www.shadertoy.com/view/llt3R4
 * Return the normalized direction to march in from the eye point for a single pixel.
 * 
 * fieldOfView: vertical field of view in degrees
 * size: resolution of the output image
 * fragCoord: the x,y coordinate of the pixel in the output image
 */
vec3 rayDirection(float fieldOfView, vec2 size, vec2 fragCoord) {
    vec2 xy = fragCoord - size / 2.0;
    float z = size.y / tan(radians(fieldOfView) / 2.0);
    return normalize(vec3(xy, -z));
}

/**
http://jamie-wong.com/2016/07/15/ray-marching-signed-distance-functions/
 * Using the gradient of the SDF, estimate the normal on the surface at point p.
 */
vec3 estimateNormal(vec3 p) {
    return normalize(vec3(
        sceneSDF(vec3(p.x + EPSILON, p.y, p.z)) - sceneSDF(vec3(p.x - EPSILON, p.y, p.z)),
        sceneSDF(vec3(p.x, p.y + EPSILON, p.z)) - sceneSDF(vec3(p.x, p.y - EPSILON, p.z)),
        sceneSDF(vec3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(vec3(p.x, p.y, p.z - EPSILON))
    ));
}


//Referenced from  http://prideout.net/blog/?tag=toon-shader and https://en.wikibooks.org/wiki/GLSL_Programming/Unity/Toon_Shading
vec3 toonShader(vec3 p, vec3 viewDir)
{
    float shininess = 50.0;

	const float A = 0.05;
	const float B = 0.15;
	const float C = 1.0;
	const float D = 1.5;

	vec3 light1Pos = vec3(4.0 * sin(time),
                          2.0,
                          4.0 * cos(time));    
	vec3 N = estimateNormal(p);
    vec3 L = normalize(light1Pos);
    vec3 E = vec3(0.0, 0.0, 10.0);
	vec3 H = normalize(L+E);

	
    float sf = max(0.0, dot(N, H));
	sf = pow(sf, shininess);
	float eps = fwidth(sf);
	if(sf > .5 - eps && sf < .5 + eps)
	{
		sf = smoothstep(0.5 - eps, 0.5 + eps, sf);
	} else {
		sf = step(0.5, sf);
	}

	float df = max(0.0, dot(N, L));
	eps = fwidth(df);
	if      (df > A - eps && df < A + eps) df = mix(A, B, smoothstep(A - eps, A + eps, df));
    else if (df > B - eps && df < B + eps) df = mix(B, C, smoothstep(B - eps, B + eps, df));
    else if (df > C - eps && df < C + eps) df = mix(C, D, smoothstep(C - eps, C + eps, df));
    else if (df < A) df = 0.0;
    else if (df < B) df = B;
    else if (df < C) df = C;
    else df = D;
	
	if(ambientMaterial.x <= 0.0 && ambientMaterial.y <= 0.0 && ambientMaterial.z <= 0.0)
	{
		ambientMaterial = (1.0 / 255.0) * vec3(128.0, 216.0, 229.0);
		diffuse = vec3(0,1.0,0);
		specularMaterial = vec3(.02, .001, .001) + (1.0 / 255.0) * vec3(128.0, 216.0, 229.0);
		outlineColor = vec3(.01,0.1,0.1);
	} 

	if(dot(-viewDir, N) < mix(.8, .6, max(0.0, dot(N, L))) )
	{
		return  ambientMaterial + df * outlineColor;
	} else {
		return ambientMaterial + df * diffuse + sf * specularMaterial;
	}

	
}

/** https://www.shadertoy.com/view/Xtd3z7
 * Return a transform matrix that will transform a ray from view space
 * to world coordinates, given the eye point, the camera target, and an up vector.
 *
 * This assumes that the center of the camera is aligned with the negative z axis in
 * view space when calculating the ray marching direction. See rayDirection.
 */
mat4 viewMatrix(vec3 eye, vec3 center, vec3 up) {
    // Based on gluLookAt man page
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat4(
        vec4(s, 0.0),
        vec4(u, 0.0),
        vec4(-f, 0.0),
        vec4(0.0, 0.0, 0.0, 1)
    );
}

void main() {
	// TODO: make a Raymarcher!

// control animation angle
	time = cos(u_Time / 100.0);

	vec2 fragCoord = convertAspectRatio(f_Pos.xy);
	vec3 viewDir = rayDirection(45.0, u_AspectRatio, fragCoord);
    vec3 eye = vec3(0.0, 0.0, 3.0); 
    
    mat4 viewToWorld = viewMatrix(eye, vec3(0.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0));
    
    vec3 worldDir = (viewToWorld * vec4(viewDir, 0.0)).xyz;
    
    float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);
    
	// bubble background adapted from https://www.shadertoy.com/view/4slGDr
    if (dist > MAX_DIST - EPSILON) {
			// bubbles	
			vec3 color = 1.0 / 255.0 * vec3(45.0, 90.0, 163.0);
		for( int i=0; i<24; i++ )
		{
			// bubble seeds
			float pha =     sin(float(i) * 232.11) * .5 + .5;
			float siz =  pow(cos(float(i) * 39.2313 + 3.0)*.5 + .5, .5);
			float pox =     cos(float(i) * 231.2142 + .76332) * u_AspectRatio.x / u_AspectRatio.y; 
			// buble size, position and color
			float rad = 0.1 + 0.5 * siz + sin(time + pha * 500.0 + siz) / 20.0;
			vec2  pos = vec2( pox+sin(time + pha + siz), -1.0-rad + (2.0 + 2.0 * rad)
							* mod(pha + 0.1 * (time) * (0.13 +0.56 * siz),1.0));
			pos.y -= cos(time);
			float dis = length(f_Pos.xy - pos );
			vec3  col = sin(cos(time)) * vec3(.1, .1, .1);
			// render
			float f = length(f_Pos.xy-pos) / rad;
			f = sqrt(clamp(1.0 + (sin((time) + pha * 289.0 + siz) * 0.5)- f * f,0.0,1.0));
			color += col.zyx *(1.0 - smoothstep(rad * 0.82, rad, dis)) * f;
		}
		
        out_Col = vec4(color, 1.0);
		return;
    }
    
    // The closest point on the surface to the eyepoint along the view ray
    vec3 p = eye + dist * worldDir;
	vec3 color = toonShader(p, worldDir);   

    out_Col = vec4(color, 1.0);
}