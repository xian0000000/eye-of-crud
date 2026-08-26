# Eye of Crud

Papan investigasi digital ala detektif: taro foto, tulis catatan, tarik benang merah buat ngubungin petunjuk, dan chat realtime sesama detektif. Jalan di web (static, hosting gratis di GitHub Pages) dan Android (APK), backend-nya 100% Firebase (serverless, gratisan/Spark plan) — Firestore buat data board, Realtime Database buat chat & presence, Firebase Auth buat login.

Cuma 2 akun yang bisa login (lu & temen lu). **Gak ada halaman daftar/register di app ini sama sekali** — akun dibikin manual lewat Firebase Console.

## 1. Prasyarat

- Flutter SDK udah terinstall (project ini dibuat pake Flutter 3.44.2).
- Akun Google buat bikin project Firebase (gratis, gak perlu kartu kredit buat Spark plan).
- (Opsional tapi disaranin) Node.js buat install `firebase-tools` kalau mau deploy rules lewat CLI.

## 2. Bikin project Firebase

1. Buka https://console.firebase.google.com → **Add project** → kasih nama (misal `eye-of-crud`) → lanjut sampe selesai (Google Analytics boleh di-skip).
2. Di dalam project, klik ikon **Web (`</>`)** buat register app web. Kasih nickname bebas, **jangan** centang Firebase Hosting (kita deploy ke GitHub Pages). Nanti kamu bakal dikasih config `apiKey`, `appId`, dll — simpen dulu, dipake di langkah 7.
3. Klik **Add app** lagi, pilih **Android**, isi package name `com.example.eyeofcrud.eye_of_crud` (harus sama persis kayak di `android/app/build.gradle.kts` / `AndroidManifest.xml`), download `google-services.json`-nya kalau ditawarin (opsional, gak wajib dipakai project ini karena kita pakai `firebase_options.dart`, tapi gak masalah kalau mau simpan juga).

## 3. Aktifin Authentication (Email/Password)

1. Di Firebase Console → **Build → Authentication → Get started**.
2. Tab **Sign-in method** → aktifin provider **Email/Password**.
3. Tab **Users** → **Add user** → masukin email + password buat akun kamu. Ulangi buat akun temen kamu. Cuma 2 akun ini yang boleh ada.

> Catetan keamanan: karena API key Firebase itu publik (nempel di kode client), secara teknis orang lain bisa aja bikin akun baru langsung lewat REST API Firebase Auth kalau dia tau project config-nya. Itu gak masalah di sini — liat bagian **Model Keamanan** di bawah, karena akun baru yang gak terdaftar di `allowedUsers` bakal ditolak sama Firestore & Realtime Database rules, jadi dia gak bisa baca/tulis apa-apa.

## 4. Bikin Firestore & Realtime Database

1. **Build → Firestore Database → Create database** → pilih lokasi (misal `asia-southeast1`) → mode **production** (rules kita apply manual, liat langkah 6).
2. **Build → Realtime Database → Create database** → pilih lokasi → mode **locked** (rules kita apply manual juga).
3. Catet URL Realtime Database-nya (bentuknya `https://<project-id>-default-rtdb.<region>.firebasedatabase.app`), dipake di `firebase_options.dart`.

## 5. Daftarin 2 UID ke allowlist (WAJIB, ini kunci keamanannya)

Cari UID tiap user: Authentication → Users → kolom **User UID**.

**Di Firestore** (Build → Firestore Database → Data → Start collection):
- Bikin collection `allowedUsers`.
- Bikin document dengan **Document ID = UID user itu sendiri** (bukan auto-ID!), isi field `email` (string) dan `name` (string).
- Ulangi buat UID kedua.

**Di Realtime Database** (Build → Realtime Database → Data):
- Bikin node `allowedUsers`, di bawahnya bikin key = UID tsb, valuenya `true`.
- Ulangi buat UID kedua.

