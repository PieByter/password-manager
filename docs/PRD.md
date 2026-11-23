# PRD — Password Manager (Flutter)

| Field | Value |
| --- | --- |
| Versi dokumen | 1.0 |
| Tanggal | 23 November 2026 |
| Status | Aktif — Fase 1 dieksekusi |
| Platform | Android, iOS, Windows, macOS, Linux, Web |
| Stack | Flutter, Provider, `flutter_secure_storage`, `encrypt`, `crypto`, `local_auth` |

## 1. Ringkasan

Password Manager adalah aplikasi lokal-first untuk menyimpan kredensial, catatan aman,
dan kode TOTP. Data dienkripsi di perangkat dengan master password yang hanya diketahui
pengguna. Tidak ada data sensitif yang dikirim ke server pada Fase 1.

**Tujuan utama**

1. Menyimpan dan mengakses password dengan aman tanpa ketergantungan cloud.
2. Memberi pengalaman buka-vault yang cepat: master password atau biometrik.
3. Menjadi fondasi yang siap dikembangkan ke sinkronisasi E2E-encrypted di masa depan.

**Non-goals (Fase 1)**

- Sinkronisasi multi-device.
- Berbagi vault antar pengguna.
- Autofill tingkat sistem (Android AutofillService / iOS Credential Provider).
- Pemulihan master password (tetap _zero-knowledge, no recovery_).

## 2. Kondisi Saat Ini (Baseline)

Sudah ada:

- Clean architecture: `data` → `domain` (repository interface + use case) → `presentation` (provider + screen).
- Vault terenkripsi disimpan sebagai satu blob di secure storage.
- Master password: PBKDF2-HMAC-SHA256 100.000 iterasi + salt.
- Autentikasi biometrik (toggle saat setup).
- CRUD entri password, pencarian judul/username/URL.
- Generator password sederhana, TOTP per entri, tema terang/gelap mengikuti sistem.

Masalah yang ditemukan pada audit:

| # | Masalah | Dampak |
| --- | --- | --- |
| 1 | `Key.fromUtf8(base64(...))` menghasilkan key 44 byte | AES menolak key; simpan/buka vault gagal total |
| 2 | `allEntries.isEmpty` dipakai sebagai penanda "belum load" | Reload berulang saat vault kosong |
| 3 | Generator memakai `DateTime.now()` | Password dapat diprediksi |
| 4 | Hash master password dan kunci enkripsi memakai derivasi yang sama | Kebocoran hash = kebocoran kunci vault |
| 5 | Biometrik hanya memunculkan prompt, lalu tetap meminta master password | Fitur tidak berguna |
| 6 | Clipboard tidak dibersihkan | Password tertinggal di clipboard |
| 7 | Tidak ada auto-lock | Vault terbuka tanpa batas waktu |
| 8 | Belum ada cara mengubah master password | Pengguna tidak bisa merotasi kredensial |

## 3. Persona & User Story

**Persona utama: individu yang sadar keamanan**

- Ingin menyimpan 50–500 kredensial di perangkat sendiri.
- Mengaktifkan biometrik agar tidak mengetik master password setiap saat.
- Khawatir password tertinggal di clipboard atau aplikasi tetap terbuka.

**User stories prioritas**

1. Sebagai pengguna, saya ingin vault benar-benar bisa disimpan dan dibuka kembali.
2. Sebagai pengguna, saya ingin membuka vault dengan sidik jari tanpa mengetik master password.
3. Sebagai pengguna, saya ingin vault terkunci otomatis saat tidak dipakai.
4. Sebagai pengguna, saya ingin password yang dihasilkan sulit diprediksi dan dapat diatur.
5. Sebagai pengguna, saya ingin clipboard password dibersihkan otomatis.
6. Sebagai pengguna, saya ingin mengganti master password tanpa kehilangan data.
7. Sebagai pengguna, saya ingin mengatur tema, auto-lock, dan perilaku clipboard.

## 4. Prioritas & Scope

| Prioritas | Definisi |
| --- | --- |
| **P0** | Wajib; tanpa ini produk tidak aman/tidak berfungsi |
| **P1** | Nilai tinggi; direncanakan setelah fondasi stabil |
| **P2** | Diferensiasi / jangka panjang |

## 5. Functional Requirements

### FR-01 — Enkripsi vault & integritas (P0)

