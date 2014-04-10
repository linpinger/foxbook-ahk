; {---------------------------------起点文本处理
FoxTxt_QiDianTxtPrepProcess(Byref SrcStr="", Byref TarStr="", Mode="") ; Mode: Add2LV(PageCount|Title)
{	; <BookName>书名</BookName><Title1>标题</Title1><Part1>内容</Part1><PartCount>212</PartCount>
	stringsplit, Line_, SrcStr, `n, `r
;	SrcStr := ""

	TarStr := "<BookName>" . Line_1 . "</BookName>`n"
	PartCount := 1
	loop, %Line_0% {
		NextLineNum := A_index + 1 , PrevPartCount := PartCount - 1
		; 更新时间2008-9-7 23:50:29  字数：605
		If instr(Line_%NextLineNum%, "更新时间") And instr(Line_%NextLineNum%, "字数：")
		{ ; 当前为　标题行
			If ( PartCount = 1 )
				TarStr .= "<Title" . PartCount . ">" . Line_%A_index% . "</Title" . PartCount . ">`n"
			else {
				TarStr .= "<Part" . PrevPartCount . ">`n" . TmpPart . "</Part" . PrevPartCount . ">`n"
					. "<Title" . PartCount . ">" . Line_%A_index% . "</Title" . PartCount . ">`n"
				TmpPart := ""
			}
			Line_%NextLineNum% := ""
If ( Mode = "Add2LV" )
	LV_Add("", PartCount, Line_%A_index%)
			++PartCount
		} else { ; 当前为　非标题行
			If ( A_index = 1 or Line_%A_index% = "" ) 
				continue
			If instr(Line_%A_index%, "欢迎广大书友光临阅读，最新、最快、最火的连载作品尽在起点原创！")
				continue
			TmpPart .= Line_%A_index% . "`n"
		}
	}
	TarStr .= "<Part" . PrevPartCount . ">" . TmpPart . "</Part" . PrevPartCount . ">`n<PartCount>" . PrevPartCount . "</PartCount>`n"
}

FoxTxt_QiDianGetSec(byref SrcStr, LableName="Title55")
{
	RegExMatch(SrcStr, "smUi)<" . LableName . ">(.*)</" . LableName . ">", out_)
	return, out_1
}

; }---------------------------------起点文本处理

