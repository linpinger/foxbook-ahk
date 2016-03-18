; 2014-7-8
; L版 快读小说网站解析库

; 获取最新更新列表
qreader_getupdate(aNU) ; in:[name,url]
{
	qreader_PageSpliter := "#"

	hh := {}
	PostData := "{""books"":["
	loop, % aNU.MaxIndex()
	{
		xx_1 := ""
		RegExMatch(aNU[A_index, 2], "i)bid=([0-9]+)", xx_)
		if (xx_1 = "")
			continue
		hh[xx_1] := aNU[A_index, 1]
		PostData .= "{""t"":0,""i"":" . xx_1 "},"
	}
	StringTrimRight, PostData, PostData, 1
	PostData .= "]}"

; {"books":[{"t":1404758734,"i":1119690},{"t":1404776764,"i":1273510},{"t":1404767792,"i":1260154}]}
	iJson := qreader_wget("http://m.qreader.me/update_books.php", PostData)
	
	iJson := GeneralW_JsonuXXXX2CN(iJson)
	StringReplace, iJson, iJson, {, `n{, A

	oRet := [] ; 返回数据对象: 1:书名 2:最新名 3:最新URL 4: 更新日期
	CountRet := 0
	loop, parse, iJson, `n
	{
		; {"id":1119690,"status":0,"img":1,"catalog_t":1404758734,"chapter_c":422,"chapter_i":422,"chapter_n":"第五章  胜者的权力"}
		FF_1 := "" , FF_2 := "" , FF_3 := ""
		regexmatch(A_loopfield, "i)""id"":([0-9]+),.*""catalog_t"":([0-9]+),.*""chapter_i"":([0-9]+),""chapter_n"":""(.+)""", FF_)
		if ( FF_1 = "" )
			continue
		++CountRet
		oRet[CountRet,1] := hh[FF_1]
		oRet[CountRet,2] := FF_4
		oRet[CountRet,3] := qreader_PageSpliter . FF_3
		oRet[CountRet,4] := FF_2
	}
	return, oRet
}

; 获取内容页
qreader_GetContent(PgURL) ; "http://m.qreader.me/query_catalog.php?bid=1119690#222"
{
	qreader_PageSpliter := "#"
	RegExMatch(PgURL, "i)bid=([0-9]+)" . qreader_PageSpliter . "([0-9]+)", xx_)
	PostData = {"id":%xx_1%,"cid":%xx_2%}
	iJson := qreader_wget("http://chapter.qreader.me/download_chapter.php", PostData)

	StringReplace, iJson, iJson, 　　, , A
	return, iJson
}

; 获取目录数组[url,name]
qreader_GetIndex(IdxURL) ; "http://m.qreader.me/query_catalog.php?bid=1119690"
{
	qreader_PageSpliter := "#"

	RegExMatch(idxURL, "i)bid=([0-9]+)", xx_)
	PostData = {"id":%xx_1%}
	iJson := qreader_wget("http://m.qreader.me/query_catalog.php", PostData)

	iJson := GeneralW_JsonuXXXX2CN(iJson)
	cc := []
	ccCount := 0
	StringReplace, iJson, iJson, {, `n{, A
	loop, parse, iJson, `n, `r
	{
		xx_1 := "" , xx_2 := ""
		RegExMatch(A_loopfield, "i)""i"":([0-9]+),""n"":""(.+)""", xx_)
		if ( "" = xx_1 )
			continue
		++ccCount
		outstr .= xx_1 . "`t" . xx_2 . "`n"
		cc[ccCount,1] := qreader_PageSpliter . xx_1
		cc[ccCount,2] := xx_2
	}
	return, cc
}

; 搜索书籍，返回url
qreader_Search(iBookName) {	; 搜索目录页地址
	uXXXX := GeneralW_CN2uXXXX(iBookName)

	PostData = {"key":"%uXXXX%"}
	iJson := qreader_wget("http://m.qreader.me/search_books.php", PostData)

	RegExMatch(iJson, "Ui)""id"":([0-9]+),", FF_)
	If ( FF_1 != "" )
		return, "http://m.qreader.me/query_catalog.php?bid=" FF_1
	else
		return, "未找到"
}

qreader_wget(iURL="", iPostData="")
{
	StringReplace, iPostData, iPostData, ", `\", A
	tmpName := A_now . "_qreader_tmp.json"
	runwait, wget "%iURL%" --post-data="%iPostData%" -O "%tmpName%", %A_Temp%, min
	fileread, iJson, %A_Temp%\%tmpName%
	filedelete, %A_Temp%\%tmpName%
	return iJson
}