- AES-256-CBC dengan IV acak per enkripsi.
- Encrypt-then-MAC: HMAC-SHA256 atas versi, IV, dan ciphertext.
- Format berversi: `v2:<iv>:<ciphertext>:<mac>`.
- Kunci enkripsi dan kunci MAC diturunkan terpisah (64 byte PBKDF2 → 32+32).
- Verifikasi MAC memakai perbandingan constant-time.
- Payload yang dimodifikasi atau password salah harus gagal dengan error generik.
- Cache kunci turunan di memori selama sesi; dibersihkan saat lock/logout.

**Acceptance criteria**

- Round-trip encrypt/decrypt berhasil.
- Decrypt dengan password salah gagal.
- Modifikasi 1 karakter ciphertext/MAC gagal.
- Dua enkripsi plaintext yang sama menghasilkan ciphertext berbeda.

### FR-02 — Master password lifecycle (P0)

- Setup minimal 12 karakter + indikator kekuatan.
- Verifikasi memakai derivasi terpisah dari kunci enkripsi (`auth|salt` vs `enc|salt`).
- Ganti master password: verifikasi password lama, re-enkripsi vault, perbarui verifier.
- Jika penyimpanan vault gagal, data lama dipertahankan.
- Tidak ada mekanisme recovery; UI harus menjelaskan risikonya.

**Acceptance criteria**

- Password lama tidak bisa membuka vault setelah perubahan berhasil.
- Password baru membuka semua entri.
- Perubahan dibatalkan bila password lama salah.

### FR-03 — Biometric unlock (P0)

- Saat biometrik diaktifkan, simpan master password di secure storage (keystore/keychain).
- Unlock biometrik: prompt sistem → baca kredensial → buka vault tanpa dialog tambahan.
- Menonaktifkan biometrik menghapus kredensial tersimpan.
- Saat master password berubah, kredensial biometrik ikut diperbarui.
- Tombol biometrik hanya tampil bila fitur aktif.

**Batasan known issue**

`flutter_secure_storage` tidak mengikat item ke biometrik secara hardware pada semua
platform; lapisan `local_auth` bertindak sebagai gerbang aplikasi. Pengikatan hardware
(StrongBox/Secure Enclave) dicatat sebagai risiko Fase 2.

### FR-04 — Auto-lock (P0)

- Timeout idle dapat diatur: 1, 5, 15 menit, atau tidak pernah.
- Default 5 menit.
- Aktivitas pointer mereset timer.
- Saat app kembali dari background, jika durasi background ≥ timeout, vault terkunci.
- Lock: hapus master password dari memori, kosongkan cache entri, tutup semua route, tampilkan layar auth.
- Tombol "Lock vault" memakai alur yang sama.

### FR-05 — Clipboard protection (P0)

- Copy password/username/TOTP memakai layanan terpusat.
- Clipboard dibersihkan otomatis setelah 15/30/60 detik (default 30), dapat dimatikan.
- Hanya dibersihkan jika isi clipboard masih sama dengan yang disalin.
- Snackbar memberi tahu durasi pembersihan.

### FR-06 — Password generator (P0)

- `Random.secure()` untuk seluruh pemilihan karakter.
- Opsi: panjang 12–64, huruf besar/kecil, angka, simbol, hindari karakter ambigu (`Il1O0o`).
- Minimal satu karakter dari setiap kelas yang dipilih.
- Acak ulang dengan Fisher–Yates.
- Indikator kekuatan password.
- Dialog generator tersedia saat membuat/mengedit entri.

### FR-07 — Settings (P0)

- Tema: system / light / dark, persisten.
- Auto-lock timeout, persisten.
- Durasi pembersihan clipboard, persisten.
- Toggle biometrik.
- Ganti master password.
- Info versi aplikasi.

### FR-08 — Pengujian & CI (P0)

- Unit test: enkripsi, TOTP (RFC 6238), generator, strength, use case rekey.
- `flutter analyze` bersih.
- GitHub Actions menjalankan analyze + test pada push/PR.

### FR-09 — TOTP lanjutan (P1)

- Scan QR `otpauth://` saat setup.
- Tampilkan QR untuk ekspor.
- Dukungan 6/8 digit, SHA-1/256/512, periode kustom.
- Tombol copy kode + progress ring.
- Issuer/account terpisah dari judul entri.

### FR-10 — Organisasi vault (P1)

- Kategori/folder, tag, favorit.
- Sorting: terbaru, A–Z, terakhir dipakai.
- Filter cepat (favorit, 2FA, kategori).
- Bulk actions.

### FR-11 — Password health (P1)

