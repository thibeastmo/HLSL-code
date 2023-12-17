float3 iResolution;//built-in
float4 iMouse; //built-in
uniform float3 iChannelResolution;//built-in
float Scale;
float2 Offset;
float iTime; //built-in
float Intensity;
float TimeSpeed;
static const float PI = 3.14159265f;

float getXYcomparison() {
    return iResolution.x > iResolution.y ? iResolution.y/iResolution.x : iResolution.x/iResolution.y;
}

float getBorderValue(float borderWidth, float2 position, float2 circleCenterPosition, float circleRadius) {
    float2 value = length(float2(circleRadius, circleRadius) - circleCenterPosition);
    float2 value2 = length(position - circleCenterPosition);
    if (value.x > value2.x && value.y > value2.y) {
        return value - value2;
    }
    return 0.;
}

float ovalShapeSoftEdges(float radius, float2 position) {
    float2 value = length(position - float2(0.5, 0.5));
    //step berekent of value groter of kleiner is dan radius (1 = groter, 0 = kleiner)
    bool isInCircle = step(radius, value) > 0.0 ? false : true;
    if (!isInCircle) {
        float antiAliasing = 400;
        return distance(radius, value) * antiAliasing; 
    }
}

//combination of circleShapeHardEdges & circleShapeGradient
float circleShapeSoftEdges(float radius, float2 position, float2 circleCenterPosition) {
    float2 p = float2(position.x, position.y);
    float comparedX = 1;
    float comparedY = 1;
    if (iResolution.x > iResolution.y) {
        comparedY = iResolution.y / iResolution.x;
    }
    else {
        comparedX = iResolution.x / iResolution.y;
    }
    // if (comparedY < comparedX) {
    //     p.x = p.x / comparedY; // - pixels to go to mid
    //     p.x = p.x;
    // }
    // else {
    //     p.y = p.y / comparedX;
    //     // p.y = p.y - 1/ddy(p.y);
    // }
    float2 value = length(p - circleCenterPosition);
    bool isInCircle = step(radius, value) > 0.0 ? false : true; //step == x radius >= value ? 1 : 0
    if (!isInCircle) {
        float antiAliasing = 400;
        return distance(radius, value) * antiAliasing; 
    }
    return 0;
}

float circleShapeGradient(float radius, float2 position, float2 circleCenter) {
    float2 value = length(position - circleCenter);
    return distance(radius, value); //gradient
}

float circleShapeHardEdges(float radius, float2 position, float2 circleCenterPosition) {
    // float2 circleCenterPosition = float2(0.5, 0.5);
    float2 value = distance(position, circleCenterPosition);
    //step berekent of value groter of kleiner is dan radius (1 = groter, 0 = kleiner)
    return step(radius, value);
}

float xWaves(in float2 uv: TEXCOORD0) {
    return pow(
        saturate(
            1.0 - abs(sin(uv.x * Scale + Offset.x) - (uv.y * Scale + Offset.y))
        ), (1.0 / Intensity));
}

float3 linesDrawer(float2 uv) {
    float angle = 0.1;
    float amount = 18; //more = more lines
    float width = 7;
    float antiAliasing = 2.5;
    return sin(amount * amount * (amount / width) * (uv.x + uv.y * angle)) * antiAliasing;
}

float4 TransparentTowardsEndGradientFunction(float4 color, float2 coords)
{
    float gradientStart = 3; // more = starts faster with gradient
    
    if (color.a)
    {
        float procent = 1-coords.y;
        color *= procent / gradientStart;
    }

    return color;
}


float squareSoftEdges(float radius, float2 position, float2 circleCenterPosition) {
    float2 value = length(position - circleCenterPosition)*1.01;
    //step: value < radius => 0.0 else 1.0
    bool isInCircle = step(radius, value) > 0.0 ? false : true;
    if (!isInCircle) {
        float antiAliasing = 400;
        return distance(radius, value) * antiAliasing; 
    }
}

