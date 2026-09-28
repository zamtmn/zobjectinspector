{
*****************************************************************************
*                                                                           *
*  This file is part of the ZCAD                                            *
*                                                                           *
*  See the file COPYING.txt, included in this distribution,                 *
*  for details about the copyright.                                         *
*                                                                           *
*  This program is distributed in the hope that it will be useful,          *
*  but WITHOUT ANY WARRANTY; without even the implied warranty of           *
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                     *
*                                                                           *
*****************************************************************************
}
{
@author(Andrey Zubarev <zamtmn@yandex.ru>) 
}

unit uzObjectInspector;

{$MODE DELPHI}
{$ModeSwitch advancedrecords}

interface

uses
  Classes,SysUtils,
  {$IFDEF LCLGTK2}gtk2,{$ENDIF}
  {$IFDEF LCLWIN32}win32proc,{$endif}
  Types,Graphics,Themes,LCLIntf,LCLType,
  ExtCtrls,Controls,Menus,Forms,
  StdCtrls,ColorBox,
  uzbUnits,uzbUnitsUtils,
  uzsbVarmanDef,
  uzsbTypeDescriptors,
  gzctnrVectorTypes,uzctnrvectorstrings,
  uzObjectInspectorManager;

const
  spliterhalfwidth=4;
  subtab=1;

type
  TCBReadOnlyMode=(CBReadOnly,CBEditable,CBDoNotTouch);
  PContent=Pointer;
  PContext=Pointer;

  TEditorContext=record
    ppropcurrentedit:PPropertyDeskriptor;
  end;

  TDisplayedData=record
    PObj:PContent;
    PType:PUserTypeDescriptor;
    Ctx:PContext;
    UnitsFormat:TzeUnitsFormat;
    constructor CreateRec(const APOdj:PContent;const APType:PUserTypeDescriptor;const ACtx:PContext;const AUnitsFormat:TzeUnitsFormat);
    procedure Clear;
  end;

  TOnGetOtherValues=procedure(var vsa:TZctnrVectorStrings;const valkey:string;const DisplayedData:TDisplayedData);
  TOnUpdateObjectInInsp=procedure(const EDContext:TEditorContext;const currobjgdbtype:PUserTypeDescriptor;
    const pcurcontext:pointer;const pcurrobj:pointer;const OnFieldModifyProc:TOnFieldModifyProc);
  TOnNotify=procedure(const pcurcontext:pointer);

  TObjInspCustom=TScrollBox;

  TNameColumnWidthCorrector=record
    LastClientWidth,LastNameColumnWidth:integer;
  end;

  TGDBobjinsp=class(TObjInspCustom)
  protected
    PDA:TPropertyDeskriptorArray;
    contentheigth:integer;
    OLDPP:PPropertyDeskriptor;
    OnMousePP:PPropertyDeskriptor;
    MResplit:boolean;

    function getRowHeight:integer;
  public
    DefaultData:TDisplayedData;
    CurrData:TDisplayedData;
    StoredData:TDisplayedData;
    NameColumnWidthCorrector:TNameColumnWidthCorrector;
    NameColumnWidth:integer;
    PEditor:TPropEditor;
    EDContext:TEditorContext;
    onGetOtherValues:TOnGetOtherValues;
    onUpdateObjectInInsp:TOnUpdateObjectInInsp;
    onNotify:TOnNotify;
    onAfterFreeEditor:TNotifyEvent;
    currpd:PPropertyDeskriptor;

    property OnContextPopup;

    procedure draw;virtual;
    procedure mypaint(Sender:TObject);
    procedure drawprop(DefaultDetails:TThemedElementDetails;PPA:PTPropertyDeskriptorArray;arect:trect);
    procedure InternalDrawprop(DefaultDetails:TThemedElementDetails;PPA:PTPropertyDeskriptorArray;
      var y,sub:integer;miny:integer;arect:trect;var LastPropAddFreespace:boolean);
    procedure calctreeh(PPA:PTPropertyDeskriptorArray;var y:integer);
    function gettreeh:integer;virtual;
    procedure _onresize(Sender:TObject);virtual;
    procedure updateeditorBounds;virtual;
    procedure buildproplist(const f:TzeUnitsFormat;exttype:PUserTypeDescriptor;bmode:integer;var addr:pointer);
    procedure SetCurrentObjDefault;
    procedure ReturnToDefault;
    procedure rebuild;
    procedure Notify(Sender:TObject;Command:TMyNotifyCommand);virtual;
    procedure createpda;
    destructor Destroy;override;
    procedure createscrollbars;virtual;
    procedure ScrollBy(DeltaX,DeltaY:integer);override;
    procedure AfterConstruction;override;

    procedure FreeEditor;
    procedure StoreAndFreeEditor;
    procedure ClearEDContext;
    procedure AsyncFreeEditorAndSelectNext(Data:PtrInt);
    procedure AsyncFreeEditor(Data:PtrInt);
    function IsMouseOnSpliter(pp:PPropertyDeskriptor;X,Y:integer):boolean;

    procedure createeditor(pp:PPropertyDeskriptor);
    constructor Create(AOwner:TComponent);override;

    function IsHeadersEnabled:boolean;
    function HeadersHeight:integer;

    {LCL}
    procedure MouseMove(Shift:TShiftState;X,Y:integer);override;
    procedure MouseLeave;override;

    procedure MouseDown(Button:TMouseButton;Shift:TShiftState;X,Y:integer);override;
    procedure MouseUp(Button:TMouseButton;Shift:TShiftState;X,Y:integer);override;
    procedure UpdateObjectInInsp;
    procedure setptr(AData:TDisplayedData);
    procedure updateinsp;
    procedure myKeyDown(Sender:TObject;var Key:word;Shift:TShiftState);
  end;

procedure Register;
procedure SetComboSize(cb:TComboBox;ItemH:integer;ReadOnlyMode:TCBReadOnlyMode);

implementation

procedure SetComboSize(cb:TComboBox;ItemH:integer;ReadOnlyMode:TCBReadOnlyMode);
begin
  cb.AutoSize:=False;
  {$IFDEF LCLWIN32}
     case ReadOnlyMode of
       CBReadOnly:cb.Style:=csOwnerDrawFixed;
       CBEditable:cb.Style:=csOwnerDrawEditableFixed;
       CBDoNotTouch:;
     end;
     cb.ItemHeight:=ItemH;
  {$ENDIF}
end;

constructor TDisplayedData.CreateRec(const APOdj:PContent;const APType:PUserTypeDescriptor;
  const ACtx:PContext;const AUnitsFormat:TzeUnitsFormat);
begin
  PObj:=APOdj;
  PType:=APType;
  Ctx:=ACtx;
  UnitsFormat:=AUnitsFormat;
end;

procedure TDisplayedData.Clear;
begin
  CreateRec(nil,nil,nil,CreateDefaultUnitsFormat);
end;

function TGDBobjinsp.getRowHeight:integer;
begin
  Result:=OIManager.RowHeightOverride.ValueOrDefault(OIManager.DefaultRowHeight);
end;

