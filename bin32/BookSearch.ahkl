#noenv
#SingleInstance,force

VerDate := "2014-9-11"

ArgA = %1% ; 书名
ArgB = %2% ; 搜索类型
if ( ArgA != "" ) {
	DefName := ArgA
	bAuto := true
} else {
	DefName = %clipboard%
	bAuto := false
}
if ( ArgB = "" ) {
	typeN := 7
} else {
	typeN := ArgB
}


SE_ListT=
(join|
S:起点中文
S:追书神器
S:快读
S:宜搜
S:Soso
----------
E:SouGou
E:Bing
E:Yahoo
E:Soso
E:baidu
E:so
E:pangusou
)

ZSSQ_Agent := "ZhuiShuShenQi/2.20"

GuiInit:
	Gui,Add,DropDownList,x4 y10 w120 vSE_Type R20 choose%typeN%, %SE_ListT%
	Gui,Add,ComboBox,x134 y10 w170 h20 R10 vSE_Name choose1, %DefName%|末日精神病院|书名|书名 site:69zw.com
	Gui,Add,Button,x314 y10 w70 h20 vSE_Go gSE_Go,搜(&S)
;	Gui,Add,ComboBox,x404 y10 w470 R10 hidden vSE_Add

	Gui,Add,ListView,x4 y40 w870 h310 NoSortHdr vFoxLV gClickLV, T|Name|URL
	LV_ModifyCol(1, 70)
	LV_ModifyCol(2, 270)
	LV_ModifyCol(3, 500)
	Gui, Add, StatusBar, , 欢迎使用哈  作者:爱尔兰之狐  版本: %VerDate%
	Gui,Show, w881 h370 , Search
	GuiControl, Focus, SE_Name

	if bAuto
		gosub, SE_Go
return

SE_Go: ; 开始搜索
	Gui, submit, nohide
	if instr(SE_Type, "E:")
	{ ; 搜索引擎
		if (SE_Type = "E:SouGou")
			URL := "http://www.sogou.com/web?query=" . SE_Name . "&num=50"
		if (SE_Type = "E:Bing")
			URL := "http://cn.bing.com/search?q=" . GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(SE_Name))
		if (SE_Type = "E:Yahoo")
			URL := "http://search.yahoo.com/search?n=40&p=" . GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(SE_Name))
		if (SE_Type = "E:Soso")
			URL := "http://www.soso.com/q?w=" . SE_Name
		if ( SE_Type = "E:so" )
			URL := "http://www.so.com/s?q=" . GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(SE_Name))
		if ( SE_Type = "E:baidu" )
			URL := "http://www.baidu.com/s?wd=" . GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(SE_Name))
		if ( SE_Type = "E:pangusou" )
			URL := "http://search.panguso.com/pagesearch.htm?q=" . GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(SE_Name))

		html := wget(URL)
		LV_Delete()
		SE_getHrefList(html, SE_Name)
	}
	if ( SE_Type = "S:起点中文" ) {
		StrName := GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(SE_Name)) ; UTF-8编码后encode
		sURL := qidian_getSearchURL_Mobile(StrName)
		sJSON := DownJson(sURL)
