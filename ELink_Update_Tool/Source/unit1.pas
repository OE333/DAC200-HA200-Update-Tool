unit Unit1;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
StdCtrls, ComCtrls, synaser, LCLType, Buttons, Menus, RichMemo, StrUtils,
LazLogger, LazLoggerBase, Types;

Const
  FT_DLL_Name            = 'FTD2XX.DLL';           // FTDI DLL Name
  UpdTool_Version        = 'V 1.05 (32 Bit)';
  FreeVersion            = true;
  Debug                  = false;
  SupportedMasters       = 'HA 200,DAC 200';
  SupportedSlaves        = 'A200,M200';            //, M 40 HV,DAC8DSD';


type
    FT_Result            = Integer;
    ElStr                = array [0..255] of byte;

  { TForm1 }
  TForm1  = class(TForm)
    DeviceButton: TButton;
    HintLabel: TLabel;
    MsgWindow: TRichMemo;
    OpenDialog1: TOpenDialog;
    StatusLabel1: TLabel;
    UpdateButton: TButton;
    ProgressBar1: TProgressBar;
    StatusLabel: TLabel;
    Panel1: TPanel;
    Panel2: TPanel;
    VerButton: TButton;
    DevSelectBox: TComboBox;
    SendButton: TButton;
    ConnectButton: TButton;
    ComPortButton: TButton;
    ComSelectBox: TComboBox;
    SendButton1: TButton;
    Timer1: TTimer;
    procedure DeviceButtonClick(Sender: TObject);
    procedure DevSelectBoxChange(Sender: TObject);
    procedure ComPortButtonClick(Sender: TObject);
    procedure ComSelectBoxChange(Sender: TObject);
    procedure ConnectButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure SendButtonClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure UpdateButtonClick(Sender: TObject);
    procedure GetVer (var VStr, DStr: string);
    procedure SendRsCmd(Sender: TObject; const Command: string; var RetStr: string);
    procedure SendRsCmdNC(Sender: TObject; const Command: AnsiString; var RetStr: AnsiString);
    procedure Disconnect(Sender: TObject);
    procedure Connect(Sender: TObject);
  private

  public

  end;


Const
// FT_Result Values
  FT_OK = 0;
  FT_INVALID_HANDLE = 1;
  FT_DEVICE_NOT_FOUND = 2;
  FT_DEVICE_NOT_OPENED = 3;
  FT_IO_ERROR = 4;
  FT_INSUFFICIENT_RESOURCES = 5;
  FT_INVALID_PARAMETER = 6;
  FT_SUCCESS = FT_OK;
  FT_INVALID_BAUD_RATE = 7;
  FT_DEVICE_NOT_OPENED_FOR_ERASE = 8;
  FT_DEVICE_NOT_OPENED_FOR_WRITE = 9;
  FT_FAILED_TO_WRITE_DEVICE = 10;
  FT_EEPROM_READ_FAILED = 11;
  FT_EEPROM_WRITE_FAILED = 12;
  FT_EEPROM_ERASE_FAILED = 13;
  FT_EEPROM_NOT_PRESENT = 14;
  FT_EEPROM_NOT_PROGRAMMED = 15;
  FT_INVALID_ARGS = 16;
  FT_OTHER_ERROR = 17;

  // FT_List_Devices Flags
  FT_LIST_NUMBER_ONLY = $80000000;
  FT_LIST_BY_INDEX = $40000000;
  FT_LIST_ALL = $20000000;
//-------------------------------------
  RecTimeOut             = 20;
  RecTimeOutLng          = 40;
  RecTimeOutShrt         = 4;
  ErrTime0ut             = 9997;
  MaxOutlines            = 80;
  GetVerStr              = 'A9,E1,C2,04,3F,C5,00,F7';
  ProgCmd                = 'A9,C2,C2,0A,3F,00,00,FC,41,50,50,32,42,4C';
  clOrange               : TColor = $0080FF;

// P_States:
  PS_Init                =  0;
  PS_ComConfigured       = 10;
  PS_DisConnected        = 20;
  PS_Connected           = 30;
  PS_Dev_Recover         = 40;
  PS_Dev_Identified      = 50;
  PS_Dev_Bootloader      = 60;
  PS_Dev_Erased          = 70;
  PS_Dev_Programming     = 80;
  PS_Dev_Verified        = 90;

// E-Link error values
// positive values: E-Link return byte - (N)ACK, Busy, unknown command etc.
// negative values: ERROR condition occurred.
  ElErrNoErr             =  0;  // no Error
  ElErrBreak             = -1;  // Break received (instead of (N)ACK
  ElErrNoBg              = -2;  // No BusGrant received
  ElErrTimeOut           = -3;  // TimeOut while waiting for (N)ACK
  ElErrMSNotDef          = -4;  // Master/Slave not defined
  ElErrCRLF              = -5;  // CR,LF received (unexpectedly)
 //TLineDelay:=20;

Var
  FT_Enable_Error_Report : Boolean = True;    //  Used to Enable / Disable the Error Report Dialog
  FT_Device_Count : DWord;
//------------------------------------------------------------------------------
  Form1                                                      : TForm1;
  ser                                                        : TBlockSerial;
  cmd, LastRecStr, ComPort                                   : string;
  SupportedDevices                                           : string;
  Receiving, Scroll                                          : boolean;
  ElTXBuff, ElRXBuff                                         : ElStr;
  ElTXBuffPtr, ElRXBuffPtr                                   : ^integer;
  Master, Slave                                              : boolean;
  SelectedDevice, DevVer, DevModel, VerStr, FileDevStr       : string;
  BL_VSTR, BL_DSTR                                           : AnsiString;
  ElDevAddr, ElSendAddr                                      : byte;
  TXActive                                                   : boolean;
  TLineDelay                                                 : integer = 20;
  BlExpectEcho                                               : boolean;
  LastElResult                                               : integer;
  P_State                                                    : integer;


  FT_Latency                                                 : byte;
  FT_DevCnt                                                  : integer;



implementation

{$R *.lfm}
//
//// FTDI functions
//function FT_GetNumDevices(pvArg1:Pointer; pvArg2:Pointer; dwFlags:Dword):FT_Result; stdcall; External FT_DLL_Name name 'FT_ListDevices';
////------------------------------------------------------------------------------
////
//Procedure FT_Error_Report(ErrStr: String; PortStatus : Integer);
//Var Str : String;
//Begin
//If Not FT_Enable_Error_Report then Exit;
//If PortStatus = FT_OK then Exit;
//Case PortStatus of
//    FT_INVALID_HANDLE : Str := ErrStr+' - Invalid handle...';
//    FT_DEVICE_NOT_FOUND : Str := ErrStr+' - Device not found...';
//    FT_DEVICE_NOT_OPENED : Str := ErrStr+' - Device not opened...';
//    FT_IO_ERROR : Str := ErrStr+' - General IO error...';
//    FT_INSUFFICIENT_RESOURCES : Str := ErrStr+' - Insufficient resources...';
//    FT_INVALID_PARAMETER : Str := ErrStr+' - Invalid parameter...';
//    FT_INVALID_BAUD_RATE : Str := ErrStr+' - Invalid baud rate...';
//    FT_DEVICE_NOT_OPENED_FOR_ERASE : Str := ErrStr+' Device not opened for erase...';
//    FT_DEVICE_NOT_OPENED_FOR_WRITE : Str := ErrStr+' Device not opened for write...';
//    FT_FAILED_TO_WRITE_DEVICE : Str := ErrStr+' - Failed to write...';
//    FT_EEPROM_READ_FAILED : Str := ErrStr+' - EEPROM read failed...';
//    FT_EEPROM_WRITE_FAILED : Str := ErrStr+' - EEPROM write failed...';
//    FT_EEPROM_ERASE_FAILED : Str := ErrStr+' - EEPROM erase failed...';
//    FT_EEPROM_NOT_PRESENT : Str := ErrStr+' - EEPROM not present...';
//    FT_EEPROM_NOT_PROGRAMMED : Str := ErrStr+' - EEPROM not programmed...';
//    FT_INVALID_ARGS : Str := ErrStr+' - Invalid arguments...';
//    FT_OTHER_ERROR : Str := ErrStr+' - Other error ...';
//    End;
//MessageDlg(Str, mtError, [mbOk], 0);
//End;
//
//// FTD2XX functions from here
//Function GetFTDeviceCount : FT_Result;
//Begin
//Result := FT_GetNumDevices(@FT_Device_Count,Nil,FT_LIST_NUMBER_ONLY);
//If Result <> FT_OK then FT_Error_Report('GetFTDeviceCount',Result);
//End;
////
//// FTDI functions end.
////
//------------------------------------------------------------------------------
// split a delimited string into a list of strings
procedure Split(Delimiter: Char; Str: string; ListOfStrings: TStrings) ;
begin
   ListOfStrings.Clear;
   ListOfStrings.Delimiter       := Delimiter;
   ListOfStrings.StrictDelimiter := True; // Requires D2006 or newer.
   ListOfStrings.DelimitedText   := Str;