float squareEdges(float radius, float2 position, float2 circleCenterPosition) {
    float2 value = distance(position, circleCenterPosition);
    return step(radius, value);
}
float subCalculateColor(float color1, float color2, float value) {
    return (color1*color2)*(value)/0.9;
    // return (color1*value)  * (color2*(1/(value))); //blue-ish
}
float4 calculateColor(float4 color1, float4 color2, float value) {
    return float4(
        subCalculateColor(color1.r, color2.r, value),
        subCalculateColor(color1.g, color2.g, value),
        subCalculateColor(color1.b, color2.b, value),
        value
    );
    
}
float4 CircleWithBorder(float2 coords, float2 circleCenterPosition, float4 insideColor, 
        	            float4 borderColor, float halfCircleWidth, float borderWidth, float comparedX, float comparedY)
{
    //0.245 borderwidth bij 0.49 circleWidth vult alles
    float circle = circleShapeSoftEdges(halfCircleWidth, coords, circleCenterPosition);
    if (circle == 0.0) {
        float comparedValue = 0;
        float circle2 = 0;
        circle2 = circleShapeSoftEdges((halfCircleWidth-borderWidth), coords, circleCenterPosition);
        // float circle4 = circleShapeSoftEdges((halfCircleWidth-borderWidth*comparedY), coords, circleCenterPosition);
        // float circle2 = (circle3 + circle4) / 2;
            if (circle2 <= 0.75) {
                //inside color
                return float4(insideColor.xyz, 1.0);
            }
            else if (circle2 <= 1.4) {
                return float4(insideColor.xyz / circle2, 1.0);
            }
            else if (circle2 <= 1.7) {
                return calculateColor(insideColor, borderColor, circle2);
            }
            return borderColor;
    }
    else {
        //outside anti-aliasing
        float tcircle = 1-circle;
        return float4(borderColor.xyz*tcircle, 1.0);
    }
}
float4 calculateColorForEdge(float borderRadius, float2 cursorPosition, float2 cc, float borderWidth, float4 color, float4 bgColor) {
    //bad one --> does not include corners
    float circle = circleShapeSoftEdges(borderRadius, cursorPosition, cc);
    if (circle == 0.) {
        return float4(0.2,0.3,0.1, 1.0); //inside circle (dark green)
    }
    else {
        if (circleShapeSoftEdges(borderRadius, float2(cursorPosition.x - borderWidth, cursorPosition.y), cc) == 0.
        || circleShapeSoftEdges(borderRadius, float2(cursorPosition.x + borderWidth, cursorPosition.y), cc) == 0.
        || circleShapeSoftEdges(borderRadius, float2(cursorPosition.x, cursorPosition.y - borderWidth), cc) == 0.
        || circleShapeSoftEdges(borderRadius, float2(cursorPosition.x, cursorPosition.y + borderWidth), cc) == 0.) {
            return float4(1.0, 1.0, 0.0, 1.0); //border (yellow)
        }
        else {
            return float4(0.75,0.75,0.75, 1.0); //outside circle (gray)
        }
    }
}


float4 SquareWithRoundEdges(float2 cursorPosition, float width, float height, float boxRounding, float4 color, float4 bgColor)
{
    float2 boxPosition = float2(0.5, 0.5);
    float2 valueX = length(cursorPosition.x - boxPosition.x);
    float2 valueY = length(cursorPosition.y - boxPosition.y);

    bool valid = step(width/2, valueX) == 1 ? false : true;
    if (valid) {
        valid = step(height/2, valueY) == 1 ? false : true;
    }
    if (valid) {
        bool alreadyOutsideBorder = false;
        //start border radius calculations
        float2 mn = min(valueY, valueX) / 2;
        float2 furthestPixel = float2(boxPosition.x - width / 2, boxPosition.y - height / 2);
        float2 cc = furthestPixel + boxRounding; //furthest pixel circle center
        if (cc.x > cursorPosition.x && cc.y > cursorPosition.y) {
            //topleft
            return calculateColorForEdge(boxRounding, cursorPosition, cc, boxRounding, color, bgColor);
        }
        else {
            furthestPixel = float2(boxPosition.x + width / 2, boxPosition.y - height / 2);
            if (furthestPixel.x < cursorPosition.x+boxRounding && furthestPixel.y+boxRounding > cursorPosition.y) {
                //topright
                cc = float2(furthestPixel.x - boxRounding, furthestPixel.y + boxRounding); //furthest pixel circle center
                return calculateColorForEdge(boxRounding, cursorPosition, cc, boxRounding, color, bgColor);
            }
            else {
                furthestPixel = float2(boxPosition.x + width / 2, boxPosition.y + height / 2);
                if (furthestPixel.x < cursorPosition.x+boxRounding && furthestPixel.y-boxRounding < cursorPosition.y) {
                    //bottomright
                    cc = float2(furthestPixel.x - boxRounding, furthestPixel.y - boxRounding); //furthest pixel circle center
                    return calculateColorForEdge(boxRounding, cursorPosition, cc, boxRounding, color, bgColor);
                }
                else {
                    furthestPixel = float2(boxPosition.x - width / 2, boxPosition.y + height / 2);
                    if (furthestPixel.x > cursorPosition.x-boxRounding && furthestPixel.y-boxRounding < cursorPosition.y) {
                        //bottomleft
                        cc = float2(furthestPixel.x + boxRounding, furthestPixel.y - boxRounding); //furthest pixel circle center
                        return calculateColorForEdge(boxRounding, cursorPosition, cc, boxRounding, color, bgColor);
                    }
                    else {
                        return color;
                    }
                }
            }
        }
    }
    else {
        return bgColor;
    }
}


