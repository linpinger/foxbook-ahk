/*
; -----备注:
^esc::reload
+esc::Edit
!esc::ExitApp
F1::
	sTime := A_TickCount
	oCHM := New FoxCHM("偷天")
	oCHM.AddChapter("章节1", "今天天气不错啊<br>呵呵<br>")
	oCHM.AddChapter("章节2", "今天天气不好啊<br>嘿嘿<br>")
	oCHM.SaveTo("C:\xxxx.chm")
	eTime := A_TickCount - sTime
	TrayTip, 耗时:, %eTime% ms
return
*/

/*
; 文件结构
FoxBook.hhp
FoxIndex.hhc
FoxIndex.htm   ; 包含链接至 11.htm ...
11.htm
12.htm
*/
Class FoxCHM {
	PrevChapterURL := "" , NextChapterURL := "" , isLastChapter := 0 ; 外部设置
	bDelTmpFiles := 1 ; 编译完毕后，是否删除临时目录
	BookName := ""
	NameHHP := "FoxBook" , NameHHC := "FoxIndex" , NameIndexHTM := "FoxIndex"
	ChapterCount := 0 , Chapters := []  ; 1:PageID 2:PageName
	__New(BookName, TmpDir="C:\FoxCHMTmp") {
		This.BookName := BookName
		This.TmpDir := TmpDir

		; 创建临时目录
		IfNotExist, % This.TmpDir
			FileCreateDir, % This.TmpDir
	}
	SaveTo(BookSavePath="C:\FoxBook.chm") { ; CHM编译依赖程序: hhc.exe HHA.DLL
		TmpDir := This.TmpDir
		NameHHP := This.NameHHP
		This._SaveIndexHTM()
		This._SaveHHC()
		This._SaveHHP()
		RunWait, HHC.EXE "%TmpDir%\%NameHHP%.hhp", %A_scriptdir%\bin32, hide
		IfNotExist, %BookSavePath%
		{
			FileMove, %TmpDir%\%NameHHP%.chm, %BookSavePath%, 1
			IfExist, %BookSavePath%
				If This.bDelTmpFiles
					FileRemoveDir, %TmpDir%, 1
		} else
			TrayTip, 保存错误:, 移动CHM文件错误，保存为:`n%TmpDir%\%NameHHP%.chm
	}
	_SaveHHP() {
		BookName := This.BookName
		NameHHC := This.NameHHC
		NameIndexHTM := This.NameIndexHTM
;		Compiled file=%BookName%.chm
		HHP =
		(Join`n Ltrim
		[OPTIONS]
		Compatibility=1.1 or later
		Contents file=%NameHHC%.hhc
		Default Window=FoxWin
		Default topic=%NameIndexHTM%.htm
		Display compile progress=No
		Language=0x804 中文(中国)
		Title=《%BookName%》     爱尔兰之狐制作

		[WINDOWS]
		FoxWin=,"%NameHHC%.hhc",,,,,,,,0x42120,,0x0,[0,24,600,424],,,,,,,0

		[INFOTYPES]

		)
		FileAppend, %HHP%, % This.TmpDir . "\" . This.NameHHP . ".hhp", CP936
	}
	_SaveHHC() {
		HHCHead =
		(Join`n Ltrim
		<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">
		<HTML><HEAD>
		<meta name="GENERATOR" content="Microsoft&reg; HTML Help Workshop 4.1">
		<!-- Sitemap 1.0 -->
		</HEAD><BODY><UL>`n`n
		)
		HHCFoot := "`n</UL></BODY></HTML>`n`n"
		HHCBody := "`t<LI><OBJECT type=""text/sitemap""><param name=""Name"" value=""目录:" . This.BookName . """><param name=""Local"" value=""" . This.NameIndexHTM . ".htm""></OBJECT>`n"
		loop, % This.Chapters.maxindex()
			HHCBody .= "`t<LI><OBJECT type=""text/sitemap""><param name=""Name"" value=""" . This.Chapters[A_index,2] . """><param name=""Local"" value=""" . This.Chapters[A_index,1] . ".htm""></OBJECT>`n"
		FileAppend, %HHCHead%%HHCBody%%HHCFoot%, % This.TmpDir . "\" . This.NameHHC . ".hhc", CP936
	}
	_SaveIndexHTM() {
		BookName := This.BookName
		IndexHTMHead =
		(Join`n Ltrim
		<html><head>
		<meta http-equiv=Content-Type content="text/html; charset=GBK">
		<style type="text/css">h2,h3,h4{text-align:center;}</style>
		<title>%BookName%</title></head><body>
		<h2>%BookName%</h2>`n`n
		)
		IndexHTMFoot := "`n`n</body></html>`n`n"
		loop, % This.Chapters.maxindex()
			IndexHTMBody .= "`t<a href=""" . This.Chapters[A_index,1] . ".htm"">" . This.Chapters[A_index,2] . "</a><br>`n"
		FileAppend, %IndexHTMHead%%IndexHTMBody%%IndexHTMFoot%, % This.TmpDir . "\" . This.NameIndexHTM . ".htm", CP936
	}
	AddChapter(iTitle="章节名", iHTMLBody="<h2>哈哈</h2>今天天气很好<br>") {
		++This.ChapterCount
		if ( this.ChapterCount = 1 )
			PrevLink := "本章为首章"
		else
			PrevLink := "<a href=""" . (This.ChapterCount - 1) . ".htm"">上一章</a>"
		if ( this.isLastChapter = 1 )
			NextLink := "本章为尾章"
		else
			NextLink := "<a href=""" . (This.ChapterCount + 1) . ".htm"">下一章</a>"
		BannerHTML := PrevLink . " | <a href=""" . This.NameIndexHTM . ".htm"">目录</a> | " . NextLink . "<br>`n"

		This.Chapters[This.ChapterCount, 1] := This.ChapterCount
		This.Chapters[This.ChapterCount, 2] := iTitle
		HTMHead =
		(Join`n Ltrim
		<html><head>
		<meta http-equiv=Content-Type content="text/html; charset=GBK">
		<style type="text/css">h2,h3,h4{text-align:center;}</style>
		<title>%iTitle%</title></head><body>
		<h3>%iTitle%</h3>`n`n
		)
		HTMFoot := "`n`n</body></html>`n`n"
		FileAppend, %HTMHead%%BannerHTML%`n<br><br>`n%iHTMLBody%`n<br><br>`n%BannerHTML%`n<br><br>`n%HTMFoot%, % This.TmpDir . "\" . This.ChapterCount . ".htm", CP936
	}
}

