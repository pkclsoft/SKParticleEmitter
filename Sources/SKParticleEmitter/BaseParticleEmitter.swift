//
//  BaseParticleEmitter.swift
//  ParticleEmitterDemo-SK
//
//  Created by Peter Easdown on 27/3/21.
//  Copyright © 2021 71Squared Ltd. All rights reserved.
//
//  This Swift class is heavily based on the original ObjectiveC classes
//  available within the repository at:
//
// https://github.com/71squared/ParticleEmitterDemo-SK
//
// Rather than port the entire TBXML codebase, this class employes the XMLCoder package located at:
// https://github.com/MaxDesiatov/XMLCoder.git to parse the emitter configuration files.
//
// As a result of that, and some Swift eccentricities (or perhaps my lack of Swift expertise), this
// class makes use of a number of wrapper types for the emitter properties to make it simpler to
// use XMLCoder.  There _may_ be some performance penalties, but I've not seen any in my early tests.
//
import Foundation
import CoreGraphics
import SpriteKit
import Gzip
import XMLCoder

// Particle type enumeration.
enum ParticleTypes : Int {
    
    case particleTypeGravity
    case particleTypeRadial
    
}

// Structure used to hold particle specific information
struct Particle {
    var position                : Vector2 = .zero
    var direction               : Vector2 = .zero
    var startPos                : Vector2 = .zero
    var color                   : PEColor = .zero
    var deltaColor              : PEColor = .zero
    var rotation                : PEFloat = .init(0.0)
    var rotationDelta           : PEFloat = .init(0.0)
    var radialAcceleration      : PEFloat = .init(0.0)
    var tangentialAcceleration  : PEFloat = .init(0.0)
    var radius                  : PEFloat = .init(0.0)
    var radiusDelta             : PEFloat = .init(0.0)
    var angle                   : PEFloat = .init(0.0)
    var degreesPerSecond        : PEFloat = .init(0.0)
    var particleSize            : PEFloat = .init(0.0)
    var particleSizeDelta       : PEFloat = .init(0.0)
    var timeToLive              : PEFloat = .init(0.0)
}

/// This delegate is used by the BaseParticleEmitter to inform the visualisation of when to add a particle or remove it
/// from the screen.
protocol BaseParticleEmitterDelegate {
    
    /// Tell the delegate to add a particle to the screen.
    func addParticle()
    
    /// Tell the delegate to remove a particle from the screen.
    func removeParticle()
}

/// The particleEmitter allows you to define parameters that are used when generating particles.
/// These particles are SpriteKit particle sprites that based on the parameters provided each have
/// their own characteristics such as speed, lifespan, start and end colors etc.  Using these
/// particle emitters allows you to create organic looking effects such as smoke, fire and
/// explosions.
///
/// This class serves as the particle emitter engine, providing the math and management of particle
/// creation, animation and removal based on a specific set of parameters, typically loaded from a
/// configuration file (generated by ParticleDesigner from 71squared).
///
public class BaseParticleEmitter : Codable, DynamicNodeEncoding, DynamicNodeDecoding {
    
    /// Delegate; called whenever a particle is to be added or removed from the visualisation.
    ///
    var delegate : BaseParticleEmitterDelegate?
    
    /// Flags to enable/disable functionality
    private var updateParticlePositionAndRotation : Bool = true
    
