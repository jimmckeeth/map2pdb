program VCLSample;

uses
  Vcl.Forms,
  VCLmain in 'VCLmain.pas' {Form36};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm36, Form36);
  Application.Run;
end.
