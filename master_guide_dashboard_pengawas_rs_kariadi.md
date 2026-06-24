# MASTER GUIDE
# Dashboard Laporan Pengawas RS Kariadi
## Laravel + Inertia + Vue + SQL Server REPORT + Groq

Dokumen ini adalah panduan kerja step-by-step untuk membangun aplikasi Dashboard Laporan Pengawas RS Kariadi.

Target aplikasi:
- Dashboard laporan pengawas berbasis database REPORT
- Database REPORT menyediakan stored procedure laporan/dashboard
- Laravel membaca REPORT melalui Repository
- Inertia + Vue untuk UI SPA-style
- Groq untuk narasi insight AI
- Snapshot untuk laporan final
- Export PDF/PPT tahap lanjutan

---

## 0. Prinsip Besar Project

Arsitektur:
```text
Laravel Modular Monolith
Backend dan frontend dalam satu project
Frontend memakai Inertia + Vue
Data berasal dari database REPORT
AI Groq hanya untuk narasi insight
```

Alur data:
```text
HMIS
↓
Database REPORT
↓
Stored Procedure schema rpt
↓
Laravel Repository
↓
Laravel Service
↓
Inertia Props
↓
Vue Dashboard
↓
Groq Insight
↓
Snapshot Laporan
↓
Export
```

Aturan utama:
1. Laravel tidak query langsung ke HMIS.
2. Laravel membaca database REPORT.
3. Semua stored procedure dashboard berada di schema `rpt`.
4. Stored procedure memakai prefix `usp_dashboard_`, bukan `sp_`.
5. Controller tidak boleh panggil stored procedure langsung.
6. Repository memanggil stored procedure.
7. Service mapping data, cache, flag, dan logic dashboard.
8. Vue hanya menampilkan data.
9. Navigasi menu memakai Inertia Link, bukan full reload.
10. Groq hanya membuat narasi dari data agregat.

---

# TAHAP 1 — Create First Project Laravel

## Tujuan
Membuat project Laravel awal yang siap dipasang Inertia + Vue.

## Langkah

Buka PowerShell atau terminal VSCode.

```powershell
cd D:\Projects
composer create-project laravel/laravel pengawas-dashboard
cd pengawas-dashboard
```

Cek Laravel:

```powershell
php artisan --version
```

Jalankan server:

```powershell
php artisan serve
```

Buka:

```text
http://127.0.0.1:8000
```

## Commit

```powershell
git init
git add .
git commit -m "chore: create initial laravel project"
```

---

# TAHAP 2 — Install Inertia + Vue Starter

## Tujuan
Membuat frontend modern tetapi tetap satu project Laravel.

## Pilihan yang disarankan
Gunakan starter kit Laravel Vue/Inertia atau Breeze Vue, tergantung versi Laravel yang dipakai.

Jika project bos sudah punya Breeze/Inertia, lewati install ulang.

## Cek folder

Pastikan ada:

```text
resources/js
resources/js/Pages
resources/js/Layouts
resources/js/Components
```

Jika belum ada, install Breeze Vue:

```powershell
composer require laravel/breeze --dev
php artisan breeze:install vue
npm install
php artisan migrate
npm run dev
```

Terminal 1:

```powershell
php artisan serve
```

Terminal 2:

```powershell
npm run dev
```

## Test
- Login page tampil
- Register/login bisa dibuka
- Tidak ada error Vite

## Commit

```powershell
git add .
git commit -m "chore: install inertia vue starter"
```

---

# TAHAP 3 — Setup Database Aplikasi Dashboard

## Tujuan
Membuat database aplikasi untuk user, role, periode laporan, snapshot, insight AI, dan laporan manual.

Database ini berbeda dari REPORT.

Contoh nama:

```text
db_pengawas_dashboard
```

## SQL Server

Di SSMS:

```sql
CREATE DATABASE db_pengawas_dashboard;
GO

CREATE LOGIN dashboard_app WITH PASSWORD = 'GantiPasswordKuat123!';
GO

USE db_pengawas_dashboard;
GO

CREATE USER dashboard_app FOR LOGIN dashboard_app;
GO

ALTER ROLE db_owner ADD MEMBER dashboard_app;
GO
```

## .env Laravel

```env
DB_CONNECTION=sqlsrv
DB_HOST=127.0.0.1
DB_PORT=1433
DB_DATABASE=db_pengawas_dashboard
DB_USERNAME=dashboard_app
DB_PASSWORD=GantiPasswordKuat123!
DB_TRUST_SERVER_CERTIFICATE=true
```

Clear config:

```powershell
php artisan config:clear
php artisan cache:clear
php artisan migrate
```

## Commit

