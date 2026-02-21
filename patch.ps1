# patch.ps1 - Style-Bert-VITS2 compatibility patches
# Called from Install-Style-Bert-VITS2.bat
param(
    [string]$BaseDir = $PSScriptRoot
)

# %~dp0は末尾に \" が付くため、" を先に、次に \ をトリムする
$BaseDir = $BaseDir.TrimEnd('"').TrimEnd('\')
$sbv2Dir = Join-Path $BaseDir "Style-Bert-VITS2"

# --- 1. requirements.txt ---
Write-Host "Patching requirements.txt..."
$reqFile = Join-Path $sbv2Dir "requirements.txt"
$c = Get-Content $reqFile -Encoding utf8
$c = $c -replace 'faster-whisper==0\.10\.1',      'faster-whisper>=1.0.0'
$c = $c -replace '^transformers$',                 'transformers>=4.34.0,<5.0.0'
$c = $c -replace '^transformers[^><=!].*$',        'transformers>=4.34.0,<5.0.0'
$c = $c -replace '^torch<.*$',                     'torch>=2.4,<3.0'
$c = $c -replace '^torchaudio<.*$',                'torchaudio>=2.4,<3.0'
$c = $c -replace '^librosa==0\.9\.2$',             'librosa>=0.10.0'
$c = $c -replace '^pyopenjtalk$',                  '# pyopenjtalk installed separately as prebuilt'
[System.IO.File]::WriteAllLines($reqFile, $c)
Write-Host "requirements.txt patched."

# --- 2. transcribe.py (use CPU for transcription) ---
Write-Host "Patching transcribe.py..."
$transcribeFile = Join-Path $sbv2Dir "transcribe.py"
$c = Get-Content $transcribeFile -Encoding utf8
$c = $c -replace 'parser\.add_argument\("--device", type=str, default="cuda"\)', 'parser.add_argument("--device", type=str, default="cpu")'
[System.IO.File]::WriteAllLines($transcribeFile, $c)
Write-Host "transcribe.py patched."

# --- 3. cloud_io.py (venv構築後のみ実行、weights_only=False for PyTorch 2.6+) ---
$cloudIoFile = Join-Path $sbv2Dir "venv\Lib\site-packages\lightning_fabric\utilities\cloud_io.py"
if (Test-Path $cloudIoFile) {
    Write-Host "Patching cloud_io.py..."
    $c = Get-Content $cloudIoFile -Encoding utf8
    $c = $c -replace 'weights_only=weights_only', 'weights_only=False'
    [System.IO.File]::WriteAllLines($cloudIoFile, $c)
    Write-Host "cloud_io.py patched."
} else {
    Write-Host "cloud_io.py not found, skipping (will be patched after venv is built)."
}

Write-Host "All patches applied."