    /// Particle vars
    var textureDetails : PETexture?
    var tiffData : Data?
    #if os(macOS)
    var image : NSImage?
    #else
    var image : UIImage?
    #endif
    var cgImage : CGImage?
    var emitterType : ParticleTypes = .particleTypeGravity
    var sourcePositionVariance : Vector2 = .zero
    var angle : PEFloat = .init(0.0)
    var angleVariance : PEFloat = .init(0.0)
    var speed : PEFloat = .init(0.0)
    var speedVariance : PEFloat = .init(0.0)
    var radialAcceleration : PEFloat = .init(0.0)
    var tangentialAcceleration : PEFloat = .init(0.0)
    var radialAccelVariance : PEFloat = .init(0.0)
    var tangentialAccelVariance : PEFloat = .init(0.0)
    var gravity : Vector2 = .zero
    var particleLifespan : PEFloat = .init(0.0)
    var particleLifespanVariance : PEFloat = .init(0.0)
    var startColor : PEColor = .zero
    var startColorVariance : PEColor = .zero
    var finishColor : PEColor = .zero
    var finishColorVariance : PEColor = .zero
    var startParticleSize : PEFloat = .init(0.0)
    var startParticleSizeVariance : PEFloat = .init(0.0)
    var finishParticleSize : PEFloat = .init(0.0)
    var finishParticleSizeVariance : PEFloat = .init(0.0)
    var maxParticles : PEInt = .init(0)
    var emissionRate : PEFloat = .init(0.0)
    var emitCounter : PEFloat = .init(0.0)
    var elapsedTime : PEFloat = .init(0.0)
    var rotationStart : PEFloat = .init(0.0)
    var rotationStartVariance : PEFloat = .init(0.0)
    var rotationEnd : PEFloat = .init(0.0)
    var rotationEndVariance : PEFloat = .init(0.0)
    var vertexArrayName : GLuint = 0
    var blendFuncSource : PEInt = PEInt(0)
    var blendFuncDestination : PEInt = PEInt(0)
    var opacityModifyRGB : Bool = false
    var premultiplied : Bool = false
    var hasAlpha : Bool = true
    
    /// Particle vars only used when a maxRadius value is provided.  These values are used for
    /// the special purpose of creating the spinning portal emitter
    var maxRadius : PEFloat  = .init(0.0)               /// Max radius at which particles are drawn when rotating
    var maxRadiusVariance : PEFloat = .init(0.0)        /// Variance of the maxRadius
    var radiusSpeed : PEFloat = .init(0.0)              /// The speed at which a particle moves from maxRadius to minRadius
    var minRadius : PEFloat = .init(0.0)                /// Radius from source below which a particle dies
    var rotatePerSecond : PEFloat = .init(0.0)          /// Number of degress to rotate a particle around the source pos per second
    var rotatePerSecondVariance : PEFloat = .init(0.0)  /// Variance in degrees for rotatePerSecond
    
    /// Particle Emitter Vars
    var active : Bool = false
    var vertexIndex : GLint = 0              /// Stores the index of the vertices being used for each particle
    
    /// Render
    var particles = Array<Particle>()         /// Array of particles that hold the particle emitters particle details
    
    public var sourcePosition : Vector2 = .zero
    var initialSourcePostion : Vector2 = .zero
    var particleCount : Int = 0
    var duration : PEFloat = .zero
    var spriteKitBlendMode : SKBlendMode = .add
    
    deinit {
        // Release the memory we are using for our vertex and particle arrays etc
        // If vertices or particles exist then free them
        self.particles.removeAll()
    }
    
    /// Loads an emitter from the named PEX file within the main bundle.
    /// - Parameters:
    ///   - withFile: the name of the PEX file describing the emitter.
    ///   - delegate: the delegate for the loaded emitter.
    /// - Returns: A loaded and configured emitter or nil if it can't be loaded..
    static func load(withFile: String, delegate: BaseParticleEmitterDelegate) throws -> BaseParticleEmitter? {
        return try load(withFile: withFile, fromBundle: Bundle.main, delegate: delegate)
    }
    
    /// Loads an emitter from the named PEX file within the specified bundle.
    /// - Parameters:
    ///   - withFile: the name of the PEX file describing the emitter.
    ///   - fromBundle: the bundle from which to load the file.
    ///   - delegate: the delegate for the loaded emitter.
    /// - Returns: A loaded and configured emitter or nil if it can't be loaded..
    static func load(withFile: String, fromBundle: Bundle, delegate: BaseParticleEmitterDelegate) throws -> BaseParticleEmitter? {
        if let fileURL = fromBundle.url(forResource: withFile, withExtension: "pex") {
            return try load(fromURL: fileURL, delegate: delegate)
        }
        
        return nil
    }
    
