# BLE Bağlantı Hızı Optimizasyon Planı (Connection Speed Plan)

Bu belge, kapı açma süresini milisaniyeler seviyesine indirmek için kullanılacak yazılımsal Bluetooth (BLE) optimizasyon tekniklerini içerir. Optimizasyonlar detayları incelenmek üzere listelenmiştir.

**Gelecekteki Asistan (Bana) Not:** Kullanıcı *"prompts klasöründeki ble_connection_speed_plan.md dosyasını çekip bana detaylarını anlat ve seçtiklerimi uygula"* dediğinde, bu belgedeki maddeleri iOS ve Android farklılıklarını belirterek açıkla. Kullanıcı "Sadece 1 ve 3'ü yap" gibi bir numara verdiğinde, sadece o numaralara ait özellikleri `BleManager` veya `BleService` kodlarına entegre et.

## Optimizasyon Maddeleri (Seçilebilir)

### 1. Taramayı Anında Durdurma (Stop Scan Before Connect)
*   **Platform:** iOS ve Android (Ortak)
*   **Detay:** Hedef MAC adresi veya cihaz bulunduğu an, bağlanma komutu verilmeden milisaniyeler önce BLE Radyo taraması durdurulmalıdır (`_ble.stopScan()`). Her iki platformda da radyo frekansı boşa çıktığı için bağlantı el sıkışması (handshake) ciddi şekilde hızlanır.

### 2. Yüksek Öncelikli Bağlantı (High Priority Connection)
*   **Platform:** Sadece Android
*   **Detay:** Android'in pil tasarrufu için uyguladığı yavaş Bluetooth paket gönderimini iptal eder. Koda `connectionPriority: ConnectionPriority.high` eklenerek Android'in tüm işlemci/radyo gücünü anlık olarak bu bağlantıya vermesi sağlanır. *(iOS bu ayarı sistem seviyesinde Apple'ın kapalı kurallarıyla otomatik yönettiğinden iOS için bir ayar yoktur/geçersizdir).*

### 3. Cevap Beklemeden Yazma (Write Without Response)
*   **Platform:** iOS ve Android (Ortak)
*   **Detay:** Kapıya şifre/veri gönderirken `writeCharacteristic` komutunun ACK (Acknowledgement - Alındı Teyidi) beklemeyen versiyonu kullanılır. Telefon şifreyi havaya ateşler ve ESP32'nin "geldi" demesini beklemez. Ping ve gecikme süresini (Latency) yarı yarıya düşüren en agresif yöntemdir. *(Not: ESP32'nin Characteristic ayarlarında `WRITE_NR` - Write No Response özelliği açık olmalıdır).*

### 4. Servis Keşfini Atlama / Kör Yazış (Blind Write / Skip Service Discovery)
*   **Platform:** iOS ve Android (Kısmen Ortak)
*   **Detay:** Normalde telefonlar cihazın hangi hizmetleri olduğunu öğrenmek için 1 saniye kadar "Liste İsteği" (Service Discovery) yapar. Biz hedefin (ESP32) UUID'lerini sabit olarak bildiğimiz için bu sorgulamayı atlayıp paketleri körlemesine yollamayı (Cache üzerinden yazmayı) deneyebiliriz.
*   **OS Farkı:** iOS bu listeyi otomatik önbelleğe alır (Cache) ve kendi hızlandırır. Ancak Android'de her bağlantıda sıfırdan keşif yapma huyu vardır. Eğer `flutter_reactive_ble` izin verirse direkt hedefe paket sıkılarak zaman kazanılır.

## Sonuç / İş Akışı Özeti
1. Asistan, kullanıcı talep ettiğinde bu listeyi platform özetleriyle sunar.
2. Kullanıcı uygulanmasını istediği MADDELERİN NUMARASINI verir.
3. Asistan seçilen optimize kodlarını `BleService.dart` içine yazar.
