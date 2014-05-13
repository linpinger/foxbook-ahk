#noenv
VerDate := "2014-5-11"
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
	Gui,Add,Button,x280 y10 w100 h20 gEasouSearch default, &Search
	Gui,Add,ListView,x10 y40 w960 h340 vFoxLV gClickLV, gid|nid|Name|Author|最新|章数|订数|Site|描述
	Gui,Show, w980 h390 , easou  %VerDate%
	if bAuto
		gosub, EasouSearch
return

ClickLV:
	if ( A_GuiEvent = "DoubleClick" ) {
		if ( NowMod = "search" or NowMod = "search_chapterrel" ) {
			gosub, EasouChapterList
			return
		}
		if ( NowMod = "chapter_list" ) {
			gosub, EasouBatch_chapter
			return
		}
	}
	if ( A_GuiEvent = "R" ) {
		if ( NowMod = "search" ) {
			LV_GetText(NowGID, LV_GetNext(0), 1)
			LV_GetText(NowNID, LV_GetNext(0), 2)
			newURL := "http://book.easou.com/ta/listAjax.m?gid=" . NowGID . "&nid=" . nowNID
			IfWinExist, 编辑窗口 ahk_class AutoHotkeyGUI
				ControlSetText, Edit4, %newURL%, 编辑窗口 ahk_class AutoHotkeyGUI
		}
		if ( NowMod = "chapter_list" ) {
			gosub, EasouSearch_chapterrel
			return
		}
	}
return

EasouSearch_chapterrel: ; 换源
	LV_GetText(NowGID, LV_GetNext(0), 1)
	LV_GetText(NowNID, LV_GetNext(0), 2)
	LV_GetText(NowChaName, LV_GetNext(0), 5)

	GuiControlGet, BookName
	NowMod := "search_chapterrel"

	LV_Delete()
	loop, 20
		LV_DeleteCol(1)
	LV_InsertCol(1, 60, "gid")
	LV_InsertCol(2, 60, "nid")
	LV_InsertCol(3, 110, "Name")
	LV_InsertCol(4, 40, "Type")
	LV_InsertCol(5, 250, "最新")
	LV_InsertCol(6, 40, "章数")
	LV_InsertCol(7, 40, "sort")
	LV_InsertCol(8, 190, "URL")
	LV_InsertCol(9, 90, "最新时间")

	StrChaName := UrlEncodeFox(GeneralW_StrToUTF8(NowChaName))
	runwait, wget -O "c:\es_search_chapterrel.json" "http://api.easou.com/api/bookapp/search_chapterrel.m?gid=%NowGID%&nid=%NowNID%&chapter_name=%StrChaName%&cid=eef_easou_book", , Min
	fileread, json, *P65001 c:\es_search_chapterrel.json
	if bDeleteTmpFile
		filedelete, c:\es_search_chapterrel.json

	count := json(json, "total") ; 条目数
	loop, %count% {
		nowPath := "items[" . ( A_index - 1 ) . "]."
		if ( "" = json(json, nowPath . "gid") )
			continue
		lv_add(""
		, json(json, nowPath . "gid")
		, json(json, nowPath . "nid")
		, json(json, nowPath . "chapter_name")
		, json(json, nowPath . "ctype")
		, json(json, nowPath . "last_chapter_name")
		, json(json, nowPath . "last_sort")
		, json(json, nowPath . "sort")
		, json(json, nowPath . "curl")
		, json(json, nowPath . "last_time"))
	}
return

