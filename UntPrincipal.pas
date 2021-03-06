unit UntPrincipal;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,

  //Units Necessárias
  IniFiles,
  IdComponent,
  IdTCPConnection,
  IdTCPClient,
  IdHTTP,
  IdBaseComponent,
  IdMessage,
  IdExplicitTLSClientServerBase,
  IdMessageClient,
  IdSMTPBase,
  IdSMTP,
  IdIOHandler,
  IdIOHandlerSocket,
  IdIOHandlerStack,
  IdSSL,
  IdSSLOpenSSL,
  IdAttachmentFile,
  IdText;

type
  TfrmPrincipal = class(TForm)
    Button1: TButton;
    Label1: TLabel;
    Label2: TLabel;
    edtAssunto: TEdit;
    memCorpo: TMemo;
    Label3: TLabel;
    edtPara: TEdit;
    edtAnexo: TEdit;
    Button2: TButton;
    Label4: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    function EnviarEmail(const AAssunto, ADestino, AAnexo: String; ACorpo: TStrings): Boolean;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

{$R *.dfm}

procedure TfrmPrincipal.Button1Click(Sender: TObject);
begin
  if EnviarEmail(edtAssunto.Text, edtPara.Text, edtAnexo.Text, memCorpo.Lines)
  then ShowMessage('Enviado com sucesso!')
  else ShowMessage('Não foi possível enviar o e-mail!');
end;

procedure TfrmPrincipal.Button2Click(Sender: TObject);
begin
  with TOpenDialog.Create(Self) do
    if Execute then
      edtAnexo.Text := FileName;
end;

function TfrmPrincipal.EnviarEmail(const AAssunto, ADestino, AAnexo: String; ACorpo: TStrings): Boolean;
var
  IniFile              : TIniFile;
  sFrom                : String;
  sBccList             : String;
  sHost                : String;
  iPort                : Integer;
  sUserName            : String;
  sPassword            : String;

  idMsg                : TIdMessage;
  idText               : TIdText;
  idSMTP               : TIdSMTP;
  idSSLIOHandlerSocket : TIdSSLIOHandlerSocketOpenSSL;
begin
  try
    try
      //Criação e leitura do arquivo INI com as configurações
      IniFile                          := TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Config.ini');
      sFrom                            := IniFile.ReadString('Email' , 'From'     , sFrom);
      sBccList                         := IniFile.ReadString('Email' , 'BccList'  , sBccList);
      sHost                            := IniFile.ReadString('Email' , 'Host'     , sHost);
      iPort                            := IniFile.ReadInteger('Email', 'Port'     , iPort);
      sUserName                        := IniFile.ReadString('Email' , 'UserName' , sUserName);
      sPassword                        := IniFile.ReadString('Email' , 'Password' , sPassword);

      //Configura os parâmetros necessários para SSL
      IdSSLIOHandlerSocket                   := TIdSSLIOHandlerSocketOpenSSL.Create(Self);
      IdSSLIOHandlerSocket.SSLOptions.Method := sslvSSLv23;
      IdSSLIOHandlerSocket.SSLOptions.Mode  := sslmClient;

      //Variável referente a mensagem
      idMsg                            := TIdMessage.Create(Self);
      idMsg.CharSet                    := 'utf-8';
      idMsg.Encoding                   := meMIME;
      idMsg.From.Name                  := 'TESTE';
      idMsg.From.Address               := sFrom;
      idMsg.Priority                   := mpNormal;
      idMsg.Subject                    := AAssunto;

      //Add Destinatário(s)
      idMsg.Recipients.Add;
      idMsg.Recipients.EMailAddresses := ADestino;
      idMsg.CCList.EMailAddresses      := 'teste@teste.com.br';
      idMsg.BccList.EMailAddresses    := sBccList;
      idMsg.BccList.EMailAddresses    := 'teste@teste.com.br'; //Cópia Oculta

      //Variável do texto
      idText := TIdText.Create(idMsg.MessageParts);
      idText.Body.Add(ACorpo.Text);
      idText.ContentType := 'text/html; text/plain; charset=iso-8859-1';

      //Prepara o Servidor
      idSMTP                           := TIdSMTP.Create(Self);
      idSMTP.IOHandler                 := IdSSLIOHandlerSocket;
      idSMTP.UseTLS                    := utUseImplicitTLS;
      idSMTP.AuthType                  := satDefault;
      idSMTP.Host                      := sHost;
      idSMTP.AuthType                  := satDefault;
      idSMTP.Port                      := iPort;
      idSMTP.Username                  := sUserName;
      idSMTP.Password                  := sPassword;

      //Conecta e Autentica
      idSMTP.Connect;
      idSMTP.Authenticate;

      if AAnexo <> EmptyStr then
        if FileExists(AAnexo) then
          TIdAttachmentFile.Create(idMsg.MessageParts, AAnexo);

      //Se a conexão foi bem sucedida, envia a mensagem
      if idSMTP.Connected then
      begin
        try
          IdSMTP.Send(idMsg);
        except on E:Exception do
          begin
            ShowMessage('Erro ao tentar enviar: ' + E.Message);
          end;
        end;
      end;

      //Depois de tudo pronto, desconecta do servidor SMTP
      if idSMTP.Connected then
        idSMTP.Disconnect;

      Result := True;
    finally
      IniFile.Free;

      UnLoadOpenSSLLibrary;

      FreeAndNil(idMsg);
      FreeAndNil(idSSLIOHandlerSocket);
      FreeAndNil(idSMTP);
    end;
  except on e:Exception do
    begin
      Result := False;
    end;
  end;
end;

end.
