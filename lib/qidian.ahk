; Ver: 2016-1-21
; 目前适合所有版本的AHK

; iURL: 3059077 | http://read.qidian.com/BookReader/3059077.aspx
; return: 3059077
qidian_getBookID_FromURL(iURL="")
{
	if instr(iURL, "http")
	{
		qd_1 := 0

		; 这里可以加入各种地址判断
		RegExMatch(iURL, "Ui)\/([0-9]+)\.aspx", qd_) ; http://read.qidian.com/BookReader/3347153.aspx
		; "Ui)\/([0-9]{2,9})\."
		; "i)\=([0-9]{2,9})"  ; ? mobile

		QidianID := qd_1
	} else {
		; 直接就是起点数字ID
		if iURL is integer
			QidianID = %iURL%
		else
			TrayTip, 错误:, 非QidianURL及QiDianID
	}
	return, QidianID
}

; pageInfoURL: http://read.qidian.com/BookReader/1939238,53927617.aspx
; return: http://files.qidian.com/Author7/1939238/53927617.txt
qidian_toPageURL_FromPageInfoURL(pageInfoURL)
{
	regexmatch(pageInfoURL, "i)/([0-9]+),([0-9]+)\.aspx", qidian_)
	return, qidian_getPageURL(qidian_2, qidian_1)
}

; pageInfoURL: http://free.qidian.com/Free/ReadChapter.aspx?bookId=2124315&chapterId=34828403
; return: http://files.qidian.com/Author4/2124315/34828403.txt
qidian_free_toPageURL_FromPageInfoURL(pageInfoURL)
{
	regexmatch(pageInfoURL, "i)bookId=([0-9]+)&chapterId=([0-9]+)", qidian_)
	return, qidian_getPageURL(qidian_2, qidian_1)
}

; pageid: 53927617
; bookid: 1939238
; return: http://files.qidian.com/Author7/1939238/53927617.txt
qidian_getPageURL(pageid, bookid) ; 返回页面内容JS地址
{
	return, "http://files.qidian.com/Author" . ( 1 + mod(bookid, 8) ) . "/" . bookid . "/" . pageid . ".txt"
}

; bookid: 1939238
; return: http://read.qidian.com/BookReader/1939238.aspx
qidian_getIndexURL_Desk(bookid)
{
	return, "http://read.qidian.com/BookReader/" . bookid . ".aspx"
}

; bookid: 1939238
; lastPageID: 0|bookid
; return: 目录地址
qidian_getIndexURL_Mobile(bookid, lastPageID=0) ; 可以用来获取lastPageID后的更新，为0获取所有
{
	return, "http://3g.if.qidian.com/Client/IGetBookInfo.aspx?version=2&BookId=" . bookid . "&ChapterId=" . lastPageID
}

; utf8encodedbookname: utf8书名经encode后的字串
; return: 搜索结果地址
qidian_getSearchURL_Mobile(utf8encodedbookname="") ; 返回: 搜索地址 参数:utf8经过encode后的编码
{
	return, "http://3g.if.qidian.com/api/SearchBooksRmt.ashx?key=" . utf8encodedbookname . "&p=0"
}
; bookinfo http://3g.if.qidian.com/BookStoreAPI/GetBookDetail.ashx?BookId=3008159&preview=1

/*
; bookname: 书名
; return: BookID
; 外部依赖: GeneralW.ahk JSON_Class.ahk(可用RE解析) wget.exe
qidian_bookName2BookId_Mobile(bookname) ; 调用客户端搜索接口地址，解析返回的json结果，得到书籍信息
{
	searchURL := qidian_getSearchURL_Mobile(GeneralW_UTF8_UrlEncode(GeneralW_StrToUTF8(bookname))) ; 返回: 搜索地址 参数:utf8经过encode后的编码
	; http://3g.if.qidian.com/api/SearchBooksRmt.ashx?key=%E6%88%91%E6%84%8F%E9%80%8D%E9%81%A5&p=0
	runwait, wget "%searchURL%" -O "C:\QD_MSearch.json"
	fileread, html, *P65001 c:\QD_MSearch.json
	FileDelete, C:\QD_MSearch.json
	j := JSON.parse(html)
	xx := j.Data.ListSearchBooks.MaxIndex()
	loop, %xx%
	{
		nbookname := j.Data.ListSearchBooks[A_index].BookName
		if ( nbookname = bookname ) {
			BookId := j.Data.ListSearchBooks[A_index].BookId
			break
		}
	}
	return, BookId
}
*/

qidian_getSearchURL_MobBrowser(utf8encodedbookname="") ; 模拟手机浏览器浏览m.qidian.com得到的搜索地址,返回的是json
{
	return, "http://m.qidian.com/ajax/top.ashx?ajaxMethod=getsearchbooks&pageindex=1&pagesize=20&isvip=-1&categoryid=-1&sort=0&action=-1&key=" . utf8encodedbookname . "&site=-1&again=0&range=-1"
}
; msgbox, % j.Data.search_response.books[1].bookid
; bookid, bookname, authorname, description, lastchaptername

