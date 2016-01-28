; 分类: 通用函数
; 适用: 原版 L版
; 日期: 2015-12-28

; 版本 名称
; 5.1 Microsoft Windows XP
; 5.2 Microsoft Windows Server 2003
; 6.0 vista / server 2008
; 6.1 server2008 r2/ win7
; 6.2 win8
; 6.3 Windows 10 Enterprise ; JAVASE6 显示的是 Windows 8 和 6.2
General_getOSVersion(isName=false) {
	if ( isName )
		RegRead, retVar, HKLM, SOFTWARE\Microsoft\Windows NT\CurrentVersion, ProductName
	else
		RegRead, retVar, HKLM, SOFTWARE\Microsoft\Windows NT\CurrentVersion, CurrentVersion
	return retVar
}

General_uXXXX2CN(uXXXX) ; in: "\u7231\u5c14\u5170\u4e4b\u72d0"  out: "爱尔兰之狐"
{
	StringReplace, uXXXX, uXXXX, \u, #, A
	cCount := StrLen(uXXXX) / 5
	VarSetCapacity(UUU, cCount * 2, 0)
	cCount := 0
	loop, parse, uXXXX, #
	{
		if ( "" = A_LoopField )
			continue
		NumPut("0x" . A_LoopField, &UUU+0, cCount)
		cCount += 2
	}
	if ( A_IsUnicode ) {
		return, UUU
	} else {
		GeneralA_Unicode2Ansi(UUU, rUUU, 0)
		return, rUUU
	}
}

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

		/* ; 填充圆
		pBrush := Gdip_BrushCreateSolid(A_LoopField)
		Gdip_FillEllipse(G1, pBrush, 0, 0, 11, 11)
		Gdip_DeleteBrush(pBrush)
		*/

		DllCall("comctl32.dll\ImageList_Add", "uint", ImageListID, "uint", Gdip_CreateHBITMAPFromBitmap(pBitmap), "uint", "")
	}
	Gdip_DeleteGraphics(G1)
	Gdip_DisposeImage(pBitmap)
	Gdip_Shutdown(pToken)
}
; }-- 使用 GDI+ 生成 纯色方块 ImageList