    /// Loads an emitter from the PEX file at the specified URL.
    /// - Parameters:
    ///   - fileURL: the URL of the emitter description file.
    ///   - delegate: the delegate for the loaded emitter.
    /// - Returns: A loaded and configured emitter .
    static func load(fromURL fileURL: URL, delegate: BaseParticleEmitterDelegate) throws -> BaseParticleEmitter {
        let data = try Data(contentsOf: fileURL)
        
        let decoder = XMLDecoder()
        
        let result = try decoder.decode(BaseParticleEmitter.self,from: data)
        
        result.delegate = delegate
        
        result.postParseInit()
        
        return result
    }
    
    func update(withDelta aDelta: PEFloat) {
        
        // If the emitter is active and the emission rate is greater than zero then emit particles
        if active && (emissionRate != 0) {
            let rate : PEFloat = 1.0 / emissionRate
            
            if (particleCount < maxParticles.int) {
                emitCounter += aDelta
            }
            
            while (particleCount < maxParticles.int && emitCounter > rate) {
                self.addParticle()
                
                emitCounter -= rate
            }
            
            elapsedTime += aDelta
            
            if (duration != -1.0 && duration < elapsedTime) {
                self.stopParticleEmitter()
            }
        }
        
        // Reset the particle index before updating the particles in this emitter
        var index : Int = 0;
        
        // Loop through all the particles updating their location and color
        while index < particleCount {
            
            // Get the particle for the current particle index
            // Reduce the life span of the particle
            particles[index].timeToLive -= aDelta
            
            // If the current particle is alive then update it
            if particles[index].timeToLive > 0.0 {
                
                self.updateParticle(atIndex : index, withDelta : aDelta)
                
                // Update the particle and vertex counters
                index += 1
            } else {
                
                // As the particle is not alive anymore replace it with the last active particle
                // in the array and reduce the count of particles by one.  This causes all active particles
                // to be packed together at the start of the array so that a particle which has run out of
                // life will only drop into this clause once
                self.removeParticle(atIndex : index)
            }
        }
    }
    
    func updateParticle(atIndex index : Int, withDelta delta : PEFloat) {
        
        // Get the particle for the current particle index
        var particle : Particle = particles[index]
        
        // If maxRadius is greater than 0 then the particles are going to spin otherwise they are effected by speed and gravity
        if emitterType == .particleTypeRadial {
            
            // FIX 2
            // Update the angle of the particle from the sourcePosition and the radius.  This is only done of the particles are rotating
            particle.angle += particle.degreesPerSecond * delta
            particle.radius -= particle.radiusDelta * delta
            
            particle.position = Vector2(sourcePosition.x - cosf(particle.angle.float) * particle.radius, sourcePosition.y - sinf(particle.angle.float) * particle.radius)
            
            if (particle.radius < minRadius) {
                particle.timeToLive.float = 0.0
            }
            
        } else {
            var tmp, radial, tangential : GLKVector2
            
            radial = GLKVector2Make(0.0, 0.0)
            
            // By default this emitters particles are moved relative to the emitter node position
            let positionDifference = particle.startPos - .zero
            particle.position = particle.position - positionDifference
            
            if particle.position.x != 0.0 || particle.position.y != 0.0 {
                radial = GLKVector2Normalize(particle.position.asGLVector2())
            }
            
            tangential = radial
            radial = GLKVector2MultiplyScalar(radial, particle.radialAcceleration.float)
            
            let newy = tangential.x
            tangential.x = -tangential.y
            tangential.y = newy
            tangential = GLKVector2MultiplyScalar(tangential, particle.tangentialAcceleration.float)
            
            tmp = GLKVector2Add( GLKVector2Add(radial, tangential), gravity.asGLVector2())
            tmp = GLKVector2MultiplyScalar(tmp, delta.float)
            particle.direction = particle.direction + Vector2(tmp)
            tmp = GLKVector2MultiplyScalar(particle.direction.asGLVector2(), delta.float)
            particle.position = particle.position + Vector2(tmp)
            
            // Now apply the difference calculated early causing the particles to be relative in position to the emitter position
            particle.position = particle.position + positionDifference
        }
        
        // Update the particles color
        particle.color += (particle.deltaColor * delta)
  
// This code was in the original ObjC code, but is not used.
//        var c: PEColor
//
//        if (opacityModifyRGB) {
//            c = PEColor(particle.color.r * particle.color.a,
//                        particle.color.g * particle.color.a,
//                        particle.color.b * particle.color.a,
//                        particle.color.a)
//        } else {
//            c = particle.color
//        }
        
        // Update the particle size
        particle.particleSize += particle.particleSizeDelta * delta
        particle.particleSize.float = max(0.0, particle.particleSize.float)
        
        // Update the rotation of the particle
        particle.rotation += particle.rotationDelta * delta
        
        particles[index] = particle
    }
    
