program EditorTests;
{$mode objfpc}{$H+}
uses
  Interfaces,
  Classes,
  Forms,
  Controls,
  Dialogs,
  LCLType,
  SysUtils,
  Graphics,
  Main,
  MDSource,
  InkRichEdit,
  InkMarkdown,
  FileEye,
  ImageInsert,
  URIParser;

type
  TRichAccess = class(TInkRichEdit)
    procedure RightClick(X, Y: integer);
  end;

  TChanges = class
    Window: TfrmMain;
    Seen: integer;
    PictureName: string;
    CancelImage: boolean;
    procedure FillImage(Data: PtrInt);
    procedure Changed(Sender: TObject; const FileName: string; Change: TFileEyeChange);
  end;

  procedure TRichAccess.RightClick(X, Y: integer);
  begin
    MouseDown(mbRight, [ssRight], X, Y);
  end;

  procedure TChanges.FillImage(Data: PtrInt);
  var
    I: integer;
    Picker: TfrmImageInsert;
  begin
    for I := 0 to Window.ComponentCount - 1 do
      if Window.Components[I] is TfrmImageInsert then
      begin
        Picker := TfrmImageInsert(Window.Components[I]);
        if CancelImage then Picker.btnCancel.Click
        else
        begin
          Picker.ChooseFile(PictureName);
          Picker.edAlt.Text := 'A [picture]';
          Picker.edTitle.Text := 'A "title"';
          Picker.btnInsert.Click;
        end;
        Exit;
      end;
    raise Exception.Create('Image dialog did not open');
  end;

  procedure TChanges.Changed(Sender: TObject; const FileName: string; Change: TFileEyeChange);
  begin
    Inc(Seen);
    Window.EyeChange(Sender, FileName, Change);
  end;

var
  Window: TfrmMain;
  FileName, Source, PictureName, InsertedSource, AssetsDir, FirstCopy, NextCopy: string;
  Picker: TfrmImageInsert;
  Shot: TBitmap;
  Checks: integer;
  Changes: TChanges;
  Target: integer;
  Deadline: QWord;

  procedure Settle;
  var
    Deadline: QWord;
  begin
    Deadline := GetTickCount64 + 250;
    repeat
      Application.ProcessMessages;
      Sleep(10)
    until GetTickCount64 >= Deadline;
  end;

  procedure Check(OK: boolean; const What: string);
  begin
    Inc(Checks);
    if not OK then raise Exception.Create(What);
  end;

