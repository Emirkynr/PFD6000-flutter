# Proje Analizi: PFD6000-flutter (Politeknik BLE Reader)

## 📌 Proje Hakkında
**PFD6000-flutter**, Flutter altyapısı kullanılarak geliştirilmiş, **Politeknik** cihazları ile Bluetooth Low Energy (BLE) üzerinden haberleşmeyi sağlayan bir mobil/masaüstü uygulamasıdır. Uygulamanın görünen adı **"Politeknik BLE Reader"**dır.

## 🛠 Platform ve Teknoloji
*   **Platform:** Flutter (Cross-platform). Kod yapısı Android, iOS, Windows, Linux, macOS ve Web platformlarını destekleyecek şekilde yapılandırılmıştır.
*   **Programlama Dili:** Dart
*   **Ana Kütüphaneler:**
    *   `flutter_reactive_ble`: BLE (Bluetooth) tarama ve bağlantı işlemleri.
    *   `crypto`: Güvenlik ve şifreleme (MD5 algoritması kullanımı).
    *   `shared_preferences`: Yerel veri saklama (örn. son kullanılan kart bilgileri).
    *   `permission_handler`: Bluetooth ve konum izinlerinin yönetimi.

## ⚙️ Nasıl Çalışır?

Uygulama temel olarak 3 ana fazda çalışır:

### 1. Tarama ve Filtreleme (Scanning)
Uygulama açıldığında çevredeki BLE cihazlarını taramaya başlar.
*   **Otomatik Tarama:** Belirli aralıklarla (örn. 15 saniyede bir) taramayı yeniler.
*   **Filtreleme:** Her bulunan cihazı listelemez. Özellikle **Politeknik** cihazlarını tespit etmek için özel filtreler kullanır:
    *   **Raw Data Filtresi:** `0x50` ve `0x54` verisini içeren cihazlar.
    *   **Manufacturer ID:** `80` ve `84` ID'lerine sahip cihazlar.

### 2. Güvenlik ve Doğrulama
Cihaz ile güvenli haberleşmek için dinamik bir şifreleme mekanizması kullanıldığı görülmektedir (`BleManager.dart`):
1.  Cihazın yaydığı `Manufacturer Data` içerisinden rastgele bir sayı veya ID (seed) okunur.
2.  Bu veri `sprintf('Poli%steknik', [rn])` formatında bir metne dönüştürülür.
3.  **MD5** algoritması ile bu metin şifrelenerek 8 byte'lık bir anahtar (password) üretilir.
4.  Bu anahtar, cihaza gönderilen komutların geçerli olması için mesaja eklenir.

### 3. Komut Gönderme ve İşlevler
Kullanıcı arayüzü (`ScannerPage.dart`) üzerinden cihazlara şu komutlar gönderilebilir:

*   **Kapı Açma (Giriş):**
    *   Kayıtlı kart numarasını alır.
    *   **0x00** Flag (Bayrak) ile işaretler.
    *   Şifreyi ekler ve cihaza gönderir.
*   **Kapı Açma (Çıkış):**
    *   Kayıtlı kart numarasını alır.
    *   **0x01** Flag (Bayrak) ile işaretler.
    *   Şifreyi ekler ve cihaza gönderir.
*   **Kart Konfigürasyonu:**
    *   Cihaza bağlanarak okutulan kartın numarasını (UID) okur ve uygulamaya kaydeder (`CardManager`).
    *   Bu kart numarası sonraki giriş/çıkış işlemlerinde kullanılır.

## 📂 Kod Yapısı
*   **`lib/main.dart`**: Uygulamanın giriş noktası.
*   **`lib/ui/scanner_page.dart`**: Ana ekran. Cihaz listesi, tarama durumu ve komut butonlarının olduğu yer.
*   **`lib/ble/ble_manager.dart`**: BLE işlemlerinin kalbi. Tarama, filtreleme ve MD5 şifre üretimi mantığı burada bulunur.
*   **`lib/ble/ble_service.dart`**: Cihazla bağlantı kurma ve ham byte verilerini yazma/okuma servisleri.

## 📝 Özet
Bu proje, yetkili kart bilgilerini kullanarak, belirli algoritmalara (MD5) göre kimlik doğrulaması yapan ve çevredeki uyumlu donanımlara (kapı, turnike vb.) güvenli bir şekilde **"Aç/Giriş Yap"** veya **"Çıkış Yap"** komutu gönderen bir mobil terminal uygulamasıdır.
