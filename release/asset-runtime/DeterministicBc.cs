// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright Invi. Deterministic BC1/BC3 encoder; independent blocks, no native codec.
using System;
using System.Threading.Tasks;
public static class PalCraftBc {
 public const string Version="oc-bc3-pca-ls-2";
 static int Clamp(int x,int hi){return Math.Max(0,Math.Min(hi,x));}
 static int Pack(double r,double g,double b){return (Clamp((int)Math.Floor(r*31/255+.5),31)<<11)|(Clamp((int)Math.Floor(g*63/255+.5),63)<<5)|Clamp((int)Math.Floor(b*31/255+.5),31);}
 static void Unpack(int c,int[] p,int o){int r=c>>11,g=(c>>5)&63,b=c&31;p[o]=(r<<3)|(r>>2);p[o+1]=(g<<2)|(g>>4);p[o+2]=(b<<3)|(b>>2);}
 static long Fit(byte[] rgb,byte[] mask,int c0,int c1,out uint indices){
  int[] p=new int[12];Unpack(c0,p,0);Unpack(c1,p,3);
  for(int c=0;c<3;c++){p[6+c]=(2*p[c]+p[3+c])/3;p[9+c]=(p[c]+2*p[3+c])/3;}
  long err=0;indices=0;
  for(int i=0;i<16;i++){if(mask[i]==0)continue;int best=0,e=int.MaxValue;for(int k=0;k<4;k++){int d=0;for(int c=0;c<3;c++){int x=rgb[i*3+c]-p[k*3+c];d+=x*x;}if(d<e){e=d;best=k;}}err+=e;indices|=(uint)best<<(2*i);}
  return err;
 }
 static void Ordered(ref int a,ref int b){if(a<b){int t=a;a=b;b=t;}if(a==b){if(a<65535)a++;else b--;}}
 static void Block(byte[] src,int w,int h,int bx,int by,byte[] dst,int at,bool alpha){
  byte[] rgb=new byte[48],al=new byte[16];double[] mean=new double[3];int amin=255,amax=0;
  for(int i=0;i<16;i++){int s=(Math.Min(h-1,by*4+i/4)*w+Math.Min(w-1,bx*4+i%4))*4;for(int c=0;c<3;c++){rgb[i*3+c]=src[s+2-c];}al[i]=src[s+3];amin=Math.Min(amin,al[i]);amax=Math.Max(amax,al[i]);}
  if(alpha){dst[at]=(byte)amax;dst[at+1]=(byte)amin;int[] ap=new int[8];ap[0]=amax;ap[1]=amin;for(int k=2;k<8;k++)ap[k]=((8-k)*amax+(k-1)*amin)/7;ulong bits=0;for(int i=0;i<16;i++){int alphaBest=0,e=int.MaxValue;for(int k=0;k<8;k++){int d=Math.Abs(al[i]-ap[k]);if(d<e){e=d;alphaBest=k;}}bits|=(ulong)alphaBest<<(3*i);}for(int k=0;k<6;k++)dst[at+2+k]=(byte)(bits>>(8*k));at+=8;}
  int visible=0;for(int i=0;i<16;i++)if(al[i]>0){visible++;for(int c=0;c<3;c++)mean[c]+=rgb[i*3+c];}for(int c=0;c<3;c++)mean[c]/=Math.Max(1,visible);
  double[,] cov=new double[3,3];for(int i=0;i<16;i++)if(al[i]>0)for(int c=0;c<3;c++)for(int d=0;d<3;d++)cov[c,d]+=(rgb[i*3+c]-mean[c])*(rgb[i*3+d]-mean[d]);
  double[] axis={1,1,1};for(int k=0;k<8;k++){double[] v=new double[3];double norm=0;for(int c=0;c<3;c++){for(int d=0;d<3;d++)v[c]+=cov[c,d]*axis[d];norm+=v[c]*v[c];}if(norm<1e-12)break;norm=Math.Sqrt(norm);for(int c=0;c<3;c++)axis[c]=v[c]/norm;}
  double lo=double.MaxValue,hi=double.MinValue;int il=0,ih=0;for(int i=0;i<16;i++){if(al[i]==0)continue;double v=0;for(int c=0;c<3;c++)v+=rgb[i*3+c]*axis[c];if(v<lo){lo=v;il=i;}if(v>hi){hi=v;ih=i;}}
  int a=Pack(rgb[ih*3],rgb[ih*3+1],rgb[ih*3+2]),b=Pack(rgb[il*3],rgb[il*3+1],rgb[il*3+2]);Ordered(ref a,ref b);uint idx;long best=Fit(rgb,al,a,b,out idx);int ba=a,bb=b;uint bi=idx;
  double[] weights={1,0,2.0/3,1.0/3};
  for(int pass=0;pass<6;pass++){double aa=0,ab=0,bbv=0;double[] ar=new double[3],br=new double[3];for(int i=0;i<16;i++){if(al[i]==0)continue;double x=weights[(int)((idx>>(2*i))&3)],y=1-x;aa+=x*x;ab+=x*y;bbv+=y*y;for(int c=0;c<3;c++){ar[c]+=x*rgb[i*3+c];br[c]+=y*rgb[i*3+c];}}double det=aa*bbv-ab*ab;if(det<1e-10)break;double[] av=new double[3],bv=new double[3];for(int c=0;c<3;c++){av[c]=(ar[c]*bbv-br[c]*ab)/det;bv[c]=(br[c]*aa-ar[c]*ab)/det;}a=Pack(av[0],av[1],av[2]);b=Pack(bv[0],bv[1],bv[2]);Ordered(ref a,ref b);long err=Fit(rgb,al,a,b,out idx);if(err<best){best=err;ba=a;bb=b;bi=idx;}else break;}
  // Search one quantization step per channel around each fitted endpoint.
  int[] steps={1,32,2048};for(int pass=0;pass<2;pass++)for(int end=0;end<2;end++)foreach(int step in steps)for(int sign=-1;sign<=1;sign+=2){a=ba;b=bb;int value=(end==0?a:b),shift=step==1?0:step==32?5:11,limit=step==32?63:31;if(((value>>shift)&limit)+sign<0||((value>>shift)&limit)+sign>limit)continue;if(end==0)a+=sign*step;else b+=sign*step;Ordered(ref a,ref b);long err=Fit(rgb,al,a,b,out idx);if(err<best){best=err;ba=a;bb=b;bi=idx;}}
  dst[at]=(byte)ba;dst[at+1]=(byte)(ba>>8);dst[at+2]=(byte)bb;dst[at+3]=(byte)(bb>>8);for(int k=0;k<4;k++)dst[at+4+k]=(byte)(bi>>(8*k));
 }
 public static byte[] Encode(byte[] bgra,int width,int height,bool alpha){if(bgra.Length!=checked(width*height*4)||width<1||height<1)throw new ArgumentException("BC input size");int nx=(width+3)/4,ny=(height+3)/4,size=alpha?16:8;byte[] output=new byte[nx*ny*size];Parallel.For(0,ny,new ParallelOptions{MaxDegreeOfParallelism=Math.Min(4,Environment.ProcessorCount)},y=>{for(int x=0;x<nx;x++)Block(bgra,width,height,x,y,output,(y*nx+x)*size,alpha);});return output;}
}
