#include "stdafx.h"
#include "GUIUtils.h"

using namespace cv;


CPropWindow::CPropWindow(int iPropID, CPRFeed* pPRFeed, std::string sPropName) :
	m_iPropID(iPropID), m_pPRFeed(pPRFeed), m_sPropName(sPropName), m_scThresh(10,255,255)
{
}

CPropWindow::~CPropWindow(void)
{
}

void CPropWindow::Show()
{
	m_matSnap = m_pPRFeed->GetSnapshot();
	namedWindow(m_sPropName, CV_WINDOW_NORMAL | CV_WINDOW_KEEPRATIO | CV_GUI_EXPANDED);
	imshow(m_sPropName, m_matSnap);
	cvtColor(m_matSnap, m_matSnap, CV_RGB2HSV);

	setMouseCallback(m_sPropName, &mouseCallback, this);

	createTrackbar("Hue Threshold", m_sPropName, NULL, 255, &trackbarCallback, this);
	setTrackbarPos("Hue Threshold", m_sPropName, 10);
	createTrackbar("Sat Threshold", m_sPropName, NULL, 255, &trackbarCallback, this);
	setTrackbarPos("Sat Threshold", m_sPropName, 26);
	createTrackbar("Val Threshold", m_sPropName, NULL, 255, &trackbarCallback, this);
	setTrackbarPos("Val Threshold", m_sPropName, 60);
}

void CPropWindow::mouseCallback(int iEvent, int x, int y, int flags, void* pPropWindow)
{
	CPropWindow* pThis = (CPropWindow*)pPropWindow;

	switch (iEvent) {
	case CV_EVENT_LBUTTONUP:
		pThis->m_pPRFeed->UpdatePropTemplate(pThis->m_iPropID, 
			pThis->m_scClr = pThis->m_matSnap.at<cv::Vec3b>(Point(x,y)), pThis->m_scThresh);
		break;

	case CV_EVENT_LBUTTONDBLCLK:
		imshow(pThis->m_sPropName, pThis->m_matSnap = pThis->m_pPRFeed->GetSnapshot());
		cvtColor(pThis->m_matSnap, pThis->m_matSnap, CV_RGB2HSV);
		break;
	}

}

void CPropWindow::trackbarCallback(int pos, void* userdata)
{
	CPropWindow* pThis = (CPropWindow*)userdata;
	
	pThis->m_pPRFeed->UpdatePropTemplate(pThis->m_iPropID, pThis->m_scClr, 
		pThis->m_scThresh = Vec3b(getTrackbarPos("Hue Threshold", pThis->m_sPropName),
		getTrackbarPos("Sat Threshold", pThis->m_sPropName),
		getTrackbarPos("Val Threshold", pThis->m_sPropName)));
}


//CROISelector::CROISelector(Mat matImg) : 
//	m_matImg(matImg), m_bDrag(false)
//{
//}
//
//CROISelector::~CROISelector(void)
//{
//}
//
//Rect CROISelector::SelectROI()
//{
//	//open the window
//	namedWindow("SelectProp");
//	imshow("SelectProp", m_matImg);
//	setMouseCallback("SelectProp",  &OnCVMouse, this);
//	
//	//wait for the enter key
//	int iKey = waitKey(0);
//	destroyWindow("SelectProp");
//
//	if (iKey == VK_RETURN)
//		return m_rectSel;
//	else
//		return cv::Rect();
//}
//
//void CROISelector::OnCVMouse(int evt, int x, int y, int flags, void* pParam)
//{
//	CROISelector* pThis = (CROISelector*)pParam;
//    
//	if (evt == CV_EVENT_LBUTTONDOWN && !pThis->m_bDrag)
//    {
//        /* left button clicked. ROI selection begins */
//        pThis->m_point1 = Point(x, y);
//        pThis->m_bDrag = true;
//    }
//     
//    if (evt == CV_EVENT_MOUSEMOVE && pThis->m_bDrag)
//    {
//        /* mouse dragged. ROI being selected */
//		Mat imgWithRect = pThis->m_matImg.clone();
//        pThis->m_point2 = Point(x, y);
//        rectangle(imgWithRect, pThis->m_point1, pThis->m_point2, Scalar(255, 0, 0), 3, 8, 0);
//        imshow("SelectProp", imgWithRect);
//    }
//     
//	if (evt == CV_EVENT_LBUTTONUP && pThis->m_bDrag)
//    {
//        pThis->m_point2 = Point(x, y);
//		pThis->m_rectSel = Rect(pThis->m_point1.x,pThis->m_point1.y,x-pThis->m_point1.x,y-pThis->m_point1.y);
//        pThis->m_bDrag = false;
//    }
//}


cv::Mat selectCarpet(cv::Mat matSnap)
{
	namedWindow("Select Carpet");
	imshow("Select Carpet", matSnap);

	concurrency::single_assignment<vector<Point>> sa_vecCarpet;

	setMouseCallback("Select Carpet", [] (int iEvent, int x, int y, int flags, void* userdata) {
		static vector<Point> vecCarpetPts;

		if (iEvent == CV_EVENT_LBUTTONDOWN) {
			vecCarpetPts.push_back(Point(x,y));

			if (vecCarpetPts.size() == 4)
				concurrency::send(((concurrency::single_assignment<vector<Point>>*)userdata), vecCarpetPts);
		}
	}, &sa_vecCarpet);
	
	vector<Point> vecCarpet;
	while (!concurrency::try_receive<vector<Point>>(sa_vecCarpet, vecCarpet))
		cv::waitKey(30);
	destroyWindow("Select Carpet");

	Mat matMskCarpet(matSnap.rows, matSnap.cols, CV_8U, Scalar(255));
	fillConvexPoly(matMskCarpet, vecCarpet, Scalar(0));

	return matMskCarpet;
}