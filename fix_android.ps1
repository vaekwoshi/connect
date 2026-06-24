$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$sdkDir = "C:\Users\vedja\AppData\Local\Android\Sdk"
$cmdlineDir = "$sdkDir\cmdline-tools\latest"
$zipPath = "$env:TEMP\cmdline-tools.zip"

Write-Host "1. Android Command-line Tools 다운로드 중..."
curl.exe -L -o $zipPath "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"

Write-Host "2. 압축 해제 중..."
$extractTemp = "$env:TEMP\cmdline-extract"
if (Test-Path $extractTemp) { Remove-Item -Path $extractTemp -Recurse -Force }
New-Item -ItemType Directory -Path $extractTemp | Out-Null
tar -xf $zipPath -C $extractTemp

# 폴더 구조 맞추기
if (Test-Path $cmdlineDir) { Remove-Item -Path $cmdlineDir -Recurse -Force }
New-Item -ItemType Directory -Path "$sdkDir\cmdline-tools" -Force | Out-Null
Move-Item -Path "$extractTemp\cmdline-tools" -Destination $cmdlineDir

# 3. 라이선스 동의
Write-Host "3. 안드로이드 라이선스 자동 동의..."
$sdkmanager = "$cmdlineDir\bin\sdkmanager.bat"
cmd.exe /c "echo y | $sdkmanager --licenses"

# 4. 플러터 환경 세팅
Write-Host "4. 플러터 라이선스 자동 동의..."
$flutterBin = "C:\src\flutter\bin\flutter.bat"
cmd.exe /c "echo y | $flutterBin doctor --android-licenses"

Write-Host "======================================"
Write-Host "완료되었습니다! 안드로이드 스튜디오를 재시작해 주세요!"
Write-Host "======================================"
