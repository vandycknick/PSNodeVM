:: Created by npm, please don't edit manually.
@IF EXIST "%~dp0%CurNodeVer%\node.exe" (
  "%~dp0%CurNodeVer%\node.exe" %*
) ELSE (
  "%~dp0latest\node.exe" %*
)
