# 🚀 Panduan Migrasi VPS & Instalasi Paket Wajib

## 1. Update Sistem

``` bash
apt update && apt upgrade -y
```

## 2. Install Paket Wajib VPS

``` bash
apt install -y \
    curl wget git unzip tar nano ufw htop net-tools \
    ca-certificates gnupg lsb-release
```

## 3. Install Docker

``` bash
curl -fsSL https://get.docker.com | sh
```

## 4. Install Docker Compose Plugin

``` bash
apt install docker-compose-plugin -y
```

## 5. Siapkan Folder Stack

``` bash
mkdir -p /opt/odoo_stack
cd /opt/odoo_stack
```

## 6. Backup dari Server Lama

``` bash
tar -czvf odoo-backup.tar.gz /opt/odoo_stack
scp odoo-backup.tar.gz root@IP_BARU:/opt/
```

## 7. Restore Backup di VPS Baru

``` bash
cd /opt
tar -xzvf odoo-backup.tar.gz
cd /opt/odoo_stack
docker compose up -d
```

## 8. Cek Semua Layanan

### Docker

``` bash
docker ps
```

### Mailserver

``` bash
docker logs mailserver | tail
```

### Proxy + SSL

``` bash
docker logs nginx-proxy | tail
docker logs acme-companion | tail
```

### PostgreSQL

``` bash
docker exec -it db_postgres psql -U odoo -d postgres
```

### MySQL

``` bash
docker exec -it mysql mysql -u root -p
```

## 9. Test Email Brevo Relay

``` bash
docker exec -it mailserver sh -c "echo 'Hallo' | mail -s 'Test' youremail@gmail.com"
docker logs mailserver | tail -n 50
```

## 10. Script Auto-Install VPS Baru

``` bash
#!/bin/bash
apt update && apt upgrade -y
apt install -y \
    curl wget git unzip tar nano ufw htop net-tools \
    ca-certificates gnupg lsb-release
curl -fsSL https://get.docker.com | sh
apt install docker-compose-plugin -y
mkdir -p /opt/odoo_stack
echo "Selesai! VPS siap restore backup."
```

# UFW Firewall Rules – Migrasi VPS

Konfigurasi berikut menyalin firewall dari VPS lama ke VPS baru (IPv4 & IPv6).

## 1. Allow Ports

```bash
sudo ufw allow 22/tcp
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 993/tcp
sudo ufw allow 143/tcp
sudo ufw allow 2222/tcp
```

## 2. Allow Ports
```bash
sudo ufw deny 9443/tcp
```

## 3. Pastikan IPv6 UFW Aktif
```bash
sudo nano /etc/ufw/ufw.conf
```
Isi harus seperti ini:
```bash
IPV6=yes
```
## 4. Enable / Reload UFW
```bash
sudo ufw enable
# jika sudah aktif:
sudo ufw reload
```

## 4. Cek Status Firewall
```bash
sudo ufw status numbered

```

# Sintaks Penting Selama konfigurasi

Beberapa sintaks penting untuk troubleshoot
## 1. Masuk ke bash container
not root
```bash
docker exec -it <nama_container atau id_container> bash
```
root
```bash
docker exec -u 0 -it <odoo-container> bash
```

## 2. Backup & Restore pg_dump dan filestore
Backup Database 
```bash
cd /tmp
sudo -u postgres pg_dump -Fc --no-owner --no-privileges nama_db > /tmp/nama_db.dump
```
Restore Database
Create DB Jika database BELUM ADA
```bash
docker exec -it db_postgres createdb -U postgres odoo17_prod
```
Lalu restore
```bash
docker exec -i db_postgres pg_restore -U postgres --no-owner --no-privileges -d odoo17_prod  < backup.dump
```
Hapus database 
```bash
docker exec -it db_postgres dropdb -U postgres odoo17_prod
```
❌ Jika tidak bisa dihapus
```bash
docker exec -it db_postgres psql -U postgres
```
Cek session aktif
```bash
SELECT pid, usename, application_name, client_addr, state
FROM pg_stat_activity
WHERE datname = 'odoo_prod';
```
Kill session aktif
```bash
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'odoo_prod'
  AND pid <> pg_backend_pid();
```

