/*
 * CC3GLProgram.m
 *
 * cocos3d 2.0.0
 * Author: Bill Hollings
 * Copyright (c) 2011-2013 The Brenwill Workshop Ltd. All rights reserved.
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
 * See header file CC3GLProgram.h for full API documentation.
 */

#import "CC3GLProgram.h"
#import "CC3GLProgramContext.h"
#import "CC3GLProgramMatchers.h"
#import "CC3OpenGLESEngine.h"


#pragma mark -
#pragma mark CC3GLProgram

@interface CC3OpenGLESShaders (TemplateMethods)
-(void) setActiveProgram: (CC3GLProgram*) aProgram;
@end

@implementation CC3GLProgram

@synthesize programID=_programID;
@synthesize semanticDelegate=_semanticDelegate;
@synthesize maxUniformNameLength=_maxUniformNameLength;
@synthesize maxAttributeNameLength=_maxAttributeNameLength;

-(void) dealloc {
	[self deleteGLProgram];
	[_uniforms release];
	[_attributes release];
	[super dealloc];
}


#pragma mark Variables

-(CC3GLSLUniform*) uniformNamed: (NSString*) varName {
	for (CC3GLSLUniform* var in _uniforms) if ( [var.name isEqualToString: varName] ) return var;
	return nil;
}

-(CC3GLSLUniform*) uniformAtLocation: (GLint) uniformLocation {
	for (CC3GLSLUniform* var in _uniforms) if (var.location == uniformLocation) return var;
	return nil;
}

-(CC3GLSLUniform*) uniformForSemantic: (GLenum) semantic {
	return [self uniformForSemantic: semantic at: 0];
}

-(CC3GLSLUniform*) uniformForSemantic: (GLenum) semantic at: (GLuint) semanticIndex {
	for (CC3GLSLUniform* var in _uniforms)
		if (var.semantic == semantic && var.semanticIndex == semanticIndex) return var;
	return nil;
}

-(CC3GLSLAttribute*) attributeNamed: (NSString*) varName {
	for (CC3GLSLAttribute* var in _attributes) if ( [var.name isEqualToString: varName] ) return var;
	return nil;
}

-(CC3GLSLAttribute*) attributeAtLocation: (GLint) attrLocation {
	for (CC3GLSLAttribute* var in _attributes) if (var.location == attrLocation) return var;
	return nil;
}

-(CC3GLSLAttribute*) attributeForSemantic: (GLenum) semantic {
	return [self attributeForSemantic: semantic at: 0];
}

-(CC3GLSLAttribute*) attributeForSemantic: (GLenum) semantic at: (GLuint) semanticIndex {
	for (CC3GLSLAttribute* var in _attributes)
		if (var.semantic == semantic && var.semanticIndex == semanticIndex) return var;
	return nil;
}

#if CC3_OGLES_2

#pragma mark Compiling and linking

/**
 * Compiles and links the underlying GL program from the specified vertex and fragment
 * shader GLSL source code.
 */
-(void) compileAndLinkVertexShaderBytes: (const GLchar*) vshBytes
				 andFragmentShaderBytes: (const GLchar*) fshBytes {
	CC3Assert( !_programID, @"%@ already compliled and linked.", self);

	_programID = glCreateProgram();
	LogGLErrorTrace(@"while creating GL program in %@", self);

	[self compileShader: GL_VERTEX_SHADER fromBytes: vshBytes];
	[self compileShader: GL_FRAGMENT_SHADER fromBytes: fshBytes];
	
	[self link];
}

/** 
 * Compiles the specified shader type from the specified GLSL source code, and returns the
 * ID of the GL shader object.
 */
-(void) compileShader: (GLenum) shaderType fromBytes: (const GLchar*) source {
	CC3Assert(source, @"%@ cannot complile empty GLSL source.", self);
	
	MarkRezActivityStart();
	
    GLuint shaderID = glCreateShader(shaderType);
    glShaderSource(shaderID, 1, &source, NULL);
	LogGLErrorTrace(@"while specifying shader %@ source in %@", NSStringFromGLEnum(shaderType), self);
	
    glCompileShader(shaderID);
	LogGLErrorTrace(@"while compiling shader %@ in %@", NSStringFromGLEnum(shaderType), self);

	CC3Assert([self getWasCompiled: shaderID], @"%@ failed to compile shader %@ because:\n%@",
			  self, NSStringFromGLEnum(shaderType), [self getShaderLog: shaderID]);

	glAttachShader(_programID, shaderID);
	LogGLErrorTrace(@"while attaching shader %@ to GL program in %@", NSStringFromGLEnum(shaderType), self);

    glDeleteShader(shaderID);
	LogGLErrorTrace(@"while deleting shader %@ in %@", NSStringFromGLEnum(shaderType), self);
	
	LogRez(@"Compiled and attached %@ shader %@ in %.4f seconds", self, NSStringFromGLEnum(shaderType), GetRezActivityDuration());
}