```powershell
git add .
git commit -m "chore: configure dashboard application database"
```

---

# TAHAP 4 — Setup Database REPORT

## Tujuan
Menjadikan database REPORT sebagai reporting layer.

## Schema

Di SSMS:

```sql
USE REPORT;
GO

CREATE SCHEMA rpt;
GO

CREATE SCHEMA ref;
GO

CREATE SCHEMA log;
GO
```

Keterangan:
- `rpt`: stored procedure dashboard/laporan
- `ref`: mapping dan registry
- `log`: log eksekusi/error

## Registry Stored Procedure

```sql
USE REPORT;
GO

CREATE TABLE ref.stored_procedure_registry (
    id INT IDENTITY(1,1) PRIMARY KEY,
    module_name VARCHAR(100) NOT NULL,
    procedure_schema VARCHAR(50) NOT NULL,
    procedure_name VARCHAR(150) NOT NULL,
    description VARCHAR(500) NULL,
    input_parameters VARCHAR(MAX) NULL,
    output_columns VARCHAR(MAX) NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'draft',
    pic_validator VARCHAR(150) NULL,
    notes VARCHAR(MAX) NULL,
    created_at DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    updated_at DATETIME2 NULL
);
GO
```

## User Read-Only untuk Laravel

```sql
CREATE LOGIN dashboard_report_reader
WITH PASSWORD = 'GantiPasswordKuat123!';
GO

USE REPORT;
GO

CREATE USER dashboard_report_reader FOR LOGIN dashboard_report_reader;
GO

GRANT EXECUTE ON SCHEMA::rpt TO dashboard_report_reader;
GO

GRANT SELECT ON SCHEMA::ref TO dashboard_report_reader;
GO
```

---

# TAHAP 5 — Dummy Stored Procedure BOR

## Tujuan
Membuat dummy data agar frontend dan backend bisa dibangun sambil menunggu query asli.

## BOR Summary

```sql
USE REPORT;
GO

CREATE OR ALTER PROCEDURE rpt.usp_dashboard_bor_summary
    @tanggal_awal DATETIME,
    @tanggal_akhir DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        1195 AS total_tt,
        912 AS pasien_dirawat,
        206 AS sisa_tt,
        CAST(77.62 AS DECIMAL(5,2)) AS bor_persen,
        77 AS tt_to,
        'naik' AS trend_status;
END;
GO
```

## BOR Per Kelas

```sql
CREATE OR ALTER PROCEDURE rpt.usp_dashboard_bor_by_class
    @tanggal_awal DATETIME,
    @tanggal_akhir DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 'KELAS 1' AS kelas, 187 AS kapasitas_tt, 164 AS tt_terisi, 23 AS sisa_tt, CAST(87.70 AS DECIMAL(5,2)) AS bor_persen, '' AS keterangan
    UNION ALL
    SELECT 'KELAS 2', 164, 144, 20, CAST(87.80 AS DECIMAL(5,2)), ''
    UNION ALL
    SELECT 'KELAS 3', 442, 367, 75, CAST(83.03 AS DECIMAL(5,2)), '';
END;
GO
```

## BOR Trend

```sql
CREATE OR ALTER PROCEDURE rpt.usp_dashboard_bor_trend
    @tanggal_awal DATETIME,
    @tanggal_akhir DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST('2026-06-20' AS DATE) AS tanggal, CAST(75.10 AS DECIMAL(5,2)) AS nilai_bor, 'naik' AS trend_status
    UNION ALL
    SELECT CAST('2026-06-21' AS DATE), CAST(76.40 AS DECIMAL(5,2)), 'naik'
    UNION ALL
    SELECT CAST('2026-06-22' AS DATE), CAST(77.62 AS DECIMAL(5,2)), 'naik';
END;
GO
```

## Test di SSMS

```sql
EXEC rpt.usp_dashboard_bor_summary
    @tanggal_awal = '2026-06-22 15:30:00',
    @tanggal_akhir = '2026-06-23 07:00:00';

EXEC rpt.usp_dashboard_bor_by_class
    @tanggal_awal = '2026-06-22 15:30:00',
    @tanggal_akhir = '2026-06-23 07:00:00';

EXEC rpt.usp_dashboard_bor_trend
    @tanggal_awal = '2026-06-22 15:30:00',
    @tanggal_akhir = '2026-06-23 07:00:00';
```

---

# TAHAP 6 — Pasang Knowledge MD Files

## Tujuan
Membuat knowledge project agar AI/Codex tidak liar.

## Buat Folder

