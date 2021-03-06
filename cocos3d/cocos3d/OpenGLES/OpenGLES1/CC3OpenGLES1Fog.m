/*
 * CC3OpenGLES1Fog.m
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
 * See header file CC3OpenGLESHints.h for full API documentation.
 */

#import "CC3OpenGLES1Fog.h"

#if CC3_OGLES_1

#pragma mark -
#pragma mark CC3OpenGLES1StateTrackerFogColor

@implementation CC3OpenGLES1StateTrackerFogColor

-(void) setGLValue { glFogfv(name, (GLfloat*)&value); }

+(CC3GLESStateOriginalValueHandling) defaultOriginalValueHandling {
	return kCC3GLESStateOriginalValueReadOnceAndRestore;
}

@end


#pragma mark -
#pragma mark CC3OpenGLES1StateTrackerFogFloat

@implementation CC3OpenGLES1StateTrackerFogFloat

-(void) setGLValue { glFogf(name, value); }

+(CC3GLESStateOriginalValueHandling) defaultOriginalValueHandling {
	return kCC3GLESStateOriginalValueReadOnceAndRestore;
}

@end


#pragma mark -
#pragma mark CC3OpenGLES1StateTrackerFogEnumeration

@implementation CC3OpenGLES1StateTrackerFogEnumeration

-(void) setGLValue { glFogx(name, value); }

+(CC3GLESStateOriginalValueHandling) defaultOriginalValueHandling {
	return kCC3GLESStateOriginalValueReadOnceAndRestore;
}

@end


#pragma mark -
#pragma mark CC3OpenGLES1Fog

@implementation CC3OpenGLES1Fog

-(void) initializeTrackers {
	self.color = [CC3OpenGLES1StateTrackerFogColor trackerWithParent: self
															forState: GL_FOG_COLOR];
	self.mode = [CC3OpenGLES1StateTrackerFogEnumeration trackerWithParent: self
																 forState: GL_FOG_MODE];
	self.density = [CC3OpenGLES1StateTrackerFogFloat trackerWithParent: self
															  forState: GL_FOG_DENSITY];
	self.start = [CC3OpenGLES1StateTrackerFogFloat trackerWithParent: self
															forState: GL_FOG_START];
	self.end = [CC3OpenGLES1StateTrackerFogFloat trackerWithParent: self
														  forState: GL_FOG_END];
}

@end

#endif