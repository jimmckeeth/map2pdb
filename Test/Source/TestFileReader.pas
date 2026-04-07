unit TestFileReader;

interface

uses
  Classes, Types,
  TestFramework,
  FileTestFramework,
  debug.info,
  debug.info.reader;

type
  TCustomMapTest = class(TFileTestCase)
  strict private
    FDebugInfo: TDebugInfo;
  private
  protected
    procedure DoLoadFromFile;
    procedure ProcessDebugInfo(DebugInfo: TDebugInfo); virtual;
  public
    class function HandlesFiles(const AFilename: string): boolean; override;
    procedure SetUp; override;
    procedure TearDown; override;
  end;

  TTestFileReader = class(TCustomMapTest)
  published
    procedure TestLoadFromFile;
    procedure TestRobustness;
  end;

  TTestFileReaderErrors = class(TTestFileReader)
  protected
    procedure RunTest(TestResult: TTestResult); override;
  end;

type
  TFolderTestSuiteSkipErrors = class(TFolderTestSuite)
  protected
    procedure ProcessFolder(Suite: ITestSuite; TestClass: TFileTestCaseClass; const NameOfMethod, Path, FileMask: string; Recursive: Boolean); override;
  end;

type
  TFolderTestSuiteOnlyErrors = class(TFolderTestSuite)
  protected
    procedure ProcessFolder(Suite: ITestSuite; TestClass: TFileTestCaseClass; const NameOfMethod, Path, FileMask: string; Recursive: Boolean); override;
  end;

implementation

uses
  Windows,
  SysUtils,
  IOUtils,
  StrUtils,
  debug.info.reader.map,
  debug.info.reader.factory;

class function TCustomMapTest.HandlesFiles(const AFilename: string): boolean;
begin
  var Ext := TPath.GetExtension(AFilename);
  Result := MatchStr(Ext.ToLower, ['.map', '.jdbg', '.test']);
end;

procedure TCustomMapTest.SetUp;
begin
  FDebugInfo := TDebugInfo.Create;
end;

procedure TCustomMapTest.TearDown;
begin
  FDebugInfo.Free;
  FDebugInfo := nil;
end;

procedure TCustomMapTest.DoLoadFromFile;
begin
  (*
  ** Determine source file format
  *)
  var InputFormat: TInputFormat;
  if (not TryDetectInputFormat(TestFileName, InputFormat)) then
  begin
    var FileType := TPath.GetExtension(TestFileName);
    if (not TryStrToInputFormat(FileType, InputFormat)) then
    begin
      Check(True);
      Status('Unknown file format');
      exit;
    end;
  end;

  (*
  ** Read source file
  *)
  var Reader := CreateReader(InputFormat);
  try

    Reader.LoadFromFile(TestFileName, FDebugInfo);

  finally
    Reader.Free;
  end;

  ProcessDebugInfo(FDebugInfo);
end;

procedure TCustomMapTest.ProcessDebugInfo(DebugInfo: TDebugInfo);
begin
  Check(DebugInfo.Segments.Count > 0, 'No segments');
  Check(DebugInfo.Modules.Count > 0, 'No modules');
  if (DebugInfo.SourceFiles.Count = 0) then
    Self.Status('No source files');
end;

procedure TTestFileReader.TestLoadFromFile;
begin
  DoLoadFromFile;
end;

procedure TTestFileReader.TestRobustness;
begin
  // Force Map reader on the ELF map file to verify robustness (no crash)
  if not TestFileName.Contains('linux_elf') then
  begin
    Check(True);
    exit;
  end;

  var Reader := TDebugInfoMapReader.Create;
  try
    var DebugInfo := TDebugInfo.Create;
    try
      Reader.LoadFromFile(TestFileName, DebugInfo);
      // We don't check for success, just that it didn't crash
      Check(True);
    finally
      DebugInfo.Free;
    end;
  finally
    Reader.Free;
  end;
end;


{ TFolderTestSuiteSkipErrors }

procedure TFolderTestSuiteSkipErrors.ProcessFolder(Suite: ITestSuite; TestClass: TFileTestCaseClass; const NameOfMethod, Path,
  FileMask: string; Recursive: Boolean);
begin
  if SameText(TPath.GetFileName(Path), 'errors') then
    exit;

  inherited;
end;

{ TFolderTestSuiteOnlyErrors }

procedure TFolderTestSuiteOnlyErrors.ProcessFolder(Suite: ITestSuite; TestClass: TFileTestCaseClass; const NameOfMethod, Path,
  FileMask: string; Recursive: Boolean);
begin
  if SameText(TPath.GetFileName(Path), 'errors') then
  begin
    inherited;
    exit;
  end;

  if Recursive then
    for var Folder in TDirectory.GetDirectories(Path) do
      ProcessFolder(Suite, TestClass, NameOfMethod, Folder, FileMask, true);
end;

{ TTestFileReaderErrors }

procedure TTestFileReaderErrors.RunTest(TestResult: TTestResult);
begin
  try

    inherited;

    Fail('Passed without expected error: '+TPath.GetFileNameWithoutExtension(TestFileName));

  except
    on E: Exception do
    begin
      var Msg := E.Message.ToLower;
      Msg := StringReplace(Msg, '/', '-', [rfReplaceAll]);
      Msg := StringReplace(Msg, '"', '', [rfReplaceAll]);
      if (Msg.Contains(TPath.GetFileNameWithoutExtension(TestFileName).ToLower)) then
        Check(True)
      else
        raise;
    end;
  end;
end;

initialization
  var TestSuite: TTestSuite := TFolderTestSuiteSkipErrors.Create('Load map files', TTestFileReader, '..\..\..\Data', '*.*', True);
  RegisterTest(TestSuite);
  TestSuite := TFolderTestSuiteOnlyErrors.Create('Reader errors', TTestFileReaderErrors, '..\..\..\Data', '*.*', True);
  RegisterTest(TestSuite);
end.