float4 SquareWithBorder(float2 position, float width, float height, float borderWidth, float4 color, float4 borderColor)
{
    float2 center = float2(0.5, 0.5);
    float2 valueX = length(position.x - center.x);
    float2 valueY = length(position.y - center.y);

    bool valid = step(width/2-borderWidth, valueX) == 1 ? false : true;
    if (valid) {
        valid = step(height/2-borderWidth, valueY) == 1 ? false : true;
    }
    if (valid) {
        return color;
        // return float4(float3(1.0, 0.2, 0.1), 1.0); //inside color (red)
    }
    else {
        valid = step(width/2, valueX) == 0 ? false : true;
        if (!valid) {
            valid = step(height/2, valueY) == 0 ? false : true;
        }
        if (!valid) {//border
            return borderColor;
            // return float4(0.15,0.15,0.0, 1.0); 
        }
        else {//outside square
            return float4(0.7, 0.1, 1.0, 1.0); // (purple)
        }
    }
}
float4 SquareWithEqualBorder(float2 position, float width, float height, float borderWidth, float4 color, float4 borderColor, float comparedX, float comparedY)
{
    float2 center = float2(0.5, 0.5);
    float2 valueX = length(position.x - center.x);
    float2 valueY = length(position.y - center.y);

    bool valid = step(width/2-borderWidth*comparedX, valueX) == 1 ? false : true;
    if (valid) {
        valid = step(height/2-borderWidth*comparedY, valueY) == 1 ? false : true;
    }
    if (valid) {
        return color;
        // return float4(float3(1.0, 0.2, 0.1), 1.0); //inside color (red)
    }
    else {
        valid = step(width/2, valueX) == 0 ? false : true;
        if (!valid) {
            valid = step(height/2, valueY) == 0 ? false : true;
        }
        if (!valid) {//border
            return borderColor;
            // return float4(0.15,0.15,0.0, 1.0); 
        }
        else {//outside square
            return float4(0.7, 0.1, 1.0, 1.0); // (purple)
        }
    }
}
float4 SquareWithRoundEdgesAndBorderBACKUP(float2 cursorPosition, float width, 
float height, float boxRounding, 
float borderWidth, float4 color, float4 borderColor, float4 cornerColor, float4 bgColor)
{
    if (width < 0.2) {
        width = 0.2;
    }
    if (height < 0.2) {
        height = 0.2;
    }
    float2 boxPosition = float2(0.5, 0.5);
    float2 valueX = length(cursorPosition.x - boxPosition.x);
    float2 valueY = length(cursorPosition.y - boxPosition.y);

    float comparedX = 1;
    float comparedY = 1;
    if (iResolution.x > iResolution.y) {
        comparedY = iResolution.x / iResolution.y;
    }
    else {
        comparedX = iResolution.y / iResolution.x;
    }

    bool valid = step(width/2, valueX) == 1 ? false : true;
    if (valid) {
        valid = step(height/2, valueY) == 1 ? false : true;
    }
    if (valid) {
        float boxRoundingAdapter = 1;
        bool alreadyOutsideBorder = false;
        //start border radius calculations
        float2 furthestPixel = float2(boxPosition.x - width / 2, boxPosition.y - height / 2);
        float2 cc = furthestPixel + boxRounding; //furthest pixel circle center
        if (cc.x > cursorPosition.x && cc.y > cursorPosition.y) {
            //topleft
            return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth*max(comparedX, comparedY), comparedY, comparedX);
        }
        else {
            furthestPixel = float2(boxPosition.x + width / 2, boxPosition.y - height / 2);
            if (furthestPixel.x < cursorPosition.x+boxRounding && furthestPixel.y+boxRounding > cursorPosition.y) {
                //topright
                cc = float2(furthestPixel.x - boxRounding, furthestPixel.y + boxRounding); //furthest pixel circle center
                return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth*max(comparedX, comparedY), comparedY, comparedX);
            }
            else {
                furthestPixel = float2(boxPosition.x + width / 2, boxPosition.y + height / 2);
                if (furthestPixel.x < cursorPosition.x+boxRounding && furthestPixel.y-boxRounding < cursorPosition.y) {
                    //bottomright
                    cc = float2(furthestPixel.x - boxRounding, furthestPixel.y - boxRounding); //furthest pixel circle center
                    return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth*max(comparedX, comparedY), comparedY, comparedX);
                }
                else {
                    furthestPixel = float2(boxPosition.x - width / 2, boxPosition.y + height / 2);
                    if (furthestPixel.x > cursorPosition.x-boxRounding && furthestPixel.y-boxRounding < cursorPosition.y) {
                        //bottomleft
                        cc = float2(furthestPixel.x + boxRounding, furthestPixel.y - boxRounding); //furthest pixel circle center
                        return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth*max(comparedX, comparedY), comparedY, comparedX);
                    }
                    else {
                        //inside anyways
                        return SquareWithEqualBorder(cursorPosition, width, height, borderWidth, color, borderColor, comparedX, comparedY);
                    }
                }
            }
        }
    }
    else {
        return bgColor;
    }
}
float4 SquareWithRoundEdgesNEW(float2 cursorPosition, float width, 
float height, float boxRounding, 
float borderWidth, float4 color, float4 borderColor, float4 cornerColor, float4 bgColor)
{
    if (width < 0.2) {
        width = 0.2;
    }
    if (height < 0.2) {
        height = 0.2;
    }
    float2 boxPosition = float2(0.5, 0.5);
    float2 valueX = length(cursorPosition.x - boxPosition.x);
    float2 valueY = length(cursorPosition.y - boxPosition.y);

    float comparedX = 1;
    float comparedY = 1;
    if (iResolution.x > iResolution.y) {
        comparedY = iResolution.x / iResolution.y;
    }
    else {
        comparedX = iResolution.y / iResolution.x;
    }

    bool valid = step(width/2, valueX) == 1 ? false : true;
    if (valid) {
        valid = step(height/2, valueY) == 1 ? false : true;
    }
    if (valid) {
        float boxRoundingAdapter = 1;
        bool alreadyOutsideBorder = false;
        //start border radius calculations
        float2 furthestPixel = float2(boxPosition.x - width / 2, boxPosition.y - height / 2);
        float2 cc = float2(furthestPixel.x/comparedX + boxRounding, furthestPixel.y/comparedY + boxRounding); 
        if (cc.x > cursorPosition.x && cc.y > cursorPosition.y) {
            //topleft
            return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth*max(comparedX, comparedY), comparedY, comparedX);
        }
        else {
            furthestPixel = float2(boxPosition.x + width / 2, boxPosition.y - height / 2);
            if (furthestPixel.x < cursorPosition.x+boxRounding && furthestPixel.y+boxRounding > cursorPosition.y) {
                //topright
                cc = float2(furthestPixel.x/comparedX - boxRounding, furthestPixel.y/comparedY + boxRounding); //furthest pixel circle center
                return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth*max(comparedX, comparedY), comparedY, comparedX);
            }
            else {
                furthestPixel = float2(boxPosition.x + width / 2, boxPosition.y + height / 2);
                if (furthestPixel.x < cursorPosition.x+boxRounding && furthestPixel.y-boxRounding < cursorPosition.y) {
                    //bottomright
                    cc = float2(furthestPixel.x/comparedX - boxRounding, furthestPixel.y/comparedY - boxRounding); //furthest pixel circle center
                    return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth*max(comparedX, comparedY), comparedY, comparedX);
                }
                else {
                    furthestPixel = float2(boxPosition.x - width / 2, boxPosition.y + height / 2);
                    if (furthestPixel.x > (cursorPosition.x-boxRounding)/comparedX && (furthestPixel.y-boxRounding)/comparedY < cursorPosition.y) {
                        //bottomleft
                        cc = float2(furthestPixel.x*comparedX + boxRounding, furthestPixel.y*comparedY - boxRounding); //furthest pixel circle center
                        return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth*max(comparedX, comparedY), comparedY, comparedX);
                    }
                    else {
                        //inside anyways
                        return SquareWithEqualBorder(cursorPosition, width, height, borderWidth, color, borderColor, comparedX, comparedY);
                    }
                }
            }
        }
    }
    else {
        return bgColor;
    }
}

