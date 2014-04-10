VerDate := "2014-2-25"
bDebug := 0
; T:海岛农场主
; GB:%BA%A3%B5%BA%C5%A9%B3%A1%D6%F7
; U:%E6%B5%B7%E5%B2%9B%E5%86%9C%E5%9C%BA%E4%B8%BB

#noenv
ArgA = %1%
if ( ArgA != "" ) {
	DefName := ArgA
	bAuto := true
} else {
	DefName = %clipboard%
	bAuto := false
}

SubKeyList =
(Join|

site:qidian.com
site:biquge.com
site:sodu.org
site:dajiadu.net
site:dukankan.com
site:paoshu8.com
site:paitxt.com
site:wudilong.net
列表 小说
)

sitelist=
(join|
SoGou
Yahoo
Bing
soso
baidu
so
pangusou
)

GuiInit:
	Gui, Add, DropDownList, x4 y10 w100 vSEngine Choose1 R20, %sitelist%
	Gui, Add, ComboBox, x114 y10 w170 vMainKW choose1 R10, %DefName%|爱尔兰之狐
	Gui, Add, ComboBox, x284 y10 w160 vSubKW choose1 R10, %SubKeyList%
	Gui, Add, Button, x454 y10 w100 h20 gSouSuo, 搜索(&S)
;	Gui, Add, checkbox, x564 y10 w100 h20 vCKExact checked, &E.标题包含
	Gui, Add, checkbox, x674 y10 w100 h20 vCKWget checked, &W.右键Wget/IE

	Gui, Add, ListView, x6 y40 w840 h320 -ReadOnly vFoxLV gClickLV, URL|Name
		LV_ModifyCol(1, 350) , LV_ModifyCol(2, 450)

	gui, add, statusbar, , 双击: 复制到剪贴板　　右键双击: 用Wget/IE打开　　Ctrl+1/2: 复制条目　　F1: QiDianLink.ahk
	; Generated using SmartGUI Creator 4.0
	Gui, Show, w855 h385, 搜索结果 Ver:%VerDate%
	onmessage(0x100, "FoxInput")  ; 在特殊控件按下特殊按键的反应
	Guicontrol, Focus, MainKW

	if bAuto
		gosub, SouSuo
Return

SouSuo:
	gui, submit, nohide
	TmpHTMLPath := A_windir . A_now . ".html"
	if ( SubKW = "" )
		SearchString := MainKW
	else
		SearchString := MainKW . A_space . SubKW

	if ( SEngine = "Yahoo" )
		URL := "http://search.yahoo.com/search?n=40&p=" . UrlEncodeFox(GeneralW_StrToUTF8(SearchString))
	if ( SEngine = "SoGou" )
		URL := "http://www.sogou.com/web?query=" . SearchString . "&num=50"
	if ( SEngine = "so" )
		URL := "http://www.so.com/s?q=" . UrlEncodeFox(GeneralW_StrToUTF8(SearchString))
	if ( SEngine = "soso" )
		URL := "http://www.soso.com/q?w=" . SearchString
	if ( SEngine = "Bing" )
		URL := "http://cn.bing.com/search?q=" . UrlEncodeFox(GeneralW_StrToUTF8(SearchString))
	if ( SEngine = "baidu" )
		URL := "http://www.baidu.com/s?wd=" . UrlEncodeFox(GeneralW_StrToUTF8(SearchString))
	if ( SEngine = "pangusou" )
		URL := "http://search.panguso.com/pagesearch.htm?q=" . UrlEncodeFox(GeneralW_StrToUTF8(SearchString))

	SB_settext("开始搜索: <" . SearchString . ">  URL: " . URL)

	FileDelete, %TmpHTMLPath%
	wget(URL, TmpHTMLPath)

	html := ReadHTML(TmpHTMLPath)
	if ! bDebug
		FileDelete, %TmpHTMLPath%

	SB_settext("结束搜索: <" . SearchString . ">  URL: " . URL)

	stringreplace, MainKW, MainKW, intitle:
	LV_delete()
	getHrefList(html, MainKW)
/*
	oLinks := Process%SEngine%(html)

	LV_delete()
	loop, % oLinks.maxindex()
	{
		if ( CkExact = 1 ) and ( ! instr(oLinks[A_Index,2], MainKW) )
			continue
		LV_Add("", oLinks[A_Index,1], oLinks[A_Index,2])
	}
*/
return

GuiClose:
GuiEscape:
	ExitApp
return

