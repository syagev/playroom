#pragma once
#include "PR.h"
//#include "tld\TLD.h"

/// constants
//#define FRAME_RATE 30
//#define BG_LEARN_RATE 0.5

class CPRFeed : concurrency::agent
{
public:
	~CPRFeed(void);
	CPRFeed(const std::string sSrc = "");

	bool Play();
	bool Stop();
	bool Pause();
	bool IsPlaying();
	//bool LearnBG();
	cv::Mat GetSnapshot();

	bool MarkCarpet(cv::Mat matMskCarpet);
	bool AttachStoryboard(CStoryboard* pStory, bool bKeepTemplates);
	bool UpdatePropTemplate(int iPropID, cv::Vec3b scClrMean, cv::Vec3b scClrThresh);


private:
	cv::VideoCapture* m_pVC;
	std::string m_sSrc;

	/*int m_iFrmRows, m_iFrmCols;
	size_t m_iStep;*/

	CStoryboard* m_pStory;
	
	struct PROP_DATA {
		CProp* pProp;
		//cv::Mat matTempl;
		//cv::Rect rectROI;
		//tld::TLD* pTLD;
		
		concurrency::overwrite_buffer<cv::Vec3b> ow_scClrMean;		//threshold & mean for color
		concurrency::overwrite_buffer<cv::Vec3b> ow_scClrThresh;

		PROP_DATA(const CProp* pPropArg) : pProp((CProp*)pPropArg) {};
		PROP_DATA(const PROP_DATA &propData) : pProp(propData.pProp) {};
	};
	std::vector<PROP_DATA> m_vecProps;

	/*std::atomic_bool m_abLearning;
	cv::BackgroundSubtractorMOG2 m_bgSub;*/
	cv::Mat m_matMskCarpet;
		
	enum THREAD_ACTION {
		NONE, START, STOP, PAUSE, KILL, //LEARN_BG, CONT_LEARN_BG
		SNAPSHOT
	};
	concurrency::unbounded_buffer<THREAD_ACTION> m_ub_Msg;
	
	concurrency::unbounded_buffer<cv::Mat> m_ub_matRes;
	std::atomic_bool m_abPlaying;
	std::atomic_bool m_abPaused;
	
	//std::vector<std::vector<cv::Point>> PreProcess(cv::Mat& matFrm, cv::Mat& matGray, std::vector<cv::Rect>& vecFGBlobs);
	void run();
	
	//cv::CascadeClassifier m_CC;
	//bool InitDetector();
};