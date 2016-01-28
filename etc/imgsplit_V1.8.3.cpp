/* imgsplit.cpp : Defines the entry point for the console application.
	2012-5-18: 修改 gifsplit 函数参数(不使用特殊高度来确定是否保存到缓存)
	2012-5-14: 添加 K3 PDF 需要图片切割到缓存, 修改main函数参数列表(-w -h)
	2012-5-8: 修正 joblist ，可任意切割大小
	2012-4-26: Dll 添加:gifcat函数:将多张图片合成为一张图片(如果同一章节图片不同，可能会有未知错误)，处理速度有微量增加
	2012-4-25: Dll 添加:gif2png_bufopen,gif2png_bufclose, bugfix: png序号增为3位
	2012-4-23: Dll 添加:gifsplit, 若要使用lib编译独立dll，需要标志:FREEIMAGE_LIB，若要编译进原始DLL，去掉该标志，并去掉初始化和反初始化代码
	2012-4-16: 添加 多图片连续处理
	2012-4-16: 修正 最后一行 action = 1 后 = 2 的状况，会造成未使用模版，使用+法修正
*/

// gifsplit() : bSaveToBuff = 1 时:输出到buff,且首图为PDF标题空出一段，LineSpace

// #define FREEIMAGE_LIB

#define WIN32_LEAN_AND_MEAN
#pragma comment ( linker,"/ALIGN:4096" )

#include <stdio.h>
#include <math.h>
#include <string.h>
#include "FreeImage.h"

#define FOX_DLL extern "C" __declspec(dllexport)  // DLL导出


#define MAXGIFCOUNT 10   // 最大图片数
#define MAXPATHCHAR 256  // 路径最大字符数
#define MAXCNCHARWIDTH 25  // 最大中文字符宽度 扫描范围用
#define MAXYLIST 1000    // 最大Y坐标数
#define MAXJOBLIST 3000  // 最大job数
#define MAXOUTBUFCOUNT 256  // 输出 hImage 数量


// 全局声明，定义
	typedef struct TextPos {  // 记录信息行
		unsigned pos;
		unsigned len;
	} POSLIST;

	typedef struct LineBorder {  // 信息行左右坐标
		unsigned left;
		unsigned right;
	} LineLR;

	typedef struct FoxJob { // 任务列表
		unsigned action;  // 0: 默认 1:先创建新图片 2:后保存图片
		unsigned left;
		unsigned top;
		unsigned right;
		unsigned bottom;
		unsigned newleft;
		unsigned newtop;
	} JOBLIST;

// 全局函数声明
	FIBITMAP * gifcat(char gifpath[MAXGIFCOUNT][MAXPATHCHAR], unsigned gifPathCount) ; // 将多张图片连接为一张图片
	FIBITMAP * CreateTemplete(FIBITMAP * hImage, unsigned ScreenWidth, unsigned ScreenHeight) ; // 创建空白PNG模版

	unsigned GetAYLineInfoCount(unsigned NowX, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) ; // 获取一列象素的信息数
	unsigned GetLeftBorderX(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch)  ; // 扫描方向: 左->右, 获取开始X坐标
	unsigned GetRightBorderX(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) ; // 扫描方向: 右->左, 获取结束X坐标

	unsigned GetMinXToLeft(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) ; // 扫描方向: 点->左, 获取最少信息数点X坐标

	unsigned GetYList(POSLIST ylist[MAXYLIST] , BYTE * pBit , unsigned ImgPitch, unsigned ImgWidth, unsigned ImgHeight) ;  // 获取 Y 分割列表
	unsigned GetLineBorder(LineLR yinfo[MAXYLIST], POSLIST ylist[MAXYLIST], unsigned TextLineCount, BYTE * pBit , unsigned ImgPitch, unsigned ImgWidth, unsigned ImgHeight) ; // 每行左右坐标
	unsigned NewGetJobList(JOBLIST joblist[MAXJOBLIST], LineLR yinfo[MAXYLIST], POSLIST ylist[MAXYLIST], unsigned TextLineCount,unsigned ScreenWidth, unsigned ScreenHeight, unsigned ImgWidth, unsigned ImgHeight, BYTE * pBit, unsigned ImgPitch, unsigned bSaveToBuff) ; // 新版任务列表,只根据屏幕宽度取X坐标,不固定

	FOX_DLL unsigned gifsplit(char * pngprefix, char gifpath[MAXGIFCOUNT][MAXPATHCHAR], unsigned gifPathCount, unsigned ScreenWidth, unsigned ScreenHeight, unsigned bSaveToBuff, FIBITMAP * hImageList[MAXOUTBUFCOUNT]) ; // 1 base count