; -----备注:
^esc::reload
+esc::Edit
!esc::ExitApp
#Ifwinactive, ahk_class AutoHotkeyGUI
^1::CopyInfo2Clip(1)
^2::CopyInfo2Clip(2)
F1::run, %A_ScriptDir%\QiDianLink.ahk
#Ifwinactive

ClickLV:
	Gui, submit, nohide
	If ( A_GuiEvent = "DoubleClick" ) {
		LV_GetText(NowURL, A_EventInfo, 1)
		Clipboard = %NowURL%
		SB_settext("已复制到剪贴板: " . NowURL)
		setFoxbookURL(NowURL)
	}
	If ( A_GuiEvent = "R" ) {
		LV_GetText(NowURL, A_EventInfo, 1)
		if CKWget
			runwait, wget "%NowURL%", C:\
		else
			OpenURL(NowURL)
	}
return

setFoxbookURL(URL) ; 注意Edit的ID会变动，假如变动了Foxbook的GUI顺序
{
	IfWinExist, 编辑窗口 ahk_class AutoHotkeyGUI
	{
	if instr(URL, ".qidian.")
		ControlSetText, Edit3, %URL%, 编辑窗口 ahk_class AutoHotkeyGUI
	else
		ControlSetText, Edit4, %URL%, 编辑窗口 ahk_class AutoHotkeyGUI
	}
}


FoxInput(wParam, lParam, msg, hwnd)  ; 在特殊控件按下特殊按键的反应
{ ;	tooltip, <%wParam%>`n<%lParam%>`n<%msg%>`n<%hwnd%>`n%A_GuiControl%
	If ( ( A_GuiControl = "MainKW" or A_GuiControl = "SubKW" ) and wParam = 13 ) {
		gosub, SouSuo
	}
}

CopyInfo2Clip(Num=1) {
	LV_GetText(NowVar, LV_GetNext(0), Num)
	Clipboard = %NowVar%
	SB_settext("剪贴板: " . NowVar)
}

OpenURL(URL="http://www.autohotkey.net/~linpinger")
{
	IfExist, %A_ProgramFiles%\Internet Explorer\IEXPLORE.EXE
		run, %A_ProgramFiles%\Internet Explorer\IEXPLORE.EXE -new %URL%
	else
		run, %URL%
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
ProcessSogou(html) ; 返回数组 [URL,Name]
{
	stringreplace, html, html, `r, , A
	stringreplace, html, html, `n, , A
	stringreplace, html, html, <a, `n<a, A
	stringreplace, html, html, <em>, , A
	stringreplace, html, html, </em>, , A
	html := RegExReplace(html, "Ui)<\!--([^>]*)-->")
	oLinks := [] , LinkCount := 0
	loop, parse, html, `n, `r
	{
		If A_loopfield not contains <a,href
			continue
		ll1 := "" , ll2 := ""
		regexmatch(A_LoopField, "i)href *= *[""']?([^>""']+)[^>]+> *([^<]+)<", ll)
		If ! instr(ll1, "http:")
			continue
		If ! instr(ll1, "sogou.com")
		{
			++ LinkCount
			oLinks[LinkCount,1] := ll1
			oLinks[LinkCount,2] := ll2
		}
	}
	return, oLinks
}

ProcessBing(html) ; 返回数组 [URL,Name]
{
	stringreplace, html, html, `r, , A
	stringreplace, html, html, `n, , A
	stringreplace, html, html, <li, `n<li, A
	stringreplace, html, html, <strong>, , A
	stringreplace, html, html, </strong>, , A
	oLinks := [] , LinkCount := 0
	loop, parse, html, `n, `r
	{
		If A_loopfield not contains <li,"sa_wr",<h3,<a,href
			continue
		ll1 := "" , ll2 := ""
		regexmatch(A_LoopField, "i)<h3><a.*href *= *[""']?([^>""']+)[^>]+> *([^<]+)<", ll)
		If ! instr(ll1, "http:")
			continue
		If ! instr(ll1, "bing.")
		{
			++ LinkCount
			oLinks[LinkCount,1] := ll1
			oLinks[LinkCount,2] := ll2
		}
	}
	return, oLinks
}
*/


getHrefList(html, KeyWord="海岛农场主")
{
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
		if ! instr(xx_1, "http:")
			continue
		if ! instr(xx_2, KeyWord)
			continue
		LV_Add("", xx_1, xx_2)
;		list .= xx_1 . ">" . xx_2 . "`n"
	}
	return, list
}

ReadHTML(HtmlPath)
{
	FileRead, html, *P65001 %HtmlPath%
	if html not contains charset=utf-8,charset="utf-8"
		FileRead, html, %HtmlPath%
	return, html
}
