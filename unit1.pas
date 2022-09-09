unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls, DBGrids,
  DBCtrls, ExtCtrls, ComCtrls, SynCompletion, SynEdit, SynHighlighterSQL,
  SynHighlighterXML, BufDataset, XMLMySQLDataSet, DB,
  XMLMySQLDatapacketReader;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Datasource1: TDatasource;
    DBGrid1: TDBGrid;
    DBNavigator1: TDBNavigator;
    PageControl1: TPageControl;
    Panel1: TPanel;
    Panel2: TPanel;
    SynEdit1: TSynEdit;
    SynEdit2: TSynEdit;
    SynSQLSyn1: TSynSQLSyn;
    SynXMLSyn1: TSynXMLSyn;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Datasource1UpdateData(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure PageControl1Change(Sender: TObject);
  private
    procedure Datasource1DataSetAfterDelete(DataSet: TDataSet);
    procedure Update(Data: PtrInt);
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;
  bd: TXMLMySQLDataSet;

implementation

uses variants;


{$R *.lfm}

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
begin
  bd.SQL := Synedit1.Text;
  Screen.Cursor := crSQLWait;
  Application.ProcessMessages;
  try
    bd.ExecSQL;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  bd.ApplyUpdates(1);
end;

procedure TForm1.Update(Data: PtrInt);
begin
  Screen.Cursor := crSQLWait;
  Application.ProcessMessages;
  bd.ApplyUpdates(1);
  Screen.Cursor := crDefault;
end;

procedure TForm1.Datasource1UpdateData(Sender: TObject);
begin
  Application.QueueAsyncCall(@Update, 0);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  bd := TXMLMySQLDataSet.Create(self);
  bd.URL := 'http://localhost/~theo/laz/query_server_xml.php';
  bd.AfterDelete := @Datasource1DataSetAfterDelete;
  DataSource1.DataSet := bd;
  //DBMemo1.DataField:='objekt.bemerkungen';
end;

procedure TForm1.PageControl1Change(Sender: TObject);
begin
  Synedit2.Text := bd.XML;
end;

procedure TForm1.Datasource1DataSetAfterDelete(DataSet: TDataSet);
begin
  Datasource1UpdateData(self);
end;

initialization
  DefaultFormatSettings.DateSeparator := '.';
  DefaultFormatSettings.ShortDateFormat := 'dd/mm/yyyy';

end.