```powershell
New-Item -ItemType Directory -Force docs
New-Item -ItemType Directory -Force docs\modules
New-Item -ItemType Directory -Force docs\modules\bor
New-Item -ItemType Directory -Force docs\modules\rawat-jalan
New-Item -ItemType Directory -Force docs\modules\igd
New-Item -ItemType Directory -Force docs\modules\operasi
New-Item -ItemType Directory -Force docs\modules\simrs
New-Item -ItemType Directory -Force docs\adr
```

## Buat File

```powershell
New-Item -ItemType File -Force docs\PROJECT_BRIEF.md
New-Item -ItemType File -Force docs\PLAYBOOK.md
New-Item -ItemType File -Force docs\AI_RULES.md
New-Item -ItemType File -Force docs\FEATURE_CATALOG.md
New-Item -ItemType File -Force docs\STORED_PROCEDURE_REGISTRY.md
New-Item -ItemType File -Force docs\API_CONTRACT.md
New-Item -ItemType File -Force docs\TEST_MATRIX.md
New-Item -ItemType File -Force docs\CHANGELOG.md
New-Item -ItemType File -Force docs\NO_TOUCH_LIST.md
New-Item -ItemType File -Force docs\PROMPT_LIBRARY.md
New-Item -ItemType File -Force docs\THEME_GUIDE.md

New-Item -ItemType File -Force docs\modules\bor\README.md
New-Item -ItemType File -Force docs\modules\rawat-jalan\README.md
New-Item -ItemType File -Force docs\modules\igd\README.md
New-Item -ItemType File -Force docs\modules\operasi\README.md
New-Item -ItemType File -Force docs\modules\simrs\README.md
```

## Isi Singkat File Wajib

### PROJECT_BRIEF.md
```md
# Project Brief

Aplikasi ini adalah Dashboard Laporan Pengawas RS Kariadi.

Arsitektur:
Laravel Modular Monolith + Inertia + Vue.

Data utama:
Database REPORT melalui stored procedure schema rpt.

AI:
Groq untuk narasi insight dari data agregat.

Frontend:
Inertia SPA-style. Sidebar/topbar tetap, content berubah.
```

### AI_RULES.md
```md
# AI Rules

1. Jangan query langsung ke HMIS.
2. Laravel membaca database REPORT.
3. Semua akses REPORT lewat Repository.
4. Logic dashboard lewat Service.
5. Controller tidak memanggil stored procedure langsung.
6. Vue hanya untuk tampilan.
7. Navigasi menu pakai Inertia Link.
8. Jangan full reload.
9. Groq hanya untuk narasi insight.
10. Jangan kirim data pribadi pasien ke Groq.
11. Semua UI mengikuti THEME_GUIDE.md.
```

### NO_TOUCH_LIST.md
```md
# No Touch List

Tidak boleh diubah tanpa izin:
1. Koneksi REPORT.
2. Stored procedure production.
3. Output stored procedure stabil.
4. DashboardLayout.vue.
5. Sidebar.
6. PeriodFilter.
7. KpiCard.
8. DataTable.
9. InsightPanel.
10. Snapshot locked.
11. Theme token kariadi.
```

### STORED_PROCEDURE_REGISTRY.md
```md
# Stored Procedure Registry

Naming:
rpt.usp_dashboard_[module]_[function]

Contoh:
- rpt.usp_dashboard_bor_summary
- rpt.usp_dashboard_bor_by_class
- rpt.usp_dashboard_bor_trend

Jangan pakai prefix sp_.

Stored procedure adalah kontrak data.
Jika output berubah besar, buat versi baru.
```

### API_CONTRACT.md
```md
# API / Inertia Props Contract

Backend mengirim data ke Vue melalui Inertia props.

Vue tidak boleh bergantung ke nama kolom mentah jika sudah dimapping Service.

Contoh BOR:
summary.totalBeds
summary.occupiedBeds
summary.availableBeds
summary.borPercentage
```

### THEME_GUIDE.md
```md
# Theme Guide

Nama theme:
Kariadi Medical Dashboard

Primary:
#00848B

Tosca:
#00BAAF

Cyan:
#33CAD6

Lime:
#CEDD28

Yellow:
#F8EC12

Background:
#F6FAFA

Card:
#FFFFFF

Karakter UI:
clean, formal, modern, medical dashboard, mudah dibaca.

Navigasi:
Sidebar/topbar persistent.

Komponen:
KpiCard, DataTable, InsightPanel, AlertBox harus mengikuti token warna kariadi.
```

## Commit

```powershell
git add .
git commit -m "docs: add project knowledge base and theme guide"
```

---

# TAHAP 7 — Setup Theme Tailwind

## Tujuan
Menentukan theme Kariadi Medical Dashboard agar semua halaman konsisten.

