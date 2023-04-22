program E_Link_UpdateTool;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, Forms, Unit1, synaser;


{$R *.res}

begin
  Application.Scaled:=True;
  Application.Title:='Free E_Link Update Tool';
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