// 主程序开始

int main(int argc, char* argv[])
{
//	unsigned ScreenWidth = 530 , ScreenHeight = 665 ; // 2 : 700:PDF 665:Mobi
	unsigned ScreenWidth = 270 , ScreenHeight = 360 ; // 3

	FIBITMAP * hImageList[MAXOUTBUFCOUNT] ;  // 输出 himage 数组, 首元素包含数组长度
	
	// 文件名数量
	int FileCount = 0 ;  // 1 base
	char pathlist[MAXGIFCOUNT][MAXPATHCHAR] ; // [最多文件名数][路径最长字符数]

	char PNGPreFix[MAXPATHCHAR] = "Fox_" ; // 前缀变量
	int i = 0 ;

	if ( argc == 1 ) {
		printf("用法:  imgsplit.exe [[ -p pngsPreFix]|[ -w ScreenWidth]|[ -h ScreenHeight]] gifpathA [ gifpathB]\n\n感谢: 没谱的人\n基于: FreeImage\n作者: 爱尔兰之狐\nURL:  http://www.autohotkey.net/~linpinger/index.html\n\n");
		return 0;
	}

	for (i = 1; i < argc && argv[i][0] == '-'; i += 2) {
		switch(argv[i][1]) {
		    	case 'p':
				strcpy(PNGPreFix, argv[i+1]) ; // 复制到前缀变量
				break ;
	    		case 'w':
				sscanf(argv[i+1], "%d", &ScreenWidth);
				break ;
	    		case 'h':
				sscanf(argv[i+1], "%d", &ScreenHeight);
				break ;
			default:
				printf("imgsplit: 未知选项 %s\n", argv[i]) ;
		}
	}

	if ( i >= argc ) {
		printf("错误: 未输入待处理文件名\n") ;
		return 0 ;
	}

	for(i = i; i < argc; ++i ) {
		strcpy(pathlist[FileCount], argv[i]) ; // 复制到路径数组
		++FileCount ;
	}

	printf("---------------------------------\n") ;
	printf("参数:\n  PNG前缀: %s\n  切割宽度: %d\n  切割高度: %d\n", PNGPreFix, ScreenWidth, ScreenHeight);
	printf("待处理GIF列表，数量: %d\n" , FileCount);
	for(i=0; i < FileCount; ++i )
		printf("  %s\n", pathlist[i]) ;
	printf("---------------------------------\n") ;

//	开始转换
	FreeImage_Initialise() ; // 初始化
	gifsplit(PNGPreFix, pathlist, FileCount, ScreenWidth, ScreenHeight, 0 , hImageList);
	FreeImage_DeInitialise() ; // 结尾工作

	printf("\n   GIF分割完毕.\n");

	return 0;
}


