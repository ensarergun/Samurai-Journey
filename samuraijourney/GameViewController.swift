import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private var hasPresented = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if let skView = view as? SKView {
            skView.isMultipleTouchEnabled = true
            skView.ignoresSiblingOrder = true
            #if DEBUG
            skView.showsFPS = true
            skView.showsNodeCount = true
            #endif
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !hasPresented, let skView = view as? SKView else { return }
        
        let scene = MenuScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        
        skView.presentScene(scene)
        hasPresented = true
    }

    override var prefersStatusBarHidden: Bool { true }
    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
}