## Edit tailwind.config.js

Tambahkan:

```js
theme: {
  extend: {
    colors: {
      kariadi: {
        teal: '#00848B',
        tosca: '#00BAAF',
        cyan: '#33CAD6',
        lime: '#CEDD28',
        yellow: '#F8EC12',
        deep: '#02575B',
        bg: '#F6FAFA',
        surface: '#FFFFFF',
        soft: '#EEF8F8',
        border: '#D7EAEA',
        text: '#0F172A',
        muted: '#64748B',
      },
      status: {
        success: '#16A34A',
        warning: '#F59E0B',
        danger: '#DC2626',
        info: '#0284C7',
        neutral: '#64748B',
      },
    },
    boxShadow: {
      card: '0 8px 24px rgba(15, 23, 42, 0.06)',
      soft: '0 4px 14px rgba(15, 23, 42, 0.04)',
    },
    borderRadius: {
      card: '1rem',
    },
  },
},
```

## Test Class

Di salah satu Vue component, coba:

```html
<div class="bg-kariadi-bg text-kariadi-text">
  Test Theme Kariadi
</div>
```

Jalankan:

```powershell
npm run dev
```

## Commit

```powershell
git add .
git commit -m "style: add kariadi dashboard theme tokens"
```

---

# TAHAP 8 — Setup Struktur Modular Backend

## Tujuan
Memisahkan Controller, Service, Repository, dan DTO.

```powershell
New-Item -ItemType Directory -Force app\Http\Controllers\Dashboard
New-Item -ItemType Directory -Force app\Services\Dashboard
New-Item -ItemType Directory -Force app\Services\Ai
New-Item -ItemType Directory -Force app\Repositories\Report
New-Item -ItemType Directory -Force app\Repositories\Dashboard
New-Item -ItemType Directory -Force app\DTO\Dashboard
```

Commit:

```powershell
git add .
git commit -m "chore: add modular backend structure"
```

---

# TAHAP 9 — Setup Struktur Frontend Dashboard

## Tujuan
Menyiapkan layout, halaman, dan komponen dashboard.

```powershell
New-Item -ItemType Directory -Force resources\js\Layouts
New-Item -ItemType Directory -Force resources\js\Pages\Dashboard
New-Item -ItemType Directory -Force resources\js\Components\Dashboard
```

File:

```powershell
New-Item -ItemType File -Force resources\js\Layouts\DashboardLayout.vue

New-Item -ItemType File -Force resources\js\Pages\Dashboard\Executive.vue
New-Item -ItemType File -Force resources\js\Pages\Dashboard\BedOccupancy.vue
New-Item -ItemType File -Force resources\js\Pages\Dashboard\Outpatient.vue
New-Item -ItemType File -Force resources\js\Pages\Dashboard\Igd.vue
New-Item -ItemType File -Force resources\js\Pages\Dashboard\Surgery.vue
New-Item -ItemType File -Force resources\js\Pages\Dashboard\Simrs.vue
New-Item -ItemType File -Force resources\js\Pages\Dashboard\ReportPreview.vue

New-Item -ItemType File -Force resources\js\Components\Dashboard\KpiCard.vue
New-Item -ItemType File -Force resources\js\Components\Dashboard\TrendChart.vue
New-Item -ItemType File -Force resources\js\Components\Dashboard\DataTable.vue
New-Item -ItemType File -Force resources\js\Components\Dashboard\PeriodFilter.vue
New-Item -ItemType File -Force resources\js\Components\Dashboard\InsightPanel.vue
New-Item -ItemType File -Force resources\js\Components\Dashboard\LoadingState.vue
New-Item -ItemType File -Force resources\js\Components\Dashboard\EmptyState.vue
New-Item -ItemType File -Force resources\js\Components\Dashboard\AlertBox.vue
```

Commit:

```powershell
git add .
git commit -m "chore: add dashboard frontend structure"
```

---

# TAHAP 10 — DashboardLayout + SPA Navigation

## Tujuan
Membuat menu banyak tetapi tetap ringan. Sidebar/topbar tetap, content berubah.

## Aturan
- Menu pakai Inertia `Link`
- Jangan pakai `<a href="">`
- Semua page pakai DashboardLayout
- Tidak full reload
- Content area saja yang berubah

## Contoh DashboardLayout.vue

