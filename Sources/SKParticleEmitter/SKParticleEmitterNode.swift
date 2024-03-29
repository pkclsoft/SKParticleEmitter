//
//  SKParticleEmitter.swift
//  ParticleEmitterDemo-SK
//
//  This is a Swift port of the SKParticleEmitter by 71Squared.
//
//  Created by Peter Easdown on 27/3/21.
//  Copyright © 2021 71Squared Ltd. All rights reserved.
//

import Foundation
import CoreGraphics
import SpriteKit

open class SKParticleEmitterNode : SKNode, BaseParticleEmitterDelegate {
    
    /// The actual emitter engine.
    public var emitter : BaseParticleEmitter?
    
    public var targetNode : SKNode?
    
    /// The texture to use for this emitter.
    var texture : SKTexture?

    /// The index of the next particle to be added to the node tree.
    var particleNodeIndex : NSInteger = 0

    /// The array of particles; only particleNodeIndex-1 of these will be in the tree, and those are updated every frame with
    /// properties from the underlying engine.
    var particleNodes = Array<SKSpriteNode>()
    
    /// Initialises the emitter (an SKNode) using the configuration specified file.
    /// - Parameter fileName: the configuration file to use; it's assumed that the extension is ".pex".
    /// - Parameter bundle: the bundle from which to load the configuration file; defaults to `Bundle.main`.
    /// - Parameter targetNode: an optional target node that renders the emitter’s particles.
    /// - Throws: If something prevents the shader configuration being loaded.
    public init(withConfigFile fileName: String, fromBundle bundle: Bundle = Bundle.main, andTargetNode targetNode : SKNode? = nil) throws {
        super.init()

        self.targetNode = targetNode
        
        // load the emitter engine.
        self.emitter = try BaseParticleEmitter.load(withFile: fileName, fromBundle: bundle, delegate: self)!
        
        // get the texture from the emitter.
        self.texture = emitter?.textureDetails!.texture()!
        
        self.configure()
    }
    
    /// Initialises the emitter (an SKNode) using the configuration specified file.
    /// - Parameter fileURL: the URL of the PEX file containing the configuration file.
    /// - Parameter targetNode: an optional target node that renders the emitter’s particles.
    /// - Throws: If something prevents the shader configuration being loaded.
    public init(withConfigURL fileURL: URL, andTargetNode targetNode : SKNode? = nil) throws {
        super.init()

        self.targetNode = targetNode
        
        // load the emitter engine.
        self.emitter = try BaseParticleEmitter.load(fromURL: fileURL, delegate: self)
        
        // get the texture from the emitter.
        self.texture = emitter?.textureDetails!.texture()!
        
        self.configure()
    }
    
    private func configure() {
        // create all of the particle SKSpriteNodes, all using the same texture.
        for _ in 0 ..< emitter!.maxParticles.int {
            let particleNode = SKSpriteNode(texture: self.texture)
            particleNode.size = .zero
            particleNode.blendMode = emitter!.spriteKitBlendMode
            self.particleNodes.append(particleNode)
            particleNode.isHidden = true
            particleNode.color = .init(red: 1.0, green: 0.3, blue: 0.5, alpha: 0.5)
        }
    }

    /// Not used by this class, but required by Swift.
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Update the emitter (typically, once a frame).  Call this from the scene or view update() method.
    /// - Parameter aDelta: the amount of time to give to the particles.
    public func update(withDelta aDelta: TimeInterval, providingAlpha: CGFloat) {
        self.emitter?.update(withDelta: PEFloat(aDelta))
        
        var particleNode : SKSpriteNode

        // for every particle currently alive in the emitter, update the respective SKSpriteNode
        // with the parameters of the particle.
        for pi in 0 ..< emitter!.particleCount {
            particleNode = particleNodes[pi]
            
            let p = emitter!.particles[pi]
            particleNode.position = CGPoint(x: CGFloat(p.position.x), y: CGFloat(p.position.y))
            particleNode.size = .init(width: CGFloat(p.particleSize.float), height: CGFloat(p.particleSize.float))
            particleNode.color = p.color.asUIColor()
            particleNode.zRotation = CGFloat(GLKMathDegreesToRadians(p.rotation.float))
            particleNode.colorBlendFactor = 1.0
            particleNode.alpha = providingAlpha
            
            // this is what 71Squared had.  I think with time, we can improve on this to map the GL blend modes to
            // SpriteKit blend modes.
//            particleNode.blendMode = self.emitter!.spriteKitBlendMode
        }
    }
    
    public override func removeFromParent() {
        super.removeFromParent()

        self.emitter?.reset()
        self.emitter?.active = false
        
    }
    
    // MARK: - BaseParticleEmitterDelegate
    
    /// Adds a single particle node to the node tree.  This is called by the emitter engine.
    ///
    func addParticle() {
        let particleNode = self.particleNodes[self.particleNodeIndex]
        particleNode.isHidden = false
        
        
        if let tn = self.targetNode {
            particleNode.zPosition = tn.zPosition + CGFloat(particleNodeIndex)
            tn.addChild(particleNode)
        } else {
            particleNode.zPosition = self.zPosition + CGFloat(particleNodeIndex)
            self.addChild(particleNode)
        }
        
        particleNodeIndex += 1
        assert(particleNodeIndex <= emitter!.maxParticles.int)
    }
    
    /// Removes a particle from the node tree.
    func removeParticle() {
        particleNodeIndex -= 1
        assert(particleNodeIndex >= 0)

        let particleNode = self.particleNodes[self.particleNodeIndex]
        particleNode.isHidden = true
        particleNode.removeFromParent()
    }

}
