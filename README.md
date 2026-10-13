# IT 305 — Student Activity 8: Website Migration and Mobile Application Integration

**Bulacan State University — College of Information and Communications Technology**  
**Course:** IT 305 - Advanced Web Development (BSIT-WMAD)

---

## 📌 Project Overview
**CoopConnect** is a cooperative member information and survey portal originally developed with PHP and MySQL. This activity migrates the application to use **Google Firebase** as its unified cloud database and authentication provider, while introducing an integrated **Flutter Mobile Application** that shares and synchronizes live data with the web platform.

### System Architecture
```text
PHP Website (Coop/) / Hosted PWA (web_hosting/)
                     ↕
   Firebase Authentication & Realtime Database (coop-692bf)
                     ↕
       Mobile Application (coop_mobile/)
```

Both platforms communicate with the **same Firebase project**, ensuring that user profiles and survey submissions are synchronized across platforms in real-time.

---

## 🔗 Project Links

* **GitHub Repository:** [https://github.com/danryleneettan-web/IT305-Activity-8]
* **Hosted Web Application:** [https://coop-692bf.web.app]
* **Firebase Console:** [https://console.firebase.google.com/project/coop-692bf/overview]
* **Video Presentation:** *[https://drive.google.com/drive/folders/18d7resILlJ8HCbdb36j5dm2JL-qP9TJC?usp=sharing]*

---


## 🚀 Key Features

### 1. User Profiling
- **Authentication**: Email/Password and Account Number sign-in via Firebase Authentication.
- **Member Registration**: Public self-registration directly provisions Firebase Auth and Realtime Database records.
- **Profile Management**: Viewing and editing personal info, contact details (11-digit validation), civil status, and family/children records.
- **Printing**: Printable member summary sheet.

### 2. Survey Module
- **Question Types**: Multiple Choice, Yes/No, Rating Scale (1–5), and Short Answer.
- **Validation**: Enforces required questions and prevents duplicate submissions per member.
- **Staff Reports**: Aggregated responses, respondent tallies, and percentage breakdowns.

---

## 🔑 Test Credentials

* **Staff / Admin**:
  * **Username**: `admin`
  * **Password**: `password`
* **Member**:
  * **Account Number**: `2026-0002`
  * **Password**: `2026-0002`

---

## 🛠️ How to Run Locally

### 1. PHP Website (`Coop/`)
Requires PHP with cURL enabled (e.g. XAMPP):
```bash
cd Coop
php -S localhost:8000
```
Open **[http://localhost:8000](http://localhost:8000)** in your browser.

### 2. Flutter Mobile App (`coop_mobile/`)
Requires Flutter SDK:
```bash
cd coop_mobile
flutter pub get
flutter run
```
Release APK is built at:
`coop_mobile/build/app/outputs/flutter-apk/app-release.apk`