;		fileappend, %sJSON%, C:\etc\xxx.json
		j := JSON.parse(sJSON)
		LV_Delete()
		loop, % j.Data.ListSearchBooks.MaxIndex()
		{
			if ( j.Data.ListSearchBooks[A_index].VipStatus )
				LV_Add("", "起点书列", j.Data.ListSearchBooks[A_index].BookName . "__" . j.Data.ListSearchBooks[A_index].NewVipChapterName
			, qidian_getIndexURL_Mobile(j.Data.ListSearchBooks[A_index].BookId))
			else 
				LV_Add("", "起点书列", j.Data.ListSearchBooks[A_index].BookName . "__" . j.Data.ListSearchBooks[A_index].NewChapterName
			, qidian_getIndexURL_Mobile(j.Data.ListSearchBooks[A_index].BookId))
		}
	}
	if ( SE_Type = "S:追书神器" ) {
		StrName := GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(SE_Name)) ; UTF-8编码后encode
		sURL := "http://api.zhuishushenqi.com/book?view=search&query=" . StrName
		runwait, wget -U "%ZSSQ_Agent%" -O "c:\zs_search.json" "%sURL%", , Min
		fileread, sJson, *P65001 c:\zs_search.json
		filedelete, c:\zs_search.json
		j := JSON.parse(sJSON)
		LV_Delete()
		loop, % j.MaxIndex()
		{
			LV_Add("", "追书书列"
			, j[A_Index].title . "__" . j[A_Index].lastChapter
			,j[A_Index]._id)
		}
	}
	if ( SE_Type = "S:快读" ) {
		LV_Delete()
		LV_Add("", "快读书列", SE_Name, qreader_Search(SE_Name))
	}
	if ( SE_Type = "S:宜搜" ) {
		StrName := GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(SE_Name)) ; UTF-8编码后encode
		sURL := "http://api.easou.com/api/bookapp/search.m?word=" . StrName . "&type=0&page_id=1&count=20&sort_type=0&cid=eef_easou_book"
		j := JSON.parse(DownJson(sURL))
		sURL := "http://api.easou.com/api/bookapp/search_chapterrel.m?gid=" . j.items[1].gid . "&nid=" . j.items[1].nid . "&chapter_name=" . GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(j.items[1].lastChapterName)) . "&cid=eef_easou_book"
		j := JSON.parse(DownJson(sURL))
		LV_Delete()
		loop, % j.items.MaxIndex()
		{  ; chapterCount
			LV_Add("", "宜搜站列"
			, j.items[A_Index].site . "__" . j.items[A_Index].last_chapter_name
			, "http://api.easou.com/api/bookapp/chapter_list.m?gid=" . j.items[A_Index].gid . "&nid=" . j.items[A_Index].nid . "&page_id=1&size=2147483647&cid=eef_easou_book")
		}
	}
	if ( SE_Type = "S:Soso" ) {
		StrName := GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(SE_Name)) ; UTF-8编码后encode
		sURL := "http://book.soso.com/ajax?m=list_book&start=1&resourcename=" . StrName
		sJSON := DownJson(sURL)
		j := JSON.parse(sJSON)
		LV_Delete()
		loop, % j.rows.MaxIndex()
		{	; from
			LV_Add("", "搜搜书列"
			, j.rows[A_index].lastserialid . "__" . j.rows[A_index].lastserialname  . "__" . j.rows[A_Index].resourcename
			, "http://book.soso.com/ajax?m=show_bookcatalog&sort=asc&resourceid=" . j.rows[A_index].resourceid . "&serialid=" . j.rows[A_index].serialnum)
		}
	}
return

