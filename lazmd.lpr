program lazmd;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms,
  SysUtils,
  Main;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := 'LazMD';
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  if ParamStr(1) = '--register' then
  begin
    WriteLn(frmMain.RegisterWithSystem(True));
    Exit;
  end;
  if ParamStr(1) = '--unregister' then
  begin
    WriteLn(frmMain.RegisterWithSystem(False));
    Exit;
  end;
  if (ParamCount >= 1) and (ParamStr(1) <> '') and (ParamStr(1)[1] <> '-') then
    frmMain.LoadFile(ExpandFileName(ParamStr(1)));
  Application.Run;
end.