end;

procedure delay(sn : double);
var
  t:double;
begin
  t := now+(sn/(24*60*60*1000));
  Application.ProcessMessages;
  repeat
   sleep(5);
  until now>t;
end;

procedure delayNP(sn : double);
var
  t:double;
begin
  t := now+(sn/(24*60*60*1000));
  repeat
   sleep(5);
  until now>t;
end;

procedure Dbg(outstring: AnsiString);
begin
 // DebugLn('Dbg : '+outstring);
end;

// get Bootloader version and Device string in RECOVERY mode
// routine works for Master or Slave devices
//
procedure GetBLVer (var BL_VS, BL_DS: AnsiString);

  var
    i, TL                               : integer;
    LCmd                                : AnsiString;

  begin
                BL_VS:='';
                BL_DS:='';

                LCmd:=#13+#10;                    // CR/LF
                for i:=1 to Length(LCmd) do ser.SendByte(ord(LCmd[i]));

                LCmd:=#86+#13+#10;                    //"V" get version
                for i:=1 to Length(LCmd) do ser.SendByte(ord(LCmd[i]));

                ElRXBuffPtr:=@ElRXBuff;
                ser.RecvBufferEx(ElRXBuffPtr, 40, 20);     // try to rx CR/LF or #>

                i:=0;
                while (ElRXBuff[i]<>$A9) and (i<40) do i:=i+1;    // find start of ELink telegram

                if i>20 then   // >20 -> no A9 tel start char. found
                begin          // no BL Version string received (device w. old Bootloader?)
                  BL_DS:='UKN';
                  BL_VS:='UKN';
                end
                else begin                   // BL version string received.
                  i:=i+3;
                  TL:= i+ElRXBuff[i];        // length byte + i -> TL
// get BL version string
                  i:=i+5;                    // i now at start of version string
                  while ElRXBuff[i]<>0 do    // ASCIIZ delimiter of version string
                  begin
                    BL_VS:=BL_VS+char(ElRXBuff[i]);
                    i:=i+1;
                  end;
// get BL device string
                  i:=i+1;
                  while i<=TL do             // while i within telegram
                  begin
                    BL_DS:=BL_DS+char(ElRXBuff[i]);
                    i:=i+1;
                  end;
                end;
       end;

// wait until T+A device quiet (not sending anything anymore)....
procedure UntilDevQuiet(var rStr: string);

var       rChr                  : Byte;

begin
  rStr:='';
  repeat                          // clear queue of RXed Bytes..
    rChr:=ser.RecvByte(50);
    if not ser.LastError=ErrTime0ut then rStr:=rStr+char(rChr);
  until ser.LastError=ErrTime0ut;
end;


procedure AddColorStr(Memo: TRichMemo; s: string; const col: TColor = clBlack; const NewLine: boolean = true);
begin
  with Memo do
  begin
    if NewLine then
    begin
      Lines.Add('');
      Lines.Delete(Lines.Count - 1); // avoid double line spacing
    end;

    SelStart  := Length(Text);
    SelText   := s;
    SelLength := Length(s);
    SetRangeColor(SelStart, SelLength, col);

    // deselect inserted string and position cursor at the end of the text
    SelStart  := Length(Text);
    SelText   := '';
  end;
end;


procedure AddLineQ(Memo: TRichMemo; OutStr: string);

var       NumOutLines    : integer;

begin
  // not TxActive then DebugLn('Msg : '+OutStr);
  NumOutLines:=Memo.Lines.Count;
  while NumOutLines>(MaxOutlines-1) do begin
     Memo.Lines.Delete(0);
     NumOutLines:=NumOutLines-1;
  end;
  Memo.Lines.Add(OutStr);
  if Scroll then Memo.SelStart := Length(Memo.Lines.Text);
  Dbg(OutStr);                         // write message to debug.
end;

// add a line to MemoX
procedure AddLine(Memo: TRichMemo; OutStr: string);
begin
  AddLineQ(Memo, OutStr);
  Application.Processmessages;
end;

// add a line to MemoX
procedure AddDbg(Memo: TRichMemo; OutStr: string);
begin
  if Debug then begin
    AddColorStr(Memo,'DEBUG: '+OutStr, clBlue, true);
  end;
end;

procedure AddInf(Memo: TRichMemo; OutStr: string);
begin
  AddColorStr(Memo,'INFO : '+OutStr, clBlack, true);
end;

procedure AddInfH(Memo: TRichMemo; OutStr: string);
begin
  AddColorStr(Memo,'INFO : ', clBlack, true);
  AddColorStr(Memo,OutStr, clOrange, false);
end;

procedure AddErr(Memo: TRichMemo; OutStr: string);
begin
  AddColorStr(Memo,'ERROR: ', clRed, true);
  AddColorStr(Memo,OutStr, clBlack, false);
end;

procedure AddWrn(Memo: TRichMemo; OutStr: string);
begin
  AddColorStr(Memo,'WARN : ', clOrange, true);
  AddColorStr(Memo,OutStr, clBlack, false);
end;

procedure AddErrC2(Memo: TRichMemo; s1,s2,s3,s4,s5: string);

begin
  AddColorStr(Memo,'ERROR: ', clRed, true);
  AddColorStr(Memo,s1, clBlack, false);
  AddColorStr(Memo,s2, clBlue, false);
  AddColorStr(Memo,s3, clBlack, false);
  AddColorStr(Memo,s4, clBlue, false);
  AddColorStr(Memo,s5, clBlack, false);
  AddColorStr(Memo,'');
end;


procedure ClearMsgWindow(Memo: TRichMemo);

begin
  //MsgStringList.Clear;
  Memo.Lines.Clear;
  Application.Processmessages;
end;

procedure ResetDevice();
begin
  SelectedDevice:='';
  DevVer:='';
  DevModel:='';
  VerStr:='';
  FileDevStr:='';
end;

// check if we receive a bootloader prompt on CR,LF
// if yes, then the connected device is in bootloader (recovery) state.
// this routine uses direct RS232, not E-Link.
// procedure is identical for connected Master&Slave devices.

procedure CheckRecoveryMode();

var
  lRecByte                    : byte;
  RStr                        : string;

begin
  RStr:='';
  ElTXBuff[0]:=$0D;                        // CR
  ElTXBuff[1]:=$0A;                        // LF
  ElTXBuffPtr:=@ElTXBuff;
  ser.SendBuffer(ElTXBuffPtr, 2);
  lRecByte:=ser.RecvByte(RecTimeOutShrt);  // wait for answer
  if lRecByte = $23 then                   // received # ?
     begin
       P_State:= PS_Dev_Recover;
       UntilDevQuiet(RStr);
     end;
end;

// Decode received E-Link Device string (9th char onwards in rx'ed EL Telegram)
// DeviceString contains FW-Version and possibly DeviceModel
// Note: FW-Version and DevModelString are both ASCIIZ strings.
procedure DecodeVer (RStr: ElStr; var VStr, DStr: string);

var       i         : integer;
          TelLen    : integer;

begin
  VStr:='';
  DStr:='';
  TelLen:=RStr[3]+4;       // get length byte from E.Link Telegram

  i:=8;                     // start with 9th rx'ed byte (RStr counts from 0).
  while RStr[i]<>0 do
  begin
    VStr:=VStr+char(RStr[i]);
    i:=i+1;
  end;