EasouBatch_chapter:
	LV_GetText(NowGID, LV_GetNext(0), 1)
	LV_GetText(NowNID, LV_GetNext(0), 2)
	LV_GetText(NowSort, LV_GetNext(0), 3)
	LV_GetText(NowChaName, LV_GetNext(0), 5)

	StrChaName := UrlEncodeFox(GeneralW_StrToUTF8(NowChaName))
	runwait, wget -O "c:\es_batch_chapter.json" "http://api.easou.com/api/bookapp/batch_chapter.m?a=1&cid=eef_easou_book&gid=%NowGID%&nid=%NowNID%&sort=%NowSort%&gsort=0&sequence=0&chapter_name=%StrChaName%", , Min
	fileread, json, *P65001 c:\es_batch_chapter.json
	if bDeleteTmpFile
		filedelete, c:\es_batch_chapter.json

	nowBodyName := json(json, "items[0].chapter_name")
	nowBody := json(json, "items[0].content")
	StringReplace, nowBody, nowBody, \n, `n, A
	StringReplace, nowBody, nowBody, 　　, , A

	filedelete, C:\es_batch_chapter.txt
	fileappend, %nowBodyName%`n`n%nowBody%`n, C:\es_batch_chapter.txt
	run, c:\bin\Vim\vim72\gvim.exe C:\es_batch_chapter.txt
return

