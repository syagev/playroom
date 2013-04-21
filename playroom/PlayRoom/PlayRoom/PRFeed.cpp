#include "stdafx.h"
#include "PRFeed.h"

using namespace cv;
using namespace std;
using namespace concurrency;


// Destructor - attempt to delete member pointers
CPRFeed::~CPRFeed(void)
{
	send(m_ub_Msg, THREAD_ACTION::KILL);
	wait(this);

	//the internal feed is done, release it
	destroyAllWindows();
	if (m_pVC->isOpened())
		m_pVC->release();
}

// Construct the feed from the specified file
CPRFeed::CPRFeed(const string sSrc) :
	m_pVC(new VideoCapture()), m_sSrc(sSrc), m_pStory(NULL), m_matMskCarpet(480,640,CV_8U,255) //, m_bgSub(500, 16, false)
{
	//start the agent (worker thread)
	start();
	m_abPlaying = false;
	m_abPaused = false;
	//m_abLearning = false;
	
	//hard coded carpet (don't forget initializer)
	vector<Point> vecCarpet;
	vecCarpet.push_back(Point(146,34));
	vecCarpet.push_back(Point(461,116));
	vecCarpet.push_back(Point(399,280));
	vecCarpet.push_back(Point(102,217));
	fillConvexPoly(m_matMskCarpet, vecCarpet, Scalar(0));
}

// Just plays the feed (start a worker thread that plays the video player)
bool CPRFeed::Play()
{
	//if playing already this wont work
	if (IsPlaying())
		return false;

	//open the players, if exists this does nothing
	namedWindow("LL");
	namedWindow("PlayRoom");

	//signal the thread
	return send(m_ub_Msg, THREAD_ACTION::START);;
}

// If thread is running signals thread to close
bool CPRFeed::Stop()
{
	//if not playing this doesn't work
	if (!IsPlaying())
		return false;
	if (m_abPaused)
		Pause();

	//signal the worker thread
	send(m_ub_Msg, THREAD_ACTION::STOP);

	return true;
}

// Signal the agent to pause/continue
bool CPRFeed::Pause()
{
	//if not playing this doesn't work
	if (!IsPlaying())
		return false;

	//signal the worker thread
	return send(m_ub_Msg, THREAD_ACTION::PAUSE);
}

// Check agent state and return playing state
bool CPRFeed::IsPlaying()
{
	return m_abPlaying;
}

// Learn BG from now until we are content or user stop
//bool CPRFeed::LearnBG()
//{
//	return (m_abLearning = !m_abLearning);
//}

// Initialize the cascade classifier
//bool CPRFeed::InitDetector()
//{
//	//m_CC.load("S:\\Dropbox\\Projects\\PlayRoom\\Raw\\CascadeTrn\\dog.xml");
//
//	return true;
//}

// Returns a snapshot from the current feed (this is a copy of the original buffer)
Mat CPRFeed::GetSnapshot()
{
	send(m_ub_Msg, THREAD_ACTION::SNAPSHOT);
	return receive(m_ub_matRes);
}

bool CPRFeed::MarkCarpet(Mat matMskCarpet)
{
	//we need either not playing or paused
	if (IsPlaying() && !m_abPaused)
		return false;

	m_matMskCarpet = matMskCarpet;

	return true;
}

// Attaches a story board to the current feed
bool CPRFeed::AttachStoryboard(CStoryboard* pStory, bool bKeepTemplates)
{
	//we need either not playing or paused
	if (IsPlaying() && !m_abPaused)
		return false;
	
	m_pStory = pStory;

	//create/update the props array
	if (bKeepTemplates) {
		if (m_vecProps.size() != m_pStory->m_vecProps.size())
			return false;

		for (int i = 0; i < m_vecProps.size(); i++)
			m_vecProps[i].pProp = &m_pStory->m_vecProps[i];
	}
	else {
		m_vecProps.clear();
		for (vector<CProp>::const_iterator itrProp = m_pStory->m_vecProps.begin(); 
			itrProp != m_pStory->m_vecProps.end(); itrProp++) {
			m_vecProps.push_back(PROP_DATA(&(*itrProp)));
		}
		
		/*tld::Settings settings(m_iFrmRows, m_iFrmCols, m_iStep);
		for (int i = 0; i < m_vecProps.size(); i++)
			m_vecProps[i].pTLD = new tld::TLD(settings);*/
	}

	return true;
}