FIBITMAP * CreateTemplete(FIBITMAP * hImage, unsigned ScreenWidth, unsigned ScreenHeight) // 创建空白PNG模版
{
	FIBITMAP * hPicTemplete;
	RGBQUAD * palMain ;
	RGBQUAD * palTemplete ;
	unsigned ImgPitchLocal ;
	BYTE * pBitLocal;
	unsigned x, y, n;

	hPicTemplete = FreeImage_Allocate(ScreenWidth, ScreenHeight, 8, 0, 0, 0);  //创建目标图像
	palMain = FreeImage_GetPalette(hImage);
	palTemplete = FreeImage_GetPalette(hPicTemplete);
	for (n = 0 ; n < 256 ; n++) {
		palTemplete[n].rgbRed = palMain[n].rgbRed ;
		palTemplete[n].rgbGreen = palMain[n].rgbGreen ;
		palTemplete[n].rgbBlue = palMain[n].rgbBlue ;
	}
	palTemplete[70].rgbRed = 255   ;
	palTemplete[70].rgbGreen = 255 ;
	palTemplete[70].rgbBlue = 255  ;
//	FreeImage_SetTransparent(hPicTemplete, false);
	// 所有像素颜色填充为 70 号索引
	ImgPitchLocal = FreeImage_GetPitch(hPicTemplete) ;
	pBitLocal = FreeImage_GetBits(hPicTemplete);
	for (y = 0 ; y < ScreenHeight; y++) {
		for (x = 0; x < ScreenWidth ; x++)
			pBitLocal[x] = 70 ;
		pBitLocal += ImgPitchLocal ; // 下一行
	}
	return hPicTemplete;
}


unsigned GetYList(POSLIST ylist[MAXYLIST] , BYTE * pBit , unsigned ImgPitch, unsigned ImgWidth, unsigned ImgHeight)  // 获取 Y 分割列表
{
	unsigned TextLineCount = 0 ; // Y 切割份数
	BYTE * pBitLocal;

	unsigned x, y;
	bool bInfoLine;
	unsigned StartY = 0 , OldInfY = 0 , xTextHeight = 0;

	pBitLocal = pBit + ImgPitch * ( ImgHeight - 1 ) ;

	// Get Ylist
	for (y = 0 ; y < ImgHeight ; y++) {
		bInfoLine = false ;
		for (x = 0; x < ImgWidth ; x++) {
			if ( ( pBitLocal[x] < 240 ) && ( pBitLocal[x] != 70 ) ) {
				bInfoLine = true ;
				break ;
			}
		}
		pBitLocal -= ImgPitch ; // 下一行
		if ( ImgHeight == y + 1 ) // 定义最后一行为信息行，避免少算最后行的错误
			bInfoLine = true ;

		if ( bInfoLine ) {
			if ( y == OldInfY + 1 ) {
				OldInfY = y ;
			} else {
				xTextHeight = OldInfY - StartY ;
				if ( xTextHeight > 0 ) {
					ylist[TextLineCount].pos = StartY ;
					ylist[TextLineCount].len = xTextHeight ;
					++TextLineCount ;
				}
				StartY = y ;
				OldInfY = y ;
			}
		}
	}
	return TextLineCount ;
}

unsigned GetLineBorder(LineLR yinfo[MAXYLIST], POSLIST ylist[MAXYLIST], unsigned TextLineCount, BYTE * pBit , unsigned ImgPitch, unsigned ImgWidth, unsigned ImgHeight) // 每行左右坐标
{
	unsigned y, NowY, StartX, EndX, linelen ;
	if ( yinfo[0].left >= 0 ) {
		StartX = yinfo[0].left - 1 ;
		EndX = yinfo[0].right ;
	} else {
		StartX = 0 ;
		EndX = ImgWidth - 1 ;
	}
	linelen = EndX - StartX ;

	for (y = 0; y < TextLineCount; ++y ) {
		NowY = ImgHeight - ylist[y].pos - ylist[y].len ;
		yinfo[y].left = GetLeftBorderX(StartX, linelen, NowY, ylist[y].len, pBit, ImgPitch) ;
		yinfo[y].right = GetRightBorderX(EndX, linelen, NowY, ylist[y].len, pBit, ImgPitch) ;
//		printf("yLR: %d , L: %d , R: %d\n", y, yinfo[y].left, yinfo[y].right) ;
	}
	return StartX ;
}