; 极速版搜索地址: http://wap.m.qidian.com/search.aspx?key=%E4%B8%9C%E4%BA%AC%E9%81%93%E5%A3%AB
; http://wap.m.qidian.com/book/showbook.aspx?bookid=3347153&pageindex=2&order=desc
; http://wap.m.qidian.com/book/bookreader.aspx?bookid=3347153&chapterid=79700245&wordscnt=0


; jsStr: http://files.qidian.com/Author7/1939238/53927617.txt 中的内容
; return: 文本，可直接写入数据库
qidian_getTextFromPageJS(jsStr="")
{
	stringreplace, jsStr, jsStr, &lt`;, <, A
	stringreplace, jsStr, jsStr, &gt`;, >, A
	stringreplace, jsStr, jsStr, document.write(', , A
	stringreplace, jsStr, jsStr, <a>手机用户请到m.qidian.com阅读。</a>, , A
	stringreplace, jsStr, jsStr, <a href=http://www.qidian.com>起点中文网www.qidian.com欢迎广大书友光临阅读，最新、最快、最火的连载作品尽在起点原创！</a>, , A
	stringreplace, jsStr, jsStr, <a href=http://www.qidian.com>起点中文网 www.qidian.com 欢迎广大书友光临阅读，最新、最快、最火的连载作品尽在起点原创！</a>, , A
	stringreplace, jsStr, jsStr, ')`;, , A
	stringreplace, jsStr, jsStr, <p>, `n, A
	stringreplace, jsStr, jsStr, 　　, , A
	return, jsStr
}

; {

/*
txt2txt(txtpath) ; 使用正则表达式获取txt标题和内容，可能比下面的方法要快，没实验
{
	fileread, txt, %txtpath%
	txt .= "`r`n<end>`r`n"
	startpos := 1
	loop {
		startpos := RegExMatch(txt, "mUiP)^([^\r\n]+)[\r\n]{1,2}更新时间.*$[\r\n]{2,4}([^\a]+)(?=(^([^\r\n]+)[\r\n]{1,2}更新时间)|^<end>$)", xx_, startpos)
		if ( 0 = startpos ) {
			break
		}
		startpos := xx_pos2 + xx_len2
		newTxt .= SubStr(txt, xx_pos1, xx_len1) . "`r`n" . SubStr(txt, xx_pos2, xx_len2)  . "`r`n`r`n"
;		msgbox, % startpos "`n" SubStr(txt, xx_pos1, xx_len1) "`n-------`n" SubStr(txt, xx_pos2, xx_len2)
	}
	fileappend, %newTxt%, %txtpath%.txt
}
*/

; QDTxt: 起点txt格式内容
; bCleanSpace: 删除其中的开头空白字符串
; return:xml 类似: <BookName>书名</BookName><Title1>标题</Title1><Part1>内容</Part1><PartCount>212</PartCount>
qidian_txt2xml(QDTxt="", bCleanSpace=true) ; qidian txt -> FoxMark 
{
	if bCleanSpace
	{ ; 去除多余字符
		stringreplace, QDTxt, QDTxt, 　　, , A
		stringreplace, QDTxt, QDTxt, `r, , A
		stringreplace, QDTxt, QDTxt, `n`n, `n, A
	}

	stringsplit, Line_, QDTxt, `n, `r
	TarXML := "<BookName>" . Line_1 . "</BookName>`n"
	PartCount := 1
	loop, %Line_0% {
		NextLineNum := A_index + 1 , PrevPartCount := PartCount - 1
		; 更新时间2008-9-7 23:50:29  字数：605
		If instr(Line_%NextLineNum%, "更新时间") And instr(Line_%NextLineNum%, "字数：")
		{ ; 当前为　标题行
			If ( PartCount = 1 )
				TarXML .= "<Title" . PartCount . ">" . Line_%A_index% . "</Title" . PartCount . ">`n"
			else {
				TarXML .= "<Part" . PrevPartCount . ">`n" . TmpPart . "</Part" . PrevPartCount . ">`n"
					. "<Title" . PartCount . ">" . Line_%A_index% . "</Title" . PartCount . ">`n"
				TmpPart := ""
			}
			Line_%NextLineNum% := ""
			++PartCount
		} else { ; 当前为　非标题行
			If ( A_index = 1 or Line_%A_index% = "" ) 
				continue
			If instr(Line_%A_index%, "欢迎广大书友光临阅读，最新、最快、最火的连载作品尽在起点原创！")
				continue
			TmpPart .= Line_%A_index% . "`n"
		}
	}
	TarXML .= "<Part" . PrevPartCount . ">" . TmpPart . "</Part" . PrevPartCount . ">`n<PartCount>" . PrevPartCount . "</PartCount>`n"
	return, TarXML
}

; FoxXML: 上面那个函数返回的类似格式
; LableName: 包含在<>中的标签对名
; return: 包含在某标签内的最小内容
qidian_getPart(byref FoxXML, LableName="Title55")
{
	RegExMatch(FoxXML, "smUi)<" . LableName . ">(.*)</" . LableName . ">", out_)
	return, out_1
}

; }
