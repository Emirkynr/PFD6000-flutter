# BLE & iOS Background Architecture Guide

Bu döküman, Bluetooth Low Energy (BLE) çalışma mantığını, mevcut sisteminizin nasıl çalıştığını ve iOS'te "arka planda uyanma" (background wake-up) özelliğinin nasıl devreye girdiğini açıklar.

## 1. BLE Yayını (Advertising) Nedir?
Bir BLE cihazı (Sizin kapı kartınız/ESP32), telefonun onu görebilmesi için sürekli olarak etrafa "Ben buradayım!" diye sinyal yayar. Buna **Advertisement (Reklam/Yayın)** denir.

Bu yayın paketleri çok küçüktür (Maksimum **31 Byte**). İçinde şunlar olabilir:
1.  **Cihaz Adı:** "Demo Kapi 1"
2.  **Manufacturer Data:** Üreticiye özel veri (Sizin şifreli datanız burada).
3.  **Service UUID:** Cihazın sunduğu hizmetin kimliği (Örn: "Ben bir Kalp Atış Hızı monitörüyüm").

---

## 2. Mevcut Sistem Nasıl Çalışıyor?
Şu anki sisteminizde kapı kartı (ESP32), **Manufacturer Data** alanını kullanıyor.
*   **Yayın:** `0x50 0x54` (Politeknik Header) + `Random Şifre` + `Cihaz Adı`
*   **Flutter Uygulaması:** Çevredeki tüm cihazları tarıyor. Gelen paketlerin içine bakıyor. Eğer `0x50 0x54` ile başlayan bir veri görürse "Hah, bu benim kapım!" diyor ve listeye ekliyor.

**Sorun:** Bu yöntem **sadece uygulama açıkken** (Foreground) mükemmel çalışır. Çünkü işlemci uyanıktır ve gelen her paketi tek tek inceleyebilir.

---

## 3. iOS Arka Plan Sorunu (Background Wake-up)
Uygulama arka plana atıldığında veya telefon kilitlendiğinde, iOS pil tasarrufu için uygulamanızı **uyutur**. Artık kodlarınız çalışmaz, tarama yapamazsınız.

iOS, uygulamayı sadece **çok özel durumlarda** uyandırır. Bluetooth için kural şudur:
> "Eğer bir cihaz, senin `Info.plist` dosyamda belirttiğin **özel bir Service UUID** yayınlıyorsa, seni 10 saniyeliğine uyandırırım."

**Mevcut Durumdaki Engel:**
Sizin kapılarınız şu an bir Service UUID yayınlamıyor. Sadece Manufacturer Data yayınlıyor. iOS, Manufacturer Data'ya bakarak uygulamayı uyandırmayı **desteklemez**. Çünkü bu veriyi analiz etmek işlemci gücü gerektirir ve Apple buna izin vermez.

---

## 4. Çözüm: Service UUID Nedir ve Ne Yapar?
**Service UUID**, bir ehliyet veya pasaport numarası gibidir. 128-bitlik (16 byte) benzersiz bir numaradır.

**Nasıl Çalışacak?**
1.  **ESP32:** Yayınına bu özel numarayı (örn: `4fafc201...`) ekleyecek.
2.  **iOS:** Telefon cebinizde uyurken bile donanım seviyesinde (düşük güç modunda) bu numarayı izleyecek.
3.  **Karşılaşma:** Siz kapıya yaklaştığınızda, Bluetooth çipi bu numarayı havada yakalayacak.
4.  **Uyanış:** iOS, ana işlemciyi dürtüp: *"Hey, senin aradığın `4fafc201...` numaralı cihaz burada! Uygulamayı uyandırıyorum, ne yapacaksan yap"* diyecek.
5.  **Aksiyon:** Uygulamanızın arka plan kodu (`BackgroundScanService`) çalışacak, şifreyi çözecek ve kapıyı açacak.

---

## 5. Teknik Engel ve Çözümü: 31 Byte Limiti

Bir BLE paketi en fazla **31 Byte** veri taşıyabilir.
*   **Service UUID (16 Byte)** + Header (2 Byte) = 18 Byte.
*   **Sizin Şifreli Datanız:** Header (2 Byte) + Şifre (8 Byte) + İsim (10+ Byte) = 20+ Byte.

**İkisi aynı pakete SIĞMAZ (18 + 20 > 31).**

**Çözüm: "Scan Response" (İkinci Paket)**
BLE standardı, cihazın **iki** paket yayınlamasına izin verir:

1.  **Paket 1 (Advertisement Data):**
    *   İçerik: SADECE **Service UUID**.
    *   Amaç: iOS'i uyandırmak. "Ben buradayım, beni tanı!" demek.

2.  **Paket 2 (Scan Response Data):**
    *   İçerik: **Manufacturer Data** (Şifre + İsim).
    *   Amaç: Veriyi taşımak.

**Akış Şöyle Olacak:**
1.  iOS, **Paket 1**'i görür ve uyanır.
2.  Uygulama, "Tamam cihazı gördüm, peki detayları ne?" diyerek **Paket 2**'yi (Scan Response) ister.
3.  ESP32, Paket 2'yi gönderir.
4.  Uygulama şifreyi alır ve kapıyı açar.

Bu yapı sayesinde hem iOS'i reliable (güvenilir) bir şekilde uyandırırız hem de veri kaybı yaşamayız.
