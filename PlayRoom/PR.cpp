#include "stdafx.h"
#include "PR.h"

using namespace cv;
using namespace std;
using namespace concurrency;

//// CProp

// Construction
CProp::CProp() : id(NULL)
{
	x = -1;
	y = -1;
}

CProp::~CProp(void)
{
}


//// CStoryboard 

// Story board construction
CStoryboard::CStoryboard(int iNumProps) : 
	m_vecProps(iNumProps), m_bPlaying(false)
{
	//start the agent
	start();
}

CStoryboard::~CStoryboard(void)
{
	//signal thread to exit
	send(m_ub_Msg, THREAD_ACTION::KILL);
	wait(this);

	//unload any existing sounds
	if (!m_mapSnds.empty()) {
		for (map<int,MCIDEVICEID>::const_iterator itr = m_mapSnds.begin(); 
			itr != m_mapSnds.end(); ++itr) {

			mciSendCommand(itr->second, MCI_CLOSE, NULL, NULL);
		}
	}
}

void CStoryboard::LoadSounds(pair<int,string> apairSnds[], int iNumSnds)
{
	m_apairSnds = apairSnds;
	m_iNumSnds = iNumSnds;

	send(m_ub_Msg, THREAD_ACTION::LOAD_SOUNDS);

	evtDone.wait();
}

void CStoryboard::Sound(int iSnd)
{
	send(m_ubiSnd, iSnd);
	send(m_ub_Msg, THREAD_ACTION::SOUND);
}

void CStoryboard::Sound(int iSnd, string sSndFile, bool bLoop)
{
	if (bLoop) {
		task<void> tSnd([sSndFile]() {
			MCIERROR err = NULL;

			MCI_OPEN_PARMS mciOpenParams = {NULL, NULL, (LPCTSTR)MCI_DEVTYPE_WAVEFORM_AUDIO, 
				sSndFile.c_str(), NULL};
			err = mciSendCommand(NULL, MCI_OPEN, MCI_OPEN_TYPE_ID | MCI_OPEN_TYPE | 
				MCI_OPEN_ELEMENT, (DWORD)&mciOpenParams);

			//not strictly thread safe but 
			MCI_PLAY_PARMS mciPlayParams = { NULL, NULL, NULL };
			MCI_SEEK_PARMS mciSeekParams = { NULL, NULL };
			
			while (!err) {
				err = mciSendCommand(mciOpenParams.wDeviceID, 
					MCI_PLAY, MCI_WAIT, (DWORD_PTR)&mciPlayParams);
				mciSendCommand(mciOpenParams.wDeviceID, 
					MCI_SEEK, MCI_WAIT | MCI_SEEK_TO_START, (DWORD_PTR)&mciSeekParams);
			}

			mciSendCommand(mciOpenParams.wDeviceID, MCI_CLOSE, NULL, NULL);
		});
	}
	else {
		MCI_OPEN_PARMS mciOpenParams = {NULL, NULL, (LPCTSTR)MCI_DEVTYPE_WAVEFORM_AUDIO, 
			sSndFile.c_str(), NULL};
		MCIERROR err = mciSendCommand(NULL, MCI_OPEN, MCI_OPEN_TYPE_ID | MCI_OPEN_TYPE | 
			MCI_OPEN_ELEMENT, (DWORD)&mciOpenParams);
		
		Sound(mciOpenParams.wDeviceID);

		mciSendCommand(mciOpenParams.wDeviceID, MCI_CLOSE, NULL, NULL);
	}
}

// Check agent state and return playing state
bool CStoryboard::IsPlaying()
{
	return m_bPlaying;
}

// Start the storyboard
bool CStoryboard::Play()
{
	//if playing already this wont work
	if (IsPlaying())
		return false;

	//update status
	return m_bPlaying = true;
}

