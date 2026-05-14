# NanoOS

```text
 ███╗   ██╗  █████╗  ███╗   ██╗  ██████╗      ██████╗ ███████╗
 ████╗  ██║ ██╔══██╗ ████╗  ██║ ██╔═══██╗    ██╔═══██╗██╔════╝
 ██╔██╗ ██║ ███████║ ██╔██╗ ██║ ██║   ██║    ██║   ██║███████╗
 ██║╚██╗██║ ██╔══██║ ██║╚██╗██║ ██║   ██║    ██║   ██║╚════██║
 ██║ ╚████║ ██║  ██║ ██║ ╚████║ ╚██████╔╝    ╚██████╔╝███████║
 ╚═╝  ╚═══╝ ╚═╝  ╚═╝ ╚═╝  ╚═══╝  ╚═════╝      ╚═════╝ ╚══════╝
```

NanoOS is a high-performance, minimal, and educational operating system written from scratch in **x86 Assembly**. It operates in 16-bit real mode, booting directly from hardware (or an emulator) to provide a raw, low-level computing experience without the overhead of modern kernels.

---

## 🚀 Core Features

- **Custom Stage-1 Bootloader:** A 512-byte BIOS-compliant bootloader that handles hardware initialization, disk I/O via `INT 13h`, and kernel handoff.
- **Dynamic Security Subsystem:** A built-in authentication engine that verifies users against an embedded database (`users.txt`) with masked password entry.
- **Categorized Command Shell:** A professional-grade terminal supporting industry-standard commands like `ls`, `clear`, and `run`.
- **Power Management:** Native support for APM (Advanced Power Management) for software-controlled system shutdown and warm reboots.
- **Flicker-Free UI:** Optimized BIOS video routines for smooth screen transitions and high-performance text rendering.

## 🛠️ Integrated Applications

| Program | Description |
| :--- | :--- |
| **Calculator** | Native 16-bit math engine using custom `atoi` and `itoa` routines. |
| **Animate** | High-performance ASCII animation engine (Starfield, Matrix, and DVD-Bounce). |
| **Memory** | Real-time system inspector for CPU registers, stack contents, and memory maps. |

---

## 📁 Project Organization

```bash
NanoOS/
├── boot/               # Bootloader & BIOS Header Art
├── kernel/             # Core Kernel Source
│   ├── system/         # Login, Admin, & User Database
│   └── kernel.asm      # Main Kernel Entry & System Calls
├── programs/           # User-space Application Source
├── build/              # Compiled Binary Artifacts
├── run.bat             # Unified Build & Emulation Script
└── README.md           # Documentation
```

---

## 🚥 Getting Started

### Prerequisites

You will need the following tools installed and available in your system `PATH`:
- **NASM:** The Netwide Assembler (for compiling `.asm` source).
- **QEMU:** A generic and open-source machine emulator.

> [!TIP]
> On Windows, you can install both via winget:
> `winget install NASM.NASM SoftwareFreedomConservancy.QEMU`

### Building and Running

Simply execute the unified build script to compile the source and launch the OS:

```powershell
.\run.bat
```

The script will:
1. Assemble the bootloader (`boot.bin`).
2. Assemble the monolithic kernel with embedded modules (`kernel.bin`).
3. Concatenate them into a bootable 64KB raw disk image (`os.bin`).
4. Launch the image in QEMU.

---

## ⌨️ Command Reference

| Command | Category | Description |
| :--- | :--- | :--- |
| `ls` | System | List all available programs. |
| `run <name>` | System | Execute a program by its name. |
| `help` | System | Display the categorized help menu. |
| `clear` | System | Reset the terminal display buffer. |
| `logout` | System | Terminate the current user session. |
| `restart` | System | Perform a warm system reboot. |
| `exit` | System | Shut down the hardware and exit. |
| `users` | Admin | List all registered system users. |
| `adduser` | Admin | Register a new user to the database. |
| `deluser` | Admin | Remove a user from the database. |

---

## 🏗️ Technical Architecture

1. **Bootstrap Phase:** BIOS loads `boot.asm` to `0x7C00`. The bootloader initializes the stack and segment registers.
2. **Kernel Load:** The bootloader reads 128 sectors (64KB) from the disk starting at Sector 2, loading the monolithic kernel to `0x8000`.
3. **Authentication Layer:** The kernel immediately transfers control to the `login` module for identity verification.
4. **Shell Execution:** Upon successful login, the system enters the main terminal loop, listening for `INT 16h` keyboard interrupts and dispatching commands via the system call table.

---

## 🗺️ Roadmap

- [x] Monolithic Kernel Architecture
- [x] APM-based Power Management
- [x] Multi-Program Application Layer
- [x] Admin/User Privilege System
- [x] Number Guessing Game
- [ ] FAT-like File System Support (Planned)
