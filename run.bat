@echo off
setlocal

echo ============================================
echo  NanoOS Build and Run Script
echo ============================================
echo.

REM ---- Check and Install NASM ----
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
    REM Refresh PATH so nasm is found this session
    for /f "tokens=*" %%i in ('where nasm 2^>nul') do set NASM_EXE=%%i
    if not defined NASM_EXE (
        echo [!] NASM installed but not yet in PATH. Please restart your terminal and run again.
        pause
        exit /b 1
    )
    echo [OK] NASM installed successfully.
) else (
    echo [OK] NASM found.
)

REM ---- Check and Install QEMU ----
set QEMU_EXE=qemu-system-i386
where qemu-system-i386 >nul 2>&1
if %errorlevel% neq 0 (
    if exist "C:\Program Files\qemu\qemu-system-i386.exe" (
        set QEMU_EXE="C:\Program Files\qemu\qemu-system-i386.exe"
        echo [OK] QEMU found at default install path.
    ) else (
        echo [!] QEMU not found. Attempting to install via winget...
        winget install --id SoftwareFreedomConservancy.QEMU -e --silent --accept-package-agreements --accept-source-agreements
        if %errorlevel% neq 0 (
            echo [ERROR] Failed to install QEMU automatically.
            echo         Please install manually from: https://www.qemu.org/download/#windows
            pause
            exit /b 1
        )
        REM Check default install location
        if exist "C:\Program Files\qemu\qemu-system-i386.exe" (
            set QEMU_EXE="C:\Program Files\qemu\qemu-system-i386.exe"
            echo [OK] QEMU installed successfully.
        ) else (
            echo [!] QEMU installed but not found. Please restart your terminal and run again.
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
nasm -f bin boot\boot.asm -o build\boot.bin
if %errorlevel% neq 0 (
    echo [ERROR] Bootloader assembly failed!
    pause
    exit /b 1
)

echo [2/3] Assembling Kernel...
nasm -f bin kernel\kernel.asm -o build\kernel.bin
if %errorlevel% neq 0 (
    echo [ERROR] Kernel assembly failed!
    pause
    exit /b 1
)

echo [3/3] Creating OS Image...
copy /b build\boot.bin + build\kernel.bin build\os.bin >nul
echo.
echo ============================================
echo  Launching NanoOS in QEMU...
echo ============================================
echo.

%QEMU_EXE% -drive format=raw,file=build\os.bin

pause
