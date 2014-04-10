/*
#NoEnv
; -----备注:
^esc::reload
+esc::Edit
!esc::ExitApp
F1::
	NowDBPath := "D:\bin\SQlite\FoxBook\FoxBook.db3"
	NowPicDir := "D:\bin\SQlite\FoxBook\FoxPic"
	NowBookID := 5
	oDB := new SQLiteDB
	oDB.OpenDB(NowDBPath)
	oDB.GetTable("select Name,Content,CharCount from page where bookid = " . NowBookID, oTable)
	oDB.CloseDB()
	
	sTime := A_TickCount
	oPDF := new FoxPDF("偷天")

	ChapterCount := oTable.RowCount
	loop, %ChapterCount%
	{
		ToolTip, 生成 第 %A_index% / %ChapterCount% 章
		NowTitle := oTable.rows[A_index][1] , NowContent := oTable.rows[A_index][2]
		If ( oTable.rows[A_index][3] > 1000 ) {
			hFirstPage := oPDF.AddTxtChapter(NowContent, NowTitle)
		} else { ; 图片章节
			GIFPathArray := [] , GIFCount := 0
			loop, parse, NowContent, `n, `r
			{
				If ( A_loopfield = "" )
					continue
				FF_1 := ""
				regexmatch(A_loopfield, "Ui)^(.*\.gif)\|", FF_)
				If ( FF_1 = "" )
					continue
				NowGIFPath = %NowPicDir%\%NowBookID%\%FF_1%
				IfNotExist, %NowGIFPath%
					continue
				++GIFCount
				GIFPathArray[GIFCount] := NowGIFPath
			}
			hFirstPage := oPDF.AddPNGChapter(GIFPathArray, NowTitle) ; GIFPathArray 为 GIF文件路径 数组
		}
	}
	tooltip

	FileDelete, C:\xxx.pdf
	oPDF.SaveTo("C:\xxx.pdf")

	eTime := A_TickCount - sTime
	IfExist, C:\xxx.pdf
		TrayTip, 耗时:, %eTime% ms
	else
		TrayTip, 错误:, 未生成pdf文件
return
#include <SQLiteDB_Class>
*/