float4 roundedRectBACKUP(float2 UV, float Width, float Height, float Radius)
{
    Radius = max(min(min(abs(Radius * 2), abs(Width)), abs(Height)), 1e-5);
    float2 uv = abs(UV * 2 - 1) - float2(Width, Height) + Radius;
    float d = length(max(0, uv)) / Radius;
    return saturate((1 - d) / fwidth(d));
}

float4 roundedRect(float2 UV, float Width, float Height, float Radius)
{
    Radius = max(min(min(abs(Radius * 2), abs(Width)), abs(Height)), 1e-5);
    float2 uv = abs(UV * 2 - 1) - float2(Width, Height) + Radius;
    float d = length(max(0, uv)) / Radius;
    return saturate((1 - d) / fwidth(d));
}

float newCircle(in float2 _st, in float _radius, in float2 circleCenter){
    float2 dist = _st-circleCenter;
	return 1.-smoothstep(_radius-(_radius*0.01),
                         _radius+(_radius*0.01),
                         dot(dist,dist)*4.0);
}

float4 SquareWithRoundEdgesAndBorder(float2 cursorPosition, float width, 
float height, float boxRounding, 
float borderWidth, float4 color, float4 borderColor, float4 cornerColor, float4 bgColor)
{
    if (width < 0.2) {
        width = 0.2;
    }
    if (height < 0.2) {
        height = 0.2;
    }
    float2 boxPosition = float2(0.5, 0.5);
    float2 valueX = length(cursorPosition.x - boxPosition.x);
    float2 valueY = length(cursorPosition.y - boxPosition.y);

    float comparedX = 1;
    float comparedY = 1;
    
    if (iResolution.x > iResolution.y) {
        comparedY = iResolution.x / iResolution.y;
    }
    else {
        comparedX = iResolution.y / iResolution.x;
    }

    bool valid = step(width/2, valueX) == 1 ? false : true;
    if (valid) {
        valid = step(height/2, valueY) == 1 ? false : true;
    }
    if (valid) {
        float boxRoundingAdapter = 1;
        bool alreadyOutsideBorder = false;
        //start border radius calculations
        float2 furthestPixel = float2(boxPosition.x - width / 2, boxPosition.y - height / 2);
        float2 cc = float2((furthestPixel.x + boxRounding), (furthestPixel.y + boxRounding));
        if (cc.x > cursorPosition.x && cc.y > cursorPosition.y) {
            //topleft
            // return float4(0,0,1,1);
            return newCircle(cursorPosition, boxRounding/2.5, cc);
            // return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth, comparedY, comparedX);
        }
        // else if (cc.y < cursorPosition.y) {
        //     return float4(1,0,0,1);
        // }
        else {
            furthestPixel = float2(boxPosition.x + width / 2, boxPosition.y - height / 2);
            if (furthestPixel.x < cursorPosition.x+boxRounding && furthestPixel.y+boxRounding > cursorPosition.y) {
                //topright
                // return float4(0,0,1,1);
                cc = float2(furthestPixel.x - boxRounding, furthestPixel.y + boxRounding); //furthest pixel circle center
                return newCircle(cursorPosition, boxRounding/2.5, cc);
                // return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth, comparedY, comparedX);
            }
            else {
                furthestPixel = float2(boxPosition.x + width / 2, boxPosition.y + height / 2);
                if (furthestPixel.x < cursorPosition.x+boxRounding && furthestPixel.y-boxRounding < cursorPosition.y) {
                    //bottomright
                    // return float4(0,0,1,1);
                    cc = float2(furthestPixel.x - boxRounding, furthestPixel.y - boxRounding); //furthest pixel circle center
                    return newCircle(cursorPosition, boxRounding/2.5, cc);
                    // return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth, comparedY, comparedX);
                }
                else {
                    furthestPixel = float2(boxPosition.x - width / 2, boxPosition.y + height / 2);
                    if (furthestPixel.x > cursorPosition.x-boxRounding && furthestPixel.y-boxRounding < cursorPosition.y) {
                        //bottomleft
                        // return float4(0,0,1,1);
                        cc = float2(furthestPixel.x + boxRounding, furthestPixel.y - boxRounding); //furthest pixel circle center
                        return newCircle(cursorPosition, boxRounding/2.5, cc);
                        // return CircleWithBorder(cursorPosition, cc, color, cornerColor, boxRounding*boxRoundingAdapter, borderWidth, comparedY, comparedX);
                    }
                    else {
                        //inside anyways
                        return SquareWithEqualBorder(cursorPosition, width, height, borderWidth, color, borderColor, comparedX, comparedY);
                    }
                }
            }
        }
    }
    else {
        return bgColor;
    }
}