FIBITMAP * gifcat(char gifpath[MAXGIFCOUNT][MAXPATHCHAR], unsigned gifPathCount) // 将多张图片连接为一张图片
{
	FIBITMAP * hImageAll ;
	unsigned ImgHeightAll = 0 ;
	FIBITMAP * hImage[MAXGIFCOUNT] ;
	unsigned ImgHeight[MAXGIFCOUNT] ;
	unsigned ImgWidth ;
	RGBQUAD * palSrc ;
	RGBQUAD * palAll ;
	unsigned n , NowYPos = 0 ;
//	---
	for ( n=0; n < gifPathCount; ++n) {
		hImage[n] = FreeImage_Load(FIF_GIF, gifpath[n], 0);
		ImgHeight[n] = FreeImage_GetHeight(hImage[n]) ;
		ImgHeightAll += ImgHeight[n] ;
	}
	ImgWidth = FreeImage_GetWidth(hImage[0]) ;

	hImageAll = FreeImage_Allocate(ImgWidth, ImgHeightAll, 8, 0, 0, 0);  //创建目标图像
	palAll = FreeImage_GetPalette(hImageAll);       // 复制调色板
	palSrc = FreeImage_GetPalette(hImage[0]);
	for (n = 0; n < 256; ++n) {
		palAll[n].rgbRed = palSrc[n].rgbRed ;
		palAll[n].rgbGreen = palSrc[n].rgbGreen ;
		palAll[n].rgbBlue = palSrc[n].rgbBlue ;
	}
	palAll[70].rgbRed = 255   ;
	palAll[70].rgbGreen = 255 ;
	palAll[70].rgbBlue = 255  ;

	for ( n=0; n < gifPathCount; ++n) {  // 粘贴图像
		FreeImage_Paste(hImageAll, hImage[n], 0, NowYPos, 300) ;
		NowYPos += ImgHeight[n] ;
		FreeImage_Unload(hImage[n]) ;
	}
	return hImageAll ;
}

unsigned GetAYLineInfoCount(unsigned NowX, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) // 获取一列象素的信息数 v1.1
{
	BYTE * pBitLocal ;
	unsigned count = 0 , n;
	pBitLocal = pBit + (ImgPitch * NowY) ;

	for (n = 0; n < YLineHeight ; ++n) {  // 循环YLineHeight次
		if ( ( pBitLocal[NowX] < 240 ) && ( pBitLocal[NowX] != 70 ) )
			++count ;
		pBitLocal += ImgPitch ;
	}
	return count ;
}

unsigned GetLeftBorderX(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) // 扫描方向: 左->右, 获取开始X坐标
{
	unsigned n;
	bool bIslastBlank = false ;

	for ( n=0 ; n<MaxWidth; ++n) {
		if ( 0 < GetAYLineInfoCount(NowX, NowY, YLineHeight, pBit, ImgPitch) ) { ; // 获取一列象素的信息数
			if ( bIslastBlank )
				return NowX ;
			else
				bIslastBlank = false ;
		} else 
			bIslastBlank = true ;
		++NowX ;
	}
	return NowX;
}

unsigned GetRightBorderX(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) // 扫描方向: 右->左, 获取结束X坐标
{
	unsigned n;
	bool bIslastBlank = false ;

	for ( n=0 ; n<MaxWidth; ++n) {
		if ( 0 < GetAYLineInfoCount(NowX, NowY, YLineHeight, pBit, ImgPitch) ) { ; // 获取一列象素的信息数
			if ( bIslastBlank )
				return NowX ;
			else
				bIslastBlank = false ;
		} else 
			bIslastBlank = true ;
		--NowX ;
	}
	return NowX;
}

