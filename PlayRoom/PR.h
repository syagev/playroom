#pragma once

class CProp
{
public:
	CProp();
	~CProp(void);

public:
	int id;
	std::atomic_int x,y;
};


#define STORYBOARD_PARAM_BASE 0

class CStoryboard : concurrency::agent
{
public:
	CStoryboard(int iNumProps);
	~CStoryboard(void);

	bool IsPlaying();
	virtual bool Play();
	virtual void Step() = 0;
	virtual void Set(int iParam, int iValue) = 0;
	virtual int Get(int iParam) = 0;

	std::vector<CProp> m_vecProps;

private:
	enum THREAD_ACTION {
		NONE, KILL, PAUSE, LOAD_SOUNDS, SOUND
	};
	concurrency::unbounded_buffer<THREAD_ACTION> m_ub_Msg;
	concurrency::event evtDone;

	std::pair<int,std::string>* m_apairSnds;
	int m_iNumSnds;
	concurrency::unbounded_buffer<int> m_ubiSnd;
	std::map<int,MCIDEVICEID> m_mapSnds;

	void run();

	bool m_bPlaying;
	
	
protected:
	void LoadSounds(std::pair<int,std::string> pairaSnds[], int iNumPairs);
	void Sound(int iSnd);
	void Sound(int iSnd, std::string sSndFile, bool bLoop);
};


// Hard coded Barnie storyboard

#define DEF_TOUCH_THRESH	200

class CStoryboardBarnie : public CStoryboard
{
public:
	CStoryboardBarnie(void);
	~CStoryboardBarnie(void);
	
	bool Play();
	void Step();
	
	enum PARAM {
		TOUCH_THRESHOLD = STORYBOARD_PARAM_BASE
	};
	void Set(int iParam, int iVal);
	int Get(int iParam);

	enum PROP {
		DOG = 0, BOWL, PARK, BONE
	};
	
private:
	enum SND {
		DRINK = 1, BARK, EAT, WATERTOPARK, WATERTOBONE, PARKTOWATER,
		PAWKTOBONE, BONETOWATER, BONETOPARK, GOODWORK, WALKINTHEPARK,
		PLAYWITHBONE, MYNAME, LOOP
	};

	int m_iCloseProp;
	std::atomic_int m_aiTouchThresh;
};