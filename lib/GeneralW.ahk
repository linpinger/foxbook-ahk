; 分类: 通用函数
; 适用: L版
; 日期: 2013-07-25

; {-- 编码
GeneralW_StrToGBK(StrIn) {
	VarSetCapacity(GBK, StrPut(StrIn, "CP936"), 0)
	StrPut(StrIn, &GBK, "CP936")
	Return GBK
}
GeneralW_StrToUTF8(StrIn) {
	VarSetCapacity(UTF8, StrPut(StrIn, "UTF-8"), 0)
	StrPut(StrIn, &UTF8, "UTF-8")
	Return UTF8
}
GeneralW_UTF8ToStr(UTF8) {
	Return StrGet(UTF8, "UTF-8")
}
; }-- 编码

GeneralW_UTF8_UrlEncode(UTF8String)
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
      NewHex := RegExReplace(StrLen( Hex ) = 1 ? "0" . Hex : Hex, "(..)(..)", "%$2%$1")
      if instr(NewHex, "%")
	Out .= NewHex
      else
	Out .= "%" . NewHex
   }
   SetFormat, Integer, %OldFormat%
   return Out
}

