# BLE Bağlantı Çarpışma Çözümü (Random Jitter & Retry Plan)

Bu belge, birden fazla cihazın aynı anda akıllı kapıya (ESP32) bağlanmaya çalışması durumunda oluşacak "Collision" (Çarpışma / Darboğaz) sorununu çözmek için yazılacak Flutter kodlarının mimarisini tanımlar.

**Gelecekteki Asistan (Bana) Not:** Kullanıcı *"prompts klasöründeki ble_connection_queue_plan.md planını uygula"* dediğinde, `BleService` içindeki bağlantı (connectToDevice) metodunu bu mantığa göre güncelle.

## 1. Temel Sorun (Problem Definition)
Eğer A ve B telefonları aynı anda kapıya bağlanmaya çalışırsa (veya ESP32 o an meşgulse), telefonlardan biri (veya ikisi) GATT Error / Connection Timeout alır. Kullanıcının kapıda kalmaması için arka planda "çaktırmadan" yeniden deneme mekanizması (Retry with Jitter) kurulmalıdır.

## 2. Uygulanacak Mimari: Rastgele Gecikmeli Yeniden Deneme (Randomized Jitter)
Bağlantı işlemi direkt bir `connect` fonksiyonu yerine sağlam bir "Retry (Yeniden Deneme)" bloğunun içine alınacaktır.

### Kodlama Kuralları:
1.  **Maksimum Deneme Sayısı (Max Retries):** Arka planda maksimum **3 veya 4** defa denenmeli. Eğer 4. denemede de açılamazsa kullanıcıya "Kapı şu an meşgul, lütfen tekrar deneyin" uyarısı verilmelidir.
2.  **Temel Bekleme (Base Delay):** İlk hata vzalındığında en az **500 milisaniye (0.5 saniye)** beklenmelidir. (Çünkü donanımın kendini toparlaması yarım saniye sürer).
3.  **Rastgele Zıplama (Random Jitter):** Temel beklemenin üzerine `0 ile 400 milisaniye` arasında rastgele (*Random().nextInt(400)*) bir süre eklenmelidir.
    *   *Örnek:* A telefonu hata aldı -> 500 + 120 = 620ms bekler.
    *   *Örnek:* B telefonu hata aldı -> 500 + 350 = 850ms bekler.
    *   **Sonuç:** Kesinlikle aynı anda tekrar çarpışmazlar. Biri diğerinden önce bağlanıp işini bitirir.

### 3. Donanım (ESP32) Ön Gereksinimi (Hatırlatma)
Bu kodların çalışması için ESP32'nin **"Vur-Kaç (Hit & Run)"** taktiğiyle kodlanması gerekir.
*   ESP32 şifreyi doğrulayıp kilidi açtığı **MİLİSANİYE içinde**, aktif bağlantıyı **koparmalıdır (Disconnect)**. 
*   Böylece ESP32 hemen boşa çıkar ve bizim yazdığımız mobil (Flutter) uygulamanın 620ms sonraki "Yeniden Deneme (Retry)" isteğini anında kabul edip sıradaki adamı içeri alır.

## Sonuç / İş Akışı Özeti
*   Kullanıcı kapıya yaklaşır -> Cihaz bağlanmayı dener.
*   ESP32 başkası yüzünden meşgul ise (Hata döner):
*   Flutter `catch` bloğu hatayı yutar (UI'a yansıtmaz) -> `await Future.delayed(Duration(milliseconds: 500 + Random().nextInt(400)))` çalışır.
*   Tekrar dener ve bu kez yüksek ihtimalle hatta girip kapıyı açar.