procedure TGDBobjinsp.myKeyDown(Sender:TObject;var Key:word;Shift:TShiftState);
begin
  if Peditor<>nil then begin
    if key=VK_ESCAPE then begin
      freeeditor;
      key:=0;
      exit;
    end;
  end;
  if StoredData.PObj<>nil then
    if key=VK_ESCAPE then begin
      setptr(StoredData);
      StoredData.Clear();
      key:=0;
      exit;
    end;
end;

function PlusMinusDetail(Collapsed,hot:boolean):TThemedTreeview;
const
  PlusMinusDetailArray:array[{isCollapsed}boolean,{isHot}boolean] of TThemedTreeview=
    ((ttGlyphClosed,ttHotGlyphClosed),(ttGlyphOpened,ttHotGlyphOpened));
begin
  {$IFDEF LCLWIN32}
  if WindowsVersion<wvVista then
    hot:=false;
  {$endif}
  Result:=PlusMinusDetailArray[Collapsed,hot];
end;

function IsWgiteBackground:boolean;
begin
  Result:=OIManager.INTFObjInspWhiteBackground;
end;

function TGDBobjinsp.IsHeadersEnabled:boolean;
begin
  Result:=OIManager.INTFObjInspShowHeaders;
end;

function TGDBobjinsp.HeadersHeight:integer;
begin
  if IsHeadersEnabled then
    Result:=OIManager.RowHeightOverride.ValueOrDefault(OIManager.DefaultRowHeight)
  else
    Result:=0;
end;

function NeedShowSeparator:boolean;
begin
  if OIManager.INTFObjInspOldStyleDraw then
    Result:=False
  else
    Result:=OIManager.INTFObjInspShowSeparator;
end;

function isOldStyleDraw:boolean;
begin
  Result:=OIManager.INTFObjInspOldStyleDraw;
end;

function NeedDrawFasteditor(OnMouseProp:boolean):boolean;
begin
  if OIManager.INTFObjInspShowFastEditors then begin
    if OIManager.INTFObjInspShowOnlyHotFastEditors then
      Result:=OnMouseProp
    else
      Result:=True;
  end else
    Result:=False;
end;

procedure TGDBobjinsp.AfterConstruction;
begin
  inherited;

  onresize:=_onresize;
  onpaint:=mypaint;
  self.DoubleBuffered:=True;
  self.BorderStyle:=bsnone;
  self.BorderWidth:=0;

  CurrData.CreateRec(nil,nil,nil,CreateDefaultUnitsFormat);
  peditor:=nil;
  createpda;
  EDContext.ppropcurrentedit:=nil;

  MResplit:=False;
  NameColumnWidth:=clientwidth div 2;
  NameColumnWidthCorrector.LastNameColumnWidth:=NameColumnWidth;
  NameColumnWidthCorrector.LastClientWidth:=clientwidth;
end;

procedure TGDBobjinsp.SetCurrentObjDefault;
begin
  DefaultData:=CurrData;
end;

procedure TGDBobjinsp.ReturnToDefault;
begin
  if assigned(peditor) then begin
    self.StoreAndFreeEditor;
  end;
  setptr(DefaultData);
end;

procedure TGDBobjinsp.createpda;
begin
  pda.init(100);
end;

destructor TGDBobjinsp.Destroy;
begin
  if peditor<>nil then begin
    peditor.Free;
  end;
  inherited;
  pda.cleareraseobj;
  pda.done;
end;

procedure TGDBobjinsp.buildproplist;
begin
  if exttype<>nil then
    PTUserTypeDescriptor(exttype)^.CreateProperties(f,PDM_Field,@PDA,'root',field_no_attrib,[],bmode,addr,'','');
end;

procedure TGDBobjinsp.calctreeh;
var
  ppd:PPropertyDeskriptor;
  ir:itrec;
  last:boolean;
  rowh:integer;
begin
  rowh:=getRowHeight;
  if ppa^.Count=0 then
    exit;
  ppd:=ppa^.beginiterate(ir);
  if ppd<>nil then
    repeat
      last:=False;
      if ppd^.IsVisible(OIManager.INTFObjInspShowEmptySections) then begin
        y:=y+rowh;
        if ppd^.SubNode<>nil then begin
          if not ppd^.Collapsed^ then begin
            calctreeh(pointer(ppd.SubNode),y);
            y:=y+OIManager.INTFObjInspSpaceHeight;
            last:=True;
          end;
        end;
      end;
      ppd:=ppa^.iterate(ir);
    until ppd=nil;
  if last then
    y:=y-OIManager.INTFObjInspSpaceHeight;
end;

procedure drawfasteditor(ppd:PPropertyDeskriptor;canvas:tcanvas;var FastEditorRT:TFastEditorRunTimeData;var r:trect);
const
  fastEditorOffset={$IFDEF LCLQT}2{$ELSE}2{$ENDIF};
var
  fer:trect;
  FESize:TSize;
  temp:integer;
begin
  if assigned(FastEditorRT.Procs.OnGetPrefferedFastEditorSize) then begin
    FESize:=FastEditorRT.Procs.OnGetPrefferedFastEditorSize(ppd^.valueAddres,r);
    temp:=r.Bottom-r.Top-2;
    if temp<2 then
      temp:=2;
    if FESize.cy>temp then begin
      FESize.cy:=temp;
    end;
    if FESize.cX>0 then
      if (r.Right-r.Left-1)>FESize.cX then begin
        fer:=r;
        fer.Left:=fer.Right-FESize.cX-fastEditorOffset;
        fer.Right:=fer.Right-fastEditorOffset;
        if FESize.cy>0 then begin
          fer.Top:=fer.Top-3;
          temp:=(fer.Bottom+fer.Top)div 2;
          fer.Top:=temp-FESize.cy div 2;
          fer.Bottom:=fer.Top+FESize.cy;
        end else begin
          fer.Top:=fer.Top-3;
        end;
        FastEditorRT.Procs.OnDrawFastEditor(canvas,fer,ppd^.valueAddres,FastEditorRT.FastEditorState,r);
        FastEditorRT.FastEditorRect:=fer;
        r.Right:=fer.Left;
        FastEditorRT.FastEditorDrawed:=True;
      end;
  end;
end;

procedure drawfasteditors(ppd:PPropertyDeskriptor;canvas:tcanvas;var r:trect);
var
  i:integer;
begin
  if assigned(ppd.FastEditors) then
    for i:=0 to ppd.FastEditors.Size-1 do
      drawfasteditor(ppd,canvas,ppd.FastEditors.Mutable[i]^,r);
end;

function GetSizeTreeIcon(Minus,hot:boolean):TSize;
var
  Details:TThemedElementDetails;
begin
  Details:=ThemeServices.GetElementDetails(PlusMinusDetail(Minus,hot));
  Result:=ThemeServices.GetDetailSizeForPPI(Details,Screen.PixelsPerInch);
end;