/** Queries the GL engine and returns whether the shader with the specified GL ID was successfully compiled. */
-(BOOL) getWasCompiled: (GLuint) shaderID {
    GLint status;
    glGetShaderiv(shaderID, GL_COMPILE_STATUS, &status);
	LogGLErrorTrace(@"while retrieving shader compile status in %@", self);
	return (status > 0);
}

/** Links the compiled vertex and fragment shaders into the GL program. */
-(void) link {
	CC3Assert(_programID, @"%@ requires the shaders to be compiled before linking.", self);
	CC3Assert(_semanticDelegate, @"%@ requires the semanticDelegate property be set before linking.", self);

	MarkRezActivityStart();
	
    glLinkProgram(_programID);
	LogGLErrorTrace(@"while linking %@", self);
	
	CC3Assert(self.getWasLinked, @"%@ could not be linked because:\n%@", self, self.getProgramLog);

	LogRez(@"Linked %@ in %.4f seconds", self, GetRezActivityDuration());	// Timing before config vars

	[self configureUniforms];
	[self configureAttributes];

	LogRez(@"Completed %@", self.fullDescription);
}

/** Queries the GL engine and returns whether the program was successfully linked. */
-(BOOL) getWasLinked {
    GLint status;
    glGetProgramiv(_programID, GL_LINK_STATUS, &status);
	LogGLErrorTrace(@"while retrieving link status in %@", self);
	return (status > 0);
}

/** 
 * Extracts information about the program uniform variables from the GL engine
 * and creates a configuration instance for each.
 */
-(void) configureUniforms {
	MarkRezActivityStart();
	[_uniforms removeAllObjects];
	
	GLint varCnt;
	glGetProgramiv(_programID, GL_ACTIVE_UNIFORMS, &varCnt);
	LogGLErrorTrace(@"while retrieving number of active uniforms in %@", self);
	glGetProgramiv(_programID, GL_ACTIVE_UNIFORM_MAX_LENGTH, &_maxUniformNameLength);
	LogGLErrorTrace(@"while retrieving max uniform name length in %@", self);
	for (GLint varIdx = 0; varIdx < varCnt; varIdx++) {
		CC3GLSLUniform* var = [CC3OpenGLESStateTrackerGLSLUniform variableInProgram: self atIndex: varIdx];
		if ( [_semanticDelegate configureVariable: var] ) [_uniforms addObject: var];
		CC3Assert(var.location >= 0, @"%@ has an invalid location. Make sure the maximum number of program uniforms for this platform has not been exceeded.", var.fullDescription);
	}
	LogRez(@"%@ configured %u uniforms in %.4f seconds", self, varCnt, GetRezActivityDuration());
}

/**
 * Extracts information about the program vertex attribute variables from the GL engine
 * and creates a configuration instance for each.
 */
-(void) configureAttributes {
	MarkRezActivityStart();
	[_attributes removeAllObjects];
	
	GLint varCnt;
	glGetProgramiv(_programID, GL_ACTIVE_ATTRIBUTES, &varCnt);
	LogGLErrorTrace(@"while retrieving number of active attributes in %@", self);
	glGetProgramiv(_programID, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, &_maxAttributeNameLength);
	LogGLErrorTrace(@"while retrieving max attribute name length in %@", self);
	for (GLint varIdx = 0; varIdx < varCnt; varIdx++) {
		CC3GLSLAttribute* var = [CC3OpenGLESStateTrackerGLSLAttribute variableInProgram: self atIndex: varIdx];
		if ( [_semanticDelegate configureVariable: var] ) [_attributes addObject: var];
		CC3Assert(var.location >= 0, @"%@ has an invalid location. Make sure the maximum number of program attributes for this platform has not been exceeded.", var.fullDescription);
	}
	LogRez(@"%@ configured %u attributes in %.4f seconds", self, varCnt, GetRezActivityDuration());
}

