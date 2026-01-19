# Odoo HTTPS & Google OAuth Setup
## Docker + nginx-proxy + Cloudflare

Dokumentasi utama untuk setup, migrasi, dan rebuild Odoo agar HTTPS konsisten
dan Google OAuth tidak redirect ke HTTP.

---

## Arsitektur Singkat

Browser  
→ Cloudflare (HTTPS)  
→ nginx-proxy (container)  
→ Odoo (container)

---

## Struktur Folder nginx

```
/opt/odoo_stack/nginx/
├── conf.d/
├── vhost.d/
│   └── kurma2.com
├── html/
└── docker-compose.yml
```

---

## Konfigurasi nginx vhost

Lokasi file:
```
/opt/odoo_stack/nginx/vhost.d/kurma2.com
```

Isi file:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Proto https;
proxy_set_header X-Forwarded-Port 443;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

---

## Konfigurasi Odoo

### odoo.conf
```ini
proxy_mode = True
```

### docker-compose.yml
```yaml
services:
  odoo:
    image: odoo:18
    environment:
      - PROXY_MODE=True
```

---

## Database Check

```sql
SELECT key, value
FROM ir_config_parameter
WHERE key LIKE 'web.base%';
```

Nilai:
```
web.base.url = https://kurma2.com
```

---

## Restart

```bash
nginx -t
docker restart nginx
docker restart odoo
```

---

## Verifikasi OAuth

```
redirect_uri=https://kurma2.com/auth_oauth/signin
```