// Updates a prop's template
bool CPRFeed::UpdatePropTemplate(int iPropID, Vec3b scClrMean, Vec3b scClrThresh)
{
	//we need either not playing or paused
	/*if (IsPlaying() && !m_abPaused)
		return false;*/

	//we need an active storyboard which fits the PropID
	if (m_pStory == NULL || iPropID > m_vecProps.size())
		return false;

	//cvtColor(matTempl, matTempl, CV_BGR2GRAY);
	//m_vecProps[iPropID].matTempl = matTempl;
	//m_vecProps[iPropID].rectROI = rectROI;
	//m_vecProps[iPropID].pTLD->selectObject(matTempl, &rectROI);

	send(m_vecProps[iPropID].ow_scClrMean, scClrMean);
	send(m_vecProps[iPropID].ow_scClrThresh, scClrThresh);

	return true;
}

//vector<vector<Point>> CPRFeed::PreProcess(Mat& matFrm, Mat& matGray, vector<Rect>& vecFGBlobs)
//{
//	vector<vector<Point>> vecContours, vecBigContours;
//	Mat matFG;
//
//	cvtColor(matFrm, matGray, CV_RGB2GRAY);
//	
//	m_bgSub(matGray, matFG, -1); //(bool)m_abLearning ? -1 : 0.00000001);
//	erode(matFG, matFG, Mat(), Point(-1,-1), 2);
//	dilate(matFG, matFG, Mat(), Point(-1,-1), 4);
//
//	findContours(matFG, vecContours, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);
//	
//	//drawContours(matGray, vecContours, -1, CV_RGB(255,255,255));
//
//	vecFGBlobs.clear();
//	for (int i = 0; i < vecContours.size(); i++) {
//		if (contourArea(vecContours[i]) > 1000) {
//			vecFGBlobs.push_back(boundingRect(vecContours[i]));
//			vecBigContours.push_back(vecContours[i]);
//		}
//	}
//
//	return vecBigContours;
//}