float4 Square(float2 position, float width, float height)
{
    float2 valueX = length(position.x - 0.5);
    float2 valueY = length(position.y - 0.5);

    bool valid = step(width/2, valueX) == 1 ? false : true;
    if (valid) {
        valid = step(height/2, valueY) == 1 ? false : true;
    }
    if (valid) {
        return float4(float3(0.5, 0.2, 0.1), 1.0);
    }
    else {
        return float4(float3(0.0, 0.2, 0.1), 1.0);
    }
}

float4 DumbSquare(float2 coords)
{
    float borderWidth = 0.9;
    float2 bottomLeft = step(float2(borderWidth, borderWidth), coords);
    float2 topRight = step(float2(borderWidth, borderWidth), coords);

    float float2ToFloat = (bottomLeft.x * bottomLeft.y) * (topRight.x * topRight.y);
    return float4(float3(float2ToFloat, float2ToFloat, float2ToFloat), 1.0);
}

float4 Circle(float2 coords, float2 circleCenterPosition, float circleWidth)
{
    float circle = circleShapeGradient(circleWidth, coords, circleCenterPosition);
    float3 color = float3(circle,circle,circle);
    return float4(color, 1.0);
}
float4 CircleWithBorderBad(float2 coords, float2 circleCenterPosition, float4 borderColor, float4 insideColor)
{
    float circleWidth = 0.3;
    float borderWidth = 5;
    float circle = circleShapeSoftEdges(circleWidth, coords, circleCenterPosition);
    float3 color = float3(circle,circle,circle);


    if (circle == 0.0) {
        // return float4(color, 1.0);
        float borderValue = getBorderValue(circle, coords, circleCenterPosition, circleWidth);
        if (borderValue == 0.) {
            insideColor = float4(insideColor.x, insideColor.y, insideColor.z, 1.0);
            return insideColor;
        }
        else {
            return float4(borderColor.x,borderColor.y,borderColor.z, circle);
        }
    }
    else {
        // return float4(color, 1.0);
        return float4(color.x*borderColor.x,color.y*borderColor.y,color.z*borderColor.z, circle);
    }
}
float4 CircleWithBorderClose(float2 coords, float2 circleCenterPosition, float4 borderColor, float4 insideColor)
{
    float circleWidth = 0.3;
    float borderWidth = 0.05;
    float circle = circleShapeSoftEdges(circleWidth, coords, circleCenterPosition);
    float3 color = float3(circle,circle,circle);


    if (circle == 0.0) {
        float circle2 = circleShapeSoftEdges(abs(circleWidth-borderWidth*2), coords, circleCenterPosition);
        float3 color2 = float3(circle2,circle2,circle2);
        return float4(color2.x*insideColor.x,color2.y*insideColor.y,color2.z*insideColor.z, 1.0);
    }
    else {
        return float4(color.xyz / borderColor.xyz, 1.0);
    }
}
float4 CircleWithCoolBorders(float2 coords, float2 circleCenterPosition, float4 borderColor, float4 insideColor)
{
    float circleWidth = 0.48;
    float borderWidth = 0.04; //0.245 borderwidth bij 0.49 circleWidth vult alles
    float circle = circleShapeSoftEdges(circleWidth, coords, circleCenterPosition);
    float3 color = float3(circle,circle,circle);


    if (circle == 0.0) {
        float circle2 = circleShapeSoftEdges(abs(circleWidth-borderWidth*2), coords, circleCenterPosition);
        if (circle2 == 0.0) {
            // return float4(insideColor.xyz / color2, 1.0);
            return float4( insideColor.xyz*1*circle2, 1.0);
        }
        else {
            return float4(borderColor.xyz*1/circle2, 1.0);
        }
    }
    else {
        return float4(borderColor.xyz * 1/circle, 1.0);
    }
}

