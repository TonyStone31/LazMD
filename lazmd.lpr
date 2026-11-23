program lazmd;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF WINDOWS}
  Windows,
  {$ENDIF}
  Interfaces,
  Forms,
  SysUtils,
  Main;

  {$R *.res}

  { --register and --unregister print what they did }
  procedure Say(const S: string);
  begin
    {$IFDEF WINDOWS}
    // a GUI program on Windows starts with no standard output: write where
    // it was redirected, else to the console it was started from, else nowhere
    if (StdOutputHandle = 0) or (StdOutputHandle = INVALID_HANDLE_VALUE) then
    begin
      if AttachConsole(ATTACH_PARENT_PROCESS) then Assign(Output, 'CONOUT$')
      else
        Assign(Output, 'NUL');
      Rewrite(Output);
    end;
    {$ENDIF}
    WriteLn(S);
  end;

begin
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Title := 'LazMD';
  Application.Initialize;
  Application.CreateForm(TfrmMain, frmMain);
  if ParamStr(1) = '--register' then
  begin
    Say(frmMain.RegisterWithSystem(True));
    Exit;
  end;
  if ParamStr(1) = '--unregister' then
  begin
    Say(frmMain.RegisterWithSystem(False));
    Exit;
  end;
  if (ParamCount >= 1) and (ParamStr(1) <> '') and (ParamStr(1)[1] <> '-') then
    frmMain.LoadFile(ExpandFileName(ParamStr(1)));
  Application.Run;
end.
