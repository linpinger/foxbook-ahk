; 2013-3-22 修改
; 没下面这句，会导致在1.1.8.0版中SQLite出错
#NoEnv
; 1.gui resize 2. 网站过滤插件机制

	AllPageFileNameMod := "All"  ; 保存到C:\all.xxx
	DBPath := A_scriptdir . "\FoxBook.db3"

;	PicDir := "D:\bin\SQlite\FoxBook\FoxPic" ; 注释掉使用: %A_scriptdir%\FoxPic

	/*
	FileGetSize, DBSizeM, %DBPath%, M ; 根据数据库大小,判断是否使用内存数据库
	if ( DBSizeM > 3 )
		bMemDB := 0 ; 文件
	else
		bMemDB := 1 ; 内存
	*/
	bMemDB := 1 ; 使用内存数据库
/*
	ifExist, D:\Program Files
		FoxType := 1  ; 台式机
	else
		FoxType := 0  ; 笔记本
*/
	FoxType := 0  ; 笔记本

	bNoSwitchLV := 0  ; 状态: 允许切换LV
; { Init
GuiInit:
	Gui, +HWNDhMain ; +Resize
	Gosub, MenuInit
	Gui, Add, ListView, x6 y10 w205 h350 +HwndhLVBook vLVBook gListViewClick AltSubmit, 名称|页数|ID|URL
		LV_ModifyCol(1, 100), LV_ModifyCol(2, 40) , LV_ModifyCol(3, 30), LV_ModifyCol(4, 10)
	Gui, Add, ListView, x216 y10 w550 h350 +HwndhLVPage vLVPage gListViewClick AltSubmit, 名称|字数|URL|ID
		LV_ModifyCol(1, 300), LV_ModifyCol(2, 50), LV_ModifyCol(3, 130), LV_ModifyCol(4, 40)

	Gui, Add, StatusBar, , 欢迎使用哈
	; Generated using SmartGUI Creator 4.0
	Gui, Show, w780 h387, FoxTest L
	onmessage(0x100, "FoxInput")  ; 在特殊控件按下特殊按键的反应
	LV_Colors.OnMessage() ; LV颜色

	gosub, ObjectInit
	gosub, SettingMenuCheck

	sTime := A_TickCount
	BookCount := oBook.ShowBookList(oLVBook)
	SB_settext(bMemDB . " 查询耗时: " . ( A_TickCount - sTime) . " ms  书籍数: " . BookCount)

	gosub, CommandProcess ; 执行外部传进来的命令
	WinSet, ReDraw, , A  ; 重绘窗口
return

CommandProcess:                ; 执行外部传进来的命令
	iAction = %1% 
	iArgA = %2%
	If ( iAction = "" )
		return
	If ( iAction = "DelBookPages" ) {
		If ( iArgA < 1 )
			gosub, FoxExitApp
		oDB.GetTable("select id from page where bookid=" . iArgA, oIDlist)
		iIDList := []
		loop, % oIDlist.rowcount
			iIDList[A_index] := oIDlist.rows[A_index][1]
		oBook.DeletePages(iIDList) ; 删除章节条目
		TrayTip, 外部调用:, 清空了书籍: %iArgA%
	}
	If ( iAction = "UpdateAll" ) {
		NowInCMD := "UpdateAll"
		gosub, BookMenuAct
	}
	If ( iAction = "CreatePDF" ) {
		NowInCMD := "ShowAll"
		gosub, DBMenuAct
		Gui, ListView, LVPage
		LV_Modify(0, "Select")

		NowInCMD := "PageToPDF"
		gosub, PageMenuAct
		loop, c:\*.pdf, 0, 0
			filemove, %A_LoopFileFullPath%, D:\bin\FoxServer\htdocs\all.pdf, 1
		TrayTip, 外部调用:, 生成 all.pdf 到网页根目录
	}
	NowInCMD := ""
	gosub, FoxExitApp
return

ObjectInit:
	IfNotExist, %DBPath%
		isCreate := 1
	oDB := new SQLiteDB
	if bMemDB
	{
		oDB.OpenDB(":memory:")
		FoxMemDB(oDB, DBPath, "File2Mem")
	} else
		oDB.OpenDB(DBPath)
	If isCreate
		CreateNewDB(oDB)
	oBook := New Book(oDB, PicDir, FoxType)
	oBook.hLVBook := hLVBook
	oBook.hLVPage := hLVPage

	oLVBook := new FoxLV("LVBook")
	oLVBook.FieldSet := [[100,"名称"],[40,"页数"],[30,"ID"],[10,"URL"]] ; Book

	oLVPage := new FoxLV("LVPage")
	oLVPage.FieldSet := [[300,"名称"],[50,"字数"],[130,"URL"],[40,"ID"]] ; Page

	oLVDown := new FoxLV("LVPage")
	oLVDown.FieldSet := [[300,"章节"],[50,"字数"],[130,"书名"],[40,"ID"]] ; Down

	oLVComp := new FoxLV("LVPage")
	oLVComp.FieldSet := [[200,"旧章节"],[200,"新章节"],[95,"书名"],[40,"ID"]] ; 比较

	FoxCompSiteType := "dajiadu" ; 书架网站 :dajiadu paitxt paoshu8 wudilong biquge
	; 下面的是为了获取默认比较书架的网站关键字
	oDB.GetTable("select URL from book limit 1", oBBB)
	FirstBookURL := oBBB.rows[1,1]
	SplitPath, FirstBookURL, , , , , FirstBookSiteType
	Type_1 := ""
	RegExMatch(FirstBookSiteType, "Ui)\.([^\.]+)\.", Type_)
	if (Type_1 != "")
		FoxCompSiteType := Type_1
return
; --------
BookGUICreate:
	Gui, Book:New
	Gui, Book:Add, GroupBox, x6 y10 w350 h80 cBlue, BookID | BookName | QidianID | URL
	Gui, Book:Add, Edit, x16 y30 w40 h20 disabled vBookID, %BookID%
	Gui, Book:Add, Edit, x66 y30 w130 h20 vBookName, %BookName%
	Gui, Book:Add, Edit, x204 y30 w70 h20 vQidianID, %QidianID%
	Gui, Book:Add, Button, x274 y30 w70 h20 gEditBookInfo vGetQidianID, &QidianID
	Gui, Book:Add, Edit, x16 y60 w330 h20 vURL, %URL%

	Gui, Book:Add, Edit, x14 y100 w240 h330 -Wrap vDelList hwndhDelListEdit, %DelList%

	Gui, Book:Add, Button, x264 y100 w95 h40 gEditBookInfo vSaveBookInfo, 保存(&S)
	Gui, Book:Add, Button, x264 y200 w100 h30 gEditBookInfo vShortingStr, 减肥(&F)
	Gui, Book:Add, Button, x264 y250 w100 h30 gEditBookInfo vCleanDelList, 清空(&C)
	Gui, Book:Add, Button, x264 y300 w100 h30 gEditBookInfo vShortAndSave, 减肥并保存(&E)
	Gui, Book:show, w371 h440, 编辑窗口

	EditJump2End(hDelListEdit) ; 跳转到Edit最后

	Guicontrol, Book:Focus, URL
return

EditJump2End(hEdit)  ; 跳转到Edit最后
{
;	GuiControlGet, hEdit, Hwnd, NR
	SendMessage 0xBA,0,0,,ahk_id %hEdit%
	LineCount := ErrorLevel
	SendMessage 0xB6,0,LineCount,,ahk_id %hEdit%
}


EditBookInfo:
	If ( A_GuiControl = "CleanDelList" ) {
		guicontrol, , DelList
	}
	If ( A_GuiControl = "ShortingStr" or A_GuiControl = "ShortAndSave" ) {
		guicontrolget, DelList
		oNewList := []
		NewLineCount := 0
		loop, parse, DelList, `n, %A_space%
		{
			fd_1 := "" , fd_2 := ""
			stringsplit, fd_, A_loopfield, |, %A_space%
			if ( fd_1 = "" )
				continue
			++NewLineCount
			oNewList[NewLineCount,1] := fd_1
			oNewList[NewLineCount,2] := fd_2
		}
		if NewLineCount < 25
			return
		NewDelList := ""
		MaxLineCount := oNewList.MaxIndex() - 10
		loop, %NewLineCount%
		{
			if A_index between 5 and %MaxLineCount%
				NewDelList .= oNewList[A_index,1] . "|`n"
			else
				NewDelList .= oNewList[A_index,1] . "|" . oNewList[A_index,2] . "`n"
		}
		guicontrol, , DelList, %NewDelList%
		NewDelList := "" , DelList := ""
		oNewList := []
		EditJump2End(hDelListEdit) ; 跳转到Edit最后
	}
	If ( A_GuiControl = "GetQidianID" ) {
		guicontrolget, QidianID
		if ( QidianID = "" )
			if instr(Clipboard, ".qidian.")
				QidianID = %Clipboard%
		if instr(QidianID, ".qidian.")
		{
			II_1 := ""
			regexmatch(QidianID, "Ui)\/([0-9]{2,9})\.", II_)
			if (II_1 != "")
				guicontrol, , QidianID, %II_1%
		}
	}
	If ( A_GuiControl = "SaveBookInfo" or A_GuiControl = "ShortAndSave" ) {
		Gui, Book:Submit
		Gui, Book:Destroy
		;  BookID | BookName | QidianID | URL, %DelList%
		oDB.EscapeStr(DelList)
		oDB.Exec("update Book set Name='" . BookName . "' , URL='" . URL . "' , QiDianID='" . QiDianID . "' , DelURL=" . DelList . " where ID = " . BookID)
	}
return

BookGuiClose:
BookGuiEscape:
	Gui, Book:Destroy
return

; --------
PageMenuBarAct:
	if ( A_ThisMenuItem = "窗口复制(&C)" )
		gosub, CopyWinInfo
	if ( A_ThisMenuItem = "获取列表(&I)" )
		gosub, GetTmpIndex
	if ( A_ThisMenuItem = "获取内容(&N)" )
		gosub, GetTmpNR
	if ( A_ThisMenuItem = "处理内容(&R)" )
		gosub, ProcTmpNR
return

TmpSiteCheck:
	Menu, TmpSite, Uncheck, 百度贴吧(&B)
	Menu, TmpSite, Uncheck, paitxt(&T)
	Menu, TmpSite, Uncheck, dajiadu(&D)
	Menu, TmpSite, Uncheck, paoshu8(&P)
	Menu, TmpSite, Uncheck, wudilong(&W)
	if ( A_ThisMenuItem = "百度贴吧(&B)" ) {
		Menu, TmpSite, check, 百度贴吧(&B)
		NowSite := "tieba"
	}
	if ( A_ThisMenuItem = "paitxt(&T)" ) {
		Menu, TmpSite, check, paitxt(&T)
		NowSite := "paitxt"
	}
	if ( A_ThisMenuItem = "dajiadu(&D)" ) {
		Menu, TmpSite, check, dajiadu(&D)
		NowSite := "dajiadu"
	}
	if ( A_ThisMenuItem = "paoshu8(&P)" ) {
		Menu, TmpSite, check, paoshu8(&P)
		NowSite := "paoshu8"
	}
	if ( A_ThisMenuItem = "wudilong(&W)" ) {
		Menu, TmpSite, check, wudilong(&W)
		NowSite := "wudilong"
	}
return

PageGUICreate:
	Gui, Page:New, +HwndhPage
	Menu, PageMenuBar, Add, 窗口复制(&C), PageMenuBarAct
	Menu, PageMenuBar, Add, 　　　　, PageMenuBarAct

	Menu, TmpSite, Add, 百度贴吧(&B), TmpSiteCheck
	if ( NowSite = "" )
		NowSite := "tieba"
;	TrayTip, 当前搜索网站:, %NowSite%
;	Menu, TmpSite, check, 百度贴吧(&B)
	Menu, TmpSite, Add, paitxt(&T), TmpSiteCheck
	Menu, TmpSite, Add, dajiadu(&D), TmpSiteCheck
	Menu, TmpSite, Add, paoshu8(&P), TmpSiteCheck
	Menu, TmpSite, Add, wudilong(&W), TmpSiteCheck
	Menu, PageMenuBar, Add, 网站设置(&T), :TmpSite

	Menu, PageMenuBar, Add, 　　　, PageMenuBarAct
	Menu, PageMenuBar, Add, 获取列表(&I), PageMenuBarAct
	Menu, PageMenuBar, Add, 获取内容(&N), PageMenuBarAct
	Menu, PageMenuBar, Add, 　　, PageMenuBarAct
	Menu, PageMenuBar, Add, 处理内容(&R), PageMenuBarAct
	Gui, Page:Menu, PageMenuBar

	Gui, Page:Add, GroupBox, x6 y10 w620 h80 cBlue, PageID | BookID | Name | URL | CharCount || TmpURL | PageFilter || Content
	Gui, Page:Add, Button, x536 y3 w80 h20 gCopyWinInfo vBtnCopyWinInfo, 窗口复制(&C)
	Gui, Page:Add, Edit, x16 y30 w40 h20 disabled vPageID, %PageID%
	Gui, Page:Add, Edit, x56 y30 w40 h20 vBookID, %BookID%
	Gui, Page:Add, Edit, x96 y30 w230 h20 vPageName, %PageName%
	Gui, Page:Add, Edit, x326 y30 w160 h20 vPageURL, %PageURL%
	Gui, Page:Add, Edit, x486 y30 w40 h20 vCharCount, %CharCount%

	Gui, Page:Add, Button, x536 y30 w80 h50 gSavePageInfo vSavePageInfo, 保存(&S)

	Gui, Page:Add, checkbox, x16 y60 w40 h20 vCKbGood +checked, 精&H
	Gui, Page:Add, Checkbox, x54 y60 w40 h20 vCKPage2, &P2
	Gui, Page:Add, Button, x94 y60 w20 h20 gGetTmpIndex vBtnTmpIndex, I
	Gui, Page:Add, ComboBox, x114 y60 w210 R10 vTmpURL choose1, %NowIndexURL%
	Gui, Page:Add, ComboBox, x354 y60 w120 R10 vPageFilter
	Gui, Page:Add, Button, x324 y60 w20 h20 gGetTmpNR vBtnTmpNR, N
	Gui, Page:Add, Button, x484 y60 w50 h20 gProcTmpNR vContProc, R

	Gui, Page:Add, ListView, x6 y100 w620 h270 vTieBaLV gSelectTieZi, Name|URL
	LV_ModifyCol(1, 350), LV_ModifyCol(2, 240)
	Gui, Page:Font, s12 , Fixedsys
	Gui, Page:Add, Edit, x6 y100 w620 h270 vContent , %Content%
	Gui, Page:Font
	; Generated using SmartGUI Creator 4.0
	GuiControl, Hide, TieBaLV
	Gui, Page:Show, h380 w630, 修改章节信息

	WinGet, TmpList, List, 修改章节信息 ahk_class AutoHotkeyGUI
	if ( TmpList = 2 )
		GuiControl, Focus, BtnCopyWinInfo
	else
		GuiControl, Focus, BtnTmpIndex
Return


CopyWinInfo: ; 复制另一个窗口信息
	WinGet, TmpList, List, 修改章节信息 ahk_class AutoHotkeyGUI
	if ( TmpList != 2 ) {
		TrayTip, 提示, 不是两个窗口`n数量: %TmpList%
		return
	}
	if ( hPage = TmpList1 )
		hOtherPage := TmpList2
	else
		hOtherPage := TmpList1
	ControlGetText, TmpTitle, Edit3, ahk_id %hOtherPage%
	ControlGetText, TmpNR, Edit8, ahk_id %hOtherPage%
	Guicontrol, , PageName, %TmpTitle%
	Guicontrol, , Content, %TmpNR%
	TmpNR := "" , TmpTitle := ""
return

GetTmpIndex:  ; 获取索引列表
	Gui, Page:submit, nohide
	oBook.GetBookInfo(BookID)
	NowBookName := oBook.Book["Name"]

	if ( NowSite = "tieba" ) {
		stringreplace, NowBookName, NowBookName, 台湾, , A
		if ( CKbGood = 1 ) {
			NowIndexURL := "http://tieba.baidu.com/f/good?kw=" . NowBookName
			tmphtml := A_windir . "_good_" . NowBookName . ".bdlist"
		} else {
			NowIndexURL := "http://tieba.baidu.com/f?kw=" . NowBookName
			tmphtml := A_windir . "_tieba_" . NowBookName . ".bdlist"
		}

		IfNotExist, %tmphtml%
			runwait, wget.exe "%NowIndexURL%" -O %tmphtml%, %A_scriptdir%\bin32
		FileRead, html, %tmphtml%
		if ! instr(html, "</html>") ; 未下完整，删除
			FileDelete, %tmphtml%
		oIndex := getTieBaList(html)
	} else {
		if ( TmpURL = "" ) {
			if ( NowSite = "paitxt" )
				NowIndexURL := oBook.Search_paitxt(NowBookName)
			if ( NowSite = "paoshu8" )
				NowIndexURL := oBook.Search_paoshu8(NowBookName)
			if ( NowSite = "dajiadu" )
				NowIndexURL := oBook.Search_dajiadu(NowBookName)
			if ( NowSite = "wudilong" )
				NowIndexURL := oBook.Search_wudilong(NowBookName)
		} else {
			NowIndexURL := TmpURL 
		}
		if ( NowIndexURL = "" ) {
			TrayTip, %NowSite%:, 未搜索到目录地址
			return
		}
		tmphtml := A_windir . "_" . NowSite . "_" . NowBookName . ".bdlist"
		oIndex := oBook._GetBookNewPages(NowIndexURL, tmphtml)
	}

	Guicontrol, text, TmpURL, %NowIndexURL%
	Guicontrol, , TmpURL, %NowIndexURL%
	Guicontrol, Hide, Content
	Guicontrol, Show, TieBaLV
	
	loop, % oIndex.MaxIndex()
		LV_Add("", oIndex[A_index,1], oIndex[A_index,2])
	LV_ModifyCol(2, "SortDesc")

	if ( PageName = "" )
		GuiControl, Focus, TieBaLV
	else {
		GuiControl, , PageFilter, %PageName%
		TmpNamexkd = %PageName%
		stringsplit, xfsk_, TmpNamexkd, %A_space%
		GuiControl, text, PageFilter, %xfsk_1% ; 设置文本为第一字段，一般为xxx章
		GuiControl, Focus, PageFilter
	}
return

SelectTiezi:
	if ( A_GuiEvent = "DoubleClick" ) { ; 双击条目，获取索引地址
		NowRowNum := A_EventInfo
		LV_GetText(NowTitle, NowRowNum, 1)
		LV_GetText(NowURL, NowRowNum, 2)
		Guicontrol, hide, TieBaLV
		Guicontrol, show, Content
		NowFullURL := GetFullURL(NowURL, NowIndexURL)
		Guicontrol, text, TmpURL, %NowFullURL%
		Guicontrol, , PageName, %NowTitle%
		GuiControl, Focus, BtnTmpNR
	}
return


FilterTmpList: ; 过滤列表
	GuiControlGet, PageFilter
	LV_Delete()
	loop, % oIndex.MaxIndex()
	{
		if instr(oIndex[A_index,1], PageFilter)
		{
			LV_Add("", oIndex[A_index,1], oIndex[A_index,2])
		} else {
			if ( PageFilter = "" )
				LV_Add("", oIndex[A_index,1], oIndex[A_index,2])
		}
	}
	GuiControl, Focus, TieBaLV
return

GetTmpNR:  ; 获取内容
	Gui, Page:submit, nohide
	if instr(TmpURL, ".baidu.")
	{
		tmphtml := A_windir . "_TieBa_" . A_now . ".html"
		runwait, wget.exe -O %tmphtml% %TmpURL%, %A_scriptdir%\bin32
		FileRead, html, %tmphtml%
		FileDelete, %tmphtml%
		GuiControl, , Content, % tiezi_process(html)
		GuiControl, Focus, Content
	} else {
		HTML := oBook.DownURL(TmpURL)
		PageContent := oBook._GetPageContent(HTML, 0, TmpURL) ; 处理HTML得到结果
		GuiControl, , Content, %PageContent%
		GuiControl, Focus, Content
	}
return

ProcTmpNR: ; 处理文本
	GuiControlGet, NowContent, , Content
	stringreplace, NowContent, NowContent, `n`n, `n, A
	stringreplace, NowContent, NowContent, 　, , A
	stringreplace, NowContent, NowContent, `n%A_space%, `n, A
	NewContent := ""
	loop, parse, NowContent, `n, `r
		NewContent .= RegExReplace(A_loopfield, "i)^[""　 ★]*") . "`n"
	stringreplace, NewContent, NewContent, `n`n, `n, A
	loop, 5 {  ; 去除头部回车符
		stringleft, HeadChar, NewContent, 1
		if ( HeadChar= "`n" or HeadChar = "`r" )
			StringTrimLeft, NewContent, NewContent, 1
	}
	GuiControl, , Content, %NewContent%
return

SavePageInfo:  ; 保存内容到数据库
	Gui, Page:Submit
	Gui, Page:Destroy
	CharCount := strlen(Content) ; 更新内容长度
	oDB.EscapeStr(Content)
	oDB.Exec("update Page set BookID=" . BookID . " , Name='" . PageName . "' , URL='" . PageURL . "' , CharCount=" . CharCount . " , Content=" . Content . " where ID = " . PageID)
	If ! instr(Content, ".gif|")
	{
		PicDir := oBook.PicDir
		FileDelete, % PicDir . "\" . BookID . "\" . PageID . "_*" ; 更新本章时，删除可能存在的图片文件
	}
return

GetTieBaList(html)
{
	stringreplace, html, html, `r, , A
	stringreplace, html, html, `n, , A
	stringreplace, html, html, <a, `n<a, A
	LV_Delete()
	oIndex := []   ; 名称,URL
	oIndexCount := 0
	loop, parse, html, `n, `r
	{
		if ! instr(A_loopfield, "class=""j_th_tit""")
			continue
		FF_1 := "" , FF_2 := ""
		RegExMatch(A_loopfield, "Ui)<a href=""([^""]+)"".*""j_th_tit"">([^<]+)</a>", FF_)
		if ( FF_2 != "" ) {
			++oIndexCount
			oIndex[oIndexCount,1] := FF_2
			oIndex[oIndexCount,2] := "http://tieba.baidu.com" . FF_1
		}
	}
	return, oIndex
}