float sdRoundBoxBACKUP( in float2 p, in float2 b, in float4 r ) 
{
    r.xy = (p.x>0.0)?r.xy : r.zw;
    r.x  = (p.y>0.0)?r.x  : r.y;
    float2 q = abs(p)-b+r.x;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}

float4 mainImageBACKUP( out float4 fragColor, in float2 fragCoord )
{
	// float2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    float2 p = fragCoord;
    float2 m = (2.0*iMouse.xy-iResolution.xy)/iResolution.y;

	float2 si = float2(0.9,0.6) + 0.3*cos(float2(0,2));
	// float2 si = float2(0.9,0.6) + 0.3*cos(iTime+float2(0,2));
    // float4 ra = 0.3 + 0.3*cos( 2.0*iTime + float4(0,1,2,3) );
    float4 ra = 0.3 + 0.3*cos( 2.0 + float4(0,1,2,3) );
    ra = min(ra,min(si.x,si.y));

	float d = sdRoundBoxBACKUP( p, si, ra );

    float3 col = (d>0.0) ? float3(0.9,0.6,0.3) : float3(0.65,0.85,1.0);
	col *= 1.0 - exp(-6.0*abs(d));
	col *= 0.8 + 0.2*cos(150.0*d);
	col = lerp( col, float3(1.0,1.0,1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );

    if( iMouse.z>0.001 )
    {
    d = sdRoundBoxBACKUP(m, si, ra );
    col = lerp(col, float3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, abs(length(p-m)-abs(d))-0.0025));
    col = lerp(col, float3(1.0,1.0,0.0), 1.0-smoothstep(0.0, 0.005, length(p-m)-0.015));
    }

	fragColor = float4(col,1.0);
    return fragColor;
}

float sdRoundBox( in float2 p, in float2 b, in float4 r )
{
    r.xy = (p.x>0.0)?r.xy : r.zw;
    r.x  = (p.y>0.0)?r.x  : r.y;
    float2 q = abs(p)-b+r.x;
    return min(max(q.x,q.y),0.0) + length(max(q,0.0)) - r.x;
}

float4 mainImage( out float4 fragColor, in float2 fragCoord )
{
	// float2 p = (2.0*fragCoord-iResolution.xy)/iResolution.y;
    // float2 p = fragCoord;
	float2 p = (1700.0*fragCoord-iResolution.xy)/iResolution.y;

	float2 si = float2(0.9,0.6) + 0.3*cos(float2(0,2));
	// float2 si = float2(0.9,0.6) + 0.3*cos(iTime+float2(0,2));
    // float4 ra = 0.3 + 0.3*cos( 2.0*iTime + float4(0,1,2,3) );
    float4 ra = 0.3 + 0.3*cos( 2.0 + float4(0,1,2,3) );
    ra = min(ra,min(si.x,si.y));

	float d = sdRoundBox( p, si, ra );

    float3 col = (d>0.0) ? float3(0.9,0.6,0.3) : float3(0.65,0.85,1.0);
	col *= 1.0 - exp(-6.0*abs(d));
	col *= 0.8 + 0.2*cos(150.0*d);
	col = lerp( col, float3(1.0,1.0,1.0), 1.0-smoothstep(0.0,0.01,abs(d)) );

	fragColor = float4(col,1.0);
    return fragColor;
}

float distanceCalculator(float2 p, float2 r) {
    float scale = getXYcomparison();
    return sqrt(pow(max(abs(p.x-r.x),0),2)/(iResolution.x > iResolution.y ? scale*scale : 1) + pow(max(abs(p.y-r.y),0),2)/(iResolution.y > iResolution.x ? scale*scale : 1));
}

float3 distanceFromInsideForBorder(in float2 uv, float4 insideRect, float2 center, float insideWidth, float insideHeight) {
    float scale = getXYcomparison();
        // if (iResolution.x > iResolution.y) {
        //     insideRect = float4(center.x - insideWidth*scale, insideRect.g, center.x + insideWidth*scale, insideRect.a);
        // }
        // else {
        //     // insideRect = float4(center.x - insideWidth/scale, insideRect.g, center.x + insideWidth/scale, insideRect.a);
        //     insideRect = float4(insideRect.r, center.y - insideHeight*scale, insideRect.b, center.y + insideHeight*scale);
        //     // insideRect = float4()
        // }
    //insideRect:
    //r = left x
    //g = top y
    //b = right x
    //a = bottom y

    if (uv.x < insideRect.r) {
        //left
        if (uv.y < insideRect.g) {
            //top left corner
            return float3(distanceCalculator(uv, float2(insideRect.r, insideRect.g)),2,0);
        }
        else if  (uv.y > insideRect.a) {
            //bottom left corner
            return float3(distanceCalculator(uv, float2(insideRect.r,insideRect.a)),2,3);
        }
        else {
            //left side
            return float3(insideRect.r - uv.x,iResolution.x > iResolution.y ? 1 : 0, -1);
        }
    }
    else if (uv.y < insideRect.g) {
        //top
        if (uv.x > insideRect.b) {
            //top right corner
            return float3(distanceCalculator(uv, float2(insideRect.b,insideRect.g)),2,1);
        }
        else {
            //top side
            return float3(insideRect.g - uv.y,iResolution.y > iResolution.x ? 1 : 0,-1);
        }
    }
    else if (uv.x > insideRect.b) {
        //right
        if (uv.y > insideRect.a) {
            //bottom right corner
            return float3(distanceCalculator(uv, float2(insideRect.b,insideRect.a)),2,2);
        }
        else {
            //right side
            return float3(uv.x - insideRect.b,iResolution.x > iResolution.y ? 1 : 0,-1);
        }
    }
    else if (uv.y >= insideRect.a) {
        //bottom
        //bottom left corner already calculated above
        return float3(uv.y - insideRect.a,iResolution.y > iResolution.x ? 1 : 0,-1);
    }
    else {
        //inside
        return 1.0;
    }
}

