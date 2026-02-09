# ENKA GS (V2) - AI Geliştirme Konteksti ve Mimari

Bu belge, **ENKA GS** (eski adıyla PFD6000-Flutter V2) projesini geliştirecek yapay zeka modelleri (AI Assisants) için özel olarak hazırlanmıştır. Projenin teknik altyapısını, kritik iş mantığını, son yapılan değişikliklerin **neden** yapıldığını ve **nasıl** devam edilmesi gerektiğini açıklar.

## 1. Proje Kimliği ve Amaç
*   **Uygulama:** ENKA GS (Gate Security)
*   **Amaç:** BLE (Bluetooth Low Energy) üzerinden turnike ve kapı geçiş sistemlerini kontrol etmek (Giriş/Çıkış/Konfigürasyon).
*   **Hedef Kitle:** Saha personeli ve güvenlik görevlileri.
*   **Teknoloji:** Flutter (Dart), `flutter_reactive_ble`, `provider` (veya `ListenableBuilder` ile state yönetimi).

## 2. Kritik İş Mantığı (Business Logic) ⚠️ DOKUNMA!

Bu bölümdeki mantık, donanım (ESP32 tabanlı kart okuyucu) ile uyumluluk açısından kritiktir. **Gerekli olmadıkça değiştirmeyin.**

### 2.1. BLE Komut Yapısı (`message_sender.dart`)
Cihaza gönderilen her veri paketi şifrelidir ve şu yapıdadır:
`[Başlangıç (16 byte)]` + `[Kart No (16/32 byte)]` + `[YÖN FLAG (1 byte)]` + `[Cihaz Şifresi (8 byte)]`

*   **Giriş Yap (Entry):** Yön flag'i **`0x00`** gönderilir.
*   **Çıkış Yap (Exit):** Yön flag'i **`0x01`** gönderilir. (V2 arayüzünde buton gizli olsa da kodda desteklenir).
*   **Konfigürasyon:** Kart tanımlamak için kullanılan özel bir mod (`configCommand`).

### 2.2. Dinamik Şifreleme (`device_filter.dart`)
Her tarama döngüsünde cihazdan gelen `Manufacturer Data` (Raw Data) analiz edilir.
*   Bu datadan **Cihaz Adı** ve **Cihaz Şifresi** dinamik olarak çıkarılır.
*   Çıkarılan şifre, komut paketinin sonuna eklenerek yetkilendirme sağlanır.

## 3. V2 Tasarım Felsefesi (Neden Böyle Yaptık?)

Son yapılan değişiklikler (V2), kullanıcı deneyimini basitleştirmek ve kurumsal kimliği güçlendirmek amacıyla yapılmıştır.

### 3.1. Minimalizm
*   **Eski:** RSSI değeri, Cihaz ID'si, Raw Data gibi teknik veriler ekranda kalabalıktı.
*   **Yeni:** Sadece **Cihaz Adı** ve **Durum (HAZIR/BAĞLI)** gösteriliyor.
*   **Neden:** Kullanıcı teknik personel olmayabilir; sadece kapıyı açmak istiyor.

### 3.2. Marka Kimliği (ENKA)
*   **Renk:** `#002A5C` (ENKA Mavisi) tüm uygulamaya hakim. (Eski `#1976D2` Politeknik mavisi kodda `comment-out` olarak saklanıyor).
*   **Logo:** Splash screen ve Drawer header'da orijinal ENKA logoları kullanılıyor.
*   **Splash Screen:** Sıralı animasyon (ENKA -> Politeknik) ile marka hiyerarşisi sağlandı.
*   **Header:** Logo yerine, okunaklılığı artırmak için **Bold "ENKA"** yazısına dönüldü.

### 3.3. Animasyonlar
*   **Bluetooth İkonu:** `DeviceListTile` içinde sürekli "nefes alan" (pulsing) dev bir ikon var.
*   **Neden:** Uygulamanın canlı olduğunu hissettirmek ve etkileşimi artırmak için.

## 4. Mimari Kararlar ve Dosya Yapısı

### 4.1. Katmanlı Yapı
*   `lib/ble/`: Sadece Bluetooth iletişiminden sorumlu (Service/Manager). UI'dan bağımsızdır.
*   `lib/ui/`: Sadece görsel bileşenler.
*   `lib/theme/`: Tema tanımları (`AppTheme`) ve state (`ThemeProvider`) buradadır.

### 4.2. State Yönetimi
*   `ScannerPage`, bir `StatefulWidget`'tır ancak karmaşık child widget'lar (ör: `DeviceListTile`) kendi animasyon controller'larına (State) sahiptir.
*   Tema değişimi (`ThemeProvider`) globaldir ve `main.dart` üzerindeki `ListenableBuilder` ile tüm ağacı günceller.

## 5. Gelecek Geliştirmeler İçin Notlar (AI'ya Talimatlar)

1.  **iOS Geçişi:** Proje şu an Android odaklıdır ancak iOS (`Info.plist`, `Podfile`) temelleri atılmıştır. Mac ortamında derlenirken izinlere dikkat edilmeli.
2.  **Hata Yönetimi:** BLE bağlantısı koptuğunda kullanıcıya daha detaylı geri bildirim (SnackBar yerine belki bir dialog veya banner) eklenebilir.
3.  **Performans:** `ScannerPage` içinde timer'lar (`_scanAutoStopTimer`) kaynak tüketimini önlemek için `dispose` edilmelidir. Yeni özellik eklerken buna dikkat et.
4.  **Kod Temizliği:** `unused_import` ve gereksiz değişkenler (Lint uyarıları) düzenli temizlenmeli.

## 6. Özet Komutlar
*   **Android Build:** `flutter build apk --release`
*   **iOS Build (Mac):** `flutter build ios --release` (veya Xcode üzerinden Archive)

Bu belgeyi okuyan AI asistanı, projenin **neyi, neden ve nasıl** yaptığını anlayarak doğrudan geliştirmeye başlayabilir.