// Check if DeviceTypeString follows.
// following chars = (ASCIIZ StringEnd(0) & Chksum) if NO DeviceString follows
//                 or ASCIIZ StringEnd(0) & DeviceString
  i:=i+1;           // -> next char.
  if RStr[i+1]=0 then DStr:='UKN'   // next+1=0 -> no DeviceString avail.
  else while i < TelLen do          // <>0 : store ASCIIZ DeviceStr.
         begin
           DStr:=DStr+char(RStr[i]);
           i:=i+1;
         end;
end;


function BusGranted (ElAddr: byte):boolean;

var
BG                          : boolean;
lRecByte                    : byte;

// try to get EL-bus
begin
  BG := false;

  Ser.SetBreakOn();                             // added function in synaser
  lRecByte:=ser.RecvByte(RecTimeOut);           // wait for '9A' from Master
  Ser.SetBreakOff();                            // added function in synaser
  if lRecByte = $9A then
     begin
       Delay(2);                                // +29.08.2022
       ElTXBuff[0]:=$AA;                        // send BusRequest
       ElTXBuff[1]:=ElAddr;                     // .. with address
       ElTXBuffPtr:=@ElTXBuff;
       ser.SendBuffer(ElTXBuffPtr, 2);
       lRecByte:=ser.RecvByte(RecTimeOutShrt);  // wait for answer
       if lRecByte = $A5 then                   // received BusGrant byte ?
       begin
         lRecByte:=ser.RecvByte(RecTimeOutShrt);// wait for address byte
         if lRecByte = ElAddr then BG:=true;    // bus granted to me ?
       end;
     end;
  result:=BG;
end;

//------------------------------------------------------------------------------
// send ELink Telegram to Master - with BusRequest
//
function Send_2_Master (EL_Tel: string; SendAddr, DevAddr: byte) : Integer;
var
   c,k,ChkSum                        : integer;
   SL                                : TStringList;

begin
  LastElResult:=0;
  for k:=0 to length(ElRXBuff) do ElRXBuff[k]:=0; // clear receive buffer
  ser.Purge;                                      // reset serial buffers
  if BusGranted(SendAddr) then                    // have we got the bus ?
  begin
    ElTXBuffPtr:=@ElTXBuff;
    ElRXBuffPtr:=@ElRXBuff;

    ChkSum := 0;
    SL := TStringList.Create;
    try
      SL.Delimiter:=',';                       // split comma separated list
      SL.DelimitedText:=AnsiUppercase(EL_Tel);
      for k := 0 to SL.Count-1 do begin        // fill TX Buffer
        case k of
        1 : ElTXBuff[k]:= DevAddr;             // receiver address
        2 : ElTXBuff[k]:= SendAddr;            // sender address
        else  ElTXBuff[k]:=Hex2Dec('$'+SL[k]);
        end;
        ChkSum := ChkSum+ElTXBuff[k];          // add byte to checksum
      end;
    finally
      SL.Free;
    end;
    ElTXBuff[k+1]:= (ChkSum mod 256);          // checksum

    ser.SendBuffer(ElTXBuffPtr, k+2);          // send telegram
    c:=ser.WaitingDataEx;
    delay(10);
    ser.RecvBufferEx(ElRXBuffPtr, k+3, 10);    // RX LoopThrough telegram & (N)ACK

    if ser.LastError=ErrTimeout then result:=ElErrTimeOut
    else result:=ElRXBuff[k+2];                // this is the (N)ACK byte.
  end
  else result:= ElErrNoBg;                     // BusGrant ERROR
  LastElResult:=result;
end;


//------------------------------------------------------------------------------
// send ELink Telegram to Slave
//
function Send_2_Slave (ElTel: string; SendAddr, DevAddr: byte):Integer;
var
k, ChkSum, TxR              : integer;
SL                          : TStringList;

begin
  LastElResult:=0;
  ser.Purge;                                 // reset serial buffers
  ElTXBuffPtr:=@ElTXBuff;
  ChkSum := 0;
  SL := TStringList.Create;
  try
    SL.Delimiter:=',';                       // split comma separated list
    SL.DelimitedText:=AnsiUppercase(ElTel);
    for k := 0 to SL.Count-1 do begin        // fill TX Buffer
      case k of
        1 : ElTXBuff[k]:= DevAddr;           // receiver address
        2 : ElTXBuff[k]:= SendAddr;          // sender address
      else  ElTXBuff[k]:=Hex2Dec('$'+SL[k]);
      end;
      ChkSum := ChkSum+ElTXBuff[k];          // add byte to checksum
    end;
  finally
    SL.Free;
  end;
  ElTXBuff[k+1]:= (ChkSum mod 256);          // checksum
  ser.SendBuffer(ElTXBuffPtr, k+2);          // send telegram
  TxR:=ser.RecvByte(RecTimeOutShrt); // get (N)ACK byte ($99, 96 etc or break)

  if ser.LastError=ErrTimeout then LastElResult:=ElErrTimeOut
  else
    case TxR of
      0     :   LastElResult:=ElErrBreak;    // Slave returned break (= BusRequest).
      13    :   begin                        // Slave returned 0D,0A (= in BootLoader) ?
                  TxR:=ser.RecvByte(RecTimeOutShrt);
                  if TxR = 10 then LastElResult:=ElErrCRLF
                end;
      else LastElResult := TxR;
    end;
  result:=LastElResult;
end;

function SendELCommand(Command: string):integer;

begin
  LastElResult:=0;
  if Master then result := Send_2_Master(Command, ElSendAddr, ElDevAddr)
  else if Slave then result := Send_2_Slave(Command, ElSendAddr, ElDevAddr)
  else result:=ElErrMSNotDef;   // Master&Slave not defined.
  LastElResult:=result;
end;

// Master: BusRequest (Break) received.
// Grant Bus and receive EL telegram.
// Slave: Receive EL telegram.
procedure RecvElStr (var RStr: ElStr; var OK: boolean);

var       b                    : byte;
          l, ChkS, TLen        : integer;
          BG                   : boolean;

begin
  OK:=false;
  BG:=false;
  for l:=0 to length(RStr) do RStr[l]:=0;

  if Slave then                          // if connected device=Slave: GrantBus
    begin
     ElTXBuff[0]:=$9A;                   // send BusSenderRequest
     ElTXBuffPtr:=@ElTXBuff;
     ser.SendBuffer(ElTXBuffPtr, 1);
     b:= ser.RecvByte(RecTimeOutShrt);   // AA ?
     if b = $AA then
     begin
       b := ser.RecvByte(RecTimeOutShrt);// receive requesting ADDR
       ElTXBuff[0]:=$A5;                 // send BusGrant
       ElTXBuff[1]:= b;                  // .. with rx'ed address
       ElTXBuffPtr:=@ElTXBuff;
       ser.SendBuffer(ElTXBuffPtr, 2);
       BG:=true;
     end;
    end
  else if Master then BG:=true;          // connected device=Master: no BG

// RX telegram (identical for connected Master & Slave devices)
  if BG then
  begin
    ChkS:=0;                             // init CheckSum
    TLen:=0;                             // reset TelegramLength
    l:=0;
    repeat                               // receive until time out (MTX loop through + (N)ACK byte)
      if l=0 then RStr[l]:= ser.RecvByte(RecTimeOutLng)
      else RStr[l]:= ser.RecvByte(RecTimeOutShrt);// get all received bytes
      if l=3 then TLen:=RStr[l];         // store LengthByte
      if l=TLen+4 then break;            // all telegram bytes completely rx'ed.
      ChkS:=ChkS+RStr[l];
      l:=l+1;
    until ser.LastError=ErrTimeOut;
    if ser.LastError=0 then
    begin
      ChkS:= ChkS mod 256;               // checksum
      if RStr[l] = ChkS then OK:=true;
      if OK then ser.SendByte($99)       // ACK
      else ser.SendByte($69);            // Error
    end;
  end;
end;

//----------------------------------------------------------------------------
// Connect to DEVICE
function ComConfig(MsgWindow:TRichMemo):boolean;
//var      //devname                                    :string;
         //devhandle                                  :THandle;
         //Latency                                    :byte;
