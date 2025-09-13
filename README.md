# Install Apache + PHP + Composer + PHPMailer + SSL (IPv4-Only ready)

Dieses Repository enthält das interaktive Setup-Script **`install_apache_php_composer_phpmailer_ssl_ipv4.sh`**.  
Es richtet auf Ubuntu/Debian in einem Durchlauf eine saubere, produktionsnahe Web-Umgebung ein:

- **Apache 2**
- **PHP** (inkl. gängiger Extensions: mbstring, xml, zip, curl)
- **Composer**
- **PHPMailer** (automatisch via Composer)
- **Projektstruktur**: `public/` (Webroot), `kontaktmailer/` (nicht öffentlich), `vendor/`, `logs/`
- **Apache vHost** inkl. **SMTP-Umgebungsvariablen** (werden von `kontaktmailer/mailer.php` gelesen)
- Optional: **Let’s Encrypt (SSL)** + **HSTS**
- Optional: **IPv4-Only** (deaktiviert Apache IPv6-Listening) – ideal, wenn kein AAAA-Record genutzt wird

> Nach dem Setup musst du nur noch deine Website-Dateien in `public/` ablegen.  
> Das Kontaktformular postet auf `public/sende.php` und lädt die Logik in `../kontaktmailer/mailer.php`.

---

## 🚀 Schnellstart (per `wget`)

### Variante 1: In das aktuelle Verzeichnis laden (ohne `cd` nötig)
```bash
wget -O install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/main/install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  || wget -O install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/master/install_apache_php_composer_phpmailer_ssl_ipv4.sh

chmod +x install_apache_php_composer_phpmailer_ssl_ipv4.sh
sudo ./install_apache_php_composer_phpmailer_ssl_ipv4.sh
```

### Variante 2: Direkt global installieren (ohne umkopieren später)
```bash
sudo wget -O /usr/local/bin/setup-phpmailer-stack \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/main/install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  || sudo wget -O /usr/local/bin/setup-phpmailer-stack \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/master/install_apache_php_composer_phpmailer_ssl_ipv4.sh

sudo chmod +x /usr/local/bin/setup-phpmailer-stack
sudo setup-phpmailer-stack
```

*(Optional)* Variante 3: Temporär nach `/tmp` laden und ausführen
```bash
wget -O /tmp/install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/main/install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  || wget -O /tmp/install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/master/install_apache_php_composer_phpmailer_ssl_ipv4.sh

chmod +x /tmp/install_apache_php_composer_phpmailer_ssl_ipv4.sh
sudo /tmp/install_apache_php_composer_phpmailer_ssl_ipv4.sh
```

---

## ✅ Voraussetzungen

- Ubuntu/Debian-Server mit `sudo`
- **DNS** zeigt per **A-Record (IPv4)** auf deinen Server  
  → Wenn du **IPv4-Only** nutzt: **Keine AAAA-Records** für `domain.tld` und `www.domain.tld`
- **Firewall**: Ports 80/443 offen
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
  - `public/.htaccess` (Basic-Hardening)
  - `kontaktmailer/mailer.php` (Validierung, Honeypot, Mini-Rate-Limit, PHPMailer)
- Installiert **PHPMailer** via Composer
- Schreibt & aktiviert **Apache vHost** mit SMTP-Env
- Optional: **Let’s Encrypt** Zertifikat + **HSTS**
- Optional: **IPv4-Only** (Apache lauscht nicht auf `::`)

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

## 📮 Formular-Setup

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
`kontaktmailer/mailer.php` (Template wird erzeugt, anpassbar):
- Liest SMTP aus **Env** (vHost) – mit Fallback auf deine Eingaben
- Escaping, Validierung, **Honeypot**, **Mini-Rate-Limit**
- Redirect auf `/danke.html`
- Composer-Autoloader:
  ```php
  require __DIR__ . '/../vendor/autoload.php';
  ```

---

## ⚙️ Konfiguration

### SMTP (empfohlen über vHost-Env)

Im vHost setzt das Script z. B.:
```apache
SetEnv SMTP_HOST "mail.example.com"
SetEnv SMTP_USER "no-reply@example.com"
SetEnv SMTP_PASS "GEHEIM"
SetEnv SMTP_PORT "587"
```

In `kontaktmailer/mailer.php` wird gelesen:
```php
$SMTP_HOST = getenv('SMTP_HOST') ?: 'mail.fallback.tld';
$SMTP_USER = getenv('SMTP_USER') ?: 'no-reply@fallback.tld';
$SMTP_PASS = getenv('SMTP_PASS') ?: 'PASSWORT_FALLBACK';
$SMTP_PORT = (int)(getenv('SMTP_PORT') ?: 587);
```

> Alternativ: feste SMTP-Werte direkt in `mailer.php` setzen oder `.env` (phpdotenv) nutzen.

### SSL (Let’s Encrypt)

- Im Script „Let’s Encrypt jetzt einrichten?“ → **y**
- Voraussetzungen: DNS korrekt (A-Record), Ports 80/443 offen
- Auto-Renew Test:
  ```bash
  sudo certbot renew --dry-run
  ```

### IPv4-Only

- Im Script „IPv4-Only?“ → **Y**
- Apache deaktiviert `Listen [::]:80/443` in `/etc/apache2/ports.conf`
- **DNS:** Sichere dich ab, dass **keine AAAA-Records** existieren:
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
  - DNS prüfen: **Nur A-Record**, bei IPv4-Only **keine AAAA-Records**
  - Firewall 80/443 freigeben
  - vHost aktiv? `sudo a2ensite <domain> && sudo systemctl reload apache2`

- **`getenv()` ist leer**
  - Bei PHP-FPM ggf. Env in `www.conf` setzen und FPM reloaden:
    ```ini
    env[SMTP_HOST] = mail.example.com
    env[SMTP_USER] = no-reply@example.com
    env[SMTP_PASS] = GEHEIM
    env[SMTP_PORT] = 587
    ```

- **Mail kommt nicht an**
  - SMTP-Host/Port/TLS korrekt? Auth ok?
  - Absender/Reply-To vom Provider erlaubt?
  - Spam-Ordner prüfen

---

## 🔐 Sicherheit

- `kontaktmailer/mailer.php` liegt **außerhalb** von `public/` (nicht direkt abrufbar)
- `public/.htaccess`: Directory-Listing aus & Basis-Security-Header an
- **Keine Passwörter** ins Repo committen – im vHost/Env oder `.env` speichern

---

## 📄 Lizenz

**MIT** — frei verwendbar & anpassbar. Nutzung auf eigenes Risiko.

