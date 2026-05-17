import SpriteKit
import UIKit

// MARK: - Oyun Kategorileri (Fizik Bitmask)
struct Category {
    static let player:     UInt32 = 0x1 << 0
    static let ground:     UInt32 = 0x1 << 1
    static let spike:      UInt32 = 0x1 << 2
    static let enemy:      UInt32 = 0x1 << 3
    static let attack:     UInt32 = 0x1 << 4
    static let coin:       UInt32 = 0x1 << 5
    static let gate:       UInt32 = 0x1 << 6
    static let sword:      UInt32 = 0x1 << 7
    static let checkpoint: UInt32 = 0x1 << 8
    static let boss:       UInt32 = 0x1 << 9
    static let arenaWall:  UInt32 = 0x1 << 10
    static let potion:     UInt32 = 0x1 << 11
    static let ammoItem:   UInt32 = 0x1 << 12
    static let playerProj: UInt32 = 0x1 << 13
    static let enemyProj:  UInt32 = 0x1 << 14
}

// MARK: - Oyun Durumları
enum GameState {
    case playing, gameOver, won
}

final class GameScene: SKScene, SKPhysicsContactDelegate {

    enum PlatformType { case staticGround, movingH, movingV }

    // MARK: - Oyun Değişkenleri
    static var currentLevel = 1
    private let maxLevels = 3
    private var levelLength: CGFloat = 4000
    private var isLevelEndSequence = false
    private var gameState: GameState = .playing
    
    // Z-Pozisyonu Katmanları
    private let world = SKNode()
    private let cam = SKCameraNode()
    private let bgLayer = SKNode()
    private let gameLayer = SKNode()
    private let uiLayer = SKNode()

    private let player = SKSpriteNode(color: .systemBlue, size: CGSize(width: 44, height: 48))
    private var facing: CGFloat = 1
    private var jumpCount = 0
    private let maxJumps = 2
    private var lastCheckpointPos: CGPoint?
    
    // İstatistikler
    private var hp = 5
    private let hpMax = 5
    private var ammoCount = 5
    static var totalCoins = 0
    private var heartNodes: [SKSpriteNode] = []

    // Animasyon Dokuları
    private var playerIdleFrames: [SKTexture] = []
    private var playerRunFrames: [SKTexture] = []
    private var playerAttackFrames: [SKTexture] = []
    private var enemyRangedRunFrames: [SKTexture] = []
    private var enemyMeleeRunFrames: [SKTexture] = []
    private var enemyShurikenFrames: [SKTexture] = []
    
    private var isAttacking = false
    private var bgNodes: [SKSpriteNode] = []
    