begin
  AddInf(MsgWindow, 'Selected COM Port '+ComPort);
  AddInf(MsgWindow, 'Configuring       '+ComPort);

    try
       ser.Connect(ComPort);
       Sleep(100);

       ser.config(230400, 8, 'N', SB1, False, False);
       AddInf(MsgWindow, 'COM Port: ' + ser.Device + '   Status: ' + ser.LastErrorDesc +'   '+ Inttostr(ser.LastError));
       if ser.LastError = 0 then P_State:=PS_ComConfigured
       else
         begin
           AddErr(MsgWindow, 'Can not connect to Serial Port!  ( '+ComPort+' )');
           if ser.LastError=87 then  AddInf(MsgWindow, 'Required baud rate not supported');
         end;
    except
       AddErr(MsgWindow, 'Can not connect to Serial Port !  ( '+ComPort+' )');
    end;

  if P_State=PS_ComConfigured then result:=true
  else begin
         result:=false;
         if ser.InstanceActive then
           begin
            Ser.Flush;       // discard any remaining output
            Ser.CloseSocket;
           end;
       end;
end;


// convert string to HEX-coded string
function StringToHex(Stringy: string): string;
var
 i, i2: Integer;
 s: string;

begin
 s:='';
 i2 := 1;
 for i := 1 to Length(Stringy) do
  begin
   Inc(i2);
    if i2 = 2 then
     begin
      if (i>1) then s  := s + ' ';
      i2 := 1;
     end;
    s := s + IntToHex(Ord(Stringy[i]), 2);
  end;
 Result := s;
end;

//##############################################################################
{ TForm1 }
//
procedure TForm1.SendRsCmdNC(Sender: TObject; const Command: AnsiString; var RetStr: AnsiString);
var rStr            : string;
    ChrIn, rChr     : Char;
    i               : integer;
    LCmd, RetStr2   : AnsiString;

begin
   rStr:='';
   //DebugLn('CmC : '+Command);
   UntilDevQuiet(rStr);
   AddDbg(MsgWindow, '[SendRSCmdNC]: String RXed while waiting for QUIET: '+rStr);
   AddDbg(MsgWindow, '[SendRSCmdNC]: sending: '+Command);

   RetStr:='';
   LCmd:=Command+#13+#10;
   for i:=1 to Length(LCmd) do begin
     ser.SendByte(ord(LCmd[i]));
     ChrIn:=Char(ser.RecvByte(20));        // 27.07.2022 - was 50ms before
     if (not (ser.LastError=ErrTime0ut)) then RetStr:=RetStr+ChrIn;
   end;
   AddDbg(MsgWindow, 'Return Bytes received: '+RetStr);

   RetStr2:=ser.RecvString(500);     // receive reply
   AddDbg(MsgWindow, '[SendRSCmdNC]: ReturnString received: '+RetStr2);

   if not ser.LastError=ErrTime0ut then begin
    RetStr:=RetStr2;
    rStr:='';
    repeat                          // wait for further messages from DAC8DSD
      rChr:=char(ser.RecvByte(200));
      if (not (ser.LastError=ErrTime0ut)) then rStr:=rStr+rChr;
    until ser.LastError=ErrTime0ut;
    AddDbg(MsgWindow, '[SendRSCmdNC]: Bytes received while wait: '+rStr);
    end;
end;


procedure TForm1.SendRsCmd(Sender: TObject; const Command: AnsiString; var RetStr: AnsiString);

begin
  if P_State >= PS_Connected then SendRsCmdNC(Sender, Command, RetStr)
  else AddErr(MsgWindow, '[SendRsCmd]: not connected !');
end;

// disconnect from T+A device
procedure TForm1.Disconnect(Sender: TObject);

begin
  AddInf(MsgWindow, 'disconnecting ...');
  P_State := PS_DisConnected;
  if ser.InstanceActive then
    begin
      Ser.Flush;       // discard any remaining output
      Ser.CloseSocket;
    end;
  UpdateButton.Visible:=false;
  UpdateButton.Enabled:=false;
  Progressbar1.Visible:=false;
  Timer1.Enabled := false;
  ClearMsgWindow(MsgWindow);
  ComSelectBox.Enabled:=true;
  DevSelectBox.Enabled:=true;
  StatusLabel.Caption := 'Disconnected';
  StatusLabel.Color := clRed;
  ConnectButton.Caption := 'Connect';
  DevSelectBox.Enabled:=true;
  Application.Processmessages;
end;


// try to connect to T+A device
procedure TForm1.Connect(Sender: TObject);

var       DevStrMatch            : boolean;
          i                      : integer;
          Reply                  : integer;

begin
  DevSelectBox.Enabled:=false;
  AddInf(MsgWindow, 'Connecting ...');
  P_State := PS_DisConnected;

  if ComConfig(MsgWindow) then             // COM port successfully configured ?
    begin
      AddInf(MsgWindow, 'Serial Interface configured.');
      AddInf(MsgWindow,'Gathering Status Information - Please Wait ...');
      GetVer(DevVer, DevModel);

  //       recovery device erkennung muss noch mit A200/M200 getestet wrden

      case P_State of
        PS_Dev_Recover    :  begin
                               if DevModel='UKN' then
                               begin            // BL Version was NOT received (maybe HA200 V1.00)
                                 Reply := Application.MessageBox('WARNING: Device type could not be determined'
                                                  + sLineBreak + '(could be HA200 with FW Version 1.xx)'
                                                  + sLineBreak + ''
                                                  + sLineBreak + 'Verify that the correct T+A Device is selected'
                                                  + sLineBreak + ''
                                                  + sLineBreak + 'Continue Recovery ?'
                                                  , 'No Device type received', MB_ICONQUESTION + MB_YESNO);

                                 if Reply = IDYES then
                                   begin
                                     UpdateButton.Caption:='Recover';
                                     AddInfH(MsgWindow,'Unidentified T+A Device in Recovery Mode connected.');
                                     StatusLabel.Caption:='Connected to T+A device in Recovery Mode';
                                     StatusLabel.Color := clOrange;
                                   end
                                 else begin
                                   P_State := PS_DisConnected;    //hier abbrechen - nicht updaten !!!
                                   DevSelectBox.enabled := true;
                                   end;
                               end
                               else begin       // BL Version was received

                                 for i:=1 to length(SelectedDevice) do begin
                                   if i<=length(DevModel)then
                                      begin
                                        if SelectedDevice[i]<>DevModel[i]then DevStrMatch:=false;    // strings don't match
                                      end
                                      else DevStrMatch:=false;            // lenngth(DevModel) < length(SelectedDevice)
                                 end;
                                 if not DevStrMatch then begin
                                   AddErrC2(MsgWindow, 'Detected device [',DevModel,'] does NOT match selected device [',SelectedDevice,']');

                                   AddInfH(MsgWindow,'|------------------------------------------------------------------|');
                                   AddInfH(MsgWindow,'| #                                                                |');
                                   AddInfH(MsgWindow,'| #   Select the correct device ...                                |');
                                   AddInfH(MsgWindow,'| #                                    then try to re-connect.     |');
                                   AddInfH(MsgWindow,'| #                                                                |');
                                   AddInfH(MsgWindow,'|------------------------------------------------------------------|');

                                   P_State := PS_DisConnected;    //hier abbrechen - nicht updaten !!!
                                   DevSelectBox.enabled := true;
                                 end
                                 else begin
                                   UpdateButton.Caption:='Recover';
                                   AddInfH(MsgWindow,'T+A Device in Recovery Mode connected.');
                                   StatusLabel.Caption:='Connected to T+A device in Recovery Mode';
                                   StatusLabel.Color := clOrange;
                                 end;
                               end;
                             end;

        PS_Dev_Identified :  begin
                               DevStrMatch:=true;
                               for i:=1 to length(SelectedDevice) do begin
                                 if i<=length(DevModel)then
                                    begin
                                      if SelectedDevice[i]<>DevModel[i]then DevStrMatch:=false;    // strings don't match
                                    end
                                    else DevStrMatch:=false;            // lenngth(DevModel) < length(SelectedDevice)
                               end;
                               if not DevStrMatch then begin
                                 AddErrC2(MsgWindow, 'Detected device [',DevModel,'] does NOT match selected device [',SelectedDevice,']');

                                 AddInfH(MsgWindow,'|------------------------------------------------------------------|');
                                 AddInfH(MsgWindow,'| #                                                                |');
                                 AddInfH(MsgWindow,'| #   Select the correct device ...                                |');
                                 AddInfH(MsgWindow,'| #                                    then try to re-connect.     |');
                                 AddInfH(MsgWindow,'| #                                                                |');
                                 AddInfH(MsgWindow,'|------------------------------------------------------------------|');

                                 P_State := PS_DisConnected;    //hier abbrechen - nicht updaten !!!
                                 DevSelectBox.enabled := true;
                               end
                               else begin
                                 UpdateButton.Caption:='Update';
                                 StatusLabel.Caption:='Connected to '+DevModel;
                                 StatusLabel.Color := clLime;
                               end;
                             end;

        PS_Connected      :  begin  // Device does not support DevString command
                               UpdateButton.Caption:='Update';
                               if (DevModel='A200') or (DevModel='M200') then begin
                                 AddInfH(MsgWindow,'T+A Device without VersionString support');
                               end
                               else begin
                                 AddWrn(MsgWindow,'T+A Device UNKNOWN');
                                 AddWrn(MsgWindow,'Assuming Device = Selected Device ['+SelectedDevice+']');
                               end;
                               StatusLabel.Caption:='Connected to unknown T+A device';
                               StatusLabel.Color := clLime;
                             end

        else begin                // no connection to T+A device established
            AddInfH(MsgWindow,'|------------------------------------------------------------------|');
            AddInfH(MsgWindow,'| #   Check if correct COM Port selected                           |');
            AddInfH(MsgWindow,'| #   Check if correct T+A device selected                         |');
            AddInfH(MsgWindow,'| #   Check if T+A device is switched ON                           |');
            if FreeVersion
              then AddInfH(MsgWindow,'| #   Check cables, check if RX/TX lines resersed                  |')
              else AddInfH(MsgWindow,'| #   Check cables and Master/Slave switch of Programming Adapter  |');
            AddInfH(MsgWindow,'|                                                                  |');
            AddInfH(MsgWindow,'| #    Then try again to connect.                                  |');
            AddInfH(MsgWindow,'|------------------------------------------------------------------|');
            DevSelectBox.enabled := true;