```vue
<script setup>
import { Link } from '@inertiajs/vue3'
</script>

<template>
  <div class="min-h-screen bg-kariadi-bg text-kariadi-text">
    <div class="flex min-h-screen">
      <aside class="w-72 border-r border-kariadi-border bg-white">
        <div class="border-b border-kariadi-border p-5">
          <div class="text-lg font-bold text-kariadi-deep">
            Dashboard Pengawas
          </div>
          <div class="text-xs text-kariadi-muted">
            RS Kariadi
          </div>
        </div>

        <nav class="space-y-1 p-4 text-sm">
          <Link href="/dashboard" class="block rounded-lg px-3 py-2 hover:bg-kariadi-soft hover:text-kariadi-teal">
            Ringkasan Pengawas
          </Link>
          <Link href="/dashboard/bor" class="block rounded-lg px-3 py-2 hover:bg-kariadi-soft hover:text-kariadi-teal">
            Tempat Tidur & BOR
          </Link>
          <Link href="/dashboard/rawat-jalan" class="block rounded-lg px-3 py-2 hover:bg-kariadi-soft hover:text-kariadi-teal">
            Rawat Jalan
          </Link>
          <Link href="/dashboard/igd" class="block rounded-lg px-3 py-2 hover:bg-kariadi-soft hover:text-kariadi-teal">
            IGD
          </Link>
          <Link href="/dashboard/operasi" class="block rounded-lg px-3 py-2 hover:bg-kariadi-soft hover:text-kariadi-teal">
            Operasi
          </Link>
          <Link href="/dashboard/simrs" class="block rounded-lg px-3 py-2 hover:bg-kariadi-soft hover:text-kariadi-teal">
            SIMRS
          </Link>
        </nav>
      </aside>

      <div class="flex flex-1 flex-col">
        <header class="border-b border-kariadi-border bg-white px-6 py-4">
          <div class="flex items-center justify-between">
            <div>
              <div class="text-sm text-kariadi-muted">Periode Laporan</div>
              <div class="font-semibold text-kariadi-text">
                Pilih periode laporan
              </div>
            </div>

            <div class="rounded-full bg-kariadi-soft px-3 py-1 text-sm text-kariadi-deep">
              Draft
            </div>
          </div>
        </header>

        <main class="flex-1 p-6">
          <slot />
        </main>
      </div>
    </div>
  </div>
</template>
```

## Page Dummy

Contoh `BedOccupancy.vue`:

```vue
<script setup>
import DashboardLayout from '@/Layouts/DashboardLayout.vue'

defineOptions({
  layout: DashboardLayout,
})
</script>

<template>
  <div>
    <h1 class="text-2xl font-bold text-kariadi-deep">
      Tempat Tidur & BOR
    </h1>

    <p class="mt-2 text-sm text-kariadi-muted">
      Halaman monitoring tempat tidur dan BOR rumah sakit.
    </p>
  </div>
</template>
```

---

# TAHAP 11 — Route Dashboard

## Buat Controller

```powershell
php artisan make:controller Dashboard/ExecutiveDashboardController
php artisan make:controller Dashboard/BedOccupancyController
php artisan make:controller Dashboard/OutpatientController
php artisan make:controller Dashboard/IgdController
php artisan make:controller Dashboard/SurgeryController
php artisan make:controller Dashboard/SimrsController
```

## Contoh Controller

```php
<?php

namespace App\Http\Controllers\Dashboard;

use App\Http\Controllers\Controller;
use Inertia\Inertia;

class BedOccupancyController extends Controller
{
    public function index()
    {
        return Inertia::render('Dashboard/BedOccupancy');
    }
}
```

## routes/web.php

```php
use App\Http\Controllers\Dashboard\ExecutiveDashboardController;
use App\Http\Controllers\Dashboard\BedOccupancyController;
use App\Http\Controllers\Dashboard\OutpatientController;
use App\Http\Controllers\Dashboard\IgdController;
use App\Http\Controllers\Dashboard\SurgeryController;
use App\Http\Controllers\Dashboard\SimrsController;

Route::middleware(['auth'])->group(function () {
    Route::get('/dashboard', [ExecutiveDashboardController::class, 'index'])->name('dashboard.executive');
    Route::get('/dashboard/bor', [BedOccupancyController::class, 'index'])->name('dashboard.bor');
    Route::get('/dashboard/rawat-jalan', [OutpatientController::class, 'index'])->name('dashboard.outpatient');
    Route::get('/dashboard/igd', [IgdController::class, 'index'])->name('dashboard.igd');
    Route::get('/dashboard/operasi', [SurgeryController::class, 'index'])->name('dashboard.surgery');
    Route::get('/dashboard/simrs', [SimrsController::class, 'index'])->name('dashboard.simrs');
});
```

## Test
- Klik menu sidebar
- Pastikan content berubah
- Browser tidak full reload
- Sidebar/topbar tetap

Commit:

```powershell
git add .
git commit -m "feat(layout): add dashboard persistent layout and inertia navigation"
```

---

