/*
 * CC3PVRShamanGLProgramSemantics.m
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2010-2013 The Brenwill Workshop Ltd. All rights reserved.
 * http://www.brenwill.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * http://en.wikipedia.org/wiki/MIT_License
 * 
 * See header file CC3PVRShamanGLProgramSemantics.h for full API documentation.
 */

#import "CC3PVRShamanGLProgramSemantics.h"
#import "CC3Light.h"
#import "CC3Scene.h"
#import "CC3OpenGLESEngine.h"


NSString* NSStringFromCC3PVRShamanSemantic(CC3PVRShamanSemantic semantic) {
	switch (semantic) {
		case kCC3PVRShamanSemanticNone: return @"kCC3PVRShamanSemanticNone";
			
		case kCC3PVRShamanSemanticLightSpotFalloff: return @"kCC3PVRShamanSemanticLightSpotFalloff";
		case kCC3PVRShamanSemanticViewportSize: return @"kCC3PVRShamanSemanticViewportSize";
		case kCC3PVRShamanSemanticViewportClipping: return @"kCC3PVRShamanSemanticViewportClipping";
		case kCC3PVRShamanSemanticElapsedTimeLastFrame: return @"kCC3PVRShamanSemanticElapsedTimeLastFrame";
			
		case kCC3PVRShamanSemanticAppBase: return @"kCC3PVRShamanSemanticAppBase";
		default: return [NSString stringWithFormat: @"Unknown PVRShaman semantic (%u)", semantic];
	}
}


#pragma mark -
#pragma mark CC3PVRShamanGLProgramSemantics

@implementation CC3PVRShamanGLProgramSemantics

-(GLenum) semanticForPFXSemanticName: (NSString*) semanticName {
	return [self.class semanticForPVRShamanSemanticName: semanticName];
}

/** Handles populating PVRShaman-specific content and delegates remainder to the standard population mechanisms.  */
-(BOOL) populateUniform: (CC3GLSLUniform*) uniform withVisitor: (CC3NodeDrawingVisitor*) visitor {
	LogTrace(@"%@ retrieving semantic value for %@", self, uniform.fullDescription);
	CC3OpenGLESEngine* glesEngine = CC3OpenGLESEngine.engine;
	CC3OpenGLESLight* glesLight;
	GLenum semantic = uniform.semantic;
	GLuint semanticIndex = uniform.semanticIndex;
	GLint uniformSize = uniform.size;
	CC3Viewport vp;

	if ( [super populateUniform: uniform withVisitor: visitor] ) return YES;
	
	switch (semantic) {

		// Sets a vec2, specific to PVRShaman, that combines the falloff angle (in degrees) and exponent
		case kCC3PVRShamanSemanticLightSpotFalloff:
			for (GLuint i = 0; i < uniformSize; i++) {
				glesLight = [glesEngine.lighting lightAt: (semanticIndex + i)];
				if (glesLight.isEnabled)
					[uniform setPoint: ccp(glesLight.spotCutoffAngle.value,
										   glesLight.spotExponent.value)
								   at: i];
			}
			return YES;
		case kCC3PVRShamanSemanticElapsedTimeLastFrame:
			// Time of last frame. Just subtract frame time from current time
			[uniform setFloat: (CCDirector.sharedDirector.displayLinkTime - visitor.deltaTime)];
			return YES;
		case kCC3PVRShamanSemanticViewportSize:
			vp = visitor.scene.viewportManager.viewport;
			[uniform setPoint: ccp(vp.w, vp.h)];
			return YES;
		case kCC3PVRShamanSemanticViewportClipping:
			// Applies the field of view angle to the narrower aspect.
			vp = visitor.scene.viewportManager.viewport;
			GLfloat aspect = (GLfloat) vp.w / (GLfloat) vp.h;
			CC3Camera* cam = visitor.camera;
			GLfloat fovWidth, fovHeight;
			if (aspect >= 1.0f) {			// Landscape
				fovHeight = DegreesToRadians(cam.effectiveFieldOfView);
				fovWidth = fovHeight * aspect;
			} else {						// Portrait
				fovWidth = DegreesToRadians(cam.effectiveFieldOfView);
				fovHeight = fovWidth / aspect;
			}
			[uniform setVector4: CC3Vector4Make(cam.nearClippingDistance, cam.farClippingDistance, fovWidth, fovHeight)];
			return YES;
			
		default: return NO;
	}
}



#pragma mark Mapping between PVRShaman semantics and cocos3d semantics

static NSMutableDictionary* _semanticsByPVRShamanSemanticName = nil;

+(GLenum) semanticForPVRShamanSemanticName: (NSString*) semanticName {
	[self ensurePVRShamanSemanticMap];
	NSNumber* semNum = [_semanticsByPVRShamanSemanticName objectForKey: semanticName];
	return semNum ? semNum.unsignedIntValue : kCC3SemanticNone;
}

