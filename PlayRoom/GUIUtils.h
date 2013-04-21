#pragma once
#include "PRFeed.h"


class CPropWindow
{
public:
	CPropWindow(int iPropID, CPRFeed* pPRFeed, std::string sPropName);
	~CPropWindow(void);

	void Show();

private:
	std::string m_sPropName;
	CPRFeed* m_pPRFeed;
	cv::Mat m_matSnap;
	cv::Vec3b m_scClr, m_scThresh;
	int m_iPropID;
	
	static void mouseCallback(int iEvent, int x, int y, int flags, void* pThis); 
	static void trackbarCallback(int pos, void* userdata);
};


cv::Mat selectCarpet(cv::Mat matSnap);

//class CROISelector
//{
//public:
//	CROISelector(cv::Mat matImg);
//	~CROISelector(void);
//
//	cv::Rect SelectROI();
//
//protected:
//	void static OnCVMouse(int event, int x, int y, int flags, void* param);
//
//private:
//	bool m_bDrag;
//	cv::Rect m_rectSel;
//	cv::Point m_point1, m_point2;
//	cv::Mat m_matImg;
//};