# TAHAP 12 — Koneksi Laravel ke Database REPORT

## .env

```env
REPORT_DB_CONNECTION=sqlsrv
REPORT_DB_HOST=127.0.0.1
REPORT_DB_PORT=1433
REPORT_DB_DATABASE=REPORT
REPORT_DB_USERNAME=dashboard_report_reader
REPORT_DB_PASSWORD=GantiPasswordKuat123!
REPORT_DB_TRUST_SERVER_CERTIFICATE=true
```

## config/database.php

Tambahkan connection:

```php
'report' => [
    'driver' => env('REPORT_DB_CONNECTION', 'sqlsrv'),
    'host' => env('REPORT_DB_HOST', '127.0.0.1'),
    'port' => env('REPORT_DB_PORT', '1433'),
    'database' => env('REPORT_DB_DATABASE', 'REPORT'),
    'username' => env('REPORT_DB_USERNAME'),
    'password' => env('REPORT_DB_PASSWORD'),
    'charset' => 'utf8',
    'prefix' => '',
    'trust_server_certificate' => env('REPORT_DB_TRUST_SERVER_CERTIFICATE', true),
],
```

Clear:

```powershell
php artisan config:clear
php artisan cache:clear
```

## Command Test

```powershell
php artisan make:command TestReportConnection
```

Isi command:

```php
public function handle()
{
    try {
        $result = \DB::connection('report')->select('SELECT 1 AS test');
        $this->info('REPORT connection OK');
        return self::SUCCESS;
    } catch (\Throwable $e) {
        $this->error($e->getMessage());
        return self::FAILURE;
    }
}
```

Jalankan:

```powershell
php artisan report:test
```

Commit:

```powershell
git add .
git commit -m "chore: add REPORT database connection"
```

---

# TAHAP 13 — Modul BOR dari Stored Procedure REPORT

## Repository

File:

```text
app/Repositories/Report/BedOccupancyRepository.php
```

```php
<?php

namespace App\Repositories\Report;

use Illuminate\Support\Facades\DB;

class BedOccupancyRepository
{
    public function getSummary(string $start, string $end): array
    {
        return DB::connection('report')->select(
            'EXEC rpt.usp_dashboard_bor_summary @tanggal_awal = ?, @tanggal_akhir = ?',
            [$start, $end]
        );
    }

    public function getByClass(string $start, string $end): array
    {
        return DB::connection('report')->select(
            'EXEC rpt.usp_dashboard_bor_by_class @tanggal_awal = ?, @tanggal_akhir = ?',
            [$start, $end]
        );
    }

    public function getTrend(string $start, string $end): array
    {
        return DB::connection('report')->select(
            'EXEC rpt.usp_dashboard_bor_trend @tanggal_awal = ?, @tanggal_akhir = ?',
            [$start, $end]
        );
    }
}
```

## Service

File:

```text
app/Services/Dashboard/BedOccupancyService.php
```

```php
<?php

namespace App\Services\Dashboard;

use App\Repositories\Report\BedOccupancyRepository;
use Illuminate\Support\Facades\Cache;

class BedOccupancyService
{
    public function __construct(
        private BedOccupancyRepository $repository
    ) {}

    public function getDashboardData(string $start, string $end): array
    {
        $cacheKey = "dashboard:bor:$start:$end";

        return Cache::remember($cacheKey, now()->addMinutes(5), function () use ($start, $end) {
            $summaryRows = $this->repository->getSummary($start, $end);
            $classRows = $this->repository->getByClass($start, $end);
            $trendRows = $this->repository->getTrend($start, $end);

            return [
                'summary' => $this->mapSummary($summaryRows[0] ?? null),
                'byClass' => $this->mapByClass($classRows),
                'trend' => $this->mapTrend($trendRows),
                'flags' => $this->buildFlags($classRows),
            ];
        });
    }

    private function mapSummary($row): array
    {
        if (!$row) {
            return [
                'totalBeds' => 0,
                'occupiedBeds' => 0,
                'availableBeds' => 0,
                'borPercentage' => null,
                'outOfServiceBeds' => 0,
                'trendStatus' => null,
            ];
        }

        return [
            'totalBeds' => (int) $row->total_tt,
            'occupiedBeds' => (int) $row->pasien_dirawat,
            'availableBeds' => (int) $row->sisa_tt,
            'borPercentage' => (float) $row->bor_persen,
            'outOfServiceBeds' => (int) $row->tt_to,
            'trendStatus' => $row->trend_status,
        ];
    }

    private function mapByClass(array $rows): array
    {
        return collect($rows)->map(fn ($row) => [
            'className' => $row->kelas,
            'capacityBeds' => (int) $row->kapasitas_tt,
            'occupiedBeds' => (int) $row->tt_terisi,
            'availableBeds' => (int) $row->sisa_tt,
            'borPercentage' => (float) $row->bor_persen,
            'note' => $row->keterangan,
        ])->values()->all();
    }

    private function mapTrend(array $rows): array
    {
        return collect($rows)->map(fn ($row) => [
            'date' => (string) $row->tanggal,
            'borPercentage' => (float) $row->nilai_bor,
            'trendStatus' => $row->trend_status,
        ])->values()->all();
    }

    private function buildFlags(array $rows): array
    {
        return collect($rows)
            ->filter(fn ($row) => (float) $row->bor_persen >= 85)
            ->map(fn ($row) => [
                'level' => ((float) $row->bor_persen >= 90) ? 'danger' : 'warning',
                'message' => "{$row->kelas} memiliki BOR {$row->bor_persen}%",
            ])
            ->values()
            ->all();
    }
}
```