procedure drawheader(Canvas:tcanvas;ppd:PPropertyDeskriptor;r:trect;Name:string;onm:boolean;
  TextDetails:TThemedElementDetails);

  procedure DrawTreeIcon(X,Y:integer;Minus,hot:boolean);
  var
    Details:TThemedElementDetails;
    Size:TSize;
  begin
    Details:=ThemeServices.GetElementDetails(PlusMinusDetail(Minus,hot));
    Size:=ThemeServices.GetDetailSizeForPPI(Details,Screen.PixelsPerInch);
    ThemeServices.DrawElement(Canvas.Handle,Details,Rect(X,Y,X+Size.cx,Y+Size.cy), {nil}@r);
  end;

var
  Size:TSize;
  temp:integer;
begin
  if not ppd^.Collapsed^ then
    ppd^.Collapsed^:=ppd^.Collapsed^;
  size:=GetSizeTreeIcon(not ppd^.Collapsed^,onm);
  temp:=(r.bottom-r.top-size.cy)div 3;
  if (r.Right-r.Left)>size.cx then
    DrawTreeIcon({Canvas,}r.left,r.top+temp,not ppd^.Collapsed^,onm);
  Inc(r.left,size.cx+1);
  clearRTd(ppd.FastEditors);
  if NeedDrawFasteditor(onm) then
    if assigned(ppd.FastEditors) then
      drawfasteditors(ppd,canvas,r);
  if (r.Right-r.Left)>1 then
    ThemeServices.DrawText(Canvas,TextDetails,Name,r,DT_END_ELLIPSIS or DT_NOPREFIX,0);
end;

function DrawRect(DefaultDetails:TThemedElementDetails;ACanvas:TCanvas;ARect:TRect;AActive:boolean;AOnMouse:boolean;
  AReadOnly:boolean;AWithChildren:boolean):TThemedElementDetails;
var
  tc:tcolor;
begin
  Result:=defaultdetails;
  if (not ThemeServices.ThemesAvailable)or isOldStyleDraw then begin
    if AOnMouse and ThemeServices.ThemesAvailable then
      Result:=ThemeServices.GetElementDetails(ttItemHot);
    if AActive and ThemeServices.ThemesAvailable then
      Result:=ThemeServices.GetElementDetails(ttItemSelected);

    tc:=ACanvas.Brush.Color;
    if OIManager.INTFObjInspBorderColor<>clDefault then
      ACanvas.Pen.Color:=OIManager.INTFObjInspBorderColor;
    if AActive then begin
      ACanvas.Brush.Color:=clHighlight{clBtnHiLight};
      ACanvas.Pen.Style:=psDot;
      inflaterect(ARect,0,-1);
      ACanvas.Rectangle(ARect);
      ACanvas.Pen.Style:=psSolid;
    end else begin
      if IsWgiteBackground then
        ACanvas.Brush.Color:=clWindow
      else
        ACanvas.Brush.Color:=clBtnFace;

      if AWithChildren then
        if OIManager.INTFObjInspLevel0HeaderColor<>clDefault then
          ACanvas.Brush.Color:=OIManager.INTFObjInspLevel0HeaderColor;

      if isOldStyleDraw then
        ACanvas.Rectangle(ARect);
    end;
    ACanvas.Brush.Color:=tc;
  end else begin
    if AActive then begin
      Result:=ThemeServices.GetElementDetails(ttItemSelected);
      ThemeServices.DrawElement(ACanvas.Handle,Result,ARect,nil);
    end else if AReadOnly then begin
      if isOldStyleDraw then begin
        Result:= {ThemeServices.GetElementDetails(ttItemNormal)}DefaultDetails;
        ThemeServices.DrawElement(ACanvas.Handle,Result,ARect,nil);
      end;
      Result:=ThemeServices.GetElementDetails(ttItemDisabled);
    end else if AOnMouse then begin
      Result:=ThemeServices.GetElementDetails(ttItemHot);
     {$IFDEF LCLWIN32}
      if ((WindowsVersion >= wvVista)and ThemeServices.ThemesEnabled) then
        ThemeServices.DrawElement(ACanvas.Handle, result, ARect, nil)
      else
        if isOldStyleDraw then
          ThemeServices.DrawElement(ACanvas.Handle, ThemeServices.GetElementDetails(ttItemNormal), ARect, nil)
     {$ENDIF}
     {$IFNDEF LCLWIN32}
      ThemeServices.DrawElement(ACanvas.Handle,Result,ARect,nil);
     {$ENDIF}
    end else begin
      if isOldStyleDraw then begin
        Result:=DefaultDetails;
        ThemeServices.DrawElement(ACanvas.Handle,Result,ARect,nil);
      end;
    end;
   {$IFDEF LCLWIN32}
     if (WindowsVersion < wvVista)or(not ThemeServices.ThemesEnabled) then
   {$ENDIF}
    if isOldStyleDraw then begin
      ACanvas.Line(ARect.Left,ARect.Top,ARect.Right,ARect.Top);
      ACanvas.Line(ARect.Right,ARect.Top,ARect.Right,ARect.Bottom);
      ACanvas.Line(ARect.Right,ARect.Bottom,ARect.Left,ARect.Bottom);
      ACanvas.Line(ARect.Left,ARect.Bottom,ARect.Left,ARect.Top);
    end;
  end;
end;

procedure drawstring(cnvs:tcanvas;r:trect;s:string;TextDetails:TThemedElementDetails);
begin
  if (r.Right-r.Left)>1 then
    ThemeServices.DrawText(cnvs,TextDetails,s,r,DT_END_ELLIPSIS or DT_SINGLELINE or DT_NOPREFIX,0);
end;

procedure drawvalue(DefaultDetails:TThemedElementDetails;ppd:PPropertyDeskriptor;canvas:tcanvas;
  fulldraw:boolean;TextDetails:TThemedElementDetails;onm:boolean;AWithChildren:boolean);
var
  r:trect;
  tempcolor:TColor;
  Value:string;
begin
  if fldaHidden in ppd^.Attr then
    canvas.Font.Italic:=True;

  if fldaApproximately in ppd^.Attr then
    Value:='≈'+ppd^.Value
  else
    Value:=ppd^.Value;

  r:=ppd.rect;
  if fulldraw then
    DrawRect(DefaultDetails,canvas,r,False,False,False,AWithChildren);
  r.Top:=r.Top+3;
  r.Left:=r.Left+3;
  r.Right:=r.Right-1;
  if fldaReadOnly in ppd^.Attr then begin
    tempcolor:=canvas.Font.Color;
    if fldaColored1 in ppd^.Attr then begin
      canvas.Font.StrikeThrough:=True;
    end;
    if fulldraw then
      if (assigned(ppd.Decorators.OnDrawProperty) and(ppd^.valueAddres<>nil)and(not(fldaDifferent in ppd^.Attr))) then
        ppd.Decorators.OnDrawProperty(canvas,r,ppd^.valueAddres)
      else
        drawstring(canvas,r,Value,DefaultDetails);
    canvas.Font.Color:=tempcolor;
  end else begin
    clearRTd(ppd.FastEditors);
    if NeedDrawFasteditor(onm) then
      drawfasteditors(ppd,canvas,r);
    if fldaColored1 in ppd^.Attr then begin
      canvas.Font.StrikeThrough:=True;
    end;
    if fulldraw then
      if (assigned(ppd.Decorators.OnDrawProperty) and(ppd^.valueAddres<>nil)and(not(fldaDifferent in ppd^.Attr))) then
        ppd.Decorators.OnDrawProperty(canvas,r,ppd^.valueAddres)
      else
        drawstring(canvas,r,Value,DefaultDetails);
  end;

  if fldaHidden in ppd^.Attr then begin
    canvas.Font.Italic:=False;
  end;
  if fldaColored1 in ppd^.Attr then begin
    canvas.Font.StrikeThrough:=False;
  end;

