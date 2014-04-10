; 分类: 通用函数
; 适用: 原版 L版
; 日期: 2013-07-26

; {{{-- 下载
General_Wget(URL="", AddParamet="-c -T 5 -O C:\WgetNoName", ShowWget="Hide", TipMethod="SB|下载错误") ; 使用wget下载
{
	loop { ; 下载，直到下载完成
		runwait, wget %AddParamet% "%URL%", , %ShowWget% UseErrorLevel
		If ( ErrorLevel = 0 )
			break
		else {
			XX_1 := "" , XX_2 := "" , XX_3 := ""
			StringSplit, XX_, TipMethod, |
			If ( XX_1 = "SB" )
				SB_settext(XX_2)
			If ( XX_1 = "TT" )
				TrayTip, %XX_2%, %XX_3%
		}
	}
	return, 0
}
; }}}-- 下载

; {-- 文件
General_GetFilePath(NowFileName="FreeImage.dll", DirList="C:\bin\bin32|D:\bin\bin32|C:\Program Files|D:\Program Files") { ; 获取文件路径
	static LastDir
	if ( LastDir != "" )
		ifExist, %LastDir%\%NowFileName%
			return, LastDir . "\" . NowFileName
	loop, parse, DirList, |
		IfExist, %A_LoopField%\%NowFileName%
		{
			LastDir := A_LoopField
			Break
		}
	if ( LastDir = "" ) { ; 未在给定路径中找到,去环境变量中寻找
		EnvGet, PosSysDirs, Path
		loop, parse, PosSysDirs, `;, %A_space%
			IfExist, %A_LoopField%\%NowFileName%
			{
				LastDir := A_LoopField
				Break
			}
	}
	if ( LastDir != "" )
		TarPath := LastDir . "\" . NowFileName
	return, TarPath
}
; }-- 文件


; {-- 加解密
General_UUID(c = false) { ; http://www.autohotkey.net/~polyethene/#uuid
	static n = 0, l, i
	f := A_FormatInteger, t := A_Now, s := "-"
	SetFormat, Integer, H
	t -= 1970, s
	t := (t . A_MSec) * 10000 + 122192928000000000
	If !i and c {
		Loop, HKLM, System\MountedDevices
		If i := A_LoopRegName
			Break
		StringGetPos, c, i, %s%, R2
		StringMid, i, i, c + 2, 17
	} Else {
		Random, x, 0x100, 0xfff
		Random, y, 0x10000, 0xfffff
		Random, z, 0x100000, 0xffffff
		x := 9 . SubStr(x, 3) . s . 1 . SubStr(y, 3) . SubStr(z, 3)
	} t += n += l = A_Now, l := A_Now
	SetFormat, Integer, %f%
	Return, SubStr(t, 10) . s . SubStr(t, 6, 4) . s . 1 . SubStr(t, 3, 3) . s . (c ? i : x)
}
; }-- 加解密


; {-- GUI扩展

General_MenuBarRightJustify(hGUI, MenuPos=0)  ; hGUI: GUI的HWND , MenuPos: 菜单项的编号(基于0)
{	; 最好在MenuBar之后，GUI显示之前
	hMenu :=DllCall("GetMenu", "Uint", hGUI)
	VarSetCapacity(mii, 48, 0)
	NumPut(48, mii, 0) , NumPut(0x100, mii, 4) , numput(0x4000, mii, 8)
	DllCall("SetMenuItemInfo", "uint", hMenu, "uint", MenuPos, "uint", 1, "uint", &mii)
	; http://msdn.microsoft.com/en-us/library/windows/desktop/ms648001(v=vs.85).aspx
}

; }-- GUI扩展

; {-- 使用 GDI+ 生成 纯色方块 ImageList
General_CreateImageListFromGDIP(ImageListID, ARGBList="0xFFFC9A35:0xFFC4C2C4:0xFFFCFE9C")
{	; 依赖 GDIP.ahk
	pToken := Gdip_Startup()
	pBitmap := Gdip_CreateBitmap(16, 16)
	G1 := Gdip_GraphicsFromImage(pBitmap)
	loop, parse, ARGBList, :
	{
		Gdip_GraphicsClear(G1, A_LoopField) ; 背景填充 ARGB
		DllCall("comctl32.dll\ImageList_Add", "uint", ImageListID, "uint", Gdip_CreateHBITMAPFromBitmap(pBitmap), "uint", "")
	}
	Gdip_DeleteGraphics(G1)
	Gdip_DisposeImage(pBitmap)
	Gdip_Shutdown(pToken)
}
; }-- 使用 GDI+ 生成 纯色方块 ImageList