## Controller

```php
public function index(Request $request, BedOccupancyService $service)
{
    $start = $request->input('start', now()->subDay()->format('Y-m-d 15:30:00'));
    $end = $request->input('end', now()->format('Y-m-d 07:00:00'));

    return Inertia::render('Dashboard/BedOccupancy', [
        'filters' => [
            'start' => $start,
            'end' => $end,
        ],
        'data' => $service->getDashboardData($start, $end),
    ]);
}
```

---

# TAHAP 14 — Prompt Library per Tahap

## Prompt 1 — Setup Project

```text
Kamu bertindak sebagai Senior Laravel Engineer.

Tugas:
Bantu saya setup project Laravel untuk Dashboard Laporan Pengawas RS Kariadi.

Stack:
- Laravel
- Inertia
- Vue
- Tailwind
- SQL Server
- Database REPORT
- Groq untuk insight AI

Aturan:
1. Jangan membuat frontend dan backend terpisah.
2. Gunakan Modular Monolith.
3. Buat struktur folder docs.
4. Buat struktur folder Controller, Service, Repository, DTO.
5. Jangan masuk ke fitur dashboard dulu.
6. Fokus setup project yang rapi.

Output:
1. Langkah install.
2. File yang dibuat.
3. Command yang dijalankan.
4. Test yang harus dilakukan.
```

## Prompt 2 — Knowledge MD Files

```text
Kamu bertindak sebagai Technical Writer dan Software Architect.

Tugas:
Buat dan isi knowledge MD files untuk project Dashboard Laporan Pengawas RS Kariadi.

File yang harus dibuat:
- PROJECT_BRIEF.md
- PLAYBOOK.md
- AI_RULES.md
- FEATURE_CATALOG.md
- STORED_PROCEDURE_REGISTRY.md
- API_CONTRACT.md
- TEST_MATRIX.md
- CHANGELOG.md
- NO_TOUCH_LIST.md
- PROMPT_LIBRARY.md
- THEME_GUIDE.md

Konteks:
Data dashboard berasal dari database REPORT melalui stored procedure schema rpt.
Frontend menggunakan Inertia SPA-style.
Theme mengacu Kariadi Medical Dashboard.

Aturan:
1. Dokumen harus ringkas tapi jelas.
2. Codex harus bisa membaca dokumen ini sebelum coding.
3. Sertakan aturan no-touch.
4. Sertakan standar naming stored procedure.
5. Sertakan aturan theme.
```

## Prompt 3 — Theme

```text
Kamu bertindak sebagai Senior Frontend Engineer.

Tugas:
Implementasikan theme Kariadi Medical Dashboard.

Acuan:
docs/THEME_GUIDE.md

Warna:
- Primary Teal: #00848B
- Tosca: #00BAAF
- Cyan: #33CAD6
- Lime: #CEDD28
- Yellow: #F8EC12
- Background: #F6FAFA
- Card: #FFFFFF

Yang harus dibuat:
1. Update tailwind.config.js
2. Style DashboardLayout
3. Style KpiCard
4. Style DataTable
5. Style InsightPanel
6. Style AlertBox

Aturan:
1. Jangan membuat warna baru sembarangan.
2. Jangan mengubah backend.
3. Jangan membuat full reload navigation.
4. Semua halaman harus clean, formal, dan mudah dibaca.
```

## Prompt 4 — DashboardLayout SPA Navigation