end;

procedure TGDBobjinsp.drawprop(DefaultDetails:TThemedElementDetails;PPA:PTPropertyDeskriptorArray;arect:trect);
var
  lpafs:boolean;
  y,sub:integer;
  miny:integer;
begin
  lpafs:=False;
  y:=HeadersHeight+BorderWidth;
  sub:=0;
  miny:=arect.Top+HeadersHeight+1;
  InternalDrawprop(DefaultDetails,PPA,y,sub,miny,arect,lpafs);
end;

procedure TGDBobjinsp.InternalDrawprop(DefaultDetails:TThemedElementDetails;PPA:PTPropertyDeskriptorArray;
  var y,sub:integer;miny:integer;arect:TRect;var LastPropAddFreespace:boolean);
var
  s:string;
  ppd:PPropertyDeskriptor;
  r:trect;
  tempcolor:TColor;
  ir:itrec;
  Visible:boolean;
  OnMouseProp:boolean;
  TextDetails:TThemedElementDetails;
  TextStyle:TTextStyle;
  rowh:integer;
begin
  rowh:=OIManager.RowHeightOverride.ValueOrDefault(OIManager.DefaultRowHeight);
  ppd:=ppa^.beginiterate(ir);
  if ppd<>nil then
    repeat
      LastPropAddFreespace:=False;
      if ppd^.IsVisible(OIManager.INTFObjInspShowEmptySections) then begin
        OnMouseProp:=(ppd=onmousepp);
        if assigned(ppd^.Collapsed) then
          r.Left:=arect.Left+{2+}(subtab+GetSizeTreeIcon(not ppd^.Collapsed^,False).cx)*sub
        else
          r.Left:=arect.Left+{2+}(subtab+GetSizeTreeIcon(True,False).cx)*sub;
        r.Top:=y;
        if NeedShowSeparator then
          r.Right:=NameColumnWidth-spliterhalfwidth
        else
          r.Right:=NameColumnWidth;
        r.Bottom:=y+rowh+1;
        if miny<=r.Bottom then
          Visible:=True
        else
          Visible:=False;
        begin
          if ppd^.SubNode<>nil then begin
            if (ppd^.SubNode^.Count>0)or OIManager.INTFObjInspShowEmptySections then begin
              if Visible then begin
                s:=ppd^.Name;
                if not NeedShowSeparator then
                  r.Right:=arect.Right-1;
                TextDetails:=DrawRect(DefaultDetails,canvas,r,False,OnMouseProp,(fldaReadOnly in ppd^.Attr),{true}sub=0);
                r.Left:=arect.Left+{2+}(subtab+GetSizeTreeIcon(not ppd^.Collapsed^,False).cx)*sub;
                r.Top:=r.Top+3;
                if fldaReadOnly in ppd^.Attr then begin
                  tempcolor:=canvas.Font.Color;
                  canvas.Font.Color:=clGrayText;

                  drawheader(canvas,ppd,r,s,OnMouseProp,TextDetails);

                  canvas.Font.Color:=tempcolor;
                end else begin
                  drawheader(canvas,ppd,r,s,OnMouseProp,TextDetails);
                end;
                ppd.rect:=r;
              end;
              Inc(sub);
              y:=y+rowh;
              if not ppd^.Collapsed^ then
                InternalDrawprop(DefaultDetails,pointer(ppd.SubNode),y,sub,miny,arect,LastPropAddFreespace);
              Dec(sub);
            end;
          end else begin
            if Visible then begin
              TextDetails:=DrawRect(DefaultDetails,canvas,r,(ppd=EDContext.ppropcurrentedit),
                OnMouseProp,fldaReadOnly in ppd^.Attr,{false}sub=0);

              if fldaHidden in ppd^.Attr then begin
                canvas.Font.Italic:=True;
              end;
              r.Left:=r.Left+2;
              r.Top:=r.Top+3;
              if [fldaReadOnly,fldaHidden]*ppd^.Attr<>[] then begin
                tempcolor:=canvas.Font.Color;
                TextStyle:=canvas.TextStyle;
                TextStyle.EndEllipsis:=True;
                TextStyle.WordBreak:=False;
                canvas.Font.Color:=clGrayText;
                if (r.Right-r.Left)>1 then
                  canvas.TextRect(r,r.Left,r.Top,ppd^.Name,TextStyle);
                canvas.Font.Color:=tempcolor;
              end else begin
                if (r.Right-r.Left)>1 then
                  ThemeServices.DrawText(Canvas,TextDetails,ppd^.Name,r,DT_END_ELLIPSIS or DT_NOPREFIX,0);
              end;
              r.Top:=r.Top-3;
              if NeedShowSeparator then
                r.Left:=r.Right-1+spliterhalfwidth
              else
                r.Left:=r.Right-1;
              r.Right:=arect.Right-1;

              ppd.rect:=r;
              drawvalue(DefaultDetails,ppd,canvas,True,TextDetails,onmouseprop,sub=0);
            end;
            y:=y++rowh;
          end;
        end;
      end;
      ppd:=ppa^.iterate(ir);
      if self.VertScrollBar.Position+self.ClientHeight<=(y) then
        system.break;
    until ppd=nil;
  if not LastPropAddFreespace then begin
    y:=y+OIManager.INTFObjInspSpaceHeight;
    LastPropAddFreespace:=True;
  end;
end;

function TGDBobjinsp.gettreeh;
begin
  Result:=0;
  calctreeh(@pda,Result);
end;

procedure TGDBobjinsp.mypaint;
begin
  draw;
end;

procedure TGDBobjinsp.draw;
var
  arect,hrect:trect;
  tc:tcolor;
  vDefaultDetails:TThemedElementDetails;
