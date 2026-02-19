# Uygulama Teslim ve Yayınlama Rehberi (Kaynak Kodsuz)

Bu rehber, geliştirdiğin Flutter uygulamasını, **kaynak kodlarını (source code) paylaşmadan** patronuna veya yayıncıya nasıl teslim edeceğini anlatır.

## 1. Temel Mantık: "Derlenmiş Dosya"
Flutter uygulamaları, web siteleri gibi (HTML/JS) "açık" değildir. **AOT (Ahead-of-Time)** teknolojisi ile makine diline (binary) derlenir. Yani oluşturacağın çıktı dosyasını alan kişi, içini açıp kodlarını **göremez**.

Ancak, "Reverse Engineering" (Tersine Mühendislik) ile kodların bazılarının (değişken isimleri vb.) anlaşılmasını zorlaştırmak için **Obfuscation (Karartma)** tekniğini kullanacağız.

---

## 2. Android İçin Teslimat (`.aab`)

Android tarafında Google Play Store'a yüklemek için **App Bundle (.aab)** formatı kullanılır.

### Adım 1: Karartmalı Derleme (Obfuscation)
Terminalde şu komutu çalıştırarak uygulamanı derle:

```bash
flutter build appbundle --obfuscate --split-debug-info=./obfuscation_maps
```

*   `--obfuscate`: Fonksiyon ve değişken isimlerini "a, b, c" gibi anlamsız harflere çevirir. Kodu okumayı imkansızlaştırır.
*   `--split-debug-info`: Hata ayıklama sembollerini ayrı bir klasöre (`obfuscation_maps`) çıkarır, bu klasörü **kendine sakla**, kimseye verme.

### Adım 2: Dosyayı Bul ve Teslim Et
Derleme bittiğinde terminal sana dosya yolunu söyleyecektir. Genellikle şuradadır:
`[Proje Klasörü]/build/app/outputs/bundle/release/app-release.aab`

👉 **Patrona Vereceğin Dosya:** `app-release.aab`
*Bu dosyayı Google Play Console'a sürükleyip bırakarak yayınlayabilir.*

---

## 3. iOS İçin Teslimat (`.ipa`)

iOS tarafında App Store'a yüklemek için **.ipa** dosyası oluşturulur.

### Adım 1: Hazırlık (Xcode)
1.  Projeni Xcode ile aç: `open ios/Runner.xcworkspace`
2.  Üst menüden cihaz olarak **"Any iOS Device (arm64)"** seç.
3.  Menüden **Product > Archive** seçeneğine tıkla.

### Adım 2: Archive & Export
Derleme bitince "Organizer" penceresi açılır:
1.  Oluşan arşivin üzerine tıkla ve **"Distribute App"** de.
2.  **"App Store Connect"** -> **"Export"** seçeneğini seç.
3.  Sertifika işlemlerini geçtikten sonra Xcode sana bir klasör verecek.

👉 **Patrona Vereceğin Dosya:** Bu klasörün içindeki `.ipa` uzantılı dosya.
*Patronun bu dosyayı "Transporter" uygulamasını kullanarak App Store'a yükleyebilir.*

---

## Özet Tablo

| Platform | Teslim Edilecek Dosya | Ne İşe Yarar? | Güvenlik |
| :--- | :--- | :--- | :--- |
| **Android** | `app-release.aab` | Play Store'a yüklenir. | Yüksek (Obfuscated) |
| **iOS** | `Runner.ipa` | App Store'a yüklenir. | Yüksek (Compiled Native) |
| **Kaynak Kod** | `lib/`, `ios/`, `android/` | **ASLA VERME** | - |

---

## 4. Yayın Öncesi "Eksiksiz Teslimat" Kontrol Listesi

Patronuna dosyaları atmadan önce, uygulamanın "Red Yememesi" için şu maddelerin **TAMAM** olduğundan emin olmalısın.

### A. Görsel Kimlik
*   [ ] **Uygulama İkonu:** Ekranda görünen ikon (App Icon) doğru mu? (Varsayılan Flutter ikonu kalmasın!)
*   [ ] **Açılış Ekranı (Splash):** Uygulama açılırken markanın logosu görünüyor mu?
*   [ ] **İsim:** Telefon ekranında uygulamanın adı doğru yazıyor mu? (Örn: "Poli Kapı" yerine "pfd6000" yazmasın).

### B. İzinler ve Gizlilik (Apple Çok Hassastır!)
*   [ ] **Bluetooth İzni:** `Info.plist` dosyasındaki açıklama net mi?
    *   *Doğru Örnek:* "Kapı kilitlerini açmak için Bluetooth kullanırız."
    *   *Yanlış Örnek:* "Bluetooth izni ver."
*   [ ] **Konum İzni:** (Eğer kullanıyorsan) Neden gerektiğini net açıkladın mı?

### C. Teknik Ayarlar (Benzersizlik)
*   [ ] **Bundle ID / Package Name:** `com.example.pfd6000` gibi varsayılan bir isimle markete yükleyemezsin. Kendi domaininize uygun olmalı (Örn: `com.politeknik.kapi`).
*   [ ] **Versiyon:** `pubspec.yaml` dosyasındaki versiyonu her güncellemede artırmalısın (1.0.0 -> 1.0.1).

### D. İmzalama (Signing)
*   **Android:** `key.jks` dosyasını oluşturup projeye tanıttın mı? (Bu olmadan Play Store kabul etmez).
*   **iOS:** Xcode'da "Signing & Capabilities" sekmesinde Patronun **"Development Team"** hesabı seçili mi?

### E. Patron İçin Ekstra Paket (Metadata)
Sadece `.aab` ve `.ipa` yetmez, mağaza için şunları da ayrı bir klasörde vermelisin:
1.  **Ekran Görüntüleri:** (App Store için iPhone 6.5" ve 5.5" boyutlarında).
2.  **Gizlilik Politikası Linki:** (Bir web sayfasında "Bluetooth verilerini saklamıyoruz" yazan bir metin).
3.  **Uygulama Açıklaması:** (Mağazada görünecek tanıtım yazısı).
