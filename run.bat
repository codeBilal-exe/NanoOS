@echo off
setlocal

echo ============================================
echo  NanoOS Build and Run Script
echo ============================================
echo.

REM ---- Check and Install NASM ----
set "NASM_EXE=nasm"
where nasm >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] NASM not found. Attempting to install via winget...
    winget install --id NASM.NASM -e --silent --accept-package-agreements --accept-source-agreements
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to install NASM automatically.
        echo         Please install manually from: https://www.nasm.us/
        pause
        exit /b 1
    )
    for /f "delims=" %%i in ('where nasm 2^>nul') do set "NASM_EXE=%%i"
    if not defined NASM_EXE (
        if exist "C:\Program Files\nasm\nasm.exe" set "NASM_EXE=C:\Program Files\nasm\nasm.exe"
    )
    if not defined NASM_EXE (
        echo [ERROR] NASM installed but not found in PATH.
        echo         Add the NASM folder to your PATH manually.
        echo         Example: C:\Program Files\nasm
        pause
        exit /b 1
    )
    echo [OK] NASM installed successfully.
    if "%NASM_EXE%" == "C:\Program Files\nasm\nasm.exe" (
        echo [INFO] NASM executable found in default folder but not in PATH.
        echo [INFO] Add "C:\Program Files\nasm" to PATH or restart your terminal after installation.
    )
) else (
    echo [OK] NASM found.
)

REM ---- Check and Install QEMU ----
set "QEMU_EXE=qemu-system-i386"
where qemu-system-i386 >nul 2>&1
if %errorlevel% neq 0 (
    if exist "C:\Program Files\qemu\qemu-system-i386.exe" (
        set "QEMU_EXE=C:\Program Files\qemu\qemu-system-i386.exe"
        echo [OK] QEMU found at default install path.
        echo [INFO] If QEMU is not in PATH, add "C:\Program Files\qemu" to your PATH.
    ) else (
        echo [!] QEMU not found. Attempting to install via winget...
        winget install --id SoftwareFreedomConservancy.QEMU -e --silent --accept-package-agreements --accept-source-agreements
        if %errorlevel% neq 0 (
            echo [ERROR] Failed to install QEMU automatically.
            echo         Please install manually from: https://www.qemu.org/download/#windows
            pause
            exit /b 1
        )
        if exist "C:\Program Files\qemu\qemu-system-i386.exe" (
            set "QEMU_EXE=C:\Program Files\qemu\qemu-system-i386.exe"
            echo [OK] QEMU installed successfully.
            echo [INFO] Add "C:\Program Files\qemu" to PATH if you want QEMU available from any terminal.
        ) else (
            echo [ERROR] QEMU installed but not found.
            echo         Please restart your terminal or add QEMU to PATH manually.
            pause
            exit /b 1
        )
    )
) else (
    echo [OK] QEMU found.
)

REM ---- Create build directory ----
if not exist build mkdir build

echo.
echo [1/3] Assembling Bootloader...
"%NASM_EXE%" -f bin boot\boot.asm -o build\boot.bin
if %errorlevel% neq 0 (
    echo [ERROR] Bootloader assembly failed!
    pause
    exit /b 1
)

echo [2/3] Assembling Kernel...
"%NASM_EXE%" -f bin kernel\kernel.asm -o build\kernel.bin
if %errorlevel% neq 0 (
    echo [ERROR] Kernel assembly failed!
    pause
    exit /b 1
)

echo [3/3] Creating OS Image...
copy /b build\boot.bin + build\kernel.bin build\os.bin >nul
if %errorlevel% neq 0 (
    echo [ERROR] Failed to create OS image.
    pause
    exit /b 1
)
echo.
echo ============================================
echo  Launching NanoOS in QEMU...
echo ============================================
echo.

"%QEMU_EXE%" -drive format=raw,file=build\os.bin 2>nul

pause