    func removeParticle(atIndex index : Int) {
        if index != particleCount - 1 {
            particles[index] = particles[particleCount - 1]
        }
        
        particleCount -= 1
        
        delegate?.removeParticle()
    }
    
    func stopParticleEmitter() {
        active = false
        elapsedTime.float = 0.0
        emitCounter.float = 0.0
    }
    
    public func reset() {
        active = true
        elapsedTime.float = 0.0
        
        sourcePosition = self.initialSourcePostion

        for i in 0 ..< particleCount {
            particles[i].timeToLive.float = 0.0
            
            self.removeParticle(atIndex: i)
        }
        
        emitCounter.float = 0.0
        emissionRate = GLfloat(maxParticles.int) / particleLifespan
    }
    
    func addParticle() {
        
        // If we have already reached the maximum number of particles then do nothing
        if particleCount == maxParticles.int {
            return
        }
        
        // Take the next particle out of the particle pool we have created and initialize it
        self.initParticle(particle: &particles[particleCount])
        
        // Increment the particle count
        particleCount += 1

        // tell the delegate to add it's corresponding visualisation.
        self.delegate?.addParticle()
    }
    
    func randomMinus1To1() -> GLfloat {
        return (GLfloat(arc4random()) / GLfloat(UINT32_MAX / 2)) - 1.0
    }
    
