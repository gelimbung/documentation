# Panduan Backup Database Odoo dan Filestores
## 1.Backup Database Odoo (pg_dump)
```bash
pg_dump -U odoo -h localhost -p 5432 nama_database > odoo_backup.sql
```
## 1.Backup Filestore
Lokasi Filestore
```bash
tar -czvf filestore_nama_db.tar.gz filestore/nama_database
```

# 🐳 Panduan Memindahkan Database Odoo ke Role `odoo` (Docker)

Panduan ini digunakan jika:
- Database Odoo hasil restore masih dimiliki `postgres`
- Muncul error `permission denied for schema public`
- Odoo & PostgreSQL berjalan di Docker

---

## 🎯 Target Akhir
- Owner database = `odoo`
- Owner schema `public` = `odoo`
- Semua TABLE, SEQUENCE, VIEW di schema `public` = `odoo`
- Odoo bisa start & install module tanpa error permission

---

## 🧩 Asumsi
- Nama database: `odoo_prod`
- Role Odoo: `odoo`
- Container PostgreSQL: `db_postgres`
- Container Odoo: `odoo17`

---

## 1️⃣ Login ke PostgreSQL (Superuser)
```bash
docker exec -it db_postgres psql -U postgres
```

---

## 2️⃣ Pastikan Role `odoo` Ada
```sql
\du
```

Jika belum ada:
```sql
CREATE ROLE odoo WITH LOGIN PASSWORD 'passwordku';
```

---

## 3️⃣ Putuskan Semua Koneksi ke Database
```sql
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'odoo_prod'
  AND pid <> pg_backend_pid();
```

---

## 4️⃣ Ubah Owner Database ke `odoo`
```sql
ALTER DATABASE odoo_prod OWNER TO odoo;
```

Verifikasi:
```sql
\l odoo_prod
```

---

## 5️⃣ Ambil Alih Schema `public`
```sql
\c odoo_prod

ALTER SCHEMA public OWNER TO odoo;
GRANT USAGE, CREATE ON SCHEMA public TO odoo;
```

---

## 6️⃣ Pindahkan Semua TABLE
```sql
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname='public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I OWNER TO odoo', r.tablename);
  END LOOP;
END$$;
```

---

## 7️⃣ Pindahkan Semua SEQUENCE
```sql
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT sequencename FROM pg_sequences WHERE schemaname='public'
  LOOP
    EXECUTE format('ALTER SEQUENCE public.%I OWNER TO odoo', r.sequencename);
  END LOOP;
END$$;
```

---

## 8️⃣ Pindahkan Semua VIEW (Disarankan)
```sql
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT table_name FROM information_schema.views WHERE table_schema='public'
  LOOP
    EXECUTE format('ALTER VIEW public.%I OWNER TO odoo', r.table_name);
  END LOOP;
END$$;
```

---

## 9️⃣ Set Default Privileges
```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON TABLES TO odoo;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON SEQUENCES TO odoo;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT ALL ON FUNCTIONS TO odoo;
```

---

## 🔍 10️⃣ Verifikasi
```sql
SELECT datname, pg_get_userbyid(datdba) AS owner
FROM pg_database
WHERE datname = 'odoo_prod';

SELECT nspname, pg_get_userbyid(nspowner) AS owner
FROM pg_namespace
WHERE nspname = 'public';
```

---

## 🔁 11️⃣ Restart Odoo
```bash
docker restart odoo17
docker logs -f odoo17
```

---

## ⚠️ Catatan Penting
❌ Jangan jalankan:
```sql
REASSIGN OWNED BY postgres TO odoo;
```

Karena object sistem PostgreSQL tidak boleh dipindahkan.

---

✅ Selesai. Database Odoo siap dipakai production.
