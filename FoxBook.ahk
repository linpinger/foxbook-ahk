; 2016-08-08 修改

; 若没下面这句，会导致在1.1.8.0版中SQLite出错
#NoEnv
	; 设置PATH环境变量，方便run只使用exe名称
	EnvGet, Paths, PATH
	EnvSet, PATH, C:\bin\bin32`;D:\bin\bin32`;%A_scriptdir%\bin32`;%A_scriptdir%`;%Paths%

	EnvGet, DBPath, DB3PATH ; 从环境变量DB3PATH中获取启动数据库路径
	if ( "" = DBPath )
		DBPath :=  A_scriptdir . "\FoxBook.db3"

	; 判断是否是RamOS以决定临时目录及输出目录
	Ifexist, %A_windir%\system32\drivers\firadisk.sys
		FoxSet := { "TmpDir": "C:\tmp" , "OutDir": "C:\etc" }
	else
		FoxSet := { "TmpDir": A_scriptdir . "\tmp" , "OutDir": A_scriptdir }
	FoxSet["PicDir"] := A_scriptdir . "\FoxPic"
	nowDBnum := 1 ; 切换数据库用

	IfNotExist, % FoxSet["TmpDir"]
		FileCreateDir, % FoxSet["TmpDir"]
	FoxSet["MyPID"] := DllCall("GetCurrentProcessId") ; 本进程PID

	bMemDB := true ; 使用内存数据库

	bOutEbookPreWithAll := true  ; 输出文件名为all_xxxxx.xxx

ObjectInit:
	; 查找书名重复 select * from book where name in(select name from book group by name having count(name)>1) order by name,url,id
	oDB := new SQLiteDB
	if ( bMemDB ) {
		oDB.OpenDB(":memory:")
		FoxMemDB(oDB, DBPath, "File2Mem")
	} else {
		oDB.OpenDB(DBPath)
	}
	FileGetSize, dbfilesize, %DBPath% ; 数据库大小为0新建
	if ( 0 = dbfilesize)
		CreateNewDB(oDB)

	CheckAndFixDB(oDB) ; 查询 表结构并检查是否缺少新增字段，修复它

	oBook := New Book(oDB, FoxSet, 0)

	FoxCompSiteType := getCompSiteType(oDB)

	; 参数个数=0进入GUI，否则进入命令行
	iArgCount = %0%
	if ( iArgCount = 0 )
		gosub, GuiInit
	else
		gosub, CommandProcess
return
; 自动化结束


