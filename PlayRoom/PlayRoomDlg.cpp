// PlayRoomDlg.cpp : implementation file

#include "stdafx.h"
#include "PlayRoom.h"
#include "PlayRoomDlg.h"
#include "afxdialogex.h"

using namespace std;
using namespace cv;

#define QUICKSTART


CPlayRoomDlg::CPlayRoomDlg(CWnd* pParent /*=NULL*/)
	: CDialogEx(CPlayRoomDlg::IDD, pParent)
{
	m_hIcon = AfxGetApp()->LoadIcon(IDR_MAINFRAME);
	m_pPRFeed = NULL;
	//m_bLearnBG = false;
	m_pStory = NULL;
}

void CPlayRoomDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialogEx::DoDataExchange(pDX);
	DDX_Control(pDX, IDC_TXT_STAT, m_txtStat);
	DDX_Control(pDX, IDC_MARK_PROP, m_btnMarkProp);
	DDX_Control(pDX, IDC_MARK_PROP, m_btnMarkProp);
	DDX_Control(pDX, IDC_SLD_TOUCH, m_sldTouch);
	DDX_Control(pDX, IDC_TXT_TOUCH, m_txtTouch);
}

BEGIN_MESSAGE_MAP(CPlayRoomDlg, CDialogEx)
	ON_WM_PAINT()
	ON_WM_QUERYDRAGICON()
	ON_BN_CLICKED(IDC_LEARN_BG, &CPlayRoomDlg::OnBnClickedLearnBg)
	ON_BN_CLICKED(IDC_GET_FEED, &CPlayRoomDlg::OnBnClickedGetFeed)
	ON_BN_CLICKED(IDC_PLAY, &CPlayRoomDlg::OnBnClickedPlay)
	ON_BN_CLICKED(IDC_STOP, &CPlayRoomDlg::OnBnClickedStop)
ON_BN_CLICKED(IDC_MARK_PROP, &CPlayRoomDlg::OnBnClickedMarkProp)
ON_BN_CLICKED(IDC_PAUSE, &CPlayRoomDlg::OnBnClickedPause)
ON_BN_CLICKED(IDC_ATT_SB, &CPlayRoomDlg::OnBnClickedAttSb)
ON_BN_CLICKED(IDC_SB_PLAY, &CPlayRoomDlg::OnBnClickedSbPlay)
ON_WM_CLOSE()
ON_BN_CLICKED(IDC_MARK_CARPET, &CPlayRoomDlg::OnBnClickedMarkCarpet)
//ON_WM_SHOWWINDOW()
//ON_NOTIFY(NM_CUSTOMDRAW, IDC_SLIDER1, &CPlayRoomDlg::OnNMCustomdrawSlider1)
//ON_NOTIFY(TRBN_THUMBPOSCHANGING, IDC_SLIDER1, &CPlayRoomDlg::OnTRBNThumbPosChangingSlider1)
ON_WM_HSCROLL()
END_MESSAGE_MAP()


// CPlayRoomDlg message handlers
BOOL CPlayRoomDlg::OnInitDialog()
{
	CDialogEx::OnInitDialog();

	// Set the icon for this dialog.  The framework does this automatically
	//  when the application's main window is not a dialog
	SetIcon(m_hIcon, TRUE);			// Set big icon
	SetIcon(m_hIcon, FALSE);		// Set small icon

	m_mnuPopup.LoadMenu(IDR_MENU_POPUP);
	m_btnMarkProp.m_hMenu = m_mnuPopup.GetSubMenu(0)->GetSafeHmenu();
	m_sldTouch.SetRange(0, 1000);
	
	//quick start
#ifdef QUICKSTART
	OnBnClickedGetFeed();
	OnBnClickedAttSb();
	OnBnClickedPlay();

	SetTimer((UINT_PTR)this, 2000, [](HWND hWnd, UINT nMsg, UINT_PTR pDlg, DWORD dwTime) {
		CPlayRoomDlg* pThis =  (CPlayRoomDlg*)pDlg;
		pThis->m_btnMarkProp.m_nMenuResult = ID_MARKPROP_DOG;
		pThis->OnBnClickedMarkProp();
		pThis->m_btnMarkProp.m_nMenuResult = ID_MARKPROP_BOWL;
		pThis->OnBnClickedMarkProp(); 
		pThis->m_btnMarkProp.m_nMenuResult = ID_MARKPROP_PARK;
		pThis->OnBnClickedMarkProp(); 
		pThis->m_btnMarkProp.m_nMenuResult = ID_MARKPROP_BONE;
		pThis->OnBnClickedMarkProp(); 
		pThis->OnBnClickedSbPlay();
		pThis->KillTimer(pDlg);
	});
#endif
	
	return TRUE;  // return TRUE  unless you set the focus to a control
}


