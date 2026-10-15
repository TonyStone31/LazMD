{ SPDX-License-Identifier: 0BSD; see LICENSE. }
unit ImageInsert;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs;

type
  TfrmImageInsert = class(TForm)
    lblSource, lblAlt, lblTitle, lblPreview, lblStatus, lblPath: TLabel;
    edSource, edAlt, edTitle, edFolder, edPath: TEdit;
    chkRelative, chkCopy: TCheckBox;
    btnBrowse, btnInsert, btnCancel: TButton;
    preview: TImage;
    dlgPicture: TOpenDialog;
    procedure BrowseClick(Sender: TObject);
    procedure SourceChange(Sender: TObject);
    procedure InsertClick(Sender: TObject);
  private
    FDocument, FReadySource: string;
    function LocalFileName: string;
    function TargetFileName: string;
    function PathForFile(const FileName: string): string;
  public
    procedure Prepare(const Document, AltText: string);
    procedure ChooseFile(const FileName: string);
    function ImageSource: string;
    function CommitImage: string;
  end;

implementation

uses URIParser, LazFileUtils, FileUtil;
  {$R *.lfm}

procedure TfrmImageInsert.Prepare(const Document, AltText: string);
begin
  FDocument := Document;
  FReadySource := '';
  chkRelative.Enabled := Document <> '';
  edTitle.Text := '';
  edSource.Text := '';
  edAlt.Text := AltText;
  if Document <> '' then dlgPicture.InitialDir := ExtractFileDir(Document);
  SourceChange(nil);
end;

procedure TfrmImageInsert.ChooseFile(const FileName: string);
begin
  edSource.Text := ExpandFileName(FileName);
end;

function TfrmImageInsert.PathForFile(const FileName: string): string;
var
  Relative: string;
begin
  Relative := FileName;
  if chkRelative.Checked and (FDocument <> '') then
    Relative := ExtractRelativePath(ExpandFileName(FDocument), FileName);
  Result := FilenameToURI(Relative);
  if not FilenameIsAbsolute(Relative) then Delete(Result, 1, Length('file:'));
end;

function TfrmImageInsert.LocalFileName: string;
var
  Address, Resolved: string;
begin
  Address := Trim(edSource.Text);
  if Address = '' then Exit('');
  if FilenameIsAbsolute(Address) then Exit(ExpandFileName(Address));
  Resolved := Address;
  if FDocument <> '' then
    if not ResolveRelativeURI(FilenameToURI(ExpandFileName(FDocument)), Address, Resolved) then Resolved := Address;
  if not URIToFilename(Resolved, Result) then
  begin
    if IsAbsoluteURI(Resolved) then Exit('');
    Result := ExpandFileName(Resolved);
  end;
end;

function TfrmImageInsert.TargetFileName: string;
var
  Folder, Original, Stem, Extension: string;
  N: integer;
begin
  Original := LocalFileName;
  Result := Original;
  if not (chkCopy.Checked and chkCopy.Enabled) then Exit;
  Folder := Trim(edFolder.Text);
  if not FilenameIsAbsolute(Folder) then Folder := ExtractFilePath(ExpandFileName(FDocument)) + Folder;
  Folder := IncludeTrailingPathDelimiter(ExpandFileName(Folder));
  Result := Folder + ExtractFileName(Original);
  if CompareFilenames(Result, Original) = 0 then Exit;
  Extension := ExtractFileExt(Result);
  Stem := ChangeFileExt(Result, '');
  N := 1;
  while FileExists(Result) or DirectoryExists(Result) do
  begin
    Inc(N);
    Result := Stem + '-' + IntToStr(N) + Extension;
  end;
end;

function TfrmImageInsert.ImageSource: string;
var
  FileName: string;
begin
  if FReadySource <> '' then Exit(FReadySource);
  FileName := TargetFileName;
  if FileName <> '' then Result := PathForFile(FileName)
  else
    Result := Trim(edSource.Text);
end;

function TfrmImageInsert.CommitImage: string;
var
  Original, Target: string;
begin
  if FReadySource <> '' then Exit(FReadySource);
  if not btnInsert.Enabled then raise EInOutError.Create('Choose an image address and a destination folder.');
  Result := ImageSource;
  Original := LocalFileName;
  if chkCopy.Checked and chkCopy.Enabled then
  begin
    Target := TargetFileName;
    Result := PathForFile(Target);
    if CompareFilenames(Original, Target) <> 0 then
      if not CopyFile(Original, Target, [cffCreateDestDirectory]) then
        raise EInOutError.Create('Could not copy the picture into ' + ExtractFileDir(Target));
  end;
  FReadySource := Result;
end;

procedure TfrmImageInsert.InsertClick(Sender: TObject);
begin
  if not btnInsert.Enabled then Exit;
  try
    CommitImage;
    ModalResult := mrOk;
  except
    on E: Exception do lblStatus.Caption := E.Message;
  end;
end;

procedure TfrmImageInsert.BrowseClick(Sender: TObject);
begin
  if dlgPicture.Execute then ChooseFile(dlgPicture.FileName);
end;

procedure TfrmImageInsert.SourceChange(Sender: TObject);
var
  Source, FileName: string;
begin
  FReadySource := '';
  Source := Trim(edSource.Text);
  FileName := LocalFileName;
  chkCopy.Enabled := (FDocument <> '') and (FileName <> '') and FileExists(FileName);
  edFolder.Enabled := chkCopy.Enabled and chkCopy.Checked;
  btnInsert.Enabled := (Source <> '') and (not edFolder.Enabled or (Trim(edFolder.Text) <> ''));
  edPath.Text := ImageSource;
  preview.Picture.Clear;
  if Source = '' then
  begin
    lblStatus.Caption := 'Choose a picture or enter its address.';
    Exit;
  end;
  if FileName <> '' then
  begin
    try
      if FileExists(FileName) then preview.Picture.LoadFromFile(FileName);
    except
      on E: Exception do preview.Picture.Clear;
    end;
    if preview.Picture.Graphic = nil then lblStatus.Caption := 'Preview unavailable. The image address will still be inserted.'
    else if edFolder.Enabled then lblStatus.Caption := 'A copy will be stored in the chosen folder when you insert.'
    else if FDocument <> '' then lblStatus.Caption := 'The picture stays in its current location.'
    else
      lblStatus.Caption := 'Save the document first to use relative paths or copy to a folder.';
  end
  else
    lblStatus.Caption := 'Web address ready. A local picture is needed for a preview.';
end;

end.