- Deteksi password lemah, dipakai ulang, dan lama tidak diganti.
- Skor kesehatan vault.
- Cek kebocoran HIBP via k-anonymity (opsional, butuh jaringan).
- Rekomendasi tindakan per entri.

### FR-12 — Riwayat password (P1)

- Simpan maksimal 10 password lama per entri.
- Tampilkan tanggal perubahan.
- Restore password lama.
- Riwayat ikut terenkripsi.

### FR-13 — Import / export & backup (P1)

- Export vault terenkripsi (file `.pmvault`).
- Import dari CSV Bitwarden/Chrome/1Password dengan pemetaan kolom.
- Deteksi duplikat saat import.
- Backup otomatis sebelum import.

### FR-14 — Tipe item lain (P1)

- Secure note, kartu kredit, identitas.
- Field khusus per tipe.
- Masking data sensitif.

### FR-15 — Buka URL & autofill (P2)

- Tombol buka website dari entri.
- Android AutofillService dan iOS Credential Provider Extension.
- Domain matching.

### FR-16 — Sinkronisasi E2E (P2)

- Firebase Auth + penyimpanan cloud (dependency sudah terpasang tetapi belum dipakai).
- Enkripsi dilakukan di device; server hanya melihat ciphertext.
- Konflik diselesaikan dengan revision/updatedAt.
- Status offline & retry queue.
- Alternatif self-hosted: WebDAV/Nextcloud.

### FR-17 — Privasi layar (P2)

- `FLAG_SECURE` di Android.
- Blur/overlay di app switcher.
- Sembunyikan isi saat screenshot.

### FR-18 — Recovery key (P2)

- Recovery key 256-bit yang dipegang pengguna, dibungkus dengan kunci publik aplikasi.
- Opsi cetak/simpan offline.
- Tetap tanpa akses server ke plaintext.

### FR-19 — Lokalisasi (P2)

- Bahasa Indonesia dan Inggris.
- Format tanggal/angka sesuai locale.

## 6. Non-Functional Requirements

| Aspek | Target |
| --- | --- |
| Waktu buka vault | < 1,5 detik setelah master password (PBKDF2 100k di perangkat target) |
| Waktu simpan | < 300 ms setelah kunci di-cache |
| Ukuran vault | 1.000 entri tanpa degradasi UI berarti |
| Offline | 100% fitur inti Fase 1 |
| Aksesibilitas | Label semantik, kontras WCAG AA, target sentuh 48dp |
| Data at rest | Tidak ada plaintext kredensial di disk/log |
| Logging | Tidak pernah mencetak password, secret, atau kunci |

## 7. Security Model

**Aset yang dilindungi:** password, TOTP secret, catatan, URL, username.

**Ancaman utama**

1. Pencurian perangkat dalam keadaan terkunci → secure storage + enkripsi.
2. Malware dengan akses ke sandbox aplikasi → enkripsi + kunci hanya di memori saat unlock.
3. Clipboard sniffing → auto-clear.
4. Aplikasi ditinggal terbuka → auto-lock.
5. Modifikasi ciphertext (bit-flipping) → Encrypt-then-MAC.
6. Password lemah/dipakai ulang → generator + health check (P1).

**Di luar cakupan:** compromised OS dengan hak root, keylogger, serangan fisik
terhadap hardware, dan pemulihan master password yang hilang.

## 8. UX Flow Utama

### Setup pertama

1. Layar "Create Master Password" → input + konfirmasi + strength meter.
2. Jika biometrik tersedia, opsi "Enable biometric unlock" (default aktif).
3. Vault kosong ditampilkan.

### Unlock

1. Layar auth menampilkan field master password dan tombol biometrik (jika aktif).
2. Biometrik sukses → vault langsung terbuka.
3. Gagal → pesan generik, tetap di layar auth.

### Auto-lock

1. Tidak ada interaksi selama N menit → vault terkunci.
2. Route yang terbuka ditutup, entri dibersihkan dari memori.
3. Pengguna kembali ke layar auth.

### Ganti master password

1. Settings → Change master password.
2. Input password lama, baru, konfirmasi.
3. Validasi → re-enkripsi → verifier baru.
4. Snackbar sukses; sesi tetap terbuka.

## 9. Arsitektur Teknis