// Communication failure due to too long FTDI latency ???
        //    GetFTDeviceCount;            // check if FTDI device present
        //    if FT_Device_Count > 0 then  // if FTDI detected output warning to ckeck the latency setting.
        //    begin
            AddInfH(MsgWindow,'|------------------------------------------------------------------|');
            AddInfH(MsgWindow,'| #   ##############   For FTDI RS232 adaptors    ################ |');
        //    AddInfH(MsgWindow,'|                                                                  |');
        //    AddInfH(MsgWindow,'| #   FTDI USB to RS232 adaptor detected                           |');
            AddInfH(MsgWindow,'| #                                                                |');
            AddInfH(MsgWindow,'| #   Check & set latency in Windows Device Manager                |');
            AddInfH(MsgWindow,'| #   Latency for FTDI adaptors must be set to 1ms !!!             |');
            AddInfH(MsgWindow,'| #   Aftersetting latency re-start this E_Link Update Tool.       |');
            AddInfH(MsgWindow,'|                                                                  |');
        //    AddInfH(MsgWindow,'|     Stopping & leaving program....                               |');
            AddInfH(MsgWindow,'|------------------------------------------------------------------|');
            //delay(10000);
            //FormDestroy(self);
            //halt;
        //    end;

            StatusLabel.Color := clRed;
            StatusLabel.Caption := 'Not connected';
            UpdateButton.visible:=false;
        end;
      end;
      if P_State >= PS_Connected then begin     // successfully connected
        ComSelectBox.Enabled:=false;
        ComPortButton.Enabled:=false;
        DevSelectBox.Enabled:=false;
        DeviceButton.Enabled:=false;;
        ConnectButton.Caption := 'Disconnect';
        ConnectButton.Caption:='Cancel Update';
        ConnectButton.Enabled:=true;
        UpdateButton.Visible:=true;
        UpdateButton.Enabled:=true;
        AddInf(MsgWindow,'Success: all pre-checks completed.');
        if P_State = PS_Dev_Recover then AddInfH(MsgWindow,'##### We are ready to start Recovery.')
        else AddInfH(MsgWindow,'##### We are ready to start update.');
      end;
    end

    else begin                        // COM port NOT successfully configured
      StatusLabel.Caption:='Disonnected';
      ConnectButton.Caption:='Cancel Update';
    end;
end;


procedure TForm1.ComPortButtonClick(Sender: TObject);
begin
  ComSelectBox.Visible := true;
  ComSelectBox.Enabled := true;
  ComPortButton.enabled := false;
end;

procedure TForm1.DevSelectBoxChange(Sender: TObject);
begin
   SelectedDevice := DevSelectBox.Items[DevSelectBox.ItemIndex];  // get selected Device
   AddInf(MsgWindow, 'Device '+SelectedDevice+' selected');
   Master:=false;
   Slave:=false;
   case SelectedDevice of
     'HA 200'    : begin
                    Master:=true;
                    ElDevAddr:=$C2;             // ELink Address of connected device
                    ElSendAddr:=$C5;            // SenderAddress (Addr. of this program)
                    BlExpectEcho:=false;        // no Echo in Bootloader
                    FileDevStr:='HA_200';
                    SelectedDevice:='HA200'     // this is the DeviceName as reported by device
                   end;

     'DAC 200'   : begin
                    Master:=true;
                    ElDevAddr:=$C2;             // ELink Address of connected device
                    ElSendAddr:=$C5;            // SenderAddress (Addr. of this program)
                    BlExpectEcho:=false;        // no Echo in Bootloader
                    FileDevStr:='DAC_200';
                    SelectedDevice:='DAC200'    // this is the DeviceName as reported by device
                   end;

     'A200'      : begin
                    Slave:=true;
                    ElDevAddr:=$E1;
                    ElSendAddr:=$C2;
                    BlExpectEcho:=true;
                    FileDevStr:='A_200';
                    SelectedDevice:='A200'      // this is the DeviceName as reported by device
                   end;

     'M200'      : begin
                    Slave:=true;
                    ElDevAddr:=$E1;
                    ElSendAddr:=$C2;
                    BlExpectEcho:=true;
                    FileDevStr:='M_200';
                    SelectedDevice:='M200'      // this is the DeviceName as reported by device
                   end;

     'M 40 HV'   : begin
                    Slave:=true;
                    ElDevAddr:=$E1;
                    ElSendAddr:=$C2;
                    BlExpectEcho:=true;
                    FileDevStr:='M 40  ';
                    SelectedDevice:='M40'       // this is the DeviceName as reported by device
                   end;

     'DAC8DSD'   : begin
                    Master:=true;
                    ElDevAddr:=$C2;
                    ElSendAddr:=$C5;
                    BlExpectEcho:=false;
                    FileDevStr:='DAC_8_DSD';
                    SelectedDevice:='DAC8DSD'   // this is the DeviceName as reported by device
                   end;
   end;
   ConnectButton.visible:=true;
   ConnectButton.enabled:=true;
end;

procedure TForm1.DeviceButtonClick(Sender: TObject);
begin
  DevSelectBox.visible:=true;
  DevSelectBox.enabled:=true;
  DeviceButton.enabled := false;
end;

procedure TForm1.ComSelectBoxChange(Sender: TObject);
begin
   Disconnect(self);
   ComPort := ComSelectBox.Items[ComSelectBox.ItemIndex];  // get selected COM Port
   AddInf(MsgWindow, 'COM Port '+ComPort+' selected');

   ComPortButton.enabled := false;
   DeviceButton.visible:=true;
   DeviceButton.enabled:=true;
end;


procedure TForm1.ConnectButtonClick(Sender: TObject);
begin
  case ConnectButton.Caption of
    'Disconnect'     : Disconnect(self);
    'Cancel Update'  : Disconnect(self);
    'Connect'        : Connect(self);
  end;
end;


procedure TForm1.FormCreate(Sender: TObject);

var       DevList                         : TStringList;
          c                               : integer;

