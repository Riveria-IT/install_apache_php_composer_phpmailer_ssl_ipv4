#!/usr/bin/env bash
# Interaktives Setup für Apache + PHP + Composer + PHPMailer + (optional) Let's Encrypt
# Wiederverwendbar für beliebig viele Domains.
# Auf Debian/Ubuntu mit root/sudo ausführen: sudo ./site_setup_interactive.sh

set -euo pipefail

# ===== Helper =====
prompt() { # prompt "Frage" "Default"
  local Q="$1" DEF="${2-}" R=""
  if [[ -n "$DEF" ]]; then read -rp "$Q [$DEF]: " R || true; echo "${R:-$DEF}";
  else read -rp "$Q: " R || true; echo "$R"; fi
}
prompt_secret() { local Q="$1" S=""; read -srp "$Q: " S || true; echo; echo "$S"; }
die() { echo "ERROR: $*" >&2; exit 1; }
ok()  { echo "✅ $*"; }
info(){ echo "— $*"; }

[[ $EUID -eq 0 ]] || die "Bitte mit sudo/root ausführen."

echo "=== Interaktives Web-Setup (Apache + PHP + PHPMailer) ==="

# ===== Fragen =====
DOMAIN=""
while [[ -z "$DOMAIN" ]]; do DOMAIN="$(prompt "Domain (z.B. liegenschaftsprofis.ch)""")"; done
ROOT="$(prompt "Installationsverzeichnis (Root)" "/var/www")"
PROJECT_ROOT="${ROOT%/}/${DOMAIN}"
DOCROOT="${PROJECT_ROOT}/public"
VENDOR="${PROJECT_ROOT}/vendor"
KONTAKT="${PROJECT_ROOT}/kontaktmailer"
LOGS="${PROJECT_ROOT}/logs"
VHOST="/etc/apache2/sites-available/${DOMAIN}.conf"

PHP_VER="$(prompt "PHP-Version (leer = automatisch)" "")"

USE_SSL="$(prompt "Let's Encrypt jetzt einrichten? (y/N)" "N")"
EMAIL_LE=""
if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
  EMAIL_LE="$(prompt "E-Mail für Let's Encrypt" "admin@${DOMAIN}")"
fi

SMTP_HOST_DEF="$(prompt "SMTP Host" "mail.${DOMAIN}")"
SMTP_USER_DEF="$(prompt "SMTP Benutzer" "no-reply@${DOMAIN}")"
SMTP_PASS_DEF="$(prompt_secret "SMTP Passwort (wird als Apache-Umgebungsvariable gesetzt)")"
[[ -n "$SMTP_PASS_DEF" ]] || die "SMTP Passwort darf nicht leer sein."
SMTP_PORT_DEF="$(prompt "SMTP Port" "587")"

CONTACT_TO="$(prompt "Empfänger-Adresse für Kontaktanfragen" "info@${DOMAIN}")"

echo
echo "=== Zusammenfassung ==="
cat <<SUM
Domain:          ${DOMAIN}
Root:            ${PROJECT_ROOT}
Webroot:         ${DOCROOT}
PHP-Version:     ${PHP_VER:-auto}
Let's Encrypt:   $( [[ "$USE_SSL" =~ ^[Yy]$ ]] && echo "JA (${EMAIL_LE})" || echo "NEIN" )
SMTP Host/User:  ${SMTP_HOST_DEF} / ${SMTP_USER_DEF}
SMTP Port:       ${SMTP_PORT_DEF}
Kontakt-Empf.:   ${CONTACT_TO}
SUM
read -rp "Weiter? (Enter)  Abbrechen mit CTRL+C " _

# ===== Pakete =====
info "Pakete installieren/aktualisieren …"
apt update -y
PKG_APACHE="apache2"
PKG_CERTBOT="certbot python3-certbot-apache"
if [[ -n "$PHP_VER" ]]; then
  PKG_PHP="libapache2-mod-php${PHP_VER} php${PHP_VER} php${PHP_VER}-cli php${PHP_VER}-mbstring php${PHP_VER}-xml php${PHP_VER}-zip php${PHP_VER}-curl"
else
  PKG_PHP="libapache2-mod-php php php-cli php-mbstring php-xml php-zip php-curl"
fi
apt install -y $PKG_APACHE $PKG_CERTBOT $PKG_PHP unzip curl git

# Composer
if ! command -v composer >/dev/null 2>&1; then
  info "Composer installieren …"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer
  php -r "unlink('composer-setup.php');"
  ok "Composer installiert."
else
  ok "Composer vorhanden: $(composer --version)"
fi

# ===== Struktur =====
info "Verzeichnisse anlegen …"
mkdir -p "$DOCROOT" "$KONTAKT" "$VENDOR" "$LOGS" \
         "$DOCROOT/css" "$DOCROOT/js" "$DOCROOT/images" "$DOCROOT/asset/css" "$DOCROOT/asset/webfonts"

# ===== Platzhalter-Dateien =====
info "Platzhalter-Dateien (überschreibbar) …"
if [[ ! -f "$DOCROOT/index.html" ]]; then
cat > "$DOCROOT/index.html" <<'EOF'
<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Website installiert</title></head><body style="font-family:sans-serif;padding:2rem">
<h1>It works 🎉</h1><p>Lege deine Website-Dateien hier in <code>public/</code> ab.</p></body></html>
EOF
fi
[[ -f "$DOCROOT/danke.html" ]] || echo "<h2>Danke für Ihre Nachricht!</h2>" > "$DOCROOT/danke.html"
[[ -f "$DOCROOT/datenschutz.html" ]] || echo "<h2>Datenschutz</h2>" > "$DOCROOT/datenschutz.html"

# sende.php Proxy
if [[ ! -f "$DOCROOT/sende.php" ]]; then
cat > "$DOCROOT/sende.php" <<'EOF'
<?php
// Öffentlicher Endpunkt – lädt die Formular-Logik außerhalb des Webroots
require __DIR__ . '/../kontaktmailer/mailer.php';
EOF
fi

# .htaccess minimal
if [[ ! -f "$DOCROOT/.htaccess" ]]; then
cat > "$DOCROOT/.htaccess" <<'EOF'
Options -Indexes
<IfModule mod_headers.c>
  Header always set X-Content-Type-Options "nosniff"
  Header always set X-Frame-Options "SAMEORIGIN"
  Header always set Referrer-Policy "no-referrer-when-downgrade"
</IfModule>
EOF
fi

# kontaktmailer/mailer.php Template (nur, wenn nicht vorhanden)
if [[ ! -f "$KONTAKT/mailer.php" ]]; then
  info "Erstelle kontaktmailer/mailer.php (Template) …"
  cat > "$KONTAKT/mailer.php" <<EOF
<?php
// Direkten Aufruf blocken
if (php_sapi_name() !== 'cli' && realpath(\$_SERVER['SCRIPT_FILENAME']) === __FILE__) {
  http_response_code(403); exit('Forbidden');
}
declare(strict_types=1);
session_start();

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require __DIR__ . '/../vendor/autoload.php';

// Nur POST
if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
  http_response_code(405); header('Allow: POST'); exit('Method Not Allowed');
}

// Mini-Rate-Limit
\$_SESSION['last_submit_ts'] = \$_SESSION['last_submit_ts'] ?? 0;
if (time() - (int)\$_SESSION['last_submit_ts'] < 8) {
  http_response_code(429); exit('Bitte etwas langsamer senden.');
}
\$_SESSION['last_submit_ts'] = time();

// Honeypot
if (!empty(\$_POST['website'] ?? '')) { header('Location: /danke.html', true, 303); exit; }

// Felder
\$rawName   = trim(\$_POST['name'] ?? '');
\$rawEmail  = trim(\$_POST['email'] ?? '');
\$rawMsg    = trim(\$_POST['message'] ?? '');
\$rawPhoneS = trim(\$_POST['phone_suffix'] ?? '');
\$ds_ok     = !empty(\$_POST['datenschutz']);

if (!\$ds_ok) { http_response_code(400); exit('Bitte Datenschutzerklärung akzeptieren.'); }
if (\$rawName === '' || \$rawEmail === '' || \$rawMsg === '') { http_response_code(400); exit('Bitte alle Pflichtfelder ausfüllen.'); }
if (!filter_var(\$rawEmail, FILTER_VALIDATE_EMAIL)) { http_response_code(400); exit('Ungültige E-Mail-Adresse.'); }
if (mb_strlen(\$rawMsg) > 5000) { http_response_code(400); exit('Nachricht ist zu lang.'); }

// Tel (CH): +41 + 9 Ziffern (wenn angegeben)
\$digits = preg_replace('/\D+/', '', \$rawPhoneS);
\$phone  = \$digits ? ('+41 ' . \$digits) : '';
if (\$digits !== '' && mb_strlen(\$digits) !== 9) {
  @mkdir(__DIR__ . '/../logs', 0775, true);
  @file_put_contents(__DIR__ . '/../logs/spam.log',
    sprintf("[%s] PHONE_BLOCK %s -> +41%s | %s | IP:%s\n", date('c'), \$rawPhoneS, \$digits, \$rawEmail, \$_SERVER['REMOTE_ADDR'] ?? '-'),
    FILE_APPEND
  );
  http_response_code(400); exit('Bitte eine gültige Schweizer Telefonnummer eingeben.');
}

// Escape
\$safe = static fn(string \$v) => htmlspecialchars(\$v, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
\$name    = \$safe(\$rawName);
\$email   = \$safe(\$rawEmail);
\$message = nl2br(\$safe(\$rawMsg));
\$phoneH  = \$safe(\$phone);

// SMTP: zuerst aus Env (vHost), sonst Defaults (aus Setup)
\$SMTP_HOST = getenv('SMTP_HOST') ?: '${SMTP_HOST_DEF}';
\$SMTP_USER = getenv('SMTP_USER') ?: '${SMTP_USER_DEF}';
\$SMTP_PASS = getenv('SMTP_PASS') ?: '${SMTP_PASS_DEF}';
\$SMTP_PORT = (int)(getenv('SMTP_PORT') ?: ${SMTP_PORT_DEF});

\$mail = new PHPMailer(true);
\$mail->CharSet = 'UTF-8';

try {
  \$mail->isSMTP();
  \$mail->Host       = \$SMTP_HOST;
  \$mail->SMTPAuth   = true;
  \$mail->Username   = \$SMTP_USER;
  \$mail->Password   = \$SMTP_PASS;
  \$mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
  \$mail->Port       = \$SMTP_PORT;

  \$mail->setFrom(\$SMTP_USER, 'Kontaktformular');
  \$mail->addAddress('${CONTACT_TO}', 'Website-Anfrage');
  \$mail->addReplyTo(\$rawEmail, \$rawName !== '' ? \$rawName : \$rawEmail);

  \$mail->isHTML(true);
  \$mail->Subject = "Neue Kontaktanfrage von {\$name}";
  \$mail->Body    = "
    <h2 style='color:#003087;margin:0 0 10px;'>Neue Nachricht über das Kontaktformular</h2>
    <p><strong>Name:</strong> {\$name}</p>
    <p><strong>E-Mail:</strong> {\$email}</p>
    <p><strong>Telefon:</strong> {\$phoneH}</p>
    <p><strong>Nachricht:</strong><br>{\$message}</p>
    <hr><p style='font-size:.9rem;color:#777'>IP: ".(\$safe(\$_SERVER['REMOTE_ADDR'] ?? '-'))." • Zeit: ".date('Y-m-d H:i:s')."</p>
  ";
  \$mail->AltBody = "Neue Kontaktanfrage von {\$rawName}\nE-Mail: {\$rawEmail}\nTelefon: {\$phone}\n\nNachricht:\n{\$rawMsg}";

  \$mail->send();
  header('Location: /danke.html', true, 303); exit;
} catch (\\Throwable \$e) {
  error_log('Kontaktformular: '.\$e->getMessage());
  http_response_code(500);
  exit('Leider gab es ein Problem beim Senden. Bitte versuchen Sie es später erneut.');
}
EOF
fi

# ===== Composer / PHPMailer =====
info "PHPMailer via Composer installieren …"
cd "$PROJECT_ROOT"
if [[ ! -f composer.json ]]; then
  composer init --no-interaction --name="${DOMAIN}/site" --require="phpmailer/phpmailer:^6.9" >/dev/null
  composer install --no-interaction
else
  composer require phpmailer/phpmailer:^6.9 --no-interaction
fi
ok "PHPMailer installiert."

# ===== Rechte =====
chown -R www-data:www-data "$VENDOR" "$LOGS"
chmod -R 750 "$LOGS"
ok "Rechte gesetzt."

# ===== Apache vHost =====
info "vHost schreiben … $VHOST"
cat > "$VHOST" <<EOF
<VirtualHost *:80>
  ServerName ${DOMAIN}
  ServerAlias www.${DOMAIN}
  DocumentRoot ${DOCROOT}

  <Directory ${DOCROOT}>
    Options -Indexes +FollowSymLinks
    AllowOverride All
    Require all granted
  </Directory>

  # SMTP-Umgebungsvariablen (werden von mailer.php gelesen)
  SetEnv SMTP_HOST "${SMTP_HOST_DEF}"
  SetEnv SMTP_USER "${SMTP_USER_DEF}"
  SetEnv SMTP_PASS "${SMTP_PASS_DEF}"
  SetEnv SMTP_PORT "${SMTP_PORT_DEF}"

  ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}_error.log
  CustomLog \${APACHE_LOG_DIR}/${DOMAIN}_access.log combined
</VirtualHost>
EOF

a2enmod rewrite headers >/dev/null
a2ensite "${DOMAIN}" >/dev/null || true
systemctl reload apache2
ok "vHost aktiv."

# ===== Let's Encrypt (optional) =====
if [[ "$USE_SSL" =~ ^[Yy]$ ]]; then
  if [[ -z "$EMAIL_LE" ]]; then
    info "Keine E-Mail für Let's Encrypt angegeben – SSL übersprungen."
  else
    info "Let's Encrypt Zertifikat holen …"
    if certbot --apache --non-interactive --agree-tos -m "${EMAIL_LE}" -d "${DOMAIN}" -d "www.${DOMAIN}"; then
      ok "SSL aktiv."
      # HSTS als conf-include setzen (sicher & updatefest)
      HSTS_CONF="/etc/apache2/conf-available/${DOMAIN}-hsts.conf"
      cat > "$HSTS_CONF" <<HST
<IfModule mod_headers.c>
  # HSTS: 1 Jahr, inkl. Subdomains (nur setzen, wenn alles per HTTPS läuft!)
  Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</IfModule>
HST
      a2enconf "$(basename "$HSTS_CONF")" >/dev/null || true
      systemctl reload apache2
      ok "HSTS gesetzt."
    else
      echo "⚠️  Certbot fehlgeschlagen. Prüfe DNS (A/AAAA) & Erreichbarkeit auf Port 80/443."
    fi
  fi
else
  info "SSL übersprungen. Später möglich mit:"
  echo "  certbot --apache -m ${EMAIL_LE:-admin@${DOMAIN}} -d ${DOMAIN} -d www.${DOMAIN}"
fi

echo
ok "Fertig. Lege jetzt deine Website-Dateien in ${DOCROOT}/ ab."
echo "Formular: action=\"sende.php\" (lädt ${KONTAKT}/mailer.php)"
echo
echo "Kurze Tests:"
echo "  curl -I http://${DOMAIN}/"
echo "  php -r \"require '${VENDOR}/autoload.php'; echo 'Autoloader OK\n';\""
echo "  curl -i -X POST http://${DOMAIN}/sende.php -d 'name=Test&email=test@example.com&message=Hallo&phone_suffix=791234567&datenschutz=on'"
