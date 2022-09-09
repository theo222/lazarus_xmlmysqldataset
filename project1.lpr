program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,Unit1, DB;

{$R *.res}

begin
  Application.Title:='';
  Application.Initialize;
  Application.CreateForm(TForm1,Form1);
  Application.Run;
end.