ClickLV: ; 点击LV
	nRow := A_EventInfo
	if ( A_GuiEvent = "DoubleClick" ) {
		LV_GetText(NowID, nRow, 1)
		LV_GetText(NowName, nRow, 2)
		LV_GetText(NowURL, nRow, 3)
		if ( nRow < 1 ) { ; 空行
			return
		}
		if (NowID = "起点书列") {
			fsldk_1 := ""
			RegExMatch(NowURL, "i)BookId=([0-9]+)", fsldk_)
			LV_Delete()
			SB_SetText("处理json中，可能耗时很长，木办法啊，也许使用正则表达式是个好办法")
			j := JSON.parse(DownJson(NowURL))
			loop, % j.Chapters.MaxIndex()
			{
				if ( j.Chapters[A_index].v )
					LV_Add("", "起点章列", j.Chapters[A_index].n . "(VIP)", "http://vipreader.qidian.com/BookReader/vip," . fsldk_1 . "," . j.Chapters[A_index].c . ".aspx")
				else
					LV_Add("", "起点章列", j.Chapters[A_index].n, "http://read.qidian.com/BookReader/" . fsldk_1 . "," . j.Chapters[A_index].c . ".aspx")
			}
		}
		if (NowID = "起点章列") {
			cURL := qidian_toPageURL_FromPageInfoURL(NowURL)
			runwait, wget -O c:\xxxx.js "%curl%", c:\, Min
			fileread, sJS, c:\xxxx.js
			msgbox, % qidian_getTextFromPageJS(sJS)
			filedelete, c:\xxxx.js
		}
		if (NowID = "追书书列") {
			sURL := "http://api.zhuishushenqi.com/toc?view=summary&book=" . NowURL
			runwait, wget -U "%ZSSQ_Agent%" -O "c:\zs_sitelist.json" "%sURL%", , Min
			fileread, sJson, *P65001 c:\zs_sitelist.json
			filedelete, c:\zs_sitelist.json

			LV_Delete()
			j := JSON.parse(sJSON)
			loop, % j.MaxIndex()
			{
				LV_Add("", "追书站列"
				, j[A_Index].lastChapter . "__" . j[A_Index].name
				, "http://api.zhuishushenqi.com/toc/" . j[A_Index]._id . "?view=chapters&bid=" . NowURL)
			}
			; http://api.zhuishushenqi.com/toc/539e02ae66e0dbc55e3f8a60?view=chapters&bid=52e13475c09f68641700068d
		}
		if (NowID = "追书站列") {
			runwait, wget -U "%ZSSQ_Agent%" -O "c:\zs_chapter_list.json" "%NowURL%", , Min
			fileread, sJson, *P65001 c:\zs_chapter_list.json
			filedelete, c:\zs_chapter_list.json
			LV_Delete()
			SB_SetText("处理json中，可能耗时很长，木办法啊，也许使用正则表达式是个好办法")
			j := JSON.parse(sJSON)
			loop, % j.chapters.MaxIndex()
			{
				LV_Add("", "追书章列"
				, j.chapters[A_index].title
				, "http://chapter.zhuishushenqi.com/chapter/" . GeneralW_UTF8_UrlEncode(j.chapters[A_index].link))
			}
		}
		if (NowID = "追书章列") {
			runwait, wget -U "%ZSSQ_Agent%" -O "c:\zs_chapter.json" "%NowURL%", , Min
			fileread, sJson, *P65001 c:\zs_chapter.json
			filedelete, c:\zs_chapter.json
			j := JSON.parse(sJSON)
			nowTitle := j.chapter.title
			nowBody := j.chapter.body
			StringReplace, nowBody, nowBody, \n, `n, A
			StringReplace, nowBody, nowBody, 　　, , A
			msgbox, %nowTitle%`n`n%nowBody%
		}
		if (NowID = "快读书列") {
			LV_Delete()
			un := qreader_GetIndex(NowURL)
			loop, % un.MaxIndex()
				LV_Add("", "快读章列", un[A_index,2], NowURL . un[A_index,1])
		}
		if (NowID = "快读章列") {
			msgbox, % qreader_GetContent(NowURL)
		}
		if (NowID = "宜搜站列") {
			SB_SetText("处理json中，可能耗时很长，木办法啊，也许使用正则表达式是个好办法")
			j := JSON.parse(DownJson(NowURL))
			LV_Delete()
			idd_1 := "" , idd_2 := ""
			RegExMatch(NowURL, "i)gid=([0-9]+).*nid=([0-9]+)", idd_)
			loop, % j.items.MaxIndex()
			{ ; nid  ctype
				LV_Add("", "宜搜章列", j.items[A_index].chapter_name
				, "http://api.easou.com/api/bookapp/batch_chapter.m?a=1&cid=eef_easou_book&gsort=0&sequence=0&gid=" . idd_1 . "&nid=" . idd_2 . "&sort=" . j.items[A_index].sort . "&chapter_name=" . GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(j.items[A_index].chapter_name)) )
			}
		}
		if (NowID = "宜搜章列") {
			j := JSON.parse(DownJson(NowURL))
			msgbox, % j.items[1].content
		}
		if (NowID = "搜搜书列") {
			fsldk_1 := ""
			RegExMatch(NowURL, "i)resourceid=([0-9]+)&", fsldk_)
			LV_Delete()
			j := JSON.parse(DownJson(NowURL))
			loop, % j.rows[2].MaxIndex()
			{
				LV_Add("", "搜搜章列", j.rows[2][A_index].serialname
				, "http://book.soso.com/ajax?m=show_bookdetail&encrypt=1&readSerialid=1&resourceid=" . fsldk_1 . "&serialid=" . j.rows[2][A_index].serialid)
			}
		}
		if (NowID = "搜搜章列") {
			j := JSON.parse(DownJson(NowURL))
			cc := soso_decContent2(j.rows[1][1].serialcontent)
			StringReplace, cc, cc, <br>, `n,A
			StringReplace, cc, cc, <br/>, `n,A
			StringReplace, cc, cc, `n`n, `n,A
			msgbox, % j.rows[1][1].serialname "`n`n" . cc
		}
		if ( NowID = "搜索结果" ) {
			Clipboard = %nowURL%
			sTime := A_TickCount
			iHTML := wget(NowURL)
			eTime := A_TickCount - sTime

			stringreplace, iHTML, iHTML, `r, , A
			stringreplace, iHTML, iHTML, `n, , A
			iHTML := RegExReplace(iHTML, "Ui)<!--[^>]+-->", "") ; 删除目录中的注释 针对 niepo
			iHTML := RegExReplace(iHTML, "Ui)<span[^>]+>", "") ; 删除 span标签 qidian
			stringreplace, iHTML, iHTML, </span>, , A

			stringreplace, iHTML, iHTML, <a, `n<a, A
			stringreplace, iHTML, iHTML, </a>, </a>`n, A
			stringreplace, iHTML, iHTML, 　　, %A_space%%A_space%%A_space%%A_space%, A

			kk := FoxNovel_getHrefList(iHTML)
			nlaststart := kk.MaxIndex() - 20 
			outlist := ""
			LV_Delete()
			loop, % kk.maxindex()
			{
				if ( A_index < nlaststart )
					continue
				LV_Add("", "章节列表", kk[A_Index,2], GetFullURL(kk[A_index,1], NowURL))
;				outlist .= kk[A_index, 1] . "`t" . kk[A_index,2] . "`n"
			}
			SB_settext("下载耗时(ms): " . eTime)
		}
		if ( NowID = "章节列表" ) {
			sTime := A_TickCount
			iHTML := wget(NowURL)
			eTime := A_TickCount - sTime
			msgbox, % FoxNovel_getPageText(iHTML)
		}
	}
	if ( A_GuiEvent = "R" ) {
		LV_GetText(NowID, nRow, 1)
		LV_GetText(NowName, nRow, 2)
		LV_GetText(NowURL, nRow, 3)

		Clipboard = %nowURL%
		if (NowID = "搜索结果") {
			html := wget(nowURL)
			LV_Delete()
			SE_getHrefList(html, nowURL)
			return
		}
		IfWinExist, 编辑窗口 ahk_class AutoHotkeyGUI
		{
			ControlSetText, Edit4, %nowURL%, 编辑窗口 ahk_class AutoHotkeyGUI
			TrayTip, 复制到FoxBook地址框:, %nowURL%
		}
		TrayTip, 剪贴板:, % nowURL
	}
