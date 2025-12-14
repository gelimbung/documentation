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

# Sintaks Penting

Beberapa sintaks penting untuk troubleshoot
## 1. Masuk ke bash container
```bash
docker exec -it <nama_container atau id_container> bash
```
## 2. Restore pg_dump
Jika database BELUM ADA
```bash
docker exec -it postgres createdb -U postgres nama_db
```
Lalu restore
```bash
docker exec -i postgres pg_restore -U postgres -d nama_db  < backup.dump
```
