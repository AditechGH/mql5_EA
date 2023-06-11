#property copyright "Copyright 2023, Aditek Trading."
#property link      "https://www.aditektrading.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Include 1                                                        |
//+------------------------------------------------------------------+
#include <..\Experts\myEAs\TimeRangeEAPanel.mq5>
#include <Controls\Defines.mqh>

//+------------------------------------------------------------------+
//| Define statements to change default dialog settings              |
//+------------------------------------------------------------------+

#undef CONTROLS_FONT_NAME
#undef CONTROLS_DIALOG_CLIENT_BG
#define CONTROLS_FONT_NAME                "Consolas"
#define CONTROLS_DIALOG_COLOR_CLIENT_BG   C'0x20,0x20, 0x20'


//+------------------------------------------------------------------+
//| Include 2                                                        |
//+------------------------------------------------------------------+

#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "==== Panel Inputs ===="
static input int InpPanelWidth = 260;                   // width in pixel
static input int InpPanelHeight = 230;                  // height in pixel
static input int InpPanelFontSize = 13;                 // font size
static input color InpPanelTxtColor = clrWhiteSmoke;  // text color


//+------------------------------------------------------------------+
//| Class CGraphicalPanel                                            |
//+------------------------------------------------------------------+

class CGraphicalPanel: public CAppDialog 
{
    private:

        // private variables
        bool m_f_color;

        // labels
        CLabel m_lInput;
        CLabel m_lMagic;
        CLabel m_lLot;
        CLabel m_lStart;
        CLabel m_lDuration;
        CLabel m_lClose;

        // buttons
        CButton m_bChangeColor;

        // private methods
        void OnClickChangeColor();
        bool CheckInputs();
        bool CreatePanel();

    public: 

        void CGraphicalPanel();
        void ~CGraphicalPanel();
        bool OnInit();
        void Update();

        // chart event handler
        void PanelChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam);

};

// constructor
void CGraphicalPanel::CGraphicalPanel(void) {};

// deconstructor
void CGraphicalPanel::~CGraphicalPanel(void) {};

// init method
bool CGraphicalPanel::OnInit(void) {

    // check user inputs
    if(!this.CheckInputs()) {
        return false;
    }

    // create panel
    if(!this.CreatePanel()){
        return false;
    }
    return true;
}

// check user inputs
bool CGraphicalPanel::CheckInputs(void) {

    if(InpPanelWidth <= 0) {
        Alert("Panel Width < 0");
        return false;
    }
    if(InpPanelHeight <= 0) {
        Alert("Panel Height < 0");
        return false;
    }
    if(InpPanelFontSize <= 0) {
        Alert("Panel Size < 0");
        return false;
    }

    return true;
}

void CGraphicalPanel::Update(void) {
    m_lStart.Text("Start time: " + (string) inputRangeStart+ " "+ (range.start_time > 0 ? TimeToString(range.start_time, TIME_MINUTES): ""));
    m_lDuration.Text("Duration: " + (string) inputRangeDuration + " " + (range.end_time > 0 ? TimeToString(range.end_time, TIME_MINUTES): ""));
    m_lClose.Text("Close time: " + (string) inputRangeClose + " " + (range.close_time > 0 ? TimeToString(range.close_time, TIME_MINUTES): ""));
};

// create panel
bool CGraphicalPanel::CreatePanel(void) {

    // create dialog panel
    this.Create(NULL, "Time Range EA", 0, 0, 0, InpPanelWidth, InpPanelHeight);


    m_lInput.Create(NULL, "lInpul", 0, 20, 10, 1, 1);
    m_lInput.Text("Inputs");
    m_lInput.Color(clrLime);
    m_lInput.FontSize(InpPanelFontSize);
    this.Add(m_lInput);

    m_lMagic.Create(NULL, "lMagic", 0, 20, 30, 1, 1);
    m_lMagic.Text("MagicNumber: " + (string) inputMagicNumber);
    m_lMagic.Color(InpPanelTxtColor);
    m_lMagic.FontSize(InpPanelFontSize);
    this.Add(m_lMagic);

    m_lLot.Create(NULL, "lLot", 0, 20, 50, 1, 1);
    m_lLot.Text("Lot: " + (string) inputRiskPerTrade + "%");
    m_lLot.Color(InpPanelTxtColor);
    m_lLot.FontSize(InpPanelFontSize);
    this.Add(m_lLot);

    m_lStart.Create(NULL, "lStart", 0, 20, 70, 1, 1);
    m_lStart.Text("Start time: " + (string) inputRangeStart+ " "+ (range.start_time > 0 ? TimeToString(range.start_time, TIME_MINUTES): ""));
    m_lStart.Color(InpPanelTxtColor);
    m_lStart.FontSize(InpPanelFontSize);
    this.Add(m_lStart);

    m_lDuration.Create(NULL, "lDuration", 0, 20, 90, 1, 1);
    m_lDuration.Text("Duration: " + (string) inputRangeDuration + " " + (range.end_time > 0 ? TimeToString(range.end_time, TIME_MINUTES): ""));
    m_lDuration.Color(InpPanelTxtColor);
    m_lDuration.FontSize(InpPanelFontSize);
    this.Add(m_lDuration);
    
    m_lClose.Create(NULL, "lClose", 0, 20, 110, 1, 1);
    m_lClose.Text("Close time: " + (string) inputRangeClose + " " + (range.close_time > 0 ? TimeToString(range.close_time, TIME_MINUTES): ""));
    m_lClose.Color(InpPanelTxtColor);
    m_lClose.FontSize(InpPanelFontSize);
    this.Add(m_lClose);

    m_bChangeColor.Create(NULL, "bChangeColor", 0, 20, 150, 230, 180);
    m_bChangeColor.Text("Change Color");
    m_bChangeColor.Color(clrWhite);
    m_bChangeColor.ColorBackground(clrDarkRed);
    m_bChangeColor.FontSize(InpPanelFontSize);
    this.Add(m_bChangeColor);
    
    // run panel
    if(!Run()) {
        Print("Failed to run panel"); 
        return false;
    }

    // refresh objects
    ChartRedraw();

    return true;
}

// panel chart event
void CGraphicalPanel::PanelChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {

    // call chart event method of base class
    ChartEvent(id, lparam, dparam, sparam);

    if(id == CHARTEVENT_OBJECT_CLICK && sparam == "bChangeColor") {
        OnClickChangeColor();
    }

}

void CGraphicalPanel::OnClickChangeColor(void) {
    ChartSetInteger(NULL, CHART_COLOR_BACKGROUND, m_f_color ? clrWhite: clrAqua);
    m_f_color = !m_f_color;

    ChartRedraw();
}