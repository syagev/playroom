// PlayRoomDlg.h : header file

#pragma once
#include "afxwin.h"
#include "PRFeed.h"
#include "afxmenubutton.h"
#include "GUIUtils.h"
#include "afxcmn.h"


// CPlayRoomDlg dialog
class CPlayRoomDlg : public CDialogEx
{
// Construction
public:
	CPlayRoomDlg(CWnd* pParent = NULL);	// standard constructor

// Dialog Data
	enum { IDD = IDD_PLAYROOM_DIALOG };

protected:
	virtual void DoDataExchange(CDataExchange* pDX);	// DDX/DDV support

private:
	CPRFeed* m_pPRFeed;
	CStoryboard* m_pStory;
	void Stat(LPCTSTR sStat);
	//bool m_bLearnBG;
	std::map<int,CPropWindow*> m_mapPropWindows;

// Implementation
protected:
	HICON m_hIcon;

	void static OnCVMouse(int event, int x, int y, int flags, void* param);

	// Generated message map functions
	virtual BOOL OnInitDialog();
	afx_msg void OnPaint();
	afx_msg HCURSOR OnQueryDragIcon();
	DECLARE_MESSAGE_MAP()
public:
	afx_msg void OnBnClickedLearnBg();
	CEdit m_txtStat;
	afx_msg void OnBnClickedGetFeed();
	afx_msg void OnBnClickedPlay();
	afx_msg void OnBnClickedStop();
	CMFCMenuButton m_btnMarkProp;
	CMenu m_mnuPopup;
	afx_msg void OnBnClickedMarkProp();
	afx_msg void OnBnClickedPause();
	afx_msg void OnBnClickedAttSb();
	afx_msg void OnBnClickedSbPlay();
	afx_msg void OnClose();
	afx_msg void OnBnClickedMarkCarpet();
//	afx_msg void OnShowWindow(BOOL bShow, UINT nStatus);
//	afx_msg void OnNMCustomdrawSlider1(NMHDR *pNMHDR, LRESULT *pResult);
//	afx_msg void OnTRBNThumbPosChangingSlider1(NMHDR *pNMHDR, LRESULT *pResult);
	afx_msg void OnHScroll(UINT nSBCode, UINT nPos, CScrollBar* pScrollBar);
	CSliderCtrl m_sldTouch;
	CEdit m_txtTouch;
};