begin
  //DebugLn('---------------------------------------------------------------------');
  //DebugLn('Starting....');

  ser:=TBlockSerial.Create;            // Serial Interface

  ResetDevice;
  Receiving:=false;
  P_State := PS_Init;

  StatusLabel.Caption:='Not connected';
  ComPortButton.Caption := 'Select COM Port';

  ComSelectBox.enabled:=false;
  ComSelectBox.visible:=false;
  ComSelectBox.Items.CommaText := GetSerialPortNames();
  if ComSelectBox.Items.Count>=1 then
    begin
      ComSelectBox.ItemIndex:=0;
      ComPort := ComSelectBox.Items[ComSelectBox.ItemIndex];  // 1st from list as start value
    end;

  DevSelectBox.enabled:=false;
  DevSelectBox.visible:=false;
  DevSelectBox.Items.Clear;
  DevList := TStringList.Create();   // assign supported devices to DevSelectBox
  SupportedDevices:=SupportedMasters+','+SupportedSlaves;
   try
     Split(',', SupportedDevices, DevList) ;
     DevSelectBox.Items:=DevList;
   finally
     DevList.Free;
   end;
  DevSelectBox.ItemIndex:=0;
  ComPort := DevSelectBox.Items[DevSelectBox.ItemIndex];  // 1st from list as start value
  ConnectButton.enabled:=false;
  ConnectButton.visible:=false;

  VerButton.enabled:=false;
  VerButton.visible:=false;

  UpdateButton.Visible:=false;
  UpdateButton.Enabled:=false;

  MsgWindow.Lines.Clear;
  AddDbg(MsgWindow, 'Debug Messages are ON');
  Scroll:=true;     // default: scrolling = ON.

  if       Screen.Fonts.IndexOf('Courier New') <> -1 then
           MsgWindow.Font.Name := 'Courier New'
  else if  Screen.Fonts.IndexOf('DejaVu Sans Mono') <> -1 then
           MsgWindow.Font.Name := 'DejaVu Sans Mono'
  else if  Screen.Fonts.IndexOf('Courier 10 pitch') <> -1 then
           MsgWindow.Font.Name := 'Courier 10 pitch';

  Timer1.Interval := 1;
  Timer1.Enabled  := true;
  if FreeVersion then Form1.Caption := Form1.Caption+'   (Free Version)         '+UpdTool_Version
  else Form1.Caption := 'T+A  '+ Form1.Caption+'            '+UpdTool_Version;;
end;


procedure TForm1.FormDestroy(Sender: TObject);
begin
  Dbg('Destroying Form');
  Timer1.Enabled  := false;
  if ser.InstanceActive then
  begin
     Dbg('Destroying SerialInstance');
     Ser.Flush;       // discard any remaining output
     Ser.CloseSocket;
     Ser.Destroy;
  end;
  inherited;
end;


procedure TForm1.SendButtonClick(Sender: TObject);
//var
//  i                         : integer;
//ElSendAddr                     : byte;
//const
//  TestStr                   : string = 'A9, C2, EE, 01, 84';

begin
   //ElSendAddr:=$C2;
   //i := Send_2_Master(TestStr, ElSendAddr, ElDevAddr);
   //if i= 0 then AddDbg(MsgWindow, 'Telegram sent - Result ok') else AddErr(MsgWindow, 'NOT ok') ;
end;


procedure TForm1.Timer1Timer(Sender: TObject);
begin
  //RecvStr:=ser.RecvString(1);
  //if RecvStr<>'' then begin
  //   AddDbg(MsgWindow, RecvStr);
  //   if RecvStr[1]='#' then
  //   begin
  //    if not Monimode then begin
  //     CmdLabel.Caption:='Command (Bootloader)';
  //     MoniMode:=true;
  //    end;
  //    MoniMode:=true;
  //   end;
  //   if ((RecvStr[1]='$')) then
  //   begin
  //    if Monimode then begin
  //     CmdLabel.Caption:='Command';
  //     MoniMode:=false;
  //    end;
  //   end;
  //   RecvStr:='';
  //   Application.Processmessages;
  //end;
end;

procedure TForm1.UpdateButtonClick(Sender: TObject);
var filename, SendS, RecS, RetS, CpS, ChkS    : string;
    fwFile                                    : TextFile;
    fwFileOpen, FlashErr, StopFlash           : boolean;
    i,j,FSize,Reply, CkSRes                   : integer;
    PBFull                                    : Real;
    TstStr                                    : string;
    B,C                                       : byte;
    Lines                                     : TStrings;

