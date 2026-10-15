// SPDX-License-Identifier: GPL-3.0-or-later
// Builds local outline glyphs from the user's Minecraft bitmap/unihex providers.
using System;using System.IO;using System.IO.Compression;using System.Drawing;using System.Text;using System.Linq;using System.Collections.Generic;using System.Web.Script.Serialization;
public static class PalCraftCookedFontCache {
 class Glyph {public int Advance;public List<int[]>Rects=new List<int[]>();}
 static Dictionary<int,Glyph> glyphs;static string root;static JavaScriptSerializer js=new JavaScriptSerializer();
 static Dictionary<string,object>D(object o){return(Dictionary<string,object>)o;}static object[]A(object o){return(object[])o;}static int N(object o){return Convert.ToInt32(o);}
 static bool Wanted(int c){int[][]ranges={new[]{0x20,0x52f},new[]{0x1100,0x11ff},new[]{0x2000,0x2bff},new[]{0x3000,0x303f},new[]{0x3130,0x318f},new[]{0xa960,0xa97f},new[]{0xac00,0xd7ff},new[]{0xff00,0xffef}};return ranges.Any(r=>c>=r[0]&&c<=r[1]);}
 static int[] Codes(string s){var r=new List<int>();for(int i=0;i<s.Length;i++){r.Add(char.ConvertToUtf32(s,i));if(char.IsHighSurrogate(s[i]))i++;}return r.ToArray();}
 static string Resource(string name,bool texture){string[]p=name.Split(':');string path=p.Length==2?p[1]:p[0];if(p.Length==2&&p[0]!="minecraft"||path.Contains("..")||path.Contains("\\")||path.StartsWith("/"))throw new Exception("Unsafe font resource");return Path.Combine(root,(texture?"textures/":"")+path);}
 static void Rects(Glyph g,int w,int h,Func<int,int,bool> on,double unit,int ascent){for(int y=0;y<h;y++){int x=0;while(x<w){if(!on(x,y)){x++;continue;}int start=x;while(x<w&&on(x,y))x++;g.Rects.Add(new[]{(int)Math.Round(start*unit),(int)Math.Round(ascent-y*unit),(int)Math.Round(x*unit),(int)Math.Round(ascent-(y+1)*unit)});}}}
 static void Providers(string name,int depth){if(depth>16)throw new Exception("Font provider depth");var doc=D(js.DeserializeObject(File.ReadAllText(Resource("minecraft:font/"+name+".json",false))));foreach(var raw in A(doc["providers"])){var p=D(raw);if(p.ContainsKey("filter")&&D(p["filter"]).ContainsKey("jp")&&Convert.ToBoolean(D(p["filter"])["jp"]))continue;string type=(string)p["type"];
  if(type=="reference"){Providers(((string)p["id"]).Split(':').Last(),depth+1);continue;}
  if(type=="space"){foreach(var v in D(p["advances"])){int cp=char.ConvertToUtf32(v.Key,0);glyphs[cp]=new Glyph{Advance=(int)Math.Round(Convert.ToDouble(v.Value)*128)};}continue;}
  if(type=="bitmap"){using(Bitmap b=new Bitmap(Resource((string)p["file"],true))){var rows=A(p["chars"]);int cw=b.Width/Codes((string)rows[0]).Length,ch=b.Height/rows.Length;double unit=(p.ContainsKey("height")?N(p["height"]):8)*128.0/ch;for(int y=0;y<rows.Length;y++){int[]line=Codes((string)rows[y]);for(int x=0;x<line.Length;x++){int cp=line[x];if(cp==0||cp>=0xd800&&cp<=0xdfff||glyphs.ContainsKey(cp))continue;int right=0;for(int iy=0;iy<ch;iy++)for(int ix=0;ix<cw;ix++)if(b.GetPixel(x*cw+ix,y*ch+iy).A>0)right=Math.Max(right,ix+1);if(right==0)continue;var g=new Glyph{Advance=(int)Math.Ceiling(right*unit/128+1)*128};int xx=x,yy=y;if(Wanted(cp))Rects(g,cw,ch,(ix,iy)=>b.GetPixel(xx*cw+ix,yy*ch+iy).A>0,unit,N(p["ascent"])*128);glyphs[cp]=g;}}}continue;}
  if(type=="unihex"){using(var zip=ZipFile.OpenRead(Resource((string)p["hex_file"],false))){foreach(var entry in zip.Entries.Where(e=>e.FullName.EndsWith(".hex")))using(var reader=new StreamReader(entry.Open())){string line;while((line=reader.ReadLine())!=null){var pair=line.Split(':');if(pair.Length!=2)continue;int cp=Convert.ToInt32(pair[0],16);if(cp==0||cp>=0xd800&&cp<=0xdfff||glyphs.ContainsKey(cp))continue;int w=pair[1].Length/4;byte[]bits=new byte[pair[1].Length/2];for(int i=0;i<bits.Length;i++)bits[i]=Convert.ToByte(pair[1].Substring(i*2,2),16);Func<int,int,bool>on=(x,y)=>(bits[y*w/8+x/8]&(1<<(7-x%8)))!=0;int left=w,right=-1;for(int y=0;y<16;y++)for(int x=0;x<w;x++)if(on(x,y)){left=Math.Min(left,x);right=Math.Max(right,x);}if(right<0){left=0;right=w-1;}if(p.ContainsKey("size_overrides"))foreach(var ov in A(p["size_overrides"])){var o=D(ov);if(cp>=char.ConvertToUtf32((string)o["from"],0)&&cp<=char.ConvertToUtf32((string)o["to"],0)){left=N(o["left"]);right=N(o["right"]);break;}}int l=left;var g=new Glyph{Advance=(right-left+1)*64+128};if(Wanted(cp))Rects(g,right-left+1,16,(x,y)=>x+l>=0&&x+l<w&&on(x+l,y),64,896);glyphs[cp]=g;}}}continue;}
 }}
 static void U16(Stream s,int v){s.WriteByte((byte)(v>>8));s.WriteByte((byte)v);}static void U32(Stream s,uint v){U16(s,(int)(v>>16));U16(s,(int)v);}static byte[]Data(Action<MemoryStream>f){using(var s=new MemoryStream()){f(s);return s.ToArray();}}static void Pad(Stream s){while(s.Length%4!=0)s.WriteByte(0);}static void S16(byte[]b,int at,int v){b[at]=(byte)(v>>8);b[at+1]=(byte)v;}static void S32(byte[]b,int at,uint v){S16(b,at,(int)(v>>16));S16(b,at+2,(int)v);}static uint Sum(byte[]b){uint v=0;for(int i=0;i<b.Length;i+=4){uint x=0;for(int j=0;j<4;j++)x=x<<8|(i+j<b.Length?b[i+j]:0u);v=unchecked(v+x);}return v;}
 static byte[] CompileGlyph(Glyph g) {
  if(g.Rects.Count==0)return new byte[0];
  var pts=new List<int[]>();foreach(var r in g.Rects){pts.Add(new[]{r[0],r[1]});pts.Add(new[]{r[2],r[1]});pts.Add(new[]{r[2],r[3]});pts.Add(new[]{r[0],r[3]});}
  var flags=new List<byte>();var xs=new MemoryStream();var ys=new MemoryStream();int px=0,py=0;
  foreach(var p in pts){int dx=p[0]-px,dy=p[1]-py;px=p[0];py=p[1];byte f=1;
   if(dx==0)f|=16;else if(Math.Abs(dx)<=255){f|=2;if(dx>0)f|=16;xs.WriteByte((byte)Math.Abs(dx));}else U16(xs,dx);
   if(dy==0)f|=32;else if(Math.Abs(dy)<=255){f|=4;if(dy>0)f|=32;ys.WriteByte((byte)Math.Abs(dy));}else U16(ys,dy);
   flags.Add(f);
  }
  return Data(s=>{U16(s,g.Rects.Count);U16(s,g.Rects.Min(r=>r[0]));U16(s,g.Rects.Min(r=>r[3]));U16(s,g.Rects.Max(r=>r[2]));U16(s,g.Rects.Max(r=>r[1]));for(int i=0;i<g.Rects.Count;i++)U16(s,4*i+3);U16(s,0);
   for(int i=0;i<flags.Count;){int count=1;while(i+count<flags.Count&&flags[i+count]==flags[i]&&count<256)count++;if(count>2){s.WriteByte((byte)(flags[i]|8));s.WriteByte((byte)(count-1));}else for(int j=0;j<count;j++)s.WriteByte(flags[i]);i+=count;}
   var x=xs.ToArray();var y=ys.ToArray();s.Write(x,0,x.Length);s.Write(y,0,y.Length);
  });
 }
 public static void Build(string assetsRoot) {
  root=Path.GetFullPath(assetsRoot);glyphs=new Dictionary<int,Glyph>();Providers("default",0);glyphs[32]=new Glyph{Advance=512};
  // Original authored subset plus the Unicode mirrored-symbol closure.
  int[] mirror={0x299b,0x29a0,0x29a3,0x29b8,0x29f5,0x2ade,0x2ae3,0x2ae4,0x2ae5,0x2aee,0x2bfe};
  var codes=glyphs.Keys.Where(c=>Wanted(c)&&(c<0x2800||c>0x2bff||mirror.Contains(c))).OrderBy(c=>c).ToArray();
  var gs=new List<Glyph>{new Glyph{Advance=768}};gs.AddRange(codes.Select(c=>glyphs[c]));
  var tables=new SortedDictionary<string,byte[]>(StringComparer.Ordinal);var offsets=new List<uint>();int maxContours=0;
  tables["glyf"]=Data(s=>{foreach(var g in gs){offsets.Add((uint)s.Length);maxContours=Math.Max(maxContours,g.Rects.Count);var bytes=CompileGlyph(g);s.Write(bytes,0,bytes.Length);}offsets.Add((uint)s.Length);});
  tables["loca"]=Data(s=>{foreach(uint v in offsets)U32(s,v);});
  tables["hmtx"]=Data(s=>{foreach(var g in gs){U16(s,g.Advance);U16(s,0);}});
  var rectangles=gs.SelectMany(g=>g.Rects).ToArray();int xmin=rectangles.Min(r=>r[0]),ymin=rectangles.Min(r=>r[3]),xmax=rectangles.Max(r=>r[2]),ymax=rectangles.Max(r=>r[1]);
  byte[] head=new byte[54];S32(head,0,0x10000);S32(head,4,0x10000);S32(head,12,0x5f0f3cf5);S16(head,16,1);S16(head,18,1024);
  // Stable build timestamps from the original authored face, not source metadata.
  S32(head,24,3873933529u);S32(head,32,3873934798u);S16(head,36,xmin);S16(head,38,ymin);S16(head,40,xmax);S16(head,42,ymax);S16(head,46,3);S16(head,48,2);S16(head,50,1);tables["head"]=head;
  byte[] hhea=new byte[36];S32(hhea,0,0x10000);S16(hhea,4,896);S16(hhea,6,-128);S16(hhea,8,128);S16(hhea,10,gs.Max(g=>g.Advance));
  S16(hhea,14,gs.Where(g=>g.Rects.Count>0).Min(g=>g.Advance-g.Rects.Max(r=>r[2])+g.Rects.Min(r=>r[0])));S16(hhea,16,gs.Where(g=>g.Rects.Count>0).Max(g=>g.Rects.Max(r=>r[2])-g.Rects.Min(r=>r[0])));S16(hhea,18,1);S16(hhea,34,gs.Count);tables["hhea"]=hhea;
  byte[] maxp=new byte[32];S32(maxp,0,0x10000);S16(maxp,4,gs.Count);S16(maxp,6,maxContours*4);S16(maxp,8,maxContours);S16(maxp,14,2);tables["maxp"]=maxp;
  byte[] os2=new byte[96];S16(os2,0,3);S16(os2,2,(int)Math.Round(glyphs.OrderBy(k=>k.Key).Take(60000).Select(k=>k.Value.Advance).Concat(new[]{768}).Where(w=>w>0).Average(),MidpointRounding.AwayFromZero));S16(os2,4,400);S16(os2,6,5);S16(os2,8,4);
  // Unicode coverage flags describe our selected script ranges.
  S32(os2,42,0x900002ff);S32(os2,46,0x0111ffff);S32(os2,50,0x10);Encoding.ASCII.GetBytes("????").CopyTo(os2,58);S16(os2,64,codes.First());S16(os2,66,codes.Last());S16(os2,68,896);S16(os2,70,-128);S16(os2,72,128);S16(os2,74,1280);S16(os2,76,384);S32(os2,78,1);S16(os2,92,32);tables["OS/2"]=os2;
  var segs=new List<int[]>();for(int i=0;i<codes.Length;){int start=i;while(i+1<codes.Length&&codes[i+1]==codes[i]+1)i++;segs.Add(new[]{codes[start],codes[i],start+1-codes[start]});i++;}segs.Add(new[]{65535,65535,1});
  byte[] cmap=Data(s=>{int n=segs.Count,p=1,e=0;while(p*2<=n){p*=2;e++;}U16(s,4);U16(s,16+n*8);U16(s,0);U16(s,n*2);U16(s,p*2);U16(s,e);U16(s,n*2-p*2);foreach(var r in segs)U16(s,r[1]);U16(s,0);foreach(var r in segs)U16(s,r[0]);foreach(var r in segs)U16(s,r[2]);foreach(var r in segs)U16(s,0);});
  tables["cmap"]=Data(s=>{U16(s,0);U16(s,2);U16(s,0);U16(s,3);U32(s,20);U16(s,3);U16(s,1);U32(s,20);s.Write(cmap,0,cmap.Length);});
  tables["name"]=Data(s=>{string[] names={"MinecraftPal","Regular","MinecraftPalPersonal2026","MinecraftPal Regular","Version 1.0","MinecraftPal-Regular"};byte[][] bytes=names.Select(n=>Encoding.BigEndianUnicode.GetBytes(n)).ToArray();U16(s,0);U16(s,6);U16(s,78);int at=0;for(int i=0;i<6;i++){U16(s,3);U16(s,1);U16(s,0x409);U16(s,i+1);U16(s,bytes[i].Length);U16(s,at);at+=bytes[i].Length;}foreach(var b in bytes)s.Write(b,0,b.Length);});
  byte[] post=new byte[32];S32(post,0,0x30000);tables["post"]=post;
  string[] order={"head","hhea","maxp","OS/2","hmtx","cmap","loca","glyf","name","post"};var locations=new Dictionary<string,int>();int offset=12+tables.Count*16;foreach(string tag in order){locations[tag]=offset;offset+=(tables[tag].Length+3)&~3;}
  byte[] font=Data(s=>{U32(s,0x10000);U16(s,10);U16(s,128);U16(s,3);U16(s,32);foreach(var t in tables){var tag=Encoding.ASCII.GetBytes(t.Key);s.Write(tag,0,4);U32(s,Sum(t.Value));U32(s,(uint)locations[t.Key]);U32(s,(uint)t.Value.Length);}foreach(string tag in order){byte[] b=tables[tag];s.Write(b,0,b.Length);Pad(s);}});
  S32(font,locations["head"]+8,unchecked(0xb1b0afba-Sum(font)));string folder=Path.Combine(root,"_palcraft");Directory.CreateDirectory(folder);File.WriteAllBytes(Path.Combine(folder,"font.ttf"),font);File.WriteAllText(Path.Combine(folder,"font-metrics.json"),js.Serialize(codes.ToDictionary(c=>c.ToString(),c=>glyphs[c].Advance/128.0)));Console.WriteLine("PalCraft cooked font: "+codes.Length+" glyphs, "+font.Length+" bytes");
 }
}