begin
  ARect:=GetClientRect;
  InflateRect(ARect,-BorderWidth,-BorderWidth);
  ARect.Top:=ARect.Top+VertScrollBar.ScrollPos;
  ARect.Bottom:=ARect.Bottom+VertScrollBar.ScrollPos;
 {$IFDEF LCLWIN32}
  if WindowsVersion < wvVista then
    vDefaultDetails := ThemeServices.GetElementDetails(tbPushButtonNormal)
  else
    vDefaultDetails := ThemeServices.GetElementDetails(tmPopupCheckBackgroundDisabled){trChevronVertHot}{ttbThumbDisabled}{tlListViewRoot};
 {$endif}
 {$IFDEF LCLGTK2}
  vDefaultDetails := ThemeServices.GetElementDetails(ttbody)
 {$endif}
 {$IFDEF LCLQT}
  bvDefaultDetails := ThemeServices.GetElementDetails({ttpane}thHeaderDontCare)
 {$endif};
 {$IFDEF LCLQT5}
  vDefaultDetails := ThemeServices.GetElementDetails(ttPane)
 {$endif};
  if IsWgiteBackground then
    Canvas.FillRect(ARect)
  else begin
    if isOldStyleDraw then begin
      tc:=Canvas.Brush.Color;
      Canvas.Brush.Color:=clBtnFace;
      Canvas.FillRect(ARect);
      Canvas.Brush.Color:=tc;
    end else
      ThemeServices.DrawElement(Canvas.Handle,vDefaultDetails,ARect,nil);
  end;

  hrect:=ARect;
 {$IFDEF LCLWIN32}
  if WindowsVersion>=wvVista then
 {$endif}
  InflateRect(hrect,-1,-1);


  drawprop(vDefaultDetails,@pda,{arect}hrect);

  hrect.Bottom:=hrect.Top+HeadersHeight-1{+1};
 {$IFDEF WINDOWS}
  hrect.Top:=hrect.Top;
 {$ENDIF}
 {$IFNDEF WINDOWS}
  hrect.Top:=hrect.Top+2;
 {$ENDIF}

  if IsHeadersEnabled then begin
    hrect.Left:=hrect.Left+2;
    hrect.Right:=NameColumnWidth{$IFDEF WINDOWS}+1{$ENDIF};
    vDefaultDetails:=ThemeServices.GetElementDetails(thHeaderItemNormal);
    ThemeServices.DrawElement(Canvas.Handle,vDefaultDetails,hrect,nil);
    ThemeServices.DrawText(Canvas,vDefaultDetails,OIManager.PropertyRowName,hrect,DT_END_ELLIPSIS or DT_CENTER or DT_VCENTER or DT_NOPREFIX,0);

    vDefaultDetails:=ThemeServices.GetElementDetails(thHeaderItemRightNormal);
    hrect.Left:=hrect.right;
   {$IFDEF WINDOWS}
    hrect.right:=ARect.Right-1;
   {$ENDIF}
   {$IFNDEF WINDOWS}
    hrect.right:=ARect.Right-2;
   {$ENDIF}
    ThemeServices.DrawElement(Canvas.Handle,vDefaultDetails,hrect,nil);
    ThemeServices.DrawText(Canvas,vDefaultDetails,OIManager.ValueRowName,hrect,DT_END_ELLIPSIS or DT_CENTER or DT_VCENTER or DT_NOPREFIX,0);
  end;

  if NeedShowSeparator then begin
    hrect.Left:=NameColumnWidth-2;
    hrect.right:=NameColumnWidth+{$IFNDEF WINDOWS}2{$ENDIF}{$IFDEF WINDOWS}1{$ENDIF};
    hrect.Top:=hrect.Bottom;
    hrect.Bottom:=contentheigth+HeadersHeight;
    if hrect.Bottom>ARect.Bottom then
      hrect.Bottom:=ARect.Bottom{height};
    if ThemeServices.ThemesEnabled then begin
     {$IFNDEF LCLWIN32}
      vDefaultDetails:=ThemeServices.GetElementDetails(ttbSeparatorNormal);
     {$ENDIF}
     {$IFDEF LCLWIN32}
      if WindowsVersion < wvVista then
        vDefaultDetails := ThemeServices.GetElementDetails(ttbSeparatorNormal)
      else
        vDefaultDetails := ThemeServices.GetElementDetails(tsPane);
     {$ENDIF}
      ThemeServices.DrawElement(Canvas.Handle,vDefaultDetails,hrect,nil);
    end else begin
      hrect.Left:=(hrect.Left+hrect.Right)div 2;
      tc:=Canvas.Pen.Color;
      Canvas.Pen.Color:=cl3DDkShadow;
      canvas.Line(hrect.Left,hrect.Top,hrect.Left,hrect.Bottom);
      Canvas.Pen.Color:=tc;
    end;
  end;
end;

function findnext(psubtree:PTPropertyDeskriptorArray;current:PPropertyDeskriptor):PPropertyDeskriptor;
var
  curr:PPropertyDeskriptor;
  ir:itrec;
begin
  Result:=nil;
  curr:=psubtree^.beginiterate(ir);
  if curr<>nil then
    repeat
      if curr^.IsVisible(OIManager.INTFObjInspShowEmptySections) then begin
        if curr=current then begin
          Result:=psubtree^.iterate(ir);
          if Result<>nil then
            if Result^.SubNode<>nil then
              Result:=nil;
          exit;
        end;
        if (curr^.SubNode<>nil)and(not curr^.Collapsed^) then
          Result:=findnext(pointer(curr^.SubNode),current);
        if Result<>nil then
          exit;
      end;
      curr:=psubtree^.iterate(ir);
    until curr=nil;
end;

function InternalMousetoprop(rowh:integer;psubtree:PTPropertyDeskriptorArray;mx,my:integer;var y:integer;
  var LastPropAddFreeSpace:boolean):PPropertyDeskriptor;
var
  curr:PPropertyDeskriptor;
  dy:integer;
  ir:itrec;
begin
  Result:=nil;
  if my<0 then
    exit;
  curr:=psubtree^.beginiterate(ir);
  if curr<>nil then
    repeat
      LastPropAddFreeSpace:=False;
      if curr^.IsVisible(OIManager.INTFObjInspShowEmptySections) then
        if (not((curr^.SubNode<>nil)and(curr^.SubNode.Count=0)))or OIManager.INTFObjInspShowEmptySections then begin
          dy:=my-y;
          if (dy<rowh)and(dy>0) then begin
            Result:=curr;
            exit;
          end;
          Inc(y,rowh);
          if (curr^.SubNode<>nil)and(not curr^.Collapsed^) then
            Result:=InternalMousetoprop(rowh,pointer(curr^.SubNode),mx,my,y,LastPropAddFreeSpace);
          if Result<>nil then
            exit;
        end;
      curr:=psubtree^.iterate(ir);
    until curr=nil;
  if not LastPropAddFreeSpace then begin
    y:=y+OIManager.INTFObjInspSpaceHeight;
    LastPropAddFreeSpace:=True;
  end;
end;

function mousetoprop(rowh:integer;psubtree:PTPropertyDeskriptorArray;mx,my:integer;var y:integer):PPropertyDeskriptor;
var
  lpafs:boolean;
begin
  lpafs:=False;
  Result:=InternalMousetoprop(rowh,psubtree,mx,my,y,lpafs);
end;

procedure TGDBobjinsp.ClearEDContext;
begin
  EDContext.ppropcurrentedit:=nil;
end;

procedure TGDBobjinsp.FreeEditor;
begin
  ClearEDContext;
  if peditor<>nil then begin
    peditor.geteditor.OnExit:=nil;
    peditor.geteditor.Hide;
    peditor.Destroy;
    peditor:=nil;
  end;
  FreeAndNil(peditor);
  invalidate;
  if assigned(onAfterFreeEditor) then
    onAfterFreeEditor(self);
