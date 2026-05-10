# NanoOS

```text
 ███╗   ██╗  █████╗  ███╗   ██╗  ██████╗      ██████╗ ███████╗
 ████╗  ██║ ██╔══██╗ ████╗  ██║ ██╔═══██╗    ██╔═══██╗██╔════╝
 ██╔██╗ ██║ ███████║ ██╔██╗ ██║ ██║   ██║    ██║   ██║███████╗
 ██║╚██╗██║ ██╔══██║ ██║╚██╗██║ ██║   ██║    ██║   ██║╚════██║
 ██║ ╚████║ ██║  ██║ ██║ ╚████║ ╚██████╔╝    ╚██████╔╝███████║
 ╚═╝  ╚═══╝ ╚═╝  ╚═╝ ╚═╝  ╚═══╝  ╚═════╝      ╚═════╝ ╚══════╝
```

A minimal, educational bootable terminal operating system written entirely in x86 Assembly (16-bit real mode). It bypasses Windows and Linux entirely, booting straight from the BIOS using a custom bootloader.

## Features

- **Custom Bootloader & Logo:** Reads the kernel from the simulated disk using BIOS `INT 13h`, displays an ASCII art boot logo, and jumps into the kernel.
- **Dynamic File Authentication:** Intercepts the boot sequence to require a valid username and masked password. It uses a custom text-parsing engine to authenticate dynamically against a raw text file (`users.txt`) compiled into the OS memory!
- **Terminal Shell:** A fully interactive command-line interface that buffers keyboard input, handles backspace, and executes commands.
- **Built-in Programs & Commands:**
  - `calc`: A functional calculator that uses custom `atoi` and `itoa` routines to handle math natively in the CPU without high-level standard libraries.
  - `help` / `info`: Lists all available commands.
  - `clear`: Clears the screen and redraws the prompt.

## Project Structure

- `boot/`: Contains the stage-1 bootloader (`boot.asm`) and the ASCII art logo (`logo.asm`).
- `kernel/kernel.asm`: The core OS kernel, containing the standard library functions (`atoi`, `itoa`, `strcmp`), the terminal loop, and the command dispatcher.
- `kernel/system/`: Core system modules like the login loop (`login.asm`) and the user database (`users.txt`).
- `kernel/programs/`: User-space applications like the calculator (`calc.asm`).
- `build/`: Temporary output directory for the compiled binaries.
- `run.bat`: A unified build and execution script for Windows.

## Quick Start (Windows)

**Step 1: Install Required Tools**
NanoOS requires two tools to be installed on your system:
- **NASM** (for assembling the code): [Download](https://www.nasm.us/)
- **QEMU** (for emulating the PC): [Download](https://www.qemu.org/download/#windows)

*(Tip: You can quickly install them via command line by typing `winget install NASM` and `winget install QEMU`)*

**Step 2: Build and Run**
Simply run the script from your terminal:
```cmd
.\run.bat
```
This script will automatically assemble both the bootloader and the kernel, concatenate them into a bootable `os.bin` disk image, and launch it in QEMU.

## Architecture & Boot Flow
1. **BIOS**: Computes POST, finds our bootable drive, loads the first 512 bytes (`boot.asm`) to `0x7C00`, and executes it.
2. **Bootloader**: Sets up segment registers and the stack. Prints the ASCII logo, pauses for 1.5 seconds, reads the kernel from the disk into memory at `0x8000`, and jumps to it.
3. **Kernel Boot**: The kernel calls the `login` module, which drops into an authentication loop until a valid user from `users.txt` is verified.
4. **Terminal Shell**: Once authenticated, the kernel clears the screen, initializes the terminal loop, listens for `INT 16h` keyboard strokes, and handles command matching/execution.

## Roadmap
- [x] Basic Bootloader
- [x] Kernel Loading
- [x] Keyboard Input Loop
- [x] Terminal Shell and String Matching
- [x] User Authentication & Dynamic Parsing
- [x] Built-in Programs (Calculator)
- [ ] Number Guessing Game