tiezi_process(html) { ; 百度贴吧帖子处理
	StringReplace, html, html, `r, , A
	StringReplace, html, html, `n, , A
	regexmatch(html, "Ui)""author"":{""id"":([0-9]+),.*""floor"":1,", LZ_)
	StringReplace, html, html, "author", `n"author", A
	NewContent := ""
	loop, parse, html, `n, `r
	{
		if ! instr(A_loopfield, """author"":{""id"":" . LZ_1 . ",""")   ; 过滤非楼主的发言
			continue
		XX_1 := ""
		RegExMatch(A_loopfield, "Ui)d_post_content"">(.*)</div></cc><br/>", XX_)
		NewContent .= XX_1 . "`n★★★★★★★★★★★★★★★★★★★★★★★★★★★★`n"
	}
	StringReplace, NewContent, NewContent, <br><br><br>, `n, A
	StringReplace, NewContent, NewContent, <br><br>, `n, A
	StringReplace, NewContent, NewContent, <br>, `n, A
	NewContent := RegExReplace(NewContent, "Ui)<[^>]+>", "") ; 删除 html标签
	return, NewContent
}

PageGuiClose:
PageGuiEscape:
	Gui, Page:Destroy
return

; --------
FaRGUICreate:
	Gui, FaR:New
	Gui, FaR:Add, ComboBox, x106 y10 w150 h20 Simple R9 vFindStr, 书|小说|手打|更新|百度|小时|com|【|】|『|xing
	Gui, FaR:Add, Button, x6 y10 w90 h30 vFindPageStr gFaRPageStr Default, 查找(&F)
	Gui, FaR:Add, Button, x6 y50 w90 h30 vReplacePageStr gFaRPageStr, 替换(&R)
	Gui, FaR:Add, Edit, x6 y90 w90 h50 vReplaceStr
	; Generated using SmartGUI Creator 4.0
	Gui, FaR:Show, h152 w265, 内容字段 查找 / 替换
Return

FaRPageStr:
	Gui, FaR:Submit
	LastControl := A_GuiControl
	Gui, FaR:Destroy
	Gui, 1:Default
	oLVDown.Switch()
	oLVDown.ReGenTitle()
	oLVDown.Clean()
	oDB.GetTable("select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and page.content like '%" . FindStr . "%' order by page.ID ", oTable)
	oLVDown.Switch()
	If ( LastControl = "FindPageStr" ) {
		loop, % oTable.rowcount
			LV_Add("",oTable.Rows[A_index][1],oTable.Rows[A_index][2],oTable.Rows[A_index][3],oTable.Rows[A_index][4])
	}
	If ( LastControl = "ReplacePageStr" ) {
		odb.Exec("BEGIN;")
		loop, % oTable.rowcount
		{
			SB_SetText("替换字符串: (" . FindStr  . " -> " . ReplaceStr . ")  进度: " . A_index . " / " . oTable.rowcount)
			LV_Add("",oTable.Rows[A_index][1],oTable.Rows[A_index][2],oTable.Rows[A_index][3],oTable.Rows[A_index][4])
			NowPageID := oTable.Rows[A_index][4]
			oDB.GetTable("select Content from page where ID =" . NowPageID, oXX)
			NowContent := oXX.rows[1,1]
			stringreplace, NowContent, NowContent, %FindStr%, %ReplaceStr%, A
			odb.EscapeStr(NowContent)
			odb.Exec("update page set Content = " . NowContent . " where id=" . NowPageID)
		}
		odb.Exec("COMMIT;")
	}
	oLVDown.Switch()
	LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
return

FaRGuiClose:
FaRGuiEscape:
	Gui, FaR:Destroy
return
; --------
CfgGUICreate:
	Gui, Cfg:New
	Gui, Cfg:Add, GroupBox, x6 y10 w240 h50 cBlue, ID|URL
	Gui, Cfg:Add, Edit, x16 y30 w40 h20 disabled vCfgID, 0
	Gui, Cfg:Add, Edit, x56 y30 w180 h20 vCFGURL, paitxt

	Gui, Cfg:Add, Button, x256 y20 w80 h30 vCFGSave gEditCfgInfo, 保存(&S)

	Gui, Cfg:Add, GroupBox, x6 y70 w160 h160 cBlue, Index RE|DelStr
	Gui, Cfg:Add, Edit, x16 y90 w140 h20 vIndexRE
	Gui, Cfg:Add, Edit, x16 y120 w140 h100 vIndexDelStr
	Gui, Cfg:Add, GroupBox, x176 y70 w160 h160 cBlue, Page RE|DelStr
	Gui, Cfg:Add, Edit, x186 y90 w140 h20 vPageRE
	Gui, Cfg:Add, Edit, x186 y120 w140 h100 vPageDelStr
	Gui, Cfg:Add, GroupBox, x6 y240 w330 h120 cBlue, Cookie
	Gui, Cfg:Add, Edit, x16 y260 w310 h90 vConfigCookie
	; Generated using SmartGUI Creator 4.0
	Gui, Cfg:Show, h372 w349, 网站过滤配置
;	GuiControl, Cfg:Focus, CFGURL
Return

EditCfgInfo:
	Gui, Cfg:Submit
	oDB.EscapeStr(IndexRE)
	oDB.EscapeStr(IndexDelStr)
	oDB.EscapeStr(PageRE)
	oDB.EscapeStr(PageDelStr)
	oDB.EscapeStr(ConfigCookie)
	oDB.Exec("update config set ListRangeRE=" . IndexRE . " , ListDelStrList=" . IndexDelStr . " , PageRangeRE=" . PageRE . " , PageDelStrList=" . PageDelStr 
	. " , cookie=" . ConfigCookie
	. " where ID = " . CfgID)
	Gui, Cfg:Destroy
return

CfgGuiClose:
CfgGuiEscape:
	Gui, Cfg:Destroy
return
; --------
IEGUICreate:
	IEHeight := Round(A_ScreenHeight / 4 * 3)
	Gui, IE:New, +HWNDhIE
	GUi, IE:+Resize ; +HWNDWinIE; 创建 GUI
	Gui, IE:Add, ActiveX, w720 h%IEHeight% vPWeb hwndPCTN, Shell.Explorer
	pWeb.Navigate("about:blank")
	Gui, IE:Show, y25, FoxIE L
return

IEGuiSize:
	WinMove, % "ahk_id " . pctn, , 0,0, A_GuiWidth, A_GuiHeight ; 改变IE控件窗口大小
return

IEGuiClose:
IEGuiEscape:
	Gui, IE:Destroy
return
; --------

GuiClose:
GuiEscape:
FoxExitApp:
	if bMemDB
	{
		Gui, Destroy
		FoxMemDB(oDB, DBPath, "Mem2File") ; Mem -> DB
	}
	oDB.CloseDB()
	filedelete, %A_windir%_*.bdlist ; 百度贴吧列表
	ExitApp
return

FoxReload:
	if bMemDB
	{
		Gui, Destroy
		FoxMemDB(oDB, DBPath, "Mem2File") ; Mem -> DB
	}
	oDB.CloseDB()
	reload
return

/*
GuiSize:  ; 当窗口大小发生变化时，变动控件大小位置
	BookW := Round((A_GuiWidth - 15) / 3.7)
	PageW := Round((A_GuiWidth - 15) * 0.729)
	LVH := A_GuiHeight - 30
	PageX := BookW + 10

	GuiControl, Move, LVBook, w%BookW% h%LVH%
	GuiControl, Move, LVPage, w%PageW% h%LVH% x%PageX%
	Gui, ListView, LVBook
	LV_ModifyCol(1, BookW * 0.487), LV_ModifyCol(2, BookW * 0.195) , LV_ModifyCol(3, BookW * 0.146), LV_ModifyCol(4, BookW * 0.048)

	Gui, ListView, LVPage
	LV_ModifyCol(1, PageW * 0.545), LV_ModifyCol(2, PageW * 0.091), LV_ModifyCol(3, PageW * 0.236), LV_ModifyCol(4, PageW * 0.072)
return
*/


MenuInit: ; 菜单栏
	Menu, BookMenu, Add, 写入当前显示顺序, BookMenuAct
	Menu, BookMenu, Add, 刷新显示列表, BookMenuAct
	Menu, BookMenu, Add
	Menu, BookMenu, Add, 显示已删除列表(&D), BookMenuAct
	Menu, BookMenu, Add, 清空已删除列表, BookMenuAct
	Menu, BookMenu, Add
	Menu, BookMenu, Add, 更新所有目录, BookMenuAct
	Menu, BookMenu, Add, 更新所有, BookMenuAct
	Menu, BookMenu, Add, 停止(&S), BookMenuAct
	Menu, BookMenu, Add
	Menu, BookMenu, Add, 更新书架中书籍`tAlt+D, BookMenuAct
	Menu, BookMenu, Add, 更新本书(&G), BookMenuAct
	Menu, BookMenu, Add, 更新本书目录(&T), BookMenuAct
	Menu, BookMenu, Add, 显示最新起点列表(&Q), BookMenuAct
	Menu, BookMenu, Add

	Menu, TransBookMenu, Add, 选中书籍生成PDF, BookMenuAct
	Menu, TransBookMenu, Add, 选中书籍生成Mobi, BookMenuAct
	Menu, TransBookMenu, Add, 选中书籍生成Epub, BookMenuAct
	Menu, TransBookMenu, Add, 选中书籍生成CHM, BookMenuAct
	Menu, TransBookMenu, Add, 选中书籍生成UMD, BookMenuAct
	Menu, TransBookMenu, Add, 选中书籍生成Txt, BookMenuAct
	Menu, BookMenu, Add, 选中书籍转换格式, :TransBookMenu
	Menu, BookMenu, Add, 选中书籍导出到Android, BookMenuAct
	Menu, BookMenu, Add
	Menu, BookMenu, Add, 新增书籍(&N), BookMenuAct
	Menu, BookMenu, Add, 搜索书籍_大家读, BookMenuAct
	Menu, BookMenu, Add, 搜索书籍_PaiTXT, BookMenuAct
	Menu, BookMenu, Add, 搜索书籍_泡书吧, BookMenuAct
	Menu, BookMenu, Add, 搜索书籍_无敌龙, BookMenuAct
	Menu, BookMenu, Add, 删除书籍, BookMenuAct
	Menu, BookMenu, Add
	Menu, BookMenu, Add, 编辑本书信息(&E), BookMenuAct
	Menu, BookMenu, Add, 添加空白章节(&C), BookMenuAct
	Menu, BookMenu, Add
	Menu, BookMenu, Add, 标记: 不再更新, BookMenuAct
	Menu, BookMenu, Add, 标记: 继续更新, BookMenuAct
	Menu, MyMenuBar, Add, 书籍(&B), :BookMenu
; --
	Menu, PageMenu, Add, 删除选中章节[写入已读列表](&D), PageMenuAct
	Menu, PageMenu, Add, 删除选中章节[不写入已读列表](&B), PageMenuAct
	Menu, PageMenu, Add
	Menu, PageMenu, Add, 交换两选中章节ID(&W), PageMenuAct
	Menu, PageMenu, Add
	Menu, PageMenu, Add, 更新本章内容(&G), PageMenuAct
	Menu, PageMenu, Add, 编辑本章信息(&E), PageMenuAct
	Menu, PageMenu, Add, 和谐本章之后的文字(&R), PageMenuAct
	Menu, PageMenu, Add

	Menu, TransPageMenu, Add, 选中章节生成PDF, PageMenuAct
	Menu, TransPageMenu, Add, 选中章节生成Mobi, PageMenuAct
	Menu, TransPageMenu, Add, 选中章节生成Epub, PageMenuAct
	Menu, TransPageMenu, Add, 选中章节生成CHM, PageMenuAct
	Menu, TransPageMenu, Add, 选中章节生成UMD, PageMenuAct
	Menu, TransPageMenu, Add, 选中章节生成Txt, PageMenuAct
	Menu, PageMenu, Add, 选中章节转换格式, :TransPageMenu

	Menu, PageMenu, Add, 选中章节导出到Android, PageMenuAct
	Menu, MyMenuBar, Add, 页面(&X), :PageMenu
; --
	Menu, dMenu, Add, 图片(文件):切割:270*360(手机), SetMenuAct
	Menu, dMenu, Add, 图片(文件):切割:530*665(K3_Mobi), SetMenuAct
	Menu, dMenu, Add, 图片(文件):切割:580*750(K3_Epub), SetMenuAct
	Menu, dMenu, Add ; -
	Menu, dMenu, Add, PDF图片(缓存):切割为手机:285*380, SetMenuAct
	Menu, dMenu, Add, PDF图片(缓存):切割为K3:530*700, SetMenuAct
	Menu, dMenu, Add, PDF图片(缓存):转换, SetMenuAct
	Menu, dMenu, Add ; -
	Menu, dMenu, Add, 比较:起点, SetMenuAct
	Menu, dMenu, Add, 比较:泡书吧, SetMenuAct
	Menu, dMenu, Add, 比较:大家读, SetMenuAct
	Menu, dMenu, Add, 比较:PaiTxt, SetMenuAct
	Menu, dMenu, Add, 比较:笔趣阁, SetMenuAct
	Menu, dMenu, Add, 比较:无敌龙, SetMenuAct
	Menu, dMenu, Add ; -
	Menu, dMenu, Add, 下载器:内置, SetMenuAct
	Menu, dMenu, Add, 下载器:wget, SetMenuAct
	Menu, dMenu, Add, 下载器:curl, SetMenuAct
	Menu, dMenu, Add ; -
	Menu, dMenu, Add, 配置:Sqlite, SetMenuAct
	Menu, dMenu, Add, 配置:INI, SetMenuAct
	Menu, dMenu, Add ; -
	Menu, dMenu, Add, 查看器:IE控件, SetMenuAct
	Menu, dMenu, Add, 查看器:IE, SetMenuAct
	Menu, dMenu, Add, 查看器:AHK_Edit, SetMenuAct
; --
	Menu, DbMenu, Add, 按书籍页数倒序排列, DBMenuAct
	Menu, DbMenu, Add, 重新生成页面ID, DBMenuAct
	Menu, DbMenu, Add, 重新生成书籍ID, DBMenuAct
	Menu, DbMenu, Add
	Menu, DbMenu, Add, 替换文本章节和谐文字(&R), DBMenuAct
	Menu, DbMenu, Add, 编辑正则信息(&E), DBMenuAct
	Menu, DbMenu, Add, 输入要执行的SQL, DBMenuAct
	Menu, DbMenu, Add
	Menu, DbMenu, Add, 显示今天的更新记录, DBMenuAct
	Menu, DbMenu, Add, 显示所有章节记录`tAlt+A, DBMenuAct
	Menu, DbMenu, Add
	Menu, DbMenu, Add, 打开数据库`tAlt+O, DBMenuAct
	Menu, DbMenu, Add, 整理数据库, DBMenuAct
	Menu, DbMenu, Add
	Menu, DbMenu, Add, 导出书籍列表到剪贴板, DBMenuAct
	Menu, DbMenu, Add, 导出QidianID的SQL到剪贴板, DBMenuAct
	Menu, DbMenu, Add, 备份今天的更新, DBMenuAct

	Menu, MyMenuBar, Add, 设置(&Y), :dMenu
	Menu, MyMenuBar, Add, 数据库(&Z), :DbMenu

	Menu, MyMenuBar, Add, 　, DBMenuAct
	Menu, MyMenuBar, Add, 和谐(&R), DBMenuAct
	Menu, MyMenuBar, Add, 整理(&L), DBMenuAct
	Menu, MyMenuBar, Add, 重启(&W), QuickMenuAct
	Menu, MyMenuBar, Add, 　　, DBMenuAct
	Menu, MyMenuBar, Add, 比较(&C), QuickMenuAct
	Menu, MyMenuBar, Add, 比较并更新, BookMenuAct
	Menu, MyMenuBar, Add, 　　　, DBMenuAct
	Menu, MyMenuBar, Add, &Mobi(K3), QuickMenuAct
	Menu, MyMenuBar, Add, &UMD(手机), QuickMenuAct
;	Menu, MyMenuBar, Add, PDF(手机), QuickMenuAct
;	Menu, MyMenuBar, Add, &PDF(K3), QuickMenuAct
;	Menu, MyMenuBar, Add, &Epub(K3), QuickMenuAct
;	Menu, MyMenuBar, Add, 一键制作(&M), QuickMenuAct  ; 暂停使用
	Gui, Menu, MyMenuBar
return

QuickMenuAct:
	if ( A_ThisMenuItem = "重启(&W)" )
		gosub, FoxReload
	If ( A_ThisMenuItem = "比较(&C)" or NowInCMD = "CompareAndDown" ) {
		bNoSwitchLV := 1
		oLVComp.ReGenTitle()
		oLVComp.Clean()

		if (FoxCompSiteType = "qidian") {
			oDB.gettable("select ID, Name, QidianID from book where ( isEnd isnull or isEnd <> 1 ) and URL not like '%qidian%' order by DisOrder", oOldBookList)
			oCOMInfo := []
			oldDownMode := oBook.DownMode
			oBook.DownMode := "curl"
			loop, % oOldBookList.RowCount
			{
				oCOMInfo[A_index,1] := oOldBookList.rows[A_index][2]
				NowURL := "http://www.qidian.com/BookReader/" . oOldBookList.rows[A_index][3] . ".aspx"
				SavePath := A_WinDir . "_QD_" . A_now . ".gif" ; 避免删除，要读取UTF-8
				SB_settext("比较起点: 下载: " . A_index . " / " . oOldBookList.RowCount . " : " . oCOMInfo[A_index,1] . "  : " . NowURL)
				oBook.DownURL(NowURL, SavePath, "-r -7000") ; 下载URL, 返回值为内容
				Fileread, html, *P65001 %SavePath%
				FileDelete, %SavePath%
				FF_1 := "" , FF_2 := ""
				regexmatch(html, "smi)href=""(.*)""[^>]*>([^<]*)<.*<div class=""book_opt"">", FF_)
				oCOMInfo[A_index,2] := FF_2
			}
			oBook.DownMode := OldDownMode
		} else {
			oCOMInfo := oBook.GetSiteBookList(FoxCompSiteType) ; 获取网站书架信息
		}
		oDB.gettable("select ID, Name from book where ( isEnd isnull or isEnd <> 1 ) and URL not like '%qidian%' order by DisOrder", oOldBookList)
		LV_Colors.Detach(hLVPage)
		LV_Colors.Attach(hLVPage, 0, 0)
		loop, % oOldBookList.RowCount
		{
			NowBookID := oOldBookList.rows[A_index][1] , NowBookName := oOldBookList.rows[A_index][2]
			oDB.GetTable("select ID,Name from page where BookID=" . NowBookID " order by ID DESC limit 1", oTmpPage)
			if ( oTmpPage.rowcount = 0 ) {
				NowPageID := "已读"
				oBook.GetBookInfo(NowBookID)
				NowBookDelList := oBook.Book["DelList"]
				stringreplace, NowBookDelList, NowBookDelList, `n`n, `n, A
				loop, parse, NowBookDelList, `n, `r
				{
					if ( A_loopfield = "" )
						continue
					tmpLastLine = %A_loopfield%
				}
				FF_1 := ""
				stringsplit, FF_, tmpLastLine, |
				NowOldPageName := FF_2
			} else {
				NowPageID := oTmpPage.rows[1][1] , NowOldPageName := oTmpPage.rows[1][2]
			}
			NowNewPageName := ""
			loop, % oCOMInfo.MaxIndex()
			{
				if ( oCOMInfo[A_index,1] = NowBookName ) {
					NowNewPageName := oCOMInfo[A_index,2]
					break
				}
			}
			if ( NowNewPageName = "" )
				NowNewPageName := "空"
			if ( NowInCMD != "CompareAndDown" )
				LV_Add("", NowOldPageName, NowNewPageName, NowBookName, NowPageID)
			stringreplace, XXOldPageName, NowOldPageName, %A_space%, , A
			stringreplace, XXOldPageName, XXOldPageName, T, , A
			stringreplace, XXNewPageName, NowNewPageName, %A_space%, , A
			stringreplace, XXNewPageName, XXNewPageName, T, , A
			if ( XXOldPageName != XXNewPageName ) {
				if ( NowInCMD = "CompareAndDown" ) {
					oBook.MainMode := "reader"
					oBook.SBMSG := ""
					oBook.UpdateBook(NowBookID, oLVBook, oLVPage, oLVDown, -9)
				} else {
					LV_Colors.Row(hLVPage, A_index, "", 0x0000FF) ; 颜色:章节名不同
				}
			}
		}
		bNoSwitchLV := 0
		SB_settext("比较书架[下载]完毕!")
	}
	If A_ThisMenuItem in &Epub(K3),&UMD(手机),PDF(手机),&Mobi(K3),&PDF(K3)
	{
		NowInCMD := "ShowAll"  ; 显示所有章节，并全选
		gosub, DBMenuAct
		Gui, ListView, LVPage
		LV_Modify(0, "Select")

		If ( A_ThisMenuItem = "&Epub(K3)" ) {
			oBook.ScreenWidth := 580 , oBook.ScreenHeight := 750  ; K3 Epub 切割尺寸
			NowInCMD := "PageToEpub" ; 页面制作Epub
		}
		If ( A_ThisMenuItem = "PDF(手机)" ) {
			oBook.PDFGIFMode := "SplitPhone" ; PDF图片:切割为手机
			NowInCMD := "PageToPDF" ; 页面制作PDF
		}
		If ( A_ThisMenuItem = "&UMD(手机)" )
			NowInCMD := "PageToUMD" ; 页面制作UMD
		If ( A_ThisMenuItem = "&Mobi(K3)" ) {
			oBook.ScreenWidth := 530 , oBook.ScreenHeight := 665   ; K3 Mobi 切割尺寸
			NowInCMD := "PageToMobi" ; 页面制作PDF
		}
		If ( A_ThisMenuItem = "&PDF(K3)" ) {
			oBook.PDFGIFMode := "SplitK3" ; PDF图片:切割为K3
			NowInCMD := "PageToPDF" ; 页面制作PDF
		}
		gosub, PageMenuAct
	}