float antiAliasing(float3 dist, float2 uv, float2 circleCenter, float borderWidth) {
            if (dist.g == 2) {
                float antiAliasing = 0.15;
                antiAliasing = pow(antiAliasing,3);
                if (dist.r < borderWidth/2+antiAliasing) {
                    float2 value = length(uv - circleCenter);
                    float antiAliasing = 1;
                    return distance(borderWidth/2, value) * antiAliasing;
                }
            }
            return 0;
}

float2 getProcentualValueForPixels(float pixels) {
        //kleinste border moet de borderWidthPixels worden --> de andere zal hetzelfde worden
        //dus x-resolutie is kleiner dan y-resolutie --> y border gelijk stellen aan borderWidthPixels
        //y > x --> x border gelijk stellen aan borderWidthPixels
        return float2(pixels / iResolution.x, pixels / iResolution.y);
}

float4 betterRoundedRect(in float2 uv, float width, float height, float borderWidthPixels, float4 color, float4 borderColor, float4 bgColor, float maxSize) {
    float scale = getXYcomparison();
    float2 center = float2(0.5,0.5);
    float2 tempBorderWidth = getProcentualValueForPixels(borderWidthPixels);
    float borderWidth = 0;
    if (iResolution.x > iResolution.y) {
        borderWidth = tempBorderWidth.y;
    }
    else {
        borderWidth = tempBorderWidth.x;
    }
    float insideWidth = width/2 - borderWidth/2;
    float insideHeight = height/2 - borderWidth/2;
    float4 insideRect = float4(center.x - insideWidth, center.y - insideHeight, center.x + insideWidth, center.y + insideHeight);
    
    if (iResolution.y > iResolution.x) {
        float heightDiff = maxSize - (insideRect.a + (borderWidth/2)*scale);
        insideRect.g = insideRect.g - heightDiff;
        insideRect.a = insideRect.a + heightDiff;
    }
    else {
        float widthDiff = maxSize - (insideRect.b + (borderWidth/2)*scale);
        insideRect.r = insideRect.r - widthDiff;
        insideRect.b = insideRect.b + widthDiff;
    }
    
    if (uv.x > insideRect.r &&
        uv.y > insideRect.g &&
        uv.x < insideRect.b &&
        uv.y < insideRect.a 
    ) {
        return color; //inside
    }
    else {
        //possibly border or outside
        //insideRect:
        //r = left x
        //g = top y
        //b = right x
        //a = bottom y
        
        float3 distance = distanceFromInsideForBorder(uv, insideRect, center, insideWidth, insideHeight);
        bool isBorder = false;
        if (distance.g == 2) {
            if (distance.r < borderWidth/2) {
                isBorder = true;
            }
        }
        else if (distance.g == 1) {
            if (distance.r <= (borderWidth/2)*scale) {
                isBorder = true;
            }
        }
        else if (distance.r <= borderWidth/2) {
            isBorder = true;
        }
        if (isBorder) {
            return borderColor;
        }
        else {
            if (distance.b >= 0 && 
                uv.x >= insideRect.r - (borderWidth/2)*(iResolution.x > iResolution.y ? scale : 1) &&
                uv.x <= insideRect.b + (borderWidth/2)*(iResolution.x > iResolution.y ? scale : 1) &&
                uv.y >= insideRect.g - (borderWidth/2)*(iResolution.y > iResolution.x ? scale : 1) &&
                uv.y <= insideRect.a + (borderWidth/2)*(iResolution.y > iResolution.x ? scale : 1)) {
                //corner-->maybe antiAliasing required
                float2 corner = 0;
                if (distance.b == 1) {
                    corner = float2(insideRect.b,insideRect.g);
                }
                else if (distance.b == 2) {
                    corner = float2(insideRect.b,insideRect.a);
                }
                else if (distance.b == 3) {
                    corner = float2(insideRect.r,insideRect.a);
                }
                else {
                    corner = float2(insideRect.r,insideRect.g);
                }
                float dist = antiAliasing(distance, uv, corner, borderWidth);
                if (dist != 0) {
                    //de juiste pixels geselecteerd en dist berekend...
                    float value = 0;
                        if (distance.r <= 0.1255) {
                            value = 0.9;
                        }
                        else if (distance.r <= 0.127) {
                            value = 0.75;
                        }
                        else if (distance.r <= 0.1287) {
                            value = 0.35;
                        }
                        else if (distance.r <= 0.1288) {
                            value = 0.1;
                        }
                        else {
                            value = 0.0;
                        }
                        
                        // return 1*value;
                        return borderColor * value;
                }
            }
            return float4(bgColor.r,bgColor.g,bgColor.b,bgColor.a+1.1);
        }
    }
}