// GL functions for retrieving log info
typedef void ( GLInfoFunction (GLuint program, GLenum pname, GLint* params) );
typedef void ( GLLogFunction (GLuint program, GLsizei bufsize, GLsizei* length, GLchar* infolog) );

/**
 * Returns a string retrieved from the specified object, using the specified functions
 * and length parameter name to retrieve the length and content.
 */
-(NSString*) getGLStringFor: (GLuint) glObjID
		usingLengthFunction: (GLInfoFunction*) lengthFunc
		 andLengthParameter: (GLenum) lenParamName
		 andContentFunction: (GLLogFunction*) contentFunc {
	GLint strLength = 0, charsRetrieved = 0;
	
	lengthFunc(glObjID, lenParamName, &strLength);
	LogGLErrorTrace(@"while retrieving GL string length in %@", self);
	if (strLength < 1) return nil;
	
	GLchar contentBytes[strLength];
	contentFunc(glObjID, strLength, &charsRetrieved, contentBytes);
	LogGLErrorTrace(@"while retrieving GL string content in %@", self);
	
	return [NSString stringWithUTF8String: contentBytes];
}

/** Returns the GL source for the specified shader. */
-(NSString*) getShaderSource: (GLuint) shaderID {
	return [self getGLStringFor: shaderID
			usingLengthFunction: glGetShaderiv
			 andLengthParameter: GL_SHADER_SOURCE_LENGTH
			 andContentFunction: glGetShaderSource];
}

/** Returns the GL log for the specified shader. */
-(NSString*) getShaderLog: (GLuint) shaderID {
	return [self getGLStringFor: shaderID
			usingLengthFunction: glGetShaderiv
			 andLengthParameter: GL_INFO_LOG_LENGTH
			 andContentFunction: glGetShaderInfoLog];
}

/** Returns the GL status log for the GL program. */
-(NSString*) getProgramLog {
	return [self getGLStringFor: _programID
			usingLengthFunction: glGetProgramiv
			 andLengthParameter: GL_INFO_LOG_LENGTH
			 andContentFunction: glGetProgramInfoLog];
}


#pragma mark Binding

// Cache this program in the GL state tracker, bind the program to the GL engine,
// and populate the uniforms into the GL engine, allowing the context to override first.
// Raise an assertion error if the uniform cannot be resolved by either context or delegate!
-(void) bindWithVisitor: (CC3NodeDrawingVisitor*) visitor fromContext: (CC3GLProgramContext*) context {
	LogTrace(@"Binding program %@ for %@", self, visitor.currentNode);
	CC3OpenGLESEngine.engine.shaders.activeProgram = self;
	
	ccGLUseProgram(_programID);

	for (CC3GLSLUniform* var in _uniforms)
		if ([context populateUniform: var withVisitor: visitor] ||
			[_semanticDelegate populateUniform: var withVisitor: visitor]) {
			[var updateGLValue];
		} else {
			CC3Assert(NO, @"%@ could not resolve the value of uniform %@ with semantic %@. Consider creating a uniform override on the program context in your material to set the value of the uniform directly.",
					  self, var.name, NSStringFromCC3Semantic(var.semantic));
		}
}

-(void) deleteGLProgram { if (_programID) ccGLDeleteProgram(_programID); }

#endif

#if CC3_OGLES_1
-(void) compileAndLinkVertexShaderBytes: (const GLchar*) vshBytes andFragmentShaderBytes: (const GLchar*) fshBytes {}
-(void) bindWithVisitor: (CC3NodeDrawingVisitor*) visitor fromContext: (CC3GLProgramContext*) context {}
-(void) deleteGLProgram {}
#endif


#pragma mark Allocation and initialization

-(id) initWithName: (NSString*) name
andSemanticDelegate: (id<CC3GLProgramSemanticsDelegate>) semanticDelegate
fromVertexShaderBytes: (const GLchar*) vshBytes
andFragmentShaderBytes: (const GLchar*) fshBytes {
	CC3Assert(name, @"%@ cannot be created without a name", [self class]);
	if ( (self = [super initWithName: name]) ) {
		_uniforms = [CCArray new];		// retained
		_attributes = [CCArray new];	// retained
		_maxUniformNameLength = 0;
		_maxAttributeNameLength = 0;
		_semanticDelegate = [semanticDelegate retain];
		[self compileAndLinkVertexShaderBytes: vshBytes andFragmentShaderBytes: fshBytes];
	}
	return self;
}