+(void) addSemantic: (GLenum) semantic forPVRShamanSemanticName: (NSString*) semanticName {
	[self ensurePVRShamanSemanticMap];
	[_semanticsByPVRShamanSemanticName setObject: [NSNumber numberWithUnsignedInt: semantic]
										  forKey: semanticName];
}

+(void) ensurePVRShamanSemanticMap {
	if (_semanticsByPVRShamanSemanticName) return;

	_semanticsByPVRShamanSemanticName = [NSMutableDictionary new];		// retained
	
	[self addSemantic: kCC3SemanticVertexLocation forPVRShamanSemanticName: @"POSITION"];
	[self addSemantic: kCC3SemanticVertexNormal forPVRShamanSemanticName: @"NORMAL"];
	[self addSemantic: kCC3SemanticVertexTangent forPVRShamanSemanticName: @"TANGENT"];
	[self addSemantic: kCC3SemanticVertexBitangent forPVRShamanSemanticName: @"BINORMAL"];
	[self addSemantic: kCC3SemanticVertexTexture forPVRShamanSemanticName: @"UV"];
	[self addSemantic: kCC3SemanticVertexColor forPVRShamanSemanticName: @"VERTEXCOLOR"];
	[self addSemantic: kCC3SemanticVertexMatrixIndices forPVRShamanSemanticName: @"BONEINDEX"];
	[self addSemantic: kCC3SemanticVertexWeights forPVRShamanSemanticName: @"BONEWEIGHT"];

	[self addSemantic: kCC3SemanticModelMatrix forPVRShamanSemanticName: @"WORLD"];
	[self addSemantic: kCC3SemanticModelMatrixInv forPVRShamanSemanticName: @"WORLDI"];
	[self addSemantic: kCC3SemanticModelMatrixInvTran forPVRShamanSemanticName: @"WORLDIT"];
	
	[self addSemantic: kCC3SemanticViewMatrix forPVRShamanSemanticName: @"VIEW"];
	[self addSemantic: kCC3SemanticViewMatrixInv forPVRShamanSemanticName: @"VIEWI"];
	[self addSemantic: kCC3SemanticViewMatrixInvTran forPVRShamanSemanticName: @"VIEWIT"];
	
	[self addSemantic: kCC3SemanticProjMatrix forPVRShamanSemanticName: @"PROJECTION"];
	[self addSemantic: kCC3SemanticProjMatrixInv forPVRShamanSemanticName: @"PROJECTIONI"];
	[self addSemantic: kCC3SemanticProjMatrixInvTran forPVRShamanSemanticName: @"PROJECTIONIT"];
	
	[self addSemantic: kCC3SemanticModelViewMatrix forPVRShamanSemanticName: @"WORLDVIEW"];
	[self addSemantic: kCC3SemanticModelViewMatrixInv forPVRShamanSemanticName: @"WORLDVIEWI"];
	[self addSemantic: kCC3SemanticModelViewMatrixInvTran forPVRShamanSemanticName: @"WORLDVIEWIT"];
	
	[self addSemantic: kCC3SemanticModelViewProjMatrix forPVRShamanSemanticName: @"WORLDVIEWPROJECTION"];
	[self addSemantic: kCC3SemanticModelViewProjMatrixInv forPVRShamanSemanticName: @"WORLDVIEWPROJECTIONI"];
	[self addSemantic: kCC3SemanticModelViewProjMatrixInvTran forPVRShamanSemanticName: @"WORLDVIEWPROJECTIONIT"];
	
	[self addSemantic: kCC3SemanticViewProjMatrix forPVRShamanSemanticName: @"VIEWPROJECTION"];
	[self addSemantic: kCC3SemanticViewProjMatrixInv forPVRShamanSemanticName: @"VIEWPROJECTIONI"];
	[self addSemantic: kCC3SemanticViewProjMatrixInvTran forPVRShamanSemanticName: @"VIEWPROJECTIONIT"];
	
	[self addSemantic: kCC3SemanticModelLocalMatrix forPVRShamanSemanticName: @"OBJECT"];
	[self addSemantic: kCC3SemanticModelLocalMatrixInv forPVRShamanSemanticName: @"OBJECTI"];
	[self addSemantic: kCC3SemanticModelLocalMatrixInvTran forPVRShamanSemanticName: @"OBJECTIT"];
	
	[self addSemantic: kCC3SemanticNone forPVRShamanSemanticName: @"UNPACKMATRIX"];
	
	[self addSemantic: kCC3SemanticMaterialOpacity forPVRShamanSemanticName: @"MATERIALOPACITY"];
	[self addSemantic: kCC3SemanticMaterialShininess forPVRShamanSemanticName: @"MATERIALSHININESS"];
	[self addSemantic: kCC3SemanticMaterialColorAmbient forPVRShamanSemanticName: @"MATERIALCOLORAMBIENT"];
	[self addSemantic: kCC3SemanticMaterialColorDiffuse forPVRShamanSemanticName: @"MATERIALCOLORDIFFUSE"];
	[self addSemantic: kCC3SemanticMaterialColorSpecular forPVRShamanSemanticName: @"MATERIALCOLORSPECULAR"];
	
	[self addSemantic: kCC3SemanticBonesPerVertex forPVRShamanSemanticName: @"BONECOUNT"];
	[self addSemantic: kCC3SemanticBoneMatrices forPVRShamanSemanticName: @"BONEMATRIXARRAY"];
	[self addSemantic: kCC3SemanticBoneMatricesInvTran forPVRShamanSemanticName: @"BONEMATRIXARRAYIT"];
	
	[self addSemantic: kCC3SemanticLightColorDiffuse forPVRShamanSemanticName: @"LIGHTCOLOR"];
	[self addSemantic: kCC3SemanticLightLocationModelSpace forPVRShamanSemanticName: @"LIGHTPOSMODEL"];
	[self addSemantic: kCC3SemanticLightLocationGlobal forPVRShamanSemanticName: @"LIGHTPOSWORLD"];
	[self addSemantic: kCC3SemanticLightLocationEyeSpace forPVRShamanSemanticName: @"LIGHTPOSEYE"];
	[self addSemantic: kCC3SemanticLightLocationModelSpace forPVRShamanSemanticName: @"LIGHTDIRMODEL"];
	[self addSemantic: kCC3SemanticLightLocationGlobal forPVRShamanSemanticName: @"LIGHTDIRWORLD"];
	[self addSemantic: kCC3SemanticLightLocationEyeSpace forPVRShamanSemanticName: @"LIGHTDIREYE"];
	[self addSemantic: kCC3SemanticLightAttenuation forPVRShamanSemanticName: @"LIGHTATTENUATION"];
	[self addSemantic: kCC3PVRShamanSemanticLightSpotFalloff forPVRShamanSemanticName: @"LIGHTFALLOFF"];

	[self addSemantic: kCC3SemanticCameraLocationModelSpace forPVRShamanSemanticName: @"EYEPOSMODEL"];
	[self addSemantic: kCC3SemanticCameraLocationGlobal forPVRShamanSemanticName: @"EYEPOSWORLD"];

	[self addSemantic: kCC3SemanticTextureSampler forPVRShamanSemanticName: @"TEXTURE"];
	[self addSemantic: kCC3SemanticAnimationFraction forPVRShamanSemanticName: @"ANIMATION"];
	
	[self addSemantic: kCC3SemanticDrawCountCurrentFrame forPVRShamanSemanticName: @"GEOMENTRYCOUNTER"];
	[self addSemantic: kCC3PVRShamanSemanticViewportSize forPVRShamanSemanticName: @"VIEWPORTPIXELSIZE"];
	[self addSemantic: kCC3PVRShamanSemanticViewportClipping forPVRShamanSemanticName: @"VIEWPORTCLIPPING"];
	
	[self addSemantic: kCC3SemanticApplicationTime forPVRShamanSemanticName: @"TIME"];
	[self addSemantic: kCC3SemanticApplicationTimeCosine forPVRShamanSemanticName: @"TIMECOS"];
	[self addSemantic: kCC3SemanticApplicationTimeSine forPVRShamanSemanticName: @"TIMESIN"];
	[self addSemantic: kCC3SemanticApplicationTimeTangent forPVRShamanSemanticName: @"TIMETAN"];

	[self addSemantic: kCC3SemanticApplicationTime forPVRShamanSemanticName: @"TIME2PI"];
	[self addSemantic: kCC3SemanticApplicationTimeCosine forPVRShamanSemanticName: @"TIME2PICOS"];
	[self addSemantic: kCC3SemanticApplicationTimeSine forPVRShamanSemanticName: @"TIME2PISIN"];
	[self addSemantic: kCC3SemanticApplicationTimeTangent forPVRShamanSemanticName: @"TIME2PITAN"];

	[self addSemantic: kCC3PVRShamanSemanticElapsedTimeLastFrame forPVRShamanSemanticName: @"LASTTIME"];
	[self addSemantic: kCC3SemanticFrameTime forPVRShamanSemanticName: @"ELAPSEDTIME"];

	[self addSemantic: kCC3SemanticCenterOfGeometry forPVRShamanSemanticName: @"BOUNDINGCENTER"];
	[self addSemantic: kCC3SemanticBoundingRadius forPVRShamanSemanticName: @"BOUNDINGSPHERERADIUS"];
	[self addSemantic: kCC3SemanticBoundingBoxSize forPVRShamanSemanticName: @"BOUNDINGBOXSIZE"];
	[self addSemantic: kCC3SemanticBoundingBoxMin forPVRShamanSemanticName: @"BOUNDINGBOXMIN"];
	[self addSemantic: kCC3SemanticBoundingBoxMax forPVRShamanSemanticName: @"BOUNDINGBOXMAX"];

	[self addSemantic: kCC3SemanticRandomNumber forPVRShamanSemanticName: @"RANDOM"];
}

@end