begin
  RetS:='';
  Timer1.Enabled:=false;
  StopFlash:=false;
  fwFileOpen:= false;
  ConnectButton.Enabled:=false;

  ComPortButton.Enabled:=false;
  ConnectButton.Enabled:=false;
  UpdateButton.Enabled:=false;
  UpdateButton.Color:=clRed;
  AddInf(MsgWindow, 'Open File');

  if OpenDialog1.Execute then begin               // Open Firmware File
    filename := OpenDialog1.Filename;
    AddInf(MsgWindow, filename);
    AssignFile(fwFile, filename);
    FSize:=FileSize(filename);                    // get filesize for progressbar
    AddInf(MsgWindow, 'FileSize= '+IntToStr(FSize));
    PBFull:= FSize/5000;
    fwFileOpen := true;                           // assume file will be opened
      try                                         // Open the file for reading
        reset(fwFile);
      except
        on E: EInOutError do
         begin
           Dbg('OpenFile Error. fwFile = '+filename+' could not be opened.');
           Application.MessageBox('File error occurred.', 'ERROR',MB_ICONINFORMATION);
           fwFileOpen := false;
           StopFlash:=true;
         end;
       end;
    end
    else begin
      AddErr(MsgWindow, 'No File selected. Leaving flash routine...');
      StopFlash:=true;
      end;

  // Check if selected FW-File is correct for the connected device
  if not StopFlash then begin
    readln(fwFile, SendS);   // first line = @xxxx
    readln(fwFile, SendS);   // second line contains device string.
    TstStr:='';
    TstStr:=StringToHex(FileDevStr);
    for i:=1 to length(TstStr) do if TstStr[i]<> SendS[i] then StopFlash:=true;
    if StopFlash then begin
      AddErrC2(MsgWindow, 'Selected firmware file [',filename ,'] does not match selected device [',FileDevStr,']');

      ShowMessage       ('ERROR: Firmware file does not match selected device !'
          + sLineBreak + '    Check if correct device selected : [' + FileDevStr +']'
          + sLineBreak + '    Check if correct firmware file selected : '
          + sLineBreak + '['+ filename+']');
     end;
  end;

  // Last Chance to quit !!!!!
  if not StopFlash then begin
    Reply := Application.MessageBox('Start Flash ?     Press "No" to quit', 'Start Flash', MB_ICONQUESTION + MB_YESNO);
    if Reply=IDNO then StopFlash:=true;
  end;


  // here flash-process starts........
  if not StopFlash then
  begin
    Form1.Enabled:=false;
    HintLabel.Caption:='File:'+LineEnding+filename+LineEnding+LineEnding+'Programming ......'+LineEnding+'DO NOT INTERRUPT'+LineEnding+'DO NOT DISCONNECT';
    HintLabel.Color:=clYellow;
    HintLabel.Visible:=true;

   // if not RecoveryMode then                        // enter Bootloader
    if P_State <> PS_Dev_Recover then
      begin
      AddInf(MsgWindow, 'Entering Bootloader ...');
      if SendELCommand(ProgCmd) = $99                 // send enter Bootloader Cmd
        then AddInf(MsgWindow, 'Bootloader started')  // ACK on BL Cmd rx'ed.

      else                     // No ACK, but maybe Bootloader prompt coming (M40)
        begin
          AddInf(MsgWindow, 'Waiting for Bootloader to come up ...');
          C:=0;
          B:=ser.RecvByte(600);                       // long wait for BL prompt (M40)
          if B=13 then begin
            repeat
              C:=B;
              B:=ser.RecvByte(10);
            until ser.LastError=ErrTime0ut;
            if C<>$3E then begin
              AddWrn(MsgWindow, 'No BL prompt received');
              StopFlash:=true;
              end
            else AddInf(MsgWindow, 'BL prompt received - Bootloader started.');
          end
          else begin
            StopFlash:=true;
            end;
        end;
      if StopFlash then AddErr(MsgWindow, 'Bootloader not entered - stopping flash routine');
      delay(1000);                                 // wait for Bootloader settled
      end;

     Lines:=MsgWindow.Lines;

     while not StopFlash do begin
       reset(fwFile);
       fwFileOpen := true;
       AddLine(MsgWindow, '');
       AddInfH(MsgWindow, 'ERASING Memory ');
       AddLine(MsgWindow, '');
       i:=0;
       ser.SendString('E'+#13+#10);                     // erase
       repeat                                           // output erase dots .....
         B:=ser.RecvByte(100);
         if B=46 then
           begin
             i:=i+1;
             if Odd(i) then begin
               Lines[Lines.Count-1]:=Lines[Lines.Count-1]+Char(B);
               Application.ProcessMessages;
             end;
           end;
       until ser.LastError=ErrTime0ut;

       UntilDevQuiet(RetS);
       AddInf(MsgWindow, 'Memory erased ');
       AddInf(MsgWindow, 'UPLOADING Program ..... ');
       ser.SendString('U');                            // Upload
       RecS:=ser.RecvString(10);
       UntilDevQuiet(RetS);

  // Keep reading lines until the end of the file is reached
       ProgressBar1.Position:=0;
       ProgressBar1.visible:=true;
       AddInf(MsgWindow, 'FLASHING. (LineDelay : '+(IntToStr(TLineDelay))+' ms)');
       AddInf(MsgWindow, 'Please wait ..... ');
       AddLine(MsgWindow, '');
       TxActive:=true;
       FlashErr:=false;
       i:=0;
       while not (eof(fwFile) or FlashErr) do begin
         readln(fwFile, SendS);
         ser.SendString(SendS+#13+#10);      // send 1 data line
  //
  // try to receive anything from device...
  // BL2 does not ECHO chars. on E_Link - but Device_String will be sent on Re-Boot
         RecS:=ser.RecvString(2);
         if ser.LastError=0 then begin       // Echo received ?
           if SendS[1]<>'q' then begin       // then check it for Comm error
             if SendS<>RecS then begin
               FlashErr:=true;
               if RecS='NX' then begin
                 AddErr (MsgWindow, 'FlashError - Line : '+(IntToStr(i))+' Received  : '+RecS+'  Byte not blank');
                 end
               else begin
                 AddWrn(MsgWindow, 'TXed Line : '+SendS);
                 AddWrn(MsgWindow, 'Received  : '+RecS);
                 Dbg('FlashError - Line : '+(IntToStr(i)));
                 Dbg('Bytes sent        : '+SendS);
                 Dbg('Bytes received    : '+RecS);
                 end;
               end;
             end;
           end;
         if Odd(i) then begin           // only every 2nd time (display flicker)
  // print Dots
           Lines[Lines.Count-1]:=Lines[Lines.Count-1]+Char(46);
  // Progress Bar
           j:= trunc(i/PBFull);
           ProgressBar1.Position:=j+1;  // work-around to correctly show progressbar
           ProgressBar1.Position:=j;
           Application.ProcessMessages;
         end;

         delayNP(TLineDelay);                       // w.o. ProcessMessages
         if SendS[1]='q' then break;                // EndChar ?  -> quit
         i:=i+1;                                    // next line
     end;       // while not EoF

     TxActive:=false;
     Form1.Enabled:=true;

  // test for programming fault
     if FlashErr then begin
       Reply := Application.MessageBox('Try again ?', 'Programming ERROR', MB_ICONQUESTION + MB_YESNO);
       if Reply = IDNO then StopFlash:=true
     else begin
       AddInf(MsgWindow, 'Trying again ....... ');
       AddLine(MsgWindow, '');
       TLineDelay:=30;                  // slower programming next time.
       end;
     end;

  // Check Check-Sum
     if not (FlashErr or StopFlash) then begin
       AddInf(MsgWindow, 'Checking Checksum ....... ');
       sleep(200);
       CkSRes:=0;

       UntilDevQuiet(RetS);
       ser.SendString('C');

       B:=ser.RecvByte(2);  // receive potential loop-back of command
       RetS:=ser.RecvString(200);
       CpS:=RetS;
       RetS:=DelChars(CpS,(' '));
       if RetS<>'' then AddInf(MsgWindow, '  Checksum Mem  : '+RetS)
       else begin
              AddWrn(MsgWindow, '  Checksum Mem  : not available');
              CkSRes:=CkSRes+10;
            end;

       readln(fwFile, CpS);
       if CpS<>'' then begin
         ChkS:=DelChars(CpS,(' '));
         AddInf(MsgWindow, '  Checksum File : '+ChkS);
         if RetS<>'' then if RetS<>ChkS then CkSRes:=CkSRes+100;
         end
       else begin
              AddWrn(MsgWindow, '  Checksum File : not available');
              CkSRes:=CkSRes+10;
            end;

       UntilDevQuiet(RetS);
       ser.SendString('X');

       B:=ser.RecvByte(2);  // receive potential loop-back of command
       RetS:=ser.RecvString(200);
       CpS:=RetS;
       RetS:=DelChars(CpS,(' '));
       if RetS<>'' then AddInf(MsgWindow, 'X_Checksum Mem  : '+RetS)
       else begin
              AddWrn(MsgWindow, 'X_Checksum Mem  : not available');
              CkSRes:=CkSRes+10;
            end;

       readln(fwFile, CpS);
       if CpS<>'' then begin
         ChkS:=DelChars(CpS,(' '));
         AddInf(MsgWindow, 'X_Checksum File : '+ChkS);
         if RetS<>'' then if RetS<>ChkS then CkSRes:=CkSRes+100;
         end
       else begin
              AddWrn(MsgWindow, 'X_Checksum File : not available');
              CkSRes:=CkSRes+10;
            end;

       if CkSRes=0 then begin
         AddInf(MsgWindow, 'FW Update: SUCCESS');
         AddInf(MsgWindow, 'Leaving Programming Mode ...... ');
         StopFlash:=true;                          // ChkSum OK -> End
         AddInf(MsgWindow, 'Resetting & re-starting connected device');
         AddInf(MsgWindow, 'Please wait ...... ');
         SendRsCmd(self, 'G', RetS);               // GO
         if RetS='+' then begin
            AddInf(MsgWindow, 'Device successfully re-started.');
            AddInf(MsgWindow, 'DONE. - Firmware update finished');
            AddInf(MsgWindow, 'You can now safely close this program');
            AddInf(MsgWindow, 'Re-start your T+A device by pressing ON/OFF button');
            end
         else begin
           AddWrn(MsgWindow, 'Device did not respond to re-start command');
           AddInf(MsgWindow, 'You can close this program now');
           AddInf(MsgWindow, 'Re-start your T+A device by disconnecting & after 30 seconds re-connecting the mains');
           end;
         if Application.MessageBox
          ('Update done.', 'Continue', MB_ICONQUESTION + MB_OK)=IDOK then
         Disconnect(self);
       end
       else begin
         CpS:='ERROR  '+IntToStr(CkSRes);
         Reply := Application.MessageBox('Checksum ERROR - Try again ?', PChar(CpS), MB_ICONQUESTION + MB_YESNO);
         if Reply = IDNO then StopFlash:=true
         else begin
           AddInf(MsgWindow, 'Trying again ....... ');
           AddInf(MsgWindow, '');
           end;
       end;
     end;
    CloseFile(fwFile);                      // Done. Close the file
    fwFileOpen:=false;
    end;
  end;
  sleep(100);
  if fwFileOpen then CloseFile(fwFile);
  HintLabel.Visible:=false;
  ProgressBar1.Visible:=false;
  ConnectButton.Enabled:=true;
  UpdateButton.Enabled:=true;
  Form1.Enabled:=true;
end;


procedure TForm1.GetVer (var VStr, DStr: string);

var
    i                                   : integer;
    RxOK, recov                         : boolean;
    RStr                                : ElStr;
    LCmd                                : AnsiString;
    b1                                  : byte;
   // b1,b2                               : byte;
    BL_VStr, BL_DStr                    : AnsiString;


begin
  Timer1.enabled:=false;
  RxOK:=false;
  P_State := PS_DisConnected;                 // assume: no E-Link device connected
  VStr:='';
  DStr:='';
  for i:=0 to length(RStr) do RStr[i]:=0;     // clear ReturnString.
  i:=SendELCommand(GetVerStr);                // send GetVersion command

  case i of

    $99      : begin                          // normal case: ACK received. Wait for Version Telegram
               P_State := PS_Connected;       // we received ACK for our request -> E_Link device is listening
               RecvElStr(RStr, RxOK);         // receive complete version message
               if RxOK then
               begin
                 AddInf(MsgWindow, 'Receiving Version w. ACK');
                 DecodeVer(RStr, VStr, DStr);
                 if DStr='UKN'
                   then AddWrn(MsgWindow, 'Device_String request not supported')
                   else begin
                     AddInf(MsgWindow, 'Detected Device  = '+DStr);
                     AddInf(MsgWindow, 'Detected Version = '+VStr) ;
                     P_State:=PS_Dev_Identified;
                   end;
               end
               else begin
                   case SelectedDevice of
                     'A200'  :  begin
                                  AddInf(MsgWindow, 'Exception A 200: Received ACK but no VersionString');
                                  DStr:='A200';
                                end;

                     'M200'  :  begin
                                  AddInf(MsgWindow, 'Exception M 200: Received ACK but no VersionString');
                                  DStr:='M200';
                                end

                   else begin
                     AddWrn(MsgWindow, '[GetVer]: Received ACK but no VersionString');
                     if Application.MessageBox
                         ('Received ACK but no VersionString - Continue anyway ?', 'Continue', MB_ICONQUESTION + MB_YESNO)=IDYES then begin
                       AddWrn(MsgWindow, '[GetVer]: Continuing without Version on user intervention');
                       DStr:='UKN';
                       VStr:='x.xx';
                     end;
                    end;
                   end;
               end;
              end;


  ElErrBreak : begin // special case: M40 returns no ACK but directly a bus-request !!!!
               RecvElStr(RStr, RxOK);    // receive message
               if RxOK then
               begin
                 P_State := PS_Connected;
                 AddInf(MsgWindow, 'Legacy mode: Version string request w.o. (N)ACK');
                 DecodeVer(RStr, VStr, DStr);
                 if DStr='UKN'
                   then AddWrn(MsgWindow, 'Device_String request not supported')
                   else begin
                     AddInf(MsgWindow, 'Detected T+A Device = '+DStr);
                     P_State := PS_Dev_Identified;
                     end;
                 AddInf(MsgWindow, 'Detected FW Version = '+VStr);
               end
               else
                 begin
                   StatusLabel.Caption:='ERROR: Device not responding';
                   StatusLabel.Color := clRed;
                   AddErr(MsgWindow, 'Device not responding.');
                   ShowMessage     ('####   ERROR: device not responding.'
                     + sLineBreak + '####   --------------------------------------------'
                     + sLineBreak + '####      Check if Device is switched ON'
                     + sLineBreak + '####      Check Device selection'
                     + sLineBreak + '####      Check cables'
                     + sLineBreak + '####      If using T+A programming adapter: Check Master/Slave switch');
                   DevSelectBox.Enabled:=true;
                 end;
             end;

  ElErrNoBg : begin        // for Master (DAC8)
                AddWrn(MsgWindow, 'E-Link ERROR: No BusGrant');
                AddInf(MsgWindow, 'Looking for T+A device in Recovery Mode...');
                repeat b1:=ser.RecvByte(2);
                  until ser.LastError=ErrTimeOut;
                LCmd:=#13+#10;
                for i:=1 to Length(LCmd) do ser.SendByte(ord(LCmd[i]));
                ElRXBuffPtr:=@ElRXBuff;
                ser.RecvBufferEx(ElRXBuffPtr, 2, 20);     // try to rx CR/LF or #>
                recov:=true;
               // b1:=ElRXBuff[0];
               // b2:=ElRXBuff[1];
                if ElRXBuff[0]<>$0D then if ElRXBuff[0]<>$23 then recov:=false;
                if ElRXBuff[1]<>$0A then if ElRXBuff[1]<>$3E then recov:=false;
                if recov then begin

                  CheckRecoveryMode;
                  if P_State = PS_Dev_Recover then begin
                    AddInf(MsgWindow, 'T+A Master Device in Recovery Mode detected');
    //########  Device Check in Recovery Mode (Master)
                    Delay(100);
                    BL_VStr:='';
                    BL_DStr:='';
                    GetBLVer(BL_VStr, BL_DStr);
                    AddInf(MsgWindow, 'BL-Device : '+BL_DStr);
                    AddInf(MsgWindow, 'BL-Version: '+BL_VStr);
    //########
                    VStr:=BL_VStr;
                    DStr:=BL_DStr;
                  end;
                end
                else begin
                    AddInf(MsgWindow, 'No device in Recovery Mode found.');
                    VStr:='NoCon';
                    DStr:='UKN';
                end;
              end;

  ElErrCRLF : begin             // Slave (M40) in Bootloader
                AddInf(MsgWindow, 'T+A Slave Device in Recovery Mode detected');
                P_State := PS_Dev_Recover;
    //########  Device Check in Recovery Mode (Slave)
                Delay(100);
                GetBLVer(BL_VStr, BL_DStr);
                AddInf(MsgWindow, 'BL-Device : '+BL_DStr);
                AddInf(MsgWindow, 'BL-Version: '+BL_VStr);
    //########
                VStr:=BL_VStr;
                DStr:=BL_DStr;
              end;

// ELink ERROR cases
    $69           : AddErr(MsgWindow, 'E-Link ERROR: 0x69');
    $95           : AddErr(MsgWindow, 'E-Link ERROR: 0x95');
    $96           : AddErr(MsgWindow, 'E-Link ERROR: 0x96');
    ElErrTimeOut  : AddErr(MsgWindow, 'E-Link ERROR: T+A device not responding');
    ElErrMSNotDef : AddErr(MsgWindow, 'System ERROR: Master & Slave not defined !!');
    else     AddErr(MsgWindow, 'E-Link ERROR: unrecognized return value $'+IntToHex(i, 4));
  end;        // case i of
  Timer1.enabled:=true;
end;



////######################
//procedure TForm1.GetFTDILatency(var FT_DCnt:integer; var Latency:byte);
//var S                 : String;
//    I                 : Integer;
//    DeviceIndex       : DWord;
//    LV                : TListItem;
//    DevicePresent     : Boolean;
//    FTDIStr           : string;
//
//    ftStatus          : Boolean; //FT_STATUS;
//    numDevs           : DWORD;
//    DevLoc            : DWord;
//begin
//Latency:=0;
//
////Memo1.Clear;
//FT_Enable_Error_Report := true; // Error reporting = on
////SaveDialog1.InitialDir := ExtractFilePath(Application.ExeName);
////OpenDialog1.InitialDir := ExtractFilePath(Application.ExeName);
//DevicePresent := False;
////Memo1.Enabled := False;
////FTSendFile.Enabled := False;
////FTReceiveFile.Enabled := False;
////FTPort_Configure.Enabled := False;
////Timer1.Enabled := True;
////FTSendFile.enabled := false;
////FTReceiveFile.Enabled := false;
////FTResend.Enabled := false;
////SndRxvCmp.Enabled := false;
////ListView1.Items.clear;
//GetFTDeviceCount;
//FT_DCnt:= FT_Device_Count;
//
//If FT_Device_Count > 0 then
//  begin
//    S := IntToStr(FT_Device_Count);
//    FTDIStr := 'FT_Device_Count - '+S+' Device(s) Present ...';
//    DeviceIndex := 0;
//    for I := 1 to FT_Device_Count do
//    begin
////      LV := ListView1.Items.Add;
////      LV.Caption := 'Device '+IntToStr(I);
//      GetFTDeviceSerialNo( DeviceIndex );
////      LV.SubItems.Add(FT_Device_String);
//      GetFTDeviceDescription ( DeviceIndex );
////      LV.SubItems.Add(FT_Device_String);
//
//        GetFTDeviceLocation( DevLoc );
//      Open_USB_Device_By_DevIndex( DeviceIndex );
//      Get_USB_Device_LatencyTimer;
////      Set_USB_Device_LatencyTimer(1);
////      Get_USB_Device_LatencyTimer;
//
//        Get_USB_Device_List_Detail( DeviceIndex );
//
//
//      if FT_LatencyRd > Latency then Latency :=FT_LatencyRd;
//      Close_USB_Device;
//      DeviceIndex := DeviceIndex + 1;
//    end;
//  end;
//end;

//######################



end.

