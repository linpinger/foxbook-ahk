; Ver: 2014-5-28
; 目前适合所有版本的AHK

; iURL: http://readbook.qidian.com/bookreader/3059077.html
; return: 3059077
qidian_getBookID_FromURL(iURL="")
{
	regexmatch(QidianID, "Ui)\/([0-9]{2,9})\.", II_)
	return, II_1
}

; pageInfoURL: http://read.qidian.com/BookReader/1939238,53927617.aspx
; return: http://files.qidian.com/Author7/1939238/53927617.txt
qidian_toPageURL_FromPageInfoURL(pageInfoURL)
{
	regexmatch(pageInfoURL, "i)/([0-9]+),([0-9]+)\.aspx", qidian_)
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
; return: http://readbook.qidian.com/bookreader/1939238.html
qidian_getIndexURL_Desk(bookid)
{
	return, "http://readbook.qidian.com/bookreader/" . bookid . ".html"
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

; jsStr: http://files.qidian.com/Author7/1939238/53927617.txt 中的内容
; return: 文本，可直接写入数据库
qidian_getTextFromPageJS(jsStr="")
{
	stringreplace, jsStr, jsStr, document.write(', , A
	stringreplace, jsStr, jsStr, <a>手机用户请到m.qidian.com阅读。</a>, , A
	stringreplace, jsStr, jsStr, <a href=http://www.qidian.com>起点中文网 www.qidian.com 欢迎广大书友光临阅读，最新、最快、最火的连载作品尽在起点原创！</a>, , A
	stringreplace, jsStr, jsStr, ')`;, , A
	stringreplace, jsStr, jsStr, <p>, `n, A
	stringreplace, jsStr, jsStr, 　　, , A
	return, jsStr
}

; {

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
