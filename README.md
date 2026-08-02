# 🎙️ Voice Studio — Smart iOS Voice Note & AI Songwriter Assistant

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat&logo=swift)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0%2B-blue.svg?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Framework-purple.svg?style=flat&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![Google Gemini AI](https://img.shields.io/badge/Google_Gemini-1.5_Flash-8E75FF.svg?style=flat&logo=google)](https://aistudio.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Voice Studio**, iOS platformı için özel olarak geliştirilmiş modern, estetik ve yapay zeka destekli bir **Sesli Not, Dikte ve AI Şarkı Besteleme Asistanıdır**. 

Kullanıcıların sesli konuşmalarını anında canlı metne dönüştürür, Google Gemini 1.5 Flash ile otomatik özet çıkarır ve fikirlerinizden ritmik **şarkı sözleri ile beste taslakları** oluşturur.

---

## ✨ Öne Çıkan Özellikler

### 🎙️ 1. Canlı Ses Kayıt Stüdyosu & Dikte
- **Canlı Metin Dökümü:** `AVFoundation` ve `Speech` çerçeveleri ile konuşmaları anlık olarak metne çevirir.
- **Canlı Ses Dalgası (Waveform Visualizer):** Ses seviyesine göre dinamik olarak şekillenen ve taşmayı önleyen downsampled renkli ses görselleştiricisi.
- **Hızlı Kategori Seçimi:** *Genel, Toplantı, Fikir, Kişisel, Ders* ve *Şarkı / Beste*.

### 🤖 2. Google Gemini 1.5 Flash AI Entegrasyonu
- **Otomatik Türkçe Özetler:** Uzun konuşmaları saniyeler içinde net özet satırlarına dönüştürür.
- **Aksiyon Maddeleri (Task List):** Konuşmadaki yapılacak işleri otomatik olarak madde işaretli görev kartları halinde listeler.
- **Yerel Yedek Modu:** İnternet veya API anahtarı olmasa dahi akıllı yerel döküm motoru ile çalışmaya devam eder.

### 🎵 3. AI Şarkı & Beste Üretici Modu (Songwriter Studio)
- **Akıllı Beste Motoru:** Mikrofona söylediğiniz herhangi bir konudan veya fikirden anında **Şarkı İsmi, Müzik Tarzı (Pop, Akustik, Rock), Giriş, Kıtalar, Nakarat ve Çıkış** bölümlerini besteler.
- **Ritim ve Vokal Tavsiyeleri:** Şarkı temposu (BPM) ve vokal tarzına dair öneriler sunar.
- **🎵 Şarkı Sözünü Dinle:** Şarkı sözlerini melodik vokal sentezleyici ile sesli dinleme imkanı.

### 🎨 4. Modern Dark Glassmorphism Tasarım Sistemi
- Mor ve siyan neon ambiyans auraları, canlı buzlu cam (glassmorphism) kartları ve akıcı iOS animasyonları.
- Dairesel dokunma titreşimli (bouncy) butonlar ve özelleştirilmiş başlık kartları.

### ⚙️ 5. Kullanıcı Odaklı Ayarlar & Kişiselleştirme
- **Kişiselleştirilmiş Karşılama:** `"Hoş Geldin, Ahmet 👋"` *(Kullanıcı kendi ismini düzenleyebilir)*.
- **Dikte Dili Seçimi:** Bayraklı hızlı dil seçimi (🇹🇷 Türkçe, 🇺🇸 İngilizce).
- **Hesap & Tercihler:** Uygulama bildirimleri, ses kalitesi (HQ/Standart) ve şifre değiştirme modalları.

---

## 🛠️ Teknoloji Yığını & Mimari

| Bileşen | Kullanılan Teknoloji |
| :--- | :--- |
| **Kullanıcı Arayüzü** | SwiftUI (Swift 6 Strict Concurrency) |
| **Yapay Zeka Motoru** | Google Gemini 1.5 Flash REST API |
| **Ses Kayıt & Çalma** | AVFoundation (`AVAudioRecorder`, `AVAudioPlayer`) |
| **Ses Tanıma (STT)** | Speech Framework (`SFSpeechRecognizer`) |
| **Metin Seslendirme (TTS)** | AVFAudio (`AVSpeechSynthesizer`) |
| **Tasarım & Mimari** | MVVM / `@Observable`, Glassmorphic UI System |

---

## 🚀 Kurulum ve Çalıştırma

### Gereksinimler
- **macOS Sonoma** (v14.0) veya üzeri
- **Xcode 15.0** veya üzeri
- **iOS 17.0+** Cihaz veya Simülatör

### Adımlar

1. Depoyu bilgisayarınıza klonlayın:
   ```bash
   git clone https://github.com/52BaranHaydar/Voice.git
   cd Voice
   ```

2. Projeyi Xcode ile açın:
   ```bash
   open Voice/Voice.xcodeproj
   ```

3. Simülatör veya fiziksel iOS cihazınızı seçip **⌘ + R** tuşlarına basarak projeyi çalıştırın.

4. *(Opsiyonel)* Gelişmiş Gemini AI özelliklerini kullanmak için uygulama içi **Ayarlar** sekmesinden [Google AI Studio](https://aistudio.google.com) üzerinden ücretsiz aldığınız API anahtarını tanımlayabilirsiniz.

---

## 📜 Lisans

Bu proje [MIT Lisansı](LICENSE) altında lisanslanmıştır. Portfolyo ve geliştirme amaçlı özgürce kullanılabilir.

---

<p center="center">
  <b>Voice Studio</b> — Developed with ❤️ using SwiftUI & Google Gemini AI.
</p>