// Agent run - takes care of the storyboard's sound system
void CStoryboard::run()
{
	THREAD_ACTION msg;
	
	MCI_GENERIC_PARMS mciGenParams = { NULL };
	MCI_PLAY_PARMS mciPlayParams = { NULL, NULL, NULL };
	MCI_SEEK_PARMS mciSeekParams = { NULL, NULL };
	MCIERROR err = NULL;

	while ((msg = receive(m_ub_Msg)) != THREAD_ACTION::KILL) {
		//actions
		switch (msg)
		{
			case THREAD_ACTION::LOAD_SOUNDS:
				//load the sounds
					
				//char acAlias[16];
				for (int i = 0; i < m_iNumSnds; i++) {
					/*sprintf_s(acAlias, 16, "S%d", i);*/
					MCI_OPEN_PARMS mciOpenParams = {NULL, NULL, (LPCTSTR)MCI_DEVTYPE_WAVEFORM_AUDIO, 
						m_apairSnds[i].second.c_str(), NULL /*acAlias*/};
					err = mciSendCommand(NULL, MCI_OPEN, MCI_OPEN_TYPE_ID | MCI_OPEN_TYPE | 
						MCI_OPEN_ELEMENT/* | MCI_OPEN_ALIAS*/, (DWORD)&mciOpenParams);

					m_mapSnds[m_apairSnds[i].first] = mciOpenParams.wDeviceID;
				}
				evtDone.set();

				break;

			case THREAD_ACTION::SOUND:
				try {
					int iSnd = receive(m_ubiSnd);
					if (iSnd < 0) {
						err = mciSendCommand(m_mapSnds.at(-iSnd), 
							MCI_STOP, NULL, (DWORD_PTR)&mciGenParams);
					}	
					else {
						err = mciSendCommand(iSnd = m_mapSnds.at(iSnd), 
							MCI_SEEK, MCI_WAIT | MCI_SEEK_TO_START, (DWORD_PTR)&mciSeekParams);
						err = mciSendCommand(iSnd, 
							MCI_PLAY, NULL, (DWORD_PTR)&mciPlayParams);
					}
				}
				catch (out_of_range) {}

				break;
		}
	}

	done();
}


//// CStoryboardBarnie

// Hard code Barnie's amazing story board
CStoryboardBarnie::CStoryboardBarnie(void) : 
	CStoryboard(4), m_iCloseProp(-1)
{
	m_aiTouchThresh = DEF_TOUCH_THRESH;

	//define props
	m_vecProps[DOG].id = DOG;
	m_vecProps[BOWL].id = BOWL;
	m_vecProps[PARK].id = PARK;
	m_vecProps[BONE].id = BONE;

	//load sounds
	pair<int,string> saSounds[] = {
		pair<int,string>(EAT, "S:\\Dropbox\\Projects\\PlayRoom\\Media\\Eat.wav"),
		pair<int,string>(DRINK, "S:\\Dropbox\\Projects\\PlayRoom\\Media\\Drink.wav"),
		pair<int,string>(BARK, "S:\\Dropbox\\Projects\\PlayRoom\\Media\\Bark.wav")
	};
	LoadSounds(saSounds, 3);
}


CStoryboardBarnie::~CStoryboardBarnie(void) 
{
}

// Set parameters
void CStoryboardBarnie::Set(int iParam, int iVal)
{
	switch (iParam) {
	case TOUCH_THRESHOLD:
		m_aiTouchThresh = iVal;
		break;
	}
}

// Get parameters
int CStoryboardBarnie::Get(int iParam)
{
	switch (iParam) {
	case TOUCH_THRESHOLD:
		return m_aiTouchThresh;
	}
	
	return NULL;
}

// Start the storyboard
bool CStoryboardBarnie::Play()
{
	if (!CStoryboard::Play())
		return false;

	//start playing the tune (independent thread)
	//Sound(LOOP, "S:\\Dropbox\\Projects\\PlayRoom\\Media\\Wonderoom_loop.wav", true);
	
	return true;
}

// Story step (frame)
void CStoryboardBarnie::Step()
{
	bool bCloseToSomeProp = false;

	if (m_vecProps[DOG].x > 0) {
		//check Barnie's proximity to other props
		for (int i = 1; i < m_vecProps.size(); i++) {
			if (m_vecProps[i].x > 0 &&
				norm(complex<int>(m_vecProps[i].x - m_vecProps[DOG].x, 
				m_vecProps[i].y - m_vecProps[DOG].y)) < m_aiTouchThresh) {

				if (i != m_iCloseProp)
					Sound(m_iCloseProp = i);
				bCloseToSomeProp = true;
				break;
			}
		}
	}

	if (!bCloseToSomeProp && m_iCloseProp >= 0) {
		Sound(-m_iCloseProp);
		m_iCloseProp = -1;
	}
}