float4 betterRoundedRectWithBorder(in float2 uv, float width, float height, float borderWidthPixels, float4 color, float4 borderColor, float4 bgColor) {
    float scale = getXYcomparison();
    //<0.5 --> not good
    width = width/2 + 0.5;

    float2 borderWidth = getProcentualValueForPixels(borderWidthPixels);
    float scaledWidth = width-borderWidth.x;
    float scaledHeight = height-borderWidth.y;
    float4 value = betterRoundedRect(uv, scaledWidth, scaledHeight, borderWidthPixels, color, color, bgColor, width-(iResolution.x > iResolution.y ? borderWidth.x/2 : borderWidth.y/2));
    if (value.a > 1) {
        //buitenkant
        value = betterRoundedRect(uv, width, height, borderWidthPixels, borderColor, borderColor, bgColor, width);
        if (value.a > 1)
        {
            return 0;
        }
        return value;
    }
    else {
        //binnenkant
        return value;
    }
}
float4 TransparentGrayBackgroundFunction(in float2 uv)
{
    float value = 0.7;
    value = value * 0.2;
    return float4(value, value, value, 1);
}

float testCircle(in float2 uv, float widthInPixels)
{
    float width = widthInPixels / iResolution.x;
    float value = distanceCalculator(uv, iMouse.xy);
    if (value > width) {
        return 0;
    }
    else {
        return width - value;
    }
}

float4 mouse(in float2 uv, in float2 circleCenter) {
    float value = testCircle(uv, 100);
    if (value > 0)
    {
        return float4(1, 0, 0, 1);
    }
    else
    {
        return float4(0, 1, 0, 1);

    }
}

float4 main(in float2 uv: TEXCOORD0): SV_TARGET
{
    float borderWidthPixels = 10;
    float borderWidth = 1;
    float borderRadius = 1;
    float2 circleCenter = float2(0.15,0.15);

    float4 color = float4(0.4,0.5,1, 1.0);
    float4 borderColor = float4(0.21,1,0.5, 1.0);
    float4 cornerColor = float4(0.2,0.5,1, 1.0);
    float4 bgColor = float4(0,0,0, 1.0);
    float width = 1;
    float height = 1;
    float comparedX = 1;
    float comparedY = 1;
    if (iResolution.x > iResolution.y) {
        comparedY = iResolution.x / iResolution.y;
    }
    else {
        comparedX = iResolution.y / iResolution.x;
    }

    // uv.x += sin(iTime * TimeSpeed);
    // return uv.x;
    return mouse(uv, iMouse.xy);
    // if (uv.x > 0) {
    //     uv.x *= 1.2;
    // }
    // else {
    //     uv.x = 0.2;
    // }
    // return mouseCircle(uv, float2(0.5, 0.5));
    // return newCircle(uv, borderRadius, circleCenter);

    // float x = xWaves(uv);
    // return float4(0, x, 0, 1);
    // return float4(1.0, 0.6, 0.9, 1.0);

    //lines
    // float3 color = linesDrawer(uv);
    // color.x = 0.63;
    // return TransparentTowardsEndGradientFunction(float4(color, 1.0), uv);

    // float value = 3 * cos((PI/3)*iTime/15-PI/3)+2.5;
    // return value;
    // return TransparentGrayBackgroundFunction(uv) * value;

    // return betterRoundedRectWithBorder(uv, width, height, borderWidthPixels, color, borderColor, bgColor);
    // return betterRoundedRect(uv, width, height, borderWidthPixels, color, borderColor, bgColor, 1);
    // return mainImage(borderColor,uv);

    //square
    // return SquareWithRoundEdges(uv, 0.5, 0.5, 0.1, color, bgColor);
    // return SquareWithRoundEdgesAndBorder(uv, 0.9,0.9, borderRadius, borderWidth, color, borderColor, borderColor, bgColor);
    // return SquareWithRoundEdgesAndBorderBACKUP(uv, 0.9,0.9, borderRadius, borderWidth, color, borderColor, borderColor, bgColor);
    // return SquareWithRoundEdgesNEW(uv, 0.9,0.9, borderRadius, borderWidth, color, borderColor, borderColor, bgColor);
    // return SquareWithBorder(uv, 0.5,0.5, 0.01);
    // return DumbSquare(uv);

    //circle
    // return newCircle(uv, borderRadius, circleCenter);
    // return Circle(uv, float2(0.5, 0.5));
    // return CircleWithBorder(uv, float2(0.5, 0.5), color, borderColor, borderRadius, borderWidth, comparedX,comparedY);

    // return float4(0.1, 0.1, 0.2, 1.0);
}