void CPlayRoomDlg::OnClose()
{
	if (m_pPRFeed != NULL)
		delete m_pPRFeed;
	if (m_pStory != NULL)
		delete m_pStory;

	for (map<int,CPropWindow*>::iterator iter = m_mapPropWindows.begin(); iter != m_mapPropWindows.end(); ++iter)
		delete iter->second;

	CDialog::OnClose();
}

// If you add a minimize button to your dialog, you will need the code below
//  to draw the icon.  For MFC applications using the document/view model,
//  this is automatically done for you by the framework.
void CPlayRoomDlg::OnPaint()
{
	if (IsIconic())
	{
		CPaintDC dc(this); // device context for painting

		SendMessage(WM_ICONERASEBKGND, reinterpret_cast<WPARAM>(dc.GetSafeHdc()), 0);

		// Center icon in client rectangle
		int cxIcon = GetSystemMetrics(SM_CXICON);
		int cyIcon = GetSystemMetrics(SM_CYICON);
		CRect rect;
		GetClientRect(&rect);
		int x = (rect.Width() - cxIcon + 1) / 2;
		int y = (rect.Height() - cyIcon + 1) / 2;

		// Draw the icon
		dc.DrawIcon(x, y, m_hIcon);
	}
	else
	{
		CDialogEx::OnPaint();
	}
}

// The system calls this function to obtain the cursor to display while the user drags
//  the minimized window.
HCURSOR CPlayRoomDlg::OnQueryDragIcon()
{
	return static_cast<HCURSOR>(m_hIcon);
}

// Set the status text
void CPlayRoomDlg::Stat(LPCTSTR sStat)
{
	m_txtStat.SetWindowText(sStat);
}

// Learn BG & Carpet button
void CPlayRoomDlg::OnBnClickedLearnBg()
{
	//if (m_pPRFeed == NULL) {
	//	Stat("There is no active feed");
	//	return;
	//}

	//////check if currently learning
	//if (!m_pPRFeed->LearnBG())
	//	Stat("Stopped learning BG");
	//else
	//	Stat("Learning BG... click again to stop");
}

// Start PR Feed button
void CPlayRoomDlg::OnBnClickedGetFeed()
{
	if (m_pPRFeed != NULL) {
		if (AfxMessageBox("There is an active feed, I will kill it", MB_OKCANCEL) == IDOK)
			delete m_pPRFeed;
	}

	//m_pPRFeed = new CPRFeed("S:\\Dropbox\\Projects\\PlayRoom\\Raw\\R1-bg-grab-move-1prop.wmv");
	m_pPRFeed = new CPRFeed("CAM");
	Stat("Feed created");
}

// Play button
void CPlayRoomDlg::OnBnClickedPlay()
{
	if (m_pPRFeed == NULL) {
		Stat("There is no active feed");
		return;
	}

	if (m_pPRFeed->Play())
		Stat("Feed playing");
	else
		Stat("Can't play, maybe playing already?");
}

// Pause button - pause/continue the feed
void CPlayRoomDlg::OnBnClickedPause()
{
	if (m_pPRFeed == NULL) {
		Stat("There is no active feed");
		return;
	}

	if (m_pPRFeed->Pause())
		Stat("Feed paused/continued");
	else
		Stat("Can't pause, maybe not playing?");
	
}

// Stop button
void CPlayRoomDlg::OnBnClickedStop()
{
	if (m_pPRFeed == NULL) {
		Stat("There is no active feed");
		return;
	}

	if (m_pPRFeed->Stop())
		Stat("Feed stopped");
}

// Mark prop button
void CPlayRoomDlg::OnBnClickedMarkProp()
{
	if (m_pPRFeed == NULL) {
		Stat("There is no active feed");
		return;
	}
	if (!m_pPRFeed->IsPlaying()) {
		Stat("The feed is not playing");
		return;
	}

	int iMenuResult;
	if ((iMenuResult = m_btnMarkProp.m_nMenuResult) != NULL) {
		////select an ROI (this will block)
		//CROISelector ROIselector(matSnap);
		//Rect rectProp = ROIselector.SelectROI();
		
		switch (iMenuResult) {
		case ID_MARKPROP_DOG:
			iMenuResult = CStoryboardBarnie::DOG;
			break;
		case ID_MARKPROP_BOWL:
			iMenuResult = CStoryboardBarnie::BOWL;
			break;
		case ID_MARKPROP_PARK:
			iMenuResult = CStoryboardBarnie::PARK;
			break;
		case ID_MARKPROP_BONE:
			iMenuResult = CStoryboardBarnie::BONE;
			break;
		}

		map<int, CPropWindow*>::const_iterator itrPropWin = 
			m_mapPropWindows.find(iMenuResult);
		if (itrPropWin == m_mapPropWindows.end()) {
			//get the prop string and open the prop's window
			CString cstrPropString;
			m_mnuPopup.GetMenuString(m_btnMarkProp.m_nMenuResult, cstrPropString, NULL);
			itrPropWin = m_mapPropWindows.insert( pair<int,CPropWindow*>( iMenuResult, 
				new CPropWindow(iMenuResult, m_pPRFeed, string((LPCSTR)cstrPropString)))).first;
		}
		(*itrPropWin).second->Show();
	}
}

