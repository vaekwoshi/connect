# 플러터(Flutter) 자동 설치 및 환경 설정 스크립트
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$flutterInstallDir = "C:\src"
$flutterPath = "$flutterInstallDir\flutter"
$flutterBin = "$flutterPath\bin"

# 1. 설치 폴더 준비
Write-Host "1. 플러터 설치 폴더($flutterInstallDir)를 준비합니다..."
if (-not (Test-Path $flutterInstallDir)) {
    New-Item -ItemType Directory -Force -Path $flutterInstallDir | Out-Null
}

# 2. 다운로드 (속도 개선을 위해 curl 사용)
$zipPath = "$env:TEMP\flutter_windows.zip"
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.44.1-stable.zip"

Write-Host "2. 플러터 SDK 최신 버전을 다운로드 중입니다 (curl 방식 사용)..."
curl.exe -L -o $zipPath $flutterUrl

# 3. 압축 해제
Write-Host "3. 다운로드한 파일을 압축 해제합니다..."
if (Get-Command tar -ErrorAction SilentlyContinue) {
    tar -xf $zipPath -C $flutterInstallDir
} else {
    Expand-Archive -Path $zipPath -DestinationPath $flutterInstallDir -Force
}

# 4. PATH 환경 변수 추가
Write-Host "4. 환경 변수(PATH)에 플러터를 등록합니다..."
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$flutterBin*") {
    $newPath = $userPath + ";$flutterBin"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = $env:Path + ";$flutterBin"
    Write-Host "   -> 환경 변수 등록 완료."
} else {
    Write-Host "   -> 이미 환경 변수에 등록되어 있습니다."
}

# 5. 빌드 환경 자동 생성
Write-Host "5. 프로젝트 안드로이드 폴더를 자동 생성합니다..."
& "$flutterBin\flutter.bat" create .

Write-Host "=========================================================================="
Write-Host "🎉 모든 설치 및 세팅이 완료되었습니다!"
Write-Host "=========================================================================="

Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