EasouChapterList:
	NowMod := "chapter_list"
	LV_GetText(NowGID, LV_GetNext(0), 1)
	LV_GetText(NowNID, LV_GetNext(0), 2)
	LV_GetText(NowCount, LV_GetNext(0), 6)

	LV_Delete()
	loop, 20
		LV_DeleteCol(1)
	LV_InsertCol(1, 60, "gid")
	LV_InsertCol(2, 60, "nid")
	LV_InsertCol(3, 60, "Sort")
	LV_InsertCol(4, 40, "Type")
	LV_InsertCol(5, 200, "Name")
	LV_InsertCol(6, 380, "URL")

	runwait, wget -O "c:\es_chapter_list.json" "http://api.easou.com/api/bookapp/chapter_list.m?gid=%NowGID%&nid=%NowNID%&page_id=1&size=2147483647&cid=eef_easou_book", , Min
	fileread, json, *P65001 c:\es_chapter_list.json
	if bDeleteTmpFile
		filedelete, c:\es_chapter_list.json
		
	sTime := A_TickCount

	; { Json处理
	/*
	loop, %NowCount% {
		nowPath := "items[" . ( A_index - 1 ) . "]."
		lv_add(""
		, NowGID
		, NowNID
		, json(json, nowPath . "sort")
		, json(json, nowPath . "ctype")
		, json(json, nowPath . "chapter_name")
		, json(json, nowPath . "curl"))
	}
	*/
	; }
	; { RE方法
	StringReplace, json,json, `r,,A
	StringReplace, json,json, `n,,A
	StringReplace, json,json, {,`n{,A
	StringReplace, json,json, },}`n,A
	RE = i)"sort":([0-9]*),"site":"[^"]*","nid":[0-9]*,"gsort":[0-9]*,"ctype":"([^"]*)","chapter_name":"([^"]*)","curl":"([^"]*)"
	loop, parse, json, `n, `r
	{
		if ! instr(A_loopfield, """nid""")
			continue
		xx_1 := "", xx_2 := "", xx_3 := "", xx_4 := ""
		regexmatch(A_LoopField, RE, xx_)
		if ( "" = xx_1 )
			continue
		LV_Add(""
		, NowGID
		, NowNID
		, xx_1
		, xx_2
		, xx_3
		, xx_4)
	}
	; }
	eTime := A_TickCount - sTime
;	TrayTip, 耗时:, %eTime% ms
	TrayTip, 提示:, 处理完毕`n耗时: %eTime% ms`n左双: 内容`n右双: 换源
return


EasouSearch:
	GuiControlGet, BookName
	NowMod := "search"

	LV_Delete()
	loop, 20
		LV_DeleteCol(1)
	LV_InsertCol(1, 60, "gid")
	LV_InsertCol(2, 60, "nid")
	LV_InsertCol(3, 110, "Name")
	LV_InsertCol(4, 70, "Author")
	LV_InsertCol(5, 180, "最新")
	LV_InsertCol(6, 40, "章数")
	LV_InsertCol(7, 50, "订数")
	LV_InsertCol(8, 90, "Site")
	LV_InsertCol(9, 290, "描述")

	StrURL := UrlEncodeFox(GeneralW_StrToUTF8(BookName))
	runwait, wget -O "c:\es_search.json" "http://api.easou.com/api/bookapp/search.m?word=%StrURL%&type=0&page_id=1&count=20&sort_type=0&cid=eef_easou_book", , Min
	fileread, json, *P65001 c:\es_search.json
	if bDeleteTmpFile
		filedelete, c:\es_search.json

	count := json(json, "total") ; 条目数
	loop, %count% {
		nowPath := "items[" . ( A_index - 1 ) . "]."
		if ( "" = json(json, nowPath . "gid") )
			continue
		lv_add(""
		, json(json, nowPath . "gid")
		, json(json, nowPath . "nid")
		, json(json, nowPath . "name")
		, json(json, nowPath . "author")
		, json(json, nowPath . "lastChapterName")
		, json(json, nowPath . "chapterCount")
		, json(json, nowPath . "subscribeCount")
		, json(json, nowPath . "site")
		, json(json, nowPath . "desc"))
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

UrlEncodeFox(UTF8String)
{
   OldFormat := A_FormatInteger
   SetFormat, Integer, H

   Loop, Parse, UTF8String
   {
      if A_LoopField is alnum
      {
         Out .= A_LoopField
         continue
      }
      Hex := SubStr( Asc( A_LoopField ), 3 )
      if ( StrLen(Hex) = 4 )
      {
	      StringSplit, xx_, Hex
	      out .= "%" . xx_3 . xx_4 . "%" . xx_1 . xx_2
      } else
		Out .= "%" . ( StrLen( Hex ) = 1 ? "0" . Hex : Hex )
   }
   SetFormat, Integer, %OldFormat%
   return Out
}

/*
; { Used In FoxBook
easou_getURL(inURL="", addStr="&st=244", type="page") ; 
{
		regexmatch(inURL, "i)gid=([0-9]+)", gg_)
		regexmatch(inURL, "i)nid=([0-9]+)", nn_)
		if ( type = "index" )
				return, "http://book.easou.com/ta/listAjax.m?gid=" . gg_1 . "&nid=" . nn_1 . addStr ; "&order=1&page=1&isHot=false&size=25"
		if ( type = "page" )
				return, "http://book.easou.com/ta/showAjax.m?gid=" . gg_1 . "&nid=" . nn_1 . addStr ; "&st=244"
}

easou_getIndexJson(json="") ; 索引返回列表: num`tTitle
{
		sp := "`t"
		itemHead := "{""status"""
		RE = i){"status":([0-9]?),"sort":([0-9]*),"nid":([0-9]*),"chapterName":"([^"]*)","chapterUrl":"([^"]*)","gsort":([0-9]?),"chapterType":"([^"]*)"}

		StringReplace, json,json, %itemHead%, `n%itemHead%, A
		loop, parse, json, `n, `r
		{
				if ! instr(A_LoopField, itemHead)
						continue
				
				xx_1 := "", xx_2 := "", xx_3 := "", xx_4 := "", xx_5 := "", xx_6 := "", xx_7 := ""
				regexmatch(A_LoopField, RE, xx_)
;				msgbox, % A_LoopField "`n" xx_1 "`n" xx_2 "`n" xx_3 "`n" xx_4 "`n" xx_5 "`n" xx_6 "`n" xx_7 "`n"
				fff .= xx_2 . sp . xx_4 . "`n"
		}
		sort, fff, N
		return, fff
}

easou_getPageJson(json="") ; 索引txt内容
{
		RE = i){"content":"(.*)","gid":[0-9]*,"sort":([0-9]*),
		regexmatch(json, RE, xx_)
;		msgbox, % xx_1 "`n" xx_2
		StringReplace, xx_1, xx_1, <br/>, `n, A
		StringReplace, xx_1, xx_1, 　　, , A
		return, xx_1
}

; }

easou_esenc(esencFile="C:\xxx.esenc", jsonFile="c:\xxx.json") ; text文件都是反码
{
	; Accept-Encoding: gzip,esenc
	ff := FileOpen(esencFile, "r")
	ww := FileOpen(jsonFile, "a")
	xx := ff.ReadChar()
	ww.WriteChar(~xx)
	loop {
		xx := ff.ReadChar()
		if ( xx = "" )
			break
		else
			ww.WriteChar(~xx)
	}
	ff.Close()
	ww.Close()
}
*/