Backup filestore
Path Location
```bash
/var/lib/odoo/.local/share/Odoo/filestore/
```
```bash
tar -czvf filestore_nama_db.tar.gz filestore/nama_database
```

## 3. Extract Tar 
folder tertentu
```bash
tar -xvzf file.tar.gz -C /opt/odoo17
```
folder here
```bash
tar -xvzf file.tar.gz
```
📌 Penjelasan opsi
1. `x` → extract  
1. `v` → verbose  
1. `z` → gzip  
1. `f` → file

_Tidak pakai -C → otomatis extract di folder tempat kamu berdiri sekarang_

## 4. Log container 
```bash
docker logs --tail 100 -f odoo
```

## 5. Copy file dari host ke container docker
```bash
docker cp odoo.conf odoo:/etc/odoo/odoo.conf
```
## 6. Recreate container Odoo supaya env baru kepakai
```bash
docker compose up -d --force-recreate odoo17-jumuah odoo17-sadean
```

## 7. Cek Odoo dari DALAM container nginx-proxy
```bash
docker exec -it nginx-proxy curl -I http://odoo18-sadean:8069
docker exec -it nginx-proxy curl -I http://odoo17-jumuah:8069
docker exec -it nginx-proxy curl -I http://odoo17-sadean:8069
```
Jika RUNNING:
```bash
HTTP/1.1 200 OK
```
atau
```bash
HTTP/1.1 303 SEE OTHER
```

## 8. Error karena package python tidak lengkap di Container
Buat file `Dockerfile` satu folder dengan `docker-compose.yml` 
```bash
#Dockerfile
FROM odoo:18

USER root

# Pastikan pip ada + install qifparse (PEP668 fix)
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3-pip \
 && python3 -m pip install --no-cache-dir --break-system-packages qifparse \
 && apt-get purge -y python3-pip \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

USER odoo
```
Update docker-compose.yml, tambahkan sintax `build: . `
```bash
services:
  odoo:
    build:
      context: .
      dockerfile: Dockerfile.odoo

```
Build ulang
```bash
docker compose build --no-cache
docker compose up -d
```

## 9. Error setelah ganti domain
#### Langkahnya: 
1. Ganti VIRTUAL_HOST + LETSENCRYPT_HOST -> .env file
2. docker compose down
3. hapus cert domain lama
Hapus sertifikat domain lama di volume odoo_stack_nginx_certs
Ganti domainlama.com dengan domain yang lama (yang mau dibuang):
```bash
docker run --rm -v odoo_stack_nginx_certs:/certs alpine sh -c "ls -lah /certs && rm -rf /certs/domainlama.com*"
```
Kalau domain lama ada wildcard / subdomain (mis. www.domainlama.com), hapus juga:
```bash
docker run --rm -v odoo_stack_nginx_certs:/certs alpine sh -c "rm -rf /certs/www.domainlama.com*"
```
#### Cek lagi isi folder cert:
```bash
docker run --rm -v odoo_stack_nginx_certs:/certs alpine sh -c "ls -lah /certs"
```
4. docker compose up -d --force-recreate
```bash
docker compose down
docker compose up -d --force-recreate
```
5. cek log letsencrypt
Nama containernya bisa beda-beda (mis. nginx-proxy-acme, letsencrypt, acme-companion). Cek yang jalan:
```bash
docker ps --format "table {{.Names}}\t{{.Image}}"
```
Lalu tail log container ACME (contoh, ganti NAMA_ACME_CONTAINER):
```bash
docker logs -f NAMA_ACME_CONTAINER
```
