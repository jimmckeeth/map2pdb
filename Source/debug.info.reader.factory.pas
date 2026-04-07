unit debug.info.reader.factory;

(*
 * Copyright (c) 2021 Anders Melander
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *)

interface

uses
  System.Classes,
  debug.info.reader;

function TryStrToInputFormat(const AName: string; var InputFormat: TInputFormat): boolean;
function TryDetectInputFormat(const AFilename: string; var InputFormat: TInputFormat): boolean;
function CreateReader(InputFormat: TInputFormat): TDebugInfoReader;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  debug.info.reader.map,
  debug.info.reader.elfmap,
  debug.info.reader.jdbg,
  debug.info.reader.test;

const
  ReaderClasses: array[TInputFormat] of TDebugInfoReaderClass = (
    TDebugInfoMapReader,
    TDebugInfoElfMapReader,
    TDebugInfoJdbgReader,
    TDebugInfoSyntheticReader
  );

function TryStrToInputFormat(const AName: string; var InputFormat: TInputFormat): boolean;
begin
  var Name := AName;
  if Name.StartsWith('.') then
    Name := Name.Substring(1);

  for var InFormat := Low(TInputFormat) to High(TInputFormat) do
    if (SameText(Name, sInputFormatNames[InFormat])) or (SameText('.'+Name, sInputFileTypes[InFormat])) then
    begin
      InputFormat := InFormat;
      Exit(True);
    end;
  Result := False;
end;

function TryDetectInputFormat(const AFilename: string; var InputFormat: TInputFormat): boolean;
begin
  Result := False;
  if not TFile.Exists(AFilename) then
    Exit;

  // Peak into the file to see if it looks like a Delphi or ELF map file
  var Reader := TStreamReader.Create(AFilename);
  try
    var LineCount := 0;
    while (not Reader.EndOfStream) and (LineCount < 50) do
    begin
      var Line := Reader.ReadLine;
      Inc(LineCount);

      if Line.Contains('Detailed map of segments') then
      begin
        InputFormat := ifMap;
        Exit(True);
      end;

      if Line.StartsWith('.text') or Line.StartsWith('.data') or Line.Contains('0x00000000') or Line.Contains('Discarded input sections') then
      begin
        InputFormat := ifElfMap;
        Result := True; // Keep looking for Delphi signature just in case
      end;
    end;
  finally
    Reader.Free;
  end;
end;

function CreateReader(InputFormat: TInputFormat): TDebugInfoReader;
begin
  Result := ReaderClasses[InputFormat].Create;
end;

end.