end;

procedure TGDBobjinsp.StoreAndFreeEditor;
begin
  if peditor<>nil then begin
    peditor.EditingDone2(peditor.geteditor);
    freeeditor;
  end;
end;

procedure TGDBobjinsp.AsyncFreeEditorAndSelectNext;
var
  Next:PPropertyDeskriptor;
begin
  Next:=findnext(@pda,pointer(Data));
  freeeditor;
  if Next<>nil then
    createeditor(Next);
end;

procedure TGDBobjinsp.AsyncFreeEditor;
begin
  freeeditor;
end;

procedure TGDBobjinsp.Notify;
var
  pld:pointer;
  saveppropcurrentedit:PPropertyDeskriptor;
begin
  if Sender=peditor then begin
    saveppropcurrentedit:=EDContext.ppropcurrentedit;
    if assigned(onNotify) then
      onNotify(CurrData.Ctx);
    pld:=peditor.PInstance;

    if (Command=TMNC_RunFastEditor) then
      EDContext.ppropcurrentedit.FastEditors[0].Procs.OnRunFastEditor(pld);
    if peditor.changed then
      UpdateObjectInInsp;
    if (Command=TMNC_RunFastEditor)or(Command=TMNC_EditingDoneLostFocus){or(Command=TMNC_EditingDoneDoNothing)} then {
or(Command=TMNC_EditingDoneDoNothing)
Revision: 1130
Author: zamtmn
Date: 13 декабря 2014 г. 4:59:54
Message:
Close selectable editors after selecting in object inspector
----
Modified : /trunk/cad_source/gui/objinsp.pas
Modified : /trunk/cad_source/languade/UBaseTypeDescriptor.pas
Modified : /trunk/cad_source/languade/varmandef.pas

но помоему оно тут ненужно, т.к. закрывает открываемый едитор
}
    begin
      Application.QueueAsyncCall(AsyncFreeEditor,0);
    end;
    if (Command=TMNC_EditingDoneEnterKey) then
      Application.QueueAsyncCall(AsyncFreeEditorAndSelectNext,ptruint(saveppropcurrentedit));
  end;
end;

procedure TGDBobjinsp.UpdateObjectInInsp;
var
  OnFieldModifyProc:TOnFieldModifyProc;
  PParentType:PUserTypeDescriptor;
begin
  PParentType:=CurrData.PType;
  OnFieldModifyProc:=nil;
  while (@OnFieldModifyProc=nil)and(PParentType<>nil) do begin
    OnFieldModifyProc:=OIManager.OnFieldModifyProc(PParentType);
    PParentType:=PParentType^.GetParentTypedef;
  end;
  if assigned(onUpdateObjectInInsp) then
    onUpdateObjectInInsp(EDContext,CurrData.PType,CurrData.Ctx,CurrData.PObj,OnFieldModifyProc);
  self.updateinsp;
end;

procedure TGDBobjinsp.ScrollBy(DeltaX,DeltaY:integer);
var
  r:trect;
begin
  {$IFNDEF WINDOWS}
  inherited;
  {$ENDIF}
  {$IFDEF WINDOWS}
  r:=ClientRect;
  r.Top:=r.Bottom;
  ScrollWindowEx(Handle, DeltaX, DeltaY, nil, {nil}@r, 0, nil, {SW_INVALIDATE or SW_ERASE}SW_SCROLLCHILDREN);
  {$ENDIF}
  if peditor<>nil then begin
    if (EDContext.ppropcurrentedit.rect.Top<HeadersHeight+VertScrollBar.ScrollPos-1)  or
      (EDContext.ppropcurrentedit.rect.Top>clientheight+VertScrollBar.ScrollPos-1) then begin
      Application.QueueAsyncCall(AsyncFreeEditor,0);
      peditor.geteditor.Hide;
    end;
  end;
  //UpdateScrollbars;
  invalidate;
end;

procedure TGDBobjinsp.createscrollbars;
var
  ch:integer;
begin
  //ебаный скролинг работает везде по разному, или я туплю... переписывать надо эту хрень
  ch:=contentheigth+HeadersHeight;
  {if (VertScrollBar.Range=ch)or(VertScrollBar.Position=0) then
    changed:=false
   else
    changed:=true;}
  self.VertScrollBar.Range:=ch;
  self.VertScrollBar.page:=Height;
  self.VertScrollBar.Tracking:=True;
  self.VertScrollBar.Smooth:=True;
  self.VertScrollBar.Increment:=200;
  if ch<Height then begin
   {$IFNDEF LCLQt}
    //ScrollBy(0,-VertScrollBar.Position);
   {$ENDIF}
    VertScrollBar.Position:=0;
    self.VertScrollBar.page:=Height;
    self.VertScrollBar.Range:=Height;
    self.VertScrollBar.Tracking:=False;
    self.VertScrollBar.Smooth:=False;
    self.VertScrollBar.Increment:=200;
  end;
  UpdateScrollbars;
end;

function TGDBobjinsp.IsMouseOnSpliter(pp:PPropertyDeskriptor;X,Y:integer):boolean;
var
  my:integer;
  canresplit:boolean;
begin
  Result:=False;
  my:=y-self.VertScrollBar.Position;
  if IsHeadersEnabled then begin
    if (my>0)and(my<HeadersHeight) then
      canresplit:=True
    else
      canresplit:=False;
  end else
    canresplit:=True;

  if canresplit then
    if (abs(x-NameColumnWidth)<spliterhalfwidth) then
      Result:=True;
end;

procedure TGDBobjinsp.MouseLeave;
begin
  if OnMousePP<>nil then begin
    clearRTstate(OnMousePP.FastEditors);
    OnMousePP:=nil;
    invalidate;
  end;
  inherited;
end;

procedure TGDBobjinsp.MouseMove(Shift:TShiftState;X,Y:integer);
var
  my:integer;
  pp:PPropertyDeskriptor;
  tp:pointer;
  tempstr:string;
  needredraw:boolean;
  i:integer;
  currstate:TFastEditorState;
  rowh:integer;
