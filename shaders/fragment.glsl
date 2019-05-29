precision mediump float;

varying vec3 vPosition;
uniform vec3 cameraPosition;
uniform int reflections;  // max = 10
uniform bool shadows;
uniform int numberOfSpheres;  // max = 64
uniform vec3 sphereCenters[64];
vec3 lightDirections[3];


uniform int trianglesnumber;  // m32
uniform vec3 trianglespnts[96];//123 ,456,789... trianglespnt

bool gettrianglepnt(int idx,out vec3 a)
{
	for(int i =0;i<96;i++)
	{
		if((i==idx)&&(i<trianglesnumber*3))
		{

			a = trianglespnts[i];
			return true;
		}
	}
	return false;
}

/**
 * Check for an intersection with a sphere
 */
bool intersectSphere(vec3 sphereCenter, vec3 rayStart, vec3 rayDirection, out float distance) {
  vec3 rayToSphere = sphereCenter - rayStart;
  float b = dot(rayDirection, rayToSphere);
  float d = b*b - dot(rayToSphere, rayToSphere) + 1.0;

  if (d < 0.0) {
    distance = 10000.0;
    return false;
  }

  distance = b - sqrt(d);
  if (distance < 0.0) {
    distance = 10000.0;
    return false;
  }

  return true;
}

/**
 * Does the ray intersect a sphere, if so, output the sphere's index and distance from the ray start
 */
bool intersectSpheres(vec3 rayStart, vec3 rayDirection, out int sphereIndex, out float distance, out vec3 intersectPosition, out vec3 normal) {
  float minDistance = -1.0, thisDistance = 0.0;
  for (int i = 0; i < 64; i++) {
    if (i < numberOfSpheres) {
      if (intersectSphere(sphereCenters[i], rayStart, rayDirection, thisDistance)) {
        if (minDistance < 0.0 || thisDistance < minDistance) {
          minDistance = thisDistance;
          sphereIndex = i;
          intersectPosition = rayStart + minDistance * rayDirection;
          normal = intersectPosition - sphereCenters[i];
        }
      }
    }
  }

  if (minDistance <= 0.0) {
    sphereIndex = -1;
    distance = 10000.0;
    return false;
  } else {
    distance = minDistance;
    return true;
  }
}

bool intersectSpheresSimple(vec3 rayStart, vec3 rayDirection) {
  float minDistance = -1.0, thisDistance = 0.0;
  for (int i = 0; i < 64; i++) {
    if (i < numberOfSpheres) {
      if (intersectSphere(sphereCenters[i], rayStart, rayDirection, thisDistance)) {
        if (minDistance < 0.0 || thisDistance < minDistance) {
          minDistance = thisDistance;
        }
      }
    }
  }

  return (minDistance >= 0.0);
}

bool intersectSingleTriangle(vec3 rayStart,vec3 rayDirection,int nidx,out float distance)
{
  vec3 a,b,c;
  if(!gettrianglepnt(nidx,a))
  {
  	return false;
  }
  if(!gettrianglepnt(nidx+1,a))
  {
  	return false;
  }
  if(!gettrianglepnt(nidx+2,a))
  {
  	return false;
  }
  vec3 veg1 = b-a;
  vec3 veg2 = c-a;
	vec3 vt = rayStart - a;
	vec3 vp = cross(rayDirection,veg2);
	vec3 vq = cross(vt,veg1);
	float vpe1 = dot(vp,veg1);
	float vu = dot(vp,vt)/vpe1;
	float vv = dot(vq,rayDirection)/vpe1;

	if((vu > 0.0) && (vv > 0.0) && ((vu + vv) < 1.0))
	{
	   distance = dot(vq ,veg2)/vpe1;
	   return true;
	}
	else
	{
	   return false;
	}

}

bool intersectTianglesSimple(vec3 rayStart,vec3 rayDirection)
{
	float closestDis = -1.0;
    float hitDis = 0.0;
    for (int i = 0; i < 32; i++)
    {
      if (i < trianglesnumber)
      {
        if (intersectSingleTriangle(rayStart, rayDirection,i, hitDis))
        {
          if (closestDis < 0.0 || hitDis < closestDis)
          {
            closestDis = hitDis;
          }
        }
      }
    }
    return (closestDis >= 0.0);

}

bool intersectTriangles(vec3 rayStart, vec3 rayDirection,out int idx,out vec3 normal,out vec3 intersectpnt)
{
    float closestDis = -1.0, hitDis = 0.0;
    for (int i = 0; i < 32; i++)
    {
      if (i < trianglesnumber)
      {
        if (intersectSingleTriangle(rayStart, rayDirection,i, hitDis))
        {
          if (closestDis < 0.0 || hitDis < closestDis)
          {
            closestDis = hitDis;
            idx = i;
            intersectpnt = rayStart + closestDis*rayDirection;
          }
        }
      }
    }
    return (closestDis >= 0.0);
}

 bool intersectionCube( vec3 dir, vec3 origin, vec3 cubeMin, vec3 cubeMax) {
                    vec3 tMin = (cubeMin - origin) / dir;
                    vec3 tMax = (cubeMax - origin) / dir;
                    vec3 t1 = min(tMin, tMax);
                    vec3 t2 = max(tMin, tMax);
                    float tNear = max(max(t1.x, t1.y), t1.z);
                    float tFar = min(min(t2.x, t2.y), t2.z);
                    return (tNear >= tFar) ? true : false;
 }
