# Install Apache + PHP + Composer + PHPMailer + SSL (IPv4-Only ready)

Dieses Repo enthält das interaktive Setup-Script **`install_apache_php_composer_phpmailer_ssl_ipv4.sh`**.  
Es richtet auf Ubuntu/Debian einen produktionsreifen Webstack ein:

- Apache 2
- PHP (+ gängige Extensions)
- Composer
- **PHPMailer** (via Composer)
- Projektstruktur: `public/` (Webroot), `kontaktmailer/` (nicht öffentlich), `vendor/`, `logs/`
- Apache vHost inkl. SMTP-Umgebungsvariablen
- Optional: Let’s Encrypt (SSL)
- Optional: IPv4-Only (deaktiviert Apache IPv6-Listening)

---

## Schnellstart (per `wget`)

**Nur das Script laden & starten:**
```bash
cd ~
wget -O install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/main/install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  || wget -O install_apache_php_composer_phpmailer_ssl_ipv4.sh \
  https://raw.githubusercontent.com/Riveria-IT/install_apache_php_composer_phpmailer_ssl_ipv4/master/install_apache_php_composer_phpmailer_ssl_ipv4.sh

chmod +x install_apache_php_composer_phpmailer_ssl_ipv4.sh
sudo ./install_apache_php_composer_phpmailer_ssl_ipv4.sh