unsigned GetMinXToLeft(unsigned NowX, unsigned MaxWidth, unsigned NowY, unsigned YLineHeight, BYTE * pBit, unsigned ImgPitch) // 扫描方向: 点->左, 获取最少信息数点X坐标
{
	unsigned n ;
	unsigned MinNum = 55555, MinX, NowNum;
	bool bIslastBlank = false ;

	MinX = NowX ;
	for ( n=0 ; n < MaxWidth; ++n) {
		NowNum = GetAYLineInfoCount(NowX, NowY, YLineHeight, pBit, ImgPitch) ; // 获取一列象素的信息数
		if ( NowNum < MinNum ) {
			MinNum = NowNum ;
			MinX = NowX ;
		}
		--NowX ;
	}
	return MinX;
}

// 独立函数，读取gif图片，写白背景，转为PNG并写入缓存，返回缓存地址
FOX_DLL FIMEMORY * gif2png_bufopen(char *gifpath, BYTE ** buffpointeraddr, DWORD * bufflenaddr)
{
	FIBITMAP * hImage ;
	RGBQUAD * pal ;
	FIMEMORY * hMemory = NULL ;
	BYTE *mem_buffer = NULL ;
	DWORD size_in_bytes = 0 ;

	hImage = FreeImage_Load(FIF_GIF, gifpath, 0);

	pal = FreeImage_GetPalette(hImage);
	pal[70].rgbRed = 255 ;
	pal[70].rgbGreen = 255 ;
	pal[70].rgbBlue = 255 ;
	FreeImage_SetTransparent(hImage, false);

	hMemory = FreeImage_OpenMemory() ;
	FreeImage_SaveToMemory(FIF_PNG, hImage, hMemory, PNG_DEFAULT) ;
	FreeImage_Unload(hImage) ;

	FreeImage_AcquireMemory(hMemory, &mem_buffer, &size_in_bytes);
	*buffpointeraddr = mem_buffer ;
	*bufflenaddr = size_in_bytes ;
	
	return hMemory ;
//	FreeImage_CloseMemory(hMemory) ; // 使用完缓存记得要释放
}

FOX_DLL int gif2png_bufclose(FIMEMORY * hMemory)
{
	FreeImage_CloseMemory(hMemory) ; // 使用完缓存记得要释放
	return 0 ;
}
/*
AHK L 调用方法:
	FreeImage_FoxInit(True) ; Load Dll
	VarSetCapacity(pBuffAddr, 4 0) , VarSetCapacity(pBuffLen, 4 0)
	hMemory := DllCall("FreeImage.dll\gif2png_bufopen", "Str", _StrToGBK(gifpath),"Uint", &pBuffAddr, "Uint", &pBuffLen, "Cdecl")
	BuffAddr := numget(&pBuffAddr+0, 0, "Uint") , BuffLen := numget(&pBuffLen+0, 0, "Uint")
	; 调用buf代码处，处理完后记得释放
	xx := DllCall("FreeImage.dll\gif2png_bufclose", "Uint", hMemory, "Cdecl")
	FreeImage_FoxInit(False) ; unLoad Dll
*/