return

GuiClose:
GuiEscape:
	ExitApp
return

/*
F1::
	fileread, sJson, *P65001 c:\zs_sitelist.json
	msgbox, % sJSON
	j := JSON.parse(sJSON)
	msgbox, % j[1]._id
return


^esc::reload
+esc::Edit
!esc::ExitApp
*/

!1::CopyInfo2Clip(1)
!2::CopyInfo2Clip(2)
!3::CopyInfo2Clip(3)
!4::CopyInfo2Clip(4)
!5::CopyInfo2Clip(5)
!6::CopyInfo2Clip(6)
!7::CopyInfo2Clip(7)
!8::CopyInfo2Clip(8)
!9::CopyInfo2Clip(9)

#include <JSON_Class>

CopyInfo2Clip(Num=1) {
	LV_GetText(NowVar, LV_GetNext(0), Num)
	Clipboard = %NowVar%
	TrayTip, 剪贴板:, %NowVar%
}

DownJson(inURL="", TmpPath="C:\xxx.json", bDelete=1) ; 下载json并读取
{
	IfNotExist, %TmpPath%
		runwait, curl -o %TmpPath% --compressed "%inURL%", c:\, Min
	fileread, sjson, *P65001 %TmpPath%
	if bDelete
		FileDelete, %TmpPath%
	return, sjson
}

