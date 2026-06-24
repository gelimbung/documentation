# KakJumBOT v31 — Tahapan Perbaikan & Prompt Odoo Codex

## Tujuan v31

Menstabilkan KakJumBOT agar tidak terus regression setiap patch. Perbaikan diarahkan ke pola:

```text
AI Interpreter dulu
↓
Intent terstruktur
↓
Action executor
↓
Odoo/Redis/Config sebagai source of truth
↓
AI menyusun jawaban sales yang empatik
```

Workflow v31 dibuat dengan prinsip **tidak membongkar total v30**. Jalur legacy masih disimpan sebagai fallback, tapi pesan valid sekarang masuk ke AI Interpreter lebih awal.

---

# Segmen 1 — Stabilkan Gerbang Masuk

## Target

Pastikan pesan WA masuk hanya diproses satu kali dan data dasar bersih.

## Node terkait

- Webhook Incoming
- Extract WA Message
- Filter Valid
- Redis Dedup Get
- Redis Dedup Mark
- Redis SameText Get
- Redis SameText Mark

## Catatan

Bagian ini tidak perlu banyak diubah karena sudah cukup aman.

Yang penting:

1. `fromMe` harus difilter.
2. pesan kosong jangan lanjut.
3. message id dedup tetap jalan.
4. same text dedup tetap pendek, 10–15 detik.

---

# Segmen 2 — Load Memory Sebelum AI

## Target

AI tidak boleh hanya membaca pesan terakhir.

Sebelum AI dipanggil, workflow harus mengambil:

1. draft aktif customer
2. chat history terakhir
3. pesan customer saat ini

## Key Redis

```text
draft:{phone}
chat:{phone}
```

## Struktur chat history

```json
[
  {"role":"customer", "text":"ajwa berapa kak", "ts":"..."},
  {"role":"bot", "text":"Ajwa 1Kg Pouch ...", "ts":"..."}
]
```

## Fungsi

Agar AI bisa memahami:

- `yang tadi`
- `yang kedua`
- `stoknya ada?`
- `yang lebih murah?`
- `tambah 1 lagi`

---

# Segmen 3 — AI Interpreter Wajib untuk Setiap Pesan

## Target

Menghapus pola lama:

```text
kalau looksOrderish baru AI
kalau activeDraft langsung deterministic
```

Diganti menjadi:

```text
semua pesan valid
↓
AI Interpreter
↓
intent JSON
```

## Output AI wajib JSON

```json
{
  "intent": "PRODUCT_PRICE",
  "confidence": 0.92,
  "normalized_message": "Tanya harga Sukari",
  "is_interrupt": true,
  "needs_odoo": true,
  "needs_config": false,
  "draft_action": "none",
  "product_query": "Sukari",
  "reference_product": "",
  "items": [],
  "customer_data": {},
  "missing_fields": [],
  "reply_hint": "Jawab harga dan ingatkan draft masih tersimpan"
}
```

## Intent utama

```text
PRODUCT_PRICE
PRODUCT_STOCK
PRODUCT_DETAIL
PRODUCT_COMPARE
PRODUCT_RECOMMENDATION
STORE_HOURS
STORE_LOCATION
SHIPPING_INFO
SMALL_TALK
ORDER_DATA
ADD_TO_CART
EDIT_CART
REMOVE_ITEM
CHECKOUT_CONFIRM
CANCEL_ORDER
UNKNOWN
```

---

# Segmen 4 — Pending Draft Tidak Boleh Menelan Chat Selingan

## Target

Saat draft pending, pesan baru tetap dibaca sebagai intent baru.

Contoh:

```text
Draft pending shareloc
Customer: harga sukari berapa kak?
```

Bot harus:

1. jawab harga Sukari dari Odoo
2. ingatkan draft masih disimpan
3. jangan langsung minta shareloc tanpa menjawab pertanyaan

Contoh jawaban:

```text
Sukari ada beberapa pilihan kak 😊

1. Sukari Premium 500Gr — Rp ...
2. Sukari Grade A 3Kg — Rp ...

Draft pesanan kak masih saya simpan ya 🙏
Untuk lanjut Kirim Ojol, nanti mohon kirim share location.
```

---

# Segmen 5 — Produk, Harga, Stok, Deskripsi Wajib dari Odoo

## Target

Hilangkan hardcode harga dari n8n.

Intent yang harus memanggil Odoo:

```text
PRODUCT_PRICE
PRODUCT_STOCK
PRODUCT_DETAIL
PRODUCT_COMPARE
PRODUCT_RECOMMENDATION
```

## Endpoint Odoo baru yang dibutuhkan

```text
POST /api/chatbot/product_info
```

Request:

```json
{
  "intent": "PRODUCT_PRICE",
  "query": "Sukari",
  "limit": 10
}
```

Response:

```json
{
  "ok": true,
  "products": [
    {
      "id": 123,
      "name": "Sukari Grade A 3Kg",
      "price": 145000,
      "stock": 20,
      "uom": "pcs",
      "description_sale": "...",
      "website_description": "..."
    }
  ]
}
```

Rule:

- Jika 1 produk exact match, tampilkan 1 produk.
- Jika lebih dari 1, tampilkan semua yang relevan.
- Jangan pilih sendiri kalau ambigu.
- Jangan hardcode harga di JS.

---

# Segmen 6 — Jam Buka dan Lokasi dari Config/Odoo

## Endpoint Odoo baru

```text
POST /api/chatbot/store_config
```

Request:

```json
{
  "intent": "STORE_HOURS"
}
```

Response:

```json
{
  "ok": true,
  "config": {
    "store_hours": "Senin–Sabtu 09.00–16.30, istirahat 11.30–12.30",
    "store_address": "...",
    "maps_url": "...",
    "pricelist_url": "https://kurma2.com/pricelist/view/1",
    "shopee_url": "https://shopee.co.id/tokoaljumuah",
    "tokopedia_url": "https://tokopedia.com/tokoaljumuah",
    "shipping_info": "Pengiriman bisa Kirim Ojol atau Diambil di toko"
  }
}
```

---

# Segmen 7 — Pertahankan Jalur Legacy sebagai Fallback

## Target

Jangan langsung buang Core Router lama.

Flow v31:

```text
AI Interpreter
↓
AI First Route
├─ product_info → Odoo Product Info
├─ store_config → Odoo Store Config
├─ direct_reply → Send WA
└─ legacy → Core Router lama
```

Artinya:

- FAQ produk tidak lagi ditangani hardcode.
- FAQ toko tidak lagi ditangani hardcode.
- Order form, add cart, cancel cart lama masih bisa jalan melalui legacy.

---

# Segmen 8 — Regression Test Wajib

Setelah import workflow dan patch Odoo, test minimal ini harus PASS.

## A. FAQ umum

```text
halo
jam buka?
toko tutup jam berapa?
alamat toko jumuah mana?
```

## B. Compact order

```text
skri grda 3k 2ds rifki kariadi ojol
```

Expected:

```text
Sukari Grade A 3Kg qty 2 dus
Nama Rifki
Alamat RS Kariadi
Pengiriman Kirim Ojol
```

## C. Pending location + chat selingan

Saat draft pending shareloc:

```text
harga sukari berapa kak?
alamat toko jumuah mana
Sukari sama Ajwa enak mana kak?
Oleh oleh haji umroh yang bagus apa?
```

Expected:

- Jawab pertanyaan dulu.
- Draft tetap disimpan.
- Tidak langsung minta shareloc tanpa menjawab.

## D. Product price dari Odoo

```text
ajwa berapa kak?
tunisia berapa kak?
harga tunisia madu?
sukari berapa?
```

Expected:

- semua cek Odoo
- jika banyak varian tampil semua
- tidak hardcode

## E. Specific query jangan turun

```text
Ajwa 1Kg Pouch 1 dus
```

Expected:

- query tetap `Ajwa 1Kg Pouch`
- tidak turun menjadi `Ajwa`

## F. Add item / add qty

```text
tambah ajwa 1
Ajwa 1Kg Pouch tambah 3
tambah 3 ajwa
yang tadi tambah 1
```

## G. Cancel item

```text
Ajwa 1Kg Pouch batal
no 2 batal kak
ajwanya jangan dulu
YA BATAL
```

---

# Prompt Codex untuk Perbaikan Odoo

Gunakan prompt berikut di Codex pada project Odoo custom module.