Struktur akhirnya kira-kira:
```
Firestore:  allowedUsers/{uid1} = { email: "...", name: "..." }
RTDB:       allowedUsers/{uid1} = true
```

Kalau lupa langkah ini, login bisa sukses tapi board & chat bakal ke-block sama rules (permission-denied) — itu emang disengaja.

## 6. Pasang rules-nya

Paling gampang: copy-paste manual.
- Firestore → tab **Rules** → paste isi file `firestore.rules` di repo ini → **Publish**.
- Realtime Database → tab **Rules** → paste isi file `database.rules.json` → **Publish**.

Atau kalau punya `firebase-tools` (`npm install -g firebase-tools`, lalu `firebase login` & `firebase use --add` buat pilih project ini):
```
firebase deploy --only firestore:rules,database
```

## 7. Ganti config Firebase (`lib/firebase_options.dart`)

File ini sekarang isinya placeholder (`REPLACE_WITH_...`) biar kodenya bisa di-compile. Ganti dengan config asli, caranya pilih salah satu:

**Cara gampang (disaranin):** install FlutterFire CLI lalu jalanin di root project:
```
dart pub global activate flutterfire_cli
flutterfire configure
```
Pilih project Firebase yang udah dibuat, pilih platform `android` dan `web`. Perintah ini bakal nge-generate ulang `lib/firebase_options.dart` otomatis dengan config asli.

**Cara manual:** buka Project Settings di Firebase Console, copy value `apiKey`, `appId`, `messagingSenderId`, `projectId`, `authDomain`, `storageBucket` dari config app Web & Android, terus isi manual ke `lib/firebase_options.dart` (ganti tiap `REPLACE_WITH_...`). Jangan lupa isi `databaseURL` sesuai URL Realtime Database dari langkah 4.

## 8. Jalanin lokal

```
flutter pub get
flutter run -d chrome
```

Login pake salah satu akun yang udah didaftarin di langkah 3.

## 9. Build APK Android

```
flutter build apk --release
```
Hasilnya ada di `build/app/outputs/flutter-apk/app-release.apk`, tinggal install manual ke HP (aktifin "Install from unknown sources" kalau perlu).

## 10. Deploy web ke GitHub Pages

1. Push repo ini ke GitHub (bikin repo baru, `git remote add origin ...`, `git push -u origin main`).
2. Buka repo di GitHub → **Settings → Pages** → di bagian **Build and deployment**, pilih **Source: Deploy from a branch**, branch **`gh-pages`** (bakal muncul otomatis setelah workflow jalan pertama kali), folder `/ (root)`.
3. Workflow `.github/workflows/deploy-web.yml` otomatis jalan tiap push ke `main`, build `flutter build web`, dan push hasilnya ke branch `gh-pages`. Situs bakal ada di `https://<username>.github.io/<nama-repo>/`.

## Model Keamanan (ringkas)

- App cuma punya layar login, gak ada signup. 2 akun dibikin manual di Firebase Console.
- Firestore & Realtime Database rules sama-sama ngecek `allowedUsers/{uid}` sebelum ngasih akses baca/tulis apapun — jadi biarpun ada orang bikin akun Firebase Auth baru dari luar (misal lewat REST API), akun itu tetep gak bisa akses data karena UID-nya gak ada di `allowedUsers`.
- Tiap "kasus" (case) punya field `members` (array UID). Board items & connections di dalam satu case cuma bisa diakses sama member case itu. Orang bisa gabung case lewat kode undangan (nambahin UID sendiri ke `members`), tapi field lain di dokumen case gak bisa diutak-atik pas gabung (dijaga di rules pake `diff().affectedKeys()`).
- Gak ada Cloud Functions atau Firebase Storage dipakai (biar tetep di Spark/free plan) — foto disimpen langsung sebagai base64 string di dalam dokumen Firestore (makanya ukuran foto dikompres & dibatasi ~900KB per foto).