/*
	If ( A_ThisMenuItem = "一键制作(&M)" ) {
		oDB.GetTable("select ID, Name, URL from book where isEnd isnull or isEnd <> 1 order by DisOrder", otable)
		sTime := A_TickCount
		MakeCount := otable.rowcount
		loop, %MakeCount% {
			NowBookID := oTable.rows[A_index][1]
			oDB.GetTable("select ID from page where CharCount < 1000 and bookid=" . NowBookID, oTmpB, -1)
			If ( oTmpB.rowcount = 0 ) { ; 纯文本章节
				oBook.SBMSG := "转换任务: " . A_index . " / " . MakeCount . " :Mobi: "
				oBook.Book2MOBIorUMD(NowBookID, "mobi")
			} else {
				oBook.SBMSG := "转换任务: " . A_index . " / " . MakeCount . " :PDF: "
				oBook.Book2PDF(NowBookID)
			}
		}
		eTime := A_TickCount - sTime
		SB_SetText("一键转换任务完成, 耗时: " . eTime)
	}
*/
	NowInCMD := ""
return

SettingMenuCheck:
	If ( FoxCompSiteType = "qidian" ) {
		Menu, dMenu, check, 比较:起点
		Menu, dMenu, Uncheck, 比较:泡书吧
		Menu, dMenu, Uncheck, 比较:大家读
		Menu, dMenu, Uncheck, 比较:PaiTxt
		Menu, dMenu, Uncheck, 比较:无敌龙
		Menu, dMenu, Uncheck, 比较:笔趣阁
	}
	If ( FoxCompSiteType = "paoshu8" ) {
		Menu, dMenu, Uncheck, 比较:起点
		Menu, dMenu, check, 比较:泡书吧
		Menu, dMenu, Uncheck, 比较:大家读
		Menu, dMenu, Uncheck, 比较:PaiTxt
		Menu, dMenu, Uncheck, 比较:无敌龙
		Menu, dMenu, Uncheck, 比较:笔趣阁
	}
	If ( FoxCompSiteType = "dajiadu" ) {
		Menu, dMenu, Uncheck, 比较:起点
		Menu, dMenu, Uncheck, 比较:泡书吧
		Menu, dMenu, check, 比较:大家读
		Menu, dMenu, Uncheck, 比较:PaiTxt
		Menu, dMenu, Uncheck, 比较:无敌龙
		Menu, dMenu, Uncheck, 比较:笔趣阁
	}
	If ( FoxCompSiteType = "paitxt" ) {
		Menu, dMenu, Uncheck, 比较:起点
		Menu, dMenu, Uncheck, 比较:泡书吧
		Menu, dMenu, Uncheck, 比较:大家读
		Menu, dMenu, check, 比较:PaiTxt
		Menu, dMenu, Uncheck, 比较:无敌龙
		Menu, dMenu, Uncheck, 比较:笔趣阁
	}
	If ( FoxCompSiteType = "wudilong" ) {
		Menu, dMenu, Uncheck, 比较:起点
		Menu, dMenu, Uncheck, 比较:泡书吧
		Menu, dMenu, Uncheck, 比较:大家读
		Menu, dMenu, Uncheck, 比较:PaiTxt
		Menu, dMenu, check, 比较:无敌龙
		Menu, dMenu, Uncheck, 比较:笔趣阁
	}
	If ( FoxCompSiteType = "biquge" ) {
		Menu, dMenu, Uncheck, 比较:起点
		Menu, dMenu, Uncheck, 比较:泡书吧
		Menu, dMenu, Uncheck, 比较:大家读
		Menu, dMenu, Uncheck, 比较:PaiTxt
		Menu, dMenu, Uncheck, 比较:无敌龙
		Menu, dMenu, check, 比较:笔趣阁
	}
	; ---
	If ( oBook.ScreenWidth = 270 ) {
		Menu, dMenu, check, 图片(文件):切割:270*360(手机)
		Menu, dMenu, Uncheck, 图片(文件):切割:530*665(K3_Mobi)
		Menu, dMenu, Uncheck, 图片(文件):切割:580*750(K3_Epub)
	}
	If ( oBook.ScreenWidth = 530 ) {
		Menu, dMenu, Uncheck, 图片(文件):切割:270*360(手机)
		Menu, dMenu, check, 图片(文件):切割:530*665(K3_Mobi)
		Menu, dMenu, Uncheck, 图片(文件):切割:580*750(K3_Epub)
	}
	If ( oBook.ScreenWidth = 580 ) {
		Menu, dMenu, Uncheck, 图片(文件):切割:270*360(手机)
		Menu, dMenu, Uncheck, 图片(文件):切割:530*665(K3_Mobi)
		Menu, dMenu, check, 图片(文件):切割:580*750(K3_Epub)
	}
	; ---
	If ( oBook.PDFGIFMode = "normal" ) {
		Menu, dMenu, check, PDF图片(缓存):转换
		Menu, dMenu, Uncheck, PDF图片(缓存):切割为K3:530*700
		Menu, dMenu, Uncheck, PDF图片(缓存):切割为手机:285*380
	}
	If ( oBook.PDFGIFMode = "SplitK3" ) {
		Menu, dMenu, Uncheck, PDF图片(缓存):转换
		Menu, dMenu, check, PDF图片(缓存):切割为K3:530*700
		Menu, dMenu, Uncheck, PDF图片(缓存):切割为手机:285*380
	}
	If ( oBook.PDFGIFMode = "SplitPhone" ) {
		Menu, dMenu, Uncheck, PDF图片(缓存):转换
		Menu, dMenu, Uncheck, PDF图片(缓存):切割为K3:530*700
		Menu, dMenu, check, PDF图片(缓存):切割为手机:285*380
	}
	; ---
	If ( oBook.DownMode = "BuildIn" ) {
		Menu, dMenu, check, 下载器:内置
		Menu, dMenu, Uncheck, 下载器:WGET
		Menu, dMenu, Uncheck, 下载器:CURL
	}
	If ( oBook.DownMode = "wget" ) {
		Menu, dMenu, Uncheck, 下载器:内置
		Menu, dMenu, check, 下载器:WGET
		Menu, dMenu, Uncheck, 下载器:CURL
	}
	If ( oBook.DownMode = "curl" ) {
		Menu, dMenu, Uncheck, 下载器:内置
		Menu, dMenu, Uncheck, 下载器:WGET
		Menu, dMenu, check, 下载器:CURL
	}
	; ---
	If ( oBook.ShowContentMode = "IEControl" ) {
		Menu, dMenu, check, 查看器:IE控件
		Menu, dMenu, Uncheck, 查看器:IE
		Menu, dMenu, Uncheck, 查看器:AHK_Edit
	}
	If ( oBook.ShowContentMode = "IE" ) {
		Menu, dMenu, Uncheck, 查看器:IE控件
		Menu, dMenu, check, 查看器:IE
		Menu, dMenu, Uncheck, 查看器:AHK_Edit
	}
	If ( oBook.ShowContentMode = "BuildIn" ) {
		Menu, dMenu, Uncheck, 查看器:IE控件
		Menu, dMenu, Uncheck, 查看器:IE
		Menu, dMenu, check, 查看器:AHK_Edit
	}
	; ---
	If ( oBook.CFGMode = "sqlite" ) {
		Menu, dMenu, check, 配置:Sqlite
		Menu, dMenu, Uncheck, 配置:INI
	}
	If ( oBook.CFGMode = "ini" ) {
		Menu, dMenu, Uncheck, 配置:Sqlite
		Menu, dMenu, check, 配置:INI
	}
return
; }

