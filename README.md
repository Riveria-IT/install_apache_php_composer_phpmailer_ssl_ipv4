# Install Apache + PHP + Composer + PHPMailer + SSL (IPv4‑Only ready)

Ein interaktives Setup‑Script für Ubuntu/Debian, das dir in wenigen Minuten einen sauberen Webstack bereitstellt – **inkl. Apache 2, PHP, Composer, PHPMailer, vHost, optional Let’s Encrypt (SSL) und IPv4‑Only Modus**.  
Nach dem Setup musst du **nur noch** deine Website‑Dateien in `public/` ablegen.

---

## ✨ Features

- **Apache 2** – produktionsbereit mit sinnvollen Defaults
- **PHP** + gängige Extensions (mbstring, xml, zip, curl)
- **Composer** – Paketmanager für PHP
- **PHPMailer** – automatisch via Composer installiert
- **Projektstruktur**: `public/` (Webroot), `kontaktmailer/` (nicht öffentlich), `vendor/`, `logs/`
- **Apache vHost** mit **SMTP‑Umgebungsvariablen** (von `mailer.php` gelesen)
- **Kontaktformular‑Flow**: `public/sende.php` → lädt `../kontaktmailer/mailer.php`
- Optional: **Let’s Encrypt** (SSL) + HSTS
- Optional: **IPv4‑Only** (deaktiviert Apache IPv6‑Listening; hilfreich, wenn kein AAAA‑Record)

---

## 🧩 Schnellstart (per `wget`)

**Nur das Script laden & starten:**

```bash
cd ~
wget -O install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/main/install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  || wget -O install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/master/install_apache_php_composer_phpmailer_ssl_ipv4.sh

chmod +x install_apache_php_composer_phpmailer_ssl_ipv4.sh
sudo ./install_apache_php_composer_phpmailer_ssl_ipv4.sh
```

**Optional – globaler Befehl:**

```bash
sudo mv install_apache_php_composer_phpmailer_ssl_ipv4.sh /usr/local/bin/setup-phpmailer-stack
sudo chmod +x /usr/local/bin/setup-phpmailer-stack
sudo setup-phpmailer-stack
```

---

## ✅ Voraussetzungen

- Ubuntu/Debian‑Server mit `sudo`
- **DNS**: Domain zeigt per **A‑Record (IPv4)** auf deinen Server  
  _(Wenn du IPv4‑Only nutzt: **keine AAAA‑Records**)_
- **Firewall**: Ports 80/443 freigeben
  ```bash
  sudo ufw allow 'Apache Full'
  ```

---

## 🛠️ Was das Script macht

- Installiert: `apache2`, `php` (+ Extensions), `composer`, `certbot`
- Erstellt Verzeichnisse:
  ```text
  /var/www/<domain>/{public,kontaktmailer,vendor,logs}
  ```
- Legt Platzhalter an:
  - `public/index.html`, `public/danke.html`, `public/datenschutz.html`
  - `public/sende.php` (Proxy → lädt `../kontaktmailer/mailer.php`)
  - `public/.htaccess` (Basic‑Hardening)
  - `kontaktmailer/mailer.php` (Validierung, Honeypot, kleines Rate‑Limit, PHPMailer)
- Installiert **PHPMailer** via Composer
- Schreibt & aktiviert **Apache vHost** mit SMTP‑Env
- Optional: **Let’s Encrypt** Zertifikat + **HSTS**
- Optional: **IPv4‑Only** (Apache lauscht nicht auf `::`)

---

## 🗂️ Projektstruktur

```text
/var/www/<domain>/
├─ public/                 # Webroot (DocumentRoot)
│  ├─ index.html
│  ├─ danke.html
│  ├─ datenschutz.html
│  ├─ sende.php            # Proxy → lädt ../kontaktmailer/mailer.php
│  ├─ .htaccess
│  ├─ css/
│  ├─ js/
│  ├─ images/
│  └─ asset/               # z. B. Font Awesome (css + webfonts)
│
├─ kontaktmailer/
│  └─ mailer.php           # Formular-/Mail-Logik (nicht öffentlich)
│
├─ vendor/                 # Composer (inkl. PHPMailer)
└─ logs/                   # z. B. spam.log
```

---

## 📮 Formular‑Setup

In deiner `index.html`:

```html
<form class="contact-form" method="POST" action="sende.php">
  <!-- name, email, phone_suffix, message, website (honeypot), datenschutz -->
</form>
```

`public/sende.php` (wird automatisch erzeugt):

```php
<?php
require __DIR__ . '/../kontaktmailer/mailer.php';
```

`kontaktmailer/mailer.php` (Template wird erzeugt und kann angepasst werden):

- Liest SMTP aus **Env** (vHost) – mit Fallback auf deine Eingaben
- Escaping, Validierung, **Honeypot**, **Mini‑Rate‑Limit**
- Redirect auf `/danke.html`
- Composer‑Autoloader:
  ```php
  require __DIR__ . '/../vendor/autoload.php';
  ```

---

## ⚙️ Konfiguration

### SMTP (empfohlen via vHost‑Env)

Im vHost setzt das Script:

```apache
SetEnv SMTP_HOST "mail.example.com"
SetEnv SMTP_USER "no-reply@example.com"
SetEnv SMTP_PASS "GEHEIM"
SetEnv SMTP_PORT "587"
```

In `kontaktmailer/mailer.php`:

```php
$SMTP_HOST = getenv('SMTP_HOST') ?: 'mail.fallback.tld';
$SMTP_USER = getenv('SMTP_USER') ?: 'no-reply@fallback.tld';
$SMTP_PASS = getenv('SMTP_PASS') ?: 'PASSWORT_FALLBACK';
$SMTP_PORT = (int)(getenv('SMTP_PORT') ?: 587);
```

> Alternativ: SMTP fest in `mailer.php` hinterlegen oder `.env` nutzen (phpdotenv).

### SSL (Let’s Encrypt)

- Im Script „Let’s Encrypt jetzt einrichten?“ → **y**
- Voraussetzungen: DNS korrekt (A‑Record), Ports 80/443 offen
- Auto‑Renew Test:
  ```bash
  sudo certbot renew --dry-run
  ```

### IPv4‑Only

- Im Script „IPv4‑Only?“ → **Y**
- Apache deaktiviert `Listen [::]:80/443`
- **DNS:** Stelle sicher, dass **keine AAAA‑Records** existieren:
  ```bash
  dig AAAA deine-domain.tld +short
  dig AAAA www.deine-domain.tld +short
  # (keine Ausgabe = gut)
  ```

---

## 🔎 Tests

**Seite erreichbar**
```bash
curl -I http://deine-domain.tld/
```

**PHPMailer verfügbar**
```bash
php -r "require '/var/www/deine-domain.tld/vendor/autoload.php'; echo (class_exists('PHPMailer\\PHPMailer\\PHPMailer')?'PHPMailer OK':'FEHLT').PHP_EOL;"
```

**Formular ohne Browser**
```bash
curl -i -X POST http://deine-domain.tld/sende.php \
  -d "name=Test&email=test@example.com&message=Hallo&phone_suffix=791234567&datenschutz=on"
# Erwartung: 303 See Other → Location: /danke.html
```

**HTTPS Header**
```bash
curl -I https://deine-domain.tld/
```

---

## 🧯 Troubleshooting

- **SSL schlägt fehl**
  - DNS prüfen (nur A‑Record, bei IPv4‑Only **keine AAAA‑Records**)
  - Firewall 80/443 freigeben
  - vHost aktiv? `sudo a2ensite <domain> && sudo systemctl reload apache2`

- **`getenv()` ist leer**
  - Bei PHP‑FPM ggf. Env in `www.conf` setzen und FPM reloaden:
    ```ini
    env[SMTP_HOST] = mail.example.com
    env[SMTP_USER] = no-reply@example.com
    env[SMTP_PASS] = GEHEIM
    env[SMTP_PORT] = 587
    ```

- **Mail kommt nicht an**
  - SMTP‑Host/Port/TLS korrekt? Auth ok?
  - Absender/Reply‑To vom Provider erlaubt?
  - Spam‑Ordner prüfen

---

## 🔐 Sicherheit

- `kontaktmailer/mailer.php` liegt **außerhalb** von `public/` (nicht direkt abrufbar)
- `public/.htaccess`: Directory‑Listing aus & Basis‑Security‑Header an
- **Keine Passwörter** ins Repo committen – im vHost/Env oder `.env` speichern

---

## 📄 Lizenz

**MIT** — frei verwendbar & anpassbar. Nutzung auf eigenes Risiko.
