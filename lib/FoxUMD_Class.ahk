/*
; -----备注:
^esc::reload
+esc::Edit
!esc::ExitApp
F1::
	sTime := A_TickCount
	oUMD := New FoxUMD("偷天")
	oUMD.AddChapter("章节1", "正文1`n今天天气不错啊")
	oUMD.SaveTo()
	eTime := A_TickCount - sTime
	TrayTip, 耗时:, %eTime% ms
return
*/

Class FoxUMD {
	DllPath := "" , hDll := "" , hUMD := ""
	__New(BookName) { ; 依赖 umd.dll zlib.dll http://code.google.com/p/umd-builder/
sPathList =
(Ltrim Join`n
D:\bin\bin32\umd.dll
C:\bin\bin32\umd.dll
%A_scriptdir%\bin32\umd.dll
%A_scriptdir%\umd.dll
)
		loop, parse, sPathList, `n, `r
			IfExist, %A_loopfield%
				This.DllPath := A_loopfield

		This.hDll := DllCall("LoadLibrary", "Str", This.DllPath)
		This.hUMD := Dllcall("umd\umd_create", "Uint", 0)
		; 2:标题 3:作者 4:出版年份 5:出版月份 6:出版日子 7:书籍种类 8:出版人 9:销售人
		Dllcall("umd\umd_set_field_w", "Uint", This.hUMD, "Uint", 2, "str", BookName)
		Dllcall("umd\umd_set_field_w", "Uint", This.hUMD, "Uint", 8, "str", "爱尔兰之狐")
	}
	AddChapter(iTitle="章节名", iContent="正文"){
		Dllcall("umd\umd_add_chapter_w", "Uint", This.hUMD, "str", iTitle, "str", iContent)
	}
	SaveTo(BookSavePath="C:\Fox.UMD") {
		Dllcall("umd\umd_build_file_w", "Uint", This.hUMD, "str", BookSavePath)
		Dllcall("umd\umd_destroy", "Uint", This.hUMD)
		DllCall("FreeLibrary", "Uint", This.hDll)
	}
}