Class FoxPDF {
	ScreenWidth := 530 , ScreenHeight := 700  ; 切割图片页尺寸 K3:530*700  s5570:270*360
	TextPageWidth := 250 , TextPageHeight := 330 , TextTitleFontsize := 12 , BodyFontSize := 9.5 , BodyLineHeight := 12.5 , CalcedOnePageRowNum := 26 ; 26*26字 文本页尺寸 K3
	hDll := "" , hDoc := "" , hCNFont := "" , hENFont := "" , hPage := "" , nPageCount := 0
	BookName := "书名"
	isAddOutLine := 1 , isInsertIndexpage := 1 ; 选项，是否 添加左侧列表、插入目录页
	isInsertPageMod := 0 , hBeInsertPage := ""   ; 被插入页面句柄
		IndexItem := [] , IndexItemCount := 0  ; 目录页需要
	__New(BookName){
		This.BookName := BookName
		
sPathList =
(Ltrim Join`n
%A_scriptdir%\bin32\libhpdf.dll
%A_scriptdir%\libhpdf.dll
D:\bin\bin32\libhpdf.dll
C:\bin\bin32\libhpdf.dll
)
		loop, parse, sPathList, `n, `r
			IfExist, %A_loopfield%
				LibHaruDllPath := A_loopfield

sPathList =
(Ltrim Join`n
%A_WinDir%\Fonts\simhei.ttf
%A_scriptdir%\兰亭黑_GBK.TTF
%A_scriptdir%\lantinghei.ttf
D:\etc\Font\兰亭黑_GBK.TTF
D:\etc\Font\lantinghei.ttf
)
		loop, parse, sPathList, `n, `r
			IfExist, %A_loopfield%
				FoxFontPath := A_loopfield

		this.hDll := HPDF_LoadDLL(LibHaruDllPath)
		this.hDoc := HPDF_New(0,0)
	
		HPDF_SetCompressionMode(This.hDoc, "ALL")
		HPDF_SetInfoAttr(This.hDoc, "AUTHOR", GeneralW_StrToGBK("Linpinger"))

		HPDF_UseCNSEncodings(This.hDoc)
		NowFontName := HPDF_LoadTTFontFromFile(This.hDoc, GeneralW_StrToGBK(FoxFontPath), 1)
		This.hCNFont := HPDF_GetFont2(This.hDoc, NowFontName, GeneralW_StrToGBK("GBK-EUC-H"))
		This.hENFont := HPDF_GetFont2(This.hDoc, NowFontName, GeneralW_StrToGBK("WinAnsiEncoding"))
	}
	SaveTo(PDFSavePath="C:\fox.pdf"){
		If This.isInsertIndexpage
			This.InsertIndexPage()
		HPDF_SaveToFile(This.hDoc, GeneralW_StrToGBK(PDFSavePath))
		HPDF_Free(This.hDoc)
		HPDF_UnloadDLL(This.hDll)
	}
	AddGIFChapterAndSplit(GIFPathArray, Title="") { ; GIFPathArray 为 GIF文件路径 数组 , 切割图片，写入缓存，然后生成PDF
		If This.isInsertIndexpage
			This.AddIndexRow("图", Title)

		FreeImage_FoxInit(True) ; Load Dll
		; {--调用gifsplit函数，合并GIF并切割为多图片，将句柄保存到数组中
		VarSetCapacity(hImageArray, 1024, 0)
		gifPathCount := GifpathArray.MaxIndex()
		VarSetCapacity(gifpathlist, 2560, 0)
		loop, %gifPathCount%
			StrPut(GifpathArray[A_index], (&gifpathlist)+256*(A_Index-1), "CP936")

		hImageCount := dllcall("FreeImage.dll\gifsplit"
		, "AStr", "Write2Buf"
		, "Uint", &gifpathlist
		, "short", gifPathCount
		, "short", This.ScreenWidth
		, "short", This.ScreenHeight
		, "Uint", 1
		, "Uint", &hImageArray
		, "Cdecl int")
		; }--

		; {-- 多切割后图片，转换到缓存中
		hImageAHKArray := []
		loop, %hImageCount% {
			hFImage := NumGet(&hImageArray+0, (A_index-1)*4, "Uint")
			hMemory := FreeImage_OpenMemory(0, 0)
			FreeImage_SaveToMemory(13, hFImage, hMemory, 0) ; 转换到PNG, 并写入内存
			FreeImage_AcquireMemory(hMemory, BufAdr, BufSize)

			hImageAHKArray[A_index] := HPDF_LoadPngImageFromMem(This.hDoc, BufAdr, BufSize)
			FreeImage_UnLoad(hFImage) ; Unload Image 释放句柄
			FreeImage_CloseMemory(hMemory)
		}
		; }--
		FreeImage_FoxInit(False) ; unLoad Dll

		; {-- AHK多图片处理
		iW := HPDF_Image_GetWidth(hImageAHKArray[1]) * 0.75
		iH := HPDF_Image_GetHeight(hImageAHKArray[1]) * 0.75
		nTitleFontSize := 16.5
		nPage := hImageAHKArray.MaxIndex()
		loop, %nPage% {
			++This.nPageCount
			If ( This.isInsertPageMod )
				This.hPage := HPDF_InsertPage(This.hDoc, This.hBeInsertPage)
			else
				This.hPage := HPDF_AddPage(This.hDoc)
			If ( This.isInsertIndexpage = 1 and This.nPageCount = 1 )  ; PDF第一页为被插入页
				This.hBeInsertPage := This.hPage
			HPDF_Page_SetWidth(This.hPage, iW)
			HPDF_Page_SetHeight(This.hPage, iH)
			AA := HPDF_Page_DrawImage(This.hPage, hImageAHKArray[A_index], 0, 0, iW, iH)
			If ( A_index = 1 ) {
				hFirstPage := This.hPage
				If ( Title != "" )
					This._ShowTitle(This.hPage, Title, nTitleFontSize)
			}
		}
		; }-- 

		If This.isAddOutLine
			This.AddOutLine(hFirstPage, Title)
		return, hFirstPage
	}
	AddPNGChapter(GIFPathArray, Title="") { ; GIFPathArray 为 GIF文件路径 数组
		If This.isInsertIndexpage
			This.AddIndexRow("图", Title)
		loop, % GIFPathArray.MaxIndex()
		{
			NowGIFPath := GIFPathArray[A_index]
;			SplitPath, NowGIFPath, OutFileName, OutDir, OutExt, OutNameNoExt, OutDrive

	FreeImage_FoxInit(True) ; Load Dll
;	
	hFImage := FreeImage_Load(GeneralW_StrToGBK(NowGIFPath)) ; load image 载入图像
	FreeImage_FoxPalleteIndex70White(hFImage) ; Fox:将索引透明Gif调色板颜色替换为白色
	FreeImage_SetTransparent(hFImage, 0)

	hMemory := FreeImage_OpenMemory(0, 0)
	FreeImage_SaveToMemory(13, hFImage, hMemory, 0) ; 转换到PNG, 并写入内存
	FreeImage_AcquireMemory(hMemory, BufAdr, BufSize)
	FreeImage_UnLoad(hFImage) ; Unload Image 释放句柄
	
	hImage := HPDF_LoadPngImageFromMem(This.hDoc, BufAdr, BufSize)
	FreeImage_CloseMemory(hMemory)
/*
	VarSetCapacity(pBuffAddr, 4 0) , VarSetCapacity(pBuffLen, 4 0)
	hMemory := DllCall("FreeImage.dll\gif2png_bufopen", "Str", GeneralW_StrToGBK(NowGIFPath), "Uint", &pBuffAddr, "Uint", &pBuffLen, "Cdecl")
	BuffAddr := numget(&pBuffAddr+0, 0, "Uint") , BuffLen := numget(&pBuffLen+0, 0, "Uint")
	hImage := HPDF_LoadPngImageFromMem(This.hDoc, BuffAddr, BuffLen)
	DllCall("FreeImage.dll\gif2png_bufclose", "Uint", hMemory, "Cdecl")
*/
	FreeImage_FoxInit(False) ; unLoad Dll

			If ( A_index = 1 )
				hFirstPage := This._ShowPNGNextPage(hImage, Title)
			else
				This._ShowPNGNextPage(hImage, "")
		}
		If This.isAddOutLine
			This.AddOutLine(hFirstPage, Title)
		return, hFirstPage
	}
	_ShowPNGNextPage(hImage, Title="") {
		iW := HPDF_Image_GetWidth(hImage) * 0.75
		iH := HPDF_Image_GetHeight(hImage) * 0.75

		nTitleHeight := 30 , nTitleFontSize := 20
		iSpace := 20 * 0.75 , iK3GifMax := 4650 * 0.75 ; 宽度分类处理 If ( ImgWidth = 700 ) ThePoint := 4650 else ThePoint := 4500
		nPage := Ceil(iH / (iK3GifMax - nTitleHeight - iSpace)) ; 页数
		iMain := iH / nPage

		loop, %nPage% {
			++This.nPageCount
			If ( This.isInsertPageMod )
				This.hPage := HPDF_InsertPage(This.hDoc, This.hBeInsertPage)
			else
				This.hPage := HPDF_AddPage(This.hDoc)
			If ( This.isInsertIndexpage = 1 and This.nPageCount = 1 )  ; PDF第一页为被插入页
				This.hBeInsertPage := This.hPage
			HPDF_Page_SetWidth(This.hPage, iW)
			If ( A_index = 1 ) {
				hFirstPage := This.hPage
				If ( ( iMain * A_index + iSpace ) > iH )
					AddSpace := 0
				else
					AddSpace := iSpace
				If ( Title = "" )
					nTitleHeight := 0
				iFirst := iMain + AddSpace + nTitleHeight
				HPDF_Page_SetHeight(This.hPage, iFirst)
				If ( Title != "" )
					This._ShowTitle(This.hPage, Title, nTitleFontSize)
				AA := HPDF_Page_DrawImage(This.hPage, hImage, 0, iMain+AddSpace-iH, iW, iH)
			} else {
				If ( ( iMain * A_index + iSpace ) > iH )
					AddSpace := 0
				else
					AddSpace := iSpace
				HPDF_Page_SetHeight(This.hPage, iMain + AddSpace)
				AA := HPDF_Page_DrawImage(This.hPage, hImage, 0, iMain*A_index+AddSpace-iH, iW, iH)
			}
		}
		return, hFirstPage
	}
	AddOutLine(hFirstPage, OutLineText="名称", hOutLineRoot=0)
	{	; 添加左侧索引栏
		NowEncoder := HPDF_GetEncoder(This.hDoc, GeneralW_StrToGBK("GBK-EUC-H"))
		hOutLine := HPDF_CreateOutline(This.hDoc, hOutLineRoot, GeneralW_StrToGBK(OutLineText), NowEncoder)
		hDest := HPDF_Page_CreateDestination(hFirstPage)
		HPDF_Outline_SetDestination(hOutLine, hDest)
	}
	AddTxtChapter(Content="", Title="") {
		If This.isInsertIndexpage
			This.AddIndexRow("文", Title)
		While ( Content != "" ) {
			If ( A_index = 1 )
				NowTitle := Title
			else
				NowTitle := ""
			nPageWriteChar := This._ShowTextNextPage(Content, NowTitle)
			StringTrimLeft, Content, Content, nPageWriteChar
			If ( A_index = 1 )
				hFirstPage := This.hPage
		}
		If This.isAddOutLine
			This.AddOutLine(hFirstPage, Title)
		return, hFirstPage
	}
	_ShowTextNextPage(Content="", Title="") {
		
		nPageWriteChar := 0
		++This.nPageCount
		If ( This.isInsertPageMod )
			This.hPage := HPDF_InsertPage(This.hDoc, This.hBeInsertPage)
		else
			This.hPage := HPDF_AddPage(This.hDoc)
		If ( This.isInsertIndexpage = 1 and This.nPageCount = 1 )  ; PDF第一页为被插入页
			This.hBeInsertPage := This.hPage

		HPDF_Page_SetWidth(This.hPage, This.TextPageWidth)
		HPDF_Page_SetHeight(This.hPage, This.TextPageHeight)

		If ( Title != "" ) { ; 有标题时, 先输出标题，并移动位置
			This._ShowTitle(This.hPage, Title, This.TextTitleFontsize)
			nLeftLine := Floor(( This.TextPageHeight - This.TextTitleFontsize ) / This.BodyLineHeight)
			StartYPos := This.TextPageHeight - This.TextTitleFontsize
		} else { ; 无标题，直接移动位置到头部
			nLeftLine := Floor(This.TextPageHeight / This.BodyLineHeight)
			StartYPos := This.TextPageHeight
		}
		HPDF_Page_BeginText(This.hPage) ; 开始输出
		HPDF_Page_MoveTextPos(This.hPage, 0, StartYPos)
		loop, %nLeftLine% { ; 显示正文
			nLineWriteChar := This._ShowTextNextLine(This.hPage, Content, This.BodyFontSize, This.BodyLineHeight)
			nPageWriteChar += nLineWriteChar
			StringTrimLeft, Content, Content, nLineWriteChar
			If ( Content = "" )
				break
		}
		HPDF_Page_EndText(This.hPage) ; 结束输出
		return, nPageWriteChar
	}
	_ShowTitle(hPage, Title="爱尔兰之狐的标题", NowTitleFontsize=20) {
		PageWidth := HPDF_Page_GetWidth(hPage) , PageHeight := HPDF_Page_GetHeight(hPage)
		nTitleEnChar := 0
		loop, parse, Title
		{
			If ( Asc(A_loopfield) > 255 ) ; 中文字符
				nTitleEnChar += 2
			else
				++nTitleEnChar
		}
		xTitlePos := PageWidth / 2 - nTitleEnChar * NowTitleFontsize / 4
		If ( xTitlePos <= 0 )
			xTitlePos := 0
		HPDF_Page_BeginText(hPage) ; 开始输出
		HPDF_Page_MoveTextPos(hPage, xTitlePos, PageHeight)
		This._ShowTextNextLine(hPage, Title, NowTitleFontsize, NowTitleFontsize)
		HPDF_Page_EndText(hPage) ; 结束输出
	}
	_ShowTextNextLine(hPage, inText="", inFontSize=9.5, inLineHeight=12.5) {
		PageWidth := HPDF_Page_GetWidth(hPage) ; , PageHeight := HPDF_Page_GetHeight(hPage)
		BodyLineMaxEnChar := PageWidth / inFontSize * 2
		HPDF_Page_MoveTextPos(hPage, 0, -inLineHeight)
		nCharCount := 0 , nShowEnChar := 0
		loop, parse, inText
		{
			If ( nShowEnChar + 2 > BodyLineMaxEnChar )
				break
			NowASC := Asc(A_loopfield)
			++nCharCount
			If ( NowAsc > 255 ) { ; 中文字符
				nShowEnChar += 2
				HPDF_Page_SetFontAndSize(hPage, This.hCNFont, inFontSize)
				HPDF_Page_ShowText(hPage, GeneralW_StrToGBK(A_loopfield))
			} else { ; 英文字符
				If ( NowASC = 13 )
					continue
				If ( NowASC = 10 )
					break
				++nShowEnChar
				HPDF_Page_SetFontAndSize(hPage, This.hENFont, inFontSize)
				HPDF_Page_ShowText(hPage, GeneralW_StrToGBK(A_loopfield))
			}
		}
		return, nCharCount
	}
	AddIndexRow(ChapterType="图", ChapterTitle="我是章节名"){ ; 添加目录页内容条目
		++This.IndexItemCount
		This.IndexItem[This.IndexItemCount,1] := ChapterType
		This.IndexItem[This.IndexItemCount,2] := This.nPageCount + 1
		This.IndexItem[This.IndexItemCount,3] := ChapterTitle
	}
	InsertIndexPage() {
		IndexContentRowNum := This.IndexItem.MaxIndex() ; 目录页内容条数
		IndexPageNum := Ceil(( IndexContentRowNum + 1 ) / This.CalcedOnePageRowNum)  ; 目录页页数
		Content := ""
		loop, %IndexContentRowNum% {  ; 生成页内容
			NowPageNum := This.IndexItem[A_index,2] + IndexPageNum
			NowNumText := "    " . NowPageNum
			StringRight, NowNumText, NowNumText, 4  ; 格式化页数
			NowTitle := This.IndexItem[A_index,3]
			StringLeft, NowTitle, NowTitle, 22  ; 格式化标题
			Content .= This.IndexItem[A_index,1] . NowNumText . "　" . NowTitle . "`n"
		}

		IndexStartNum := This.nPageCount
		This.isInsertPageMod := 1
		This.AddTxtChapter(Content, This.BookName . "★目录★")
		This.isInsertPageMod := 0
		TheTruePageNum := This.nPageCount - IndexStartNum
		If ( TheTruePageNum != IndexPageNum )
			TrayTip, 错误:, % This.BookName . "`n目录页数与预估页数不对`n可能造成目录中页数不正常"
	}
}

