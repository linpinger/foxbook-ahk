; 分类: 通用函数
; 适用: 原版
; 日期: 2012-5-22

; {-- 编码: L版不通用
GeneralA_Ansi2UTF8(sString)
{
   GeneralA_Ansi2Unicode(sString, wString, 0) , GeneralA_Unicode2Ansi(wString, zString, 65001)
   Return zString
}

GeneralA_UTF82Ansi(zString)
{
   GeneralA_Ansi2Unicode(zString, wString, 65001) , GeneralA_Unicode2Ansi(wString, sString, 0)
   Return sString
}

GeneralA_Ansi2Unicode(ByRef sString, ByRef wString, CP = 0)
{
  nSize := DllCall("MultiByteToWideChar", "Uint", CP, "Uint", 0, "Uint", &sString, "int",  -1, "Uint", 0, "int",  0) 
  VarSetCapacity(wString, nSize * 2)
  DllCall("MultiByteToWideChar", "Uint", CP, "Uint", 0, "Uint", &sString, "int",  -1, "Uint", &wString, "int", nSize)
}

GeneralA_Unicode2Ansi(ByRef wString, ByRef sString, CP = 0)
{
  nSize := DllCall("WideCharToMultiByte", "Uint", CP, "Uint", 0, "Uint", &wString, "int",  -1, "Uint", 0, "int", 0, "Uint", 0, "Uint", 0) 
  VarSetCapacity(sString, nSize)
  DllCall("WideCharToMultiByte", "Uint", CP, "Uint", 0, "Uint", &wString, "int",  -1, "str",  sString, "int",  nSize, "Uint", 0, "Uint", 0)
}
; }-- 编码: L版不通用

