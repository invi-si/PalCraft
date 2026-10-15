// SPDX-License-Identifier: GPL-3.0-or-later
// User-owned local resources only. Declarative transforms contain no image data.
using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Web.Script.Serialization;
public class PalCraftTextureCache {
 class Pix {
  public int W,H; public uint[] P;
  public Pix(int w,int h){if(w<1||h<1||w>8192||h>8192||(long)w*h>16777216)throw new Exception("Image budget exceeded");W=w;H=h;P=new uint[w*h];}
  public uint At(int x,int y){return x<0||y<0||x>=W||y>=H?0:P[y*W+x];}
 }
 string Root;Dictionary<string,object> Nodes;Dictionary<string,Pix> Cache=new Dictionary<string,Pix>();
 static Dictionary<string,object> D(object v){return(Dictionary<string,object>)v;}
 static object[] A(object v){return(object[])v;}
 static int I(object v){return Convert.ToInt32(v);} static double F(object v){return Convert.ToDouble(v);}
 static uint Color(object[] a){return (uint)(I(a[3])<<24|I(a[0])<<16|I(a[1])<<8|I(a[2]));}
 static int C(uint p,int s){return(int)(p>>s)&255;}
 string Safe(string relative){if(relative.Contains("..")||relative.Contains(":")||relative.Contains("\\")||relative.StartsWith("/"))throw new Exception("Unsafe resource path");string p=Path.GetFullPath(Path.Combine(Root,relative));if(!p.StartsWith(Root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new Exception("Resource escape");return p;}
 Pix Read(string path){using(Bitmap b=new Bitmap(Safe(path))){Pix r=new Pix(b.Width,b.Height);BitmapData d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);try{int[] row=new int[b.Width];for(int y=0;y<b.Height;y++){Marshal.Copy(IntPtr.Add(d.Scan0,y*d.Stride),row,0,row.Length);for(int x=0;x<row.Length;x++)r.P[y*r.W+x]=unchecked((uint)row[x]);}}finally{b.UnlockBits(d);}return r;}}
 void Save(Pix p,string path){string file=Safe(path);Directory.CreateDirectory(Path.GetDirectoryName(file));using(Bitmap b=new Bitmap(p.W,p.H,PixelFormat.Format32bppArgb)){BitmapData d=b.LockBits(new Rectangle(0,0,p.W,p.H),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);try{int[] row=new int[p.W];for(int y=0;y<p.H;y++){for(int x=0;x<p.W;x++)row[x]=unchecked((int)p.P[y*p.W+x]);Marshal.Copy(row,0,IntPtr.Add(d.Scan0,y*d.Stride),row.Length);}}finally{b.UnlockBits(d);}string temp=file+".tmp";b.Save(temp,ImageFormat.Png);if(File.Exists(file))File.Delete(file);File.Move(temp,file);}}
 static uint Over(uint bg,uint fg){int a=C(fg,24),b=C(bg,24);if(a==255)return fg;if(a==0)return bg;int blend=b*(255-a),alpha=a*255+blend;int coef1=a*255*255*128/alpha,coef2=255*128-coef1;uint r=(uint)((alpha+127)/255)<<24;foreach(int s in new int[]{16,8,0}){int t=C(fg,s)*coef1+C(bg,s)*coef2+128*128;r|=(uint)(((t+(t>>8))>>8)>>7)<<s;}return r;}
 Pix Render(string id){Pix cached;if(Cache.TryGetValue(id,out cached))return cached;var n=D(Nodes[id]);string op=(string)n["op"];object[] a=n.ContainsKey("args")?A(n["args"]):new object[0];Pix p=n.ContainsKey("src")?Render((string)n["src"]):null,r=null;
  if(op=="source")r=Read((string)n["path"]);
  else if(op=="new"){r=new Pix(I(a[0]),I(a[1]));if(a.Length>2){uint color=Color(A(a[2]));for(int i=0;i<r.P.Length;i++)r.P[i]=color;}}
  else if(op=="compose"){var size=A(n["size"]);r=new Pix(I(size[0]),I(size[1]));foreach(object v in A(n["layers"])){var layer=D(v);var src=Render((string)layer["src"]);var xy=layer.ContainsKey("xy")?A(layer["xy"]):new object[]{0,0};int ox=I(xy[0]),oy=I(xy[1]);bool blend=layer.ContainsKey("blend")&&(bool)layer["blend"];for(int y=0;y<src.H;y++)for(int x=0;x<src.W;x++){int dx=x+ox,dy=y+oy;if(dx>=0&&dy>=0&&dx<r.W&&dy<r.H){int i=dy*r.W+dx;r.P[i]=blend?Over(r.P[i],src.P[y*src.W+x]):src.P[y*src.W+x];}}}}
  else if(op=="crop"){r=new Pix(I(a[2])-I(a[0]),I(a[3])-I(a[1]));for(int y=0;y<r.H;y++)for(int x=0;x<r.W;x++)r.P[y*r.W+x]=p.At(x+I(a[0]),y+I(a[1]));}
  else if(op=="resize"){r=Resize(p,I(a[0]),I(a[1]));}
  else if(op=="tile"){r=new Pix(I(a[0]),I(a[1]));for(int y=0;y<r.H;y++)for(int x=0;x<r.W;x++)r.P[y*r.W+x]=p.At(x%p.W,y%p.H);}
  else if(op=="edgePad"){int pad=I(a[0]);r=new Pix(p.W+2*pad,p.H+2*pad);for(int y=0;y<r.H;y++)for(int x=0;x<r.W;x++)r.P[y*r.W+x]=p.At(Math.Min(p.W-1,Math.Max(0,x-pad)),Math.Min(p.H-1,Math.Max(0,y-pad)));}
  else if(op=="waterShade"){r=new Pix(p.W,p.H);for(int i=0;i<r.P.Length;i++){double factor=.82+.18*C(p.P[i],16)/255.0;uint col=(uint)I(a[3])<<24;for(int j=0;j<3;j++)col|=(uint)Math.Round(F(a[j])*factor)<<(16-j*8);r.P[i]=col;}}
  else if(op=="tintFactor"){r=new Pix(p.W,p.H);for(int i=0;i<r.P.Length;i++){uint col=p.P[i]&0xff000000;for(int j=0;j<3;j++)col|=(uint)(int)(C(p.P[i],16-j*8)*F(a[j]))<<(16-j*8);r.P[i]=col;}}
  else if(op=="flip"){r=new Pix(p.W,p.H);bool horizontal=(string)a[0]=="x";for(int y=0;y<r.H;y++)for(int x=0;x<r.W;x++)r.P[y*r.W+x]=p.At(horizontal?p.W-1-x:x,horizontal?y:p.H-1-y);}
  else if(op=="rotate"){r=new Pix(p.W,p.H);int angle=((I(a[0])%360)+360)%360;for(int y=0;y<r.H;y++)for(int x=0;x<r.W;x++)r.P[y*r.W+x]=angle==90?p.At(p.W-1-y,x):angle==180?p.At(p.W-1-x,p.H-1-y):angle==270?p.At(y,p.H-1-x):p.At(x,y);}
  else if(op=="iso"){r=new Pix(32,32);int[][]points={new int[]{16,1,30,9,2,9},new int[]{2,9,16,17,2,23},new int[]{16,17,30,9,16,31}};double[]shades={1,.8,.6};var faces=A(n["faces"]);for(int f=0;f<3;f++){Pix face=Render((string)faces[f]);var q=points[f];double aa=(q[2]-q[0])/16.0,b=(q[4]-q[0])/16.0,c=(q[3]-q[1])/16.0,d=(q[5]-q[1])/16.0,det=aa*d-b*c;for(int y=0;y<32;y++)for(int x=0;x<32;x++){double[] vv={d/det,-b/det,(b*q[1]-d*q[0])/det,-c/det,aa/det,(c*q[0]-aa*q[1])/det};int[] k=new int[6];for(int j=0;j<6;j++)k[j]=(int)Math.Floor(vv[j]*65536+.5);int u=(k[0]*x+k[1]*y+k[2]+((k[0]+k[1])>>1))>>16,v=(k[3]*x+k[4]*y+k[5]+((k[3]+k[4])>>1))>>16;uint col=face.At(u,v);uint shaded=col&0xff000000;foreach(int shift in new int[]{16,8,0})shaded|=(uint)Math.Round(C(col,shift)*shades[f])<<shift;r.P[y*32+x]=Over(r.P[y*32+x],shaded);}}var size=n.ContainsKey("size")?A(n["size"]):new object[]{128,128};r=Resize(r,I(size[0]),I(size[1]));}
  else {r=new Pix(p.W,p.H);Array.Copy(p.P,r.P,p.P.Length);if(op=="fill"){for(int y=I(a[1]);y<=I(a[3]);y++)for(int x=I(a[0]);x<=I(a[2]);x++)if(x>=0&&y>=0&&x<r.W&&y<r.H)r.P[y*r.W+x]=Color(A(a[4]));}else for(int i=0;i<r.P.Length;i++){uint col=p.P[i],outc=col&0xff000000;if(op=="alpha")outc=(uint)I(a[0])<<24|col&0xffffff;else if(op=="alphaScale")outc=(uint)(int)(C(col,24)*F(a[0]))<<24|col&0xffffff;else if(op=="colorMask")outc=col&0xff000000|Color(a)&0xffffff;else foreach(int shift in new int[]{16,8,0}){int value=C(col,shift),j=(16-shift)/8;if(op=="tint")value=(int)Math.Floor(value*F(a[j])/255.0);else if(op=="tintRound")value=(int)Math.Floor(value*F(a[j])+.5);else if(op=="hit")value=(int)(value+((shift==16?255:20)-value)*.35f);else if(op=="linearTint"){double linear=value/255.0;linear=linear<=.04045?linear/12.92:Math.Pow((linear+.055)/1.055,2.4);linear*=F(a[j]);value=(int)Math.Round(255*(linear<=.0031308?linear*12.92:1.055*Math.Pow(linear,1/2.4)-.055));}else throw new Exception("Unknown operation "+op);outc|=(uint)value<<shift;}r.P[i]=outc;}}
  Cache[id]=r;return r;
 }
 static Pix Resize(Pix p,int w,int h){Pix r=new Pix(w,h);for(int y=0;y<h;y++)for(int x=0;x<w;x++)r.P[y*w+x]=p.At(Math.Min(p.W-1,(int)((x+.5)*p.W/w)),Math.Min(p.H-1,(int)((y+.5)*p.H/h)));return r;}
 public static void Build(string root,string recipes){var js=new JavaScriptSerializer();js.MaxJsonLength=100000000;js.RecursionLimit=256;var data=D(js.DeserializeObject(File.ReadAllText(recipes)));var worker=new PalCraftTextureCache();worker.Root=Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar,Path.AltDirectorySeparatorChar);worker.Nodes=D(data["nodes"]);int done=0;var failed=new List<string>();foreach(var row in D(data["outputs"])){try{worker.Save(worker.Render((string)row.Value),row.Key);done++;}catch(Exception e){failed.Add(row.Key+": "+e.Message);}}File.WriteAllText(Path.Combine(root,"_palcraft-cache-receipt.json"),js.Serialize(new{complete=failed.Count==0,generated=done,failed=failed}));Console.WriteLine("PalCraft cache: "+done+" generated, "+failed.Count+" unavailable");}
}