/*
Gif2Png(SrcPath="C:\xxx.gif", TarPath="C:\xxx.png", Mode="gif2png")
{
	If ( Mode = "gif2png" ) {
		runwait, gif2png.exe -b FFFFFF %SrcPath%, %A_scriptdir%, Hide
		SplitPath, SrcPath, OutFileName, OutDir, OutExt, OutNameNoExt, OutDrive
		IfExist, %OutDir%\%OutNameNoExt%.png            ; 对于某些GIF它处理不了，会出错，虽然可以加入-r参数修复，不过效果不好
			return, OutDir . "\" . OutNameNoExt . ".png"
		else {
			Mode := "FreeImage"
		}
	}
	If ( Mode = "FreeImage" ) {
		FreeImage_FoxInit(True) ; Load Dll
		hImage := FreeImage_Load(GeneralW_StrToGBK(SrcPath)) ; load image 载入图像
		FreeImage_FoxPalleteIndex70White(hImage) ; Fox:将索引透明Gif调色板颜色替换为白色
		FreeImage_SetTransparent(hImage, 0)
		FreeImage_Save(hImage, GeneralW_StrToGBK(TarPath), "PNG") ; Save Image 写入图像
		FreeImage_UnLoad(hImage) ; Unload Image 释放句柄
		FreeImage_FoxInit(False) ; Unload Dll
		return, TarPath
	}
}
*/