; { Init
CommandProcess:                ; 执行外部传进来的命令
	iAction = %1%
	iArgA = %2%
	If ( iAction = "" )
		return
	else
		print() ; 初始化 命令行标准输出
	If ( iAction = "-h" or iAction = "h" or iAction = "help" or iAction = "--help" ) {
cmdstr =
(join`n
FoxBook命令行用法: FoxBook [选项] [参数]

  up		更新所有书籍
  ls [b|.p|l|a]	显示书籍章节列表/章节内容
  rm [b|.p]	清空指定书籍所有章节
  sort [a|d]	排序书籍
  sp		排序页面

  toM		转换为Mobi电子书
  toU		转换为UMD电子书
  toE		转换为Epub电子书
  toC		转换为CHM电子书
  toT		转换为Txt电子书
  toP		转换为PDF电子书

  vac		整理压缩数据库
  [-]h		本帮助

)
		print(cmdstr)
	}
	If ( iAction = "up" ) {
		print("开始更新所有书籍`n")
		NowInCMD := "UpdateAll"
		gosub, BookMenuAct
		print("已更新所有书籍`n")
	}
	If ( iAction = "ls" ) {
		if iArgA is alpha
			SQLstr := "select id, charcount, name from page where bookid = " . alpha2integer(iArgA)
		if ( iArgA = "" )
			SQLstr := "select book.id,count(page.id) cc,book.name from Book left join page on book.id=page.bookid group by book.id order by cc"
		if ( iArgA = "a" )
			SQLstr := "select page.id, book.name, page.name from book, page where page.bookid = book.id order by page.Bookid Desc,page.id "
		if ( iArgA = "l" )
			SQLstr := "select page.id, book.name, page.name from book, page where page.bookid = book.id order by page.DownTime Desc,page.id Desc limit 20"
		if iArgA is integer
			SQLstr := "select id, charcount, name from page where bookid = " . iArgA
		if instr(iArgA, ".")
		{
			StringReplace, argtwo, iArgA, ., , A
			if argtwo is alpha
				SQLstr := "select charcount, name, Content from page where id = " . alpha2integer(argtwo)
			if argtwo is integer
				SQLstr := "select charcount, name, Content from page where id = " . argtwo
		}
		oDB.GetTable(SQLstr, oRS)
		outNR := ""
		loop, % oRS.rowcount
			outNR .= oRS.rows[A_index][1] . "`t" . oRS.rows[A_index][2] . "`t" . oRS.rows[A_index][3] . "`n"
		print(outNR)
	}
	If ( iAction = "rm" ) {
		If ( iArgCount < 2 ) {
			print("清除章节后面缺少bookid`n")
			gosub, FoxExitApp
		}
		if iArgA is alpha
			SQLstr := "select id from page where bookid = " . alpha2integer(iArgA)
		if iArgA is integer
			SQLstr := "select id from page where bookid = " . iArgA
		if instr(iArgA, ".")
		{
			StringReplace, argtwo, iArgA, ., , A
			if argtwo is alpha
				SQLstr := "select id from page where id = " . alpha2integer(argtwo)
			if argtwo is integer
				SQLstr := "select id from page where id = " . argtwo
		}
		oDB.GetTable(SQLstr, oIDlist)
		iIDList := []
		loop, % oIDlist.rowcount
			iIDList[A_index] := oIDlist.rows[A_index][1]
		oBook.DeletePages(iIDList) ; 删除章节条目
		if instr(iArgA, ".")
			print("已删除指定章节: " . argtwo . "`n")
		else
			print("已清空书籍 " . iArgA . " 中的所有章节`n")
	}
	If iAction in toM,toE,toU,toC,toT,toP
	{
		if ( iAction = "toM" )
			TmpMod := "mobi"
		if ( iAction = "toE" )
			TmpMod := "epub"
		if ( iAction = "toU" )
			TmpMod := "umd"
		if ( iAction = "toC" )
			TmpMod := "chm"
		if ( iAction = "toT" )
			TmpMod := "txt"
		if ( iAction = "toP" )
			TmpMod := "pdf"
		print("开始转换所有页面到" . TmpMod . "格式`n" )
		oDB.GetTable("select ID from Page order by bookid,ID", oIDlist)
		aPageIDList := []
		loop, % oIDlist.rowcount
			aPageIDList[A_index] := oIDlist.rows[A_index][1]
		If bOutEbookPreWithAll
			SavePath := FoxSet["OutDir"] . "\all_" . FoxCompSiteType . "." . TmpMod
		else
			SavePath := FoxSet["OutDir"] . "\" . oBook.book["name"] . "." . TmpMod
		If iAction in toM,toE,toU,toC,toT
			oBook.Pages2MobiorUMD(aPageIDList, SavePath, FoxCompSiteType)
		if ( iAction = "toP" )
			oBook.Pages2PDF(aPageIDList, SavePath)
		print("已转换所有页面到" . TmpMod . "格式`n" )
	}
	If ( iAction = "sort" ) {
		if ( iArgA = "" or iArgA = "a" or iArgA = "d" ) {
			oBook.ReGenBookID("Desc", "select ID From Book order by ID Desc")
			if ( iArgA = "d" )
				sPar := "desc" , smm := "倒序"
			else
				sPar := "asc" , smm := "顺序"
			oBook.ReGenBookID("Asc", "select book.ID from Book left join page on book.id=page.bookid group by book.id order by count(page.id) " . sPar . ",book.isEnd,book.ID")
			oDB.Exec("update Book set Disorder=ID")
			print("按书籍页数" . smm . "排列 并 生成书籍ID完毕`n")
		} else {
			print("参数需为 a 或 d`n")
		}
	}
	If ( iAction = "sp" ) {
		print("开始生成页面ID`n")
		oBook.ReGenPageID("Desc")
		oBook.ReGenPageID("Asc")
		print("页面ID生成完毕`n")
	}
	If ( iAction = "vac" ) {
		NowInCMD := "SaveAndCompress"
		gosub, DBMenuAct
		print("空白文件夹删除完毕, " . TmpSBText . "释放大小(K): " . ( StartSize - EndSize ) . "   现在大小(K): " . EndSize . "`n")
	}
	NowInCMD := ""
	gosub, FoxExitApp
return

alpha2integer(inST="") ; 使用qwertyuiop表示1234567890
{
	kk := "qwertyuio"
	loop, parse, kk
		StringReplace, inST, inST, %A_LoopField%, %A_index%, A
	StringReplace, inST, inST, p, 0, A
	return, inST
}


GuiInit:
	bNoSwitchLV := 0  ; 状态: 允许切换LV

	; GUI宽度以适应系统变化
	if A_OSVersion in WIN_XP,WIN_2003
		gw := 775
	else
		gw := 783
	Gui, +HWNDhMain ; +Resize
	Gosub, MenuInit
	Gui, Add, ListView, x6 y10 w205 h400 +HwndhLVBook vLVBook gListViewClick AltSubmit, 名称|页数|ID|URL
		LV_ModifyCol(1, 100), LV_ModifyCol(2, 40) , LV_ModifyCol(3, 30), LV_ModifyCol(4, 10)
	Gui, Add, ListView, x216 y10 w550 h400 +HwndhLVPage vLVPage gListViewClick AltSubmit, 名称|字数|URL|ID
		LV_ModifyCol(1, 300), LV_ModifyCol(2, 50), LV_ModifyCol(3, 130), LV_ModifyCol(4, 40)

	Gui, Add, StatusBar, , 欢迎使用哈
	; Generated using SmartGUI Creator 4.0
	Gui, Show, w%gw% h435, FoxBook
	OnMessage(0x4a, "Receive_WM_COPYDATA")  ; 接收另一个脚本传来的字符串
	onmessage(0x100, "FoxInput")  ; 在特殊控件按下特殊按键的反应
	LV_Colors.OnMessage() ; LV颜色


	oBook.hLVBook := hLVBook
	oBook.hLVPage := hLVPage

	oLVBook := new FoxLV("LVBook")
	oLVBook.FieldSet := [[100,"名称"],[40,"页数"],[30,"ID"],[10,"URL"]] ; Book

	oLVPage := new FoxLV("LVPage")
	oLVPage.FieldSet := [[300,"名称"],[50,"字数"],[130,"URL"],[40,"ID"]] ; Page

	oLVDown := new FoxLV("LVPage")
	oLVDown.FieldSet := [[300,"章节"],[50,"字数"],[130,"书名"],[40,"ID"]] ; Down

	oLVComp := new FoxLV("LVPage")
	oLVComp.FieldSet := [[200,"本地章节"],[200,"网站章节"],[95,"书名"],[40,"ID"],[9, "URL"]] ; 比较

	gosub, SettingMenuCheck

	sTime := A_TickCount
	BookCount := oBook.ShowBookList(oLVBook)
	SB_settext(bMemDB . " 查询耗时: " . ( A_TickCount - sTime) . " ms  书籍数: " . BookCount . "  In: " . DBPath)

	gosub, CommandProcess ; 执行外部传进来的命令
	WinSet, ReDraw, , A  ; 重绘窗口
return


; --------
BookGUICreate:
	Gui, Book:New, +Resize
	Gui, Book:Add, GroupBox, x6 y10 w350 h80 cBlue, BookID | BookName | QidianID | URL
	Gui, Book:Add, Edit, x16 y30 w40 h20 disabled vBookID, %BookID%
	Gui, Book:Add, Edit, x66 y30 w130 h20 vBookName, %BookName%
	Gui, Book:Add, Button, x200 y30 w20 h20 gEditBookInfo vSearchNovel, &D
	Gui, Book:Add, Edit, x224 y30 w70 h20 vQidianID, %QidianID%
	Gui, Book:Add, Button, x294 y30 w50 h20 gEditBookInfo vGetQidianID, &QD_ID
	Gui, Book:Add, Edit, x16 y60 w330 h20 vURL, %URL%

	Gui, Book:Add, Edit, x6 y95 w616 h230 0x40000 -Wrap vDelList hwndhDelListEdit, %DelList%

	Gui, Book:Add, Button, x454 y60 w170 h30 gEditBookInfo vCleanLastModified, 清空最后更新时间(&T)
	Gui, Book:Add, Button, x524 y20 w100 h30 gEditBookInfo vShortAndSave, 减肥并保存(&E)
	Gui, Book:Add, Button, x363 y19 w80 h30 gEditBookInfo vShortingStr, 减肥(&F)
	Gui, Book:Add, Button, x364 y60 w80 h30 gEditBookInfo vCleanDelList, 清空(&C)
	Gui, Book:Add, Button, x453 y19 w65 h30 gEditBookInfo vSaveBookInfo, 保存(&S)
	Gui, Book:show, w630 h330, 编辑窗口

	EditJump2End(hDelListEdit) ; 跳转到Edit最后

	Guicontrol, Book:Focus, URL
return

EditJump2End(hEdit)  ; 跳转到Edit最后
{
	SendMessage 0xBA,0,0,,ahk_id %hEdit%
	LineCount := ErrorLevel
	SendMessage 0xB6,0,LineCount,,ahk_id %hEdit%
}

SimplifyDelList(DelList, nLastItem=9) ; 精简已删除列表
{
	StringReplace, DelList, DelList, `r, , A
	StringReplace, DelList, DelList, `n`n, `n, A
	StringReplace, tmpss, DelList, `n, , UseErrorLevel
	linenum := ErrorLevel , tmpss := ""
	if ( linenum < ( nLastItem + 2 ) )
		return, DelList
	
	MaxLineCount := linenum - nLastItem
	NewList := ""
	recCount := 0
	loop, parse, DelList, `n, %A_space%
	{
		if ( instr(A_LoopField, "|") ) {
			++recCount
			if ( recCount > MaxLineCount ) {
				NewList .= A_loopfield . "`n"
			}
		}
	}
	return, NewList
}

EditBookInfo:
	If ( A_GuiControl = "SearchNovel" ) {
		guicontrolget, BookName
		guicontrolget, URL
		TypeCC := ""
		if instr(URL, ".qidian.")
			TypeCC := 1
		ifExist, D:\bin\autohotkey\fox_scripts\novel\BookSearch.ahkl
			run, "D:\bin\autohotkey\fox_scripts\novel\BookSearch.ahkL" %BookName% %TypeCC%
		else
			run, BookSearch.exe BookSearch.ahk %BookName% %TypeCC%
	}
	If ( A_GuiControl = "CleanDelList" ) {
		guicontrol, , DelList
	}
	If ( A_GuiControl = "ShortingStr" or A_GuiControl = "ShortAndSave" ) {
		guicontrolget, DelList
		NewDelList := SimplifyDelList(DelList) ; 精简已删除列表
		guicontrol, , DelList, %NewDelList%
		NewDelList := "" , DelList := ""
		EditJump2End(hDelListEdit) ; 跳转到Edit最后
	}
	If ( A_GuiControl = "GetQidianID" ) {
		guicontrolget, QidianID
		if ( QidianID = "" ) {
			if ( instr(Clipboard, ".qidian.") ) {
				QidianID = %Clipboard%
			} else {
				guicontrolget, BookName
				iJson := oBook.DownURL(qidian_getSearchURL_Mobile(GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(bookname))), "", "<useUTF8>")
				qdid_1 := ""
				regexmatch(iJson, "Ui)""ListSearchBooks"":\[{""BookId"":([0-9]+),""BookName"":""" . bookname . """", qdid_)
				guicontrol, , QidianID, %qdid_1%
			}
		}
		if instr(QidianID, ".qidian.")
			guicontrol, , QidianID, % qidian_getBookID_FromURL(QidianID)
	}
	If ( A_GuiControl = "SaveBookInfo" or A_GuiControl = "ShortAndSave" ) {
		Gui, Book:Submit
		Gui, Book:Destroy
		oDB.EscapeStr(DelList)
		if BookID is integer
			oDB.Exec("update Book set Name='" . BookName . "' , URL='" . URL . "' , QiDianID='" . QiDianID . "' , DelURL=" . DelList . " , LastModified='' where ID = " . BookID)
	}
	If ( A_GuiControl = "CleanLastModified" ) {
		guicontrolget, BookID
		if BookID is integer
			oDB.Exec("update Book set LastModified='' where ID = " . BookID)
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
	Menu, TmpSite, Uncheck, 百度贴吧`tAlt+1
	Menu, TmpSite, Uncheck, 扒书网`tAlt+2
	if ( A_ThisMenuItem = "百度贴吧`tAlt+1" ) {
		Menu, TmpSite, check, 百度贴吧`tAlt+1
		NowSite := "tieba"
	}
	if ( A_ThisMenuItem = "扒书网`tAlt+2" ) {
		Menu, TmpSite, check, 扒书网`tAlt+2
		NowSite := "8shu"
	}
return

PageGUICreate:
	Gui, Page:New, +HwndhPage
	Menu, PageMenuBar, Add, 窗口复制(&C), PageMenuBarAct
	Menu, PageMenuBar, Add, 　　　　, PageMenuBarAct

	Menu, TmpSite, Add, 百度贴吧`tAlt+1, TmpSiteCheck
	if ( NowSite = "" )
		NowSite := "tieba"
	Menu, TmpSite, Add, 扒书网`tAlt+2, TmpSiteCheck
	Menu, PageMenuBar, Add, 网站设置(&T), :TmpSite

	Menu, PageMenuBar, Add, 　　　, PageMenuBarAct
	Menu, PageMenuBar, Add, 获取列表(&I), PageMenuBarAct
	Menu, PageMenuBar, Add, 获取内容(&N), PageMenuBarAct
	Menu, PageMenuBar, Add, 　　, PageMenuBarAct
	Menu, PageMenuBar, Add, 处理内容(&R), PageMenuBarAct
	Gui, Page:Menu, PageMenuBar

	Gui, Page:Add, GroupBox, x6 y10 w620 h80 cBlue, PageID | BookID | Name | URL | CharCount | Mark || TmpURL | PageFilter || Content
	Gui, Page:Add, Button, x536 y3 w80 h20 gCopyWinInfo vBtnCopyWinInfo, 窗口复制(&C)
	Gui, Page:Add, Edit, x16 y30 w40 h20 disabled vPageID, %PageID%
	Gui, Page:Add, Edit, x56 y30 w40 h20 vBookID, %BookID%
	Gui, Page:Add, Edit, x96 y30 w210 h20 vPageName, %PageName%
	Gui, Page:Add, Edit, x306 y30 w140 h20 vPageURL, %PageURL%
	Gui, Page:Add, Edit, x446 y30 w40 h20 vCharCount, %CharCount%
	Gui, Page:Add, Edit, x486 y30 w40 h20 vPageMark, %Mark%

	Gui, Page:Add, Button, x536 y30 w80 h50 gSavePageInfo vSavePageInfo, 保存(&S)

	Gui, Page:Add, checkbox, x16 y60 w40 h20 vCKbGood +checked0, 精&H
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
	ControlGetText, TmpNR, Edit9, ahk_id %hOtherPage%
	Guicontrol, , PageName, %TmpTitle%
	Guicontrol, , Content, %TmpNR%
	TmpNR := "" , TmpTitle := ""
return

GetTmpIndex:  ; 获取索引列表
	Gui, Page:submit, nohide
	oBook.GetBookInfo(BookID)
	NowBookName := oBook.Book["Name"]

	if ( NowSite = "tieba" or NowSite = "8shu" ) {
		if ( NowSite = "tieba" ) {
		stringreplace, NowBookName, NowBookName, 台湾, , A
		if ( CKbGood = 1 ) {
			NowIndexURL := "http://tieba.baidu.com/f?kw=" . NowBookName . "&ie=utf-8&tab=good"
			tmphtml := FoxSet["Tmpdir"] . "\good_" . NowBookName . ".bdlist"
		} else {
			NowIndexURL := "http://tieba.baidu.com/f?kw=" . NowBookName . "&ie=utf-8"
			tmphtml := FoxSet["Tmpdir"] . "\tieba_" . NowBookName . ".bdlist"
		}

		IfNotExist, %tmphtml%
			runwait, wget.exe "%NowIndexURL%" -O %tmphtml%, %A_scriptdir%\bin32
		FileRead, html, *P65001 %tmphtml%
		if ! instr(html, "</html>") ; 未下完整，删除
			FileDelete, %tmphtml%
		oIndex := getTieBaList(html)
		}
		if ( NowSite = "8shu" ) {
			NowIndexURL := "http://www.8shu.net/search.php?w=" . GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(NowBookName))
			tmphtml := FoxSet["Tmpdir"] . "\8shu_" . NowBookName . ".bdlist"
			IfNotExist, %tmphtml%
				runwait, wget.exe "%NowIndexURL%" -O %tmphtml%, %A_scriptdir%\bin32
			FileRead, html, *P65001 %tmphtml%
			if ! instr(html, "</html>") ; 未下完整，删除
				FileDelete, %tmphtml%
			oIndex := get8shuList(html)
		}
	}

	Guicontrol, text, TmpURL, %NowIndexURL%
	Guicontrol, , TmpURL, %NowIndexURL%
	Guicontrol, Hide, Content
	Guicontrol, Show, TieBaLV
	
	loop, % oIndex.MaxIndex()
		LV_Add("", oIndex[A_index,2], oIndex[A_index,1])
	LV_ModifyCol(2, "SortDesc")

	if ( PageName = "" )
		GuiControl, Focus, TieBaLV
	else {
		GuiControl, , PageFilter, %PageName%
		TmpNamexkd := GetTitleKeyWord(PageName, 1)
		if ( TmpNamexkd != "" )
			GuiControl, text, PageFilter, %TmpNamexkd% ; 设置文本为第一字段，一般为xxx章
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
		tmphtml := FoxSet["Tmpdir"] . "\TieBa_" . A_TickCount . ".html"
		runwait, wget.exe -O %tmphtml% %TmpURL%, %A_scriptdir%\bin32
		FileRead, html, *P65001 %tmphtml%
		FileDelete, %tmphtml%
		GuiControl, , Content, % tiezi_process(html)
		GuiControl, Focus, Content
	}
	if instr(TmpURL, ".8shu.") {
		tmphtml := FoxSet["Tmpdir"] . "\8shu_" . A_TickCount . ".html"
		runwait, wget.exe -O %tmphtml% %TmpURL%, %A_scriptdir%\bin32
		FileRead, html, *P65001 %tmphtml%
		FileDelete, %tmphtml%
		GuiControl, , Content, % pro8shu(html)
		GuiControl, Focus, Content
	}
return

ProcTmpNR: ; 处理文本
	GuiControlGet, NowContent, , Content
	GuiControl, , Content, % ProcTxtNR(NowContent)
return

ProcTxtNR(SrcTxt="")
{
	stringreplace, SrcTxt, SrcTxt, `r, , A
	stringreplace, SrcTxt, SrcTxt, `n`n, `n, A
	stringreplace, SrcTxt, SrcTxt, 　, , A
	stringreplace, SrcTxt, SrcTxt, `n%A_space%, `n, A
	NewContent := ""
	loop, parse, SrcTxt, `n, `r
		NewContent .= RegExReplace(A_loopfield, "i)^[""　 ★]*") . "`n"
	stringreplace, NewContent, NewContent, `n`n, `n, A
	loop, 5 {  ; 去除头部回车符
		stringleft, HeadChar, NewContent, 1
		if ( HeadChar= "`n" or HeadChar = "`r" )
			StringTrimLeft, NewContent, NewContent, 1
	}
	return, NewContent
}

SavePageInfo:  ; 保存内容到数据库
	Gui, Page:Submit
	Gui, Page:Destroy
	CharCount := strlen(Content) ; 更新内容长度
	if ( PageMark = "" or PageMark = "text" or PageMark = "image" ) {  ; 小说时 猜测章节类型
		if ( PageMark = "image" )
			DelOldImage := 1
		If instr(Content, ".gif|")
		{
			PageMark := "image"
		} else {
			PageMark := "text"
			if Content contains html>,<body,<br>,<p>,<div>
				PageMark := "html"
		}
	}
	If ( PageMark != "image" and DelOldImage = 1 )
		FileDelete, % oBook.PicDir . "\" . BookID . "\" . PageID . "_*" ; 更新本章时，删除可能存在的图片文件
	
	oDB.EscapeStr(Content)
	if PageID is integer
		oDB.Exec("update Page set BookID=" . BookID . ", Name='" . PageName . "', URL='" . PageURL . "', CharCount=" . CharCount . ", Mark='" . PageMark . "', Content=" . Content . " where ID = " . PageID)
return

get8shuList(html)
{
	LV_Delete()
	oIndex := []   ; 名称,URL
	oIndexCount := 0

	xx_1 := ""
	regexmatch(html, "smUi)id=""Tbs""[^>]*>(.*)</table>", xx_)
	loop, parse, xx_1, `n, `r
	{
		xx_1 := "" , xx_2 := "", xx_3 := ""
		regexmatch(A_loopfield, "Ui)<tr><td>.*</td>.*<td>.*<a[^>]*>([^<]*)<.*</td>.*<td>.*href=""([^""]*)"".*</td>.*<td><[^>]*>(.*)<[^>]*>.*</td>.*<td>.*</td>.*<td>.*</td></tr>", xx_)
		if ( xx_1 != "" ) {
			++oIndexCount
			oIndex[oIndexCount,1] := "http://www.8shu.net" . xx_2
			oIndex[oIndexCount,2] := xx_1 . A_space . xx_3
		}
	}
	return, oIndex
}

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
		if ! instr(A_loopfield, "class=""j_th_tit")
			continue
		FF_1 := "" , FF_2 := ""
		RegExMatch(A_loopfield, "Ui)<a href=""([^""]+)"".*""j_th_tit[ ]*"">([^<]+)</a>", FF_)
		if ( FF_2 != "" ) {
			++oIndexCount
			oIndex[oIndexCount,1] := "http://tieba.baidu.com" . FF_1
			oIndex[oIndexCount,2] := FF_2
		}
	}
	return, oIndex
}

pro8shu(html) { ; 8shu快照处理
	stringreplace, html, html, `n, , A
	stringreplace, html, html, `r, , A
	stringreplace, html, html, <br/>, `n, A
	stringreplace, html, html, &nbsp`;, , A
	stringreplace, html, html, `n`n, `n, A
	regexmatch(html, "smUi)id=""kz_content"">(.*)</div></td>", xx_)
	return, xx_1
}
tiezi_process(html) { ; 百度贴吧帖子处理
	StringReplace, html, html, `r, , A
	StringReplace, html, html, `n, , A
	StringReplace, html, html, <div class="louzhubiaoshi_wrap">, `n<div class="louzhubiaoshi_wrap">, A
	NewContent := ""
	loop, parse, html, `n, `r
	{
		if ! instr(A_loopfield, "<div class=""louzhubiaoshi_wrap"">")   ; 过滤非楼主的发言
			continue
		XX_1 := ""
		RegExMatch(A_loopfield, "Ui)<cc>(.*)</cc>", XX_)
		NewContent .= XX_1 . "`n★★★★★★★★★★★★★★★★★★★★★★★★★★★★`n"
	}
	StringReplace, NewContent, NewContent, <br><br><br>, `n, A
	StringReplace, NewContent, NewContent, <br><br>, `n, A
	StringReplace, NewContent, NewContent, <br>, `n, A
	NewContent := RegExReplace(NewContent, "Ui)<[^>]+>", "") ; 删除 html标签

	regexmatch(NewContent, "si)^(.*[\-\=_—]{5,})[^\-\=]*", adHead_)
	regexmatch(NewContent, "si)([\(（]?未完待续.*)$", adFoot_)
	aa := strlen(adHead_1)
	bb := strlen(adfoot_1)
	if ( ( aa > 0 and aa < 800 ) or ( bb > 0 and bb < 800 ) ) {
		if (aa > 800)
			adHead_1 := "头部大于800字符"
		if (bb > 800)
			adfoot_1 := "尾部大于800字符"
		msgbox, 4, 自动除垃圾, 需要自动消除以下垃圾字符串么`n<%adHead_1%>`n<%adfoot_1%>
		ifmsgbox, yes
		{
			stringreplace, NewContent, NewContent, %adHead_1%, , A
			stringreplace, NewContent, NewContent, %adFoot_1%, , A
		}
	}
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
	Gui, Cfg:Add, Edit, x56 y30 w180 h20 vCFGURL, biquge

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
	if ( General_getOSVersion() > 6.1 ) {
		yPos := 90
		IEHeight := A_ScreenHeight - 100
	} else {
		yPos := 26
		IEHeight := A_ScreenHeight - 30
	}
	Gui, IE:New, +HWNDhIE
	GUi, IE:+Resize ; +HWNDWinIE; 创建 GUI
	Gui, IE:Add, ActiveX, x0 y0 w%A_ScreenWidth% h%IEHeight% vPWeb hwndPCTN, Shell.Explorer
	pWeb.Navigate("about:blank")
	Gui, IE:Show, y%yPos%, FoxIE L
return

IEGuiSize:
	guicontrol, move, PWeb, w%A_GuiWidth% h%A_GuiHeight%
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
	filedelete, % FoxSet["Tmpdir"] . "\*.bdlist" ; 百度贴吧列表
	WinGet, TmpList, List, FoxBook ahk_class AutoHotkeyGUI
	if ( TmpList = 0 ) { ; 清空0字节文件及空白目录
		loop, % FoxSet["Tmpdir"] . "\*", 0, 1
			if ( A_LoopFileSize = 0 )
				FileDelete, %A_LoopFileFullPath%
		loop, % FoxSet["Tmpdir"] . "\*", 2, 1
			FileRemoveDir, %A_LoopFileFullPath%
		FileRemoveDir, % FoxSet["Tmpdir"]
	}
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

FoxSwitchDB:  ; 切换数据库
	if bMemDB
		FoxMemDB(oDB, DBPath, "Mem2File") ; Mem -> DB
	oDB.CloseDB()

	dbList := getDBList(A_Scriptdir)
	countDBs := dbList.MaxIndex()
    ++nowDBnum
	if ( nowDBnum > countDBs )
		nowDBnum := 1
	DBPath := dbList[nowDBnum]

	if bMemDB
	{
		oDB.OpenDB(":memory:")
		FoxMemDB(oDB, DBPath, "File2Mem")
	} else
		oDB.OpenDB(DBPath)
	SB_settext("切换为: " . DBPath)

	FoxCompSiteType := getCompSiteType(oDB)
	oBook.ShowBookList(oLVBook)
return

getDBList(DBDir="") ; 获取数据库列表
{
	DBList := []
	DBList[1] := DBDir . "\FoxBook.db3" ; 默认路径
	cDB := 1
	loop, %DBDir%\*.db3
	{
		if ( A_LoopFileName != "FoxBook.db3" ) {
			++cDB
			DBList[cDB] := A_LoopFileFullPath
		}
	}
	return, DBList
}

MenuInit: ; 菜单栏
; -- 菜单: 书籍
	aSTran := Array("选中书籍生成PDF" , "选中书籍生成Mobi" , "选中书籍生成Epub" , "选中书籍生成CHM" , "选中书籍生成UMD" , "选中书籍生成Txt")
	MenuInit_tpl(aSTran, "TransBookMenu", "BookMenuAct")
	Menu, BookMenu, Add, 选中书籍转换格式, :TransBookMenu

	aSSearch := Array("搜索书籍_起点" , "搜索书籍_PaiTXT" , "搜索书籍_大家读")
	MenuInit_tpl(aSSearch, "SearchBookMenu", "BookMenuAct")
	Menu, BookMenu, Add, 搜索书籍, :SearchBookMenu

	aBM := Array("-", "刷新显示列表" , "写入当前显示顺序" , "-" , "清空LastModified" , "清空已删除列表" , "显示已删除列表(&D)" , "-"
	, "更新所有目录" , "更新所有" , "停止(&S)" , "-"
	, "更新本书(&G)" , "更新本书目录(&T)", "更新书架中书籍`tAlt+D" , "显示最新起点列表(&Q)" , "-"
	, "新增书籍(&N)", "编辑本书信息(&E)", "删除本书", "-", "添加空白章节(&C)", "导入起点TXT", "-", "标记: 继续更新", "标记: 不再更新", "标记: 非主")
	MenuInit_tpl(aBM, "BookMenu", "BookMenuAct")

	Menu, MyMenuBar, Add, 书籍(&B), :BookMenu
; -- 菜单: 页面
	aPTran := Array("选中章节生成PDF" , "选中章节生成Mobi" , "选中章节生成Epub" , "选中章节生成CHM" , "选中章节生成UMD" , "选中章节生成Txt")
	MenuInit_tpl(aPTran, "TransPageMenu", "PageMenuAct")
	Menu, PageMenu, Add, 选中章节转换格式, :TransPageMenu

	aPMain := Array("-", "删除选中章节[写入已读列表](&D)", "删除选中章节[不写入已读列表](&B)", "-", "交换两选中章节ID(&W)", "-", "标记本章节类型为text", "标记本章节类型为image", "标记本章节类型为html", "-", "更新本章内容(&G)", "编辑本章信息(&E)", "-", "添加书架最新章节(&C)", "发送本章内容到另一窗口(&S)")
	MenuInit_tpl(aPMain, "PageMenu", "PageMenuAct")
	Menu, MyMenuBar, Add, 页面(&X), :PageMenu
; -- 菜单: 设置
	aSMain := Array("PDF图片(缓存):切割为手机:285*380", "PDF图片(缓存):切割为K3:530*700", "PDF图片(缓存):转换", "-"
	, "图片(文件):切割:270*360(手机)", "图片(文件):切割:530*665(K3_Mobi)", "图片(文件):切割:580*750(K3_Epub)", "-"
	, "比较:起点", "比较:大家读", "比较:PaiTxt", "比较:13xs", "比较:笔趣阁", "-"
	, "下载器:内置", "下载器:wget", "下载器:curl", "-" , "配置:Sqlite", "配置:INI", "-"
	, "查看器:IE控件", "查看器:IE", "查看器:AHK_Edit")
	MenuInit_tpl(aSMain, "dMenu", "SetMenuAct")
	Menu, MyMenuBar, Add, 设置(&Y), :dMenu
; -- 菜单: 数据库
	aDBMain := Array("按书籍页数倒序排列", "按书籍页数顺序排列", "重新生成页面ID", "重新生成书籍ID", "精简所有DelList", "-"
	, "编辑正则信息(&E)", "输入要执行的SQL", "-"
	, "显示今天的更新记录", "显示所有章节记录`tAlt+A", "显示所有过短章节`tAlt+I", "显示所有同URL章节`tCtrl+U", "-"
	, "打开数据库`tAlt+O", "整理数据库", "切换数据库`tAlt+S", "-", "导出书籍列表到剪贴板", "导出QidianID的SQL到剪贴板", "-", "快捷倒序`tAlt+E", "快捷顺序`tAlt+W")
	MenuInit_tpl(aDBMain, "DbMenu", "DBMenuAct")
	Menu, MyMenuBar, Add, 数据库(&Z), :DbMenu

; -- 菜单: 独立条目
	Menu, MyMenuBar, Add, 　, DBMenuAct
	Menu, MyMenuBar, Add, 顺序(&W), DBMenuAct
	Menu, MyMenuBar, Add, 倒序(&E), DBMenuAct
	Menu, MyMenuBar, Add, 切换(&S), QuickMenuAct
	Menu, MyMenuBar, Add, 短章(&I), DBMenuAct
	Menu, MyMenuBar, Add, 　　, DBMenuAct
	Menu, MyMenuBar, Add, 比较(&C), QuickMenuAct
	Menu, MyMenuBar, Add, 比较并更新, BookMenuAct
	Menu, MyMenuBar, Add, 　　　, DBMenuAct
	Menu, MyMenuBar, Add, &Mobi(K3), QuickMenuAct
	Gui, Menu, MyMenuBar
return
MenuInit_tpl(inArray, menuName, menuActName)
{
	Loop % inArray.MaxIndex()
	{
		if ( "-" = inArray[A_index])
			Menu, %menuName%, Add
		else
			Menu, %menuName%, Add, % inArray[A_index], %menuActName%
	}
}


QuickMenuAct:
	if ( A_ThisMenuItem = "切换(&S)" )
		gosub, FoxSwitchDB
	If ( A_ThisMenuItem = "比较(&C)" or NowInCMD = "CompareAndDown" ) {
		bNoSwitchLV := 1
		oLVComp.ReGenTitle(1)
		oLVComp.Clean()

		if (FoxCompSiteType = "qidian") {
			oDB.gettable("select ID, Name, QidianID from book where ( isEnd isnull or isEnd <> 1 ) and URL not like '%qidian%' order by DisOrder", oOldBookList)
			oCOMInfo := []
			oldDownMode := oBook.DownMode
			oBook.DownMode := "curl"
			loop, % oOldBookList.RowCount
			{
				oCOMInfo[A_index,1] := oOldBookList.rows[A_index][2]
				NowURL := qidian_getIndexURL_Desk(oOldBookList.rows[A_index][3])
				SavePath := FoxSet["Tmpdir"] . "\QD_" . A_TickCount . ".gif" ; 避免删除，要读取UTF-8
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
		oDB.gettable("select ID, Name from book where ( isEnd isnull or isEnd <> 1 ) order by DisOrder", oOldBookList) ; and URL not like '%qidian%' 
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
					NowNewPageURL := oCOMInfo[A_index,3]
					break
				}
			}
			if ( NowNewPageName = "" )
				NowNewPageName := "空"
			if ( NowInCMD != "CompareAndDown" )
				LV_Add("", NowOldPageName, NowNewPageName, NowBookName, NowPageID, NowNewPageURL)
			stringreplace, XXOldPageName, NowOldPageName, %A_space%, , A
			stringreplace, XXOldPageName, XXOldPageName, T, , A
			stringreplace, XXOldPageName, XXOldPageName, ., , A
			stringreplace, XXOldPageName, XXOldPageName, ♂, , A
			stringreplace, XXNewPageName, NowNewPageName, %A_space%, , A
			stringreplace, XXNewPageName, XXNewPageName, T, , A
			stringreplace, XXNewPageName, XXNewPageName, ., , A
			stringreplace, XXNewPageName, XXNewPageName, ♂, , A
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
	If A_ThisMenuItem in &Epub(K3),PDF(手机),&Mobi(K3),&PDF(K3)
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
		If ( A_ThisMenuItem = "&Mobi(K3)" ) {
			oBook.ScreenWidth := 530 , oBook.ScreenHeight := 665   ; K3 Mobi 切割尺寸
			NowInCMD := "PageToMobi" ; 页面制作Mobi
		}
		If ( A_ThisMenuItem = "&PDF(K3)" ) {
			oBook.PDFGIFMode := "SplitK3" ; PDF图片:切割为K3
			NowInCMD := "PageToPDF" ; 页面制作PDF
		}
		gosub, PageMenuAct
	}

	NowInCMD := ""
return

SettingMenuCheck:
	xx := Object("qidian", "比较:起点" , "dajiadu", "比较:大家读" , "paiTxt", "比较:PaiTxt" , "13xs", "比较:13xs", "biquge", "比较:笔趣阁")
	SettingMenuCheck_tpl(xx, FoxCompSiteType, "dMenu")
	; ---
	xx := Object("270", "图片(文件):切割:270*360(手机)" , "530", "图片(文件):切割:530*665(K3_Mobi)" , "580", "图片(文件):切割:580*750(K3_Epub)")
	SettingMenuCheck_tpl(xx, oBook.ScreenWidth, "dMenu")
	; ---
	xx := Object("normal", "PDF图片(缓存):转换" , "SplitK3", "PDF图片(缓存):切割为K3:530*700" , "SplitPhone", "PDF图片(缓存):切割为手机:285*380")
	SettingMenuCheck_tpl(xx, oBook.PDFGIFMode, "dMenu")
	; ---
	xx := Object("BuildIn", "下载器:内置" , "wget", "下载器:WGET" , "curl", "下载器:CURL")
	SettingMenuCheck_tpl(xx, oBook.DownMode, "dMenu")
	; ---
	xx := Object("IEControl", "查看器:IE控件" , "IE", "查看器:IE" , "BuildIn", "查看器:AHK_Edit")
	SettingMenuCheck_tpl(xx, oBook.ShowContentMode, "dMenu")
	; ---
	xx := Object("sqlite", "配置:Sqlite" , "ini", "配置:INI")
	SettingMenuCheck_tpl(xx, oBook.CFGMode, "dMenu")
return
SettingMenuCheck_tpl(hashmap, compareVar, menuName="dMenu")
{
	For sk, sv in hashmap {
		if ( compareVar = sk )
			Menu, %menuName%, check, %sv%
		else
			Menu, %menuName%, Uncheck, %sv%
	}
}

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
		NowListURL := qidian_getIndexURL_Desk(oBook.book["QiDianID"])
		oLVDown.Clean()
		oLVDown.focus()
		bNoSwitchLV := 1
		oBook.UpdateBook(NowBookID, oLVBook, oLVPage, oLVDown, NowListURL)
		bNoSwitchLV := 0
	}
	If ( A_ThisMenuItem = "删除本书" ) {
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
	If ( A_ThisMenuItem = "导入起点TXT" ) {
		FileSelectFile, QiDianTxtPath, 3, %A_Desktop%, 选择起点Txt文件, 起点Txt(*.txt)
		if ( QiDianTxtPath = "" )
			return
		QDXML := qidian_txt2xml(QiDianTxtPath, true, false) ; qidian txt -> FoxMark 

		; 获取信息，新增书籍
		NowQDBookName := qidian_getPart(QDXML, "BookName")
		NowQDPageCount := qidian_getPart(QDXML, "PartCount")
		NowQidianID := qidian_getPart(QDXML, "QidianID")
		NowSiteURL := qidian_getIndexURL_Mobile(NowQidianID)

		oDB.exec("insert into book (Name, URL, QidianID) values ('" . NowQDBookName . "', '" . NowSiteURL . "', '" . NowQidianID . "')")
		oDB.LastInsertRowID(BookID)
		; 插入章节
		oDB.Exec("BEGIN;")
		loop, %NowQDPageCount%
		{
			NowQDPageTitle := qidian_getPart(QDXML, "Title" . A_index)
			NowQDPageContent := qidian_getPart(QDXML, "Part" . A_index)
			NowQDPageContent := ProcTxtNR(NowQDPageContent)  ; 处理内容
			NowContSize := strlen(NowQDPageContent)
			SB_SetText("添加: " . A_index . " / " . NowQDPageCount . " : " . NowQDPageTitle)
			odb.EscapeStr(NowQDPageTitle)
			odb.EscapeStr(NowQDPageContent)
			oDB.exec("insert into page(BookID, Mark, CharCount, Name, Content) values(" . BookID . ", 'text', " . NowContSize . ", " . NowQDPageTitle . ", " . NowQDPageContent . ");")
		}
		oDB.Exec("COMMIT;")
		QDXML := ""
		SB_SetText("已加入起点Txt: " . NowQDBookName . "  章节数: " . NowQDPageCount)
	}
	If ( A_ThisMenuItem = "新增书籍(&N)" or A_ThisMenuItem = "编辑本书信息(&E)" ) {
		If ( A_ThisMenuItem = "新增书籍(&N)" ) {
			oDB.exec("insert into book (Name, URL) values ('BookName', 'http://XXXXXXXXX')")
			oDB.LastInsertRowID(BookID)
		}
		If ( A_ThisMenuItem = "编辑本书信息(&E)" )
			BookID := oLVBook.GetOneSelect(3)
		if BookID is not integer
			return
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
		If ( A_ThisMenuItem = "搜索书籍_起点" ) {
			iJson := oBook.DownURL(qidian_getSearchURL_Mobile(GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(NowBookName))), "", "<useUTF8>")
			qdid_1 := ""
			regexmatch(iJson, "Ui)""ListSearchBooks"":\[{""BookId"":([0-9]+),""BookName"":""" . NowBookName . """", qdid_)
			if ( qdid_1 != "" ) {
				NowURL := qidian_getIndexURL_Desk(qdid_1)
			} else {
				NowURL := -1
				fileappend, %iJson%, C:\%NowBookName%.json
			}
		}
		If ( A_ThisMenuItem = "搜索书籍_PaiTXT" )
			NowURL := oBook.Search_paitxt(NowBookName)
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
	If ( A_ThisMenuItem = "标记: 非主" )
		oBook.MarkBook(oLVBook.GetOneSelect(3), "非主")

	If ( A_ThisMenuItem = "添加空白章节(&C)" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		NowBookName := oLVBook.GetOneSelect(1)
		oDB.Exec("insert into page (BookID, Name, URL, DownTime) Values (" . NowBookID . ", '" . NowBookName . "', 'FoxAdd.html', " . A_now . ")")
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
	If ( A_ThisMenuItem = "清空LastModified" ) {
		NowBookID := oLVBook.GetOneSelect(3)
		oDB.Exec("update Book set LastModified=null where ID = " . NowBookID)
		SB_SetText("已清空LastModified: " . NowBookID)
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
			NowTransMode := "pdf"
		If ( A_ThisMenuItem = "选中书籍生成Mobi" )
			NowTransMode := "mobi"
		If ( A_ThisMenuItem = "选中书籍生成Epub" )
			NowTransMode := "epub"
		If ( A_ThisMenuItem = "选中书籍生成CHM" )
			NowTransMode := "chm"
		If ( A_ThisMenuItem = "选中书籍生成UMD" )
			NowTransMode := "umd"
		If ( A_ThisMenuItem = "选中书籍生成Txt" )
			NowTransMode := "txt"
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
	BookCount := oBook.ShowBookList(oLVBook) ; 刷新左侧的列表
	NowInCMD := ""
return
; }
PageMenuAct:
	If ( instr(A_ThisMenuItem, "选中章节生成") or instr(NowInCMD , "PageTo") )
	{
		If ( A_ThisMenuItem = "选中章节生成PDF" or NowInCMD = "PageToPDF" )
			TmpMod := "pdf"
		If ( A_ThisMenuItem = "选中章节生成Mobi" or NowInCMD = "PageToMobi")
			TmpMod := "mobi"
		If ( A_ThisMenuItem = "选中章节生成Epub" or NowInCMD = "PageToEpub" )
			TmpMod := "epub"
		If ( A_ThisMenuItem = "选中章节生成CHM" )
			TmpMod := "chm"
		If ( A_ThisMenuItem = "选中章节生成UMD" )
			TmpMod := "umd"
		If ( A_ThisMenuItem = "选中章节生成Txt" )
			TmpMod := "txt"
		aPageIDList := oLVPage.GetSelectList(4)
		PageCount := aPageIDList.MaxIndex()
		If ( PageCount = "" or PageCount = 0 )
			return
		; 保存路径
		oBook.GetPageInfo(aPageIDList[1])
		oBook.GetBookInfo(oBook.page["BookID"])
		If bOutEbookPreWithAll
			SavePath := FoxSet["OutDir"] . "\all_" . FoxCompSiteType . "." . TmpMod
		else
			SavePath := FoxSet["OutDir"] . "\" . oBook.book["name"] . "." . TmpMod
		sTime := A_TickCount
		oBook.SBMSG := "任务: 选定章节列表转" . TmpMod . ": " . oBook.Book["Name"] . " : "
		If ( TmpMod = "PDF" )
			oBook.Pages2PDF(aPageIDList, SavePath)
		If TmpMod in Mobi,epub,CHM,UMD,Txt
			oBook.Pages2MobiorUMD(aPageIDList, SavePath, FoxCompSiteType)
		SB_SetText(oBook.SBMSG . "恭喜，转换完毕  耗时: " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "添加书架最新章节(&C)" ){
		NewPageName := oLVComp.GetOneSelect(2)
		NowBookName := oLVComp.GetOneSelect(3)
		NowPageURL := oLVComp.GetOneSelect(5)
		if ( "" = NowPageURL )
			return
		oDB.GetTable("select ID from Book where Name='" . NowBookName . "'", tID)
		oDB.Exec("insert into page (BookID, Name, URL, DownTime) Values (" . tID.Rows[1,1] . ", '" . NewPageName . "', '" . NowPageURL . "', " . A_now . ")")
		oDB.LastInsertRowID(LastInsrtRowID)
		SB_SetText("添加空白章节完毕, PageID: " . LastInsrtRowID . "  Name: " . NewPageName . "  URL: " . NowPageURL)
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
		Mark := oBook.Page["Mark"]
		gosub, PageGUICreate
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
	If instr(A_ThisMenuItem, "标记本章节类型为" )
	{
		mmPageID := oLVPage.GetOneSelect(4)
		if ( A_ThisMenuItem = "标记本章节类型为text" )
			NowMark := "text"
		if ( A_ThisMenuItem = "标记本章节类型为image" )
			NowMark := "image"
		if ( A_ThisMenuItem = "标记本章节类型为html" )
			NowMark := "html"
		oDB.Exec("update Page set Mark='" . NowMark . "' where ID = " . mmPageID)
		SB_SetText("已修改章节: " . mmPageID . " 的类型为: " . NowMark )
		mmPageID := "" , NowMark := ""
	}
	If ( A_ThisMenuItem = "发送本章内容到另一窗口(&S)" ) {
		msgPageID := oLVPage.GetOneSelect(4)

		WinGet, TmpList, List, FoxBook ahk_class AutoHotkeyGUI
		if ( TmpList != 2 ) {
			TrayTip, 提示, 不是两个主窗口`n数量: %TmpList%
			NowInCMD := ""
			return
		}
		if ( hMain = TmpList1 )
			hOtherMain := TmpList2
		else
			hOtherMain := TmpList1

		msgxml := "<MsgType>FoxBook_onePage</MsgType>`n"
		msgxml .= "<ScriptDir>" . A_Scriptdir . "</ScriptDir>`n"
		msgxml .= "<SenderHWND>" . hMain . "</SenderHWND>`n"
		oBook.GetPageInfo(msgPageID)
		oBook.GetBookInfo(oBook.Page["BookID"])
		msgxml .= "<BookName>" . oBook.Book["Name"] . "</BookName>`n"
		msgxml .= "<QidianID>" . oBook.Book["QidianID"] . "</QidianID>`n"
		msgxml .= "<PageName>" . oBook.Page["Name"] . "</PageName>`n"
		msgxml .= "<PageContent>" . oBook.Page["Content"] . "</PageContent>`n"
		msgxml .= "<PageMark>" . oBook.Page["Mark"] . "</PageMark>`n"
		
		TargetScriptTitle := "ahk_id " . hOtherMain
		Send_WM_COPYDATA(msgxml, TargetScriptTitle)
		SB_SetText(A_now . "  已发送到窗口: " . hOtherMain . "  " . ErrorLevel)
	}
	NowInCMD := ""
return

IGotAPage:  ; 处理收到的单章节
	awScriptdir := qidian_getPart(gFoxMsg, "ScriptDir")
	awSenderHWND := qidian_getPart(gFoxMsg, "SenderHWND")
	awBookName := qidian_getPart(gFoxMsg, "BookName")
	awQidianID := qidian_getPart(gFoxMsg, "QidianID")
	awPageName := qidian_getPart(gFoxMsg, "PageName")
	awPageContent := qidian_getPart(gFoxMsg, "PageContent")
	awPageMark := qidian_getPart(gFoxMsg, "PageMark")
	gFoxMsg := ""

	awPageCharCount := StrLen(awPageContent)
	SB_SetText("收到窗口 " . awSenderHWND . " 发来的章节: " . awBookName . " - " . awPageName . "  字数:" . awPageCharCount . "  标记: " . awPageMark)
	BAKawPageName := awPageName ; 后面 URL分析需要

	; 插入到page表
	odb.EscapeStr(awPageName)
	odb.EscapeStr(awPageContent)
	oDB.Exec("insert into page (Name,CharCount,Content,Mark) values(" . awPageName . ", " . awPageCharCount . ", " . awPageContent . ", '" . awPageMark . "')")
	oDB.LastInsertRowID(NewPageID)

	; 获取该章节可能属于的书籍信息 添加所属bookID
	oDB.GetTable("select ID,Name,QidianID From book where Name like '%" . awBookName . "%' or QidianID ='" . awQidianID . "'", oNBI)
	if ( oNBI.rowcount = 1 ) { ;　当前匹配了一本书籍
		NewPagesBookID := oNBI.Rows[1][1]
		oDB.Exec("update Page set BookID = " . NewPagesBookID . " where ID = " . NewPageID)
		NewPagesBookName := oNBI.Rows[1][2]
		TrayTip, 添加章节<%NewPageID%>至:, BookID: %NewPagesBookID%`nBookName: %NewPagesBookName%
	} else {
		tmpStr := ""
		loop, % oNBI.rowcount
			tmpStr .= oNBI.Rows[A_index][1] . "`t" . oNBI.Rows[A_index][2] . "`t" . oNBI.Rows[A_index][3] . "`n" 
		inputbox, NewPagesBookID, 输入归属BookID, BookID`tBookName`tQidianID`n%tmpStr%, , 400, 222
		if ( NewPagesBookID = "" or NewPagesBookID = " " )
			return
		oDB.Exec("update Page set BookID = " . NewPagesBookID . " where ID = " . NewPageID)
		TrayTip, 人工添加章节至:, BookID: %NewPagesBookID%
	}

	; 获取该章节可能属于的章节 添加所属URL
	odb.GetTable("select URL,ID,Name from Page where bookid=" . NewPagesBookID . " and ID <> " . NewPageID . " and Name like '%" . GetTitleKeyWord(BAKawPageName, 1) . "%'", oCXtmp)
	if ( oCXtmp.rowcount = 1 ) {
		oDB.Exec("update Page set URL = '" . oCXtmp.Rows[1][1] . "' where ID = " . NewPageID)
	} else {
		if ( oCXtmp.rowcount > 1 ) { ; 当结果多余1条记录时，使用完整标题过滤
			odb.GetTable("select URL,ID,Name from Page where bookid=" . NewPagesBookID . " and ID <> " . NewPageID . " and Name like '%" . BAKawPageName . "%'", oCXtemp)
			if ( oCXtemp.rowcount = 1 ) { ; 如果只有一条结果，使用该结果
				oCXtmp := oCXtemp
				oDB.Exec("update Page set URL = '" . oCXtmp.Rows[1][1] . "' where ID = " . NewPageID)
				return
			}
		}

		tmpStr := ""
		loop, % oCXtmp.rowcount
			tmpStr .= oCXtmp.Rows[A_index][2] . "`t" . oCXtmp.Rows[A_index][3] . "`t" . oCXtmp.Rows[A_index][1] . "`n" 
		inputbox, NewPageLikeID, 输入和本章相同URL的ID, PageID`tPageName`tURL`n%tmpStr%, , 400, 222
		if ( NewPageLikeID = "" or NewPageLikeID = " " )
			return
		NewPageURL := ""
		loop, % oCXtmp.rowcount
			if ( oCXtmp.Rows[A_index][2] = NewPageLikeID )
				NewPageURL := oCXtmp.Rows[A_index][1]
		if ( NewPageURL = "" ) { ; 当没找到URL时
			oDB.GetTable("select URL from page where id = " . NewPageLikeID, osswi)
			NewPageURL := osswi.Rows[1][1]
		}
		oDB.Exec("update Page set URL = '" . NewPageURL . "' where ID = " . NewPageID)
		if ( NewPageURL != "" )
			TrayTip, 页面 %NewPageID% 的URL:, %NewPageURL%
	}
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
ReOrderBookIDDesc: ; 倒序
	oBook.ReGenBookID("Desc", "select ID From Book order by ID Desc")
	oBook.ReGenBookID("Asc", "select book.ID from Book left join page on book.id=page.bookid group by book.id order by count(page.id) desc,book.isEnd,book.ID")
	oDB.Exec("update Book set Disorder=ID")
	oBook.ShowBookList(oLVBook)
return

ReOrderBookIDAsc:  ; 顺序
	oBook.ReGenBookID("Desc", "select ID From Book order by ID Desc")
	oBook.ReGenBookID("Asc", "select book.ID from Book left join page on book.id=page.bookid group by book.id order by count(page.id),book.isEnd,book.ID")
	oDB.Exec("update Book set Disorder=ID")
	oBook.ShowBookList(oLVBook)
return

ReOrderPageID:
	oBook.ReGenPageID("Desc")
	oBook.ReGenPageID("Asc")
return

simplifyAllDelList: ; 精简所有
	oDB.gettable("select ID, DelURL from book where length(DelURL) > 200", oTable)
	loop, % oTable.RowCount
	{
		sDelURL := SimplifyDelList(oTable.rows[A_index][2]) ; 精简已删除列表
		oDB.EscapeStr(sDelURL)
		oDB.Exec("update Book set DelURL=" . sDelURL . " where ID = " . oTable.rows[A_index][1])
	}
	oTable := []
	sDelURL := ""
return

DBMenuAct:
	sTime := A_TickCount
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
		gosub, ReOrderPageID
		SB_settext("页面ID生成完毕, 耗时(ms): " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "按书籍页数倒序排列" ) {
		gosub, ReOrderBookIDDesc
		SB_settext("按书籍页数倒序排列 并 生成书籍ID完毕, 耗时(ms): " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "按书籍页数顺序排列" ) {
		gosub, ReOrderBookIDAsc
		SB_settext("按书籍页数顺序排列 并 生成书籍ID完毕, 耗时(ms): " . (A_TickCount - sTime))
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
		oDB.GetTable("select name,url,QidianID from book order by DisOrder", otable)
		loop, % oTable.rowcount
			TmpList .= oTable.rows[A_index][1] . ">" . oTable.Rows[A_index][3] . ">" . oTable.Rows[A_index][2] . "`r`n"
		clipboard = %TmpList%
		TmpList := ""
		SB_settext("书籍列表 已导出到 剪贴板")
	}
	If ( A_ThisMenuItem = "显示今天的更新记录" or A_ThisMenuItem = "显示所有章节记录`tAlt+A" or A_ThisMenuItem = "显示所有过短章节`tAlt+I" or A_ThisMenuItem = "短章(&I)" or A_ThisMenuItem = "显示所有同URL章节`tCtrl+U" or NowInCMD = "ShowAll" ) {
		If ( A_ThisMenuItem = "显示今天的更新记录" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and page.DownTime > " . A_YYYY . A_MM . A_DD  . "000000 order by page.bookid,page.ID"
		If ( A_ThisMenuItem = "显示所有章节记录`tAlt+A" or NowInCMD = "ShowAll" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid order by page.bookid,page.ID"
		If ( A_ThisMenuItem = "显示所有过短章节`tAlt+I" or A_ThisMenuItem = "短章(&I)" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and page.CharCount < 999 order by page.bookid,page.ID"
		If ( A_ThisMenuItem = "显示所有同URL章节`tCtrl+U" )
			SQLstr := "select page.name, page.CharCount, book.name, page.ID from book,Page where book.id=page.bookid and ( ( select count(url) from page as p where p.bookid = page.bookid and p.url=page.url) > 1 ) order by page.bookid,page.ID"

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
	If ( A_ThisMenuItem = "精简所有DelList" ) {
		gosub, simplifyAllDelList
		SB_settext("精简完毕，耗时: " . ( A_TickCount - sTime) . " ms  书籍数: " . oTable.RowCount)
	}
	If ( A_ThisMenuItem = "切换数据库`tAlt+S" )
		gosub, FoxSwitchDB
	If ( A_ThisMenuItem = "整理数据库" or NowInCMD = "SaveAndCompress" ) {  ; 按钮: 整理数据库
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
		InputBox, ExtraSQL, 输入SQL语句, 请输入你希望Exec的SQL语句:`n表:[book] [page] [config]`ndelete from page where charcount < 9000, , 400, 150, , , , , update Book set LastModified = ''
		if ( ExtraSQL = "" or ExtraSQL = " " )
			return
		oDB.Exec(ExtraSQL)
		Traytip, 已执行:, %ExtraSQL%
		oBook.ShowBookList(oLVBook)
	}
	If ( A_ThisMenuItem = "快捷倒序`tAlt+E" or A_ThisMenuItem = "倒序(&E)" ) {
		gosub, ReOrderBookIDDesc
		gosub, ReOrderPageID
		gosub, simplifyAllDelList
		oDB.Exec("vacuum")
		SB_SetText("快捷倒序完毕, 耗时(ms): " . (A_TickCount - sTime))
	}
	If ( A_ThisMenuItem = "快捷顺序`tAlt+W" or A_ThisMenuItem = "顺序(&W)" ) {
		gosub, ReOrderBookIDAsc
		gosub, ReOrderPageID
		gosub, simplifyAllDelList
		oDB.Exec("vacuum")
		SB_SetText("快捷顺序完毕, 耗时(ms): " . (A_TickCount - sTime))
	}
	NowInCMD := ""
return
; }
SetMenuAct:
	If ( A_ThisMenuItem = "比较:起点" )
		FoxCompSiteType := "qidian"
	If ( A_ThisMenuItem = "比较:大家读" )
		FoxCompSiteType := "dajiadu"
	If ( A_ThisMenuItem = "比较:PaiTxt" )
		FoxCompSiteType := "paitxt"
	If ( A_ThisMenuItem = "比较:13xs" )
		FoxCompSiteType := "13xs"
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
		If ( A_GuiEvent = "ColClick" ){
			If ( A_GuiControl = "LVBook" ) { ; 点击了Book标题，重绘颜色
				if ( A_EventInfo = 1 ) { ; 点击第1列
					ColA := ! ColA
					if ColA
						orderby := "book.Name,book.DisOrder"
					else
						orderby := "book.Name desc,book.DisOrder"
				}
				if ( A_EventInfo = 2 ) {
					ColB := ! ColB
					if ColB
						orderby := "count(page.id),book.DisOrder"
					else
						orderby := "count(page.id) desc,book.DisOrder"
				}
				if ( A_EventInfo = 3 ) {
					ColC := ! ColC
					if ColC
						orderby := "book.DisOrder desc"
					else
						orderby := "book.DisOrder"
				}
				if ( A_EventInfo = 4 ) {
					ColD := ! ColD
					if ColD
						orderby := "book.URL"
					else
						orderby := "book.URL desc"
				}
				BookCount := oBook.ShowBookList(oLVBook, "select book.Name,count(page.id),book.ID,book.URL,book.isEnd from Book left join page on book.id=page.bookid group by book.id order by " . orderby)
				SB_settext(bMemDB . " 查询耗时: " . ( A_TickCount - sTime) . " ms  书籍数: " . BookCount)
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
!5::CopyInfo2Clip(5)
!6::CopyInfo2Clip(6)
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

GetTitleKeyWord(NR="", RetType=1) ; RetType: 1:RE1/Part1 2:RE1/Part2
{
	stringreplace, NR, NR, `,, %A_space%, A
	stringreplace, NR, NR, `., %A_space%, A
	stringreplace, NR, NR, ：, %A_space%, A
	stringreplace, NR, NR, 　, %A_space%, A
	stringreplace, NR, NR, %A_space%%A_space%, %A_space%, A
	regexmatch(NR, "Ui)([第]?[0-9零○一二两三四五六七八九十百千廿卅卌壹贰叁肆伍陆柒捌玖拾佰仟万１２３４５６７８９０]{1,7}[章节節堂讲回集]{1})[ ]*(.*)$", rr_)
	if ( rr_1 = "" ) {
		stringsplit, xx_, NR, %A_space%
		if ( RetType = 1 )
			return, xx_1
		if ( RetType = 2 )
			return, xx_2
	} else {
		if ( RetType = 1 )
			return, rr_1
		if ( RetType = 2 )
			return, rr_2
	}
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
		NowVar := qidian_getIndexURL_Mobile(oBook.Book["QidianID"])
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
	if ( Num = 5 ) {
		Gui, ListView, LVPage
		LV_GetText(NowVar, LV_GetNext(0), Num)
	}
	if ( Num = 6 ) {
		Gui, ListView, LVPage
		LV_GetText(NowVar, LV_GetNext(0), 2)
	}
	Clipboard = %NowVar%
	SB_settext("剪贴板: " . NowVar)
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
	ReGenTitle(bNew=0){
		This.Switch()
		if bNew
		{
			loop, 9
				LV_DeleteCol(1)
			loop, % This.FieldSet.MaxIndex()
				LV_InsertCol(A_index, This.FieldSet[A_index,1], This.FieldSet[A_index,2])
		} else {
			loop, % This.FieldSet.MaxIndex()
				LV_ModifyCol(A_index, This.FieldSet[A_index,1], This.FieldSet[A_index,2])
		}
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
	FoxSet := {}
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
	__New(oDB, FoxSet, FoxType=0) {
		This.oDB := oDB
		This.FoxSet := FoxSet
		This.PicDir := FoxSet["PicDir"]
		if ( FoxType = 0 )
			This.PDFGIFMode := "SplitK3" , This.ScreenWidth := 530 , This.ScreenHeight := 665
		if ( FoxType = 1 )
			This.PDFGIFMode := "SplitPhone" , This.ScreenWidth := 270 , This.ScreenHeight := 360
	}
	ShowBookList(oLVBook, SQLStr="select book.Name,count(page.id),book.ID,book.URL,book.isEnd from Book left join page on book.id=page.bookid group by book.id order by book.DisOrder") {
		oLVBook.Clean()
		LV_Colors.Detach(This.hLVBook)
		GuiControl, -Redraw, %hLVBook%
		LV_Colors.Attach(This.hLVBook, 0, 0)
		This.oDB.gettable(SQLStr, oTable)
		loop, % oTable.RowCount
		{
			LV_Add("", oTable.rows[A_index][1],oTable.rows[A_index][2],oTable.rows[A_index][3],oTable.rows[A_index][4])
			If ( oTable.rows[A_index][2] > 0 )
				LV_Colors.Row(This.hLVBook, A_index, 0xCCFFCC, "") ; 颜色:无章节
			else
				LV_Colors.Row(This.hLVBook, A_index, 0xCCFFFF, "") ; 颜色:有章节
			If ( oTable.rows[A_index][5] = 1 )
				LV_Colors.Row(This.hLVBook, A_index, "", 0x008000) ; 颜色:不再更新
			If ( oTable.rows[A_index][5] = 2 )
				LV_Colors.Row(This.hLVBook, A_index, "", 0x3D4ACB) ; 颜色:非主
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
			xx := A_space = xx ? "" : xx
			NowCFG["IdxRE"] := XX
			IniRead, XX, %IniPath%, %URLSite%, 列表删除字符串列表, %A_space%
			xx := A_space = xx ? "" : xx
			NowCFG["IdxStr"] := XX
			IniRead, XX, %IniPath%, %URLSite%, 页面范围正则, %A_space%
			xx := A_space = xx ? "" : xx
			NowCFG["PageRE"] := XX
			IniRead, XX, %IniPath%, %URLSite%, 页面删除字符串列表, %A_space%
			xx := A_space = xx ? "" : xx
			NowCFG["PageStr"] := XX
			This.CFGMode := "sqlite"
		}
		return, NowCFG
	}
	DownURL(URL, SavePath="", AddParamet="", bDeleteHTML=true) ; 下载URL, 返回值为内容
	{
		If ( SavePath = "" )
			SavePath := This.FoxSet["TmpDir"] . "\Fox_" . This.FoxSet["MyPID"] . "_" . A_TickCount . ".gz"
		SplitPath, SavePath, OutFileName, OutDir, OutExt
		IfNotExist, %OutDir%
			FileCreateDir, %OutDir%

		If ( "wget" = This.DownMode ) {
			stderrPath := This.FoxSet["TmpDir"] . "\Fox_" . This.FoxSet["MyPID"] . "_stderr.txt"
			oriAddParamet := AddParamet
			if instr(AddParamet, "<embedHeader>")
				stringreplace, AddParamet, AddParamet, <embedHeader>, -o "%stderrPath%",A
			if instr(AddParamet, "<useUTF8>")
				stringreplace, AddParamet, AddParamet, <useUTF8>, -U "ZhuiShuShenQi/2.22",A
			loop, 3 { ; 下载，直到下载完成
				runwait, wget.exe -S -c -T 5 --header="Accept-Encoding: gzip`, deflate" -O "%SavePath%" %AddParamet% "%URL%", %A_scriptdir%\bin32 , Min UseErrorLevel
				If ( ErrorLevel = 0 ) {  ; 下载完成
					break
				} else {
					if ( ErrorLevel = 1 ) { ; 网页木有更新
						SB_settext("下载警告: 网页真的木有更新过啊")
						break
					} else {
						SB_settext("下载错误: 重试地址: " . URL)
					}
				}
			}
		}
		If ( "curl" = This.DownMode ) {
			loop { ; 下载，直到下载完成
				runwait, curl.exe --compressed -L -o "%SavePath%" %AddParamet% "%URL%",  %A_scriptdir%\bin32, Min UseErrorLevel
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
		If OutExt in gif,png,jpg,jpeg
		{
			oContent := OutFileName . "|" . URL
		} else { ; 网页/json
			if oriAddParamet contains <embedHeader>,<useUTF8>
			{
				if instr(oriAddParamet, "<embedHeader>") ; 网页 使用LastModified
				{
					fileread, ssterr, %stderrPath%
					oContent := "`n<!--`n" . ssterr . "`n-->`n"
					oContent .= GeneralW_htmlUnGZip(SavePath)
				}
				if instr(oriAddParamet, "<useUTF8>") ; json
					oContent := GeneralW_htmlUnGZip(SavePath, "UTF-8")
			} else { ; 不使用LastModified
				oContent := GeneralW_htmlUnGZip(SavePath)
			}
			if bDeleteHTML
			{
				FileDelete, %SavePath%
				FileDelete, %stderrPath%
;				fileappend, %oContent%, c:\tmp\oContent
			}
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
		This.Book["LastModified"] := oTable.rows[1][8]
		return, this.Book
	}
	Book2MOBIorUMD(iBookID, ToF="mobi") {
		This.GetBookInfo(iBookID)

		This.oDB.GetTable("select id from page where bookid = " . iBookID, oTable)
		TmpPageCount := oTable.RowCount
		If ( TmpPageCount = "" or TmpPageCount = 0 )
			return
		oPageList := []
		loop, %TmpPageCount% 
			oPageList[A_index] := oTable.rows[A_index][1]

		This.Pages2MobiorUMD(oPageList, This.FoxSet["OutDir"] . "\" . This.Book["name"] . "." . ToF)
	}
	Book2PDF(iBookID) {
		sTime := A_TickCount
		This.GetBookInfo(iBookID)
		SavePDFPath := This.FoxSet["OutDir"] . "\" . This.Book["name"] . ".pdf"
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
		This.oDB.gettable("select Name,CharCount,URL,ID,Mark from Page where BookID = " . iBookID . " order by DisOrder", oTable)
		oLVPage.ReGenTitle()
		oLVPage.Clean()
		loop, % oTable.RowCount
		{
			LV_Add("", oTable.rows[A_index][1],oTable.rows[A_index][2],oTable.rows[A_index][3],oTable.rows[A_index][4])
			If ( oTable.rows[A_index][5] = "image" or oTable.rows[A_index][2] < 1000 )
				LV_Colors.Row(This.hLVPage, A_index, "", 0x008000) ; 颜色:图片章节
		}
		GuiControl, +Redraw, %hLVPage%
;		LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
		This.GetBookInfo(iBookID)
		SB_settext("选中: " . This.Book["Name"] . "　ID:" . This.Book["ID"] . "　QiDian:" . This.Book["QiDianID"] . "　<" . This.Book["LastModified"] . ">　停更:" . This.Book["isEnd"] . "　" . This.Book["URL"])
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
		If ( Mark = "继续更新" )
			SQLStr := "update Book set isEnd=null where ID = " . iBookID
		If ( Mark = "不再更新" )
			SQLStr := "update Book set isEnd=1 where ID = " . iBookID
		If ( Mark = "非主" )
			SQLStr := "update Book set isEnd=2 where ID = " . iBookID
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
		if ( This.Book["LastModified"] = "" )
			WgetCMDIfModifiedSince := "<embedHeader>"
		else
			WgetCMDIfModifiedSince := "<embedHeader> --header=""If-Modified-Since: " . This.Book["LastModified"] . """"
		if IndexURL contains m.baidu.com/tc,3g.if.qidian.com
			WgetCMDIfModifiedSince := "<useUTF8>"
		oNewPage := This._GetBookNewPages(IndexURL, "GetIt", WgetCMDIfModifiedSince) ; [Title,URL]
		NewPageCount := oNewPage.MaxIndex()
		If ( NewPageCount = "") {
			SB_settext(This.SBMSG . "无新章节")
			print(This.SBMSG . "`n")
			return, 0
		}
		print(This.SBMSG . "`t`t`t新章节: " . NewPageCount . "`n")
		SB_settext(This.SBMSG . "新章节数: " . NewPageCount)
		If ( bJustView = 1 ) { ; 不写入数据库
			oLVDown.Focus()
			lastNum := NewPageCount - 10 ; 显示最后几条
			loop, %NewPageCount%  ; Page
			{
				if (A_index > lastNum)
					LV_Add("",oNewPage[A_index,2], "只读", oNewPage[A_index,1], "不写")
			}
			LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
			return, 0
		}
		If ( This.MainMode = "update" ) { ; 更新模式，仅更新目录
			This.oDB.Exec("BEGIN;")
			loop, %NewPageCount% {
				This.oDB.Exec("INSERT INTO Page (BookID, Name, URL, DownTime) VALUES (" . iBookID . ", '" . oNewPage[A_index,2] . "', '" . oNewPage[A_index,1] . "', " . A_now . ")")
				LV_Add("",oNewPage[A_index,2], "", oNewPage[A_index,1], 0)
			}
			This.oDB.Exec("COMMIT;")
			LV_Modify(LV_GetCount(), "Vis") ; Jump2Last
			This.ShowPageList(iBookID, oLVPage)
			return, 0
		}

		If ( This.MainMode = "reader" ) { ; 更新模式，逐章更新
			LastSBMSG := This.SBMSG
			loop, %NewPageCount% {
				This.oDB.Exec("INSERT INTO Page (BookID, Name, URL, DownTime) VALUES (" . iBookID . ", '" . oNewPage[A_index,2] . "', '" . oNewPage[A_index,1] . "', " . A_now . ")")
				This.oDB.LastInsertRowID(LastRowID)
				oLVDown.Switch()
				LV_Add("", oNewPage[A_index,2], "", This.Book["Name"], LastRowID)
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
	_GetBookNewPages(IndexURL, ExistChapterList="GetIt", LastModifiedStr="" ) { ; 分析页面，对比数据库，获取新章节列表
		IfExist, %ExistChapterList%
		{  ;  编辑章节搜索时使用
			Fileread, iHTML, %ExistChapterList%
			regexmatch(iHTML, "Ui)<meta[^>]+charset([^>]+)>", Encode_)
			If instr(Encode_1, "UTF-8")
				Fileread, iHTML, *P65001 %ExistChapterList%
		} else { ; 普通更新
			if ( "GetIt" = ExistChapterList ) {  ; 普通更新
				iHTML := This.DownURL(IndexURL, "", LastModifiedStr)
				if instr(LastModifiedStr, "<embedHeader>")  ; 当网页中保存了头部时，获取最新头部
				{
					if instr(iHTML, "Last-Modified:")  ; 当木有更新，也就不会写头部了
					{
						regexmatch(iHTML, "mi)Last-Modified:[ ]?(.*)$", LM_)
						if ( LM_1 != "" ) { ; 有头部，更新数据库字段
							This.oDB.Exec("update Book set LastModified = '" . LM_1 . "' where ID = " . This.Book["ID"] . ";")
						}
					}
				}
			} else {
				iHTML := This.DownURL(IndexURL, ExistChapterList, "", 0)
			}
		}

		oCFG := This.GetCFG(IndexURL) ; "IdxRE", "IdxStr"

		if ( "GetIt" = ExistChapterList ) {
			oBookInfo := This.Book
			This.oDB.GetTable("select URL,Name from page where BookID=" . oBookInfo["ID"], oTable)
			ExistChapterList := oBookInfo["DelList"]
			loop, % oTable.RowCount
				ExistChapterList .= oTable.Rows[A_index][1] . "|" . oTable.Rows[A_index][2] . "`n"
			stringreplace, ExistChapterList, ExistChapterList, `r, , A
			stringreplace, ExistChapterList, ExistChapterList, `n`n, `n, A

		}

		if ( instr(IndexURL, "3g.if.qidian.com") ) { ; 处理起点手机
			oRemoteLink := qidianL_getIndexJson(iHTML)
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
			return, oNewPage
		}
		if ( instr(IndexURL, "m.baidu.com/tc") ) { ; 处理百度读书页面
			oRemoteLink := bdds_getIndexJson(iHTML) ; 索引返回数组: [url,Title]
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
			return, oNewPage
		}
		if ( instr(IndexURL, "novel.mse.sogou.com") ) { ; 处理搜狗读书页面
			oRemoteLink := sogou_getIndexJson(iHTML) ; 索引返回数组: [url,Title]
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
			return, oNewPage
		}

		LinkDelList := oCFG["IdxStr"]
		regexmatch(iHTML, oCFG["IdxRE"], Tmp_)
		If Tmp_1
			iHTML := Tmp_1
		stringreplace, iHTML, iHTML, `r, , A
		stringreplace, iHTML, iHTML, `n, , A
		iHTML := RegExReplace(iHTML, "Ui)<!--[^>]+-->", "") ; 删除目录中的注释 针对 niepo
		iHTML := RegExReplace(iHTML, "Ui)<span[^>]+>", "") ; 删除 span标签 qidian
		stringreplace, iHTML, iHTML, </span>, , A

		stringreplace, iHTML, iHTML, <a, `n<a, A
		stringreplace, iHTML, iHTML, </a>, </a>`n, A
		stringreplace, iHTML, iHTML, 　　, %A_space%%A_space%%A_space%%A_space%, A
		oNewPage := [] , NewItemCount := 0
		if ( oCFG["IdxRE"] = "" ) { ; 处理无规则(通用): 2014-2-22 链接列表应该是长度极近似的
			oRemoteLink := FoxNovel_getHrefList(iHTML) ; oPre数组: [链接, 文字]
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
		} else { ; 下面是有规则的处理
			oRemoteLink := This._getRuledSiteLinkArray(iHTML, LinkDelList)
			oNewPage := FoxNovel_Compare2GetNewPages(oRemoteLink, ExistChapterList)
		}
		return, oNewPage
	}
	_getRuledSiteLinkArray(iHTML, LinkDelList=" ") { ; return: oRemoteLink:[url, title]
		oRemoteLink := [] , oRemoteCount := 0
		loop, parse, iHTML, `n, `r
		{
			If ! instr(A_LoopField, "href")
				continue
			regexmatch(A_LoopField, "i)href *= *[""']?([^>""']+)[^>]*> *([^<]+)<", FF_)
			If FF_1 contains %LinkDelList% ; 删除链接
				continue
			if ( FF_1 = "" )
				continue
			++oRemoteCount
			oRemoteLink[oRemoteCount, 1] := FF_1 ; url
			oRemoteLink[oRemoteCount, 2] := FF_2 ; title
		}
		return, oRemoteLink
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
		This.Page["Mark"] := oTable.rows[1][9]
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
		<div id="IEContent" class="content" style="font-size:30px; font-family:微软雅黑; line-height:150`%;">`n`n
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
		NowTmpBookURL := This.Book["URL"]
		if NowTmpBookURL contains qidian.com,m.baidu.com/tc,novel.mse.sogou.com
		{
			if instr(NowPageURL, "qidian.com")
			{
				if ( instr(NowPageURL, "free.qidian.com") ) {
					NowPageURL := qidian_free_toPageURL_FromPageInfoURL(NowPageURL)
				} else {
					if ( ! instr(NowPageURL, "files.qidian.com") ) {
						nouseHTML := This.DownURL(NowPageURL)
						xx_1 := ""
						regexmatch(nouseHTML, "<script.*(http.*\.txt).*", xx_)
						NowPageURL := xx_1
					}
				}
				; 2015-4-16: 默认下载.gz会造成使用cdn，然后出现故障
				SavePath := This.FoxSet["TmpDir"] . "\Fox_" . This.FoxSet["MyPID"] . "_" . A_TickCount . ".txt"
				runwait, wget -S -c -T 5 -O "%SavePath%" "%NowPageURL%", , Min
				fileread, oHTML, %SavePath%
				FileDelete, %SavePath%

				PageContent := qidian_getTextFromPageJS(oHTML)
				oHTML := ""
				NowSBMSG := This.SBMSG . "文 : "
			}
			if instr(This.Book["URL"], "m.baidu.com/tc")
			{
				regexmatch(This.Book["URL"], "i)gid=([0-9a-z]+)&", bdgid_)
				PageContent := bdds_getPageJson(This.DownURL("http://m.baidu.com/tc?srd=1&appui=alaxs&ajax=1&gid=" . bdgid_1 . "&pageType=undefined&src=" . NowPageURL . "&time=&skey=&id=wisenovel", "", "<useUTF8>"))
			}
			if instr(This.Book["URL"], "novel.mse.sogou.com")
			{
				regexmatch(This.Book["URL"], "i)md=([0-9a-z]+)", gsmd_)
				PageContent := sogou_getPageJson(This.DownURL("http://novel.mse.sogou.com/http_interface/getContData.php?md=" . gsmd_1 . "&url=" . NowPageURL, "", "<useUTF8>"))
			}
		} else {
			iHTML := This.DownURL(NowPageURL)
			PageContent := This._GetPageContent(iHTML, This.Page["ID"], NowPageURL) ; 处理HTML得到结果
		}
		; 针对不同返回值，不同处理方式
		If instr(PageContent, "|http://")  ; 图片处理
		{
			NowMark := "image"
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
		} else {
			NowMark := "text"
			if Content contains html>,<body,<br>,<p>,<div>
				NowMark := "html"
		}
		; 文本处理, 将PageContent StrSize 写入数据库,并修改LV
		StrSize := StrLen(PageContent)
		This.oDB.EscapeStr(PageContent)
		This.oDB.Exec("update Page set CharCount=" . StrSize . ", Mark='" . NowMark . "', Content=" . PageContent . " where ID = " . This.Page["ID"])
		If ( NowSBMSG = "" )
			NowSBMSG := This.SBMSG . "文 : "
		SB_settext(NowSBMSG . This.Page["Name"] . " : 字符数: " . StrSize)
		return, StrSize
	}
	_GetPageContent(iHTML, PageID=0, PageURL="") {
		oCFG := This.GetCFG(PageURL)
		if ( oCFG["PageRE"] = "" ) { ; 当没有相应规则的话，使用通用处理方式: Add: 2014-2-21
			return, FoxNovel_getPageText(iHTML) ; 正文 应该是由<div>包裹着的最长的行
		}
		regexmatch(iHTML, oCFG["PageRE"], Tmp_)
		If ( Tmp_1 != "" )
			iHTML := Tmp_1
		iHTML := FoxNovel_Html2Txt(iHTML)
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
			iHTML := RegExReplace(iHTML, "Ui)<a [^>]+>[^<]*</a>", "") ; 删除正文中的链接
			iHTML := RegExReplace(iHTML, "Ui)<[^>]+>", "") ; 删除 html标签

			PageDelStrList := oCFG["PageStr"]       ; 删除页面字符串
			stringreplace, PageDelStrList, PageDelStrList, <##>, `v, A
			stringreplace, PageDelStrList, PageDelStrList, <br>, `n, A
			loop, parse, PageDelStrList, `v, `r
			{
				If ( A_LoopField = "" )
					continue
				if instr(A_loopfield, "<re>")
				{	; 当被<re>标签包含，表示正则表达式
					fawi_1 := ""
					regexmatch(A_loopfield, "Ui)<re>(.*)</re>", fawi_)
					iHTML := RegExReplace(iHTML, fawi_1, "") ; 删除
				} else {
					stringreplace, iHTML, iHTML, %A_loopfield%, , A
				}
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
	Pages2MobiorUMD(oPageIDList, SavePath="C:\fox.mobi", tmode="书籍") {
		SplitPath, SavePath, OutFileName, OutDir, OutExt, OutNameNoExt, OutDrive
		If OutExt not in mobi,epub,chm,umd,txt
			return, -1
		This.GetPageInfo(oPageIDList[1])
		This.GetBookInfo(This.Page["BookID"])
		TmpPageCount := oPageIDList.MaxIndex()

		if ( tmode = "书籍" )
			ShowingBookName := This.Book["Name"]
		else
			ShowingBookName := This.Book["Name"] . "_" . tmode
		If ( OutExt = "mobi" or OutExt = "epub" )
			oEpub := New FoxEpub(ShowingBookName, This.FoxSet["TmpDir"] . "\ePubTmp_" . This.FoxSet["MyPID"])
		If ( OutExt = "chm" )
			oCHM := New FoxCHM(ShowingBookName, This.FoxSet["TmpDir"] . "\ChmTmp_" . This.FoxSet["MyPID"])
		If ( OutExt = "umd" )
			oUMD := New FoxUMD(ShowingBookName)
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
			If ( OutExt = "txt" ) {
				txtContent := "`n" . This.Page["Content"]
				StringReplace, txtContent, txtContent, `n, `n　　, A
				sTxt .= NowPageTitle . "`n" . txtContent . "`n`n"
			}
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
		This.GetPageInfo(oPageIDList[1])
		This.GetBookInfo(This.Page["BookID"])
		oPDF := new FoxPDF(This.Book["Name"])
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
			NowTitle := This.Page["Name"] , NowContent := This.Page["Content"] , NowStrSize := This.Page["CharCount"] , NowMark := This.Page["Mark"]
; ------
			If ( NowMark = "text" or NowMark = "" or NowStrSize > 1000 ) { ; 文本章节
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
			SavePDFPath := This.FoxSet["OutDir"] . "\" . A_TickCount . ".pdf"
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
		This.oDB.GetTable("select id from page where mark='image'", oExistPic)
		if ( oExistPic.RowCount > 0 ) {
			bExistPicDir := 1
			imageChaList := ":"
			loop, % oExistPic.RowCount
				imageChaList .= oExistPic.rows[A_index,1] . ":"
		} else {
			bExistPicDir := 0
		}
		This.oDB.GetTable(NowSQL, oTable)
		nPageCount := oTable.RowCount
		This.oDB.Exec("BEGIN;")         ; 事务开始
		loop, %nPageCount% {
			NowPageID := oTable.Rows[A_index][1]
			SB_settext("正在处理记录: " . A_index . " / " . nPageCount . " : " . NowPageID . " -> " . StartID)
			if bExistPicDir
			{ ; 存在图片章节
				if instr(imageChaList, ":" . NowPageID . ":")
				{
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
				} else {
					This.oDB.Exec("update Page set ID = " . StartID . " where ID = " . NowPageID . ";")
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
	Search_paitxt(iBookName="偷天") {	; 搜索目录页地址
		OldDownMode := This.DownMode
		This.DownMode := "wget"
		html := This.DownURL("http://paitxt.com/modules/article/search.php", "", "--post-data=SearchClass=1&searchkey=" . iBookName . "&searchtype=articlename") ; 下载URL, 返回值为内容
		This.DownMode := OldDownMode
		RegExMatch(html, "smUi)href=""(http://[w\.]*paitxt.com/[0-9]*/[0-9]*/)"" target=""_blank"">点击阅读</a>", FF_)
		If ( FF_1 != "" )
			return, FF_1
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
	GetSiteBookList(SiteType = "dajiadu") {
		TmpcookiePath := This.FoxSet["Tmpdir"] . "\FoxTmpCookie.txt"

		if ( SiteType = "dajiadu" )
			URLBookShelf := "http://www.dajiadu.net/modules/article/bookcase.php"
		if ( SiteType = "paitxt" )
			URLBookShelf := "http://paitxt.com/modules/article/bookcase.php"
		if ( SiteType = "13xs" )
			URLBookShelf := "http://www.13xs.com/shujia.aspx"
		if ( SiteType = "biquge" )
			URLBookShelf := "http://www.biquge.com.tw/modules/article/bookcase.php"

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

		if ( SiteType = "dajiadu" ) {  ; 输入html,输出 对象
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			StringReplace, html, html, <span class="hottext">新</span>, , A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "checkid")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td[^>]*><a[^>]*>([^<]*)<.*</td>.*<td[^>]*><a href=""([^""]+)""[^>]+>([^<]*)</a>.*</td>.*<td.*</td>.*<td.*</td>.*<td.*</td>", FF_)
				RegExMatch(FF_2, "i)cid=([0-9]+)", pid_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := pid_1 . ".html"
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
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td.*<a[^>]+>([^<]*)<.*</td>.*<td.*<a href=""([^""]+)""[^>]+>([^<]*)<.*</td>.*<td.*</td>.*<td.*</td>.*<td.*</td>", FF_)
				RegExMatch(FF_2, "i)cid=([0-9]+)", pid_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := pid_1 . ".html"
				oRet[CountRet,4] := ""
			}
		}
		if ( SiteType = "13xs" ) {  ; 输入html,输出 对象
			StringReplace, html, html, `r, , A
			StringReplace, html, html, `n, , A
			StringReplace, html, html, <tr, `n<tr, A
			loop, parse, html, `n, `r
			{
				if ! instr(A_loopfield, "odd")
					continue
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td.*><a[^>]*>([^<]*)</a></td>.*<td.*href=""([^""]*)""[^>]*>([^<]*)<.*</td>.*<td.*</td>.*<td[^>]*>([^<]*)</td>.*<td.*</td>", FF_)
				RegExMatch(FF_2, "i)cid=([0-9]+)", pid_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := pid_1 . ".html"
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
				RegExMatch(A_loopfield, "Ui)<td.*</td>.*<td.*><a[^>]*>([^<]*)</a></td>.*<td.*href=""([^""]*)""[^>]*>([^<]*)<.*</td>.*<td.*</td>.*<td[^>]*>([^<]*)</td>.*<td.*</td>", FF_)
				++CountRet
				oRet[CountRet,1] := FF_1
				oRet[CountRet,2] := FF_3
				oRet[CountRet,3] := biquge_urlFromBCToPage(FF_2)
				oRet[CountRet,4] := FF_4
			}
		}
		FileDelete, %TmpcookiePath% ; 删除临时cookie文件
		return, oRet
	}
	; }
}

#include <SQLiteDB_Class>
#Include <LV_Colors_Class>
#include <FoxNovel>
#include <FoxPDF_Class>
#include <FoxEpub_Class>
#include <FoxUMD_Class>
#include <FoxCHM_Class>

; {
biquge_urlFromBCToPage(sURL="http://www.biquge.com/modules/article/readbookcase.php?aid=5976&bid=2782260&cid=2116619")
{
	RegExMatch(sURL, "i)aid=([0-9]+)", aa_)
;	RegExMatch(sURL, "i)bid=([0-9]+)", bb_)
	RegExMatch(sURL, "i)cid=([0-9]+)", cc_)
	return, "/" . biquge_id2IndexBid(aa_1) . "/" . cc_1 . ".html"
}

biquge_id2IndexBid(iId=5976) ; 5676 -> 5_5976  213 -> 0_213
{
	if ( iId < 1000 )
		return, "0_" . iId
	if ( iId < 10000 ) {
		StringLeft, hh, iId, 1
		return, hh . "_" . iId
	}
	if ( iId < 100000 ) {
		StringLeft, hh, iId, 2
		return, hh . "_" . iId
	}
	msgbox, 错误:`nID : %iId% >= 100000`n怎么处理呢？
}

; }

; {
qidianL_getIndexJson(json="") ; 索引返回列表: URL`tTitle
{
	oRemoteLink := [] , oRemoteCount := 0
	StringReplace, json,json, `r,,A
	StringReplace, json,json, `n,,A
	StringReplace, json,json, {,`n{,A
	StringReplace, json,json, },}`n,A
	bid_1 := 0
	regexmatch(json, "i)""BookId"":([0-9]+),", bid_) ; 获取bookid
	urlHead := "http://files.qidian.com/Author" . ( 1 + mod(bid_1, 8) ) . "/" . bid_1 . "/" ; . pageid . ".txt"
	; {"c":80213678,"n":"第三百七十三章 最后的大结局（上）","v":0,"p":0,"t":1423412257000,"w":2177,"vc":"101","ui":0,"pn":0,"ccs":0,"cci":0}
	RE = i)"c":([0-9]+),"n":"([^"]+)","v":([01]),

	loop, parse, json, `n, `r
	{
		xx_1 := "", xx_2 := "", xx_3 := ""
		regexmatch(A_LoopField, RE, xx_)
		if( xx_1 = "" )
			continue
		if ( "1" = xx_3 )
			break
		++oRemoteCount
		oRemoteLink[oRemoteCount, 1] := urlHead . xx_1 . ".txt" ; url
		oRemoteLink[oRemoteCount, 2] := xx_2 ; title
	}
	return, oRemoteLink
}
; }

; {
bdds_getIndexJson(json="") ; 索引返回列表: URL`tTitle
{
	oRemoteLink := [] , oRemoteCount := 0
	sp := "`t"
	StringReplace, json,json, `r,,A
	StringReplace, json,json, `n,,A
	StringReplace, json,json, {,`n{,A
	StringReplace, json,json, },}`n,A
; {        "index": "3",        "cid": "3682020160|12752225317556097817",        "text": "第2章 这朴素的生活",        "href": "http://www.zhuzhudao.com/txt/29176/9559662/",        "rank": "0",        "create_time": "1425223386"      }
	RE = i)"text": *"([^"]*)"[, ]*"href": *"([^"]*)"[, ]*
	loop, parse, json, `n, `r
	{
		if instr(A_loopfield, "pageType") ; 避免最后一个重复
			break
		xx_1 := "", xx_2 := "", xx_3 := ""
		regexmatch(A_LoopField, RE, xx_)
		if( xx_1 = "" )
			continue
		++oRemoteCount
		oRemoteLink[oRemoteCount, 1] := xx_2 ; url
		oRemoteLink[oRemoteCount, 2] := xx_1 ; title
	}
	return, oRemoteLink
}
bdds_getPageJson(json="") ; 索引txt内容
{
	RE = i)<div[^>]+>(.*)</div>
	regexmatch(json, RE, xx_)
	StringReplace, xx_1, xx_1, &amp`;, , A
	StringReplace, xx_1, xx_1, \", ", A
	StringReplace, xx_1, xx_1, % chr(160), , A ; 特殊空白字符
	xx_1 := FoxNovel_getPageText(xx_1)
	return, xx_1
}
; }

; {
sogou_getIndexJson(json="") ; 索引返回列表: URL`tTitle
{
	json := GeneralW_JsonuXXXX2CN(json) ; 转码
	StringReplace, json, json, \/, /, A

	oRemoteLink := [] , oRemoteCount := 0
	sp := "`t"
	StringReplace, json,json, `r,,A
	StringReplace, json,json, `n,,A
	StringReplace, json,json, {,`n{,A
	StringReplace, json,json, },}`n,A
; {"name":"第1章 前面的，你皮裤掉了","cmd":"6221462379586502657","url":"http://read.qidian.com/BookReader/3425938,80820570.aspx"}
	RE = i)"name":[ ]*"([^"]*)",.*"url":[ ]*"([^"]*)"
	loop, parse, json, `n, `r
	{
		xx_1 := "", xx_2 := "", xx_3 := ""
		regexmatch(A_LoopField, RE, xx_)
		if( xx_1 = "" )
			continue
		++oRemoteCount
		oRemoteLink[oRemoteCount, 1] := xx_2 ; url
		oRemoteLink[oRemoteCount, 2] := xx_1 ; title
	}
	return, oRemoteLink
}
sogou_getPageJson(json="") ; 索引txt内容
{
	RE = Ui)"block":"[\\n]*(.*)"}
	regexmatch(json, RE, xx_)
	StringReplace, xx_1, xx_1, \n, `n, A
	StringReplace, xx_1, xx_1, 　　, , A
	StringReplace, xx_1, xx_1, `n`n, `n, A
	return, xx_1
}
; }

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

print(cmdstr=":初始化:") ; 命令行标准输出
{
	static stdout
;	DllCall("AllocConsole")
	if ( cmdstr = ":初始化:" ) {
		stdout := FileOpen(DllCall("GetStdHandle", "int", -11, "ptr"), "h `n")
		EnvGet, nowShell, SHELL
		if ( nowShell != "" ) ; 通过环境变量判断是否是cygwin环境
			stdout.Encoding := "UTF-8"  ; 标准输出编码 UTF-8, 便于 cygwin 使用
		return
	}
	if ( stdout = "" )
		return
	stdout.Write(cmdstr)
	stdout.Read(0) ; 刷新写入缓冲区.
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
	piccount := 0
	txtcount := 0
	Loop, % LV_GetCount()
	{ ; 获取选定的列表
		LV_GetText(NowSize, A_index, 2)
		If ( SelType = "Pic" And NowSize < TypePoint ) {
			++PicCount
			LV_Modify(A_index, "Select")
		}
		If ( SelType = "Text" And NowSize >= TypePoint ) {
			++txtcount
			LV_Modify(A_index, "Select")
		}
	}
	if ( SelType = "Pic" )
		SB_settext("选中章节数:  图片: " . PicCount)
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

; {{
Receive_WM_COPYDATA(wParam, lParam)  ; 通过消息接收大字符串
{
	global gFoxMsg
	StringAddress := NumGet(lParam + 2*A_PtrSize)
	gFoxMsg := StrGet(StringAddress)
	if instr(gFoxMsg, "<MsgType>FoxBook_onePage</MsgType>")
		gosub, IGotAPage
	return true
}

Send_WM_COPYDATA(ByRef StringToSend, ByRef TargetScriptTitle)  ; 通过消息发送大字符串
{
	VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)
	SizeInBytes := (StrLen(StringToSend) + 1) * (A_IsUnicode ? 2 : 1)
	NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)
	NumPut(&StringToSend, CopyDataStruct, 2*A_PtrSize)
	Prev_DetectHiddenWindows := A_DetectHiddenWindows
	Prev_TitleMatchMode := A_TitleMatchMode
	DetectHiddenWindows On
	SetTitleMatchMode 2
	SendMessage, 0x4a, 0, &CopyDataStruct,, %TargetScriptTitle%
	DetectHiddenWindows %Prev_DetectHiddenWindows%
	SetTitleMatchMode %Prev_TitleMatchMode%
	return ErrorLevel
}
; }}

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

CreateNewDB(oDB) {
	oDB.Exec("Create Table Book (ID integer primary key, Name Text, URL text, DelURL text, DisOrder integer, isEnd integer, QiDianID text, LastModified text)")
	oDB.Exec("Create Table Page (ID integer primary key, BookID integer, Name text, URL text, CharCount integer, Content text, DisOrder integer, DownTime integer, Mark text)")
	oDB.Exec("Create Table config (ID integer primary key, Site text, ListRangeRE text, ListDelStrList text, PageRangeRE text, PageDelStrList text, cookie text)")

	NovelList := InitBookInfo("NovelList") ; ConfigList
	loop, parse, NovelList, `n
	{
		stringsplit, FF_, A_loopfield, >
		oDB.Exec("INSERT INTO Book (Name, URL, QiDianID) VALUES ('" . FF_1 . "', '" . FF_2 . "', '" . FF_3 . "')")
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

CheckAndFixDB(oDB) ; 查询 表结构并检查是否缺少新增字段，修复它
{
	;CREATE TABLE sqlite_master ( type TEXT, name TEXT, tbl_name TEXT, rootpage INTEGER, sql TEXT);
	; 检查 Book 表
	oDB.GetTable("select sql from sqlite_master where tbl_name like '%book%'", sBook)
	NowSQL := sBook.rows[1,1]
	if NowSQL not contains ID,Name,URL,DelURL,DisOrder,isEnd,QiDianID
	{
		TrayTip, 数据库错误:, 表格Book中必需字段缺乏
	} else {
		if ! instr(NowSQL, "LastModified")
			oDB.Exec("alter table book add LastModified text")
	}

	; 检查 Page 表
	oDB.GetTable("select sql from sqlite_master where tbl_name like '%page%'", sPage)
	NowSQL := sPage.rows[1,1]
	if NowSQL not contains ID,BookID,Name,URL,CharCount,Content,DisOrder,DownTime
	{
		TrayTip, 数据库错误:, 表格Page中必需字段缺乏
	} else {
		if ! instr(NowSQL, "Mark")
			oDB.Exec("alter table Page add Mark text")
	}

	; 检查 Config 表
	oDB.GetTable("select sql from sqlite_master where tbl_name like '%config%'", sConfig)
	NowSQL := sConfig.rows[1,1]
	if NowSQL not contains ID,Site,ListRangeRE,ListDelStrList,PageRangeRE,PageDelStrList
	{
		TrayTip, 数据库错误:, 表格config中必需字段缺乏
	} else {
		if ! instr(NowSQL, "cookie")
			oDB.Exec("alter table config add cookie text")
	}
}
/*
RE.ini :
[模版]
列表范围正则=smUi)
列表删除字符串列表=
页面范围正则=smUi)
页面删除字符串列表=
说明=列表删除字符串列表以逗号分隔，将删除包含字符串的链接行html代码；页面删除字符串列表以<##>分隔，<br>表示换行，<re>正则表达式</re>，将删除文本字符串
*/

getCompSiteType(oDB) { ; 下面的是为了获取默认比较书架的网站关键字，需要根据奇葩网站升级正则表达式
	oDB.GetTable("select URL from book where ( isEnd isnull or isEnd < 1 )", oBBB)
	RegExMatch(oBBB.rows[1,1], "Ui)http[s]?://[0-9a-z\.]*([^\.]+)\.(com|net|org|se|me|cc|cn|net\.cn|com\.cn|com\.tw|org\.cn)/", Type_)
	if (Type_1 != "")
		return, Type_1
	else
		return, "biquge" ; 默认书架网站 :dajiadu 13xs
}

InitBookInfo(What2Return="NovelList") ; ConfigList
{
lNovelList =
(join`n
狐闹大唐>http://3g.if.qidian.com/Client/IGetBookInfo.aspx?version=2&BookId=1939238&ChapterId=0>1939238
)
lConfigList =
(Join`n
http://www.qidian.com@smUi)<div id="content">(.*)<div class="book_opt">@/book/,/BookReader/vol,/financial/,BuyVIPChapterList@@
http://read.qidian.com@smUi)<div id="content">(.*)<div class="book_opt">@/book/,/BookReader/vol,/financial/,BuyVIPChapterList@@
)
; http://msn.qidian.com@smUi)<!--正文-->(.*)<!-- 读书站点内容 end -->@@@
	return, l%What2Return%
}
; }

