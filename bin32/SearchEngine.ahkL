VerDate := "2014-3-4"
bDebug := 0

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
	Gui, Add, checkbox, x564 y10 w100 h20 vCKWget checked, &W.右键Wget/IE
	Gui, Add, checkbox, x674 y10 w130 h20 vCKNovel checked, &E.分析小说目录

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
		{
			if CKNovel
			{
				HtmlPath := A_windir . "_" . A_now . "_index.html"
				runwait, wget "%NowURL%" -O "%HtmlPath%", C:\
				iHTML := ReadHTML(HtmlPath)
		stringreplace, iHTML, iHTML, `r, , A
		stringreplace, iHTML, iHTML, `n, , A
		iHTML := RegExReplace(iHTML, "Ui)<!--[^>]+-->", "") ; 删除目录中的注释 针对 niepo
		iHTML := RegExReplace(iHTML, "Ui)<span[^>]+>", "") ; 删除 span标签 qidian
		stringreplace, iHTML, iHTML, </span>, , A

		stringreplace, iHTML, iHTML, <a, `n<a, A
		stringreplace, iHTML, iHTML, </a>, </a>`n, A
		stringreplace, iHTML, iHTML, 　　, %A_space%%A_space%%A_space%%A_space%, A

				kk := novel_getHrefList(iHTML)
				nlaststart := kk.MaxIndex() - 10 
				outlist := ""
				loop, % kk.maxindex()
				{
					if ( A_index < nlaststart )
						continue
					outlist .= kk[A_index, 3] . "`t" . kk[A_index,4] . "`n"
				}
				msgbox, % outlist
				filedelete, %HtmlPath%
			} else {
				runwait, wget "%NowURL%", C:\
			}
		} else {
			OpenURL(NowURL)
		}
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

OpenURL(URL="http://linpinger.github.io")
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

novel_getHrefList(html) ; 获取目录页链接，理论: 链接列表应该是长度极近似(最多增加一位)的
{	; 搜索FoxBook: _GetBookNewPages(
	cList := ":"
	jj := []  ; 链接长度, 链接位置, 链接, 文字
	cJJ := 0

	loop, parse, html, `n, `r
	{
		if ! instr(A_LoopField, "</a>")
			continue
		xx_1 := "" , xx_2 := ""
		regexmatch(A_LoopField, "i)href *= *[""']?([^>""']+)[^>]*> *([^<]+)<", xx_)
		nowlen := strlen(xx_1)
		if ( nowlen < 4 ) ; 链接长度小于4的过滤掉
			continue
		++cJJ
		jj[cJJ,1] := nowlen
		jj[cJJ,2] := A_index
		jj[cJJ,3] := xx_1
		jj[cJJ,4] := xx_2
		clist .= nowlen . ":"
	}
	
	uList := clist
	sort, uList, D: U  ; 唯一列表
	
	; 获取最多链接长度相同的长度
	nCount := 0
	loop, parse, uList, :
	{
		if (A_LoopField = "" )
			continue
		stringreplace, fksd, clist, :%A_LoopField%:, , UseErrorLevel
		if ( ErrorLevel > nCount ) {
			nCount := ErrorLevel
			nMax := A_LoopField
		}
	}
	nLeft := nMax - 1  ; 可能长度小一位 ; 较少
	nRight := nMax + 1 ; 可能长度大一位 ; 极少 可能新书或
	uList := "" , clist := ""

	; 过滤出在 nMax+-1范围内的长度的链接
	kk := []  ; 链接长度, 链接位置, 链接, 文字
	cKK := 0
	loop, %cJJ%
	{
		; 长度不在 nMax+-1范围内的，过滤掉
		xx := jj[A_index,1]
		if xx not in %nLeft%,%nMax%,%nRight%
			continue
		++cKK
		kk[cKK,1] := jj[A_index,1]
		kk[cKK,2] := jj[A_index,2]
		kk[cKK,3] := jj[A_index,3]
		kk[cKK,4] := jj[A_index,4]
	;	Blist .= kk[cKK,1] . "@" . kk[ckk,2] . "=" . kk[cKK,3] . ">" . kk[cKK,4] . "`n"
	}
	; 后面还可以深化: 过滤出不在相邻域值范围内的链接 过滤长度不是递增的区间
	; 目前的方案是: 过滤头部多少章节
	return, kk
;	return, nMax . "`n`n" . uList . "`n`n" . clist . "`n`n" . alist
}
