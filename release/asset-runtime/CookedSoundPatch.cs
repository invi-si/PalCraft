// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright Invi. Install-time, variable-length Vorbis payload replacement.
using System;using System.IO;using System.Text;using System.Linq;using System.Collections.Generic;using System.Security.Cryptography;using System.Web.Script.Serialization;
public static class PalCraftCookedSoundPatch {
 static Dictionary<string,object> D(object o){return (Dictionary<string,object>)o;}static object[] A(object o){return (object[])o;}static int N(object o){return Convert.ToInt32(o);}static long L(object o){return Convert.ToInt64(o);}
 static string Hex(byte[] b){return BitConverter.ToString(b).Replace("-","").ToLowerInvariant();}
 static byte[] Sha1(byte[] b){using(var h=SHA1.Create())return h.ComputeHash(b);}static string Sha256(byte[] b){using(var h=SHA256.Create())return Hex(h.ComputeHash(b));}
 static string Under(string root,string rel){if(String.IsNullOrEmpty(rel)||rel.Contains("..")||rel.Contains(":")||rel.Contains("\\")||rel.StartsWith("/"))throw new Exception("Unsafe sound path");string p=Path.GetFullPath(Path.Combine(root,rel));if(!p.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new Exception("Sound path escaped root");return p;}
 static void Put(byte[] b,int at,byte[] value){if(at<0||at>b.Length-value.Length)throw new Exception("Sound field outside export");Buffer.BlockCopy(value,0,b,at,value.Length);}
 static uint[] CrcTable(){var t=new uint[256];for(int i=0;i<256;i++){uint r=(uint)i<<24;for(int k=0;k<8;k++)r=(r&0x80000000)!=0?(r<<1)^0x04c11db7:r<<1;t[i]=r;}return t;}
 static readonly uint[] crc=CrcTable();
 class Ogg {public int Channels,Rate;public long Frames;public double Duration;}
 static Ogg Validate(byte[] b){
  if(b.Length<58||b.Length>33554432)throw new Exception("Ogg size");int at=0;uint seq=0,serial=0;long frames=-1;Ogg result=null;
  while(at<b.Length){
   if(b.Length-at<27||b[at]!=79||b[at+1]!=103||b[at+2]!=103||b[at+3]!=83||b[at+4]!=0)throw new Exception("Ogg page header");
   int flags=b[at+5],head=27+b[at+26];if(at>b.Length-head)throw new Exception("Ogg lacing");int size=0;for(int i=27;i<head;i++)size+=b[at+i];if(at>b.Length-head-size)throw new Exception("Ogg truncated");
   uint s=BitConverter.ToUInt32(b,at+14),q=BitConverter.ToUInt32(b,at+18),check=0,expected=BitConverter.ToUInt32(b,at+22);
   for(int i=0;i<head+size;i++){byte v=(i>=22&&i<26)?(byte)0:b[at+i];check=(check<<8)^crc[((check>>24)^v)&255];}if(check!=expected)throw new Exception("Ogg CRC");
   if(seq==0){
    if(flags!=2||size<30)throw new Exception("Ogg beginning");serial=s;int p=at+head;if(b[p]!=1||Encoding.ASCII.GetString(b,p+1,6)!="vorbis"||BitConverter.ToInt32(b,p+7)!=0)throw new Exception("Not Vorbis");
    result=new Ogg{Channels=b[p+11],Rate=BitConverter.ToInt32(b,p+12)};
   }
   if(s!=serial||q!=seq++)throw new Exception("Chained/disordered Ogg");
   if((flags&4)!=0){if(at+head+size!=b.Length)throw new Exception("Ogg trailing data");frames=BitConverter.ToInt64(b,at+6);}
   at+=head+size;
  }
  if(result==null||frames<=0||result.Channels<1||result.Channels>2||result.Rate<8000||result.Rate>192000)throw new Exception("Ogg audio limits");result.Frames=frames;result.Duration=frames/(double)result.Rate;if(result.Duration>600)throw new Exception("Ogg duration limit");return result;
 }
 static void PakString(BinaryWriter w,string s){byte[] b=Encoding.UTF8.GetBytes(s);w.Write(b.Length+1);w.Write(b);w.Write((byte)0);}
 static void Entry(BinaryWriter w,long offset,byte[] data){w.Write(offset);w.Write((long)data.Length);w.Write((long)data.Length);w.Write(0);w.Write(Sha1(data));w.Write((byte)0);w.Write(0);}
 static void WritePak(string path,SortedDictionary<string,byte[]> files){
  using(var fs=new FileStream(path,FileMode.CreateNew,FileAccess.Write))using(var w=new BinaryWriter(fs)){
   var offsets=new Dictionary<string,long>();foreach(var pair in files){offsets[pair.Key]=fs.Position;Entry(w,0,pair.Value);w.Write(pair.Value);}
   long indexAt=fs.Position;byte[] index;using(var ms=new MemoryStream())using(var iw=new BinaryWriter(ms)){PakString(iw,"../../../");iw.Write(files.Count);foreach(var pair in files){PakString(iw,pair.Key);Entry(iw,offsets[pair.Key],pair.Value);}iw.Flush();index=ms.ToArray();}
   w.Write(index);w.Write((uint)0x5a6f12e1);w.Write(3);w.Write(indexAt);w.Write((long)index.Length);w.Write(Sha1(index));w.Flush();fs.Flush(true);
  }
 }
 public static string Apply(string pakDirectory,string assetsDirectory,string manifestPath){
  string paks=Path.GetFullPath(pakDirectory).TrimEnd(Path.DirectorySeparatorChar),assets=Path.GetFullPath(assetsDirectory).TrimEnd(Path.DirectorySeparatorChar);
  var js=new JavaScriptSerializer{MaxJsonLength=16000000,RecursionLimit=128};var manifest=D(js.DeserializeObject(File.ReadAllText(manifestPath)));if(N(manifest["version"])!=1)throw new Exception("Unsupported sound manifest");
  var receipts=new List<object>();int patched=0,silent=0;
  foreach(var raw in A(manifest["paks"])){
   var pak=D(raw);string name=(string)pak["name"];if(Path.GetFileName(name)!=name||!name.EndsWith(".pak",StringComparison.OrdinalIgnoreCase))throw new Exception("Sound pak filename");string target=Under(paks,name);if(!File.Exists(target))continue;
   byte[] template=File.ReadAllBytes(target);if(Sha256(template)!=(string)pak["sha256"])throw new Exception("Sound template SHA256 mismatch: "+name);
   var files=new SortedDictionary<string,byte[]>(StringComparer.Ordinal);
   foreach(var rawEntry in A(pak["entries"])){
    var entry=D(rawEntry);string path=(string)entry["path"];if(!path.StartsWith("Pal/Content/")||path.Contains("..")||path.Contains(":")||path.Contains("\\"))throw new Exception("Sound entry path");int at=N(entry["dataOffset"]),size=N(entry["size"]);if(size<0||at<0||at>template.Length-size)throw new Exception("Sound entry range");byte[] b=new byte[size];Buffer.BlockCopy(template,at,b,0,size);if(Sha256(b)!=(string)entry["sha256"])throw new Exception("Sound entry hash");files.Add(path,b);
   }
   var items=new List<object>();foreach(var rawSound in A(pak["sounds"])){
    var row=D(rawSound);string source=(string)row["source"],path=Under(assets,source),stem=(string)row["file"];string status="PATCHED",reason=null;Ogg info=null;byte[] ogg=null;
    try{if(!File.Exists(path))throw new Exception("Source missing");var fi=new FileInfo(path);if(fi.Length>33554432)throw new Exception("Source exceeds limit");ogg=File.ReadAllBytes(path);if(row.ContainsKey("sourceSha1")&&Hex(Sha1(ogg))!=(string)row["sourceSha1"])throw new Exception("Source SHA1 differs from supported Minecraft version");info=Validate(ogg);}
    catch(Exception ex){status="SILENT_FALLBACK";reason=ex.Message;silent++;}
    if(info!=null){
     byte[] h=files[stem+".uasset"],d=files[stem+".uexp"];var layout=D(row["layout"]);int offset=N(layout["payloadOffset"]),oldSize=N(layout["payloadSize"]),bulk=N(layout["bulkHeaderOffset"]);
     if(offset<20||oldSize<1||offset>d.Length-oldSize||d.Length-offset-oldSize!=20||BitConverter.ToInt32(d,bulk)!=0x48||BitConverter.ToInt32(d,bulk+4)!=oldSize||BitConverter.ToInt32(d,bulk+8)!=oldSize||BitConverter.ToInt64(d,bulk+12)!=(long)h.Length+offset)throw new Exception("Sound template layout differs");
     byte[] output=new byte[d.Length-oldSize+ogg.Length];Buffer.BlockCopy(d,0,output,0,offset);Buffer.BlockCopy(ogg,0,output,offset,ogg.Length);Buffer.BlockCopy(d,offset+oldSize,output,offset+ogg.Length,20);
     Put(output,bulk+4,BitConverter.GetBytes(ogg.Length));Put(output,bulk+8,BitConverter.GetBytes(ogg.Length));var props=D(layout["properties"]);
     Put(output,N(props["Duration"]),BitConverter.GetBytes((float)info.Duration));Put(output,N(props["TotalSamples"]),BitConverter.GetBytes((float)(info.Frames*info.Channels)));Put(output,N(props["SampleRate"]),BitConverter.GetBytes(info.Rate));Put(output,N(props["NumChannels"]),BitConverter.GetBytes(info.Channels));
     Put(h,N(layout["exportSizeOffset"]),BitConverter.GetBytes((long)output.Length-4));Put(h,N(layout["bulkStartOffset"]),BitConverter.GetBytes((long)h.Length+output.Length-4));files[stem+".uexp"]=output;patched++;
    }
    items.Add(new{package=row["package"],source=source,status=status,reason=reason,sampleRate=info==null?0:info.Rate,channels=info==null?0:info.Channels,frames=info==null?0:info.Frames,duration=info==null?0:info.Duration});
   }
   string temp=target+".audio-"+Guid.NewGuid().ToString("N")+".tmp";
   try{WritePak(temp,files);File.Replace(temp,target,null);}catch{if(File.Exists(temp))File.Move(temp,temp+".failed");throw;}
   receipts.Add(new{name=name,sha256=Sha256(File.ReadAllBytes(target)),sounds=items});
  }
  return js.Serialize(new{version=1,complete=silent==0,patched=patched,silentFallback=silent,paks=receipts});
 }
}