begin
  rowh:=getRowHeight;
  needredraw:=False;
  if mresplit then begin
    if NameColumnWidth<subtab then begin
      if x>NameColumnWidth then begin
        NameColumnWidth:=x;
        NameColumnWidthCorrector.LastNameColumnWidth:=NameColumnWidth;
        NameColumnWidthCorrector.LastClientWidth:=clientwidth;
      end;
    end else if NameColumnWidth>clientwidth-subtab then begin
      if x<NameColumnWidth then begin
        NameColumnWidth:=x;
        NameColumnWidthCorrector.LastNameColumnWidth:=NameColumnWidth;
        NameColumnWidthCorrector.LastClientWidth:=clientwidth;
      end;
    end else begin
      NameColumnWidth:=x;
      NameColumnWidthCorrector.LastNameColumnWidth:=NameColumnWidth;
      NameColumnWidthCorrector.LastClientWidth:=clientwidth;
    end;
    repaint;
    updateeditorBounds;
    exit;
  end;
  y:=y+VertScrollBar.scrollpos-self.BorderWidth;
  my:=HeadersHeight;
  pp:=mousetoprop(rowh,@pda,x,y,my);
  if OnMousePP<>pp then begin
    needredraw:=True;
    if OnMousePP<>nil then
      clearRTstate(OnMousePP.FastEditors);
    OnMousePP:=pp;
  end;
  if IsMouseOnSpliter(pp,X,Y) then
    self.Cursor:=crHSplit
  else
    self.Cursor:=crDefault;

  if (pp=nil)or(EDContext.ppropcurrentedit=pp) then begin
    self.Hint:='';
    self.ShowHint:=False;
    oldpp:=pp;
    if needredraw then
      invalidate;
    exit;
  end;

  if assigned(pp.FastEditors) then begin
    if ssLeft in Shift then
      currstate:=TFES_Pressed
    else
      currstate:=TFES_Hot;
    for i:=0 to pp.FastEditors.Size-1 do begin
      if pp.FastEditors.Mutable[i]^.FastEditorDrawed then begin
        if PtInRect(pp.FastEditors[i].FastEditorRect,Point(x,y)) then
          pp.FastEditors.Mutable[i]^.FastEditorState:=currstate
        else
          pp.FastEditors.Mutable[i]^.FastEditorState:=TFES_Default;
      end;
    end;
    needredraw:=True;
  end;

  if oldpp<>pp then begin
    if oldpp<>nil then begin
      clearRTstate(oldpp.FastEditors);
      needredraw:=True;
    end;
    Application.CancelHint;
    tempstr:=pp^.Name;
    if pp^.ValKey<>'' then
      tempstr:=tempstr+'   '+pp^.ValKey+':'+pp^.ValType;
    if pp^.Value<>'' then
      tempstr:=tempstr+':='+pp^.Value;
    self.Hint:=tempstr;
    self.ShowHint:=True;
  end else
    Application.ActivateHint(ClientToScreen(Point(X,Y)));

  if needredraw then
    invalidate;

  oldpp:=pp;
  if fldaReadOnly in pp^.Attr then
    exit;

  exit;

  if pp^.PTypeManager<>nil then begin
    if peditor<>nil then begin
      tp:=CurrData.PObj;
      buildproplist(CurrData.UnitsFormat,CurrData.PType,property_correct,tp);
      EDContext.ppropcurrentedit:=pp;
    end;
    PEditor:=pp^.PTypeManager^.CreateEditor(@self,pp.rect,pp^.valueAddres,nil,False,'этого не должно тут быть',
      rowh,CurrData.UnitsFormat).Editor;
    if PEditor<>nil then begin
      //PEditor^.show;
    end;
  end;
end;

procedure TGDBobjinsp.MouseUp(Button:TMouseButton;Shift:TShiftState;X,Y:integer);
var
  pp:PPropertyDeskriptor;
  my:integer;
  i:integer;
  needexit:boolean;
begin
  inherited;
  if (button=mbLeft)  and (mresplit=True) then begin
    mresplit:=False;
    exit;
  end;
  if peditor<>nil then
    if peditor.geteditor.Visible=False then begin
      peditor.geteditor.Visible:=True;
      peditor.geteditor.SetFocus;
      if peditor.geteditor is  TComboBox then
        if (peditor.geteditor as  TComboBox).Style in [csDropDownList,csOwnerDrawFixed,csOwnerDrawVariable] then
          TComboBox(peditor.geteditor).DroppedDown:=True;
      //автооткрытие комбика мещает вводу, открываем только те что без возможности ввода значений
      exit;
    end;
  if (button=mbLeft) then begin
    y:=y+VertScrollBar.scrollpos-self.BorderWidth;
    my:=HeadersHeight;
    pp:=mousetoprop(getRowHeight,@pda,x,y,my);
    if pp=nil then
      exit;
    if assigned(pp.FastEditors) then begin
      needexit:=False;
      for i:=0 to pp.FastEditors.size-1 do
        if pp.FastEditors[i].FastEditorDrawed then
          if PtInRect(pp.FastEditors[i].FastEditorRect,point(x,y)) then
            if pp.FastEditors[i].FastEditorState=TFES_Pressed then begin
              pp.FastEditors.Mutable[i]^.FastEditorState:=TFES_Default;
              if assigned(pp.FastEditors[i].Procs.OnRunFastEditor) then begin
                StoreAndFreeEditor;;
                EDContext.ppropcurrentedit:=pp;
                if pp.FastEditors[i].Procs.UndoInsideFastEditor then begin
                  pp.FastEditors[i].Procs.OnRunFastEditor(pp.valueAddres);
                  needexit:=True;
                end else begin
                  if (*IsCurrObjInUndoContext({GDBobj,}CurrPObj)*)False then begin
                    //EDContext.UndoStack:=GetUndoStack;
                    //EDContext.UndoCommand:=EDContext.UndoStack.PushCreateTTypedChangeCommand(pp^.valueAddres,pp^.PTypeManager);
                    // EDContext.UndoCommand.PDataOwner:=CurrPObj;

                    pp.FastEditors[i].Procs.OnRunFastEditor(pp.valueAddres);
                    //EDContext.UndoCommand.ComitFromObj;

                    //EDContext.UndoStack:=nil;
                    //EDContext.UndoCommand:=nil;
                    needexit:=True;
                  end else begin
                    pp.FastEditors[i].Procs.OnRunFastEditor(pp.valueAddres);
                    needexit:=True;
                  end;
                end;
              end;
              UpdateObjectInInsp;
              EDContext.ppropcurrentedit:=nil;
              invalidate;
              if needexit then
                system.break;
            end;
    end;
  end;
end;
constructor TGDBobjinsp.Create(AOwner:TComponent);
begin
  inherited;
end;

procedure TGDBobjinsp.createeditor(pp:PPropertyDeskriptor);
var
  tp:pointer;
  vsa:TZctnrVectorStrings;
  TED:TEditorDesc;
  editorcontrol:TWinControl;
  tr:TRect;
  initialvalue:string;