; book.soso.com  内容解密
soso_decContent2(cc) ; 10594   12625 15000   ms/1000次
{
	bb := ""

	loop, parse, cc
	{
		if ( 0 = mod(A_index, 2) )
			bb .= A_loopfield . c1
		else
			c1 := A_loopfield
	}

	if ( 1 = mod(strlen(cc), 2) )
		bb .= c1

	return bb
}

wget(URL, SavePath="", AddParamet="") {
	if ( SavePath = "" )
		SavePath := A_windir . "_Wget_" . A_now
	loop { ; 下载，直到下载完成
		runwait, wget -c -T 5 -O "%SavePath%" %AddParamet% "%URL%", , Min UseErrorLevel
		If ( ErrorLevel = 0 )
			break
		else
			SB_settext("下载错误: 重试地址: " . URL)
	}

	html := ReadHTML(SavePath)
	FileDelete, %SavePath%
	return  html
}

ReadHTML(HtmlPath)
{
	FileRead, html, *P65001 %HtmlPath%
	if html not contains charset=utf-8,charset="utf-8"
		FileRead, html, %HtmlPath%
	return, html
}

SE_getHrefList(html, KeyWord="海岛农场主") ; KeyWord中包含http表示父网址，用来合成完整网址
{
	if (instr(KeyWord, "http")) {
		isSearchEngine := false
	} else {
		isSearchEngine := true
	}
;	stringreplace, html,html, %A_space%%A_space%%A_space%, %A_space%, A
	stringreplace, html,html, `t, , A
	stringreplace, html,html, `r, , A
	stringreplace, html,html, `n, , A

	html := RegExReplace(html, "smUi)<!--[^>]+-->", "")
	stringreplace, html,html, <em>, , A
	stringreplace, html,html, </em>, , A
	stringreplace, html,html, <b>, , A
	stringreplace, html,html, </b>, , A
	stringreplace, html,html, <strong>, , A
	stringreplace, html,html, </strong>, , A

	stringreplace, html,html, <a, `n<a, A
	stringreplace, html,html, </a>, </a>`n, A

	loop, parse, html, `n, `r
	{
		if ! instr(A_LoopField, "</a>")
			continue
		xx_1 := "" , xx_2 := ""
		regexmatch(A_LoopField, "i)href *= *[""']?([^>""']+)[""']?[^>]*> *(.*)</a>", xx_)
		if ( strlen(xx_1) < 5 )
			continue
		if ( isSearchEngine ) {
			if ! instr(xx_1, "http:")
				continue
			if instr(xx_1, "http://www.sogou.com/web?query=")
				continue
			if ! instr(xx_2, KeyWord)
				continue
			LV_Add("", "搜索结果", xx_2, xx_1)
		} else {
			LV_Add("", "搜索结果", xx_2, GetFullURL(xx_1, KeyWord))
		}
	}
	return, list
}

GetFullURL(ShortURL="xxx.html", ListURL="http://www.xxx.com/45456/238/list.html")
{	; 获取完整URL
	If Instr(ShortURL, "http://")
		return, ShortURL
	Stringleft, ttt, ShortURL, 1
	SplitPath, ListURL, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
	If ( ttt = "/" )
		return, OutDrive . ShortURL
	else
		return, OutDir . "/" . ShortURL
}