    private let leftBtn = SKShapeNode(circleOfRadius: 40)
    private let rightBtn = SKShapeNode(circleOfRadius: 40)
    private let jumpBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 90), cornerRadius: 20)
    private let attackBtn = SKShapeNode(rectOf: CGSize(width: 90, height: 90), cornerRadius: 20)
    private let shootBtn = SKShapeNode(circleOfRadius: 35)
    
    private var leftPressed = false
    private var rightPressed = false
    
    // Zamanlayıcılar ve Fizik Ayarları
    private var attackCooldown: TimeInterval = 0
    private var shootCooldown: TimeInterval = 0
    private var hurtCooldown: TimeInterval = 0
    private var worldGenX: CGFloat = 0
    private let groundY: CGFloat = 60
    private let moveSpeed: CGFloat = 260
    private let jumpImpulse: CGFloat = 30
    
    private var pauseMenu: SKNode?

    // MARK: - Scene Kurulumu
    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -24)
        physicsWorld.contactDelegate = self

        addChild(world)
        world.addChild(bgLayer)
        world.addChild(gameLayer)
        camera = cam
        addChild(cam)
        cam.addChild(uiLayer)

        setupTextures()
        setupBackground()
        setupHUD()
        setupPlayer()
        setupPauseButton()
        
        createPlatform(x: -400, width: 1200, y: groundY, type: .staticGround)
        worldGenX = 800
        
        for _ in 0..<2 { generateNextChunk() }
        showLevelStartText()
    }

    // MARK: - Animasyon ve Karakter Kurulumu
    private func setupPlayer() {
        if let t = playerIdleFrames.first { player.texture = t }
        player.position = lastCheckpointPos ?? CGPoint(x: 0, y: groundY + 100)
        player.zPosition = 10
        player.setScale(3.0)
        
        let body = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 30), center: CGPoint(x: 0, y: -12))
        body.allowsRotation = false
        body.friction = 0.0
        body.restitution = 0.0
        body.linearDamping = 0.1
        body.categoryBitMask = Category.player
        body.collisionBitMask = Category.ground | Category.enemy | Category.arenaWall | Category.boss
        body.contactTestBitMask = Category.ground | Category.spike | Category.enemy | Category.coin | Category.potion | Category.checkpoint | Category.boss | Category.gate | Category.sword | Category.ammoItem | Category.enemyProj
        player.physicsBody = body
        
        gameLayer.addChild(player)
        hp = hpMax
        ammoCount = 5
    }

    private func setupTextures() {
        playerIdleFrames = loadFrames(name: "player_idle", count: 8)
        playerRunFrames = loadFrames(name: "player_run", count: 8)
        playerAttackFrames = loadFrames(name: "player_attack", count: 14)
        enemyRangedRunFrames = loadFrames(name: "enemy_ranged_run", count: 8)
        enemyMeleeRunFrames = loadFrames(name: "enemy_melee_run", count: 8)
        enemyShurikenFrames = loadFrames(name: "enemy_shuriken", count: 4)
    }

    private func loadFrames(name: String, count: Int) -> [SKTexture] {
        var frames: [SKTexture] = []
        for i in 0..<count {
            if UIImage(named: "\(name)_\(i)") != nil {
                let tex = SKTexture(imageNamed: "\(name)_\(i)")
                tex.filteringMode = .nearest // Ölçeklendirmede pixel art netliğini korur
                frames.append(tex)
            }
        }
        return frames
    }

    private func animatePlayer() {
        guard gameState == .playing else { return }
        guard !isAttacking else { return }
        
        if jumpCount > 0 {
            player.removeAllActions()
            return
        }
        
        if leftPressed || rightPressed {
            if player.action(forKey: "run") == nil {
                player.removeAction(forKey: "idle")
                if !playerRunFrames.isEmpty {
                    player.run(.repeatForever(.animate(with: playerRunFrames, timePerFrame: 0.1)), withKey: "run")
                }
            }
        } else {
            if player.action(forKey: "idle") == nil {
                player.removeAction(forKey: "run")
                if !playerIdleFrames.isEmpty {
                    player.run(.repeatForever(.animate(with: playerIdleFrames, timePerFrame: 0.15)), withKey: "idle")
                }
            }
        }
    }

    // MARK: - Harita Motoru
    private func generateNextChunk() {
        if worldGenX >= levelLength {
            if !isLevelEndSequence { buildBossArena(); isLevelEndSequence = true }
            return
        }

        let pattern = Int.random(in: 0...4)
        switch pattern {
        case 0: createCombatZone()
        case 1: createStairway()
        case 2: createGapJump()
        case 3: createMovingParkour()
        default: createCombatZone()
        }
    }

    private func createCombatZone() {
        let w = CGFloat.random(in: 800...1200)
        createPlatform(x: worldGenX, width: w, y: groundY, type: .staticGround)
        
        for i in 0..<Int.random(in: 2...4) {
            let type = (i % 2 == 0) ? "melee" : "ranged"
            spawnEnemy(type: type, at: CGPoint(x: worldGenX + 300 + CGFloat(i)*250, y: groundY + 60))
        }
        if Bool.random() { spawnAmmoItem(at: CGPoint(x: worldGenX + w/2, y: groundY + 80)) }
        if Bool.random() { spawnCheckpoint(at: worldGenX + w - 200) }
        worldGenX += w + 150
    }

    private func createStairway() {
        for i in 0..<3 {
            createPlatform(x: worldGenX, width: 160, y: groundY + CGFloat(i)*70, type: .staticGround)
            worldGenX += 180
        }
        createPlatform(x: worldGenX, width: 400, y: groundY + 210, type: .staticGround)
        spawnAmmoItem(at: CGPoint(x: worldGenX + 100, y: groundY + 250))
        spawnEnemy(type: "ranged", at: CGPoint(x: worldGenX + 300, y: groundY + 250))
        worldGenX += 450
    }

    private func createGapJump() {
        createPlatform(x: worldGenX, width: 250, y: groundY, type: .staticGround)
        worldGenX += 250
        createSpikes(x: worldGenX, width: 350)
        if Bool.random() { createPlatform(x: worldGenX + 125, width: 100, y: groundY + 80, type: .staticGround) }
        worldGenX += 350
        createPlatform(x: worldGenX, width: 300, y: groundY, type: .staticGround)
        worldGenX += 300
    }

    private func createMovingParkour() {
        createPlatform(x: worldGenX, width: 200, y: groundY, type: .staticGround)
        worldGenX += 220
        createPlatform(x: worldGenX, width: 130, y: groundY + 40, type: .movingH)
        worldGenX += 280
        createPlatform(x: worldGenX, width: 130, y: groundY + 80, type: .movingV)
        spawnPotion(at: CGPoint(x: worldGenX + 60, y: groundY + 220))
        worldGenX += 280
        createPlatform(x: worldGenX, width: 200, y: groundY, type: .staticGround)
        worldGenX += 250
    }

    // MARK: - Boss Arenası
    private func buildBossArena() {
        let startX = worldGenX + 150
        createPlatform(x: startX, width: 1200, y: groundY, type: .staticGround)
        spawnWall(x: startX); spawnWall(x: startX + 1200)
        
        let boss = SKSpriteNode(color: .red, size: CGSize(width: 100, height: 100))
        if UIImage(named: "boss_idle") != nil { boss.texture = SKTexture(imageNamed: "boss_idle") }
        boss.position = CGPoint(x: startX + 900, y: groundY + 100)
        boss.name = "boss"
        
        let hpVal = 20 + (GameScene.currentLevel * 10)
        boss.userData = ["hp": hpVal, "maxHP": hpVal]
        
        let body = SKPhysicsBody(rectangleOf: boss.size)
        body.allowsRotation = false; body.friction = 1.0; body.mass = 5.0
        body.categoryBitMask = Category.boss
        body.collisionBitMask = Category.ground | Category.player | Category.arenaWall
        body.contactTestBitMask = Category.player | Category.attack | Category.playerProj
        boss.physicsBody = body
        gameLayer.addChild(boss)
        
        let bar = SKShapeNode(rectOf: CGSize(width: 100, height: 12), cornerRadius: 4); bar.fillColor = .black
        bar.position = CGPoint(x: 0, y: 70); boss.addChild(bar)
        let fill = SKSpriteNode(color: .red, size: CGSize(width: 96, height: 8))
        fill.name = "hpFill"; fill.anchorPoint = CGPoint(x: 0.5, y: 0.5); bar.addChild(fill)
        
        popup("BOSS SAVAŞI!", .red, p: CGPoint(x: startX + 600, y: groundY + 300))
    }

    private func spawnWall(x: CGFloat) {
        let w = SKSpriteNode(color: .clear, size: CGSize(width: 40, height: 1000))
        w.position = CGPoint(x: x, y: groundY + 500)
        let b = SKPhysicsBody(rectangleOf: w.size); b.isDynamic = false; b.categoryBitMask = Category.arenaWall
        w.physicsBody = b; w.name = "arenaWall"; gameLayer.addChild(w)
    }

    private func bossDefeated(at p: CGPoint) {
        gameLayer.enumerateChildNodes(withName: "arenaWall") { n, _ in n.removeFromParent() }
        createDust(at: p, scale: 4.0)
        if GameScene.currentLevel == maxLevels {
            spawnFinalSword(at: p)
        } else {
            spawnExitGate(at: p)
        }
    }

    // MARK: - Oyuncu Aksiyonları
    private func tryJump() {
        guard gameState == .playing, jumpCount < maxJumps, let b = player.physicsBody else { return }
        b.velocity.dy = 0; b.applyImpulse(CGVector(dx: 0, dy: jumpImpulse))
        jumpCount += 1
        createDust(at: CGPoint(x: player.position.x, y: player.position.y - 20), scale: 1.5)
    }

    private func tryAttack() {
        guard gameState == .playing, !isAttacking else { return }
        let now = CACurrentMediaTime()
        if now < attackCooldown { return }
        attackCooldown = now + 0.45
        
        isAttacking = true
        player.removeAllActions()
        
        if !playerAttackFrames.isEmpty {
            let anim = SKAction.animate(with: playerAttackFrames, timePerFrame: 0.03)
            player.run(.sequence([anim, .run { self.isAttacking = false }]))
        } else {
            isAttacking = false
        }
        
        let hitSize = CGSize(width: 60, height: 50)
        let hit = SKNode()
        hit.position = CGPoint(x: player.position.x + facing * 40, y: player.position.y)
        
        let b = SKPhysicsBody(rectangleOf: hitSize)
        b.isDynamic = false
        b.categoryBitMask = Category.attack
        b.contactTestBitMask = Category.enemy | Category.boss
        hit.physicsBody = b
        
        gameLayer.addChild(hit)
        hit.run(.sequence([.wait(forDuration: 0.2), .removeFromParent()]))
    }

    private func tryShoot() {
        guard gameState == .playing else { return }
        let now = CACurrentMediaTime()
        if now < shootCooldown || ammoCount <= 0 { return }
        
        ammoCount -= 1; updateUI(); shootCooldown = now + 0.5
        
        let s = SKShapeNode(rectOf: CGSize(width: 14, height: 14), cornerRadius: 2)
        s.fillColor = .cyan; s.position = player.position
        let b = SKPhysicsBody(rectangleOf: CGSize(width: 14, height: 14))
        b.categoryBitMask = Category.playerProj; b.contactTestBitMask = Category.enemy | Category.boss | Category.ground
        b.affectedByGravity = false; s.physicsBody = b; gameLayer.addChild(s)
        
        b.velocity = CGVector(dx: facing * 600, dy: 0)
        s.run(.repeatForever(.rotate(byAngle: 10, duration: 0.5)))
        s.run(.sequence([.wait(forDuration: 1.5), .removeFromParent()]))
    }

    // MARK: - Update Döngüsü
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .playing else { return }
        
        if let b = player.physicsBody {
            var dx: CGFloat = 0
            if leftPressed { dx = -1; facing = -1 }
            if rightPressed { dx = 1; facing = 1 }
            b.velocity.dx = dx * moveSpeed
            player.xScale = abs(player.xScale) * facing
        }
        animatePlayer()
        
        let targetX = max(0, player.position.x)
        let targetY = max(groundY + 120, player.position.y + 50)
        cam.position.x += (targetX - cam.position.x) * 0.1
        cam.position.y += (targetY - cam.position.y) * 0.1
        
        bgLayer.position.x = cam.position.x * 0.8
        
        // Sonsuz arka plan (Parallax) döngüsü
        let referenceX = cam.position.x
        for bg in bgNodes {
            let bgWidth = bg.size.width
            if bg.position.x < referenceX - bgWidth {
                bg.position.x += bgWidth * 4
            } else if bg.position.x > referenceX + (bgWidth * 3) {
                bg.position.x -= bgWidth * 4
            }
        }
        
        if player.position.x > worldGenX - 1200 { generateNextChunk() }
        if player.position.y < -400 { takeDamage(hpMax) }
        
        gameLayer.enumerateChildNodes(withName: "enemy") { node, _ in
            if let e = node as? SKSpriteNode, let eb = e.physicsBody {
                let dist = self.player.position.x - e.position.x
                let type = e.userData?["type"] as? String ?? "melee"
                
                if type == "melee" {
                    if abs(dist) < 400 && abs(dist) > 45 {
                        eb.velocity.dx = (dist > 0 ? 1 : -1) * 90
                    } else if abs(dist) <= 45 {
                        let nextAttack = e.userData?["nextShoot"] as? TimeInterval ?? 0
                        if currentTime > nextAttack {
                            self.takeDamage(1)
                            e.userData?["nextShoot"] = currentTime + 1.5
                        }
                    }
                } else if abs(dist) < 550 {
                    eb.velocity.dx = (abs(dist) < 250) ? (dist > 0 ? -90 : 90) : (dist > 0 ? 60 : -60)
                    let nS = e.userData?["nextShoot"] as? TimeInterval ?? 0
                    if currentTime > nS {
                        self.spawnEnemyProj(from: e); e.userData?["nextShoot"] = currentTime + Double.random(in: 1.8...2.5)
                    }
                }
            }
        }
        
        if let boss = gameLayer.childNode(withName: "boss") as? SKSpriteNode {
            let dist = player.position.x - boss.position.x
            boss.physicsBody?.velocity.dx = (dist > 0 ? 1 : -1) * 65
        }
    }

    // MARK: - Çarpışmalar (Physics)
    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing else { return }
        let m = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        if m & (Category.player | Category.ground) == (Category.player | Category.ground) || m & (Category.player | Category.arenaWall) == (Category.player | Category.arenaWall) {
            jumpCount = 0
        }
        
        if m & (Category.player | Category.potion) == (Category.player | Category.potion) {
            let n = (contact.bodyA.categoryBitMask == Category.potion) ? contact.bodyA.node : contact.bodyB.node
            n?.removeFromParent(); hp = min(hp + 1, hpMax); updateUI(); popup("CAN+1", .green)
        }
        
        if m & (Category.player | Category.ammoItem) == (Category.player | Category.ammoItem) {
            let n = (contact.bodyA.categoryBitMask == Category.ammoItem) ? contact.bodyA.node : contact.bodyB.node
            n?.removeFromParent(); ammoCount += 3; updateUI(); popup("SHURIKEN+3", .cyan)
        }

        if m & (Category.attack | Category.enemy) == (Category.attack | Category.enemy) || m & (Category.playerProj | Category.enemy) == (Category.playerProj | Category.enemy) {
            let en = (contact.bodyA.categoryBitMask == Category.enemy) ? contact.bodyA.node : contact.bodyB.node
            if m & Category.playerProj != 0 { (contact.bodyA.categoryBitMask == Category.playerProj ? contact.bodyA.node : contact.bodyB.node)?.removeFromParent() }
            if let e = en as? SKSpriteNode { hitEnemy(e, 1) }
        }

        if m & (Category.attack | Category.boss) == (Category.attack | Category.boss) || m & (Category.playerProj | Category.boss) == (Category.playerProj | Category.boss) {
            if m & Category.playerProj != 0 { (contact.bodyA.categoryBitMask == Category.playerProj ? contact.bodyA.node : contact.bodyB.node)?.removeFromParent() }
            if let b = gameLayer.childNode(withName: "boss") as? SKSpriteNode { hitEnemy(b, 1) }
        }

        if m & (Category.player | Category.enemy) == (Category.player | Category.enemy) || m & (Category.player | Category.enemyProj) == (Category.player | Category.enemyProj) || m & (Category.player | Category.spike) == (Category.player | Category.spike) {
            if m & Category.enemyProj != 0 { (contact.bodyA.categoryBitMask == Category.enemyProj ? contact.bodyA.node : contact.bodyB.node)?.removeFromParent() }
            takeDamage(1)
        }
        
        if m & (Category.player | Category.checkpoint) == (Category.player | Category.checkpoint) {
            let cp = (contact.bodyA.categoryBitMask == Category.checkpoint) ? contact.bodyA.node : contact.bodyB.node
            if let flag = cp?.childNode(withName: "flag") as? SKShapeNode, flag.fillColor == .red {
                flag.fillColor = .green; lastCheckpointPos = cp?.position; popup("KAYIT ALINDI!", .yellow)
            }
        }

        if m & (Category.player | Category.gate) == (Category.player | Category.gate) { handleLevelComplete() }
        if m & (Category.player | Category.sword) == (Category.player | Category.sword) { handleVictory() }
    }

    // MARK: - Savaş ve Hasar
    private func hitEnemy(_ e: SKSpriteNode, _ d: Int) {
        let cur = (e.userData?["hp"] as? Int ?? 1) - d
        e.userData?["hp"] = cur
        popup("-\(d)", .white, p: e.position)
        
        let knockbackDir = (e.position.x > player.position.x) ? 1.0 : -1.0
        e.physicsBody?.applyImpulse(CGVector(dx: knockbackDir * 15, dy: 5))
        
        if e.name == "boss", let m = e.userData?["maxHP"] as? Int, let f = e.childNode(withName: "hpFill") as? SKSpriteNode {
            f.size.width = 96 * (CGFloat(max(0, cur))/CGFloat(m))
        }
        
        if cur <= 0 {
            if e.name == "boss" { bossDefeated(at: e.position) }
            createDust(at: e.position, scale: 2.0); e.removeFromParent()
        } else {
            e.run(.sequence([.fadeAlpha(to: 0.3, duration: 0.1), .fadeAlpha(to: 1.0, duration: 0.1)]))
        }
    }

    private func takeDamage(_ d: Int) {
        guard gameState == .playing else { return }
        let now = CACurrentMediaTime()
        if now < hurtCooldown { return }
        hurtCooldown = now + 1.2
        
        hp -= d; updateUI()
        
        player.physicsBody?.velocity = .zero
        player.physicsBody?.applyImpulse(CGVector(dx: -facing * 40, dy: 40))
        player.run(.sequence([.fadeAlpha(to: 0.2, duration: 0.1), .fadeAlpha(to: 1.0, duration: 0.1), .fadeAlpha(to: 0.2, duration: 0.1), .fadeAlpha(to: 1.0, duration: 0.1)]))
        
        if hp <= 0 { handleGameOver() }
    }

    private func spawnEnemyProj(from e: SKSpriteNode) {
        guard !enemyShurikenFrames.isEmpty else {
            let p = SKShapeNode(circleOfRadius: 7); p.fillColor = .purple; p.position = e.position
            let b = SKPhysicsBody(circleOfRadius: 7); b.categoryBitMask = Category.enemyProj
            b.contactTestBitMask = Category.player; b.affectedByGravity = false; p.physicsBody = b
            gameLayer.addChild(p)
            let dx = player.position.x - e.position.x, dy = player.position.y - e.position.y
            let len = sqrt(dx*dx + dy*dy)
            b.velocity = CGVector(dx: (dx/len)*250, dy: (dy/len)*250)
            p.run(.sequence([.wait(forDuration: 3), .removeFromParent()]))
            return
        }

        let s = SKSpriteNode(texture: enemyShurikenFrames[0])
        s.position = e.position
        s.zPosition = 8
        s.setScale(2.0)
        
        let rotateAction = SKAction.rotate(byAngle: .pi * 2, duration: 0.5)
        s.run(.repeatForever(rotateAction))
        
        let b = SKPhysicsBody(circleOfRadius: s.size.width / 2)
        b.categoryBitMask = Category.enemyProj
        b.contactTestBitMask = Category.player
        b.collisionBitMask = Category.ground
        b.affectedByGravity = true
        b.mass = 0.05
        b.linearDamping = 0.0
        s.physicsBody = b
        
        gameLayer.addChild(s)
        
        // Hitbox merkezine nişan alma düzeltmesi (-12px ofset)
        let correctedPlayerY = player.position.y - 12
        let targetX = player.position.x
        let targetY = correctedPlayerY
        
        let dx = targetX - e.position.x
        let dy = targetY - e.position.y
        let len = sqrt(dx*dx + dy*dy)
        
        let speed: CGFloat = 350
        b.velocity = CGVector(dx: (dx/len) * speed, dy: (dy/len) * speed)
        
        s.run(.sequence([.wait(forDuration: 3), .removeFromParent()]))
    }

    // MARK: - Oyun Durumu Değişimleri
    private func handleGameOver() {
        gameState = .gameOver
        player.physicsBody?.velocity = .zero
        player.run(.sequence([.rotate(byAngle: .pi/2, duration: 0.5), .fadeOut(withDuration: 0.5)]))
        
        let overlay = SKShapeNode(rectOf: size); overlay.fillColor = .black.withAlphaComponent(0.8); overlay.zPosition = 2000; cam.addChild(overlay)
        let l1 = SKLabelNode(text: "ÖLDÜN"); l1.fontSize = 50; l1.fontColor = .red; l1.position = CGPoint(x: 0, y: 30); l1.zPosition = 2001; cam.addChild(l1)
        let l2 = SKLabelNode(text: "Yeniden Başlamak İçin Ekrana Dokun"); l2.fontSize = 20; l2.position = CGPoint(x: 0, y: -30); l2.zPosition = 2001; cam.addChild(l2)
    }

    private func handleLevelComplete() {
        gameState = .won
        GameScene.currentLevel += 1
        player.physicsBody?.velocity = .zero
        view?.presentScene(GameScene(size: size), transition: .doorway(withDuration: 1.5))
    }

    private func handleVictory() {
        gameState = .won
        player.physicsBody?.velocity = .zero
        let overlay = SKShapeNode(rectOf: size); overlay.fillColor = .black.withAlphaComponent(0.8); overlay.zPosition = 2000; cam.addChild(overlay)
        let l1 = SKLabelNode(text: "EFSANE TAMAMLANDI!"); l1.fontSize = 40; l1.fontColor = .yellow; l1.position = CGPoint(x: 0, y: 30); l1.zPosition = 2001; cam.addChild(l1)
        let l2 = SKLabelNode(text: "Kılıcı Aldın. Başa Dönmek İçin Dokun."); l2.fontSize = 20; l2.position = CGPoint(x: 0, y: -30); l2.zPosition = 2001; cam.addChild(l2)
    }

    private func resetGame() {
        if gameState == .won { GameScene.currentLevel = 1; GameScene.totalCoins = 0 }
        let newScene = GameScene(size: size)
        newScene.lastCheckpointPos = (gameState == .gameOver) ? self.lastCheckpointPos : nil
        view?.presentScene(newScene, transition: .crossFade(withDuration: 1.0))
    }

    // MARK: - UI ve Çevre Oluşturucular
    private func createPlatform(x: CGFloat, width: CGFloat, y: CGFloat, type: PlatformType) {
        let groundTex = SKTexture(imageNamed: "tile_ground")
        groundTex.filteringMode = .nearest
        
        let p = SKSpriteNode(texture: groundTex, size: CGSize(width: width, height: 32))
        p.position = CGPoint(x: x + width/2, y: y)
        p.zPosition = 5
        
        // Hareketli platformlar için renk filtresi
        if type != .staticGround {
            p.color = .systemOrange
            p.colorBlendFactor = 0.5
        }
        
        let b = SKPhysicsBody(rectangleOf: p.size)
        b.isDynamic = false
        b.friction = 1.0
        b.categoryBitMask = Category.ground
        p.physicsBody = b
        
        gameLayer.addChild(p)
        
        if type == .movingH { p.run(.repeatForever(.sequence([.moveBy(x: 120, y: 0, duration: 2), .moveBy(x: -120, y: 0, duration: 2)]))) }
        if type == .movingV { p.run(.repeatForever(.sequence([.moveBy(x: 0, y: 120, duration: 2), .moveBy(x: 0, y: -120, duration: 2)]))) }
    }

    private func setupHUD() {
        func addBtn(_ b: SKShapeNode, _ p: CGPoint, _ t: String, c: SKColor = .white) {
            b.fillColor = .white.withAlphaComponent(0.15); b.strokeColor = c; b.lineWidth = 2; b.position = p; b.zPosition = 100
            let l = SKLabelNode(text: t); l.fontName = "AvenirNext-Bold"; l.verticalAlignmentMode = .center; b.addChild(l); uiLayer.addChild(b)
        }
        let sy = -size.height/2 + 80, sx = -size.width/2 + 80
        addBtn(leftBtn, CGPoint(x: sx, y: sy), "◀"); addBtn(rightBtn, CGPoint(x: sx + 110, y: sy), "▶")
        addBtn(jumpBtn, CGPoint(x: size.width/2 - 90, y: sy), "▲"); addBtn(attackBtn, CGPoint(x: size.width/2 - 200, y: sy), "⚔")
        addBtn(shootBtn, CGPoint(x: size.width/2 - 200, y: sy + 100), "★", c: .cyan)
        
        let ammoIcon = SKLabelNode(text: "★:"); ammoIcon.fontSize = 20; ammoIcon.fontColor = .cyan; ammoIcon.position = CGPoint(x: -20, y: 45); shootBtn.addChild(ammoIcon)
        let lblAmmo = SKLabelNode(text: "5"); lblAmmo.name = "ammoLbl"; lblAmmo.fontSize = 22; lblAmmo.fontColor = .white; lblAmmo.position = CGPoint(x: 10, y: 45); shootBtn.addChild(lblAmmo)
        
        for i in 0..<hpMax {
            let h = SKSpriteNode(color: .red, size: CGSize(width: 20, height: 18))
            h.position = CGPoint(x: -size.width/2 + 50 + CGFloat(i)*28, y: size.height/2 - 40)
            uiLayer.addChild(h)
            heartNodes.append(h)
        }
    }
    
    private func updateUI() {
        if let l = shootBtn.childNode(withName: "ammoLbl") as? SKLabelNode { l.text = "\(ammoCount)" }
        for (i, h) in heartNodes.enumerated() { h.alpha = i < hp ? 1 : 0.2 }
    }

    private func popup(_ t: String, _ c: SKColor, p: CGPoint? = nil) {
        let l = SKLabelNode(text: t); l.fontSize = 18; l.fontColor = c; l.fontName = "AvenirNext-Bold"
        l.position = p ?? CGPoint(x: player.position.x, y: player.position.y + 30); l.zPosition = 100; gameLayer.addChild(l)
        l.run(.sequence([.moveBy(x: 0, y: 40, duration: 0.8), .fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    private func createDust(at p: CGPoint, scale: CGFloat = 1.0) {
        let d = SKShapeNode(circleOfRadius: 6); d.fillColor = .white; d.alpha = 0.7; d.position = p
        gameLayer.addChild(d); d.run(.sequence([.scale(to: 2 * scale, duration: 0.3), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    private func setupBackground() {
        let bgTexture = SKTexture(imageNamed: "background")
        bgTexture.filteringMode = .nearest
        
        let scaleHeight = size.height / bgTexture.size().height
        let scaleWidth = size.width / bgTexture.size().width
        let finalScale = max(scaleHeight, scaleWidth)
        let scaledWidth = bgTexture.size().width * finalScale
        
        // Kusursuz döngü (seamless loop) için aynalanmış doku çiftleri
        for i in 0...3 {
            let bg = SKSpriteNode(texture: bgTexture)
            
            bg.yScale = finalScale
            bg.xScale = (i % 2 == 1) ? -finalScale : finalScale
            
            bg.zPosition = -1
            bg.position = CGPoint(x: (size.width / 2) + CGFloat(i) * scaledWidth, y: size.height / 2)
            
            addChild(bg)
            bgNodes.append(bg)
        }
    }
    
    private func setupPauseButton() {
        let pauseCircle = SKShapeNode(circleOfRadius: 25)
        pauseCircle.name = "pauseBtn"
        pauseCircle.fillColor = .black
        pauseCircle.alpha = 0.6
        pauseCircle.strokeColor = .white
        pauseCircle.lineWidth = 2
        
        for i in [-6, 6] {
            let bar = SKShapeNode(rectOf: CGSize(width: 4, height: 16))
            bar.fillColor = .white
            bar.strokeColor = .clear
            bar.position = CGPoint(x: CGFloat(i), y: 0)
            pauseCircle.addChild(bar)
        }
        
        pauseCircle.position = CGPoint(x: size.width/2 - 50, y: size.height/2 - 50)
        pauseCircle.zPosition = 100
        camera?.addChild(pauseCircle)
    }

    private func showPauseMenu() {
        self.isPaused = true
        
        let menu = SKNode()
        menu.zPosition = 200
        pauseMenu = menu
        
        camera?.addChild(menu)
        
        let bg = SKSpriteNode(color: .black, size: CGSize(width: 10000, height: 10000))
        bg.alpha = 0.7
        menu.addChild(bg)
        
        let resume = SKLabelNode(text: "DEVAM ET")
        resume.name = "resumeBtn"
        resume.fontName = "AvenirNext-Bold"
        resume.position = CGPoint(x: 0, y: 50)
        menu.addChild(resume)
        
        let home = SKLabelNode(text: "ANA MENÜ")
        home.name = "homeBtn"
        home.fontName = "AvenirNext-Bold"
        home.position = CGPoint(x: 0, y: -50)
        menu.addChild(home)
    }

    private func showLevelStartText() {
        let l = SKLabelNode(text: "BÖLÜM \(GameScene.currentLevel)"); l.fontName = "AvenirNext-Bold"; l.fontSize = 50; l.position = CGPoint(x: 0, y: 80)
        uiLayer.addChild(l); l.run(.sequence([.wait(forDuration: 2), .fadeOut(withDuration: 1.5), .removeFromParent()]))
    }

    private func trianglePath(w: CGFloat, h: CGFloat) -> CGPath {
        let p = CGMutablePath(); p.move(to: CGPoint(x: -w/2, y: 0)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: w/2, y: 0)); p.closeSubpath(); return p
    }

    private func createSpikes(x: CGFloat, width: CGFloat) {
        let c = Int(width/30)
        for i in 0..<c {
            let s = SKShapeNode(path: trianglePath(w: 24, h: 25)); s.fillColor = .red; s.position = CGPoint(x: x + 15 + CGFloat(i)*30, y: groundY - 40)
            let b = SKPhysicsBody(rectangleOf: CGSize(width: 15, height: 20)); b.isDynamic = false; b.categoryBitMask = Category.spike; s.physicsBody = b; gameLayer.addChild(s)
        }
    }

    private func spawnAmmoItem(at p: CGPoint) { let n = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4); n.fillColor = .cyan; n.position = p; let b = SKPhysicsBody(rectangleOf: n.frame.size); b.isDynamic = false; b.categoryBitMask = Category.ammoItem; b.contactTestBitMask = Category.player; n.physicsBody = b; gameLayer.addChild(n) }
    private func spawnPotion(at p: CGPoint) { let n = SKShapeNode(circleOfRadius: 10); n.fillColor = .red; n.position = p; let b = SKPhysicsBody(circleOfRadius: 10); b.isDynamic = false; b.categoryBitMask = Category.potion; b.contactTestBitMask = Category.player; n.physicsBody = b; gameLayer.addChild(n) }
    private func spawnCheckpoint(at x: CGFloat) { let p = SKShapeNode(rectOf: CGSize(width: 6, height: 60)); p.fillColor = .brown; p.position = CGPoint(x: x, y: groundY + 30); let f = SKShapeNode(path: trianglePath(w: 25, h: 20)); f.fillColor = .red; f.position = CGPoint(x: 5, y: 20); f.zRotation = -1.57; f.name = "flag"; p.addChild(f); let b = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 60)); b.isDynamic = false; b.categoryBitMask = Category.checkpoint; b.contactTestBitMask = Category.player; p.physicsBody = b; gameLayer.addChild(p) }
    private func spawnEnemy(type: String, at p: CGPoint) {
        let e: SKSpriteNode
        
        if type == "ranged", let firstFrame = enemyRangedRunFrames.first {
            e = SKSpriteNode(texture: firstFrame)
            e.setScale(2.0)
            if !enemyRangedRunFrames.isEmpty {
                let runAnim = SKAction.animate(with: enemyRangedRunFrames, timePerFrame: 0.1)
                e.run(.repeatForever(runAnim), withKey: "enemyRun")
            }
        } else if type == "melee", let firstFrame = enemyMeleeRunFrames.first {
            e = SKSpriteNode(texture: firstFrame)
            e.setScale(2.0)
            if !enemyMeleeRunFrames.isEmpty {
                let runAnim = SKAction.animate(with: enemyMeleeRunFrames, timePerFrame: 0.1)
                e.run(.repeatForever(runAnim), withKey: "enemyRun")
            }
        } else {
            e = SKSpriteNode(color: type == "melee" ? .orange : .purple, size: CGSize(width: 36, height: 36))
        }
        
        e.position = p
        e.name = "enemy"
        e.userData = ["hp": 2, "type": type, "nextShoot": 0.0]
        
        let b = SKPhysicsBody(rectangleOf: CGSize(width: 24, height: 35), center: CGPoint(x: 0, y: -15))
        b.allowsRotation = false
        b.categoryBitMask = Category.enemy
        b.collisionBitMask = Category.ground | Category.player
        b.contactTestBitMask = Category.player | Category.attack | Category.playerProj
        e.physicsBody = b
        
        gameLayer.addChild(e)
    }
    private func spawnExitGate(at p: CGPoint) { let g = SKSpriteNode(color: .darkGray, size: CGSize(width: 70, height: 110)); g.position = CGPoint(x: p.x, y: groundY + 55); let b = SKPhysicsBody(rectangleOf: g.size); b.isDynamic = false; b.categoryBitMask = Category.gate; g.physicsBody = b; gameLayer.addChild(g) }
    private func spawnFinalSword(at p: CGPoint) { let s = SKSpriteNode(color: .yellow, size: CGSize(width: 15, height: 75)); s.position = CGPoint(x: p.x, y: groundY + 60); let b = SKPhysicsBody(rectangleOf: s.size); b.isDynamic = false; b.categoryBitMask = Category.sword; s.physicsBody = b; gameLayer.addChild(s) }

    // MARK: - Dokunmatik Giriş
    private var touchMap: [UITouch: String] = [:]
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .gameOver || gameState == .won { resetGame(); return }
        
        for t in touches {
            let locationInScene = t.location(in: self)
            let tappedNodes = self.nodes(at: locationInScene)
            
            var menuActionTriggered = false
            for node in tappedNodes {
                if node.name == "pauseBtn" {
                    showPauseMenu()
                    menuActionTriggered = true
                    break
                } else if node.name == "resumeBtn" {
                    pauseMenu?.removeFromParent()
                    self.isPaused = false
                    menuActionTriggered = true
                    break
                } else if node.name == "homeBtn" {
                    let menuScene = MenuScene(size: self.size)
                    menuScene.scaleMode = .aspectFill
                    self.view?.presentScene(menuScene, transition: SKTransition.doorway(withDuration: 1.0))
                    menuActionTriggered = true
                    break
                }
            }
            
            if menuActionTriggered || self.isPaused { continue }
            
            let p = t.location(in: uiLayer)
            if leftBtn.contains(p) { leftPressed = true; leftBtn.alpha = 0.5; touchMap[t] = "L" }
            else if rightBtn.contains(p) { rightPressed = true; rightBtn.alpha = 0.5; touchMap[t] = "R" }
            else if jumpBtn.contains(p) { tryJump(); jumpBtn.alpha = 0.5; touchMap[t] = "J" }
            else if attackBtn.contains(p) { tryAttack(); attackBtn.alpha = 0.5; touchMap[t] = "A" }
            else if shootBtn.contains(p) { tryShoot(); shootBtn.alpha = 0.5; touchMap[t] = "S" }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if let k = touchMap[t] {
                if k == "L" { leftPressed = false; leftBtn.alpha = 1.0 }
                if k == "R" { rightPressed = false; rightBtn.alpha = 1.0 }
                if k == "J" { jumpBtn.alpha = 1.0 }
                if k == "A" { attackBtn.alpha = 1.0 }
                if k == "S" { shootBtn.alpha = 1.0 }
                touchMap.removeValue(forKey: t)
            }
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }
}
