# Odoo HTTPS & OAuth Troubleshooting

---

## OAuth Redirect Masih HTTP

Pastikan header nginx:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header X-Forwarded-Proto https;
```

Restart:
```bash
docker restart nginx
docker restart odoo
```

---

## Cek vhost nginx

```bash
nginx -T | grep kurma2.com
```

---

## Cek proxy_mode

```bash
printenv | grep PROXY_MODE
```

---

## Cloudflare

- SSL/TLS: Full (strict)
- Jangan Flexible