begin
  try
    Application.Initialize;
    Window := TfrmMain.Create(nil);
    FileName := GetTempFileName(GetTempDir, 'lazmd');
    try
      Source := #$EF#$BB#$BF + 'A document' + #13#10 + '==========' + #13#10#13#10 + '__hello__' + #13#10;
      WriteMarkdownFile(FileName, Source);
      Window.LoadFile(FileName);
      Window.Show;
      Settle;
      Check(Window.pnlTools.Visible and Window.reDoc.Visible, 'documents open in rendered editing mode');
      Check(Window.FindComponent('pageView') = nil, 'no separate read-only viewer');
      Check(Window.FindComponent('btnOpen') = nil, 'no duplicate Open button');
      Check((Window.FindComponent('sbRaw') = nil) and (Window.FindComponent('tabsViews') = nil), 'mode choices belong to the menu');
      Window.ModeClick(Window.miModeEdit);
      Check(Window.pnlTools.Visible and Window.miModeEdit.Checked, 'Rendered shows the formatting toolbar');
      Window.EditAction(Window.miFind);
      Check(Window.reDoc.FindBarVisible, 'Edit > Find opens the find bar');
      Window.reDoc.HideFindBar;
      Window.FileSaveClick(nil);
      Check(ReadMarkdownFile(FileName) = Source, 'save in untouched Edit preserves every byte');
      Window.reDoc.SelStart := Pos('hello', Window.reDoc.PlainText) - 1;
      Window.reDoc.SelLength := 5;
      Window.EditAction(Window.btnItalic);
      Check(Window.btnItalic.Down, 'Italic button follows selection');
      Window.FileSaveClick(nil);
      Check((Pos('<em>hello</em>', MarkdownToHTML(MarkdownContent(ReadMarkdownFile(FileName)))) > 0) and
        (Pos('<strong>', MarkdownToHTML(MarkdownContent(ReadMarkdownFile(FileName)))) > 0), 'Italic action reaches saved Markdown');
      Window.EditAction(Window.btnUndo);
      Window.FileSaveClick(nil);
      Check(ReadMarkdownFile(FileName) = Source, 'undo after save restores the exact source');
      Window.reDoc.SelStart := 0;
      Window.reDoc.SelLength := 1;
      Window.EditAction(Window.btnItalic);
      WriteMarkdownFile(FileName, 'outside edit one');
      Window.EyeChange(nil, FileName, fcChanged);
      Settle;
      Check(Window.Bar.Has('changed'), 'first external change asks before discarding edits');
      WriteMarkdownFile(FileName, 'outside edit two');
      Window.EyeChange(nil, FileName, fcChanged);
      Settle;
      Check(Window.Bar.Count = 1, 'repeated change refreshes its pending question');
      Window.BarAnswer(nil, 'changed', mrYes);
      Check(Window.memRaw.Text = 'outside edit two', 'reload takes the latest external content');
      Window.LoadFile(FileName);
      WriteMarkdownFile(FileName, Source);
      Window.LoadFile(FileName);
      Window.ModeClick(Window.miModeRaw);
      Window.memRaw.Text := StringReplace(Window.memRaw.Text, 'hello', 'world', []);
      Window.RawChanged(nil);
      Window.FileSaveClick(nil);
      Check(ReadMarkdownFile(FileName) = StringReplace(Source, 'hello', 'world', []), 'Raw edit preserves BOM and CRLF');
      Window.SplitClick(nil);
      Check(Window.reDoc.Visible and Window.memRaw.Visible and Window.splSource.Visible,
        'optional split displays both editable panes');
      Window.ModeClick(Window.miModeRaw);
      Window.memRaw.Text := Window.memRaw.Text + ' appended';
      Window.RawChanged(nil);
      Check(Pos('appended', Window.reDoc.PlainText) > 0, 'raw edits update rendered split pane');
      Window.ModeClick(Window.miModeEdit);
      Window.reDoc.SelStart := Pos('world', Window.reDoc.PlainText) - 1;
      Window.reDoc.SelLength := 5;
      Window.EditAction(Window.btnItalic);
      Check(Pos('*world*', Window.memRaw.Text) > 0, 'rendered edits update source split pane');
      Window.SplitClick(nil);
      Check(Window.reDoc.Visible and not Window.memRaw.Visible, 'turning split off restores the selected tab');
      Window.reDoc.SelStart := Pos('world', Window.reDoc.PlainText) - 1;
      Window.reDoc.SelLength := 5;
      Changes := TChanges.Create;
      try
        Changes.Window := Window;
        Window.Eye.OnChange := @Changes.Changed;
        for Target := 1 to 2 do
        begin
          WriteMarkdownFile(FileName, 'watcher write ' + IntToStr(Target));
          Deadline := GetTickCount64 + 2500;
          repeat
            Application.ProcessMessages;
            Sleep(10)
          until (Changes.Seen >= Target) or (GetTickCount64 >= Deadline);
          Check(Changes.Seen >= Target, 'real file watcher delivered the external write');
          Check(Window.Bar.Has('changed') and (Window.Bar.Count = 1), 'real repeated writes retain one pending question');
        end;
      finally
        Window.Eye.OnChange := @Window.EyeChange;
        Changes.Free;
      end;
      Window.Bar.Hide('changed');
      Window.reDoc.GoToSource;
      Check(Window.miModeRaw.Checked, 'Go to source opens the Raw tab');
      Check(Window.memRaw.SelText = 'world', 'Go to source highlights selected source text');
      Window.ModeClick(Window.miModeEdit);
      Window.reDoc.SelStart := Pos('world', Window.reDoc.PlainText) + 1;
      Window.reDoc.SelLength := 0;
      Window.reDoc.GoToSource;
      Check((Window.miModeRaw.Checked) and (Window.memRaw.SelLength = 0), 'caret navigation opens Raw without selecting text');
      Check(Copy(Window.memRaw.Text, Window.memRaw.SelStart + 1, 3) = 'rld', 'caret navigation locates formatted text');
      PictureName := FileName + ' space #image.bmp';
      Shot := TBitmap.Create;
      try
        Shot.SetSize(20, 40);
        Shot.SaveToFile(PictureName);
      finally
        Shot.Free
      end;
      try
        Picker := TfrmImageInsert.Create(Window);
        try
          Picker.Prepare(FileName, 'selected description');
          Check(not Picker.btnInsert.Enabled, 'image dialog requires a destination');
          Check(Picker.edAlt.Text = 'selected description', 'image dialog starts with selected text as description');
          Picker.ChooseFile(PictureName);
          Check((Pos('%20', Picker.ImageSource) > 0) and (Pos('%23', Picker.ImageSource) > 0), 'image filename escapes spaces and fragment characters');
          Check(Pos('file:', Picker.ImageSource) = 0, 'saved documents use relative picture paths');
          Check(Picker.preview.Picture.Width = 20, 'image file chooser previews local pictures');
          Picker.chkRelative.Checked := False;
          Check(Pos('file:', Picker.ImageSource) = 1, 'absolute image paths can be selected explicitly');
          Picker.chkRelative.Checked := True;
          AssetsDir := FileName + '.assets';
          Picker.edFolder.Text := AssetsDir;
          Picker.chkCopy.Checked := True;
          Check(not DirectoryExists(AssetsDir), 'previewing a copy creates no asset folder');
          FirstCopy := Picker.CommitImage;
          Check(Pos('.assets/', FirstCopy) > 0, 'copied image link is relative to its document');
          Check(ReadMarkdownFile(AssetsDir + DirectorySeparator + ExtractFileName(PictureName)) = ReadMarkdownFile(PictureName), 'image copy preserves file bytes');
          Check(FileExists(PictureName), 'copy leaves the original image in place');
          Check(Picker.CommitImage = FirstCopy, 'committing an image twice reuses the prepared copy');
          Picker.SourceChange(nil);
          NextCopy := Picker.CommitImage;
          Check(NextCopy <> FirstCopy, 'duplicate image filename receives a fresh name');
          Check(FileExists(AssetsDir + DirectorySeparator + ChangeFileExt(ExtractFileName(PictureName), '') + '-2.bmp'), 'image copy avoids replacing an existing asset');
          DeleteFile(AssetsDir + DirectorySeparator + ExtractFileName(PictureName));
          DeleteFile(AssetsDir + DirectorySeparator + ChangeFileExt(ExtractFileName(PictureName), '') + '-2.bmp');
          RemoveDir(AssetsDir);
          Picker.chkCopy.Checked := False;

          Picker.edSource.Text := 'https://example.com/pic.png';
          Check(Picker.btnInsert.Enabled and (Picker.ImageSource = Picker.edSource.Text), 'image dialog accepts web addresses');
          Check(Picker.preview.Picture.Graphic = nil, 'web address clears previous local preview');
          Picker.Prepare('', '');
          Picker.ChooseFile(PictureName);
          Check(Pos('file:', Picker.ImageSource) = 1, 'untitled documents keep an absolute picture URI');
          Check(not Picker.chkCopy.Enabled and not Picker.chkRelative.Enabled, 'untitled documents explain unavailable relative path options');
          if ParamCount > 0 then
          begin
            Picker.Prepare(FileName, 'A picture description');
            Picker.ChooseFile(PictureName);
            Picker.edFolder.Text := 'assets';
            Picker.chkCopy.Checked := True;
            Picker.Show;
            Settle;
            Shot := Picker.GetFormImage;
            try
              Shot.SaveToFile(ParamStr(1) + '.image.bmp')
            finally
              Shot.Free
            end;
          end;

        finally
          Picker.Free
        end;
        WriteMarkdownFile(FileName, 'caption' + #13#10#13#10 + '__unchanged__');
        Window.LoadFile(FileName);
        Window.reDoc.SelStart := 0;
        Window.reDoc.SelLength := 7;
        Changes := TChanges.Create;
        try
          Changes.Window := Window;
          Changes.PictureName := PictureName;
          Application.QueueAsyncCall(@Changes.FillImage, 0);
          Window.ImageClick(Window.btnImage);
          Window.FileSaveClick(nil);
          InsertedSource := ReadMarkdownFile(FileName);
          Check((Pos('![A \[picture\]]', InsertedSource) = 1) and (Pos('__unchanged__', InsertedSource) > 0), 'image toolbar inserts Markdown and preserves adjacent source');
          Check(Pos('space%20%23image.bmp', InsertedSource) > 0, 'inserted image has a portable escaped relative path');
          Settle;
          Window.reDoc.SelStart := 2;
          Window.reDoc.SelLength := 0;
          TRichAccess(Window.reDoc).RightClick(5, 8);
          Window.reDoc.GoToSource;
          Check((Window.miModeRaw.Checked) and (Pos('![', Window.memRaw.SelText) = 1), 'right click image goes straight to its complete source');
          Window.ModeClick(Window.miModeEdit);
          Window.reDoc.Undo;
          Window.FileSaveClick(nil);
          Check(ReadMarkdownFile(FileName) = 'caption' + #13#10#13#10 + '__unchanged__', 'undo image insertion restores exact source after save');
          Changes.CancelImage := True;
          Application.QueueAsyncCall(@Changes.FillImage, 0);
          Window.ImageClick(Window.miImage);
          Window.FileSaveClick(nil);
          Check(ReadMarkdownFile(FileName) = 'caption' + #13#10#13#10 + '__unchanged__', 'canceling image insertion preserves source');
        finally
          Changes.Free
        end;
        WriteMarkdownFile(FileName, '| Alpha | Beta |' + #10 + '| --- | --- |' + #10 + '| a | b |');
        Window.LoadFile(FileName);
        Window.reDoc.SelStart := Pos('Beta', Window.reDoc.PlainText);
        Window.reDoc.SelLength := 0;
        Window.reDoc.GoToSource;
        Check((Window.miModeRaw.Checked) and (Window.memRaw.SelLength = 0), 'table caret opens its source without selection');
        Check(Copy(Window.memRaw.Text, Window.memRaw.SelStart + 1, 3) = 'eta', 'table caret maps to matching source cell');
        Window.ModeClick(Window.miModeEdit);
      finally
        DeleteFile(PictureName)
      end;
      Window.Width := 480;
      Settle;
      Check(Window.btnTable.Top > Window.btnUndo.Top, 'toolbar wraps on a narrow window');
      Window.Width := 920;
      Window.ModeClick(Window.miModeEdit);
      if ParamCount > 1 then Window.LoadFile(ExpandFileName(ParamStr(2)))
      else
        Window.LoadFile(ExpandFileName('../LazInk/docs/MARKDOWN_ROUNDTRIP.md'));
      Window.ModeClick(Window.miModeEdit);
      Settle;
      if ParamCount > 0 then
      begin
        Shot := Window.GetFormImage;
        try
          Shot.SaveToFile(ParamStr(1))
        finally
          Shot.Free
        end;
      end;
      WriteLn(Checks, ' editor checks passed.');
    finally
      Window.Free;
      DeleteFile(FileName);
    end;
  except
    on Err: Exception do
    begin
      WriteLn(Err.ClassName, ': ', Err.Message);
      DumpExceptionBackTrace(Output);
      Halt(1);
    end;
  end;
end.