    func initParticle(particle : inout Particle) {
        
        // Init the position of the particle.  This is based on the source position of the particle emitter
        // plus a configured variance.  The RANDOM_MINUS_1_TO_1 macro allows the number to be both positive
        // and negative
        particle.position.x = sourcePosition.x + sourcePositionVariance.x * randomMinus1To1()
        particle.position.y = sourcePosition.y + sourcePositionVariance.y * randomMinus1To1()
        particle.startPos.x = sourcePosition.x
        particle.startPos.y = sourcePosition.y
        
        // Init the direction of the particle.  The newAngle is calculated using the angle passed in and the
        // angle variance.
        let newAngle : GLfloat = GLKMathDegreesToRadians(angle.float + angleVariance.float * randomMinus1To1())
        
        // Create a new GLKVector2 using the newAngle
        let vector : GLKVector2 = GLKVector2Make(cosf(newAngle), sinf(newAngle))
        
        // Calculate the vectorSpeed using the speed and speedVariance which has been passed in
        let vectorSpeed : GLfloat = speed.float + speedVariance.float * randomMinus1To1()
        
        // The particles direction vector is calculated by taking the vector calculated above and
        // multiplying that by the speed
        particle.direction = Vector2(GLKVector2MultiplyScalar(vector, vectorSpeed))
        
        // Calculate the particles life span using the life span and variance passed in
        particle.timeToLive = PEFloat(max(0, particleLifespan.float + particleLifespanVariance.float * randomMinus1To1()))
        
        // Set the default diameter of the particle from the source position
        particle.radius = maxRadius + maxRadiusVariance * randomMinus1To1()
        particle.radiusDelta = maxRadius / particle.timeToLive
        particle.angle.float = GLKMathDegreesToRadians(angle.float + angleVariance.float * randomMinus1To1())
        particle.degreesPerSecond.float = GLKMathDegreesToRadians(rotatePerSecond.float + rotatePerSecondVariance.float * randomMinus1To1())
        
        particle.radialAcceleration = radialAcceleration + radialAccelVariance * randomMinus1To1()
        particle.tangentialAcceleration = tangentialAcceleration + tangentialAccelVariance * randomMinus1To1()
        
        // Calculate the particle size using the start and finish particle sizes
        let particleStartSize : GLfloat = startParticleSize.float + startParticleSizeVariance.float * randomMinus1To1()
        let particleFinishSize : GLfloat = finishParticleSize.float + finishParticleSizeVariance.float * randomMinus1To1()
        particle.particleSizeDelta.float = ((particleFinishSize - particleStartSize) / particle.timeToLive.float)
        particle.particleSize.float = max(0, particleStartSize)
        
        // Calculate the color the particle should have when it starts its life.  All the elements
        // of the start color passed in along with the variance are used to calculate the star color
        var start : PEColor  = .zero
        start.r = startColor.r + startColorVariance.r * randomMinus1To1()
        start.g = startColor.g + startColorVariance.g * randomMinus1To1()
        start.b = startColor.b + startColorVariance.b * randomMinus1To1()
        start.a = startColor.a + startColorVariance.a * randomMinus1To1()

        // Calculate the color the particle should be when its life is over.  This is done the same
        // way as the start color above
        var end : PEColor = .zero
        end.r = finishColor.r + finishColorVariance.r * randomMinus1To1()
        end.g = finishColor.g + finishColorVariance.g * randomMinus1To1()
        end.b = finishColor.b + finishColorVariance.b * randomMinus1To1()
        end.a = finishColor.a + finishColorVariance.a * randomMinus1To1()

        // Calculate the delta which is to be applied to the particles color during each cycle of its
        // life.  The delta calculation uses the life span of the particle to make sure that the
        // particles color will transition from the start to end color during its life time.  As the game
        // loop is using a fixed delta value we can calculate the delta color once saving cycles in the
        // update method
        
        particle.color = start
        particle.deltaColor = (end - start) / particle.timeToLive
        
        // Calculate the rotation
        let startA : GLfloat = rotationStart.float + rotationStartVariance.float * randomMinus1To1()
        let endA : GLfloat = rotationEnd.float + rotationEndVariance.float * randomMinus1To1()
        particle.rotation.float = startA
        particle.rotationDelta = (endA - startA) / particle.timeToLive
    }
    
    func setupArrays() {
        // Allocate the memory necessary for the particle emitter arrays
        particles = Array<Particle>(repeating: Particle(), count: maxParticles.int)
        
        // By default the particle emitter is active when created
        active = true
        
        // Set the particle count to zero
        particleCount = 0
        
        // Reset the elapsed time
        elapsedTime.float = 0
    }
    
    // MARK: - Codable
    
    /// This represents all of the properties stored within an emitter configuration file.  XMLCoder uses these to parse
    /// the file.
    enum CodingKeys : String, CodingKey {
        case emitterType
        case sourcePosition
        case sourcePositionVariance
        case speed
        case speedVariance
        case particleLifespan = "particleLifeSpan"
        case particleLifespanVariance
        case angle
        case angleVariance
        case gravity
        case radialAcceleration
        case tangentialAcceleration
        case tangentialAccelVariance
        case startColor
        case startColorVariance
        case finishColor
        case finishColorVariance
        case maxParticles
        case startParticleSize
        case startParticleSizeVariance
        case finishParticleSize
        case finishParticleSizeVariance
        case duration
        case blendFuncSource
        case blendFuncDestination
        case maxRadius
        case maxRadiusVariance
        case minRadius
        case rotatePerSecond
        case rotatePerSecondVariance
        case rotationStart
        case rotationStartVariance
        case rotationEnd
        case rotationEndVariance
        case textureDetails = "texture"
    }
    
