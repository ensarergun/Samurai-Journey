import SpriteKit

class MenuScene: SKScene {
    
    // MARK: - Değişkenler
    private var bgNodes: [SKSpriteNode] = []
    
    // MARK: - Kurulum
    override func didMove(to view: SKView) {
        setupBackground()
        
        // Başlık (Gölge Efekti)
        let titleShadow = SKLabelNode(text: "SAMURAI JOURNEY")
        titleShadow.fontName = "AvenirNext-Bold"
        titleShadow.fontSize = 64
        titleShadow.fontColor = .black
        titleShadow.position = CGPoint(x: size.width/2 + 4, y: size.height * 0.75 - 4)
        addChild(titleShadow)
        
        let title = SKLabelNode(text: "SAMURAI JOURNEY")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 64
        title.fontColor = .white
        title.position = CGPoint(x: size.width/2, y: size.height * 0.75)
        addChild(title)
        
        // Butonlar
        createMenuButton(name: "playBtn", text: "OYUNA BAŞLA", yPos: size.height * 0.45, color: .systemRed)
        createMenuButton(name: "exitBtn", text: "OYUNDAN ÇIK", yPos: size.height * 0.45 - 120, color: .darkGray)
    }
    
    // MARK: - UI Oluşturucular
    private func createMenuButton(name: String, text: String, yPos: CGFloat, color: SKColor) {
        let btn = SKShapeNode(rectOf: CGSize(width: 300, height: 70), cornerRadius: 15)
        btn.name = name
        btn.fillColor = color
        btn.strokeColor = .white
        btn.lineWidth = 2
        btn.position = CGPoint(x: size.width/2, y: yPos)
        addChild(btn)
        
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 24
        label.verticalAlignmentMode = .center
        btn.addChild(label)
    }
    
    // MARK: - Arka Plan (Aynalı Döngü)
    private func setupBackground() {
        let bgTexture = SKTexture(imageNamed: "background")
        bgTexture.filteringMode = .nearest
        
        let finalScale = max(size.height / bgTexture.size().height, size.width / bgTexture.size().width)
        let scaledWidth = bgTexture.size().width * finalScale
        
        for i in 0...3 {
            let bg = SKSpriteNode(texture: bgTexture)
            bg.yScale = finalScale
            bg.xScale = (i % 2 == 1) ? -finalScale : finalScale
            bg.position = CGPoint(x: (size.width / 2) + CGFloat(i) * scaledWidth, y: size.height / 2)
            bg.zPosition = -1
            
            addChild(bg)
            bgNodes.append(bg)
        }
    }
    
    // MARK: - Döngü ve Etkileşim
    override func update(_ currentTime: TimeInterval) {
        for bg in bgNodes {
            bg.position.x -= 0.5
            if bg.position.x < -(bg.size.width / 2) {
                bg.position.x += bg.size.width * 4
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)
        
        for node in nodes {
            if node.name == "playBtn" {
                let scene = GameScene(size: self.size)
                scene.scaleMode = .resizeFill
                self.view?.presentScene(scene, transition: SKTransition.fade(withDuration: 1.5))
            } else if node.name == "exitBtn" {
                exit(0)
            }
        }
    }
}
