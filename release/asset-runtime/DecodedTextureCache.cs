// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright Invi. Generated files contain local user resources, never release assets.
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class PalCraftDecodedTextureCache {
 static uint Crc(byte[] bytes) {
  uint crc=0xffffffff;
  foreach(byte b in bytes) { crc^=b;for(int i=0;i<8;i++)crc=(crc&1)!=0?(crc>>1)^0xedb88320:crc>>1; }
  return ~crc;
 }
 public static void Build(string assetsRoot) {
  string root=Path.GetFullPath(assetsRoot);
  string mod=Path.GetDirectoryName(Path.GetDirectoryName(root));
  string cache=Path.Combine(mod,"skins","_cache");Directory.CreateDirectory(cache);
  int written=0,hits=0;
  foreach(string file in Directory.GetFiles(root,"*.png",SearchOption.AllDirectories)) {
   byte[] bytes=File.ReadAllBytes(file);if(bytes.Length>33554432)throw new Exception("PNG file exceeds cache budget");
   string destination=Path.Combine(cache,"tex-"+Crc(bytes).ToString("x8")+"-"+bytes.Length+".tga");
   using(Bitmap bitmap=new Bitmap(file)) {
    int w=bitmap.Width,h=bitmap.Height;
    if(w<1||h<1||w>8192||h>8192||(long)w*h>16777216)throw new Exception("PNG dimensions exceed cache budget");
    if(File.Exists(destination)) {
     using(var input=new BinaryReader(File.OpenRead(destination))) {
      if(input.BaseStream.Length==18L+w*h*4) {
       byte[] header=input.ReadBytes(18);
       if(header[2]==2&&header[16]==32&&header[17]==40&&BitConverter.ToUInt16(header,12)==w&&BitConverter.ToUInt16(header,14)==h){hits++;continue;}
      }
     }
    }
    var pixels=bitmap.LockBits(new Rectangle(0,0,w,h),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
    try {
     using(var output=new BinaryWriter(File.Create(destination))) {
      byte[] header=new byte[18];header[2]=2;header[12]=(byte)w;header[13]=(byte)(w>>8);header[14]=(byte)h;header[15]=(byte)(h>>8);header[16]=32;header[17]=40;output.Write(header);
      byte[] row=new byte[w*4];for(int y=0;y<h;y++){Marshal.Copy(IntPtr.Add(pixels.Scan0,y*pixels.Stride),row,0,row.Length);output.Write(row);}
     }
    } finally {bitmap.UnlockBits(pixels);}
    written++;
   }
  }
  Console.WriteLine("PalCraft decoded BGRA cache: "+written+" written, "+hits+" reused");
 }
}
