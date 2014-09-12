/*
C:\FoxEpubTemp:
mimetype
META-INF\container.xml
xxxx.opf
xxxx.ncx
xxxx.htm
html:
101.html
102.html
p23_1.png



; -----备注:
^esc::reload
+esc::Edit
!esc::ExitApp
F1::
	sTime := A_TickCount
	oMobi := new FoxEpub("偷天")
;	oMobi.SetCover("c:\cover.jpg") ; 设置封面
	oMobi.AddChapter("第1章", "<p>今天你蛋疼了吗</p>`n<p>呵呵</p>")
	oMobi.AddChapter("第2章", "<p>xx今天你蛋疼了吗</p>`n<p>xx呵呵</p>")
	oMobi.AddChapter("第3章", "<p>cc今天你蛋疼了吗</p>`n<p>cc呵呵</p>")
	oMobi.SaveTo("C:\etc\FoxTesting.mobi")
	
	eTime := A_TickCount - sTime
	TrayTip, 耗时:, %eTime% ms
return
*/
; 2013-5-7: mobigen生成的mobi格式在Kindle PaperWhite上，跳转目录显示为乱码，需使用kindlegen
Class FoxEpub {
	EpubMod := "epub" ; epub|mobi
;	TmpDir := ""

	BookUUID := ""
	BookName := "狐狸之书"
	BookCreator := "爱尔兰之狐"
	DefNameNoExt := "FoxMake"  ; 默认文件名
	ImageExt := "png"
	ImageMetaType := "image/png"
	CoverImgNameNoExt := "FoxCover"   ; 封面图片路径
	CoverImgExt := "png"

	Chapter := []     ; 章节结构:1:ID 2:Title
	ChapterCount := 0 ; 章节数
	ChapterID := 100  ; 章节ID

	__New(iBookName, TmpDir="C:\FoxEpubTemp") {
		This.BookUUID := General_UUID()
		This.BookName := iBookName

		; 创建临时目录结构
		ifexist, %Tmpdir%
			FileRemoveDir, %Tmpdir%, 1
		FileCreateDir, %Tmpdir%\html
		ifNotExist, %TmpDir%\html
			msgbox, Epub错误: 无法创建临时目录，C盘是否不可写呢？
		This.Tmpdir := Tmpdir
	}
	SetCover(ImgPath) { ; 设置封面图片
		SplitPath, ImgPath, OutFileName, OutDir, OutExt, OutNameNoExt, OutDrive
		This.CoverImgExt := OutExt
		IfExist, %ImgPath%
			filecopy, %ImgPath%, % This.Tmpdir . "\" . this.CoverImgNameNoExt . "." . OutExt, 1
	}
	AddChapter(Title="章节标题", Content="章节内容", iPageID="") {
		++This.ChapterCount
		if ( iPageID = "" ) {
			++This.ChapterID
			This.Chapter[This.ChapterCount,1] := This.ChapterID
		} else
			This.Chapter[This.ChapterCount,1] := iPageID
		This.Chapter[This.ChapterCount,2] := Title
		This._CreateChapterHTML(Title, Content, This.Chapter[This.ChapterCount,1]) ; 写入文件
	}
	SaveTo(EpubSavePath) {
		SplitPath, EpubSavePath, OutFileName, OutDir, OutExt, OutNameNoExt, OutDrive
		This.EpubMod := OutExt

		NowEpubMod := This.EpubMod
		NowTmpDir := This.Tmpdir

		NowOPFPre := NowTmpDir . "\" . This.DefNameNoExt
		NowOPFPath := NowOPFPre . ".opf"

		This._CreateIndexHTM()
		This._CreateNCX()
		This._CreateOPF()
		This._CreateEpubMiscFiles()

		if ( NowEpubMod = "mobi" ) {
sPathList =
(Ltrim Join`n
D:\bin\bin32\kindlegen.exe
C:\bin\bin32\kindlegen.exe
%A_scriptdir%\bin32\kindlegen.exe
%A_scriptdir%\kindlegen.exe
D:\bin\bin32\mobigen.exe
C:\bin\bin32\mobigen.exe
%A_scriptdir%\bin32\mobigen.exe
%A_scriptdir%\mobigen.exe
)
		loop, parse, sPathList, `n, `r
			IfExist, %A_loopfield%
				NowMobigenName := A_loopfield

			runwait, "%NowMobigenName%" "%NowOPFPath%", %NowTmpDir%, Hide
			filemove, %NowOPFPre%.mobi, %EpubSavePath%, 1
		}
		if ( NowEpubMod = "epub" ) {
sPathList =
(Ltrim Join`n
D:\bin\bin32\zip.exe
C:\bin\bin32\zip.exe
%A_scriptdir%\bin32\zip.exe
%A_scriptdir%\zip.exe
)
		loop, parse, sPathList, `n, `r
			IfExist, %A_loopfield%
				NowExeZip := A_loopfield

			envget, bWine, DISPLAY ; linux桌面下不为空，可能为 :0
			if ( bWine = "" )
				runwait, "%NowExeZip%" -0Xq "%EpubSavePath%" mimetype, %NowTmpDir%, hide
			runwait, "%NowExeZip%" -Xr9Dq "%EpubSavePath%" *, %NowTmpDir%, hide
			; EPUB 规范的 OEBPS Container Format 讨论了 EPUB 和 ZIP，最重要的几点是：档案中的第一个文件必须是 mimetype 文件。mimetype 文件不能被压缩。这样非 ZIP 工具就能从 EPUB 包的第 30 个字节开始读取原始字节，从而发现 mimetype。 ZIP 档案不能加密。EPUB 支持加密，但不是在 ZIP 文件这一层上。
		}
		FileGetSize, NowFileSize, %EpubSavePath%, K
		If ( NowFileSize > 0 )
			FileRemoveDir, %NowTmpDir%, 1
	}
	_CreateNCX() {  ; 生成NCX文件
		NowTmpDir := This.TmpDir . "\html"
		NowDefName := This.DefNameNoExt
		NCXPath := This.TmpDir . "\" . NowDefName . ".ncx"
		NowBookName := This.BookName
		NowUUID := This.BookUUID
		NowCreator := This.BookCreator
		
		DisOrder := 1  ; 初始 顺序, 根据下面的playOrder数据
		loop, % This.Chapter.MaxIndex()
			++ DisOrder
,			NCXList .= "`t<navPoint id=""" . This.Chapter[A_index,1] . """ playOrder=""" . DisOrder . """><navLabel><text>" . This.Chapter[A_index,2]
			. "</text></navLabel><content src=""html/" . This.Chapter[A_index,1] . ".html"" /></navPoint>`n"
		NCXXML =
		(join`n Ltrim
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
		<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="zh-cn">
		<head>
		<meta name="dtb:uid" content="%NowUUID%"/>
		<meta name="dtb:depth" content="1"/>
		<meta name="dtb:totalPageCount" content="0"/>
		<meta name="dtb:maxPageNumber" content="0"/>
		<meta name="dtb:generator" content="%NowCreator%"/>
		</head>
		<docTitle><text>%NowBookName%</text></docTitle>
		<docAuthor><text>%NowCreator%</text></docAuthor>
		<navMap>
			`t<navPoint id="toc" playOrder="1"><navLabel><text>目录:%NowBookName%</text></navLabel><content src="%NowDefName%.htm"/></navPoint>
			%NCXList%
		</navMap></ncx>
		)
		Fileappend, %NCXXML%, %NCXPath%, UTF-8
	}
	_CreateOPF() {  ; 生成OPF文件
		NowTmpDir := This.TmpDir . "\html"
		NowDefName := This.DefNameNoExt
		OPFPath := This.TmpDir . "\" . NowDefName . ".opf"
		NowBookName := This.BookName
		NowUUID := This.BookUUID
		NowEpubMod := This.EpubMod
		NowCreator := This.BookCreator
		
		; 封面图片
		IfExist, % This.TmpDir . "\" .  This.CoverImgNameNoExt . "." . This.CoverImgExt
		{
			MetaImg := "<meta name=""cover"" content=""FoxCover"" />"
			If ( This.CoverImgExt = "jpg" or This.CoverImgExt = "jpeg" )
				ManiImg := "<item id=""FoxCover"" media-type=""image/jpeg"" href=""" . This.CoverImgNameNoExt . "." . This.CoverImgExt . """/>"
			If ( This.CoverImgExt = "png" )
				ManiImg := "<item id=""FoxCover"" media-type=""image/png"" href=""" . This.CoverImgNameNoExt . "." . This.CoverImgExt . """/>"
			If ( This.CoverImgExt = "gif" )
				ManiImg := "<item id=""FoxCover"" media-type=""image/gif"" href=""" . This.CoverImgNameNoExt . "." . This.CoverImgExt . """/>"
		}

		FirstPath := "html/" . This.Chapter[1,1] . ".html"
		loop, % This.Chapter.MaxIndex()
			NowHTMLMenifest .= "`t<item id=""page" . This.Chapter[A_index,1] . """ media-type=""application/xhtml+xml"" href=""html/" . This.Chapter[A_index,1] . ".html"" />`n"
,			NowHTMLSpine .= "`t<itemref idref=""page" . This.Chapter[A_index,1] . """ />`n"

		NowImgExt := This.ImageExt
		ImgID := 100
		loop, %NowTmpDir%\*.%NowImgExt%, 0, 0  ; 搜索图片
			++ImgID
,			NowImgMenifest .= "`t<item id=""img" . ImgID . """ media-type=""" . This.ImageMetaType . """ href=""html/" . A_LoopFileName . """ />`n"

		if ( NowEpubMod = "mobi" )
			AddXMetaData := "<x-metadata><output encoding=""utf-8""></output></x-metadata>"
		OPFXML =
		(Join`n Ltrim C
		<?xml version="1.0" encoding="utf-8"?>
		<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="FoxUUID">
		<metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
			`t<dc:title>%NowBookName%</dc:title>
			`t<dc:identifier opf:scheme="uuid" id="FoxUUID">%NowUUID%</dc:identifier>
			`t<dc:creator>%NowCreator%</dc:creator>
			`t<dc:publisher>%NowCreator%</dc:publisher>
;			`t<dc:contributor>爱尔兰之狐</dc:contributor>
;			`t<dc:description>爱尔兰之狐工具生成，暂时不考虑</dc:description>
			`t<dc:language>zh-cn</dc:language>
			`t%MetaImg%
			`t%AddXMetaData%
		</metadata>`n`n
		<manifest>
			`t<item id="FoxNCX" media-type="application/x-dtbncx+xml" href="%NowDefName%.ncx" />
			`t<item id="FoxIDX" media-type="application/xhtml+xml" href="%NowDefName%.htm" />
			`t%ManiImg%`n
			%NowHTMLMenifest%`n`n
			%NowImgMenifest%
		</manifest>`n`n
		<spine toc="FoxNCX">
			`t<itemref idref="FoxIDX"/>`n`n
			%NowHTMLSpine%
		</spine>`n`n
		<guide>
			`t<reference type="text" title="正文" href="%FirstPath%"/>
			`t<reference type="toc" title="目录" href="%NowDefName%.htm"/>
		</guide>`n`n</package>`n`n
		)
		Fileappend, %OPFXML%, %OPFPath%, UTF-8
	}
	_CreateEpubMiscFiles() { ;  生成 epub 必须文件 mimetype, container.xml
		TmpOPFFilePath := This.DefNameNoExt . ".opf"
		TmpDirLocal := This.Tmpdir
		epubcontainer =
		(join`n Ltrim
		<?xml version="1.0"?>
		<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
		`t<rootfiles>
		`t`t<rootfile full-path="%TmpOPFFilePath%" media-type="application/oebps-package+xml"/>
		`t</rootfiles>
		</container>
		)
		fileappend, application/epub+zip, %TmpDirLocal%\mimetype
		FileCreateDir, %TmpDirLocal%\META-INF
		Fileappend, %epubcontainer%, %TmpDirLocal%\META-INF\container.xml, UTF-8
	}
	_CreateChapterHTML(Title="章节标题", Content="章节内容", iPageID="") { ; 生成章节页面
		HTMLPath := This.TmpDir . "\html\" . iPageID . ".html"
		HTML =
		(Join`n Ltrim
		<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-CN">
		<head>
		`t<title>%Title%</title>
		`t<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		`t<style type="text/css">
		`t`th2,h3,h4{text-align:center;}
		`t`tp { text-indent: 2em; line-height: 0.5em; }
		`t</style>
		</head>`n<body>
		<h4>%Title%</h4>
		<div class="content">
		`n`n
		%Content%
		`n`n
		</div>`n</body>`n</html>`n
		)
		Fileappend, %HTML%, %HTMLPath%, UTF-8
	}
	_CreateIndexHTM() { ; 生成索引页
		HTMLPath := This.TmpDir . "\" . This.DefNameNoExt . ".htm"
		NowBookName := This.BookName
		loop, % This.Chapter.MaxIndex()
			NowTOC .= "<div><a href=""html/" . This.Chapter[A_index,1] . ".html"">" . This.Chapter[A_index,2] . "</a></div>`n"

		HTML =
		(Join`n Ltrim
		<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="zh-CN">
		<head>
		`t<title>%NowBookName%</title>
		`t<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
		`t<style type="text/css">h2,h3,h4{text-align:center;}</style>
		</head>`n<body>
		<h2>%NowBookName%</h2>
		<div class="toc">
		`n`n
		%NowTOC%
		`n`n
		</div>`n</body>`n</html>`n
		)
		Fileappend, %HTML%, %HTMLPath%, UTF-8
	}
}