```
lib/
  core/
    security/          # generator, strength
    services/          # clipboard
    totp/              # RFC 6238
    utils/             # helper UI
  data/
    datasources/       # secure storage platform
    encryption/        # AES-CBC + HMAC, PBKDF2
    models/            # JSON mapping
    repositories/      # implementasi kontrak domain (vault, auth, settings)
  domain/
    entities/          # PasswordEntry (pure)
    repositories/      # interface
    usecases/          # auth, vault
  features/
    auth/              # provider, screen
    vault/             # provider, screen
    entry/             # screen, widget
    settings/          # provider, screen
    session/           # auto-lock coordinator
```

Prinsip:

- Presentation tidak pernah menyentuh storage/enkripsi langsung.
- Use case adalah satu unit logika bisnis.
- Repository implementation menyembunyikan detail platform.
- Dependency injection hanya di composition root (`app.dart`).

## 10. Roadmap & Status

| Fase | Isi | Status |
| --- | --- | --- |
| **Fase 1** | FR-01 s.d. FR-08: perbaikan enkripsi, auto-lock, biometrik, generator, clipboard, settings, test, CI | **Selesai** |
| Fase 2 | FR-09 s.d. FR-14: TOTP lanjutan, organisasi vault, health, history, import/export, tipe item | Planned |
| Fase 3 | FR-15 s.d. FR-19: autofill, sync E2E, privacy screen, recovery key, lokalisasi | Planned |

## 11. Metrik Keberhasilan

- 0 kegagalan simpan/buka vault pada test round-trip.
- 100% unit test kripto & TOTP lulus.
- Tidak ada password di clipboard lebih dari durasi yang diatur.
- Vault terkunci otomatis sesuai konfigurasi.
- Crash-free rate > 99,5% (setelah rilis).

## 12. Risiko & Mitigasi

| Risiko | Mitigasi |
| --- | --- |
| Master password hilang | Peringatan jelas di onboarding; recovery key (P2) |
| Secure storage tidak biometric-bound di semua platform | Dokumentasikan; evaluasi plugin native (P2) |
| Rekey gagal di tengah proses | Rollback vault ke password lama; verifier baru hanya ditulis setelah vault sukses |
| PBKDF2 pure-Dart lambat | Cache kunci per sesi; evaluasi Argon2/native (P2) |
| Data lama tidak kompatibel | Tidak ada data valid dari versi lama karena bug enkripsi; format `v2` berversi |
| Sync membocorkan data | E2E encryption; server hanya ciphertext (P2) |

## 13. Out of Scope

- Sharing antar pengguna.
- SSO / enterprise directory.
- Browser extension.
- Pemulihan akun via server.
- Audit keamanan pihak ketiga (disarankan sebelum rilis publik).

## 14. Changelog

- **2026-11-23** — Dokumen dibuat; audit baseline; Fase 1 diimplementasikan.

## 15. Catatan Implementasi Fase 1

**Kripto**

- `EncryptionService` sekarang memakai format `v2` dengan AES-256-CBC + HMAC-SHA256.
- Salt tetap di secure storage; kunci enkripsi/MAC diturunkan dari `enc|salt`,
  verifier dari `auth|salt`.
- Cache kunci per (password, salt) dibersihkan saat lock, logout, dan rekey.

**Sesi & autentikasi**

- `SessionProvider` menangani idle timer, lifecycle background, keyboard/pointer
  activity, dan penutupan route saat lock.
- `ChangeMasterPassword` melakukan verifikasi → re-enkripsi → ganti verifier,
  dengan rollback bila penyimpanan gagal.
- Biometrik menyimpan master password di secure storage dan membuka vault
  langsung setelah prompt berhasil.

**UI**

- Settings screen: tema, auto-lock, clipboard timeout, biometrik, rekey, lock now.
- Generator password: bottom sheet dengan opsi charset/panjang + strength meter.
- Clipboard service terpusat dengan auto-clear; dipakai di vault, entri, dan TOTP.
- Vault memiliki empty/error state dan retry; tidak ada lagi reload loop.

**Verifikasi**

- `flutter analyze`: 0 issue.
- `flutter test`: 36 test lulus (enkripsi, TOTP RFC 6238, generator, strength,
  rekey, inisialisasi auth, provider).
- `flutter build windows --debug` belum dijalankan karena Visual Studio
  toolchain tidak tersedia di mesin ini.

**Langkah berikutnya**

Fase 2 dimulai dari FR-10 (kategori/favorit) dan FR-11 (password health),
kemudian FR-12 (riwayat) dan FR-13 (backup/import). Fase 3 (sync, autofill,
privacy screen) memerlukan keputusan produk dan dependency tambahan.

