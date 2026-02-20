# iBeacon Teknolojisi ve Projeye Entegrasyonu

## 1. iBeacon Nedir?
iBeacon, Apple tarafından geliştirilen ve Bluetooth Low Energy (BLE) kullanan bir konumlandırma protokolüdür. Temel amacı, cihazların (telefonların) belirli bir fiziksel konuma (örneğin bir kapıya) ne kadar yakın olduğunu çok hassas ve pil dostu bir şekilde anlamasını sağlamaktır.

Bir iBeacon yayını (Advertisement) standart BLE yayınından farklı olarak şu 3 temel bilgiyi içerir:
*   **UUID (Universally Unique Identifier):** Şirketinizin veya projenizin genel kimliği (Örn: Politeknik Kapı Sistemleri).
*   **Major Değeri:** Belirli bir grubu temsil eder (Örn: A Binası).
*   **Minor Değeri:** O gruptaki spesifik cihazı temsil eder (Örn: A Binasındaki Zemin Kat Kapısı).

## 2. iBeacon'ın Mevcut Sisteme (BLE Service UUID) Göre Faydaları

Şu anki planımızda iOS'i arkaplanda uyandırmak için ESP32'ye **Service UUID** ekliyoruz ve `CoreBluetooth` kullanıyoruz. Ancak iBeacon (`CoreLocation` kullanır) bazı eşsiz avantajlar sunar:

### A. Kusursuz Arkaplan (Background) Çalışması (App "Kill" Edilse Bile)
Apple, iBeacon protokolüne işletim sistemi seviyesinde devasa ayrıcalıklar tanır.
*   **Mevcut Durum (BLE Service UUID):** Uygulama arkaplandayken (background) kapıyı görüp uyanabilir. Ancak kullanıcı uygulamayı çoklu görev ekranından (App Switcher) yukarı kaydırıp **tamamen kapatırsa (kill/terminate)**, BLE taraması durur ve yanına gelse bile kapıyı açmaz.
*   **iBeacon ile:** Uygulama tamamen kapatılmış (kill edilmiş) olsa bile, donanımsal Bluetooth çipi iBeacon bölgesine (Region) girdiğinizi algılar ve iOS **uygulamanızı kapalıyken bile gizlice başlatır**. (Kilitli kapıya yaklaştığınızda %100 uyanma garantisi verir).

### B. Hassas Mesafe Ölçümü (Ranging)
iBeacon, cihazın kapıya olan uzaklığını 3 kategoride çok net verir:
*   `Immediate` (Çok Yakın: 0 - 0.5 metre -> **Kapıyı Aç**)
*   `Near` (Yakın: 0.5 - 3 metre)
*   `Far` (Uzak: 3+ metre)
Normal BLE RSSI (Sinyal Gücü) değerleri çok dalgalanırken, iBeacon algoritması işletim sistemi seviyesinde filtreleme yaparak daha kararlı bir mesafe sunar.

## 3. Sisteme Nasıl Entegre Edilir?

Bu entegrasyonu yapmak için hem ESP32 hem de Flutter tarafında değişiklik gerekir. İkili bir yapı kurulur:

### A. Donanım Tarafı (ESP32)
ESP32'nin standart yayın (Advertisement) paketi yerine veya ona ek olarak iBeacon formatında yayın yapması gerekir.
ESP32 normal BLE datası (şifre vs.) ile iBeacon paketini **dönüşümlü olarak (interleaved advertising)** havaya gönderebilir.

### B. Mobil Uygulama Tarafı (Flutter)
Şu an kullandığımız `flutter_reactive_ble` kütüphanesi standart BLE içindir, iBeacon'un iOS tasarımlı "Bölge İzleme" (Region Monitoring) yeteneklerini tam anlamıyla kullanamaz. 
Flutter tarafında `flutter_beacon` gibi konum bazlı çalışan bir paket de projeye dahil edilir.

**Çalışma Döngüsü:**
1.  Uygulama iBeacon üzerinden sizin UUID'nizi "Monitor" eder (dinler).
2.  Kullanıcı kapının menziline girince (Region Entry), uygulama donanım tarafından uyandırılır.
3.  Uygulama uzaklık (Ranging) kontrolü yapar. Eğer uzaklık `Immediate` ise (kullanıcı kapı dibine gelmişse):
4.  Uygulama standart BLE yeteneğiyle (`flutter_reactive_ble`) kapıya bağlanıp şifreli "AÇ" komutunu gönderir.

## 4. Dezavantajları Nelerdir?

*   **İzin Yükü (Permissions):** iBeacon bir "Konum Teknolojisi" sayıldığı için kullanıcılardan Bluetooth izninin yanında **"Konum (Her Zaman)" (Location Always)** izni almanız gerekir. Kullanıcılar konum izni vermekten çekinebilir.
*   **Bağlantı Kurulamaması:** iBeacon formatı tek yönlüdür ("Ben buradayım" der). Karşılıklı veri alışverişi (şifre göndermek) için mutlaka yine standart BLE bağlantısına ihtiyaç duyulur. Yani iBeacon mevcut sistemi çöpe atmaz, sadece iOS'u **tetiklemek (uyandırmak)** için bir "katalizör" olarak kullanılır.
*   **Android Tarafı:** Android işletim sistemi iBeacon'a özel (CoreLocation gibi) %100 uyanma garantisi veren yapılı bir işletim sistemi desteği sunmaz. Mevcut arkaplan izleme sistemi aynı şekilde çalışmaya devam eder.

## Özet ve Tavsiye

Eğer mevcut "Service UUID" çözümünüz ***"Kullanıcı uygulamayı ekranı kaydırarak tamamen kapatırsa kapı açılmıyor, uygulama illaki arkada açık kalmalı"*** şeklinde haklı bir müşteri şikayeti yaratırsa, "VIP/Kusursuz" bir deneyim için **iBeacon** mimarisine geçiş yapılmalıdır. 

İlk etapta donanım ekibi Service UUID ile "Scan Response" mimarisini kurmalı, iOS tetiklemeleri "uygulama arka plandayken" başarıyla test edildikten sonra (Gerekirse B Planı olarak) iBeacon eklentisi masaya yatırılmalıdır.
