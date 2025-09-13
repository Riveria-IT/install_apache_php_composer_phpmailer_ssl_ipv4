# Webstack Setup (Apache + PHP + Composer + PHPMailer + Let’s Encrypt, IPv4-Only Option)

Ein interaktives Setup-Script für Ubuntu/Debian, das eine produktionsreife Webumgebung erstellt:

- **Apache 2**
- **PHP** (inkl. gängiger Extensions)
- **Composer**
- **PHPMailer** (via Composer)
- **Projektstruktur** mit `public/` (Webroot), `kontaktmailer/` (nicht öffentlich), `vendor/`, `logs/`
- **Apache vHost** inkl. **SMTP-Umgebungsvariablen**
- Optional: **Let’s Encrypt** (SSL)
- Optional: **IPv4-Only** (deaktiviert IPv6-Listening in Apache)

> Ziel: Nach dem Setup musst du **nur noch** deine Website-Dateien nach `public/` kopieren.  
> Das Kontaktformular postet auf `public/sende.php`, welches die Logik in `kontaktmailer/mailer.php` lädt.

---

## Voraussetzungen

- Ubuntu/Debian-Server mit `sudo`
- Domain zeigt auf den Server (A-Record für IPv4; **keine AAAA-Records**, wenn du IPv4-Only nutzt)
- Ports **80/443** offen:
