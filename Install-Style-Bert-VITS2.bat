chcp 65001 > NUL
@echo off

@REM エラーコードを遅延評価するために設定
setlocal enabledelayedexpansion

@REM PowerShellのコマンド
set PS_CMD=PowerShell -Version 5.1 -ExecutionPolicy Bypass

@REM PortableGitのURLと保存先
set DL_URL=https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/PortableGit-2.44.0-64-bit.7z.exe
set DL_DST=%~dp0lib\PortableGit-2.44.0-64-bit.7z.exe

@REM Style-Bert-VITS2のリポジトリURL
set REPO_URL=https://github.com/litagin02/Style-Bert-VITS2

@REM カレントディレクトリをbatファイルのディレクトリに変更
pushd %~dp0

@REM lib フォルダがなければ作成
if not exist lib\ ( mkdir lib )

echo --------------------------------------------------
echo PS_CMD: %PS_CMD%
echo DL_URL: %DL_URL%
echo DL_DST: %DL_DST%
echo REPO_URL: %REPO_URL%
echo --------------------------------------------------
echo.
echo --------------------------------------------------
echo Checking Git Installation...
echo --------------------------------------------------
echo Executing: git --version
git --version
if !errorlevel! neq 0 (
    echo --------------------------------------------------
    echo Git is not installed, so download and use PortableGit.
    echo Downloading PortableGit...
    echo --------------------------------------------------
    curl -L %DL_URL% -o "%DL_DST%"
    if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

    "%DL_DST%" -y
    if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

    del "%DL_DST%"
    if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

    set "PATH=%~dp0lib\PortableGit\bin;%PATH%"
)

echo --------------------------------------------------
echo Cloning repository...
echo --------------------------------------------------
if exist Style-Bert-VITS2\ (
    echo Style-Bert-VITS2 folder already exists, skipping clone.
) else (
    echo Executing: git clone %REPO_URL%
    git clone %REPO_URL%
    if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )
)

echo --------------------------------------------------
echo Patching requirements.txt for known compatibility issues...
echo --------------------------------------------------
powershell -Command "$c = (Get-Content 'Style-Bert-VITS2\requirements.txt' -Encoding utf8); $c = $c -replace 'faster-whisper==0\.10\.1', 'faster-whisper>=1.0.0'; $c = $c -replace '^transformers$', 'transformers>=4.34.0,<5.0.0'; $c = $c -replace '^transformers[^><=!].*$', 'transformers>=4.34.0,<5.0.0'; $c = $c -replace '^torch<.*$', 'torch>=2.4,<3.0'; $c = $c -replace '^torchaudio<.*$', 'torchaudio>=2.4,<3.0'; $c = $c -replace '^librosa==0\.9\.2$', 'librosa>=0.10.0'; $c = $c -replace '^pyopenjtalk$', '# pyopenjtalk installed separately as prebuilt'; [System.IO.File]::WriteAllLines('Style-Bert-VITS2\requirements.txt', $c)"
echo Patching complete.

@REM Pythonのセットアップ
echo --------------------------------------------------
echo Setting up Python environment...
echo --------------------------------------------------
call Setup-Python.bat ".\lib\python" ".\Style-Bert-VITS2\venv"
if !errorlevel! neq 0 ( popd & exit /b !errorlevel! )

pushd Style-Bert-VITS2

echo --------------------------------------------------
echo Activating the virtual environment...
echo --------------------------------------------------
call ".\venv\Scripts\activate.bat"
if !errorlevel! neq 0 ( popd & exit /b !errorlevel! )

echo --------------------------------------------------
echo Installing package manager uv...
echo --------------------------------------------------
pip install uv
if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

echo --------------------------------------------------
echo Installing PyTorch (>=2.4 required for SBV2)...
echo --------------------------------------------------
uv pip install "torch>=2.4,<3.0" "torchaudio>=2.4,<3.0" --index-url https://download.pytorch.org/whl/cu118
if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

echo --------------------------------------------------
echo Installing setuptools (pkg_resources compatible version)...
echo --------------------------------------------------
pip install "setuptools<70" --force-reinstall
if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

echo --------------------------------------------------
echo Installing other dependencies...
echo --------------------------------------------------
uv pip install -r requirements.txt
if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

echo --------------------------------------------------
echo Installing pyopenjtalk-plus (prebuilt wheel, no C compilation required)...
echo --------------------------------------------------
pip install pyopenjtalk-plus
if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

echo --------------------------------------------------
echo Patching transcribe.py to use CPU for transcription...
echo (faster-whisper GPU requires CUDA 12.x DLLs not bundled with PyTorch cu118)
echo --------------------------------------------------
powershell -Command "$content = (Get-Content 'transcribe.py' -Encoding utf8) -replace 'parser.add_argument\(\"--device\", type=str, default=\"cuda\"\)', 'parser.add_argument(\"--device\", type=str, default=\"cpu\")'; [System.IO.File]::WriteAllLines('transcribe.py', $content)"
if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

echo --------------------------------------------------
echo Patching cloud_io.py for weights_only compatibility (PyTorch 2.6+)...
echo --------------------------------------------------
powershell -Command "$content = (Get-Content 'venv\Lib\site-packages\lightning_fabric\utilities\cloud_io.py' -Encoding utf8) -replace 'weights_only=weights_only', 'weights_only=False'; [System.IO.File]::WriteAllLines('venv\Lib\site-packages\lightning_fabric\utilities\cloud_io.py', $content)"
if !errorlevel! neq 0 ( pause & popd & exit /b !errorlevel! )

echo ----------------------------------------
echo Environment setup is complete. Start downloading the model.
echo ----------------------------------------
python initialize.py

echo ----------------------------------------
echo Model download is complete. Start Style-Bert-VITS2 App.
echo ----------------------------------------
python app.py --inbrowser
pause

popd
popd
endlocal