FOX_DLL unsigned gifsplit(char * pngprefix, char gifpath[MAXGIFCOUNT][MAXPATHCHAR], unsigned gifPathCount, unsigned ScreenWidth, unsigned ScreenHeight, unsigned bSaveToBuff, FIBITMAP * hImageList[MAXOUTBUFCOUNT]) // 1 base count
{
//	------ 声明开始
//	FIBITMAP * hImageList[MAXOUTBUFCOUNT] ;  // 输出 himage 数组, 首元素包含数组长度
	FIBITMAP * hPicTemplete;
	FIBITMAP * hImage ;
	FIBITMAP * hPicBlank;
	BYTE * pBit ;
	unsigned ImgPitch, ImgWidth, ImgHeight ;

	char pathPNG[MAXPATHCHAR];
	unsigned n;

//	ylist
	unsigned xsplitcount = 0 ;   // X 切割份数
	POSLIST ylist[MAXYLIST] ;
	unsigned TextLineCount = 0 ; // Y 切割份数
	LineLR yinfo[MAXYLIST] ;
	unsigned StartX, EndX ;

//	joblist
	JOBLIST joblist[MAXJOBLIST]  ;
	unsigned NowJobCount ; // joblist item count

	unsigned nNewPicCount = 0 ;

//	------- 语句开始

	hImage = gifcat(gifpath, gifPathCount) ; // 将多张图片连接为一张图片
	hPicTemplete = CreateTemplete(hImage, ScreenWidth, ScreenHeight) ; // 创建空白PNG模版
	

		ImgWidth = FreeImage_GetWidth(hImage) ;
		ImgHeight = FreeImage_GetHeight(hImage) ;
		ImgPitch = FreeImage_GetPitch(hImage) ;
		pBit = FreeImage_GetBits(hImage) ;

		TextLineCount = GetYList(ylist , pBit , ImgPitch, ImgWidth, ImgHeight) ;  // 获取 Y 分割列表
		StartX = GetLeftBorderX(0, ImgWidth, 0, ImgHeight, pBit, ImgPitch) ;
		EndX = GetRightBorderX(ImgWidth - 1, ImgWidth, 0, ImgHeight, pBit, ImgPitch) ;
		yinfo[0].left = StartX ;
		yinfo[0].right = EndX ;
		GetLineBorder(yinfo, ylist, TextLineCount, pBit, ImgPitch, ImgWidth, ImgHeight) ; // 每行左右坐标
		yinfo[TextLineCount].left = StartX ;
		yinfo[TextLineCount].right = EndX ;

		NowJobCount = NewGetJobList(joblist, yinfo, ylist, TextLineCount, ScreenWidth, ScreenHeight, ImgWidth, ImgHeight, pBit, ImgPitch, bSaveToBuff) ; // 新版任务列表,只根据屏幕宽度取X坐标,不固定


	// 根据joblist 来生成 png
	for (n = 0; n < NowJobCount; n++) {
//		printf("任务编号: %d , A: %d , L: %d , R: %d , T: %d , B: %d , nL: %d , nT: %d, R-L: %d\n", n, joblist[n].action, joblist[n].left, joblist[n].right, joblist[n].top, joblist[n].bottom, joblist[n].newleft, joblist[n].newtop, joblist[n].right - joblist[n].left) ; // 调试用
		if ( ( joblist[n].action >= 1 ) && ( joblist[n].action != 5 ) )
			hPicBlank = FreeImage_Clone(hPicTemplete);

		FreeImage_Paste(hPicBlank, FreeImage_Copy(hImage, joblist[n].left, joblist[n].top, joblist[n].right, joblist[n].bottom), joblist[n].newleft, joblist[n].newtop, 300);

		if ( joblist[n].action >= 5 ) {
			++nNewPicCount ;
			sprintf(pathPNG, "%s%03d.png", pngprefix, nNewPicCount) ;
			printf("生成PNG %d : %s\n", nNewPicCount , pathPNG) ;

			if ( bSaveToBuff == 1 ) { // 输出到buff
				hImageList[nNewPicCount-1] = hPicBlank ;
			} else {  // 输出到文件
				FreeImage_Save(FIF_PNG, hPicBlank, pathPNG) ;
				FreeImage_Unload(hPicBlank) ;
			}
		}
	}
	return nNewPicCount;
}


