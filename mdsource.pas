{ The file's exact bytes and the raw editor's text. The memo works in the
  platform's line endings with no BOM; an edit there goes back into the
  bytes it came from, so the file keeps its BOM and its own line endings.
  SPDX-License-Identifier: 0BSD; see LICENSE. }
unit MDSource;
{$mode objfpc}{$H+}
interface

uses Classes, SysUtils, Math;

function ReadMarkdownFile(const FileName: string): string;
procedure WriteMarkdownFile(const FileName, Source: string);
function MarkdownContent(const Source: string): string;
function MarkdownEditorText(const Source: string): string;
function UpdateMarkdownSource(const Source, Text: string): string;

implementation

const
  UTF8BOM = #$EF#$BB#$BF;

function ReadMarkdownFile(const FileName: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, Stream.Size);
    if Result <> '' then Stream.ReadBuffer(Result[1], Length(Result));
  finally
    Stream.Free;
  end;
end;

procedure WriteMarkdownFile(const FileName, Source: string);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    if Source <> '' then Stream.WriteBuffer(Source[1], Length(Source));
  finally
    Stream.Free;
  end;
end;

function MarkdownContent(const Source: string): string;
begin
  Result := Source;
  if Copy(Result, 1, 3) = UTF8BOM then Delete(Result, 1, 3);
end;

function MarkdownEditorText(const Source: string): string;
begin
  Result := StringReplace(MarkdownContent(Source), #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #10, LineEnding, [rfReplaceAll]);
end;

function UpdateMarkdownSource(const Source, Text: string): string;
var
  Old, NewText, EOL, Inserted: string;
  First, Last, NewLast, ByteFirst, ByteLast, P, N: integer;

  function SourceOffset(Offset: integer): integer;
  var
    K, Chars: integer;
  begin
    K := 1;
    if Copy(Source, 1, 3) = UTF8BOM then K := 4;
    Chars := 1;
    while (K <= Length(Source)) and (Chars < Offset) do
    begin
      if (Source[K] = #13) and (Copy(Source, K, 2) = #13#10) then Inc(K);
      Inc(K);
      Inc(Chars);
    end;
    Result := K;
  end;

begin
  Old := StringReplace(MarkdownEditorText(Source), LineEnding, #10, [rfReplaceAll]);
  NewText := StringReplace(Text, #13#10, #10, [rfReplaceAll]);
  NewText := StringReplace(NewText, #13, #10, [rfReplaceAll]);
  if Old = NewText then Exit(Source);
  First := 1;
  N := Min(Length(Old), Length(NewText));
  while (First <= N) and (Old[First] = NewText[First]) do Inc(First);
  Last := Length(Old);
  NewLast := Length(NewText);
  while (Last >= First) and (NewLast >= First) and (Old[Last] = NewText[NewLast]) do
  begin
    Dec(Last);
    Dec(NewLast);
  end;
  ByteFirst := SourceOffset(First);
  ByteLast := SourceOffset(Last + 1);
  EOL := LineEnding;
  P := 1;
  while (P <= Length(Source)) and not (Source[P] in [#10, #13]) do Inc(P);
  if P <= Length(Source) then
  begin
    EOL := Source[P];
    if Copy(Source, P, 2) = #13#10 then EOL := #13#10;
  end;
  Inserted := StringReplace(Copy(NewText, First, NewLast - First + 1), #10, EOL, [rfReplaceAll]);
  Result := Copy(Source, 1, ByteFirst - 1) + Inserted + Copy(Source, ByteLast, MaxInt);
end;

end.