```text
Saya punya Odoo 18 CE untuk Toko Al Jumuah dan workflow n8n KakJumBOT. Tolong tambahkan endpoint JSON API untuk chatbot agar n8n tidak hardcode harga/stok/deskripsi/jam buka/lokasi.

Kondisi saat ini:
- Sudah ada endpoint order/quote lama:
  - POST /api/chatbot/quote
  - POST /api/chatbot/order
- Authentication pakai header X-API-Key atau header auth yang sudah ada.
- Jangan rusak endpoint lama.
- Tambahkan endpoint baru dengan response JSON konsisten.

Endpoint 1:
POST /api/chatbot/product_info

Request:
{
  "intent": "PRODUCT_PRICE|PRODUCT_STOCK|PRODUCT_DETAIL|PRODUCT_COMPARE|PRODUCT_RECOMMENDATION",
  "query": "Sukari",
  "limit": 10
}

Tugas endpoint:
1. Search produk dari product.template/product.product berdasarkan query.
2. Harus fuzzy friendly untuk typo ringan:
   - skri/sukri/sokari/sukary => Sukari
   - ajwah => Ajwa
   - grd a/gd a/gr a/grda => Grade A
   - grd b/gd b/gr b/grdb => Grade B
   - 3k/3kg => 3Kg
   - 1k/1kg => 1Kg
   - 500 g/500gr => 500Gr
3. Jangan menurunkan query spesifik. Jika query "Ajwa 1Kg Pouch", prioritaskan exact/contains match dengan nama lengkap itu, jangan ubah menjadi Ajwa saja.
4. Jika ada exact match, letakkan exact match paling atas.
5. Jika ada banyak varian, return semua varian relevan sesuai limit.
6. Return harga dari list_price atau price yang dipakai toko.
7. Return stok dari qty_available/free_qty sesuai konfigurasi yang aman untuk sales.
8. Return deskripsi dari prioritas:
   - website_description
   - description_sale
   - description
9. Jangan mengarang data jika tidak ada.

Response sukses:
{
  "ok": true,
  "query": "Sukari",
  "normalized_query": "Sukari",
  "products": [
    {
      "id": 123,
      "product_tmpl_id": 45,
      "name": "Sukari Grade A 3Kg",
      "default_code": "A010001",
      "price": 145000,
      "stock": 20,
      "uom": "pcs",
      "description_sale": "...",
      "website_description": "...",
      "is_exact": false
    }
  ]
}

Response tidak ketemu:
{
  "ok": false,
  "query": "...",
  "normalized_query": "...",
  "products": [],
  "error": "product_not_found"
}

Endpoint 2:
POST /api/chatbot/store_config

Request:
{
  "intent": "STORE_HOURS|STORE_LOCATION|SHIPPING_INFO|MARKETPLACE_LINKS|PAYMENT_INFO"
}

Tugas endpoint:
Return konfigurasi toko dari ir.config_parameter atau model config custom. Jika belum ada, buat default parameter yang mudah diubah dari Odoo Settings/System Parameters.

Config key yang dibutuhkan:
- chatbot.store_hours
- chatbot.store_address
- chatbot.maps_url
- chatbot.pricelist_url
- chatbot.shopee_url
- chatbot.tokopedia_url
- chatbot.shipping_info
- chatbot.payment_info

Response:
{
  "ok": true,
  "config": {
    "store_hours": "Senin–Sabtu 09.00–16.30, istirahat 11.30–12.30",
    "store_address": "...",
    "maps_url": "...",
    "pricelist_url": "https://kurma2.com/pricelist/view/1",
    "shopee_url": "https://shopee.co.id/tokoaljumuah",
    "tokopedia_url": "https://tokopedia.com/tokoaljumuah",
    "shipping_info": "Pengiriman bisa Kirim Ojol atau Diambil di toko",
    "payment_info": "..."
  }
}

Keamanan:
- Wajib validasi API key sama seperti endpoint lama.
- Jangan expose cost/modal supplier.
- Jangan expose produk inactive/sale_ok false.
- Jangan return terlalu banyak field internal.
- Limit default 10, max 20.

Tambahkan logging ringkas untuk debug:
- query asli
- normalized query
- jumlah hasil
- intent

Tambahkan test manual minimal:
1. query "sukari" return semua varian sukari.
2. query "Ajwa 1Kg Pouch" return exact match paling atas dan tidak turun menjadi Ajwa saja.
3. query "skri grda 3k" return Sukari Grade A 3Kg.
4. query "tunisia madu" return produk terkait jika ada.
5. store_config return jam buka, alamat, maps, link katalog.

Jangan ubah endpoint /quote dan /order yang sudah ada kecuali hanya refactor kecil yang tidak mengubah contract response lama.
```