; {
BookMenuAct:
	If ( A_ThisMenuItem = "更新书架中书籍`tAlt+D" or A_ThisMenuItem = "比较并更新" ) {
		NowInCMD := "CompareAndDown"
		gosub, QuickMenuAct
	}
	If ( A_ThisMenuItem = "更新本书目录(&T)" or A_ThisMenuItem = "更新本书(&G)" ) {
		oLVBook.LastRowNum := oLVBook.GetOneSelect()
		NowBookID := oLVBook.GetOneSelect(3)
		If ( A_ThisMenuItem = "更新本书目录(&T)" )
			oBook.MainMode := "update"
		If ( A_ThisMenuItem = "更新本书(&G)" )
			oBook.MainMode := "reader"
		oBook.SBMSG := ""
		bNoSwitchLV := 1
		oBook.UpdateBook(NowBookID, oLVBook, oLVPage, oLVDown, -9)
		bNoSwitchLV := 0
	}
	If ( A_ThisMenuItem = "更新所有" or A_ThisMenuItem = "更新所有目录" or NowInCMD = "UpdateAll" ) {
		OldMainMode := oBook.MainMode
		If ( A_ThisMenuItem = "更新所有" or NowInCMD = "UpdateAll" )
			oBook.MainMode := "reader" ; 逐章下载, 影响更新书的模式
		If ( A_ThisMenuItem = "更新所有目录" )
			oBook.MainMode := "update"
		oDB.gettable("select ID, Name from book where isEnd isnull or isEnd <> 1 order by DisOrder", oUpdateList)
		UpdateCount := oUpdateList.rowcount
		sTime := A_TickCount
		oLVDown.Clean()
		bNoSwitchLV := 1
		loop, %UpdateCount% {
			oBook.SBMSG := "当前: " . A_index . " / " . UpdateCount . " : "
			oBook.UpdateBook(oUpdateList.rows[A_index][1], oLVBook, oLVPage, oLVDown, -9)
			If ( oBook.isStop = 1 )
				Break
		}
		bNoSwitchLV := 0
		oBook.isStop := 0
		eTime := A_TickCount - sTime
		SB_settext("更新完毕所有书籍 : 共 " . UpdateCount . " 本，耗时: " . eTime . " ms")
		oBook.MainMode := OldMainMode
	}
	If ( A_ThisMenuItem = "停止(&S)" )
		oBook.isStop := 1
	If ( A_ThisMenuItem = "显示最新起点列表(&Q)" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		oBook.GetBookInfo(NowBookID)
		NowListURL := "http://www.qidian.com/BookReader/" . oBook.book["QiDianID"] . ".aspx"
		oLVDown.Clean()
		oLVDown.focus()
		bNoSwitchLV := 1
		oBook.UpdateBook(NowBookID, oLVBook, oLVPage, oLVDown, NowListURL)
		bNoSwitchLV := 0
	}
	If ( A_ThisMenuItem = "删除书籍" ) {
		BookID := oLVBook.GetOneSelect(3)
		oBook.GetBookInfo(BookID)
		BookName := oBook.Book["Name"]
		msgbox, 4, 删除确认, ID: %BookID%  书名: %BookName%`n`n确定要删除本书？
		Ifmsgbox, no
			return
		if (BookID = "" or BookID = 0) {
			SB_SetText("删除失败: BookID错误，请选中一本书后选择菜单删除")
			return
		}
		; 先删除章节记录，如果有的话
		PicDir := oBook.PicDir
		FileRemoveDir, %PicDir%\%BookID%, 1
		oDB.Exec("Delete From Page where BookID = " . BookID)
		oDB.Exec("Delete From Book where ID = " . BookID)
		SB_SetText("删除完毕: " . BookName)
	}
	If ( A_ThisMenuItem = "新增书籍(&N)" or A_ThisMenuItem = "编辑本书信息(&E)" ) {
		If ( A_ThisMenuItem = "新增书籍(&N)" ) {
			oDB.exec("insert into book (Name, URL) values ('BookName', 'http://XXXXXXXXX')")
			oDB.LastInsertRowID(BookID)
		}
		If ( A_ThisMenuItem = "编辑本书信息(&E)" )
			BookID := oLVBook.GetOneSelect(3)
		oBook.GetBookInfo(BookID)
		BookName := oBook.Book["Name"]
		QidianID := oBook.Book["QidianID"]
		URL := oBook.Book["URL"]
		DelList := oBook.Book["DelList"]
		gosub, BookGUICreate
	}
	if ( instr(A_ThisMenuItem, "搜索书籍_") ) {
		NowName := oLVBook.GetOneSelect(1)
		inputbox, NowBookName, 搜索书籍, 请输入书名:, , 500, 130, , , , , %NowName%
		If ( A_ThisMenuItem = "搜索书籍_泡书吧" )
			NowURL := oBook.Search_paoshu8(NowBookName)
		If ( A_ThisMenuItem = "搜索书籍_PaiTXT" )
			NowURL := oBook.Search_paitxt(NowBookName)
		If ( A_ThisMenuItem = "搜索书籍_无敌龙" )
			NowURL := oBook.Search_wudilong(NowBookName)
		If ( A_ThisMenuItem = "搜索书籍_大家读" )
			NowURL := oBook.Search_dajiadu(NowBookName)
		Clipboard = %NowURL%
		SB_SetText("书名: " . NowBookName . "  目录地址: " . NowURL)
	}
	If ( A_ThisMenuItem = "刷新显示列表" ) {
		sTime := A_TickCount
		BookCount := oBook.ShowBookList(oLVBook)
		SB_settext(bMemDB . " 查询耗时: " . ( A_TickCount - sTime) . " ms  书籍数: " . BookCount)
	}
	If ( A_ThisMenuItem = "写入当前显示顺序" ) {
		oLVBook.focus()
		oDB.Exec("BEGIN;")
		Loop % LV_GetCount()
		{
			LV_GetText(NowBookID, A_Index, 3)
			oDB.Exec("update book set DisOrder = " . A_index . " where ID = " . NowBookID)
		}
		oDB.Exec("COMMIT;")
		SB_SetText("当前显示顺序已经写入数据库")
	}
	If ( A_ThisMenuItem = "标记: 不再更新" )
		oBook.MarkBook(oLVBook.GetOneSelect(3), "不再更新")
	If ( A_ThisMenuItem = "标记: 继续更新" )
		oBook.MarkBook(oLVBook.GetOneSelect(3), "继续更新")

	If ( A_ThisMenuItem = "添加空白章节(&C)" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		NowBookName := oLVBook.GetOneSelect(1)
		oDB.Exec("insert into page (BookID, Name, URL) Values (" . NowBookID . ", '" . NowBookName . "', 'FoxAdd.html')")
		oDB.LastInsertRowID(LastInsrtRowID)
		SB_SetText("添加空白章节完毕, PageID: " . LastInsrtRowID)
	}
	If ( A_ThisMenuItem = "清空已删除列表" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		msgbox, 260, 确认,你确定要清空该书已删除列表？
		Ifmsgbox, yes
			oDB.Exec("update Book set DelURL=null where ID = " . NowBookID)
		SB_SetText("已清空已删除列表: " . NowBookID)
	}
	If ( A_ThisMenuItem = "显示已删除列表(&D)" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		oBook.GetBookInfo(NowBookID)
		oLVPage.ReGenTitle()
		oLVPage.Clean()
		DeleteList := oBook.book["DelList"]
		stringreplace, sjdfkfs, DeleteList, `n, , UseErrorLevel
		lastNum := ErrorLevel - 10
		loop, parse, DeleteList, `n, `r
		{
			If ( A_loopfield = "" )
				continue
			Stringsplit, FF_, A_LoopField, |, %A_space%
			if (A_index > lastNum)
				LV_Add("",FF_2, 0, FF_1, 0)
		}
		LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
		SB_SetText("记录条数: " . oTable.RowCount)
	}

	If ( instr(A_ThisMenuItem, "选中书籍生成") ) {
		If ( A_ThisMenuItem = "选中书籍生成PDF" )
			NowTransMode := "PDF"
		If ( A_ThisMenuItem = "选中书籍生成Mobi" )
			NowTransMode := "Mobi"
		If ( A_ThisMenuItem = "选中书籍生成Epub" )
			NowTransMode := "epub"
		If ( A_ThisMenuItem = "选中书籍生成CHM" )
			NowTransMode := "CHM"
		If ( A_ThisMenuItem = "选中书籍生成UMD" )
			NowTransMode := "UMD"
		If ( A_ThisMenuItem = "选中书籍生成Txt" )
			NowTransMode := "Txt"
		sTime := A_TickCount
		aIDList := oLVBook.GetSelectList(3)
		NowSelectCount := aIDList.MaxIndex()
		If ( NowSelectCount = "" )
			return
		oBook.SBMSG := ""
		loop, %NowSelectCount% {
			NowID := aIDList[A_index]
			oBook.SBMSG := "转换任务: " . A_index . " / " . NowSelectCount . " : "
			If ( NowTransMode = "PDF" )
				oBook.Book2PDF(NowID)
			else
				oBook.Book2MOBIorUMD(NowID, NowTransMode)
		}
		eTime := A_TickCount - sTime
		SB_SetText("转 " . NowTransMode . " 任务完成, 耗时: " . eTime)
	}
	If ( A_ThisMenuItem = "选中书籍导出到Android" ) {
		sTime := A_TickCount
		aIDList := oLVBook.GetSelectList(3)
		NowSelectCount := aIDList.MaxIndex()
		If ( NowSelectCount = "" )
			return
		oFoxBook66 := new FoxBookToAnd66(oBook, oDB)
		oFoxBook66.AddBooks(aIDList)
		SB_SetText("导出到Android完毕, 耗时: " . ( A_TickCount - sTime ))
	}
	BookCount := oBook.ShowBookList(oLVBook) ; 刷新左侧的列表
	NowInCMD := ""
return
; }
PageMenuAct:
	If ( instr(A_ThisMenuItem, "选中章节生成") or instr(NowInCMD , "PageTo") )
	{
		If ( A_ThisMenuItem = "选中章节生成PDF" or NowInCMD = "PageToPDF" )
			TmpMod := "PDF"
		If ( A_ThisMenuItem = "选中章节生成Mobi" or NowInCMD = "PageToMobi")
			TmpMod := "Mobi"
		If ( A_ThisMenuItem = "选中章节生成Epub" or NowInCMD = "PageToEpub" )
			TmpMod := "epub"
		If ( A_ThisMenuItem = "选中章节生成CHM" )
			TmpMod := "CHM"
		If ( A_ThisMenuItem = "选中章节生成UMD" or NowInCMD = "PageToUMD" )
			TmpMod := "UMD"
		If ( A_ThisMenuItem = "选中章节生成Txt" )
			TmpMod := "Txt"
		aPageIDList := oLVPage.GetSelectList(4)
		PageCount := aPageIDList.MaxIndex()
		If ( PageCount = "" or PageCount = 0 )
			return
		; 保存路径
		oBook.GetPageInfo(aPageIDList[1])
		oBook.GetBookInfo(oBook.page["BookID"])
		If ( AllPageFileNameMod = "All" )
			SavePath := "C:\etc\all." . TmpMod
		else
			SavePath := "C:\" . oBook.book["name"] . "." . TmpMod
		sTime := A_TickCount
		oBook.SBMSG := "任务: 选定章节列表转" . TmpMod . ": " . oBook.Book["Name"] . " : "
		If ( TmpMod = "PDF" )
			oBook.Pages2PDF(aPageIDList, SavePath)
		If TmpMod in Mobi,epub,CHM,UMD,Txt
			oBook.Pages2MobiorUMD(aPageIDList, SavePath)
		SB_SetText(oBook.SBMSG . "恭喜，转换完毕  耗时: " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "选中章节导出到Android" ) {
		sTime := A_TickCount
		aIDList := oLVPage.GetSelectList(4)
		NowSelectCount := aIDList.MaxIndex()
		If ( NowSelectCount = "" )
			return
		oFoxBook66 := new FoxBookToAnd66(oBook, oDB)
		oFoxBook66.AddMixPages(aIDList)
		SB_SetText("导出到Android完毕, 耗时: " . ( A_TickCount - sTime ))

	}
	If ( A_ThisMenuItem = "删除选中章节[写入已读列表](&D)" )
		gosub, DeleteselectedPages
	If ( A_ThisMenuItem = "删除选中章节[不写入已读列表](&B)" ) {
		bNotAddintoDelList := 1
		gosub, DeleteselectedPages
	}
	If ( A_ThisMenuItem = "更新本章内容(&G)" ) {
		oLVPage.LastRowNum := oLVPage.GetOneSelect()
		NowPageID := oLVPage.GetOneSelect(4)
		oBook.UpdatePage(NowPageID)
	}
	If ( A_ThisMenuItem = "编辑本章信息(&E)" ) {
		PageID := oLVPage.GetOneSelect(4)
		oBook.GetPageInfo(PageID)
		BookID := oBook.Page["BookID"]
		PageName := oBook.Page["Name"]
		PageURL := oBook.Page["URL"]
		CharCount := oBook.Page["CharCount"]
		Content := oBook.Page["Content"]
		gosub, PageGUICreate
	}
	If ( A_ThisMenuItem = "和谐本章之后的文字(&R)" ) {
		HXPageID := oLVPage.GetOneSelect(4)
		NowInCMD := "HexieAfterPages"
		gosub, DBMenuAct
	}
	If ( A_ThisMenuItem = "交换两选中章节ID(&W)" ) {
		tmpBigPageID := "96969696"
		tIDList := oLVPage.GetSelectList(4)
		NowSelectCount := tIDList.MaxIndex()
		if ( NowSelectCount != 2 ) {
			SB_SetText("错误: 选中ID数不正确 " . NowSelectCount)
			return
		}
		ida := tIDList[1]
		idb := tIDList[2]
		oBook.GetPageInfo(ida)
		bookida := oBook.Page["bookid"]
		oBook.GetPageInfo(idb)
		bookidb := oBook.Page["bookid"]
		if ( bookida != bookidb ) {
			SB_SetText("错误: 选中两ID的BookID不同 " . bookida . " != " . bookidb)
			return
		}
		SB_SetText("开始交换ID: " . ida . " <=> " . idb)
		ChangePageID(ida, tmpBigPageID)
		ChangePageID(idb, ida)
		ChangePageID(tmpBigPageID, idb)
		SB_SetText("ID交换完毕: " . ida . " <=> " . idb . "  请刷新列表以查看效果")
	}
	NowInCMD := ""
return

ChangePageID(PageIDA="", PageIDB="")  ; 将PageIDa(存在) 变为 PageIDb(不存在) , BookID不变
{
	global oBook, oDB

	oBook.GetPageInfo(PageIDA)
	bookdir := oBook.PicDir . "\" . oBook.Page["BookID"]

	ifexist, %bookdir%\%PageIDA%_*  ; 存在图片
	{
		NowContent := oBook.Page["Content"]
		stringreplace, NewContent, NowContent, %PageIDA%_, %PageIDB%_, A
		loop, parse, NowContent, `n, `r
		{
			If ( A_LoopField = "" )
				continue
			UU_1 := "" , UU_2 := ""
			stringsplit, UU_, A_LoopField, |
			stringreplace, NewName, UU_1, %PageIDA%_, %PageIDB%_, A
			FileMove, %bookdir%\%UU_1%, %bookdir%\%NewName%, 1
			oDB.Exec("update Page set ID = " . PageIDB . " , Content='" . NewContent . "' where ID = " . PageIDA)
		}
	} else
		odb.Exec("update page set ID = " . PageIDB . " where id=" . PageIDA)
}

; {
DBMenuAct:
	sTime := A_TickCount
	If ( A_ThisMenuItem = "替换文本章节和谐文字(&R)" or A_ThisMenuItem = "和谐(&R)" or NowInCMD = "HexieAfterPages" ) {
		sTime := A_TickCount
		If ( NowInCMD = "HexieAfterPages" )
			NowTmpAddSql := " and page.id >= " . HXPageID
		else
			NowTmpAddSql := ""
		oDB.GetTable("select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid " . NowTmpAddSql . " and page.CharCount > 1000 order by page.ID", oTable)
		oLVDown.Switch()
		oLVDown.ReGenTitle()
		oLVDown.Clean()

		oHeXie := GetHeXieStr()
		odb.Exec("BEGIN;")
		loop, % oTable.rowcount
		{
			SB_SetText("替换记录的字符串进度: " . A_index . " / " . oTable.rowcount)
			oLVDown.Switch()
			LV_Add("",oTable.Rows[A_index][1],oTable.Rows[A_index][2],oTable.Rows[A_index][3],oTable.Rows[A_index][4])
			NowPageID := oTable.Rows[A_index][4]
			oDB.GetTable("select Content from page where ID =" . NowPageID, oXX)
			NowContent := oXX.rows[1,1]
			loop, % oHeXie.MaxIndex()
				stringreplace, NowContent, NowContent, % oHeXie[A_index,1], % oHeXie[A_index,2] , A
			stringreplace, NowContent, NowContent, `nw`n, , A
			odb.EscapeStr(NowContent)
			odb.Exec("update page set Content = " . NowContent . " where id=" . NowPageID)
		}
		odb.Exec("COMMIT;")
		eTime := A_TickCount - sTime
		SB_settext("所有文本章节替换和谐文字完毕: 共 " . oTable.rowcount . " 条记录  耗时(ms): " . eTime)
	}
	If ( A_ThisMenuItem = "编辑正则信息(&E)" ) {
		gosub, CfgGUICreate
	}
	If ( A_ThisMenuItem = "重新生成书籍ID" ) {
		oBook.ReGenBookID("Desc")
		oBook.ReGenBookID("Asc")
		SB_settext("书籍ID生成完毕, 耗时(ms): " . (A_TickCount - sTime))
		oBook.ShowBookList(oLVBook)
	}
	If ( A_ThisMenuItem = "重新生成页面ID" ) {
		oBook.ReGenPageID("Desc")
		oBook.ReGenPageID("Asc")
		SB_settext("页面ID生成完毕, 耗时(ms): " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "按书籍页数倒序排列" ) {
		oBook.ReGenBookID("Desc", "select ID From Book order by ID Desc")
		oBook.ReGenBookID("Asc", "select book.ID from Book left join page on book.id=page.bookid group by book.id order by count(page.id) desc,book.ID")
		oDB.Exec("update Book set Disorder=ID")
		SB_settext("按书籍页数倒序排列 并 生成书籍ID完毕, 耗时(ms): " . (A_TickCount - sTime))
		oBook.ShowBookList(oLVBook)
	}
	If ( A_ThisMenuItem = "导出QidianID的SQL到剪贴板" ) {
		oDB.GetTable("select name,QidianID from book order by DisOrder", otable)
		loop, % oTable.rowcount
			TmpList .= "update Book set QidianID='" . oTable.Rows[A_index][2] . "' where name = '" . oTable.Rows[A_index][1] . "';`r`n"
		clipboard = %TmpList%
		TmpList := ""
		SB_settext("QidianID的SQL 已导出到 剪贴板")
	}
	If ( A_ThisMenuItem = "导出书籍列表到剪贴板" ) {
		oDB.GetTable("select name,url from book order by DisOrder", otable)
		loop, % oTable.rowcount
			TmpList .= oTable.rows[A_index][1] . ">" . oTable.Rows[A_index][2] . "`n"
		clipboard = %TmpList%
		TmpList := ""
		SB_settext("书籍列表 已导出到 剪贴板")
	}
	If ( A_ThisMenuItem = "显示今天的更新记录" or A_ThisMenuItem = "显示所有章节记录`tAlt+A" or NowInCMD = "ShowAll" ) {
		If ( A_ThisMenuItem = "显示今天的更新记录" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and page.DownTime > " . A_YYYY . A_MM . A_DD  . "000000 order by page.bookid,page.ID"
		If ( A_ThisMenuItem = "显示所有章节记录`tAlt+A" or NowInCMD = "ShowAll" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid order by page.bookid,page.ID"
		oLVDown.ReGenTitle()
		oLVDown.Clean()
		oDB.GetTable(SQLstr, oTable)
		LastItemBookName := "" , BookCount := 0
		LV_Colors.Detach(hLVPage)
		GuiControl, -Redraw, %hLVPage%
		LV_Colors.Attach(hLVPage, 0, 0)
		loop, % oTable.rowcount
		{
			LV_Add("",oTable.Rows[A_index][1],oTable.Rows[A_index][2],oTable.Rows[A_index][3],oTable.Rows[A_index][4])
			If ( oTable.rows[A_index][3] != LastItemBookName ) { ; 不同书
				++BookCount
				if ( BookCount & 1 ) ; 间隔一行
					NewColor := "0xCCFFCC"
				else
					NewColor := "0xCCFFFF"
			}
			LastItemBookName := oTable.rows[A_index][3]
			If ( oTable.rows[A_index][2] < 1000 ) ; 图片章节颜色
				LV_Colors.Row(hLVPage, A_index, NewColor, 0xFF0000) ; 颜色:行文字颜色
			else
				LV_Colors.Row(hLVPage, A_index, NewColor, "") ; 颜色:行颜色( 间隔)
		}
		GuiControl, +Redraw, %hLVPage%
		LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
		SB_SetText("记录条数: " . oTable.RowCount)
	}
	If ( A_ThisMenuItem = "备份今天的更新" ) {
		IfExist, C:\etc
			nSaveDir := "C:\etc"
		else
			nSaveDir := "C:"
		SQLstr := "select book.id,page.ID,page.name from book,Page where book.id=page.bookid and page.DownTime > " . A_YYYY . A_MM . A_DD  . "000000 order by page.ID"
		oDB.GetTable(SQLstr, oTable)
		TodaysPageCount := oTable.RowCount
		loop, %TodaysPageCount% {
			SB_SetText("备份任务: " . A_index . " / " . TodaysPageCount . " : " . oTable.Rows[A_index][3])
			NowSrcName := oBook.PicDir . "\" . oTable.Rows[A_index][1]  . "\" . oTable.Rows[A_index][2]
			NowSaveBookDir := nSaveDir . "\FoxPic\" . oTable.Rows[A_index][1]
			NowTarName := NowSaveBookDir . "\" . oTable.Rows[A_index][2]
			IfNotExist, %NowSaveBookDir%
				Filecreatedir, %NowSaveBookDir%
			Filecopy, %NowSrcName%_*, %NowTarName%_*
		}
		Filecopy, %DBPath%, %nSaveDir%\FoxBook.db3
		Filecopy, %A_ScriptFullPath%, %nSaveDir%\%A_ScriptName%
		SB_SetText("完成备份任务: 共 " TodaysPageCount . " 章")
	}
	If ( A_ThisMenuItem = "整理数据库" or A_ThisMenuItem = "整理(&L)" ) {  ; 按钮: 整理数据库
		PicDir := oBook.PicDir ; 删除空白文件夹
		loop, %PicDir%\*, 2, 0
			FileRemoveDir, %PicDir%\%A_LoopFileName%, 0
		FileRemoveDir, %PicDir%, 0

		;　当是内存数据库时，存盘
		SB_SetText("开始整理数据库，请稍等...")
		FileGetSize, StartSize, %DBPath%, K
		if bMemDB
		{
			oDB.Exec("vacuum")
			FoxMemDB(oDB, DBPath, "Mem2File") ; Mem -> DB
			TmpSBText := "内存数据库存盘完毕, "
		} else {
			oDB.Exec("vacuum")
			if ( EndSize > 5000 ) {  ; 当数据库大小小于5M的时候仅释放大小，不备份
				TmpSBText := ""
			} else {
				Filecopy, %DBPath%, %DBPath%.old, 1
				TmpSBText := "数据库文件备份完毕, "
			}
		}
		FileGetSize, EndSize, %DBPath%, K
		SB_SetText("空白文件夹删除完毕, " . TmpSBText . "释放大小(K): " . ( StartSize - EndSize ) . "   现在大小(K): " . EndSize, 1)
	}
	If ( A_ThisMenuItem = "打开数据库`tAlt+O" )
		run, %DBPath%
	If ( A_ThisMenuItem = "输入要执行的SQL" ) {
		InputBox, ExtraSQL, 输入SQL语句, 请输入你希望Exec的SQL语句:`n表:[book] [page] [config]`ndelete from page where content like '`%●●`%', , 400, 150, , , , , delete from page where charcount < 9000
		if ( ExtraSQL = "" or ExtraSQL = " " )
			return
		oDB.Exec(ExtraSQL)
		Traytip, 已执行:, %ExtraSQL%
		oBook.ShowBookList(oLVBook)
	}
	NowInCMD := ""
return
; }
SetMenuAct:
	If ( A_ThisMenuItem = "比较:起点" )
		FoxCompSiteType := "qidian"
	If ( A_ThisMenuItem = "比较:泡书吧" )
		FoxCompSiteType := "paoshu8"
	If ( A_ThisMenuItem = "比较:大家读" )
		FoxCompSiteType := "dajiadu"
	If ( A_ThisMenuItem = "比较:PaiTxt" )
		FoxCompSiteType := "paitxt"
	If ( A_ThisMenuItem = "比较:无敌龙" )
		FoxCompSiteType := "wudilong"
	If ( A_ThisMenuItem = "比较:笔趣阁" )
		FoxCompSiteType := "biquge"
	; ---
	If ( A_ThisMenuItem = "图片(文件):切割:270*360(手机)" )
		oBook.ScreenWidth := 270 , oBook.ScreenHeight := 360
	If ( A_ThisMenuItem = "图片(文件):切割:530*665(K3_Mobi)" )
		oBook.ScreenWidth := 530 , oBook.ScreenHeight := 665   ; mobi split
	If ( A_ThisMenuItem = "图片(文件):切割:580*750(K3_Epub)" )
		oBook.ScreenWidth := 580 , oBook.ScreenHeight := 750   ; mobi split
	; ---
	If ( A_ThisMenuItem = "PDF图片(缓存):转换" )
		oBook.PDFGIFMode := "normal"
	If ( A_ThisMenuItem = "PDF图片(缓存):切割为K3:530*700" )
		oBook.PDFGIFMode := "SplitK3"
	If ( A_ThisMenuItem = "PDF图片(缓存):切割为手机:285*380" )
		oBook.PDFGIFMode := "SplitPhone"
	; ---
	If ( A_ThisMenuItem = "下载器:内置" )
		oBook.DownMode := "BuildIn"
	If ( A_ThisMenuItem = "下载器:wget" )
		oBook.DownMode := "wget"
	If ( A_ThisMenuItem = "下载器:curl" )
		oBook.DownMode := "curl"
	; ---
	If ( A_ThisMenuItem = "查看器:IE控件" )
		oBook.ShowContentMode := "IEControl"
	If ( A_ThisMenuItem = "查看器:IE" )
		oBook.ShowContentMode := "IE"
	If ( A_ThisMenuItem = "查看器:AHK_Edit" )
		oBook.ShowContentMode := "BuildIn"
	; ---
	If ( A_ThisMenuItem = "配置:Sqlite" )
		oBook.CFGMode := "sqlite"
	If ( A_ThisMenuItem = "配置:ini" ) {
		IniPath := A_scriptdir . "\RE.ini"
		IfNotExist, %IniPath%
		{
			msgbox, 当前目录下不存在 RE.ini`n使用配置文件失效`n建议使用SQLite内置规则
			return
		} else
			oBook.CFGMode := "ini"
	}
	gosub, SettingMenuCheck
return

GuiContextMenu:
	If ( A_GuiControl = "LVBook" )
		Menu, BookMenu, Show, %A_GuiX%, %A_GuiY%
	If ( A_GuiControl = "LVPage" ) {
		If ( LV_GetCount() > 0 )
			Menu, PageMenu, Show, %A_GuiX%, %A_GuiY%
	}
return

ListViewClick:
	If ( A_gui = 1 and bNoSwitchLV = 0 ) { ; 主窗口下
		Hotkey, IfWinActive, ahk_class AutoHotkeyGUI
		If ( A_GuiEvent == "F" ) { ; 切换LV时
			Gui, ListView, %A_GuiControl%
			If ( A_GuiControl = "LVBook" )
				HotKey, ^A, LVBookSelectAll, on
			If ( A_GuiControl = "LVPage" )
				HotKey, ^A, LVPageSelectAll, on
		}
		If ( A_GuiEvent == "f" ) { ; 失去焦点
			If ( A_GuiControl = "LVBook" )
				HotKey, ^A, LVBookSelectAll, off
			If ( A_GuiControl = "LVPage" )
				HotKey, ^A, LVPageSelectAll, off
		}
		Hotkey, IfWinActive
		If ( A_GuiEvent = "DoubleClick" ){
			If ( A_GuiControl = "LVBook" ) {
				oLVBook.LastRowNum := oLVBook.GetOneSelect()
				NowBookID := oLVBook.GetOneSelect(3)
				oBook.ShowPageList(NowBookID, oLVPage)
			}
			If ( A_GuiControl = "LVPage" ) {
				oLVPage.LastRowNum := oLVPage.GetOneSelect()
				NowPageID := oLVPage.GetOneSelect(4)
				If ( oBook.ShowContentMode = "IEControl" )
					gosub, IEGUICreate
				oBook.ShowPageContent(NowPageID, pWeb)
			}
		}
	}
return

LVBookSelectAll:
	oLVBook.Focus()
	LV_Modify(0, "Select")
return

LVPageSelectAll:
	oLVPage.Focus()
	LV_Modify(0, "Select")
return

DeleteselectedPages:
	sTime := A_TickCount
	aIDList := oLVPage.GetSelectList(4)
	aIDCount := aIDList.MaxIndex()
	If ( aIDCount > 55 )
		SB_settext("选定ID数 > 55 , 使用 单本删除模式(较快) 删除选定的章节...")
	else
		SB_settext("选定ID数 <= 55 , 使用 合集删除模式(较慢) 删除选定的章节...")
	If bNotAddintoDelList
	{
		oBook.DeletePages(aIDList,1) ; 删除章节条目,不写入已删除列表
		bNotAddintoDelList := 0
	} else {
		oBook.DeletePages(aIDList) ; 删除章节条目
	}
	oBook.ShowBookList(oLVBook)
	oLVBook.select(oLVBook.LastRowNum)
	oBook.ShowPageList(oLVBook.GetOneSelect(3), oLVPage)
	SB_settext("恭喜: 选定的章节删除完毕, 耗时: " . ( A_TickCount - sTime ) )
return

#Ifwinactive, ahk_class AutoHotkeyGUI
#If WinActive("ahk_id " . hMain)
; -----备注:
^esc:: gosub, FoxReload
+esc::Edit
!esc:: gosub, GuiClose

^R:: WinSet, ReDraw, , A  ; 重绘窗口
^F:: gosub, FaRGUICreate
^i:: SelectChapter(oLVPage, "Pic") ; 选择图片章节
+Del::gosub, DeleteselectedPages
^Up::
	oLVBook.Focus()
	LV_MoveRow()       ; 向上移动一行
return
^Down::
	oLVBook.Focus()
	LV_MoveRow(false)  ; 向下移动一行
return
^Left:: oLVBook.Focus()
^right:: oLVPage.focus()
!1::CopyInfo2Clip(1)
!2::CopyInfo2Clip(2)
!3::CopyInfo2Clip(3)
!4::CopyInfo2Clip(4)
#If

#If WinActive("ahk_id " . hIE)
CapsLock::
+CapsLock::
	pWeb.document.close()
	If ( A_ThisHotkey = "CapsLock" )
		IESql := ">" , IESec := "asc" , IETip := "末章"
	If ( A_ThisHotkey = "+CapsLock" )
		IESql := "<" , IESec := "desc" , IETip := "首章"
	
	oDB.GetTable("select id from page where id " . IESql . " " . NowPageID . " and bookid = (select bookid from page where id = " . NowPageID . ") order by id " . IESec . " limit 1", oNaberID)
	if ( oNaberID.rows[1,1] = "" )
		pWeb.document.write("<html><head><META http-equiv=Content-Type content=""text/html; charset=utf-8""><title></title></head><body bgcolor=""#eefaee""><center><br><br><br><br><br><br><br><br><font color=""green""><h1>★★★★★★★</h1><h1>★已经到" . IETip . "★</h1><h1>★★★★★★★</h1></font></center></body></html>")
	else {
		NowPageID := oNaberID.rows[1,1]
		oBook.ShowPageContent(NowPageID, pWeb)
	}
return
#If
#Ifwinactive

DescStr(iStr="") ; Add:2013-01-07:倒序输入字符串，针对变态paoshu8文字
{
	AllLen := StrLen(iStr)
	StartPos := 0
	NewStr := ""
	loop {
		NewStr .= SubStr(iStr, StartPos, 1)
		if ( AllLen + StartPos = 1 )
			break
		else
			--StartPos
	}
	return, NewStr
}

CopyInfo2Clip(Num=1) {
	global oLVBook, oBook
	if ( Num = 1 ) {
		Gui, ListView, LVBook
		LV_GetText(NowVar, LV_GetNext(0), Num)
	}
	if ( Num = 2 ) {
		Gui, ListView, LVBook
		LV_GetText(NowBookID, LV_GetNext(0), 3)
		oBook.GetBookInfo(NowBookID)
		NowVar := "http://www.qidian.com/BookReader/" . oBook.Book["QidianID"] . ".aspx"
	}
	if ( Num = 3 ) {
		Gui, ListView, LVPage
		LV_GetText(ShortURL, LV_GetNext(0), Num)
		oLVBook.select(oLVBook.LastRowNum)
		Gui, ListView, LVBook
		LV_GetText(LongURL, LV_GetNext(0), 4)
		NowVar := GetFullURL(ShortURL, LongURL)
	}
	if ( Num = 4 ) {
		Gui, ListView, LVBook
		LV_GetText(NowVar, LV_GetNext(0), Num)
	}
	Clipboard = %NowVar%
	SB_settext("剪贴板: " . NowVar)
}


Class FoxBookToAnd66 {
	BooksDir := ":\mybook66\books"
	BookID := "000000"
	BookName := ""
	BookURL := ""
	BookCount := 0
	PageName := ""
	PageURL := ""
	PageCount := -1
	oFoxBook := ""
	oDB := ""
	BookXMLBody := ""
	__New(oFoxBook, oDB) {
		This.BooksDir := This._DetectDir(This.BooksDir)
		This.oDB := oDB
		This.oFoxBook := oFoxBook
	}
	AddBooks(FoxBookIDList) { ; book ID列表数组[]
		This._AddABook2List(1) ; 清空 list.txt
		loop, % FoxBookIDList.MaxIndex()
			This._AddOneBook(FoxBookIDList[A_index])
	}
	AddMixPages(FoxPageIDList) { ; page ID列表数组[]
		; 依赖: BookURL , NowBookDir(创建目录结构) 
		This.oFoxBook.GetPageInfo(FoxPageIDList[1]) ; 获取第一章的书籍ID
		This.oFoxBook.GetBookInfo(This.oFoxBook.Page["BookID"])
		++This.BookCount
		This.BookID := SubStr("000000" . This.BookCount, -5)
		This.BookName := "Fox" . This.oFoxBook.Book["Name"]
		This.BookURL := This.oFoxBook.Book["URL"]

		This._AddABook2List() ; -> list.txt
		; list.xml
		NowBookDir := This.BooksDir . "\" . This.BookID
		IfExist, %NowBookDir%
			FileRemoveDir, %NowBookDir%, 1 ; 先删除旧目录
		FilecreateDir, %NowBookDir%\contents ; 创建新目录
		; // 读取数据库中Page表并创建内容html，复制gif，写入 list.xml
		loop, % FoxPageIDList.MaxIndex()
		{
			This.oFoxBook.GetPageInfo(FoxPageIDList[A_index]) ; 获取当前章节信息
			++ This.PageCount
			This.PageName := This.oFoxBook.Page["Name"]
			This.PageURL := GetFullURL(This.oFoxBook.Page["URL"], This.BookURL)
			This._AddPage2XML(0) ; 依赖 PageName  PageURL PageCount | BookXMLBody BookName BookURL

			This._AddOneHTML(This.PageName, This.oFoxBook.Page["Content"], This.oFoxBook.PicDir . "\" . This.oFoxBook.page["BookID"], NowBookDir . "\contents")  ; 依赖 PageCount
		}
		This._AddPage2XML(1, NowBookDir . "\list.xml")
	}
	_AddOneBook(FoxBookID=0) {
		This.oDB.gettable("select ID,Name,URL,CharCount,Content from page where BookID = " . FoxBookID, oTable)
		If ( oTable.RowCount = 0 or oTable.RowCount = "" )
			return
		This.oFoxBook.GetBookInfo(FoxBookID)
		++This.BookCount
		This.BookID := SubStr("000000" . This.BookCount, -5)
		This.BookName := "Fox" . This.oFoxBook.Book["Name"]
		This.BookURL := This.oFoxBook.Book["URL"]

		This._AddABook2List() ; -> list.txt
		; list.xml
		NowBookDir := This.BooksDir . "\" . This.BookID
		IfExist, %NowBookDir%
			FileRemoveDir, %NowBookDir%, 1 ; 先删除旧目录
		FilecreateDir, %NowBookDir%\contents ; 创建新目录
		; 获取章节列表，处理
		loop, % oTable.RowCount
		{
			tID := oTable.rows[A_index][1]
			tName := oTable.rows[A_index][2]
			tURL := oTable.rows[A_index][3]
			tCharCount := oTable.rows[A_index][4]
			tContent := oTable.rows[A_index][5]
			++ This.PageCount
			This.PageName := tName
			This.PageURL := GetFullURL(tURL, This.BookURL)
			This._AddPage2XML(0)

			This._AddOneHTML(tName, tContent, This.oFoxBook.PicDir . "\" . FoxBookID, NowBookDir . "\contents")  ; 依赖 PageCount
		}
		This._AddPage2XML(1, NowBookDir . "\list.xml")
	}
	_AddOneHTML(PageName, Content, SrcPageDir, DesPageDir) { ; 依赖 PageCount
		HTMLHead = 
		(join`r`n Ltrim
		<HTML><HEAD><META http-equiv=Content-Type content="text/html; charset=utf-8"><title></title><!--style--></HEAD>
		<BODY text=#000000 vLink=#990000 aLink=#990000 link=#990000 leftMargin=0 topMargin=0 marginheight=0 marginwidth=0 class=Body style='word-break:break-all'>
		<table border="0" height="98" cellpadding="0" cellspacing="0" width=100`% id=main>
		<tr><td width="100`%" align="center" valign="top"><br></td></tr>
		<tr vAlign=center align=center>
		<td height="295"  valign="top" align="left">
		<table cellSpacing=0 borderColorDark=#999999 cellPadding=0 align=center borderColorLight=#ffffff border="0" style="line-height:150`%;" WIDTH="90`%">
		<TBODY>
		<tr vAlign=top align=left>
		<td id=thetd class=thetd>
		<div align="left" style="width: 100`%; height: 132">
		<p align="left">
		<center><font class="article_title">%PageName%</font></center>
		<br>
		<hr size="1" noshade color="#FF9900">
		<span id=content><!--BookContent Start-->

		)
		HTMLFoot := "`r`n<!--BookContent End--><br></span></div></td></tr></TBODY></table></td></tr></table></BODY></HTML>`r`n"
		HTMLBody := ""
		If ( instr(Content, ".gif|") ) { ; 图片章节
			PicCount := -1
			loop, parse, Content, `n, `r
			{
				tt_1 := ""
				stringsplit, tt_, A_loopfield, |
				If ( tt_1 = "" )
					continue
				++PicCount
				NewGIFName := This.PageCount . "_" . PicCount . ".gif"
				FIlecopy, %SrcPageDir%\%tt_1% , %DesPageDir%\%NewGIFName%
				HTMLBody .= "`r`n<img src=""" . NewGIFName . """ />`r`n"
			}
		} else { ; 文本章节
			loop, parse, Content, `n, `r
				HTMLBody .= "<p>　　" . A_loopfield . "</p>`r`n"
		}
		HTMLName := This.PageCount . ".html"
		Fileappend, %HtmlHead%%HTMLBody%%HTMLFoot%, %DesPageDir%\%HTMLName%, UTF-8
	}
	_AddPage2XML(bWriteXML=0, XMLPath="C:\xxx.xml") { ; 依赖 PageName  PageURL PageCount | BookXMLBody BookName BookURL
		If ( bWriteXML = 0 ) {
			This.BookXMLBody .= "`t<chapter title=""" . This.PageName . """ bisdown=""1"" src=""" . This.PageURL . """ sequence=""" . This.PageCount . """/>`r`n"
		} else {
			NowBookName := this.BookName
			NowBookURL := This.BookURL
			LastPageID := This.PageCount
			XMLBody := This.BookXMLBody
			XML =
			(Join`r`n Ltrim
			<?xml version="1.0" encoding="UTF-8"?>
			<book type="novel" title="%NowBookName%" listurl="%NowBookURL%" author="" lastread="0" lastdown="%LastPageID%">
			<brief></brief>

			<volume title="狐狸之卷">
			%XMLBody%
			</volume>

			</book>

			)
			Fileappend, %XML%, %XMLPath%, UTF-8
			This.BookXMLBody := ""
			This.PageCount := -1
		}
	}
	_AddABook2List(bCleanList=0) { ; 依赖 BooksDir, BookID, BookName, BookURL
		ListFilePath := This.BooksDir . "\list.txt"
		NowBookStr := This.BookID . "||" . This.BookName . "||" . This.BookURL . "||`r`n"
		If bCleanList
			FileDelete, %ListFilePath%
		else
			FileAppend, %NowBookStr%, %ListFilePath%, UTF-8
	}
	_DetectDir(TarPath) { ; 探测目标目录
		driveget, dlist, list
		loop, parse, dlist
			IfExist, %A_loopfield%%TarPath%
				tardir = %A_loopfield%%TarPath%
		If ( tardir = "" ) {
			IfExist, C:\etc
				tardir := "C:\etc"
			else
				tardir := "C:"
		}
		return, tardir
	}
}

Class FoxLV {
	Name := "" , FieldSet := []
	LastRowNum := -1
	__New(LVName) {
		This.Name := LVName
	}
	Switch() {
		Gui, ListView, % This.Name
	}
	Focus() {
		this.Switch()
		Guicontrol, Focus, % This.Name
	}
	Clean() {
		This.Switch()
		LV_Delete()
	}
	select(RowNum=0){
		This.Switch()
		LV_Modify(RowNum, "select focus")
	}
	ReGenTitle(){
		This.Switch()
		loop, % This.FieldSet.MaxIndex()
			LV_ModifyCol(A_index, This.FieldSet[A_index,1], This.FieldSet[A_index,2])
	}
	GetOneSelect(FieldNum=-1){
		This.Switch()
		RowNum := LV_GetNext(0)
		If ( FieldNum != -1 ){
			LV_GetText(xx, RowNum, FieldNum)
			return, xx
		} else
			return, RowNum
	}
	GetSelectList(FieldNum=-1) {
		This.Switch()
		aSelectItems := []
		RowNumber := 0 , SelectCount := 0
		Loop {
			RowNumber := LV_GetNext(RowNumber)
			if not RowNumber
				break
			++SelectCount
			If ( FieldNum != -1 ){
				LV_GetText(xx, RowNumber, FieldNum)
				aSelectItems[SelectCount] := xx
			} else
				aSelectItems[SelectCount] := RowNumber
		}
		return, aSelectItems
	}
}

Class Book {
	PicDir := A_scriptdir . "\FoxPic"

	PDFGIFMode := "normal" ; normal | SplitK3 | SplitPhone
	ScreenWidth := 270 , ScreenHeight := 360

	SBMSG := ""
	isStop := 0
	MainMode := "update" ; update reader
	DownMode := "wget" ; BuildIn wget curl
	ShowContentMode := "IEControl" ; IEControl IE BuildIn
	CFGMode := "sqlite" ; sqlite ini
	Book := Object("ID", "空ID"
	, "Name", "空Name"
	, "URL", "空URL"
	, "DelList", "空DelList"
	, "DisOrder", "空DisOrder"
	, "isEnd", "空isEnd"
	, "QidianID", "空QidianID")
	Page := Object("ID", "空"
	, "BookID", "空"
	, "Name", "空"
	, "URL", "空"
	, "CharCount", "空"
	, "Content", "空"
	, "DisOrder", "空"
	, "DownTime", "空")

	oDB := ""
	__New(oDB, PicDir = "", FoxType=0) {
		This.oDB := oDB
		if ( PicDir != "" )
			This.PicDir := PicDir
		if ( FoxType = 0 )
			This.PDFGIFMode := "SplitK3" , This.ScreenWidth := 530 , This.ScreenHeight := 665
		if ( FoxType = 1 )
			This.PDFGIFMode := "SplitPhone" , This.ScreenWidth := 270 , This.ScreenHeight := 360
	}
	ShowBookList(oLVBook) {
		oLVBook.Clean()
		LV_Colors.Detach(This.hLVBook)
		GuiControl, -Redraw, %hLVBook%
		LV_Colors.Attach(This.hLVBook, 0, 0)
		This.oDB.gettable("select book.Name,count(page.id),book.ID,book.URL,book.isEnd from Book left join page on book.id=page.bookid group by book.id order by book.DisOrder",oTable)
		loop, % oTable.RowCount
		{
			LV_Add("", oTable.rows[A_index][1],oTable.rows[A_index][2],oTable.rows[A_index][3],oTable.rows[A_index][4])
			If ( oTable.rows[A_index][2] > 0 )
				LV_Colors.Row(This.hLVBook, A_index, 0xCCFFCC, "") ; 颜色:无章节
			else
				LV_Colors.Row(This.hLVBook, A_index, 0xCCFFFF, "") ; 颜色:有章节
			If oTable.rows[A_index][5]
				LV_Colors.Row(This.hLVBook, A_index, "", 0x008000) ; 颜色:不再更新
		}
		GuiControl, +Redraw, %hLVBook%
		return, oTable.RowCount
	}
	GetCFG(AnyFullURL="http://www.qidian.com/xxx.html") {
		SplitPath, AnyFullURL, , , , , URLSite
		NowCFG := Object("Site", ""
		, "IdxRE", ""
		, "IdxStr", ""
		, "PageRE", ""
		, "PageStr", ""
		, "cookie", "")
		If ( This.CFGMode = "sqlite" ) {
			this.oDB.GetTable("select * from config where Site = '" . URLSite . "'", oTable)
			NowCFG["site"] := oTable.rows[1][2]
			NowCFG["IdxRE"] := oTable.rows[1][3]
			NowCFG["IdxStr"] := oTable.rows[1][4]
			NowCFG["PageRE"] := oTable.rows[1][5]
			NowCFG["PageStr"] := oTable.rows[1][6]
			NowCFG["cookie"] := oTable.rows[1][7]
			if ( oTable.RowCount = 0 )
				This.CFGMode := "ini"
		}
		If ( This.CFGMode = "ini" ) {
			IniPath := A_scriptdir . "\RE.ini"
			NowCFG["site"] := URLSite
			IniRead, XX, %IniPath%, %URLSite%, 列表范围正则, %A_space%
			NowCFG["IdxRE"] := XX
			IniRead, XX, %IniPath%, %URLSite%, 列表删除字符串列表, %A_space%
			NowCFG["IdxStr"] := XX
			IniRead, XX, %IniPath%, %URLSite%, 页面范围正则, %A_space%
			NowCFG["PageRE"] := XX
			IniRead, XX, %IniPath%, %URLSite%, 页面删除字符串列表, %A_space%
			NowCFG["PageStr"] := XX
		}
		return, NowCFG
	}
	DownURL(URL, SavePath="", AddParamet="", bDeleteHTML=true) ; 下载URL, 返回值为内容
	{
		SplitPath, URL, , , FileExt
		If ( SavePath = "" )
			SavePath := A_WinDir . "_Fox_" . A_now . "." . FileExt
		else
			SplitPath, SavePath, , , FileExt
		SplitPath, SavePath, OutFileName, OutDir
		IfNotExist, %OutDir%
			FileCreateDir, %OutDir%
		If ( "wget" = This.DownMode ) {
			loop { ; 下载，直到下载完成
				runwait, wget.exe -c -T 5 -O "%SavePath%" %AddParamet% "%URL%", %A_scriptdir%\bin32 , Min UseErrorLevel
				If ( ErrorLevel = 0 )
					break
				else
					SB_settext("下载错误: 重试地址: " . URL)
			}
		}
		If ( "curl" = This.DownMode ) {
			loop { ; 下载，直到下载完成
				runwait, curl.exe -# -o "%SavePath%" %AddParamet% "%URL%",  %A_scriptdir%\bin32, Min UseErrorLevel
				If ( ErrorLevel = 0 )
					break
				else
					SB_settext("下载错误: " . ErrorLevel . " : 重试地址: " . URL)
			}
		}

		If ( "BuildIn" = This.DownMode ) {
			loop { ; 下载，直到下载完成
				UrlDownloadToFile, %URL%, %SavePath%
				If ( ErrorLevel = 0 )
					break
				else
					SB_settext("下载错误: 重试地址: " . URL)
			}
		}
		If FileExt in gif,png,jpg,jpeg
		{
			oContent := OutFileName . "|" . URL
		} else {
			Fileread, oContent, %SavePath%
			regexmatch(oContent, "Ui)<meta[^>]+charset([^>]+)>", Encode_)
			If instr(Encode_1, "UTF-8")
				Fileread, oContent, *P65001 %SavePath%
			if bDeleteHTML
				FileDelete, %SavePath%
		}
		return, oContent
	}
	GetBookInfo(iBookID) {
		this.oDB.GetTable("select * from book where id = " . iBookID, oTable)
		This.Book["ID"] := oTable.rows[1][1]
		This.Book["Name"] := oTable.rows[1][2]
		This.Book["URL"] := oTable.rows[1][3]
		This.Book["DelList"] := oTable.rows[1][4]
		This.Book["DisOrder"] := oTable.rows[1][5]
		This.Book["isEnd"] := oTable.rows[1][6]
		This.Book["QidianID"] := oTable.rows[1][7]
		return, this.Book
	}
	Book2MOBIorUMD(iBookID, ToF="mobi") {
		IfExist, C:\etc
			SaveDir := "C:\etc"
		else
			SaveDir := "C:"
		This.GetBookInfo(iBookID)

		This.oDB.GetTable("select id from page where bookid = " . iBookID, oTable)
		TmpPageCount := oTable.RowCount
		If ( TmpPageCount = "" or TmpPageCount = 0 )
			return
		oPageList := []
		loop, %TmpPageCount% 
			oPageList[A_index] := oTable.rows[A_index][1]

		This.Pages2MobiorUMD(oPageList, SaveDir . "\" . This.Book["name"] . "." . ToF)
	}
	Book2PDF(iBookID) {
		IfExist, C:\etc
			PDFDir := "C:\etc"
		else
			PDFDir := "C:"
		sTime := A_TickCount
		This.GetBookInfo(iBookID)
		SavePDFPath := PDFDir . "\" . This.Book["name"] . ".pdf"
		This.oDB.gettable("select id,name from page where BookID=" . iBookID, oTable)
		If ( oTable.rowcount = "" or oTable.rowcount = 0 )
			return
		oPageIDList := []
		loop, % oTable.rowcount
			oPageIDList[A_index] := oTable.rows[A_index][1]
		BakSBMSG := This.SBMSG
		This.SBMSG .= This.Book["Name"] . " : "
		This.Pages2PDF(oPageIDList, SavePDFPath) 
		eTime := A_TickCount - sTime
		SB_settext(This.SBMSG . "共 " . oTable.RowCount . " 章节，转为 PDF 完毕，耗时: " . eTime)
		This.SBMSG := BakSBMSG
	}
	ShowPageList(iBookID, oLVPage) {
		LV_Colors.Detach(This.hLVPage)
		GuiControl, -Redraw, %hLVPage%
		LV_Colors.Attach(This.hLVPage, 0, 0)
		This.oDB.gettable("select Name,CharCount,URL,ID from Page where BookID = " . iBookID . " order by DisOrder", oTable)
		oLVPage.ReGenTitle()
		oLVPage.Clean()
		loop, % oTable.RowCount
		{
			LV_Add("", oTable.rows[A_index][1],oTable.rows[A_index][2],oTable.rows[A_index][3],oTable.rows[A_index][4])
			If ( oTable.rows[A_index][2] < 1000 )
				LV_Colors.Row(This.hLVPage, A_index, "", 0x008000) ; 颜色:图片章节
		}
		GuiControl, +Redraw, %hLVPage%
;		LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
		This.GetBookInfo(iBookID)
		SB_settext("选中书籍 ID: " . This.Book["ID"] . "  书名: " . This.Book["Name"] . "  是否停更: " . This.Book["isEnd"] . "　" . This.Book["URL"])
	}
	DeletePages(aIDList, isNotAddIntoDelList=0){ ; 删除页面
		IDCount := aIDList.MaxIndex()
	If ( IDCount > 55 ) { ; 大于 55 个 PageID 就是单部书籍记录删除
		msgbox, 4, 确认删除, 当前选定记录大于55`n判断是 单部书籍，是否删除？, 9
		ifmsgbox, no
			return
		this.GetPageInfo(aIDList[1])
		NowBookID := this.page["BookID"]
		this.GetBookInfo(NowBookID)
		sDelURL := this.book["DelList"]
		NowBookDir := this.PicDir . "\" . NowBookID
		This.oDB.Exec("BEGIN;")
		loop, %IDCount% {
			NowPageID := aIDList[A_index]
			this.GetPageInfo(NowPageID)
			FileDelete, %NowBookDir%\%NowPageID%_* ; 删除图片文件
			sDelURL .= this.Page["URL"] . "|" . this.Page["Name"] . "`n"
			This.oDB.Exec("Delete From Page where ID = " . NowPageID)
		}
		this.oDB.EscapeStr(sDelURL)
		If ! isNotAddIntoDelList
			This.oDB.Exec("update Book set DelURL=" . sDelURL . " where ID = " . NowBookID)
		This.oDB.Exec("COMMIT;")
	} else { ; 合集多记录删除，速度较慢
		PicDir := This.PicDir
		loop, %IDCount% {
			NowPageID := aIDList[A_index]
			this.GetPageInfo(NowPageID)
			NowBookID := This.Page["BookID"]
			FileDelete, %PicDir%\%NowBookID%\%NowPageID%_* ; 删除图片文件
			This.oDB.Exec("Delete From Page where ID = " . NowPageID)
			If ! isNotAddIntoDelList
			{
				this.GetBookInfo(NowBookID)
				sDelURL := this.book["DelList"]
				sDelURL .= this.Page["URL"] . "|" . this.Page["name"] . "`n"
				this.oDB.EscapeStr(sDelURL)
				This.oDB.Exec("update Book set DelURL=" . sDelURL . " where ID = " . NowBookID)
			}
		}
	}
	} ; 删除页面
	MarkBook(iBookID, Mark="") {
		If ( Mark = "不再更新" )
			SQLStr := "update Book set isEnd=1 where ID = " . iBookID
		If ( Mark = "继续更新" )
			SQLStr := "update Book set isEnd=null where ID = " . iBookID
		this.odb.exec(SQLstr)
		SB_SetText("BookID " . iBookID . " 已标记为: " . Mark)
	}
	UpdateBook(iBookID, oLVBook=-9, oLVPage=-9, oLVDown=-9, IndexURL=-9) {
		This.GetBookInfo(iBookID)
		If ( IndexURL = -9 ) ; -9 时，说明为写入数据库模式
			IndexURL := This.book["URL"] , bJustView := 0
		else
			bJustView := 1
		oLVDown.ReGenTitle()
		This.SBMSG .= This.Book["Name"] . " : "

		; 检查是否有空白章节,有就更新
		This.oDB.GetTable("select ID,Name from page where CharCount isnull and BookID=" . iBookID " order by DisOrder", otable)
		If ( oTable.rowcount != "" ) {
			LastSBMSG := This.SBMSG
			This.SBMSG .= "空白章节: "
			loop, % oTable.RowCount
			{
				SB_settext(LastSBMSG . A_index . " / " . oTable.RowCount . " : " . oTable.Rows[A_index][2])
				PageContentSize := This.UpdatePage(oTable.Rows[A_index][1])
			}
			This.SBMSG := LastSBMSG
		}

		SB_settext(This.SBMSG . "下载目录页: " . IndexURL)
		oNewPage := This._GetBookNewPages(IndexURL) ; [Title,URL]
		NewPageCount := oNewPage.MaxIndex()
		If ( NewPageCount = "") {
			SB_settext(This.SBMSG . "无新章节")
			return, 0
		}
		SB_settext(This.SBMSG . "新章节数: " . NewPageCount)
		If ( bJustView = 1 ) { ; 不写入数据库
			oLVDown.Focus()
			lastNum := NewPageCount - 10 ; 显示最后几条
			loop, %NewPageCount%  ; Page
			{
				if (A_index > lastNum)
					LV_Add("",oNewPage[A_index,1], "只读", oNewPage[A_index,2], "不写")
			}
			LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
			return, 0
		}
		If ( This.MainMode = "update" ) { ; 更新模式，仅更新目录
			This.oDB.Exec("BEGIN;")
			loop, %NewPageCount% {
				This.oDB.Exec("INSERT INTO Page (BookID, Name, URL, DownTime) VALUES (" . iBookID . ", '" . oNewPage[A_index,1] . "', '" . oNewPage[A_index,2] . "', " . A_now . ")")
				LV_Add("",oNewPage[A_index,1], "", oNewPage[A_index,2], 0)
			}
			This.oDB.Exec("COMMIT;")
			LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
			This.ShowPageList(iBookID, oLVPage)
			return, 0
		}

		If ( This.MainMode = "reader" ) { ; 更新模式，逐章更新
			LastSBMSG := This.SBMSG
			loop, %NewPageCount% {
				This.oDB.Exec("INSERT INTO Page (BookID, Name, URL, DownTime) VALUES (" . iBookID . ", '" . oNewPage[A_index,1] . "', '" . oNewPage[A_index,2] . "', " . A_now . ")")
				This.oDB.LastInsertRowID(LastRowID)
				oLVDown.Switch()
				LV_Add("", oNewPage[A_index,1], "", This.Book["Name"], LastRowID)
				LastLVRowNum := LV_GetCount()
				LV_Modify(LastLVRowNum, "Vis")

				This.SBMSG := LastSBMSG . A_index . " / " . NewPageCount . " : "
				PageContentSize := This.UpdatePage(LastRowID)
				oLVPage.Switch()
				LV_Modify(LastLVRowNum, "Vis Col2", PageContentSize)
				If ( This.isStop = 1 )
					return
			}
		}
		This.ShowBookList(oLVBook) ; 更新左侧列表
		oLVBook.select(oLVBook.LastRowNum)
		SB_settext(This.SBMSG . "更新完毕!")
	}
	_GetBookNewPages(IndexURL, ExistChapterList="GetIt" ) { ; 分析页面，对比数据库，获取新章节列表
		IfExist, %ExistChapterList%
		{  ;  编辑章节搜索时使用
			Fileread, iHTML, %ExistChapterList%
			regexmatch(iHTML, "Ui)<meta[^>]+charset([^>]+)>", Encode_)
			If instr(Encode_1, "UTF-8")
				Fileread, iHTML, *P65001 %ExistChapterList%
		} else { ; 普通更新
			if ( ExistChapterList = "GetIt" )
				iHTML := This.DownURL(IndexURL)
			else
				iHTML := This.DownURL(IndexURL, ExistChapterList, "", 0)
		}

		oCFG := This.GetCFG(IndexURL) ; "IdxRE", "IdxStr"

		if ( ExistChapterList = "GetIt" ) {
			oBookInfo := This.Book
			This.oDB.GetTable("select URL,Name from page where BookID=" . oBookInfo["ID"], oTable)
			ExistChapterList := oBookInfo["DelList"]
			loop, % oTable.RowCount
				ExistChapterList .= oTable.Rows[A_index][1] . "|" . oTable.Rows[A_index][2] . "`n"
			stringreplace, ExistChapterList, ExistChapterList, `r, , A
			stringreplace, ExistChapterList, ExistChapterList, `n`n, `n, A
		}
		LinkDelList := oCFG["IdxStr"]
		regexmatch(iHTML, oCFG["IdxRE"], Tmp_)
		If Tmp_1
			iHTML := Tmp_1
		stringreplace, iHTML, iHTML, `r, , A
		stringreplace, iHTML, iHTML, `n, , A
		iHTML := RegExReplace(iHTML, "Ui)<!--[^>]+-->", "") ; 删除目录中的注释 针对 niepo
		stringreplace, iHTML, iHTML, <a, `n<a, A
		stringreplace, iHTML, iHTML, 　　, %A_space%%A_space%%A_space%%A_space%, A
		oNewPage := [] , NewItemCount := 0
		loop, parse, iHTML, `n, `r
		{
			If ! instr(A_LoopField, "href")
				continue
			If A_LoopField contains %LinkDelList% ; 删除链接
				continue
			; href="3022768.shtm">引子</a></li>
			regexmatch(A_LoopField, "i)href *= *[""']?([^>""']+)[^>]+> *([^<]+)<", FF_)
			If ! instr(ExistChapterList, FF_1 . "|")
			{	; 当有新 item时，添加到数据库和列表中
				If ( FF_1 = "" or FF_2 = "" )
					continue
				++NewItemCount
				oNewPage[NewItemCount,1] := FF_2  ; Title
				oNewPage[NewItemCount,2] := FF_1  ; URL
			}
		}
		return, oNewPage
	}
	ReGenBookID(Action="Desc", NowSQL="") { ; 修改生成BookID
		If ( Action = "Desc" ) {
			StartID := 55555
			if ( NowSQL = "" )
				NowSQL := "select ID From Book order by DisOrder Desc"
		} else {
			StartID := 1
			if ( NowSQL = "" )
				NowSQL := "select ID From Book order by DisOrder"
		}
		PicDir := This.PicDir
		IDList := This.oDB.GetTable(NowSQL, oTable)
		This.oDB.Exec("BEGIN;")         ; 事务开始
		loop, % oTable.rowcount
		{
			NowOldID := oTable.Rows[A_index][1] , NowNewID := StartID
			If ( NowOldID = "" or NowNewID = "" )
				continue
			This.oDB.Exec("update Book set ID = " . NowNewID . " where ID = " . NowOldID . ";")
			This.oDB.Exec("update Page set BookID = " . NowNewID . " where BookID = " . NowOldID . ";")
			FileMoveDir, %PicDir%\%NowOldID%, %PicDir%\%NowNewID%, 0
			If ( Action = "Desc" )
				--StartID
			else
				++StartID
		}
		This.oDB.Exec("COMMIT;")        ; 事务结束
	}

	GetPageInfo(iPageID) {
		this.oDB.GetTable("select * from Page where id = " . iPageID, oTable)
		This.Page["ID"] := oTable.rows[1][1]
		This.Page["BookID"] := oTable.rows[1][2]
		This.Page["Name"] := oTable.rows[1][3]
		This.Page["URL"] := oTable.rows[1][4]
		This.Page["CharCount"] := oTable.rows[1][5]
		This.Page["Content"] := oTable.rows[1][6]
		This.Page["DisOrder"] := oTable.rows[1][7]
		This.Page["DownTime"] := oTable.rows[1][8]
		This.Book["ID"] := oTable.rows[1][2]
		return, this.Page
	}
	ShowPageContent(iPageID, pWeb="") {
		This.GetPageInfo(iPageID)
		Title := This.Page["Name"]
		TmpTxt := This.Page["Content"]
		If ( This.ShowContentMode = "BuildIn" ) {
			stringreplace, TmpTxt, TmpTxt, `n, `r`n, A
			ListLines
			winwait, ahk_class AutoHotkey, , 3
			ControlSetText, Edit1, %TmpTxt%, ahk_class AutoHotkey
			TmpTxt := ""
		}
		If ( This.ShowContentMode = "IEControl" ) {
			NowHTML := This._CreateHtml(iPageID)
			StringList := "小说,书,章节,手打,更新,百度,小时,com"
			loop, parse, StringList, `,
				stringreplace, NowHTML, NowHTML, %A_loopfield%, <font color=blue><b>%A_loopfield%</b></font>, A  ; 方便去广告
			pWeb.document.focus() ; 写之前调用方便space翻页
			pWeb.document.write(NowHTML)
		}
		If ( This.ShowContentMode = "IE" ) {
			NowHTML := This._CreateHtml(iPageID)
			NowSaveDir := This.PicDir . "\" . This.Page["BookID"]
			URL := NowSaveDir . "\" . This.Page["ID"] . ".html"
			IfNotExist, %NowSaveDir%
				FileCreateDir, %NowSaveDir%
			FileAppend, %NowHTML%, %URL%, UTF-8
			IfExist, %A_ProgramFiles%\Internet Explorer\IEXPLORE.EXE
				run, %A_ProgramFiles%\Internet Explorer\IEXPLORE.EXE -new %URL%, , , oPID
		}
	}
	_CreateHtml(iPageID){
;		This.GetPageInfo(iPageID) ; 调用它的之前调用过,可以不调用
		Title := This.Page["Name"] , TmpTxt := This.Page["Content"]
		BookDir := This.PicDir . "\" . This.Page["Bookid"] . "\"
		HtmlHead =
		(join`n Ltrim
		<html><head>
		<meta http-equiv=Content-Type content="text/html; charset=gb2312">
		<style type="text/css">h2,h3,h4,.FoxPic{text-align:center;}</style>
		<script language=javascript>
			function BS(colorString) {document.bgColor=colorString;}
			var currentpos,timer; 
			function initialize() {timer=setInterval("scrollwindow()",100);} 
			function clr(){clearInterval(timer);} 
			function scrollwindow() {
				currentpos=document.body.scrollTop;
				window.scroll(0,currentpos+=1);
				if (currentpos != document.body.scrollTop) clr();
			} 
			document.onmousedown=clr;
			document.ondblclick=initialize;
		</script>
		<title>Test</title></head><body bgcolor="#eefaee">`n
		<a id="%iPageID%"></a>`n
		<h4>%title%　　
		<a href="javascript:BS('#e9faff');">蓝</a>
		<a href="javascript:BS('#ffffed');">黄</a>
		<a href="javascript:BS('#eefaee');">绿</a>
		<a href="javascript:BS('#fcefff');">粉</a>
		<a href="javascript:BS('#ffffff');">白</a>
		<a href="javascript:BS('#efefef');">灰</a>
		</h4>`n
		<div id="IEContent" class="content" style="font-size:22px; line-height:150`%;">`n`n
		)
		If instr(TmpTxt, iPageID . "_") and instr(TmpTxt, "|")
		{ ; 图片章节
			NowBody := "<div class=""FoxPic"">`n`n"
			loop, parse, TmpTxt, `n, `r
			{
				PP_1 := ""
				stringsplit, pp_, A_LoopField, |, %A_space%
				If ( PP_1 != "" )
					NowBody .= "<img src=""" . BookDir . PP_1 . """ /><hr><br>`n"
			}
			NowBody .= "`n</div>`n"
		} else { ; 文字章节
			If ( TmpTxt = "" )
				return
			loop, parse, TmpTxt, `n, `r
			{
				If ( A_loopfield = "" )
					continue
				NowBody .= "　　" . A_LoopField . "<br>`n"
			}
		}
		return, HtmlHead . NowBody . "`n</div></body></html>`n`n"
	}
	UpdatePage(iPageID=0) {
		This.GetPageInfo(iPageID)
		This.GetBookInfo(This.Page["BookID"])
		NowPageURL := GetFullURL(This.Page["URL"], This.Book["URL"])
		FileDelete, % This.PicDir . "\" . This.Page["BookID"] . "\" . iPageID . "_*" ; 更新本章时，删除可能存在的图片文件
		SB_settext(This.SBMSG . This.Page["Name"] .  ": 下载内容页...")
		iHTML := This.DownURL(NowPageURL)
		PageContent := This._GetPageContent(iHTML, This.Page["ID"], NowPageURL) ; 处理HTML得到结果
		; 针对不同返回值，不同处理方式
		If instr(PageContent, "|http://")  ; 图片处理
		{
			NowImageSaveDir := This.PicDir . "\" . This.Page["BookID"]
			PicCount := 0
			loop, parse, PageContent, `n, `r
			{
				If ( A_loopfield = "" )
					continue
				FF_1 := "" , FF_2 := ""
				stringsplit, FF_, A_loopfield, |, %A_space%
				++PicCount
				SB_settext(This.SBMSG . "图 : " . This.Page["Name"] . " : " . PicCount . " : " . FF_1)
				if ( This.DownMode = "curl" )
					This.DownURL(FF_2, NowImageSaveDir . "\" . FF_1 , "-e " . NowPageURL)
				else
					This.DownURL(FF_2, NowImageSaveDir . "\" . FF_1 , "--referer=" . NowPageURL)
			}
			NowSBMSG := This.SBMSG . "图 : "
		}
		If instr(PageContent, "files.qidian.com")  ; 起点文本处理, 交给下面的文本处理
		{
			oHTML := This.DownURL(PageContent)
			stringreplace, oHTML, oHTML, document.write(', , A
			stringreplace, oHTML, oHTML, <a, , A
			stringreplace, oHTML, oHTML, href=http://www.qidian.com>起点中文网, , A
			stringreplace, oHTML, oHTML, www.qidian.com, , A
			stringreplace, oHTML, oHTML, 欢迎广大书友光临阅读，最新、最快、最火的连载作品尽在起点原创！, , A
			stringreplace, oHTML, oHTML, </a>')`;, , A
			stringreplace, oHTML, oHTML, <p>, `n, A
			stringreplace, oHTML, oHTML, 　　, , A
			PageContent := oHTML , oHTML := ""
			NowSBMSG := This.SBMSG . "文 : "
		}
		; 文本处理, 将PageContent StrSize 写入数据库,并修改LV
		StrSize := StrLen(PageContent)
		This.oDB.EscapeStr(PageContent)
		This.oDB.Exec("update Page set CharCount=" . StrSize . " , Content=" . PageContent . " where ID = " . This.Page["ID"])
		If ( NowSBMSG = "" )
			NowSBMSG := This.SBMSG . "文 : "
		SB_settext(NowSBMSG . This.Page["Name"] . " : 字符数: " . StrSize)
		return, StrSize
	}
	_GetPageContent(iHTML, PageID=0, PageURL="") {
		oCFG := This.GetCFG(PageURL)
		regexmatch(iHTML, oCFG["PageRE"], Tmp_)
		If ( Tmp_1 != "" )
			iHTML := Tmp_1
		stringreplace, iHTML, iHTML, `r, , A
		stringreplace, iHTML, iHTML, `n, , A
		stringreplace, iHTML, iHTML, &nbsp`;, , A
		stringreplace, iHTML, iHTML, 　　, , A
		stringreplace, iHTML, iHTML, <br>, `n, A
		stringreplace, iHTML, iHTML, <br/>, `n, A
		stringreplace, iHTML, iHTML, <br />, `n, A
		stringreplace, iHTML, iHTML, <p>, `n, A
		stringreplace, iHTML, iHTML, </p>, `n, A
		stringreplace, iHTML, iHTML, <div, `n<div, A
		stringreplace, iHTML, iHTML, <img, `n<img, A
		stringreplace, iHTML, iHTML, `n`n, `n, A
		If instr(iHTML, "<img")
		{	; 图片
			PicCount := 0
			loop, parse, iHTML, `n, %A_space%
			{
				If ! instr(A_LoopField, "<img")
					continue
				II_1 := ""
				regexmatch(A_LoopField, "i)src *= *[""']?([^""'>]+)[^>]*>", II_)
				If ( II_1 != "" ) {
					If instr(II_1, "/front.gif")
						continue
					NowGifURL := GetFullURL(II_1, PageURL)
					SplitPath, NowGifURL, , , PicExt
					++PicCount
					oHTML .= PageID . "_" . PicCount . "." . PicExt . "|" . NowGifURL . "`n"
				}
			}
		} else { ; 文字
			If instr(iHTMl, "files.qidian.com")  ; 起点文本处理
				return, iHTML
			iHTML := RegExReplace(iHTML, "Ui)<a [^>]+>[^<]*</a>", "") ; 删除正文中的链接
			iHTML := RegExReplace(iHTML, "Ui)<[^>]+>", "") ; 删除 html标签
			if instr(PageURL, ".paoshu8.")
			{
				if instr(iHTML, "$|$")
				{
				StringReplace, iHTML, iHTML, $|$, `n, A
				NewStr := ""
				loop, parse, iHTML, `n, `r
					NewStr .= DescStr(A_LoopField) . "`n"
				iHTML := NewStr , NewStr := ""
				}
			}
			PageDelStrList := oCFG["PageStr"]       ; 删除页面字符串
			stringreplace, PageDelStrList, PageDelStrList, \n, `n, A
			loop, parse, PageDelStrList, `n, `r
			{
				If ( A_LoopField = "" )
					continue
				stringreplace, iHTML, iHTML, %A_loopfield%, , A
			}
			loop, parse, iHTML, `n, `r
			{
				NowLine = %A_LoopField%
				If ( NowLine = "" )
					continue
				oHTML .= NowLine . "`n"
			}
			iHTML := ""
		}
		stringreplace, oHTML, oHTML, `n`n, `n, A
		return, oHTML
	}
	Pages2MobiorUMD(oPageIDList, SavePath="C:\Fox.Mobi") {
		SplitPath, SavePath, OutFileName, OutDir, OutExt, OutNameNoExt, OutDrive
		If OutExt not in mobi,epub,chm,umd,txt
			return, -1
		This.GetPageInfo(oPageIDList[1])
		This.GetBookInfo(This.Page["BookID"])
		TmpPageCount := oPageIDList.MaxIndex()

		If ( OutExt = "mobi" or OutExt = "epub" )
			oEpub := New FoxEpub(This.Book["Name"])
		If ( OutExt = "chm" )
			oCHM := New FoxCHM(This.Book["Name"])
		If ( OutExt = "umd" )
			oUMD := New FoxUMD(This.Book["Name"])
		If ( OutExt = "txt" )
			sTxt := ""
		TmpMsg := This.SBMSG . oEpub.BookName . " 转 " . OutExt . " : "

		LastBookID := 0
		loop, %TmpPageCount% {
			This.GetPageInfo(oPageIDList[A_index])
			If ( LastBookID = This.Page["BookID"] ) { ; 获取章节标题,根据上次Bookid是否和这次相同来判断是否多本书合集
				NowPageTitle := This.Page["Name"]
			} else {
				This.GetBookInfo(This.Page["BookID"])
				NowPageTitle := "●" . This.Book["Name"] . "●" . This.Page["Name"]
				LastBookID := This.Page["BookID"]
			}
			SB_settext(TmpMsg . A_index . " / " . TmpPageCount)
			If ( OutExt = "mobi" or OutExt = "epub" ) {
				NowContent := This.Page["Content"]
				If ! instr(NowContent, ".gif|")   ; 文本章节
				{
					xxCC := ""
					loop, parse, NowContent, `n, `r
						xxCC .= "　　" . A_loopfield . "<br/>`n"
					oEpub.AddChapter(NowPageTitle, xxCC, oPageIDList[A_index])
				} else { ; 图片章节
					tmpdir := oEpub.TmpDir ; Mobi临时文件目录
					srcgifdir := This.PicDir . "\" . This.Page["BookID"]
					PNGPreFix := tmpdir . "\html\" . oPageIDList[A_index] . "_"
					ChapterHTMLY := ""
					GifpathArray := [] , NowGC := 0
					loop, parse, NowContent, `n, `r
					{
						FF_1 := ""
						stringsplit, FF_, A_loopfield, |
						if ( FF_1 = "" )
							continue
						++NowGC
						GifpathArray[NowGC] := srcgifdir . "\" . FF_1
					}
					gifsplit(PNGPreFix, GifpathArray, This.ScreenWidth, This.ScreenHeight)
					loop, %PNGPreFix%*, 0, 0
						ChapterHTMLY .= "<div><img src=""" . A_LoopFileName . """ alt=""Fox"" /></div>`n"
					oEpub.AddChapter(NowPageTitle, ChapterHTMLY, oPageIDList[A_index])
				}
			}
			If ( OutExt = "chm" ) {
				if ( TmpPageCount = A_index )
					oCHM.isLastChapter := 1
				NowContent := This.Page["Content"]
				If ! instr(NowContent, ".gif|") {  ; 文本章节
					NewContent := ""
					loop, parse, NowContent, `n, `r
						NewContent .= "　　" . A_loopfield . "<br>`n"
					oCHM.AddChapter(NowPageTitle, NewContent)
					NewContent := ""
				} else { ; 图片章节
					tmpdir := oCHM.TmpDir ; CHM临时文件目录
					srcgifdir := This.PicDir . "\" . This.Page["BookID"]
					PNGPreFix := tmpdir . "\p" . oPageIDList[A_index] . "_"
					ChapterHTMLY := ""
					GifpathArray := [] , NowGC := 0
					loop, parse, NowContent, `n, `r
					{
						FF_1 := ""
						stringsplit, FF_, A_loopfield, |
						if ( FF_1 = "" )
							continue
						++NowGC
						GifpathArray[NowGC] := srcgifdir . "\" . FF_1
					}
					gifsplit(PNGPreFix, GifpathArray, This.ScreenWidth, This.ScreenHeight)
					loop, %PNGPreFix%*, 0, 0
						ChapterHTMLY .= "<div><img src=""" . A_LoopFileName . """ /></div>`n"
					ChapterHTMLY .= "`n<!-- A image page splitted by fox -->`n"
					oCHM.AddChapter(NowPageTitle, ChapterHTMLY)
				}
			}
			If ( OutExt = "umd" )
				oUMD.AddChapter(NowPageTitle, This.Page["Content"])
			If ( OutExt = "txt" )
				sTxt .= NowPageTitle . "`n" . This.Page["Content"] . "`n"
		}
		If ( OutExt = "mobi" or OutExt = "epub" ) {
			SB_settext(TmpMsg . "生成" . OutExt . "文件...")
			oEpub.SaveTo(SavePath)
		}
		If ( OutExt = "chm" ) {
			SB_settext(TmpMsg . "生成CHM文件...")
			oCHM.SaveTo(SavePath)
		}
		If ( OutExt = "umd" ) {
			SB_settext(TmpMsg . "生成UMD文件...")
			oUMD.SaveTo(SavePath)
		}
		If ( OutExt = "txt" ) {
			SB_settext(TmpMsg . "生成Txt文件...")
			FileAppend, %sTxt%, %SavePath%
			sTxt := ""
		}
	}
	Pages2PDF(oPageIDList, SavePDFPath="") {
;		FreeImage_FoxInit(True) ; Load Dll
		nPageIDCount := oPageIDList.MaxIndex()
			NowPageID := oPageIDList[1]
		oBook.GetBookInfo(oPageIDList[1]) ; 获取书籍信息
		NowBookName := This.Book["Name"]
		oPDF := new FoxPDF(NowBookName)
		if ( This.PDFGIFMode = "SplitK3" ) {
			oPDF.ScreenWidth := 530 , oPDF.ScreenHeight := 700
			oPDF.TextPageWidth := 250 , oPDF.TextPageHeight := 330 , oPDF.TextTitleFontsize := 12 , oPDF.BodyFontSize := 9.5 , oPDF.BodyLineHeight := 12.5 , oPDF.CalcedOnePageRowNum := 26 ; 26*26字 文本页尺寸 K3
		}
		if ( This.PDFGIFMode = "SplitPhone" ) {
			oPDF.ScreenWidth := 285 , oPDF.ScreenHeight := 380
			oPDF.TextPageWidth := 180 , oPDF.TextPageHeight := 240 , oPDF.TextTitleFontsize := 13.5 , oPDF.BodyFontSize := 12 , oPDF.BodyLineHeight := 14.5 , oPDF.CalcedOnePageRowNum := 16 ; 26*26字 文本页尺寸 K3
		}
		loop, %nPageIDCount% {
			NowPageID := oPageIDList[A_index]
			This.GetPageInfo(NowPageID)
			NowTitle := This.Page["Name"] , NowContent := This.Page["Content"] , NowStrSize := This.Page["CharCount"]
; ------
			If ( NowStrSize > 1000 ) { ; 文本章节
				SB_settext(This.SBMSG . "页面: " . A_index . " / " . nPageIDCount . " :文: " . NowTitle)

				NewContent := "" ; 章节文本处理
				loop, parse, NowContent, `n, `r
				{
					If ( A_loopfield = "" )
						continue
					NewContent .= "　　" . A_loopfield . "`n"
				}
				NowContent := NewContent , NewContent := ""

				hFirstPage := oPDF.AddTxtChapter(NowContent, NowTitle)
			} else { ; 图片章节
				SB_settext(This.SBMSG . "页面: " . A_index . " / " . nPageIDCount . " :图: " . NowTitle)
				GIFPathArray := [] , GIFCount := 0
				loop, parse, NowContent, `n, `r
				{
					If ( A_loopfield = "" )
						continue
					FF_1 := ""
					regexmatch(A_loopfield, "Ui)^(.*\.gif)\|", FF_)
					If ( FF_1 = "" )
						continue
					NowGIFPath := This.PicDir . "\" . This.Page["bookid"] . "\" . FF_1
					IfNotExist, %NowGIFPath%
						continue
					++GIFCount
					GIFPathArray[GIFCount] := NowGIFPath
				}
				if ( This.PDFGIFMode = "normal" )
					hFirstPage := oPDF.AddPNGChapter(GIFPathArray, NowTitle) ; GIFPathArray 为 GIF文件路径 数组
				if ( This.PDFGIFMode = "SplitK3" or This.PDFGIFMode = "SplitPhone" )
					hFirstPage := oPDF.AddGIFChapterAndSplit(GIFPathArray, NowTitle)  ; 切割图片
			}
; ------
		}
		If ( SavePDFPath = "" )
			SavePDFPath := "C:\" . A_now . ".pdf"
		SB_settext(This.SBMSG . "保存PDF文件 -> " . SavePDFPath)
		oPDF.SaveTo(SavePDFPath)
;		FreeImage_FoxInit(False) ; unLoad Dll
	}
	ReGenPageID(Action="Desc") { ; 修改生成PageID
		If ( Action = "desc" )
			StartID := 55555 , NowSQL := "select ID from Page order by BookID,ID Desc"
		else
			StartID := 1 , NowSQL := "select ID from Page order by BookID,ID"
		PicDir := This.PicDir
		This.oDB.GetTable(NowSQL, oTable)
		nPageCount := oTable.RowCount
		This.oDB.Exec("BEGIN;")         ; 事务开始
		ifExist, %PicDir%
			bExistPicDir := 1
		else
			bExistPicDir := 0
		loop, %nPageCount% {
			NowPageID := oTable.Rows[A_index][1]
			SB_settext("正在处理记录: " . A_index . " / " . nPageCount . " : " . NowPageID . " -> " . StartID)
			if bExistPicDir
			{ ; 存在图片章节
				This.GetPageInfo(NowPageID)
				NowBookID := This.Page["BookID"]
				NowContent := This.Page["Content"]
				stringreplace, NewContent, NowContent, %NowPageID%_, %StartID%_, A
				This.oDB.Exec("update Page set ID = " . StartID . " , Content='" . NewContent . "' where ID = " . NowPageID)
				loop, parse, NowContent, `n, `r
				{
					If ( A_LoopField = "" )
						continue
					UU_1 := "" , UU_2 := ""
					stringsplit, UU_, A_LoopField, |
					stringreplace, NewName, UU_1, %NowPageID%_, %StartID%_, A
					FileMove, %PicDir%\%NowBookID%\%UU_1%, %PicDir%\%NowBookID%\%NewName%, 1
				}
			} else { ; 文字章节
				This.oDB.Exec("update Page set ID = " . StartID . " where ID = " . NowPageID . ";")
			}
			If ( Action = "desc" )
				--StartID
			else
				++StartID
		}
		This.oDB.Exec("COMMIT;")        ; 事务结束
	}
	; {
	Search_paoshu8(iBookName="偷天") {	; 搜索目录页地址
		OldDownMode := This.DownMode
		This.DownMode := "wget"
		html := This.DownURL("http://www.paoshu8.com/Book/Search.aspx", "", "--post-data=SearchClass=1&SearchKey=" . iBookName) ; 下载URL, 返回值为内容
		This.DownMode := OldDownMode
		RegExMatch(html, "smUi)href=""(/Html/Book/[0-9]*/[0-9]*/)[0-9]+.shtm""", FF_)
		If ( FF_1 != "" )
			return, "http://www.paoshu8.com" . FF_1 . "List.shtm"
		else
			return, "未找到"
	}
	Search_paitxt(iBookName="偷天") {	; 搜索目录页地址
		OldDownMode := This.DownMode
		This.DownMode := "wget"
		html := This.DownURL("http://www.paitxt.com/modules/article/search.php", "", "--post-data=SearchClass=1&searchkey=" . iBookName . "&searchtype=articlename") ; 下载URL, 返回值为内容
		This.DownMode := OldDownMode
		RegExMatch(html, "smUi)href=""(http://www.paitxt.com/[0-9]*/[0-9]*/)"" target=""_blank"">点击阅读</a>", FF_)
		If ( FF_1 != "" )
			return, FF_1
		else
			return, "未找到"
	}
	Search_wudilong(iBookName="偷天") {	; 搜索目录页地址
		OldDownMode := This.DownMode

		This.DownMode := "wget"
		html := This.DownURL("http://www.wudilong.net/Book/Search.aspx", "", "--referer=http://www.wudilong.net --keep-session-cookies --save-cookies=" . A_windir . "_wudicookie")
		html := This.DownURL("http://www.wudilong.net/Book/Search.aspx", "", "--post-data=""SearchKey=" . iBookName . "&SearchClass=1&button=%BF%EC%CB%D9%CB%D1%CB%F7"" --referer=http://www.wudilong.net --keep-session-cookies --save-cookies=" . A_windir . "_wudicookie --load-cookies=" . A_windir . "_wudicookie")
		FileDelete, %A_windir%_wudicookie

		This.DownMode := OldDownMode
		RegExMatch(html, "smUi)href=""(/Html/Book/[0-9]*/[0-9]*/)[0-9]*.shtml""", FF_)
		If ( FF_1 != "" )
			return, "http://www.wudilong.net" . FF_1 . "List.shtml"
		else
			return, "未找到"
	}
	Search_dajiadu(iBookName="偷天") {	; 搜索目录页地址
		OldDownMode := This.DownMode
		This.DownMode := "wget"
		html := This.DownURL("http://www.dajiadu.net/modules/article/searcha.php", "", "--post-data=searchtype=articlename&searchkey=" . iBookName . "&&Submit=+%CB%D1+%CB%F7+")
		This.DownMode := OldDownMode
		regexmatch(html, "Ui)href=""([^""]*)"">点击阅读</a>", FF_)
		If ( FF_1 != "" )
			return, FF_1
		else
			return, "未找到"
	}
	; }
	; {
	GetSiteBookList(SiteType = "paoshu8") {
		TmpcookiePath := "C:\FoxTmpCookie.txt"

		if ( SiteType = "paoshu8" )
			URLBookShelf := "http://www.paoshu8.com/User/User_BookList.aspx"
		if ( SiteType = "dajiadu" )
			URLBookShelf := "http://www.dajiadu.net/modules/article/bookcase.php"
		if ( SiteType = "paitxt" )
			URLBookShelf := "http://www.paitxt.com/modules/article/bookcase.php"
		if ( SiteType = "wudilong" )
			URLBookShelf := "http://www.wudilong.net/User/User_BookList.aspx"
		if ( SiteType = "biquge" )
			URLBookShelf := "http://www.biquge.com/modules/article/bookcase.php"

		oCFG := This.GetCFG(URLBookShelf) ; 获取cookie内容
		NowCookie := oCFG["cookie"]
		FileDelete, %TmpcookiePath% ; 删除临时cookie文件
		Fileappend, %NowCookie% , %TmpcookiePath% ; 创建临时cookie文件

		OldDownMode := This.DownMode
		This.DownMode := "wget"
		html := This.DownURL(URLBookShelf, "", "-S --load-cookies=""" . TmpcookiePath . """ --keep-session-cookies")
		This.DownMode := OldDownMode

		oRet := [] ; 返回数据对象: 1:书名 2:最新名 3:最新URL 4: 更新日期
		CountRet := 0

		if ( SiteType = "paoshu8" ) {  ; 输入html,输出 对象
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, %A_tab%, , A
			StringReplace, html, html, <ul, `n<ul, A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "class=""ule""")
					continue
				RegExMatch(A_loopfield, "Ui)li2.><a[^>]*>([^<]*)<.*</li>.*li3.*href=""([^""]*)""[^>]*>([^<]*)<.*li5.>([^<]*)<", FF_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := "http://www.paoshu8.com" . FF_2
				oRet[CountRet,4] := FF_4
			}
		
		}
		if ( SiteType = "dajiadu" ) {  ; 输入html,输出 对象
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			StringReplace, html, html, <span class="hottext">新</span>, , A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "checkid")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td[^>]*><a[^>]*>([^<]*)<.*</td>.*<td[^>]*><a[^>]*>([^<]*)</a>.*</td>.*<td.*</td>.*<td.*</td>.*<td.*</td>", FF_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_2
				oRet[CountRet,3] := ""
				oRet[CountRet,4] := ""
			}

		}
		if ( SiteType = "paitxt" ) {  ; 输入html,输出 对象
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "odd")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td[^>]*><a[^>]*>([^<]*)</a>.*</td>.*<td.*</td>.*<td.*href=""([^""]*)""[^>]*>([^<]*)<.*</td>.*<td.*</td>.*<td[^>]*>([^<]*)</td>.*<td.*</td>", FF_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := FF_2
				oRet[CountRet,4] := FF_4
			}
		}
		if ( SiteType = "wudilong" ) {  ; 输入html,输出 对象
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "#bcbec0")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td><td[^>]*><a[^>]*>([^<]*)</a>.*</td><td.*href=""([^""]*)""[^>]*>([^<]*)<.*</td><td.*</td><td[^>]*>([^<]*)</td><td.*</td><td.*</td><td.*</td>", FF_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := "http://www.wudilong.net" . FF_2
				oRet[CountRet,4] := FF_4
			}
		}
		if ( SiteType = "biquge" ) {  ; 输入html,输出 对象
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "odd")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td[^>]*><a[^>]*>([^<]*)</a></td>.*<td.*href=""([^""]*)""[^>]*>([^<]*)<.*</td>.*<td.*</td>.*<td[^>]*>([^<]*)</td>.*<td.*</td>", FF_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := "http://www.biquge.com" . FF_2
				oRet[CountRet,4] := FF_4
			}
		}
		FileDelete, %TmpcookiePath% ; 删除临时cookie文件
		return, oRet
	}
	; }
}

