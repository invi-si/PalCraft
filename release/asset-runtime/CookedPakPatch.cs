// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright Invi. Patches only hash-bound, uncompressed PalCraft template paks.
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Web.Script.Serialization;

public static class PalCraftCookedPakPatch {
 static Dictionary<string,object> D(object x){return (Dictionary<string,object>)x;}
 static object[] A(object x){return (object[])x;}
 static int N(object x){return Convert.ToInt32(x);}
 static long L(object x){return Convert.ToInt64(x);}
 static string Hex(byte[] b){return BitConverter.ToString(b).Replace("-","").ToLowerInvariant();}
 static string HashFile(string p){using(var s=File.OpenRead(p))using(var h=SHA256.Create())return Hex(h.ComputeHash(s));}
 static string Under(string root,string rel){
  if(String.IsNullOrEmpty(rel)||rel.Contains("..")||rel.Contains(":")||rel.Contains("\\")||rel.StartsWith("/"))throw new Exception("Unsafe patch path");
  string p=Path.GetFullPath(Path.Combine(root,rel));if(!p.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new Exception("Patch path escaped its root");return p;
 }
 static byte[] Pixels(string file,int w,int h,bool normal,bool opaque){
  using(var bitmap=new Bitmap(file)){
   if(bitmap.Width!=w||bitmap.Height!=h||w<1||h<1||(long)w*h>16777216)throw new Exception("Source dimensions differ: "+Path.GetFileName(file));
   byte[] output=new byte[w*h*4];var data=bitmap.LockBits(new Rectangle(0,0,w,h),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
   try{for(int y=0;y<h;y++)Marshal.Copy(IntPtr.Add(data.Scan0,y*data.Stride),output,y*w*4,w*4);}finally{bitmap.UnlockBits(data);}
   // A BC5 color resource exposes R,G,0,1. Preserve that sampling convention
   // when moving the original accidentally-normal-compressed color maps to BGRA.
   if(normal)for(int i=0;i<output.Length;i+=4){output[i]=0;output[i+3]=255;}
   if(opaque)for(int i=3;i<output.Length;i+=4)output[i]=255;
   return output;
  }
 }
 static byte Byte(double v){return(byte)Math.Max(0,Math.Min(255,Math.Floor(v*255.0+.5)));}
 static List<byte[]> EncodeLevels(string file,Dictionary<string,object> row,List<byte[]> levels){
  string format=row.ContainsKey("format")?(string)row["format"]:"PF_B8G8R8A8";
  if(format=="PF_B8G8R8A8")return levels;
  if(format!="PF_DXT1"&&format!="PF_DXT5")throw new Exception("Unsupported install encoder");
  var layouts=A(row["mips"]);string cache=Path.Combine(Path.GetDirectoryName(file),"bc-cache");Directory.CreateDirectory(cache);
  for(int i=0;i<levels.Count;i++){
   var m=D(layouts[i]);int w=N(m["width"]),h=N(m["height"]),size=((w+3)/4)*((h+3)/4)*(format=="PF_DXT5"?16:8);
   string hash;using(var sha=SHA256.Create())hash=Hex(sha.ComputeHash(levels[i]));
   string name=Path.Combine(cache,PalCraftBc.Version+"-"+format+"-"+w+"x"+h+"-"+hash+".bc");
   byte[] encoded=null;
   if(File.Exists(name)&&File.Exists(name+".sha256")){byte[] saved=File.ReadAllBytes(name);using(var sha=SHA256.Create())if(saved.Length==size&&Hex(sha.ComputeHash(saved))==File.ReadAllText(name+".sha256"))encoded=saved;}
   if(encoded==null){encoded=PalCraftBc.Encode(levels[i],w,h,format=="PF_DXT5");File.WriteAllBytes(name,encoded);using(var sha=SHA256.Create())File.WriteAllText(name+".sha256",Hex(sha.ComputeHash(encoded)));}
   levels[i]=encoded;
  }
  return levels;
 }
 static List<byte[]> Mips(string file,Dictionary<string,object> row){
  int w=N(row["width"]),h=N(row["height"]);bool srgb=Convert.ToBoolean(row["srgb"]);byte[] raw=Pixels(file,w,h,Convert.ToBoolean(row["normalChannels"]),row.ContainsKey("forceOpaque")&&Convert.ToBoolean(row["forceOpaque"]));var result=new List<byte[]>{raw};var layouts=A(row["mips"]);
  if(layouts.Length==1)return EncodeLevels(file,row,result);
  float[] linear=new float[raw.Length];for(int i=0;i<raw.Length;i++){double v=raw[i]/255.0;linear[i]=(float)(i%4!=3&&srgb?(v<=.04045?v/12.92:Math.Pow((v+.055)/1.055,2.4)):v);}
  for(int mip=1;mip<layouts.Length;mip++){
   var m=D(layouts[mip]);int nw=N(m["width"]),nh=N(m["height"]);if(nw!=Math.Max(1,w/2)||nh!=Math.Max(1,h/2))throw new Exception("Unsupported mip dimensions");
   float[] next=new float[nw*nh*4];byte[] encoded=new byte[next.Length];
   for(int y=0;y<nh;y++)for(int x=0;x<nw;x++)for(int ch=0;ch<4;ch++){
    float sum=0;for(int yy=0;yy<2;yy++)for(int xx=0;xx<2;xx++)sum+=linear[(Math.Min(h-1,y*2+yy)*w+Math.Min(w-1,x*2+xx))*4+ch];
    int at=(y*nw+x)*4+ch;next[at]=sum*.25f;double v=next[at];encoded[at]=Byte(ch!=3&&srgb?(v<=.0031308?v*12.92:1.055*Math.Pow(v,1.0/2.4)-.055):v);
   }
   result.Add(encoded);linear=next;w=nw;h=nh;
  }
  return EncodeLevels(file,row,result);
 }
 static void Write(FileStream stream,long at,byte[] data){if(at<0||at>stream.Length-data.Length)throw new Exception("Payload range outside pak");stream.Position=at;stream.Write(data,0,data.Length);}
 static byte[] Sha1(FileStream stream,long at,long size){
  if(at<0||size<0||at>stream.Length-size)throw new Exception("Hash range outside pak");
  stream.Position=at;using(var hash=SHA1.Create()){byte[] buf=new byte[1048576];long remaining=size;while(remaining>0){int n=stream.Read(buf,0,(int)Math.Min(remaining,buf.Length));if(n<=0)throw new EndOfStreamException();hash.TransformBlock(buf,0,n,buf,0);remaining-=n;}hash.TransformFinalBlock(new byte[0],0,0);return hash.Hash;}
 }
 public static string Apply(string pakDirectory,string assetsDirectory,string manifestPath){
  string paks=Path.GetFullPath(pakDirectory).TrimEnd(Path.DirectorySeparatorChar),assets=Path.GetFullPath(assetsDirectory).TrimEnd(Path.DirectorySeparatorChar);
  var js=new JavaScriptSerializer{MaxJsonLength=100000000,RecursionLimit=256};var manifest=D(js.DeserializeObject(File.ReadAllText(manifestPath)));if(N(manifest["version"])!=1||N(manifest["pakVersion"])!=3)throw new Exception("Unsupported patch manifest");
  var receipts=new List<object>();int textures=0,fonts=0,skipped=0;var images=new Dictionary<string,List<byte[]>>();byte[] font=null;
  foreach(var item in A(manifest["paks"])){
   var pak=D(item);string name=(string)pak["name"];if(Path.GetFileName(name)!=name||!name.EndsWith(".pak",StringComparison.OrdinalIgnoreCase))throw new Exception("Invalid pak filename");string target=Under(paks,name);if(!File.Exists(target))continue;
   if(HashFile(target)!=(string)pak["sha256"])throw new Exception("Template SHA256 mismatch: "+name);
   var patches=A(pak["patches"]);var missing=patches.Select(p=>(string)D(p)["source"]).Distinct().Where(s=>!File.Exists(Under(assets,s))).ToArray();
   skipped+=missing.Length;
   string temp=target+".patch-"+Guid.NewGuid().ToString("N")+".tmp";
   File.Copy(target,temp,false);
   try{
    using(var stream=new FileStream(temp,FileMode.Open,FileAccess.ReadWrite,FileShare.None)){
     foreach(var rawRow in patches){var row=D(rawRow);long dataAt=L(row["dataOffset"]);string source=(string)row["source"];if(missing.Contains(source))continue;
      if((string)row["kind"]=="font"){
       if(font==null)font=File.ReadAllBytes(Under(assets,source));
       if(font.Length!=N(row["size"]))throw new Exception("Font payload size differs from its cooked layout");
       using(var h=SHA256.Create())if(Hex(h.ComputeHash(font))!=(string)row["expectedPayloadSha256"])throw new Exception("Generated font differs from supported Minecraft 1.21.11 face");
       Write(stream,dataAt+L(row["offset"]),font);fonts++;
      }else{
       string key=source+"|"+row["srgb"]+"|"+row["normalChannels"]+"|"+(row.ContainsKey("forceOpaque")?row["forceOpaque"]:false)+"|"+row["width"]+"x"+row["height"]+"|"+A(row["mips"]).Length+"|"+(row.ContainsKey("format")?row["format"]:"PF_B8G8R8A8");List<byte[]> levels;
       if(!images.TryGetValue(key,out levels)){levels=Mips(Under(assets,source),row);images[key]=levels;}
       var layouts=A(row["mips"]);for(int i=0;i<layouts.Length;i++){var m=D(layouts[i]);if(levels[i].Length!=N(m["size"]))throw new Exception("Mip payload size mismatch");Write(stream,dataAt+L(m["offset"]),levels[i]);}textures++;
      }
      long size=L(row.ContainsKey("fileSize")?row["fileSize"]:row["size"]);byte[] digest=Sha1(stream,dataAt,size);Write(stream,L(row["headerHashOffset"]),digest);Write(stream,L(row["indexHashOffset"]),digest);
     }
     byte[] index=Sha1(stream,L(pak["indexOffset"]),L(pak["indexSize"]));Write(stream,L(pak["indexHashOffset"]),index);stream.Flush(true);
    }
    // The only replaced file is the exact hash-bound blank template above.
    File.Replace(temp,target,null);receipts.Add(new{name=name,status=missing.Length==0?"PATCHED":"PARTIAL_BLANK_FALLBACK",sha256=HashFile(target),assets=patches.Length,missing=missing});
   }catch{
    // Keep failed output for diagnosis; the original blank pak still loads.
    if(File.Exists(temp))File.Move(temp,temp+".failed");throw;
   }
  }
  return js.Serialize(new{version=1,complete=skipped==0,textures=textures,fonts=fonts,blankFallbackAssets=skipped,paks=receipts});
 }
}