begin
  if pp^.SubNode<>nil then begin
    StoreAndFreeEditor;
    if pbyte(pp^.Collapsed)^<>0 then
      pbyte(pp^.Collapsed)^:=1;
    pp^.Collapsed^:=not(pp^.Collapsed^);
    updateinsp;
  end else begin
    if fldaReadOnly in pp^.Attr then
      exit;
    if pp^.PTypeManager<>nil then begin
      if peditor<>nil then begin
        tp:=CurrData.PObj;
        buildproplist(CurrData.UnitsFormat,CurrData.PType,property_correct,tp);
        StoreAndFreeEditor;
      end;
      vsa.init(50);

      if assigned(onGetOtherValues) then
        onGetOtherValues(vsa,pp^.valkey,CurrData);

      if assigned(pp^.valueAddres) then begin
        if fldaDifferent in pp^.Attr then
          initialvalue:=OIManager.DifferentName
        else
          initialvalue:='';
        tr:=pp^.rect;
        if assigned(pp^.Decorators.OnCreateEditor) then
          TED:=
            pp^.Decorators.OnCreateEditor(self,tr,pp^.valueAddres,@vsa,False,pp^.PTypeManager,CurrData.UnitsFormat)
        else
          TED:=pp^.PTypeManager^.CreateEditor(self,tr,pp^.valueAddres,@vsa,{false}True,initialvalue,
            getRowHeight,CurrData.UnitsFormat);
        case ted.Mode of
          TEM_Integrate:begin
            TED.Editor.SetEditorBounds(pp,OIManager.INTFObjInspShowOnlyHotFastEditors);
            editorcontrol:=TED.Editor.geteditor;
            if (editorcontrol is TComboBox) then begin
             {$IFNDEF LCLWIN32}
              editorcontrol.Visible:=False;
             {$ENDIF}
              editorcontrol.Parent:=self;
              SetComboSize(editorcontrol as TCombobox,getRowHeight-6,CBDoNotTouch);
              if (editorcontrol as TCombobox).Style in [csDropDownList,csOwnerDrawFixed,csOwnerDrawVariable] then
                (editorcontrol as TCombobox).droppeddown:=True;
              //автооткрытие комбика мещает вводу, открываем только те что без возможности ввода значений
            end else if (editorcontrol is TColorBox) then begin
              {$IFNDEF LCLWIN32}
              editorcontrol.Visible:=False;
              {$ENDIF}
              editorcontrol.Parent:=self;
              (editorcontrol as TColorBox).droppeddown:=True;
            end else
              editorcontrol.Parent:=self;
            PEditor:=TED.Editor;
          end;
        end;
      end;
      vsa.done;
      if assigned(PEditor) then begin
        EDContext.ppropcurrentedit:=pp;
        peditor.OwnerNotify:=self.Notify;
        if peditor.geteditor.Visible then
          peditor.geteditor.SetFocus;
      end;
    end;
  end;
end;

procedure TGDBobjinsp.MouseDown(Button:TMouseButton;Shift:TShiftState;X,Y:integer);
var
  my:integer;
  pp:PPropertyDeskriptor;
  clickonheader:boolean;
  i,Count:integer;
  handled:boolean;
begin
  inherited;
  if (y<0)or(y>clientheight)or(x<0)or(x>clientwidth) then begin
    StoreAndFreeEditor;
    exit;
  end;
  if (y<HeadersHeight) then begin
    if button<>mbLeft then
      StoreAndFreeEditor;
    clickonheader:=True;
  end else
    clickonheader:=False;
  y:=y+VertScrollBar.scrollpos-self.BorderWidth;
  my:=HeadersHeight;
  pp:=mousetoprop(getRowHeight,@pda,x,y,my);

  if (button=mbLeft)  and (IsMouseOnSpliter(pp,X,Y)) then begin
    mresplit:=True;
    exit;
  end;
  if (pp=nil)and(button=mbLeft) then
    exit;
  if (button=mbLeft) then begin
    if not clickonheader then begin
      if assigned(pp.FastEditors) then begin
        Count:=0;
        for i:=0 to pp.FastEditors.size-1 do
          if pp.FastEditors[i].FastEditorDrawed then
            if PtInRect(pp.FastEditors[i].FastEditorRect,point(x,y)) then begin
              pp.FastEditors.Mutable[i]^.FastEditorState:=TFES_Pressed;
              Inc(Count);
            end;
        if Count=0 then
          createeditor(pp);
      end else
        createeditor(pp);
    end;
  end else begin
    begin
      currpd:=pp;
      if assigned(OnContextPopup) then
        OnContextPopup(self,point(X,Y),handled);
    end;
  end;

  contentheigth:=gettreeh;
  createscrollbars;
  self.Invalidate;
end;

procedure TGDBobjinsp.updateinsp;
begin
  setptr(CurrData);
  updateeditorBounds;
end;


procedure TGDBobjinsp.rebuild;
var
  tp:pointer;
begin
  pda.cleareraseobj;
  if peditor<>nil then begin
    //--MultiSelectEditor not work with this self.freeeditor;
  end;
  tp:=CurrData.PObj;
  buildproplist(CurrData.UnitsFormat,CurrData.PType,property_build,tp);
  contentheigth:=gettreeh;
  if CurrData.PType^.OIP.ci=self.Height then begin
    VertScrollBar.Position:=CurrData.PType^.OIP.barpos;
  end else begin
    VertScrollBar.Position:=0;
  end;

  createscrollbars;
  draw;
end;

procedure TGDBobjinsp.setptr(AData:TDisplayedData);
begin
  if (CurrData.PObj<>AData.PObj)or(CurrData.PType<>AData.PType) then begin
    OnMousePP:=nil;
    currpd:=nil;
    if peditor<>nil then begin
      self.freeeditor;
    end;
    if assigned(CurrData.PType) then begin
      CurrData.PType^.OIP.ci:=self.Height;
      CurrData.PType^.OIP.barpos:=VertScrollBar.Position;
    end;
    pda.cleareraseobj;
    CurrData:=AData;
    oldpp:=nil;
    buildproplist(AData.UnitsFormat,AData.PType,property_build,AData.PObj);
    contentheigth:=gettreeh;
    createscrollbars;
    if CurrData.PType^.OIP.ci=self.Height then begin
      VertScrollBar.Position:=CurrData.PType^.OIP.barpos;
    end else begin
      VertScrollBar.Position:=0;
    end;

  end else begin
    buildproplist(AData.UnitsFormat,AData.PType,property_correct,AData.PObj);
    contentheigth:=gettreeh;
    createscrollbars;
  end;
  Refresh;
end;

procedure TGDBobjinsp.updateeditorBounds;
begin
  if (peditor<>nil)and(EDContext.ppropcurrentedit<>nil) then
    pEditor.SetEditorBounds(EDContext.ppropcurrentedit,OIManager.INTFObjInspShowOnlyHotFastEditors);
end;

procedure TGDBobjinsp._onresize(Sender:TObject);
 {$IFDEF LCLGTK2}
  var Widget: PGtkWidget;
 {$ENDIF}
begin
  if NameColumnWidthCorrector.LastClientWidth>0 then
    NameColumnWidth:=round(NameColumnWidthCorrector.LastNameColumnWidth*(clientwidth/NameColumnWidthCorrector.LastClientWidth));
  if NameColumnWidth>clientwidth-subtab then
    NameColumnWidth:=clientwidth-subtab;
  if NameColumnWidth<subtab then
    NameColumnWidth:=clientwidth div 2;
  {$IFDEF LCLGTK2}
  //Widget:=PGtkWidget(PtrUInt(Handle));
  //gtk_widget_add_events (Widget,GDK_POINTER_MOTION_HINT_MASK);
  {$ENDIF}
  createscrollbars;
  updateeditorBounds;
end;

procedure Register;
begin
  RegisterComponents('zcadcontrols',[TGDBobjinsp]);
end;

initialization
  //OIManager.Init;
finalization
  //OIManager.Done;
end.
