# =============================================================
#  로또 추천 앱 릴리스 자동화 스크립트
# =============================================================
#  사용법:
#    .\release.ps1 -Version "1.0.1" -Notes "버그 수정 및 개선"
#    .\release.ps1 -Version "1.1.0"   (노트 생략 시 커밋 로그 자동 사용)
#
#  사전 요구:
#    - flutter (PATH 또는 D:\flutter\bin)
#    - gh CLI (https://cli.github.com)  : `gh auth login` 한 번 실행 필요
#    - git 작업 디렉토리가 깨끗한 상태(커밋 완료) 권장
# =============================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$false)]
    [string]$Notes = "",

    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild = $false,

    [Parameter(Mandatory=$false)]
    [switch]$Draft = $false
)

$ErrorActionPreference = "Stop"

# --- Flutter 경로 자동 감지 ---
$flutterCmd = "flutter"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Test-Path "D:\flutter\bin\flutter.bat") {
        $flutterCmd = "D:\flutter\bin\flutter.bat"
    } else {
        Write-Error "flutter 실행 파일을 찾을 수 없습니다."
        exit 1
    }
}

# --- gh CLI 확인 ---
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "gh CLI가 설치되어 있지 않습니다. https://cli.github.com 에서 설치하세요."
    exit 1
}

# --- 버전 형식 검증 ---
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Error "버전 형식이 올바르지 않습니다. 예: 1.0.1"
    exit 1
}

$tag = "v$Version"
Write-Host ""
Write-Host "=== 로또 추천 앱 릴리스 ===" -ForegroundColor Cyan
Write-Host "버전: $tag" -ForegroundColor Yellow

# --- 기존 태그 확인 ---
$existingTag = git tag -l $tag
if ($existingTag) {
    Write-Error "태그 $tag 가 이미 존재합니다."
    exit 1
}

# --- pubspec.yaml 버전 업데이트 ---
Write-Host ""
Write-Host "[1/6] pubspec.yaml 버전 업데이트..." -ForegroundColor Cyan
$pubspec = Get-Content "pubspec.yaml" -Raw -Encoding UTF8
$buildNumber = ([int](Get-Date -UFormat %s)) -band 0xFFFFFFF  # 빌드번호: epoch 하위 비트
$newVersionLine = "version: $Version+$buildNumber"
$pubspec = $pubspec -replace 'version:\s*\S+', $newVersionLine
Set-Content "pubspec.yaml" $pubspec -Encoding UTF8 -NoNewline
Write-Host "  → $newVersionLine" -ForegroundColor Green

# --- APK 빌드 ---
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if ($SkipBuild) {
    Write-Host ""
    Write-Host "[2/6] APK 빌드 스킵 (--SkipBuild)" -ForegroundColor Yellow
    if (-not (Test-Path $apkPath)) {
        Write-Error "기존 APK가 없습니다: $apkPath"
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "[2/6] flutter pub get..." -ForegroundColor Cyan
    & $flutterCmd pub get
    if ($LASTEXITCODE -ne 0) { Write-Error "flutter pub get 실패"; exit 1 }

    Write-Host ""
    Write-Host "[3/6] APK 빌드 (flutter build apk --release)..." -ForegroundColor Cyan
    & $flutterCmd build apk --release
    if ($LASTEXITCODE -ne 0) { Write-Error "APK 빌드 실패"; exit 1 }
}

if (-not (Test-Path $apkPath)) {
    Write-Error "APK가 생성되지 않았습니다: $apkPath"
    exit 1
}

$apkSizeMB = [Math]::Round((Get-Item $apkPath).Length / 1MB, 2)
Write-Host "  → APK: $apkPath ($apkSizeMB MB)" -ForegroundColor Green

# --- 릴리스용 APK 이름 변경 ---
$releaseDir = "build\release"
if (-not (Test-Path $releaseDir)) { New-Item -ItemType Directory -Path $releaseDir | Out-Null }
$renamedApk = Join-Path $releaseDir "lsy-m-lotto-$Version.apk"
Copy-Item $apkPath $renamedApk -Force
Write-Host "  → 릴리스 APK: $renamedApk" -ForegroundColor Green

# --- 커밋 & 태그 ---
Write-Host ""
Write-Host "[4/6] git 커밋 및 태그 생성..." -ForegroundColor Cyan

git add pubspec.yaml
$status = git status --porcelain
if ($status) {
    git commit -m "chore: bump version to $Version"
    if ($LASTEXITCODE -ne 0) { Write-Error "git commit 실패"; exit 1 }
}

git tag -a $tag -m "Release $tag"
if ($LASTEXITCODE -ne 0) { Write-Error "git tag 실패"; exit 1 }

Write-Host "  → 커밋 + 태그 $tag 생성 완료" -ForegroundColor Green

# --- push ---
Write-Host ""
Write-Host "[5/6] origin으로 push..." -ForegroundColor Cyan
git push origin HEAD
if ($LASTEXITCODE -ne 0) { Write-Error "git push 실패"; exit 1 }
git push origin $tag
if ($LASTEXITCODE -ne 0) { Write-Error "git push tag 실패"; exit 1 }
Write-Host "  → push 완료" -ForegroundColor Green

# --- 릴리스 노트 ---
if (-not $Notes) {
    $prevTag = git describe --tags --abbrev=0 $tag^ 2>$null
    if ($prevTag) {
        $Notes = git log "$prevTag..$tag" --pretty=format:"- %s" --no-merges | Out-String
    } else {
        $Notes = "초기 릴리스"
    }
}

# --- GitHub Release 생성 ---
Write-Host ""
Write-Host "[6/6] GitHub Release 생성 (gh release create)..." -ForegroundColor Cyan

$ghArgs = @(
    "release", "create", $tag,
    $renamedApk,
    "--title", "$tag",
    "--notes", $Notes
)
if ($Draft) { $ghArgs += "--draft" }

& gh @ghArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "GitHub Release 생성 실패"
    Write-Host "수동 복구: 태그는 push되었으니 'gh release create $tag $renamedApk' 으로 재시도" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "✅ 릴리스 $tag 완료!" -ForegroundColor Green
Write-Host "   https://github.com/leeseyoung77/lsy-m-lotto/releases/tag/$tag" -ForegroundColor Cyan
Write-Host ""
