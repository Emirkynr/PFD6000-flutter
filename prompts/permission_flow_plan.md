# İzin ve Uyarı Mantığı Uygılama Planı (Permission Flow Plan)

Bu belge, uygulamanın donanım ve işletim sistemi izinlerini (Bluetooth, Konum, Bildirim, Pil Optimizasyonu) nasıl yöneteceğini ve son kullanıcıya nasıl uyarı (prompt) göstereceğini adım adım tanımlar.

**Gelecekteki Asistan (Bana) Not:** Kullanıcı *"prompts klasöründeki permission_flow_plan.md planını uygula"* dediğinde, bu belgedeki tüm maddeleri eksiksiz olarak koda dök.

## 1. Uygulama Açılışında (App Startup) Yapılacak Kontroller

Uygulamanın `main.dart` veya kök widget'ında (splash veya home init) her açılışta şu senaryolar test edilmelidir:

### A. Bluetooth Kapalı Kontrolü
*   **Aksiyon:** Uygulama açıldığında cihazın Bluetooth'unun açık olup olmadığı kontrol edilecek (`flutter_reactive_ble` veya `flutter_blue_plus` yardımıyla).
*   **Prompt (Uyarı):** Eğer kapalıysa, kullanıcıya *"Kapıları açabilmek için Bluetooth'u açmanız gerekmektedir"* şeklinde bir Dialog/Snackbar gösterilecek ve sistem Bluetooth ayarları açılacak/tetiklenecek.

### B. Tutarlılık Kontrolü (Ayarlar vs. Sistem İzinleri)
Kullanıcının uygulama içi ayarları (Örn: `SharedPreferences` ile tutulan `isNotificationEnabled`) ile işletim sisteminin gerçek izin durumu (OS Level Permission) çapraz olarak kontrol edilecek.

*   **Bildirim Senaryosu:** 
    *   Eğer uygulama içi `isNotificationEnabled = true` ise,
    *   **VE** işletim sistemi seviyesinde Bildirim izni geri alınmışsa (PermissionStatus.denied),
    *   **Uyarı:** *"Ayarlarda bildirim gönderme açık görünüyor ancak sistem bildirim izni kapalı. Düzeltilmeli"* promptu çıkacak ve ayarlara yönlendirecek.
*   **Arkaplan Konum / BLE Senaryosu:**
    *   Eğer "Arkaplanda tarama / Otomatik Açma" özelliği aktifse,
    *   **VE** "Her Zaman Konum İzleme (Location Always)" izni verilmemişse,
    *   **Uyarı:** *"Otomatik açma için konum izninin 'Her Zaman' olması gerekir"* denilecek.

## 2. Pil Tasarrufu (Battery Optimization) Sayfası Yönlendirmesi

Bu konu **uygulama açılışında DEĞİL**, Ayarlar sayfasında yapılacaktır.

*   **Aksiyon:** Ayarlar sayfasında "Arkaplanda Otomatik Aç" veya benzeri bir toggle (anahtar) açıldığı anda tetiklenecektir.
*   **Prompt (Uyarı):** Toggle açılır açılmaz: *"Arkaplanda otomatik açma özelliğinin kusursuz çalışması için Android Pil Optimizasyonunu kapatmanız (Sınırsız / Unrestricted yapmanız) gereklidir."* uyarısı çıkacak.
*   **İşlev:** Kullanıcı "Tamam" dediğinde doğrudan Android'in o uygulamaya özel "Pil Optimizasyonu" sayfasına (Request Ignore Battery Optimizations) yönlendirilecek (bunun için `permission_handler` paketindeki `requestIgnoreBatteryOptimizations` metodu kullanılabilir).

## 3. Platformlara Özel İzin Metinleri (Manifest & Info.plist)

Kodlamaya başlamadan önce veya sırasında işletim sistemi dosyaları güncellenecektir:

### A. iOS (Info.plist)
Apple izin metinlerine çok dikkat eder. Şu keyler doldurulacak (Zaten eklendiyse kontrol edilecek):
*   `NSBluetoothAlwaysUsageDescription`: "Yakınınızdaki kapı kilitleriyle iletişim kurmak ve kapıları açmak için Bluetooth erişimi gereklidir."
*   `NSLocationAlwaysAndWhenInUseUsageDescription` / `NSLocationWhenInUseUsageDescription`: (Eğer iBeacon/Arkaplan tetikleme için gerekiyorsa) "Arka planda dahi olsanız, kapıya yaklaştığınızı tespit edip otomatik açabilmemiz için konum iznine ihtiyacımız var."

### B. Android (AndroidManifest.xml)
*   Android 12+ (API 31+) için: `BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN` izinleri.
*   Konum için: `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION` (Android 10+ otomatik arka plan için).
*   Arkaplanda başlatma / Pil optimizasyon kırma izinleri (gerekirse).

## Sonuç / İş Akışı Özeti
1. Uygulama açılır -> BT açık mı bakar -> Değilse prompt.
2. Uygulama açılır -> İzinler ile Ayarlar senkronize mi (Bildirim, BT) bakar -> Bozuntu varsa prompt.
3. Ayarlar sayfasına gidilir -> Arkaplan/Otomatik Aç toggle'ı açılır -> Sadece O AN Android Pil prompt'u çıkar.