-(id) initWithName: (NSString*) name
andSemanticDelegate: (id<CC3GLProgramSemanticsDelegate>) semanticDelegate
fromVertexShaderFile: (NSString*) vshFilename
andFragmentShaderFile: (NSString*) fshFilename {
	LogRez(@"");
	LogRez(@"--------------------------------------------------");
	LogRez(@"Loading GLSL program named %@ from vertex shader file '%@' and fragment shader file '%@'", name, vshFilename, fshFilename);

	return [self initWithName: name
		  andSemanticDelegate: semanticDelegate
		fromVertexShaderBytes: [self.class glslSourceFromFile: vshFilename]
	   andFragmentShaderBytes: [self.class glslSourceFromFile: fshFilename]];
}

+(NSString*) programNameFromVertexShaderFile: (NSString*) vshFilename
					   andFragmentShaderFile: (NSString*) fshFilename {
	return [NSString stringWithFormat: @"%@-%@", vshFilename, fshFilename];
}

+(GLchar*) glslSourceFromFile: (NSString*) glslFilename {
	MarkRezActivityStart();
	NSError* err = nil;
	NSString* filePath = CC3EnsureAbsoluteFilePath(glslFilename);
	CC3Assert([[NSFileManager defaultManager] fileExistsAtPath: filePath],
			  @"Could not load GLSL file '%@' because it could not be found", filePath);
	NSString* glslSrcStr = [NSString stringWithContentsOfFile: filePath encoding: NSUTF8StringEncoding error: &err];
	CC3Assert(!err, @"Could not load GLSL file '%@' because %@, (code %i), failure reason %@",
			  glslFilename, err.localizedDescription, err.code, err.localizedFailureReason);
	LogRez(@"Loaded GLSL source from file %@ in %.4f seconds", glslFilename, GetRezActivityDuration());
	return (GLchar*)glslSrcStr.UTF8String;
}

-(NSString*) description { return [NSString stringWithFormat: @"%@ named: %@", [self class], self.name]; }

-(NSString*) fullDescription {
	NSMutableString* desc = [NSMutableString stringWithCapacity: 500];
	[desc appendFormat: @"%@ declaring %i attributes and %i uniforms:", self.description, _attributes.count, _uniforms.count];
	for (CC3GLSLVariable* var in _attributes) [desc appendFormat: @"\n\t %@", var.fullDescription];
	for (CC3GLSLVariable* var in _uniforms) [desc appendFormat: @"\n\t %@", var.fullDescription];
	return desc;
}


#pragma mark Tag allocation

static GLuint _lastAssignedProgramTag = 0;

-(GLuint) nextTag { return ++_lastAssignedProgramTag; }

+(void) resetTagAllocation { _lastAssignedProgramTag = 0; }


#pragma mark Program cache

static NSMutableDictionary* _programsByName = nil;

+(void) addProgram: (CC3GLProgram*) program {
	if ( !program ) return;
	CC3Assert( ![self getProgramNamed: program.name], @"%@ already contains a program named %@", self, program.name);
	if ( !_programsByName ) _programsByName = [NSMutableDictionary new];		// retained
	[_programsByName setObject: program forKey: program.name];
}

+(CC3GLProgram*) getProgramNamed: (NSString*) name { return [_programsByName objectForKey: name]; }

+(void) removeProgram: (CC3GLProgram*) program { [self removeProgramNamed: program.name]; }

+(void) removeProgramNamed: (NSString*) name { [_programsByName removeObjectForKey: name]; }


#pragma mark Program matching

static id<CC3GLProgramMatcher> _programMatcher = nil;

+(id<CC3GLProgramMatcher>) programMatcher {
	if ( !_programMatcher ) _programMatcher = [CC3GLProgramMatcherBase new];	// retained
	return _programMatcher;
}

+(void) setProgramMatcher: (id<CC3GLProgramMatcher>) programMatcher {
	id old = _programMatcher;
	_programMatcher = [programMatcher retain];
	[old release];
}

@end