```text
Kamu bertindak sebagai Senior Vue/Inertia Engineer.

Tugas:
Buat DashboardLayout persistent untuk aplikasi Dashboard Laporan Pengawas RS Kariadi.

Yang harus dibuat:
1. DashboardLayout.vue
2. Sidebar menu
3. Topbar
4. PeriodFilter placeholder
5. Content slot
6. Halaman dummy dashboard

Aturan:
1. Menu wajib pakai Link dari @inertiajs/vue3.
2. Jangan pakai anchor biasa untuk menu.
3. Jangan full reload.
4. Sidebar/topbar tetap.
5. Yang berubah hanya content area.
6. Gunakan theme Kariadi dari THEME_GUIDE.md.
```

## Prompt 5 — REPORT Connection

```text
Kamu bertindak sebagai Senior Laravel Engineer.

Tugas:
Tambahkan koneksi database REPORT untuk membaca stored procedure dashboard.

Aturan:
1. Laravel tidak membaca HMIS langsung.
2. Connection diberi nama report.
3. Semua akses REPORT nantinya lewat Repository.
4. Buat command test koneksi.
5. Jangan ubah connection database aplikasi utama.

Yang harus dibuat:
1. Tambahan .env
2. Tambahan config/database.php
3. Artisan command TestReportConnection
4. Cara test
```

## Prompt 6 — Modul BOR

```text
Kamu bertindak sebagai Senior Laravel + Inertia Engineer.

Tugas:
Buat modul Tempat Tidur & BOR dari stored procedure REPORT.

Stored procedure:
- rpt.usp_dashboard_bor_summary
- rpt.usp_dashboard_bor_by_class
- rpt.usp_dashboard_bor_trend

Aturan:
1. Controller tidak boleh panggil SP langsung.
2. Repository memanggil SP.
3. Service mapping output.
4. Vue hanya menampilkan data.
5. Pakai cache 5 menit.
6. Gunakan KpiCard, DataTable, TrendChart, InsightPanel.
7. Jangan ubah modul lain.
8. Jangan ubah stored procedure.

Output:
1. Repository
2. Service
3. Controller
4. Page Vue
5. Props contract
6. Test scenario
```

## Prompt 7 — AI Insight Groq

```text
Kamu bertindak sebagai Senior AI Integration Engineer.

Tugas:
Tambahkan AI insight menggunakan Groq untuk modul BOR.

Aturan:
1. Groq hanya menerima data agregat.
2. Jangan kirim data pasien.
3. Groq tidak boleh menghitung angka utama.
4. Output Groq wajib JSON.
5. Simpan input payload, input hash, model, dan output JSON.
6. Jika Groq error, dashboard tetap tampil.
7. Laporan locked tidak regenerate otomatis.

Yang harus dibuat:
1. GroqClient
2. InsightNarrationService
3. PromptBuilder
4. Migration ai_insights
5. InsightPanel integration
6. Test Groq error fallback
```

## Prompt 8 — Snapshot Laporan

```text
Kamu bertindak sebagai Senior Laravel Engineer.

Tugas:
Buat fitur report period dan snapshot laporan.

Aturan:
1. Laporan punya status draft, validated, locked.
2. Jika locked, data tidak diambil dari live SP lagi.
3. Snapshot menyimpan payload data dan insight JSON.
4. Snapshot dipakai untuk export.
5. Jangan mengubah modul BOR.

Yang harus dibuat:
1. Migration report_periods
2. Migration report_snapshots
3. Service snapshot
4. Tombol validate/lock
5. Test locked report
```

---

# TAHAP 15 — Checklist Setiap Selesai Task

Setiap task selesai, lakukan:

```text
[ ] npm run dev tidak error
[ ] php artisan serve jalan
[ ] php artisan route:list jalan
[ ] halaman terkait bisa dibuka
[ ] console browser bersih
[ ] Laravel log tidak error
[ ] test manual sesuai TEST_MATRIX.md
[ ] CHANGELOG.md diupdate
[ ] FEATURE_CATALOG.md diupdate jika perlu
[ ] commit dibuat
```

Commit format:

```text
feat(bor): add bed occupancy dashboard from REPORT stored procedure
style(theme): apply kariadi medical dashboard theme
docs: update project knowledge files
fix(report): handle stored procedure empty result
```

---

# Urutan Kerja Paling Aman

```text
1. Create Laravel project
2. Install Inertia Vue
3. Setup database aplikasi
4. Setup database REPORT
5. Buat dummy SP BOR
6. Pasang knowledge MD files
7. Pasang theme guide
8. Setup Tailwind token
9. Buat struktur backend modular
10. Buat struktur frontend dashboard
11. Buat DashboardLayout SPA navigation
12. Koneksi Laravel ke REPORT
13. Modul BOR dari SP
14. AI insight BOR
15. Report period dan snapshot
16. Rawat Jalan
17. IGD
18. Operasi
19. SIMRS
20. Export PDF/PPT
