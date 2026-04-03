unit debug.info.reader;

(*
 * Copyright (c) 2021 Anders Melander
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *)

interface

{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

uses
  System.Classes,
  debug.info,
  debug.info.log;

type
  IDebugInfoLineLogger = interface
    ['{1EA6E06A-0491-4BCF-BFA5-508BC88912BD}']
    procedure Warning(const Msg: string); overload;
    procedure Warning(const Fmt: string; const Args: array of const); overload;
    procedure Error(const Msg: string); overload;
    procedure Error(const Fmt: string; const Args: array of const); overload;
  end;

  IDebugInfoLineLoggerContextProvider = interface
    ['{44664F53-A3E3-41FD-9DD4-6C98B8D4397D}']
    function GetLineNumber: integer;
    function GetLineText: string;
    property LineNumber: integer read GetLineNumber;
    property LineText: string read GetLineText;
  end;

  TDebugInfoLineModuleLogger = class(TInterfacedObject, IDebugInfoLineLogger)
  private
    FModuleLogger: IDebugInfoModuleLogger;
    FContextProvider: IDebugInfoLineLoggerContextProvider;
  protected
    // IDebugInfoLineModuleLogger
    procedure Warning(const Msg: string); overload;
    procedure Warning(const Fmt: string; const Args: array of const); overload;
    procedure Error(const Msg: string); overload;
    procedure Error(const Fmt: string; const Args: array of const); overload;
  public
    constructor Create(const AModuleLogger: IDebugInfoModuleLogger; const AContextProvider: IDebugInfoLineLoggerContextProvider);
  end;

  TLineReader = class(TNoRefCountObject, IDebugInfoLineLoggerContextProvider)
  strict private
    FReader: TStreamReader;
    FLineNumber: integer;
    FLineBuffer: string;
    FHasLineBuffer: boolean;
    FPeekBuffer: string;
    FHasPeekBuffer: boolean;
  private
    // IDebugInfoLineLoggerContextProvider
    function GetLineNumber: integer;
    function GetLineText: string;
  public
    constructor Create(Stream: TStream);
    destructor Destroy; override;

    function CurrentLine(ASkipEmpty: boolean = False; ATrim: boolean = True): string;
    function HasData: boolean;
    function NextLine(ASkipEmpty: boolean = False; ATrim: boolean = True): string;
    function PeekLine(ASkipEmpty: boolean = False; ATrim: boolean = True): string;

    function SkipSpace(Offset: integer): integer;

    property LineBuffer: string read FLineBuffer;
    property LineNumber: integer read FLineNumber;
  end;

  // Abstract reader base class
  TDebugInfoReader = class abstract
  private
    FModuleLogger: IDebugInfoModuleLogger;
  protected
    property Logger: IDebugInfoModuleLogger read FModuleLogger;
  public
    constructor Create; virtual;

    procedure LoadFromStream(Stream: TStream; DebugInfo: TDebugInfo); virtual; abstract;
    procedure LoadFromFile(const Filename: string; DebugInfo: TDebugInfo); virtual;
  end;

  TDebugInfoReaderClass = class of TDebugInfoReader;


implementation

uses
  System.SysUtils;


constructor TDebugInfoReader.Create;
begin
  inherited Create;
  FModuleLogger := RegisterDebugInfoModuleLogger('reader');
end;

procedure TDebugInfoReader.LoadFromFile(const Filename: string; DebugInfo: TDebugInfo);
begin
  try

    var Stream := TBufferedFileStream.Create(Filename, fmOpenRead or fmShareDenyWrite);
    try

      LoadFromStream(Stream, DebugInfo);

    finally
      Stream.Free;
    end;

  except
    on E: EFOpenError do
      Logger.Error(E.Message);
  end;
end;

{ TDebugInfoLineModuleLogger }

constructor TDebugInfoLineModuleLogger.Create(const AModuleLogger: IDebugInfoModuleLogger; const AContextProvider: IDebugInfoLineLoggerContextProvider);
begin
  inherited Create;
  FModuleLogger := AModuleLogger;
  FContextProvider := AContextProvider;
end;

procedure TDebugInfoLineModuleLogger.Error(const Msg: string);
begin
  FModuleLogger.Error('[%5d] %s'#13#10'%s', [FContextProvider.LineNumber, Msg, FContextProvider.LineText]);
end;

procedure TDebugInfoLineModuleLogger.Error(const Fmt: string; const Args: array of const);
begin
  Error(Format(Fmt, Args));
end;

procedure TDebugInfoLineModuleLogger.Warning(const Msg: string);
begin
  FModuleLogger.Warning('[%5d] %s', [FContextProvider.LineNumber, Msg]);
end;

procedure TDebugInfoLineModuleLogger.Warning(const Fmt: string; const Args: array of const);
begin
  Warning(Format(Fmt, Args));
end;

{ TLineReader }

constructor TLineReader.Create(Stream: TStream);
begin
  inherited Create;
  FReader := TStreamReader.Create(Stream);
end;

destructor TLineReader.Destroy;
begin
  FReader.Free;
  inherited;
end;

function TLineReader.GetLineNumber: integer;
begin
  Result := FLineNumber;
end;

function TLineReader.GetLineText: string;
begin
  Result := FLineBuffer;
end;

function TLineReader.PeekLine(ASkipEmpty: boolean; ATrim: boolean): string;
begin
  while (not FHasPeekBuffer) and (not FReader.EndOfStream) do
  begin
    FPeekBuffer := FReader.ReadLine;
    Inc(FLineNumber);
    if (not ASkipEmpty) or (not FPeekBuffer.TrimLeft.IsEmpty) then
      FHasPeekBuffer := True;
  end;

  if (FHasPeekBuffer) then
  begin
    if (ATrim) then
      Result := FPeekBuffer.TrimLeft
    else
      Result := FPeekBuffer;
  end else
    Result := '';
end;

function TLineReader.SkipSpace(Offset: integer): integer;
begin
  Result := Offset;
  while (Result <= Length(FLineBuffer)) and (FLineBuffer[Result] = ' ') do
    Inc(Result);
end;

function TLineReader.CurrentLine(ASkipEmpty: boolean; ATrim: boolean): string;
begin
  if (not FHasLineBuffer) then
  begin
    if (not FHasPeekBuffer) then
    begin
      while (not FHasLineBuffer) and (not FReader.EndOfStream) do
      begin
        FLineBuffer := FReader.ReadLine;
        Inc(FLineNumber);
        if (not ASkipEmpty) or (not FLineBuffer.TrimLeft.IsEmpty) then
          FHasLineBuffer := True;
      end;
    end else
    begin
      FLineBuffer := FPeekBuffer;
      FHasPeekBuffer := False;
      FPeekBuffer := '';
    end;
  end;

  if (FHasLineBuffer) then
  begin
    if (ATrim) then
      Result := FLineBuffer.TrimLeft
    else
      Result := FLineBuffer;
  end else
    Result := '';
end;

function TLineReader.NextLine(ASkipEmpty: boolean; ATrim: boolean): string;
begin
  FHasLineBuffer := False;
  FLineBuffer := '';
  Result := CurrentLine(ASkipEmpty, ATrim);
end;

function TLineReader.HasData: boolean;
begin
  Result := (FHasLineBuffer) or (FHasPeekBuffer) or (not FReader.EndOfStream);
end;

end.