// Attach SB button
void CPlayRoomDlg::OnBnClickedAttSb()
{
	//check if there is a current story
	if (m_pStory != NULL) {
		if (m_pStory->IsPlaying()) {
			Stat("Stop the current storyboard first");
			return;
		}
	}
	//check there is a feed
	if (m_pPRFeed == NULL) {
		Stat("Need an active feed to attach to");
		return;
	}

	//create the new storyboard
	CStoryboard* pNewStory = new CStoryboardBarnie();

	//update controls to params
	int iTouchThresh = pNewStory->Get(CStoryboardBarnie::TOUCH_THRESHOLD); 
	m_sldTouch.SetPos(iTouchThresh);

	//attach
	if (m_pPRFeed->AttachStoryboard(pNewStory, false)) {
		//delete the old story
		delete m_pStory;
		m_pStory = pNewStory;

		Stat("Storyboard attached");
	}
	else {
		delete pNewStory;
		Stat("Can't attach storyboard, make sure feed either stopped or paused");
	}
}

// SB Play button
void CPlayRoomDlg::OnBnClickedSbPlay()
{
	if (m_pStory == NULL) {
		Stat("No storyboard attached");
		return;
	}

	if (m_pStory->Play())
		Stat("Storyboard playing");
	else
		Stat("Can't play, maybe storyboard playing already?");
}

void CPlayRoomDlg::OnBnClickedMarkCarpet()
{
	if (m_pPRFeed == NULL) {
		Stat("There is no active feed");
		return;
	}
	if (!m_pPRFeed->IsPlaying()) {
		Stat("The feed is not playing");
		return;
	}
	
	Mat matSnap = m_pPRFeed->GetSnapshot();
	m_pPRFeed->Pause();

	if (m_pPRFeed->MarkCarpet(selectCarpet(matSnap)))
		Stat("Carpet updated");
	else
		Stat("Couldn't update carpet, you need to be un-paused");
	
	m_pPRFeed->Pause();
}


//void CPlayRoomDlg::OnShowWindow(BOOL bShow, UINT nStatus)
//{
//	CDialogEx::OnShowWindow(bShow, nStatus);
//#ifdef QUICKSTART
//	m_btnMarkProp.m_nMenuResult = ID_MARKPROP_DOG;
//	OnBnClickedMarkProp();
//	m_btnMarkProp.m_nMenuResult = ID_MARKPROP_BOWL;
//	OnBnClickedMarkProp();
//#endif
//}


//void CPlayRoomDlg::OnNMCustomdrawSlider1(NMHDR *pNMHDR, LRESULT *pResult)
//{
//	LPNMCUSTOMDRAW pNMCD = reinterpret_cast<LPNMCUSTOMDRAW>(pNMHDR);
//	@TN
//		*pResult = 0;
//	// TODO: Add your control notification handler code here
//	*pResult = 0;
//}


//void CPlayRoomDlg::OnTRBNThumbPosChangingSlider1(NMHDR *pNMHDR, LRESULT *pResult)
//{
//	// This feature requires Windows Vista or greater.
//	// The symbol _WIN32_WINNT must be >= 0x0600.
//	NMTRBTHUMBPOSCHANGING *pNMTPC = reinterpret_cast<NMTRBTHUMBPOSCHANGING *>(pNMHDR);
//	@TN
//		*pResult = 0;
//	// TODO: Add your control notification handler code here
//	*pResult = 0;
//}


void CPlayRoomDlg::OnHScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar)
{
	char sBuf[16];

	if (nSBCode == TB_THUMBTRACK) {
		_itoa_s(nPos, sBuf, 16, 10);
		m_txtTouch.SetWindowText(sBuf);
		m_pStory->Set(CStoryboardBarnie::TOUCH_THRESHOLD, nPos);
	}

	CDialogEx::OnHScroll(nSBCode, nPos, pScrollBar);
}