// Agent run - runs the capturing device and processes events and actions
void CPRFeed::run()
{
	THREAD_ACTION msg = THREAD_ACTION::NONE;
	int64 iTic;
	char sStats[128];
	float fFPS;
	double dToc;
	bool bKill = false;

	while (!bKill && receive(m_ub_Msg) != THREAD_ACTION::KILL) {
		
		Mat matFrm, matHSV, matMskProp, matBlobs; //matMskCarpet, matSnapshot, matGray, matHue(matFrm.rows, matFrm.cols, CV_8UC1), matFG, 
		//vector<Rect> vecFGBlobs;

		vector<vector<Point>> vecContours;
		int iBiggestContourInd;
		double dBiggestContourArea, dBlobArea;
		Moments momentsProp;
		Vec3b scPropClrMean, scPropClrThresh;
				
		//re-open the VideoCapture if not open
		if (!m_pVC->isOpened()) {
			if (m_sSrc.compare("CAM") != 0)
				m_pVC->open(m_sSrc);
			else
				m_pVC->open(0);
		}

		//retrieve a frame to know stream size
		m_pVC->read(matFrm);
		
		/*cvtColor(matFrm, matGray, CV_RGB2GRAY);
		m_iFrmCols = matGray.cols;
		m_iFrmRows = matGray.rows;
		m_iStep = matGray.step;*/

		/*matFG.create(m_iFrmRows, m_iFrmCols, CV_8UC1);*/

		//init TLDs
		/*for (int i = 0; i < m_vecProps.size(); i++) {
			if (m_vecProps[i].pTLD == NULL)
				m_vecProps[i].pTLD = new tld::TLD(tld::Settings(m_iFrmRows, m_iFrmCols, m_iStep));
			else
				m_vecProps[i].pTLD->updateFrmSize(m_iFrmRows, m_iFrmCols, m_iStep);
		}*/

		bool bStop = false;
		//int piFromTo[] = {0,0};

		//create the BG subtractor
		//BackgroundSubtractorMOG bgSub;
		
		//update status
		m_abPlaying = true;

		//do the PlayRoom!
		while (!bStop && m_pVC->read(matFrm)) {
			//actions
			if (try_receive(m_ub_Msg, msg)) {
				switch (msg)
				{
				//begin learning carpet & BG
				//case THREAD_ACTION::LEARN_BG:
				//	convert to HSV color space and extract Hue
				//	cvtColor(matFrm, matCarpet, CV_RGB2HSV);
				//	mixChannels(&matFrm, 1, &matHue, 1, piFromTo, 1);
				//	inRange(matHue, Scalar(CARPET_COLOR)+
				//	m_iAction = THREAD_ACTION::CONT_LEARN_BG;	//continue learning
				//	break;

				//continue learning carpet & BG
				/*case THREAD_ACTION::CONT_LEARN_BG:
					bgSub.operator()(matFrm, matFG, BG_LEARN_RATE);
					break;*/

				case THREAD_ACTION::SNAPSHOT:
					send(m_ub_matRes, matFrm.clone());
					break;

				case THREAD_ACTION::PAUSE:
					m_abPaused = true;
					while ((msg = receive(m_ub_Msg)) != THREAD_ACTION::PAUSE && 
						msg != THREAD_ACTION::STOP && msg != THREAD_ACTION::KILL);
					m_abPaused = false;

					//reque STOP or KILL messages
					if (msg != THREAD_ACTION::PAUSE)
						send(m_ub_Msg, msg);

					break;

				case THREAD_ACTION::STOP:
					bStop = true;
					break;

				case THREAD_ACTION::KILL:
					bStop = true;
					bKill = true;
					break;
				}
			}

			//subtract background
			//bgSub.operator()(matFrm, matFG);

			//run cascade classifier
			//cvtColor(matFrm, matFrm, CV_RGB2GRAY);
			//m_CC.detectMultiScale(matFrm, vecRect);
			//rectangle(matFrm, vecRect[0], 255, 2);

			iTic = getTickCount();
			
			//convert frame to HSV
			cvtColor(matFrm, matHSV, CV_RGB2HSV);
						
			//matFG = 0;
			//PreProcess(matFrm, matGray, vecFGBlobs);
			/*drawContours(matFG, PreProcess(matFrm, matGray, vecFGBlobs), -1, Scalar(255,255,255));
			imshow("FG", matFG);*/

			/*for (int i = 0; i < vecFGBlobs.size(); i++)
				rectangle(matFrm, vecFGBlobs[i], CV_RGB(100,100,100), 1);*/

			//check if there's a storyboard
			if (m_pStory != NULL && m_pStory->IsPlaying()) {
				/*m_vecProps[0].pTLD->processImage(matGray, vecFGBlobs);

				if(m_vecProps[0].pTLD->currBB != NULL)
					rectangle(matFrm, *(m_vecProps[0].pTLD->currBB), CV_RGB(255,0,0), 3);*/

				//zero blobs display
				matBlobs = Mat::zeros(matFrm.rows, matFrm.cols, CV_8UC3);
				
				//iterate props
				//TODO: this should be parallelized
				for (int i = 0; i < m_vecProps.size(); i++) {
					if (!m_vecProps[i].ow_scClrMean.has_value())
						continue;

					scPropClrMean = m_vecProps[i].ow_scClrMean.value();
					scPropClrThresh = m_vecProps[i].ow_scClrThresh.value();

					//threshold the input frame
					inRange(matHSV, scPropClrMean - scPropClrThresh, 
						scPropClrMean + scPropClrThresh, matMskProp);

					//apply carpet mask
					//TODO: masking every time is completely stupid, at least ROI an upright rect bounding the carpet
					if (!m_matMskCarpet.empty())
						matMskProp.setTo(0, m_matMskCarpet);

					//clear some noise
					erode(matMskProp, matMskProp, Mat());
					dilate(matMskProp, matMskProp, Mat(), Point(-1,-1), 2);

					//find largest connected component
					Mat matTmp = matMskProp.clone();
					findContours(matMskProp, vecContours, CV_RETR_EXTERNAL, CV_CHAIN_APPROX_SIMPLE);
					for (int j = iBiggestContourInd = (int)(dBiggestContourArea = 0); j < vecContours.size(); j++) {
						if ((dBlobArea = contourArea(vecContours[j])) > dBiggestContourArea) {
							dBiggestContourArea = dBlobArea;
							iBiggestContourInd = j;
						}
					}

					if (vecContours.size() > 0) {
						//calculate the shapes moments and center of mass
						momentsProp = moments(vecContours[iBiggestContourInd]);
						m_vecProps[i].pProp->x = (int)(momentsProp.m10 / momentsProp.m00);
						m_vecProps[i].pProp->y = (int)(momentsProp.m01 / momentsProp.m00);

						//display stuff
						drawContours(matBlobs, vecContours, iBiggestContourInd, (Scalar)scPropClrMean, CV_FILLED);
					}

					circle(matFrm, Point(m_vecProps[i].pProp->x, m_vecProps[i].pProp->y), 5, Scalar(255, 0, 0));
				}

				m_pStory->Step();
			}
			dToc = (getTickCount() - iTic) / cvGetTickFrequency();
			dToc = dToc / 1000000;
			fFPS = (float)(1 / dToc);
			
			//it's always nice to see
			sprintf_s(sStats, "FPS %.2f", fFPS);
			putText(matFrm, sStats, Point(25, 25), FONT_HERSHEY_PLAIN, 1, Scalar(255,255,255));
			
			imshow("PlayRoom", matFrm);
			if (!matBlobs.empty())
				imshow("LL", matBlobs);
		
			cv::waitKey(1);
		}

		//update status
		m_abPlaying = false;

		m_pVC->release();
	}

	done();
}