/*
Class ProcessInfo {
	PID := 0 , MemInM := 0 , VMInM := 0
	GetMyPID() {
		This.PID := DllCall("GetCurrentProcessId")
	}
	GetMyMemInfo() {
		for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where ProcessId=" . This.PID)
			This.MemInM := ceil(process.WorkingSetSize / 1024 / 1024) , This.VMInM := ceil(process.PageFileUsage / 1024 / 1024)
	}
}
*/

#include <SQLiteDB_Class>
#Include <LV_Colors_Class>
#include <FoxPDF_Class>
#include <FoxEpub_Class>
#include <FoxUMD_Class>
#include <FoxCHM_Class>

FoxMemDB(oMemDB, FileDBPath, Action="Mem2File") ; 2013-1-9 添加
{
	if ( Action = "Mem2File" ) ; MemDB -> FileDB
		ifExist, %FileDBPath%
			FileMove, %FileDBPath%, %FileDBPath%.old, 1
	oFileDB := new SQLiteDB
	oFileDB.OpenDB(FileDBPath)

	if ( Action = "Mem2File" ) ; MemDB -> FileDB
		oDBFrom := oMemDB , oDBTo := oFileDB
	else ; FileDB -> MemDB
		oDBFrom := oFileDB , oDBTo := oMemDB

	pBackup := DllCall("SQlite3\sqlite3_backup_init", "UInt", oDBTo._Handle, "Astr", "main", "UInt", oDBFrom._Handle, "Astr", "main", "Cdecl Int")
	RetA := DllCall("SQlite3\sqlite3_backup_step", "UInt", pBackup, "Int", -1, "Cdecl Int")
	DllCall("SQlite3\sqlite3_backup_finish", "UInt", pBackup, "Cdecl Int")

	oFileDB.closedb()
	if ( RetA != 101 ) ; SQLITE_DONE
		msgbox, 错误:`nAction: %Action%`nsqlite3_backup_step 返回值: %RetA% 不等于 101:意思全部备份完毕
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

LV_MoveRow(moveup = true) { ; 从英文论坛弄来的函数，功能调整ListView中的条目顺序
   Loop, % (allr := LV_GetCount("Selected"))
      max := LV_GetNext(max)
   Loop, %allr% {
      cur := LV_GetNext(cur)
      If ((cur = 1 && moveup) || (max = LV_GetCount() && !moveup))
         Return
      Loop, % (ccnt := LV_GetCount("Col"))
         LV_GetText(col_%A_Index%, cur, A_Index)
      LV_Delete(cur), cur := moveup ? cur-1 : cur+1
      LV_Insert(cur, "Select Focus", col_1)
      Loop, %ccnt%
         LV_Modify(cur, "Col" A_Index, col_%A_Index%), col_%A_Index% := ""
   }
}

SelectChapter(oLVPage, SelType="Pic") ; 选取章节
{
	TypePoint := 1000  ; 大小分割点
	oLVPage.focus()
	Loop, % LV_GetCount()
	{ ; 获取选定的列表
		LV_GetText(NowSize, A_index, 2)
		If ( SelType = "Pic" And NowSize < TypePoint )
			LV_Modify(A_index, "Select")
		If ( SelType = "Text" And NowSize >= TypePoint )
			LV_Modify(A_index, "Select")
	}
}

FoxInput(wParam, lParam, msg, hwnd)  ; 在特殊控件按下特殊按键的反应
{ ;	tooltip, <%wParam%>`n<%lParam%>`n<%msg%>`n<%hwnd%>`n%A_GuiControl%
	Global
	If ( A_GuiControl = "LVBook" and wParam = 13 ) {
		oLVBook.LastRowNum := oLVBook.GetOneSelect()
		NowBookID := oLVBook.GetOneSelect(3)
		oBook.ShowPageList(NowBookID, oLVPage)
	}
	If ( A_GuiControl = "LVPage" and wParam = 13 ) {
		NowPageID := oLVPage.GetOneSelect(4)
		If ( oBook.ShowContentMode = "IEControl" )
			gosub, IEGUICreate
		oBook.ShowPageContent(NowPageID, pWeb)
	}
	If ( A_GuiControl = "CfgURL" and wParam = 13 ) {
		Gui, Cfg:submit, nohide
		If instr(CFGURL, "http://")
			SplitPath, CFGURL, , , , , CfgSite
		else
			CfgSite := CFGURL
		oDB.GetTable("select * from config where Site like '%" . CfgSite . "%'", oTable)
		Guicontrol, Cfg:, CFGID, % oTable.rows[1][1]
		Guicontrol, Cfg:, CFGURL, % oTable.rows[1][2]
		Guicontrol, Cfg:, IndexRE, % oTable.rows[1][3]
		Guicontrol, Cfg:, IndexDelStr, % oTable.rows[1][4]
		Guicontrol, Cfg:, PageRE, % oTable.rows[1][5]
		Guicontrol, Cfg:, PageDelStr, % oTable.rows[1][6]
		Guicontrol, Cfg:, ConfigCookie, % oTable.rows[1][7]
	}
	If ( A_GuiControl = "PageFilter" and wParam = 13 ) {
		gosub, FilterTmpList
	}
}


gifsplit(pngprefix, GifpathArray, ScreenWidth=350, ScreenHeight=467)
{
	VarSetCapacity(hImageArray, 1024, 0)
	gifPathCount := GifpathArray.MaxIndex()
	VarSetCapacity(gifpathlist, 2560, 0)
	loop, %gifPathCount%
		StrPut(GifpathArray[A_index], (&gifpathlist)+256*(A_Index-1), "CP936")

	ifExist, %A_scriptdir%\bin32\FreeImage.dll
		NowDllDir = %A_scriptdir%\bin32\
	return, dllcall(NowDllDir . "FreeImage.dll\gifsplit"
	, "AStr", pngprefix
	, "Uint", &gifpathlist
	, "short", gifPathCount
	, "short", ScreenWidth
	, "short", ScreenHeight
	, "Uint", 0
	, "Uint", &hImageArray
	, "Cdecl int")
}

; {
GetHeXieStr() {
	HeXieStr =
	(Join`n Ltrim C
	bào,爆
	bà,罢
	bī,逼
	bo,波
	bō,波
	bang,棒
	cū,粗
	cǎo,草
	cào,操
	cháo,潮
	chao,潮
	chā,插
	cha,插
	chī,痴
	chún,唇
	chōu,抽
	chou,抽
	chuáng,床
	chūn,春
	dāi,呆
	dang,荡
	dàng,荡
	dāo,刀
	dòng,洞
	fǎ,法
	féi,肥
	fù,妇
	guān,官
	hán,含
	huā,花
	hua,花
	huá,华
;	hún,混
	hún,魂
	huo,惑
	huò,惑
	jiao,交
	jiāo,娇
	jiāng,江
	jiā,佳
	jīng,精
	jǐng,警
	jī,激
	jìn,禁
	kù,裤
	kao,靠
	liú,流
	lù,露
	1ù,露
	lou,露
	luàn,乱
	1uan,乱
	1ang,浪
	mài,卖
	máo,毛
	mao,毛
	méng,蒙
	mén,门
	mí,迷
	miè,灭
	min,民
	mo,摸
	mō,摸
	nǎi,奶
	nòng,弄
	nong,弄
	nèn,嫩
	nv,女
	qīn,亲
	qiú,求
	rou,肉
	rǔ,乳
	sao,骚
	sāo,骚
	sè,色
	sǐ,死
	sī,私
	shuǎng,爽
	shā,杀
	shè,射
	shì,侍
	tān,贪
	tiǎn,舔
	tǐng,挺
	tuǐ,腿
	tūn,吞
	wēn,温
	wěn,吻
	xī,吸
	xí,袭
	xiao,小
	xìng,性
	xing,性
	xiōng,胸
	xiong,胸
	xuè,血
	xué,穴
	xùe,穴
	yan,艳
	yao,药
	yào,药
	yàn,艳
	yīn,阴
;	yín,淫
	yin,淫
	yé,爷
	yòu,诱
	yù,欲
	zàng,藏
	zhēn,针
	zuì,罪
	zhèng,政
	zhōngyāng,中央
	è,恶
	o阿,啊
	1日,旧
	**不离十,八九不离十
	十有**,十有八九
	『色』,色
	『性』,性
	武动乾坤,
	最新章节,
	………,
	垩,
	圌,
	冇,
	囘,
	龘,
	伱,你
	)
	xx := []
	loop, parse, HeXieStr, `n
	{
		stringsplit, FF_, A_loopfield, `,
		xx[A_index,1] := FF_1 , xx[A_index,2] := FF_2
	}
	return, xx
}

CreateNewDB(oDB) {
	oDB.Exec("Create Table Book (ID integer primary key, Name Text, URL text, DelURL text, DisOrder integer, isEnd integer, QiDianID text)")
	oDB.Exec("Create Table Page (ID integer primary key, BookID integer, Name text, URL text, CharCount integer, Content text, DisOrder integer, DownTime integer)")
	oDB.Exec("Create Table config (ID integer primary key, Site text, ListRangeRE text, ListDelStrList text, PageRangeRE text, PageDelStrList text, cookie text)")

	NovelList := InitBookInfo("NovelList") ; ConfigList
	loop, parse, NovelList, `n
	{
		stringsplit, FF_, A_loopfield, >
		oDB.Exec("INSERT INTO Book (Name, URL) VALUES ('" . FF_1 . "', '" . FF_2 . "')")
	}
	ConfigList := InitBookInfo("ConfigList") ; NovelList
	loop, parse, ConfigList, `n
	{
		FF_1 := "" , FF_2 := "" , FF_3 := "" , FF_4 := "" , FF_5 := ""
		stringsplit, FF_, A_loopfield, @
		oDB.EscapeStr(FF_2)
		oDB.EscapeStr(FF_4)
		oDB.Exec("INSERT INTO config (Site, ListRangeRE, ListDelStrList, PageRangeRE, PageDelStrList) VALUES ('" . FF_1 . "', " . FF_2 . ", '" . FF_3 . "', " . FF_4 . ", '" . FF_5 . "')")
	}
}

InitBookInfo(What2Return="NovelList") ; ConfigList
{
lNovelList =
(join`n
狐闹大唐>http://www.qidian.com/BookReader/1939238.aspx
)
lConfigList =
(Join`n
http://www.qidian.com@smUi)<div id="content">(.*)<div class="book_opt">@/BookReader/vol@smUi)(http://files.*.txt)@
http://www.paoshu8.com@smUi)<div id="BookText">(.*)<div id="End">@@smUi)<div id="BookText"[^>]*>[。]*(.*)<div id="Adsgg2">@http://www.paoshu8.com/\n百度搜索泡书吧阅读最新最全的小说\n小说阅读下载尽在泡书吧中文网更新超快小说更多：
http://www.wudilong.net@smUi)<div id="Content">(.*)<table@/Author/,/Book/@smUi)<div id="BookText">(.*)<br><br><br />@
http://www.paitxt.com@smUi)book_article_texttable(.*)<div class="footer@@smUi)<div id="booktext"><!--go-->(.*)<!--over--></div>@www.paitxt.com\n()\n无弹窗更新快\n◎聪明的孩子记住派小说网超快手打更新派小说网◎\n派小说最快更新，请收藏派小说。
http://www.biquge.com@smUi)<dl>(.*)</dl>@@smUi)<div id="content">(.*)<script>@
http://www.dajiadu.net@smUi)</ul>(.*)<div id="tong">@@smUi)<div id='content'>(.*)<span class="copy">@~~.shushuw.cn-更新首发~~\n(书书屋.shushu5.com最快更新)\n//最快文字更新.shumilou.com无弹窗无广告//
http://www.fkzww.com@smUi)<div id="BookText">(.*)<div align=center>@@smUi)<div id="BookText">(.*)<div align=center>@
http://www.niepo.net@smUi)<table(.*)</table>@@smUi)<div id="content">(.*)涅破小说网www.niepo.net@(wWw.NiEpO.NeT)
http://www.bxwx.cc@smUi)<div class="novel_volume">(.*)<div class="novel_action1">@@smUi)<div class="novel_content">(.*)<!--@
http://www.wcxiaoshuo.com@smUi)min-height:420px;">(.*)<div align="center">@@smUi)nrh.js"></script></div>(.*)=========@
http://www.shenmaxiaoshuo.com@smUi)min-height:420px;">(.*)<div align="center">@@smUi)class="contentbox">(.*)更多手打全文字章节请到@
http://www.16kbook.org@smUi)"BookText">(.*)<div id="ListEnd">@@smUi)<!--开始-->(.*)<!--END-->@
http://www.dukankan.com@smUi)<div class="readerListShow"(.*)<div class="readerListADbox2">@@smUi)<div id="content" style="font-size:16px;">(.*)</div>@
http://www.86zw.com@smUi)<div id="BookText">(.*)<center>@@smUi)<div id="BookText">(.*)<center>@
http://www.89wx.com@smUi)<DIV id=content>(.*)<DIV id="zw">@@smUi)<DIV id="content">(.*)<DIV id=zw>@在百度搜索“89”可以迅速找到我们www.89wx.com
http://www.900hao.com@smUi)<table(.*)</table>@@smUi)<div id="content">(.*)<div id="adbottom@
http://www.zlsy.net.cn@smUi)<table(.*)</table>@@smUi)TXT电子书免费下载网\)(.*)\(致岚书院<a@
http://www.sohubook.com@smUi)<div class="list_box">(.*)<div class="list_clear">@@smUi)readtop.js"></script>(.*)搜狐书库书友1群@wWw.sohubook.CoM
)
; http://www.shulib.com@smUi)<table(.*)</table>@@smUi)<div id="content">(.*)<div id="footlink">@
; http://www.bhdao.com@smUi)<table(.*)</table>@@smUi)<div id="content">(.*)<div style@
	return, l%What2Return%
}
; }