/**
 * Calculate the intensity of light at a certain angle - 0.0 means none, 1.0 means true colour, >1.0 for gloss/shine
 */
vec3 lightAt(vec3 position, vec3 normal, vec3 viewer, vec3 color) {
  vec3 light = lightDirections[0];
  vec3 reflection = reflect(-light, normal);

  vec3 intersectPosition, n;
  float intensity = 0.0, distance;
  int sphereIndex;

  for (int i = 0; i < 3; i++) {
    light = lightDirections[i];
    reflection = reflect(-light, normal);

    // TODO: check if testing for shadows here is valid...
    if (!shadows || !intersectSpheresSimple(position, light)) {
      intensity = intensity + 0.05 + 0.3 * pow(max(dot(reflection, viewer), 0.0), 30.0) + 0.7 * dot(light, normal);
    } else {
      intensity = intensity + 0.05;
    }
  }

  intensity = intensity / 1.5;

  if (intensity > 1.0) {
    return mix(color, vec3(1.2, 1.2, 1.2), intensity - 1.0);
  }

  return intensity * color;
}


const vec3 boxMin = vec3(-0.5, -0.5, -0.5);
  const vec3 boxMax = vec3(1.0, 1.0, 1.0);
/**
 * Check if our ray intersects with an object/floor
 */
bool intersectWorld(vec3 rayStart, vec3 rayDirection, out vec3 intersectPosition, out vec3 normal, out vec3 color,out int hitType) {
  int gemIndex;
  float distance;

  if (intersectSpheres(rayStart, rayDirection, gemIndex, distance, intersectPosition, normal)) {
    float i = float(gemIndex);
    float n = i / 32.0;
    color = vec3(sin(1.0/n) / 2.0 + 0.5, sin(n) / 2.0 + 0.5, cos(n) / 2.0 + 0.5);
    hitType = 0; //sphere
   } else if(intersectionCube( rayDirection, rayStart,boxMin, boxMax))
   {
     float n = 1.0/ 32.0;
     color = vec3(sin(1.0/n) / 2.0 + 0.5, sin(n) / 2.0 + 0.5, cos(n) / 2.0 + 0.5);
  
  }
  else if (rayDirection.y < -0.01) {
    intersectPosition = rayStart + ((rayStart.y + 2.7) / -rayDirection.y) * rayDirection;

    if (intersectPosition.x*intersectPosition.x + intersectPosition.z*intersectPosition.z > 300.0) {
      return false;
    }

    normal = vec3(0.0, 1.0, 0.0);

    if (fract(intersectPosition.x / 5.0) > 0.5 == fract(intersectPosition.z / 5.0) > 0.5) {
      color = vec3(1.0);
    } else {
      color = vec3(0.0, 0.45, 0.4);
    }
  } else {
   return false;
  }

  return true;
}

void main(void) {
  vec3 cameraDirection = normalize(vPosition - cameraPosition);

  lightDirections[0] = normalize(vec3(0.577350269, 0.577350269, -0.577350269));
  lightDirections[1] = normalize(vec3(0.577350269, 0.577350269, -0.577350269));
  lightDirections[2] = normalize(vec3(0.5, 1.0, 1.0));

  // start pos, normal, end pos
  vec3 position1, normal, position2;
  vec3 color, reflectedColor, colorMax;
  int hitType =0;
  if (intersectWorld(cameraPosition, cameraDirection, position1, normal, reflectedColor,hitType)) {
    color = lightAt(position1, normal, -cameraDirection, reflectedColor);
    colorMax = (reflectedColor + vec3(0.7)) / 1.7;
    cameraDirection = reflect(cameraDirection, normal);

    // since integer modulo isn't available
    bool even = true;
    for (int i=0; i<10; i++) {
      // since loops *have* to be unrolled due to no branches
      if (i < int(reflections)) {
        if (even) {
          even = false;
          if (intersectWorld(position1, cameraDirection, position2, normal, reflectedColor,hitType)) {
            color += lightAt(position1, normal, -cameraDirection, reflectedColor) * colorMax;
            colorMax *= (reflectedColor + vec3(0.7)) / 1.7;
            cameraDirection = reflect(cameraDirection, normal);
          } else {
            break;
          }
        } else {
          even = true;
          if (intersectWorld(position2, cameraDirection, position1, normal, reflectedColor,hitType)) {
            color += lightAt(position2, normal, -cameraDirection, reflectedColor) * colorMax;
            colorMax *= (reflectedColor + vec3(0.7)) / 1.7;
            cameraDirection = reflect(cameraDirection, normal);
          } else {
            break;
          }
        }
      } else {
        break;
      }
    }

    gl_FragColor = vec4(color, 1.0);
  } else {
    gl_FragColor = vec4(0.1, 0.1, 0.1, 1.0);
  }
}
