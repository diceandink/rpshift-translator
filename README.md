# RPShift Translator 

![RPShift Logo](logo.png)

**[English](#english) | [Türkçe](#türkçe)**

---

<a id="english"></a>
## 🇺🇸 English

### Overview
**RPShift Translator** is an advanced translation tool designed specifically for roleplayers (GTA V RP, text-based RPGs) and power users. Unlike standard translators, it goes beyond literal meaning: it can convert Turkish text into **natural, context-aware American slang** suited for your character's personality.

Powered by **DeepL** (for precision) and **Groq AI** (for style/slang).

###  Features
- **4 Translation Modes**:
    1. **Groq Only (Direct)**: Fast AI translation.
    2. **Groq Slang (Recommended)**: Translates & slangifies in one go.
    3. **DeepL Only (Recommended)**: Professional, exact translation.
    4. **DeepL + Groq Slang**: DeepL for meaning + Groq for style.
- **Modern Dark GUI**: A tracking window that shows you the original text, raw translation, and final result.
- **Smart Hotkeys**: Rebind your trigger key instantly from the menu.
- **Auto-Paste**: The result is automatically typed into your game/chat window.
- **Bypass**: If you type `/` before your text (e.g. `/me walks`), it skips slangification to preserve commands.

###  Installation Guide

#### 1. Install AutoHotkey v2
This script requires **AutoHotkey v2.0+**.
- Download it here: [autohotkey.com](https://www.autohotkey.com/)
- Run the installer and select "Install v2.0".

#### 2. Get Free API Keys
This tool is free to use, but you need your own API keys for the backend services. Both offer generous free tiers.

**A. Groq API (Free Beta)**
1. Go to [console.groq.com](https://console.groq.com/keys).
2. Sign up/Log in.
3. Click **"Create API Key"**.
4. Copy the key (starts with `gsk_`).

**B. DeepL API (Free Tier)**
1. Go to [deepl.com/pro-api](https://www.deepl.com/pro-api).
2. Sign up for "DeepL API Free".
3. Go to your Account Summary and copy the **Authentication Key**.

#### 3. Setup Project
1. Clone or download this repository.
2. Inside the folder, create a new text file named `.env` (no .txt extension).
3. Paste your keys inside like this:
   ```ini
   DEEPL_API_KEY=your_deepl_key_here
   GROQ_API_KEY=your_groq_key_here
   ```
4. Save the file.

#### 4. Run
Double-click `groq.ahk`. You will see the "RPShift Menu" icon in your system tray.

###  How to Use
1. **Select text** (Turkish) in any app or type it out.
2. Press **PageDown (`PgDn`)** (Default).
   - *Note: You can change this key anytime from the Debug Menu!*
3. The script will translate it and **replace** your text with the English result.

**Debug Menu / Settings**
- Press **Ctrl + Alt + D** (or click the Tray Icon) to open the Debugger.
- Here you can:
    - See exactly what the AI did.
    - Change **Translation Mode**.
    - **Rebind Hotkey**: Click "Change", press your desired key (e.g., F1), and Save.
    - Click the Logo/Link to visit our GitHub.

---

<a id="türkçe"></a>
## 🇹🇷 Türkçe

### Genel Bakış
**RPShift Translator**, rol yapanlar (GTA V RP, yazılı RPG'ler) için özel olarak geliştirilmiş gelişmiş bir çeviri aracıdır. Sıradan çevirilerin aksine, sadece kelime anlamını çevirmez; Türkçe metinleri karakterinize uygun, **doğal Amerikan argosuna (slang)** dönüştürür.

###  Özellikler
- **4 Çeviri Modu**:
    1. **Groq Only (Direct)**: Hızlı yapay zeka çevirisi.
    2. **Groq Slang (Önerilen)**: Tek seferde hem çevirir hem slangify eder. (önerilen)
    3. **DeepL Only (Önerilen)**: Profesyonel, tam metin çevirisi. (önerilen)
    4. **DeepL + Groq Slang**: DeepL ile çevirip Groq ile slangify eder.
- **Modern Arayüz**: Orijinal metni, ham çeviriyi ve sonucu gösteren şık, karanlık modlu bir pencere.
- **Akıllı Kısayol**: Çeviri tuşunu menüden anında değiştirebilirsiniz.
- **Oto-Yazma**: Sonuç otomatik olarak oyuna veya sohbet penceresine yapıştırılır.
- **Komut Modu**: Eğer yazınız `/` ile başlıyorsa (örn: `/me yürür`), komutun bozulmaması için argo modu devre dışı kalır.

###  Kurulum Rehberi

#### 1. AutoHotkey v2 Yükleyin
Bu araç **AutoHotkey v2.0+** gerektirir.
- Buradan indirin: [autohotkey.com](https://www.autohotkey.com/)
- Kurulumu çalıştırın ve "Install v2.0" seçeneğini seçin.

#### 2. Ücretsiz API Anahtarlarını Alın
Aracı kullanmak ücretsizdir ancak arka plandaki servisler için kendi anahtarlarınıza ihtiyacınız var. İkisi de ücretsiz ve kolayca alınabiliyor.

**A. Groq API (Ücretsiz Beta)**
1. [console.groq.com](https://console.groq.com/keys) adresine gidin.
2. Üye olun/Giriş yapın.
3. **"Create API Key"** butonuna basın.
4. Anahtarı kopyalayın (`gsk_` ile başlar).

**B. DeepL API (Ücretsiz Paket)**
1. [deepl.com/pro-api](https://www.deepl.com/pro-api) adresine gidin.
2. "DeepL API Free" paketi için kaydolun.
3. Hesap özetinizden **Authentication Key**'i kopyalayın.

#### 3. Projeyi Hazırlayın
1. Bu dosyaları indirin veya repo'yu klonlayın.
2. Klasörün içinde `.env` adında yeni bir metin belgesi oluşturun (uzantısı .txt olmasın).
3. Oluşturduğunuz `.env` dosyasını not defteriyle açın ve anahtarlarınızı şu şekilde içine yapıştırın:
   ```ini
   DEEPL_API_KEY=buraya_deepl_kodu_gelecek
   GROQ_API_KEY=buraya_groq_kodu_gelecek
   ```
4. Dosyayı kaydedin.

#### 4. Çalıştırın
`groq.ahk` dosyasına çift tıklayın.

###  Nasıl Kullanılır?
1. Herhangi bir yerde metni (Türkçe) **seçin**. (ctrl+a ile hızlıca seçebilirsiniz)
2. **PageDown (`PgDn`)** tuşuna basın (Varsayılan).
   - *Not: Bu tuşu isterseniz Debug menüsünden değiştirebilirsiniz!*
3. Script metni çevirecek ve sonucu anında yerine yazacaktır.

**Debug Menüsü / Ayarlar**
- **Ctrl + Alt + D** tuşlarına basarak (veya ahk simgesine sağ tıklayarak) menüyü açıp kapatabilirsiniz.
- Buradan şunları yapabilirsiniz:
    - Yapay zekanın ne yaptığını canlı izleyebilirsiniz. (eğer bir problem olursa tam olarak nerede olduğunu buradan görebilirsiniz, böylece çeviri modunu değiştirebilirsiniz)
    - **Çeviri Modunu** değiştirebilirsiniz.
    - **Kısayolu Değiştirin**: "Change" butonuna basın, istediğiniz tuşa basın (örn: F1) ve kaydedin.
    - GitHub sayfama gitmek için logoya tıklayabilirsiniz.


---
Created by [diceandink](https://github.com/diceandink)
