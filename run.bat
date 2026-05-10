@echo off
setlocal

REM Find NASM executable
where nasm >nul 2>&1
if %errorlevel% neq 0 (
    echo NASM is not installed or not in PATH.
    echo Please install NASM or ensure it is in your PATH.
    pause
    exit /b 1
)

REM Find QEMU executable
set QEMU_EXE=qemu-system-i386
where qemu-system-i386 >nul 2>&1
if %errorlevel% neq 0 (
    if exist "C:\Program Files\qemu\qemu-system-i386.exe" (
        set QEMU_EXE="C:\Program Files\qemu\qemu-system-i386.exe"
    ) else (
        echo QEMU is not installed or not in PATH, and not found in C:\Program Files\qemu.
        echo Please install QEMU from https://www.qemu.org/download/#windows
        pause
        exit /b 1
    )
)

if not exist build mkdir build

echo Assembling Bootloader...
nasm -f bin boot\boot.asm -o build\boot.bin
if %errorlevel% neq 0 (
    echo Bootloader build failed!
    pause
    exit /b 1
)

echo Assembling Kernel...
nasm -f bin kernel\kernel.asm -o build\kernel.bin
if %errorlevel% neq 0 (
    echo Kernel build failed!
    pause
    exit /b 1
)

echo Creating OS Image...
REM Windows copy /b concatenates binary files
copy /b build\boot.bin + build\kernel.bin build\os.bin >nul

echo Running NanoOS in QEMU...
%QEMU_EXE% -drive format=raw,file=build\os.bin

pause
