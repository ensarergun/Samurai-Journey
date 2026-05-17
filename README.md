# ⚔️ Samurai Journey

**Samurai Journey**, iOS platformu için Swift ve SpriteKit kullanılarak tamamen yerel (native) olarak geliştirilmiş, aksiyon dolu 2D bir platform oyunudur. Oyuncular, engellerle ve düşmanlarla dolu dinamik seviyeleri aşarak efsanevi kılıca ulaşmaya çalışan bir samurayı kontrol eder.

> <img width="1266" height="585" alt="IMG_9109" src="https://github.com/user-attachments/assets/acb5d698-bb52-4f6d-9270-b771f8058a7c" />

## 🌟 Özellikler

* **Dinamik Seviye Üretimi:** Oyun, her oynayışta farklı bir deneyim sunmak için (savaş alanları, hareketli parkurlar, uçurumlar) prosedürel olarak harita parçaları (chunks) üretir.
* **Akıllı Düşman Yapay Zekası:** * **Yakın Dövüşçüler (Spearman):** Karakterin menziline girdiğinde hızlanır ve belirli aralıklarla hasar vurur.
* **Menzilli Düşmanlar (Assassin):** Karakterin konumunu hesaplayarak doğrudan göğüs hizasına dönen shurikenler fırlatır.
* **Kusursuz Arka Plan Döngüsü (Seamless Parallax):** Arka plan görselleri aynalama (mirroring) algoritması ile sonsuz ve dikişsiz bir atmosfer yaratacak şekilde tasarlanmıştır.

<p align="center">
  <img width="1266" height="585" alt="IMG_9108" src="https://github.com/user-attachments/assets/1e9170e5-5f08-44d5-a34b-366b16e082eb" />
  &nbsp; &nbsp; &nbsp;
  <img width="1266" height="585" alt="IMG_9110" src="https://github.com/user-attachments/assets/b76a1582-c6dd-4b9d-830b-986d2f1f9d5a" />
</p>

* **Gelişmiş Fizik ve Çarpışma Sistemi:** SpriteKit'in fizik motoru kullanılarak piksel hassasiyetinde çarpışmalar, geri tepme (knockback) ve yerçekimi mekanikleri uygulanmıştır.
* **Özel UI / UX Tasarımı:** Modern ana menü tasarımı, oyun içi HUD (can ve mermi takibi) ve oyunu duraklatabilen (Pause) özel katman yönetimi.
* **Pixel Art Optimizasyonu:** Tüm dokular (textures) piksellerin bulanıklaşmasını engellemek için `.nearest` filtreleme modu ile optimize edilmiştir.


## 🛠 Kullanılan Teknolojiler

* **Dil:** Swift
* **Oyun Motoru:** SpriteKit
* **Geliştirme Ortamı:** Xcode
* **Mimari:** Scene Yönetimi (MenuScene -> GameScene), OOP, SKPhysicsBody.

## 🚀 Kurulum ve Çalıştırma

Projeyi kendi bilgisayarınızda derlemek ve çalıştırmak için:

1. Bu depoyu klonlayın:
   ```bash
   git clone [https://github.com/ensarergun/Samurai-Journey.git](https://github.com/ensarergun/Samurai-Journey.git)
2. Klonladığınız klasördeki samuraijourney.xcodeproj dosyasını Xcode ile açın.

3. Hedef cihaz olarak bir iOS Simülatörü veya kendi iPhone'unuzu seçin.

4. Command + R tuşlarına basarak (veya sol üstteki Play butonuna tıklayarak) oyunu derleyip çalıştırın.

🎮 Kontroller
Sol/Sağ Oklar: Karakteri sağa sola hareket ettirir.

Zıplama (▲): Karakteri zıplatır (Çift zıplama desteklenir).

Saldırı (⚔): Yakın dövüş hasarı verir.

Shuriken Fırlatma (★): Menzilli saldırı yapar (Sınırlı mühimmat).

Geliştirici: Ensar Ergun