unsigned NewGetJobList(JOBLIST joblist[MAXJOBLIST], LineLR yinfo[MAXYLIST], POSLIST ylist[MAXYLIST], unsigned TextLineCount,unsigned ScreenWidth, unsigned ScreenHeight, unsigned ImgWidth, unsigned ImgHeight, BYTE * pBit, unsigned ImgPitch, unsigned bSaveToBuff)  // 新版任务列表,只根据屏幕宽度取X坐标,不固定
{
	unsigned StartX, EndX ;  // 所有图片的左右边界X坐标
	unsigned i = 0 ; // joblist item count
	unsigned y = 0 ; // Ylist item count
	unsigned TrueRight, NowSegWidth ;
	unsigned nScreenWidth = 0 , nScreenHeight = 0 ;
	unsigned LineSpace = 5 ;  // 行间距

	if ( bSaveToBuff == 1 ) { // 当用来切割为K3需要的PDF时，第一张图片空出一段空白用做标题行，要求先draw图片，后show文字
		nScreenHeight = 30 ;
	}

	StartX = yinfo[TextLineCount].left ;
	EndX = yinfo[TextLineCount].right  ;

	for ( i=0; i < MAXJOBLIST; ++i )
		joblist[i].action = 0 ;

	i = 0 ;
	joblist[i].action = 1 ;
	joblist[i].left = StartX ;
	joblist[i].right = joblist[i].left + ScreenWidth ;
	joblist[i].top = ylist[y].pos ;
	joblist[i].bottom = ylist[y].pos + ylist[y].len ;
	joblist[i].newleft = 0 ;
	joblist[i].newtop = nScreenHeight ;

while ( true ) { // 无限循环生成joblist
	TrueRight = GetMinXToLeft(joblist[i].right, MAXCNCHARWIDTH, ImgHeight - ylist[y].pos - ylist[y].len, ylist[y].len, pBit, ImgPitch) ; // 实际大右坐标
	joblist[i].right = TrueRight ; // 当前任务右坐标
	NowSegWidth = joblist[i].right - joblist[i].left ; // 当前片段宽度
	nScreenWidth += NowSegWidth ;      // 当前小图已写宽度

	++i ;
	joblist[i].left = TrueRight ;
	joblist[i].right = TrueRight + ScreenWidth ;
	joblist[i].top = ylist[y].pos ;
	joblist[i].bottom = ylist[y].pos + ylist[y].len ;
	joblist[i].newleft = nScreenWidth ;
	joblist[i].newtop = nScreenHeight ;

	if ( joblist[i].right > yinfo[y].right )
		joblist[i].right = yinfo[y].right + 1 ;

	if ( ScreenWidth - nScreenWidth < MAXCNCHARWIDTH ) { // 下个任务 剩余 1 中文宽度 小换行
		nScreenWidth = 0 ;
		nScreenHeight += ylist[y].len + LineSpace ;
		joblist[i].newleft = 0 ;
		joblist[i].newtop = nScreenHeight ;
	} else { // 不小换行
		++y ;
		if ( y >= TextLineCount ) { // 大图片完了
			joblist[i-1].action += 5 ;
			break ;
		}
		if ( yinfo[y].left > StartX + MAXCNCHARWIDTH ) {  // 新段
			joblist[i].left = StartX ;

			nScreenWidth = 0 ;
			nScreenHeight += ylist[y].len + LineSpace ;
			joblist[i].newleft = 0 ;
			joblist[i].newtop = nScreenHeight ;
		} else
			joblist[i].left = yinfo[y].left ;

		joblist[i].right = joblist[i].left + ScreenWidth - nScreenWidth  ;
		if (joblist[i].right > yinfo[y].right)   // 当预定右边小于图片实际宽度时
			joblist[i].right = yinfo[y].right + 1 ;

		joblist[i].top = ylist[y].pos ;
		joblist[i].bottom = ylist[y].pos + ylist[y].len ;
	}
	if ( joblist[i].newtop + ylist[y].len > ScreenHeight) { // 换页
		joblist[i-1].action += 5 ;
		joblist[i].action = 1 ;
		nScreenHeight = 0 ;
		joblist[i].newtop = nScreenHeight ;
	}
}
	return i ;
}

