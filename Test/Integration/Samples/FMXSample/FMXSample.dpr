program FMXSample;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  FMXMain in 'FMXMain.pas' {Form37};

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TForm37, Form37);
  Application.Run;
end.
