#noenv
VerDate := "2014-6-6"
#SingleInstance force

ArgA = %1%

bDeleteTmpFile := false

NowMod := "search" ; 根据这个判断当前所处模式以采取不同动作

if ( ArgA = "" ) {
	DefName = %clipboard%
	bAuto := false
} else {
	DefName = %ArgA%
	bAuto := true
}

Guiinit:
	Gui,Add,Edit,x10 y10 w260 h20 vBookName, %DefName%
	Gui,Add,Button,x280 y10 w100 h20 gBookSearch default, &Search
	Gui,Add,ListView,x10 y40 w960 h340 vFoxLV gClickLV, _id|Name|最新|章数|最新时间|Site
	Gui,Show, w980 h390 , 追书神器  %VerDate%
	if bAuto
		gosub, BookSearch
return

ClickLV:
	if ( A_GuiEvent = "DoubleClick" ) {
		if ( NowMod = "search" or NowMod = "search_chapterrel" ) {
			gosub, ChapterList
			return
		}
		if ( NowMod = "chapter_list" ) {
			gosub, ChapterContent
			return
		}
	}
	if ( A_GuiEvent = "R" ) {
		if ( NowMod = "search" ) {
			LV_GetText(NowID, LV_GetNext(0), 1)
			newURL := "http://api.zhuishushenqi.com/toc/" . NowID . "?view=chapters"
			IfWinExist, 编辑窗口 ahk_class AutoHotkeyGUI
				ControlSetText, Edit4, %newURL%, 编辑窗口 ahk_class AutoHotkeyGUI
		}
	}
return


ChapterContent:
	LV_GetText(NowURL, LV_GetNext(0), 2)

	StrChaURL := GeneralW_UTF8_UrlEncode(NowURL)
	runwait, wget -U "ZhuiShuShenQi/2.14" -O "c:\zs_chapter.json" "http://chapter.zhuishushenqi.com/chapter/%StrChaURL%", , Min
	fileread, json, *P65001 c:\zs_chapter.json
	if bDeleteTmpFile
		filedelete, c:\zs_chapter.json

	nowTitle := json(json, "chapter.title")
	nowBody := json(json, "chapter.body")
	StringReplace, nowBody, nowBody, \n, `n, A
	StringReplace, nowBody, nowBody, 　　, , A

	filedelete, C:\zs_chapter.txt
	fileappend, %nowTitle%`n`n%nowBody%`n, C:\zs_chapter.txt
	run, c:\bin\Vim\vim72\gvim.exe C:\zs_chapter.txt
return

ChapterList:
	NowMod := "chapter_list"
	LV_GetText(NowID, LV_GetNext(0), 1)

	runwait, wget -U "ZhuiShuShenQi/2.14" -O "c:\zs_chapter_list.json" "http://api.zhuishushenqi.com/toc/%NowID%?view=chapters", , Min
	fileread, json, *P65001 c:\zs_chapter_list.json
	if bDeleteTmpFile
		filedelete, c:\zs_chapter_list.json
		
	LV_Delete()
	loop, 20
		LV_DeleteCol(1)
	LV_InsertCol(1, 200, "Name")
	LV_InsertCol(2, 380, "URL")
	LV_InsertCol(3, 80, "unreadble")

	sTime := A_TickCount

	; { RE方法
	StringReplace, json,json, `r,,A
	StringReplace, json,json, `n,,A
	StringReplace, json,json, {,`n{,A
	StringReplace, json,json, },}`n,A
; { "title": "第一章 风吹鸡蛋壳", "link": "http://leduwo.com/book/47/47078/11350239.html", "unreadble": false },

	RE = i)"title": *"([^"]*)"[, ]*"link": *"([^"]*)"[, ]*"unreadble": ([a-z]*)
	loop, parse, json, `n, `r
	{
		xx_1 := "", xx_2 := "", xx_3 := ""
		regexmatch(A_LoopField, RE, xx_)
		if( xx_1 = "" )
			continue
		LV_Add(""
		, xx_1
		, xx_2
		, xx_3)
	}
	; }
	eTime := A_TickCount - sTime
;	TrayTip, 耗时:, %eTime% ms
	TrayTip, 提示:, 处理完毕`n耗时: %eTime% ms`n左双: 内容
return


BookSearch:
	GuiControlGet, BookName
	NowMod := "search"

	LV_Delete()
	loop, 20
		LV_DeleteCol(1)
	LV_InsertCol(1, 60, "_id")
	LV_InsertCol(2, 120, "Name")
	LV_InsertCol(3, 180, "最新")
	LV_InsertCol(4, 40, "章数")
	LV_InsertCol(5, 160, "最新时间")
	LV_InsertCol(6, 360, "Site")

;	获取总 bookid
	if ( BookName != PreBookName ) { ; 根据书名来缓存 总bookid
	StrURL := GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(BookName))
	runwait, wget -U "ZhuiShuShenQi/2.14" -O "c:\zs_search.json" "http://api.zhuishushenqi.com/book?view=search&query=%StrURL%", , Min
	fileread, json, *P65001 c:\zs_search.json
	if bDeleteTmpFile
		filedelete, c:\zs_search.json

	outBookName := json(json, "title")
	if ( BookName != outBookName )
		trayTip, 警告:, 搜索结果书名不符
	bookid := json(json, "_id")
	PreBookName := BookName
	clipboard = %bookid%
	TrayTip, 总BookID:, %bookid%

;	获取该书站点列表
	runwait, wget -U "ZhuiShuShenQi/2.14" -O "c:\zs_sitelist.json" "http://api.zhuishushenqi.com/toc?view=summary&book=%bookid%", , Min
	fileread, json_l, *P65001 c:\zs_sitelist.json
	if bDeleteTmpFile
		filedelete, c:\zs_sitelist.json

	json_l := "{""fox"":" . json_l . "}" ; 貌似不知道怎么解析默认的匿名数组
	}

	StringReplace, xksdf, json_l, "_id", , UseErrorLevel
	xksdf := ""
	count := ErrorLevel ; 条目数
	loop, %count% {
		nowPath := "fox[" . ( A_index - 1 ) . "]."
		if ( "" = json(json_l, nowPath . "_id") )
			continue
		lv_add(""
		, json(json_l, nowPath . "_id")
		, outBookName
		, json(json_l, nowPath . "lastChapter")
		, json(json_l, nowPath . "chaptersCount")
		, json(json_l, nowPath . "updated")
		, json(json_l, nowPath . "link"))
	}
	Guicontrol, Focus, FoxLV
	TrayTip, 提示:, 双左: 列表`n双右: URL到Edit
return

GuiClose:
GuiEscape:
	ExitApp
return

; -----备注:
^esc::reload
+esc::Edit
!esc::ExitApp
!1::CopyInfo2Clip(1)
!2::CopyInfo2Clip(2)
!3::CopyInfo2Clip(3)
!4::CopyInfo2Clip(4)
!5::CopyInfo2Clip(5)
!6::CopyInfo2Clip(6)
!7::CopyInfo2Clip(7)
!8::CopyInfo2Clip(8)
!9::CopyInfo2Clip(9)

CopyInfo2Clip(Num=1) {
	LV_GetText(NowVar, LV_GetNext(0), Num)
	Clipboard = %NowVar%
	TrayTip, 剪贴板:, %NowVar%
}