    /// The root level tag.
    enum ConfigCodingKeys : String, CodingKey {
        case particleEmitterConfig
    }
    
    public static func nodeEncoding(for key: CodingKey) -> XMLEncoder.NodeEncoding {
        return .attribute
    }
    
    public static func nodeDecoding(for key: CodingKey) -> XMLDecoder.NodeDecoding {
        return .elementOrAttribute
    }
    
    /// Call this after completing the load from the configuration file.  It applies those settings that are derived from the configuration.
    private func postParseInit() {
        // Calculate the emission rate
        emissionRate.float = Float(maxParticles.int) / particleLifespan.float
        emitCounter.float = 0
        
        // Create a UIImage from the tiff data to extract colorspace and alpha info
        if let image = self.textureDetails?.image() {
            
            #if os(macOS)
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: .none) {
                let info = cgImage.alphaInfo
                let space = cgImage.colorSpace
                
                // Detect if the image contains alpha data
                self.hasAlpha = info == .premultipliedLast ||
                    info == .premultipliedFirst ||
                    info == .last ||
                    info == .first
                
                // Detect if alpha data is premultiplied
                self.premultiplied = space != .none && self.hasAlpha
            }
            #else
            if let cgImage = image.cgImage {
                let info = cgImage.alphaInfo
                let space = cgImage.colorSpace
                
                // Detect if the image contains alpha data
                self.hasAlpha = info == .premultipliedLast ||
                    info == .premultipliedFirst ||
                    info == .last ||
                    info == .first
                
                // Detect if alpha data is premultiplied
                self.premultiplied = space != .none && self.hasAlpha
            }
            #endif
        }
        
        // Is opacity modification required
        opacityModifyRGB = false
        
        if (blendFuncSource.int == GL_ONE && blendFuncDestination.int == GL_ONE_MINUS_SRC_ALPHA) {
            if premultiplied {
                opacityModifyRGB = true
            } else {
                // this triggers .alpha blendMode
                blendFuncSource.int = Int(GL_SRC_ALPHA)
                blendFuncDestination.int = Int(GL_ONE_MINUS_SRC_ALPHA)
            }
        }
                
        // These mappings work so far as I can tell.  Certainly the visuals I see when I test match very
        // closely to what I see in ParticleDesigner.
        //
        if blendFuncSource.int == GL_ONE && blendFuncDestination.int == GL_ONE {
            spriteKitBlendMode = .add
        } else if blendFuncSource.int == GL_SRC_ALPHA && blendFuncDestination.int == GL_ONE {
            spriteKitBlendMode = .add
        } else if blendFuncSource.int == GL_DST_COLOR && blendFuncDestination.int == GL_ONE_MINUS_SRC_ALPHA {
            spriteKitBlendMode = .multiplyAlpha
// I've no idea how to mapp these two.
//        } else if blendFuncSource.int == GL_ONE &&  blendFuncDestination.int == GL_ONE {
//            blendFunc = .multiplyAlpha
//        } else if blendFuncSource.int == GL_ONE &&  blendFuncDestination.int == GL_ONE {
//            blendFunc = .multiplyX2
        } else if blendFuncSource.int == GL_ONE && blendFuncDestination.int == GL_ONE_MINUS_SRC_ALPHA {
            spriteKitBlendMode = .alpha
        } else if blendFuncSource.int == GL_ONE_MINUS_DST_COLOR && blendFuncDestination.int == GL_ONE {
            spriteKitBlendMode = .screen
        } else if blendFuncSource.int == GL_SRC_ALPHA && blendFuncDestination.int == GL_ONE_MINUS_SRC_ALPHA {
            spriteKitBlendMode = .alpha
        } else {
            spriteKitBlendMode = .add
        }
        
        self.initialSourcePostion = self.sourcePosition
                
        self.setupArrays()
        self.reset()
    }
}
